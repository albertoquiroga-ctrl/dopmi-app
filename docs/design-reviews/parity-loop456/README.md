# Loop456 — encabezado de Configuración del donador

Referencia `irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb`, reconsultada en este ciclo. Source CSS `--ink:#15110d`, `--line:#e6e2dd`; rescuer conserva `#151423/#e3e4ed`. Captura fuente vigente: [donador](../parity-loop444/source-donor.png).

ProfileFrame recibe standardSettings únicamente en Settings del donador. Corrige color del título y divisor sin cambiar geometría, navegación o persistencia. El SVG de regresar ya contiene #15110d, como el AssetIcon fuente.

Revisión de pantallas hijas: BasicInfo, PaymentMethods y Billing fuente no incluyen BottomNav; BasicInfoScreen/ContributionFrame del cliente tampoco. No corresponde agregarles una barra ni cambiar el fallback global.

Flutter: 18 pruebas dirigidas pasan (perfil + capturador), 8 s; handle92306 exit0. Cuatro capturas de widgets con repositorios fixture; normal377x852 y texto200%320x640. Normal y grande inspeccionadas; no aceptación instalada ni igualdad global. Capturas conservan accesos reales adicionales; badge de prueba del prototipo no copiado.

Full564 del loop452 precede453–456. Codemagic únicamente al completar el objetivo.
