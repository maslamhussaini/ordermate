import 'package:mailer/mailer.dart';
import 'package:mailer/smtp_server.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class EmailService {
  // Singleton pattern
  static final EmailService _instance = EmailService._internal();
  factory EmailService() => _instance;
  EmailService._internal();

  // SMTP Credentials - Fetched via getters to ensure they are read AFTER dotenv.load()
  String get smtpUsername => dotenv.env['SMTP_EMAIL'] ?? dotenv.env['GMAIL_USERNAME'] ?? ''; 
  String get smtpPassword => dotenv.env['SMTP_PASSWORD'] ?? dotenv.env['GMAIL_APP_PASSWORD'] ?? ''; 

  String get _smtpUsername => smtpUsername;
  String get _smtpPassword => smtpPassword; 

  Future<bool> sendOtpEmail(String recipientEmail, String otp) async {
    // 1. Configure SMTP
    // Note: Using gmail sasl auth. 
    // If user has a different SMTP, they need to change this.
    final smtpServer = gmail(_smtpUsername, _smtpPassword);
    
    // 2. Create Message
    final message = Message()
      ..from = Address(_smtpUsername, 'OrderMate App')
      ..recipients.add(recipientEmail)
      ..subject = 'OrderMate App - Your Verification Code'
      ..text = 'Your OrderMate App verification code is: $otp. It is valid for 10 minutes.'
      ..html = """
        <div style="font-family: sans-serif; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
          <h2 style="color: #2196F3;">OrderMate App Verification</h2>
          <p>Hello,</p>
          <p>Your verification code is:</p>
          <div style="font-size: 32px; font-weight: bold; color: #333; margin: 20px 0;">$otp</div>
          <p style="color: #666; font-size: 14px;">This code is valid for 10 minutes. If you did not request this, please ignore this email.</p>
          <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
          <p style="font-size: 12px; color: #999;">Sent safely via OrderMate App</p>
        </div>
      """;

    try {
      final sendReport = await send(message, smtpServer);
      debugPrint('Message sent: $sendReport');
      return true;
    } on MailerException catch (e) {
      debugPrint('Message not sent.');
      for (var p in e.problems) {
        debugPrint('Problem: ${p.code}: ${p.msg}');
      }
      return false;
    }
  }

  Future<bool> sendWelcomeEmail(String recipientEmail, String employeeName, String role) async {
    final smtpServer = gmail(_smtpUsername, _smtpPassword);
    
    final message = Message()
      ..from = Address(_smtpUsername, 'OrderMate App')
      ..recipients.add(recipientEmail)
      ..subject = 'Welcome to OrderMate - Your Account is Ready'
      ..html = """
        <div style="font-family: sans-serif; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
          <h2 style="color: #4CAF50;">Welcome to OrderMate, $employeeName!</h2>
          <p>Your account has been created successfully with the role of <strong>$role</strong>.</p>
          <p>You can now log in to the application and start managing your tasks.</p>
          <div style="padding: 15px; background: #f5f5f5; border-radius: 5px; margin: 20px 0;">
             <p><strong>Login Email:</strong> $recipientEmail</p>
          </div>
          <p>If you have any questions, please contact your administrator.</p>
          <hr style="border: none; border-top: 1px solid #eee; margin: 20px 0;">
          <p style="font-size: 12px; color: #999;">Sent safely via OrderMate App</p>
        </div>
      """;

    try {
      await send(message, smtpServer);
      return true;
    } catch (e) {
      debugPrint('Error sending welcome email: $e');
      return false;
    }
  }
}
