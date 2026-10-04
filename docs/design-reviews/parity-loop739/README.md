# Loop 739 — Cancelar publicación

2026-10-04. Mockup `irlanda/apoyar-detalle-perfil`: `a3c969cd9103fd46dc5cd886999912526ce75efb`, verificado al inicio y al cierre.

`.publish-cancel` usa fondo transparente; su cambio de fondo está limitado a hover. El TextButton de producción agregaba tinta Material al tocar. Se desactiva overlay, splash y duración de transición sin cambiar navegación, bloqueo durante consulta ni objetivo táctil de 48 px.

Verificación de la fuente modificada en scratch: sesión 62885, terminal 0, `flutter test --no-pub test/publish_choice_test.dart` 6/6; `flutter analyze --no-pub` sin problemas (13.3 s). La ejecución anterior 9037 fue anterior a la copia efectiva y no valida este cambio.

No captura nueva ni aceptación visual o de dispositivo en este loop. El gate completo de loop736 antecede este cambio. Codemagic queda diferido hasta completar el objetivo, según la última instrucción del usuario.
