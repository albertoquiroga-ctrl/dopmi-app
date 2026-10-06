# Fotos: carga, recuperación y caché — 5 de octubre de 2026

## Alcance y referencia

Continuación en `codex/design-foundation`, base `2286a68ffcf2395beac41118ec8188252e9afeb4`.
PR6 continúa abierto en borrador. Referencia visual de Irlanda comprobada mediante
`git ls-remote`: `889c096ade9479b348530db7ba169f023b472ab9` en ambas pasadas.
Los cambios locales anteriores del titular quedan fuera del commit de este feature.
No cambia compresión JPEG85/1600, esquema, RLS, identidad de distribución ni pagos.

## Implementación

`PhotoRuntime` comparte firmas vigentes, transporte, bytes y proveedores decodificados.
Sus claves incluyen entorno, cuenta, bucket, ruta, revisión y política de uso; cada
tamaño físico tiene proveedor propio. Las rutas de subida son UUID nuevos con
`upsert:false`: el cambio de ruta identifica una revisión nueva sin sobrescribir fotos.
`RemotePhoto` conserva geometría y controles, registra fallas, ofrece reintento manual
y recupera fotos visibles fallidas/vencidas al volver. Una foto lista vigente se conserva.

Cada intento tiene diez segundos incluyendo firmado, transporte y primera decodificación.
Hay un solo reintento visible después de un segundo; una precarga no reintenta.
El timeout/cancelación cierra el transporte, retira listeners/entradas pendientes y
rechaza resultados tardíos. Las denegaciones confirmadas y GET404 son terminales.
Un GET vencido renueva firma una vez; la corrupción purga el archivo antes del intento limpio.

`flutter_cache_manager: 3.4.5` está fijado con lockfile. Se utiliza sólo para archivos
locales: ninguna URL firmada/token entra a su índice. El directorio privado de caché
tiene cuota adicional de 50MiB/100 archivos, edad absoluta de siete días y expulsión LRU.
Sólo se escriben bytes completos ya decodificados. El caché de bytes en memoria tiene
límite de 10MiB/40 fotos; las firmas en memoria están acotadas a 256 entradas.

La restauración de identidad validada por servidor y la firma vigente preceden lectura
de disco; los consumidores consultan referencias actuales por repositorios existentes.
Avatares y fotos ordinarias usan disco. El visor de identificación/evidencia usa memoria,
aunque comparta bucket con fotos públicas. Logout/cambio de cuenta purgan el ámbito
anterior; retiro/reemplazo confirmado invalida archivo, píxeles y firma correspondientes.
El sistema operativo puede vaciar caché; disco no concede acceso sin autorización vigente.

La ventana de Adoptar/Apoyar incluye las siguientes dos portadas; las galerías anticipan
una foto. Hay máximo dos trabajos de fondo, promoción del trabajo a visible sin segunda
descarga y cancelación de la ventana al cambiarla u ocultar pantalla. Se retira el firmado
desde `build` del anillo de caso.

## Auditoría acotada

Revisión independiente únicamente del feature; máximo dos pasadas agrupadas realizadas:

1. Ocultar píxeles inmediatamente al cambiar cuenta; recuperar tras restauración tardía;
   liberar slots de firmas canceladas sin esperar diez segundos. Cubierto por widget tests.
2. Limpiar avatar retirado/reemplazado también en cuenta, perfil público y editor propio.
   Cubierto por vaciado de caché y necesidad de una firma nueva.

La recomprobación del auditor no dejó causa material pendiente de esos hallazgos.
No hubo rondas por diferencias de píxeles ni optimizaciones menores de 200ms.

## Evidencia local y límites

Las pruebas nuevas decodifican JPEG reales y cubren timeout21s, ausencia de tercer intento,
firmas tardías, cancelación, truncado/tamaño excesivo, GET vencido, corrupción, permiso
denegado, reintento manual, deduplicación, promoción, cambio de cuenta, retiro, cuota,
edad absoluta, limpieza interrumpida y recreación del servicio con nueva autorización
y cero descargas del cuerpo. Se prueban además galerías, historia y edición de avatares.

Pruebas en copia temporal porque OneDrive bloqueó `build/unit_test_assets` en el workspace.
Flutter3.47.4/Dart3.13.3, sincronización controlada de fuentes antes de cada ejecución.
La batería core/recuperación/transporte/perfil pasó24 pruebas; otra batería afectada pasó43.
Esto no es el gate completo ni aceptación instalada.

