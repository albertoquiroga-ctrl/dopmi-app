# Atribución iPhone con descarga directa

Investigación del 20/11/2026, CDMX. Alcance: atribuir primera ficha y mensajes
sin códigos ni login antes de descargar. Es investigación y propuesta; no acredita
implementación, revisión de páginas personalizadas ni prueba instalada.

## Hallazgo que corrige la conclusión anterior

La afirmación anterior de que la descarga directa sólo permite agregados era
demasiado amplia. **Custom Product Pages (CPP) con deep links** ofrece una vía
nativa prometedora: la persona llega directamente a una página de App Store,
instala y pulsa **Abrir en esa misma página**. En iOS/iPadOS18 o posterior, Apple
envía el deep link configurado para esa CPP. No promete entregarlo cuando abre
desde el icono o una ficha genérica. El deep link puede ser universal o URL
propia; necesita aprobación de Apple. [Configuración oficial](https://developer.apple.com/help/app-store-connect/create-custom-product-pages/configure-multiple-product-page-versions/).

Las CPP tienen URLs propias, admiten comunicaciones y promociones sociales y
pueden crearse copiando la ficha existente. Apple Ads es una posibilidad, no
un requisito. [Descripción de CPP](https://developer.apple.com/app-store/custom-product-pages/).
Apple confirmó el uso de sus deep links en canales sociales en
[WWDC24, desde14:12](https://developer.apple.com/videos/play/wwdc2024/10063/?time=852).
También describe website→CPP→descarga→contenido específico en
[WWDC26, desde2:50](https://developer.apple.com/videos/play/wwdc2026/205/?time=170).
Esto justifica probar una instalación nueva; no reemplaza esa prueba.

## Aplicación propuesta a DopMi

Inferencia de ingeniería: cuatro CPP corresponderían a personal-a, personal-b,
pagina-a y pagina-b. Cada una tendría un deep link fijo hacia una experiencia
real de publicar o conocer adopciones, incluyendo la variante. Los enlaces de
dopmi.org conservarían el salto directo a App Store. Después de Abrir, DopMi
guardaría la variante pendiente; tras login normal y consentimiento de Analítica,
la uniría a la cuenta autenticada. No habría código ni autenticación previa.

Desde esa fuente propia podrían medirse separadamente primera ficha enviada,
aprobación de esa ficha, saludo automático, primer mensaje humano del adoptante
y primera respuesta del dueño, conservando moderación y privacidad de mensajes.
La recepción del enlace no debe publicar mascotas, enviar saludos ni conceder
permisos. Esta vinculación futura requiere integración cliente/servidor; Apple
entrega una URL, no hace la unión con la identidad DopMi.

Para comparar mensajes de Facebook, convendría mantener los mismos recursos
visuales de tienda en las cuatro páginas y variar sólo su referencia/contexto
necesarios. Así no se confunde texto del comentario con una ficha diferente.
La admisión de cuatro páginas equivalentes depende de App Review: no se presume.
Si exige contenidos distintos, el resultado compararía comentario y página
combinados; no demostraría por sí solo qué mensaje de Facebook funciona mejor.
No asignarles keywords de búsqueda ni reutilizarlas en anuncios u otros canales
durante el piloto. Un enlace compartido también puede circular fuera de Facebook;
la fuente identifica la variante del enlace recibido, no dónde vio realmente la
persona el comentario. Esa URL tampoco es un recibo autenticado de Apple: se
puede invocar o compartir fuera de la tienda. No usarla como prueba antifraude,
de instalación nueva ni como base de beneficios o privilegios.

## Evidencia y ventana diferentes de Android

El deep link de CPP es estático por página. No contiene un nonce por clic ni
fecha autenticada del clic original, y tampoco demuestra primera instalación.
Propuesta: método independiente `ios_cpp_open`, variante y hora de recepción en
servidor, sin fabricar `p_clicked_at` de Android. No se deben reutilizar sin
cambios el lector Play ni su elegibilidad por clic dentro de14d.

La política de caducidad pendiente y ventana de eventos iOS tendría que definirse
desde esta nueva evidencia. Mantener denominadores separados: descargas Apple,
aperturas CPP reconocidas, cuentas consentidas y resultados. Las aperturas sin
URL seguirían sin atribuir; no completar su fuente por IP, proximidad horaria o
un reparto estimado entre variantes. Reportar cobertura observada y cohortes
maduras antes de comparar resultados. No hay una garantía universal documentada.

## Brechas del candidato419

Inspección de las fuentes móviles vigentes, equivalentes al419/efcce99f:
[content_links.dart](../apps/mobile/lib/core/content_links.dart) sólo admite
enlaces públicos con dos segmentos y UUID; rechaza query, fragmento, puerto y
usuario. No reconoce una ruta de campaña. El listener actual navega al contenido,
sin guardar una fuente pendiente durante login/consentimiento.
[Info.plist](../apps/mobile/ios/Runner/Info.plist) declara `io.dopmi.app`, pero
[Runner.entitlements](../apps/mobile/ios/Runner/Runner.entitlements) no declara
Associated Domains. El lector
[android_rescuer_acquisition.dart](../apps/mobile/lib/core/android_rescuer_acquisition.dart)
devuelve nulo fuera de Android. Configurar sólo una CPP no resuelve esas brechas.

Un futuro cambio necesitaría parser específico estricto y separado del público,
persistencia pendiente protegida, consumo idempotente y dueño autenticado. Habría
que rechazar replay/reasignación entre cuentas y conservar la primera fuente
válida según una política explícita. OFF, revocación y cambio de cuenta deben
impedir atribuir una acción al actor anterior. El URL scheme ya registrado
permitiría ensayar el nuevo handler; universal links añadirían asociación dominio/app y AASA,
con revisión de su alcance. No ampliar silenciosamente el parser público ni
desactivar autorización para aceptar cualquier URL.

## Alternativas contrastadas

| Opción | Capacidad y límite para este encargo |
| --- | --- |
| Campañas Apple `pt/ct` | Ya disponibles para descargas y uso agregado; no entregan a DopMi la cuenta que creó ficha o mensaje. El API exporta esos reportes, no convierte esos eventos propios en métricas Apple. [Campañas](https://developer.apple.com/help/app-store-connect-analytics/acquisition/campaign-links). |
| Branch NativeLink | Copia el enlace mediante un botón previo a App Store y lo recupera del portapapeles. Puede mostrar permiso de pegado en iOS16. Requiere SDK/servicio; añade interacción y no conserva la redirección directa actual. [NativeLink](https://help.branch.io/developer-hub/nativelink-deferred-deep-linking). |
| Adjust LinkMe | Exige Safari, SDK y landing con opción de copiar antes de ir a la tienda. No satisface el recorrido directo sin acciones nuevas. [LinkMe](https://help.adjust.com/en/article/linkme). |
| AppsFlyer OneLink/UDL | Ofrece deferred deep linking, pero devuelve Found/Not found/Failure. Para nuevos usuarios entrega parámetros de deep link, no `campaign`/`media_source` convencionales. Su documentación extendida contempla pérdidas, incluida ventana UDL de15min. Evaluar servicio, privacidad y cobertura; su existencia no prueba matching exacto universal. [UDL](https://dev.appsflyer.com/hc/docs/dl_ios_unified_deep_linking), [extendido](https://dev.appsflyer.com/hc/docs/dl_ios_ocds_ddl). |
| SKAdNetwork web | Admite promoción propia, pero requiere red registrada, firma, receptor y un enlace especial pulsado; un302 no basta. Sólo Safari iOS16.1+, no WKWebView/SFSafariViewController. No cubre universalmente Facebook interno. [API](https://developer.apple.com/documentation/skadnetworkforwebads), [enlace](https://developer.apple.com/documentation/skadnetworkforwebads/creating-an-attributable-ad-link). |
| App/Web AdAttributionKit | App atribuye campañas con señales limitadas por privacidad; Web mide conversiones del sitio. No equivale a entregar el actor DopMi de un comentario orgánico. [Apple](https://developer.apple.com/app-store/ad-attribution/). |
| App Clip | Añade una experiencia previa a la app completa. Debe ofrecer una tarea/demo real, no existir sólo para marketing. No coincide con descarga directa estricta. [Apple HIG](https://developer.apple.com/design/human-interface-guidelines/app-clips). |
| Autenticación web después de instalar | Un puente de sesión/cookie sería condicionado al navegador y continuidad del almacenamiento. ASWebAuthenticationSession muestra consentimiento y autenticación; no es recuperación invisible universal. [Apple](https://developer.apple.com/documentation/authenticationservices/aswebauthenticationsession). |
| Volver a pulsar el enlace | Universal links pueden entregar contexto con la app instalada, pero añaden una acción después de descargar. [Apple](https://developer.apple.com/documentation/xcode/allowing-apps-and-websites-to-link-to-your-content). |

SKAN podría codificar eventos en conversiones agregadas: primer tramo0–2d con
valor fino y tramos3–7/8–35d con valor grueso. La privacidad puede limitar o
suprimir datos; no hay unión con la cuenta. [Ventanas Apple](https://developer.apple.com/documentation/storekit/receiving-postbacks-in-multiple-conversion-windows).
El fingerprinting está prohibido incluso con permiso ATT; no usarlo como puente.
[Privacidad Apple](https://developer.apple.com/app-store/user-privacy-and-data-use/).

## Prueba acotada y decisión

Primero, una CPP aprobada y un cliente que reconozca su destino, sin retirar419
de revisión por esta investigación. Probar en iPhone físico18+ y distribución
App Store: instalación limpia desde Safari y desde Facebook interno por separado,
conservación de CPP durante descarga y Abrir en esa misma página. TestFlight
puede validar parser/onboarding, no demuestra el recorrido CPP de App Store.

Después: login, consentimiento y una ficha privada; comprobar unión exacta de
variante/cuenta/ficha y deduplicación. Los mensajes requieren dos participantes
de prueba legítimos y distinguir saludo, compositor y respuesta. Negativos:
icono, ficha genérica, iOS anterior, variante inválida, dos CPP, reinstalación,
revocación, consentimientoOFF y cambio de cuenta. No inventar eventos ni backfill.

**Avanzar** sólo si el recorrido físico recibe la variante sin pasos previos y
los negativos no crean ni reasignan fuentes. Publicar cobertura medida y límites.
**Detener esa vía** si App Store pierde la CPP o Abrir no entrega el enlace;
conservar agregados Apple y fuente desconocida. En esta investigación no se
crearon CPP, builds, cuentas, SDK, migraciones ni cambios de producto en producción.
