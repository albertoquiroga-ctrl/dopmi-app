import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/ui.dart';
import 'identity_controller.dart';
import 'identity_repository.dart';

enum AuthFormMode { login, signup, forgot, reset }

class AuthFormScreen extends ConsumerStatefulWidget {
  const AuthFormScreen({super.key, required this.mode, this.intent = 'adopt'});
  final AuthFormMode mode;
  final String intent;
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
  bool busy = false, consent = false;
  String? error;
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
        () => error = 'Lee y acepta el aviso de desarrollo para continuar.',
      );
      return;
    }
    setState(() {
      busy = true;
      error = null;
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
      if (mounted) setState(() => error = identityError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> social(String provider) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await ref.read(identityRepositoryProvider).oauth(provider);
    } catch (cause) {
      if (mounted) setState(() => error = identityError(cause));
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
    final title = switch (widget.mode) {
      AuthFormMode.login => 'Qué bueno\nverte de nuevo.',
      AuthFormMode.signup => 'Hagamos equipo.',
      AuthFormMode.forgot => 'Recupera tu acceso.',
      AuthFormMode.reset => 'Una nueva\ncontraseña.',
    };
    final description = switch (widget.mode) {
      AuthFormMode.login => 'Entra a tu comunidad Dopmi.',
      AuthFormMode.signup => 'Tu primera huella en una comunidad que cuida.',
      AuthFormMode.forgot => 'Te enviaremos las instrucciones a tu correo.',
      AuthFormMode.reset => 'Elige una contraseña segura para volver a entrar.',
    };
    return PageFrame(
      back: !reset,
      children: [
        Heading(
          title,
          description,
          eyebrow: signup ? 'CREA TU CUENTA' : 'TU CUENTA DOPMI',
        ),
        if (login && GoRouterState.of(context).extra is String)
          Notice(GoRouterState.of(context).extra! as String),
        AutofillGroup(
          child: Form(
            key: form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (signup) ...[
                  TextFormField(
                    controller: name,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 80,
                    autofillHints: const [AutofillHints.name],
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (value) => (value ?? '').trim().isEmpty
                        ? 'Escribe tu nombre.'
                        : null,
                  ),
                  const SizedBox(height: 16),
                ],
                if (!reset) ...[
                  TextFormField(
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    autofillHints: const [AutofillHints.email],
                    maxLength: 254,
                    decoration: const InputDecoration(
                      labelText: 'Correo electrónico',
                      counterText: '',
                    ),
                    validator: validateEmail,
                  ),
                  const SizedBox(height: 16),
                ],
                if (signup) ...[
                  TextFormField(
                    controller: phone,
                    keyboardType: TextInputType.phone,
                    maxLength: 24,
                    autofillHints: const [AutofillHints.telephoneNumber],
                    decoration: const InputDecoration(
                      labelText: 'Teléfono (opcional)',
                      counterText: '',
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                if (login || signup || reset) ...[
                  PasswordField(
                    controller: password,
                    newPassword: !login,
                    validator: login
                        ? (value) => (value ?? '').isEmpty
                              ? 'Escribe tu contraseña.'
                              : null
                        : validatePassword,
                  ),
                  const SizedBox(height: 16),
                ],
                if (signup || reset) ...[
                  PasswordField(
                    controller: confirmation,
                    label: 'Confirmar contraseña',
                    newPassword: true,
                    validator: (value) => value != password.text
                        ? 'Las contraseñas no coinciden.'
                        : null,
                  ),
                  const SizedBox(height: 16),
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
                      'Leí y acepto el aviso de desarrollo.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/terms'),
                    child: const Text('Leer aviso y uso de mis datos'),
                  ),
                ],
                if (error != null) Notice(error!, isError: true),
                const SizedBox(height: 8),
                ActionButton(
                  switch (widget.mode) {
                    AuthFormMode.login => 'Iniciar sesión',
                    AuthFormMode.signup => 'Crear cuenta',
                    AuthFormMode.forgot => 'Enviar instrucciones',
                    AuthFormMode.reset => 'Actualizar contraseña',
                  },
                  busy: busy,
                  sunny: signup,
                  onPressed: submit,
                ),
                if (login) ...[
                  TextButton(
                    onPressed: busy ? null : () => context.push('/forgot'),
                    child: const Text('Olvidé mi contraseña'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => context.push(
                            '/confirm',
                            extra: email.text.trim(),
                          ),
                    child: const Text('Necesito confirmar mi correo'),
                  ),
                  if (config.googleEnabled || config.appleEnabled)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'También puedes entrar con',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (config.googleEnabled)
                    OutlinedButton(
                      onPressed: busy ? null : () => social('google'),
                      child: const Text('Continuar con Google'),
                    ),
                  if (config.appleEnabled) ...[
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: busy ? null : () => social('apple'),
                      child: const Text('Continuar con Apple'),
                    ),
                  ],
                  TextButton(
                    onPressed: () => context.push('/signup'),
                    child: const Text('Soy nuevo · Crear una cuenta'),
                  ),
                ],
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
      }
    } catch (cause) {
      if (mounted) setState(() => error = identityError(cause));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageFrame(
    children: [
      const Icon(Icons.mark_email_unread_outlined, size: 76, color: purple),
      const SizedBox(height: 28),
      Heading(
        'Revisa tu correo.',
        widget.recovery
            ? 'Si existe una cuenta con ese correo, recibirás instrucciones para recuperar el acceso.'
            : 'Abre el enlace que te enviamos para confirmar tu cuenta.',
        eyebrow: widget.recovery ? 'RECUPERA TU ACCESO' : 'UN PASO MÁS',
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
              decoration: const InputDecoration(labelText: 'Código del correo'),
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
  );
}

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});
  @override
  Widget build(BuildContext context) => const PageFrame(
    children: [
      Heading(
        'Aviso de desarrollo',
        'Dopmi · Versión del 13 de septiembre de 2026',
      ),
      Text(
        'Esta versión sirve para probar registro, acceso y perfiles. No está habilitada para recibir aportaciones ni tramitar adopciones.',
      ),
      SizedBox(height: 20),
      Text(
        'Datos de tu cuenta',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
      ),
      SizedBox(height: 8),
      Text(
        'Guardamos tu correo, nombre, preferencias y los datos opcionales de tu perfil en el proyecto de desarrollo de Dopmi. El equipo autorizado puede consultarlos para operar y probar el servicio. Tu perfil todavía no es público.',
      ),
      SizedBox(height: 20),
      Text(
        'Para las pruebas',
        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 20),
      ),
      SizedBox(height: 8),
      Text(
        'Usa datos de prueba. No agregues documentos de identidad, información bancaria ni comprobantes. Puedes editar tu perfil o cerrar sesión en cualquier momento.',
      ),
      SizedBox(height: 20),
      Text(
        'Antes del lanzamiento se publicarán los términos y el aviso de privacidad definitivos, con la identidad del responsable, contacto y mecanismos para ejercer tus derechos. Este aviso no los reemplaza.',
      ),
    ],
  );
}
