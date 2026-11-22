# Etiquetas por comentario y piloto60 MTY

Corte21/11/2026. El titular autoriza implementar etiquetas, verificarlas y después
iniciar60 contactos. [Plan técnico](superpowers/plans/2026-11-21-campaign-placement-pilot.md)
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
conteos y hashes; RPC sin sesión rechazaHTTP401/42501. Registro61exacto:60deshabilitados
y1QA habilitado, sin atribuciones ni recibos insertados como prueba. Candidato,
QA limpia y cliente público pendientes. **Contactos enviados:0/60.**

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
no publicar los60 enlaces antes de disponibilidad pública del nuevo cliente.
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
2. CuentaQA nueva y consentimiento personal → instalación limpia desde tokenQA
   → primera ficha privada válida. Cotejar fuente/token/brazo y unión exacta de
   receipt.post_id=adoption.id con dueño. No insertar atribución porSQL.
3. Cliente público compatible → habilitar noQA → contactos pertinentes. No invitar
   al canal de pruebas para ocultar falta de disponibilidad.
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
