-- ============================================
-- 1M-scale hardening migration.
-- Apply on top of supabase_schema.sql.
-- ============================================

-- ── 1. Daily usage RPC (server-enforced rate limit) ──────────

CREATE OR REPLACE FUNCTION public.increment_fit_check_usage(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  current_count int;
  limit_count int := 3;
BEGIN
  -- Upsert the row and return the new count atomically.
  INSERT INTO public.daily_usage (user_id, usage_date, fit_checks)
  VALUES (p_user_id, CURRENT_DATE, 1)
  ON CONFLICT (user_id, usage_date)
  DO UPDATE SET fit_checks = public.daily_usage.fit_checks + 1
  RETURNING fit_checks INTO current_count;

  -- If the bump pushed us past the limit, roll back the increment so
  -- the counter doesn't inflate on repeated over-limit calls.
  IF current_count > limit_count THEN
    UPDATE public.daily_usage
       SET fit_checks = limit_count
     WHERE user_id = p_user_id AND usage_date = CURRENT_DATE;
    RETURN false;
  END IF;

  RETURN true;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.increment_fit_check_usage(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.increment_fit_check_usage(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.remaining_fit_checks_today(p_user_id uuid)
RETURNS int
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT GREATEST(
    0,
    3 - COALESCE(
      (SELECT fit_checks FROM public.daily_usage
        WHERE user_id = p_user_id AND usage_date = CURRENT_DATE),
      0
    )
  );
$$;

GRANT EXECUTE ON FUNCTION public.remaining_fit_checks_today(uuid) TO authenticated;

-- ── 2. Subscribers (RevenueCat sync target) ──────────────────

CREATE TABLE IF NOT EXISTS public.subscribers (
  user_id        UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  rc_customer_id TEXT,
  is_pro         BOOLEAN NOT NULL DEFAULT false,
  entitlement    TEXT,
  product_id     TEXT,
  period_type    TEXT,
  purchased_at   TIMESTAMPTZ,
  expires_at     TIMESTAMPTZ,
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_subscribers_expires
  ON public.subscribers(expires_at)
  WHERE is_pro = true;

ALTER TABLE public.subscribers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own subscription" ON public.subscribers
  FOR SELECT USING (auth.uid() = user_id);
-- No INSERT/UPDATE policy: only the service role (from webhook) writes.

-- ── 3. Indexes for pagination + hot queries ──────────────────

CREATE INDEX IF NOT EXISTS idx_wardrobe_items_user_created
  ON public.wardrobe_items(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_outfits_user_created
  ON public.outfits(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_fit_checks_user_created
  ON public.fit_checks(user_id, created_at DESC);

-- ── 4. Storage bucket split ──────────────────────────────────
-- Private (signed URLs only): wardrobe + personal fit checks.
-- Public (CDN-served): battle images + opted-in public fit checks.

INSERT INTO storage.buckets (id, name, public)
VALUES ('grwm-private', 'grwm-private', false)
ON CONFLICT (id) DO UPDATE SET public = false;

INSERT INTO storage.buckets (id, name, public)
VALUES ('grwm-public', 'grwm-public', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- grwm-private RLS: path must be `<user_id>/...`
DROP POLICY IF EXISTS "Private upload own" ON storage.objects;
CREATE POLICY "Private upload own" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'grwm-private'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
DROP POLICY IF EXISTS "Private read own" ON storage.objects;
CREATE POLICY "Private read own" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'grwm-private'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );
DROP POLICY IF EXISTS "Private delete own" ON storage.objects;
CREATE POLICY "Private delete own" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'grwm-private'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- grwm-public RLS:
--   - battles/<user_id>/<code>.jpg
--   - fitchecks/<user_id>/<hash>.jpg
DROP POLICY IF EXISTS "Public upload own" ON storage.objects;
CREATE POLICY "Public upload own" ON storage.objects
  FOR INSERT WITH CHECK (
    bucket_id = 'grwm-public'
    AND auth.uid()::text = (storage.foldername(name))[2]
    AND (storage.foldername(name))[1] IN ('battles', 'fitchecks')
  );
DROP POLICY IF EXISTS "Public read all" ON storage.objects;
CREATE POLICY "Public read all" ON storage.objects
  FOR SELECT USING (bucket_id = 'grwm-public');
DROP POLICY IF EXISTS "Public delete own" ON storage.objects;
CREATE POLICY "Public delete own" ON storage.objects
  FOR DELETE USING (
    bucket_id = 'grwm-public'
    AND auth.uid()::text = (storage.foldername(name))[2]
  );

-- ── 5. Feature flags (remote kill-switch) ────────────────────

CREATE TABLE IF NOT EXISTS public.feature_flags (
  key        TEXT PRIMARY KEY,
  enabled    BOOLEAN NOT NULL DEFAULT false,
  payload    JSONB,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.feature_flags ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone auth'd reads flags" ON public.feature_flags
  FOR SELECT USING (auth.role() = 'authenticated');

-- Seed a few practical flags.
INSERT INTO public.feature_flags (key, enabled, payload) VALUES
  ('kill_ai_proxy',        false, NULL),
  ('force_upgrade_build',  false, '{"min_build": 1}'::jsonb),
  ('enable_stranger_feed', true,  NULL)
ON CONFLICT (key) DO NOTHING;
