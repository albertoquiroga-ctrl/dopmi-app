# Atribución y restauración de producción

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development o superpowers:executing-plans. Ejecutar y registrar cada bloque antes de distribuir.

**Goal:** Entregar atribución Android consentida y eventos separados sobre el release reciente, recuperando compartir y visor de fotos sin retirar mejoras existentes.

**Architecture:** Base congelada c9d9d03dc34ac99f743c15be8862788136b189be, descendiente del release público 409 (24f0656b). Integrar diferencias funcionales acotadas de atribución416 y restauraciones conocidas; PostgreSQL registra resultados prospectivos y distingue el origen servidor de los mensajes. El reporte agregado no exporta contenido de conversaciones.

**Tech Stack:** Flutter, Kotlin/Play Install Referrer2.2, Supabase/PostgreSQL, React Admin, Codemagic/Google Play.

**Spec:** Decisiones del titular en este chat20nov: producción conservando arreglos y minifeatures recientes; primera ficha, primer mensaje escrito, primera respuesta y saludos separados. `docs/product-decisions.md` conserva Tienda Amazon autorizada16nov y la decisión17nov del sello por perfil confirmado y revisión manual, sin documentos de identidad.

## Global Constraints

- Una cola Flutter; raíz integra interfaces/SQL/configuración. Conservar cambios ajenos y `scripts/__pycache__/`.
- No fusionar la rama395 ni copiar configuración antigua. Conservar Tienda Amazon, navegación centrada, detalles opcionales, identidad de distribución y firma.
- Consentimiento local ausente no revoca el consentimiento global; revocación explícita elimina atribución. Mismo actor al reiniciar conserva identidad Firebase; otro actor o revocación la retira.
- Atribución orgánica existente: cuatro variantes, fuente por actor y ventana336horas. Los anuncios Meta/TikTok requieren contrato y consentimiento independientes; no activar transferencia publicitaria o gasto por inferencia.
- Eventos separados: primera ficha enviada y aprobada, primer saludo automático iniciado, primer mensaje de usuario como adoptante y primera respuesta del dueño. Sólo acciones persistidas después de atribución/consentimiento; históricos de mensajes desconocidos, sin backfill por contenido. La primera respuesta puede contestar un saludo.
- Medir el actor que ejecuta la acción; no atribuir el mensaje de otra persona al dueño de una campaña. El reporte explicita primer evento observable en la ventana, no primero histórico de toda la cuenta.
- Supabase PROD68migraciones al sondeo20nov20:38UTC; falta adquisición. Comparar historia y cuerpos reales antes de aplicar; no replay/repair/reset. Preservar permisos de participantes y estabilidad UUID de mensajes.
- Dinero y gates financieros se conservan; esta entrega no cambia su activación.
- Publicación, disponibilidad de Play, instalación y aceptación son comprobaciones distintas. Código de build debe superar todos los canales; versión semántica reciente.

## Review Focus

1. Instalación nueva o segundo equipo sin preferencia local no purga campaña.
2. Saludo automático, mensaje escrito, respuesta y reintento no se confunden ni duplican.
3. Opt-out concurrente elimina resultados; otro participante no puede falsificar actor/origen o consultar campañas.
4. Restauraciones no retiran Tienda, paso opcional, navegación ni Admin Web Push/primera publicación ya desplegados.
5. Fotos retiradas/cambiadas y preview privado cierran o impiden el visor; compartir conserva URL HTTPS pública aprobada.

## Inventario congelado

| Bloque | Fuente | Integración |
|---|---|---|
| Base reciente | c9d9d03d | Conserva Store, optional-details2ef993ae, fundingff9f5b84 y nav83fad7a1 |
| Compartir y visor | c3c04cca, d0da2aa1 | Siete archivos, conservar storeAmazonAvailable |
| Atribución | d7a960f7, dd7f0c0c, 8a95c2fc, 17a42029, 953d3342 | Native/Dart/SQL/test; no revertir UI/configuración desde395 |
| Continuidad Firebase | 647e38a8/93081ca1 | Componer con triestado953d, sin duplicar sincronización |
| Sello por perfil | a95a44c9, 342c5dd5 | Conservar decisión previa; comprobar baseline Admin y despliegue SQL antes de consumidores |
| Eventos nuevos | Este lote | Origen servidor prospectivo y hitos privados consentidos |

