# Dopmi — plan de lanzamiento autorizado

Decisión del titular: 25 de septiembre de 2026 (México). Este plan sustituye el alcance anterior de H6; H1–H5 conservan su evidencia. H5 está aceptado **sólo en test**, con la excepción de disputa descrita en `hito5-delivery.md`. Las etapas R0–R6 siguen como checklist de lanzamiento, no como hitos de desarrollo.

## Alcance y responsables

MVP público Android/iOS: paridad con Irlanda, identidad Google/Apple, recuperación y eliminación de cuenta; adopción, guardados, perfiles, mensajes y notificaciones internas; rescates, evidencia y moderación; aportaciones/Guardián; ayuda, reportes, soporte, legal, landing, administración, medición mínima y errores.

Post-MVP: videos, Meta/atribución publicitaria, push y analítica avanzada. Fuera del producto: tienda, fondos comunitarios, bonos y cashback. No copiar esas promesas del mockup. Sólo gastos pagados/aprobados, comisión Dopmi 2 %, mensualidad asignable completa y omisiones sin deuda.

Irlanda revisa diseño; el titular acepta producto y recorridos en dispositivos; el implementador entrega código, pruebas y estados faltantes. Una identidad conserva ambas experiencias. Mantener Flutter, React admin y Supabase, `com.mycompany.dopmi`, firma existente e idempotencia financiera.

## Hitos y dependencias

| Hito | Entrega | Depende de | Cierre |
| --- | --- | --- | --- |
| H6 | Base integrada por PR, documentos reconciliados, referencia viva y matriz de paridad | H5 test | PR integrado, CI verde y base inequívoca |
| H7 | Inventario/dependencias, respaldo restaurado, retiro gradual de legado, permisos y límites de código/archivos | H6 | Sistema actual independiente del legado, accesos antiguos cerrados y regresiones aprobadas |
| H8 | Tokens, fuentes, assets, componentes y navegación por experiencia | H7 | Comparaciones de capturas, accesibilidad y revisión visual |
| H9 | Adopción/contacto → rescate/evidencia → aportaciones/Guardián → cuenta/ayuda/reportes/admin | H8 | Recorridos reales con estados de carga, vacío, error, reintento, interrupción y éxito |
| H10 | Google/Apple, eliminación, analítica/errores, correo, soporte/legal y separación de entornos | H9 | Integraciones y configuraciones verificadas; sin exposición de contenido privado |
| H11 | Mismo candidato por Play Internal y TestFlight, usabilidad y reversión | H10 | Cero defectos críticos/altos, aceptación visual y funcional en ambos sistemas |
| H12 | Fichas, landing, revisión live, operación y publicación gradual | H11 | Autorización separada de dinero real y lanzamiento verificable |

H7 no permite borrar por similitud de nombres. Respaldar y restaurar antes de retirar; preservar evidencia financiera vigente. El titular confirmó que el sistema anterior era de pruebas. No resetear el proyecto compartido ni reproducir migraciones para alinear timestamps.

H8/H9 siguen el último commit de `irlanda/apoyar-detalle-perfil`. Registrar el SHA al inicio y cierre de cada ciclo, sin congelar indefinidamente el diseño. Las reglas de servidor y privacidad prevalecen sobre simulaciones. Los estados que no tengan diseño se revisan con Irlanda usando los mismos componentes.

## Contratos de implementación

- Pantallas → estado de presentación → repositorios → servicios. Introducir modelos tipados al tocar cada flujo, sin reescribir el motor financiero ya aceptado.
- Interfaz de archivos común para fotos/documentos, conservando validación, normalización, propiedad, inmutabilidad y publicación aprobada. Videos siguen rechazados hasta su hito propio.
- Analítica mediante interfaz explícita, eventos de navegación/conversión y consentimiento; jamás mensajes, documentos, correos ni tarjetas. La contabilidad no se deriva de analítica.
- Pagos mantienen estados separados de cobro, asignación, transferencia, depósito, devolución y revisión. No sustituir confirmación del servidor por la página de retorno.
- Eliminación de cuenta incluirá revocación de sesión, tratamiento de contenido y retención justificada de evidencia; Google/Apple no duplicarán identidades.

## Verificación y correspondencia de lanzamiento

R0 → H6/H7; R1 → H8/H10; R2/R3 → H9; R4 → H12; R5 → H10/H12; R6 → H11/H12.

Ejecutar checks pertinentes de Flutter, admin, configuración y backend; PostgreSQL y concurrencia para cambios transaccionales; integración identidad/adopción para cambios de autorización/ciclo de vida. CI completo antes de integración. Registrar commit/run, no sólo conteos.

Capturas con referencia de 377×852, dispositivo pequeño y texto ampliado; no declarar paridad con mera compilación. Beta: instalación/actualización, permisos, cámara/galería, enlaces, sesión, recuperación, pagos test y pruebas con personas ajenas al desarrollo. Evidencia por SHA, versión, build y dispositivo.

## Operación recurrente

| Frecuencia (America/Mexico_City) | Control | Límites |
| --- | --- | --- |
| Inicio/cierre de cada ciclo | Diff de Irlanda y actualización de matriz | Nueva referencia no borra evidencia anterior |
| Diario 09:00 | Detectar cambios de diseño | Avisar sólo novedades accionables; no publicar automáticamente |
| Cada PR | CI, permisos y comparación visual afectada | No integrar fallos pendientes |
| Cada build | Commit, artefactos y resultado de publicación | Build no equivale a instalación |
| Cada minuto | Trabajador financiero existente | No duplicar Cron ni cambiar idempotencia |
| Cada 5 minutos en producción | Fallos persistentes, webhooks y conciliación atrasada | Activar al preparar producción; alertas agrupadas |
| Lunes 09:30 | Dependencias, avisos, costos, soporte y deuda | Lectura y tareas acotadas; sin actualizaciones masivas |
| Día 1 de cada mes 10:00 | Restauración de respaldo, accesos y firma | Restaurar sólo en entorno desechable, nunca sobre remoto compartido |

La disponibilidad de automatizaciones locales depende del equipo y de las conexiones. No sustituye el monitoreo de producción del servidor. Dinero real requiere autorización explícita independiente.
