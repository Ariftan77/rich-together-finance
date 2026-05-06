// =============================================================================
// Supabase Edge Function: validate-purchase
// =============================================================================
// Validates App Store (iOS) and Google Play (Android) purchase receipts
// server-side, records the purchase, and updates the user's premium status.
//
// Deploy: supabase functions deploy validate-purchase
//
// Required environment variables (set via Supabase dashboard > Edge Functions > Secrets):
//   APPLE_SIGNING_KEY    — Private key (.p8 content) from App Store Connect
//   APPLE_KEY_ID         — Key ID from App Store Connect (10-char string)
//   APPLE_ISSUER_ID      — Issuer ID from App Store Connect (UUID)
//   APPLE_BUNDLE_ID      — iOS bundle ID: com.axiomtech.richtogether
//   GOOGLE_PLAY_KEY      — JSON service account key from Google Play Console
//   SUPABASE_SERVICE_ROLE_KEY — Injected automatically by Supabase runtime
//   SUPABASE_URL          — Injected automatically by Supabase runtime
// =============================================================================

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { create, getNumericDate } from 'https://deno.land/x/djwt@v3.0.2/mod.ts';

// ---------------------------------------------------------------------------
// Types
// ---------------------------------------------------------------------------

interface RequestBody {
  platform: 'ios' | 'android';
  user_id?: string | null;
  temporary_user_id?: string | null;
  product_id: string;
  is_restore: boolean;

  // iOS only — StoreKit 2 sends transactionId; legacy fallback sends receipt blob
  transaction_id?: string;
  receipt?: string;         // legacy fallback only — prefer transaction_id

  // Android only
  purchase_token?: string;
  original_json?: string;
  signature?: string;
  package_name?: string;
}

interface ValidationResponse {
  success: boolean;
  premium_type: string | null;
  expires_at: string | null;
  error: string | null;
}

// Apple JWS transaction structure (flattened from decoded payload)
interface AppleTransactionPayload {
  originalTransactionId: string;
  bundleId: string;
  productId: string;
  purchaseDate: number;        // epoch ms
  expiresDate?: number;        // epoch ms, only for subscriptions
  transactionReason?: string;
  revocationDate?: number;
}

interface AppleVerificationResult {
  originalTransactionId: string;
  productId: string;
  purchaseDate: Date;
  expiresDate: Date | null;
  isRevoked: boolean;
}

interface GoogleProductPurchase {
  purchaseState: number;       // 0=purchased, 1=canceled, 2=pending
  purchaseTimeMillis: string;
  acknowledgementState: number; // 0=unacknowledged, 1=acknowledged
  orderId: string;
}

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------

const VALID_PRODUCT_IDS = new Set([
  'expense_tracker_premium',
  'expense_tracker_sync_yearly',
]);

const PRODUCT_PREMIUM_TYPE: Record<string, string> = {
  expense_tracker_premium: 'lifetime',
  expense_tracker_sync_yearly: 'sync_yearly',
};

const APPLE_PRODUCTION_URL =
  'https://api.storekit.itunes.apple.com/inApps/v1/lookup';
const APPLE_SANDBOX_URL =
  'https://api.storekit-sandbox.itunes.apple.com/inApps/v1/lookup';

const GOOGLE_PLAY_BASE =
  'https://androidpublisher.googleapis.com/androidpublisher/v3/applications';

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

