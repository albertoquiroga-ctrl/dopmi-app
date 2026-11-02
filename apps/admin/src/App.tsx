import { useCallback, useEffect, useRef, useState, type FormEvent } from 'react';
import { errorMessage, type AdminApi, type AdminUser, type UserPage } from './api';
import Adoptions from './Adoptions';
import Rescues from './Rescues';
import Contributions from './Contributions';
import ModerationQueues, { type ModerationView } from './ModerationQueues';
import StoreCatalog from './StoreCatalog';
import VideoModeration from './VideoModeration';
import Dashboard, { type DashboardDestination } from './Dashboard';

function Brand() { return <a className="brand" href="/" aria-label="Dopmi, inicio"><img src="/dopmi-wordmark.png" alt="Dopmi" /><span>Administración</span></a>; }
function Notice({ text }: { text: string }) { return <div className="notice" role="alert">{text}</div>; }

export default function App({ api }: { api: AdminApi | null }) {
  const [access, setAccess] = useState<'loading' | 'guest' | 'denied' | 'admin' | 'error'>('loading');
  const [error, setError] = useState('');
  const [section, setSection] = useState<'dashboard' | 'users' | 'adoptions' | 'rescues' | 'contributions' | 'moderation' | 'store' | 'videos'>('dashboard');
  const [menuOpen, setMenuOpen] = useState(false);
  const [moderationView, setModerationView] = useState<ModerationView>('updates');
  const [rescueKind, setRescueKind] = useState<'case' | 'verification' | 'expense'>('case');
  const main = useRef<HTMLElement>(null);
  const menuButton = useRef<HTMLButtonElement>(null);
  function navigate(next: typeof section, kind: typeof rescueKind = 'case', view: ModerationView = 'updates') {
    setModerationView(view); setRescueKind(kind); setSection(next); setMenuOpen(false);
    requestAnimationFrame(() => main.current?.focus());
  }
  function openQueue(destination: DashboardDestination) {
    navigate(destination.section, destination.section === 'rescues' ? destination.kind : 'case', destination.section === 'moderation' ? destination.view : undefined);
  }
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
      if (current === generation.current) {
        setError(errorMessage(cause));
        setAccess(typeof cause === 'object' && cause !== null && 'code' in cause && cause.code === 'google_sign_in_failed' ? 'guest' : 'error');
      }
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
  if (access === 'guest') return <Login api={api} onLogin={refresh} initialError={error} />;
  if (access !== 'admin') return <main className="access-page"><Brand /><section className="access-card">
    <p className="eyebrow">Acceso del equipo</p><h1>{access === 'loading' ? 'Comprobando tu acceso…' : access === 'denied' ? 'Esta cuenta no tiene acceso' : 'No pudimos verificar tu acceso'}</h1>
    {access === 'denied' && <p>El panel está disponible para integrantes autorizados del equipo Dopmi. Puedes usar esta cuenta en la app móvil.</p>}
    {error && <Notice text={error} />}
    {access === 'error' && <button onClick={() => void refresh()}>Volver a intentar</button>}
    {access !== 'loading' && <button className="secondary" onClick={() => void logout()}>Cerrar sesión</button>}
  </section></main>;
  const navigation = [
    { key: 'dashboard', label: 'Pendientes' },
    { key: 'rescues', label: 'Casos y necesidades' },
    { key: 'adoptions', label: 'Adopciones' },
    { key: 'moderation', label: 'Moderación' },
    { key: 'videos', label: 'Videos', available: !!api.videoModeration },
    { key: 'users', label: 'Usuarios' },
    { key: 'contributions', label: 'Aportes' },
    { key: 'store', label: 'Tienda', available: !!api.storeCatalog },
  ] as const;
  return <div className="admin-shell">
    <a className="skip-link" href="#admin-workspace">Ir al contenido</a>
    <aside className={`sidebar${menuOpen ? ' menu-open' : ''}`}>
      <div className="sidebar-heading"><Brand /><button ref={menuButton} className="menu-toggle secondary" aria-expanded={menuOpen} aria-controls="admin-navigation" onClick={() => setMenuOpen(value => !value)}>{menuOpen ? 'Cerrar menú' : 'Menú'}</button></div>
      <p className="nav-label">Tu espacio de trabajo</p>
      <nav id="admin-navigation" className="admin-navigation" aria-label="Administración" onKeyDown={event => { if (event.key === 'Escape') { setMenuOpen(false); menuButton.current?.focus(); } }}>
        {navigation.filter(item => !('available' in item) || item.available).map(item => <button key={item.key} className="nav-item" aria-current={section === item.key ? 'page' : undefined} onClick={() => navigate(item.key)}><NavIcon name={item.key}/><span>{item.label}</span></button>)}
      </nav>
      <div className="sidebar-bottom"><span className="connection-label"><span className="status-dot" /> Acceso del equipo</span><button className="text-button" onClick={() => void logout()}>Cerrar sesión</button></div>
    </aside>
    <main id="admin-workspace" ref={main} className="workspace" tabIndex={-1}>
      {error && <Notice text={error} />}
      {section === 'dashboard' ? <Dashboard api={api} onOpen={openQueue}/> : section === 'users' ? <Users api={api} /> : section === 'adoptions' ? <Adoptions api={api} /> : section === 'rescues' ? <Rescues key={rescueKind} api={api} initialKind={rescueKind} /> : section === 'contributions' ? <Contributions api={api} /> : section === 'store' && api.storeCatalog ? <StoreCatalog api={api.storeCatalog} /> : section === 'videos' && api.videoModeration ? <VideoModeration api={api.videoModeration} /> : <ModerationQueues key={moderationView} api={api} initialView={moderationView}/>}
    </main>
  </div>;
}

