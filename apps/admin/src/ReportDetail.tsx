import { useEffect, useRef, useState } from 'react';
import type { AdminApi } from './api';
import type { ReportAction, ReportActionInput, ReportCursor, ReportDetail as ReportPacket, ReportMessages, ReportPerson, ReportState } from './reportModeration';

const reportStatuses: Record<string, string> = { open: 'Abierto', reviewing: 'En revisión', resolved: 'Resuelto', dismissed: 'Descartado' };
const contentStatuses: Record<string, string> = { published: 'Publicada', approved: 'Aprobada', archived: 'Retirada', adopted: 'Adopción realizada', suspended: 'Suspendida', active: 'Activa', deleted: 'Eliminada', submitted: 'En revisión', changes_requested: 'Con correcciones', draft: 'Borrador', rejected: 'No aprobada' };
const reportReasons: Record<string, string> = { incorrect: 'Información incorrecta', unsafe: 'Riesgo', fraud: 'Posible fraude', privacy: 'Privacidad', other: 'Otro' };
const actionLabels: Record<ReportAction, string> = { reviewing: 'Marcar en revisión', resolve: 'Resolver reporte', dismiss: 'Descartar reporte', withdraw_publication: 'Retirar publicación', suspend_account: 'Suspender cuenta', reactivate_account: 'Reactivar cuenta' };

