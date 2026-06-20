import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme/app_colors.dart';
import 'bloc/auth_bloc.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _register = false;
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();

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
      bloc.add(AuthRegisterRequested(
          _name.text.trim(), _email.text.trim(), _password.text));
    } else {
      bloc.add(AuthLoginRequested(_email.text.trim(), _password.text));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.4, -1),
            radius: 1.2,
            colors: [Color(0xFF14171D), AppColors.bg],
            stops: [0, 0.6],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 40),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _logo(),
                      const SizedBox(height: 24),
                      Text(_register ? 'Create your account' : 'Welcome back',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.hankenGrotesk(
                              fontSize: 26,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.5,
                              color: AppColors.tx)),
                      const SizedBox(height: 6),
                      Text(
                          _register
                              ? 'Start running your life like a system.'
                              : 'Pick up where you left off.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 13.5, color: AppColors.tx3)),
                      const SizedBox(height: 30),
                      if (_register) ...[
                        _field(_name, 'Name', TextInputType.name),
                        const SizedBox(height: 12),
                      ],
                      _field(_email, 'Email', TextInputType.emailAddress,
                          validator: (v) =>
                              (v != null && v.contains('@')) ? null : 'Enter a valid email'),
                      const SizedBox(height: 12),
                      _field(_password, 'Password', TextInputType.text,
                          obscure: true,
                          validator: (v) => (v != null && v.length >= 6)
                              ? null
                              : 'Min 6 characters'),
                      const SizedBox(height: 8),
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          if (state.error == null) return const SizedBox(height: 8);
                          return Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 2),
                            child: Text(state.error!,
                                style: const TextStyle(
                                    color: AppColors.danger, fontSize: 12.5)),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      BlocBuilder<AuthBloc, AuthState>(
                        builder: (context, state) {
                          final busy = state.status == AuthStatus.authenticating;
                          return _primaryButton(busy);
                        },
                      ),
                      const SizedBox(height: 18),
                      TextButton(
                        onPressed: () => setState(() => _register = !_register),
                        child: RichText(
                          text: TextSpan(
                            style: TextStyle(
                                fontSize: 13, color: AppColors.tx3),
                            children: [
                              TextSpan(
                                  text: _register
                                      ? 'Already have an account?  '
                                      : "Don't have an account?  "),
                              TextSpan(
                                  text: _register ? 'Sign in' : 'Sign up',
                                  style: TextStyle(
                                      color: AppColors.accent,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _logo() => Center(
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: AppColors.accent,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(color: AppColors.accentGlow, blurRadius: 22)
                ],
              ),
              child: Center(
                child: Text('L',
                    style: GoogleFonts.hankenGrotesk(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.accentInk)),
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                style: GoogleFonts.hankenGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.tx),
                children: [
                  TextSpan(text: 'Life'),
                  TextSpan(text: 'OS', style: TextStyle(color: AppColors.accent)),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _field(TextEditingController c, String hint, TextInputType type,
      {bool obscure = false, String? Function(String?)? validator}) {
    return TextFormField(
      controller: c,
      keyboardType: type,
      obscureText: obscure,
      style: TextStyle(color: AppColors.tx, fontSize: 15),
      validator: validator,
      decoration: InputDecoration(hintText: hint),
    );
  }

  Widget _primaryButton(bool busy) => SizedBox(
        height: 52,
        child: FilledButton(
          onPressed: busy ? null : _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accent,
            foregroundColor: AppColors.accentInk,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: busy
              ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.4, color: AppColors.accentInk))
              : Text(_register ? 'Create account' : 'Sign in',
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700)),
        ),
      );
}
