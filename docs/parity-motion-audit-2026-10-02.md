# Corte de movimiento y regreso — loop341, 2/10/2026

Referencia irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb. Cliente inicial a02ecac. Esta revisión distingue movimiento aplicable de CSS antiguo o hover y acredita únicamente las comprobaciones descritas.

| Recorrido | Contrato de referencia vigente | Evidencia de cliente |
| --- | --- | --- |
| Cambio de ruta | React Router sustituye contenido sin transición global. | DopmiPageTransitionsBuilder duration0/child directo. Pruebas de rutas Android/iOS y nueva ruta real signup→Aviso→Atrás: animationcompleted en primer pump, correo/intención/scroll/consentimiento intactos. |
| Introducción adoptante/rescatista | onb-gate-body con key slide.id; entrada450ms cubic(.22,1,.36,1), opacity0→1, y10→0; paso siguiente remonta cuerpo. | Nueva prueba DopmiApp/router/controllers reales: siguiente remonta entrada,0 al inicio/intermedia225/completa450; Atrás del sistema vuelve al paso anterior sin salir de ruta ni crear cuenta y reinicia entrada. Repositorios fake. |
| Selección de bienvenida | Colapso550ms y resumen/pie con demoras propias; CSS de selección separado de hover. | onboarding_motion_test comprueba retrasos, entrada y reducción de movimiento; navigation test conserva intención y regreso ampliado. |
| Tarjeta de Adoptar | DragX y giro directo; salida280ms y retorno250ms, curvas definidas en discovery CSS2594/2598. | discovery_motion_test comprueba seguimiento inmediato, umbral/retorno/cancelación sin guardar, salida280ms, interpolación independiente de giro/traslación y avance sin espera bajo movimiento reducido. |
| Pestañas | Acciones reales de navegación, estado privado por cuenta. | design_navigation_test comprueba ramas Adoptar/Favoritos, sesión rescatista, borrador descartado al cambiar identidad y navegación320px/200% accesible. |
| Evidencia de necesidad | NeedCard usa donate-need-chevron (styles6941), giro instantáneo al alternar. | PublicExpenseCard RotatedBox instantáneo. CSS need-expand/styles7086 pertenece a selector anterior no usado por NeedCard actual; no añadir animación150ms sólo por encontrar regla CSS antigua. No nueva aceptación de expansión/servidor aquí. |

Gate dirigido final:30/30,8s,flutter test --no-pub test/route_motion_test.dart test/onboarding_motion_test.dart test/discovery_motion_test.dart test/design_navigation_test.dart,handle20897 exit0. No producción modificada en este loop; tres pruebas integradas nuevas reemplazan evidencia indirecta por la app/router reales. Primera ejecución28/28 precede dos pruebas añadidas.

No acredita rasterización/runtimeSource nuevo, dedo físico/Samsung, navegación instalada, share nativo ni publicación Play. No cierre de las demás familias. Último full481 sobre7defead precede337/339/340/341. Capturas305/36 sin nuevas341. Mantener matrizglobal265 y verificar familias restantes con sus flujos reales antes de candidato Codemagic único final.
