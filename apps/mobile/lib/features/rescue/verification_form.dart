import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class VerificationFormFrame extends StatelessWidget {
  const VerificationFormFrame({
    super.key,
    required this.children,
    this.onBack,
    this.title = 'Formulario de verificación',
    this.rescuer = true,
    this.processing = false,
    this.bodyPadding = const EdgeInsets.fromLTRB(16, 20, 16, 32),
  });
  final List<Widget> children;
  final String title;
  final bool rescuer, processing;
  final EdgeInsets bodyPadding;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    body: SafeArea(
      child: Column(
        children: [
          Stack(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: rescuer
                          ? const Color(0xffe3e4ed)
                          : const Color(0xffe6e2dd),
                    ),
                  ),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 68),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          key: const ValueKey('verification-header-back'),
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          onPressed: onBack,
                          tooltip: 'Volver',
                          icon: Transform.translate(
                            offset: const Offset(-4, -.5),
                            child: SvgPicture.asset(
                              'assets/profile/back.svg',
                              width: 20,
                              height: 20,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            title,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 18,
                              height: 1.25,
                              letterSpacing: -.36,
                              fontWeight: FontWeight.w700,
                              color: rescuer
                                  ? const Color(0xff151423)
                                  : const Color(0xff15110d),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.textScalerOf(context).scale(18) > 24
                              ? 0
                              : 48,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (processing)
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    semanticsLabel: 'Guardando o subiendo archivos',
                  ),
                ),
            ],
          ),
          Expanded(
            child: ListView(
              key: const ValueKey('verification-form-body'),
              padding: bodyPadding,
              children: children,
            ),
          ),
        ],
      ),
    ),
  );
}

class VerificationSectionTitle extends StatelessWidget {
  const VerificationSectionTitle(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 16),
    child: Semantics(
      header: true,
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 19,
          height: 1.3,
          fontWeight: FontWeight.w700,
          color: Color(0xff151423),
        ),
      ),
    ),
  );
}

class VerificationProgress extends StatelessWidget {
  const VerificationProgress({
    super.key,
    required this.captured,
    required this.total,
  });
  final int captured, total;
  @override
  Widget build(BuildContext context) {
    const heading = Text(
      'Progreso del formulario',
      style: TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        height: 17 / 14,
        color: Color(0xff4f4e5c),
      ),
    );
    final status = Text(
      captured == total ? 'Completo' : 'Incompleto',
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        height: 17 / 14,
        fontWeight: FontWeight.w700,
        color: Color(0xff151423),
      ),
    );
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffe3e4ed)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (MediaQuery.textScalerOf(context).scale(14) > 21)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [heading, const SizedBox(height: 12), status],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(child: heading),
                const SizedBox(width: 12),
                status,
              ],
            ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: captured / total,
            minHeight: 8,
            borderRadius: BorderRadius.circular(99),
            color: const Color(0xff7841f2),
            backgroundColor: const Color(0xffefede8),
            semanticsLabel:
                'Progreso del formulario: $captured de $total requisitos capturados',
          ),
        ],
      ),
    );
  }
}

class VerificationDocumentCard extends StatelessWidget {
  const VerificationDocumentCard({
    super.key,
    required this.role,
    required this.title,
    this.onUpload,
    this.showUpload = true,
    this.attachments = const [],
  });
  final String role, title;
  final VoidCallback? onUpload;
  final bool showUpload;
  final List<Widget> attachments;

