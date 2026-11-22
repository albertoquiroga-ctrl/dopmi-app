## Estado operativo — 22/nov/2026 CDMX

PROD ya incorpora b471bdaf; SQL20261122232424/worker1 y parVault dedicados
verificados. PurgaON/15min, entregaOFF/2min y gateMetaOFF. Android2.3.11(439)
disponible interna, artefacto/firma/perfil comprobados. Aviso público publicado;
DataSafetyMeta en revisión. Esperando SamsungUSB y aceptación adicional del panel
para revisar eventos. No hay QA física439 ni eventos PROD ni pilotos activados.
El panel muestra Contact1/SubmitApplication1 de la prueba previa435/DEV.
La asociación app/cuenta es correcta; el selector aún pide configurar eventos.
No cambiar SDK/nombres/payload sólo por ese aviso. Las acciones y pendientes
precisos están en [candidato vigente](candidate-release-current.md).

# Eventos de adopción para Meta Ads

El piloto es Android. Las dos copias de las campañas de descargas conservan un conjunto «Android Interactuaron en FB e IG» cada una y los ocho anuncios originales. En las copias quedó seleccionado «Maximizar el número de eventos de la aplicación». Meta exige un evento estándar del origen de la app antes de permitir elegirlo. [Borradores de Android](https://adsmanager.facebook.com/adsmanager/manage/adsets/edit/standalone?act=773207924311457&business_id=733426408896859&selected_campaign_ids=120250491805980619%2C120250491805960619&selected_adset_ids=120250491806060619%2C120250491806010619)

| Evento de Meta | Acción confirmada por Dopmi |
| --- | --- |
| `Contact` | Primer envío elegible desde el compositor por el adoptante después de activar la preferencia. Puede ser texto o foto. La apertura del chat, el saludo automático, la respuesta del dueño y el reintento de un envío ya guardado quedan fuera. |
| `SubmitApplication` | Primera ficha nueva y válida que el rescatista envía a revisión con la preferencia activa. Los cambios de una ficha previa siguen su recorrido habitual. La primera ficha aprobada sigue siendo el resultado de calidad en el reporte interno. |

Cada cuenta puede generar una señal de cada tipo. La app obtiene el identificador de publicidad de Android cuando el servidor confirma que la acción es elegible, con la preferencia activa y sólo si Android lo permite. La función envía a Meta el identificador, un ID aleatorio de evento, el nombre y la hora del evento, el identificador de la app y las versiones de la app y de Android. La cola borra el identificador al confirmar el envío, vencer la ventana de 24 horas o retirar el permiso. Una solicitud ya despachada puede llegar a Meta después de apagar el interruptor. Se conserva una marca interna para evitar repetir la señal. El contenido de los mensajes y fichas permanece en Dopmi. [Campos de App Events](https://developers.facebook.com/documentation/ads-commerce/conversions-api/app-events)

## Texto propuesto para el aviso de privacidad

> Medición opcional de anuncios en Android. Puedes permitir que Dopmi comparta con Meta el identificador de publicidad de Android, las versiones de Dopmi y Android, y el tipo y la hora de tu primer mensaje elegible de adopción o de tu primera ficha elegible enviada a revisión. Meta usa esos datos para atribuir resultados y optimizar la entrega de anuncios de Dopmi. Esta preferencia está apagada inicialmente y se puede retirar en Cuenta y privacidad. La preferencia es independiente de Analítica de uso y puedes seguir utilizando Dopmi aunque la dejes apagada.

El [aviso vigente](https://www.dopmi.org/privacy-policy) ya incorpora la adenda Meta del 22/nov/2026, independiente del consentimiento general del 1/nov. La declaración de Play añade finalidad publicitaria y transferencia opcional de ID e interacciones; su revisión sigue pendiente antes de abrir el piloto a usuarios. La preferencia se habilita en Android y se puede retirar desde cualquier cliente actualizado. La incorporación de iOS a la medición requiere su propia verificación de atribución y de App Tracking Transparency. [Seguridad de los datos de Play](https://support.google.com/googleplay/android-developer/answer/10787469) · [Identificador de publicidad de Android](https://support.google.com/googleplay/android-developer/answer/6048248) · [Privacidad de Apple](https://developer.apple.com/app-store/user-privacy-and-data-use/)

## Configuración y prueba

1. El conjunto DopMi (`1839761860506617`) quedó vinculado a la app (`1156849688851390`) el 17 de noviembre de 2026, con autorización del titular para aceptar las condiciones empresariales de Meta. Configurar `DOPMI_META_ADS_DATASET_ID`, `DOPMI_META_ADS_ACCESS_TOKEN` y `DOPMI_META_ADS_WORKER_SECRET` en la función. Para automatizar la entrega, guardar el secreto de invocación en Vault como `dopmi_meta_ads_worker_secret` y la URL raíz del proyecto como `dopmi_meta_ads_project_url`. La prueba inicial435 se hizo en DEV; la siguiente usa439 y PROD, conservando la sesión del teléfono y los controles independientes de Meta/GA. Un lote de prueba en el conjunto vinculado puede formar parte de sus estadísticas, incluso con un código de prueba. [Conjunto DopMi](https://eventsmanager.facebook.com/events_manager2/list/dataset/1839761860506617/settings?business_id=733426408896859&act=773207924311457) · [Pruebas de Conversions API](https://developers.facebook.com/documentation/ads-commerce/conversions-api/using-the-api#testEvents)
2. Preparar el candidato Android con `DOPMI_ANDROID_META_ADS_MEASUREMENT=true` en Codemagic o con `scripts/write-mobile-config.py --meta-ads-measurement` y las opciones del perfil que corresponda en local. La configuración habitual de compilación permite únicamente retirar un permiso previo. Aplicar la migración y desplegar `meta-ads-worker` con la medición cerrada. En QA, probar que el saludo automático, una ficha incompleta, las operaciones repetidas y el permiso apagado quedan fuera. Con permiso activo, comprobar recepción de ambos eventos. Verificar por separado que el evento queda disponible en el conjunto de anuncios y que Meta atribuye una conversión real.
3. Habilitar `DOPMI_META_ADS_ENABLED=true` en el worker, habilitar la medición en la base con `public.dopmi_set_meta_ads_gate(true)` bajo rol de servicio y usar la programación de abajo. Para cerrar la medición, ejecutar `public.dopmi_set_meta_ads_gate(false)` y apagar el worker. El cierre cancela la cola y elimina el contexto por enviar.
4. Elegir `Contact` en el primer piloto Android. Comparar contra las campañas de descarga con el mismo público y anuncios en una ventana de atribución comparable. Medir gasto dividido entre usuarios atribuidos con primer mensaje. Usar `SubmitApplication` en su propio piloto y reportar además costo por primera ficha publicada. En los borradores se heredaron $30 MXN diarios por campaña. El arranque del piloto requiere definir si sustituye gasto existente o agrega presupuesto.

La purga se ejecuta por separado de la entrega, incluso si la función está fuera de servicio. La programación requiere las extensiones `pg_cron`, `pg_net` y Vault en el proyecto. [Funciones programadas de Supabase](https://supabase.com/docs/guides/functions/schedule-functions)

```sql
select cron.schedule('dopmi-meta-ads-purge', '*/15 * * * *',
  'select public.dopmi_purge_expired_meta_ads_events()');

select cron.schedule('dopmi-meta-ads-worker', '*/2 * * * *', $job$
  select net.http_post(
    url := project.decrypted_secret || '/functions/v1/meta-ads-worker',
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'Authorization', 'Bearer ' || credential.decrypted_secret
    ),
    body := '{}'::jsonb,
    timeout_milliseconds := 90000
  )
  from vault.decrypted_secrets project
  cross join vault.decrypted_secrets credential
  where project.name = 'dopmi_meta_ads_project_url'
    and credential.name = 'dopmi_meta_ads_worker_secret'
    and exists (select 1 from private.dopmi_meta_ads_gate where enabled);
$job$);
```
