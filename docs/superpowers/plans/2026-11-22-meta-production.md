# Integración de eventos Meta en producción

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development or superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Medir el primer mensaje y la primera ficha nueva enviada a revisión desde Android de producción, comprobar ambos en el panel de Meta y activar sus pilotos con los públicos y anuncios de descargas conservados.

**Architecture:** Incorporar la medición opcional de Meta ya probada en DEV mediante contratos aditivos sobre las transiciones confirmadas de producción. Conservar el registro de Play Install Referrer, los tokens de atribución, las señales de Analytics y los contratos anteriores. La cola privada entrega eventos sin contenido de mensajes ni fichas y elimina el identificador publicitario al entregar, revocar o vencer.

**Tech Stack:** Flutter/Dart, Android/Kotlin, PostgreSQL/Supabase, Edge Functions, Meta Conversions API, Codemagic y Google Play.

**Spec:** [Eventos de adopción para Meta](../../meta-app-events.md), [prueba Samsung](../../meta-samsung-qa-20261122.md) y petición expresa del 22/nov/2026 de continuar en producción.

## Restricciones

- Base congelada `3e52c871b01756aeed02bc9728e3693570404a4c`, producto `a24408beeb664d48f15b1bd90e9a8c578602659e` / Android 437. No incorporar pushes posteriores sin inventario propio.
- Una cola Flutter y un candidato por intento justificado. Conservar identidad `com.mycompany.dopmi`, firma y perfil PROD de adopciones/Amazon. Dinero y servicios ajenos conservados.
- Meta requiere preferencia propia, apagada inicialmente. Conservar Analítica de uso y diagnóstico como los dejó cada cuenta. No retroactividad ni AAID inventado.
- Los datos y cuentas ficticios para la prueba están autorizados, incluso en producción. La ficha de QA permanece privada y no se aprueba para publicar.
- Confirmar recepción visible de `Contact` y `SubmitApplication` en el conjunto vinculado antes de activar los pilotos. La aceptación de la API y la atribución a un anuncio son verificaciones distintas.
- Conservar los públicos y anuncios de las campañas originales de descargas. Comparar los borradores con los originales antes de publicar.

## Riesgos que deben cubrir las pruebas

- Consentimiento apagado, incierto o retirado durante la acción: no transmitir contexto sin autorización vigente.
- Cambio de actor/sesión durante la acción: no asociar la señal al propietario anterior.
- Reintento, saludo automático, respuesta del dueño o corrección de ficha: no crear un segundo primer evento.
- Fallo de Meta: no impedir el mensaje ni la revisión; reintentos con lease y borrado por vencimiento independientes.
- Migración aditiva: conservar cuerpos, permisos y resultados de las RPC v3 y las señales confirmadas de Analytics.

## Lote 1 — código y contratos

- [ ] Auditar historia y catálogo real de PROD antes de preparar el SQL. No replay, repair ni db push.
- [ ] Escribir y observar pruebas fallar para el contrato Meta sobre `dopmi_send_message_v3`, su envelope `message/signals`, la ficha nueva y el aislamiento de consentimiento.
- [ ] Añadir wrapper `dopmi_send_message_meta_v2` y wrapper de envío de ficha sin sustituir contratos anteriores. Conservar autorización y token atribuible en la operación canónica.
- [ ] Adaptar Dart, privacidad y pruebas sobre esta base; mantener el fallback limitado a `PGRST202`.
- [ ] Incorporar el canal Android conservando `registerPlayInstallReferrer`, dependencia de AAID y colección automática de AAID en Firebase apagada.
- [ ] Probar el opt-in explícito en el generador móvil y los perfiles de Codemagic; conservar valores financieros y Amazon.

## Lote 2 — revisión, servidor y distribución

- [ ] Ejecutar Flutter analyze/test, verificación Node, SQL local disponible, configuración móvil y revisión independiente del diff. Registrar SHA y CI integrada.
- [ ] Publicar el aviso de privacidad y conciliar las declaraciones de Play para la finalidad Meta antes de abrir la medición a usuarios.
- [ ] Aplicar una migración exacta revisada con preflight/postflight de historia, cuerpos, ACL y datos preservados; gate de Meta cerrado al desplegar.
- [ ] Desplegar worker de PROD y secretos por canales privados. Programar entrega y purga; no exponer credenciales ni modificar cron ajeno.
- [ ] Con cola libre y reserva vigente, compilar una vez el SHA/tag aprobado en `android-guardian-internal`, con Meta explícito y perfil PROD. Verificar el recibo, firma y publicación de Play por separado.

## Lote 3 — Samsung, Meta y campañas

- [ ] Instalar desde Play conservando datos. Usar cuentas controladas y autorización existente para las dos acciones; no generar conversiones de Analytics para poblar sus informes.
- [ ] Con preferencia Meta activa, enviar un primer mensaje manual y una ficha privada válida a revisión desde el Samsung. Registrar build, contexto presente y resultados reales.
- [ ] Verificar entrega aceptada y eliminación de AAID. Comprobar ambos eventos en el panel de Meta y guardar captura del resultado.
- [ ] Verificar disponibilidad pública del cliente que emite las señales antes de iniciar el tráfico de los pilotos. Conciliar solicitudes existentes de Play; no cancelar revisión ajena por rutina.
- [ ] Elegir `Contact` y `SubmitApplication` en sus borradores. Comparar públicos, anuncios, presupuesto y destinos con las campañas de descargas, conservarlos y activar sólo después de completar las verificaciones anteriores.
- [ ] Registrar IDs y estados reales, retirar sólo datos temporales propios y entregar evidencia al titular.

## Cierre y recuperación

Ante un fallo de medición, cerrar el gate Meta y detener sólo su programación. El cierre elimina preferencias y contextos pendientes, una acción irreversible documentada; las marcas de deduplicación se conservan. El fallo de Meta no revierte mensajes o fichas ya guardados. Los contratos viejos y la versión de producción anterior siguen siendo compatibles con el SQL aditivo. No ejecutar una restauración ni cancelar solicitudes de tienda ajenas sin causa concreta.
