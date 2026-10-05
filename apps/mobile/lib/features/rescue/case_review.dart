import 'package:flutter/material.dart';

import '../adoption/community_repository.dart';
import '../adoption/publication_frame.dart';
import 'rescue_public_photo.dart';
import 'case_need_row.dart';
import 'case_detail_layout.dart';
import 'rescue_repository.dart';

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
    this.preview = false,
    this.expenseDrafts = const [],
    this.ownerId,
    this.rescuerName,
    this.rescuerVerified = false,
  });
  final bool preview, rescuerVerified;
  final String? ownerId, rescuerName;
  final List<RescueRecord> expenseDrafts;
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
  Widget build(BuildContext context) => preview
      ? Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PublicationPreviewIntro(
              'Esta es una previsualización de la publicación que verán quienes apoyen la causa.',
            ),
            PublicationPreviewFrame(
              child: CaseDetailLayout(
                preview: true,
                requestedAmountCents: expenseDrafts.fold<int>(
                  0,
                  (total, expense) =>
                      total +
                      (int.tryParse(
                            expense.privateData['amount_cents']?.toString() ??
                                '',
                          ) ??
                          0),
                ),
                saved: false,
                busy: true,
                favorite: () {},
                share: () {},
                report: () {},
                record: RescueRecord({
                  'id': 'preview',
                  'kind': 'case',
                  'status': 'draft',
                  'owner_id': ownerId,
                  'rescuer_name': rescuerName,
                  'rescuer_verified': rescuerVerified,
                  'public_data': {
                    ...values,
                    'photos': [
                      for (final file in files)
                        if (file['role'] == 'public') file['path'],
                    ],
                  },
                }),
                expenses: expenseDrafts,
                needs: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (final expense in expenseDrafts)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CaseNeedRow(
                          item: {
                            'title': expense.title.isEmpty
                                ? 'Borrador sin título'
                                : expense.title,
                            'type':
                                expense.publicData['category'] ?? 'veterinary',
                            'amount_cents':
                                int.tryParse(
                                  expense.privateData['amount_cents']
                                          ?.toString() ??
                                      '',
                                ) ??
                                0,
                            'detail': expense.publicData['description'] ?? '',
                            'urgent': false,
                          },
                        ),
                      ),
                    for (final item in items)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: CaseNeedRow(item: item),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'La publicación y los gastos se revisan por separado. Esta vista previa no habilita aportaciones.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: Color(0xff616174),
              ),
            ),
            Wrap(
              spacing: 12,
              children: [
                if (onEditInformation != null)
                  TextButton(
                    key: const ValueKey('case-review-edit-Información básica'),
                    onPressed: onEditInformation,
                    child: const Text('Editar perfil'),
                  ),
                if (onEditNeeds != null)
                  TextButton(
                    key: const ValueKey('case-review-edit-Necesidades'),
                    onPressed: onEditNeeds,
                    child: const Text('Editar necesidades'),
                  ),
              ],
            ),
          ],
        )
      : Column(
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
