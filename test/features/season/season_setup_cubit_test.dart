import 'package:flutter_test/flutter_test.dart';
import 'package:lifeos_mobile/data/models/season.dart';
import 'package:lifeos_mobile/data/repositories/life_repository.dart';
import 'package:lifeos_mobile/features/season/season_setup_cubit.dart';

class _FakeRepo implements LifeRepository {
  _FakeRepo(this.json);
  final Map<String, dynamic> json;
  Map<String, dynamic>? started;
  bool? startedSame;
  Map<String, DateTime?> parkedUntil = {};

  @override
  Future<SeasonData> season() async => SeasonData.fromJson(json);

  @override
  Future<({SeasonData data, String? activityId})> startSeason({
    String? name,
    DateTime? endsAt,
    String? endEvent,
    required List<String> focusIds,
    List<String> keepGoingIds = const [],
    List<({String areaId, DateTime? until})> parked = const [],
    bool sameSeason = false,
  }) async {
    started = {'name': name, 'endEvent': endEvent, 'focus': focusIds, 'keep': keepGoingIds, 'parked': parked.map((p) => p.areaId).toList()};
    startedSame = sameSeason;
    parkedUntil = {for (final p in parked) p.areaId: p.until};
    return (data: SeasonData.fromJson(json), activityId: 'act-1');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnimplementedError(invocation.memberName.toString());
}

Map<String, dynamic> _data({List<Map<String, dynamic>>? areas, Map<String, dynamic>? season}) => {
      'season': season,
      'areas': areas ??
          [
            {'id': 'career', 'name': 'Career', 'tier': 'MAINTAIN', 'weeklyMinutes': 480},
            {'id': 'fitness', 'name': 'Fitness', 'tier': 'MAINTAIN', 'weeklyMinutes': 180},
            {'id': 'english', 'name': 'English', 'tier': 'MAINTAIN', 'weeklyMinutes': 120},
            {'id': 'money', 'name': 'Money', 'tier': 'MAINTAIN', 'weeklyMinutes': 0},
            {'id': 'music', 'name': 'Music', 'tier': 'MAINTAIN', 'weeklyMinutes': 60},
            {'id': 'business', 'name': 'Business', 'tier': 'MAINTAIN', 'weeklyMinutes': 30},
          ],
      'places': {'focus': [], 'keepGoing': [], 'background': [], 'parked': []},
      'caps': {'MAIN': 2, 'SECONDARY': 3},
      'freeMinutes': 660,
    };

void main() {
  test('first season: explainer first, biggest two pre-selected for focus, guesses marked', () async {
    final cubit = SeasonSetupCubit(_FakeRepo(_data()));
    await cubit.load();
    final s = cubit.state;
    expect(s.step, SetupStep.explain);
    expect(s.idsIn(Place.focus), ['career', 'fitness']);
    expect(s.idsIn(Place.keepGoing), ['english', 'money', 'music']);
    expect(s.idsIn(Place.background), ['business']);
    expect(s.guessed, {'money'}); // nothing planned, so 2 h is Ally's guess
    expect(s.minutes['money'], guessMinutes);
    expect(s.freeMinutes, 660);
  });

  test('a third focus asks which one makes room, and the one moved out is parked', () async {
    final cubit = SeasonSetupCubit(_FakeRepo(_data()));
    await cubit.load();
    cubit.place('english', Place.focus);
    expect(cubit.state.swapFor, 'english');
    expect(cubit.state.idsIn(Place.focus), ['career', 'fitness']); // nothing changed silently
    cubit.swap('fitness');
    expect(cubit.state.idsIn(Place.focus), ['career', 'english']);
    expect(cubit.state.places['fitness'], Place.parked);
    expect(cubit.state.swapFor, isNull);
  });

  test('an existing season keeps its places and skips the explainer', () async {
    final cubit = SeasonSetupCubit(_FakeRepo(_data(
      areas: [
        {'id': 'a', 'name': 'A', 'tier': 'MAIN', 'weeklyMinutes': 60},
        {'id': 'b', 'name': 'B', 'tier': 'LATER', 'weeklyMinutes': 60},
      ],
      season: {'number': 1, 'name': 'Switch & Shape', 'startedAt': '2026-11-16T00:00:00Z', 'week': 2, 'weeks': 10, 'line': 'x'},
    )));
    await cubit.load();
    expect(cubit.state.step, SetupStep.areas);
    expect(cubit.state.places, {'a': Place.focus, 'b': Place.parked});
    expect(cubit.name, 'Switch & Shape');
  });

  test('start sends each place and finishes with an Undo id', () async {
    final repo = _FakeRepo(_data());
    final cubit = SeasonSetupCubit(repo);
    await cubit.load();
    cubit.place('business', Place.parked);
    cubit.name = 'Switch & Shape';
    cubit.endEvent = 'when I switch jobs';
    await cubit.start();
    expect(repo.started, {
      'name': 'Switch & Shape',
      'endEvent': 'when I switch jobs',
      'focus': ['career', 'fitness'],
      'keep': ['english', 'money', 'music'],
      'parked': ['business'],
    });
    expect(cubit.state.status, SetupStatus.started);
    expect(cubit.state.undoId, 'act-1');
  });

  final running = {'number': 1, 'name': 'Switch & Shape', 'startedAt': '2026-11-16T00:00:00Z', 'week': 4, 'weeks': 10, 'line': 'x'};
  final runningAreas = [
    {'id': 'career', 'name': 'Career', 'tier': 'MAIN', 'weeklyMinutes': 480},
    {'id': 'fitness', 'name': 'Fitness', 'tier': 'MAIN', 'weeklyMinutes': 180},
    {'id': 'english', 'name': 'English', 'tier': 'SECONDARY', 'weeklyMinutes': 120},
    {'id': 'music', 'name': 'Music', 'tier': 'LATER', 'weeklyMinutes': 60},
  ];

  test('changing a running season keeps it, and keeps parked return dates', () async {
    final data = _data(areas: runningAreas, season: running)
      ..['places'] = {
        'focus': [],
        'keepGoing': [],
        'background': [],
        'parked': [
          {'id': 'music', 'name': 'Music', 'until': '2027-03-01T00:00:00.000Z'},
        ],
      };
    final repo = _FakeRepo(data);
    final cubit = SeasonSetupCubit(repo);
    await cubit.load();
    expect(cubit.editing, isTrue);
    expect(cubit.number, 1); // same chapter, not Season 2
    await cubit.start();
    expect(repo.startedSame, isTrue);
    expect(repo.parkedUntil['music'], DateTime.utc(2027, 3, 1));
  });

  test('from the season review: next season picks, a fresh name, Season 2', () async {
    final repo = _FakeRepo(_data(areas: runningAreas, season: running));
    final cubit = SeasonSetupCubit(repo, next: (focusIds: ['fitness', 'music'], keepGoingIds: ['career', 'english']));
    await cubit.load();
    expect(cubit.editing, isFalse);
    expect(cubit.number, 2);
    expect(cubit.name, ''); // a new chapter gets its own name
    expect(cubit.state.step, SetupStep.areas); // no explainer the second time
    expect(cubit.state.idsIn(Place.focus), ['fitness', 'music']);
    expect(cubit.state.idsIn(Place.keepGoing), ['career', 'english']);
    await cubit.start();
    expect(repo.startedSame, isFalse);
  });
}
