import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart' as mob_wv;
import 'package:webview_windows/webview_windows.dart' as win_wv;

import '../../../../core/config/trust_app_client.dart';
import '../../../../shared_widgets/gradient_filled_button.dart';
import '../../../../shared_widgets/page_header.dart';
import '../../domain/entities/device_token.dart';
import '../controllers/trust_portal_controllers.dart';

/// Embeds the Trust Management web app in-app. The React app only works
/// through this tab: the device token obtained from `TrustPortalTokenController`
/// is injected into the page's `sessionStorage` before its own scripts run, and
/// the backend rejects every API call that doesn't carry it — a plain browser
/// hitting the same URL has no way to get that token.
///
/// Supports both Windows desktop (via WebView2) and Android/mobile (via webview_flutter).
class TrustPortalScreen extends ConsumerStatefulWidget {
  const TrustPortalScreen({super.key});

  @override
  ConsumerState<TrustPortalScreen> createState() => _TrustPortalScreenState();
}

class _TrustPortalScreenState extends ConsumerState<TrustPortalScreen> {
  // Windows WebView
  win_wv.WebviewController? _winController;
  win_wv.ScriptID? _scriptId;

  // Mobile WebView
  mob_wv.WebViewController? _mobileController;

  bool _webviewReady = false;
  Object? _loadError;

  bool get _isWindows => defaultTargetPlatform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    if (_isWindows) {
      _winController = win_wv.WebviewController();
    }
  }

  @override
  void dispose() {
    _winController?.dispose();
    super.dispose();
  }

  String _setTokenScript(String token) => "window.sessionStorage.setItem('device_token', '$token');";

  Future<void> _loadWithToken(String token) async {
    try {
      if (_isWindows) {
        final ctrl = _winController ?? win_wv.WebviewController();
        _winController = ctrl;
        await ctrl.initialize();
        _scriptId = await ctrl.addScriptToExecuteOnDocumentCreated(_setTokenScript(token));
        await ctrl.loadUrl('${TrustAppClient.portalUrl}?entry_secret=${TrustAppClient.clientSecret}');
      } else {
        final ctrl = mob_wv.WebViewController()
          ..setJavaScriptMode(mob_wv.JavaScriptMode.unrestricted)
          ..setNavigationDelegate(
            mob_wv.NavigationDelegate(
              onPageFinished: (_) {
                _mobileController?.runJavaScript(_setTokenScript(token));
              },
            ),
          )
          ..loadRequest(Uri.parse('${TrustAppClient.portalUrl}?entry_secret=${TrustAppClient.clientSecret}'));
        _mobileController = ctrl;
      }
      if (mounted) setState(() => _webviewReady = true);
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    }
  }

  Future<void> _refreshToken(String token) async {
    try {
      if (_isWindows && _winController != null) {
        await _winController!.executeScript(_setTokenScript(token));
        final oldScriptId = _scriptId;
        _scriptId = await _winController!.addScriptToExecuteOnDocumentCreated(_setTokenScript(token));
        if (oldScriptId != null) {
          await _winController!.removeScriptToExecuteOnDocumentCreated(oldScriptId);
        }
      } else if (_mobileController != null) {
        await _mobileController!.runJavaScript(_setTokenScript(token));
      }
    } catch (_) {}
  }

  Future<void> _openInBrowser(String token) async {
    final url = '${TrustAppClient.portalUrl}?entry_secret=${TrustAppClient.clientSecret}&device_token=$token';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Widget _buildWebView() {
    if (!_webviewReady) return const Center(child: CircularProgressIndicator());
    if (_isWindows && _winController != null) {
      return win_wv.Webview(_winController!);
    }
    if (_mobileController != null) {
      return mob_wv.WebViewWidget(controller: _mobileController!);
    }
    return const Center(child: CircularProgressIndicator());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<DeviceToken>>(trustPortalTokenControllerProvider, (previous, next) {
      next.whenData((deviceToken) {
        if (!_webviewReady) {
          _loadWithToken(deviceToken.token);
        } else if (previous?.valueOrNull?.token != deviceToken.token) {
          _refreshToken(deviceToken.token);
        }
      });
    });

    final tokenAsync = ref.watch(trustPortalTokenControllerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Trust Portal',
          icon: Icons.account_balance_outlined,
          accentColor: const Color(0xFFF97316),
          actions: [
            Builder(
              builder: (ctx) {
                final isMobile = MediaQuery.of(ctx).size.width < 500;
                final onPressed = tokenAsync.valueOrNull == null
                    ? null
                    : () => _openInBrowser(tokenAsync.valueOrNull!.token);
                if (isMobile) {
                  return IconButton(
                    onPressed: onPressed,
                    icon: const Icon(Icons.open_in_browser),
                    tooltip: 'Open in Browser',
                  );
                }
                return OutlinedButton.icon(
                  onPressed: onPressed,
                  icon: const Icon(Icons.open_in_browser),
                  label: const Text('Open in Browser'),
                );
              },
            ),
          ],
        ),
        Expanded(
          child: _loadError != null
              ? _ErrorState(message: 'Could not load the Trust Portal: $_loadError')
              : tokenAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => _ErrorState(message: 'Could not connect to the Trust Management server: $e'),
                  data: (_) => _buildWebView(),
                ),
        ),
      ],
    );
  }
}

class _ErrorState extends ConsumerWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(padding: const EdgeInsets.symmetric(horizontal: 40), child: Text(message, textAlign: TextAlign.center)),
          const SizedBox(height: 16),
          GradientFilledButton(
            onPressed: () => ref.invalidate(trustPortalTokenControllerProvider),
            icon: Icons.refresh,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
