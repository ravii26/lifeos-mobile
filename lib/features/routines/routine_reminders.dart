import '../../core/notifications/notification_service.dart';
import '../../data/repositories/life_repository.dart';

/// After a routine changes, the phone's reminders follow. Best effort: the
/// change is already saved, so a failure here is not the person's problem.
Future<void> syncRoutineReminders(LifeRepository repo) async {
  try {
    NotificationService.instance.syncHabitReminders(await repo.habits(activeOnly: true));
  } catch (_) {}
}
