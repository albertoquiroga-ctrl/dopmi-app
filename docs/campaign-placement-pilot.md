# Etiquetas por comentario y piloto60 MTY

Corte22/11/2026. El titular autorizó implementar etiquetas y un piloto de60;
el22nov ordenó arrancar los contactos. [Plan técnico](superpowers/plans/2026-11-21-campaign-placement-pilot.md)
y [protocolo experimental](superpowers/specs/2026-11-21-rescuer-acquisition-experiment-design.md).

## Estado de aceptación

Base reciente af0e2274/425–426 y metadata fda91c1f, integrados con campañas en
f0e6521a. Conserva elección explícita de Analítica, favoritos, visor/carrusel,
compartir HTTPS y Tienda. El iPad426 mantiene elOFF elegido por el titular.

Cliente/servidor implementados; revisión independiente integrada sin hallazgos
materiales.113 pruebas móviles enfocadasPASS, análisis0incidencias, backend
1367PASS/14SKIP,18dirigidas con PostgreSQL realPASS/0SKIP, configuración42PASS y
admin174PASS/buildPASS. Suite móvil1991PASS/4SKIP de etiquetas; después se incorporó el fix de navegación b08f040f y pasaron sus6regresiones. Fuente integrada1544a85236ee96a89eda576bda35fb2a5b9b140c, tag codex/campaign-placement-p60-1544a852; CI44966371479 terminó con cuatroSUCCESS.

Landing2179f1c6c3bc544fd31a078812eeabbbd7475353, Vercel
dpl_CE3DQ25R3fhuhSGJyby2qRd5iFuv READY/production;18HTTP postflightPASS.
Rutas antiguas y legales conservan hashes. SQLPROD aplicado una vez como
20261122004520/android_campaign_placements_pilot60_20261121; postflight22nov00:46:37UTC
31/31PASS, prefijo72 y339funciones previas intactos. Fuentes/eventos conservan
conteos y hashes; RPC sin sesión rechazaHTTP401/42501. Registro inicial61exacto:
60deshabilitados y1QA habilitado, sin atribuciones ni recibos insertados como prueba.

Android2.3.9(429), Codemagic6b02411ebc3b31211424b493:14SUCCESS desde fuente
exacta1544a852. AAB96785875B, SHA256
f2330e84b019d58d9371e1e502da9f04e5dbe853637f97e9a27f118414c7b71f;
1184entradas firmadas/0sin firma/pinupload esperado. Manifest/reporte/versiones,
PROD/Firebase/Amazon y marcadores de campaña/RPC en todos losABI verificados.
El log observado de Publishing confirma429/internal/Statuscompleted/Successfully
published. Es salida humana delCLI; no se encontró objeto de track estructurado.
Esa evidencia corresponde al candidato anterior y no demuestra su aceptación física.

**Cliente público compatible confirmado22nov:** lectura fresca de Google Play
Console muestra Submission166 Published, Production2.3.9(433) y «Start full
rollout». La etiqueta visible21nov22:54 no tiene zona horaria acreditada.
CM6b0264a98a656efc66c206b5 terminó14SUCCESS; fuente
efc3277a7c11f8633235584a4cf2c95c7d471181/tag codex/discovery-zoom-efc3277a,
metadata AAB2.3.9(433)/96783038B y perfilPROD/adopciones/Amazon cotejados.
El envío inicial de ese workflow ainternal es distinto de la promoción posterior
que confirma Console. Comparación1544a852…efc3277a: ahead5/behind0 y merge-base
1544a852; parser, enrollment y hook de adquisición p60 sin cambios. Incluye
también los arreglos recientes de adjuntos y controles con pantalla ampliada.
No se ha inspeccionado criptográficamente el AAB433 ni probado p60 en dispositivo.

**Fase de contacto completada; seguimiento abierto:** las60 colocaciones noQA
se activaron atómicamente enPROD el22nov19:07:54UTC por instrucción del titular.
Último envío22nov21:39:03UTC; ledger final con60 envíos,59 visibles y1 pendiente
de moderación. Balance30personal/30DopMi,15porR1–R4 y32gatos/28perros.
La auditoría de lectura confirma60 claves distintas de autora, post y token,
sin diferencias con manifiesto, bloques, identidades o textos congelados.
El corte anterior01:28:39UTC, con60OFF y cero fuentes/recibos, es histórico.
Cerrar contactos no cierra medición, aprendizaje ni el experimento: esta auditoría
no consultó conversiones y no demuestra cero conversiones.
**QA manual pendiente:** instalación limpia desde tokenQA y primera ficha privada
válida, con fuente/brazo y recibo exactos. No reutilizar fixtures consumidos;
disponibilidad pública, pruebas técnicas y comentarios enviados no cierran esa QA.

## Contrato y operación

