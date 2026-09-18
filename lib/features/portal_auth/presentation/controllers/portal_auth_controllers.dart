import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/errors/result.dart';
import '../../../device_activation/presentation/controllers/device_access_controller.dart';
import '../../data/portal_auth_repository_impl.dart';
import '../../domain/entities/portal_session.dart';
import '../../domain/repositories/portal_auth_repository.dart';

final portalAuthRepositoryProvider = Provider<PortalAuthRepository>(
  (ref) => PortalAuthRepositoryImpl(),
);

const _tokenPrefsKey = 'portal_auth_token';

/// Holds the logged-in portal user's session (separate from the app's local
/// ledger login) and persists just the token locally, so re-opening the app
/// doesn't require logging into the portals again. On every build, the
/// stored token is revalidated against the backend (via `/me`) so grants an
/// admin changed since last login take effect immediately.
class PortalSessionController extends AsyncNotifier<PortalSession?> {
  @override
  Future<PortalSession?> build() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenPrefsKey);
    if (token == null) return null;

    final result = await ref.read(portalAuthRepositoryProvider).me(token);
    if (result.isSuccess) {
      final session = result.valueOrNull;
      if (session != null && session.userId != null && session.userId! > 0) {
        Future.microtask(() {
          ref
              .read(deviceAccessControllerProvider.notifier)
              .autoRegisterDevice(userId: session.userId);
        });
      }
      return session;
    }

    await prefs.remove(_tokenPrefsKey);
    return null;
  }

  Future<void> refreshSession() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenPrefsKey);
    if (token == null) {
      state = const AsyncData(null);
      return;
    }
    final result = await ref.read(portalAuthRepositoryProvider).me(token);
    if (result.isSuccess) {
      state = AsyncData(result.valueOrNull);
    }
  }

  Future<Result<void>> login({
    required String identifier,
    required String password,
  }) async {
    final result = await ref
        .read(portalAuthRepositoryProvider)
        .login(identifier: identifier, password: password);
    final session = result.valueOrNull;
    if (session == null) return Failure(result.errorOrNull!);

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenPrefsKey, session.token);
    state = AsyncData(session);

    // Auto-sync: automatically register device and activate token on login
    if (session.userId != null && session.userId! > 0) {
      try {
        await ref
            .read(deviceAccessControllerProvider.notifier)
            .autoRegisterDevice(userId: session.userId);
      } catch (_) {}
    }

    return const Success(null);
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenPrefsKey);
    state = const AsyncData(null);
  }
}

final portalSessionControllerProvider =
    AsyncNotifierProvider<PortalSessionController, PortalSession?>(
      PortalSessionController.new,
    );
