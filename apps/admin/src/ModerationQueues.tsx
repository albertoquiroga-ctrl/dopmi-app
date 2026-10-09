import { useCallback, useEffect, useRef, useState, type ReactNode } from 'react';
import { errorMessage, validateProfileFieldFeedback, type AdminApi, type CaseUpdate, type ContentReport, type RescuerPublicProfile, type ProfileFeedbackField, type ProfileFieldFeedback } from './api';
import SupportInbox from './SupportInbox';

type Page<T> = { items: T[]; total: number };

export default function ModerationQueues({ api }: { api: AdminApi }) {
  const [view, setView] = useState<'updates' | 'reports' | 'profiles' | 'support'>('updates');
  return <><header className="page-heading"><div><p className="eyebrow">Moderación</p><h1>Contenido y reportes</h1><p>Revisa textos y fotografías antes de publicar; registra el motivo de cada decisión.</p></div></header>
    <div className="moderation-filters"><button onClick={() => setView('updates')}>Avances</button><button onClick={() => setView('profiles')}>Perfiles</button><button onClick={() => setView('reports')}>Reportes</button><button onClick={() => setView('support')}>Soporte</button></div>
    {view === 'support' ? <SupportInbox api={api} /> : view === 'updates' ? <Updates api={api} /> : view === 'profiles' ? <Profiles api={api} /> : <Reports api={api} />}</>;
}

function Queue<T extends { id: string }>({ load, empty, render }: {
  load: (page: number) => Promise<Page<T>>; empty: string;
  render: (item: T, refresh: () => void) => ReactNode;
}) {
  const [page, setPage] = useState(1), [revision, setRevision] = useState(0);
  const [data, setData] = useState<Page<T>>({ items: [], total: 0 });
  const [loading, setLoading] = useState(true), [error, setError] = useState('');
  useEffect(() => {
    let alive = true; setLoading(true); setError('');
    load(page).then(value => {
      if (!alive) return;
      if (!value.items.length && page > 1) { setPage(page - 1); return; }
      setData(value);
    }).catch(e => { if (alive) setError(errorMessage(e)); }).finally(() => { if (alive) setLoading(false); });
    return () => { alive = false; };
  }, [load, page, revision]);
  const refresh = () => setRevision(v => v + 1);
  return <>
    <button onClick={refresh} disabled={loading}>Actualizar cola</button>
    {error ? <div role="alert">{error}<button onClick={refresh}>Volver a intentar</button></div> : loading ? <p role="status">Cargando cola…</p> : <>
      {!data.items.length ? <p>{empty}</p> : <div className="moderation-list">{data.items.map(item => <article key={item.id}>{render(item, refresh)}</article>)}</div>}
      <nav aria-label="Páginas de moderación"><button disabled={page === 1} onClick={() => setPage(v => v - 1)}>Anterior</button><span>Página {page} · {data.total} registros</span><button disabled={page * 20 >= data.total} onClick={() => setPage(v => v + 1)}>Siguiente</button></nav>
    </>}
  </>;
}

