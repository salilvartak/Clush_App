// Supabase Edge Function: verify-purchase
// Deploy: supabase functions deploy verify-purchase
//
// Validates an in-app subscription receipt server-side before granting
// "Clush+" premium — the client never writes is_premium/premium_expiry
// directly, so a modified app can't fabricate a purchase and grant itself
// premium for free.
//
// Set secrets in Supabase dashboard → Project Settings → Edge Functions:
//   GOOGLE_SERVICE_ACCOUNT   = <Play Console service-account JSON, single line>
//   APPLE_SHARED_SECRET      = <App-Specific Shared Secret from App Store Connect> (iOS only)
//   SUPABASE_URL             = (already set for other functions)
//   SUPABASE_SERVICE_ROLE_KEY = (already set for other functions)

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const ANDROID_PACKAGE_NAME = "com.clush.app";

// Product ID → entitlement duration. Mirrors PurchaseIds in
// lib/services/purchase_service.dart.
const PRODUCT_DURATIONS: Record<string, number> = {
  clush_plus_1month: 30,
  clush_plus_3months: 90,
  clush_plus_6months: 180,
  clush_plus_12months: 365,
};

function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    headers: { "Content-Type": "application/json" },
    status,
  });
}

// ─── Google Play receipt verification ───────────────────────────────────────

function base64url(input: ArrayBuffer | string): string {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : new Uint8Array(input);
  let str = "";
  for (const b of bytes) str += String.fromCharCode(b);
  return btoa(str).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

/// Exchanges the Google service-account credentials for a short-lived OAuth2
/// access token via a self-signed JWT (RFC 7523), the same flow
/// `google-auth-library` performs under the hood.
async function getGoogleAccessToken(serviceAccount: { client_email: string; private_key: string }): Promise<string> {
  const header = { alg: "RS256", typ: "JWT" };
  const now = Math.floor(Date.now() / 1000);
  const claims = {
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/androidpublisher",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  };

  const unsigned = `${base64url(JSON.stringify(header))}.${base64url(JSON.stringify(claims))}`;

  const pemBody = serviceAccount.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");
  const keyBytes = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const key = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign("RSASSA-PKCS1-v1_5", key, new TextEncoder().encode(unsigned));
  const jwt = `${unsigned}.${base64url(signature)}`;

  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion: jwt,
    }),
  });
  const tokenJson = await tokenRes.json();
  if (!tokenRes.ok || !tokenJson.access_token) {
    throw new Error(`Google token exchange failed: ${JSON.stringify(tokenJson)}`);
  }
  return tokenJson.access_token as string;
}

/// Calls the Play Developer API to confirm the subscription purchase is real,
/// active, and was paid for the given product. Returns the verified expiry.
async function verifyGooglePurchase(productId: string, purchaseToken: string): Promise<{ expiry: Date }> {
  const serviceAccountStr = Deno.env.get("GOOGLE_SERVICE_ACCOUNT");
  if (!serviceAccountStr) throw new Error("GOOGLE_SERVICE_ACCOUNT secret not configured");
  const serviceAccount = JSON.parse(serviceAccountStr);

  const accessToken = await getGoogleAccessToken(serviceAccount);

  const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/` +
    `${ANDROID_PACKAGE_NAME}/purchases/subscriptions/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}`;

  const res = await fetch(url, { headers: { Authorization: `Bearer ${accessToken}` } });
  const body = await res.json();
  if (!res.ok) throw new Error(`Play Developer API error: ${JSON.stringify(body)}`);

  // paymentState: 1 = received, 2 = free trial, 0 = pending
  const paymentState = body.paymentState;
  if (paymentState !== 1 && paymentState !== 2) {
    throw new Error(`Subscription not paid (paymentState=${paymentState})`);
  }

  const expiryMs = Number(body.expiryTimeMillis);
  if (!expiryMs || expiryMs <= Date.now()) {
    throw new Error("Subscription is expired");
  }

  return { expiry: new Date(expiryMs) };
}

// ─── Apple App Store receipt verification ───────────────────────────────────

/// Validates against Apple's `verifyReceipt` endpoint (production, falling
/// back to sandbox per Apple's documented status-21007 flow).
async function verifyApplePurchase(productId: string, receiptData: string): Promise<{ expiry: Date }> {
  const sharedSecret = Deno.env.get("APPLE_SHARED_SECRET");
  if (!sharedSecret) throw new Error("APPLE_SHARED_SECRET secret not configured");

  const verify = async (endpoint: string) => {
    const res = await fetch(endpoint, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ "receipt-data": receiptData, password: sharedSecret, "exclude-old-transactions": true }),
    });
    return res.json();
  };

  let body = await verify("https://buy.itunes.apple.com/verifyReceipt");
  // 21007 = receipt is from the sandbox but was sent to the production endpoint
  if (body.status === 21007) {
    body = await verify("https://sandbox.itunes.apple.com/verifyReceipt");
  }
  if (body.status !== 0) {
    throw new Error(`Apple verifyReceipt failed (status=${body.status})`);
  }

  const latest: Array<{ product_id: string; expires_date_ms: string }> = body.latest_receipt_info ?? [];
  const matching = latest
    .filter((tx) => tx.product_id === productId)
    .sort((a, b) => Number(b.expires_date_ms) - Number(a.expires_date_ms))[0];
  if (!matching) throw new Error("No matching subscription transaction in receipt");

  const expiryMs = Number(matching.expires_date_ms);
  if (!expiryMs || expiryMs <= Date.now()) {
    throw new Error("Subscription is expired");
  }

  return { expiry: new Date(expiryMs) };
}

// ─── Handler ─────────────────────────────────────────────────────────────────

serve(async (req) => {
  try {
    const { user_id, product_id, purchase_token, platform } = await req.json();

    if (!user_id || !product_id || !purchase_token || !platform) {
      return jsonResponse({ success: false, error: "user_id, product_id, purchase_token and platform are required" }, 400);
    }
    if (!PRODUCT_DURATIONS[product_id]) {
      return jsonResponse({ success: false, error: `Unknown product_id: ${product_id}` }, 400);
    }

    let verified: { expiry: Date };
    if (platform === "android") {
      verified = await verifyGooglePurchase(product_id, purchase_token);
    } else if (platform === "ios") {
      verified = await verifyApplePurchase(product_id, purchase_token);
    } else {
      return jsonResponse({ success: false, error: `Unsupported platform: ${platform}` }, 400);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    const supabase = createClient(supabaseUrl, supabaseKey);

    const { error } = await supabase
      .from("profiles")
      .update({
        // profiles.is_premium is TEXT ('true'/'false'), not boolean — the
        // matchmaking RPCs compare it with `is_premium = 'true'`.
        is_premium: "true",
        premium_expiry: verified.expiry.toISOString(),
        purchase_token,
      })
      .eq("id", user_id);

    if (error) {
      console.error("Failed to write premium entitlement:", error);
      return jsonResponse({ success: false, error: "Failed to update profile" }, 500);
    }

    return jsonResponse({ success: true, expiry: verified.expiry.toISOString() });
  } catch (err) {
    console.error("Purchase verification error:", err);
    return jsonResponse({ success: false, error: String(err) }, 400);
  }
});