function date(value: string) {
  const parsed = new Date(value);
  return Number.isNaN(parsed.getTime()) ? 'Fecha no disponible' : new Intl.DateTimeFormat('es-MX', { dateStyle: 'medium', timeStyle: 'short' }).format(parsed);
}
function code(error: unknown) { return typeof error === 'object' && error !== null && 'code' in error ? String(error.code) : ''; }
function publicUrl(value: string | null) {
  try { const url = new URL(value || ''); return url.protocol === 'https:' && !url.port && !url.username && !url.password && ['dopmi.org', 'www.dopmi.org'].includes(url.hostname) ? url.href : null; } catch { return null; }
}
function validPacket(value: ReportPacket, reportId: string) {
  return value?.report?.id === reportId && Number.isInteger(value.report.version) && value.report.version > 0 &&
    value.reporter !== undefined && value.subject !== undefined && value.content !== undefined &&
    ['withdraw_publication', 'suspend_account', 'reactivate_account'].every(action => typeof value.capabilities?.[action as keyof ReportPacket['capabilities']]?.allowed === 'boolean') &&
    typeof value.conversation?.available === 'boolean' && Number.isFinite(new Date(value.conversation.cutoff).getTime()) &&
    Array.isArray(value.conversation.threads) && Array.isArray(value.history);
}
function stateText(value: ReportState) {
  if (typeof value === 'string') return contentStatuses[value] || reportStatuses[value] || value;
  if (!value) return 'Sin estado anterior';
  const labels: Record<string, string> = { status: 'Estado', account_status: 'Cuenta', report_status: 'Reporte', target_status: 'Publicación', content_status: 'Publicación', version: 'Versión', report_version: 'Versión del reporte', target_version: 'Versión de publicación' };
  const entries = Object.entries(value).filter(([key, entry]) => key in labels && (typeof entry === 'string' || typeof entry === 'number')).map(([key, entry]) => `${labels[key]}: ${contentStatuses[String(entry)] || reportStatuses[String(entry)] || entry}`);
  const target = value.target && typeof value.target === 'object' && !Array.isArray(value.target) ? value.target as Record<string, unknown> : null;
  const account = value.account && typeof value.account === 'object' && !Array.isArray(value.account) ? value.account as Record<string, unknown> : null;
  if (typeof target?.status === 'string') entries.push(`Publicación: ${contentStatuses[target.status] || target.status}`);
  if (typeof target?.version === 'number') entries.push(`Versión de publicación: ${target.version}`);
  if (typeof account?.status === 'string') entries.push(`Cuenta: ${contentStatuses[account.status] || account.status}`);
  return entries.join(' · ') || 'Estado registrado';
}
function Person({ title, person }: { title: string; person: ReportPerson | null }) {
  return <section className="report-person" aria-label={title}><h3>{title}</h3>{person ? <><h4>{person.name || 'Sin nombre público'}</h4><dl><dt>Cuenta</dt><dd>{contentStatuses[person.account_status] || person.account_status}</dd><dt>Registro</dt><dd>{date(person.created_at)}</dd><dt>Ciudad</dt><dd>{person.city || 'Sin registrar'}</dd><dt>Adopciones publicadas</dt><dd>{person.published_adoptions_count}</dd><dt>Reportes recibidos</dt><dd>{person.reports_received_count}</dd></dl></> : <p>Cuenta eliminada o no disponible.</p>}</section>;
}
function PublicPhotos({ content, api }: { content: NonNullable<ReportPacket['content']>; api: AdminApi }) {
  const [photos, setPhotos] = useState<string[]>([]), [error, setError] = useState(false), [attempt, setAttempt] = useState(0);
  const paths = JSON.stringify(content.public_photos);
  useEffect(() => {
    let alive = true; setPhotos([]); setError(false);
    const resolve = content.kind === 'adoption' ? api.photoUrl : api.rescueFileUrl;
    Promise.all(content.public_photos.map(path => resolve(path))).then(urls => {
      if (!alive) return;
      if (urls.some(url => { try { return new URL(url).protocol !== 'https:'; } catch { return true; } })) { setError(true); return; }
      setPhotos(urls);
    }).catch(() => { if (alive) setError(true); });
    return () => { alive = false; };
  // The immutable ordered photo paths, kind and version identify this snapshot.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [api, content.id, content.kind, content.version, paths, attempt]);
  if (!content.public_photos.length) return <p>Sin fotografías públicas disponibles.</p>;
  return <><div className="report-public-photos">{!photos.length && !error && <p role="status">Cargando fotografías públicas…</p>}{photos.map((url, index) => <img key={`${attempt}:${index}:${url}`} src={url} alt={`Fotografía pública ${index + 1} de ${content.title}`} onError={() => setError(true)} />)}</div>{error && <div className="notice" role="alert">No pudimos cargar todas las fotografías públicas.<button className="secondary" onClick={() => setAttempt(value => value + 1)}>Reintentar fotografías</button></div>}</>;
}

export default function ReportDetail({ reportId, api, close, changed }: { reportId: string; api: AdminApi; close: () => void; changed: () => void }) {
  const dialog = useRef<HTMLDialogElement>(null), closeButton = useRef<HTMLButtonElement>(null), confirmationHeading = useRef<HTMLHeadingElement>(null), generation = useRef(0), sending = useRef(false);
  const [detail, setDetail] = useState<ReportPacket | null>(null), [loading, setLoading] = useState(true), [error, setError] = useState(''), [revision, setRevision] = useState(0), [notice, setNotice] = useState<{ reportId: string; text: string } | null>(null);
  const [selection, setSelection] = useState<ReportAction | null>(null), [reason, setReason] = useState(''), [actionError, setActionError] = useState(''), [busy, setBusy] = useState(false), [attempt, setAttempt] = useState<ReportActionInput | null>(null);
  const [messages, setMessages] = useState<ReportMessages['items']>([]), [chatOpened, setChatOpened] = useState(false), [chatBusy, setChatBusy] = useState(false), [chatError, setChatError] = useState(''), [cursor, setCursor] = useState<ReportCursor | null>(null);
  const chatPending = useRef(false);
  const packet = detail?.report.id === reportId ? detail : null;
  const blocked = busy || attempt !== null;

  useEffect(() => {
    const previous = document.activeElement instanceof HTMLElement ? document.activeElement : null;
    dialog.current?.showModal(); closeButton.current?.focus();
    return () => { if (previous?.isConnected) previous.focus(); };
  }, []);
  useEffect(() => { if (selection) confirmationHeading.current?.focus(); }, [selection]);
  useEffect(() => {
    const scope = ++generation.current; let alive = true;
    setDetail(null); setLoading(true); setError(''); setSelection(null); setReason(''); setAttempt(null); setActionError(''); setBusy(false); sending.current = false;
    setMessages([]); setChatOpened(false); setChatBusy(false); setChatError(''); setCursor(null); chatPending.current = false;
    if (!api.reportDetail) { setError('El expediente no está disponible en esta versión del panel.'); setLoading(false); return; }
    api.reportDetail(reportId).then(value => {
      if (!alive || scope !== generation.current) return;
      if (!validPacket(value, reportId)) throw new Error('invalid_report_detail');
      setDetail(value);
    }).catch(() => { if (alive && scope === generation.current) setError('No pudimos cargar el expediente. Recárgalo antes de tomar una decisión.'); }).finally(() => { if (alive && scope === generation.current) setLoading(false); });
    return () => { alive = false; };
  }, [api, reportId, revision]);

  function reload(message = '') {
    setNotice(message ? { reportId, text: message } : null); setDetail(null); setLoading(true); setMessages([]); setChatOpened(false); setCursor(null); setChatError(''); setSelection(null); setReason(''); setAttempt(null); setActionError(''); setRevision(value => value + 1);
  }
  function requestClose() { if (!sending.current && !blocked) close(); }

  async function readConversation(before?: ReportCursor) {
    if (!packet || !api.reportConversation || chatPending.current || blocked) return;
    const threads = packet.conversation.threads;
    if (packet.report.target_type !== 'adoption' || !packet.conversation.available || threads.length !== 1 || threads[0].post_id !== packet.report.target_id) return;
    const thread = threads[0], scope = generation.current;
    chatPending.current = true; setChatBusy(true); setChatError('');
    try {
      const value = await api.reportConversation(packet.report.id, packet.report.version, thread.id, before);
      if (scope !== generation.current) return;
      const cutoff = new Date(packet.conversation.cutoff).getTime();
      if (value.report_id !== packet.report.id || value.report_version !== packet.report.version || value.thread_id !== thread.id || value.cutoff !== packet.conversation.cutoff || !Array.isArray(value.items) || value.items.length > 40 || value.items.some(item => !['reporter', 'subject'].includes(item.sender_role) || item.sender_id !== (item.sender_role === 'reporter' ? packet.reporter?.id : packet.subject?.id) || !Number.isFinite(new Date(item.created_at).getTime()) || new Date(item.created_at).getTime() > cutoff)) throw new Error('invalid_report_messages');
      if (value.next_cursor !== null && (!value.next_cursor || typeof value.next_cursor.before_id !== 'string' || !value.next_cursor.before_id || !Number.isFinite(new Date(value.next_cursor.before_time).getTime()) || new Date(value.next_cursor.before_time).getTime() > cutoff || before && value.next_cursor.before_time === before.before_time && value.next_cursor.before_id === before.before_id)) throw new Error('invalid_report_cursor');
      setMessages(previous => {
        const combined = before ? [...previous, ...value.items] : value.items;
        // PostgreSQL keeps sub-millisecond timestamp precision. Preserve its
        // newest-first order instead of reordering through JavaScript Date.
        return [...new Map(combined.map(item => [item.id, item])).values()];
      });
      setCursor(value.next_cursor); setChatOpened(true);
    } catch (cause) {
      if (scope !== generation.current) return;
      if (code(cause) === '40001') reload('El reporte cambió. Recargamos el expediente y retiramos la conversación anterior.');
      else setChatError('No pudimos abrir esta página de la conversación vinculada. Puedes intentarlo de nuevo.');
    } finally { if (scope === generation.current) { chatPending.current = false; setChatBusy(false); } }
  }

  function choose(action: ReportAction) { if (!blocked) { setSelection(action); setReason(''); setActionError(''); } }
  async function perform(saved?: ReportActionInput) {
    if (!packet || !api.reportAction || sending.current) return;
    if (!saved && (attempt || !selection)) return;
    const note = reason.trim();
    if (!saved && (Array.from(note).length < 5 || Array.from(note).length > 1000)) { setActionError('Escribe un motivo de 5 a 1000 caracteres.'); return; }
    const input = saved || {
      report_id: packet.report.id, expected_version: packet.report.version, action: selection!, reason: note, request_id: crypto.randomUUID(),
      expected_target_version: packet.content?.version ?? null, expected_account_updated_at: packet.subject?.account_updated_at ?? null, expected_suspension_action_id: packet.subject?.active_suspension_action_id ?? null,
    };
    const scope = generation.current;
    sending.current = true; setBusy(true); setAttempt(input); setActionError('');
    try {
      const result = await api.reportAction(input);
      if (scope !== generation.current) return;
      if (!result?.action_id || !Number.isInteger(result.report_version) || result.report_version <= input.expected_version) throw new Error('invalid_report_action_receipt');
      setAttempt(null); setSelection(null); changed();
      reload(`${actionLabels[input.action]}: acción confirmada.${['withdraw_publication', 'suspend_account', 'reactivate_account'].includes(input.action) ? ' Esta acción no resuelve el reporte.' : ''}`);
    } catch (cause) {
      if (scope !== generation.current) return;
      if (code(cause) === '40001') reload('El expediente cambió. No se confirmó la acción; revisa el estado actualizado antes de decidir.');
      else if (['22023', '42501'].includes(code(cause))) reload('La acción fue rechazada. Recargamos el expediente para comprobar sus permisos y estado.');
      else setActionError('No recibimos una confirmación. No inicies otra acción: reintenta la misma solicitud para conciliar su resultado.');
    } finally { if (scope === generation.current) { sending.current = false; setBusy(false); } }
  }

  const singleThread = packet?.report.target_type === 'adoption' && packet.conversation.available && packet.conversation.threads.length === 1 && packet.conversation.threads[0].post_id === packet.report.target_id;
  const publicPage = publicUrl(packet?.content?.public_url || null);
  const target = selection === 'withdraw_publication' ? packet?.content?.title || 'publicación no disponible' : selection === 'suspend_account' || selection === 'reactivate_account' ? packet?.subject?.name || 'cuenta no disponible' : 'este reporte';
  return <dialog ref={dialog} className="report-dialog" aria-labelledby="report-detail-title" onCancel={event => { event.preventDefault(); requestClose(); }}>
    <header className="dialog-header report-dialog-header"><div><p className="eyebrow">Moderación con contexto</p><h2 id="report-detail-title">Expediente del reporte</h2></div><button ref={closeButton} className="text-button" disabled={blocked} onClick={requestClose}>Cerrar expediente</button></header>
    {notice?.reportId === reportId && <p className="report-status-note" role="status">{notice.text}</p>}
    <button className="secondary report-reload" disabled={loading || blocked} onClick={() => reload()}>Recargar expediente</button>
    {loading ? <p role="status">Cargando expediente…</p> : error ? <p className="notice" role="alert">{error}</p> : packet && <>
      <section className="report-section" aria-labelledby="report-overview"><h3 id="report-overview">Reporte</h3><div className="report-summary-line"><span className="badge">{reportStatuses[packet.report.status] || packet.report.status}</span><strong>{reportReasons[packet.report.reason] || packet.report.reason}</strong></div><p className="authored-text">{packet.report.details || 'Sin detalles adicionales.'}</p><dl><dt>Recibido</dt><dd>{date(packet.report.reported_at)}</dd><dt>Versión</dt><dd>{packet.report.version}</dd><dt>Resolución registrada</dt><dd>{packet.report.resolution || 'Sin resolución registrada.'}</dd></dl>{packet.report.cutoff_basis === 'legacy_created_at' && <p className="muted">Reporte histórico: el corte de conversación usa la primera fecha de recepción disponible.</p>}</section>
      <section className="report-section" aria-labelledby="report-content"><h3 id="report-content">Publicación reportada</h3>{packet.content ? <><h4>{packet.content.title || 'Sin nombre'}</h4><p className="report-summary-line"><span>{contentStatuses[packet.content.status] || packet.content.status}</span><span>Versión {packet.content.version}</span><span>{[packet.content.city, packet.content.region].filter(Boolean).join(', ') || 'Ubicación pública sin registrar'}</span></p><p className="muted">Contenido vigente. Este reporte no conserva una copia de cómo se veía al enviarlo.</p><PublicPhotos key={`${packet.content.id}:${packet.content.version}`} content={packet.content} api={api} /><p className="authored-text">{packet.content.description || 'Sin descripción pública disponible.'}</p>{publicPage && <a className="report-public-link" href={publicPage} target="_blank" rel="noreferrer">Ver página pública</a>}</> : <p>No hay contenido público aprobado disponible. La publicación pudo retirarse, cambiar o eliminarse después del reporte.</p>}</section>
      <section className="report-section" aria-labelledby="report-people"><h3 id="report-people">Personas involucradas</h3><div className="report-people-grid"><Person title="Quien reporta" person={packet.reporter} /><Person title="Responsable reportado" person={packet.subject} /></div></section>
      <section className="report-section" aria-labelledby="report-conversation"><h3 id="report-conversation">Conversación vinculada</h3><p className="muted">Sólo el hilo de esta adopción entre las dos personas, hasta {date(packet.conversation.cutoff)}. La apertura queda registrada. Los adjuntos privados no se abren desde este expediente.</p>{singleThread && api.reportConversation ? <><p>{packet.conversation.threads[0].pet_name || 'Adopción vinculada'} · {packet.conversation.threads[0].message_count_before_cutoff} mensajes hasta el corte</p>{!chatOpened && <button className="secondary" disabled={chatBusy || blocked} onClick={() => void readConversation()}>Abrir conversación</button>}{chatOpened && <><p className="muted">Más recientes primero.</p>{!messages.length ? <p>No hay mensajes anteriores al corte.</p> : <ol className="report-messages">{messages.map(message => <li key={message.id}><div className="report-message-heading"><strong>{message.sender_role === 'reporter' ? packet.reporter?.name || 'Quien reporta' : packet.subject?.name || 'Responsable reportado'}</strong><time dateTime={message.created_at}>{date(message.created_at)}</time></div>{message.body && <p className="authored-text">{message.body}</p>}{message.has_attachment && <span className="report-attachment">Adjunto privado</span>}</li>)}</ol>}{cursor && <button className="secondary" disabled={chatBusy || blocked} onClick={() => void readConversation(cursor)}>Ver mensajes anteriores</button>}</>}{chatBusy && <p role="status">Cargando conversación…</p>}{chatError && <p className="notice" role="alert">{chatError}</p>}</> : <p>Sin conversación vinculada. {packet.conversation.reason || (singleThread ? 'La consulta de conversación no está disponible en esta versión del panel.' : 'No hay un hilo inequívoco de esta adopción y estas dos personas.')}</p>}</section>
      <section className="report-section" aria-labelledby="report-history"><h3 id="report-history">Historial de moderación</h3>{!packet.history.length ? <p>Todavía no hay acciones registradas.</p> : <ol className="report-history">{packet.history.map(entry => <li key={entry.id}><strong>{actionLabels[entry.action as ReportAction] || entry.action}</strong><p>{entry.actor_name || 'Administrador'} · <time dateTime={entry.created_at}>{date(entry.created_at)}</time></p><p className="authored-text">{entry.reason}</p><dl><dt>Antes</dt><dd>{stateText(entry.previous_state)}</dd><dt>Después</dt><dd>{stateText(entry.next_state)}</dd></dl></li>)}</ol>}</section>
      <section className="report-section report-actions" aria-labelledby="report-actions"><h3 id="report-actions">Acciones de moderación</h3><p>Retirar o suspender no resuelve el reporte automáticamente. Cada decisión requiere motivo y confirmación.</p>{!api.reportAction && <p className="notice">Las acciones no están disponibles en esta versión del panel.</p>}<div className="report-action-grid">{(['withdraw_publication', 'suspend_account', 'reactivate_account'] as const).map(action => { const capability = packet.capabilities[action]; const allowed = capability?.allowed === true && (action === 'withdraw_publication' ? packet.content !== null : packet.subject !== null); return <div key={action}><button className={action === 'reactivate_account' ? 'secondary' : 'report-danger'} disabled={blocked || !api.reportAction || !allowed} onClick={() => choose(action)}>{actionLabels[action]}</button>{!allowed && <p className="muted">{capability?.reason || 'El objetivo no está disponible para esta acción.'}</p>}</div>; })}</div><h4>Estado del reporte</h4><div className="report-status-actions">{(['reviewing', 'resolve', 'dismiss'] as const).map(action => <button key={action} className="secondary" disabled={blocked || !api.reportAction || !['open', 'reviewing'].includes(packet.report.status) || (action === 'reviewing' && packet.report.status === 'reviewing')} onClick={() => choose(action)}>{actionLabels[action]}</button>)}</div>{!['open', 'reviewing'].includes(packet.report.status) && <p className="muted">El reporte ya está cerrado; puedes consultar su contexto e historial.</p>}
        {selection && <section className="report-confirmation" aria-labelledby="report-confirmation-title"><h4 ref={confirmationHeading} tabIndex={-1} id="report-confirmation-title">Confirmar: {actionLabels[selection]}</h4><p>Objetivo: <strong>{target}</strong>.</p>{selection === 'withdraw_publication' && <p>Dejará de aparecer en el catálogo. Esta acción conserva el expediente y no se deshace al reactivar la cuenta.</p>}{selection === 'suspend_account' && <p>Se restringirá la cuenta responsable y su contenido público. No se eliminan sus datos ni se modifican sus pagos.</p>}{selection === 'reactivate_account' && <p>Sólo revierte la suspensión vigente de este flujo. No vuelve a publicar contenido retirado.</p>}<label>Motivo de la decisión<textarea value={reason} maxLength={1000} rows={3} disabled={blocked} onChange={event => setReason(event.target.value)} /></label><small>De 5 a 1000 caracteres. Quedará en el historial administrativo.</small>{actionError && <p className="notice" role="alert">{actionError}</p>}{attempt && !busy ? <button onClick={() => void perform(attempt)}>Reintentar misma acción</button> : <div className="report-confirmation-buttons"><button disabled={blocked} onClick={() => void perform()}>Confirmar acción</button><button className="secondary" disabled={blocked} onClick={() => { setSelection(null); setReason(''); setActionError(''); }}>Cancelar acción</button></div>}{busy && <p role="status">Esperando confirmación…</p>}</section>}
      </section>
    </>}
  </dialog>;
}
