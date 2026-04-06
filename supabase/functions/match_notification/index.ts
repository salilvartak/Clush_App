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
      console.log("Invalid payload received:", payload)
      return new Response("Invalid payload", { status: 400 })
    }

    // 3. Use standard Supabase variables
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseKey)

    // 4. Fetch profiles (to get names and FCM tokens)
    const { data: users, error } = await supabase
      .from('profiles')
      .select('id, full_name, fcm_token')
      .in('id', [record.user_a, record.user_b])

    if (error) {
      console.error("Database query error:", error)
      throw error
    }
    
    if (!users || users.length < 2) {
      console.warn("Could not find both user profiles for match:", {
        user_a: record.user_a,
        user_b: record.user_b,
        foundCnt: users?.length || 0
      })
    }

    const userA = users?.find((u: any) => u.id === record.user_a)
    const userB = users?.find((u: any) => u.id === record.user_b)

    // 5. Send Notification to User A
    if (userA?.fcm_token) {
      try {
        await admin.messaging().send({
          token: userA.fcm_token,
          notification: {
            title: "It's a Match! 🎉",
            body: `You and ${userB?.full_name || 'someone'} liked each other!`
          },
          data: { type: 'new_match', matchId: userB?.id || '' }
        })
        console.log(`Notification sent to User A (${userA.id})`)
      } catch (err) {
        console.error(`Failed to send notification to User A (${userA.id}):`, err)
      }
    } else {
      console.log(`No FCM token for user A (${record.user_a})`)
    }

    // 6. Send Notification to User B
    if (userB?.fcm_token) {
      try {
        await admin.messaging().send({
          token: userB.fcm_token,
          notification: {
            title: "It's a Match! 🎉",
            body: `You and ${userA?.full_name || 'someone'} liked each other!`
          },
          data: { type: 'new_match', matchId: userA?.id || '' }
        })
        console.log(`Notification sent to User B (${userB.id})`)
      } catch (err) {
        console.error(`Failed to send notification to User B (${userB.id}):`, err)
      }
    } else {
      console.log(`No FCM token for user B (${record.user_b})`)
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (err: any) {
    console.error("Critical error in match_notification:", err)
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})