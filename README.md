# DopMi Functional Prototype V2

La implementación real del **hito 1 está completada y verificada** en `apps/mobile`, `apps/admin` y `supabase`: identidad, perfiles y consulta administrativa. [CI aprobado](https://github.com/albertoquiroga-ctrl/dopmi-app/actions/runs/34788208103). Consulta [la guía de desarrollo](docs/development.md), [las decisiones vigentes](docs/product-decisions.md) y [el avance verificado](docs/progress.md). El contenido siguiente y `src/` describen el prototipo de referencia; sus simulaciones económicas no son reglas de la app real.

Prototipo navegable para pruebas de UX basado en los frames vigentes de Figma y en `DopMi_Fuente_de_la_Verdad.md`.

## Reglas de producto (permanentes)

- **Español:** todo el copy visible va en español de México. Si Figma trae inglés, se traduce antes de implementar. Excepciones: marcas y nombres propios (DopMi, Google, Apple Pay, etc.).
- **Contraste WCAG 2.2 AA:** texto normal ≥ 4.5:1; texto grande e iconos necesarios ≥ 3:1. El amarillo de marca (`--yellow`) se usa en rellenos; para texto/íconos sobre fondo claro se usa `--yellow-ink`. Ver `.cursor/rules/dopmi-i18n-a11y.mdc`.

## Ejecutar

```bash
export PATH="$PWD/.tools/node/bin:$PATH"
npm run dev
```

La app abre en `http://127.0.0.1:5173`.

## Alcance

- Acceso, intención, onboarding y autenticación.
- Onboarding con tres pistas de dos slides (Adoptante, Donante, Rescatista) según el rol elegido en Tipo de Cuenta.
- Bienvenida con accesos sociales (Google/Apple), Iniciar sesión y Crear cuenta, como el frame `Welcome` de Figma.
- Header común del flujo de acceso (`BrandHeader`): ranuras laterales de 40px a 24px del borde y logo de 144×48 centrado; las pantallas internas conservan la barra con título a 16px, como en Figma.
- Cuenta compartida Adoptante/Donante y cambio a Rescatista.
- Adopción (incluido el estado sin mascotas disponibles), guardados y mensajes.
- Perfil público del rescatista con redes sociales, pestañas En Adopción / Casos / Actividad y reporte; lista de rescatistas guardados.
- Donaciones con éxito/error, historial y notificaciones sincronizadas.
- Tu Impacto: cuando no eres Guardián, carrusel de tres slides ("casos urgentes", "fondo comunitario", "reportes de impacto") con comunidad y beneficios; ya suscrito, muestra "Vidas que continúan gracias a ti" con las tarjetas de Luna, Milo, Max y Bella.
- Flujo Guardián: "Elige tu apoyo" (montos $50/$200/$500 o cantidad personalizada, resumen, Apple/Google Pay y tarjeta predeterminada), pantalla "¡Ya eres Guardián!" con la membresía y error de pago según Modo prueba.
- Selección de monto y administración de suscripción desde Billing.
- Settings con Información Básica, Métodos de Pago y Billing (suscripción activa o sin suscripción, cambio de cantidad, cancelación e historial de pagos).
- Centro de ayuda con las preguntas frecuentes de Donante y de Rescatista.
- Lado rescatista: Home verificado con Cuenta Dopmi, acciones pendientes tipadas (mensajes, evidencia incompleta, evidencia nueva) y actividad reciente; sin verificar / en revisión muestran la tarjeta de estado del mock; Perfil con tarjeta pública, Settings con estado de verificación, información personal, redes sociales y datos bancarios.
- Verificación de rescatista con el modal explicativo del reembolso, formulario único (información básica, experiencia, redes, documentos) y barra de progreso; el panel muestra el bono de $350 MXN al aprobar y en revisión el CTA "Simular verificación".
- Publicar con dos entradas y Mis Casos con progreso de fondeo, interruptor de adopción y los estados Borrador y Rechazado.
- Evidencia, ciclo de comida y estados simulados identificados.
- Modo prueba para cambiar resultados de pago, verificación y cuenta activa.

No incluye Administración interna, landing pública ni Comunidad. Los estados sin frame aprobado muestran la leyenda `ESTADO SIMULADO`.

## Assets

Todos los iconos, fotos y el logo viven en `public/assets` y provienen de Figma (exportaciones de los frames vigentes) o del logo entregado por el equipo:

- `dopmi-wordmark.png` y `dopmi-mark.png`: logo oficial, usados en splash y pantallas de acceso.
- `tab-*.svg` y `rtab-*.svg`: barras de navegación de Donante y Rescatista.
- `notif-*.svg`: iconos de cada tipo de notificación con su color de chip.
- `icon-*.svg`: campana, marcador, chevron, configuración, escudo, corazón, más y mensajes; también las filas de Settings (usuario, tarjeta, billing, ayuda, salir), el sello de verificado y las redes sociales.
- `icon-google.svg`, `icon-apple.svg` y `welcome-pets.png`: accesos sociales e imagen de la pantalla de bienvenida.
- `onb-*.svg`: chevron de retroceso e iconos de las ilustraciones del onboarding por rol.
- `check-circle.svg` e `icon-doc.svg`: lista de requisitos de evidencia y aviso de revisión manual en la verificación del rescatista.
- `icon-wallet.svg`, `icon-alert-circle.svg`, `icon-chat-yellow.svg`, `icon-camera-red.svg`, `icon-receipt-purple.svg` e `icon-donation-in.svg`: home del rescatista (Cuenta Dopmi, acciones pendientes y actividad).
- `icon-share.svg`, `icon-bolt.svg` e `icon-clock.svg`: compartir en las tarjetas de impacto y los sellos del carrusel Guardián.
- `impact-luna.png`, `impact-milo.png`, `impact-max.png` e `impact-bella.png`: fotos originales de las tarjetas de Tu Impacto suscrito.
- `guardian-*.jpg`: fotos del carrusel Guardián. En Figma cada slide es una sola imagen plana dentro de un frame llamado "Placeholder for HeroCarousel", con el texto y las tarjetas incrustados en el pixel. Para conservar los mismos animales se recortaron las zonas de foto limpia de esas imágenes (`scripts/crop-guardian-photos.py` documenta los recuadros) y encima se reconstruyeron las tarjetas con componentes del sistema, respetando la distribución del mock: sellos apilados arriba a la izquierda, monto y caso en paralelo, diagrama del fondo en tres columnas y el panel de reportes sobre la mitad derecha.

Los iconos de una sola tinta se pintan con `Icon`, que aplica el SVG como máscara CSS para heredar el color de estado (activo/inactivo). Los iconos multicolor se renderizan con `AssetIcon` como imagen. Cada uso define ancho y alto explícitos para conservar la geometría del diseño.

## Verificar

```bash
npm test
npm run build
```