Manifiesto tools/campaigns/rescuer-pilot-60-v1.json, SHA256
edcf94d92aa3af4e17e98a73797b20c15ad96df5b9742608342018a50ada7e5a:
60colocaciones balanceadas,15porR1–R4, más unaQA separada. Las60 nacen
deshabilitadas en SQL. No regenerar tokens ni cambiarles significado.

R1/personal-a yR3/pagina-a usan beneficio de difusión;R2/personal-b yR4/pagina-b
facilidad/gratuidad. MismaCTA y enlace. Ruta real
https://www.dopmi.org/descargar/piloto/{token},32hex registrados. Android lleva
cuatroUTM: sourcefacebook, mediumorganic_comment, campaigndopmi_rescatistas_mty_p60_v1
y contenttoken. El servidor deriva experimento/brazo/variante del registro privado.
El token es contexto público, no prueba de instalación o identidad social.

El cliente anterior rechaza este formato y puede consumir su procesamiento:
el gate de disponibilidad pública quedó acreditado con433. No extrapolar esa
compatibilidad a binarios anteriores ni contabilizar fallos como conversiones.
Las cuatro rutas históricas siguen compatibles. iOS conserva descarga directa
conct agregado por brazo/QA, sin atribución individual de este token tras instalar;
origen desconocido no significa cero. La CPP pública es una puerta separada.

Fuente única por cuenta, CAS de revisión servidor,336h desde clic y propietario/
flags conservados. Los recibos privados por mascota retienen el primer envío
original aunque se corrija/retire/guarde/reenvíe; sólo captura prospectiva dentro
de la ventana, sin backfill. OFF/eliminaciones purgan por cascada. Los cinco hitos
siguen separados; mascotas adicionales heredan adquisición, no un nuevo clic.
El objetivo principal sigue contando una cuenta una sola vez.

1. CI delSHA exacto → migración única/postflight → artefactoPROD firmado.
2. QA manual aún pendiente: cuentaQA nueva y consentimiento personal → instalación limpia desde tokenQA
   → primera ficha privada válida. Cotejar fuente/token/brazo y unión exacta de
   receipt.post_id=adoption.id con dueño. No insertar atribución porSQL.
3. Cliente público433 compatible y fase de60 envíos cerrada22nov. Observar el
   pendiente de moderación sin sustituir exposiciones para obtener60 visibles;
   mantener visible la QA pendiente del paso2. No invitar al canal de pruebas
   para ocultar falta de disponibilidad ni declarar QA pasada.
4. Ledger privado por token: autora pseudónima, post/comentario reales, municipio,
   especie, bloque, texto/identidad, visibilidad y tiempo. Una autora/un contacto;
   gatos prioritarios. Ambos perfiles deben poder comentar para estimar identidad.
5. Agregado operador: tools/verification/android-campaign-placements.sql,60filas
   incluidos ceros yQA aparte. Detalle privado y fichas adicionales:
   tools/verification/android-campaign-placement-publications.sql. No exponer
   IDs de fichas/cuentas en RPC pública, comentarios oGit.
6. ExcluirQA de ambos lados, esperar madurez y contar costo/tiempo. No inferir
   autoría, impresiones o significancia del volumen. No se exporta automáticamente
   aMeta/Google.

Recibos y ledger fuera deGit; candidato/progress actualizan los siguientes cortes.
No fabricar60 comentarios ni llamar aceptación a una carga interna.

## Primer corte de medición posterior a los contactos — 22/11/2026

ConsultaPROD de sólo lectura21:40:10UTC:15 colocaciones habilitadas por cada
brazo y0 fuentes Android consentidas retenidas con etiqueta p60,0 primeras
fichas/primeras aprobaciones/recibos y0 hitos de mensajes en los cuatro brazos.
QA se consultó por separado y también está en cero;0 cuentas han madurado336h.
La evidencia agregada quedó en el directorio privado de la operación.
No interpretar esos ceros como0 clics/descargas ni como una prueba de que la
atribución funciona o falla: siguen pendientes la QA manual p60 y la madurez;
iOS agregado, ausencia de consentimiento y atribución desconocida se separan.

Cortes sugeridos del seguimiento:23nov,29nov y6dic, sin prometer ejecución
automática. La ventana de336h del servidor parte del clic, por lo que un corte
de14d desde el comentario no vuelve maduras todas las cohortes de clic tardío.
Conservar todos los envíos, el pendiente de moderación y las desviaciones de
selección. La fase de contacto está cerrada; conversiones y aprendizaje siguen abiertos.

Ledger operativo: `.tools/campaign-placement-pilot/pilot-ledger.private.json`.
Existe respaldo local privado fuera del worktree, en la carpeta
`piloto60-20261122-private` del directorio de evidencias de esta sesión, con
ledger, exclusiones, activación, agregado y comprobantes. Si otro chat no encuentra
el ledger en su checkout, localizar ese respaldo; no suponer que hay0 contactos
ni regenerar etiquetas o repetir autores. Estos archivos no se suben aGit.

