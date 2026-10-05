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

### Gate integrado y correcci�n posterior

Candidato inicial `a85d180618a1b6db2b8ed36ba41bf7952b005169`, CI37366058216:
web/administraci�n/configuraci�n/PostgreSQL/concurrencia aprobados. Flutter analiz� sin
errores;859 pruebas aprobadas y6 fallaron en expectativas anteriores de NetworkImage
y espera del reintento. La comprobaci�n de archivo privado adem�s detect� que Recargar
deb�a renovar autorizaci�n aunque quedaran p�xeles en memoria: ahora invalida su
entrada al abrir/recargar, oculta el frame previo y conserva el aviso seguro de error.
La bater�a afectada posterior aprob�29 pruebas con JPEG realmente decodificado.
La auditor�a acotada ya cerr� sus dos pasadas; esto corrige el gate, no abre otra ronda.

`photo-candidate.yml` permite recomprobar s�lo m�vil mediante workflow_dispatch,
conservando el gate de administraci�n/backend anterior. Incluye an�lisis, pruebas
afectadas, capturas y compilaciones Android/iOS sobre el nuevo SHA.
