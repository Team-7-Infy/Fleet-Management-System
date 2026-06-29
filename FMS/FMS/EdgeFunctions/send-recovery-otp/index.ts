import { createClient } from "jsr:@supabase/supabase-js@2"

async function sendEmail(
  host: string,
  port: number,
  username: string,
  password: string,
  from: string,
  to: string,
  subject: string,
  body: string,
): Promise<void> {
  const encoder = new TextEncoder()
  const decoder = new TextDecoder()

  async function readUntilLast(reader: Deno.Reader & Deno.Closer): Promise<string> {
    let data = ""
    const buf = new Uint8Array(4096)
    while (true) {
      const n = await reader.read(buf)
      if (n === null) break
      data += decoder.decode(buf.subarray(0, n))
      const lines = data.split("\r\n")
      if (lines.length > 1) {
        const last = lines[lines.length - 2]
        if (last.length >= 4 && last[3] === " ") break
        if (last.length === 3 && /^\d{3}$/.test(last)) break
      }
    }
    return data
  }

  async function sendLine(writer: Deno.Writer, line: string) {
    await writer.write(encoder.encode(line + "\r\n"))
  }

  let conn: Deno.TcpConn | Deno.TlsConn
  let writer: Deno.Writer
  let reader: Deno.Reader & Deno.Closer

  if (port === 465) {
    conn = await Deno.connectTls({ hostname: host, port })
    writer = conn
    reader = conn
  } else {
    conn = await Deno.connect({ hostname: host, port })
    writer = conn
    reader = conn
  }

  await readUntilLast(reader)

  await sendLine(writer, "EHLO " + host)
  const ehloResponse = await readUntilLast(reader)

  if (port !== 465 && port !== 25 && ehloResponse.toUpperCase().includes("STARTTLS")) {
    await sendLine(writer, "STARTTLS")
    await readUntilLast(reader)
    conn = await Deno.startTls(conn, { hostname: host })
    writer = conn
    reader = conn
    await sendLine(writer, "EHLO " + host)
    await readUntilLast(reader)
  }

  await sendLine(writer, "AUTH LOGIN")
  await readUntilLast(reader)
  await sendLine(writer, btoa(username))
  await readUntilLast(reader)
  await sendLine(writer, btoa(password))
  await readUntilLast(reader)

  await sendLine(writer, "MAIL FROM:<" + from + ">")
  await readUntilLast(reader)
  await sendLine(writer, "RCPT TO:<" + to + ">")
  await readUntilLast(reader)
  await sendLine(writer, "DATA")
  await readUntilLast(reader)

  await sendLine(writer, "From: " + from)
  await sendLine(writer, "To: " + to)
  await sendLine(writer, "Subject: " + subject)
  await sendLine(writer, "MIME-Version: 1.0")
  await sendLine(writer, "Content-Type: text/plain; charset=\"utf-8\"")
  await sendLine(writer, "")
  await sendLine(writer, body)
  await sendLine(writer, ".")
  await readUntilLast(reader)

  await sendLine(writer, "QUIT")
  conn.close()
}

Deno.serve(async (req) => {
  try {
    const { email } = await req.json()

    if (!email) {
      return new Response(
        JSON.stringify({ error: "email is required" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      )
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL")!
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
    const supabase = createClient(supabaseUrl, serviceRoleKey)

    const { data: userData, error: userError } = await supabase
      .from("users")
      .select("userid, f_name, l_name, email")
      .eq("email", email)
      .single()

    if (userError || !userData) {
      return new Response(
        JSON.stringify({ error: "No user found with this email address" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      )
    }

    const displayName = (userData.f_name || "") + " " + (userData.l_name || "")

    const { data: linkData, error: linkError } = await supabase.auth.admin.generateLink({
      type: "recovery",
      email: email,
      redirect_to: "fmsapp://reset-password"
    })

    if (linkError || !linkData) {
      console.error("generateLink error:", linkError?.message || "No data returned")
      throw new Error(linkError?.message || "Failed to generate recovery link")
    }

    const otp = linkData.properties?.email_otp
    if (!otp) {
      console.error("No email_otp in response:", JSON.stringify(linkData))
      throw new Error("No OTP returned from recovery link generation")
    }

    const smtpHost = Deno.env.get("SMTP_HOST")
    const smtpPort = Deno.env.get("SMTP_PORT")
    const smtpUser = Deno.env.get("SMTP_USER")
    const smtpPass = Deno.env.get("SMTP_PASS")
    const fromEmail = Deno.env.get("SMTP_FROM_EMAIL") || "noreply@fms.com"
    const fromName = Deno.env.get("SMTP_FROM_NAME") || "Fleet Management System"

    let emailSent = false
    let emailError: string | null = null

    if (smtpHost && smtpPort && smtpUser && smtpPass) {
      try {
        const body = "Hello " + (displayName.trim() || email) + ",\n\n" +
          "A password reset was requested for your Fleet Management System account.\n\n" +
          "Your verification code is:\n\n" +
          otp + "\n\n" +
          "Please enter this code in the app to reset your password.\n\n" +
          "This code will expire in 1 hour.\n\n" +
          "If you did not request this password reset, please ignore this email.\n\n" +
          "Best regards,\n" + fromName

        await sendEmail(
          smtpHost,
          Number(smtpPort),
          smtpUser,
          smtpPass,
          fromEmail,
          email,
          "Your Password Reset Verification Code - Fleet Management System",
          body,
        )
        emailSent = true
      } catch (err) {
        emailError = err.message
        console.error("SMTP email failed:", emailError)
      }
    }

    return new Response(
      JSON.stringify({ otpSent: emailSent, emailError }),
      { headers: { "Content-Type": "application/json" } }
    )
  } catch (error) {
    console.error("send-recovery-otp error:", error.message)
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    )
  }
})