Deno.serve(async (req: Request) => {
  // Only POST is accepted
  if (req.method !== 'POST') {
    return errorResponse(405, 'method_not_allowed', 'Method not allowed');
  }

  // CORS preflight (if needed for debugging via browser)
  if (req.method === 'OPTIONS') {
    return new Response(null, {
      headers: {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'content-type, authorization',
        'Access-Control-Allow-Methods': 'POST, OPTIONS',
      },
    });
  }

  let body: RequestBody;
  try {
    body = await req.json();
  } catch {
    return errorResponse(400, 'invalid_json', 'Request body must be valid JSON');
  }

  // ---------------------------------------------------------------------------
  // Input validation
  // ---------------------------------------------------------------------------

  if (!body.platform || !['ios', 'android'].includes(body.platform)) {
    return errorResponse(400, 'invalid_platform', 'platform must be "ios" or "android"');
  }

  if (!body.product_id || !VALID_PRODUCT_IDS.has(body.product_id)) {
    return errorResponse(400, 'invalid_product', 'Unknown product_id');
  }

  // At least one of user_id or temporary_user_id must be present for attribution
  if (!body.user_id && !body.temporary_user_id) {
    return errorResponse(
      400,
      'missing_user_identifier',
      'Provide either user_id or temporary_user_id',
    );
  }

  // ---------------------------------------------------------------------------
  // Environment variable guard
  // ---------------------------------------------------------------------------

  const supabaseUrl = Deno.env.get('SUPABASE_URL');
  const serviceRoleKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (!supabaseUrl || !serviceRoleKey) {
    console.error('[validate-purchase] Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY');
    return errorResponse(500, 'server_misconfiguration', 'Server configuration error');
  }

  // Service-role client bypasses RLS — only used inside this function
  const db = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  // ---------------------------------------------------------------------------
  // Dispatch to platform handler
  // ---------------------------------------------------------------------------

  try {
    if (body.platform === 'ios') {
      return await handleIos(body, db);
    } else {
      return await handleAndroid(body, db);
    }
  } catch (err) {
    console.error('[validate-purchase] Unhandled error:', err);
    return errorResponse(500, 'internal_error', 'An unexpected error occurred');
  }
});

// =============================================================================
// iOS handler
// =============================================================================

