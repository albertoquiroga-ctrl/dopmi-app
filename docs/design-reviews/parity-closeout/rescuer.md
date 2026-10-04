# Cierre agrupado — Rescatista

Fecha: 2026-10-04 (México). Fuente de inicio `53716dc5669dd5b55eb690d1ca071b9902868e7e`.
Referencia local y remota comprobada: `irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb`.
Sesión Source propia `dopmi-closeout-rescuer`, Edge377×852 en puerto5176; cerrada con exit0.

## Pasada finita

Se inspeccionaron **142 capturas móviles** existentes de la colección758 en hojas de contacto a píxeles originales, incluyendo tamaño normal377×852,320×640/texto200%, estados y posiciones inferiores. No se regeneró la colección ni se ejecutó Flutter en paralelo. Las variantes de foco/hover se excluyeron. Los screenshots sintéticos con teclado no acreditan teclado Android.

| Familia | Capturas inspeccionadas | Estados incluidos | Resultado de esta pasada |
| --- | ---: | --- | --- |
| RH |12|inicio, sin verificar, en revisión, vacío, acciones y evidencia; normal/200%|Sin nuevo defecto visual. Resumen y actividad conservan hechos financieros reales.|
| RC |16|lista, vacío, correcciones, detalle, historia, historia vacía, inferior y cerrado; normal/200%|RC-01/02 cerrados con pruebas y capturas nuevas.|
| PUBLISH |38|selector, fotos/cuadrícula, información/nombre opcional, necesidades, medicina/comida/veterinario, salud/social y revisión; normal/200%|PUBLISH-01 cerrado; SVG correctos y composición ampliada conservada.|
| VERIFY |16|introducción e inferior, formulario/campos/experiencia/documentos/progreso, aprobado y revisión; normal/200%|VERIFY-01/02 cerrados con Inter, pruebas y capturas nuevas.|
| EVIDENCE |29|archivo privado imagen/PDF/error, modal/adjuntos, información/descripción/privados/revisión/enviado e inferiores; normal/200%|EVIDENCE-01/02 cerrados con pruebas y capturas nuevas.|
| RP |19|perfil normal/referencia/ancho/200%, editor y teclado sintético, configuración/inferior/sociales/diálogos; normal/200%|RP-01 cerrado; palabra completa y vista normal idéntica.|
| STORY |12|lista, vacío, error, editor nuevo/borrador/error; normal/200%|Sin nuevo defecto; editor real adicional. Historia pública incluida también en RC.|

Selección exacta sobre [inventario758](../parity-loop758/capture-inventory.json): prefijos RH=`rescuer-home`; RC=`owned-cases`,`owned-case-detail`; PUBLISH=`publish-`,`case-publication`; VERIFY=`verification-`; EVIDENCE=`expense-`,`private-file-`; RP=`rescuer-profile`,`rescuer-settings`,`public-profile-editor`; STORY=`managed-updates`. Se excluyen nombres que contienen `-focus` o `-scroll-blur`; no hay duplicados entre las siete familias.

Las142 capturas permiten una inspección visual conjunta; no son142 recorridos remotos ni142 aceptaciones instaladas. Fuente de colección758:714853a/producción0328de6. Los parches760/761 posteriores no modificaron estas familias.

## Contraste con Source ejecutado

- `/rescuer`: resumen, acciones pendientes, evidencia y navegación. `/rescuer/cases`: publicado/borrador/revisión/rechazado; `/rescuer/cases/rocky`: hero, fotos, necesidades y sección histórica inferior. `scrollIntoView` confirmó historia aY65.203125 y MAIN.screen-scroll.scrollTop1243.
- `/rescuer/publish`: selector y ruta Dar en adopción/fotos. Recibir donaciones recorrido por foto simulada Source→información→necesidades→modal medicina→revisión. No se pulsó Publicar; no se trasladó simulación al cliente.
- `/rescuer/verification`: aprobado; cambio del modo de prueba a sin verificar, introducción y Continuar→formulario. El intento genérico de scroll no desplazó el formulario: el screenshot denominado source-verify-bottom es el primer viewport, **no prueba del footer**. Footer Flutter sí inspeccionado; el estilo/control Source inferior se comprobó en App.tsx y se conserva evidencia541 de la ruta real de progreso.
- `/rescuer/evidence/rocky/rocky-vet`: marco/modal, recibo, navegación de pasos y acciones; `/rescuer/profile` y `/rescuer/settings`: identidad, métricas, actividad y filas/acciones. El intento genérico de scroll en settings no probó el último pie; se inspeccionaron los pies Flutter y las filas Source en código.
- Historia: reutiliza el contraste755 de dimensiones, fecha, tipografía y aprobaciones; nueva captura Source inferior inspeccionada. No existe ruta Source para el editor real de avances.

Capturas Source y hojas temporales: `C:/Users/betoq/AppData/Local/Temp/dopmi-closeout-rescuer/`. No se versionan imágenes, datos reales ni configuración. La sesión contiene sólo ejemplos del mockup.

## Ocho diferencias concretas; un solo lote

