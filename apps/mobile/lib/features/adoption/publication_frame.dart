import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'community_ui.dart';

class PublicationFrame extends StatelessWidget {
  const PublicationFrame({
    super.key,
    required this.title,
    required this.step,
    required this.children,
    required this.footer,
    required this.onBack,
  });
  final String title;
  final int step;
  final List<Widget> children;
  final Widget footer;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final header = _PublicationHeader(title: title, step: step, onBack: onBack);
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: keyboard
          ? null
          : const CommunityNav(3, selectedPath: '/publish'),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (!keyboard) header,
            Expanded(
              child: ListView(
                key: const PageStorageKey('publication-body'),
                padding: EdgeInsets.zero,
                children: [
                  // Let the focused field scroll the header away on short keyboard
                  // viewports; controllers and the keyed Form retain authored text.
                  if (keyboard) header,
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: children,
                    ),
                  ),
                ],
              ),
            ),
            footer,
          ],
        ),
      ),
    );
  }
}

class _PublicationHeader extends StatelessWidget {
  const _PublicationHeader({
    required this.title,
    required this.step,
    required this.onBack,
  });
  final String title;
  final int step;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xffe3e4ed))),
    ),
    child: Column(
      children: [
        Semantics(
          button: true,
          label: 'Volver',
          enabled: onBack != null,
          child: TextButton(
            onPressed: onBack,
            style:
                TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: Size.zero,
                  splashFactory: NoSplash.splashFactory,
                ).copyWith(
                  overlayColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: SvgPicture.asset(
                      'assets/profile/back.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 24,
                          height: 32 / 24,
                          fontWeight: FontWeight.w700,
                          color: Color(0xff151423),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        PublicationStepper(step: step),
      ],
    ),
  );
}

class PublicationStepper extends StatelessWidget {
  const PublicationStepper({super.key, required this.step});
  final int step;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Paso ${step + 1} de 3',
    child: ExcludeSemantics(
      child: Row(
        children: [
          for (var index = 0; index < 3; index++) ...[
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: index <= step
                    ? const Color(0xff7c3aed)
                    : const Color(0xfff0eff8),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  fontSize: 14,
                  height: 1,
                  fontWeight: FontWeight.w700,
                  color: index <= step ? Colors.white : const Color(0xff616174),
                ),
              ),
            ),
            if (index < 2)
              Expanded(
                child: Container(
                  height: 2,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: index < step
                        ? const Color(0xff7c3aed)
                        : const Color(0xfff0eff8),
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
          ],
        ],
      ),
    ),
  );
}

class PublicationFooter extends StatelessWidget {
  const PublicationFooter({
    super.key,
    required this.label,
    required this.onContinue,
    this.onSave,
    this.busy = false,
    this.compact = false,
  });
  final String label;
  final VoidCallback? onContinue, onSave;
  final bool busy, compact;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(top: BorderSide(color: Color(0xffe3e4ed))),
      boxShadow: [
        BoxShadow(
          color: Color(0x0d000000),
          blurRadius: 10,
          offset: Offset(0, -2),
        ),
      ],
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: busy ? null : onContinue,
          style:
              FilledButton.styleFrom(
                backgroundColor: const Color(0xff7841f2),
                foregroundColor: const Color(0xfffbfbff),
                disabledBackgroundColor: const Color(0xfff2f2f2),
                disabledForegroundColor: const Color(0xffc5c5c5),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                splashFactory: NoSplash.splashFactory,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ).copyWith(
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
                backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.disabled)
                      ? const Color(0xfff2f2f2)
                      : states.contains(WidgetState.hovered)
                      ? const Color(0xff6d28d9)
                      : const Color(0xff7841f2),
                ),
              ),
          child: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    semanticsLabel: 'Guardando publicación',
                  ),
                )
              : Text(
                  label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.2,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
        if (onSave != null && !compact) ...[
          const SizedBox(height: 8),
          TextButton(
            onPressed: busy ? null : onSave,
            style:
                TextButton.styleFrom(
                  foregroundColor: const Color(0xff151423),
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  splashFactory: NoSplash.splashFactory,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 1,
                  ),
                ).copyWith(
                  overlayColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                ),
            child: const Text(
              'Guardar borrador',
              style: TextStyle(
                fontSize: 14,
                height: 1.2,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ],
    ),
  );
}

class PublicationPhotoPicker extends StatelessWidget {
  const PublicationPhotoPicker({
    super.key,
    required this.onCamera,
    required this.onGallery,
  });
  final VoidCallback? onCamera, onGallery;
  @override
  Widget build(BuildContext context) => CustomPaint(
    painter: const _PhotoBorder(),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(17, 33, 17, 33),
      child: Column(
        children: [
          SvgPicture.asset(
            'assets/profile/publish-cam-lg.svg',
            width: 48,
            height: 48,
          ),
          const SizedBox(height: 16),
          const Text(
            'Añade fotos de la mascota',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              height: 1.55,
              fontWeight: FontWeight.w500,
              color: Color(0xff151423),
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Puedes subir una o varias fotos.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.55,
              color: Color(0xff616174),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _PhotoAction('Tomar foto', 'publish-cam-sm.svg', onCamera),
              _PhotoAction(
                'Subir desde galería',
                'publish-upload.svg',
                onGallery,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

class _PhotoAction extends StatelessWidget {
  const _PhotoAction(this.label, this.asset, this.onPressed);
  final String label, asset;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: onPressed,
    icon: SvgPicture.asset('assets/profile/$asset', width: 16, height: 16),
    label: Text(
      label,
      textAlign: TextAlign.center,
      style: const TextStyle(
        fontSize: 14,
        height: 1.2,
        fontWeight: FontWeight.w500,
      ),
    ),
    style: OutlinedButton.styleFrom(
      backgroundColor: const Color(0xfffafafd),
      foregroundColor: const Color(0xff151423),
      minimumSize: const Size(0, 36),
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      splashFactory: NoSplash.splashFactory,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      side: const BorderSide(color: Color(0xffe3e4ed)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ).copyWith(overlayColor: const WidgetStatePropertyAll(Colors.transparent)),
  );
}

class _PhotoBorder extends CustomPainter {
  const _PhotoBorder();
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(24),
    );
    canvas.drawRRect(bounds, Paint()..color = const Color(0x4df0eff8));
    final border = Path()..addRRect(bounds.deflate(.5));
    final paint = Paint()
      ..color = const Color(0xffe3e4ed)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in border.computeMetrics()) {
      for (var offset = 0.0; offset < metric.length; offset += 5) {
        canvas.drawPath(
          metric.extractPath(offset, (offset + 2).clamp(0, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PhotoBorder oldDelegate) => false;
}