function ReviewMedia({ paths, resolve, onReady }: { paths: string[]; resolve: (path: string) => Promise<string>; onReady: (ready: boolean) => void }) {
  const [urls, setUrls] = useState<string[]>([]), [error, setError] = useState(''), [attempt, setAttempt] = useState(0);
  const loaded = useRef(new Set<number>());
  const key = JSON.stringify(paths);
  useEffect(() => {
    let alive = true; loaded.current.clear(); setUrls([]); setError(''); onReady(paths.length === 0);
    Promise.all(paths.map(resolve)).then(value => { if (alive) setUrls(value); }).catch(() => { if (alive) setError('No pudimos cargar las fotografías.'); });
    return () => { alive = false; };
    // key represents the ordered immutable snapshot, independent of array identity.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key, resolve, attempt, onReady]);
  if (error) return <div role="alert">{error}<button onClick={() => setAttempt(v => v + 1)}>Reintentar fotografías</button></div>;
  return <div>{paths.length > 0 && urls.length === 0 && <p role="status">Cargando fotografías…</p>}{urls.map((url, index) => <a key={url} href={url} target="_blank" rel="noreferrer"><img src={url} alt={`Fotografía para revisión ${index + 1}`} width="160" onLoad={() => { loaded.current.add(index); if (loaded.current.size === paths.length) onReady(true); }} onError={() => { onReady(false); setError('No pudimos cargar las fotografías.'); }} /></a>)}</div>;
}

function Decision({ publishLabel, ready, decide, refresh }: { publishLabel: string; ready: boolean; decide: (decision: string, note: string) => Promise<unknown>; refresh: () => void }) {
  const [note, setNote] = useState(''), [error, setError] = useState(''), [busy, setBusy] = useState(false);
  const pending = useRef(false);
  async function submit(decision: string) {
    if (pending.current) return;
    if (decision !== 'published' && !note.trim()) { setError('Explica qué debe corregirse.'); return; }
    pending.current = true; setBusy(true); setError('');
    try { await decide(decision, note.trim()); refresh(); } catch (e) { setError(errorMessage(e)); }
    finally { pending.current = false; setBusy(false); }
  }
  return <div><label>Observaciones de revisión<textarea maxLength={1000} value={note} onChange={e => setNote(e.target.value)} /></label>{error && <p role="alert">{error}</p>}
    <button disabled={busy || !ready} onClick={() => void submit('published')}>{publishLabel}</button><button disabled={busy} onClick={() => void submit('changes_requested')}>Pedir cambios</button><button disabled={busy} onClick={() => void submit('rejected')}>Rechazar</button>
  </div>;
}

function UpdateReview({ item, api, refresh }: { item: CaseUpdate; api: AdminApi; refresh: () => void }) {
  const [ready, setReady] = useState(item.photos.length === 0);
  return <><div><p>Caso {item.case_id} · versión {item.version}</p><h2>{item.body}</h2><ReviewMedia paths={item.photos} resolve={api.caseUpdatePhotoUrl!} onReady={setReady} /></div><Decision publishLabel="Publicar" ready={ready} decide={(decision, note) => api.reviewCaseUpdate!(item, decision, note)} refresh={refresh} /></>;
}
function Updates({ api }: { api: AdminApi }) {
  const load = useCallback((page: number) => api.listCaseUpdates!('submitted', page), [api]);
  return <Queue load={load} empty="No hay historias esperando revisión." render={(item, refresh) => <UpdateReview key={`${item.id}:${item.version}`} item={item} api={api} refresh={refresh} />} />;
}
const profileFields: [ProfileFeedbackField, string][] = [
  ['display_name', 'Nombre visible'], ['bio', 'Historia'], ['city', 'Ciudad'], ['region', 'Estado'],
  ['instagram_url', 'Instagram'], ['facebook_url', 'Facebook'], ['avatar_path', 'Foto de perfil'],
  ['public_email', 'Correo público'], ['public_phone', 'Teléfono público'],
  ['public_address', 'Dirección pública'], ['website_url', 'Sitio web'], ['contact_consent', 'Consentimiento de contacto'],
];
function ProfileContacts({ item }: { item: Partial<RescuerPublicProfile> }) {
  return <><p>Consentimiento para publicar contacto: {item.contact_consent === true ? 'Autorizado' : 'Sin consentimiento'}</p>
    <dl>{profileFields.filter(([field]) => ['public_email', 'public_phone', 'public_address', 'website_url'].includes(field)).map(([field, label]) => <div key={field}><dt>{label}</dt><dd>{String(item[field] || 'Sin registrar')}</dd></div>)}</dl></>;
}
function ProfileReview({ item, api, refresh }: { item: RescuerPublicProfile; api: AdminApi; refresh: () => void }) {
  const [ready, setReady] = useState(!item.avatar_path);
  const [fieldFeedback, setFieldFeedback] = useState<ProfileFieldFeedback>(item.field_feedback || {});
  return <><div><p>{item.city}, {item.region} · versión {item.version}</p><h2>{item.display_name}</h2><p>{item.bio}</p><p>{[item.instagram_url, item.facebook_url].filter(Boolean).join(' · ') || 'Sin enlaces públicos.'}</p>
    <h3>Contacto enviado a revisión</h3><ProfileContacts item={item} />
    <p>Publicación de contacto vigente: {item.contact_publication_enabled === true ? 'Habilitada' : 'Deshabilitada'}</p>
    {item.approved_snapshot && <details><summary>Versión aprobada anterior</summary><p>{item.approved_snapshot.display_name}</p><p>{item.approved_snapshot.bio}</p><p>{[item.approved_snapshot.city, item.approved_snapshot.region].filter(Boolean).join(', ')}</p><p>{[item.approved_snapshot.instagram_url, item.approved_snapshot.facebook_url].filter(Boolean).join(' / ') || 'Sin enlaces sociales.'}</p><ProfileContacts item={item.approved_snapshot} /></details>}
    <ReviewMedia paths={item.avatar_path ? [item.avatar_path] : []} resolve={api.profileAvatarUrl!} onReady={setReady} /></div>
    <fieldset><legend>Comentarios por campo</legend>{profileFields.map(([field, label]) => <label key={field}>Corrección: {label}<textarea maxLength={500} value={fieldFeedback[field] || ''} onChange={e => setFieldFeedback(previous => ({ ...previous, [field]: e.target.value }))} /></label>)}</fieldset>
    <Decision publishLabel="Publicar perfil" ready={ready} decide={(decision, note) => { const fields = Object.fromEntries(profileFields.map(([field]) => [field, (fieldFeedback[field] || '').trim()]).filter(([, value]) => value)) as ProfileFieldFeedback; validateProfileFieldFeedback(fields); return api.reviewRescuerProfile!(item, decision, note, fields); }} refresh={refresh} /></>;
}
function Profiles({ api }: { api: AdminApi }) {
  const load = useCallback(async (page: number) => { const data = await api.listRescuerProfiles!('submitted', page); return { ...data, items: data.items.map(item => ({ ...item, id: item.owner_id })) }; }, [api]);
  return <Queue load={load} empty="No hay perfiles públicos esperando revisión." render={(item, refresh) => <ProfileReview key={`${item.id}:${item.version}`} item={item} api={api} refresh={refresh} />} />;
}
function ReportReview({ item, api, refresh }: { item: ContentReport; api: AdminApi; refresh: () => void }) {
  const [note, setNote] = useState(''), [error, setError] = useState(''), [busy, setBusy] = useState(false);
  const pending = useRef(false);
  async function resolve(status: string) {
    if (pending.current) return;
    if (!note.trim()) { setError('Describe la revisión y la acción realizada.'); return; }
    pending.current = true; setBusy(true); setError('');
    try { await api.resolveReport!(item.id, status, note.trim()); refresh(); } catch (e) { setError(errorMessage(e)); }
    finally { pending.current = false; setBusy(false); }
  }
  const types: Record<string, string> = { adoption: 'Adopción', case: 'Caso', rescuer: 'Rescatista' };
  const reasons: Record<string, string> = { incorrect: 'Información incorrecta', unsafe: 'Riesgo', fraud: 'Posible fraude', privacy: 'Privacidad', other: 'Otro' };
  return <><div><p>{types[item.target_type]} · {reasons[item.reason]}</p><h2>{item.target_id}</h2><p>{item.details || 'Sin detalles adicionales.'}</p><p>{item.resolution}</p></div><div><label>Resolución<textarea maxLength={1000} value={note} onChange={e => setNote(e.target.value)} /></label>{error && <p role="alert">{error}</p>}<button disabled={busy} onClick={() => void resolve('resolved')}>Resolver</button><button disabled={busy} onClick={() => void resolve('dismissed')}>Descartar</button></div></>;
}
function Reports({ api }: { api: AdminApi }) {
  const [status, setStatus] = useState('open');
  const load = useCallback((page: number) => api.listReports!(status, page), [api, status]);
  return <><label>Estado del reporte<select value={status} onChange={e => setStatus(e.target.value)}><option value="open">Abiertos</option><option value="reviewing">En revisión</option><option value="resolved">Resueltos</option><option value="dismissed">Descartados</option></select></label><Queue key={status} load={load} empty="No hay reportes en este estado." render={(item, refresh) => <ReportReview item={item} api={api} refresh={refresh} />} /></>;
}
