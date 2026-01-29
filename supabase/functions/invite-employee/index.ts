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

    // Logging container
    const logs: string[] = [];
    const log = (msg: string) => {
        console.log(msg);
        logs.push(msg);
    };

    try {
        const { email, full_name, role_id, organization_id, store_id, smtp_settings, email_subject, email_html, generate_link, redirect_to } = await req.json();

        // Validate Inputs
        if (!email || !smtp_settings?.username || !smtp_settings?.password) {
            throw new Error("Missing email or SMTP credentials");
        }

        const { username, password } = smtp_settings;
        let finalHtml = email_html;
        let authUserId = null;

        // Generate Magic Link if requested
        if (generate_link) {
            log("Generating Magic Link...");
            try {
                // Create a Supabase Client with Service Role Key to access Admin API
                const supabaseAdmin = createClient(
                    Deno.env.get('SUPABASE_URL') ?? '',
                    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
                );

                // 1. Ensure/Create User
                log(`Upserting Auth User for ${email}...`);
                const { data: userData, error: createError } = await supabaseAdmin.auth.admin.createUser({
                    email: email,
                    email_confirm: true,
                    user_metadata: { full_name: full_name }
                });

                if (userData?.user) {
                    authUserId = userData.user.id;
                    log(`User created/found: ${authUserId}`);
                } else if (createError && createError.message.includes('already registered')) {
                    log("User already registered. Fetching ID...");
                    const { data: existingUser } = await supabaseAdmin.auth.admin.getUserByEmail(email);
                    if (existingUser?.user) {
                        authUserId = existingUser.user.id;
                        log(`Found existing ID: ${authUserId}`);
                    }
                } else {
                    log(`User creation note: ${createError?.message}`);
                }

                // 2. Generate Link
                const redirectUrl = redirect_to ?? 'https://ordermate-app.com/login';

                const { data, error } = await supabaseAdmin.auth.admin.generateLink({
                    type: 'recovery',
                    email: email,
                    options: {
                        redirectTo: redirectUrl
                    }
                });

                if (error) {
                    log(`Link Gen Error: ${error.message}`);
                    // Fallback to simpler URL
                    finalHtml = finalHtml.replace('{{ACTION_URL}}', redirectUrl);
                } else {
                    const actionLink = data.properties?.action_link ?? redirectUrl;
                    log("Link generated successfully.");
                    finalHtml = finalHtml.replace('{{ACTION_URL}}', actionLink);
                }

            } catch (linkError) {
                log(`Link Logic Exception: ${linkError}`);
                finalHtml = finalHtml.replace('{{ACTION_URL}}', redirect_to ?? 'https://ordermate-app.com/login');
            }
        } else {
            finalHtml = finalHtml.replace('{{ACTION_URL}}', '#');
        }

        log(`Attempting to send email to ${email} via ${username}`);

        // Connecting to Gmail (smtp.gmail.com:465) via TLS
        const hostname = "smtp.gmail.com";
        const port = 465;

        log(`Connecting to ${hostname}:${port}...`);
        const conn = await Deno.connectTls({ hostname, port });
        log("Connected to SMTP.");

        const encoder = new TextEncoder();
        const decoder = new TextDecoder();

        // Helper to write to the connection
        const write = async (text: string) => {
            const data = encoder.encode(text + "\r\n");
            await writeAll(conn, data);
        };

        // Helper to read response
        const read = async () => {
            const buf = new Uint8Array(1024);
            const n = await conn.read(buf);
            if (n === null) return "";
            const s = decoder.decode(buf.subarray(0, n));
            return s;
        };

        // Initial handshake
        await read();

        // EHLO
        log("Sending EHLO...");
        await write("EHLO localhost");
        await read();

        // AUTH LOGIN
        log("Authenticating...");
        await write("AUTH LOGIN");
        await read();

        await write(base64.encode(username));
        await read();

        await write(base64.encode(password));
        const authRes = await read();
        if (!authRes.includes("235")) {
            throw new Error(`SMTP Auth failed: ${authRes}`);
        }
        log("Authentication successful.");

        // MAIL FROM
        await write(`MAIL FROM: <${username}>`);
        await read();

        // RCPT TO
        await write(`RCPT TO: <${email}>`);
        await read();

        // DATA
        await write("DATA");
        await read();

        // Headers and Body
        const emailHeader = `From: OrderMate <${username}>
To: ${email}
Subject: ${email_subject}
MIME-Version: 1.0
Content-Type: text/html; charset=utf-8`;

        await write(emailHeader);
        await write(""); // Empty line

        const cleanBody = finalHtml.replace(/\r\n/g, '\n').replace(/\n/g, '\r\n');
        await write(cleanBody);
        log("Body sent.");

        // End of message
        await write(".");

        const res = await read();
        if (!res.includes("250")) {
            throw new Error(`Sending failed: ${res}`);
        }
        log("Email sent successfully.");

        // QUIT
        await write("QUIT");
        try {
            await read();
            conn.close();
        } catch (_) { }

        return new Response(
            JSON.stringify({
                message: 'Email sent successfully',
                user_id: authUserId,
                debug_logs: logs
            }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 200 }
        );

    } catch (error) {
        console.error("Error:", error);
        return new Response(
            JSON.stringify({
                error: `Email Failed: ${error.message}`,
                debug_logs: logs
            }),
            { headers: { ...corsHeaders, 'Content-Type': 'application/json' }, status: 400 }
        );
    }
});
