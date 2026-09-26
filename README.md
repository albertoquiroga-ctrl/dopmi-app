# Dopmi — app Flutter, administración y backend

Dopmi conecta adoptantes, donantes y rescatistas. La implementación está en Flutter para Android/iOS, React/TypeScript para administración y Supabase para identidad, datos, permisos y funciones de pagos.

## Continuar en Codex

**Lee primero [la guía de continuidad](docs/codex-handoff.md) y [AGENTS.md](AGENTS.md).** Corte documental: 25 de septiembre de 2026, UTC.

La base H6 está en **`codex/mvp-consolidation`**, que reúne la continuación y la rama predeterminada mediante un PR. Verifica su integración y los refs antes de trabajar. H1–H3 están completos en desarrollo; H4/H5 están aceptados en test. H5 conserva la excepción explícita de disputa posterior a transferencia. Dinero real sigue separado.

El trabajo vigente es [H6–H12](docs/release-roadmap.md): consolidación, retiro del legado, paridad con la rama de Irlanda, integraciones y aceptación en ambas tiendas. La [matriz de paridad](docs/design-parity.md) distingue funciones implementadas de aceptación visual.

## Dónde trabajar

| Ruta | Responsabilidad |
| --- | --- |
| `apps/mobile/` | App Flutter: identidad, adopción, rescate, comunicación, aportaciones y Guardián. |
| `apps/admin/` | Panel con permisos de servidor: usuarios, adopciones, rescates y aportaciones. |
| `supabase/migrations/` | Esquema, permisos y operaciones transaccionales. |
| `supabase/functions/` | Checkout, Connect, Guardián, webhook y trabajador de conciliación. |
| `tools/verification/` | Pruebas Node/PGlite, concurrencia PostgreSQL y comprobaciones remotas. |
| `codemagic.yaml` | Compilación/firma y distribución Android/iOS. |
| `src/`, `public/` | Prototipo visual conservado como referencia. |

## Documentación

- [Continuidad para Codex](docs/codex-handoff.md): estado, evidencia, prioridades, configuración y primer encargo.
- [Decisiones de producto](docs/product-decisions.md): reglas vigentes; prevalecen sobre las simulaciones del prototipo.
- [Backlog](docs/backlog.md) y [registro de avance](docs/progress.md): tareas y evidencia histórica.
- [Aceptación Guardián / TestFlight](docs/guardian-acceptance.md): matriz y evidencia de aceptación test.
- [Auditoría del historial de migraciones](docs/migration-history-audit.md): correspondencia comprobada y límites para futuros cambios de esquema.
- [Desarrollo](docs/development.md): herramientas, configuración local y pruebas.
- [Diseño de cobro Guardián](docs/guardian-billing-design.md), [entrega H4](docs/hito4-delivery.md) y [operación Stripe test](docs/stripe-test-mode.md).
- [Contrato del MVP público](docs/mvp-release-contract.md): paridad y lanzamiento; sus etapas R0–R6 no son los hitos H1–H6.
- [Prototipo de referencia](docs/prototype-reference.md): README original de UX, assets y simulaciones.

## Inicio local

Usa Node 24, Flutter 3.47.4 / Dart 3.13.3 y los lockfiles del repositorio. Instala dependencias por separado en raíz, `apps/admin` y `tools/verification`; ejecuta `flutter pub get` en `apps/mobile`. Configura solo claves publicables en las apps; ejemplos y comandos completos en [desarrollo](docs/development.md).

El `npm run dev` de la raíz inicia **el prototipo**, no la app Flutter. El `npm test` de la raíz tampoco sustituye las pruebas de Flutter, administración o backend.

## Evidencia más reciente revisada

CI [36202506285](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36202506285), SHA `943a7d4`: cuatro jobs aprobados. H5 y sus límites en [la entrega](docs/hito5-delivery.md). Codemagic Android 2.3.3 (252), SHA `0140fbd`, build `6ab6e1527e2cdbe815b37fa0`, firma y publicación aprobadas. iOS 2.3.3 (241), SHA `d74fe97`, corresponde a una base anterior; no acredita el Guardián actual en TestFlight. Estas comprobaciones no certifican producción ni depósito bancario.
