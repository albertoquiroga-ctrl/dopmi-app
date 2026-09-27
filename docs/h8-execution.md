# H8 — paridad completa y funcional

Plan autorizado el 26 de septiembre de 2026. Supersede la definición anterior «componentes y navegación». Build 253 es parcial; no basta una revisión visual para cerrar H8. Referencia inicial y reconsultada: `irlanda/apoyar-detalle-perfil@a246fa6f42ec517aae264d7fbd2358d647c4f840`.

## Contrato

La experiencia completa visible del mockup pasa de H9 a H8, incluidas sus dependencias mínimas de backend. H9 conserva aceptación integrada/excepciones pendientes; H10 identidad pública, eliminación, analítica/legal; H11 ambos sistemas desde el mismo candidato. Historias son avances persistentes moderados, no contenido temporal. Ubicación aproximada opcional con alternativa manual; públicamente ciudad y chat, nunca domicilio, teléfono o correo personal.

Mantener servicios actuales, Flutter/React, reglas económicas y test. Nunca copiar fondo, tienda, bonos, cashback, identidades, estadísticas ni éxitos simulados. No habilitar videos. No reabrir H5. No alterar firmas de RPC usadas por build 253; migraciones aditivas, historial remoto contrastado antes del despliegue.

## Ciclos y aceptación

| Ciclo | Entrega concreta | Dependencias y comprobación |
| --- | --- | --- |
| H8.0 | Inventario de pantallas, modales, acciones y diferencias; separar implementación, verificación y aceptación | Recorrer HTML y contrastar Flutter; toda diferencia tiene tarea y excepción explícita |
| H8.1 | Dos experiencias, navegación, cambio de modo dedicado, acceso revisado | Preferencia persistida sin escribir formulario; regreso/borradores/cuenta aislados |
| H8.2 | Mazo swipe, Perros/Gatos, filtros, ubicación, intercalar caso elegible cada dos mascotas | Gesto/botón equivalentes; favorito real, paginación sin duplicados, error/reintento/final; no distancia inventada |
| H8.3 | Detalle de adopción, galería, contacto confirmado, Mis match, chats y tres clases de favoritos | Persistencia privada, retirar guardados inaccesibles sin revelar contenido, mensajes idempotentes |
| H8.4 | Perfil donante con tarjeta e historial; configuración/edición/ayuda separadas | Datos reales, vacío/error, tarjeta y suscripción mediante operaciones existentes |
| H8.5 | Apoyar, detalle/gastos, avances, perfil público y estadísticas | Avances moderados, sólo material aprobado, impacto ligado a asignaciones propias |
| H8.6 | Inicio/Casos/Publicar/Mensajes/Perfil rescatista; publicación por pasos, verificación y evidencia | Borradores persistentes, correcciones, vínculo caso–adopción sin saltarse revisión; Connect para banco |
| H8.7 | Aportación y Guardián con diseño fiel y estados completos | Confirmación del servidor; pago/asignación/transferencia/depósito/devolución diferenciados; regresiones financieras |

Dependencias nuevas: favoritos de casos y rescatistas por UUID; avances moderados; perfil público con avatar/enlaces aprobados; personalidad/zona aproximada; relación caso–adopción; reportes y bandeja de moderación; resúmenes públicos/privados autorizados. Modelos Dart tipados y repositorios separados de UI. No reutilizar tablas archivadas.

Cada tarea: implementar → probar → comparar pantallas reales con HTML → corregir → registrar evidencia. Comparar a 377×852, pantalla pequeña y texto ampliado. Verificar permisos de propietario/terceros/administrador y estados carga/vacío/error/reintento/interrupción. Ejecutar las suites pertinentes de AGENTS.md. Capturas de galerías de componentes no acreditan paridad de recorridos.

Entregas coherentes mediante `android-guardian-internal`, verificar publicación Play además del build y registrar SHA/versión. Irlanda/titular revisan desde Internal Testing. No marcar aceptación sin su respuesta. Consultar rama de Irlanda al inicio/cierre y abrir nuevas diferencias cuando cambie.

## Estado

H8.0–H8.7 están implementados y comprobados técnicamente en `codex/design-foundation`; la matriz conserva aceptación visual en **No**. La auditoría de cierre añadió el acceso directo a rescatistas guardados, restauró el hero fotográfico de Apoyar y versionó comparaciones completas HTML/Flutter. Estas correcciones son posteriores al Android 2.3.3 (254), por lo que requieren un nuevo candidato instalado antes de la revisión de Irlanda/titular. Las excepciones explícitas son OAuth/eliminación/analítica/legal de H10, iOS conjunto de H11 y dinero live de H12.
