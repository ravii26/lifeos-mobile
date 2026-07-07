import 'package:get_it/get_it.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/life_repository.dart';
import '../api/api_client.dart';
import '../api/token_store.dart';
import '../widget/widget_sync_service.dart';

final getIt = GetIt.instance;

/// Wire up singletons. Call once before runApp() (and again, independently,
/// in each headless background isolate the widget spawns).
Future<void> setupLocator() async {
  final tokens = TokenStore();
  await tokens.read(); // warm the in-memory cache for the interceptor

  getIt.registerSingleton<TokenStore>(tokens);
  getIt.registerSingleton<ApiClient>(ApiClient(tokens));

  getIt.registerSingleton<AuthRepository>(
      AuthRepository(getIt<ApiClient>(), tokens));
  getIt.registerSingleton<LifeRepository>(LifeRepository(getIt<ApiClient>()));
  getIt.registerSingleton<WidgetSyncService>(
      WidgetSyncService(getIt<LifeRepository>()));
}