async function handleIos(
  body: RequestBody,
  db: ReturnType<typeof createClient>,
): Promise<Response> {
  const requiredEnv = ['APPLE_SIGNING_KEY', 'APPLE_KEY_ID', 'APPLE_ISSUER_ID', 'APPLE_BUNDLE_ID'];
  for (const key of requiredEnv) {
    if (!Deno.env.get(key)) {
      console.error(`[validate-purchase] Missing env var: ${key}`);
      return errorResponse(500, 'server_misconfiguration', 'Server configuration error');
    }
  }

  // Accept either transaction_id (StoreKit 2 preferred) or legacy receipt blob.
  // At least one must be present.
  if (!body.transaction_id && !body.receipt) {
    return errorResponse(
      400,
      'missing_ios_identifier',
      'transaction_id (or legacy receipt) is required for iOS',
    );
  }

  // ---------------------------------------------------------------------------
  // 1. Validate with Apple — prefer transactionId, fall back to receipt blob
  // ---------------------------------------------------------------------------

  let appleResult: AppleVerificationResult;
  try {
    if (body.transaction_id) {
      // StoreKit 2 path: clean numeric transaction ID — no encoding needed
      appleResult = await verifyAppleTransaction(body.transaction_id, body.product_id);
    } else {
      // Legacy path: base64 receipt blob (kept for backwards compatibility)
      appleResult = await verifyAppleReceipt(body.receipt!, body.product_id);
    }
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error('[validate-purchase] Apple verification failed:', msg);

    if (msg === 'invalid_receipt') {
      return errorResponse(400, 'invalid_receipt', 'Apple rejected this receipt');
    }
    // Network or upstream error
    return errorResponse(502, 'upstream_error', 'Could not reach Apple validation servers');
  }

  // ---------------------------------------------------------------------------
  // 2. Fraud check — same original_transaction_id must map to same user
  // ---------------------------------------------------------------------------

  const { data: existingReceipt, error: receiptFetchErr } = await db
    .from('app_store_receipts')
    .select('id, user_id, temporary_user_id')
    .eq('original_transaction_id', appleResult.originalTransactionId)
    .maybeSingle();

  if (receiptFetchErr) {
    console.error('[validate-purchase] DB error fetching receipt:', receiptFetchErr);
    return errorResponse(500, 'db_error', 'Database error');
  }

  if (existingReceipt) {
    const isSameUser =
      (body.user_id && existingReceipt.user_id === (await resolveUserUuid(body.user_id, db))) ||
      (!body.user_id &&
        body.temporary_user_id &&
        existingReceipt.temporary_user_id === body.temporary_user_id);

    if (!isSameUser) {
      // Receipt already claimed by a different user — reject
      console.warn(
        '[validate-purchase] Receipt fraud attempt: original_transaction_id',
        appleResult.originalTransactionId,
        'claimed by different user',
      );
      return errorResponse(
        409,
        'already_owned_by_other_user',
        'This purchase is associated with a different account',
      );
    }

    // Same user — idempotent success
    const premiumType = PRODUCT_PREMIUM_TYPE[appleResult.productId] ?? 'lifetime';
    return successResponse(
      premiumType,
      appleResult.expiresDate ? appleResult.expiresDate.toISOString() : null,
    );
  }

  // ---------------------------------------------------------------------------
  // 3. New receipt — resolve or create the user record
  // ---------------------------------------------------------------------------

  const premiumType = PRODUCT_PREMIUM_TYPE[body.product_id] ?? 'lifetime';
  const expiresAt = appleResult.expiresDate ? appleResult.expiresDate.toISOString() : null;

  let userUuid: string | null = null;
  if (body.user_id) {
    userUuid = await resolveUserUuid(body.user_id, db);
  }

  // ---------------------------------------------------------------------------
  // 4. Persist receipt record
  // ---------------------------------------------------------------------------

  const receiptRow = {
    user_id: userUuid,
    temporary_user_id: userUuid ? null : (body.temporary_user_id ?? null),
    original_transaction_id: appleResult.originalTransactionId,
    product_id: appleResult.productId,
    // Prefer storing the clean transactionId; fall back to legacy receipt blob.
    receipt: body.transaction_id ?? body.receipt ?? null,
    premium_type: premiumType,
    expires_at: expiresAt,
    purchase_date: appleResult.purchaseDate.toISOString(),
    status: appleResult.isRevoked ? 'revoked' : 'valid',
  };

  const { error: insertErr } = await db
    .from('app_store_receipts')
    .insert(receiptRow);

  if (insertErr) {
    // Race condition: another request inserted first (concurrent restore taps).
    // Treat as success if unique constraint; otherwise DB error.
    if (insertErr.code === '23505') {
      console.warn('[validate-purchase] Concurrent receipt insert race — treating as idempotent success');
    } else {
      console.error('[validate-purchase] Failed to insert receipt:', insertErr);
      return errorResponse(500, 'db_error', 'Failed to record purchase');
    }
  }

  // ---------------------------------------------------------------------------
  // 5. Update users table immediately so next session refresh sees premium
  // ---------------------------------------------------------------------------

  if (userUuid && !appleResult.isRevoked) {
    const { error: upsertErr } = await db
      .from('users')
      .update({
        premium_type: premiumType,
        expires_at: expiresAt,
      })
      .eq('id', userUuid);

    if (upsertErr) {
      // Non-fatal: the receipt is stored; the app can still use the returned values
      console.error('[validate-purchase] Failed to update user premium status:', upsertErr);
    }
  }

  console.log(
    `[validate-purchase] iOS success: product=${body.product_id}, premium=${premiumType}, user=${userUuid ?? body.temporary_user_id}`,
  );

  return successResponse(premiumType, expiresAt);
}

// =============================================================================
// Android handler
// =============================================================================

