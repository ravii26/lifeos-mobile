import 'json.dart';

class AppUser {
  final String id;
  final String email;
  final String name;
  final String? timezone;

  /// Started with "Get started" and not saved with an email yet.
  final bool guest;

  const AppUser({
    required this.id,
    required this.email,
    required this.name,
    this.timezone,
    this.guest = false,
  });

  /// First name for greetings; first initial for the avatar.
  String get firstName => name.trim().split(' ').first;
  String get initial => name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

  /// Kept on the phone so the app can open signed in without waiting for the server.
  Json toJson() => {'id': id, 'email': email, 'name': name, if (timezone != null) 'timezone': timezone, if (guest) 'guest': true};

  bool sameAs(AppUser o) => id == o.id && email == o.email && name == o.name && timezone == o.timezone && guest == o.guest;

  factory AppUser.fromJson(Json j) => AppUser(
        id: asString(j['id']),
        email: asString(j['email']),
        name: asString(j['name'], 'Friend'),
        timezone: asStringOrNull(j['timezone']),
        guest: asBool(j['guest']),
      );
}
