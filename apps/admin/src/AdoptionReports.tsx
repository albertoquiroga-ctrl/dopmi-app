import { useEffect, useState } from 'react';
import { errorMessage, type AdminApi } from './api';
import type { AdoptionReportPage } from './adoptionReportApi';
import './adoptionReports.css';

const number = new Intl.NumberFormat('es-MX');
function date(value: string) {
  return new Intl.DateTimeFormat('es-MX', { dateStyle: 'medium', timeStyle: 'short', timeZone: 'America/Mexico_City' }).format(new Date(value));
}

export default function AdoptionReports({ api }: { api: Pick<AdminApi, 'adoptionReport'> }) {
  const [request, setRequest] = useState({ search: '', species: '', page: 1 });
  const [search, setSearch] = useState(''); const [species, setSpecies] = useState('');
  const [revision, setRevision] = useState(0);
  const [data, setData] = useState<AdoptionReportPage | null>(null);
  const [loading, setLoading] = useState(true); const [error, setError] = useState('');
  useEffect(() => {
    let alive = true; setData(null); setLoading(true); setError('');
    const read = api.adoptionReport;
    if (!read) { setError('Este reporte todavía no está disponible en este entorno.'); setLoading(false); return; }
    read(request.search, request.species, request.page)
      .then(result => { if (alive) setData(result); })
      .catch(cause => { if (alive) setError(errorMessage(cause)); })
      .finally(() => { if (alive) setLoading(false); });
    return () => { alive = false; };
  }, [api, request, revision]);
  const filtered = !!(request.search || request.species);
  return <>
    <header className="page-heading"><div><p className="eyebrow">Actividad de adopción</p><h1>Reportes</h1><p>Conoce el interés que recibe cada mascota. Sólo adopciones publicadas.</p></div><span className="read-only">Consulta</span></header>
    <section className="users-card adoption-report" aria-label="Reporte de mascotas publicadas">
      <div className="table-toolbar"><div><h2>Mascotas publicadas</h2><p aria-live="polite">{loading ? 'Consultando reporte…' : data ? `${number.format(data.total)} ${data.total === 1 ? 'mascota encontrada' : 'mascotas encontradas'}` : 'Datos no disponibles'}</p></div><button className="secondary" disabled={loading} onClick={() => setRevision(n => n + 1)}>Actualizar</button></div>
      <form className="report-filters" onSubmit={event => { event.preventDefault(); setRequest({ search: search.trim(), species, page: 1 }); }}>
        <label htmlFor="report-search">Buscar mascota o rescatista<input id="report-search" value={search} maxLength={100} onChange={event => setSearch(event.target.value)} placeholder="Nombre de mascota o rescatista" /></label>
        <label htmlFor="report-species">Especie<select id="report-species" value={species} onChange={event => setSpecies(event.target.value)}><option value="">Perros y gatos</option><option value="dog">Perros</option><option value="cat">Gatos</option></select></label>
        <button className="secondary" type="submit">Filtrar</button>
      </form>
      {error ? <div className="empty-state"><div className="notice" role="alert">{error}</div><button className="secondary" onClick={() => setRevision(n => n + 1)}>Volver a intentar</button></div>
        : loading ? <div className="empty-state" role="status">Cargando reporte…</div>
          : data?.items.length ? <div className="table-scroll" role="region" aria-label="Tabla de actividad por mascota" tabIndex={0}><table aria-describedby="report-definitions"><caption className="sr-only">Actividad acumulada de mascotas publicadas en adopción</caption><thead><tr><th scope="col">Mascota</th><th scope="col">Especie</th><th scope="col">Rescatista</th><th scope="col">Personas que vieron el detalle</th><th scope="col">Favoritos actuales</th><th scope="col">Personas que contactaron</th><th scope="col">Primeras respuestas</th></tr></thead><tbody>{data.items.map(row => <tr key={row.id}><th scope="row"><strong>{row.pet_name}</strong><small>{[row.city, row.region].filter(Boolean).join(', ') || 'Sin ubicación'}</small></th><td>{row.species === 'dog' ? 'Perro' : 'Gato'}</td><td>{row.publisher_name || 'Sin nombre público'}</td><td className="report-count">{number.format(row.detail_viewers)}</td><td className="report-count">{number.format(row.current_favorites)}</td><td className="report-count">{number.format(row.contacts)}</td><td className="report-count">{number.format(row.first_replies)}</td></tr>)}</tbody></table></div>
            : <div className="empty-state"><h2>{filtered ? 'No encontramos coincidencias' : 'No hay adopciones publicadas'}</h2><p>{filtered ? 'Prueba con otro nombre o especie.' : 'Las mascotas aparecerán aquí cuando se publiquen.'}</p></div>}
      <footer className="pagination"><span>Página {request.page}{data ? ` de ${Math.max(request.page, Math.ceil(data.total / 20), 1)}` : ''}</span><div><button className="secondary" disabled={loading || request.page === 1} onClick={() => setRequest(r => ({ ...r, page: r.page - 1 }))}>Anterior</button><button className="secondary" disabled={loading || !data || request.page * 20 >= data.total} onClick={() => setRequest(r => ({ ...r, page: r.page + 1 }))}>Siguiente</button></div></footer>
    </section>
    <section id="report-definitions" className="report-definitions" aria-label="Cómo se cuentan las cifras"><h2>Cómo se cuentan las cifras</h2>
      <p><strong>Detalle:</strong> Una persona cuenta una vez por mascota, aunque entre varias veces o desde otro dispositivo, usando la misma cuenta y con Analítica de uso activada. Se excluyen las visitas de su autor y las vistas de tarjetas.</p>
      {data && <p>Medición del detalle desde {date(data.detail_tracking_started_at)} (Ciudad de México); no se incluyen vistas anteriores. Cifras consultadas el {date(data.generated_at)}.</p>}
      <p><strong>Favoritos:</strong> Personas que la tienen guardada ahora; disminuye al quitarla. <strong>Contactos:</strong> Personas que enviaron al menos un mensaje, incluido el saludo confirmado al contactar. <strong>Primeras respuestas:</strong> Conversaciones en las que la rescatista respondió al contacto al menos una vez. Leer el chat no cuenta como respuesta.</p>
      <p>Favoritos, contactos y respuestas se calculan con los registros disponibles, incluidas conversaciones cerradas. Retirar el consentimiento elimina las vistas de esa persona. Se muestran cifras agregadas, sin mensajes privados.</p>
    </section>
  </>;
}
