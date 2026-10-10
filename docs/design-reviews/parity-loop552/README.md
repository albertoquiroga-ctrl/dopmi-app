# Loop 552 — Toque y desplazamiento de tarjetas

Referencia local `a3c969cd9103fd46dc5cd886999912526ce75efb` (remoto revalidado551): RescuerCases usa manage-case-top linkish para estados distintos de revisión. El contenido superior de la tarjeta nativa ahora abre /rescue/:id, como las acciones reales existentes, y refresca al volver. Revisión conserva Ver envío; no se copia hover. InkWell sin splash/highlight/hover y borde superior19 reserva borde exterior20.

Seis pruebas nuevas: borrador/correcciones/aprobado × texto normal/ampliado. Desplazar desde la tarjeta no navega ni lee expediente; tocar foto/nombre carga el ID correcto y no guarda. Son gestos inyectados en Flutter, sin aceptación de Android físico.

11479 terminal exit0: 40/40 seleccionadas,9s. 87146 terminal exit0: analyzer sin incidencias,20.9s. Seis PNG regenerados e idénticos byte por byte a551; manifest contiene comparación. No nueva inspección visual directa ni nuevo runtime web. Full611/407 de546/547 precede este bloque; existen ahora seis pruebas adicionales, sin full617 ejecutado.

Cambios locales preservados. Sin push/Codemagic hasta objetivo completo.
