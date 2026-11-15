import '../../data/models/json.dart';

/// How Library describes notes and people, kept apart so it can be tested.

typedef NoteJson = Map<String, dynamic>;

const _months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];

bool isPerson(NoteJson n) => '${n['collection']}' == 'People';
bool isDiet(NoteJson n) => '${n['collection']}' == 'Diet';

List<String> itemsOf(NoteJson n) => [for (final i in (n['items'] as List? ?? const [])) '$i'];
Set<String> doneOf(NoteJson n) => {for (final i in (n['done'] as List? ?? const [])) '$i'};
String? textOf(NoteJson n) {
  final t = '${n['text'] ?? ''}'.trim();
  return t.isEmpty ? null : t;
}

/// LIST | ROUTINE | PLAYBOOK | INFO
String templateOf(NoteJson n) => '${n['template'] ?? 'INFO'}';

/// Lists and routines have ticks.
bool hasTicks(NoteJson n) => const {'LIST', 'ROUTINE'}.contains(templateOf(n));

String _count(int n, String one, String many) => '$n ${n == 1 ? one : many}';

/// "Fitness · List · 6 items, 2 ticked", "Rules · 5", "Free text".
String noteTag(NoteJson n) {
  final items = itemsOf(n);
  final kind = isDiet(n)
      ? 'Meals'
      : switch (templateOf(n)) {
          'LIST' => 'List · ${_count(items.length, 'item', 'items')}${doneOf(n).isEmpty ? '' : ', ${doneOf(n).where(items.contains).length} ticked'}',
          'ROUTINE' => 'Routine · ${_count(items.length, 'step', 'steps')}',
          'PLAYBOOK' => 'Rules · ${items.length}',
          _ => items.isNotEmpty ? _count(items.length, 'line', 'lines') : 'Free text',
        };
  final collection = '${n['collection'] ?? ''}'.trim();
  final title = '${n['title'] ?? ''}'.trim();
  final showCollection = collection.isNotEmpty && !isDiet(n) && collection.toLowerCase() != title.toLowerCase();
  return showCollection ? '$collection · $kind' : kind;
}

Json _meta(NoteJson n) => n['meta'] is Json ? n['meta'] as Json : const <String, dynamic>{};

String? phoneOfNote(NoteJson n) => asStringOrNull(_meta(n)['phone']);

/// Rules switched on to show before a matching event.
bool whenNeededOf(NoteJson n) => _meta(n)['showBefore'] == true;

DateTime? lastSpokeOf(NoteJson n) => DateTime.tryParse('${_meta(n)['lastContact'] ?? ''}')?.toLocal();

/// "3 Feb", or null.
String? birthdayOf(NoteJson n) {
  final b = _meta(n)['birthday'];
  if (b is! Json) return null;
  final m = asInt(b['month']), d = asInt(b['day']);
  if (m < 1 || m > 12 || d < 1) return null;
  return '$d ${_months[m - 1].substring(0, 3)}';
}

/// "today", "yesterday", "5 days ago", "3 weeks ago", "2 months ago".
String ago(DateTime then, DateTime now) {
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(then.year, then.month, then.day)).inDays;
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 14) return '$days days ago';
  if (days < 60) return '${days ~/ 7} weeks ago';
  return '${days ~/ 30} months ago';
}

/// "Last spoke 8 days ago · Birthday 3 Feb", or what is known.
String personLine(NoteJson n, DateTime now) {
  final last = lastSpokeOf(n);
  final bday = birthdayOf(n);
  return [
    if (last != null) 'Last spoke ${ago(last, now)}',
    if (bday != null) 'Birthday $bday',
    if (last == null && bday == null) itemsOf(n).firstOrNull ?? 'Nothing saved yet',
  ].join(' · ');
}

/// A 10-digit number with no country code is taken as Indian, like the server does.
String dialable(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (!phone.trim().startsWith('+') && digits.length == 10) return '+91$digits';
  return phone.trim().startsWith('+') ? '+$digits' : digits;
}

/// The diet as (day, meals) lines, every day first.
List<(String, String)> dietLines(NoteJson n) {
  const weekdays = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  final days = _meta(n)['days'] is Json ? _meta(n)['days'] as Json : const <String, dynamic>{};
  return [
    for (final k in const ['all', '1', '2', '3', '4', '5', '6', '0'])
      if (days[k] is Json && (days[k] as Json).isNotEmpty)
        (
          k == 'all' ? 'Every day' : weekdays[int.parse(k)],
          [for (final m in const ['breakfast', 'lunch', 'snack', 'dinner']) if ((days[k] as Json)[m] != null) '$m ${(days[k] as Json)[m]}'].join('; '),
        ),
  ];
}
