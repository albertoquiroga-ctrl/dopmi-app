import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/ui.dart';
import 'community_repository.dart';
import 'community_ui.dart';
import 'photo_recovery.dart';

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
    if (mounted) {
      setState(() {
        post = result;
        message = action == 'submit'
            ? 'Enviamos tu publicación a revisión. Te avisaremos aquí cuando haya respuesta.'
            : 'Actualizamos el estado de tu publicación.';
      });
    }
  });
  Future<void> addPhoto() => perform(() async {
    if (!form.currentState!.validate()) return;
    await save(); // Preserve all fields before the operating system opens its photo picker.
    final preferences = await SharedPreferences.getInstance();
    final pendingKey = pendingPhotoKey(repo.userId!);
    await preferences.setString(pendingKey, post!.id);
    final file = await ImagePicker().pickImage(
      source: ImageSource.gallery,
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
  @override
  Widget build(BuildContext context) => CommunityFrame(
    children: [
      Heading(
        post?.name.isNotEmpty == true ? post!.name : 'Una nueva historia.',
        'Completa lo que sabes. Puedes guardar un borrador antes de enviarlo.',
        eyebrow: post == null
            ? 'NUEVA PUBLICACIÓN'
            : statusLabels[post!.status]?.toUpperCase(),
      ),
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
        _PublishSteps(step: step),
        const SizedBox(height: 18),
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (step == 1) ...[
                Text(
                  'Su información',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 18),
                field('pet_name', 'Nombre de la mascota', 80),
                choice('species', 'Especie', {'dog': 'Perro', 'cat': 'Gato'}),
                choice('sex', 'Sexo', {'female': 'Hembra', 'male': 'Macho'}),
                field('age_months', 'Edad aproximada en meses', 3),
                choice('size', 'Tamaño', {
                  'small': 'Pequeño',
                  'medium': 'Mediano',
                  'large': 'Grande',
                }),
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
                Text(
                  'Fotos (${photos.length}/5)',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Usa fotos de la mascota sin documentos ni direcciones visibles. Eliminamos los metadatos de las imágenes antes de subirlas.',
                  ),
                ),
                for (final path in photos)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      children: [
                        AdoptionPhoto(path, height: 200),
                        if (post?.status != 'submitted')
                          TextButton.icon(
                            onPressed: busy
                                ? null
                                : () => setState(() => photos.remove(path)),
                            icon: const Icon(Icons.close),
                            label: const Text('Quitar foto del borrador'),
                          ),
                      ],
                    ),
                  ),
                if (photos.length < 5 && post?.status != 'submitted')
                  OutlinedButton.icon(
                    onPressed: busy ? null : addPhoto,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Agregar una foto'),
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
              if (error != null) Notice(error!, isError: true),
              const SizedBox(height: 20),
              if (post?.status != 'submitted') ...[
                if (step < 2)
                  ActionButton(
                    'Guardar y continuar',
                    busy: busy,
                    onPressed: () => perform(() async {
                      if (!form.currentState!.validate()) return;
                      await save();
                      if (mounted) setState(() => step++);
                    }),
                  )
                else ...[
                  ActionButton(
                    'Enviar a revisión',
                    busy: busy,
                    onPressed: () => change('submit'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: busy ? null : () => perform(save),
                    child: const Text('Guardar borrador'),
                  ),
                ],
                if (step > 0)
                  TextButton(
                    onPressed: busy ? null : () => setState(() => step--),
                    child: const Text('Regresar al paso anterior'),
                  ),
              ] else
                ActionButton(
                  'Retirar de revisión para editar',
                  busy: busy,
                  onPressed: () => change('withdraw'),
                ),
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

class _PublishSteps extends StatelessWidget {
  const _PublishSteps({required this.step});
  final int step;
  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Paso ${step + 1} de 3',
    child: Row(
      children: [
        for (final entry in ['Fotos', 'Información', 'Revisión'].indexed) ...[
          Expanded(
            child: Column(
              children: [
                LinearProgressIndicator(
                  value: entry.$1 <= step ? 1 : 0,
                  minHeight: 5,
                  borderRadius: BorderRadius.circular(5),
                  backgroundColor: const Color(0xffe7e2da),
                ),
                const SizedBox(height: 5),
                Text(entry.$2, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          if (entry.$1 < 2) const SizedBox(width: 8),
        ],
      ],
    ),
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
