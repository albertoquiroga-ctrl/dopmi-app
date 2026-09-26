# Dopmi — continuidad de ChatGPT Work a Codex

## Estado vigente — consolidación H6, 25 de septiembre de 2026 (México)

Esta sección supersede las prioridades históricas siguientes. H5 está aceptado en test según `hito5-delivery.md`, con excepción de disputa explícita. El titular autorizó ejecutar `release-roadmap.md` (H6–H12). Trabajar desde `codex/mvp-consolidation` hasta integrar su PR en `codex/Dopmi`; verificar refs/CI antes de elegir base. No reiniciar H5.

Referencia viva: `irlanda/apoyar-detalle-perfil`, SHA inicial `a246fa6f42ec517aae264d7fbd2358d647c4f840`. Ver `design-reference.json` y `design-parity.md`. Seguir nuevos commits al inicio/cierre de cada ciclo. Videos, Meta, push y analítica avanzada son post-MVP; tienda/fondo/bonos/cashback quedan fuera.

Codemagic API verificada mediante variable local de usuario `CM_API_TOKEN` (nunca imprimir su valor). Android 2.3.3 (252), `0140fbd`, publicado desde `android-guardian-internal`; iOS 2.3.3 (241), `d74fe97`, es anterior. H11 exige el mismo candidato en Play interno y TestFlight.

Siguiente: cerrar integración/CI de H6, después H7 con inventario, respaldo restaurado y retiro gradual. No borrar legado ni modificar historial de migraciones a ciegas. Dinero real requiere autorización separada.

## Registro histórico de traspaso


Actualización final del 25/9/2026: H5 aceptado en modo prueba con excepción explícita autorizada para la disputa posterior a transferencia. Consultar [entrega H5](hito5-delivery.md) y backlog vigente antes de los cortes históricos inferiores. No reiniciar pruebas aceptadas ni activar dinero real.

Corte: **25 de septiembre de 2026, UTC**. Permite retomar el trabajo sin acceso al chat anterior. El titular pidió dejar la documentación en GitHub; continuará compilando en **Codemagic** y probando desde **TestFlight**.

## 1. Repositorio y rama de continuación

