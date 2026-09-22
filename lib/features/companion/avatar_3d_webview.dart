import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Hosts the real-time 3D toon character — the exact same Three.js scene as
/// the web app's Avatar3D.tsx, run inside a transparent WebView. Flutter has
/// no mature native 3D renderer, so this reuses the web character wholesale
/// instead of building/maintaining a second one.
class Avatar3DWebView extends StatefulWidget {
  final double size;
  final bool talking;
  final bool thinking;
  final Color accent;

  const Avatar3DWebView({
    super.key,
    required this.size,
    required this.talking,
    required this.thinking,
    required this.accent,
  });

  @override
  State<Avatar3DWebView> createState() => _Avatar3DWebViewState();
}

class _Avatar3DWebViewState extends State<Avatar3DWebView> {
  late final WebViewController _controller;

  @override
  void initState() {
    super.initState();
    final hex = '#${(widget.accent.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';
    final size = widget.size.round();
    _controller = WebViewController()
      ..setBackgroundColor(const Color(0x00000000))
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel('AvatarTap', onMessageReceived: _onMessage)
      ..setNavigationDelegate(NavigationDelegate(
        // loadFlutterAsset resolves its argument as a literal asset key, not
        // a URL — it can't carry a query string, so init params are passed
        // via a JS call instead, once the page has actually finished
        // loading (calling runJavaScript before that is a silent no-op).
        onPageFinished: (_) {
          _controller.runJavaScript('window.initAvatar("$hex", $size);');
        },
      ))
      ..loadFlutterAsset('assets/avatar3d/index.html');
  }

  void _onMessage(JavaScriptMessage message) {
    final scope = _AvatarTapScope.of(context);
    if (message.message == 'longpress') {
      scope?.onLongPress?.call();
    } else {
      scope?.onTap?.call();
    }
  }

  @override
  void didUpdateWidget(covariant Avatar3DWebView old) {
    super.didUpdateWidget(old);
    if (old.talking != widget.talking || old.thinking != widget.thinking) {
      _controller.runJavaScript(
        'window.setAvatarState && window.setAvatarState(${widget.talking}, ${widget.thinking});',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: IgnorePointer(
        // Taps are handled by the JS channel above (and the parent's own
        // GestureDetector for drag/long-press) — the WebView itself doesn't
        // need to intercept touches.
        ignoring: false,
        child: WebViewWidget(controller: _controller),
      ),
    );
  }
}

/// Lets [Avatar3DWebView] reach tap/long-press callbacks supplied higher in
/// the tree without threading them through every intermediate widget.
class _AvatarTapScope extends InheritedWidget {
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  const _AvatarTapScope({
    required this.onTap,
    required this.onLongPress,
    required super.child,
  });

  static _AvatarTapScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AvatarTapScope>();

  @override
  bool updateShouldNotify(_AvatarTapScope old) =>
      old.onTap != onTap || old.onLongPress != onLongPress;
}

/// Wrap an [Avatar3DWebView] subtree with this to receive taps/long-presses
/// that originate from inside the WebView (the JS `AvatarTap.postMessage`
/// bridge) — a WebView captures touch input itself, so a normal
/// [GestureDetector] around it won't see these directly.
class AvatarTapListener extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final Widget child;
  const AvatarTapListener({
    super.key,
    required this.onTap,
    required this.onLongPress,
    required this.child,
  });

  @override
  Widget build(BuildContext context) =>
      _AvatarTapScope(onTap: onTap, onLongPress: onLongPress, child: child);
}
