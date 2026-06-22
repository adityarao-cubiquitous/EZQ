import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router.dart';
import 'theme.dart';

class EzqApp extends ConsumerWidget {
  const EzqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'EZQ by Cubiquitous',
      debugShowCheckedModeBanner: false,
      theme: EzqTheme.light(),
      routerConfig: router,
    );
  }
}
