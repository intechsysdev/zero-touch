import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/state/auth_controller.dart';
import 'features/home/presentation/home_screen.dart';

class ZeroTouchApp extends ConsumerWidget {
  const ZeroTouchApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return MaterialApp(
      title: 'ZeroTouch Intechsys',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: authState.when(
        data: (session) {
          if (session == null) {
            return const LoginScreen();
          }
          return HomeScreen(session: session);
        },
        loading: () => const _LoadingScreen(),
        error: (error, _) => LoginScreen(errorMessage: error.toString()),
      ),
    );
  }
}

class _LoadingScreen extends StatelessWidget {
  const _LoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
