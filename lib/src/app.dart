import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:loader_overlay/loader_overlay.dart';
import 'package:silence_remover/src/router/router.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Creates a GoRouter with all the app routes, and adding a loading overlay.
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        ShellRoute(
          builder: (context, state, child) {
            return Scaffold(body:child);
          },
          routes: $appRoutes,
        ),
      ],
    );
    return GlobalLoaderOverlay(
      child:
      MaterialApp.router(
        routerConfig: router,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        ),
      )
    );
  }
}
