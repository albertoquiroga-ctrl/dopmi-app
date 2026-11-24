# Reparación de señales de adquisición — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task.

**Goal:** Recuperar medición consentida de instalación/apertura Meta y revisión de Analytics legado sin cambiar campañas ni convertir actualizaciones en instalaciones.
**Architecture:** Cliente Flutter y canales nativos mínimos llaman AppEventsAPI directamente; gate público booleano failclosed y permiso por dispositivo separados de CAPI de cuenta. Analytics reutiliza recibos existentes/CAS.
**Tech Stack:** Dart/Flutter, Kotlin, Swift/StoreKit/ATT, PostgreSQL/Supabase, HTTP, Codemagic/Play/TestFlight.
**Spec:** ../specs/2026-11-24-acquisition-signal-repair-design.md

## Global Constraints

- Base408fdde5; preservar Tienda y conciliar tutorial corregido antes del candidato.
- CuentaMeta773207924311457/app1156849688851390; Graphv27.0; sin SDK/servidorsecretos en app.
- Sin cambios de campañas/públicos/creativos/gastos/GooglePlayPrimary ni finanzas.
- AAID/IDFA sólo después de permiso propio; iOS ATT.authorized; sin identificador no enviar.
- CAPI Contact/SubmitApplication y sus contratos/preferencias intactos.
- Una cola Flutter local; no repetir publicaciones/QA previa. Recibo de API no es atribución.

## Review Focus

- OFF/revocación/timeout/actor cambiado tras cada await: no envío ni restauración de consentimiento.
- Update/restauración/primera ejecución de instrumentación: no fabricar Install; prueba incierta =>Activate.
- ATT/cámara/resume/reinicio/reintento ambiguo: no duplicar Install ni inflar sesiones.
- Leer legado no escribe ni crea revisión; CAS conflictiva no sobreescribe negativa de otro cliente.
- Configuración sin token/flag/gate/identificador válido: fallo cerrado sin impedir usar DopMi.

### Task1 — Analytics legado (eventos_dopmi)

Files: core/usage_analytics_choice.dart, core/measurement.dart, features/profile/usage_analytics_prompt.dart,
app.dart (sólo invocación del prompt); sus tests choice/gate/prompt/measurement/identitysync.
Interfaces: hasCurrentExplicitChoice; analyticsChoiceInitialValue; analyticsChoiceIsReview.
- [ ] RED: legacyfalse cacheado necesita revisiónOFF; sin fila proponeON sin recoger; reciboOFF no pregunta.
- [ ] RED: abrir revisión no escribe/avanzaCAS; respuesta tardíaA no configuraB; falla/JSONinválido no habilitan.
- [ ] Implementar distinción de recibo vigente, pending sin synclegacy mientras espera, y prompt con modo/valor inicial.
- [ ] GREEN: pruebas dirigidas y analyzer; preservar identidad ante pausa y limpiar sólo en OFF/salida/cambio reales.

### Task2 — Core y canales Lifecycle (prod_meta_impact)

Files: core/meta_lifecycle_measurement.dart y tests; AndroidMainActivity/MetaLifecycleBridge.kt y tests;
iOSAppDelegate.swift/MetaLifecycleBridge.swift si queda registrado correctamente; Info.plist ATT copy.
Interfaces públicos: MetaLifecycleController(preferences,namespace,configured,appId,clientToken,readGate,
native?,transport?,clock?); loading,consent,needsChoice,available; initialize(),setConsent(bool),
foreground(),background(),dispose(). Native devuelve contexto válido+evidencia instalación sin almacenarlo.
- [ ] RED: OFF/configmissing/gateerror/AAID0/ATTdeny =>ceroPOST y cero lecturaID antes de permiso.
- [ ] RED: freshconsent produce Install+Activate; update/inconcluso produce sóloActivate; reinicio noInstall.
- [ ] RED: revokeenawait cancela, resumes<60s no repiten, timeout no reintenta, devnotice noautorizaPROD.
- [ ] Implementar almacenamiento mínimo, transporte propio sinredirects y ACK success:true sin payloadlogs.
- [ ] Implementar contexto Android y prueba iOS conservadora/ATT; conservar InstallReferrer/canalMeta anterior.
- [ ] GREEN: tests de core/native adecuados y revisión de campos/extinfo/credenciales antes de integración.

### Task3 — Configuración (review_restart)

Files: core/config.dart, scripts/write-mobile-config.py y tests, codemagic.yaml y recibo.
Interfaces: AppConfig.metaLifecycleEnabled=false,metaAppId='',metaAppClientToken=''; JSON
META_LIFECYCLE_ENABLED/META_APP_ID/META_APP_CLIENT_TOKEN; --meta-lifecycle; CM
DOPMI_META_LIFECYCLE_ENABLED. Validar AppID existente y ClientToken32hex cuando se habilita.
- [ ] RED: defectoOFF, habilitación explícita válida, tokenCAPI/ausente/IDincorrecto rechazados.
- [ ] Implementar inyección sin publicar token; conservar perfiles, flags, firma e identidad.
- [ ] GREEN: configuración móvil/Firebase y recibo de build sin secretos.

### Task4 — UI/gate/privacidad (root)

Files: main.dart/app.dart (coordinado), nuevo MetaLifecycleConsentGate/diálogo y AccountPrivacy;
aviso móvil, HTMLprivacidad del landing; SQLnuevo RPC dopmi_meta_lifecycle_enabled con tests.
- [ ] RED: Permitir/Continuar sin activar no bloqueanlogin; revisiónOFF respetaestados; privacidadrevocaLifecycle sinCAPI.
- [ ] Añadir proveedor/gate prelogin/control propio y registro de callbacksforeground; integrar Task1 sin perder tutorial.
- [ ] Añadir RPC readonly anon/auth/service que devuelve sólo bool; probar ACL/noPII/defaultOFF.
- [ ] Actualizar aviso versionado sin términos generales; conciliar declaraciones de tiendas.
- [ ] Obtener ClientToken existente por canal privado y guardarlo para build; no generar acceso mayor por rutina.

### Task5 — Integración y despliegue (root + revisión cruzada)

- [ ] Revisar diff/contratos/privacidad y reconciliar tutorial corregido; ejecutar gates apropiados exactos.
- [ ] Aplicar SQL exacto aditivo con pre/postflight conservando historia/catálogos; gateOFF.
- [ ] Cola libre y candidato único firmado, perfilPROD, publicaciones verificadas por separado.
- [ ] Samsung: update/consentOFF/ON/reinicio/revocación sin perder sesión; instalación limpia sólo con alcance autorizado.
- [ ] ACK y panel Meta para Install/Activate estándar; repetir message/submissionPROD si quedan en alcance previo.
- [ ] Publicar el mismo binario probado/declaraciones; conservar campañas hasta cumplir su gate específico.
- [ ] Registrar resultados/limitaciones reales y pendiente físico/AppStore iOS si corresponde; nunca éxito inferido.
