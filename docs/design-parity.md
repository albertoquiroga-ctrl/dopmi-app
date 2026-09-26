# Dopmi — matriz de paridad

Referencia observada: `irlanda/apoyar-detalle-perfil@a246fa6f42ec517aae264d7fbd2358d647c4f840`. Inventario por lectura del código, no aceptación visual. Fuente y hashes en `design-reference.json`; volver a consultar la rama al inicio/cierre de cada ciclo.

## Rutas

| Referencia | Implementación/entrada actual | Hito | Diferencia | Responsables | Aceptación |
| --- | --- | --- | --- | --- | --- |
| `/` | `/welcome` | H8 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/choose-account` | `/welcome` | H8 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/choose-intent` | `/welcome` | H8 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/intro` | `/onboarding` | H8 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/onboarding/donor` | `/onboarding` | H8 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/onboarding/rescuer` | `/onboarding` | H8 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/welcome/donor` | `/start?intent=adopt` o `donate` | H8 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/welcome/rescuer` | `/start?intent=rescue` | H8 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/login/donor` | `/login` | H8 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/login/rescuer` | `/login` | H8 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/signup/donor` | `/signup` | H8 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/signup/rescuer` | `/signup` | H8 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/forgot-password` | `/forgot` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/terms/:mode` | `/terms` | H10 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/privacy/:mode` | `/terms (separación pendiente)` | H10 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/terms` | `/terms` | H10 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/privacy` | `/terms (separación pendiente)` | H10 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/adoption` | `/adoptions` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/adoption/:petId` | `/adoptions/:id` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/donate` | `/rescue-cases` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/case/:caseId` | `/rescue-cases/:id` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/donate/:caseId/:needId` | `/contribute/:id` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/donation-success/:caseId` | `Sin equivalente dedicado` | H9 | Diseñar/conectar estado o función real; no copiar simulación. | Implementador / Irlanda / titular | Pendiente |
| `/payment-error/:caseId/:needId` | `Sin equivalente dedicado` | H9 | Diseñar/conectar estado o función real; no copiar simulación. | Implementador / Irlanda / titular | Pendiente |
| `/impact` | `/guardian` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/impact/support` | `/guardian` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/impact/success` | `Sin equivalente dedicado` | H9 | Diseñar/conectar estado o función real; no copiar simulación. | Implementador / Irlanda / titular | Pendiente |
| `/impact/error` | `Sin equivalente dedicado` | H9 | Diseñar/conectar estado o función real; no copiar simulación. | Implementador / Irlanda / titular | Pendiente |
| `/messages` | `/messages` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/messages/:threadId` | `/messages/:id` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/notifications` | `/notifications` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/history` | `/payments` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/profile` | `/profile` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/saved` | `/saved` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/saved-rescuers` | `Sin equivalente dedicado` | H9 | Diseñar/conectar estado o función real; no copiar simulación. | Implementador / Irlanda / titular | Pendiente |
| `/settings` | `Sin equivalente dedicado` | H9 | Diseñar/conectar estado o función real; no copiar simulación. | Implementador / Irlanda / titular | Pendiente |
| `/settings/basic-info` | `/profile` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/settings/payment-methods` | `/guardian` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/settings/billing` | `/guardian` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/help` | `Sin equivalente dedicado` | H9 | Diseñar/conectar estado o función real; no copiar simulación. | Implementador / Irlanda / titular | Pendiente |
| `/rescuer-profile/:caseId` | `/people/:id` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/rescuer` | `/rescuer` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/rescuer/verification` | `/rescue/new?kind=verification` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/rescuer/cases` | `/rescuer` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/rescuer/cases/:caseId` | `/rescue/:id` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/rescuer/publish` | `/rescue/new?kind=case o /my-adoptions/new` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/rescuer/evidence/:caseId/:needId` | `/rescue/:id?kind=expense` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/rescuer/food/:caseId/:needId` | `/rescue/:id?kind=expense` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/rescuer/messages` | `/messages` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/rescuer/profile` | `/profile` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/rescuer/profile/edit` | `/profile` | H9 | Paridad visual pendiente; conservar backend existente. | Implementador / Irlanda / titular | Pendiente |
| `/rescuer/settings` | `Sin equivalente dedicado` | H9 | Diseñar/conectar estado o función real; no copiar simulación. | Implementador / Irlanda / titular | Pendiente |

## Estados transversales obligatorios

Cada fila necesita carga, vacío, error recuperable, reintento, interrupción, éxito y permisos cuando aplique. Adjuntar capturas del mockup/app con tamaño, SHA y datos de prueba equivalentes. Irlanda valida diseño, titular producto/dispositivo; el implementador registra evidencia.

- Autenticación: correo pendiente, recuperación, sesión expirada, OAuth cancelado y cambio de experiencia sin duplicar cuenta.
- Adopción/rescate: borrador privado, revisión, corrección/rechazo, publicación aprobada, retiro, cierre y suspensión.
- Archivos: selección cancelada, límite/tipo inválido, reanudación, acceso denegado y archivo aprobado inmutable; videos post-MVP.
- Mensajes: vacío, carga persistente, reconexión, duplicado evitado y acceso exclusivo de participantes.
- Aportaciones: capacidad agotada, Checkout abandonado, procesamiento incierto, pago confirmado, asignación, transferencia y devolución.
- Guardián: alta sin capacidad, consentimiento, mes omitido sin deuda, rechazo/3DS, tarjeta, cambio de monto futuro, cancelación, revisión e historial privado.
- No presentar transferencias como depósitos bancarios ni reservas como pagos. Nunca borrar estados necesarios porque no estén en el mockup.

## Diferencias de producto que prevalecen sobre el diseño

| Mockup | Tratamiento productivo |
| --- | --- |
| Fondo comunitario / Guardadito | Sustituir por asignación a gastos pagados y aprobados |
| Bono de $350 / cashback / Coins / compra antes de evidencia | Excluir promesas; evidencia y aprobación antes de recibir aportaciones |
| Éxito simulado / verificar con botón | Confirmación del servidor y moderación real |
| CLABE recolectada por formulario propio | Onboarding de Stripe Connect, sin duplicar datos bancarios |
| Videos | Post-MVP; rechazar hasta implementar pipeline y moderación |

H8 incorpora Adoptar/Apoyar/Perfil para donantes y las cinco pestañas de rescatistas, Inter/Fraunces locales, fondo blanco y púrpura #7841f2. La bienvenida usa las tres intenciones y sus iconos de referencia. Guardados, mensajes y publicaciones siguen accesibles desde Perfil. Onboarding contextual y formularios de acceso implementados; aceptación visual y paridad de los recorridos H9 siguen pendientes; ver [evidencia H8](design-foundation.md). No se declara aprobación visual por aplicar un tema.
