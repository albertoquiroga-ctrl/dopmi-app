# Inventario al pausar — 2 de octubre de 2026

Objetivo pausado por el titular. No continuar implementación ni iniciar Codemagic hasta que lo reanude. El CI ya iniciado puede continuar externamente.

Decisión nueva: paridad de experiencia de teléfono. Hover y otros comportamientos exclusivos de escritorio no son requisitos ni justifican nuevos ciclos. El teclado virtual, accesibilidad, áreas táctiles y gesto de regreso sí corresponden al teléfono. El hover añadido anteriormente no se ha retirado durante esta pausa.

Referencia: irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb, última consulta remota exitosa en loop248. Producción publicada: b38acd8f82ba7444901117ee8b43eca0d7f9fff5. HEAD local c776856 añade únicamente registro del checkpoint. Archivos locales del titular preservados.

## Evidencia disponible

- Funciones reales existentes de identidad, adopción, mensajes, moderación, evidencia, contribuciones y Guardian se conservan; no requieren reconstrucción.
- Inventario del capturador:250 estados en29URLs, más el capturador de acceso/componentes. Son fixtures de widgets de producción, no250 pantallas aceptadas ni toda la matriz del router.
- Capturador completo de perfiles/casos/mensajes/estados pasó localmente en2m01s; análisis final sin incidencias.
- Perfil público: marco, identidad, redes, pestañas, adopciones/casos y numeralia implementados. Contrato agregado público desplegado y comprobado en DEV; importes netos y revocación con pruebas. Composición de actividad comparada con referencia renderizada. Esto no cierra todos sus estados ni dispositivo.
- CI422: web/base de datos, identidad/adopción e iOS simulator aprobados; Flutter pruebas/análisis aprobados, capturas fallaron por toque bajo encabezado. Corrección publicada y capturador completo local aprobado.
- CI424/run37049347038 para b38acd8: in_progress al consultar durante el inventario. Aún no se afirma éxito integral de este corte.

## Pendientes de paridad y entrega

| Bloque | Qué falta demostrar o corregir |
| --- | --- |
| Comparación visual completa | Cerrar diferencias concretas por ruta/estado: acceso y navegación, Adoptar/filtros/detalle/match/guardados, mensajes/notificaciones, perfiles/ajustes, Apoyar/caso/historia/impacto, panel rescatista/casos/publicación/verificación/evidencia, pagos/Guardian/reportes/legal. Recuperar evidencia histórica; no reconstruir lo ya implementado. |
| Gestos y animaciones móviles | Comparación ejecutada de swipe parcial/umbral/retorno/salida, interrupción/doble toque, galerías/carruseles, scroll y regreso, transiciones y hojas. Una captura estática o test de duración no demuestra la sensación en Android. |
| Descubrimiento con red lenta | La salida visual y RPC de favorito ya arrancan en paralelo; la siguiente tarjeta aún puede esperar el RPC. Contrastar con referencia y corregir sin perder persistencia, rollback ni aislamiento de cuenta. |
| Perfil público | Comparar pestañas de adopción/casos y todos los estados vacío/carga/error/reporte/contacto con la referencia; validar fotos reales y recuperación del avatar tras suspensión/expiración; comprobar compartir/enlaces útiles. Actividad y tarjetas ya tienen implementación, no están en cero. |
| Datos y estados reales en candidato | Recorrer con servicios de prueba: guardado/reintento, retiro público, permisos, mensajes, moderación y pagos test; verificar que los cambios visuales no ocultan errores ni muestran datos privados o simulados. Las funciones ya aceptadas requieren regresión, no desarrollo nuevo general. |
| Android instalado | Instalar candidato firmado nuevo preservando identidad/sesión y verificar fotos, teclado virtual, texto ampliado, áreas táctiles, gesto atrás, suspensión/reanudación y red. Última instalación observada2.3.3(285) precede estos cambios. Conexión USB no acredita esta aceptación. |
| Gate técnico actual | Esperar resultado424 y resolver fallas si aparecen. Repetir gates sólo ante nuevos cambios o dudas concretas; registrar SHA/run exactos. |
| Codemagic y Play interno | Aún no enviado. Al reanudar y completar el candidato: android-guardian-internal, conservar com.mycompany.dopmi/firma, verificar build y publicación separadamente; registrar SHA, versión/build y enlace. Luego revisión instalada de Irlanda. |

No existe porcentaje de paridad ni número fiable de ciclos restantes: la evidencia actual no permite estimarlos honestamente. El próximo avance útil es cerrar comparaciones móviles por recorrido, empezando por descubrimiento/galerías/mensajes con teclado, seguido del perfil público; evitar microciclos de escritorio.

Fuera de este objetivo: activación de dinero real, tienda, fondo comunitario, bonos/cashback, videos, Meta, push y analítica avanzada. Dinero permanece test-only. La ruta autorizada de entrega es Android/Play interno; iOS simulator de CI no es aceptación instalada en iPhone.

## Actualización posterior: reanudación autorizada

El titular aclaró que desea continuar el objetivo hasta terminarlo. La pausa anterior ya no aplica. Hover sigue fuera del criterio. Loop250 corrige espera de red entre tarjetas; falta validación instalada y cierre de recorridos. El inventario superior conserva el corte histórico, no una nueva orden de pausa.

