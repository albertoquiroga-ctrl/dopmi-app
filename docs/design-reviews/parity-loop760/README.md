# Loop760 — Reserva fraccionaria de líneas en Adoptar vacío

2026-10-04. Basecd9bb3d; SourceIrlanda a3c969cd9103fd46dc5cd886999912526ce75efb sin cambios inicio/cierre.

Source ejecutado Edge377x852/adoption, awaitdocument.fonts.ready explícito: card x28.5/y144/w320/h277.265625/padding32x24/borde1/gap8; título x66.375/y177/w244.234375/h62.375; párrafo x56.015625/y247.375/w264.953125/h60.890625, marginbottom16; CTA x53.5/y336.265625/w270/h52/margintop4. Confirma cascada efectiva, no estilo antiguo28padding/border0. Browser propio cerrado.

Native758 título62 y párrafo60 redondean línea a31 y20. Probe71340 con Inter real confirma paragraph60 y líneas20 tanto sin strut como forceStrutHeighttrue; prueba temporal retirada del scratch tras terminar. No se atribuye corrección a strut.

WordWrap heading conserva anchos y palabra completa, ahora reserva scaler26*1.2 por línea; copia calcula número real de líneas con TextPainter a ancho disponible y reserva scaler14*1.45 por línea. No escala ni distorsiona glifos; reserva fracción de layout para alinear bloques siguientes. Conserva texto/categoría/filtros/callbacks y wrapping200%. Es adaptación de cajas CSS a layoutFlutter, no igualdad de pintura subpíxel atribuida.

Gate78661 exit0:6/6 en2s discovery_empty. Capturador ahora exige cardheight277.265625 yCTA336.265625 con tolerancia.1, frente tolerancia previa2 para CTA. Captura/analyzer82478 pendientes al redactar. Full756/803 y global758/419 anteriores a este cambio; sin Codemagic ni aceptación global/nativa. Dinero test-only.

Final82478 exit0:captura1/1 en2s/3PNGnormal200wide200 PIL/dimensiones/hash en capture-manifest.json; normal y200 inspeccionados. cardheight277.3 yCTA336.3: diferencia.034375px frenteSource, assertion.1 pasa. Analyzer limpio65.2s ydiffchecksinerror. Sólo comentario de documentación reubicado después, copia scratch sincronizada; no comportamiento nuevo sin verificar. No todos los glifos CSS/Skia idénticos atribuidos.
