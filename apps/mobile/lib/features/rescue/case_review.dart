import 'package:flutter/material.dart';

import '../adoption/community_repository.dart';
import '../adoption/publication_frame.dart';
import 'rescue_public_photo.dart';
import 'case_need_row.dart';

class CaseReview extends StatelessWidget {
  const CaseReview({
    super.key,
    required this.values,
    required this.files,
    this.items = const [],
    required this.onOpen,
    this.onEditPhotos,
    this.onEditInformation,
    this.onEditNeeds,
  });
  final Map<String, String> values;
  final List<Json> files, items;
  final ValueChanged<String> onOpen;
  final VoidCallback? onEditPhotos, onEditInformation, onEditNeeds;

  Widget heading(String title, VoidCallback? edit) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 16,
            height: 1.25,
            fontWeight: FontWeight.w500,
            color: Color(0xff151423),
          ),
        ),
      ),
      if (edit != null)
        TextButton(
          key: ValueKey('case-review-edit-$title'),
          onPressed: edit,
          style: TextButton.styleFrom(
            foregroundColor: const Color(0xff7c3aed),
            padding: EdgeInsets.zero,
            minimumSize: const Size(48, 20),
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            textStyle: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 14,
              height: 17 / 14,
              fontWeight: FontWeight.w400,
            ),
          ),
          child: Semantics(
            label: 'Editar $title',
            excludeSemantics: true,
            child: const Text('Editar'),
          ),
        ),
    ],
  );

  Widget card(List<(String, String)> rows) => DecoratedBox(
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xffe3e4ed)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            Text(
              rows[i].$1,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                height: 1.25,
                color: Color(0xff616174),
              ),
            ),
            Text(
              rows[i].$2.trim().isEmpty ? 'Sin capturar' : rows[i].$2,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                height: 1.5,
                fontWeight: FontWeight.w500,
                color: Color(0xff151423),
              ),
            ),
          ],
        ],
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      heading('Fotos', onEditPhotos),
      const SizedBox(height: 12),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final file in files.where(
            (f) => f['role'] == 'public' && f['path'] is String,
          ))
            Semantics(
              button: true,
              label: 'Ver foto del caso',
              child: InkWell(
                onTap: () => onOpen(file['path'] as String),
                splashFactory: NoSplash.splashFactory,
                highlightColor: Colors.transparent,
                child: SizedBox(
                  width: 110,
                  height: 110,
                  child: PublicationPhotoThumbnail(
                    principal: false,
                    photo: RescuePublicPhoto(
                      file['path'] as String,
                      height: 110,
                      radius: 0,
                      compact: true,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
      const SizedBox(height: 24),
      heading('Información básica', onEditInformation),
      const SizedBox(height: 12),
      card([
        (
          'Nombre',
          (values['pet_name'] ?? '').trim().isEmpty
              ? 'Sin nombre'
              : values['pet_name']!,
        ),
        ('Edad', values['age'] ?? ''),
        ('Historia', values['story'] ?? ''),
        (
          'Especie',
          const {'dog': 'Perro', 'cat': 'Gato'}[values['species']] ??
              'Sin capturar',
        ),
        (
          'Sexo',
          const {
                'male': 'Macho',
                'female': 'Hembra',
                'unknown': 'Por determinar',
              }[values['sex']] ??
              'Sin capturar',
        ),
        ('Ciudad', values['city'] ?? ''),
        ('Estado', values['state'] ?? ''),
      ]),
      const SizedBox(height: 24),
      heading('Necesidades', onEditNeeds),
      const SizedBox(height: 12),
      for (final item in items) ...[
        CaseNeedRow(item: item),
        const SizedBox(height: 8),
      ],
      if ((values['need'] ?? '').isNotEmpty)
        card([('Necesidad y cuidados', values['need']!)]),
      if (items.isEmpty && (values['need'] ?? '').isEmpty)
        const Text(
          'Sin necesidades agregadas.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            color: Color(0xff616174),
          ),
        ),
    ],
  );
}
