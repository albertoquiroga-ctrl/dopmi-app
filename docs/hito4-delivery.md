# Dopmi — entrega del Hito 4 (modo prueba)

## Alcance entregado

- Aportaciones únicas a gastos aprobados con Stripe Checkout en modo de prueba; comisión Dopmi del 2 % del bruto y costo real de Stripe descontado para calcular el neto de la rescatista.
- Stripe Connect con cobro y transferencia separados; los estados de pago, asignación, transferencia a la cuenta Stripe y depósito bancario se muestran y contabilizan por separado.
- Webhook firmado y trabajador periódico; registros de eventos, reclamos y movimientos idempotentes. Los fallos necesarios permanecen reintentables en lugar de confirmarse silenciosamente.
- Reembolso total posterior a la transferencia y reversión correspondiente, con evidencia privada y acumulados recalculados. Las devoluciones/reversiones parciales quedan explícitamente sujetas a revisión manual.
- Historial privado para donante y rescatista, y consulta administrativa con permisos del servidor.

## Evidencia de aceptación

- Stripe de prueba: aportación de $50.00 MXN, una transferencia neta de $43.14 MXN, un reembolso de $50.00 MXN y una reversión de $43.14 MXN. El acumulado del gasto y del caso volvió a cero. La rescatista vio «Devuelto», «Transferencia revertida» y neto de $0.00 MXN en Android. No es dinero real ni demuestra un depósito bancario.
- Trabajo programado `dopmi-payment-worker-reconcile`: activo cada minuto; respuesta comprobada HTTP 200, tres eventos pendientes conciliados, cero fallos. El token vive en Supabase Vault y se resuelve en cada ejecución.
- Pruebas locales de backend: 54/54, incluida la regresión de la consulta de candidatos. Admin: 18/18 y compilación de producción correcta.
- Los cuatro jobs de [CI 35926624549](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/35926624549) aprobaron el commit `ca7d23e`: `supabase test db` con migraciones reales, pruebas y build web/admin, formato/análisis/tests Flutter, APK Android de desarrollo, iOS simulator y pruebas integradas de backend. La compilación iOS no incluye firma para dispositivo.

## Límites y operación

- Las funciones rechazan claves/eventos live. No activar cobros reales sin revisar negocio, cumplimiento, comisiones, devoluciones, disputas, privacidad, alertas y conciliación; revisar por separado el webhook y credenciales live.
- Una transferencia Stripe no acredita que haya llegado un depósito bancario. La aceptación de ese paso queda para una prueba específica y no se deduce del caso reembolsado.
- Supervisar Cron y respuestas HTTP del trabajador. HTTP 200 con `failed=0` es distinto de una ejecución SQL exitosa que solo encola la solicitud HTTP. Para errores persistentes o revisión manual, conciliar en Stripe antes de reintentar; nunca volver a cobrar ni reiniciar claves de idempotencia.
- Configuración y recuperación segura en `docs/stripe-test-mode.md`. No conservar tokens en SQL del trabajo, código, móvil ni documentación.

## Propuesta histórica para Hito 5 — Guardián

La propuesta siguiente se conserva como antecedente. El titular decidió las reglas el 23 de septiembre y H5 ya fue implementado en modo prueba; sigue pendiente la aceptación integrada. Para continuar, usar [product-decisions.md](product-decisions.md), [backlog.md](backlog.md) y [codex-handoff.md](codex-handoff.md), sin volver a solicitar decisiones ya tomadas.

1. Definir el ciclo mensual y la autorización del donante: $50/$200/$500 MXN o monto personalizado, con cancelación y estado transparentes. Validar sus decisiones de UX antes de implementar.
2. En cada ciclo, obtener los gastos previamente pagados y aprobados de rescatistas habilitados; ordenar por urgencia aprobada y luego por aprobación más antigua. Cubrir cada faltante antes de asignar al siguiente, sin exceder el reembolso autorizado.
3. Solo cobrar cuando **todo** el importe mensual pueda asignarse; si no hay suficiente gasto aprobado, omitir el ciclo sin deuda, sin «Guardadito» y sin reserva comunitaria. Si un cobro confirmado deja de ser asignable, devolver lo no asignado de forma auditable.
4. Reutilizar los controles de Hito 4 para cobro, transferencias, devolución, duplicados, historial privado y conciliación; probar cancelación, cambios de gasto entre selección y confirmación, concurrencia y mes omitido. No activar bonos ni cashback simulados.

Este antecedente no autoriza dinero real. El estado vigente de la preparación y apertura de altas test está en `guardian-acceptance.md`.
