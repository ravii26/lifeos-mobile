import 'json.dart';

class VaultItem {
  final String id;
  final String title;
  final String content;
  final String vaultType; // QUOTE | WIN | PROTOCOL | NOTE ...
  final String? url;
  final List<String> triggerTags;
  final int usedCount;

  const VaultItem({
    required this.id,
    required this.title,
    required this.content,
    required this.vaultType,
    this.url,
    this.triggerTags = const [],
    required this.usedCount,
  });

  factory VaultItem.fromJson(Json j) => VaultItem(
        id: asString(j['id']),
        title: asString(j['title']),
        content: asString(j['content']),
        vaultType: asString(j['vaultType'], 'NOTE'),
        url: asStringOrNull(j['url']),
        triggerTags: asStringList(j['triggerTags']),
        usedCount: asInt(j['usedCount']),
      );
}
