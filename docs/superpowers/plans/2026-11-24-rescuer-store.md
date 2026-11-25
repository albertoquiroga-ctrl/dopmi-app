# Tienda desde Inicio Rescatista

Base c58eb51d; producto edcdd5aa; mock congelado d9f9aa430ffc4b1d9df76e49e7efbe9f0e5cae1c.

1. Probar la entrada real de Inicio, las guardas de catálogo/actor y el retorno de la Tienda conservando modo y cinco pestañas. Ejecutar con el perfil adoption-only/PROD/Amazon actual.
2. Habilitar el banner existente cuando Amazon esté disponible y aplicar al caller Rescatista el texto y fotografía de CroquetasConCausaCard. Reutilizar /store; conservar el banner donante, catálogo, confirmación Amazon, navegación y permisos.
3. Revisar normal/320px con texto 200%, regresiones afectadas, análisis y CI completa. Revisión independiente de código y capturas antes del freeze.
4. Publicar sólo QA Play interno y TestFlight con una ventana real de cinco minutos por envío y una cola Flutter. Mantener QA física pendiente mientras el Samsung siga diferido; no inferir aceptación.

Sin SQL, flags, finanzas, cambios legales, nueva pestaña ni regla de inactividad.

## Ejecución comprobada

Fuente36f8e47f/tagcodex/rescuer-store-20261124-v1, CI45535907438 cuatro SUCCESS,
2178PASS/0FAIL/5SKIP en suite completa CI. Análisis limpio,144 regresiones locales,
44 checks de configuración; perfiles PROD/Amazon y sinAmazon comprobados.
Cinco capturas y revisión independiente código/visual sin P1/P2.
Android446 AAB/firma/runtime/Play interno comprobados; iOS447 IPA/provisión/
runtime y carga comprobados, tarea Apple finished/error=false03:53UTC25/nov. Dos envíos, ventanas propias
y cola serial. Instalación/QA/aceptación siguen diferidas por el titular.
