import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';

/// Shared access layout from Irlanda's auth-gate, with native scrolling,
/// autofill, keyboard avoidance and accessible controls.
class AuthFrame extends StatelessWidget {
  const AuthFrame({
    super.key,
    required this.child,
    this.footer,
    this.back = true,
    this.onBack,
    this.accountLink = false,
  });
  final Widget child;
  final Widget? footer;
  final bool back, accountLink;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(
        colorScheme: theme.colorScheme.copyWith(
          primary: ink,
          onPrimary: Colors.white,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: ink,
            foregroundColor: Colors.white,
            minimumSize: const Size.fromHeight(52),
            shape: const StadiumBorder(),
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: ink),
        ),
      ),
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(28, 24, 28, 28),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (back)
                                IconButton(
                                  tooltip: 'Volver',
                                  icon: const Icon(Icons.arrow_back_rounded),
                                  onPressed:
                                      onBack ??
                                      () {
                                        if (context.canPop()) {
                                          context.pop();
                                        } else {
                                          context.go('/welcome');
                                        }
                                      },
                                ),
                              const Brand(),
                              if (accountLink)
                                TextButton(
                                  onPressed: () => context.push('/login'),
                                  child: const Text('Ya tengo cuenta'),
                                ),
                            ],
                          ),
                          SizedBox(height: accountLink ? 8 : 28),
                          child,
                        ],
                      ),
                      if (footer != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 24),
                          child: footer!,
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthHeading extends StatelessWidget {
  const AuthHeading(this.title, this.description, {super.key});
  final String title, description;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      Semantics(
        header: true,
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineLarge,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        description,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, height: 1.5, color: muted),
      ),
      const SizedBox(height: 22),
    ],
  );
}