async function handleAndroid(
  body: RequestBody,
  db: ReturnType<typeof createClient>,
): Promise<Response> {
  if (!Deno.env.get('GOOGLE_PLAY_KEY')) {
    console.error('[validate-purchase] Missing GOOGLE_PLAY_KEY');
    return errorResponse(500, 'server_misconfiguration', 'Server configuration error');
  }

  if (!body.purchase_token) {
    return errorResponse(400, 'missing_purchase_token', 'purchase_token is required for Android');
  }

  const packageName = body.package_name ?? 'com.axiomtechdev.richtogether';

  // ---------------------------------------------------------------------------
  // 1. Validate purchase with Google Play Developer API
  // ---------------------------------------------------------------------------

  let googlePurchase: GoogleProductPurchase;
  try {
    googlePurchase = await verifyGooglePlayPurchase(
      packageName,
      body.product_id,
      body.purchase_token,
    );
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    console.error('[validate-purchase] Google Play verification failed:', msg);

    if (msg === 'invalid_token') {
      return errorResponse(400, 'invalid_receipt', 'Google Play rejected this purchase token');
    }
    return errorResponse(502, 'upstream_error', 'Could not reach Google Play API');
  }

  // Reject canceled or pending purchases — only state 0 (purchased) is valid
  if (googlePurchase.purchaseState === 1) {
    return errorResponse(400, 'purchase_cancelled', 'This purchase was cancelled');
  }
  if (googlePurchase.purchaseState === 2) {
    // Pending (e.g. cash payment awaiting clearance) — not yet consumable
    return errorResponse(400, 'purchase_pending', 'Purchase is pending external approval');
  }

  // ---------------------------------------------------------------------------
  // 2. Fraud check — same purchase_token must map to same user
  // ---------------------------------------------------------------------------

  const { data: existingPurchase, error: purchaseFetchErr } = await db
    .from('google_play_purchases')
    .select('id, user_id, temporary_user_id')
    .eq('purchase_token', body.purchase_token)
    .maybeSingle();

  if (purchaseFetchErr) {
    console.error('[validate-purchase] DB error fetching purchase:', purchaseFetchErr);
    return errorResponse(500, 'db_error', 'Database error');
  }

  if (existingPurchase) {
    const isSameUser =
      (body.user_id && existingPurchase.user_id === (await resolveUserUuid(body.user_id, db))) ||
      (!body.user_id &&
        body.temporary_user_id &&
        existingPurchase.temporary_user_id === body.temporary_user_id);

    if (!isSameUser) {
      console.warn(
        '[validate-purchase] Android fraud attempt: purchase_token',
        body.purchase_token.substring(0, 20),
        '... claimed by different user',
      );
      return errorResponse(
        409,
        'already_owned_by_other_user',
        'This purchase is associated with a different account',
      );
    }

    const premiumType = PRODUCT_PREMIUM_TYPE[existingPurchase.product_id ?? body.product_id] ?? 'lifetime';
    return successResponse(premiumType, null);
  }

  // ---------------------------------------------------------------------------
  // 3. New purchase — persist and activate
  // ---------------------------------------------------------------------------

  const premiumType = PRODUCT_PREMIUM_TYPE[body.product_id] ?? 'lifetime';
  const purchaseDateMs = parseInt(googlePurchase.purchaseTimeMillis, 10);

  // sync_yearly: compute expiry as 1 year from purchase date
  const expiresAt =
    premiumType === 'sync_yearly'
      ? new Date(purchaseDateMs + 365 * 24 * 60 * 60 * 1000).toISOString()
      : null;

  let userUuid: string | null = null;
  if (body.user_id) {
    userUuid = await resolveUserUuid(body.user_id, db);
  }

  const ackState =
    googlePurchase.acknowledgementState === 1 ? 'acknowledged' : 'unacknowledged';

  const purchaseRow = {
    user_id: userUuid,
    temporary_user_id: userUuid ? null : (body.temporary_user_id ?? null),
    purchase_token: body.purchase_token,
    product_id: body.product_id,
    original_json: body.original_json ?? '',
    signature: body.signature ?? '',
    premium_type: premiumType,
    expires_at: expiresAt,
    purchase_date_ms: purchaseDateMs,
    status: 'purchased',
    acknowledgement_state: ackState,
  };

  const { error: insertErr } = await db
    .from('google_play_purchases')
    .insert(purchaseRow);

  if (insertErr) {
    if (insertErr.code === '23505') {
      console.warn('[validate-purchase] Concurrent Android purchase insert race — idempotent success');
    } else {
      console.error('[validate-purchase] Failed to insert Google purchase:', insertErr);
      return errorResponse(500, 'db_error', 'Failed to record purchase');
    }
  }

  if (userUuid) {
    const { error: upsertErr } = await db
      .from('users')
      .update({
        premium_type: premiumType,
        expires_at: expiresAt,
      })
      .eq('id', userUuid);

    if (upsertErr) {
      console.error('[validate-purchase] Failed to update user premium status:', upsertErr);
    }
  }

  console.log(
    `[validate-purchase] Android success: product=${body.product_id}, premium=${premiumType}, user=${userUuid ?? body.temporary_user_id}`,
  );

  return successResponse(premiumType, expiresAt);
}

