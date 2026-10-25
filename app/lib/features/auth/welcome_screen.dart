import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../core/data/session.dart';
import '../../core/ui/theme.dart';
import '../../core/ui/widgets.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  bool _busy = false;

  Future<void> _signIn() async {
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } on GoogleSignInException catch (e) {
      if (e.code != GoogleSignInExceptionCode.canceled && mounted) {
        showSnack(context, 'Google sign-in failed. Please try again.');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Sign-in failed. Check your internet and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Center(
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: AppColors.green.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.storefront, size: 64, color: AppColors.green),
                ),
              ),
              const SizedBox(height: 28),
              Text('Kamal Bhandar', textAlign: TextAlign.center, style: t.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(
                'Order your groceries ahead and pick them up at the store.',
                textAlign: TextAlign.center,
                style: t.bodyLarge?.copyWith(color: Colors.black54),
              ),
              const Spacer(),
              FilledButton.icon(
                onPressed: _busy ? null : _signIn,
                icon: _busy
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.login),
                label: const Text('Continue with Google'),
              ),
              const SizedBox(height: 12),
              Text(
                'New customers fill a short form after signing in. The store approves every account.',
                textAlign: TextAlign.center,
                style: t.bodySmall?.copyWith(color: Colors.black54),
              ),
              TextButton(onPressed: () => context.push('/policy'), child: const Text('Privacy policy')),
            ],
          ),
        ),
      ),
    );
  }
}
