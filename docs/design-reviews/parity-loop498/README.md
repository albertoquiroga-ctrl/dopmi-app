# Loop498 — curva de entrada de bienvenida

SourceSHA a3c969cd9103fd46dc5cd886999912526ce75efb reconsultado. CSS1032-1042 prescribe onb-in450ms cubic(.22,1,.36,1), opacity0→1 y translateY10→0. App.tsx684 asigna key por slide.id; cliente tiene keys por intención/paso y OnboardingEntrance con la misma curva. No nueva observación runtime Source en este loop.

La prueba de entrada existente ahora comprueba opacidad exacta y desplazamiento a225ms contra la curva, además de origen/final450. Gate97218exit0,18/18,5s (onboarding_motion y design_navigation), log dopmi-loop498-onboarding.log. Incluye retrasos independientes de resumen/footer, movimiento reducido y regresos de las tres intenciones/texto200. Fuente 4e14d63b20b6806ebc4327f096d871101c420e3d, sólo test; no cambios de producción. Esta comprobación temporal de componente y las rutas existentes no acreditan aceptación visual de todas las pantallas. Full601493 producciónc57974a vigente; sin backend/SQL/push/Codemagic.
