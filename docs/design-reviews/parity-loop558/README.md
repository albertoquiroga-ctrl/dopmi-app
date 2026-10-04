# Loop 558 — Preparación Android nativo (en curso)

Emulator -list-avds: Dopmi_API_35. -accel-check exit0 confirma WHPX instalado y usable. Lanzado oculto/headless/read-only/no-snapshot-save, PID70556, logs Temp/dopmi-loop558-emulator.out.log y .err.log. ADB identifica emulator-5554 device; sys.boot_completed=1. pm list packages com.mycompany.dopmi vacío: la app actual aún no está instalada. No equivale a dispositivo físico, build ni aceptación de gestos. Continuar con candidato local actual y verificaciones nativas; no reemplazarlo con APK viejo. Sin push/Codemagic.

## Continuación: conexión y compilación nativa en curso

Supabase skill consultada; changelog recuperado con Python tras rechazo de tipo markdown en web. No feature ni esquema nuevo. Config existente apunta DEV ohqxranynackjignryep, clave publishable, Guardian test true; auth settings HTTP200 y catálogo público HTTP200 con5casos. No credenciales en evidencia. Config copiada sólo a scratch privado. Pubspec y archivos Android versionados coinciden entre raíz/scratch.

Flutter build apk debug/android-x64 con config.local.json, sesión95153 todavía activa. Diagnósticos jcmd muestran operaciones RUNNABLE de caché y R8; se conserva el mismo proceso. APK previo del scratch anterior al inicio no se instala como candidato actual. AVD API35/720x1520/densidad300 boot1; zona horaria cambiada GMT→America/Mexico_City para QA, emulador read-only. App aún no instalada; no aceptación nativa. Próxima continuación debe consultar95153, sin reiniciar por timeout, y verificar APK nuevo antes de instalar. Sin push/Codemagic.

## Resultado que sustituye los pendientes anteriores

La misma compilación95153 terminó exit0 (assembleDebug1112.1s). APK nuevo212447398bytes, SHA2569A2E0FACC184F39B59BFAB70B78AAB3D785FD710A8403E706957BC76185DDF5E; paquete com.mycompany.dopmi, versión local0.2.0+2, min24/target36. Instalar75429 terminó Success. Los232archivos Dart coinciden con scratch y hashes de557 después del build/QA. No cambios productivos en558.

En emulator-5554 API35/densidad300 se observaron selección Adoptar, scroll vertical al footer, entrada sin cuenta, foto/detalle Rocky Demo y Back4 regresando a la misma tarjeta y filtro Perros. Fotos remotas cargaron después del estado pendiente. Capturas inicial, selected-final, guest-final, detail-final y return permanecen en Temp/dopmi-loop558-*.png; sólo datos sintéticos DEMO observados. Sin cuentas, escrituras ni pagos. Log de errores Flutter/AndroidRuntime consultado sin líneas en el recorrido.

Primer am start -W terminó timeout aunque app visible y viva; segunda ejecución perdió su salida terminal al expirar la sesión, pero PID2499 y topResumedActivity quedaron verificados. No aceptación de rendimiento de arranque. Un primer lanzamiento se intentó antes de concluir instalación y se corrigió tras Success; una lectura de imagen precedió al fin de captura y se repitió tras exit0. No se atribuyen a defectos del app.

Esto no acepta animaciones por fotogramas, gestos físicos/edge-back, teléfono ni paridad global. No push/Codemagic; continúa comparación visual con referencia.
