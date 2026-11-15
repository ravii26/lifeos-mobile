import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../design/appearance.dart';
import '../../design/components.dart';
import '../../design/rings.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';
import '../auth/bloc/auth_bloc.dart';

/// The first screen: the promise and "Get started", with no account yet.
/// Someone who has one signs in instead.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _signIn = false;
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    _email.addListener(() => setState(() {}));
    _password.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(data: AllyAppearance.themeOf(context), child: Builder(builder: _page));

  Widget _page(BuildContext themed) {
    final c = themed.ac;
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, auth) {
        final busy = auth.status == AuthStatus.authenticating;
        return Scaffold(
          backgroundColor: c.bg,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(Sp.side, Sp.x6, Sp.side, Sp.x5),
              children: [
                if (!_signIn) ...[
                  Center(
                    child: SizedBox(
                      width: 96,
                      height: 96,
                      child: ProgressRing(value: 0.7, color: c.ink, size: 96, stroke: 12),
                    ),
                  ),
                  const SizedBox(height: Sp.x6),
                  Text('Plan less. Do more.', style: AllyType.h1(color: c.ink)),
                  const SizedBox(height: Sp.x2),
                  Text('Tell Ally everything you want. It keeps the plan, fits it into your real week, and tells you the one thing to do when you have time.',
                      style: AllyType.body(color: c.muted)),
                  const SizedBox(height: Sp.x6),
                  if (auth.error != null) ...[AllyNote(auth.error!), const SizedBox(height: Sp.x3)],
                  AllyButton(busy ? 'Starting…' : 'Get started', wide: true, onPressed: busy ? null : () => context.read<AuthBloc>().add(const AuthGuestRequested())),
                  const SizedBox(height: Sp.x2),
                  AllyButton('I already have an account', kind: AllyButtonKind.ghost, wide: true, onPressed: () => setState(() => _signIn = true)),
                  const SizedBox(height: Sp.x3),
                  Text('No account needed to start. Save it with an email at the end.', textAlign: TextAlign.center, style: AllyType.small(color: c.faint)),
                ] else ...[
                  Align(
                    alignment: Alignment.centerLeft,
                    child: AllyButton('Back', kind: AllyButtonKind.ghost, icon: Icons.arrow_back_rounded, onPressed: () => setState(() => _signIn = false)),
                  ),
                  const SizedBox(height: Sp.x3),
                  Text('Welcome back', style: AllyType.h1(color: c.ink)),
                  const SizedBox(height: Sp.x5),
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    style: AllyType.body(color: c.ink),
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: Sp.x3),
                  TextField(
                    controller: _password,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    style: AllyType.body(color: c.ink),
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: Sp.x4),
                  if (auth.error != null) ...[AllyNote(auth.error!), const SizedBox(height: Sp.x3)],
                  AllyButton(
                    busy ? 'Signing in…' : 'Sign in',
                    wide: true,
                    onPressed: busy || _email.text.trim().isEmpty || _password.text.isEmpty
                        ? null
                        : () => context.read<AuthBloc>().add(AuthLoginRequested(_email.text.trim(), _password.text)),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
