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

-- 5. Fit Checks
CREATE TABLE public.fit_checks (
  id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id               UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  outfit_id             UUID REFERENCES public.outfits(id) ON DELETE SET NULL,
  score                 INTEGER NOT NULL CHECK (score BETWEEN 1 AND 100),
  feedback              TEXT NOT NULL,
  color_harmony_score   INTEGER,
  style_cohesion_score  INTEGER,
  occasion_score        INTEGER,
  fit_score             INTEGER,
  improvement_tips      JSONB DEFAULT '[]'::jsonb,
  image_path            TEXT,
  created_at            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_fit_checks_user ON public.fit_checks(user_id);

-- 6. Outfit Logs (calendar)
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

-- 7. Daily Usage Tracking (for free tier limits)
CREATE TABLE public.daily_usage (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  usage_date  DATE NOT NULL DEFAULT CURRENT_DATE,
  outfit_generations INTEGER NOT NULL DEFAULT 0,
  fit_checks  INTEGER NOT NULL DEFAULT 0,
  UNIQUE(user_id, usage_date)
);

CREATE INDEX idx_daily_usage_user_date ON public.daily_usage(user_id, usage_date);

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

-- Fit Checks
ALTER TABLE public.fit_checks ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own fit checks" ON public.fit_checks
  FOR ALL USING (auth.uid() = user_id);

-- Outfit Logs
ALTER TABLE public.outfit_logs ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own outfit logs" ON public.outfit_logs
  FOR ALL USING (auth.uid() = user_id);

-- Daily Usage
ALTER TABLE public.daily_usage ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users manage own usage" ON public.daily_usage
  FOR ALL USING (auth.uid() = user_id);

-- ============================================
-- Storage Bucket for wardrobe images
-- NOTE: Create this manually in Supabase Dashboard:
--   Storage → New Bucket → Name: "wardrobe-images" → Public: OFF
-- Then add this policy via SQL:
-- ============================================

-- Allow users to manage their own folder in the bucket
INSERT INTO storage.buckets (id, name, public)
VALUES ('wardrobe-images', 'wardrobe-images', false)
ON CONFLICT (id) DO NOTHING;

CREATE POLICY "Users can upload own images"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'wardrobe-images'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can view own images"
  ON storage.objects FOR SELECT
  USING (
    bucket_id = 'wardrobe-images'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

CREATE POLICY "Users can delete own images"
  ON storage.objects FOR DELETE
  USING (
    bucket_id = 'wardrobe-images'
    AND auth.uid()::text = (storage.foldername(name))[1]
  );

-- ============================================
-- Done! Your GRWM database is ready.
-- ============================================
