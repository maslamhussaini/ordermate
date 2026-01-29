import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import * as base64 from "https://deno.land/std@0.168.0/encoding/base64.ts";
import { writeAll } from "https://deno.land/std@0.168.0/streams/write_all.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.7.1";

const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req) => {
    if (req.method === 'OPTIONS') {
        return new Response('ok', { headers: corsHeaders });
    }

    try {
        const { email, full_name, role_id, organization_id, store_id, smtp_settings, email_subject, email_html, generate_link, redirect_to } = await req.json();

        if (!email || !smtp_settings?.username || !smtp_settings?.password) {
            throw new Error("Missing email or SMTP credentials");
        }

        const { username, password } = smtp_settings;

        let finalHtml = email_html;

        let authUserId = null;

        // Generate Magic Link if requested
        if (generate_link) {
            try {
                // ... (existing code)
                const { data: userData, error: createError } = await supabaseAdmin.auth.admin.createUser({
                    // ...
                });

                if (userData?.user) {
                    authUserId = userData.user.id;
                } else if (createError && createError.message.includes('already registered')) {
                    // Try to fetch existing user if needed, or assume repository handles it
                    // Ideally we fetch the user to get the ID
                    const { data: existingUser } = await supabaseAdmin.auth.admin.getUserByEmail(email);
                    if (existingUser?.user) authUserId = existingUser.user.id;
                }

                // ... (rest of link generation)
            } catch (linkError) {
                // ...
            }
        }

        // ... (SMTP Code) ...

        return new Response(
            JSON.stringify({ message: 'Email sent successfully', user_id: authUserId }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        );

    } catch (error) {
        console.error("Error:", error);
        return new Response(
            JSON.stringify({ error: `Email Failed: ${error.message}` }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
        );
    }
});
