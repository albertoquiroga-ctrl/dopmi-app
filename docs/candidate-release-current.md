# Candidato Guardián y pagos — 15/10/2026 México

El titular encarga a Codex terminar directamente este release sin depender de
Paperclip. CEO, Desarrollo, Calidad y Mejora IA quedaron pausados estando libres;
se conserva su evidencia. Se reutiliza un solo seguimiento operacional.

Base `23f64786d96586e04feb53652d209d33ebb5f1b7`, continuación
`codex/finish-release-20261015`. El checkout original tiene cambios ajenos y no
se limpia ni superpone. Referencia congelada
`0962ebec70bacf9ff8707960bb0908e5b979acfe`, conservada privadamente en
`development/dopa39/reference0962ebe/App.tsx`.

## Alcance humano vigente

Decisión14oct: registrar Guardián aun sin capacidad, sin cargo/deuda/recobro;
evaluar el siguiente aniversario mensual. Conciliar el mismo intento; éxito y
error confirmados, acción bancaria cuando sea necesaria y fallos mensuales en
Perfil/Tu impacto. Implementar primero y auditar después diseño residual.
No pedir otra vez variantes como bloqueo previo a la implementación.
Mínimo Guardián20MXN, puntual10MXN; este lote conserva la fórmula financiera
existente y no autoriza dinero real.

## Delta implementado

- Tarjeta Guardián mediante SetupIntent y PaymentSheet dentro de Dopmi:
  consentimiento previo, propietario, lease, clave estable y confirmación servidor.
  Apple/Google mantienen controles separados; Checkout histórico conserva canal.
- Puntual mediante PaymentIntent ligado antes de abrir SDK, reserva completa y
  settlement existente. Expiración1h conserva el límite Checkout anterior;
  sólo cancelación confirmada libera, sin nuevo cargo ante incertidumbre.
- Intento Guardián marcado/no enviado/rechazado se cancela y consulta sobre el
  mismo recurso. Método nulo sólo en canceled/requires_payment_method ya ligado;
  éxito/acción/método extranjero o identidad incompleta siguen rechazados.
  requires_confirmation conserva120s de gracia para no cancelar un envío concurrente.
- pk_test independiente de billeteras; disponibilidad y avisos seguros, clave
  conservada, navegación bloqueada durante SDK y consulta sin segundo envío.
  Perfil/Tu impacto muestran el intento terminado sin cobro.
- El SDK comprueba propietario/ruta antes y después de inicializar: cerrar sesión
  o salir no abre una hoja de pago del actor anterior. Recibos terminales e
  históricos se leen con filtro de propietario aunque la admisión nativa esté
  cerrada. Accesos de pagos refluyen al ampliar texto, sin partir palabras.
- Webhook del PI Guardián concilia únicamente su intento marcado/vinculado y
  ciclo de SQL; una entrega duplicada termina sólo jobs pendientes de ese ciclo.
  Relee evidenciaTEST y no autoriza cobros ni busca candidatos globales. La
  ausencia de binding se distingue de un fallo de permisos/RLS, que conserva503.

## Evidencia actual y límites

Paquete privado: `C:/Users/betoq/Paperclip-Dopmi/development/dopa39/integration-test-package-23f64786`.

PostgreSQL17.6 real59/59, `codex-registration-postgres-v3.log`: fuentes actuales
en base nueva temporal, carreras con dos conexiones para registro y puntual.
Contenedor dedicado/tmpfs, puerto127.0.0.1:55432, sin datos de negocio ni
AuthHTTP/Stripe. Red interna+bridge para Windows; no afirmar salida aislada.
No se parcheó el stack antiguo ni se tocaron sus volúmenes.

Backend completo782/782, `codex-full-backend-v2.log`, antes del último caso de
gracia concurrente; consumer final32/32 y puntual38 dirigidas. Configuración
móvil17/17. Primer fallo backend era proyección ampliada
stripe_payment_intent_id:null; corrección y regresión561/561.

Flutter analyze sin incidencias (`codex-mobile-analyze-v2.log`, antes del último
ajuste de perfil/guardas SDK). La suite completa local obtuvo1085 aprobadas y8
fallos, conservados en `codex-mobile-full.log`: fixtures de disponibilidad,
desplazamiento y etiquetas anteriores, lectura de recibos y navegación pendiente.
Se corrigieron agrupadamente; después118/121 dirigidas identificaron tres
restantes. El corte final19/19 (`codex-mobile-async-final.log`) comprueba esas
correcciones y sesión cambiada durante respuesta503;53/53
(`codex-mobile-profile-final.log`) comprueba registro y accesos al100/200%.
Formato de19 archivos Dart sin cambios. CI completa nueva aún debe acreditar
todas las comprobaciones juntas en el commit final; no extrapolar del subconjunto.

Revisión independiente de capturas actuales cerró el defecto de palabras
partidas al200%. Capturas en `codex-native-captures-release`; demuestran widgets,
no PaymentSheet bancario, lector de pantalla ni teléfono real. Diseño residual
se audita después de esta implementación: registro sin cobro, conciliación y
método pendiente/expirado no vuelven a bloquear código por un diseño previo.

