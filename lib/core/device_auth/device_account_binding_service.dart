import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BoundAccount {
  final int userId;
  final String username;
  final String email;

  const BoundAccount({
    required this.userId,
    required this.username,
    required this.email,
  });

  String get displayName => username.isNotEmpty ? username : email;
}

/// Service that enforces single-account device binding.
/// Once any account (user or admin) logs into this installation,
/// the installation is permanently bound to that account.
/// The only way to switch accounts is by uninstalling and reinstalling the app.
class DeviceAccountBindingService {
  static const _prefBoundUserId = 'armss_bound_user_id';
  static const _prefBoundUsername = 'armss_bound_username';
  static const _prefBoundEmail = 'armss_bound_email';

  static BoundAccount? _cachedBoundAccount;

  /// Retrieves the currently bound account on this device, or null if none is bound yet.
  Future<BoundAccount?> getBoundAccount() async {
    if (_cachedBoundAccount != null) {
      return _cachedBoundAccount;
    }

    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getInt(_prefBoundUserId);
    final username = prefs.getString(_prefBoundUsername);
    final email = prefs.getString(_prefBoundEmail);

    if (userId != null || (username != null && username.isNotEmpty) || (email != null && email.isNotEmpty)) {
      _cachedBoundAccount = BoundAccount(
        userId: userId ?? 0,
        username: username ?? '',
        email: email ?? '',
      );
      return _cachedBoundAccount;
    }
    return null;
  }

  /// Permanently binds this device installation to the specified account.
  Future<void> bindAccount({
    required int userId,
    required String username,
    required String email,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_prefBoundUserId, userId);
    await prefs.setString(_prefBoundUsername, username);
    await prefs.setString(_prefBoundEmail, email);

    _cachedBoundAccount = BoundAccount(
      userId: userId,
      username: username,
      email: email,
    );
  }

  /// Checks whether an identifier (username or email) matches the bound account.
  /// Returns true if no account is bound yet, or if it matches the bound account.
  Future<bool> isIdentifierAllowed(String identifier) async {
    final bound = await getBoundAccount();
    if (bound == null) return true;

    final clean = identifier.trim().toLowerCase();
    if (clean.isEmpty) return false;

    final boundUser = bound.username.trim().toLowerCase();
    final boundEmail = bound.email.trim().toLowerCase();

    return clean == boundUser || clean == boundEmail;
  }

  /// Validates whether a logged in session belongs to the bound account.
  Future<bool> isSessionAllowed({int? userId, String? username, String? email}) async {
    final bound = await getBoundAccount();
    if (bound == null) return true;

    if (userId != null && bound.userId > 0 && userId == bound.userId) {
      return true;
    }
    final cleanUser = (username ?? '').trim().toLowerCase();
    if (cleanUser.isNotEmpty && cleanUser == bound.username.trim().toLowerCase()) {
      return true;
    }
    final cleanEmail = (email ?? '').trim().toLowerCase();
    if (cleanEmail.isNotEmpty && cleanEmail == bound.email.trim().toLowerCase()) {
      return true;
    }
    return false;
  }
}

final deviceAccountBindingServiceProvider = Provider<DeviceAccountBindingService>(
  (ref) => DeviceAccountBindingService(),
);
