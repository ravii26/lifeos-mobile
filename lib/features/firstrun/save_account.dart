import 'package:flutter/material.dart';

import '../../core/api/api_exception.dart';
import '../../data/models/user.dart';
import '../../design/components.dart';
import '../../design/tokens.dart';
import '../../design/type.dart';

typedef Claim = Future<AppUser> Function({required String name, required String email, required String password});

/// "Save your account": name, email and a password, so the plan is kept
/// if the phone is lost. Everything made so far stays.
class SaveAccountForm extends StatefulWidget {
  final Claim claim;
  final ValueChanged<AppUser> onSaved;

  /// Shown as "Later" when given.
  final VoidCallback? onLater;
  const SaveAccountForm({super.key, required this.claim, required this.onSaved, this.onLater});

  @override
  State<SaveAccountForm> createState() => _SaveAccountFormState();
}

class _SaveAccountFormState extends State<SaveAccountForm> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    for (final c in [_name, _email, _password]) {
      c.addListener(() => setState(() {}));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  bool get _emailOk => RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(_email.text.trim());
  bool get _ready => _name.text.trim().isNotEmpty && _emailOk && _password.text.length >= 8 && !_busy;

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await widget.claim(name: _name.text.trim(), email: _email.text.trim(), password: _password.text);
      if (mounted) widget.onSaved(user);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.ac;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('Save your plan', style: AllyType.h1(color: c.ink)),
      const SizedBox(height: Sp.x1),
      Text('So it is kept if you change or lose this phone. Everything so far stays.', style: AllyType.body(color: c.muted)),
      const SizedBox(height: Sp.x5),
      TextField(
        controller: _name,
        textCapitalization: TextCapitalization.words,
        autofillHints: const [AutofillHints.name],
        style: AllyType.body(color: c.ink),
        decoration: const InputDecoration(labelText: 'Your name'),
      ),
      const SizedBox(height: Sp.x3),
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
        autofillHints: const [AutofillHints.newPassword],
        style: AllyType.body(color: c.ink),
        decoration: const InputDecoration(labelText: 'Password', helperText: 'At least 8 characters'),
      ),
      const SizedBox(height: Sp.x4),
      if (_error != null) ...[AllyNote(_error!), const SizedBox(height: Sp.x3)],
      AllyButton(_busy ? 'Saving…' : 'Save my account', wide: true, onPressed: _ready ? _save : null),
      if (widget.onLater != null) ...[
        const SizedBox(height: Sp.x2),
        AllyButton('Later', kind: AllyButtonKind.ghost, wide: true, onPressed: _busy ? null : widget.onLater),
        Text('You can save it any time from You.', textAlign: TextAlign.center, style: AllyType.small(color: c.faint)),
      ],
    ]);
  }
}
