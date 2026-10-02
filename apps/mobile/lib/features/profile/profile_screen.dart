import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';

import '../../core/measurement.dart';
import '../../core/ui.dart';
import '../identity/identity_controller.dart';
import '../identity/identity_repository.dart';
import '../identity/experience_controller.dart';

class BasicInfoScreen extends ConsumerStatefulWidget {
  const BasicInfoScreen({super.key});
  @override
  ConsumerState<BasicInfoScreen> createState() => _BasicInfoScreenState();
}

class _BasicInfoScreenState extends ConsumerState<BasicInfoScreen> {
  final form = GlobalKey<FormState>();
  final name = TextEditingController(),
      phone = TextEditingController(),
      city = TextEditingController();
  Profile? profile;
  bool loading = true, busy = false;
  String mode = 'donor';
  String? error, message;
  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    city.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await ref.read(identityRepositoryProvider).loadProfile();
      if (mounted) {
        ref.read(experienceProvider).applyProfile(result);
        setState(() {
          profile = result;
          name.text = result.name;
          phone.text = result.phone;
          city.text = result.city;
          mode = result.mode;
        });
      }
    } catch (cause) {
      if (mounted) setState(() => error = identityError(cause));
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
      if (mounted) setState(() => error = identityError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    await perform(() async {
      final result = await ref
          .read(identityRepositoryProvider)
          .saveProfile(name: name.text, phone: phone.text, city: city.text);
      if (mounted) {
        ref.read(experienceProvider).applyProfile(result);
        setState(() {
          profile = result;
          message = 'Guardamos los cambios de tu perfil.';
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final identity = ref.read(identityControllerProvider).identity;
    final suspended = profile?.status == 'suspended';
    final large = MediaQuery.textScalerOf(context).scale(18) > 25;
    return Scaffold(
      backgroundColor: cream,
      appBar: AppBar(
        centerTitle: true,
        toolbarHeight: large
            ? MediaQuery.textScalerOf(context).scale(18) * 2.6 + 16
            : 67,
        title: Text(
          'Información básica',
          maxLines: large ? 3 : 1,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 18,
            height: 1.2,
            letterSpacing: 0,
            color: ink,
            fontWeight: FontWeight.w700,
          ),
        ),
        leading: IconButton(
          tooltip: 'Volver',
          onPressed: () =>
              context.canPop() ? context.pop() : context.go('/settings'),
          icon: SvgPicture.asset(
            'assets/profile/back.svg',
            width: 20,
            height: 20,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xffe6e2dd)),
        ),
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
          children: [
            if (loading)
              const Center(
                child: CircularProgressIndicator(
                  semanticsLabel: 'Cargando perfil',
                ),
              ),
            if (!loading && profile == null) ...[
              Notice(error ?? 'No pudimos cargar tu perfil.', isError: true),
              ActionButton('Volver a intentar', onPressed: load),
            ],
            if (!loading && profile != null) ...[
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: yellow,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 27,
                      backgroundColor: cream,
                      child: Icon(Icons.person_outline, color: ink, size: 32),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            profile!.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          Text(
                            identity?.email ?? '',
                            style: const TextStyle(color: ink),
                          ),
                          const SizedBox(height: 4),
                          const Row(
                            children: [
                              Icon(
                                Icons.verified_outlined,
                                size: 16,
                                color: ink,
                              ),
                              SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  'Correo confirmado',
                                  style: TextStyle(color: ink),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              if (suspended)
                const Notice(
                  'Tu cuenta está suspendida. Contacta al equipo Dopmi para revisar tu acceso.',
                  isError: true,
                ),
              for (final shortcut in const [
                ('Guardados', '/saved', Icons.favorite_border),
                ('Mis mensajes', '/messages', Icons.chat_bubble_outline),
                ('Mis publicaciones', '/my-adoptions', Icons.pets_outlined),
                (
                  'Rescatistas guardados',
                  '/saved?kind=rescuer',
                  Icons.bookmark_border,
                ),
                ('Mi impacto', '/impact', Icons.auto_stories_outlined),
                ('Configuración', '/settings', Icons.settings_outlined),
              ])
                ListTile(
                  leading: Icon(shortcut.$3),
                  title: Text(shortcut.$1),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(shortcut.$2),
                ),
              Form(
                key: form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Mis datos',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: name,
                      enabled: !suspended && !busy,
                      maxLength: 80,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (value) => (value ?? '').trim().isEmpty
                          ? 'Escribe tu nombre.'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phone,
                      enabled: !suspended && !busy,
                      maxLength: 24,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Teléfono (opcional)',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: city,
                      enabled: !suspended && !busy,
                      maxLength: 100,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Ciudad (opcional)',
                        counterText: '',
                      ),
                    ),
                    const SizedBox(height: 28),
                    if (error != null) Notice(error!, isError: true),
                    if (message != null) Notice(message!),
                    const SizedBox(height: 24),
                    ActionButton(
                      'Guardar cambios',
                      busy: busy,
                      onPressed: suspended ? null : save,
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: busy
                  ? null
                  : () => perform(
                      () => ref.read(identityControllerProvider).logout(),
                    ),
              child: const Text('Cerrar sesión'),
            ),
            TextButton(
              onPressed: () => context.push('/terms'),
              child: const Text('Términos y privacidad'),
            ),
          ],
        ),
      ),
    );
  }
}

class ConsentScreen extends ConsumerStatefulWidget {
  const ConsentScreen({super.key, this.onTerms, this.onPrivacy});
  final VoidCallback? onTerms, onPrivacy;

  @override
  ConsumerState<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends ConsumerState<ConsentScreen> {
  bool loading = true, busy = false, consent = false;
  String? error;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    if (mounted) {
      setState(() {
        loading = true;
        error = null;
      });
    }
    try {
      final profile = await ref.read(identityRepositoryProvider).loadProfile();
      if (!mounted) return;
      ref.read(experienceProvider).applyProfile(profile);
    } catch (cause) {
      if (mounted) setState(() => error = identityError(cause));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> accept() async {
    if (busy || !consent) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(identityRepositoryProvider).acceptTerms();
      await ref.read(measurementControllerProvider)?.event('sign_up_completed');
      await load();
    } catch (cause) {
      if (mounted) setState(() => error = identityError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    back: false,
    children: [
      const Heading(
        'Antes de continuar',
        'Dopmi es exclusivamente para personas mayores de 18 años.',
        eyebrow: 'TU CUENTA',
      ),
      if (loading) const Center(child: CircularProgressIndicator()),
      if (!loading) ...[
        const Notice(
          'Revisa y acepta los términos y el aviso de privacidad vigentes para usar Dopmi.',
        ),
        TextButton(
          onPressed: widget.onTerms ?? () => context.push('/terms'),
          child: const Text('Leer términos y privacidad'),
        ),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          controlAffinity: ListTileControlAffinity.leading,
          value: consent,
          onChanged: busy
              ? null
              : (value) => setState(() => consent = value ?? false),
          title: const Text(
            'Confirmo que tengo 18 años o más y acepto los términos y el aviso de privacidad.',
          ),
        ),
        if (error != null) Notice(error!, isError: true),
        ActionButton(
          'Confirmar y continuar',
          busy: busy,
          onPressed: consent ? accept : null,
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          onPressed: busy
              ? null
              : () => ref.read(identityControllerProvider).logout(),
          child: const Text('Cerrar sesión'),
        ),
        TextButton(
          onPressed: widget.onPrivacy ?? () => context.push('/account-privacy'),
          child: const Text('Privacidad y eliminación de cuenta'),
        ),
      ],
      if (!loading && error != null)
        TextButton(onPressed: load, child: const Text('Volver a intentar')),
    ],
  );
}
