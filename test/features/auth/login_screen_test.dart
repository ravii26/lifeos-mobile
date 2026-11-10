import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/features/auth/bloc/auth_bloc.dart';
import 'package:lifeos_mobile/features/auth/login_screen.dart';

class _Bloc extends Cubit<AuthState> implements AuthBloc {
  _Bloc() : super(const AuthState());

  @override
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('welcome leads to sign-up and sign-in, on a small phone', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(MaterialApp(home: BlocProvider<AuthBloc>(create: (_) => _Bloc(), child: const LoginScreen())));
    expect(find.text('Too much on your mind?'), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.tap(find.text('Get started'));
    await t.pump();
    expect(find.text('Create my account'), findsOneWidget);
    expect(find.text('Name'), findsOneWidget);
    expect(t.takeException(), isNull);

    await t.tap(find.text('I already have an account'));
    await t.pump();
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Name'), findsNothing);
  });
}
