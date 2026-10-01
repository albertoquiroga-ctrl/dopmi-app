import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ui.dart';
import '../../core/measurement.dart';
import 'community_repository.dart';
import 'community_ui.dart';
import 'photo_recovery.dart';
import 'publication_frame.dart';
import 'discovery_filters.dart' show personalityLabels, legacyPersonalityLabels;

class MyAdoptionsScreen extends ConsumerStatefulWidget {
  const MyAdoptionsScreen({super.key});
  @override
  ConsumerState<MyAdoptionsScreen> createState() => _MyAdoptionsState();
}

class _MyAdoptionsState extends ConsumerState<MyAdoptionsScreen> {
  int page = 1, revision = 0;
  @override
  Widget build(BuildContext context) => CommunityFrame(
    index: 2,
    back: false,
    children: [
      const PhotoRecoveryNotice(),
      const Heading(
        'Dale voz\na su historia.',
        'Prepara una publicación y envíala al equipo Dopmi para su revisión.',
        eyebrow: 'MIS PUBLICACIONES',
      ),
      ActionButton(
        'Publicar una adopción',
        sunny: true,
        onPressed: () async {
          await context.push('/my-adoptions/new');
          if (mounted) setState(() => revision++);
        },
      ),
      const SizedBox(height: 24),
      OutlinedButton.icon(
        onPressed: () => context.push('/rescuer'),
        icon: const Icon(Icons.volunteer_activism_outlined),
        label: const Text('Mis rescates y gastos'),
      ),
      const SizedBox(height: 16),
      LiveSection<DataPage<Adoption>>(
        key: ValueKey('$page:$revision'),
        tables: const ['dopmi_adoptions'],
        load: () => ref.read(communityRepositoryProvider).mine(page),
        builder: (result, refresh) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (result.items.isEmpty)
              const Notice(
                'Aquí encontrarás tus borradores, las publicaciones en revisión y sus respuestas.',
              ),
            for (final post in result.items)
              Card(
                color: Colors.white,
                child: ListTile(
                  contentPadding: const EdgeInsets.all(16),
                  title: Text(
                    post.name.isEmpty ? 'Borrador sin nombre' : post.name,
                  ),
                  subtitle: Text(
                    [
                      statusLabels[post.status],
                      if (post.text('review_feedback').isNotEmpty)
                        post.text('review_feedback'),
                    ].join('\n'),
                  ),
                  isThreeLine: post.text('review_feedback').isNotEmpty,
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await context.push('/my-adoptions/${post.id}');
                    refresh();
                  },
                ),
              ),
            PageControls(
              page: page,
              total: result.total,
              size: 12,
              change: (value) => setState(() => page = value),
            ),
          ],
        ),
      ),
    ],
  );
}

class PublicationScreen extends ConsumerStatefulWidget {
  const PublicationScreen(this.id, {super.key, this.rescueCaseId});
  final String id;
  final String? rescueCaseId;
  @override
  ConsumerState<PublicationScreen> createState() => _PublicationState();
}

class _PublicationState extends ConsumerState<PublicationScreen> {
  final form = GlobalKey<FormState>();
  final fields = <String, TextEditingController>{
    for (final key in [
      'pet_name',
      'age_months',
      'breed',
      'city',
      'region',
      'story',
      'special_care',
      'publisher_name',
      'publisher_bio',
    ])
      key: TextEditingController(),
  };
  Json choices = {'species': 'dog', 'sex': 'female', 'size': 'medium'};
  List<String> photos = [];
  Adoption? post;
  bool loading = false, busy = false;
  String? error, message;
  int loaded = 0, step = 0;
  CommunityRepository get repo => ref.read(communityRepositoryProvider);
  @override
  void initState() {
    super.initState();
    fields['age_months']!.text = '0';
    if (widget.id != 'new') load();
  }

