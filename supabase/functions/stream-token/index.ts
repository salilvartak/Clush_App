// Supabase Edge Function: stream-token
// Deploy: supabase functions deploy stream-token
//
// Set secret in Supabase dashboard → Project Settings → Edge Functions:
//   STREAM_SECRET = <your Stream app secret>

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { create } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const STREAM_SECRET = Deno.env.get("STREAM_SECRET")!;

serve(async (req) => {
  try {
    const { user_id } = await req.json();
    if (!user_id) {
      return new Response(JSON.stringify({ error: "user_id required" }), { status: 400 });
    }

    const key = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(STREAM_SECRET),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"],
    );

    const now = Math.floor(Date.now() / 1000);
    const token = await create(
      { alg: "HS256", typ: "JWT" },
      { user_id, iat: now, exp: now + 86400 }, // 24 h expiry
      key,
    );

    return new Response(JSON.stringify({ token }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
