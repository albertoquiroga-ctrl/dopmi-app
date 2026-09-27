# Dopmi — matriz de paridad

## Contrato vigente — 26/9/2026

H8 comprende todos los recorridos siguientes. La tabla histórica de rutas más abajo localiza pantallas, pero sus asignaciones anteriores a H9 quedan supersedidas por `h8-execution.md`. Estado por defecto de cada fila: **I pendiente / T pendiente / V pendiente** (implementación, comprobación técnica, aceptación visual). Ninguna fila está aceptada por Irlanda.

| ID | Pantalla/acción de referencia | Diferencia concreta a resolver en Flutter | Datos/dependencia | Prueba/evidencia requerida |
| --- | --- | --- | --- | --- |
| NAV | Barras donante/rescatista, cambio desde Perfil/Configuración | Cambiar preferencia sin guardar datos; Publicar abre selector; perfiles por modo | profiles.active_mode, sesión única | Persistencia/restauración, error de guardado, borradores entre pestañas, cambio de cuenta |
| AUTH | Splash, elección, introducciones, entrada, login/registro/recuperación | Revisar encuadres y espaciados existentes; confirmación real y OAuth gated | Auth existente | Cada intención, regreso, teclado y texto ampliado |
| DISC | Inicio Adoptar | Sustituir lista/título genérico por foto dominante, swipe y controles Pasar/Me gusta/contacto | Catálogo, favoritos, casos elegibles | Arrastre corto/largo, doble pulsación, fallo de favorito, fin, reintento y paginación |
| FILTER | Perros/Gatos; modal filtros/ubicación | Selector, chips sexo/tamaño/personalidad, ciudad/radio con aplicar/cancelar | Personalidad y zona aproximada nuevas | Filtro real, permisos denegados, sin ubicación, ninguna distancia inventada |
| PET | Detalle de mascota, galería y contacto | Jerarquía fotográfica, datos/historia/cuidados, responsable y barra de acciones | Adopción aprobada, chat actual | Imagen/galería, volver mantiene mazo; contacto confirmado, retiro público |
| MATCH | Mis match, búsqueda, chats y favoritos por tipo | Pantalla nueva; no es sólo lista de conversaciones | Threads/favoritos adopción/casos | Búsqueda propia, selección, vacío, errores, no simular reciprocidad |
| SAVED | Mascotas, casos y rescatistas guardados | Conteos y listas separadas sincronizadas | Favoritos de casos/rescatistas nuevos | Alta/baja idempotente; terceros no acceden; retirados no filtran datos |
| CHAT | Conversaciones de ambos modos, detalle y notificaciones | Rehacer presentación/badges conservando backend | Mensajes/lecturas/notificaciones actuales | Duplicados/red/reconexión, remitente auténtico, aislamiento |
| PROFILE | Perfil donante | Sustituir formulario principal por tarjeta amarilla, historial corto, accesos e interruptor | Perfil, pagos y estado Guardián reales | Sin datos simulados; actualizado al volver; vacío/error |
| SETTINGS | Configuración, información básica, pagos, ayuda | Pantallas separadas, regresos contextuales, acciones operativas | Perfil/Stripe existentes; FAQ por rol | Guardado fallido conserva edición; no pisa modo; cancelación/cierre sesión |
| SUPPORT | Apoyar / Ver todos | Círculos de casos, progreso y entrada Guardián en lugar de lista uniforme | Catálogo/objetivos aprobados | Sin gastos elegibles, recarga, abrir caso/Guardián |
| CASE | Caso público, gastos desplegables, galería/reportar | Foto principal, historia, categorías y gasto con evidencia pública aprobada | Casos/gastos/pagos actuales; reportes nuevos | Foto privada denegada, gasto agotado, share/deep link, reporte persistido |
| STORY | Avances / historia hasta ahora | Timeline/ciclo/Storage implementados; falta comparación visual y datos demo instalados | `dopmi_case_updates`, snapshot moderado y Storage privado | Borrador/corrección privados, revisión/publicación y edición posterior |
| PUBLIC | Perfil público: Actividad/En adopción/Casos | Avatar/bio/redes moderados; conteos verdaderos; guardar rescatista | Perfil público, agregados autorizados | Ciudad/chat públicos; ningún correo/documento; filtros por propietario |
| IMPACT | Impacto personal | Sustituir ejemplos por avances de casos realmente apoyados | Asignaciones privadas y avances publicados | Usuario A no ve atribuciones de B; cero asignaciones muestra vacío |
| RH | Inicio rescatista | Panel con saludo, casos, acciones pendientes y actividad | Resúmenes autorizados | Sin saldo ficticio; acciones abren entidad correcta; estados incompletos |
| RC | Mis casos/detalle/editar/cerrar | Tarjetas por estado, progreso y vínculo a adopción | Relación caso–adopción nueva | Interruptor no publica; cierre/revisión correctos; guardado de corrección |
| PUBLISH | Selector y formularios por pasos | Publicar deja de abrir Mis publicaciones; fotos/datos/revisión, recuperar borrador | Publicaciones/casos y archivos actuales | Cancelar selección, subir/interrumpir/reanudar, validar/enviar una vez |
| VERIFY | Introducción/verificación/estado | Flujo progresivo con expediente privado y correcciones | Verificación/moderación actuales | No autoaprobar; estado remoto, documentos sólo autorizados |
| EVIDENCE | Gasto veterinario/comida/medicina/otro | Pasos específicos y progreso persistido; evidencia antes de recibir aportaciones | Gastos pagados actuales | Adjuntos privados, fechas/importes, recibo duplicado, correcciones |
| RP | Perfil/configuración rescatista | Perfil propio distinto, editar público separado del expediente | Perfil moderado; Connect | Datos bancarios externos; cambio modo no confiere autorización |
| PAYMENT | Aportar, resultado/error/regreso | Diseño del resumen y estados reales en vez de éxito simulado | Checkout/conciliación test existentes | Abandono, pendiente, confirmado, devuelto, revisión; sin doble cobro |
| GUARD | Presentación/monto/consentimiento/impacto/gestión | Adaptar carruseles, tarjeta, cambios/cancelación e historial | Guardián H5 existente | Sin capacidad, mes omitido, monto futuro, tarjeta, cancelación y errores |
| REPORT | Reportar mascota/caso/rescatista; administración | Recepción/RPC/bandeja persistente creadas; conectar caso, perfil y panel visual | RPC/RLS implementados | Acuse sólo tras insertar, duplicados/reintento, denuncias privadas |
| LEGAL | Ayuda/términos/privacidad | Composición coherente sin presentar legal provisional como definitivo | Textos actuales; definitivo H10 | Regreso por modo y enlaces reales |

