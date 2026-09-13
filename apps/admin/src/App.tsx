import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react';
import { errorMessage, type AdminApi, type AdminUser, type UserPage } from './api';

function Brand() { return <a className="brand" href="/" aria-label="Dopmi, inicio"><img src="/dopmi-wordmark.png" alt="Dopmi" /><span>Administración</span></a>; }
function Notice({ text }: { text: string }) { return <div className="notice" role="alert">{text}</div>; }

export default function App({ api }: { api: AdminApi | null }) {
  const [access, setAccess] = useState<'loading' | 'guest' | 'denied' | 'admin' | 'error'>('loading');
  const [error, setError] = useState('');
  const generation = useRef(0);
  const refresh = useCallback(async () => {
    if (!api) return;
    const current = ++generation.current;
    setAccess('loading'); setError('');
    try {
      const loggedIn = await api.session();
      const allowed = loggedIn && await api.isAdmin();
      if (current === generation.current) setAccess(loggedIn ? (allowed ? 'admin' : 'denied') : 'guest');
    } catch (cause) {
      if (current === generation.current) { setError(errorMessage(cause)); setAccess('error'); }
    }
  }, [api]);
  useEffect(() => {
    let active = true;
    void refresh();
    // Do not await Supabase calls inside its auth callback (client lock).
    const stop = api?.watch(() => { setTimeout(() => { if (active) void refresh(); }, 0); });
    return () => { active = false; generation.current++; stop?.(); };
  }, [api, refresh]);
  async function logout() {
    setError('');
    try { await api?.logout(); await refresh(); } catch (cause) { setError(errorMessage(cause)); }
  }
  if (!api) return <main className="access-page"><Brand /><section className="access-card"><p className="eyebrow">Entorno de desarrollo</p><h1>Conecta el panel a Dopmi</h1><p>Falta configurar la conexión con Supabase. Encontrarás los pasos en la guía de desarrollo del proyecto.</p><p className="muted">Este panel solo consulta usuarios reales del entorno configurado.</p></section></main>;
  if (access === 'guest') return <Login api={api} onLogin={refresh} />;
  if (access !== 'admin') return <main className="access-page"><Brand /><section className="access-card">
    <p className="eyebrow">Acceso del equipo</p><h1>{access === 'loading' ? 'Comprobando tu acceso…' : access === 'denied' ? 'Esta cuenta no tiene acceso' : 'No pudimos verificar tu acceso'}</h1>
    {access === 'denied' && <p>El panel está disponible para integrantes autorizados del equipo Dopmi. Puedes usar esta cuenta en la app móvil.</p>}
    {error && <Notice text={error} />}
    {access === 'error' && <button onClick={() => void refresh()}>Volver a intentar</button>}
    {access !== 'loading' && <button className="secondary" onClick={() => void logout()}>Cerrar sesión</button>}
  </section></main>;
  return <div className="admin-shell"><aside className="sidebar"><Brand /><p className="nav-label">OPERACIÓN</p><div className="nav-item" aria-current="page"><span aria-hidden="true">◎</span> Usuarios</div><div className="sidebar-bottom"><span className="status-dot" /> Conexión activa<button className="text-button" onClick={() => void logout()}>Cerrar sesión</button></div></aside><main className="workspace">{error && <Notice text={error} />}<Users api={api} /></main></div>;
}

function Login({ api, onLogin }: { api: AdminApi; onLogin: () => Promise<void> }) {
  const [busy, setBusy] = useState(false); const [error, setError] = useState('');
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); if (busy) return;
    const fields = new FormData(event.currentTarget);
    setBusy(true); setError('');
    try { await api.login(String(fields.get('email')).trim(), String(fields.get('password'))); await onLogin(); }
    catch (cause) { setError(errorMessage(cause)); } finally { setBusy(false); }
  }
  return <main className="access-page"><Brand /><section className="access-card"><p className="eyebrow">Equipo Dopmi</p><h1>Cuidamos cada paso.</h1><p>Ingresa para consultar las cuentas de la comunidad.</p><form onSubmit={submit}>
    <label>Correo electrónico<input name="email" type="email" autoComplete="username" required maxLength={254} /></label>
    <label>Contraseña<input name="password" type="password" autoComplete="current-password" required /></label>
    {error && <Notice text={error} />}<button disabled={busy}>{busy ? 'Ingresando…' : 'Iniciar sesión'}</button>
  </form><p className="access-note">Acceso exclusivo para cuentas autorizadas. Puedes recuperar tu contraseña desde la app Dopmi.</p></section></main>;
}

