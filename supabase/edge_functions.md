# Supabase Edge Functions for Razorpay Integration

To securely integrate Razorpay payments without exposing your Razorpay Secret Key on the frontend, you should set up two Supabase Edge Functions.

Below is the code and deployment instructions for these two functions:
1. `create-razorpay-order`
2. `verify-razorpay-payment`

---

## 1. Prerequisites & Setup

1. **Install Supabase CLI** (if not already installed):
   ```bash
   npm install -g supabase
   ```
2. **Login to Supabase CLI**:
   ```bash
   supabase login
   ```
3. **Initialize Supabase in your project**:
   ```bash
   supabase init
   ```
4. **Set Razorpay Environment Secrets** in Supabase:
   ```bash
   supabase secrets set RAZORPAY_KEY_ID="your_key_id" RAZORPAY_KEY_SECRET="your_key_secret" --project-ref your-project-ref
   ```

---

## 2. Function 1: `create-razorpay-order`

Create a new function using the CLI:
```bash
supabase functions new create-razorpay-order
```

Replace the content of `supabase/functions/create-razorpay-order/index.ts` with the following:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { amount, currency = "INR", receipt } = await req.json()

    if (!amount || isNaN(amount)) {
      return new Response(JSON.stringify({ error: "Invalid amount" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    }

    const keyId = Deno.env.get("RAZORPAY_KEY_ID")
    const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET")

    if (!keyId || !keySecret) {
      return new Response(JSON.stringify({ error: "Razorpay credentials are not configured" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    }

    // Convert amount to paise (Razorpay expects smallest currency unit, i.e., 100 paise = 1 INR)
    const amountInPaise = Math.round(amount * 100)

    const basicAuth = btoa(`${keyId}:${keySecret}`)
    const response = await fetch("https://api.razorpay.com/v1/orders", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Basic ${basicAuth}`
      },
      body: JSON.stringify({
        amount: amountInPaise,
        currency,
        receipt: receipt || `receipt_${Date.now()}`
      })
    })

    const orderData = await response.json()

    if (!response.ok) {
      return new Response(JSON.stringify({ error: orderData.error || "Failed to create order" }), {
        status: response.status,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    }

    return new Response(JSON.stringify(orderData), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    })
  }
})
```

---

## 3. Function 2: `verify-razorpay-payment`

Create a new function using the CLI:
```bash
supabase functions new verify-razorpay-payment
```

Replace the content of `supabase/functions/verify-razorpay-payment/index.ts` with the following:

```typescript
import { serve } from "https://deno.land/std@0.168.0/http/server.ts"
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

// Simple HmacSHA256 signature verification in Deno (using Web Crypto API)
async function verifySignature(orderId: string, paymentId: string, signature: string, secret: string): Promise<boolean> {
  const text = `${orderId}|${paymentId}`
  const encoder = new TextEncoder()
  const keyData = encoder.encode(secret)
  const messageData = encoder.encode(text)

  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    keyData,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  )

  const signatureBuffer = await crypto.subtle.sign(
    "HMAC",
    cryptoKey,
    messageData
  )

  const signatureArray = Array.from(new Uint8Array(signatureBuffer))
  const calculatedSignature = signatureArray
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("")

  return calculatedSignature === signature;
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { 
      razorpay_order_id, 
      razorpay_payment_id, 
      razorpay_signature,
      donor_name,
      donor_email,
      donor_mobile,
      donor_pan,
      amount,
      user_id
    } = await req.json()

    const keySecret = Deno.env.get("RAZORPAY_KEY_SECRET")

    if (!keySecret) {
      return new Response(JSON.stringify({ error: "Razorpay secret key is not configured" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    }

    // Verify signature
    const isValid = await verifySignature(
      razorpay_order_id,
      razorpay_payment_id,
      razorpay_signature,
      keySecret
    )

    if (!isValid) {
      return new Response(JSON.stringify({ error: "Invalid payment signature" }), {
        status: 400,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    }

    // Insert record in Supabase Database
    const supabaseUrl = Deno.env.get("SUPABASE_URL") || ""
    const supabaseServiceRole = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || ""
    
    const supabase = createClient(supabaseUrl, supabaseServiceRole)

    const { error: insertError } = await supabase
      .from('donations')
      .insert({
        user_id: user_id || null,
        donor_name,
        donor_email,
        donor_mobile,
        donor_pan: donor_pan || null,
        amount,
        payment_id: razorpay_payment_id,
        order_id: razorpay_order_id,
        status: 'success'
      })

    if (insertError) {
      console.error("Database insert error:", insertError)
      return new Response(JSON.stringify({ error: "Payment verified but database insert failed" }), {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" }
      })
    }

    return new Response(JSON.stringify({ success: true, message: "Payment verified and recorded successfully" }), {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    })

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" }
    })
  }
})
```

---

## 4. Deploying Functions

Deploy the functions to your Supabase project:
```bash
supabase functions deploy create-razorpay-order --project-ref your-project-ref
supabase functions deploy verify-razorpay-payment --project-ref your-project-ref
```
Once deployed, the endpoints will be available at:
`https://your-project-ref.supabase.co/functions/v1/create-razorpay-order`
`https://your-project-ref.supabase.co/functions/v1/verify-razorpay-payment`
