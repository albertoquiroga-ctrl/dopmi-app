# Loop742 — Borde interior del historial

2026-10-04. Base70b2d32; Sourceirlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb verificado inicio/cierre.

Runtime Edge377×852 /history con empty states apagados: primera fila x17/y136.6875/width343/height64; fecha x31, cuerpo x93, amount right346. La lista CSS tiene border1/padding0 y filas padding14. Material.shape dibujaba borde sin descontar ancho de hijos; captura Flutter inicial fecha30/cuerpo92. Se añade Padding1 dentro de Material, sin modificar PaymentHistoryRow ni permisos/callbacks financieros.

Captura previa7391 terminal0,1/1 en3s; final32940 terminal0,1/1 en2s. Normal final inspeccionado. El desplazamiento visible se corrige; los textos/fechas/importes reales difieren de simulaciones Source. Test agregado al recorrido real verifica cuerpo x93, valor medido del navegador. No se afirma igualdad vertical fraccionaria ni aceptación visual global.

Suite87275 terminal0,27/27 en4s (payment_history_screen/row/payments). Analyzer32940 terminal0 limpio19.5s, antes de añadir assertion a test. Final72716 terminal0,9/9 en2s con assertion x93. No nuevo gate completo ni aceptación nativa. Codemagic sigue diferido y dinero test-only.
