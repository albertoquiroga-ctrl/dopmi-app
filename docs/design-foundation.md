# H8 — base visual y navegación

Referencia: `dopmi-functional-mockup`, rama `irlanda/apoyar-detalle-perfil`, commit `a246fa6f42ec517aae264d7fbd2358d647c4f840`, reconsultada al inicio y cierre de este ciclo. Implementación: `codex/design-foundation`, desde H7 integrado (`ba9f897`). **H8 sigue abierto**: estas capturas no acreditan paridad de todos los recorridos ni aceptación de Irlanda/dispositivo.

## Cambio implementado

- Inter y Fraunces empaquetadas localmente, con licencias OFL de Google Fonts. La app no descarga fuentes en ejecución. Colores, superficies, radios, botones, campos y tarjetas centralizados; SVG de navegación tomados de la referencia.
- Donante/adoptante: Adoptar, Apoyar, Perfil. Rescatista: Inicio, Casos, Publicar, Mensajes, Perfil. Guardados, mensajes y publicaciones siguen accesibles desde Perfil. La preferencia de experiencia proviene del perfil real y nunca concede permisos.
- Navegadores conservados por pestaña. Un borrador sin guardar se conserva al alternar; el cambio de identidad reconstruye los navegadores y descarta estado privado anterior. Se conserva la ruta resuelta (incluido historial de Guardián) y los enlaces iniciales de recuperación/pagos. La recuperación no carga el perfil personal.
- Bienvenida con las tres intenciones, iconos, tipografía y selección del mockup. Sus accesos a iniciar sesión y explorar sin cuenta permanecen disponibles. Los destinos posteriores siguen usando los servicios existentes.
- Controles de navegación con etiqueta, selección y acción accesibles; barras verificadas a 320 px con texto al 200 %. Esto no sustituye una prueba con VoiceOver/TalkBack.

## Capturas

Capturas de widgets Flutter reales a 377 × 852, escala 1; los componentes usan datos ilustrativos sin cuentas/documentos. No son capturas de TestFlight/Play. Las imágenes de referencia provienen del HTML ejecutado localmente al mismo tamaño. No hay comparación automática de píxeles ni aprobación visual implícita.

| Referencia | Flutter |
| --- | --- |
| [Bienvenida](design-reviews/h8-foundation/reference-welcome.png) | [Bienvenida](design-reviews/h8-foundation/welcome.png) |
| [Intención seleccionada](design-reviews/h8-foundation/reference-welcome-selected.png) | [Intención seleccionada](design-reviews/h8-foundation/welcome-selected.png) |

Componentes reales: [donante](design-reviews/h8-foundation/donor.png), [rescatista](design-reviews/h8-foundation/rescuer.png), [320 × 640 con texto al 200 %](design-reviews/h8-foundation/small-large-text.png). Las dos primeras son galerías de componentes, no catálogos conectados ni pantallas finales de H9.

Regenerar desde `apps/mobile`:

```sh
flutter test tool/capture_design_test.dart
```

Salida ignorada: `.tools/design-review`. Revisar antes de reemplazar las capturas versionadas. La galería interactiva usa `flutter run -t tool/design_gallery.dart`; es una herramienta de revisión separada de `lib/main.dart`.

## Verificación y diferencias pendientes

- `flutter analyze`: sin incidencias.
- `flutter test test tool/capture_design_test.dart`: 58 aprobadas (57 de la suite y una generación de capturas).
- `flutter test test_backend`: cuatro recorridos con Supabase local real aprobados. Configuración móvil: seis pruebas aprobadas.
- Regresión encontrada/corregida: al reconstruir el router por cambio de cuenta se recordaba la intención de ruta antes del redirect; ahora se registra la configuración resuelta. El historial financiero de la nueva cuenta se muestra vacío y no conserva detalles anteriores.
- CI del commit se registra por separado en `progress.md`. No se generó un candidato firmado de Codemagic en este ciclo.

Pendiente H8.4: portar onboarding contextual, entrada de cuenta y formularios; el nuevo tema por sí solo no los hace idénticos al HTML. Mantener validación de contraseña, confirmación de correo, recuperación y OAuth real con sus gates. Los textos de consentimiento de desarrollo permanecen hasta H10. El gris y foco de campos usan contraste mayor que algunas muestras del prototipo. Revisar con Irlanda las diferencias de altura/espaciado y los enlaces adicionales de la bienvenida.

Pendiente H9: contenido y estados de adopción/rescate/pagos/cuenta, sin copiar éxitos, verificaciones o promesas financieras simulados. Pendiente H11: dispositivo, enlaces externos, cámara/galería, teclado, VoiceOver/TalkBack y aceptación en ambas tiendas desde el mismo SHA.
