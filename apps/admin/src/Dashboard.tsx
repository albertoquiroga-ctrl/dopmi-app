import { useEffect, useState } from 'react';
import type { AdminApi } from './api';
import type { ModerationView } from './ModerationQueues';
import AdminPushControls from './AdminPushControls';

export type DashboardDestination =
  | { section: 'rescues'; kind: 'case' | 'verification' }
  | { section: 'moderation'; view?: ModerationView }
  | { section: 'adoptions' | 'videos' };

type QueueId = 'cases' | 'adoptions' | 'verification' | 'reports' | 'updates' | 'profiles';
type QueueCount = { id: QueueId; label: string; count: number | null };
type QueueLoader = { id: QueueId; label: string; load: () => Promise<{ total: number }> };

function loaders(api: AdminApi): QueueLoader[] {
  return [
    { id: 'cases', label: 'Casos para apoyo', load: () => api.listRescue('case', 'submitted', 1) },
    { id: 'adoptions', label: 'Mascotas en adopción', load: () => api.listAdoptions('submitted', 1) },
    { id: 'verification', label: 'Sellos de refugio', load: () => api.listRescue('verification', 'submitted', 1) },
    ...(api.listReports ? [{ id: 'reports' as const, label: 'Reportes', load: () => api.listReports!('open', 1) }] : []),
    ...(api.listCaseUpdates ? [{ id: 'updates' as const, label: 'Avances', load: () => api.listCaseUpdates!('submitted', 1) }] : []),
    ...(api.listRescuerProfiles ? [{ id: 'profiles' as const, label: 'Perfiles públicos', load: () => api.listRescuerProfiles!('submitted', 1) }] : []),
  ];
}

