# AGENTS.md: lifeos_mobile (Ally app)

> The main client of **Ally**, a personal assistant app (formerly LifeOS; package and code names keep `lifeos`).
> **What is built and what is next: `../ALLY.md` (the single source of truth; it wins over this file).** Branch: **`lifeos-2.0`**.

## Commands
```bash
flutter pub get
flutter analyze lib                      # 0 errors / warnings required (info-level legacy hints exist)
flutter run --dart-define=API_BASE_URL=http://<LAN-IP>:3000/api/v1   # against a local server
flutter build apk --release              # default API = Render (lib/core/config/app_config.dart)
```
Always verify a **release** build on a real phone (`docs/runbooks/mobile-release.md`). R8 issues only appear in release.

## Stack
Flutter / Dart 3 · `flutter_bloc` (Cubits) · `get_it` · Dio · `flutter_local_notifications` + `timezone` · `receive_sharing_intent` ·
`home_widget` + `workmanager` · `speech_to_text` · `google_fonts` · `shared_preferences`.

## Layout
```
lib/
  main.dart                     app root, auth gate, providers (Auth, Appearance, Decisions)
  core/
    api/                        api_client.dart (envelope, errors, offline cache + queue), offline_store.dart, token_store.dart
    notifications/              notification_service.dart (habit reminders, chat reminders, opt-in nudges, action buttons)
    share/ intents/ deeplink/   share sheet → save flow, capture intents, lifeos:// links
    widget/                     home-screen widget sync (WorkManager)
    di/ config/ theme/
  data/models/                  plain models with fromJson (json.dart helpers)
  data/repositories/            life_repository.dart: every API call lives here
  design/                       the design system: tokens.dart (AllyColors, Sp, Rad, Motion), type.dart, components.dart,
                                rings.dart, appearance.dart (theme, larger text, reduce motion)
  features/
    shell/home_shell.dart       bottom bar Today · Areas · + (Talk) · Week · You; provides LifeCubit, TonightCubit, NowCubit, ChatCubit
    firstrun/                   welcome (Get started as a guest), first run (5 steps), save account, the gate in main.dart
    today/ session/ areas/ week/ routines/ talk/ library/ you/    the new-look screens
    chat/                       ChatCubit (actions, undo, offline retry) used by talk/; the old chat screen is unreachable
    places/ guide/ more/ …      older screens, some still opened from You until rebuilt
```
Old screens are removed as the new ones replace them (ALLY.md section 6 lists each). Build only what ALLY.md lists.

## Launch (keep it instant)
The app opens from the cached account (`AuthRepository.cachedUser`, wiped on sign-out) and checks `/auth/me` behind it;
only a 401 signs out. Now shows the phone's copy of `/now` if it is from today and under 3 h old, then the live answer.
Notifications and the widget start after `runApp`; `NotificationService` waits for its own init instead of skipping work.
Never put a network call or plugin setup back in front of the first frame.

## Conventions
- **All network calls go through `LifeRepository`** → `ApiClient`. Screens never use Dio directly.
- Cubits own state (`Equatable` states with `copyWith`). Catch `ApiException`; show `e.message`.
- **Offline:** reads in `OfflineStore.cachedPaths` are cached automatically. Small mutations use
  `queueOffline: true` and must handle `QueuedOfflineException` optimistically (see `TonightCubit.respond`).
- **Undo:** server responses carry `activityId`; offer Undo via `LifeRepository.undo(activityId)`.
- **Notifications:** reminders are what the person asked for; what Ally starts itself is proactive by default with Normal / Quieter / Silent (ADR 0027, replaces the opt-in rule of ADR 0006). Id ranges: habits `& 0x3fffffff`,
  chat reminders `0x40000000 | …` (each upcoming time of a repeat has its own id), nightly `9000` / morning `9001` (retired, only cleared), prep `9002`, test `9003`, **agenda `9100`–`9119`** (briefing, slot nudges, wrap-up, Sunday review from `GET /now/agenda`, ADR 0027), reminder follow-ups in the reminder range. Refresh the agenda with `AgendaSync.now()` / `.soon()` after anything that changes the day.
  Reminders are exact alarms when allowed and the next 7 times come from the server (ADR 0024); You → Reminders checks permissions.
- **First use:** "Get started" makes a guest account (`POST /auth/guest`); first run saves as it goes and the account is saved
  last (`POST /auth/claim`). Permissions are asked when first needed, with the reason. `talkPrefill.value = '…'` opens Talk with words started.
- User-visible name is **Ally**. Never change `applicationId` / bundle ids.
- New screens use `lib/design/` only (`context.ac` colours, `AllyType`, `Sp`, components), wrapped in
  `Theme(data: AllyAppearance.themeOf(context))`. `G` / `guide_style.dart` is the old plum look: don't use it in new code.
  A screen is done only with loading, empty, offline and error states, widget tests, and a 320×640 at 1.5× text check.

## Android release essentials
`android/app/proguard-rules.pro` keeps WorkManager/Room and Gson classes. Removing it crashes the app on start.
`AndroidManifest.xml` declares the flutter_local_notifications receivers (scheduled, boot, action). Keep them.
