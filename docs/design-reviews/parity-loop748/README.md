# Loop748 — Teclado y candidato local

2026-10-04. Fuente `5fc3822535a02a6631bd9137736d7b6f3d42612f`. Referencia `irlanda/apoyar-detalle-perfil@a3c969cd9103fd46dc5cd886999912526ce75efb`, reconsultada sin cambios.

Se inspeccionaron nueve capturas de colección743: chat-keyboard, chat-keyboard-large, basic-info-keyboard-large, help-center-support-keyboard, help-center-support-keyboard-large, public-profile-editor-keyboard-large, rescuer-settings-social-dialog-keyboard, rescuer-settings-social-dialog-keyboard-large y public-profile-report-reference-keyboard-large. Usan viewInsets sintéticos; no dibujan ni verifican el teclado Android. Algunas capturas se desplazan deliberadamente hasta Guardar/Enviar; no se atribuye un defecto a contenido fuera del viewport durante ese desplazamiento.

Suite81595 terminó exit0:82/82 en18s. Archivos community, help_support_route, help_support_dialog, content_actions, content_report_flow, case_update_editor y rescuer_settings_details. Cubren widgets de producción con repositorios de prueba, no persistencia remota ni aceptación instalada.

Build16795 terminó exit0: APK debug local compilado en57.5s con configuración privada existente. SHA256 `98ea8d86fdff540162d46de83ac6ef7dfa14141b3fcc54f7dfff56a43cfea2e6`. No se guarda APK ni configuración en Git. Plugins Firebase emiten advertencia sobre compatibilidad futura de Kotlin; compilación actual exit0.

ADB confirmó Samsung SM-S938B conectado y Dopmi2.3.3/build286 instalado. Certificado SHA256 Play `1ff930410c43b6daaa179cbe9946c79134f36ba0f0e00a00b793ce21336faa87`; debug local `91f110abe6921164bf77b7211cd19c3157f7627230a93ecd4d3de984363c68c0`. Son distintos: no se intentó actualizar/desinstalar la app del teléfono ni borrar sus datos. La compilación instalada anterior no prueba el código actual.

Instalación30258 en emulator-5554 terminó exit0, `Success`. Suite completa iniciada; resultado pendiente al redactar. Se solicitó apertura manual del emulador para observar teclado nativo: una revisión automática previa rechazó el comando ADB de lanzamiento sin motivo específico. No se sustituye por otro mecanismo de lanzamiento. Instalación no demuestra apertura, teclado ni gestos.

Objetivo activo. No Codemagic, publicación Play ni aceptación global; dinero continúa sólo en test.

Gate completo85630:801/801 aprobadas en4m54s, exit0, fuente5fc3822. Los365 archivos de lib/test/tool/assets y configuración pública relevantes son idénticos root/scratch (verificación11270 exit0). Supersede full743/795 para pruebas unitarias/widgets; no supersede su colección visual ni acredita backend/device. `dumpsys` del emulador confirma versión debug0.2.0/build2 y actualización de este APK; no es candidato de distribución2.3.3. Source sin cambios al cierre. Refs remotas siguen continuatione4f4e858 y baseba9f897; sin push.
