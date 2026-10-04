import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ExpenseEvidenceCard extends StatelessWidget {
  const ExpenseEvidenceCard({
    super.key,
    required this.title,
    required this.public,
    required this.fileIndexes,
    required this.onOpen,
    required this.onRemove,
    required this.onAttach,
  });

  final String title;
  final bool public;
  final List<int> fileIndexes;
  final ValueChanged<int> onOpen;
  final ValueChanged<int>? onRemove;
  final VoidCallback? onAttach;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            height: 17 / 14,
            fontWeight: FontWeight.w500,
            color: Color(0xff15110d),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          public
              ? 'Esta evidencia se mostrará a los donantes después de la aprobación.'
              : 'Archivo privado para revisión. No se muestra a los donantes.',
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            height: 16 / 12,
            color: Color(0xff554e48),
          ),
        ),
        const SizedBox(height: 8),
        for (final index in fileIndexes)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xffe3e4ed)),
              color: Colors.white,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () => onOpen(index),
                    icon: const Icon(Icons.description_outlined, size: 20),
                    label: Text(
                      'Ver archivo ${index + 1}',
                      style: const TextStyle(fontFamily: 'Inter', fontSize: 14),
                    ),
                  ),
                ),
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Quitar archivo ${index + 1}',
                    onPressed: () => onRemove!(index),
                    icon: const Icon(Icons.close, size: 20),
                  ),
              ],
            ),
          ),
        CustomPaint(
          painter: const _EvidenceDropBorder(),
          child: OutlinedButton(
            onPressed: onAttach,
            style:
                OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 148),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 28,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  side: BorderSide.none,
                  backgroundColor: Colors.transparent,
                  foregroundColor: const Color(0xff15110d),
                  splashFactory: NoSplash.splashFactory,
                ).copyWith(
                  overlayColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SvgPicture.asset(
                  'assets/profile/publish-upload.svg',
                  width: 28,
                  height: 28,
                ),
                const SizedBox(height: 6),
                Text(
                  public
                      ? 'Toca para subir foto'
                      : 'Adjuntar ${title.toLowerCase()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    height: 17 / 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 240),
                  child: Text(
                    public
                        ? 'JPG, PNG o WebP, máximo 5 MB'
                        : 'JPG, PNG, WebP o PDF, máximo 5 MB',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      height: 15 / 12,
                      color: Color(0xff554e48),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _EvidenceDropBorder extends CustomPainter {
  const _EvidenceDropBorder();
  @override
  void paint(Canvas canvas, Size size) {
    final bounds = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(24),
    );
    canvas.drawRRect(bounds, Paint()..color = const Color(0x59f0eff8));
    final path = Path()..addRRect(bounds.deflate(.5));
    final paint = Paint()
      ..color = const Color(0xffe3e4ed)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (var offset = 0.0; offset < metric.length; offset += 5) {
        canvas.drawPath(
          metric.extractPath(offset, (offset + 2).clamp(0, metric.length)),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_EvidenceDropBorder oldDelegate) => false;
}
