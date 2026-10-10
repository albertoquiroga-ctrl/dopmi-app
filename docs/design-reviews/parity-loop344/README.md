# Fuentes efectivas de la referencia — loop344, 2/10/2026

Referencia irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb. Cliente e1f4d32. Esta comprobación resuelve la incertidumbre de carga de fuentes de cortes anteriores; no acredita igualdad de rasterización entre Chromium y Flutter ni de todas las pantallas.

## Recepción y uso reales

Vite5176, IAB27 /terms/donor. CDP Network tras reload observó200 de CSS Google Fonts y de dos WOFF2 (cache del navegador). Sin loadingFailed de esas solicitudes en el intervalo completo observado. DOM.querySelector + CSS.getPlatformFontsForNode confirmó en h1 Fraunces/21glifos/isCustomFonttrue/PostScriptFraunces-9pt-SemiBold-NonWonky, y en lead Inter/63glifos/isCustomFonttrue/PostScriptInter. La lectura anterior mediante iterable document.fonts no probaba fallback; no cambiar producción para compensar una ausencia no demostrada.

Archivos efectivamente solicitados:
- https://fonts.gstatic.com/s/inter/v20/UcC73FwrK3iLTeHuS_nVMrMxCp50SjIa1ZL7.woff2
- https://fonts.gstatic.com/s/fraunces/v38/6NU78FyLNQOQZAnv9bYEvDiIdE9Ea92uemAk_WBq8U_9v0c2Wa0KxC9TeA.woff2

## Archivos y ejes

Inter Source/móvil Version4.001/git-66647c0bb. WOFF tiene wght100–900/default400; TTF local tiene además opsz14–32/default14. Fraunces Source/móvil Version1.000/[b76b70a41]. Ambos opsz9–144 y wght100–900; local conserva SOFT0–100/default0 y WONK0–1/default1. Source face es NonWonky y DopmiTokens usa WONK0. Revisión contextual de todos los fontFamily Fraunces/displayFont en lib halló fontVariations alrededor; no se cambiaron fuentes por hipótesis.

Comparación FontTools4.62.1/instancer/DecomposingRecordingPen, sólo los ejes y corpus declarados en [font-outline-sample.json](font-outline-sample.json):
- Inter400 Source contra móvil400/opsz14:230Unicode comunes,0 diferencias de avance y0 de contorno.
- Fraunces600/opsz28 Source contra móvil600/opsz28/SOFT0/WONK0:222Unicode comunes,0 diferencias de avance; tres diferencias diminutas de coordenadas en !, underscore e ¡. Mismo número/tipo de comandos; máxima coordenada observada0.103710fontunits sobre2000≈0.001452px a28. No afirmar contornos idénticos de Fraunces ni extrapolar a otros ejes.

WOFF descargados sólo a TEMP. Python global tenía FontTools pero faltaba Brotli; runtime empaquetado no tenía ambos. Brotli1.2.0 dePyPI se instaló únicamente en TEMP/dopmi-font-audit-344/packages, sin modificar dependenciasapp/lock/SDK ni instalación global. Scripts/resultados auxiliares fueraGit; no credenciales ni datos de usuario. No changeSource/DOM/font override: sólo instrumentación de lectura, reload, tabcerrado y Vite detenido.

Siguiente comparación debe usar fuentes efectivamente comprobadas y condiciones equivalentes; no interpretar identidad de archivos/métricas como aceptación visual completa ni gesto instalado. Regresión494/342 y pagos12/343 siguen cortes previos; sin producción modificada344, sin CM/push.