Benchmark reproducible: `flutter test tool/photo_benchmark_test.dart`.
Red controlada:30ms de firmado +300ms de cuerpo, pausa idéntica400ms antes de swipe,
foto de fixture real, diez portadas, dos fotos de galería y recreación sobre mismo disco.
Resultados de la primera ejecución:

| Recorrido | Sin precarga | Con precarga |
| --- | ---: | ---: |
| Mediana de portadas posteriores a la primera | 346ms | <1ms |
| Siguiente foto de galería | 346ms | <1ms |
| Mediana al reabrir con nueva firma | 117ms | 116ms |
| Descargas del cuerpo al reabrir (12 fotos) | 0 | 0 |

Son tiempos de un experimento controlado, no tiempos de Supabase real o del Samsung.
No acreditan aún la mejora perceptible instalada. El registro bruto privado está en
`.tools/photo-loop/benchmark.json`; contiene sólo fixtures sintéticos.

## Cierre pendiente

Fijar SHA candidato y ejecutar una sola vez el gate integrado reproducible: Flutter,
administración, configuración y backend/PostgreSQL/identidad/adopción; repetir después
sólo checks afectados por correcciones necesarias. Publicar un único candidato mediante
`android-guardian-internal`, verificar Play por separado y comprobar swipe, galería,
suspensión, reapertura y red en Samsung instalado. Al corte local sólo está conectado
`emulator-5554`; Samsung solicitado al titular. El objetivo permanece activo.

SHA final, CI, publicación y evidencia instalada se registran en `docs/progress.md`
y `docs/backlog.md` sin sobrescribir el trabajo local anterior del titular.

### Gate integrado y corrección posterior

Candidato inicial `a85d180618a1b6db2b8ed36ba41bf7952b005169`, CI37366058216:
web/administración/configuración/PostgreSQL/concurrencia aprobados. Flutter analizó sin
errores;859 pruebas aprobadas y6 fallaron en expectativas anteriores de NetworkImage
y espera del reintento. La comprobación de archivo privado además detectó que Recargar
debía renovar autorización aunque quedaran píxeles en memoria: ahora invalida su
entrada al abrir/recargar, oculta el frame previo y conserva el aviso seguro de error.
La batería afectada posterior aprobó29 pruebas con JPEG realmente decodificado.
La auditoría acotada ya cerró sus dos pasadas; esto corrige el gate, no abre otra ronda.

`milestone-1.yml`, scope `photo`, permite recomprobar sólo móvil mediante workflow_dispatch,
conservando el gate de administración/PostgreSQL anterior. El backend de identidad/adopción aún pendiente se ejecuta aparte. Incluye análisis, pruebas
afectadas, capturas y compilaciones Android/iOS sobre el nuevo SHA.

### Causa nueva encontrada en recorrido instalado

La APK de emulador069640a cargó las adopciones sintéticas y persistió sus bytes,
pero una tarjeta de apoyo intercalada quedó con Cargar foto. Se confirmó en SQL
que las2 portadas de apoyo están en dopmi-rescue-evidence y0 en adopciones.
El consumidor anterior usaba AdoptionPhoto/firma de adopciones para esas rutas.
Se corrigen juntos precarga y presentación usando rescuePhotoSource, conservando
el componente, geometría y controles. Una prueba decodificada impide volver a
firmar una portada de rescate como adopción; batería movimiento/origen27/27.
No se repiten rondas de auditoría ni se atribuye la falla a compresión.

Codemagic6ac403c59f62f266cdb32d1f fue cancelado antes de publicar (API canceled,
Publishing sin ejecutar); no constituye candidato distribuido. El próximo build
se solicita sólo tras comprobar este origen en el emulador. Una única publicación
final sigue siendo el objetivo. CI37367773448 aprobó análisis/pruebas/capturas e
iOS de069640a; no cubre por sí solo esta corrección posterior.

APK aislada actualizada: imagen de apoyo realmente visible donde antes aparecía
Cargar foto; captura privada support-fixed.png. Se mantuvieron las fotos sintéticas
previas al cerrar/reabrir.37/37 comunidad/fotos y27/27 movimiento/origen aprobados;
flutter analyze sin problemas. Falta completar la pasada de diez tarjetas/galería/red
y Samsung con candidato Play, sin atribuirle al emulador aceptación física.

### Entrega interna verificada

Candidato786ed33063be4cfa07e02a13d3d84d79d2a7327d, Codemagic6ac408a773bd44aa241585a3:
análisis,866 pruebas, AAB firmado y publicación aprobados. Build-info descargado
confirma2.3.3(293), Guardian test true. Consulta google-play tracks get posterior
confirma com.mycompany.dopmi/internal completed, versionCode293; publicación comprobada
aparte de compilación. SHA256 informado por Google del AAB:
5d085a21f1151801503da841d641c5441ddabad56f8704b9de09a822b5371691.

