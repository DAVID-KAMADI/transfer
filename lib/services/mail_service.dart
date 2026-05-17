import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';

class EmailService {
  // ================================
  // GMAIL SMTP SERVER
  // ================================
  static final smtpServer = gmail(
    dotenv.env["GMAIL_EMAIL"]!,
    dotenv.env["GMAIL_PASSWORD"]!,
  );

  // ================================
  // SEND GENERIC EMAIL (HTML ENABLED)
  // ================================
  static Future<void> sendEmail({
    required String recipient,
    required String subject,
    required String body, // now HTML supported
  }) async {
    final message = Message()
      ..from = Address(
        dotenv.env["GMAIL_EMAIL"]!,
        "Transfer System",
      )
      ..recipients.add(recipient)
      ..subject = subject
      ..html = body; // ✅ CHANGED from .text → .html

    try {
      await send(message, smtpServer);
    } on MailerException catch (e) {
      // ignore: unused_local_variable
      for (var p in e.problems) {
      }
      rethrow;
    }
  }

  // ================================
  // OTP EMAIL (STYLED HTML VERSION)
  // ================================
  static Future<void> sendOtpEmail({
    required String recipient,
    required String otp,
    String? transferNo,
    String? fromStore,
    String? toStore,
    String? companyName,
    String? supportEmail,
    String? logoUrl,
  }) async {
    final htmlBody = """
    <div style="margin:0; padding:0; background-color:#f4f6f8; font-family:Arial, sans-serif;">

      <div style="max-width:600px; margin:0 auto; background:#ffffff; border-radius:10px; overflow:hidden;">

        <!-- HEADER -->
        <div style="background:#1E3A5F; padding:20px; text-align:center;">
          ${logoUrl != null
              ? "<img src='$logoUrl' style='height:50px; margin-bottom:10px;' />"
              : ""}

          <h2 style="color:white; margin:0;">
            ${companyName ?? "748 AIR"}
          </h2>

          <p style="color:#cbd5e1; font-size:13px; margin:5px 0 0;">
            Secure Verification Email
          </p>
        </div>

        <!-- BODY -->
        <div style="padding:25px;">

          <p style="color:#333; font-size:15px;">
            Use the OTP below to complete your transfer verification.
          </p>

          <!-- TRANSFER INFO -->
          <div style="background:#f0f4ff; border-left:5px solid #4A90D9; padding:12px; margin:20px 0;">
            <p style="margin:5px 0;"><b>Transfer No:</b> ${transferNo ?? "-"}</p>
            <p style="margin:5px 0;"><b>From:</b> ${fromStore ?? "-"}</p>
            <p style="margin:5px 0;"><b>To:</b> ${toStore ?? "-"}</p>
          </div>

          <!-- OTP -->
          <div style="text-align:center; margin:30px 0;">
            <p style="font-size:13px; color:#555;">Your OTP Code</p>

            <div style="
              display:inline-block;
              font-size:36px;
              font-weight:bold;
              letter-spacing:8px;
              color:#10B981;
              background:#ecfdf5;
              padding:15px 25px;
              border-radius:10px;
              border:2px dashed #10B981;
            ">
              $otp
            </div>

            <p style="font-size:12px; color:#888; margin-top:15px;">
              Expires in <b>5 minutes</b>
            </p>
          </div>

        </div>

        <!-- FOOTER -->
        <div style="background:#f8fafc; padding:18px; text-align:center; font-size:12px; color:#6b7280;">

          <p style="margin:5px 0;">
            ${companyName ?? "Transfer System"}
          </p>

          <p style="margin:5px 0;">
            Support:
            <a href="mailto:${supportEmail ?? "support@company.com"}">
              ${supportEmail ?? "support@company.com"}
            </a>
          </p>

          <p style="margin:10px 0 0;">
            © ${DateTime.now().year} All rights reserved
          </p>

        </div>

      </div>
    </div>
    """;

    await sendEmail(
      recipient: recipient,
      subject: "Transfer OTP Verification",
      body: htmlBody,
    );
  }
}