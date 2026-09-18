import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme.dart';
import '../features/auth/presentation/screens/login_screen.dart';
import '../features/portal_auth/presentation/controllers/portal_auth_controllers.dart';
import 'app_shell.dart';

const _loadingHome = Scaffold(body: Center(child: CircularProgressIndicator()));

class MisApp extends ConsumerStatefulWidget {
  const MisApp({super.key});

  @override
  ConsumerState<MisApp> createState() => _MisAppState();
}

class _MisAppState extends ConsumerState<MisApp> {


  @override
  Widget build(BuildContext context) {
    final portalSessionAsync = ref.watch(portalSessionControllerProvider);
    final Widget home = portalSessionAsync.when(
      loading: () => _loadingHome,
      error: (_, _) => const LoginScreen(),
      data: (session) =>
          session == null ? const LoginScreen() : const AppShell(),
    );

    return MaterialApp(
      title: 'ARMSS Gateway',
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: home,
    );
  }
}
