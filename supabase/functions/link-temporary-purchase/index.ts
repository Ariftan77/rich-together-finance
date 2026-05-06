// =============================================================================
// Supabase Edge Function: link-temporary-purchase
// =============================================================================
// Called when an unsigned user (who bought premium without signing in) later
// signs in to Google or Apple. Finds all receipt/purchase rows associated with
// their temporary_user_id and links them to their real user account UUID.
//
// Also updates the user's premium_type/expires_at if no active premium exists.
//
// Deploy: supabase functions deploy link-temporary-purchase
//
// Required secrets (same as validate-purchase):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY (auto-injected by runtime)
// =============================================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

interface RequestBody {
  // The platform ID (google_id or apple_id) sent by the Flutter app after sign-in
  user_id: string;
  temporary_user_id: string;
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return respond(405, { success: false, error: 'method_not_allowed' });
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return respond(400, { success: false, error: 'invalid_json' });
  }

  if (!body.user_id || !body.temporary_user_id) {
    return respond(400, { success: false, error: 'user_id and temporary_user_id are required' });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !serviceRoleKey) {
    return respond(500, { success: false, error: 'server_misconfiguration' });
  }

  const db = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  try {
    // ---------------------------------------------------------------------------
    // 1. Resolve platform user_id → internal UUID
    // ---------------------------------------------------------------------------

    let userUuid: string | null = null;

    const { data: byGoogle } = await db
      .from('users')
      .select('id, premium_type, expires_at')
      .eq('google_id', body.user_id)
      .maybeSingle();

    if (byGoogle?.id) {
      userUuid = byGoogle.id as string;
    } else {
      const { data: byApple } = await db
        .from('users')
        .select('id, premium_type, expires_at')
        .eq('apple_id', body.user_id)
        .maybeSingle();

      if (byApple?.id) userUuid = byApple.id as string;
    }

    if (!userUuid) {
      console.warn('[link-temporary-purchase] User not found for platform ID:', body.user_id);
      return respond(404, { success: false, error: 'user_not_found' });
    }

    const currentUser = byGoogle ?? null;

    // ---------------------------------------------------------------------------
    // 2. Find unlinked iOS receipts for this temporary_user_id
    // ---------------------------------------------------------------------------

    const { data: iosReceipts, error: iosFetchErr } = await db
      .from('app_store_receipts')
      .select('id, premium_type, expires_at')
      .eq('temporary_user_id', body.temporary_user_id)
      .is('user_id', null);

    if (iosFetchErr) {
      console.error('[link-temporary-purchase] iOS fetch error:', iosFetchErr);
      return respond(500, { success: false, error: 'db_error' });
    }

    // ---------------------------------------------------------------------------
    // 3. Find unlinked Android purchases for this temporary_user_id
    // ---------------------------------------------------------------------------

    const { data: androidPurchases, error: androidFetchErr } = await db
      .from('google_play_purchases')
      .select('id, premium_type, expires_at')
      .eq('temporary_user_id', body.temporary_user_id)
      .is('user_id', null);

    if (androidFetchErr) {
      console.error('[link-temporary-purchase] Android fetch error:', androidFetchErr);
      return respond(500, { success: false, error: 'db_error' });
    }

    const iosCount = iosReceipts?.length ?? 0;
    const androidCount = androidPurchases?.length ?? 0;

    if (iosCount === 0 && androidCount === 0) {
      // Nothing to link — not an error, just a no-op
      return respond(200, { success: true, linked_count: 0 });
    }

    // ---------------------------------------------------------------------------
    // 4. Link iOS receipts
    // ---------------------------------------------------------------------------

    if (iosCount > 0) {
      const iosIds = iosReceipts!.map((r) => r.id as string);
      const { error: iosUpdateErr } = await db
        .from('app_store_receipts')
        .update({ user_id: userUuid, temporary_user_id: null })
        .in('id', iosIds);

      if (iosUpdateErr) {
        console.error('[link-temporary-purchase] iOS update error:', iosUpdateErr);
        // Continue — try Android
      }
    }

    // ---------------------------------------------------------------------------
    // 5. Link Android purchases
    // ---------------------------------------------------------------------------

    if (androidCount > 0) {
      const androidIds = androidPurchases!.map((p) => p.id as string);
      const { error: androidUpdateErr } = await db
        .from('google_play_purchases')
        .update({ user_id: userUuid, temporary_user_id: null })
        .in('id', androidIds);

      if (androidUpdateErr) {
        console.error('[link-temporary-purchase] Android update error:', androidUpdateErr);
      }
    }

    // ---------------------------------------------------------------------------
    // 6. Promote premium status on the user row if not already premium
    // ---------------------------------------------------------------------------

    const hasActivePremium =
      currentUser?.premium_type === 'lifetime' ||
      (currentUser?.premium_type === 'sync_yearly' &&
        currentUser?.expires_at &&
        new Date(currentUser.expires_at as string) > new Date());

    if (!hasActivePremium) {
      // Pick the best purchase across both platforms: prefer lifetime over sync_yearly
      const allPurchases = [
        ...(iosReceipts ?? []),
        ...(androidPurchases ?? []),
      ];

      const lifetime = allPurchases.find((p) => p.premium_type === 'lifetime');
      const bestPurchase = lifetime ?? allPurchases[0];

      if (bestPurchase) {
        const { error: promoteErr } = await db
          .from('users')
          .update({
            premium_type: bestPurchase.premium_type,
            expires_at: bestPurchase.expires_at ?? null,
          })
          .eq('id', userUuid);

        if (promoteErr) {
          console.error('[link-temporary-purchase] Premium promotion error:', promoteErr);
        }
      }
    }

    console.log(
      `[link-temporary-purchase] Linked ${iosCount} iOS + ${androidCount} Android purchases to user ${userUuid}`,
    );

    return respond(200, {
      success: true,
      linked_count: iosCount + androidCount,
    });
  } catch (err) {
    console.error('[link-temporary-purchase] Unhandled error:', err);
    return respond(500, { success: false, error: 'internal_error' });
  }
});

function respond(status: number, body: Record<string, unknown>): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
