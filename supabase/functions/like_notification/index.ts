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

    // 3. ONLY proceed if the type is "like". If it's "dislike", stop here.
    if (!record || record.type !== 'like' || !record.user_id || !record.target_user_id) {
      return new Response("Not a like or invalid payload", { status: 200 })
    }

    // 4. Initialize Supabase client
    const supabaseUrl = 'https://roblwklgvyvjrgvyumqp.supabase.co'
    const supabaseKey = Deno.env.get('MY_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseKey)

    // 5. Fetch profiles for both users (to get the liker's name, and the target's token)
    const { data: users, error } = await supabase
      .from('profiles')
      .select('id, full_name, fcm_token')
      .in('id', [record.user_id, record.target_user_id])

    if (error || !users) throw error

    const liker = users.find((u: any) => u.id === record.user_id)
    const target = users.find((u: any) => u.id === record.target_user_id)

    // 6. Send Notification to the Target User
    if (target?.fcm_token) {
      // You can change 'Someone' to liker?.full_name if you want to reveal who liked them!
      // Dating apps usually hide the name until they match, so I used "Someone".
      await admin.messaging().send({
        token: target.fcm_token,
        notification: {
          title: "New Like! ❤️",
          body: `Someone just liked your profile! Open the app to see who.`
        },
        data: { type: 'new_like', likerId: liker?.id || '' }
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