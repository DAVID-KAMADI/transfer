// ignore_for_file: avoid_print

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server/gmail.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import 'dart:convert';

class EmailService {
  static String? _cachedLogoUrl;
  static String? _cachedLogoBase64;

  // =========================================================
  // UPLOAD LOGO TO FIREBASE STORAGE
  // =========================================================
  static Future<String> uploadLogo(File logoFile) async {
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('email-logos')
          .child('app-logo-${DateTime.now().millisecondsSinceEpoch}.png');

      final uploadTask = await storageRef.putFile(logoFile);
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      print('✅ Logo uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      print('❌ Logo upload failed: $e');
      throw Exception('Failed to upload logo: $e');
    }
  }

  // =========================================================
  // GET LOGO URL FROM FIREBASE STORAGE
  // =========================================================
  static Future<String?> getLogoUrl() async {
    try {
      if (_cachedLogoUrl != null) {
        return _cachedLogoUrl;
      }

      final storageRef = FirebaseStorage.instance.ref().child('email-logos');

      final ListResult result = await storageRef.listAll();

      if (result.items.isNotEmpty) {
        // Get the most recent logo
        final latestLogo = result.items.last;
        final downloadUrl = await latestLogo.getDownloadURL();

        _cachedLogoUrl = downloadUrl;
        print('✅ Logo URL retrieved: $downloadUrl');
        return downloadUrl;
      }

      return null;
    } catch (e) {
      print('❌ Failed to get logo URL: $e');
      return null;
    }
  }

  // =========================================================
  // GET LOGO AS BASE64 FOR EMBEDDING
  // =========================================================
  static Future<String?> getLogoBase64() async {
    try {
      if (_cachedLogoBase64 != null) {
        return _cachedLogoBase64;
      }

      final logoUrl = await getLogoUrl();
      if (logoUrl == null) return null;

      final ref = FirebaseStorage.instance.refFromURL(logoUrl);
      final bytes = await ref.getData();

      if (bytes != null) {
        _cachedLogoBase64 = 'data:image/png;base64,${base64Encode(bytes)}';
        print('✅ Logo converted to base64');
        return _cachedLogoBase64;
      }

      return null;
    } catch (e) {
      print('❌ Failed to convert logo to base64: $e');
      return null;
    }
  }

  // =========================================================
  // CLEAR LOGO CACHE
  // =========================================================
  static void clearLogoCache() {
    _cachedLogoUrl = null;
    _cachedLogoBase64 = null;
    print('🗑️ Logo cache cleared');
  }

  static Future<void> sendEmail(
    String recipient,
    String subject,
    String body,
  ) async {
    final email = dotenv.env["GMAIL_MAIL"];
    final password = dotenv.env["GMAIL_PASSWORD"];

    // ✅ SAFE CHECK (prevents crash)
    if (email == null || password == null) {
      throw Exception("Email credentials not found in .env");
    }

    final smtpServer = gmail(email, password);

    // Generate modern HTML email
    final htmlBody = await _generateModernEmailHtml(subject, body);

    final message = Message()
      ..from = Address(email, '748 Store System')
      ..recipients.add(recipient)
      ..subject = subject
      ..html = htmlBody;

    try {
      final sendReport = await send(message, smtpServer);
      print('✅ Email sent: $sendReport');
    } on MailerException catch (e) {
      print('❌ Email failed');
      for (var p in e.problems) {
        print('Problem: ${p.code}: ${p.msg}');
      }
      rethrow;
    }
  }

  // =========================================================
  // GENERATE MODERN HTML EMAIL
  // =========================================================
  static Future<String> _generateModernEmailHtml(
    String subject,
    String body,
  ) async {
    final isOtpEmail = subject.contains("OTP");
    final logoUrl = await getLogoUrl();

    if (isOtpEmail) {
      return _generateOtpEmailHtml(body, logoUrl);
    } else {
      return _generateStandardEmailHtml(subject, body, logoUrl);
    }
  }

