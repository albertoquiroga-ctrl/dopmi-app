import { useEffect, useState } from 'react';
import type { AdminApi, FirstPublicationSummary } from './api';

const cdmxDate = new Intl.DateTimeFormat('es-MX', {
  dateStyle: 'medium',
  timeStyle: 'short',
  timeZone: 'America/Mexico_City',
});

const stages = [
  ['accounts_created', 'Cuentas nuevas'],
  ['authors_with_drafts', 'Iniciaron una publicación'],
  ['authors_with_photo', 'Con foto guardada'],
  ['authors_with_submissions', 'Con envío a revisión'],
  ['authors_with_publications', 'Con adopción publicada'],
] as const;

function isCount(value: unknown): boolean {
  return typeof value === 'number' && Number.isSafeInteger(value) && value >= 0;
}

function isValid(summary: FirstPublicationSummary): boolean {
  return !!summary &&
    typeof summary.generated_at === 'string' && Number.isFinite(Date.parse(summary.generated_at)) &&
    typeof summary.window_started_at === 'string' && Number.isFinite(Date.parse(summary.window_started_at)) &&
    stages.every(([key]) => isCount(summary[key])) &&
    isCount(summary.rescuer_mode_accounts) &&
    isCount(summary.stalled_draft_authors) &&
    isCount(summary.first_reviews_pending) &&
    (summary.oldest_first_review_hours === null || isCount(summary.oldest_first_review_hours));
}

type LoadSummary = NonNullable<AdminApi['firstPublicationSummary']>;

export default function FirstPublicationPanel({ load, revision, onReview }: {
  load: LoadSummary;
  revision: number;
  onReview: () => void;
}) {
  const [response, setResponse] = useState<{
    load: LoadSummary;
    revision: number;
    data: FirstPublicationSummary | null;
  }>();

  useEffect(() => {
    let active = true;
    void Promise.resolve().then(load).then(summary => {
      if (active) setResponse({ load, revision, data: isValid(summary) ? summary : null });
    }, () => {
      if (active) setResponse({ load, revision, data: null });
    });
    return () => { active = false; };
  }, [load, revision]);

  const loading = response?.load !== load || response.revision !== revision;
  const summary = loading ? null : response.data;
  const checkPhotos = summary && summary.stalled_draft_authors >= 5;

  return <section className="queue-card first-publication" aria-labelledby="first-publication-title" aria-busy={loading}>
    <h2 id="first-publication-title" className="queue-title">Primera publicación de adopción</h2>
    <div aria-live="polite">
      {loading ? <p>Consultando las primeras publicaciones…</p> :
        !summary ? <p role="status">Datos no disponibles. Usa Actualizar pendientes para volver a consultar.</p> : <>
          <p className="queue-description">
            Cuentas creadas en los últimos 7 días. Corte del {cdmxDate.format(new Date(summary.generated_at))} (CDMX).
          </p>
          <dl className="first-publication-counts">
            {stages.map(([key, label]) => <div key={key}><dt>{label}</dt><dd>{summary[key]}</dd></div>)}
          </dl>
          <p className="queue-description">{summary.rescuer_mode_accounts} cuentas nuevas en modo Rescatista al corte.</p>
          <p className={checkPhotos ? 'notice' : 'queue-description'}>
            {checkPhotos && <strong>Revisar cámara y galería. </strong>}
            Cuentas con un borrador de al menos 24 horas, sin foto ni envío registrado: {summary.stalled_draft_authors}.
          </p>
          <p className="queue-description">
            Primeras publicaciones en revisión en todo Dopmi: {summary.first_reviews_pending}.
            {summary.oldest_first_review_hours !== null && ` La más antigua lleva ${summary.oldest_first_review_hours} h.`}
          </p>
        </>}
    </div>
    <button className="secondary" onClick={onReview}>Abrir revisión de adopciones</button>
  </section>;
}
