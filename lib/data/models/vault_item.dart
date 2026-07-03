import 'json.dart';

class VaultItem {
  final String id;
  final String title;
  final String content;
  final String vaultType; // QUOTE | WIN | PROTOCOL | NOTE ...
  final String mediaType; // TEXT | QUOTE | VIDEO | AUDIO | IMAGE
  final String? url;
  final List<String> triggerTags;
  final int usedCount;
  final int helpfulCount;

  const VaultItem({
    required this.id,
    required this.title,
    required this.content,
    required this.vaultType,
    this.mediaType = 'TEXT',
    this.url,
    this.triggerTags = const [],
    required this.usedCount,
    this.helpfulCount = 0,
  });

  factory VaultItem.fromJson(Json j) => VaultItem(
        id: asString(j['id']),
        title: asString(j['title']),
        content: asString(j['content']),
        vaultType: asString(j['vaultType'], 'NOTE'),
        mediaType: asString(j['mediaType'], 'TEXT'),
        url: asStringOrNull(j['url']),
        triggerTags: asStringList(j['triggerTags']),
        usedCount: asInt(j['usedCount']),
        helpfulCount: asInt(j['helpfulCount']),
      );
}
