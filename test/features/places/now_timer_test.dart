import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeos_mobile/features/places/now_screen.dart';
import 'package:lifeos_mobile/features/places/timer_screen.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('clock', () {
    test('shows minutes and seconds', () {
      expect(clockText(const Duration(minutes: 24, seconds: 18)), '24:18');
      expect(clockText(const Duration(seconds: 5)), '00:05');
      expect(clockText(const Duration(minutes: 90)), '90:00');
    });

    test('never goes below zero', () {
      expect(clockText(const Duration(seconds: -3)), '00:00');
    });
  });

  group('Now wording', () {
    test('long tasks get smaller type', () {
      expect(nowTitleSize('One DSA problem'), 46);
      expect(nowTitleSize('Update resume with my last project'), 38);
      expect(nowTitleSize('Finish the quarterly budget report before the review meeting'), 31);
      expect(nowTitleSize('Finish the quarterly budget report and send it to Rakesh before Thursday meeting'), 26);
    });

    test('the greeting follows the hour', () {
      expect(nowGreeting(DateTime(2026, 11, 10, 8)), contains('morning'));
      expect(nowGreeting(DateTime(2026, 11, 10, 19)), contains('Long day'));
      expect(nowGreeting(DateTime(2026, 11, 10, 23)), 'Last thing tonight.');
      expect(nowGreeting(DateTime(2026, 11, 10, 19), lowEnergy: true), contains('Easy day'));
    });
  });

  group('timer screen', () {
    Future<NavigatorState> open(WidgetTester tester, void Function(TimerResult?) done, {Size size = const Size(360, 640)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final key = GlobalKey<NavigatorState>();
      await tester.pumpWidget(MaterialApp(navigatorKey: key, home: const SizedBox()));
      key.currentState!
          .push<TimerResult>(MaterialPageRoute(builder: (_) => const TimerScreen(title: 'One DSA problem', minutes: 30, firstStep: 'Read one problem')))
          .then(done);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      return key.currentState!;
    }

    testWidgets('fits a small phone and reports Finished', (tester) async {
      TimerResult? result;
      await open(tester, (r) => result = r);
      expect(tester.takeException(), isNull);
      expect(find.text('30:00'), findsOneWidget);
      await tester.tap(find.text('Finished'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(result, TimerResult.finished);
    });

    testWidgets('pausing stops the clock and offers Resume', (tester) async {
      await open(tester, (_) {});
      await tester.tap(find.text('Pause'));
      await tester.pump();
      expect(find.text('Resume'), findsOneWidget);
      expect(find.text('paused'), findsOneWidget);
      await tester.tap(find.text('Resume'));
      await tester.pump();
      await tester.tap(find.byTooltip('Leave the timer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    });

    testWidgets("I'm stuck is reported, and leaving reports nothing", (tester) async {
      TimerResult? result = TimerResult.finished;
      await open(tester, (r) => result = r);
      await tester.tap(find.byTooltip('Leave the timer'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(result, isNull);

      TimerResult? second;
      await open(tester, (r) => second = r);
      await tester.tap(find.text("I'm stuck"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(second, TimerResult.stuck);
    });
  });
}
