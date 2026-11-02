import type { NeedComment, NeedCommentInput } from './api';

export function needKey(kind: NeedCommentInput['target_kind'], id: string) { return `${kind}:${id}`; }

export function validateNeedComments(comments: NeedCommentInput[]): string | null {
  if (!comments.length || comments.length > 40) return 'Guarda entre 1 y 40 comentarios a la vez.';
  if (comments.some(comment => !comment.body.trim() || Array.from(comment.body).length > 1000)) return 'Cada comentario debe tener entre 1 y 1000 caracteres.';
  if (comments.reduce((total, comment) => total + Array.from(comment.body).length, 0) > 20000) return 'Reduce los comentarios a un total de 20000 caracteres.';
  if (new TextEncoder().encode(JSON.stringify(comments)).length > 100000) return 'Reduce el tamaño de los comentarios antes de guardarlos.';
  return null;
}

export function CommentHistory({ comments, previous = false }: { comments: NeedComment[]; previous?: boolean }) {
  if (!comments.length) return null;
  return <section className="need-comment-history" aria-label={previous ? 'Comentarios de versiones anteriores' : 'Comentarios guardados'}>
    <h5>{previous ? 'Comentarios de versiones anteriores' : 'Comentarios guardados'}</h5>
    {comments.map(comment => <article key={comment.id} className="need-comment">
      <strong>{comment.target_title}</strong>
      <small>Expediente versión {comment.case_version} · Necesidad versión {comment.target_version} · {new Date(comment.created_at).toLocaleString('es-MX')}</small>
      <p className="authored-text">{comment.body}</p>
    </article>)}
  </section>;
}

export default function NeedFeedback({ kind, id, version, caseId, caseVersion, title, comments, value, disabled, editable, onChange }: {
  kind: NeedCommentInput['target_kind']; id: string; version: number; caseId: string; caseVersion: number; title: string;
  comments: NeedComment[]; value: string; disabled: boolean; editable: boolean; onChange: (value: string) => void;
}) {
  // A title or a position never identifies a need. Even a reused ID belongs to
  // the historical section when either the case or the target version differs.
  const associated = comments.filter(comment => comment.case_id === caseId && comment.target_kind === kind && comment.target_id === id);
  const current = associated.filter(comment => comment.case_version === caseVersion && comment.target_version === version);
  const previous = associated.filter(comment => comment.case_version !== caseVersion || comment.target_version !== version);
  return <div className="need-feedback">
    <CommentHistory comments={current}/>
    <CommentHistory comments={previous} previous/>
    {editable && <label>Comentario para {title}<textarea aria-label={`Comentario para ${title}`} value={value} maxLength={1000} rows={3} disabled={disabled} onChange={event => onChange(event.target.value)}/></label>}
  </div>;
}
