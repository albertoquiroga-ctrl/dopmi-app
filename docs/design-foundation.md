# H8 — base visual y navegación

> El plan vigente es [h8-execution.md](h8-execution.md), autorizado el 26/9/2026. H8 incluye los recorridos completos antes asignados a H9. Este documento reúne la evidencia visual; la aceptación instalada sigue separada de la implementación y las pruebas.

Referencia: `dopmi-functional-mockup`, rama `irlanda/apoyar-detalle-perfil`, commit `a246fa6f42ec517aae264d7fbd2358d647c4f840`, reconsultada al inicio y cierre de los bloques. Implementación: `codex/design-foundation`, desde H7 integrado (`ba9f897`). **H8 sigue abierto únicamente para revisión/aceptación instalada y las correcciones que ésta produzca.**

## Cambio implementado

- Inter y Fraunces empaquetadas localmente, con licencias OFL de Google Fonts. La app no descarga fuentes en ejecución. Colores, superficies, radios, botones, campos y tarjetas centralizados; SVG de navegación tomados de la referencia.
- Donante/adoptante: Adoptar, Apoyar, Perfil. Rescatista: Inicio, Casos, Publicar, Mensajes, Perfil. Guardados, mensajes y publicaciones siguen accesibles desde Perfil. La preferencia de experiencia proviene del perfil real y nunca concede permisos.
- La entrada normal de una sesión restaurada abre el inicio correspondiente a su experiencia. Una pantalla de resolución espera el perfil hasta diez segundos, con navegación donante como fallback si falla; los enlaces explícitos mantienen su destino. La recuperación no pasa por esta entrada.
- Navegadores conservados por pestaña. Un borrador sin guardar se conserva al alternar; el cambio de identidad reconstruye los navegadores y descarta estado privado anterior. Se conserva la ruta resuelta (incluido historial de Guardián) y los enlaces iniciales de recuperación/pagos. La recuperación no carga el perfil personal.
- Bienvenida con las tres intenciones, iconos, tipografía y selección del mockup. Sus accesos a iniciar sesión y explorar sin cuenta permanecen disponibles. Los destinos posteriores siguen usando los servicios existentes.
- Dos pasos contextuales por intención, entrada de cuenta y formularios de inicio/registro/recuperación/confirmación con marco común, títulos centrados, campos etiquetados y botones negros. Regresar conserva el paso y crear cuenta conserva la intención. Ilustraciones nativas con las imágenes del mockup; son ejemplos decorativos, separados de los repositorios reales.
- Controles de navegación con etiqueta, selección y acción accesibles; barras verificadas a 320 px con texto al 200 %. Esto no sustituye una prueba con VoiceOver/TalkBack.

## Capturas

Capturas de widgets Flutter reales a 377 × 852, escala 1; los componentes usan datos ilustrativos sin cuentas/documentos. No son capturas de TestFlight/Play. Las imágenes de referencia provienen del HTML ejecutado localmente al mismo tamaño. No hay comparación automática de píxeles ni aprobación visual implícita.

| Referencia | Flutter |
| --- | --- |
| [Bienvenida](design-reviews/h8-foundation/reference-welcome.png) | [Bienvenida](design-reviews/h8-foundation/welcome.png) |
| [Intención seleccionada](design-reviews/h8-foundation/reference-welcome-selected.png) | [Intención seleccionada](design-reviews/h8-foundation/welcome-selected.png) |

Componentes reales: [donante](design-reviews/h8-foundation/donor.png), [rescatista](design-reviews/h8-foundation/rescuer.png), [320 × 640 con texto al 200 %](design-reviews/h8-foundation/small-large-text.png). Las dos primeras son galerías de componentes, no catálogos conectados ni pantallas finales de H9.

| Acceso | HTML de referencia | Flutter |
| --- | --- | --- |
| Inicio de sesión | [HTML](design-reviews/h8-access/reference-login.png) | [App](design-reviews/h8-access/login.png) |
| Registro | [HTML](design-reviews/h8-access/reference-signup.png) | [App](design-reviews/h8-access/signup.png) |
| Entrada de cuenta | [HTML](design-reviews/h8-access/reference-start.png) | [App](design-reviews/h8-access/start.png) |
| Adoptar, paso 1 | [HTML](design-reviews/h8-access/reference-onboarding-adopt.png) | [App](design-reviews/h8-access/onboarding-adopt.png) |
| Adoptar, paso 2 | [HTML](design-reviews/h8-access/reference-onboarding-adopt-2.png) | [App](design-reviews/h8-access/onboarding-adopt-2.png) |
| Aportar, paso 1 | [HTML](design-reviews/h8-access/reference-onboarding-donate.png) | [App](design-reviews/h8-access/onboarding-donate.png) |
| Aportar, paso 2 | [HTML](design-reviews/h8-access/reference-onboarding-donate-2.png) | [App](design-reviews/h8-access/onboarding-donate-2.png) |
| Rescatista, paso 1 | [HTML](design-reviews/h8-access/reference-onboarding-rescue.png) | [App](design-reviews/h8-access/onboarding-rescue.png) |
| Rescatista, paso 2 | [HTML](design-reviews/h8-access/reference-onboarding-rescue-2.png) | [App](design-reviews/h8-access/onboarding-rescue-2.png) |

