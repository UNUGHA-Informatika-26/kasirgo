import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'auth/cubit/auth_cubit.dart';
import 'auth/cubit/auth_state.dart';
import 'auth/login_pages.dart';
import 'features/home/pages/home_page.dart';
import 'shared/services/supabase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await SupabaseService.init();
  } catch (e) {
    debugPrint('Supabase Service Warning: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(),
      child: MaterialApp(
        title: 'KasirGo',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF2563EB),
            primary: const Color(0xFF2563EB),
          ),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
      ),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _openInitialPage();
  }

  Future<void> _openInitialPage() async {
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) context.read<AuthCubit>().restoreSession();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listenWhen: (previous, current) =>
          current.operation == AuthOperation.restore &&
          current.status != AuthStatus.loading,
      listener: (context, state) {
        final Widget page;
        if (state.status == AuthStatus.authenticated) {
          page = const HomePage();
        } else if (state.status == AuthStatus.failure) {
          page = LoginPages(
            initialMessage: 'Gagal memulihkan sesi: ${state.message}',
          );
        } else {
          page = const LoginPages();
        }
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => page),
        );
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/splash.png',
                height: 180,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(
                    Icons.shopping_cart_outlined,
                    size: 100,
                    color: Color(0xFF2563EB),
                  );
                },
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: Color(0xFF2563EB)),
            ],
          ),
        ),
      ),
    );
  }
}
