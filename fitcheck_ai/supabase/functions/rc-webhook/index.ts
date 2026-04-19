// deno-lint-ignore-file no-explicit-any
//
// RevenueCat → Supabase sync. Point RC's webhook at:
//   https://<project>.functions.supabase.co/rc-webhook
//
// Authenticate the webhook with a shared secret configured in RC and stored
// here as RC_WEBHOOK_SECRET. RC sends it as the `Authorization: Bearer ...`
// header when you set the authorization header in its dashboard.
//
// Events we care about:
//   INITIAL_PURCHASE, RENEWAL, PRODUCT_CHANGE → is_pro=true
//   CANCELLATION, EXPIRATION, BILLING_ISSUE  → is_pro=false
//   NON_RENEWING_PURCHASE (weekly one-shot)   → is_pro=true until expiry
//
// The `app_user_id` in the payload is the Supabase auth.uid() we set via
// Purchases.logIn() in the client.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4'
import { serve } from 'https://deno.land/std@0.224.0/http/server.ts'

const PRO_EVENTS = new Set([
  'INITIAL_PURCHASE',
  'RENEWAL',
  'PRODUCT_CHANGE',
  'NON_RENEWING_PURCHASE',
  'UNCANCELLATION',
])

const BYE_EVENTS = new Set([
  'CANCELLATION',
  'EXPIRATION',
  'BILLING_ISSUE',
  'SUBSCRIPTION_PAUSED',
])

serve(async (req) => {
  if (req.method !== 'POST') {
    return new Response('method_not_allowed', { status: 405 })
  }

  const secret = Deno.env.get('RC_WEBHOOK_SECRET') ?? ''
  const auth = req.headers.get('authorization') ?? ''
  if (!secret || auth !== `Bearer ${secret}`) {
    return new Response('unauthorized', { status: 401 })
  }

  const supaUrl = Deno.env.get('SB_URL')
  const svcKey = Deno.env.get('SB_SERVICE_ROLE_KEY')
  if (!supaUrl || !svcKey) {
    return new Response('server_misconfigured', { status: 500 })
  }
  const supabase = createClient(supaUrl, svcKey, {
    auth: { persistSession: false },
  })

  let payload: any
  try {
    payload = await req.json()
  } catch (_) {
    return new Response('bad_json', { status: 400 })
  }

  const event = payload?.event
  const type = event?.type as string | undefined
  const appUserId = event?.app_user_id as string | undefined
  if (!type || !appUserId) {
    return new Response('missing_fields', { status: 400 })
  }

  let isPro: boolean | null = null
  if (PRO_EVENTS.has(type)) isPro = true
  else if (BYE_EVENTS.has(type)) isPro = false

  if (isPro === null) {
    // TRANSFER, TEST, etc. — record but don't change entitlement.
    return new Response('ignored', { status: 200 })
  }

  const expiresMs = event?.expiration_at_ms as number | undefined
  const purchasedMs = event?.purchased_at_ms as number | undefined

  const { error } = await supabase.from('subscribers').upsert({
    user_id: appUserId,
    rc_customer_id: event?.original_app_user_id ?? appUserId,
    is_pro: isPro,
    entitlement: event?.entitlement_id ?? null,
    product_id: event?.product_id ?? null,
    period_type: event?.period_type ?? null,
    purchased_at: purchasedMs ? new Date(purchasedMs).toISOString() : null,
    expires_at: expiresMs ? new Date(expiresMs).toISOString() : null,
    updated_at: new Date().toISOString(),
  })

  if (error) {
    console.error('upsert failed', error)
    return new Response('db_error', { status: 500 })
  }
  return new Response('ok', { status: 200 })
})