Emulador:141 fuentes lib comparadas con786ed33, cero diferencias (normalizando
saltos de línea). Diez tarjetas, galería, reapertura, pérdida de red y recuperación
de Foto3de3 al reanudar verificadas con JPEG decodificado, sin error/spinner final.
Caché instalada conserva14 archivos y expiración absoluta entre procesos.

CI37370051631 aprobó Flutter, capturas, APK e iOS. Backend no obtuvo runner hosted
en el primer intento; rerun sólo ese job, attempt2, sin repetir gates aprobados.
Web/admin/configuración/PG/concurrencia aprobados en37366058216 permanecen aplicables.
Samsung instalado293 y limpieza exacta de fixtures quedan pendientes de aceptación;
no se declara objetivo completo ni medición perceptible Samsung desde emulador.

CI37370051631 attempt2 completó backend identidad/adopción/rescates/comunidad
aprobado, job111971136578. Gate compuesto íntegro aprobado conservando web/PG
original sin cambios. El único pendiente de aceptación es Samsung instalado293
y la limpieza final de fixtures tras su pasada. No hay un problema de código abierto
de los hallazgos revisados ni otra ronda general en curso.

## 2026-10-05 — Fotos: aceptación Samsung y limpieza concluidas

Samsung SM-S938B, Android 16: paquete com.mycompany.dopmi, versión 2.3.3 (293), instalador com.android.vending comprobados por ADB. Corresponde al único candidato publicado 786ed33063be4cfa07e02a13d3d84d79d2a7327d / Codemagic 6ac408a773bd44aa241585a3. Sin nueva compilación, publicación ni cambios de código.

Pasada física: diez swipes consecutivos mostraron portadas decodificadas, incluidas dos tarjetas de apoyo; ninguna captura estable mostró error o carga. Cada captura se obtuvo después de 700 ms de espera más la ejecución ADB: evidencia de fluidez visible, no una medición exacta de tiempo hasta imagen. Galería de tres fotos, suspensión/reanudación conservando la tercera y reapertura del proceso aprobadas. La reapertura sin Wi-Fi ni datos mostró el error recuperable del control de acceso; tras restaurar ambos y usar «Volver a intentar», recuperó sesión y portadas sin aceptar términos ni cerrar sesión. Ambas preferencias quedaron en 1, como antes de la prueba.

Fallo instalado de foto: una referencia sintética controlada todavía sin archivo mostró «Cargar foto» en la tercera posición. Después de subir el JPEG autorizado y volver de segundo plano, la misma tercera foto se decodificó y desapareció el error. El harness usó exclusivamente su publicación sintética y las políticas existentes de subida (borrador); no modificó RLS ni esquema. Evidencia privada: samsung-photo-fault.png, samsung-photo-recovered.png, samsung-swipe-contact-sheet.png y capturas de galería/reapertura en .tools/photo-loop. Estas capturas no se publican porque algunas portadas existentes contienen información de usuarios.

El benchmark antes/después permanece controlado y separado de Samsung: transición mediana 346 ms sin precarga frente a menos de 1 ms con precarga, autorización nueva y cero descargas de cuerpo al recrear servicio con archivos válidos. No se atribuyen esos milisegundos ni un contador HTTP al dispositivo físico. Gate compuesto y auditoría independiente previamente aprobados, dos pasadas de corrección cerradas; no se repiten checks sin cambio material.

Limpieza DEV verificada después de la pasada: 10 publicaciones archivadas mediante RPC del propietario y eliminadas con guardas de inventario; 13 objetos retirados mediante API Storage (12 originales y uno de recuperación); una verificación exclusivamente sintética, dos Auth, dos perfiles y dos consentimientos eliminados. Lectura remota final: Auth, perfiles, publicaciones, rescates, Storage y consentimientos restantes = 0. Preflight comprobó ausencia de conversaciones y registros financieros de esos actores; no se tocaron cuentas, pagos ni casos ajenos. No se borraron datos locales de la app ni se sustituyó la firma Play.

Referencia Irlanda vigente consultada: irlanda/apoyar-detalle-perfil@889c096ade9479b348530db7ba169f023b472ab9. CI final 37370051631 attempt2 (móvil/iOS/backend) y gate sin cambios 37366058216 (web/admin/configuración/PG/concurrencia); 866 pruebas Flutter completas en Codemagic. Play internal 293 completed verificado por separado y ahora también instalación física comprobada. Objetivo del loop concluido.