  static const titleStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 16,
    height: 20 / 16,
    fontWeight: FontWeight.w700,
    color: Color(0xff151423),
  );
  static const subtitleStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 12,
    height: 15 / 12,
    color: Color(0xff4f4e5c),
  );
  static const uploadStyle = TextStyle(
    fontFamily: 'Inter',
    fontSize: 14,
    height: 17 / 14,
    fontWeight: FontWeight.w600,
  );
  static const subtitle = 'Privado · Solo para revisión del equipo';

  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final stacked = scaler.scale(14) > 21;
    final summary = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title *', style: titleStyle),
        const SizedBox(height: 2),
        const Text(subtitle, style: subtitleStyle),
      ],
    );
    final upload = Semantics(
      label: 'Adjuntar ${title.toLowerCase()}',
      child: OutlinedButton(
        key: ValueKey('verification-upload-$role'),
        onPressed: onUpload,
        style:
            OutlinedButton.styleFrom(
              foregroundColor: const Color(0xff151423),
              side: const BorderSide(color: Color(0xffe3e4ed)),
              minimumSize: const Size(0, 35),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              textStyle: uploadStyle,
              splashFactory: NoSplash.splashFactory,
              tapTargetSize: MaterialTapTargetSize.padded,
              visualDensity: VisualDensity.standard,
            ).copyWith(
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              animationDuration: Duration.zero,
            ),
        child: const Text('Subir'),
      ),
    );
    return DecoratedBox(
      key: ValueKey('verification-document-$role'),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xffe3e4ed)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          double textHeight(String text, TextStyle style, double width) {
            final painter = TextPainter(
              text: TextSpan(text: text, style: style),
              textDirection: Directionality.of(context),
              textScaler: scaler,
            )..layout(maxWidth: width);
            final height = painter.height;
            painter.dispose();
            return height;
          }

          var verticalPadding = 15.0;
          if (showUpload && !stacked) {
            final label = TextPainter(
              text: const TextSpan(text: 'Subir', style: uploadStyle),
              textDirection: Directionality.of(context),
              textScaler: scaler,
            )..layout();
            final summaryWidth =
                (constraints.maxWidth - 30 - 12 - label.width - 28).clamp(
                  1.0,
                  double.infinity,
                );
            label.dispose();
            final summaryHeight =
                textHeight('$title *', titleStyle, summaryWidth) +
                2 +
                textHeight(subtitle, subtitleStyle, summaryWidth);
            // Source has 15 px of visible inset. Center the 48 px touch target
            // inside that space instead of adding its padding to the card height.
            verticalPadding = 15 - ((48 - summaryHeight) / 2).clamp(0.0, 15.0);
          }
          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 15,
              vertical: verticalPadding,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!showUpload)
                  summary
                else if (stacked)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [summary, const SizedBox(height: 12), upload],
                  )
                else
                  Row(
                    children: [
                      Expanded(child: summary),
                      const SizedBox(width: 12),
                      upload,
                    ],
                  ),
                ...attachments,
              ],
            ),
          );
        },
      ),
    );
  }
}

class VerificationFormActions extends StatelessWidget {
  const VerificationFormActions({
    super.key,
    required this.onSubmit,
    required this.onSaveLater,
    this.busy = false,
  });
  final VoidCallback onSubmit, onSaveLater;
  final bool busy;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      const ghostStyle = TextStyle(
        fontFamily: 'Inter',
        fontSize: 14,
        height: 17 / 14,
        fontWeight: FontWeight.w500,
      );
      final label =
          TextPainter(
            text: const TextSpan(
              text: 'Guardar y continuar después',
              style: ghostStyle,
            ),
            textDirection: Directionality.of(context),
            textScaler: MediaQuery.textScalerOf(context),
          )..layout(
            maxWidth: (constraints.maxWidth - 14).clamp(1.0, double.infinity),
          );
      final surfaceHeight = (label.height + 6).clamp(36.0, double.infinity);
      label.dispose();
      final gap = 16 - ((48 - surfaceHeight) / 2).clamp(0.0, 6.0);
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton(
            key: const ValueKey('verification-submit'),
            onPressed: busy ? null : onSubmit,
            style:
                FilledButton.styleFrom(
                  backgroundColor: const Color(0xff7841f2),
                  foregroundColor: const Color(0xfffbfbff),
                  minimumSize: const Size.fromHeight(48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    height: 20 / 16,
                    fontWeight: FontWeight.w600,
                  ),
                  splashFactory: NoSplash.splashFactory,
                ).copyWith(
                  overlayColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                  animationDuration: Duration.zero,
                ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                ExcludeSemantics(
                  excluding: busy,
                  child: Opacity(
                    opacity: busy ? 0 : 1,
                    child: const Text(
                      'Enviar a revisión',
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                if (busy)
                  Positioned.fill(
                    child: Center(
                      child: Semantics(
                        label: 'Procesando',
                        child: const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Preserve Source's visible gap while retaining the larger touch target.
          SizedBox(height: gap),
          OutlinedButton(
            key: const ValueKey('verification-save-later'),
            onPressed: busy ? null : onSaveLater,
            style:
                OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xff151423),
                  side: const BorderSide(color: Color(0xffe3e4ed)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  minimumSize: const Size.fromHeight(36),
                  padding: EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: MediaQuery.textScalerOf(context).scale(14) > 21
                        ? 8
                        : 3,
                  ),
                  textStyle: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    height: 17 / 14,
                    fontWeight: FontWeight.w500,
                  ),
                  splashFactory: NoSplash.splashFactory,
                  tapTargetSize: MaterialTapTargetSize.padded,
                  visualDensity: VisualDensity.standard,
                ).copyWith(
                  overlayColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                  animationDuration: Duration.zero,
                ),
            child: const Text(
              'Guardar y continuar después',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    },
  );
}
