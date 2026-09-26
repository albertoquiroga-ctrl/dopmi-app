# Dopmi — entrega de Hito 5 (modo prueba)

## Decisión de aceptación — 25 de septiembre de 2026

El titular autorizó: «Hagamos lo que recomendo el humano de stripe. autorizo». H5 queda aceptado únicamente en modo prueba con la cobertura alternativa de disputa descrita abajo. No autoriza dinero real ni cierra las etapas R0–R6 del lanzamiento público.

## Alcance y evidencia

- Alta con consentimiento, abandono/expiración y recuperación del mismo intento; reserva y asignación completas, sin cobro cuando falta capacidad. Evidencia integrada y referencias en [aceptación](guardian-acceptance.md) y [registro](progress.md).
- Renovación mensual, omisión sin deuda, rechazo y recuperación con tarjeta válida sin recobrar meses omitidos; cambio de tarjeta/3DS, solicitudes de monto/retiro y cancelación. Android, RPC propietarias y objetos Stripe test conciliados.
- Calendario de fin de mes desde plan preparado: enero por 50, febrero28 y marzo30 por 200, cancelación y ausencia de factura/ciclo en abril. Capturas1000344226/1000344230/1000344228/1000344232. Alta ordinaria acreditada separadamente; no se afirma alta originada el día30.
- Historial privado, cambio de cuenta, restricciones para administradores y paginación móvil21 ciclos. Devolución total, devolución parcial en revisión y reversión en dos destinos; referencias e importes conservados.
- Reenvío firmado y recuperación tras pérdida de respuesta real, incluida solicitud incierta que cruza el aniversario. Sin duplicados observados; instrumentación temporal retirada. La pérdida de respuesta antes del SDK no se presenta como corte TCP.

## Excepción aceptada: disputa posterior a transferencia

Soporte humano Stripe, Smile, caso `sco_VKNrYjqxXyMbJi`, confirmó que el entorno test no ofrece disparador manual, demora configurable ni mecanismo asistido para crear una disputa después de confirmar la transferencia de un cargo existente. La secuencia remota completa **no se ejecutó** y no se marca como aprobada.

La cobertura alternativa recomendada por soporte y autorizada por el titular consta de:

1. Disputa automática real de Stripe antes de asignar: cargo recuperado por API, revisión conservada y ausencia de liquidación/plan/transferencia; pantalla Android sin formulario ni reintento. Cambios847e184/0140fbd y capturas1000344166/1000344168.
2. Conciliación posterior a transferencia aislada: evidencia Stripe simulada, RPC local real, variantes con/sin devolución, estado review, historial refund_review, asignado/transferido4314 y revertido0. Repetir conciliación no crea reversión ni devolución y conserva capacidad ocupada. Prueba943a7d4. No acredita Stripe remoto ni una pantalla móvil de este segundo escenario.

Revisión independiente documental y del test no identificó otro recorrido funcional pendiente y consideró suficiente esta excepción explícita para proponer cierre test. No repitió consultas remotas ni verificó por su cuenta el chat de soporte. La revisión de seguridad previa y revisiones de correcciones están registradas en progress.md.

## Verificación y distribución

- `npm test` en tools/verification:388 aprobadas. CI [36202506285](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36202506285), commit `943a7d4fb8797333e49981cbf7f1d96de15f2583`: cuatro jobs completed/success, reconsultados al cierre. Incluye checks de configuración, web/admin, PostgreSQL/permisos/concurrencia, identidad/adopción, Flutter analyze/tests y compilaciones Android e iOS simulator.
- Ruta de dispositivo: Codemagic → Google Play interno. Build252, versión2.3.3, commit0140fbd, ejecución6ab6e1527e2cdbe815b37fa0, publicación internal completed. Samsung SM-S938B, Android16/One UI8.5. El titular reportó actualización y las pantallas acreditan el comportamiento; las capturas no muestran versionCode instalado. TestFlight es alternativa, no requisito adicional de esta aceptación.
- Cierre documental sin cambios de runtime, esquema, configuración de dinero ni nuevo build. Conservar `com.mycompany.dopmi`, gates test y claves idempotentes.

## Continuidad

H6 y las etapas de lanzamiento conservan su alcance en [backlog](backlog.md) y [contrato](mvp-release-contract.md). Producción, operación con dinero real y depósito bancario necesitan aceptación separada. No repetir los recorridos H5 aceptados ni presentar la excepción como una prueba remota realizada.
