import { useEffect, useRef, useState } from 'react';
import { AdminPushKeyChanged, adminPushEnabled, disableAdminPush, enableAdminPush, supportsAdminPush, type AdminPushApi } from './adminPush';

export default function AdminPushControls({ api }: { api: AdminPushApi }) {
  const supported = supportsAdminPush();
  const [sessionId, setSessionId] = useState<string | null>(null);
  const [enabled, setEnabled] = useState<boolean | null>(null);
  const [busy, setBusy] = useState(false);
  const [notice, setNotice] = useState('');
  const lifetime = useRef<AbortController | null>(null);

  useEffect(() => {
    const controller = new AbortController();
    lifetime.current = controller;
    if (supported) {
      const check = async () => {
        const id = await api.sessionId();
        if (!id || controller.signal.aborted) throw new Error('No signed-in session');
        setSessionId(id);
        const value = await adminPushEnabled(api, id, controller.signal);
        if (!controller.signal.aborted) setEnabled(value);
      };
      void check().catch(() => {
        if (!controller.signal.aborted) {
          setEnabled(false);
          setNotice('No pudimos consultar el estado de los avisos.');
        }
      });
    }
    return () => controller.abort();
  }, [api, supported]);

  async function toggle() {
    if (!lifetime.current || !sessionId || busy) return;
    const { signal } = lifetime.current;
    setBusy(true);
    setNotice('');
    try {
      if (enabled) {
        await disableAdminPush(api, sessionId, signal);
        if (!signal.aborted) setEnabled(false);
      } else {
        const result = await enableAdminPush(api, sessionId, signal);
        if (!signal.aborted) {
          setEnabled(result);
          if (!result) setNotice('Permite las notificaciones de Dopmi en los ajustes del navegador o de Android.');
        }
      }
    } catch (cause) {
      if (!signal.aborted) {
        setNotice(cause instanceof AdminPushKeyChanged
          ? 'Restablece el permiso de notificaciones de Dopmi en el navegador y vuelve a intentarlo.'
          : 'No pudimos cambiar los avisos. Vuelve a intentarlo.');
      }
    } finally {
      if (!signal.aborted) setBusy(false);
    }
  }

  return <section className="admin-push-card" aria-labelledby="admin-push-title">
    <div>
      <h2 id="admin-push-title">Avisos en este dispositivo</h2>
      <p role="status">
        {!supported ? 'Abre Dopmi en un navegador compatible para recibir avisos.' :
          enabled === null ? 'Comprobando tus avisos…' :
          enabled ? 'Recibirás avisos de nuevas solicitudes, reportes y soporte.' :
          'Recibe avisos cuando haya solicitudes, reportes o consultas de soporte.'}
      </p>
      {notice && <p className="admin-push-error" role="alert">{notice}</p>}
    </div>
    {supported && <button className="secondary" onClick={() => void toggle()} disabled={busy || !sessionId || enabled === null}>
      {busy ? 'Guardando…' : enabled ? 'Desactivar avisos' : 'Activar avisos'}
    </button>}
  </section>;
}
