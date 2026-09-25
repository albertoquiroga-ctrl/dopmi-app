# Dopmi — app Flutter, administración y backend

Dopmi conecta adoptantes, donantes y rescatistas. La implementación está en Flutter para Android/iOS, React/TypeScript para administración y Supabase para identidad, datos, permisos y funciones de pagos.

## Continuar en Codex

**Lee primero [la guía de continuidad](docs/codex-handoff.md) y [AGENTS.md](AGENTS.md).** Corte documental: 25 de septiembre de 2026, UTC.

La rama de continuación es **`codex/stripe-transfer-delivery`**. La predeterminada, `codex/Dopmi`, recibió el PR #2, pero al revisar aún no incluía los seis commits posteriores que preparan la aceptación y TestFlight. Comprueba las referencias remotas antes de trabajar; no tomes un checkout predeterminado como la última versión.

| Área | Estado de entrega |
| --- | --- |
| H1: identidad y perfiles | Completado en desarrollo. |
| H2: adopción y comunicación | Completado en desarrollo. |
| H3: rescatistas, casos y evidencia | Completado en desarrollo. |
| H4: aportaciones únicas y Connect | Completado **en modo prueba**. |
| H5: Guardián mensual | Implementación avanzada y CI aprobado; **aceptación integrada pendiente**. |
| Beta, paridad completa y tiendas | Pendientes según el contrato de lanzamiento. |

El siguiente trabajo es preparar y aceptar Guardián mediante **Codemagic → TestFlight**, como solicitó el titular. El alta sigue cerrada según la última evidencia remota registrada. Tener la interfaz habilitada en un build no abre Checkout en el servidor ni acredita pagos o una prueba en dispositivo.

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
- [Aceptación Guardián / TestFlight](docs/guardian-acceptance.md): preparación y matriz de recorridos pendientes.
- [Auditoría del historial de migraciones](docs/migration-history-audit.md): diferencias documentales por comprobar antes de un despliegue de esquema.
- [Desarrollo](docs/development.md): herramientas, configuración local y pruebas.
- [Diseño de cobro Guardián](docs/guardian-billing-design.md), [entrega H4](docs/hito4-delivery.md) y [operación Stripe test](docs/stripe-test-mode.md).
- [Contrato del MVP público](docs/mvp-release-contract.md): paridad y lanzamiento; sus etapas R0–R6 no son los hitos H1–H6.
- [Prototipo de referencia](docs/prototype-reference.md): README original de UX, assets y simulaciones.

## Inicio local

Usa Node 24, Flutter 3.47.4 / Dart 3.13.3 y los lockfiles del repositorio. Instala dependencias por separado en raíz, `apps/admin` y `tools/verification`; ejecuta `flutter pub get` en `apps/mobile`. Configura solo claves publicables en las apps; ejemplos y comandos completos en [desarrollo](docs/development.md).

El `npm run dev` de la raíz inicia **el prototipo**, no la app Flutter. El `npm test` de la raíz tampoco sustituye las pruebas de Flutter, administración o backend.

## Evidencia más reciente revisada

[CI 36074983990](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/36074983990), sobre `8e6663d03ff2479ab6a75cc4776533dfc19e1bc4`: cuatro jobs aprobados; 356 pruebas backend, 191 pgTAP, 51 Flutter, 18 admin, cuatro del prototipo y seis de configuración. Incluye concurrencia PostgreSQL, integración local de identidad/adopción, Android debug e iOS simulator. **No acredita un IPA firmado nuevo, publicación en TestFlight, aceptación Guardián en dispositivo ni dinero real.**
