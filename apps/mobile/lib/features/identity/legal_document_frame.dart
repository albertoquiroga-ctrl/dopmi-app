import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/design_tokens.dart';
import '../../core/ui.dart';

class LegalDocumentFrame extends StatelessWidget {
  const LegalDocumentFrame({
    super.key,
    required this.title,
    required this.lead,
    required this.children,
  });
  final String title, lead;
  final List<Widget> children;
  void back(BuildContext context) {
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go('/signup');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 393),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 28, 28, 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 40,
                  child: Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Positioned(
                        left: -10,
                        top: 0,
                        child: SizedBox(
                          width: 40,
                          height: 40,
                          child: IconButton(
                            tooltip: 'Volver',
                            padding: EdgeInsets.zero,
                            onPressed: () => back(context),
                            icon: SvgPicture.asset(
                              'assets/profile/back.svg',
                              width: 24,
                              height: 24,
                            ),
                          ),
                        ),
                      ),
                      const Positioned(left: 32, top: 2, child: Brand()),
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 20, bottom: 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth:
                                  262.836 *
                                  MediaQuery.textScalerOf(context).scale(28) /
                                  28,
                            ),
                            child: Semantics(
                              header: true,
                              child: _LegalTitle(title),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth:
                                  262.4375 *
                                  MediaQuery.textScalerOf(context).scale(13) /
                                  13,
                            ),
                            child: Text(
                              lead,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: muted,
                                letterSpacing: 0,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        for (var i = 0; i < children.length; i++) ...[
                          if (i > 0) const SizedBox(height: 16),
                          children[i],
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: ink,
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: const StadiumBorder(),
                  ),
                  onPressed: () => back(context),
                  child: const Text(
                    'Entendido',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _LegalTitle extends StatelessWidget {
  const _LegalTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const style = TextStyle(
        fontFamily: DopmiTokens.displayFont,
        fontVariations: DopmiTokens.display28Variations,
        fontSize: 28,
        height: 1.15,
        letterSpacing: -.56,
        fontWeight: FontWeight.w600,
        color: ink,
      );
      final requested = MediaQuery.textScalerOf(context).scale(28) / 28;
      var scale = requested;
      // Keep each word intact on narrow screens with enlarged text. Body text
      // retains the user's full scale; only the headline fits its longest word.
      for (final word in title.split(' ')) {
        final painter = TextPainter(
          text: TextSpan(text: word, style: style),
          textDirection: Directionality.of(context),
          textScaler: TextScaler.linear(requested),
        )..layout();
        if (painter.width > constraints.maxWidth) {
          final fit = requested * constraints.maxWidth / painter.width;
          if (fit < scale) scale = fit;
        }
        painter.dispose();
      }
      return Text(
        title,
        style: style,
        textAlign: TextAlign.center,
        textScaler: TextScaler.linear(scale),
      );
    },
  );
}

class LegalDocumentSection extends StatelessWidget {
  const LegalDocumentSection(this.title, this.body, {super.key, this.footer});
  final String title, body;
  final Widget? footer;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: DopmiTokens.line),
      borderRadius: BorderRadius.circular(18),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          header: true,
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              height: 1.3,
              fontWeight: FontWeight.w700,
              color: ink,
              letterSpacing: 0,
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          body,
          style: const TextStyle(
            fontSize: 13,
            height: 1.55,
            color: muted,
            letterSpacing: 0,
          ),
        ),
        if (footer != null) ...[const SizedBox(height: 6), footer!],
      ],
    ),
  );
}