Evidencia por fila se anexará al completar cada ciclo con SHA de código/diseño, prueba y capturas de pantallas reales. No cerrar por una captura de componente aislado.

### Estado I/T/V vigente

| ID | Implementado | Comprobado técnicamente | Aceptado visualmente | Evidencia o diferencia abierta |
| --- | --- | --- | --- | --- |
| NAV | Parcial | Parcial | No | Cambio de modo dedicado y selector Publicar cubiertos; falta cerrar toda la conservación de estado y revisión instalada. |
| AUTH | Parcial | Sí, sobre recorridos existentes | No | Acceso previo reutilizado; falta nueva comparación final con la referencia vigente. |
| PROFILE | Parcial | Parcial | No | Vista principal, datos reales, historial/vacío/error y cambio de modo implementados; faltan rescatistas guardados y aceptación. |
| SETTINGS | Parcial | Parcial | No | Información básica separada, ayuda, historial y cierre de sesión; método de pago depende de Guardián habilitado. |
| PUBLISH | Parcial | Parcial | No | Selector inicial implementado; formularios por pasos y reanudación siguen abiertos. |
| DISC, FILTER | Sí | Sí | No | Mazo, acciones, filtros, ubicación aproximada, paginación y casos elegibles cada dos adopciones conectados; falta revisión instalada. |
| PET, MATCH, SAVED, CHAT | Sí | Sí | No | Detalle/galería, favorito con rollback, contacto confirmado, búsqueda, guardados tipados/tombstones, acciones de casos/perfiles y mensajería idempotente cubiertos; falta comparación instalada. |
| SUPPORT, CASE, STORY, PUBLIC, IMPACT | Sí | Sí | No | Apoyar, progreso/gastos reales, galería pública, avances moderados, perfil con pestañas e impacto propio asignado están conectados y tienen capturas Flutter; falta revisión instalada. |
| RH, RC, VERIFY, EVIDENCE, RP | No | No | No | H8.6 pendiente. |
| PAYMENT, GUARD, REPORT, LEGAL | Parcial | Parcial | No | Servicios previos reutilizables; falta paridad completa y estados del plan vigente. |

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
| `/impact` | `/impact` | H8 | Impacto propio conectado a cantidades asignadas y avances públicos; falta comparación visual instalada. | Implementador / Irlanda / titular | I/T sí; V pendiente |
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
