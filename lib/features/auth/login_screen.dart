import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../guide/guide_style.dart';
import 'bloc/auth_bloc.dart';

enum _Stage { welcome, register, signIn }

/// The first thing anyone sees: the promise, then an account in as few fields as possible.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  _Stage _stage = _Stage.welcome;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool get _register => _stage == _Stage.register;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final bloc = context.read<AuthBloc>();
    if (_register) {
      bloc.add(AuthRegisterRequested(_name.text.trim(), _email.text.trim(), _password.text));
    } else {
      bloc.add(AuthLoginRequested(_email.text.trim(), _password.text));
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: _stage == _Stage.welcome,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _stage = _Stage.welcome);
        },
        child: Scaffold(
          backgroundColor: G.bg,
          body: SafeArea(child: _stage == _Stage.welcome ? _welcome() : _form()),
        ),
      );

  Widget _welcome() => Padding(
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  const AllyOrb(size: 140),
                  const SizedBox(height: 34),
                  Text('Too much on your mind?',
                      textAlign: TextAlign.center, style: G.text(46, w: FontWeight.w600, height: 1.06, letterSpacing: -1.4)),
                  const SizedBox(height: 16),
                  Text('Tell Ally everything. Get back one thing to do.',
                      textAlign: TextAlign.center, style: G.text(20, color: G.muted, height: 1.4)),
                ]),
              ),
            ),
          ),
          GPill('Get started', primary: true, onTap: () => setState(() => _stage = _Stage.register)),
          const SizedBox(height: 10),
          GPill('I already have an account', onTap: () => setState(() => _stage = _Stage.signIn)),
          const SizedBox(height: 14),
          Text('For adults, 18 and over. You can delete everything anytime.',
              textAlign: TextAlign.center, style: G.text(15, color: G.muted, height: 1.3)),
        ]),
      );

  Widget _form() => Padding(
        padding: const EdgeInsets.fromLTRB(22, 10, 22, 16),
        child: Form(
          key: _formKey,
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Align(
              alignment: Alignment.centerLeft,
              child: IconButton(
                tooltip: 'Back',
                onPressed: () => setState(() => _stage = _Stage.welcome),
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: G.ink),
                style: IconButton.styleFrom(backgroundColor: G.card, minimumSize: const Size(46, 46)),
              ),
            ),
            Expanded(
              child: ListView(children: [
                const SizedBox(height: 20),
                Text(_register ? "Let's get you set up" : 'Good to see you',
                    style: G.text(44, w: FontWeight.w600, height: 1.05, letterSpacing: -1.3)),
                const SizedBox(height: 24),
                if (_register) ...[
                  _field(_name, 'Name', 'What should I call you?', TextInputType.name),
                  const SizedBox(height: 16),
                ],
                _field(_email, 'Email', 'you@gmail.com', TextInputType.emailAddress,
                    validator: (v) => (v != null && v.contains('@')) ? null : 'Enter a valid email'),
                const SizedBox(height: 16),
                _field(_password, 'Password', 'At least 6 characters', TextInputType.text,
                    obscure: true, validator: (v) => (v != null && v.length >= 6) ? null : 'At least 6 characters'),
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, state) => state.error == null
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.only(top: 14),
                          child: Text(state.error!, style: G.text(16, color: G.accent, height: 1.3)),
                        ),
                ),
              ]),
            ),
            BlocBuilder<AuthBloc, AuthState>(
              builder: (context, state) {
                final busy = state.status == AuthStatus.authenticating;
                return GPill(busy ? 'One moment…' : (_register ? 'Create my account' : 'Sign in'), primary: true, onTap: busy ? null : _submit);
              },
            ),
            TextButton(
              onPressed: () => setState(() => _stage = _register ? _Stage.signIn : _Stage.register),
              style: TextButton.styleFrom(foregroundColor: G.ink, minimumSize: const Size(64, 52)),
              child: Text(_register ? 'I already have an account' : 'New here? Create an account', style: G.text(17, height: 1.2)),
            ),
          ]),
        ),
      );

  Widget _field(TextEditingController c, String label, String hint, TextInputType type,
          {bool obscure = false, String? Function(String?)? validator}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: G.text(17, height: 1.2)),
        const SizedBox(height: 8),
        TextFormField(
          controller: c,
          keyboardType: type,
          obscureText: obscure,
          style: G.text(18, height: 1.3),
          cursorColor: G.accent,
          validator: validator,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: G.text(18, color: G.faint, height: 1.3),
            filled: true,
            fillColor: G.card,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide(color: G.accent)),
            errorStyle: G.text(15, color: G.accent, height: 1.2),
          ),
        ),
      ]);
}
