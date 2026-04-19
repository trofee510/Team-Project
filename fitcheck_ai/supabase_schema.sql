-- ============================================
-- GRWM (Get Ready With Me) - Supabase Schema
-- Paste this into Supabase SQL Editor and Run
-- ============================================

-- 1. User Profiles (auto-created on signup)
CREATE TABLE public.user_profiles (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  aesthetics  JSONB DEFAULT '[]'::jsonb,
  body_type   TEXT,
  color_preferences JSONB DEFAULT '[]'::jsonb,
  gender      TEXT,
  display_name TEXT,
  onboarding_complete BOOLEAN NOT NULL DEFAULT false,
  notifications_enabled BOOLEAN NOT NULL DEFAULT false,
  notification_time TEXT,
  location    TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(user_id)
);

-- Auto-create profile on signup
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.user_profiles (user_id)
  VALUES (NEW.id);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();

-- 2. Wardrobe Items
CREATE TABLE public.wardrobe_items (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  category        TEXT NOT NULL,
  subcategory     TEXT,
  color           TEXT,
  image_path      TEXT NOT NULL,
  thumbnail_path  TEXT,
  name            TEXT,
  brand           TEXT,
  purchase_price  NUMERIC(10,2),
  wear_count      INTEGER NOT NULL DEFAULT 0,
  tags            JSONB DEFAULT '[]'::jsonb,
  season          TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_wardrobe_user_cat ON public.wardrobe_items(user_id, category);

-- 3. Outfits
CREATE TABLE public.outfits (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  occasion    TEXT,
  reasoning   TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_outfits_user ON public.outfits(user_id);

-- 4. Outfit Items (join table)
CREATE TABLE public.outfit_items (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  outfit_id         UUID NOT NULL REFERENCES public.outfits(id) ON DELETE CASCADE,
  wardrobe_item_id  UUID NOT NULL REFERENCES public.wardrobe_items(id) ON DELETE CASCADE,
  slot              TEXT NOT NULL
);

CREATE INDEX idx_outfit_items_outfit ON public.outfit_items(outfit_id);

-- 5. Challenges (must exist before fit_checks references it)
CREATE TABLE public.challenges (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  title       TEXT NOT NULL,
  description TEXT,
  theme       TEXT,
  start_date  TIMESTAMPTZ NOT NULL,
  end_date    TIMESTAMPTZ NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_challenges_window ON public.challenges(start_date, end_date);

-- 6. Fit Checks
CREATE TABLE public.fit_checks (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  outfit_id             UUID REFERENCES public.outfits(id) ON DELETE SET NULL,
  score                 INTEGER NOT NULL CHECK (score BETWEEN 0 AND 100),
  feedback              TEXT NOT NULL,
  color_harmony_score   INTEGER,
  style_cohesion_score  INTEGER,
  occasion_score        INTEGER,
  fit_score             INTEGER,
  improvement_tips      JSONB DEFAULT '[]'::jsonb,
  image_path            TEXT,
  image_hash            TEXT,                            -- SHA-256 of normalized bytes (reproducibility cache)
  is_public             BOOLEAN NOT NULL DEFAULT false,  -- opt-in to strangers feed
  challenge_id          UUID REFERENCES public.challenges(id) ON DELETE SET NULL,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_fit_checks_user ON public.fit_checks(user_id);
CREATE INDEX idx_fit_checks_user_hash ON public.fit_checks(user_id, image_hash);
CREATE INDEX idx_fit_checks_public_recent
  ON public.fit_checks(created_at DESC)
  WHERE is_public = true;
CREATE INDEX idx_fit_checks_challenge ON public.fit_checks(challenge_id)
  WHERE challenge_id IS NOT NULL;

-- 7. Outfit Logs (calendar)
CREATE TABLE public.outfit_logs (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id           UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  outfit_id         UUID NOT NULL REFERENCES public.outfits(id) ON DELETE CASCADE,
  worn_date         DATE NOT NULL,
  notes             TEXT,
  selfie_image_path TEXT,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_outfit_logs_user_date ON public.outfit_logs(user_id, worn_date);

-- 8. Daily Usage Tracking (for free tier limits)
CREATE TABLE public.daily_usage (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  usage_date  DATE NOT NULL DEFAULT CURRENT_DATE,
  outfit_generations INTEGER NOT NULL DEFAULT 0,
  fit_checks  INTEGER NOT NULL DEFAULT 0,
  UNIQUE(user_id, usage_date)
);

CREATE INDEX idx_daily_usage_user_date ON public.daily_usage(user_id, usage_date);

-- 9. Fit Battles (friend-mode scoring)
CREATE TABLE public.fit_battles (
  id                   UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code                 TEXT NOT NULL UNIQUE,
  user_id              UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  owner_display_name   TEXT,
  image_path           TEXT NOT NULL,
  caption              TEXT,
  ai_score             INTEGER,
  ai_feedback          TEXT,
  expires_at           TIMESTAMPTZ NOT NULL,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_fit_battles_user ON public.fit_battles(user_id, created_at DESC);
CREATE INDEX idx_fit_battles_code ON public.fit_battles(code);

-- 10. Battle ratings (friends rate)
CREATE TABLE public.fit_battle_ratings (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  battle_id    UUID NOT NULL REFERENCES public.fit_battles(id) ON DELETE CASCADE,
  rater_id     UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  rater_name   TEXT NOT NULL,
  score        INTEGER NOT NULL CHECK (score BETWEEN 1 AND 100),
  comment      TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(battle_id, rater_id)
);

CREATE INDEX idx_battle_ratings_battle
  ON public.fit_battle_ratings(battle_id, created_at DESC);

-- 11. Public outfit ratings (strangers feed)
CREATE TABLE public.public_outfit_ratings (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  fit_check_id   UUID NOT NULL REFERENCES public.fit_checks(id) ON DELETE CASCADE,
  rater_id       UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  score          INTEGER NOT NULL CHECK (score BETWEEN 1 AND 100),
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE(fit_check_id, rater_id)
);

CREATE INDEX idx_public_ratings_fit ON public.public_outfit_ratings(fit_check_id);
CREATE INDEX idx_public_ratings_rater ON public.public_outfit_ratings(rater_id);

-- 12. Leaderboard view (last 7 days, min 3 votes)
CREATE OR REPLACE VIEW public.public_leaderboard_7d AS
SELECT
  fc.id              AS fit_check_id,
  fc.image_path      AS image_path,
  fc.score           AS ai_score,
  AVG(r.score)::NUMERIC(5,2) AS avg_rating,
  COUNT(r.id)        AS rating_count
FROM public.fit_checks fc
JOIN public.public_outfit_ratings r ON r.fit_check_id = fc.id
WHERE fc.is_public = true
  AND fc.created_at > now() - INTERVAL '7 days'
GROUP BY fc.id, fc.image_path, fc.score
HAVING COUNT(r.id) >= 3;

-- ============================================
-- Row Level Security (RLS) - CRITICAL
-- Each user can only access their own data
-- ============================================

-- User Profiles
ALTER TABLE public.user_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own profile" ON public.user_profiles
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can update own profile" ON public.user_profiles
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users can insert own profile" ON public.user_profiles
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Wardrobe Items
ALTER TABLE public.wardrobe_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own wardrobe" ON public.wardrobe_items
  FOR ALL USING (auth.uid() = user_id);

-- Outfits
ALTER TABLE public.outfits ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own outfits" ON public.outfits
  FOR ALL USING (auth.uid() = user_id);

-- Outfit Items
ALTER TABLE public.outfit_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own outfit items" ON public.outfit_items
  FOR ALL USING (
    outfit_id IN (SELECT id FROM public.outfits WHERE user_id = auth.uid())
  );

-- Fit Checks — owner manages; anyone (auth'd) can read public ones
ALTER TABLE public.fit_checks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users read own fit checks" ON public.fit_checks
  FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users read public fit checks" ON public.fit_checks
  FOR SELECT USING (is_public = true);
CREATE POLICY "Users write own fit checks" ON public.fit_checks
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own fit checks" ON public.fit_checks
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users delete own fit checks" ON public.fit_checks
  FOR DELETE USING (auth.uid() = user_id);

-- Outfit Logs
ALTER TABLE public.outfit_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own outfit logs" ON public.outfit_logs
  FOR ALL USING (auth.uid() = user_id);

-- Daily Usage
ALTER TABLE public.daily_usage ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own usage" ON public.daily_usage
  FOR ALL USING (auth.uid() = user_id);

-- Challenges — readable by any authenticated user; only service role writes
ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read challenges" ON public.challenges
  FOR SELECT USING (auth.role() = 'authenticated');

-- Fit Battles — owner manages; anyone (auth'd) with the code can read.
-- Because the code is the only way to discover the id, readability is fine.
ALTER TABLE public.fit_battles ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read a battle" ON public.fit_battles
  FOR SELECT USING (true);
CREATE POLICY "Users create own battles" ON public.fit_battles
  FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Users update own battles" ON public.fit_battles
  FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY "Users delete own battles" ON public.fit_battles
  FOR DELETE USING (auth.uid() = user_id);

-- Battle ratings — anyone can read; authenticated users can upsert their own.
ALTER TABLE public.fit_battle_ratings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone can read ratings" ON public.fit_battle_ratings
  FOR SELECT USING (true);
CREATE POLICY "Users insert own ratings" ON public.fit_battle_ratings
  FOR INSERT WITH CHECK (auth.uid() = rater_id OR rater_id IS NULL);
CREATE POLICY "Users update own ratings" ON public.fit_battle_ratings
  FOR UPDATE USING (auth.uid() = rater_id);

-- Public outfit ratings — anyone auth'd can read aggregates; write own only.
ALTER TABLE public.public_outfit_ratings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Anyone auth'd reads public ratings" ON public.public_outfit_ratings
  FOR SELECT USING (auth.role() = 'authenticated');
CREATE POLICY "Users write own public ratings" ON public.public_outfit_ratings
  FOR INSERT WITH CHECK (auth.uid() = rater_id);
CREATE POLICY "Users update own public ratings" ON public.public_outfit_ratings
  FOR UPDATE USING (auth.uid() = rater_id);

-- ============================================
-- Storage Bucket for all uploaded images.
-- Set PUBLIC so getPublicUrl() resolves for battle recipients.
-- Paths are UUID-based so wardrobe items are not browseable in practice.
--   - Personal wardrobe / fit checks: "<user_id>/..."
--   - Battles:                        "battles/<user_id>/<code>.jpg"
--   - Public fit checks:              "fitchecks/<user_id>/<hash>.jpg"
-- ============================================

INSERT INTO storage.buckets (id, name, public)
VALUES ('wardrobe-images', 'wardrobe-images', true)
ON CONFLICT (id) DO UPDATE SET public = true;

-- Read: with public=true, Supabase serves public URLs directly. We still
-- keep an explicit SELECT policy for authenticated access patterns.
CREATE POLICY "Anyone can view images"
  ON storage.objects FOR SELECT
  USING (bucket_id = 'wardrobe-images');

-- Write: user must own the path. We accept the user's UUID in folder[0]
-- (personal) or folder[1] (social prefixes).
CREATE POLICY "Users upload own images"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'wardrobe-images'
    AND auth.uid()::text IN (
      (storage.foldername(name))[1],
      (storage.foldername(name))[2]
    )
  );

CREATE POLICY "Users update own images"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'wardrobe-images'
    AND auth.uid()::text IN (
      (storage.foldername(name))[1],
      (storage.foldername(name))[2]
    )
  );

CREATE POLICY "Users delete own images"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'wardrobe-images'
    AND auth.uid()::text IN (
      (storage.foldername(name))[1],
      (storage.foldername(name))[2]
    )
  );

-- ============================================
-- Done! Your GRWM database is ready.
-- ============================================