  @override
  void dispose() {
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await repo.own(post?.id ?? widget.id);
      if (result == null) {
        throw const FormatException(
          'Esta publicación no está disponible para tu cuenta.',
        );
      }
      if (mounted) {
        setState(() {
          post = result;
          loaded++;
          for (final entry in fields.entries) {
            entry.value.text = '${result.data[entry.key] ?? ''}';
          }
          choices = {
            for (final key in [
              'species',
              'sex',
              'size',
              'vaccinated',
              'sterilized',
              'social_dogs',
              'social_cats',
              'social_children',
              'personality',
            ])
              key: result.data[key],
          };
          photos = result.photos;
          if (result.status == 'submitted') step = 2;
        });
      }
    } catch (cause) {
      if (mounted) setState(() => error = communityError(cause));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> perform(Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      await action();
    } catch (cause) {
      if (mounted) setState(() => error = communityError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    final payload = <String, dynamic>{
      ...choices,
      for (final entry in fields.entries) entry.key: entry.value.text.trim(),
      'photos': photos,
      if (widget.rescueCaseId != null || post?.data['rescue_case_id'] != null)
        'rescue_case_id': widget.rescueCaseId ?? post?.data['rescue_case_id'],
    };
    payload['age_months'] = int.tryParse(fields['age_months']!.text) ?? 0;
    final result = await repo.save(
      payload,
      id: post?.id,
      version: post?.version,
    );
    if (mounted) {
      setState(() {
        post = result;
        message = 'Guardamos tu borrador. Puedes continuar después.';
      });
    }
  }

  Future<void> change(String action) => perform(() async {
    if (action == 'submit') {
      if (!form.currentState!.validate()) return;
      await save();
    }
    final result = await repo.transition(post!, action);
    if (action == 'submit') {
      await ref
          .read(measurementControllerProvider)
          ?.event('publication_submitted');
    }
    if (mounted) {
      setState(() {
        post = result;
        message = action == 'submit'
            ? 'Enviamos tu publicación a revisión. Te avisaremos aquí cuando haya respuesta.'
            : 'Actualizamos el estado de tu publicación.';
      });
    }
  });
  Future<void> addPhoto({ImageSource source = ImageSource.gallery}) =>
      perform(() async {
        if (!form.currentState!.validate()) return;
        await save(); // Preserve all fields before the operating system opens its photo picker.
        final preferences = await SharedPreferences.getInstance();
        final pendingKey = pendingPhotoKey(repo.userId!);
        await preferences.setString(pendingKey, post!.id);
        final file = await ImagePicker().pickImage(
          source: source,
          maxWidth: 1600,
          maxHeight: 1600,
          requestFullMetadata: false,
        );
        await preferences.remove(pendingKey);
        if (file == null || !mounted) return;
        final path = await repo.uploadPhoto(post!.id, await file.readAsBytes());
        if (!mounted) return;
        setState(() => photos.add(path));
        await save();
      });
  Widget field(String key, String label, int max, {int lines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: fields[key],
      enabled: !busy && post?.status != 'submitted',
      maxLength: max,
      maxLines: lines,
      keyboardType: key == 'age_months'
          ? TextInputType.number
          : lines > 1
          ? TextInputType.multiline
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        counterText: lines > 1 ? null : '',
      ),
      validator: key == 'age_months'
          ? (value) {
              final months = int.tryParse(value ?? '');
              return months == null || months < 0 || months > 360
                  ? 'Escribe de 0 a 360 meses.'
                  : null;
            }
          : null,
    ),
  );
  Widget publicationChoice(
    String key,
    String label,
    Map<String, String> options,
  ) => PublicationChoiceRow(
    label: label,
    options: options,
    value: choices[key] as String?,
    onChanged: busy || post?.status == 'submitted'
        ? null
        : (value) => setState(() => choices[key] = value),
  );
  Widget choice(String key, String label, Map<String, String> options) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: DropdownButtonFormField<String>(
          key: ValueKey('$key:$loaded'),
          initialValue: choices[key] as String?,
          isExpanded: true,
          decoration: InputDecoration(labelText: label),
          items: options.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: busy || post?.status == 'submitted'
              ? null
              : (value) => setState(() => choices[key] = value),
        ),
      );
  Widget trait(String key, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<String>(
      key: ValueKey('$key:$loaded'),
      initialValue: choices[key] == null ? 'unknown' : '${choices[key]}',
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: const [
        DropdownMenuItem(value: 'unknown', child: Text('Por confirmar')),
        DropdownMenuItem(value: 'true', child: Text('Sí')),
        DropdownMenuItem(value: 'false', child: Text('No')),
      ],
      onChanged: busy || post?.status == 'submitted'
          ? null
          : (value) => setState(
              () => choices[key] = value == 'unknown' ? null : value == 'true',
            ),
    ),
  );
  Widget publicationFooter() {
    if (loading || (post == null && widget.id != 'new')) {
      return const SizedBox.shrink();
    }
    final compact = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (post?.status == 'submitted') {
      return PublicationFooter(
        label: 'Retirar de revisión para editar',
        busy: busy,
        compact: compact,
        onContinue: () => change('withdraw'),
      );
    }
    return PublicationFooter(
      label: step < 2 ? 'Continuar' : 'Enviar a revisión',
      busy: busy,
      compact: compact,
      onSave: () => perform(save),
      onContinue: step == 0 && photos.isEmpty
          ? null
          : step < 2
          ? () => perform(() async {
              if (!form.currentState!.validate()) return;
              await save();
              if (mounted) setState(() => step++);
            })
          : () => change('submit'),
    );
  }

