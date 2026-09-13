import { useEffect, useRef, useState } from 'react';
import { adoptionStatus, errorMessage, type Adoption, type AdminApi, type Review } from './api';

function date(value: string | null) { return value ? new Date(value).toLocaleString('es-MX', { dateStyle: 'medium', timeStyle: 'short' }) : 'Sin enviar'; }

export default function Adoptions({ api }: { api: AdminApi }) {
  const [status, setStatus] = useState('submitted'), [page, setPage] = useState(1), [revision, setRevision] = useState(0);
  const [data, setData] = useState<{ total: number; items: Adoption[] }>({ total: 0, items: [] });
  const [selected, setSelected] = useState<Adoption | null>(null), [loading, setLoading] = useState(true), [error, setError] = useState('');
  useEffect(() => {
    let alive = true; setLoading(true); setSelected(null); setData({ total: 0, items: [] }); setError('');
    api.listAdoptions(status, page).then(result => { if (alive) setData(result); }).catch(cause => { if (alive) setError(errorMessage(cause)); }).finally(() => { if (alive) setLoading(false); });
    return () => { alive = false; };
  }, [api, status, page, revision]);
  return <>
    <header className="page-heading"><div><p className="eyebrow">Adopción responsable</p><h1>Publicaciones</h1><p>Revisa la historia, las fotos y la presentación pública antes de aprobar.</p></div><span className="read-only">Moderación</span></header>
    <section className="users-card"><div className="table-toolbar"><div><h2>Cola de publicaciones</h2><p aria-live="polite">{loading ? 'Consultando…' : `${data.total} publicaciones`}</p></div>
      <div className="moderation-filters"><label>Estado<select value={status} onChange={event => { setStatus(event.target.value); setPage(1); }}>{Object.entries(adoptionStatus).map(([value, label]) => <option key={value} value={value}>{label}</option>)}</select></label><button className="secondary" onClick={() => setRevision(v => v + 1)}>Actualizar</button></div>
    </div>
    {error ? <div className="empty-state"><div className="notice" role="alert">{error}</div><button onClick={() => setRevision(v => v + 1)}>Volver a intentar</button></div> : loading ? <div className="empty-state" role="status">Cargando publicaciones…</div> : !data.items.length ? <div className="empty-state"><span className="empty-icon" aria-hidden="true">♡</span><h2>Todo al día por aquí</h2><p>No hay publicaciones con este estado.</p></div> : <div className="moderation-list">{data.items.map(post => <article key={post.id}><div><p className="eyebrow">{adoptionStatus[post.status]} · Versión {post.version}</p><h2>{post.pet_name || 'Sin nombre'}</h2><p>{post.city}, {post.region}<br />{post.publisher_name || 'Nombre público pendiente'} · {date(post.submitted_at)}</p></div><button className="secondary" onClick={() => setSelected(post)} aria-label={`Revisar ${post.pet_name || 'borrador'}`}>Revisar →</button></article>)}</div>}
    <footer className="pagination"><span>Página {page} de {Math.max(1, Math.ceil(data.total / 20))}</span><div><button className="secondary" disabled={loading || page === 1} onClick={() => setPage(p => p - 1)}>Anterior</button><button className="secondary" disabled={loading || page * 20 >= data.total} onClick={() => setPage(p => p + 1)}>Siguiente</button></div></footer></section>
    {selected && <ReviewDialog key={selected.id} post={selected} api={api} close={() => setSelected(null)} completed={() => { setSelected(null); setRevision(v => v + 1); }} denied={() => { setSelected(null); setData({ total: 0, items: [] }); setError(errorMessage({ code: '42501' })); }} />}
  </>;
}

