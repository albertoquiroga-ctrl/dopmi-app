# Dopmi móvil

Flutter + Riverpod + go_router + Supabase. Incluye identidad, adopción, mensajes, rescates/evidencia, aportaciones y Guardián protegido por flags. H1–H3 cerrados en desarrollo, H4 cerrado en prueba y H5 pendiente de aceptación integrada al 25 de septiembre de 2026.

Para continuar en Codex, leer [la guía de continuidad](../../docs/codex-handoff.md) y seleccionar la rama `codex/stripe-transfer-delivery`. El titular compila con el workflow `ios-testflight` de Codemagic y prueba desde TestFlight; [procedimiento y recorridos](../../docs/guardian-acceptance.md).

La configuración local vive en `config.local.json` (ignorada por Git). Usa `config.example.json` como punto de partida en otra máquina.

Consulta [la guía de desarrollo](../../docs/development.md), [las decisiones de producto](../../docs/product-decisions.md) y [los resultados reales de pruebas](../../docs/progress.md).

Desde la raíz del repositorio en Windows:

```powershell
.\scripts\dev.ps1 mobile-web
.\scripts\dev.ps1 mobile
.\scripts\dev.ps1 verify
```

Para otros sistemas, los comandos Flutter equivalentes están en la guía. iOS necesita macOS y Xcode. Los pagos son exclusivamente de prueba; el flag cliente `ENABLE_GUARDIAN_TEST` no abre el alta del servidor. Conservar el bundle `com.mycompany.dopmi` y la firma configurada. La versión de distribución la inyecta Codemagic; no deducirla solo de `pubspec.yaml`.
