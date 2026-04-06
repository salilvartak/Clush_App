import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { create } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const STREAM_API_KEY = "kqxgf6aywea2"; // Hardcoded as provided
const STREAM_SECRET = Deno.env.get("STREAM_SECRET")!;

serve(async (req) => {
  try {
    const { user_id, name, image } = await req.json();
    if (!user_id) return new Response("user_id required", { status: 400 });

    // 1. Create a Server-Side Admin Token
    const key = await crypto.subtle.importKey(
      "raw",
      new TextEncoder().encode(STREAM_SECRET),
      { name: "HMAC", hash: "SHA-256" },
      false,
      ["sign"],
    );
    const serverToken = await create(
      { alg: "HS256", typ: "JWT" },
      { server: true, iat: Math.floor(Date.now() / 1000) },
      key,
    );

    // 2. Call Stream REST API to upsert the user
    const streamRes = await fetch(
      `https://chat.stream-io-api.com/users?api_key=${STREAM_API_KEY}`,
      {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Stream-Auth-Type": "jwt",
          Authorization: serverToken,
        },
        body: JSON.stringify({
          users: {
            [user_id]: {
              id: user_id,
              name: name || user_id,
              image: image || "",
            },
          },
        }),
      }
    );

    const result = await streamRes.json();
    return new Response(JSON.stringify(result), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 500 });
  }
});