| ID | Diferencia observada | Corrección implementada | Evidencia de cierre |
| --- | --- | --- | --- |
| VERIFY-01 | donacione/s en la introducción al 200% | Padding horizontal 16 sólo con título ampliado; normal 24 conservado, sin reducir fuente | Cerrado: prueba con Inter y selección de palabra; verification-intro-large muestra «donaciones» completa. |
| VERIFY-02 | Acción multilínea de introducción sin margen; guardar después alineado a izquierda | Márgenes de botones sólo ampliados, labels centrados y ghost con margen 8 sólo ampliado | Cerrado: prueba de márgenes y capturas verification-intro-footer-large / verification-form-progress-large con labels centrados. |
| RC-01 | Corregir publicación multilínea sin margen/centrado | CTA tonal y outlined de lista con padding 12×18 sólo ampliado, texto centrado | Cerrado: pruebas de lista y owned-cases-correction-large con margen superior/inferior y líneas centradas. |
| RC-02 | Administrar avances/Consultar expediente multilínea con espacio insuficiente | Padding 12×18 sólo ampliado y texto centrado en acciones inferiores | Cerrado: pruebas de detalle y owned-case-detail-bottom-large con labels centrados y espacio interior. |
| EVIDENCE-01 | Informació/n y publicació/n junto a Editar | Título y Editar en filas separadas sólo a texto grande/ancho <300 | Cerrado: prueba con Inter/selección de palabras a 240 px; expense-review-large y expense-review-private-large muestran títulos completos y Editar debajo. |
| EVIDENCE-02 | Guardar progreso multilínea alineado a izquierda; Entendido ampliado pegado al borde | Labels centrados; confirmación reserva padding vertical 10 sólo ampliado | Cerrado: pruebas de acciones; expense-description-footer-large centrado y expense-submitted-footer-large con margen alrededor de Entendido. |
| RP-01 | Rescatis/ta junto al avatar al 200% | Avatar encima del texto sólo cuando scale(20)>26; fila normal conservada | Cerrado: prueba con Inter/selección de palabra; rescuer-profile-reference-large muestra «Rescatista» completa. |
| PUBLISH-01 | Tres emojis de necesidades renderizados como glifos de sustitución | Tres SVG existentes de referencia en caja 36×36, sin dependencia de emoji/font del sistema | Cerrado: prueba de flujo; case-publication-needs normal muestra las tres ilustraciones Source. Variante ampliada y lista ampliada sin regresión; las tres opciones quedan fuera del primer viewport ampliado. |

Cambios productivos: verification_intro, verification_form, rescue_screens (sólo CTA de OwnedRescueCard), owned_case_detail, expense_frame, expense_review, case_needs y rescuer_profile_hero. Tres pruebas existentes fortalecidas: verification_intro_test, expense_review_press_test y rescuer_profile_hero_test; no se añadieron pruebas que dupliquen implementación. Dartformat y diffcheck aprobados.

## Comprobación del lote integrado

El coordinador ejecutó el gate de las familias integradas en una sola cola: **386/386, exit 0, 1m41s**, sesión 71673. Se comprobó el final real del log `C:/Users/betoq/AppData/Local/Temp/dopmi-parity-20260930/closeout-batches-tests.log`: identifica verification_intro_test, expense_review_press_test, expense_frame_controls_test, case_need_dialog_test, owned_case_card_gesture_test y owned_case_detail_test, entre otras suites. El coordinador reporta también cobertura de rescuer_profile_hero_test; ese nombre no aparece en el log de salida, por lo que la selección exacta queda por confirmar en el comando o en el gate final. Se trata del árbol con cambios sin commit sobre `53716dc`; el gate del SHA final sigue a cargo del coordinador.

Capturador integrado profile: **1/1, exit 0, 3m26s**, log `closeout-profile-captures.log` en el mismo directorio. Se inspeccionaron **22 PNG nuevos** de los ocho IDs, generados entre 13:05:55 y 13:08:46 del 4 de octubre. Registro de dimensiones, hora y hashes: [rescuer-capture-manifest.json](rescuer-capture-manifest.json). Son ocho fixtures normales idénticos por SHA256 a 758: owned-cases-correction, owned-case-detail-bottom, rescuer-profile-reference, verification-intro, verification-intro-footer, verification-form-progress, expense-review y expense-submitted. case-publication-needs normal cambia por los tres SVG esperados; su variante ampliada conserva el hash anterior porque las opciones están debajo del primer viewport. También se inspeccionó la lista ampliada y la sección privada de revisión.

Resultado finito de este frente: **ocho IDs cerrados; cero nuevas diferencias visuales pendientes** en las siete familias inspeccionadas. El ajuste posterior del coordinador `if (edit != null) edit` → `?edit` en expense_review es sólo sintaxis equivalente; no modifica el layout. El análisis final continúa en la cola común. No se ejecutó Flutter, compilación, publicación ni comprobación Android desde este agente.

## Diferencias de función que deben conservarse

Source simula saldo disponible, progreso de fondeo, links sociales/OAuth, CLABE directa, publicación instantánea y liberación de fondos. Cliente conserva asignado/transferido/en revisión, gastos ya pagados, Connect, enlace social revisado manualmente, nombres/ubicaciones reales y revisión antes de publicar. No fabricar porcentajes de saldo/fondeo, distancias, contadores o información pública. No videos, tienda, fondo, bonos ni cashback.

Adopción y necesidades siguen guardadas como borradores privados; imágenes públicas requieren aprobación. Archivos imagen/PDF privados y editor real de avances son recorridos adicionales necesarios, sin contraparte simulada idéntica. No se modifican repositorios, permisos, idempotencia, cálculos, esquema ni dinero test. El archivo de usuario rescuer_settings_verification.dart permanece intacto.

Los ocho IDs ya tienen pruebas y contraste de sus capturas afectadas; no se reabrieron las 142 capturas por cambios exclusivamente ampliados. RH y STORY no requieren nueva implementación por esta pasada. Navegación/gestos/teclado Android y aceptación del candidato final siguen en el gate nativo común; este documento no cierra el objetivo por sí solo.
