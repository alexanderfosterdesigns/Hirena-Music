import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/player_controller.dart';
import '../audio/proxy_server.dart';
import '../audio/stream_resolver.dart';
import '../deezer/gateway.dart';
import 'app_controller.dart';

/// Deezer gateway (ARL auth + catalog + streams).
final gatewayProvider = Provider<DeezerGateway>((ref) => DeezerGateway());

/// Loopback decrypting proxy.
final proxyProvider = Provider<StreamProxyServer>((ref) {
  final gw = ref.watch(gatewayProvider);
  return StreamProxyServer(resolve: (id, q) => resolveStreamFor(gw, id, q));
});

/// Playback engine — watches this provider to rebuild on player state changes.
final playerProvider = ChangeNotifierProvider<PlayerController>(
  (ref) => PlayerController(ref.watch(proxyProvider)),
);

/// App hub (auth, settings, library, recommender, recorder).
final appControllerProvider = ChangeNotifierProvider<AppController>(
  (ref) => AppController(
    gateway: ref.watch(gatewayProvider),
    proxy: ref.watch(proxyProvider),
    player: ref.watch(playerProvider),
  ),
);
