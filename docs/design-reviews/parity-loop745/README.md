# Loop745 — Texto ampliado de Configuración

2026-10-04. Based868406. Sourceirlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb verificado inicio/cierre.

Se inspeccionaron12 capturas320×640/texto200% de colección743: adoption-large, adoption-detail-large, match-all-large, chat-bubbles-large, support-home-large, case-detail-large; profile-overview-large, profile-settings-large, rescuer-profile-large, rescuer-settings-large, rescuer-home-large, owned-cases-large. Support está intencionalmente desplazado hasta el hero. Contenido parcial bajo barras fijas necesita desplazamiento; no se infiere fallo por no estar entero en primer viewport.

Defecto observado: Información básica partía Información en Informació/n en Configuración. RescuerNavigationRow standardSettings mantiene normal intacto; en ancho interior<300 y texto16 escalado>25 usa icono/flecha/contador en primera fila y copia a todo el ancho debajo. Reflujo de accesibilidad para teléfono, sin contraparte Source exacta200% medida; no se presenta como copia literal de layout Source ampliado. Mantiene fuente/tamaños, etiquetas, iconos, roles, callbacks, enabled y presión plana. No modifica filas rescatista estándar.

Nueva prueba con Inter real,320×640, escala1/2 y enabledfalse/true: selección de palabra Información produce un único box de línea; texto contenido dentro de tarjeta; hold150/cancel sin callback/rect estable; tap invoca callback sólo enabled. Gate67840 terminal0,10/10 en2s (settings_navigation_reflow/rescuer_profile_access). Primera ejecución19672 exit1 por archivo inexistente profile_settings_test; no se contabiliza como suite aprobada.

Capture22462 terminal0,1/1 en3s:cincoPNG profile-settings actuales, PIL/hash/dimensiones en manifest. Normal PNG exactamente igual al baseline743 por SHA256 a9bd24a037d4eda6ec11bf716fa1fd5ea72870baaa1544fbe4eb1716f6e5feed. Grande final inspeccionado: Información y básica quedan en líneas completas, subtítulo legible. Analyzer22462 terminal0 limpio6.1s.

Full743/795 antecede cambios744/745 y cuatro pruebas nuevas. Sin aceptación instalada/global; Codemagic diferido hasta terminar, dinero test-only. Próximo continuar inspección de estados amplificados/formularios y comparación de rutas pendientes.
