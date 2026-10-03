import '../../core/reference_focus_outline.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'community_ui.dart';

class PublicationFrame extends StatelessWidget {
  const PublicationFrame({
    super.key,
    required this.title,
    required this.step,
    this.totalSteps = 3,
    required this.children,
    required this.footer,
    required this.onBack,
  });
  final String title;
  final int step, totalSteps;
  final List<Widget> children;
  final Widget footer;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final header = _PublicationHeader(
      title: title,
      step: step,
      totalSteps: totalSteps,
      onBack: onBack,
    );
    return Scaffold(
      backgroundColor: Colors.white,
      bottomNavigationBar: keyboard
          ? null
          : const CommunityNav(3, selectedPath: '/publish'),
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final scrollHeader = keyboard || constraints.maxHeight < 500;
            return Column(
              children: [
                if (!scrollHeader) header,
                Expanded(
                  child: ListView(
                    key: const PageStorageKey('publication-body'),
                    padding: EdgeInsets.zero,
                    children: [
                      // Short viewports and large navigation need the same
                      // scrolling header as an open keyboard. Keep the footer
                      // reachable and the keyed Form's authored text intact.
                      if (scrollHeader) header,
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
            );
          },
        ),
      ),
    );
  }
}

class _PublicationHeader extends StatelessWidget {
  const _PublicationHeader({
    required this.title,
    required this.step,
    required this.totalSteps,
    required this.onBack,
  });
  final String title;
  final int step, totalSteps;
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
          child: ReferenceFocusOutline(
            radius: 0,
            child: TextButton(
              key: const ValueKey('publication-header-back'),
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
                            letterSpacing: -.48,
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
        ),
        const SizedBox(height: 4),
        PublicationStepper(step: step, totalSteps: totalSteps),
      ],
    ),
  );
}

class PublicationStepper extends StatelessWidget {
  const PublicationStepper({
    super.key,
    required this.step,
    this.totalSteps = 3,
  });
  final int step, totalSteps;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Paso ${step + 1} de $totalSteps',
    child: ExcludeSemantics(
      child: Row(
        children: [
          for (var index = 0; index < totalSteps; index++) ...[
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
              child: index < step
                  ? const Icon(Icons.check, size: 18, color: Colors.white)
                  : Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 14,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: index <= step
                            ? Colors.white
                            : const Color(0xff616174),
                      ),
                    ),
            ),
            if (index < totalSteps - 1)
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
      // CSS includes the one-pixel outline outside its 12px content padding.
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
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

class PublicationPhotoThumbnail extends StatelessWidget {
  const PublicationPhotoThumbnail({
    super.key,
    required this.photo,
    required this.principal,
    this.onRemove,
  });
  final Widget photo;
  final bool principal;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 167,
    height: 167,
    child: ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xffe3e4ed)),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            photo,
            if (principal)
              Positioned(
                left: 8,
                bottom: 8,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: const Color(0xff7c3aed),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                    child: Text(
                      'Principal',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.55,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            if (onRemove != null)
              Positioned(
                right: 8,
                top: 8,
                child: SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    onPressed: onRemove,
                    tooltip: 'Quitar foto del borrador',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 28,
                      height: 28,
                    ),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xb3000000),
                      foregroundColor: Colors.white,
                      hoverColor: const Color(0xcc000000),
                      shape: const CircleBorder(),
                    ),
                    icon: const Icon(Icons.close, size: 16),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class PublicationChoiceRow extends StatelessWidget {
  const PublicationChoiceRow({
    super.key,
    required this.label,
    required this.options,
    required this.value,
    this.onChanged,
    this.leading = const {},
    this.required = false,
  });
  final String label;
  final Map<String, Widget> leading;
  final bool required;
  final Map<String, String> options;
  final String? value;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                height: 17 / 14,
                fontWeight: FontWeight.w500,
                color: Color(0xff151423),
              ),
            ),
            if (required)
              const Text(
                ' *',
                style: TextStyle(fontSize: 14, color: Color(0xffd52222)),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final entry in options.entries) ...[
              if (entry.key != options.keys.first) const SizedBox(width: 12),
              Expanded(
                child: Semantics(
                  selected: value == entry.key,
                  child: OutlinedButton(
                    onPressed: onChanged == null
                        ? null
                        : () => onChanged!(entry.key),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 46),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      foregroundColor: value == entry.key
                          ? const Color(0xff7c3aed)
                          : const Color(0xff151423),
                      backgroundColor: value == entry.key
                          ? const Color(0x147c3aed)
                          : Colors.white,
                      side: BorderSide(
                        color: value == entry.key
                            ? const Color(0xff7c3aed)
                            : const Color(0xffe3e4ed),
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      textStyle: const TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        height: 1.55,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    child: Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      children: [
                        if (leading[entry.key] != null)
                          ExcludeSemantics(child: leading[entry.key]!),
                        Text(entry.value, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        if (value == null) ...[
          const SizedBox(height: 8),
          const Text(
            'Selecciona una opción para continuar.',
            style: TextStyle(
              fontSize: 12,
              height: 1.55,
              color: Color(0xff616174),
            ),
          ),
        ],
      ],
    ),
  );
}

class PublicationTraitCard extends StatelessWidget {
  const PublicationTraitCard({
    super.key,
    required this.title,
    required this.children,
  });
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffe3e4ed)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(17),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  height: 20 / 16,
                  fontWeight: FontWeight.w600,
                  color: Color(0xff151423),
                ),
              ),
            ),
            for (final child in children) ...[
              const SizedBox(height: 12),
              child,
            ],
          ],
        ),
      ),
    ),
  );
}

class PublicationTraitCheck extends StatelessWidget {
  const PublicationTraitCheck({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
  });
  final String label;
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  void advance() => onChanged?.call(
    value == null
        ? true
        : value == true
        ? false
        : null,
  );
  @override
  Widget build(BuildContext context) => MergeSemantics(
    child: InkWell(
      onTap: onChanged == null ? null : advance,
      borderRadius: BorderRadius.circular(4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 24,
            height: 17,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Transform.scale(
                scale: 16 / 18,
                child: Checkbox(
                  value: value,
                  tristate: true,
                  onChanged: onChanged == null ? null : (_) => advance(),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  visualDensity: VisualDensity.compact,
                  activeColor: const Color(0xff7841f2),
                  checkColor: Colors.white,
                  fillColor: WidgetStatePropertyAll(
                    value == false ? Colors.white : const Color(0xff7841f2),
                  ),
                  side: const BorderSide(color: Color(0xffe3e4ed)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 17 / 14,
                    color: Color(0xff151423),
                  ),
                ),
                if (value == null)
                  const Text(
                    'Por confirmar',
                    style: TextStyle(
                      fontSize: 12,
                      height: 15 / 12,
                      color: Color(0xff616174),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
