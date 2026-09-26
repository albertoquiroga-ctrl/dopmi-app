# Datos demo — 26 de septiembre de 2026

Carga solicitada por el titular en Supabase de pruebas `ohqxranynackjignryep`. Disponible para el build interno 2.3.3 (253) sin recompilar. Todos los textos nuevos identifican su carácter ficticio.

## Contenido y uso

- Cinco adopciones públicas: Luna, Milo, Nina, Rocky y Toby, con foto, historia, convivencia, cuidados y ciudades diferentes. Tres perros y dos gatos permiten probar filtros, detalle, guardados y entrada al contacto.
- Perfil sintético `Refugio Demo Dopmi`, ID `de092626-0000-4000-8000-000000000001`. No representa un refugio real ni tiene permisos administrativos o Connect. Su buzón no tiene una persona que responda; no se envían respuestas automáticas.
- Una adopción en revisión y otra con correcciones, privadas y disponibles en moderación. No se asignaron a Irlanda porque falta confirmar su correo de acceso.
- Tres casos ficticios Choco: Recuperación y Alimentación aprobados, Alta cerrado. Pertenecen al rescatista de pruebas ya verificado del caso anterior; reutilizan su foto pública de pruebas. No se cambió su verificación ni sus casos anteriores.
- No se crearon gastos reembolsables, recibos, aportaciones, suscripciones, transferencias ni pagos ficticios. Los recorridos financieros conservan sus datos y reglas de pruebas existentes.

Las fotos de adopción proceden de los assets del mockup `irlanda/apoyar-detalle-perfil@a246fa6f42ec517aae264d7fbd2358d647c4f840`. Se subieron por Storage autenticado con las políticas existentes. Creación/envío de adopciones y decisiones de moderación utilizaron las RPC actuales. No se cambió el esquema, RLS, código de aplicación ni servicios.

## Identificación para mantenimiento

Adopciones del perfil demo:

| Nombre | ID | Estado inicial |
| --- | --- | --- |
| Luna | `8b947c81-f7da-4fc8-8417-62dbf2893322` | published |
| Milo | `2c466745-a862-428d-a5f0-90f6ac5d4c86` | published |
| Nina | `87bda4fb-7b11-4065-ae0f-3e96cc2116aa` | published |
| Rocky | `4c20e307-5cf8-4338-9e95-94684f07b1f4` | published |
| Toby | `7f45127d-5d9f-4272-b1cb-b9d9ca46c4ed` | published |
| Luna en revisión | `d351dd67-fcf3-411e-83c6-102d664996d2` | submitted |
| Nina por corregir | `47377532-021a-4271-8eb5-648b05673b30` | changes_requested |

Casos: `de092626-0000-4000-8000-000000000101`, `de092626-0000-4000-8000-000000000102`, `de092626-0000-4000-8000-000000000103` (cerrado). Para retirar el demo, revisar primero interacciones nuevas y archivar/cerrar exclusivamente estos registros; no borrar el perfil de pruebas ni la foto compartida a ciegas.

## Verificación

- API anónima real: catálogo con cinco adopciones; filtros devuelven tres perros y dos gatos; perfil público accesible.
- Cinco fotos firmadas y descargadas correctamente. Dos fotos de publicaciones no aprobadas rechazan firma anónima.
- RPC pública devuelve los tres casos demo. Base confirma dos aprobados, uno cerrado y cero importes reembolsables nuevos.
- Credencial temporal del perfil sintético rotada a un valor aleatorio descartado; sesiones revocadas y archivos locales de contraseña/sesión retirados. No se entregan credenciales compartidas.
- No acredita aceptación visual o funcional en un dispositivo. Volver a entrar a Adoptar/Apoyar o reiniciar la app permite consultar los datos nuevos.