Siete definiciones/ACL remotas y cuatro bundles Edge actuales respaldados mediante
conector propio. La operación agrupada16SQL pasó ensayo PostgreSQL real sobre83
fuentes base y los siete originales remotos exactos: STOP por drift inducido,
COMMIT único y postflight19 funciones/6 tablas/ACL/RLS; base UUID eliminada.
Recibo `codex-operation/operation-local-rehearsal-receipt.json`.
Tres GET de metadatos de cuentas Connect TEST existentes verificaron tipo/país/
capacidad, sin propietarios/PII, cambios ni transferencias; destino nominal sólo
para fixture local. No migraciones remotas, flags, pagos, KYC o producción
modificados en este corte.

## Cierre pendiente

1. CI completa por SHA/evento/workflow.5b3c15e1/run38835112715 final4/4verde:
   web/base, Flutter (analyze0,1113tests, capturas y APK debug), iOS simulator,
   integración identidad/adopción. No es publicación firmada ni Play.
   El primer379d8baf/run38833853805 tuvo3jobsverdes y Flutter detenido por tres
   infos de análisis ya corregidas, sin quitar reglas. La auditoría remota después
   encontró un webhookPI Guardián que caía al procesador puntual; corrección
   acotada y revisión independiente favorables,46/46 dirigidas y4entrypoints
   Deno comprobados (`codex-registration-scoped-webhook-final.log`). Ese delta
   backend requiere su commit/CI nueva; no atribuirle la CI anterior por inferencia.
2. Una operación revisada:16 fuentes SQL agrupadas con guardas, postflight,
   cuatro bundles Edge, flags TEST nominados y ensayo finito. Sólo DEV
   ohqxranynackjignryep; PRODysaoeuidcvgtlmphmeyb excluido. Sin replay/repair/purga.
   Conservar expansión/reconciliadores después de jobs nativos; no restaurar
   ciegamente tres RPC anteriores ni prometer reversión de efectos Stripe por SQL.
   Ensayo proveedor preparado, NO ejecutado:1Customer/1SetupIntent/máximo4
   PaymentIntents,30MXN TEST esperados y50MXN TEST intentados,96 peticiones máximo;
   sin transferencias. No prueba webhooks reales ni entrega al rescatista por sí solo.
   Los flags actuales no delimitan una cohorte; no prometer aislamiento por actor
   sin control efectivo. Cambios remotos/recorrido TEST necesitan la decisión
   concreta agrupada, no heredan los permisos de lectura anteriores.
3. Autenticación Stripe ya disponible: clave publicable TEST recuperada del
   sandbox correcto y ligada al tenant obtenido con GET /v1/account. Petición
   Codemagic preparada con override público por build; no necesita persistir
   una variable nueva ni copiar claves privadas. Build aún no disparado.
   Dashboard Supabase DEV autenticado permite configurar el flag puntual nuevo,
   actualmente ausente, sin ampliar accesos. Los seis flags Guardián ya estaban
   habilitados. Lectura real del webhook TEST detectó cuatro eventos faltantes:
   setup_intent.succeeded/canceled/setup_failed y payment_intent.canceled.
   Incluir unión exacta conservando los21 eventos anteriores, URL, versión y
   secreto en la autorización agrupada; todavía no se modificó configuración.
   Cron existente activo cada minuto, colas financieras agregadas sin elegibles
   al corte01:27Z; no crear otro timer ni invocar reconcile global como probe.
   Capacidad actual de dos gastos DEV aprobados suficiente para Guardián20;
   lectura predictiva no es barrera de concurrencia ni prueba de caso sintético.
   Preparar un único recorrido financiero remoto revisable que sustituya el
   ensayo financiero local aún PENDING; no ejecutar ambos ni crear otras cuentas
   por inferencia. AuthAdmin de dos identidades técnicas requiere alcance y
   acceso específico en la misma decisión agrupada; sin INSERTauth/PII/grants.
4. Integración TEST real y android-guardian-internal/com.mycompany.dopmi.
   Publicación Play se comprueba separada del build; teléfono/aceptación humanos
   siguen pendientes. El campo teléfono vacío fue observado EN APP por titular;
   no inferir estado Auth ni enviar SMS/cambiar cuentas.

Ruta local/DEV existente sin Pro ni proyecto/rama nuevos: incremento de planUSD0.
No se contrató plan; cuotas/saldo Codemagic se comprueban aparte. Una compra nueva
requiere costo/alcance concreto, no se infiere del permiso condicional Supabase.

## Traslado y retro

Captura20261015T234131Z-014202 conserva9536 archivos comprobados, pero no es
respaldo final completo: automatización y tareas cambiaron durante captura.
Se conserva compañía/originales y trabajo comercial independiente; no borrar.

La cadena anterior acumuló preparación/lecturas y esperas sin integración.
Esta continuación usa checkout conservado, ejecución directa, revisión acotada y
una cola Flutter. Juzgar resultados/gates/candidato, no roles/acuses, autonomía
general o ahorro de tokens/costo inferido de una muestra pequeña.