Los60 enlaces p60 identifican este piloto de comentarios orgánicos. Para la
comparación futura con Meta/Google pagado, conservar el método de atribución y
crear registro/cohorte y etiquetas de origen propios: reutilizar p60 como si fuera
publicidad pagada contaminaría esta muestra. Mantener los límites de consentimiento,
Android/iOS y QA y confirmar el flujo real antes de atribuir resultados a anuncios.

## Observaciones de muestreo — 22/11/2026

La propuesta inicial del diseño usa publicaciones de hasta7d al seleccionar.
En el piloto se contactaron también dos publicaciones de8d y9d. Conservarlas
en el registro asignado y declarar la desviación; no descartarlas después de
conocer resultados ni presentar todo el inventario como si cumpliera≤7d.
Esto no modifica los textos, identidades, brazos ni bloques congelados.

Gatos son prioritarios, sin una restricción original a esa única especie o a un
solo grupo. El contexto observado incluye rescate y particulares que reubican
a su mascota; no clasificar automáticamente a toda autora como rescatista
independiente. Mantener separado el tipo desconocido cuando falte evidencia.
Algunas publicaciones sólo ofrecen contexto de un grupo local, sin municipio
explícito: geografía desconocida no equivale a MTY confirmado ni se deduce de
una lada. Son límites de selección, no resultados del experimento.

Separar comentarios enviados, visibles y pendientes de moderación. Un envío
pendiente conserva su asignación y no equivale a entrega visible ni conversión.
El cierre de contactos consta arriba; la madurez y resultados siguen abiertos.

## Ajuste prospectivo de especie — 22/11/2026

El titular autoriza buscar aproximadamente mitad gatos y mitad perros y observar
sus diferencias. Conservar las60 colocaciones del manifiesto: dado el avance
previo de gatos, el objetivo operativo pasa a32gatos/28perros, completando lo
restante con perros. Esta meta se acordó antes del cierre; el balance final
32/28 no añadió tokens ni cambió textos, brazos, identidades o bloques.

Comparar tasas por especie del post contactado usando sus propios denominadores
reales de asignados, enviados y visibles, y primeras fichas atribuidas maduras.
No comparar sólo conteos brutos ni tratar la especie como asignada al azar:
el cambio durante el reclutamiento puede coincidir con grupos y horarios distintos.
Estas tasas describen la respuesta al outreach del piloto, no una tendencia
natural de especies dentro de la app. El orgánico nativo requiere un apartado
observacional separado; una fuente sin atribución no demuestra origen orgánico.

## Enmienda prospectiva de antigüedad — 22/11/2026

Antes de seleccionar la colocación55, se amplía la búsqueda restante a avisos
activos de adopción de hasta14d, ante el inventario reciente deduplicado limitado.
La ampliación fue comunicada al titular sin consultar conversiones. Afecta sólo
las seis colocaciones restantes y no elimina las desviaciones previas frente a
la propuesta de7d. Los avisos restantes serán de perros para mantener la meta
de composición32gatos/28perros; textos, identidades, brazos y bloques siguen fijos.

Conservar todas las exposiciones y su antigüedad observada, sin sustituir casos
ya contactados. El análisis por asignación (ITT) incluye los contactos originales
y distingue visibilidad/moderación; añadir sensibilidad limitada a≤7d y desglose
por antigüedad. Ningún corte por edad se elegirá según sus conversiones. La
ampliación modifica la población reclutada y debe acompañar cualquier comparación
por especie o brazo. En ese momento los envíos seguían abiertos; el cierre de
contactos posterior no equivale a cerrar datos de conversión o madurez.

## Límites observados al cerrar contactos — 22/11/2026

Los60 envíos no acreditan60 rescatistas independientes verificadas. El inventario
incluye propietarias que reubican, rescate, difusión/eventos y reportes; conservar
esas clases y la desconocida. El último tramo incluye avisos del10,12 y15nov,
una republicación del18nov cuyo original es del14nov, crías anunciadas el20nov
con un mes y un reporte del22nov de una perra observada. El reporte procede de
su reportante original, sin resguardo propio; no equivale a una ficha de
adopción bajo su custodia. La edad anunciada de las crías no acredita que estén
listas para separarse. Ninguno de esos contextos prueba conversión o calidad.

Mantener los registros originales y ambos tiempos de republicación/original,
sin escoger después la fecha favorable a elegibilidad. Analizar por asignación
(ITT) y declarar sensibilidad≤7d/antigüedad y límites de geografía/tipo de post.
El comentario que pasó de moderación a visible se verificó en la revisión final;
el restante sigue pendiente. No presentar60 envíos como60 publicaciones visibles,
éxito de atribución p60, significancia ni tendencia natural de la app.
