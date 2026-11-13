import 'dart:async';

import 'publication_age.dart';
import 'location_map_picker.dart';
import 'location_selection.dart';
import 'nearby_location_controller.dart';
import 'publication_location_default.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/design_tokens.dart';
import '../../core/config/adoption_only_build.dart';
import '../../core/ui.dart';
import '../../core/measurement.dart';
import 'community_repository.dart';
import 'community_ui.dart';
import 'photo_recovery.dart';
import 'publication_frame.dart';
import 'adoption_traits.dart';
import 'adoption_detail_layout.dart';
import '../identity/identity_controller.dart';

final publicationImagePickerProvider = Provider<ImagePicker>(
  (ref) => ImagePicker(),
);

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
  final _basicFieldAnchors = {
    for (final field in [
      'photo',
      'pet_name',
      'species',
      'sex',
      'size',
      'age_band',
      'story',
      'location',
      'city',
      'region',
      'publisher_name',
    ])
      field: GlobalKey(),
  };
  bool _showBasicGuidance = false;
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
  Json choices = {'species': null, 'sex': null, 'size': null, 'age_band': null};
  List<String> photos = [];
  Adoption? post;
  SelectedLocation? selectedLocation;
  PublicationLocationDefault? locationDefault;
  bool get mapsEnabled => ref.read(configProvider).mapsEnabled;
  bool loading = false, busy = false;
  String? error, message;
  int loaded = 0, step = 0;
  bool requiresSpecialCare = false, needsPublisherName = true;
  CommunityRepository? _formRepository;
  String? _formActor;
  bool _openingObserved = false;
  VoidCallback? _cancelOpeningObservation;
  final _reachedSteps = <int>{};
  CommunityRepository get repo => ref.read(communityRepositoryProvider);
  @override
  void initState() {
    super.initState();
    if (widget.id != 'new') {
      load();
    } else {
      prefillPublisher();
      startLocationDefault();
      _observeFormOpening(repo, repo.userId, 'adoption_form_opened');
    }
  }

  bool _currentPublicationActor(CommunityRepository source, String? actor) =>
      mounted &&
      actor != null &&
      identical(source, repo) &&
      source.userId == actor &&
      ref.read(identityControllerProvider).identity?.id == actor;

  MeasurementController? _currentPublicationMeasurement(
    CommunityRepository source,
    String? actor,
  ) {
    if (!_currentPublicationActor(source, actor)) return null;
    final measurement = ref.read(measurementControllerProvider);
    return measurement?.ownerId == actor ? measurement : null;
  }

  void Function(String) _formReporter(
    CommunityRepository source,
    String? actor,
  ) {
    final measurement = _currentPublicationMeasurement(source, actor);
    if (!identical(_formRepository, source) ||
        _formActor != actor ||
        measurement == null ||
        !measurement.preferencesReadyFor(actor) ||
        !measurement.analyticsEnabled) {
      return (_) {};
    }
    return (event) {
      if (identical(
            _currentPublicationMeasurement(source, actor),
            measurement,
          ) &&
          measurement.preferencesReadyFor(actor) &&
          measurement.analyticsEnabled) {
        unawaited(measurement.event(event));
      }
    };
  }

  void _observeFormOpening(
    CommunityRepository source,
    String? actor,
    String event,
  ) {
    if (_openingObserved) return;
    final routeId = widget.id;
    bool visible() =>
        _currentPublicationActor(source, actor) &&
        widget.id == routeId &&
        ModalRoute.isCurrentOf(context) != false;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_openingObserved || !visible()) return;
      _openingObserved = true;

      void resolve(MeasurementController measurement) {
        if (!measurement.analyticsEnabled) return;
        _formRepository = source;
        _formActor = actor;
        unawaited(measurement.event(event));
      }

      final measurement = ref.read(measurementControllerProvider);
      if (measurement == null) return;
      if (measurement.preferencesReadyFor(actor)) {
        resolve(measurement);
        return;
      }
      if (measurement.ownerId != null && measurement.ownerId != actor) return;

      final identity = ref.read(identityControllerProvider);
      void onIdentityChanged() {
        if (!visible()) _cancelOpeningObservation?.call();
      }

      final subscription = ref.listenManual(measurementControllerProvider, (
        _,
        restored,
      ) {
        if (!visible() ||
            !identical(restored, measurement) ||
            (restored?.ownerId != null && restored?.ownerId != actor)) {
          _cancelOpeningObservation?.call();
        } else if (measurement.preferencesReadyFor(actor)) {
          _cancelOpeningObservation?.call();
          resolve(measurement);
        }
      });
      identity.addListener(onIdentityChanged);
      _cancelOpeningObservation = () {
        subscription.close();
        identity.removeListener(onIdentityChanged);
        _cancelOpeningObservation = null;
      };
    });
  }

  void _observeReachedStep(int reached, void Function(String) report) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          step != reached ||
          ModalRoute.isCurrentOf(context) == false ||
          !_reachedSteps.add(reached)) {
        return;
      }
      report(
        reached == 1 ? 'adoption_details_reached' : 'adoption_preview_reached',
      );
    });
  }

  void startLocationDefault() {
    if (!mapsEnabled || widget.id != 'new') return;
    final actor = ref.read(identityControllerProvider).identity?.id;
    final source = repo;
    final config = ref.read(configProvider);
    locationDefault = PublicationLocationDefault(
      source: ref.read(nearbyLocationControllerProvider),
      lookup: ref.read(placeLookupProvider),
      mayApply: () =>
          mounted &&
          mapsEnabled &&
          selectedLocation == null &&
          identical(source, repo) &&
          repo.userId == actor &&
          ref.read(identityControllerProvider).identity?.id == actor &&
          ref.read(configProvider).environment == config.environment &&
          ref.read(configProvider).url == config.url,
      apply: (selection) => setState(() {
        selectedLocation = selection;
        fields['city']!.text = selection.city;
        fields['region']!.text = selection.region;
      }),
    )..start();
  }

  Future<void> prefillPublisher() async {
    try {
      final profile = await ref.read(identityRepositoryProvider).loadProfile();
      if (!mounted || profile.id != repo.userId) return;
      setState(() {
        if (fields['publisher_name']!.text.isEmpty) {
          fields['publisher_name']!.text = profile.name;
        }
        if (selectedLocation == null && fields['city']!.text.isEmpty) {
          fields['city']!.text = profile.city;
        }
        needsPublisherName = fields['publisher_name']!.text.trim().isEmpty;
      });
    } catch (_) {
      if (mounted) setState(() => needsPublisherName = true);
    }
  }

  ({String field, String guidance})? get _firstMissingBasicField {
    bool blank(String field) => fields[field]!.text.trim().isEmpty;
    if (photos.isEmpty) {
      return (field: 'photo', guidance: 'Agrega una foto principal.');
    }
    if (blank('pet_name')) {
      return (field: 'pet_name', guidance: 'Escribe el nombre de la mascota.');
    }
    if (choices['species'] == null) {
      return (field: 'species', guidance: 'Elige la especie.');
    }
    if (choices['sex'] == null) {
      return (field: 'sex', guidance: 'Elige el sexo.');
    }
    if (choices['size'] == null) {
      return (field: 'size', guidance: 'Elige el tamaño.');
    }
    if (choices['age_band'] == null &&
        (publicationAgeMonths(fields['age_months']!.text) ?? 0) <= 0) {
      return (field: 'age_band', guidance: 'Elige la edad aproximada.');
    }
    if (blank('story')) {
      return (field: 'story', guidance: 'Cuéntanos su historia.');
    }
    final missingCity = blank('city');
    final missingRegion = blank('region');
    if (mapsEnabled &&
        (selectedLocation == null || missingCity || missingRegion)) {
      return (field: 'location', guidance: 'Elige la ubicación en el mapa.');
    }
    if (missingCity) {
      return (field: 'city', guidance: 'Escribe la ciudad.');
    }
    if (missingRegion) {
      return (field: 'region', guidance: 'Escribe el estado.');
    }
    if (blank('publisher_name')) {
      return (
        field: 'publisher_name',
        guidance: 'Escribe tu nombre público o el de tu refugio.',
      );
    }
    return null;
  }

  Future<void> _continuePublication() async {
    if (busy) return;
    final missing = step == 0 ? _firstMissingBasicField : null;
    if (missing != null) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _showBasicGuidance = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || step != 0) return;
        final target = _basicFieldAnchors[missing.field]?.currentContext;
        if (target != null) {
          unawaited(
            Scrollable.ensureVisible(
              target,
              alignment: missing.field == 'photo' ? .5 : .1,
              duration: const Duration(milliseconds: 220),
            ),
          );
        }
      });
      return;
    }
    await perform(() async {
      final source = repo;
      final report = _formReporter(source, source.userId);
      if (!form.currentState!.validate()) return;
      await save();
      if (mounted) {
        setState(() {
          _showBasicGuidance = false;
          step++;
        });
        _observeReachedStep(step, report);
      }
    });
  }

  void backStep() {
    if (busy) return;
    if (step > 0 && post?.status != 'submitted') {
      setState(() => step--);
    } else if (context.canPop()) {
      context.pop();
    } else {
      context.go(adoptionOnlyBuild ? '/my-cases' : '/publish');
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
    _cancelOpeningObservation?.call();
    locationDefault?.dispose();
    for (final field in fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> load() async {
    final source = repo;
    final actor = source.userId;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await source.own(post?.id ?? widget.id);
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
          needsPublisherName = fields['publisher_name']!.text.trim().isEmpty;
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
          selectedLocation = SelectedLocation.fromData(
            result.data,
            city: fields['city']!.text,
            region: fields['region']!.text,
          );
          if (result.status == 'submitted') step = 2;
        });
        if (widget.id != 'new' &&
            (result.status == 'draft' ||
                result.status == 'changes_requested') &&
            result.data['_has_private_draft'] != true &&
            result.data['published_at'] == null) {
          _observeFormOpening(source, actor, 'adoption_draft_resumed');
        }
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

  Future<void> choosePetLocation() async {
    locationDefault?.dispose();
    final repository = repo;
    final actor = repository.userId;
    final identity = ref.read(identityControllerProvider).identity?.id;
    final result = await chooseLocationOnMap(
      context,
      initial:
          selectedLocation ??
          ref.read(nearbyLocationControllerProvider).publicationDefault,
      city: fields['city']!.text,
      region: fields['region']!.text,
    );
    if (!mounted ||
        result == null ||
        !identical(repository, repo) ||
        repository.userId != actor ||
        ref.read(identityControllerProvider).identity?.id != identity) {
      return;
    }
    setState(() {
      selectedLocation = result;
      fields['city']!.text = result.city;
      fields['region']!.text = result.region;
    });
  }

  Future<void> save() async {
    final payload = <String, dynamic>{
      ...choices,
      for (final entry in fields.entries) entry.key: entry.value.text.trim(),
      'photos': photos,
      if (selectedLocation != null) ...selectedLocation!.payload,
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
        message = result.status == 'published'
            ? 'Guardamos tus cambios privados. La versión aprobada sigue activa hasta que revisemos y aprobemos la edición.'
            : 'Guardamos tu borrador. Puedes continuar después.';
      });
    }
  }

  Future<void> change(String action) => perform(() async {
    final source = repo;
    final actor = source.userId;
    final report = _formReporter(source, actor);
    if (action == 'submit') {
      report('adoption_submit_attempted');
      if (!form.currentState!.validate()) {
        report('adoption_submit_validation_failed');
        return;
      }
      try {
        await save();
      } catch (_) {
        report('adoption_submit_save_failed');
        rethrow;
      }
    }
    final Adoption result;
    try {
      result = await repo.transition(post!, action);
    } catch (_) {
      if (action == 'submit') report('adoption_submit_transition_failed');
      rethrow;
    }
    if (action == 'submit') {
      report(
        result.status == 'submitted'
            ? 'adoption_submit_accepted'
            : 'adoption_submit_transition_failed',
      );
      final measurement = _currentPublicationMeasurement(source, actor);
      if (measurement != null) {
        unawaited(measurement.event('publication_submitted'));
      }
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
        await showPublicationSubmittedDialog(context);
      }
    }
  });
  Future<void> addPhoto({
    ImageSource source = ImageSource.gallery,
    bool replaceMain = false,
  }) => perform(() async {
    if (!replaceMain && photos.length >= 6) return;
    final repository = repo;
    final actor = repository.userId;
    final identity = ref.read(identityControllerProvider).identity?.id;
    if (actor == null || identity != actor) return;
    final config = ref.read(configProvider);
    bool current() =>
        mounted &&
        identical(repository, repo) &&
        repository.userId == actor &&
        ref.read(identityControllerProvider).identity?.id == identity &&
        ref.read(configProvider).environment == config.environment &&
        ref.read(configProvider).url == config.url;
    final report = replaceMain ? _formReporter(repository, actor) : null;
    report?.call(
      source == ImageSource.camera
          ? 'adoption_main_photo_camera'
          : 'adoption_main_photo_gallery',
    );
    var failureEvent = 'adoption_photo_prep_failed';
    try {
      await save(); // Preserve all fields before the operating system opens its photo picker.
      if (!current()) return;
      final postId = post!.id;
      final preferences = await SharedPreferences.getInstance();
      if (!current()) return;
      final pendingKey = pendingPhotoKey(actor);
      await preferences.setString(pendingKey, postId);
      if (!current()) return;
      await preferences.setString(pendingPhotoActorKey, actor);
      if (!current()) return;
      failureEvent = 'adoption_photo_picker_failed';
      final picker = ref.read(publicationImagePickerProvider);
      final List<XFile> files;
      if (source == ImageSource.gallery && !replaceMain) {
        files = await picker.pickMultiImage(
          maxWidth: 1600,
          maxHeight: 1600,
          limit: 6 - photos.length,
          requestFullMetadata: false,
        );
      } else {
        final file = await picker.pickImage(
          source: source,
          maxWidth: 1600,
          maxHeight: 1600,
          requestFullMetadata: false,
        );
        files = file == null ? [] : [file];
      }
      if (!current()) return;
      await preferences.remove(pendingKey);
      if (preferences.getString(pendingPhotoActorKey) == actor) {
        await preferences.remove(pendingPhotoActorKey);
      }
      if (files.isEmpty) {
        report?.call('adoption_photo_picker_cancelled');
        return;
      }
      for (final file in files.take(replaceMain ? 1 : 6 - photos.length)) {
        if (!current()) return;
        failureEvent = 'adoption_photo_read_failed';
        final bytes = await file.readAsBytes();
        if (!current()) return;
        failureEvent = 'adoption_photo_upload_failed';
        final path = await repository.uploadPhoto(postId, bytes);
        if (!current()) return;
        setState(() {
          if (replaceMain && photos.isNotEmpty) {
            photos[0] = path;
          } else {
            photos.add(path);
          }
        });
        // A later failure must not lose photos already attached successfully.
        failureEvent = 'adoption_photo_attach_save_failed';
        await save();
      }
      if (current()) report?.call('adoption_photo_attached');
    } catch (cause) {
      if (current()) {
        const deniedCodes = {
          'camera_access_denied',
          'camera_access_restricted',
          'photo_access_denied',
          'photo_access_restricted',
        };
        final denied =
            failureEvent == 'adoption_photo_picker_failed' &&
            cause is PlatformException &&
            deniedCodes.contains(cause.code);
        if (denied) {
          failureEvent = 'adoption_photo_picker_denied';
        } else if (failureEvent == 'adoption_photo_upload_failed' &&
            cause is FormatException) {
          failureEvent = 'adoption_photo_process_failed';
        }
        report?.call(failureEvent);
      }
      rethrow;
    }
  });
  Widget field(
    String key,
    String label,
    int max, {
    int lines = 1,
    bool required = false,
  }) => Padding(
    key: _basicFieldAnchors[key],
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PublicationFieldLabel(
          label,
          required: required,
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
                  borderSide: const BorderSide(color: DopmiTokens.ink),
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
    key: _basicFieldAnchors[key],
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
    final footer = PublicationFooter(
      label: step < 2 ? 'Continuar' : 'Enviar a revisión',
      review: step == 2,
      saveLabel: post?.status == 'published'
          ? 'Guardar cambios'
          : 'Guardar borrador',
      busy: busy,
      compact: compact,
      onSave: () => perform(save),
      onContinue: step < 2 ? _continuePublication : () => change('submit'),
    );
    final guidance = step == 0 && _showBasicGuidance
        ? _firstMissingBasicField?.guidance
        : null;
    if (guidance == null) return footer;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          liveRegion: true,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text(
              guidance,
              style: const TextStyle(
                color: DopmiTokens.danger,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        footer,
      ],
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
        sectionTitle('Características de la mascota'),
        const Text(
          'Selecciona las que apliquen. Ninguna es obligatoria pero ayudará al adoptante a motivarse más rápido.',
          style: TextStyle(fontSize: 14, height: 1.5, color: muted),
        ),
        const SizedBox(height: 20),
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
                            ? DopmiTokens.saffronSoft
                            : const Color(0xfffafafd),
                        foregroundColor: coexistence.contains(item.key)
                            ? DopmiTokens.ink
                            : const Color(0xff151423),
                        minimumSize: const Size(0, 72),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        side: BorderSide(
                          color: coexistence.contains(item.key)
                              ? DopmiTokens.yellow
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
                        ? DopmiTokens.ink
                        : personalityTextColors[item.key] ??
                              const Color(0xff151423),
                    disabledForegroundColor:
                        personalityTextColors[item.key] ??
                        const Color(0xff151423),
                    side: BorderSide(
                      color: traits.contains(item.key)
                          ? DopmiTokens.ink
                          : personalityBorderColors[item.key] ??
                                const Color(0xffe3e4ed),
                      width: traits.contains(item.key) ? 2 : 1,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    item.value,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      height: 1.2,
                      fontWeight: traits.contains(item.key)
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ),
          ],
        ),
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
          if (!adoptionOnlyBuild &&
              (widget.rescueCaseId != null ||
                  post?.data['rescue_case_id'] != null))
            const Notice(
              'Esta publicación está vinculada a un caso aprobado. Su revisión de adopción es independiente.',
            ),
          if (post?.text('review_feedback').isNotEmpty == true)
            Notice('Respuesta del equipo: ${post!.text('review_feedback')}'),
          if (post?.status == 'published')
            const Notice(
              'La versión aprobada sigue activa. Tus cambios y fotos se guardan en privado y necesitan una nueva revisión antes de publicarse.',
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
                    pickerKey: _basicFieldAnchors['photo'],
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
                  if (mapsEnabled)
                    PublicationLocationField(
                      key: _basicFieldAnchors['location'],
                      city: fields['city']!.text,
                      region: fields['region']!.text,
                      selection: selectedLocation,
                      onChoose: busy ? null : choosePetLocation,
                    )
                  else ...[
                    field('city', 'Ciudad', 100, required: true),
                    field('region', 'Estado', 100, required: true),
                  ],
                  if (needsPublisherName) ...[
                    const Notice(
                      'Falta tu nombre público. Complétalo para identificar quién publica este caso.',
                    ),
                    field(
                      'publisher_name',
                      'Nombre público o del refugio',
                      80,
                      required: true,
                    ),
                  ],
                ],
                if (step == 1) extras(),
                if (step == 2) ...[
                  const PublicationPreviewIntro(
                    'Esta es una previsualización de la publicación que verán los adoptantes.',
                  ),
                  PublicationPreviewFrame(
                    expandToContent: true,
                    child: AdoptionDetailLayout(
                      post: previewPost(),
                      saved: false,
                      busy: true,
                      owner: true,
                      preview: true,
                      inlinePreview: true,
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
              ],
            ),
          ),
        ],
      ],
    ),
  );
}
