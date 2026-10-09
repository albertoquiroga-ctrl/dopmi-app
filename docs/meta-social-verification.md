# Vinculación social — encargo del 9/10/2026

Estado: investigación y preparación de consola; no implementado ni publicado.
Este encargo nuevo no modifica la referencia congelada dde1bb9 ni acredita
el pendiente SMS de Play308. No requiere repetir su QA válida.

## Decisión del titular

Facebook e Instagram se conectan desde una cuenta Dopmi ya autenticada para
demostrar control de la cuenta social. No son métodos nuevos para acceder a
Dopmi ni sustituyen su revisión de identidad/documentos o aprobación de perfil.
Instagram personal mantiene enlace y revisión manual; OAuth se ofrece para
cuentas profesionales (Empresa/Creador). Decisión respondida expresamente.

## Consola comprobada

- App existente DopMi:1156849688851390, publicada, Facebook Login disponible.
  public_profile/email muestran «Ya se puede publicar»; user_link no añadido.
  Esto no prueba el nuevo flujo ni aprobación de permisos adicionales.
- Redirección existente de Facebook a Firebase:
  https://dopmi-e3b6a.firebaseapp.com/__/auth/handler. Conservarla y conservar
  la integración anterior; no reenviar OAuth a ella para verificar en Supabase.
- «Añadir casos de uso» de esa app sólo ofrece anuncios; Instagram no aparece.
  La propia consola indica crear otra app para casos incompatibles.
- Nueva alta preparada, NO creada: «Dopmi Verificación Social», porfolio DopMi
  con verificación de empresa completada, caso «Administrar mensajes y contenido
  en Instagram». Es el nombre general del producto: no autoriza solicitar lectura
  de mensajes, publicaciones, comentarios, anuncios ni administración de contenido.
- Resumen final exige aceptar Condiciones de plataforma/Políticas de Meta.
  Crear está pendiente de confirmación expresa del titular. No se concedieron
  permisos nuevos ni se cambiaron callbacks, roles, secretos o la app anterior.

## Implementación prevista y requisitos de seguridad

1. Botones Conectar Facebook/Conectar Instagram profesional dentro del perfil.
   Instagram personal conserva edición de enlace con etiqueta de revisión manual.
2. OAuth dedicado a vinculación; no usar signInWithOAuth/linkIdentity para crear
   una nueva vía de inicio de sesión en Dopmi. UUID y sesión Dopmi se conservan.
3. Inicio autenticado en servidor, state aleatorio de un uso con caducidad y
   vinculado al actor/proveedor/intento; callback HTTPS exacto. Cancelación y
   cambio de sesión no vinculan nada. Consumo atómico evita replay y carreras.
4. Servidor intercambia código y comprueba identidad/proveedor/aplicación.
   El cliente no puede escribir una bandera «verificado». Secretos/tokens fuera
   de app, URLs de retorno, logs y Git. Minimizar datos y retención de tokens.
5. Guardar evidencia privada de proveedor/ID/fecha; impedir apropiación de una
   cuenta ya vinculada a otro actor. No inferir propiedad de un enlace escrito
   manualmente a partir de una autenticación que no devolvió ese enlace.
6. La publicación del perfil sigue snapshot y moderación existentes. Revocación,
   desconexión y eliminación de cuenta retiran la evidencia correspondiente.
7. Permiso mínimo: perfil básico. Evaluar user_link sólo si Meta lo aprueba y
   es necesario para certificar la URL de Facebook; no pedir email por defecto.
   Instagram: comprobar instagram_business_basic en el producto nuevo antes
   de configurar el flujo. Publicación/revisión de Meta separadas de QA propia.

## Siguiente acción

Confirmar el alta preparada que acepta condiciones de Meta; después revisar
permisos reales del producto, preparar backend y callback de DEV y configurar
su URI exacta. No activar credenciales ni callbacks sin endpoint comprobado.
Verificar únicamente el nuevo flujo (éxito/cancelación/denegación, state caducado
o repetido, cambio de sesión y conflicto de propiedad), después gate obligatorio
y candidato instalado. No afirmar que configuración de consola implementa UI.

Fuentes: consola Meta autenticada del titular y colección oficial de Meta
[Instagram API](https://www.postman.com/meta/instagram/collection/6yqw8pt/instagram-api).
La documentación directa de developers.facebook.com respondió429 durante esta
consulta. Limitación profesional corroborada por la colección; permisos exactos
y revisión siguen pendientes de inspección del producto nuevo.
