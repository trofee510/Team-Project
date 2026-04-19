// deno-lint-ignore-file no-explicit-any
//
// GRWM ai-proxy — the ONLY path from client to any model provider.
// Authenticates via Supabase JWT, enforces daily usage, routes models
// by Pro status, and returns a structured FitCheckResult.
//
// Deploy:   supabase functions deploy ai-proxy --no-verify-jwt=false
// Env needed (supabase secrets set ...):
//   GEMINI_API_KEY, OPENAI_API_KEY, CLAUDE_API_KEY
//   SB_URL (Supabase project URL), SB_SERVICE_ROLE_KEY
//
// Rate limiting: every fit_check call goes through increment_fit_check_usage()
// which atomically checks the free-tier ceiling and bumps the counter.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4'
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'

// ── Config ──────────────────────────────────────────────────
const MODEL_FREE = 'gemini-2.5-flash'
const MODEL_PRO_FAST = 'gpt-4o-mini'
const MODEL_PRO_DEEP = 'claude-sonnet-4-20250514'

const PROMPT_TEMPLATE = `You are a professional fashion stylist scoring an outfit photo.

{{CONTEXT}}
SCORING RUBRIC (strict + consistent — same outfit must always score within 3 points):
- overall (1-100): holistic appeal **relative to the user's stated aesthetic**. Bias 55-85. 90+ for exceptional. 50 average. <40 requires a visible styling issue.
- color_harmony, style_cohesion, occasion_fit, versatility (1-100 each).

PERSONALIZATION:
- Score within the user's aesthetic lane (streetwear vs corporate vs old-money).
- If body type is given, comment on proportion/fit — never on the body itself.
- Tips must fit the aesthetic. No blazers for streetwear, no hoodies for corporate.

RULES:
- If not an outfit photo, set overall=0 and feedback="Not an outfit photo".
- Tips: exactly 3, specific + actionable.

Respond with ONLY valid JSON, no markdown:
{"score":<int>,"color_harmony":<int>,"style_cohesion":<int>,"occasion_fit":<int>,"versatility":<int>,"feedback":"<string>","tips":["<string>","<string>","<string>"]}
`

// ── Shared helpers ──────────────────────────────────────────
const json = (body: any, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { 'content-type': 'application/json' },
  })

const clamp = (v: any): number => {
  const n = Number(v) | 0
  return Math.max(0, Math.min(100, n))
}

function extractJson(text: string): any {
  const trimmed = text.trim()
  try {
    return JSON.parse(trimmed)
  } catch (_) { /* try harder */ }
  const match = trimmed.match(/\{[\s\S]*\}/)
  if (!match) throw new Error('no JSON in model response')
  return JSON.parse(match[0])
}

