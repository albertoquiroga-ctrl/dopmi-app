# Tutorial inicial de Adoptar — Implementation Plan

> **For agentic workers:** Use subagent-driven-development for the visual component and a final independent review; root owns integration, persistence and the single Flutter queue.

**Goal:** Enseñar a pasar y guardar mascotas con un tutorial breve, visual e interactivo, una vez por cuenta al entrar a Adoptar.

**Architecture:** Presentar una tarjeta demostrativa con mano/flechas y dos pasos (derecha guarda; izquierda pasa), sin operar el catálogo real. Una marca funcional versionada de Auth user_metadata recuerda cierre/completado entre dispositivos; caché local acotada a entorno/proyecto/cuenta conserva la decisión sin conexión. La lectura/escritura Auth usa el token del actor capturado sin modificar la sesión compartida del SDK.

**Tech Stack:** Flutter/Riverpod, Supabase Auth REST, http y SharedPreferences ya instalados.

**Spec:** Solicitud del titular 24/nov/2026 en este chat; decisiones de negocio y controles existentes en docs/product-decisions.md.

## Global Constraints

- Nuevas cuentas y existentes una sola vez; interpretación recomendada comunicada al titular mientras la pregunta opcional permanece abierta.
- Sólo Adoptar autenticado, tras términos, elección de analítica y explicación/permiso de ubicación. Nunca en Rescatista, recuperación ni enlaces a otras pantallas.
- Derecha guarda en Mis matches, izquierda muestra otra mascota. No simular match mutuo, contacto, like, visto ni evento analítico.
- Español mexicano y marca Dopmi; botones alternativos a gestos, salida visible, sin caducidad automática. Respetar movimiento reducido y texto al 200% en 320 px.
- No privilegios/consentimientos en metadata. No SQL, claves, flags financieros ni servicios nuevos. Mantener com.mycompany.dopmi y la base 442/443.
- Publicación QA continua autorizada; no promover a producción pública. Una cola Flutter y ventana de cinco minutos antes de cada envío Codemagic.

## Review Focus

1. Cambiar de cuenta durante una petición nunca modifica la sesión nueva ni marca su tutorial.
2. Lectura/escritura fallida permite usar Dopmi; cierre local se conserva y sincroniza al próximo acceso elegible.
3. Diálogos de ubicación y tutorial no se apilan; salir de Adoptar cierra una explicación pendiente.
4. La tarjeta real no registra vistos/métricas ni acepta acciones mientras está cubierta.
5. Pantallas pequeñas, texto grande y movimiento reducido conservan todos los controles accesibles.

## Tasks

### 1. Marca funcional y ciclo de vida

Files: crear `apps/mobile/lib/features/adoption/swipe_tutorial_store.dart`; pruebas `apps/mobile/test/swipe_tutorial_store_test.dart`.

Interface: `SwipeTutorialStore.completed(String actor)` y `complete(String actor)`, provider del store. Implementación HTTP con GET/PUT `/auth/v1/user`, clave única `dopmi_swipe_tutorial_v1`; scope local entorno+host+actor. PUT sólo ese campo, respuesta valida mismo actor, sin tocar Auth SDK ni copiar otros metadatos.

- [x] Escribir pruebas de primera lectura, cierre, segunda instalación, aislamiento de actor/entorno, error y respuesta tardía; observar fallo.
- [x] Implementar mínimo y ejecutar las pruebas hasta PASS.

### 2. Tutorial visual independiente

Files: crear `apps/mobile/lib/features/adoption/swipe_tutorial.dart`; pruebas `apps/mobile/test/swipe_tutorial_test.dart`.

Interface: `SwipeTutorial({required VoidCallback onDone})`. Dos pasos practicables por gesto o botón, cerrar/omitir llama una vez a onDone. Tarjeta de ejemplo local, no fotos/datos de usuarios. Animación de mano direccional, feedback corazón/X, al completar `Empezar a descubrir`.

- [x] Escribir pruebas de recorrido, salida, escalado y movimiento reducido; root ejecuta RED.
- [x] Implementar; root ejecuta GREEN y revisa captura local.

### 3. Integración y entrega

Files: crear gate `swipe_tutorial_gate.dart`; integrar en `app.dart` antes de montar Discovery; pruebas `swipe_tutorial_gate_test.dart` y `swipe_tutorial_entry_test.dart`. Limpieza local al eliminar en `account_privacy_screen.dart`. No modificar consentimientos ni permisos de ubicación.

Interface: gate recibe actor, eligible, ready y child. eligible cambia por ruta/actor; ready sólo habilita el inicio tras ubicación. Reemplaza child mientras comprueba/enseña: Discovery real no se monta ni recibe gestos. Futuros antiguos se invalidan; refresco GPS conserva práctica. Excluir catálogos owner y detalles.

Corrección tras CI v1: la consulta empieza antes de ready para no montar/desmontar
el catálogo al resolver GPS. ready sólo retrasa enseñar; _showing conserva la
práctica. El resultado terminado (incluido bypass sin recibo por error) vive en
el shell actual y conserva sus pestañas; otro login/reinicio reconsulta si falló.

- [x] Escribir y ejecutar RED: secuencia ubicación, cambios de ruta/cuenta y ausencia de likes/vistos/eventos durante demo.
- [x] Implementar y verificar pruebas afectadas y flutter analyze; revisión independiente de seguridad/UX/código.
- [ ] Congelar candidato exacto y ejecutar CI completa; registrar evidencia en fuentes existentes.
- [ ] Preparar/publicar Play interno y TestFlight con una cola y ventanas reales; verificar artefactos y publicación por separado. Samsung físico pendiente hasta que el titular lo conecte; no reiterar solicitud.

## Evidence / rulings

- Base limpia `408fdde5` (producto anterior `dbac483b`); conserva correctivo Tienda 442/443 y mock congelado d9f9aa43.
- SDK instalado gotrue 2.27.2: updateUser puede aplicar respuesta vieja a sesión nueva. Se evita esa mutación compartida mediante REST acotado al token capturado; no se actualiza dependencia.
- Changelog Supabase revisado: v3 es opt-in; se conserva SDK instalado. Docs oficiales Auth updateUser permiten metadata funcional. La marca se elimina junto con Auth al eliminar cuenta.
- RED de store: lectura remota true obtuvo false con stub. RED visual/gate: componentes ausentes. RED owner: catálogo de persona mostró SwipeTutorial indebidamente. GREEN final afectado:84 pruebas PASS y44 configuración PASS. Dos P2 de revisión cerrados; nueve capturas verificadas independientemente. Analyze/CI/publicación siguen pendientes al corte.
- CI v1 falló tres regresiones de catálogo (otros tres trabajos SUCCESS), sin envío. Reproducción local70PASS/3FAIL; correctivo de gate revisado sin P1/P2. Suite local completa posterior2169PASS/0FAIL/4SKIP. Se prepara freeze/tag v2; visual sin cambios y nueve capturas aplicables.
