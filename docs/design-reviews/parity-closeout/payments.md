# Lote pagos en prueba

4 de octubre de 2026. Base `53716dc`; referencia
`irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb`.

Pasada completa de 66 estados: 25 de métodos de pago, 30 de Guardián y 11 de
aportaciones/resultados. Se revisaron normales, texto al 200 %, posiciones
inferiores, espera, cancelación, error, confirmaciones, historial y autorización.
Source ejecutado con fuentes cargadas y viewport 377 × 852 en métodos,
facturación, cancelación y alta de Guardián. Datos financieros simulados no se
copian al producto. PAYMENT y GUARD tienen implementación completa; aceptación
del SDK y del candidato instalado permanece separada.

| ID | Diferencia observada | Corrección | Evidencia de cierre |
| --- | --- | --- | --- |
| PM-A | Confirmación multilínea sin margen vertical suficiente al 200 % | Padding del botón existente; mismo consentimiento y resultado | PNG actuales de confirmaciones independiente/default/remove/add, normales y ampliadas, inspeccionadas por revisor Adoptar |
| PM-B | Eliminar tarjeta alineado a izquierda al ocupar dos líneas | Centrar label de confirmAction | cards-remove-confirm normal/200, margen y centrado inspeccionados |
| PM-C | predeterminado partido dentro de la palabra en el aviso ampliado | Icono encima del texto a escala grande; ancho completo | cards-default-toast normal/200, palabra completa; prueba con Inter real conserva expiración2600ms y cancelación al desmontar |

El candidato PM-D no se cuenta como defecto: la captura antigua no mostraba
el tile completo. La adaptación preventiva apila radio y texto sólo al ampliar;
`guardian-billing-amount-tile-large.png` actual muestra Aportación completa y
mantiene selección. La prueba existente de consentimiento/céntimos/teclado se
fortalece con selección de palabra y fuente real. No se reduce la escala del texto.

PNG actuales en `C:/Users/betoq/AppData/Local/Temp/.tools/design-review/`,
revisión posterior con mtime 13:06 del 4 de octubre. Source en el mismo
directorio: `closeout-source-payment-methods`, `billing`, `guardian-amount`,
`guardian-cancel`, `enrollment`. El alta Source confirma botones de cantidad
67px, wallets56px, tarjeta70px y confirmación48px. Se conserva el marco existente;
los proveedores disponibles dependen de SDK, plataforma y configuración reales.

Gate dirigido integrado: `closeout-batches-tests.log`, sesión71673 exit0,
386/386 en1m41s. Incluye pagos, Guardián, cantidad, facturación y feedback;
anteriores al fortalecimiento final de selección por palabra. Regresión integral
y APK nativo se registran en el tablero común sobre el SHA candidato.

Se conservan la aceptación financiera H5 en test y su excepción de disputa,
idempotencia, revisión de evidencia, consentimiento, ownership, autorización
del servidor, neto y ciclos reales. Cambios exclusivamente de presentación:
sin APIs, SQL, cobros, nuevas reglas, saldo inventado, beneficios ni fondos.
Las capturas no comprueban Stripe ni publicación Play.
