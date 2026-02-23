import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import admin from "npm:firebase-admin@11.11.0"

// 1. Initialize Firebase Admin
const serviceAccountStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')

if (serviceAccountStr && (!admin.apps || admin.apps.length === 0)) {
  try {
    const serviceAccount = JSON.parse(serviceAccountStr)
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    })
  } catch (error) {
    console.error("Failed to parse Firebase Service Account:", error)
  }
}

serve(async (req) => {
  try {
    // 2. Read Webhook Payload
    const payload = await req.json()
    const record = payload.record 

    if (!record || !record.user_a || !record.user_b) {
      return new Response("Invalid payload", { status: 400 })
    }

    // --- FIX: Hardcoded URL and Custom Secret Name ---
    const supabaseUrl = 'https://roblwklgvyvjrgvyumqp.supabase.co'
    const supabaseKey = Deno.env.get('MY_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseKey)
    // ------------------------------------------------

    // 4. Fetch profiles
    const { data: users, error } = await supabase
      .from('profiles')
      .select('id, full_name, fcm_token')
      .in('id', [record.user_a, record.user_b])

    if (error || !users) throw error

    const userA = users.find((u: any) => u.id === record.user_a)
    const userB = users.find((u: any) => u.id === record.user_b)

    // 5. Send Notification to User A
    if (userA?.fcm_token) {
      await admin.messaging().send({
        token: userA.fcm_token,
        notification: {
          title: "It's a Match! 🎉",
          body: `You and ${userB?.full_name || 'someone'} liked each other!`
        },
        data: { type: 'new_match', matchId: userB?.id || '' }
      })
    }

    // 6. Send Notification to User B
    if (userB?.fcm_token) {
      await admin.messaging().send({
        token: userB.fcm_token,
        notification: {
          title: "It's a Match! 🎉",
          body: `You and ${userA?.full_name || 'someone'} liked each other!`
        },
        data: { type: 'new_match', matchId: userA?.id || '' }
      })
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (err: any) {
    console.error("Error sending notification:", err)
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})