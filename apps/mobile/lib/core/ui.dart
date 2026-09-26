import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'design_tokens.dart';

const ink = DopmiTokens.ink;
const cream = DopmiTokens.surface;
const purple = DopmiTokens.purple;
const yellow = DopmiTokens.yellow;
const muted = DopmiTokens.muted;

ThemeData dopmiTheme({bool rescuer = false}) {
  final colors = ColorScheme.fromSeed(seedColor: purple).copyWith(
    primary: rescuer ? purple : yellow,
    onPrimary: rescuer ? Colors.white : ink,
    secondary: yellow,
    onSecondary: ink,
    surface: cream,
    onSurface: ink,
    error: DopmiTokens.danger,
  );
  return ThemeData(
    useMaterial3: true,
    fontFamily: DopmiTokens.bodyFont,
    progressIndicatorTheme: const ProgressIndicatorThemeData(color: purple),
    textSelectionTheme: const TextSelectionThemeData(cursorColor: ink),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: DopmiTokens.line),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: const Color(0xff59408f)),
    ),
    colorScheme: colors,
    scaffoldBackgroundColor: cream,
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontFamily: DopmiTokens.displayFont,
        fontSize: 32,
        fontWeight: FontWeight.w600,
        height: 1.15,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontFamily: DopmiTokens.displayFont,
        fontSize: 28,
        fontWeight: FontWeight.w600,
        height: 1.2,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: ink,
      ),
      bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: ink),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: DopmiTokens.line),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: DopmiTokens.yellowInk, width: 2),
      ),
      errorMaxLines: 3,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        shape: const StadiumBorder(),
        textStyle: const TextStyle(
          fontFamily: DopmiTokens.bodyFont,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: rescuer ? purple : ink,
        minimumSize: const Size.fromHeight(48),
        shape: const StadiumBorder(),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: cream,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
    ),
  );
}

class Brand extends StatelessWidget {
  const Brand({super.key});
  @override
  Widget build(BuildContext context) => Image.asset(
    'assets/dopmi-wordmark.png',
    width: 108,
    semanticLabel: 'Dopmi',
  );
}

class PageFrame extends StatelessWidget {
  const PageFrame({
    super.key,
    required this.children,
    this.back = true,
    this.actions,
    this.bottomNavigationBar,
  });
  final List<Widget> children;
  final bool back;
  final List<Widget>? actions;
  final Widget? bottomNavigationBar;
  @override
  Widget build(BuildContext context) => Scaffold(
    bottomNavigationBar: bottomNavigationBar,
    appBar: AppBar(
      title: const Brand(),
      automaticallyImplyLeading: false,
      leading: back
          ? IconButton(
              tooltip: 'Volver',
              icon: const Icon(Icons.arrow_back_rounded),
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/welcome');
                }
              },
            )
          : null,
      actions: actions,
    ),
    body: SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            children: children,
          ),
        ),
      ),
    ),
  );
}

class Heading extends StatelessWidget {
  const Heading(this.title, this.description, {super.key, this.eyebrow});
  final String title, description;
  final String? eyebrow;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (eyebrow != null) ...[
        Text(
          eyebrow!,
          style: const TextStyle(
            color: purple,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
      ],
      Semantics(
        header: true,
        child: Text(title, style: Theme.of(context).textTheme.headlineLarge),
      ),
      const SizedBox(height: 12),
      Text(description, style: Theme.of(context).textTheme.bodyLarge),
      const SizedBox(height: 28),
    ],
  );
}

class Notice extends StatelessWidget {
  const Notice(this.message, {super.key, this.isError = false});
  final String message;
  final bool isError;
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isError ? const Color(0xffffeded) : const Color(0xffeee7fc),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        message,
        style: TextStyle(color: isError ? const Color(0xff8e2121) : purple),
      ),
    ),
  );
}

class ActionButton extends StatelessWidget {
  const ActionButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.busy = false,
    this.sunny = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy, sunny;
  @override
  Widget build(BuildContext context) => FilledButton(
    style: sunny
        ? FilledButton.styleFrom(backgroundColor: yellow, foregroundColor: ink)
        : null,
    onPressed: busy ? null : onPressed,
    child: busy
        ? Semantics(
            label: 'Procesando',
            child: const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        : Text(label),
  );
}

String? validateEmail(String? value) =>
    RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch((value ?? '').trim())
    ? null
    : 'Escribe un correo válido.';
String? validatePassword(String? value) {
  final password = value ?? '';
  return password.length >= 10 &&
          RegExp('[A-Z]').hasMatch(password) &&
          RegExp('[a-z]').hasMatch(password) &&
          RegExp('[0-9]').hasMatch(password)
      ? null
      : 'Usa al menos 10 caracteres, mayúscula, minúscula y número.';
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Contraseña',
    this.validator,
    this.newPassword = false,
  });
  final TextEditingController controller;
  final String label;
  final String? Function(String?)? validator;
  final bool newPassword;
  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool hidden = true;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: widget.controller,
    obscureText: hidden,
    autocorrect: false,
    enableSuggestions: false,
    validator: widget.validator,
    autofillHints: [
      widget.newPassword ? AutofillHints.newPassword : AutofillHints.password,
    ],
    decoration: InputDecoration(
      labelText: widget.label,
      suffixIcon: IconButton(
        tooltip: hidden
            ? 'Mostrar ${widget.label.toLowerCase()}'
            : 'Ocultar ${widget.label.toLowerCase()}',
        icon: Icon(
          hidden ? Icons.visibility_outlined : Icons.visibility_off_outlined,
        ),
        onPressed: () => setState(() => hidden = !hidden),
      ),
    ),
  );
}