function date(value: string | null) { return value ? new Intl.DateTimeFormat('es-MX', { dateStyle: 'medium' }).format(new Date(value)) : 'Sin registro'; }
function Users({ api }: { api: AdminApi }) {
  const [data, setData] = useState<UserPage>({ total: 0, users: [] });
  const [search, setSearch] = useState(''); const [query, setQuery] = useState('');
  const [page, setPage] = useState(1); const [loading, setLoading] = useState(true);
  const [error, setError] = useState(''); const [retry, setRetry] = useState(0);
  const [selected, setSelected] = useState<AdminUser | null>(null);
  const closeButton = useRef<HTMLButtonElement>(null);
  const dialog = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    let alive = true; setLoading(true); setError(''); setSelected(null); setData({ total: 0, users: [] });
    api.listUsers(query, page).then(result => { if (alive) setData(result); }).catch(cause => { if (alive) setError(errorMessage(cause)); }).finally(() => { if (alive) setLoading(false); });
    return () => { alive = false; };
  }, [api, query, page, retry]);
  useEffect(() => { if (selected) { dialog.current?.showModal(); closeButton.current?.focus(); } }, [selected]);
  return <>
    <header className="page-heading"><div><p className="eyebrow">Comunidad Dopmi</p><h1>Usuarios</h1><p>Una vista clara de quienes forman parte de la comunidad.</p></div><span className="read-only">Consulta</span></header>
    <section className="users-card"><div className="table-toolbar"><div><h2>Directorio de usuarios</h2><p aria-live="polite">{loading ? 'Consultando cuentas…' : `${data.total} ${data.total === 1 ? 'cuenta encontrada' : 'cuentas encontradas'}`}</p></div>
      <form className="search-form" onSubmit={event => { event.preventDefault(); setPage(1); setQuery(search.trim()); setRetry(n => n + 1); }}><label className="sr-only" htmlFor="search">Buscar por nombre o correo</label><input id="search" placeholder="Buscar nombre o correo" value={search} maxLength={100} onChange={event => setSearch(event.target.value)} /><button className="secondary" type="submit">Buscar</button></form>
    </div>
    {error ? <div className="empty-state"><Notice text={error} /><button className="secondary" onClick={() => setRetry(n => n + 1)}>Volver a intentar</button></div> : loading ? <div className="empty-state" role="status">Cargando usuarios…</div> : data.users.length === 0 ? <div className="empty-state"><span className="empty-icon" aria-hidden="true">◎</span><h2>{query ? 'No encontramos coincidencias' : 'La comunidad está por comenzar'}</h2><p>{query ? 'Prueba con otro nombre o correo.' : 'Las cuentas registradas desde Dopmi aparecerán aquí.'}</p></div> : <div className="table-scroll"><table><thead><tr><th>Persona</th><th>Experiencia</th><th>Correo</th><th>Estado</th><th>Registro</th><th><span className="sr-only">Detalle</span></th></tr></thead><tbody>{data.users.map(user => <tr key={user.id}><td><div className="person"><span className="avatar" aria-hidden="true">{user.display_name.slice(0, 1).toUpperCase()}</span><div><strong>{user.display_name}</strong><small>{user.city || 'Ciudad sin registrar'}</small></div></div></td><td>{user.active_mode === 'rescuer' ? 'Rescatista' : 'Donante / Adoptante'}</td><td>{user.email}<small>{user.email_confirmed_at ? 'Confirmado' : 'Por confirmar'}</small></td><td><span className={`badge ${user.account_status}`}>{user.account_status === 'active' ? 'Activa' : 'Suspendida'}</span></td><td>{date(user.created_at)}</td><td><button className="text-button" aria-label={`Ver perfil de ${user.display_name}`} onClick={() => setSelected(user)}>Ver perfil →</button></td></tr>)}</tbody></table></div>}
    <footer className="pagination"><span>Página {page} de {Math.max(1, Math.ceil(data.total / 20))}</span><div><button className="secondary" disabled={page === 1 || loading} onClick={() => setPage(p => p - 1)}>Anterior</button><button className="secondary" disabled={page * 20 >= data.total || loading} onClick={() => setPage(p => p + 1)}>Siguiente</button></div></footer>
    </section>
    {selected && <dialog ref={dialog} onCancel={() => setSelected(null)} onClose={() => setSelected(null)} aria-labelledby="profile-title"><div className="dialog-header"><p className="eyebrow">Perfil de usuario</p><button ref={closeButton} className="text-button" onClick={() => dialog.current?.close()}>Cerrar</button></div><h2 id="profile-title">{selected.display_name}</h2><dl><dt>Correo</dt><dd>{selected.email || 'Sin correo'}</dd><dt>Teléfono</dt><dd>{selected.phone || 'Sin registrar'}</dd><dt>Ciudad</dt><dd>{selected.city || 'Sin registrar'}</dd><dt>Cuenta creada</dt><dd>{date(selected.created_at)}</dd><dt>Último acceso</dt><dd>{date(selected.last_sign_in_at)}</dd></dl><p className="muted">La consulta de usuarios queda registrada en el historial administrativo.</p></dialog>}
  </>;
}