  // =========================================================
  // OTP EMAIL TEMPLATE
  // =========================================================
  static String _generateOtpEmailHtml(String otpCode, String? logoUrl) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Transfer OTP Code</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;500;700&display=swap" rel="stylesheet">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Inter', 'Roboto', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: #F8FAFC;
            min-height: 100vh;
            padding: 20px;
            color: #1E293B;
        }
        
        .email-container {
            max-width: 650px;
            margin: 0 auto;
            background: #ffffff;
            border-radius: 12px;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
            overflow: hidden;
            border: 1px solid #E2E8F0;
        }
        
        .header {
            background: linear-gradient(135deg, #1E3A5F 0%, #2E5A8C 100%);
            padding: 40px 35px;
            text-align: center;
            border-bottom: 3px solid #06B6D4;
        }
        
        .logo {
            width: 80px;
            height: 80px;
            background: #ffffff;
            border-radius: 12px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            margin-bottom: 20px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
        }
        
        .logo img {
            width: 100%;
            height: 100%;
            object-fit: contain;
            border-radius: 12px;
        }
        
        .header-text {
            color: #ffffff;
            font-size: 28px;
            font-weight: 600;
            font-family: 'Inter', sans-serif;
            margin: 0;
            letter-spacing: -0.5px;
        }
        
        .header-subtitle {
            color: rgba(255,255,255,0.85);
            font-size: 14px;
            font-weight: 400;
            font-family: 'Inter', sans-serif;
            margin-top: 8px;
        }
        
        .content {
            padding: 45px 35px;
            background: #ffffff;
        }
        
        .otp-container {
            background: linear-gradient(135deg, #06B6D4 0%, #0891B2 100%);
            border-radius: 12px;
            padding: 35px;
            text-align: center;
            margin: 30px 0;
            box-shadow: 0 4px 15px rgba(6, 182, 212, 0.3);
        }
        
        .otp-label {
            color: rgba(255,255,255,0.9);
            font-size: 13px;
            font-weight: 500;
            font-family: 'Inter', sans-serif;
            margin-bottom: 12px;
            text-transform: uppercase;
            letter-spacing: 1.5px;
        }
        
        .otp-code {
            font-size: 42px;
            font-weight: 700;
            font-family: 'Roboto', monospace;
            color: #ffffff;
            letter-spacing: 10px;
            margin: 10px 0;
            text-shadow: 0 2px 4px rgba(0,0,0,0.2);
        }
        
        .info-box {
            background: #F8FAFC;
            border-left: 4px solid #06B6D4;
            border-radius: 8px;
            padding: 24px;
            margin: 24px 0;
        }
        
        .info-title {
            font-weight: 600;
            color: #1E3A5F;
            font-family: 'Inter', sans-serif;
            margin-bottom: 10px;
            font-size: 16px;
        }
        
        .info-text {
            color: #64748B;
            line-height: 1.7;
            font-family: 'Inter', sans-serif;
            font-size: 14px;
        }
        
        .security-notice {
            background: #FEF3C7;
            border: 1px solid #F59E0B;
            border-radius: 8px;
            padding: 16px;
            margin: 24px 0;
            display: flex;
            align-items: center;
            gap: 12px;
        }
        
        .security-icon {
            font-size: 20px;
        }
        
        .security-text {
            color: #92400E;
            font-size: 13px;
            font-family: 'Inter', sans-serif;
            line-height: 1.5;
        }
        
        .footer {
            background: #F8FAFC;
            padding: 30px 35px;
            text-align: center;
            border-top: 1px solid #E2E8F0;
        }
        
        .footer-text {
            color: #64748B;
            font-size: 12px;
            font-family: 'Inter', sans-serif;
            line-height: 1.6;
        }
        
        .footer-divider {
            width: 60px;
            height: 3px;
            background: linear-gradient(90deg, #06B6D4, #1E3A5F);
            margin: 0 auto 16px;
            border-radius: 2px;
        }
        
        @media (max-width: 600px) {
            body {
                padding: 10px;
            }
            
            .email-container {
                border-radius: 10px;
                margin: 10px;
            }
            
            .header, .content {
                padding: 30px 25px;
            }
            
            .otp-code {
                font-size: 32px;
                letter-spacing: 6px;
            }
            
            .logo {
                width: 60px;
                height: 60px;
            }
        }
    </style>
</head>
<body>
    <div class="email-container">
        <div class="header">
            ${logoUrl != null ? '<div class="logo"><img src="$logoUrl" alt="748 Store System"></div>' : '<div class="logo">748</div>'}
            <h1 class="header-text">Transfer Verification</h1>
            <p class="header-subtitle">748 Store System</p>
        </div>
        
        <div class="content">
            <div class="otp-container">
                <div class="otp-label">Your One-Time Password</div>
                <div class="otp-code">$otpCode</div>
            </div>
            
            <div class="info-box">
                <div class="info-title">Important Information</div>
                <div class="info-text">
                    This OTP code is required to complete your transfer verification. Please keep it secure and do not share it with anyone.
                </div>
            </div>
            
            <div class="security-notice">
                <span class="security-icon">🔒</span>
                <span class="security-text">This code will expire in 5 minutes for security reasons.</span>
            </div>
        </div>
        
        <div class="footer">
            <div class="footer-divider"></div>
            <p class="footer-text">
                © 2024 748 Store System. All rights reserved.<br>
                This is an automated message, please do not reply.
            </p>
        </div>
    </div>
</body>
</html>
''';
  }

  // =========================================================
  // STANDARD EMAIL TEMPLATE
  // =========================================================
  static String _generateStandardEmailHtml(
    String subject,
    String body,
    String? logoUrl,
  ) {
    return '''
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>$subject</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <link href="https://fonts.googleapis.com/css2?family=Roboto:wght@400;500;700&display=swap" rel="stylesheet">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: 'Inter', 'Roboto', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
            background: #F8FAFC;
            min-height: 100vh;
            padding: 20px;
            color: #1E293B;
        }
        
        .email-container {
            max-width: 650px;
            margin: 0 auto;
            background: #ffffff;
            border-radius: 12px;
            box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1), 0 2px 4px -1px rgba(0, 0, 0, 0.06);
            overflow: hidden;
            border: 1px solid #E2E8F0;
        }
        
        .header {
            background: linear-gradient(135deg, #1E3A5F 0%, #2E5A8C 100%);
            padding: 40px 35px;
            text-align: center;
            border-bottom: 3px solid #06B6D4;
        }
        
        .logo {
            width: 80px;
            height: 80px;
            background: #ffffff;
            border-radius: 12px;
            display: inline-flex;
            align-items: center;
            justify-content: center;
            margin-bottom: 20px;
            box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
        }
        
        .logo img {
            width: 100%;
            height: 100%;
            object-fit: contain;
            border-radius: 12px;
        }
        
        .header-text {
            color: #ffffff;
            font-size: 28px;
            font-weight: 600;
            font-family: 'Inter', sans-serif;
            margin: 0;
            letter-spacing: -0.5px;
        }
        
        .header-subtitle {
            color: rgba(255,255,255,0.85);
            font-size: 14px;
            font-weight: 400;
            font-family: 'Inter', sans-serif;
            margin-top: 8px;
        }
        
        .content {
            padding: 45px 35px;
            background: #ffffff;
        }
        
        .message-box {
            background: #F8FAFC;
            border-radius: 12px;
            padding: 30px;
            margin: 25px 0;
            border-left: 4px solid #06B6D4;
        }
        
        .message-text {
            color: #1E293B;
            line-height: 1.7;
            font-family: 'Inter', sans-serif;
            font-size: 15px;
            white-space: pre-wrap;
            word-wrap: break-word;
        }
        
        .footer {
            background: #F8FAFC;
            padding: 30px 35px;
            text-align: center;
            border-top: 1px solid #E2E8F0;
        }
        
        .footer-text {
            color: #64748B;
            font-size: 12px;
            font-family: 'Inter', sans-serif;
            line-height: 1.6;
        }
        
        .footer-divider {
            width: 60px;
            height: 3px;
            background: linear-gradient(90deg, #06B6D4, #1E3A5F);
            margin: 0 auto 16px;
            border-radius: 2px;
        }
        
        @media (max-width: 600px) {
            body {
                padding: 10px;
            }
            
            .email-container {
                border-radius: 10px;
                margin: 10px;
            }
            
            .header, .content {
                padding: 30px 25px;
            }
            
            .logo {
                width: 60px;
                height: 60px;
            }
        }
    </style>
</head>
<body>
    <div class="email-container">
        <div class="header">
            ${logoUrl != null ? '<div class="logo"><img src="$logoUrl" alt="748 Store System"></div>' : '<div class="logo">748</div>'}
            <h1 class="header-text">$subject</h1>
            <p class="header-subtitle">748 Store System</p>
        </div>
        
        <div class="content">
            <div class="message-box">
                <div class="message-text">$body</div>
            </div>
        </div>
        
        <div class="footer">
            <div class="footer-divider"></div>
            <p class="footer-text">
                © 2024 748 Store System. All rights reserved.<br>
                This is an automated message, please do not reply.
            </p>
        </div>
    </div>
</body>
</html>
''';
  }
}
