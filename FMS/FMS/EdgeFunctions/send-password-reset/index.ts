import { createClient } from "jsr:@supabase/supabase-js@2"

function generatePassword(): string {
  const chars = "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789!@#$"
  let password = ""
  for (let i = 0; i < 12; i++) {
    password += chars.charAt(Math.floor(Math.random() * chars.length))
  }
  return password
}

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

    const { data: users, error: userError } = await supabase
      .from("users")
      .select("userid, f_name, l_name, email")
      .eq("email", email)
      .single()

    if (userError || !users) {
      return new Response(
        JSON.stringify({ error: "No user found with this email address" }),
        { status: 404, headers: { "Content-Type": "application/json" } }
      )
    }

    const userId = users.userid
    const displayName = (users.f_name || "") + " " + (users.l_name || "")
    const tempPassword = generatePassword()

    const { error: updateError } = await supabase.auth.admin.updateUserById(
      userId,
      { password: tempPassword }
    )

    if (updateError) {
      throw updateError
    }

    const { error: firstTimeError } = await supabase
      .from("users")
      .update({ first_time_login: true })
      .eq("userid", userId)

    if (firstTimeError) {
      console.error("Failed to set first_time_login:", firstTimeError.message)
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
          "Your temporary password is:\n\n" +
          tempPassword + "\n\n" +
          "Please log in with this temporary password. You will be prompted to set a new password after logging in.\n\n" +
          "If you did not request this password reset, please contact your system administrator immediately.\n\n" +
          "Best regards,\n" + fromName

        await sendEmail(
          smtpHost,
          Number(smtpPort),
          smtpUser,
          smtpPass,
          fromEmail,
          email,
          "Your Password Has Been Reset - Fleet Management System",
          body,
        )
        emailSent = true
      } catch (err) {
        emailError = err.message
        console.error("SMTP email failed:", emailError)
      }
    }

    return new Response(
      JSON.stringify({ emailSent, emailError }),
      { headers: { "Content-Type": "application/json" } }
    )
  } catch (error) {
    return new Response(
      JSON.stringify({ error: error.message }),
      { status: 400, headers: { "Content-Type": "application/json" } }
    )
  }
})
