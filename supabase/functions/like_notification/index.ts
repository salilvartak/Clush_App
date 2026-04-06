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

    // 3. ONLY proceed if the type is "like/super_like".
    if (!record || (record.type !== 'like' && record.type !== 'super_like') || !record.user_id || !record.target_user_id) {
      console.log("Skipping notification for non-like or invalid payload:", payload)
      return new Response("Not a like or invalid payload", { status: 200 })
    }

    // 4. Initialize Supabase client
    const supabaseUrl = Deno.env.get('SUPABASE_URL') ?? ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    const supabase = createClient(supabaseUrl, supabaseKey)

    // 5. Fetch profiles for both users (to get the liker's name, and the target's token)
    const { data: users, error } = await supabase
      .from('profiles')
      .select('id, full_name, fcm_token')
      .in('id', [record.user_id, record.target_user_id])

    if (error) {
      console.error("Database query error:", error)
      throw error
    }
    
    if (!users || users.length < 2) {
      console.warn("Could not find both user profiles for like notification:", {
        liker: record.user_id,
        target: record.target_user_id,
        foundCnt: users?.length || 0
      })
    }

    const liker = users?.find((u: any) => u.id === record.user_id)
    const target = users?.find((u: any) => u.id === record.target_user_id)

    // 6. Send Notification to the Target User
    if (target?.fcm_token) {
      try {
        const title = record.type === 'super_like' ? "Super Like! ⭐" : "New Like! ❤️"
        const body = record.type === 'super_like' 
          ? `Someone just gave you a Super Like! Open the app to see who.` 
          : `Someone just liked your profile! Open the app to see who.`
          
        await admin.messaging().send({
          token: target.fcm_token,
          notification: {
            title: title,
            body: body
          },
          data: { type: 'new_like', likerId: liker?.id || '' }
        })
        console.log(`Notification sent to target user (${target.id})`)
      } catch (err) {
        console.error(`Failed to send notification to target user (${target.id}):`, err)
      }
    } else {
      console.log(`No FCM token for target user (${record.target_user_id})`)
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (err: any) {
    console.error("Critical error in like_notification:", err)
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})