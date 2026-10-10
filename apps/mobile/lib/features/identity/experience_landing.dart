import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import 'experience_controller.dart';
import 'identity_controller.dart';

/// Resolve the account's presentation preference only for an ordinary entry.
/// Explicit deep links retain their destination and do not wait for this page.
class ExperienceLandingScreen extends ConsumerStatefulWidget {
  const ExperienceLandingScreen({super.key});
  @override
  ConsumerState<ExperienceLandingScreen> createState() =>
      _ExperienceLandingState();
}

class _ExperienceLandingState extends ConsumerState<ExperienceLandingScreen> {
  bool scheduled = false;
  @override
  Widget build(BuildContext context) {
    final experience = ref.watch(experienceProvider);
    return ListenableBuilder(
      listenable: experience,
      builder: (context, _) {
        if (!experience.loading && !scheduled) {
          scheduled = true;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            final identity = ref.read(identityControllerProvider);
            if (identity.identity?.verified == true && !identity.recovering) {
              context.go(
                experience.value == AccountExperience.rescuer
                    ? '/rescuer'
                    : '/adoptions',
              );
            }
          });
        }
        return const PageFrame(
          back: false,
          children: [
            Center(
              child: CircularProgressIndicator(
                semanticsLabel: 'Preparando tu inicio',
              ),
            ),
          ],
        );
      },
    );
  }
}
