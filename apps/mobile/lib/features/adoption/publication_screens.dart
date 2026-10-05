import 'publication_age.dart';

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
import 'adoption_traits.dart';
import 'adoption_detail_layout.dart';
import '../identity/identity_controller.dart';

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
  bool requiresSpecialCare = false, careEditorOpen = false;
  CommunityRepository get repo => ref.read(communityRepositoryProvider);
  @override
  void initState() {
    super.initState();
    if (widget.id != 'new') {
      load();
    } else {
      prefillPublisher();
    }
  }

  Future<void> prefillPublisher() async {
    try {
      final profile = await ref.read(identityRepositoryProvider).loadProfile();
      if (!mounted || profile.id != repo.userId) return;
      setState(() {
        if (fields['publisher_name']!.text.isEmpty) {
          fields['publisher_name']!.text = profile.name;
        }
        if (fields['city']!.text.isEmpty) fields['city']!.text = profile.city;
      });
    } catch (_) {
      // Manual public identity and location remain available when profile loading fails.
    }
  }

  bool get basicComplete =>
      photos.isNotEmpty &&
      fields['pet_name']!.text.trim().isNotEmpty &&
      fields['story']!.text.trim().length >= 10 &&
      choices['species'] != null &&
      choices['sex'] != null &&
      choices['size'] != null &&
      (choices['age_band'] != null ||
          (publicationAgeMonths(fields['age_months']!.text) ?? 0) > 0) &&
      fields['city']!.text.trim().isNotEmpty &&
      fields['region']!.text.trim().isNotEmpty &&
      fields['publisher_name']!.text.trim().isNotEmpty;

  void backStep() {
    if (busy) return;
    if (step > 0 && post?.status != 'submitted') {
      setState(() => step--);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go('/publish');
    }
  }

  Future<void> pickMainPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Subir desde galería'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source != null && mounted) {
      await addPhoto(source: source, replaceMain: true);
    }
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
          requiresSpecialCare = fields['special_care']!.text.trim().isNotEmpty;
          careEditorOpen =
              requiresSpecialCare &&
              fields['special_care']!.text.trim() !=
                  'Requiere cuidados especiales';
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
              'age_band',
              'coexistence',
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
    payload['special_care'] = requiresSpecialCare
        ? (fields['special_care']!.text.trim().isEmpty
              ? 'Requiere cuidados especiales'
              : fields['special_care']!.text.trim())
        : '';
    final age = publicationAgeMonths(fields['age_months']!.text);
    if (age == null) {
      throw const FormatException(
        'Escribe una edad válida en meses o años, hasta 30 años.',
      );
    }
    payload['age_months'] = age;
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
      if (action == 'submit' && result.status == 'submitted') {
        setState(() => busy = false);
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const Icon(
              Icons.check_circle_outline,
              color: Color(0xff7841f2),
              size: 48,
            ),
            title: const Text('Enviado a revisión'),
            content: const Text(
              'Gracias por compartir su historia. Dopmi revisará el caso antes de publicarlo.',
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Entendido'),
              ),
            ],
          ),
        );
      }
    }
  });
  Future<void> addPhoto({
    ImageSource source = ImageSource.gallery,
    bool replaceMain = false,
  }) => perform(() async {
    if (!replaceMain && photos.length >= 6) return;
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
    setState(() {
      if (replaceMain && photos.isNotEmpty) {
        photos[0] = path;
      } else {
        photos.add(path);
      }
    });
    await save();
  });
  Widget field(
    String key,
    String label,
    int max, {
    int lines = 1,
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text.rich(
          TextSpan(
            text: label,
            children: required
                ? [
                    const TextSpan(
                      text: ' *',
                      style: TextStyle(color: Color(0xffe62c2c)),
                    ),
                  ]
                : const [],
          ),
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
          child: KeyedSubtree(
            key: PageStorageKey('publication-field-scroll-$key'),
            child: TextFormField(
              key: ValueKey('publication-field-$key'),
              controller: fields[key],
              enabled: !busy && post?.status != 'submitted',
              maxLength: key == 'pet_name' && fields[key]!.text.length <= 25
                  ? 25
                  : max,
              maxLines: lines,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 16,
                height: 20 / 16,
                color: Color(0xff151423),
              ),
              keyboardType: lines > 1
                  ? TextInputType.multiline
                  : TextInputType.text,
              decoration: InputDecoration(
                isDense: true,
                hintText: key == 'pet_name'
                    ? 'Ej. Luna'
                    : key == 'age_months'
                    ? 'ej. 3 meses'
                    : key == 'story'
                    ? 'Cuéntanos cómo llegó a ti. Danos una descripción de él/ella.'
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
              onChanged: (_) => setState(() {}),
              validator: key == 'age_months'
                  ? (value) {
                      final months = publicationAgeMonths(value ?? '');
                      return months == null || months < 0 || months > 360
                          ? 'Escribe una edad válida en meses o años, hasta 30 años.'
                          : null;
                    }
                  : null,
            ),
          ),
        ),
        if (key == 'age_months') ...[
          const SizedBox(height: 8),
          const Text(
            'Puede ser aproximada.',
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
    required: ['sex', 'species', 'size', 'age_band'].contains(key),
    verticalIcons: key == 'size',
    leading: switch (key) {
      'sex' => const {
        'male': Icon(Icons.male, size: 16),
        'female': Icon(Icons.female, size: 16),
      },
      'species' => {
        for (final species in ['dog', 'cat'])
          species: PublicationPetIcon(species),
      },
      'size' => {
        for (final entry in const {
          'small': 14.0,
          'medium': 22.0,
          'large': 30.0,
        }.entries)
          entry.key: PublicationPetIcon('dog', size: entry.value),
      },
      _ => const {},
    },
    value: choices[key] as String?,
    onChanged: busy || post?.status == 'submitted'
        ? null
        : (value) => setState(() => choices[key] = value),
  );
  Widget trait(String key, String label) => PublicationTraitCheck(
    key: ValueKey('publication-trait-$key'),
    label: label,
    value: choices[key] as bool?,
    onChanged: busy || post?.status == 'submitted'
        ? null
        : (value) => setState(() => choices[key] = value),
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
      onContinue: step == 0 && !basicComplete
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

  Widget sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(
      text,
      style: const TextStyle(
        fontFamily: 'Inter',
        fontSize: 18,
        height: 28 / 18,
        fontWeight: FontWeight.w600,
        color: Color(0xff151423),
      ),
    ),
  );

  Widget extras() {
    final traits = List<String>.from(
      choices['personality'] as List? ?? const [],
    );
    final coexistence = List<String>.from(
      choices['coexistence'] as List? ?? const [],
    );
    final enabled = !busy && post?.status != 'submitted';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        sectionTitle('Complementa sus fotos'),
        const Text(
          'Puedes agregar hasta 5 fotos más.',
          style: TextStyle(fontSize: 14, color: Color(0xff8a837c)),
        ),
        const SizedBox(height: 16),
        if (photos.length < 6 && enabled)
          PublicationPhotoPicker(
            supplementary: true,
            onCamera: () => addPhoto(source: ImageSource.camera),
            onGallery: () => addPhoto(),
          ),
        if (photos.length > 1) ...[
          const SizedBox(height: 16),
          const Text(
            'Fotos agregadas',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var index = 1; index < photos.length; index++)
                PublicationPhotoThumbnail(
                  key: ValueKey(photos[index]),
                  size: 110,
                  photo: AdoptionPhoto(photos[index], height: 110),
                  principal: false,
                  onRemove: enabled
                      ? () => setState(() => photos.removeAt(index))
                      : null,
                ),
            ],
          ),
        ],
        const SizedBox(height: 24),
        sectionTitle('Salud'),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xffe3e4ed)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              trait('vaccinated', 'Vacunado'),
              const SizedBox(height: 10),
              trait('sterilized', 'Esterilizado'),
              const SizedBox(height: 10),
              PublicationTraitCheck(
                key: const ValueKey('publication-special-care'),
                label: 'Requiere cuidados especiales',
                value: requiresSpecialCare,
                onChanged: enabled
                    ? (_) => setState(
                        () => requiresSpecialCare = !requiresSpecialCare,
                      )
                    : null,
              ),
            ],
          ),
        ),
        if (requiresSpecialCare && !careEditorOpen)
          TextButton(
            onPressed: enabled
                ? () => setState(() => careEditorOpen = true)
                : null,
            child: const Text('Describir cuidados'),
          ),
        if (requiresSpecialCare && careEditorOpen)
          field(
            'special_care',
            'Cuidados especiales (opcional)',
            1000,
            lines: 3,
          ),
        const SizedBox(height: 24),
        const Text(
          'Convivencia y hogar',
          style: TextStyle(
            fontSize: 16,
            height: 1.5,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = MediaQuery.textScalerOf(context).scale(14) > 20
                ? constraints.maxWidth
                : (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final item in coexistenceLabels.entries)
                  SizedBox(
                    width: width,
                    child: OutlinedButton(
                      key: ValueKey('publication-coexistence-${item.key}'),
                      onPressed: enabled
                          ? () => setState(() {
                              coexistence.contains(item.key)
                                  ? coexistence.remove(item.key)
                                  : coexistence.add(item.key);
                              choices['coexistence'] = coexistence;
                            })
                          : null,
                      style: OutlinedButton.styleFrom(
                        backgroundColor: coexistence.contains(item.key)
                            ? const Color(0xfff3eeff)
                            : const Color(0xfffafafd),
                        foregroundColor: coexistence.contains(item.key)
                            ? const Color(0xff5b21b6)
                            : const Color(0xff151423),
                        minimumSize: const Size(0, 72),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        side: BorderSide(
                          color: coexistence.contains(item.key)
                              ? const Color(0xff7841f2)
                              : const Color(0xffe3e4ed),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        item.value,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 13, height: 1.35),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
        if (choices['social_dogs'] != null ||
            choices['social_cats'] != null ||
            choices['social_children'] != null)
          ExpansionTile(
            key: const PageStorageKey('publication-legacy-compatibility'),
            title: const Text('Compatibilidad registrada'),
            tilePadding: EdgeInsets.zero,
            children: [
              trait('social_dogs', 'Social con perros'),
              trait('social_cats', 'Social con gatos'),
              trait('social_children', 'Social con niñas y niños'),
            ],
          ),
        const SizedBox(height: 24),
        const Row(
          children: [
            Expanded(
              child: Text(
                'Personalidad',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              'Máximo 3',
              style: TextStyle(fontSize: 12, color: Color(0xff8a837c)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in {
              ...personalityLabels,
              for (final old in legacyPersonalityLabels.entries)
                if (traits.contains(old.key)) old.key: old.value,
            }.entries)
              Opacity(
                opacity:
                    enabled && !traits.contains(item.key) && traits.length >= 3
                    ? .45
                    : 1,
                child: OutlinedButton(
                  key: ValueKey('publication-personality-${item.key}'),
                  onPressed:
                      enabled &&
                          (traits.contains(item.key) || traits.length < 3)
                      ? () => setState(() {
                          traits.contains(item.key)
                              ? traits.remove(item.key)
                              : traits.add(item.key);
                          choices['personality'] = traits;
                        })
                      : null,
                  style: OutlinedButton.styleFrom(
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    minimumSize: const Size(0, 32),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    backgroundColor:
                        personalityColors[item.key] ?? const Color(0xfff3f2f8),
                    foregroundColor: traits.contains(item.key)
                        ? const Color(0xff4c1d95)
                        : personalityTextColors[item.key] ??
                              const Color(0xff151423),
                    disabledForegroundColor:
                        personalityTextColors[item.key] ??
                        const Color(0xff151423),
                    side: BorderSide(
                      color: traits.contains(item.key)
                          ? const Color(0xff7c3aed)
                          : personalityBorderColors[item.key] ??
                                const Color(0xffe3e4ed),
                      width: traits.contains(item.key) ? 2 : 1,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    item.value,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 24),
        field('breed', 'Raza o mestizo (opcional)', 80),
      ],
    );
  }

  Adoption previewPost() => Adoption({
    ...?post?.data,
    ...choices,
    for (final item in fields.entries) item.key: item.value.text.trim(),
    'id': post?.id ?? 'preview',
    'owner_id': repo.userId ?? '',
    'age_months': publicationAgeMonths(fields['age_months']!.text) ?? 0,
    'photos': List<String>.from(photos),
    'special_care': requiresSpecialCare
        ? (fields['special_care']!.text.trim().isEmpty
              ? 'Requiere cuidados especiales'
              : fields['special_care']!.text.trim())
        : '',
  });

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !busy && (step == 0 || post?.status == 'submitted'),
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) backStep();
    },
    child: PublicationFrame(
      title: step == 2
          ? 'Valida tu caso'
          : step == 1
          ? 'Un poco más...'
          : 'Empecemos...',
      step: step,
      footer: publicationFooter(),
      onBack: busy ? null : backStep,
      children: [
        const PhotoRecoveryNotice(),
        if (loading) const Center(child: CircularProgressIndicator()),
        if (error != null) Notice(error!, isError: true),
        if (!loading && widget.id != 'new' && post == null)
          ActionButton('Volver a intentar', onPressed: load),
        if (!loading && (post != null || widget.id == 'new')) ...[
          if (widget.rescueCaseId != null ||
              post?.data['rescue_case_id'] != null)
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
                if (step == 0) ...[
                  sectionTitle('Perfil'),
                  PublicationMainPhoto(
                    photo: photos.isEmpty
                        ? null
                        : AdoptionPhoto(photos.first, height: 120),
                    onPick: busy || post?.status == 'submitted'
                        ? null
                        : pickMainPhoto,
                  ),
                  field('pet_name', 'Nombre de la mascota', 80, required: true),
                  publicationChoice('species', 'Especie', const {
                    'dog': 'Perro',
                    'cat': 'Gato',
                  }),
                  publicationChoice('sex', 'Sexo', const {
                    'male': 'Macho',
                    'female': 'Hembra',
                  }),
                  publicationChoice('size', 'Tamaño', const {
                    'small': 'Chico',
                    'medium': 'Mediano',
                    'large': 'Grande',
                  }),
                  publicationChoice('age_band', 'Edad', ageBandLabels),
                  sectionTitle('Su historia'),
                  field(
                    'story',
                    'Historia de rescate',
                    4000,
                    lines: 4,
                    required: true,
                  ),
                  field('city', 'Ciudad', 100, required: true),
                  field('region', 'Estado', 100, required: true),
                  ExpansionTile(
                    key: const PageStorageKey('publication-public-identity'),
                    tilePadding: EdgeInsets.zero,
                    title: const Text('Presentación pública y edad precisa'),
                    initiallyExpanded: fields['publisher_name']!.text.isEmpty,
                    children: [
                      field(
                        'publisher_name',
                        'Nombre público o del refugio',
                        80,
                        required: true,
                      ),
                      field(
                        'publisher_bio',
                        'Sobre ti y tu labor (opcional)',
                        1000,
                        lines: 3,
                      ),
                      field('age_months', 'Edad precisa (opcional)', 40),
                    ],
                  ),
                ],
                if (step == 1) extras(),
                if (step == 2) ...[
                  const PublicationPreviewIntro(
                    'Esta es una previsualización de la publicación que verán los adoptantes.',
                  ),
                  PublicationPreviewFrame(
                    child: AdoptionDetailLayout(
                      post: previewPost(),
                      saved: false,
                      busy: true,
                      owner: true,
                      preview: true,
                      favorite: () {},
                      contact: () {},
                      share: () {},
                      report: () {},
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Notice(
                    'Al enviar, el equipo revisará fotos, información y privacidad antes de publicar.',
                  ),
                ],
                if (message != null) Notice(message!),
                if (post?.status == 'published')
                  OutlinedButton(
                    onPressed: busy ? null : () => change('adopted'),
                    child: const Text('Marcar adopción realizada'),
                  ),
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
    ),
  );
}
