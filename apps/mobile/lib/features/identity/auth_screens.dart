import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show AuthException;

import '../../core/ui.dart';
import '../../core/measurement.dart';
import 'identity_controller.dart';
import 'identity_repository.dart';
import 'auth_ui.dart';

enum AuthFormMode { login, signup, forgot, reset }

class AuthFormScreen extends ConsumerStatefulWidget {
  const AuthFormScreen({
    super.key,
    required this.mode,
    this.intent = 'adopt',
    this.initialEmail,
  });
  final AuthFormMode mode;
  final String intent;
  final String? initialEmail;
  @override
  ConsumerState<AuthFormScreen> createState() => _AuthFormScreenState();
}

class _AuthFormScreenState extends ConsumerState<AuthFormScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController(),
      password = TextEditingController(),
      confirmation = TextEditingController(),
      name = TextEditingController(),
      phone = TextEditingController();
  bool busy = false, consent = false, needsEmailConfirmation = false;
  String? error;
  @override
  void initState() {
    super.initState();
    email.text = widget.initialEmail ?? '';
  }

  @override
  void dispose() {
    for (final item in [email, password, confirmation, name, phone]) {
      item.dispose();
    }
    super.dispose();
  }

  Future<void> submit() async {
    if (busy || !form.currentState!.validate()) return;
    if (widget.mode == AuthFormMode.signup && !consent) {
      setState(
        () => error = 'Confirma que eres mayor de edad y acepta los términos y el aviso de privacidad.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
      needsEmailConfirmation = false;
    });
    final repo = ref.read(identityRepositoryProvider);
    final navigation = GoRouter.of(context);
    try {
      switch (widget.mode) {
        case AuthFormMode.login:
          await repo.login(email.text, password.text);
        case AuthFormMode.signup:
          await repo.signup(
            name: name.text,
            email: email.text,
            phone: phone.text,
            password: password.text,
            intent: widget.intent,
          );
          if (mounted) context.go('/confirm', extra: email.text.trim());
        case AuthFormMode.forgot:
          await repo.requestRecovery(email.text);
          if (mounted) {
            context.go('/confirm-recovery', extra: email.text.trim());
          }
        case AuthFormMode.reset:
          await ref
              .read(identityControllerProvider)
              .completeRecovery(password.text);
          navigation.go(
            '/login',
            extra: 'Tu contraseña se actualizó. Inicia sesión con la nueva.',
          );
      }
    } catch (cause) {
      if (mounted) {
        setState(() {
          error = identityError(cause);
          needsEmailConfirmation =
              cause is AuthException && cause.code == 'email_not_confirmed';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> social(String provider) async {
    if (busy) return;
    setState(() {
      busy = true;
      error = null;
      needsEmailConfirmation = false;
    });
    try {
      await ref.read(identityRepositoryProvider).oauth(provider);
    } catch (cause) {
      if (mounted) {
        setState(() {
          error = identityError(cause);
          needsEmailConfirmation =
              cause is AuthException && cause.code == 'email_not_confirmed';
        });
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final signup = widget.mode == AuthFormMode.signup,
        login = widget.mode == AuthFormMode.login,
        reset = widget.mode == AuthFormMode.reset;
    final config = ref.watch(configProvider);
    final fieldLabel = login || signup
        ? const TextStyle(
            fontFamily: 'Inter',
            fontSize: 14,
            height: 1.2,
            letterSpacing: 0,
            fontWeight: FontWeight.w600,
            color: muted,
          )
        : null;
    final fieldText = login || signup
        ? const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            height: 1.2,
            letterSpacing: 0,
            fontWeight: FontWeight.w400,
            color: ink,
          )
        : null;

    final title = switch (widget.mode) {
      AuthFormMode.login => 'Inicia sesión',
      AuthFormMode.signup => 'Crea tu cuenta',
      AuthFormMode.forgot => 'Recupera tu acceso.',
      AuthFormMode.reset => 'Una nueva\ncontraseña.',
    };
    final description = switch (widget.mode) {
      AuthFormMode.login =>
        'Entra para seguir tus favoritos y retomar donde lo dejaste.',
      AuthFormMode.signup =>
        'Completa tus datos para guardar favoritos y contactar al rescatista.',
      AuthFormMode.forgot => 'Te enviaremos las instrucciones a tu correo.',
      AuthFormMode.reset => 'Elige una contraseña segura para volver a entrar.',
    };
    return AuthFrame(
      sheet: login || signup,
      sheetBottomPadding: login || signup ? 0 : 18,
      intent: widget.intent,
      back: !reset,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AuthHeading(title, description, sheet: login || signup),
          if (login && GoRouterState.of(context).extra is String)
            Notice(GoRouterState.of(context).extra! as String),
          AutofillGroup(
            child: Form(
              key: form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (signup) ...[
                    LabeledField(
                      'Nombre completo',
                      labelStyle: fieldLabel,
                      child: TextFormField(
                        style: fieldText,
                        controller: name,
                        textCapitalization: TextCapitalization.words,
                        maxLength: 80,
                        autofillHints: const [AutofillHints.name],
                        decoration: const InputDecoration(
                          hintText: 'Tu nombre',
                          counterText: '',
                        ),
                        validator: (value) => (value ?? '').trim().isEmpty
                            ? 'Escribe tu nombre.'
                            : null,
                      ),
                    ),
                    SizedBox(height: login || signup ? 12 : 16),
                  ],
                  if (!reset) ...[
                    LabeledField(
                      'Correo electrónico',
                      labelStyle: fieldLabel,
                      child: TextFormField(
                        style: fieldText,
                        controller: email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        autofillHints: const [AutofillHints.email],
                        maxLength: 254,
                        decoration: const InputDecoration(
                          hintText: 'tu@email.com',
                          counterText: '',
                        ),
                        validator: validateEmail,
                      ),
                    ),
                    SizedBox(height: login || signup ? 12 : 16),
                  ],
                  if (signup) ...[
                    LabeledField(
                      'Teléfono (opcional)',
                      labelStyle: fieldLabel,
                      child: TextFormField(
                        style: fieldText,
                        controller: phone,
                        keyboardType: TextInputType.phone,
                        maxLength: 24,
                        autofillHints: const [AutofillHints.telephoneNumber],
                        decoration: const InputDecoration(
                          hintText: '+52 123 456 7890',
                          counterText: '',
                        ),
                      ),
                    ),
                    SizedBox(height: login || signup ? 12 : 16),
                  ],
                  if (login || signup || reset) ...[
                    PasswordField(
                      controller: password,
                      style: fieldText,
                      labelStyle: fieldLabel,
                      labelAbove: true,
                      newPassword: !login,
                      validator: login
                          ? (value) => (value ?? '').isEmpty
                                ? 'Escribe tu contraseña.'
                                : null
                          : validatePassword,
                    ),
                    if (!login) SizedBox(height: signup ? 12 : 16),
                  ],
                  if (signup || reset) ...[
                    PasswordField(
                      controller: confirmation,
                      style: fieldText,
                      labelStyle: fieldLabel,
                      hintText: signup ? 'Confirma tu contraseña' : null,
                      labelAbove: true,
                      label: 'Confirmar contraseña',
                      newPassword: true,
                      validator: (value) => value != password.text
                          ? 'Las contraseñas no coinciden.'
                          : null,
                    ),
                    SizedBox(height: login || signup ? 12 : 16),
                  ],
                  if (signup) ...[
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: consent,
                      onChanged: busy
                          ? null
                          : (value) => setState(() => consent = value ?? false),
                      title: const Text(
                        'Confirmo que tengo 18 años o más y acepto los Términos y el Aviso de privacidad.',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/terms'),
                      child: const Text('Leer términos y privacidad'),
                    ),
                  ],
                  if (login)
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: busy
                            ? null
                            : () => context.push(
                                '/forgot?intent=${widget.intent}',
                                extra: email.text.trim(),
                              ),
                        style: TextButton.styleFrom(
                          // Keep the label 12px below the field while the full
                          // 48px target stays between password and submit.
                          padding: const EdgeInsets.only(bottom: 8),
                          minimumSize: const Size(48, 48),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          splashFactory: NoSplash.splashFactory,
                          overlayColor: Colors.transparent,
                          textStyle: const TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13,
                            height: 1.2,
                            letterSpacing: 0,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text(
                          'Olvidé mi contraseña',
                          style: TextStyle(
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  if (error != null) Notice(error!, isError: true),
                  if (!login) const SizedBox(height: 8),
                  ActionButton(
                    switch (widget.mode) {
                      AuthFormMode.login => 'Inicia sesión',
                      AuthFormMode.signup => 'Crea una cuenta',
                      AuthFormMode.forgot => 'Enviar instrucciones',
                      AuthFormMode.reset => 'Actualizar contraseña',
                    },
                    busy: busy,
                    onPressed: signup && !consent ? null : submit,
                  ),
                  if ((login && needsEmailConfirmation) ||
                      widget.mode == AuthFormMode.forgot)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => context.push(
                              '/confirm',
                              extra: email.text.trim(),
                            ),
                      child: const Text('Necesito confirmar mi correo'),
                    ),
                  if ((login || signup) &&
                      (config.googleEnabled || config.appleNativeAvailable))
                    AuthProviderIcons(
                      google: config.googleEnabled,
                      apple: config.appleNativeAvailable,
                      busy: busy,
                      onPick: social,
                    ),
                  if (login || signup)
                    AuthSwitchFooter(
                      signup: signup,
                      busy: busy,
                      intent: widget.intent,
                    ),
                  if (reset)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              try {
                                await ref
                                    .read(identityControllerProvider)
                                    .logout();
                              } catch (cause) {
                                if (mounted) {
                                  setState(() => error = identityError(cause));
                                }
                              }
                            },
                      child: const Text('Cancelar y cerrar sesión'),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ConfirmationScreen extends ConsumerStatefulWidget {
  const ConfirmationScreen({super.key, this.email = '', this.recovery = false});
  final String email;
  final bool recovery;
  @override
  ConsumerState<ConfirmationScreen> createState() => _ConfirmationScreenState();
}

class _ConfirmationScreenState extends ConsumerState<ConfirmationScreen> {
  late final email = TextEditingController(text: widget.email);
  final code = TextEditingController(), form = GlobalKey<FormState>();
  Timer? timer;
  int seconds = 0;
  bool busy = false;
  String? error, message;
  @override
  void dispose() {
    timer?.cancel();
    email.dispose();
    code.dispose();
    super.dispose();
  }

  Future<void> perform(bool resend) async {
    if (busy || (resend && seconds > 0)) return;
    if (validateEmail(email.text) != null) {
      setState(() => error = 'Escribe el correo de tu cuenta.');
      return;
    }
    if (!resend && !form.currentState!.validate()) return;
    setState(() {
      busy = true;
      error = null;
      message = null;
    });
    try {
      final repo = ref.read(identityRepositoryProvider);
      if (resend) {
        if (widget.recovery) {
          await repo.requestRecovery(email.text);
        } else {
          await repo.resendConfirmation(email.text);
        }
        if (mounted) {
          setState(() {
            message = 'Si corresponde, recibirás un correo con las instrucciones. Revisa también spam.';
            seconds = 60;
          });
          timer?.cancel();
          timer = Timer.periodic(const Duration(seconds: 1), (tick) {
            if (!mounted) {
              tick.cancel();
              return;
            }
            setState(() => seconds--);
            if (seconds == 0) tick.cancel();
          });
        }
      } else {
        await repo.confirmCode(
          email.text,
          code.text,
          recovery: widget.recovery,
        );
        if (!widget.recovery) {
          final measurement = ref.read(measurementControllerProvider);
          await measurement?.owner(repo.current?.id);
          await measurement?.event('sign_up_completed');
        }
      }
    } catch (cause) {
      if (mounted) setState(() => error = identityError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthFrame(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.mark_email_unread_outlined, size: 76, color: purple),
        const SizedBox(height: 28),
        AuthHeading(
          'Revisa tu correo.',
          widget.recovery
              ? 'Si existe una cuenta con ese correo, recibirás instrucciones para recuperar el acceso.'
              : 'Abre el enlace que te enviamos para confirmar tu cuenta.',
        ),
        const Text(
          'Abre el enlace en este mismo dispositivo y navegador. Si tu correo incluye un código, también puedes ingresarlo aquí.',
        ),
        const SizedBox(height: 20),
        Form(
          key: form,
          child: Column(
            children: [
              TextFormField(
                controller: email,
                decoration: const InputDecoration(
                  labelText: 'Correo electrónico',
                ),
                keyboardType: TextInputType.emailAddress,
                validator: validateEmail,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: code,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                decoration: const InputDecoration(
                  labelText: 'Código del correo',
                ),
                validator: (value) =>
                    RegExp(r'^\d{6,10}$').hasMatch((value ?? '').trim())
                    ? null
                    : 'Escribe el código que recibiste.',
              ),
            ],
          ),
        ),
        if (message != null) Notice(message!),
        if (error != null) Notice(error!, isError: true),
        const SizedBox(height: 24),
        ActionButton(
          'Verificar código',
          busy: busy,
          onPressed: () => perform(false),
        ),
        TextButton(
          onPressed: busy || seconds > 0 ? null : () => perform(true),
          child: Text(
            seconds > 0 ? 'Reenviar en ${seconds}s' : 'Reenviar correo',
          ),
        ),
        TextButton(
          onPressed: () => context.go('/login'),
          child: const Text('Volver a iniciar sesión'),
        ),
      ],
    ),
  );
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});
  @override
  Widget build(BuildContext context) => PageFrame(
    children: [
      const Heading(
        'Términos y privacidad',
        'Dopmi · Versión del 28 de septiembre de 2026',
      ),
      const Text(
        'Dopmi es un servicio para personas mayores de 18 años que facilita adopciones, comunicación con rescatistas y aportaciones de prueba sujetas a revisión y disponibilidad.',
      ),
      const SizedBox(height: 20),
      const Text(
        'Uso responsable',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
      ),
      const SizedBox(height: 8),
      const Text(
        'Debes proporcionar información veraz, respetar la privacidad de otras personas y usar los canales de reporte y moderación. Una publicación o aportación puede quedar en revisión, requerir correcciones o retirarse.',
      ),
      const SizedBox(height: 20),
      const Text(
        'Privacidad y pagos',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
      ),
      const SizedBox(height: 8),
      const Text(
        'Tratamos los datos necesarios para operar tu cuenta, publicaciones, mensajes, moderación y pagos. Los datos de tarjeta se capturan con Stripe. No mostramos públicamente tu domicilio exacto, teléfono, correo, documentos o conversaciones privadas.',
      ),
      const SizedBox(height: 20),
      const Text(
        'Cuenta y soporte',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
      ),
      const SizedBox(height: 8),
      const Text(
        'Puedes solicitar la eliminación de tu cuenta desde Configuración. Conservaremos únicamente la evidencia necesaria para atender pagos, disputas y obligaciones legales. Para ayuda escribe a soporte@dopmi.org.',
      ),
      const SizedBox(height: 24),
      ActionButton(
        'Abrir Aviso de privacidad',
        onPressed: () => launchUrl(
          Uri.parse('https://dopmi.org/privacy-policy'),
          mode: LaunchMode.externalApplication,
        ),
      ),
    ],
  );
}
