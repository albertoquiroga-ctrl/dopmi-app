# H9 — aceptación integrada

Autorizado el 27/9/2026. Base: codex/design-foundation, c40eb73; candidato previo ea5350e, Android 2.3.3 (256). Referencia visual a246fa6. El titular admite las pantallas actuales para continuar y aplaza la fidelidad visual; no equivale a aceptación de Irlanda. Revisión funcional final agrupada en Internal Testing.

## Matriz de ejecución

| ID | Actores y recorrido | Resultado exigido | Evidencia / estado |
|---|---|---|---|
| H9.0 | Base, accesos, cobertura y fixtures | Entorno y pruebas reproducibles | GitHub PR6 abierto, refs comprobadas; Supabase MCP y Codemagic API accesibles; Docker local activo |
| H9.1 | Autor, adoptante y tercero: publicar/moderar/guardar/contactar/retirar | Favoritos privados, conversación idempotente, retirado no visible | Suite adoption_backend existente; ampliación de comunidad pendiente |
| H9.2 | Rescatista, tercero y moderador: verificar/corregir/caso/gasto/avance/perfil/adopción vinculada | Sólo snapshots aprobados públicos, archivos privados y revisión de versión | Suite rescue_backend existente; integración de H8 pendiente |
| H9.3 | Donante, rescatista, servidor: Checkout/retorno/historial/Guardián | Resultado persistido, importes conciliados, reintento sin duplicación | Reutilizar H5 y regresiones; candidato instalado pendiente |
| H9.4 | Reportante y administrador: recepción/revisión/resolución | Bandejas accesibles, evidencia visible, permisos y errores recuperables | Detectadas fotos de avances no visibles y ausencia de paginación; corrección en curso |
| H9.5 | Titular en Play interno | Revisión agrupada de 8 recorridos, cero defectos críticos/altos | Pendiente de candidato final y titular |

## Verificación y límites

Cada bloque: comprobar, corregir, probar y registrar. Pruebas de fallos/concurrencia en base local desechable; remoto sólo test acotado, sin borrar demo ni evidencia financiera. Nuevas integraciones usan Auth/REST/Storage reales y cuentas desechables; nunca presentar esas pruebas como hardware.

Ejecutar Flutter analyze/tests, admin test/build, verificación Node, pgTAP, integración test_backend, configuración móvil y CI completo del SHA candidato. Publicar por android-guardian-internal y comprobar Publishing separadamente. H9 no cierra hasta aceptación del titular; visual aplazado, H10/H11 y excepción de disputa H5 conservan sus límites.

## Revisión agrupada del titular

Registrar versión/build instalado, dispositivo, resultado y defecto por recorrido:
1. Descubrir, guardar y contactar una adopción.
2. Recibir/responder desde la cuenta responsable.
3. Cambiar de modo y recuperar borrador.
4. Enviar/corregir publicación y verla tras moderación.
5. Consultar caso, avance y perfil público.
6. Aportar en test, revisar historial y administrar/cancelar Guardián.
7. Reportar contenido y verificar recepción administrativa.
8. Reiniciar y cambiar de cuenta sin exposición ni pérdida.

No guardar contraseñas, tokens ni datos privados en la evidencia versionada.

## Operación y diagnóstico

- Publicación bloqueada: consultar UUID, estado, versión y feedback en Adopciones o Rescates. Corregir como propietario y reenviar; el moderador decide la versión recibida. Un conflicto exige recargar, no forzar la aprobación.
- Avance/perfil: abrir Moderación, revisar texto e imágenes cargadas y decidir. Si una imagen falla, reintentar; publicar permanece bloqueado. Escribir indicaciones concretas para corrección/rechazo.
- Reporte: localizar UUID/tipo de contenido, contrastar su expediente en la sección correspondiente, efectuar la acción autorizada y registrar lo realizado en Resolución. Resolver el reporte no retira automáticamente contenido. Consultar resueltos/descartados para seguimiento.
- Archivo fallido: conservar borrador, reintentar selección/carga y comprobar estado del servidor. No hacer público un bucket ni retirar RLS para resolverlo.
- Pago incierto: consultar historial y referencias existentes, distinguir cobro/asignación/transferencia/devolución; seguir guardian-acceptance.md. No recrear el intento ni borrar evidencia. Los pagos en revisión requieren diagnóstico de servidor y proveedor test.
- Cuenta o permiso: cambiar de modo no verifica ni concede administración. Mensajes sólo para participantes. La publicación y el expediente privado se investigan por superficies separadas.

## Defectos encontrados y corregidos

- H9-D1: fotos de avances ausentes al moderar; ahora visibles y aprobación bloqueada hasta carga correcta.
- H9-D2: colas limitadas a primera página; paginación, recarga y retorno cuando se vacía la última página.
- H9-D3: RPC administrativa de perfiles enviaba profile_id inexistente; usa profile_owner/owner_id y versión real.
- H9-D4: aprobar tras pedir correcciones fallaba por notificación duplicada; UPSERT conserva aviso actual e historial de decisiones.
- H9-D5: fotos/avatares previamente aprobados admitían nuevas firmas aun sin visibilidad vigente; permisos ahora vinculados a caso/verificación. Actividad pública filtra también casos retirados.

Cuentas de integración: owner, adopter/outsider y moderator desechables en cada suite local, con verificación pendiente y aprobada dentro del recorrido. No se conservan contraseñas en Git. La preparación de cuentas remotas para revisión instalada se registra por separado.
