import { useEffect, useState } from 'react';
import { errorMessage, type AdminApi, type Contribution } from './api';

const statuses: Record<string, string> = {
  all: 'Todos',
  pending: 'Pago pendiente',
  partial: 'Asignado con devolución parcial',
  allocated: 'Asignado al gasto',
  unassigned: 'Devolución completa en proceso',
  canceled: 'Cancelado sin cobro',
  refunded: 'Devuelto',
  attention: 'Necesita revisión',
};
const transfers: Record<string,string> = { not_started: 'Sin transferencia', pending: 'Transferencia en proceso', transferred: 'Transferido a Stripe', attention: 'Transferencia en revisión', reversed: 'Transferencia revertida' };
const payments: Record<string,string> = { pending: 'Pendiente de confirmación', confirmed: 'Pago confirmado', canceled: 'Cancelado sin cobro', refunded: 'Pago devuelto' };

function money(cents: number) { return new Intl.NumberFormat('es-MX', { style: 'currency', currency: 'MXN' }).format(cents / 100); }
function date(value: string) { return new Intl.DateTimeFormat('es-MX', { dateStyle: 'medium', timeStyle: 'short' }).format(new Date(value)); }

export default function Contributions({ api }: { api: AdminApi }) {
  const [status, setStatus] = useState('all');
  const [page, setPage] = useState(1);
  const [revision, setRevision] = useState(0);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [data, setData] = useState<{ total: number; items: Contribution[] }>({ total: 0, items: [] });

  useEffect(() => {
    let alive = true;
    setLoading(true);
    setError('');
    setData({ total: 0, items: [] });

    api.listContributions(status, page).then(result => { if (alive) setData(result); }).catch(cause => { if (alive) setError(errorMessage(cause)); }).finally(() => { if (alive) setLoading(false); });
    return () => { alive = false; };
  }, [api, status, page, revision]);

  return <>
    <header className="page-heading"><div>
      <p className="eyebrow">Stripe Connect · modo de prueba</p>
      <h1>Aportes</h1>
      <p>Consulta el cobro, la comisión del 2%, los costos de Stripe y el neto asignado al gasto elegido.</p>
    </div><span className="read-only">Consulta administrativa</span></header>
    <section className="users-card">
      <div className="table-toolbar"><div>
        <h2>Historial de aportaciones</h2>
        <p aria-live="polite">{loading ? 'Consultando…' : `${data.total} ${data.total === 1 ? 'aportación' : 'aportaciones'}`}</p>
      </div>
        <div className="moderation-filters">
          <label>Estado<select value={status} onChange={event => { setStatus(event.target.value); setPage(1); }}>
            {Object.entries(statuses).map(([value, label]) => <option key={value} value={value}>{label}</option>)}
          </select></label>
          <button className="secondary" onClick={() => setRevision(v => v + 1)}>Actualizar</button>
        </div>
      </div>
      {error ? <div className="empty-state"><div role="alert" className="notice">{error}</div><button className="secondary" onClick={() => setRevision(v => v + 1)}>Volver a intentar</button></div>
        : loading ? <div className="empty-state" role="status">Cargando aportaciones…</div>
      : !data.items.length ? <div className="empty-state"><span className="empty-icon" aria-hidden="true">♡</span><h2>Todo al día por aquí</h2><p>No hay registros con este estado.</p></div>
            : <div className="table-scroll"><table><thead><tr><th>Donante y gasto</th><th>Cobro y costos</th><th>Neto al rescatista</th><th>Pago y transferencia</th><th>Fecha</th><th>Devolución</th></tr></thead>
              <tbody>{data.items.map(item => <tr key={item.id}><td><div><strong>{item.donor_name}</strong><small>{item.donor_email || 'Sin correo'}</small></div></td>
                <td><strong>{money(item.gross_cents)}</strong><small>Dopmi: {money(item.platform_fee_cents)}</small><small>Stripe: {item.stripe_fee_cents === null ? 'Por confirmar' : money(item.stripe_fee_cents)}</small></td>
                <td><strong>{item.processed_at === null ? 'Por confirmar' : money(item.allocated_cents)}</strong><small>{item.expense_title}</small></td>
                <td><strong>{payments[item.payment_status] || 'En revisión'}</strong><small>{transfers[item.transfer_status] || 'En revisión'}</small><small>{statuses[item.status]}</small>
                  {item.stripe_charge_id && /^ch_[a-zA-Z0-9_]+$/.test(item.stripe_charge_id) && <a href={`https://dashboard.stripe.com/test/payments/${item.stripe_charge_id}`} target="_blank" rel="noreferrer">Ver en Stripe</a>}
                </td><td>{date(item.created_at)}</td><td>{money(item.refund_cents)}<small>{item.refund_status === 'refunded' ? 'Devuelta' : item.refund_status === 'attention' ? 'Requiere revisión' : item.refund_status === 'pending' ? 'En proceso' : 'Sin devolución'}</small></td></tr>)}</tbody></table></div>}
      <p className="notice">Transferido a Stripe no confirma un depósito bancario. El rescatista puede consultar sus depósitos en su cuenta de cobro. Los fallos se reintentan con la misma referencia; los intentos sin resultado seguro requieren conciliación.</p>
      <footer className="pagination"><span>Página {page} de {Math.max(1, Math.ceil(data.total / 20))}</span><div><button className="secondary" disabled={loading || page === 1} onClick={() => setPage(p => p - 1)}>Anterior</button><button className="secondary" disabled={loading || page * 20 >= data.total} onClick={() => setPage(p => p + 1)}>Siguiente</button></div></footer>
    </section>
  </>;
}