  @override
  Widget build(BuildContext context) => PublicationFrame(
    title: 'Publicar caso',
    step: step,
    footer: publicationFooter(),
    onBack: busy
        ? null
        : () {
            if (step > 0 && post?.status != 'submitted') {
              setState(() => step--);
            } else if (context.canPop()) {
              context.pop();
            } else {
              context.go('/publish');
            }
          },
    children: [
      if (loading) const Center(child: CircularProgressIndicator()),
      if (error != null) Notice(error!, isError: true),
      if (!loading && widget.id != 'new' && post == null)
        ActionButton('Volver a intentar', onPressed: load),
      if (!loading && (post != null || widget.id == 'new')) ...[
        if (widget.rescueCaseId != null || post?.data['rescue_case_id'] != null)
          const Notice(
            'Esta publicación está vinculada a un caso aprobado. Su revisión de adopción es independiente.',
          ),
        if (post?.text('review_feedback').isNotEmpty == true)
          Notice('Respuesta del equipo: ${post!.text('review_feedback')}'),
        if (post?.status == 'published' || post?.status == 'adopted')
          const Notice(
            'Guardar cambios o agregar fotos retirará esta publicación del catálogo. El contenido necesitará una nueva revisión.',
          ),
        if (post?.status == 'submitted')
          const Notice(
            'Tu publicación está en revisión. Retírala de revisión si necesitas editarla.',
          ),
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (step == 1) ...[
                Text(
                  'Información básica',
                  style: const TextStyle(
                    fontSize: 18,
                    height: 28 / 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff151423),
                  ),
                ),
                const SizedBox(height: 18),
                field('pet_name', 'Nombre de la mascota', 80),
                publicationChoice('sex', 'Sexo', {
                  'male': 'Macho',
                  'female': 'Hembra',
                }),
                publicationChoice('species', 'Especie', {
                  'dog': 'Perro',
                  'cat': 'Gato',
                }),
                field('age_months', 'Edad aproximada en meses', 3),
                choice('size', 'Tamaño', {
                  'small': 'Pequeño',
                  'medium': 'Mediano',
                  'large': 'Grande',
                }),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('Personalidad'),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in {
                      ...personalityLabels,
                      for (final entry in legacyPersonalityLabels.entries)
                        if ((choices['personality'] as List? ?? const [])
                            .contains(entry.key))
                          entry.key: entry.value,
                    }.entries)
                      FilterChip(
                        label: Text(item.value),
                        selected: (choices['personality'] as List? ?? const [])
                            .contains(item.key),
                        onSelected: busy || post?.status == 'submitted'
                            ? null
                            : (selected) => setState(() {
                                final traits = List<String>.from(
                                  choices['personality'] as List? ?? const [],
                                );
                                selected
                                    ? traits.add(item.key)
                                    : traits.remove(item.key);
                                choices['personality'] = traits;
                              }),
                      ),
                  ],
                ),
                field('breed', 'Raza o mestizo (opcional)', 80),
                field('city', 'Ciudad', 100),
                field('region', 'Estado', 100),
                field(
                  'story',
                  'Su historia y el hogar que necesita',
                  4000,
                  lines: 5,
                ),
                trait('vaccinated', '¿Tiene sus vacunas al día?'),
                trait('sterilized', '¿Está esterilizado?'),
                trait('social_dogs', '¿Convive con perros?'),
                trait('social_cats', '¿Convive con gatos?'),
                trait('social_children', '¿Convive con niñas y niños?'),
                field(
                  'special_care',
                  'Cuidados especiales (opcional)',
                  1000,
                  lines: 3,
                ),
                const SizedBox(height: 8),
                Text(
                  'Tu presentación pública',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Estos datos aparecerán en la publicación y en tu perfil público después de la aprobación. No incluyas tu domicilio, teléfono ni documentos.',
                  ),
                ),
                field('publisher_name', 'Nombre público o del refugio', 80),
                field(
                  'publisher_bio',
                  'Sobre ti y tu labor (opcional)',
                  1000,
                  lines: 3,
                ),
              ],
              if (step == 0) ...[
                const Text(
                  'Sube fotos de la mascota',
                  style: TextStyle(
                    fontSize: 18,
                    height: 28 / 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xff151423),
                  ),
                ),
                const SizedBox(height: 16),
                if (photos.length < 5 && post?.status != 'submitted') ...[
                  PublicationPhotoPicker(
                    onCamera: busy
                        ? null
                        : () => addPhoto(source: ImageSource.camera),
                    onGallery: busy ? null : () => addPhoto(),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  photos.isEmpty
                      ? 'Sube al menos una foto para continuar.'
                      : 'Fotos agregadas (${photos.length}/5)',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: Color(0xff616174),
                  ),
                ),
                if (photos.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var index = 0; index < photos.length; index++)
                        PublicationPhotoThumbnail(
                          key: ValueKey(photos[index]),
                          photo: AdoptionPhoto(photos[index], height: 167),
                          principal: index == 0,
                          onRemove: busy || post?.status == 'submitted'
                              ? null
                              : () => setState(() => photos.removeAt(index)),
                        ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                const Text(
                  'Usa fotos sin documentos ni direcciones visibles. Eliminamos los metadatos antes de subirlas.',
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.5,
                    color: Color(0xff616174),
                  ),
                ),
              ],
              if (step == 2) ...[
                Text(
                  'Revisa antes de enviar',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                _ReviewRow(
                  'Mascota',
                  fields['pet_name']!.text.trim().isEmpty
                      ? 'Sin nombre'
                      : fields['pet_name']!.text.trim(),
                ),
                _ReviewRow(
                  'Ubicación',
                  [
                    fields['city']!.text.trim(),
                    fields['region']!.text.trim(),
                  ].where((value) => value.isNotEmpty).join(', '),
                ),
                _ReviewRow('Fotos', '${photos.length} de 5'),
                const Notice(
                  'Al enviar, el equipo revisará fotos, información y privacidad antes de publicar.',
                ),
              ],
              if (message != null) Notice(message!),
              if (post?.status == 'published') ...[
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: busy ? null : () => change('adopted'),
                  child: const Text('Marcar adopción realizada'),
                ),
              ],
              if (post != null && post!.status != 'archived')
                TextButton(
                  onPressed: busy ? null : () => change('archive'),
                  child: const Text('Retirar publicación'),
                ),
              if (post != null)
                TextButton(
                  onPressed: busy ? null : load,
                  child: const Text(
                    'Descartar cambios y cargar versión guardada',
                  ),
                ),
            ],
          ),
        ),
      ],
    ],
  );
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow(this.label, this.value);
  final String label, value;
  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    title: Text(label),
    subtitle: Text(value.isEmpty ? 'Falta completar' : value),
  );
}
