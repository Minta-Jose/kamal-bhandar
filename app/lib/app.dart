import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'core/data/messaging.dart';
import 'core/data/session.dart';
import 'core/ui/theme.dart';
import 'core/ui/widgets.dart';
import 'router.dart';

class KamalBhandarApp extends ConsumerStatefulWidget {
  const KamalBhandarApp({super.key});

  @override
  ConsumerState<KamalBhandarApp> createState() => _KamalBhandarAppState();
}

class _KamalBhandarAppState extends ConsumerState<KamalBhandarApp> {
  StreamSubscription<String>? _taps;

  @override
  void initState() {
    super.initState();
    _taps = Messaging.instance.taps.listen((route) => ref.read(routerProvider).go(route));
  }

  @override
  void dispose() {
    _taps?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Every signed-in phone registers for notifications (owner and customers).
    ref.listen(currentUidProvider, (_, uid) {
      if (uid != null) Messaging.instance.register(uid);
    });
    final minVersion = ref.watch(settingsProvider).value?.minAppVersion ?? 0;
    final build = ref.watch(_buildNumberProvider).value ?? 0;
    return MaterialApp.router(
      title: 'Kamal Bhandar',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => build > 0 && build < minVersion ? const _UpdateNeeded() : child!,
    );
  }
}

final _buildNumberProvider = FutureProvider<int>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return int.tryParse(info.buildNumber) ?? 0;
});

/// Shown when the store has set a minimum app version newer than this one.
class _UpdateNeeded extends StatelessWidget {
  const _UpdateNeeded();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: EmptyState(
        icon: Icons.system_update,
        title: 'Please update the app',
        message: 'This version is too old. Ask the store for the new Kamal Bhandar app and install it over this one.',
      ),
    );
  }
}
