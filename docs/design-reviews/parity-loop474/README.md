# Loop474 — privacidad compacta y corrección de evidencia de navegación

Basef811904; referencia a3c969cd9103fd46dc5cd886999912526ce75efb reconsultada. AccountPrivacyScreen pasa de PageFrame/HeadingFraunces a ContributionFrame title18/padding16-20-16-32, paleta de experiencia y back al origen o perfil. Mantiene medición/accesos/confirmación/eliminación, mensajes/errores y ausencia de barra. No cambios de repositorio/SQL/SDK/configuración ni eliminación real.

Errata473: el bloque de navegación se había insertado tras la captura de adoption-drag; condición account-access-options allí nunca era verdadera. Las42 pruebas y PNG eran válidas, pero no probaban ese recorrido. Se movió al bloque final de captura y se corrigió la atribución en README473/ledger474. Contadores expected/actual exigen ejecutar cada fixture de navegación seleccionado:2/2 para account-access. También se bombea tras ensureVisible antes de hitTestable; el primer intento realmente ejecutado detectó ese frame pendiente.

10pruebas identidad/social pasaron en bundle44373 (11/11 incluyendo capturador anterior), log dopmi-loop474-mobile.log. Capturador final46585 exit0,1test/9capturas7s, dopmi-loop474-capture-final3.log, con los dos recorridos efectivamente ejecutados: opciones→privacidad→opciones→perfil y modo rescatista conservado. Analyzer68820 limpio33.6s antes mover/instrumentar sólo capturador; compilación final incluye esos cambios. Privacidad normal/grande/contenido final inspeccionados, before preservados.

Extensión sin SourceURL literal; encabezado coherente no aceptación visual global ni Android. Full591471 anterior a473/474; no gate completo nuevo atribuido. Siguiente consentimiento y precisión del encabezado común, Connect/archivo privado/matriz global. Sin Codemagic/push/aceptación instalada.