function NavIcon({ name }: { name: string }) {
  const paths: Record<string, string> = {
    dashboard: 'M4 4h6v6H4z M14 4h6v6h-6z M4 14h6v6H4z M14 14h6v6h-6z',
    rescues: 'M12 20s-8-5-8-11a4 4 0 0 1 8-2 4 4 0 0 1 8 2c0 6-8 11-8 11z',
    adoptions: 'M4 10 12 3l8 7v10h-6v-6h-4v6H4z',
    moderation: 'm12 3 8 3v5c0 5-8 10-8 10S4 16 4 11V6z M8 11l3 3 5-5',
    videos: 'M3 5h13v14H3z m13 5 5-3v10l-5-3',
    users: 'M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2 M9 11a4 4 0 1 0 0-8 4 4 0 0 0 0 8 M20 21v-2a4 4 0 0 0-3-4 M16 3a4 4 0 0 1 0 8',
    contributions: 'M3 6h18v14H3z M3 10h18 M7 15h3',
    store: 'M4 9v11h16V9 M3 9l2-6h14l2 6 M3 9h18 M9 20v-7h6v7',
  };
  return <svg viewBox="0 0 24 24" width="22" height="22" fill="none" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" strokeLinejoin="round" aria-hidden="true"><path d={paths[name]}/></svg>;
}

