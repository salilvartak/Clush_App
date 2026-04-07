import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import admin from "npm:firebase-admin@11.11.0"

// --- 1. Initialize Firebase Admin ---
const serviceAccountStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')

if (serviceAccountStr && (!admin.apps || admin.apps.length === 0)) {
  try {
    const serviceAccount = JSON.parse(serviceAccountStr)
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount)
    })
  } catch (error) {
    console.error("❌ Failed to parse Firebase Service Account:", error)
  }
}

/**
 * PUSH-ENGINE (Unified Notification Service)
 * Accepts:
 * {
 *   "targetId": "uuid", (Optional)
 *   "targetIds": ["uuid", "uuid"], (Optional - for multiple targets)
 *   "title": "Title",
 *   "body": "Body text",
 *   "data": { "type": "new_match", ... },
 *   "all": false (Boolean - for promotional broadcast)
 * }
 */
serve(async (req) => {
  try {
    // 1. Basic Setup
    const supabaseUrl = Deno.env.get('SUPABASE_URL') || ''
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || ''
    const supabase = createClient(supabaseUrl, supabaseKey)

    // 2. Parse Request
    const { targetId, targetIds, title, body, data, all } = await req.json()

    if (!title || !body) {
      return new Response("Missing title or body", { status: 400 })
    }

    // 3. Resolve Target Tokens
    let tokens: string[] = []

    if (all === true) {
      // Promotional Broadcast: Fetch ALL users with tokens
      const { data: users, error } = await supabase
        .from('profiles')
        .select('fcm_token')
        .not('fcm_token', 'is', null)

      if (!error && users) tokens = users.map(u => u.fcm_token)
    } 
    else if (targetIds && Array.isArray(targetIds)) {
      // Multiple Targets
      const { data: users, error } = await supabase
        .from('profiles')
        .select('fcm_token')
        .in('id', targetIds)
        .not('fcm_token', 'is', null)
      
      if (!error && users) tokens = users.map(u => u.fcm_token)
    }
    else if (targetId) {
      // Single Target
      const { data: user, error } = await supabase
        .from('profiles')
        .select('fcm_token')
        .eq('id', targetId)
        .maybeSingle()

      if (!error && user?.fcm_token) tokens = [user.fcm_token]
    }

    if (tokens.length === 0) {
      console.log("No valid FCM tokens found for targets.")
      return new Response(JSON.stringify({ success: true, message: "No tokens found" }), { status: 200 })
    }

    // 4. Send Notifications
    console.log(`🚀 Sending notification to ${tokens.length} tokens...`)
    
    const results = await Promise.allSettled(
      tokens.map(token => 
        admin.messaging().send({
          token,
          notification: { title, body },
          data: data || {},
          android: { notification: { sound: 'default' } },
          apns: { payload: { aps: { sound: 'default' } } }
        })
      )
    )

    const sentCnt = results.filter(r => r.status === 'fulfilled').length
    const failCnt = results.length - sentCnt

    console.log(`✅ Sent: ${sentCnt}, ❌ Failed: ${failCnt}`)

    return new Response(JSON.stringify({ success: true, sent: sentCnt, failed: failCnt }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (err: any) {
    console.error("🚨 Critical error in push-engine:", err)
    return new Response(JSON.stringify({ error: err.message }), { status: 500 })
  }
})