// ── Provider adapters ───────────────────────────────────────
async function callGemini(model: string, prompt: string, imageB64: string) {
  const key = Deno.env.get('GEMINI_API_KEY')
  if (!key) throw new Error('GEMINI_API_KEY not set')
  const res = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent?key=${key}`,
    {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({
        contents: [{
          parts: [
            { text: prompt },
            { inline_data: { mime_type: 'image/jpeg', data: imageB64 } },
          ],
        }],
        generationConfig: {
          temperature: 0.15, topP: 0.8, topK: 20,
          maxOutputTokens: 512,
          responseMimeType: 'application/json',
        },
      }),
    },
  )
  if (!res.ok) throw new Error(`gemini ${res.status}: ${await res.text()}`)
  const body = await res.json()
  const text = body?.candidates?.[0]?.content?.parts?.[0]?.text ?? ''
  return extractJson(text)
}

async function callOpenAI(model: string, prompt: string, imageB64: string) {
  const key = Deno.env.get('OPENAI_API_KEY')
  if (!key) throw new Error('OPENAI_API_KEY not set')
  const res = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      authorization: `Bearer ${key}`,
    },
    body: JSON.stringify({
      model,
      temperature: 0.15,
      response_format: { type: 'json_object' },
      messages: [{
        role: 'user',
        content: [
          { type: 'text', text: prompt },
          {
            type: 'image_url',
            image_url: { url: `data:image/jpeg;base64,${imageB64}` },
          },
        ],
      }],
      max_tokens: 512,
    }),
  })
  if (!res.ok) throw new Error(`openai ${res.status}: ${await res.text()}`)
  const body = await res.json()
  return extractJson(body?.choices?.[0]?.message?.content ?? '')
}

async function callClaude(model: string, prompt: string, imageB64: string) {
  const key = Deno.env.get('CLAUDE_API_KEY')
  if (!key) throw new Error('CLAUDE_API_KEY not set')
  const res = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'content-type': 'application/json',
      'x-api-key': key,
      'anthropic-version': '2023-06-01',
    },
    body: JSON.stringify({
      model,
      max_tokens: 512,
      temperature: 0.15,
      messages: [{
        role: 'user',
        content: [
          { type: 'image', source: { type: 'base64', media_type: 'image/jpeg', data: imageB64 } },
          { type: 'text', text: prompt },
        ],
      }],
    }),
  })
  if (!res.ok) throw new Error(`claude ${res.status}: ${await res.text()}`)
  const body = await res.json()
  const text = body?.content?.[0]?.text ?? ''
  return extractJson(text)
}

// ── Routing ─────────────────────────────────────────────────
async function scoreWithFallback(
  tier: 'free' | 'pro',
  mode: 'fast' | 'deep',
  prompt: string,
  imageB64: string,
) {
  const attempts: Array<() => Promise<any>> = []
  if (tier === 'free') {
    attempts.push(() => callGemini(MODEL_FREE, prompt, imageB64))
    attempts.push(() => callOpenAI(MODEL_PRO_FAST, prompt, imageB64))
  } else {
    if (mode === 'deep') {
      attempts.push(() => callClaude(MODEL_PRO_DEEP, prompt, imageB64))
    }
    attempts.push(() => callOpenAI(MODEL_PRO_FAST, prompt, imageB64))
    attempts.push(() => callGemini(MODEL_FREE, prompt, imageB64))
  }
  let lastErr: any
  for (const attempt of attempts) {
    try {
      return await attempt()
    } catch (e) {
      lastErr = e
      console.error('provider failed, trying next:', e)
    }
  }
  throw lastErr ?? new Error('all providers failed')
}

// ── Main handler ────────────────────────────────────────────
serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      status: 204,
      headers: {
        'access-control-allow-origin': '*',
        'access-control-allow-headers': '*',
        'access-control-allow-methods': 'POST, OPTIONS',
      },
    })
  }
  if (req.method !== 'POST') return json({ error: 'method_not_allowed' }, 405)

  // 1. Authn via Supabase JWT.
  const auth = req.headers.get('authorization') ?? ''
  const jwt = auth.startsWith('Bearer ') ? auth.slice(7) : null
  if (!jwt) return json({ error: 'missing_jwt' }, 401)

  const supaUrl = Deno.env.get('SB_URL')
  const svcKey = Deno.env.get('SB_SERVICE_ROLE_KEY')
  if (!supaUrl || !svcKey) return json({ error: 'server_misconfigured' }, 500)

  const supabase = createClient(supaUrl, svcKey, {
    auth: { persistSession: false },
  })
  const { data: authData, error: authErr } = await supabase.auth.getUser(jwt)
  if (authErr || !authData.user) return json({ error: 'bad_jwt' }, 401)
  const userId = authData.user.id

  // 2. Parse request.
  let payload: any
  try {
    payload = await req.json()
  } catch (_) {
    return json({ error: 'bad_json' }, 400)
  }

  const task = payload.task as string | undefined
  const imageB64 = payload.image_base64 as string | undefined
  const context = payload.context as
    | { occasion?: string; aesthetic?: string; body_type?: string }
    | undefined
  const mode = (payload.mode ?? 'fast') as 'fast' | 'deep'

  if (task !== 'fit_check') return json({ error: 'unsupported_task' }, 400)
  if (!imageB64) return json({ error: 'missing_image' }, 400)

  // 3. Check Pro status.
  const { data: proRow } = await supabase
    .from('subscribers')
    .select('is_pro, expires_at')
    .eq('user_id', userId)
    .maybeSingle()
  const isPro = !!proRow?.is_pro &&
    (!proRow?.expires_at || new Date(proRow.expires_at) > new Date())
  const tier: 'free' | 'pro' = isPro ? 'pro' : 'free'

  // 4. Server-side rate limit (atomic). Pro bypasses.
  if (!isPro) {
    const { data: allowed, error: rpcErr } = await supabase.rpc(
      'increment_fit_check_usage',
      { p_user_id: userId },
    )
    if (rpcErr) {
      console.error('rate-limit rpc failed', rpcErr)
      return json({ error: 'rate_check_failed' }, 500)
    }
    if (allowed === false) {
      return json({ error: 'limit_reached', tier }, 402)
    }
  }

  // 5. Build prompt + call model.
  const ctxParts: string[] = []
  if (context?.occasion) ctxParts.push(`Occasion: ${context.occasion}`)
  if (context?.aesthetic) ctxParts.push(`Aesthetic: ${context.aesthetic}`)
  if (context?.body_type) ctxParts.push(`Body type: ${context.body_type}`)
  const ctx = ctxParts.length
    ? `USER CONTEXT: ${ctxParts.join(' • ')}\n`
    : ''
  const prompt = PROMPT_TEMPLATE.replace('{{CONTEXT}}', ctx)

  let parsed: any
  try {
    parsed = await scoreWithFallback(tier, mode, prompt, imageB64)
  } catch (e) {
    console.error('all providers failed', e)
    return json({ error: 'model_unavailable' }, 502)
  }

  const result = {
    score: clamp(parsed.score),
    color_harmony: clamp(parsed.color_harmony),
    style_cohesion: clamp(parsed.style_cohesion),
    occasion_fit: clamp(parsed.occasion_fit),
    versatility: clamp(parsed.versatility),
    feedback: String(parsed.feedback ?? '').trim(),
    tips: Array.isArray(parsed.tips)
      ? parsed.tips.map((t: any) => String(t)).filter((s: string) => s.trim().length)
      : [],
    tier,
  }

  return json(result)
})