Estados reales ausentes o simulados en el HTML: [recuperación](design-reviews/h8-access/forgot.png), [confirmación de correo](design-reviews/h8-access/confirm.png). La insignia «Modo prueba» pertenece al prototipo, no a las capturas Flutter.

Comparaciones de pantallas completas generadas al ejecutar el HTML y las rutas Flutter a 377 × 852 con datos equivalentes de prueba:

| Recorrido | HTML de referencia | Flutter |
| --- | --- | --- |
| Adoptar / swipe | [HTML](design-reviews/h8-complete/reference-adoption.png) | [App](design-reviews/h8-complete/adoption-swipe.png) |
| Perfil donante | [HTML](design-reviews/h8-complete/reference-profile.png) | [App](design-reviews/h8-complete/profile-overview.png) |
| Apoyar | [HTML](design-reviews/h8-complete/reference-support.png) | [App](design-reviews/h8-complete/support-home.png) |
| Inicio rescatista | [HTML](design-reviews/h8-complete/reference-rescuer-home.png) | [App](design-reviews/h8-complete/rescuer-home.png) |
| Casos rescatista | [HTML](design-reviews/h8-complete/reference-rescuer-cases.png) | [App](design-reviews/h8-complete/rescuer-cases.png) |
| Detalle de caso | [HTML](design-reviews/h8-complete/reference-case-detail.png) | [App](design-reviews/h8-complete/case-detail.png) |

La captura Flutter de swipe usa el estado sin foto de la prueba; el candidato instalado consume las fotos públicas aprobadas de Supabase. Apoyar conserva la fotografía y composición destacada de la referencia, sustituyendo sus promesas simuladas por gastos pagados/aprobados. Inicio rescatista sustituye “disponible” por Asignado/Transferido/En revisión porque una transferencia a Stripe no acredita depósito bancario. Perfil añade Mi impacto y conserva Configuración/cambio de modo al desplazarse; el acceso y contador de rescatistas guardados ya están en la vista principal.

Regenerar desde `apps/mobile`:

```sh
flutter test tool/capture_design_test.dart
```

Salida ignorada: `.tools/design-review`. Revisar antes de reemplazar las capturas versionadas. La galería interactiva usa `flutter run -t tool/design_gallery.dart`; es una herramienta de revisión separada de `lib/main.dart`.

## Verificación y diferencias pendientes

Capturas nuevas del cierre técnico H8.7: `contribution-amount.png`, `guardian-intro.png` y `guardian-active.png` en `.tools/design-review`. Reproducen componentes Flutter reales a 377 × 852. El perfil público moderado, el panel/casos/formularios rescatista y los recorridos de aportación/Guardián ya están implementados; la diferencia transversal restante es la aceptación instalada y cualquier ajuste que resulte de ella.

- `flutter analyze`: sin incidencias en la copia local fuera de OneDrive; la carpeta generada del checkout quedó bloqueada temporalmente por sincronización, sin afectar fuentes ni CI.
- `flutter test`: **80 pruebas** aprobadas. `tool/capture_design_test.dart` y `tool/capture_profile_test.dart`: **2 generaciones de capturas** aprobadas. Los tres onboardings se recorren con texto al 200 % en 320 × 640, incluyendo regreso y registro con intención preservada; la restauración de sesión rescatista abre su inicio.
- `flutter test test_backend`: cuatro recorridos con Supabase local real aprobados. Configuración móvil: seis pruebas aprobadas.
- Regresión encontrada/corregida: al reconstruir el router por cambio de cuenta se recordaba la intención de ruta antes del redirect; ahora se registra el destino superior resuelto, incluidas páginas abiertas con `push`. El historial financiero de la nueva cuenta se muestra vacío y no conserva detalles anteriores.
- El candidato corregido es Android 2.3.3 (256), SHA `ea5350e`, mediante Codemagic `6ab89b4db5c299cd1e6841cc`; firma, pruebas y Publishing aprobaron. Incorpora el acceso directo de rescatistas guardados y la composición fotográfica de Apoyar. Irlanda revisa desde Internal Testing; aceptación visual pendiente.

Pendiente de cierre H8: revisión visual de Irlanda/titular y ajustes antes de declarar paridad aceptada. Diferencias explícitas: controles nativos con áreas táctiles amplias y mostrar/ocultar contraseña; gris/foco con mayor contraste; acceso anónimo y confirmación de correo disponibles; OAuth oculto mientras sus proveedores no estén configurados; consentimiento de desarrollo hasta H10; textos de gastos pagados/aprobados en lugar de financiación previa. Las ilustraciones de introducción no escalan como texto interactivo: el contenido explicativo exterior sí lo hace. H9 conserva aceptación integrada y excepciones operativas; H11 conserva dispositivo, enlaces externos, cámara/galería, teclado, VoiceOver/TalkBack y distribución conjunta Android/iOS.


## Referencia vigente de bienvenida — 1/10/2026, paridad108
El mockup irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb comprobado en navegador a320px presenta dos opciones iniciales: Adoptar y Dar en adopción; ambos círculos92px eiconos32. Esto supersede la referencia histórica a tres intenciones en este documento. La app se ajustó a esas dos entradas; conserva recorridos y enlaces existentes de donación sin crear otra cuenta ni permisos por experiencia.18pruebas/capturas ver parity-loops108; aceptación visual integral instalada pendiente.