## Task1: Restauraciones móviles

**Files:** content_links.dart, catalog_screens.dart, adoption_detail_layout.dart, adoption_photo_viewer.dart, community_ui.dart y pruebas relacionadas.
**Interfaces:** conservar AdoptionPhoto/RemotePhoto y route links; sólo añadir fit opcional al componente existente.

- [ ] Aplicar los dos parches exactos; inspeccionar ausencia de regresiones Store.
- [ ] Ejecutar pruebas de enlaces y visor, analyze y capturas relevantes en la cola única.
- [ ] Revisión independiente de diff y fotos verticales/horizontales, retirada, Back y preview privado.

## Task2: Atribución y consentimiento integrados

**Files:** core/android_rescuer_acquisition.dart, core/measurement.dart, main.dart, app.dart, Android native bridge, privacidad, discovery/publication y pruebas.
**Interfaces:** `prepareAdoptionConsent(owner,bool)` captura sesión; `analyticsConsentCurrent` y revisiones invalidan tareas pendientes; RPC `dopmi_record_android_rescuer_acquisition(p_variant,p_clicked_at)` permanece compatible.

- [ ] Integrar fuentes funcionales416 selectivamente y continuidad de identidad; conservar textos/pasos actuales.
- [ ] Probar ausencia de preferencia, revocación, cambio de cuenta durante espera y reinicio misma cuenta.
- [ ] Restaurar SQL/reporte original y comprobar aislamiento,14d, primer envío/aprobación y borrado.
- [ ] Cerrar dos hallazgos de revisión: renovar el token del mismo actor antes de fijar Authorization; OFF no queda detrás de un ON atascado. Para este último, estado servidor con revisión y RPC compare-and-set, sin identificador de dispositivo: `dopmi_adoption_measurement_state()` y `dopmi_set_adoption_measurement_v2(consent,expected_revision)`. Cada actualización, incluso legacy, incrementa revisión. Una solicitud basada en una revisión antigua no sobrescribe un OFF ya aplicado. Transporte limitado10s; sólo OFF reintenta conflictos confirmados mientras siga vigente. ON nunca convierte un conflicto en una nueva autorización, incluso desde otro equipo; no repetir un POST de resultado indeterminado.

## Task3: Mensajería medible

**Files:** nueva migración generada por CLI, pruebas SQL/pgTAP y reporte de adquisición.
**Interfaces:** origen servidor de mensaje desconocido/saludo/usuario; hitos privados deduplicados por actor/tipo, sin texto ni ID de interlocutor exportado. RPCs públicos de mensajería conservan firma y autorización.

- [ ] Escribir pruebas de saludo, texto/foto, respuesta dueño, legacy, rechazo, repetición UUID y consentimiento antes de implementar.
- [ ] Implementar origen sólo en rutas servidor; INSERT confirmado registra hitos atómicos dentro de336horas.
- [ ] Verificar opt-out/eliminación y concurrencia en PostgreSQL real; no enviar mensajes a usuarios de producción como fixture.

## Task4: Recuperación de sello

**Files:** delta acotado de a95a44c9/342c5dd5; Admin se compone desde su despliegue real, no desde una carpeta antigua.

- [ ] Congelar baseline Admin actual e incorporar sólo delta revisado; conservar push y panel de primera publicación.
- [ ] Validar SQL/RLS, revisión manual, móvil y Admin; no desplegar consumidores antes de RPC.

## Task5: Verificación y entrega

- [ ] Flutter analyze/test, Admin test/build, tools/verification npm test, Python configuración; DB local y suites de aceptación afectadas cuando disponibles.
- [ ] Revisión independiente de código/seguridad y CI completa por SHA.
- [ ] Cotejo remoto, ensayo y aplicación aditiva única de SQL revisado; postflight.
- [ ] Un candidato reciente con configuración PROD correcta; verificar publicación separadamente.
- [ ] QA instalada en Samsung del candidato: atribución y eventos privados controlados, reinstalación, fotos/compartir, Store/nav/sello. No reciclar fixtures DEV416 consumidos.
- [ ] Actualizar ledger con evidencia exacta y límites; completar distribución autorizada cuando sus gates pasen.
