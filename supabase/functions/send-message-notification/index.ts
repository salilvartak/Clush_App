// supabase/functions/send-message-notification/index.ts
//
// Triggered by a Supabase Database Webhook on messages INSERT.
// Looks up the recipient's FCM token and sends a Firebase push notification.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// ── Environment variables (set in Supabase Dashboard → Edge Functions → Secrets)
const FIREBASE_PROJECT_ID = Deno.env.get("FIREBASE_PROJECT_ID")!;
const FIREBASE_SERVICE_ACCOUNT = JSON.parse(Deno.env.get("FIREBASE_SERVICE_ACCOUNT")!);
const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// ── Generate a short-lived OAuth2 access token from the service account ──────
async function getAccessToken(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  const headerB64 = base64url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const payloadB64 = base64url(JSON.stringify({
    iss: FIREBASE_SERVICE_ACCOUNT.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));

  const signingInput = `${headerB64}.${payloadB64}`;

  // Import the RSA private key from the service account JSON
  const pemBody = FIREBASE_SERVICE_ACCOUNT.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/g, "")
    .replace(/-----END PRIVATE KEY-----/g, "")
    .replace(/\n/g, "");

  const keyBytes = Uint8Array.from(atob(pemBody), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyBytes,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signingInput),
  );

  const sigB64 = base64url(new Uint8Array(signature));
  const jwt = `${signingInput}.${sigB64}`;

  // Exchange the signed JWT for a Google OAuth2 access token
  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const data = await res.json();
  if (!data.access_token) throw new Error(`OAuth token error: ${JSON.stringify(data)}`);
  return data.access_token;
}

// ── Helper: URL-safe base64 (no padding) ─────────────────────────────────────
function base64url(input: string | Uint8Array): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : input;
  let binary = "";
  bytes.forEach((b) => (binary += String.fromCharCode(b)));
  return btoa(binary).replace(/=/g, "").replace(/\+/g, "-").replace(/\//g, "_");
}

// ── Main handler ──────────────────────────────────────────────────────────────
serve(async (req) => {
  try {
    const body = await req.json();

    // Supabase database webhooks put the new row under `record`
    const record = body.record ?? body;
    const senderId: string = record.sender;
    const roomId: string = record.room_id;

    if (!senderId || !roomId) {
      return new Response("Missing sender or room_id", { status: 400 });
    }

    // room_id format: "smallerUID_largerUID" (both are Firebase UIDs = 28 alphanum chars)
    // Firebase UIDs contain no underscores, so splitting by "_" is safe.
    const uids = roomId.split("_");
    const recipientId = uids.find((uid) => uid !== senderId);

    if (!recipientId) {
      return new Response("Could not determine recipient from room_id", { status: 400 });
    }

    // Use service-role key so RLS doesn't block the lookup
    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);

    // Fetch sender name + recipient FCM token in one round trip
    const [senderRes, recipientRes] = await Promise.all([
      supabase.from("profiles").select("full_name").eq("id", senderId).maybeSingle(),
      supabase.from("profiles").select("fcm_token").eq("id", recipientId).maybeSingle(),
    ]);

    const senderName: string = senderRes.data?.full_name ?? "Someone";
    const fcmToken: string | null = recipientRes.data?.fcm_token ?? null;

    if (!fcmToken) {
      // Recipient has no token (app never granted notification permission) — not an error
      console.log(`No FCM token for recipient ${recipientId}, skipping push`);
      return new Response(JSON.stringify({ skipped: true }), { status: 200 });
    }

    const accessToken = await getAccessToken();

    const fcmRes = await fetch(
      `https://fcm.googleapis.com/v1/projects/${FIREBASE_PROJECT_ID}/messages:send`,
      {
        method: "POST",
        headers: {
          Authorization: `Bearer ${accessToken}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: fcmToken,
            notification: {
              title: senderName,
              body: "Sent you a message 💬",
            },
            // Pass metadata so the Flutter app can navigate to the right chat
            data: {
              type: "new_message",
              room_id: roomId,
              sender_id: senderId,
              sender_name: senderName,
            },
            android: {
              priority: "high",
              notification: {
                sound: "default",
                click_action: "FLUTTER_NOTIFICATION_CLICK",
                channel_id: "messages",
              },
            },
            apns: {
              headers: {
                "apns-priority": "10",
              },
              payload: {
                aps: {
                  sound: "default",
                  badge: 1,
                  "content-available": 1,
                },
              },
            },
          },
        }),
      },
    );

    const fcmResult = await fcmRes.json();

    if (!fcmRes.ok) {
      console.error("FCM send error:", JSON.stringify(fcmResult));
      // If the token is invalid/unregistered, clear it from the profile
      if (fcmResult.error?.code === 404 || fcmResult.error?.status === "NOT_FOUND") {
        await supabase.from("profiles").update({ fcm_token: null }).eq("id", recipientId);
        console.log("Cleared stale FCM token for", recipientId);
      }
      return new Response(JSON.stringify(fcmResult), { status: 500 });
    }

    return new Response(JSON.stringify({ success: true, fcm: fcmResult }), { status: 200 });
  } catch (err) {
    console.error("Edge function error:", err);
    return new Response(JSON.stringify({ error: String(err) }), { status: 500 });
  }
});