function Login({ api, onLogin, initialError }: { api: AdminApi; onLogin: () => Promise<void>; initialError: string }) {
  const [busy, setBusy] = useState<'password' | 'google' | null>(null); const [error, setError] = useState(initialError);
  const googleAttempt = useRef<symbol | null>(null);
  useEffect(() => {
    function returned(event: PageTransitionEvent) {
      if (!event.persisted || !googleAttempt.current) return;
      googleAttempt.current = null;
      setBusy(current => current === 'google' ? null : current);
    }
    window.addEventListener('pageshow', returned);
    return () => { googleAttempt.current = null; window.removeEventListener('pageshow', returned); };
  }, []);
  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault(); if (busy) return;
    const fields = new FormData(event.currentTarget);
    setBusy('password'); setError('');
    try { await api.login(String(fields.get('email')).trim(), String(fields.get('password'))); await onLogin(); }
    catch (cause) { setError(errorMessage(cause)); } finally { setBusy(null); }
  }
  async function googleLogin() {
    if (busy || googleAttempt.current || !api.loginWithGoogle) return;
    const attempt = Symbol();
    googleAttempt.current = attempt;
    setBusy('google'); setError('');
    try { await api.loginWithGoogle(); }
    catch {
      if (googleAttempt.current === attempt) {
        googleAttempt.current = null;
        setError(errorMessage({ code: 'google_sign_in_failed' }));
        setBusy(null);
      }
    }
    // A resolved OAuth request only starts navigation. Keep the latch until this
    // page unloads, or pageshow confirms a browser Back return from the provider.
  }
  return <main className="access-page"><Brand /><section className="access-card"><p className="eyebrow">Equipo Dopmi</p><h1>Cuidamos cada paso.</h1><p>Ingresa para consultar las cuentas de la comunidad.</p><form onSubmit={submit}>
    <label>Correo electrónico<input name="email" type="email" autoComplete="username" required maxLength={254} /></label>
    <label>Contraseña<input name="password" type="password" autoComplete="current-password" required /></label>
    {error && <Notice text={error} />}<button disabled={busy !== null}>{busy === 'password' ? 'Ingresando…' : 'Iniciar sesión'}</button>
    {api.loginWithGoogle && <button type="button" className="secondary" disabled={busy !== null} onClick={() => void googleLogin()}>{busy === 'google' ? 'Conectando con Google…' : 'Continuar con Google'}</button>}
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
    {error ? <div className="empty-state"><Notice text={error} /><button className="secondary" onClick={() => setRetry(n => n + 1)}>Volver a intentar</button></div> : loading ? <div className="empty-state" role="status">Cargando usuarios…</div> : data.users.length === 0 ? <div className="empty-state"><span className="empty-icon" aria-hidden="true">◎</span><h2>{query ? 'No encontramos coincidencias' : 'La comunidad está por comenzar'}</h2><p>{query ? 'Prueba con otro nombre o correo.' : 'Las cuentas registradas desde Dopmi aparecerán aquí.'}</p></div> : <div className="table-scroll"><table className="user-directory"><thead><tr><th>Persona</th><th>Experiencia</th><th>Correo</th><th>Estado</th><th>Registro</th><th><span className="sr-only">Detalle</span></th></tr></thead><tbody>{data.users.map(user => <tr key={user.id}><td data-label="Persona"><div className="person"><span className="avatar" aria-hidden="true">{user.display_name.slice(0, 1).toUpperCase()}</span><div><strong>{user.display_name}</strong><small>{user.city || 'Ciudad sin registrar'}</small></div></div></td><td data-label="Experiencia">{user.active_mode === 'rescuer' ? 'Rescatista' : 'Donante / Adoptante'}</td><td data-label="Correo">{user.email}<small>{user.email_confirmed_at ? 'Confirmado' : 'Por confirmar'}</small></td><td data-label="Estado"><span className={`badge ${user.account_status}`}>{user.account_status === 'active' ? 'Activa' : 'Suspendida'}</span></td><td data-label="Registro">{date(user.created_at)}</td><td className="user-action"><button className="text-button" aria-label={`Ver perfil de ${user.display_name}`} onClick={() => setSelected(user)}>Ver perfil</button></td></tr>)}</tbody></table></div>}
    <footer className="pagination"><span>Página {page} de {Math.max(1, Math.ceil(data.total / 20))}</span><div><button className="secondary" disabled={page === 1 || loading} onClick={() => setPage(p => p - 1)}>Anterior</button><button className="secondary" disabled={page * 20 >= data.total || loading} onClick={() => setPage(p => p + 1)}>Siguiente</button></div></footer>
    </section>
    {selected && <dialog ref={dialog} onCancel={() => setSelected(null)} onClose={() => setSelected(null)} aria-labelledby="profile-title"><div className="dialog-header"><p className="eyebrow">Perfil de usuario</p><button ref={closeButton} className="text-button" onClick={() => dialog.current?.close()}>Cerrar</button></div><h2 id="profile-title">{selected.display_name}</h2><dl><dt>Correo</dt><dd>{selected.email || 'Sin correo'}</dd><dt>Teléfono</dt><dd>{selected.phone || 'Sin registrar'}</dd><dt>Ciudad</dt><dd>{selected.city || 'Sin registrar'}</dd><dt>Cuenta creada</dt><dd>{date(selected.created_at)}</dd><dt>Último acceso</dt><dd>{date(selected.last_sign_in_at)}</dd></dl><p className="muted">La consulta de usuarios queda registrada en el historial administrativo.</p></dialog>}
  </>;
}