// =============================================================================
// Apple receipt verification
// =============================================================================

/**
 * Verifies an App Store purchase using the StoreKit 2 transaction ID.
 *
 * The Flutter app sends a numeric transactionId string (e.g. "12345678901234").
 * This function hits the StoreKit 2 Server API lookup endpoint directly:
 *   GET https://api.storekit.itunes.apple.com/inApps/v1/lookup/{transactionId}
 *
 * Sandbox detection: the production endpoint returns HTTP 404 for sandbox
 * transactions. On a 404 we retry against the sandbox URL automatically.
 * No more body.status === 21007 inspection needed.
 *
 * @throws Error with message 'invalid_receipt' if Apple rejects the transaction
 * @throws Error for network/upstream failures (let caller map to 502)
 */
async function verifyAppleTransaction(
  transactionId: string,
  productId: string,
): Promise<AppleVerificationResult> {
  const signingKey = Deno.env.get('APPLE_SIGNING_KEY')!;
  const keyId = Deno.env.get('APPLE_KEY_ID')!;
  const issuerId = Deno.env.get('APPLE_ISSUER_ID')!;
  const bundleId = Deno.env.get('APPLE_BUNDLE_ID')!;

  const jwt = await buildAppleJwt(signingKey, keyId, issuerId, bundleId);

  // StoreKit 2 lookup URL — transactionId is a plain numeric string, no encoding needed
  const productionUrl = `${APPLE_PRODUCTION_URL}/${transactionId}`;
  console.log('[verify-apple-sk2] Trying production:', productionUrl);

  let response = await fetch(productionUrl, {
    method: 'GET',
    headers: { Authorization: `Bearer ${jwt}` },
  });

  console.log('[verify-apple-sk2] Production status:', response.status);

  // HTTP 404 on production = sandbox transaction — retry on sandbox URL
  if (response.status === 404) {
    const sandboxUrl = `${APPLE_SANDBOX_URL}/${transactionId}`;
    console.log('[verify-apple-sk2] Production returned 404, retrying sandbox:', sandboxUrl);
    response = await fetch(sandboxUrl, {
      method: 'GET',
      headers: { Authorization: `Bearer ${jwt}` },
    });
    console.log('[verify-apple-sk2] Sandbox status:', response.status);
  }

  if (!response.ok) {
    console.error('[verify-apple-sk2] HTTP error:', response.status, await response.text());
    throw new Error('upstream_error');
  }

  return parseAppleResponse(await response.json(), productId);
}

/**
 * Verifies an App Store receipt using the legacy base64 receipt blob path.
 *
 * Kept for backwards compatibility only. New builds use verifyAppleTransaction.
 * Sandbox detection: HTTP 404 on production → retry on sandbox.
 *
 * @throws Error with message 'invalid_receipt' if Apple rejects the receipt
 * @throws Error for network/upstream failures (let caller map to 502)
 */
