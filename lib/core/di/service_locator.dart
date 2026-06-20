import 'package:get_it/get_it.dart';

import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/life_repository.dart';
import '../api/api_client.dart';
import '../api/token_store.dart';

final getIt = GetIt.instance;

/// Wire up singletons. Call once before runApp().
Future<void> setupLocator() async {
  final tokens = TokenStore();
  await tokens.read(); // warm the in-memory cache for the interceptor

  getIt.registerSingleton<TokenStore>(tokens);
  getIt.registerSingleton<ApiClient>(ApiClient(tokens));

  getIt.registerSingleton<AuthRepository>(
      AuthRepository(getIt<ApiClient>(), tokens));
  getIt.registerSingleton<LifeRepository>(LifeRepository(getIt<ApiClient>()));
}
