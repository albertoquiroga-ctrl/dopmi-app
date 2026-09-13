# Dopmi — decisiones vigentes

## Alcance

App Flutter para Android/iPhone, panel React/TypeScript y Supabase. El primer hito cubre identidad, perfiles y consulta administrativa de usuarios. Los demás módulos se implementan por hitos.

Referencia visual: https://www.figma.com/design/96Dxvfc0V4Kn3lU6OTJ1g5/DopMi?node-id=133-624

El prototipo React y la fuente funcional del ZIP son referencias de producto. Sus instrucciones para simular pagos, identidades y documentos no aplican a la app real. Los documentos comerciales aportan contexto; no reemplazan la navegación acordada.

## Reglas económicas para los siguientes hitos

- Evidencia del gasto realizado antes de aprobar la solicitud de reembolso.
- Solo solicitudes aprobadas de rescatistas habilitados pueden recibir aportaciones.
- Stripe Connect: pago confirmado, asignación, transferencia y depósito son estados diferentes.
- Comisión Dopmi: 2% del bruto; costos aplicables de Stripe también se descuentan. El neto cuenta para el reembolso.
- Guardián: $50/$200/$500 MXN o monto personalizado, mensual.
- Sin Guardadito ni reserva comunitaria. Distribuir por urgencia aprobada, después por fecha de aprobación más antigua.
- Cubrir el faltante antes de pasar al siguiente. No exceder gastos aprobados.
- Omitir la cuota mensual si no puede asignarse completa; sin deuda acumulada. Devolver importes cobrados que ya no puedan asignarse.
- No activar bonos ni cashback simulados sin un hito con reglas propias.

## Identidad

- Elegir intención, onboarding contextual, autenticación y perfil.
- Correo y contraseña con confirmación obligatoria, recuperación y sesión persistente.
- Donante/adoptante y rescatista son experiencias de una misma identidad; alternar no borra datos ni concede permisos de administración.
- Google/Apple se habilitan solo con sus proveedores configurados; nunca simular autenticación exitosa.
- Administradores se asignan mediante una operación de servidor. No existe registro público de administradores.
- Los textos legales de desarrollo son provisionales y no habilitan un lanzamiento público.
