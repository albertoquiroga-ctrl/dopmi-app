# Loop366 — confirmación de tarjeta, 3/10/2026

Referencia Irlanda a3c969cd9103fd46dc5cd886999912526ce75efb, reconsultada sin cambios. Toast Source inmediato, 2600ms, márgenes16/bottom24, blanco/borde/radio16/sombra0 12 32, icono16/gap10/padding12 16/peso500. Flutter conserva esos valores y anuncia resultado en live region. Eliminación Source no tiene toast visible: lista verificada y anuncio accesible solamente.

El cambio sólo anuncia éxito si estado aplicado y lectura nueva confirman la misma tarjeta predeterminada. Fallo de consulta retiene comprobación pendiente; actualizar puede confirmarla. Solicitud histórica aplicada no se presenta como nueva acción; refrescos posteriores no repiten aviso. Timer se cancela al desmontar.

Capturas de widgets reales, fixtures sintéticos: 377×852 normal y320×640 texto200%; inspeccionadas sin overflow. No comparación de píxeles ni aceptación instalada. Texto adapta líneas al espacio disponible. Capturador6estados aprobados4s (78235), analyze limpio29.1s (1225). Suite original dirigida45/45; pruebas nuevas de lectura fallida/histórico/replay: guardian+feedback44/44,8s (65058 exit0). Primer intento43pass1fail por helper que buscaba FilledButton en control de actualización; corregido a tap/ensureVisible del control existente. Un comando invocado accidentalmente en raíz no encontró pubspec; se ejecutó luego en scratchmobile.

Inventario316estados/37URLs. Full504 de359 antecede este cambio. Alta independiente, billeteras reales, aceptación Auth integrada y matriz global siguen abiertas. Sin Codemagic/push; candidato final únicamente.
