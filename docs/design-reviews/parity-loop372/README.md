# Loop372 — diagnóstico del retorno


### Loop372 — diagnóstico de representación y retorno de tarjetas, 3/10/2026

Previo371 progreso e38a59c: Auth+Checkout Stripe test confirmado y fixture limpio. Referencia a3c969c reconsultada sin cambios. Reproducción local en Chrome controlado: text/plain CSPdefaultnone+sandbox bloqueado; mismo texto con sandbox allow-same-origin bloqueado; mismo texto sólo defaultnone también bloqueado. HTML con sandbox/defaultnone abre y muestra contenido. Esto contradice atribuir el fallo exclusivamente a sandbox; apunta a manejo de MIME en este entorno, sin identificar extensión/causa exacta ni demostrar defecto en Android. No se desactivaron protecciones, no se cambió CSP y no se afirmó retorno instalado aceptado. Tres servidores locales terminados por sus handles29963/35069/44564.

Retorno agrega instrucciones reales Perfil > Métodos de pago, consultar el mismo intento y guardar sin cobro/activar Guardian. Supabase dominio estándar continúa text/plain, sin HTML/deep-link inventado ni confiar en parámetros. Deno check exit0/dbdf48 3.06s. Preflightpayment-return9ACTIVE únicoarchivo coincidefuente; deploy sólo éste en DEV a10ACTIVE, verify_jwtfalse previo conservado, cuerpo posterior coincide CRLFnormalizado. HTTPsmoke21/21 exit0/a9ab24 5.82s incluyendo copia nueva/CSP/no-store/nosniff. No schema/flags/Stripewrite/PROD/CM/push. Loop371 confirmaalta servidor, retorno visible en browsercontrolado queda limitado; aceptación teléfono y resto objetivo pendientes.

Comparación local HTML, no captura de Android ni página remota:

![HTML estricto](local-html-strict.png)