export default function Dashboard({ api, onOpen }: {
  api: AdminApi;
  onOpen: (destination: DashboardDestination) => void;
}) {
  const [counts, setCounts] = useState<QueueCount[]>([]);
  const [loading, setLoading] = useState(true);
  const [revision, setRevision] = useState(0);
  const [updatedAt, setUpdatedAt] = useState<Date | null>(null);
  useEffect(() => {
    let active = true;
    setLoading(true); setCounts([]); setUpdatedAt(null);
    const queues = loaders(api);
    // One first-page read per queue. Totals come from the server, not page length.
    void Promise.allSettled(queues.map(queue => Promise.resolve().then(async () => {
      const page = await queue.load();
      if (!Number.isSafeInteger(page.total) || page.total < 0) throw new Error('invalid_queue_total');
      return page.total;
    }))).then(results => {
      if (!active) return;
      setCounts(results.map((result, index) => ({
        id: queues[index].id, label: queues[index].label,
        count: result.status === 'fulfilled' ? result.value : null,
      })));
      setLoading(false); setUpdatedAt(new Date());
    });
    return () => { active = false; };
  }, [api, revision]);

  const failed = counts.filter(item => item.count === null);
  const knownTotal = counts.reduce((sum, item) => sum + (item.count ?? 0), 0);
  const moderation = counts.filter((item): item is QueueCount & { id: 'reports' | 'updates' | 'profiles' } => item.id === 'reports' || item.id === 'updates' || item.id === 'profiles');
  const moderationUnavailable = moderation.some(item => item.count === null);
  const moderationTotal = moderation.reduce((sum, item) => sum + (item.count ?? 0), 0);
  const cards: { title: string; description: string; entries: QueueCount[]; destination: DashboardDestination; tone: string }[] = [
    { title: 'Casos para apoyo', description: 'Revisa casos nuevos y ediciones completas con sus necesidades.', entries: counts.filter(item => item.id === 'cases'), destination: { section: 'rescues', kind: 'case' }, tone: 'saffron' },
    { title: 'Mascotas en adopción', description: 'Revisa la información y las fotos antes de publicarlas.', entries: counts.filter(item => item.id === 'adoptions'), destination: { section: 'adoptions' }, tone: 'sky' },
    { title: 'Sellos de refugio', description: 'La verificación del refugio es opcional para solicitar apoyo.', entries: counts.filter(item => item.id === 'verification'), destination: { section: 'rescues', kind: 'verification' }, tone: 'orange' },
  ];

  return <>
    <header className="page-heading dashboard-heading">
      <div><p className="eyebrow">Equipo Dopmi</p><h1>Pendientes de revisión</h1><p>Todo lo que necesita tu atención, en un mismo lugar.</p></div>
      <button className="secondary refresh-button" disabled={loading} onClick={() => setRevision(value => value + 1)}>{loading ? 'Consultando…' : 'Actualizar pendientes'}</button>
    </header>
    {api.pushNotifications && <AdminPushControls api={api.pushNotifications} />}
    <section className="dashboard-summary" aria-live="polite" aria-busy={loading}>
      <span className="summary-mark" aria-hidden="true">♡</span>
      <div><h2>{loading ? 'Consultando las colas de revisión…' : failed.length === counts.length ? 'No pudimos consultar los pendientes' : failed.length ? `${knownTotal} pendientes en las colas consultadas` : knownTotal ? `${knownTotal} ${knownTotal === 1 ? 'pendiente por revisar' : 'pendientes por revisar'}` : 'Estas colas están al día'}</h2>
        <p>{loading ? 'Estamos comprobando la información del servidor.' : 'Abre un expediente para revisar su contenido y registrar tu decisión.'}</p>
      </div>
    </section>
    {failed.length > 0 && <div className="notice" role="alert">No pudimos consultar: {failed.map(item => item.label).join(', ')}. Su recuento está pendiente; actualiza o abre la sección para volver a intentar.</div>}
    <div className="dashboard-grid">
      {cards.map(card => {
        const unavailable = card.entries.some(item => item.count === null);
        const count = card.entries.reduce((sum, item) => sum + (item.count ?? 0), 0);
        return <button key={card.title} className={`queue-card queue-${card.tone}`} onClick={() => onOpen(card.destination)}>
          <span className="queue-card-heading"><span className="queue-title">{card.title}</span><span className="queue-count" aria-label={loading ? 'Consultando recuento' : unavailable ? 'Recuento no disponible' : `${count} ${count === 1 ? 'pendiente' : 'pendientes'}`}>{loading || unavailable ? '—' : count}</span></span>
          <span className="queue-description">{card.description}</span>
          {card.entries.length > 1 && <span className="queue-breakdown">{card.entries.map(item => `${item.label}: ${item.count ?? 'sin consultar'}`).join(' · ')}</span>}
          <span className="queue-open">Abrir revisión <span aria-hidden="true">↗</span></span>
        </button>;
      })}
      {moderation.length > 0 && <section className="queue-card queue-neutral" aria-labelledby="dashboard-moderation-title">
        <div className="queue-card-heading"><h2 id="dashboard-moderation-title" className="queue-title">Contenido y reportes</h2><span className="queue-count" aria-label={moderationUnavailable ? 'Recuento no disponible' : `${moderationTotal} ${moderationTotal === 1 ? 'pendiente' : 'pendientes'}`}>{moderationUnavailable ? '—' : moderationTotal}</span></div>
        <p className="queue-description">Abre la cola que quieres revisar.</p>
        <div className="decision-actions">{moderation.map(item => <button key={item.id} className="secondary" onClick={() => onOpen({ section: 'moderation', view: item.id })}>{item.label}: {item.count === null ? 'sin consultar' : `${item.count} ${item.count === 1 ? 'pendiente' : 'pendientes'}`}</button>)}</div>
      </section>}
    </div>
    <footer className="dashboard-footer"><p>{updatedAt ? `Última consulta: ${updatedAt.toLocaleTimeString('es-MX', { hour: '2-digit', minute: '2-digit' })}. Los recuentos cambian al actualizar.` : 'Los recuentos se consultan al abrir este resumen.'}</p>
    </footer>
    {(api.videoModeration || api.listSupportRequests) && <section className="dashboard-tools" aria-labelledby="dashboard-tools-title"><h2 id="dashboard-tools-title">Otros apartados</h2><p>Los videos y las consultas de soporte se revisan por separado y no están incluidos en estos recuentos.</p><div>{api.videoModeration && <button className="secondary" onClick={() => onOpen({ section: 'videos' })}>Revisar videos</button>}{api.listSupportRequests && <button className="secondary" onClick={() => onOpen({ section: 'moderation', view: 'support' })}>Revisar soporte</button>}</div></section>}
  </>;
}