async function verifyAppleReceipt(
  receipt: string,
  productId: string,
): Promise<AppleVerificationResult> {
  const signingKey = Deno.env.get('APPLE_SIGNING_KEY')!;
  const keyId = Deno.env.get('APPLE_KEY_ID')!;
  const issuerId = Deno.env.get('APPLE_ISSUER_ID')!;
  const bundleId = Deno.env.get('APPLE_BUNDLE_ID')!;

  const jwt = await buildAppleJwt(signingKey, keyId, issuerId, bundleId);

  const productionUrl = `${APPLE_PRODUCTION_URL}/${receipt}`;
  console.log('[verify-apple-legacy] Making request to production lookup');
  console.log('[verify-apple-legacy] JWT generated, kid=' + keyId);

  let response = await fetch(productionUrl, {
    method: 'GET',
    headers: {
      Authorization: `Bearer ${jwt}`,
      'Content-Type': 'application/json',
    },
  });

  console.log('[verify-apple-legacy] Production status:', response.status);

  // HTTP 404 on production = sandbox receipt — retry on sandbox URL.
  // (The old body.status === 21007 check was unreliable for the SK2 lookup API.)
  if (response.status === 404) {
    console.log('[verify-apple-legacy] Production returned 404, retrying sandbox');
    response = await fetch(`${APPLE_SANDBOX_URL}/${receipt}`, {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${jwt}`,
        'Content-Type': 'application/json',
      },
    });
    console.log('[verify-apple-legacy] Sandbox status:', response.status);
  }

  if (!response.ok) {
    console.error('[verify-apple-legacy] HTTP error:', response.status, await response.text());
    throw new Error('upstream_error');
  }

  return parseAppleResponse(await response.json(), productId);
}

/**
 * Shared response parser for both verifyAppleTransaction and verifyAppleReceipt.
 * Handles the signedTransactions (SK2) and latestReceiptInfo (legacy) shapes.
 */
async function parseAppleResponse(
  appleData: Record<string, unknown>,
  productId: string,
): Promise<AppleVerificationResult> {
  // status 0 = valid; non-zero indicates a problem with legacy API responses
  if (typeof appleData.status === 'number' && appleData.status !== 0) {
    console.warn('[verify-apple] Apple returned non-zero status:', appleData.status);
    throw new Error('invalid_receipt');
  }

  // Find the latest transaction for the requested product
  const transactions: AppleTransactionPayload[] =
    appleData.signedTransactions
      ? await Promise.all(
          (appleData.signedTransactions as string[]).map(decodeAppleJwsPayload),
        )
      : ((appleData.latestReceiptInfo as AppleTransactionPayload[]) ?? []);

  const matching = transactions
    .filter((t) => t.productId === productId)
    .sort((a, b) => b.purchaseDate - a.purchaseDate);

  if (matching.length === 0) {
    console.warn('[verify-apple] No transactions found for product:', productId);
    throw new Error('invalid_receipt');
  }

  const tx = matching[0];
  return {
    originalTransactionId: tx.originalTransactionId,
    productId: tx.productId,
    purchaseDate: new Date(tx.purchaseDate),
    expiresDate: tx.expiresDate ? new Date(tx.expiresDate) : null,
    isRevoked: tx.revocationDate != null,
  };
}

/**
 * Builds a signed JWT for authenticating with the Apple App Store Server API.
 * Uses ES256 with the .p8 private key from App Store Connect.
 */
async function buildAppleJwt(
  signingKey: string,
  keyId: string,
  issuerId: string,
  bundleId: string,
): Promise<string> {
  // signingKey is the raw content of the .p8 file from App Store Connect.
  // Strip PEM headers and decode to binary for WebCrypto.
  const pemBody = signingKey
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const keyBytes = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyBytes.buffer,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign'],
  );

  const now = Math.floor(Date.now() / 1000);
  return create(
    { alg: 'ES256', kid: keyId },
    {
      iss: issuerId,
      iat: now,
      exp: getNumericDate(60 * 20), // 20-minute TTL
      aud: 'appstoreconnect-v1',
      bid: bundleId,
    },
    cryptoKey,
  );
}

/**
 * Decodes the payload of a JWS-encoded Apple transaction without signature
 * verification (Apple's API already guarantees authenticity by serving them
 * only over authenticated HTTPS to our signed request).
 */
async function decodeAppleJwsPayload(jws: string): Promise<AppleTransactionPayload> {
  const [, payloadB64] = jws.split('.');
  const payloadJson = atob(payloadB64.replace(/-/g, '+').replace(/_/g, '/'));
  return JSON.parse(payloadJson) as AppleTransactionPayload;
}

// =============================================================================
// Google Play verification
// =============================================================================

/**
 * Validates a purchase token against the Google Play Developer API.
 *
 * Uses the service account JSON key (GOOGLE_PLAY_KEY) to obtain an
 * OAuth2 access token via the JWT grant flow, then calls the
 * purchases.products.get endpoint.
 *
 * @throws Error with message 'invalid_token' if Google rejects the token
 */
async function verifyGooglePlayPurchase(
  packageName: string,
  productId: string,
  purchaseToken: string,
): Promise<GoogleProductPurchase> {
  const serviceAccountJson = Deno.env.get('GOOGLE_PLAY_KEY')!;
  const serviceAccount = JSON.parse(serviceAccountJson);

  const accessToken = await getGoogleAccessToken(serviceAccount);

  const url = `${GOOGLE_PLAY_BASE}/${packageName}/purchases/products/${productId}/tokens/${purchaseToken}`;
  const response = await fetch(url, {
    headers: {
      Authorization: `Bearer ${accessToken}`,
      'Content-Type': 'application/json',
    },
  });

  if (response.status === 400 || response.status === 410) {
    // 400 = malformed token, 410 = token expired/voided
    throw new Error('invalid_token');
  }

  if (!response.ok) {
    const text = await response.text();
    console.error('[verify-google] Google Play API error:', response.status, text);
    throw new Error('upstream_error');
  }

  return response.json() as Promise<GoogleProductPurchase>;
}

/**
 * Obtains a short-lived OAuth2 access token using the Google service account
 * JWT grant flow (no external SDK required).
 *
 * Scope: https://www.googleapis.com/auth/androidpublisher
 */
async function getGoogleAccessToken(
  serviceAccount: Record<string, string>,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  // Import the RSA private key from the service account JSON
  const pemBody = serviceAccount.private_key
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const keyBytes = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyBytes.buffer,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );

  const jwtToken = await create(
    { alg: 'RS256', typ: 'JWT' },
    {
      iss: serviceAccount.client_email,
      scope: 'https://www.googleapis.com/auth/androidpublisher',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    },
    cryptoKey,
  );

  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwtToken,
    }),
  });

  if (!tokenResponse.ok) {
    const errText = await tokenResponse.text();
    console.error('[verify-google] Failed to obtain OAuth2 token:', errText);
    throw new Error('upstream_error');
  }

  const tokenData = await tokenResponse.json();
  return tokenData.access_token as string;
}

// =============================================================================
// User resolution
// =============================================================================

/**
 * Resolves a platform user ID (google_id or apple_id string from the Flutter app)
 * to the internal UUID used in receipt tables.
 *
 * The `user_id` field in the request body is the string identifier (google_id or
 * apple_id), NOT the UUID. This function looks up the UUID.
 *
 * Returns null if the user row cannot be found (defensive — does not block
 * receipt storage).
 */
async function resolveUserUuid(
  platformUserId: string,
  db: ReturnType<typeof createClient>,
): Promise<string | null> {
  // Try google_id first (most common for Android), then apple_id
  const { data: byGoogle } = await db
    .from('users')
    .select('id')
    .eq('google_id', platformUserId)
    .maybeSingle();

  if (byGoogle?.id) return byGoogle.id as string;

  const { data: byApple } = await db
    .from('users')
    .select('id')
    .eq('apple_id', platformUserId)
    .maybeSingle();

  if (byApple?.id) return byApple.id as string;

  console.warn('[validate-purchase] Could not resolve user UUID for platform ID:', platformUserId);
  return null;
}

// =============================================================================
// Response helpers
// =============================================================================

function successResponse(
  premiumType: string,
  expiresAt: string | null,
): Response {
  const body: ValidationResponse = {
    success: true,
    premium_type: premiumType,
    expires_at: expiresAt,
    error: null,
  };
  return new Response(JSON.stringify(body), {
    status: 200,
    headers: { 'Content-Type': 'application/json' },
  });
}

function errorResponse(
  status: number,
  errorCode: string,
  message: string,
): Response {
  const body: ValidationResponse = {
    success: false,
    premium_type: null,
    expires_at: null,
    error: errorCode,
  };
  console.warn(`[validate-purchase] Returning ${status} ${errorCode}: ${message}`);
  return new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json' },
  });
}
