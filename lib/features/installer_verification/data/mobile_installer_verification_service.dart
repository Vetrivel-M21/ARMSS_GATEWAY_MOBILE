import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/config/gateway_api_client.dart';
import '../../../core/device_auth/device_identity_service.dart';

class MobileInstallerVerificationService {
  static const _kInstallerVerified = 'armss_installer_verified';

  /// Checks if this installation has already passed installer verification.
  /// Automatically marks existing logged-in or bound users as verified during auto-updates.
  Future<bool> isVerified() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_kInstallerVerified) == true) {
      return true;
    }

    // Auto-migration: if already logged in or bound to an account, this is an update
    final hasToken = prefs.getString('portal_auth_token') != null;
    final hasBound = prefs.getString('armss_bound_username') != null ||
        prefs.getInt('armss_bound_user_id') != null;
    if (hasToken || hasBound) {
      await prefs.setBool(_kInstallerVerified, true);
      return true;
    }

    return false;
  }

  /// Step 1: Request an OTP to be sent to the administrator's email.
  Future<String> requestOtp({
    required String username,
    required String department,
    required String branch,
  }) async {
    final uri = Uri.parse('${GatewayApiClient.apiBaseUrl}/installer/request-otp');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'X-Installer-Secret': GatewayApiClient.installerApiSecret,
          },
          body: jsonEncode({
            'username': username.trim(),
            'department': department.trim(),
            'branch': branch.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['success'] == true && data['data'] != null) {
      final reqId = data['data']['request_id'] as String?;
      if (reqId != null && reqId.isNotEmpty) {
        return reqId;
      }
    }

    final msg = data['error']?['message'] ?? 'Failed to request installer OTP. Please try again.';
    throw Exception(msg);
  }

  /// Step 2: Verify the 6-digit OTP received via email.
  Future<bool> verifyOtp({
    required String requestId,
    required String otp,
  }) async {
    final uri = Uri.parse('${GatewayApiClient.apiBaseUrl}/installer/verify-otp');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'X-Installer-Secret': GatewayApiClient.installerApiSecret,
          },
          body: jsonEncode({
            'request_id': requestId.trim(),
            'otp': otp.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['success'] == true && data['data'] != null) {
      return data['data']['valid'] == true;
    }

    final msg = data['error']?['message'] ?? 'Invalid or expired OTP. Please try again.';
    throw Exception(msg);
  }

  /// Step 3: Verify the centralized installer password.
  Future<int> verifyPassword({required String password}) async {
    final uri = Uri.parse('${GatewayApiClient.apiBaseUrl}/installer/verify-password');
    final response = await http
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'X-Installer-Secret': GatewayApiClient.installerApiSecret,
          },
          body: jsonEncode({
            'password': password.trim(),
          }),
        )
        .timeout(const Duration(seconds: 15));

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    if (response.statusCode == 200 && data['success'] == true && data['data'] != null) {
      final valid = data['data']['valid'] == true;
      if (valid) {
        final userIdRaw = data['data']['user_id'];
        int userId = 1;
        if (userIdRaw is int) {
          userId = userIdRaw;
        } else if (userIdRaw is String) {
          userId = int.tryParse(userIdRaw) ?? 1;
        }
        return userId;
      }
    }

    final msg = data['error']?['message'] ?? 'Invalid installer password. Please try again.';
    throw Exception(msg);
  }

  /// Step 4: Finalize installation verification by registering the device and setting verified flag.
  Future<void> completeVerification({int? userId}) async {
    // Self-register device and issue initial device token
    try {
      await DeviceIdentityService().registerDeviceOnServer(userId: userId);
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kInstallerVerified, true);
  }
}
