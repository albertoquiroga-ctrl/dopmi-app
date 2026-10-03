import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
    showAppBar: false,
    children: [
      const PhotoRecoveryNotice(),
      Builder(
        builder: (context) {
          final large = MediaQuery.textScalerOf(context).scale(24) > 32;
          final back = IconButton(
            tooltip: 'Regresar',
            onPressed: () =>
                context.canPop() ? context.pop() : context.go('/profile'),
            icon: SvgPicture.asset(
              'assets/profile/back.svg',
              width: 20,
              height: 20,
            ),
          );
          final heading = Semantics(
            header: true,
            child: Text(
              'Mis publicaciones',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: large ? 20 : 24,
                height: 1.25,
                letterSpacing: large ? -.4 : -.48,
                fontWeight: FontWeight.w700,
                color: ink,
              ),
            ),
          );
          return large
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [back, heading],
                )
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    back,
                    const SizedBox(width: 8),
                    Expanded(child: heading),
                  ],
                );
        },
      ),
      const SizedBox(height: 6),
      const Text(
        'Prepara una publicación y envíala al equipo Dopmi para su revisión.',
        style: TextStyle(fontSize: 12, height: 1.5, color: muted),
      ),
      const SizedBox(height: 20),
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
        await preferences.setString(pendingPhotoActorKey, repo.userId!);
        final file = await ImagePicker().pickImage(
          source: source,
          maxWidth: 1600,
          maxHeight: 1600,
          requestFullMetadata: false,
        );
        await preferences.remove(pendingKey);
        if (preferences.getString(pendingPhotoActorKey) == repo.userId) {
          await preferences.remove(pendingPhotoActorKey);
        }
        if (file == null || !mounted) return;
        final path = await repo.uploadPhoto(post!.id, await file.readAsBytes());
        if (!mounted) return;
        setState(() => photos.add(path));
        await save();
      });
  Widget field(String key, String label, int max, {int lines = 1}) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
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
        const SizedBox(height: 8),
        Semantics(
          label: label,
          child: TextFormField(
            key: ValueKey('publication-field-$key'),
            controller: fields[key],
            enabled: !busy && post?.status != 'submitted',
            maxLength: max,
            maxLines: lines,
            style: const TextStyle(
              fontFamily: 'Inter',
              fontSize: 16,
              height: 20 / 16,
              color: Color(0xff151423),
            ),
            keyboardType: key == 'age_months'
                ? TextInputType.number
                : lines > 1
                ? TextInputType.multiline
                : TextInputType.text,
            decoration: InputDecoration(
              isDense: true,
              hintText: key == 'pet_name'
                  ? 'Opcional'
                  : key == 'story'
                  ? 'Cuenta cómo la encontraste.'
                  : null,
              counterText: lines > 1 ? null : '',
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 9,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xffeaeaf3)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xffeaeaf3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xff7c3aed)),
              ),
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
        ),
        if (key == 'pet_name') ...[
          const SizedBox(height: 8),
          const Text(
            'Si aún no tiene nombre, puedes dejarlo vacío.',
            style: TextStyle(
              fontSize: 12,
              height: 15 / 12,
              color: Color(0xff616174),
            ),
          ),
        ],
      ],
    ),
  );
  Widget publicationChoice(
    String key,
    String label,
    Map<String, String> options,
  ) => PublicationChoiceRow(
    label: label,
    options: options,
    required: key == 'sex' || key == 'species',
    leading: switch (key) {
      'sex' => const {
        'male': Icon(Icons.male, size: 16),
        'female': Icon(Icons.female, size: 16),
      },
      'species' => {
        for (final species in ['dog', 'cat'])
          species: SvgPicture.asset(
            'assets/profile/species-$species.svg',
            width: 20,
            height: 20,
          ),
      },
      _ => const {},
    },
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
  Widget trait(String key, String label) => PublicationTraitCheck(
    key: ValueKey('publication-trait-$key'),
    label: label,
    value: choices[key] as bool?,
    onChanged: busy || post?.status == 'submitted'
        ? null
        : (value) => setState(() => choices[key] = value),
  );
  Widget reviewTrait(String key, String label) => PublicationTraitCheck(
    key: ValueKey('publication-review-trait-$key'),
    label: label,
    value: choices[key] as bool?,
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
    title: step == 2 ? 'Revisa tu caso' : 'Publicar caso',
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
                const SizedBox(height: 16),
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
                field(
                  'story',
                  'Su historia y el hogar que necesita',
                  4000,
                  lines: 3,
                ),
                PublicationTraitCard(
                  title: 'Salud',
                  children: [
                    trait('vaccinated', 'Vacunado'),
                    trait('sterilized', 'Esterilizado'),
                    field(
                      'special_care',
                      'Cuidados especiales (opcional)',
                      1000,
                      lines: 3,
                    ),
                  ],
                ),
                PublicationTraitCard(
                  title: 'Social',
                  children: [
                    trait('social_dogs', 'Social con perros'),
                    trait('social_cats', 'Social con gatos'),
                    trait('social_children', 'Social con niñas y niños'),
                  ],
                ),
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
                _ReviewSection(
                  title: 'Fotos',
                  onEdit: busy || post?.status == 'submitted'
                      ? null
                      : () => setState(() => step = 0),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final path in photos)
                        SizedBox(
                          width: 110,
                          height: 110,
                          child: AdoptionPhoto(path, height: 110),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                _ReviewSection(
                  title: 'Información básica',
                  onEdit: busy || post?.status == 'submitted'
                      ? null
                      : () => setState(() => step = 1),
                  child: _ReviewCard(
                    rows: [
                      (
                        'Nombre',
                        fields['pet_name']!.text.trim().isEmpty
                            ? 'Sin nombre'
                            : fields['pet_name']!.text.trim(),
                      ),
                      (
                        'Sexo',
                        choices['sex'] == 'male'
                            ? 'Macho'
                            : choices['sex'] == 'female'
                            ? 'Hembra'
                            : 'Por confirmar',
                      ),
                      (
                        'Especie',
                        choices['species'] == 'dog'
                            ? 'Perro'
                            : choices['species'] == 'cat'
                            ? 'Gato'
                            : 'Por confirmar',
                      ),
                      ('Edad', '${fields['age_months']!.text.trim()} meses'),
                      ('Historia', fields['story']!.text.trim()),
                      (
                        'Ubicación',
                        [
                          fields['city']!.text.trim(),
                          fields['region']!.text.trim(),
                        ].where((value) => value.isNotEmpty).join(', '),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                PublicationTraitCard(
                  title: 'Salud',
                  children: [
                    reviewTrait('vaccinated', 'Vacunado'),
                    reviewTrait('sterilized', 'Esterilizado'),
                    PublicationTraitCheck(
                      label: 'Requiere cuidados especiales',
                      value: fields['special_care']!.text.trim().isEmpty
                          ? null
                          : true,
                    ),
                    if (fields['special_care']!.text.trim().isNotEmpty)
                      Text(
                        fields['special_care']!.text.trim(),
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          height: 20 / 14,
                          color: Color(0xff151423),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                PublicationTraitCard(
                  title: 'Social',
                  children: [
                    reviewTrait('social_dogs', 'Social con perros'),
                    reviewTrait('social_cats', 'Social con gatos'),
                    reviewTrait('social_children', 'Social con niñas y niños'),
                  ],
                ),
                const SizedBox(height: 8),
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

class _ReviewSection extends StatelessWidget {
  const _ReviewSection({required this.title, required this.child, this.onEdit});
  final String title;
  final Widget child;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    final large = scaler.scale(16) > 20;
    final heading = Semantics(
      header: true,
      child: Text(
        title,
        style: const TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          height: 20 / 16,
          fontWeight: FontWeight.w500,
          color: Color(0xff151423),
        ),
      ),
    );
    Widget edit({bool compact = false}) => Tooltip(
      message: 'Editar $title',
      child: SizedBox(
        width: large ? scaler.scale(42) : 64,
        height: 48,
        child: TextButton(
          onPressed: onEdit,
          style:
              TextButton.styleFrom(
                foregroundColor: const Color(0xff7c3aed),
                textStyle: const TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  height: 17 / 14,
                ),
                minimumSize: const Size(48, 48),
                alignment: compact ? Alignment.topCenter : Alignment.center,
                padding: compact
                    ? EdgeInsets.only(
                        top: (scaler.scale(20) - scaler.scale(17)) / 2,
                      )
                    : EdgeInsets.zero,
                splashFactory: NoSplash.splashFactory,
              ).copyWith(
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
          child: const Text('Editar'),
        ),
      ),
    );
    if (large || onEdit == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: heading),
              if (onEdit != null) edit(),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      );
    }
    // Keep the reference's compact heading while the full 48px target remains
    // inside this section's bounds, above the card's first content line.
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(padding: const EdgeInsets.only(right: 76), child: heading),
            const SizedBox(height: 12),
            child,
          ],
        ),
        Positioned(top: 0, right: 0, child: edit(compact: true)),
      ],
    );
  }
}

class _ReviewCard extends StatelessWidget {
  const _ReviewCard({required this.rows});
  final List<(String, String)> rows;
  @override
  Widget build(BuildContext context) => DecoratedBox(
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
          for (var index = 0; index < rows.length; index++) ...[
            if (index > 0) const SizedBox(height: 8),
            Text(
              rows[index].$1,
              style: const TextStyle(
                fontSize: 12,
                height: 15 / 12,
                color: Color(0xff616174),
              ),
            ),
            Text(
              rows[index].$2.isEmpty ? 'Por confirmar' : rows[index].$2,
              style: const TextStyle(
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
}