function ReviewDialog({ post, api, close, completed, denied }: { post: Adoption; api: AdminApi; close: () => void; completed: () => void; denied: () => void }) {
  const dialog = useRef<HTMLDialogElement>(null), closeButton = useRef<HTMLButtonElement>(null);
  const [photos, setPhotos] = useState<string[]>([]), [history, setHistory] = useState<Review[]>([]);
  const [loading, setLoading] = useState(true), [busy, setBusy] = useState(false), [error, setError] = useState(''), [feedback, setFeedback] = useState(''), [retry, setRetry] = useState(0);
  const [failedPhoto, setFailedPhoto] = useState(false);
  const [loadedPhotos, setLoadedPhotos] = useState<string[]>([]);
  useEffect(() => { dialog.current?.showModal(); closeButton.current?.focus(); }, []);
  useEffect(() => {
    let alive = true; setLoading(true); setError(''); setPhotos([]); setHistory([]); setFailedPhoto(false); setLoadedPhotos([]);
    Promise.all([Promise.all(post.photos.map(path => api.photoUrl(path))), api.reviews(post.id)]).then(([urls, reviews]) => { if (alive) { setPhotos(urls); setHistory(reviews); } }).catch(cause => {
      if (!alive) return; if (cause?.code === '42501') denied(); else setError(errorMessage(cause));
    }).finally(() => { if (alive) setLoading(false); });
    return () => { alive = false; };
  // Callbacks belong to this dialog instance; remote responses are discarded on unmount.
  // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [api, post, retry]);
  async function decide(decision: string) {
    if (busy) return;
    if (decision !== 'published' && feedback.trim().length < 5) { setError('Escribe un motivo de al menos 5 caracteres.'); return; }
    setBusy(true); setError('');
    try { await api.reviewAdoption(post, decision, feedback.trim()); completed(); }
    catch (cause) { if ((cause as { code?: string })?.code === '42501') denied(); else setError(errorMessage(cause)); }
    finally { setBusy(false); }
  }
  const traits: [string, boolean | null][] = [['Vacunas al día', post.vaccinated], ['Esterilización', post.sterilized], ['Convive con perros', post.social_dogs], ['Convive con gatos', post.social_cats], ['Convive con niñas y niños', post.social_children]];
  return <dialog className="review-dialog" ref={dialog} onCancel={event => { if (busy) event.preventDefault(); else close(); }} onClose={close} aria-labelledby="review-title">
    <div className="dialog-header"><p className="eyebrow">{adoptionStatus[post.status]} · Versión {post.version}</p><button ref={closeButton} className="text-button" disabled={busy} onClick={close}>Cerrar</button></div>
    <h2 id="review-title">{post.pet_name || 'Borrador sin nombre'}</h2><p>{post.city}, {post.region}</p>
    {loading ? <p role="status">Cargando fotos e historial…</p> : <div className="review-photos">{photos.map((url, index) => <img key={url} src={url} alt={`Foto ${index + 1} de ${post.pet_name}`} onLoad={() => setLoadedPhotos(previous => previous.includes(url) ? previous : [...previous, url])} onError={() => setFailedPhoto(true)} />)}</div>}
    {failedPhoto && <div className="notice" role="alert">No se pudo abrir una foto. Recárgala antes de aprobar.</div>}
    {(error || failedPhoto) && <><div className="notice" role="alert">{error || 'La foto puede haber caducado.'}</div><button className="secondary" onClick={() => setRetry(n => n + 1)}>Recargar fotos e historial</button></>}
    <dl><dt>Especie / sexo</dt><dd>{post.species === 'dog' ? 'Perro' : 'Gato'} · {post.sex === 'female' ? 'Hembra' : 'Macho'}</dd><dt>Edad / tamaño</dt><dd>{post.age_months} meses · {{ small: 'Pequeño', medium: 'Mediano', large: 'Grande' }[post.size] || post.size}</dd><dt>Raza</dt><dd>{post.breed || 'Sin especificar'}</dd></dl>
    <h3>Historia y hogar que necesita</h3><p className="authored-text">{post.story || 'Sin completar'}</p>
    <dl>{traits.map(([label, value]) => <div className="trait" key={label}><dt>{label}</dt><dd>{value === null ? 'Por confirmar' : value ? 'Sí' : 'No'}</dd></div>)}</dl>
    <h3>Cuidados especiales</h3><p className="authored-text">{post.special_care || 'Sin registrar'}</p>
    <h3>Presentación pública</h3><strong>{post.publisher_name || 'Sin completar'}</strong><p className="authored-text">{post.publisher_bio || 'Sin presentación'}</p>
    <p className="muted">Revisa que las fotos y los textos no expongan domicilios, documentos ni información privada. La aprobación publica estos campos en Dopmi.</p>
    {(post.status === 'submitted' || ['published', 'adopted'].includes(post.status)) && <div className="review-decision"><label htmlFor="feedback">Respuesta para el responsable<textarea id="feedback" rows={3} maxLength={2000} value={feedback} disabled={busy} onChange={event => setFeedback(event.target.value)} /></label><small>Obligatoria al pedir cambios, rechazar o retirar. Se conserva en el historial.</small>
      <div className="decision-actions">{post.status === 'submitted' ? <><button disabled={busy || loading || !!error || failedPhoto || loadedPhotos.length !== post.photos.length} onClick={() => void decide('published')}>Aprobar publicación</button><button className="secondary" disabled={busy || loading} onClick={() => void decide('changes_requested')}>Pedir correcciones</button><button className="secondary" disabled={busy || loading} onClick={() => void decide('rejected')}>No aprobar</button></> : <button disabled={busy || loading} onClick={() => void decide('archived')}>Retirar del catálogo</button>}</div>
    </div>}
    <h3>Historial de revisión</h3>{!history.length ? <p>Todavía no hay decisiones registradas.</p> : <ol className="review-history">{history.map(item => <li key={item.id}><strong>{adoptionStatus[item.decision]} · Versión {item.version}</strong><small>{date(item.created_at)}</small><p className="authored-text">{item.feedback || 'Aprobada sin observaciones.'}</p></li>)}</ol>}
  </dialog>;
}