Implementación: [`albertoquiroga-ctrl/dopmi-app`](https://github.com/albertoquiroga-ctrl/dopmi-app).

| Referencia al revisar | SHA del código antes del traspaso documental | Uso |
| --- | --- | --- |
| `codex/stripe-transfer-delivery` | `8e6663d03ff2479ab6a75cc4776533dfc19e1bc4` | **Continuar aquí**: incluye la preparación TestFlight de Guardián. |
| `codex/Dopmi` (predeterminada) | `21628a6ace26978e21e01e454154bd142c36391b` | PR #2 integrado; falta la preparación posterior. |
| `codex/mvp-release-foundation` | `12b4078d63f6f2be5f985bb7e2ec029c921591ac` | Trabajo histórico de distribución. |

Los PR [#1](https://github.com/albertoquiroga-ctrl/dopmi-app/pull/1) y [#2](https://github.com/albertoquiroga-ctrl/dopmi-app/pull/2) estaban integrados y cerrados. No había issues ni PR abiertos en la consulta de entrega. La comparación de ramas mostró un merge exclusivo de la predeterminada y **seis commits posteriores** en la rama de continuación: `e9716ef`, `7f206d8`, `3aa7c22`, `9478076`, `1c2b976`, `8e6663d`. Contienen verificación de acceso, preparación del servidor, APK separado y TestFlight.

Este traspaso modifica documentación, no integra código entre ramas. Los SHA anteriores fijan la evidencia de implementación; los commits documentales posteriores no son builds nuevos.

Al comenzar, preservando cambios locales:

```sh
git status --short
git fetch origin
git branch -avv
git log --oneline --left-right origin/codex/Dopmi...origin/codex/stripe-transfer-delivery
```

En un checkout limpio, seleccionar `codex/stripe-transfer-delivery` y actualizar con fast-forward; si no existe localmente, crearla siguiendo `origin/codex/stripe-transfer-delivery`. También se puede crear una rama de trabajo desde esa referencia. Si el remoto avanzó, contrastar el código y CI nuevos. No hacer force-push ni volver a implementar los seis commits desde una base antigua.

Referencia funcional fijada: [`dopmi-functional-mockup@961b557`](https://github.com/albertoquiroga-ctrl/dopmi-functional-mockup/tree/961b557cfb4163aceaf6283fd077ab2e659037ba). `dopmi-landing-mockup` es un repositorio separado de referencia de landing. Dentro de `dopmi-app`, `src/` y `public/` conservan el prototipo; la implementación real está en `apps/` y `supabase/`.

## 2. Estado de los hitos

| Hito | Estado | Límite |
| --- | --- | --- |
| H1 | Identidad, perfiles, recuperación, sesión y administración completos en desarrollo. | Google/Apple aún requieren configuración/verificación; aceptación de plataforma en beta. |
| H2 | Adopción moderada, catálogo, favoritos, perfiles públicos, mensajes y notificaciones internas completos. | Paridad final y recorridos en dispositivos del lanzamiento. |
| H3 | Verificación de rescatistas, casos, gastos pagados, evidencia privada y moderación completos en desarrollo. | Aceptación global de beta/paridad. |
| H4 | Aportaciones únicas, Connect, devolución total y reversión completos **en test**. | No demuestra dinero real ni depósito bancario. |
| H5 | Reserva/liquidación, alta, calendario, cobro condicionado, recuperación, cambios/cancelación, tarjeta, historial y reversiones implementados. | **Abierto**: permisos de la clave del servidor, aceptación integrada Stripe/app/dispositivo y revisión independiente. |
| H6 / lanzamiento | Infraestructura de compilación y contrato existentes. | Beta, contenido definitivo, paridad completa, tiendas y operación pendientes. |

H1–H6 son hitos de desarrollo; R0–R6 en [el contrato público](mvp-release-contract.md) son etapas de lanzamiento. H4 cerrado en test no cierra R4 de dinero real. El alcance sigue incluyendo todas las funcionalidades acordadas del prototipo; no reducirlo a lo ya construido.

## 3. Decisiones que deben conservarse

- Español de México, marca Dopmi y contraste accesible. Las [decisiones vigentes](product-decisions.md) prevalecen sobre simulaciones del prototipo.
- Solo gastos ya pagados, documentados y aprobados de rescatistas habilitados reciben aportaciones. No exceder su monto aprobado.
- Comisión Dopmi **2 % del bruto**; los costos reales de Stripe también se descuentan. Las estimaciones no sustituyen importes conciliados.
- Guardián: **$50/$200/$500 MXN o personalizado**; primer cobro al activar, siguientes en el aniversario mensual. Consentimiento explícito de monto, frecuencia y cancelación.
- Reservar capacidad antes de Checkout/cobro. Ordenar por urgencia aprobada y aprobación más antigua, con desempate estable. Solo cobrar si se puede asignar **todo el neto**.
- Sin capacidad inicial: no Checkout ni suscripción cobrable. Sin capacidad mensual: omitir sin deuda ni recobro posterior. Si un cobro confirmado deja de ser asignable: devolución total conciliada.
- Sin Guardadito, reserva comunitaria, bono de verificación ni cashback. La reserva técnica transitoria de capacidad no es un fondo comunitario.
- Cambiar monto aplica al siguiente ciclo; cancelar detiene ciclos futuros y conserva historial. Cambiar tarjeta no cobra meses omitidos.
- Distinguir pago, asignación, transferencia Connect y depósito bancario. Devolución y reversión de transferencia son operaciones distintas.
- Stripe solo test: conservar controles de `livemode=false`, claves de prueba y Stripe Tax apagado. La aceptación test no autoriza producción.

## 4. Mapa de implementación

| Área | Rutas |
| --- | --- |
| Flutter / navegación | `apps/mobile/lib/app.dart`, `apps/mobile/lib/core/config.dart`, `apps/mobile/lib/features/` |
| Guardián móvil | `apps/mobile/lib/features/payments/guardian_repository.dart`, `guardian_screen.dart`, `guardian_history_screen.dart` |
| Panel | `apps/admin/src/`, especialmente `Rescues.tsx`, `Contributions.tsx`, `api.ts` |
| Endpoints | `supabase/functions/guardian-client/`, `payments/`, `stripe-webhook/`, `payment-worker/`, `payment-return/` |
| Orquestación | En `supabase/functions/_shared/`: `guardian-runtime.ts`, `guardian-activation.mjs`, `guardian-schedule.mjs`, `guardian-collection.mjs` |
| Ciclo de vida | En el mismo directorio: `guardian-recovery.mjs`, `guardian-changes.mjs`, `guardian-method.mjs`, `guardian-refunds.mjs` |
| Evidencia/liquidación | En el mismo directorio: `guardian-billing.mjs`, `guardian-reconciliation.mjs`, `guardian-service.mjs`, `guardian-allocation.mjs` |
| PostgreSQL | `supabase/migrations/`, `supabase/tests/` |
| Pruebas financieras | `tools/verification/guardian.test.mjs`, `payments.test.mjs`, `guardian-concurrency.mjs`, `guardian-preflight.test.mjs` |
| Build | `codemagic.yaml`, `scripts/write-mobile-config.py`, `scripts/test_mobile_config.py` |

Billing usa `send_invoice` y `pause_collection.behavior=keep_as_draft`, sin reanudación programada. Se paga una factura individual tras comprobar/reservar capacidad; no cambiar a cobro automático general ni pausar después del cobro. Conservar concesiones, bloqueos compartidos e idempotencia. Ante incertidumbre, conciliar las referencias existentes: no borrar trabajos, reiniciar contadores, renovar claves ni crear otro pago.

## 5. Evidencia revisada para el traspaso

Se inspeccionaron ramas/historial, PR, archivos y estado/pasos/logs del último CI. No se desplegaron funciones, cambiaron flags, migraron datos ni ejecutaron pagos durante este traspaso.

[CI 36074983990](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36074983990), `8e6663d`, terminó el 24 de septiembre de 2026 a las 23:59 UTC:

| Job aprobado | Evidencia |
| --- | --- |
| `web-and-database` | 6 pruebas de configuración, 4 prototipo, 18 admin, 356 Node/PGlite, 191 pgTAP; builds web/admin y concurrencia PostgreSQL. |
| `flutter` | Formato, análisis, 51 pruebas y APK debug. |
| `ios` | Compilación para simulador, sin firma para dispositivo. |
| `identity-and-adoption-backend` | Integración contra Auth/PostgreSQL/Storage/Realtime/correo locales; no es aceptación Stripe Guardián. |

También se revisó éxito en [preflight de acceso 36070835483](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36070835483), [preparación 36071101143](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36071101143) y [APK separado 36071700507](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36071700507). El preflight de acceso comprueba presencia de nombres de secretos, no permisos Stripe.

La evidencia **histórica** de H4 registra pago/devolución de $50 MXN y transferencia/reversión de $43.14; no depósito bancario. Los experimentos Billing comprobaron factura individual pagada y renovación siguiente retenida. Ninguno sustituye el recorrido completo Guardián desde la app. La compilación firmada nueva y el recorrido TestFlight de Guardián siguen pendientes.

## 6. Entornos y credenciales

Supabase de desarrollo/test: **`ohqxranynackjignryep`**. Stripe test documentado: **`acct_1U2Dyq2ZjyMOQ0uL`**. Las sesiones/conexiones de Work no se heredan por abrir Git en Codex. Comprobar acceso efectivo y reutilizar las automatizaciones existentes; no pedir secretos por chat.

| Ubicación | Nombres / alcance |
| --- | --- |
| Flutter local | `apps/mobile/config.local.json`: `SUPABASE_URL`, `SUPABASE_PUBLISHABLE_KEY`, `AUTH_REDIRECT_URL`; `ENABLE_GUARDIAN_TEST` explícito para pruebas. |
| Panel local | `apps/admin/.env.local`: `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`. |
| Codemagic | Grupo `dopmi_supabase`: URL/clave publicable; integración `dopmi_app_store`; bundle `com.mycompany.dopmi`. |
| Android Codemagic | Firma `dopmi_upload_2026`; grupo `dopmi_google_play` / `GCLOUD_SERVICE_ACCOUNT_CREDENTIALS` para publicación. |
| GitHub Actions | Entorno `h4-test` / `SUPABASE_ACCESS_TOKEN`; usado por la preparación previa, disponibilidad futura por comprobar. |
| Edge Functions | `STRIPE_SECRET_KEY_H4_TEST`, `STRIPE_WEBHOOK_SECRET_H4_TEST`, `DOPMI_WORKER_SECRET`; credenciales de servidor solo aquí. |
| Vault / Cron | `dopmi_payment_worker_token`, mismo secreto del trabajador; Cron `dopmi-payment-worker-reconcile`, cada minuto. |

Último estado remoto **registrado**, por reconsultar en Codex: `DOPMI_GUARDIAN_WORKER_ENABLED`, `DOPMI_GUARDIAN_SCHEDULE_ENABLED`, `DOPMI_GUARDIAN_COLLECTION_ENABLED`, `DOPMI_GUARDIAN_CHANGES_ENABLED` y `DOPMI_GUARDIAN_REFUNDS_ENABLED` en `true`; **`DOPMI_GUARDIAN_CHECKOUT_ENABLED=false`**, respuesta `503 guardian_disabled`. El flag cliente de TestFlight no abre ese gate.

No asumir que `8e6663d` está desplegado: el último despliegue documentado de `payment-worker` precede al nuevo `guardian_preflight`. El push a la rama de continuación **no despliega funciones automáticamente**. Revisar `.github/workflows/deploy-supabase-payments.yml`. `prepare-guardian-test.yml` solo cambia flags manteniendo Checkout cerrado; tampoco despliega.

Antes de schema push/repair, leer [auditoría de migraciones](migration-history-audit.md): **18 nombres tienen timestamps distintos** entre archivos y versiones remotas documentadas. No demuestra divergencia del SQL; exige comparar historia/esquema antes de volver a aplicarlos.

## 7. Siguiente trabajo, en orden

1. **Contexto técnico:** rama/commit/CI actuales, herramientas y acceso efectivo a Supabase/Stripe/Codemagic. Comparar funciones desplegadas y esquema/historial; registrar los resultados.
2. **Preparar H5 test:** comprobar permisos de la clave del servidor, incluidas escrituras y reversiones. Desplegar el preflight si falta usando el procedimiento existente, tras comprobar dependencias. `guardian_preflight` solo prueba lecturas: no certifica escrituras, pago, webhook firmado ni Cron.
3. **Preparar aceptación:** cuenta de prueba, capacidad aprobada, Connect listo y dispositivo/build. Entonces abrir el alta **test** siguiendo [la guía](guardian-acceptance.md); comprobar gate y respuestas reales de Cron. Se abre para usuarios autenticados elegibles, no para un único donante.
4. **Codemagic → TestFlight:** el titular compila e instala `ios-testflight` desde la rama de continuación. Registrar SHA, versión/build y dispositivo. `pubspec.yaml` conserva una versión base antigua; Codemagic inyecta `2.3.3` y su build number.
5. **Completar matriz H5:** alta/sin capacidad/abandono/retorno, mensualidad/mes omitido, rechazo/3DS/tarjeta, monto/cancelación/aniversario, historial privado, devolución/reversión y fallos/duplicados. Corregir defectos con evidencia y CI pertinente.
6. **Cerrar H5 con evidencia:** aceptación integrada y revisión independiente registradas. Después continuar H6 y las etapas R pendientes. El cierre test no habilita dinero real.

Primer cobro, periodicidad y falta de capacidad ya están decididos. Solicitar al titular solo acciones concretas de su dispositivo/cuenta o decisiones nuevas; completar antes todo lo independiente.

## 8. Comandos y cierre de cada ciclo

Versiones del CI: Node 24, Flutter 3.47.4 / Dart 3.13.3, Python 3; Docker/Supabase para PostgreSQL; macOS/Xcode para iOS. Codemagic `ios-testflight` fija Flutter; otros workflows usan `stable`. Android usa Java 21 en GitHub CI y 17 en Codemagic. Conservar lockfiles/configuración hasta verificar cualquier cambio.

```sh
# Desde la raíz
npm ci
npm test
npm run build
npm --prefix apps/admin ci
npm --prefix apps/admin test
npm --prefix apps/admin run build
npm --prefix tools/verification ci
npm --prefix tools/verification test
python3 scripts/test_mobile_config.py
git diff --check
```

Desde `apps/mobile`: `flutter pub get`, `flutter analyze`, `flutter test`. PostgreSQL y recorridos integrados: [desarrollo](development.md) y `.github/workflows/milestone-1.yml`. `guardian-concurrency.mjs` crea fixtures y solo debe ejecutarse contra una base **local desechable** con un único contenedor Supabase.

Las rutas `.tools/`, instalaciones Windows, sesiones y configuraciones locales de registros anteriores eran de esa sesión. No asumir que existen en Codex. Este entorno de traspaso no tenía Flutter ni Docker: la evidencia de aplicación se consultó en CI, sin atribuirla a una ejecución local nueva.

Cada ciclo termina con cambio acotado, validación pertinente, evidencia por SHA/run y actualización de `progress.md`/`backlog.md`. Registrar comprobaciones bloqueadas sin declararlas aprobadas. Actualizar esta guía cuando cambien rama, flags, entorno o prioridad.

## Primer encargo listo para Codex

> Continúa Dopmi desde `codex/stripe-transfer-delivery`. Lee `AGENTS.md`, `docs/codex-handoff.md`, `docs/product-decisions.md`, `docs/backlog.md` y `docs/guardian-acceptance.md`. Comprueba el estado actual y las conexiones disponibles. El hito 5 sigue abierto: termina la preparación de Guardián en Stripe test y la aceptación por Codemagic/TestFlight; yo compilo y pruebo en mi dispositivo. Empieza por despliegue/permisos pendientes y la discrepancia del historial de migraciones, sin reejecutarlas a ciegas. Conserva las reglas económicas y registra evidencia antes de cerrar tareas. No actives dinero real.
