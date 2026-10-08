import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_mobile/core/api/api_client.dart' show QueuedOfflineException;
import 'package:lifeos_mobile/core/api/api_exception.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/features/places/now_cubit.dart';

class _FakeRepo implements LifeRepository {
  final List<String> calls = [];
  bool offlineAnswers = false;
  bool serverDown = false;
  int loads = 0;

  Map<String, dynamic> pick(List<String> titles) => {
        'kind': 'PICK',
        'message': 'Right now: ${titles.first}.',
        'prep': <dynamic>[],
        'options': [
          for (final t in titles)
            {'sourceType': 'TASK', 'sourceId': 'id-$t', 'title': t, 'minutes': 20, 'smaller': false, 'minimum': 'Open it', 'why': 'It is next.'},
        ],
      };

  @override
  Future<Map<String, dynamic>> now({bool smallest = false, int? minutes}) async {
    loads++;
    calls.add('now(smallest=$smallest)');
    if (serverDown) throw const ApiException('offline');
    if (smallest) {
      return {
        'kind': 'PICK',
        'message': 'small',
        'prep': <dynamic>[],
        'options': [
          {'sourceType': 'TASK', 'sourceId': 'id-A', 'title': 'A', 'minutes': 2, 'smaller': true, 'minimum': 'Open the doc.', 'why': ''},
        ],
      };
    }
    return pick(['A', 'B', 'C']);
  }

  @override
  Future<String?> respondNow(String sourceType, String sourceId, String action) async {
    calls.add('respond($sourceId,$action)');
    if (offlineAnswers) throw QueuedOfflineException();
    return 'undo-$action';
  }

  @override
  Future<void> undo(String activityId) async => calls.add('undo($activityId)');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _FakeRepo repo;
  late NowCubit cubit;

  setUp(() {
    repo = _FakeRepo();
    cubit = NowCubit(repo);
  });
  tearDown(() => cubit.close());

  test('loads the card with the first option showing and the next two lined up', () async {
    await cubit.load();
    expect(cubit.state.status, NowStatus.ready);
    expect(cubit.state.current?.title, 'A');
    expect(cubit.state.later.map((o) => o.title), ['B', 'C']);
  });

  test('Done logs it, reloads, and keeps an Undo', () async {
    await cubit.load();
    await cubit.done();
    expect(repo.calls, containsAllInOrder(['respond(id-A,DONE)', 'now(smallest=false)']));
    expect(cubit.state.undoId, 'undo-DONE');
  });

  test('Not now logs a skip and moves to the next option without asking the server again', () async {
    await cubit.load();
    final loadsBefore = repo.loads;
    await cubit.notNow();
    expect(repo.calls, contains('respond(id-A,SKIP)'));
    expect(cubit.state.current?.title, 'B');
    expect(repo.loads, loadsBefore);
  });

  test('Not now on the last option asks the server for a fresh answer', () async {
    await cubit.load();
    await cubit.notNow();
    await cubit.notNow();
    final loadsBefore = repo.loads;
    await cubit.notNow();
    expect(repo.loads, loadsBefore + 1);
  });

  test('Smaller asks for the smallest version and does not log a skip', () async {
    await cubit.load();
    await cubit.smaller();
    expect(repo.calls, contains('now(smallest=true)'));
    expect(repo.calls.where((c) => c.startsWith('respond')), isEmpty);
    expect(cubit.state.current?.minutes, 2);
    expect(cubit.state.current?.smaller, isTrue);
  });

  test('offline: the answer is queued, the card says so calmly and does not error', () async {
    await cubit.load();
    repo.offlineAnswers = true;
    await cubit.done();
    expect(cubit.state.error, isNull);
    expect(cubit.state.note, contains('Saved offline'));
    expect(cubit.state.busy, isFalse);
    // It moves on by itself: A is queued as done, so B is showing.
    expect(cubit.state.current?.title, 'B');
  });

  test('server waking: the last known card stays on screen, with no scary error state', () async {
    await cubit.load();
    repo.serverDown = true;
    await cubit.load();
    expect(cubit.state.status, NowStatus.ready);
    expect(cubit.state.current?.title, 'A');
  });

  test('server down on the very first load shows the gentle fallback', () async {
    repo.serverDown = true;
    await cubit.load();
    expect(cubit.state.status, NowStatus.error);
  });

  test('Undo reverses the last answer and refreshes', () async {
    await cubit.load();
    await cubit.done();
    await cubit.undo();
    expect(repo.calls, contains('undo(undo-DONE)'));
    expect(cubit.state.undoId, isNull);
  });
}
