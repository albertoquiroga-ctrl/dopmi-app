# Auditoría de rutas y pendientes concretos — 2/10/2026, loop265

Referencia verificada: `irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb`.
Producción remota: `3374c507004cd2de7a693de87658e85cc445c0f8`.

Inventario extraído de `src/App.tsx` de referencia, `apps/mobile/lib/app.dart`
y del bloque de especificaciones de `tool/capture_profile_test.dart`:
55 patrones Source (incluye redirecciones y comodín), 49 patrones nativos
(incluye una ruta hija), 262 estados fixture en29URLs. Lista exacta y nombres
reproducibles en [route-inventory.json](design-reviews/parity-loop265/route-inventory.json).
La diferencia entre55/49 no significa seis pantallas faltantes: los nombres,
consolidación de estados, redirecciones y rutas técnicas difieren.

## Pendientes visuales confirmados por el código actual

| Familia | Source vigente | Producción actual | Trabajo listo |
| --- | --- | --- | --- |
| Guardados | SavedPets: TopBar Mis mascotas, lead, filas foto70, nombre/datos, bookmark. SavedRescuers: TopBar, avatar/ubicación/verificación, tarjetas y vacío. | SavedScreen: Heading/eyebrow, SegmentedButton, Card/ListTile/CircleAvatar genéricos. No captura directa /saved en capturador. | Implementar composición de mascotas/rescatistas, preservar tercera categoría real de casos, tombstones, paginación y operaciones privadas; verificar retiro fallido/concurrente y navegación. |
| Información básica | BasicInfo /settings/basic-info, formulario personal dedicado. | BasicInfoScreen incluye tarjeta amarilla/correo y seis atajos ListTile antes del formulario. No captura /basic-info. | Comparar ruta renderizada, sacar navegación redundante de composición principal preservando accesos desde Perfil/Configuración, mantener guardado real/no pisar modo. |
| Centro de ayuda | HelpCenter, composición y preguntas por experiencia. | HelpScreen conserva ExpansionTile Material y contenido común para ambos modos. No captura /help. | Aplicar composición/FAQ correspondiente, conservar reglas económicas reales y contacto por correo; mailto no acredita entrega de correo. |
| Editor público | RescuerEditPublicProfile, /rescuer/profile/edit. | RescuerPublicProfileEditScreen: campos Material sin composición de referencia; avatar/status moderado funcional. No captura directa. | Contrastar editor renderizado y sustituir presentación, conservar borrador/versionado/revisión y datos privados fuera de perfil público. |

Estos son cuatro grupos concretos descubiertos en la revisión actual, no el
número final de pantallas sin aceptación ni una promesa de que sólo falten cuatro.
Se empieza por Guardados; una implementación a la vez.

## Cobertura que aún requiere comprobación agrupada

Las familias NAV/AUTH/DISC/FILTER/PET/MATCH/CHAT/PROFILE/SUPPORT/CASE/
STORY/PUBLIC/IMPACT/RH/RC/PUBLISH/VERIFY/EVIDENCE/RP/PAYMENT/GUARD/REPORT/LEGAL
se cruzarán con evidencia vigente en parity-loops, acciones y regresos reales.
La lista incluye solapamiento con SETTINGS/SAVED y no se usa como total.
I/T históricos en design-parity no acreditan fidelidad actual ni instalada.

Rutas nativas sin URL directa de este capturador incluyen: /guardian/history,
/connect, /my-adoptions (listado), /rescue-file, /rescue-cases/:id/updates y
su detalle, /settings/account, /consent, /account-privacy. Se distinguen
extensiones reales (Connect/privacidad/consentimiento), estados alcanzados desde
otra ruta y rutas que necesitan capturas propias. Sin render/flujo actual no
se marca ninguna como idéntica ni defectuosa por ausencia de captura.
Acceso /welcome,/onboarding,/start,/signup,/login,/forgot,/reset-password,
/confirm,/confirm-recovery,/auth-error,/terms y componentes tienen capturador
separado: revisar su cobertura sin contarlos otra vez en262.

## Condiciones de cierre del objetivo original

- Todas las familias Source aplicables comparadas con el mismo SHA y viewport,
  estados/errores/transiciones/scroll/regreso/gestos móviles; hover excluido por
  decisión del titular. Fotos e identidades sintéticas no sustituyen servicios.
- Guardas de identidad, moderación, conversaciones, Connect, aportaciones e
  idempotencia Guardian intactas. No éxito por redirect, tarjeta simulada,
  tienda/fondo/bonos/cashback ni dinero live.
- Gates apropiados Flutter/admin/backend/config y gate integrado sobre SHA
  exacto del candidato. CIdebug no es build Play.
- Candidato Codemagic android-guardian-internal en rama de continuidad; mismo
  com.mycompany.dopmi/firma, resultado y publicación Play verificados por separado.
- Android instalado: recorridos visuales/gestos/teclado/share/deep link con versión
  y SHA nuevos. La instalación2.3.3(285) anterior no demuestra estas correcciones.
  Capturas/controles ADB requieren la autorización específica pendiente; continuar
  trabajo independiente mientras tanto. No reinstalar borrando sesión.

Objetivo sigue activo. No se declara terminado por este inventario.
