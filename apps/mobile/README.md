# Dopmi móvil

Hito 1: onboarding, registro y confirmación de correo, inicio/cierre de sesión, recuperación, perfil y cambio de experiencia. Flutter + Riverpod + go_router + Supabase.

La configuración local vive en `config.local.json` (ignorada por Git). Usa `config.example.json` como punto de partida en otra máquina.

Consulta [la guía de desarrollo](../../docs/development.md), [las decisiones de producto](../../docs/product-decisions.md) y [los resultados reales de pruebas](../../docs/progress.md).

Desde la raíz del repositorio en Windows:

```powershell
.\scripts\dev.ps1 mobile-web
.\scripts\dev.ps1 mobile
.\scripts\dev.ps1 verify
```

Para otros sistemas, los comandos Flutter equivalentes están en la guía. iOS necesita macOS y Xcode. Esta entrega es de desarrollo y no habilita pagos.
