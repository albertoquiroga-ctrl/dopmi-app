# Cierre de paridad — tablero vigente

Actualizado: 4 de octubre de 2026. Base `53716dc`; referencia
`irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb`.

## Criterio acordado

La app debe verse y sentirse igual al usarla. Se corrigen diferencias perceptibles,
recortes, animaciones y gestos; el titular acepta diferencias imperceptibles de
renderizado. Hover queda excluido. Se conservan operaciones reales, privacidad,
accesibilidad y dinero exclusivamente en test.

## Estado de la pasada de cierre

Este contador acredita el cierre revisado de familias, no pantallas implementadas.
Las 25 familias ya tienen implementación. La pasada encontró **24 defectos
confirmados**: 24 corregidos y revisados en capturas actuales; cero defectos
visuales conocidos restantes en esta pasada.
El candidato PM-D no se confirmó como defecto y no se suma. **25/25 familias**
tienen revisión de desarrollo cerrada. Ninguna cifra sustituye
la aceptación Android ni la regresión integral del candidato final.

| Lote | Familias | Estado | Ficha |
| --- | --- | --- | --- |
| Acceso/navegación | NAV, AUTH, LEGAL | 3/3 revisadas; nativo pendiente | [Acceso](design-reviews/parity-closeout/access-navigation.md) |
| Adoptar/conversar | DISC, FILTER, PET, MATCH, SAVED, CHAT | 6/6 revisadas; nativo pendiente | [Adoptar](design-reviews/parity-closeout/adopt-converse.md) |
| Donante/público | PROFILE, SETTINGS, SUPPORT, CASE, PUBLIC, IMPACT, REPORT | 7/7 revisadas; nativo pendiente | [Público](design-reviews/parity-closeout/donor-public.md) |
| Rescatista | RH, RC, PUBLISH, VERIFY, EVIDENCE, RP, STORY | 7/7 revisadas; nativo pendiente | [Rescatista](design-reviews/parity-closeout/rescuer.md) |
| Pagos en test | PAYMENT, GUARD | 2/2 revisadas; SDK/nativo pendiente | [Pagos](design-reviews/parity-closeout/payments.md) |

## Cola única restante

| ID | Tipo | Diferencia / comprobación | Cierre requerido |
| --- | --- | --- | --- |
| ANDROID-01 | Nativo | Candidato instalado anterior al código actual | APK nuevo con SHA y verificación de las ocho mecánicas |
| ANDROID-02 | Nativo | Teclado/archivos/fotos/share/permisos/interrupción | Recorridos por cinco lotes desde candidato actualizado |
| RELEASE-01 | Gate | 386/386+67/67 dirigidas; falta gate integral del lote | Regresión integral CI sobre SHA candidato final |
| RELEASE-02 | Entrega | Play286 anterior al candidato | Codemagic final y publicación Play comprobados separadamente |

AUTH01/04/05, AC01–05, DP01–05, VERIFY01/02, RC01/02,
EVIDENCE01/02, RP01, PUBLISH01 y PM-A/B/C son los24 defectos corregidos.
AUTH02 tiene27 capturas actuales; AUTH03 documenta la pista adicional Apoyar
sin atribuir una tercera pista Source inexistente. No se considera defecto una
prueba o captura pendiente.

Colección actual:421PNG más27 de acceso, manifiestos en las fichas; capturador
profile1/1 en3m26s y acceso1/1 en12s. Gate dirigido71673:386/386 en1m41s.
DP04 cerró con recaptura de3estados y67/67 dirigidas en22s; analyzer limpio75s.
Se confirmó la corrección de ambas pruebas sociales que fallaron en Codemagic.
El detalle completo permanece en cada ficha, sin expedientes
por cada margen. La recuperación restaurada se prueba sin cargar perfil privado.

## Evidencia reutilizable

- [Colección758](design-reviews/parity-loop758/README.md):419estados/47URLs;
  no419aceptaciones. Capturas válidas de componentes sin cambios se conservan.
- [Acceso761](design-reviews/parity-loop761/README.md):18capturas/6rutas.
- [Gate756](design-reviews/parity-loop756/README.md):803/803, anterior760/761.
- [Movimiento741](design-reviews/parity-loop741/README.md):55comprobaciones de
  ocho mecánicas; [757](design-reviews/parity-loop757/README.md) fortalece indicadores.
- Histórico del tablero: versión Git `53716dc:docs/parity-current-review.md`.
  Sus pendientes se interpretan con entradas posteriores de progress; no son cola actual.

## Regla de trabajo

Una inspección completa por lote, una lista de diferencias, una corrección
agrupada y pruebas dirigidas. Una cola Flutter central. Un estado verificado
se reabre por cambios en su componente/dependencia/referencia o defecto
comprobado. Datos, archivos privados y snapshots aprobados conservan sus reglas.
Codemagic se ejecuta al finalizar el candidato, no por avance.
