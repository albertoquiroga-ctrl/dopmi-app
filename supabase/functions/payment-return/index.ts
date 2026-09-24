// The project's default Supabase domain rewrites HTML to text/plain. Return
// readable instructions there; never trust a status or redirect from the URL.
Deno.serve(() => new Response(`Continúa en Dopmi

Vuelve a la app que ya tienes abierta. Si usabas Dopmi en la web, regresa a su pestaña.

Guardián: abre Cuenta > Mi plan Guardián y actualiza tu plan o historial.
Aportación única: abre tu historial de aportaciones y actualízalo.
Cuenta de cobro: vuelve a Tu cuenta de cobro y consulta su estado.

Dopmi consultará el estado confirmado por Stripe. Esta pantalla no confirma un pago ni un cambio de medio de pago.

Si el resultado sigue pendiente, consulta el mismo intento desde Dopmi. No inicies otro pago.
`, {
  headers: { 'Content-Type': 'text/plain; charset=utf-8', 'Cache-Control': 'no-store',
    'Content-Security-Policy': "default-src 'none'; sandbox", 'X-Content-Type-Options': 'nosniff' },
}));
