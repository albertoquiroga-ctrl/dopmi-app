import { act, fireEvent, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import ReportDetail from './ReportDetail';
import type { AdminApi } from './api';
import type { ReportActionInput, ReportDetail as Packet, ReportMessages } from './reportModeration';

const cutoff = '2026-11-22T12:00:00Z';
function packet(): Packet {
  return {
    report: { id: 'report-one', target_type: 'adoption', target_id: 'pet-one', reason: 'unsafe', details: 'Revisar lo ocurrido.', status: 'open', resolution: '', created_at: cutoff, updated_at: cutoff, reported_at: cutoff, version: 3, cutoff_basis: 'reported_at' },
    reporter: { id: 'reporter', name: 'Ana', account_status: 'active', created_at: '2026-09-20T12:00:00Z', city: 'Monterrey', published_adoptions_count: 0, reports_received_count: 0 },
    subject: { id: 'owner', name: 'Refugio Luna', account_status: 'active', created_at: '2026-09-01T12:00:00Z', city: 'Monterrey', published_adoptions_count: 2, reports_received_count: 1, account_updated_at: '2026-11-20T12:00:00Z', active_suspension_action_id: null },
    content: { kind: 'adoption', id: 'pet-one', title: 'Luna', description: 'Historia pública de Luna.', status: 'published', version: 8, city: 'Monterrey', region: 'Nuevo León', public_photos: ['approved/luna.jpg'], public_url: 'https://www.dopmi.org/adoptions/pet-one', current_snapshot: true },
    conversation: { available: true, reason: null, cutoff, threads: [{ id: 'thread-one', post_id: 'pet-one', pet_name: 'Luna', message_count_before_cutoff: 3 }] },
    capabilities: { withdraw_publication: { allowed: true, reason: null }, suspend_account: { allowed: true, reason: null }, reactivate_account: { allowed: false, reason: 'La cuenta no está suspendida por este flujo.' } }, history: [],
  };
}
function messages(): ReportMessages { return { report_id: 'report-one', report_version: 3, thread_id: 'thread-one', cutoff, items: [{ id: 'message-two', sender_id: 'owner', sender_role: 'subject', body: 'Gracias por escribir.', has_attachment: true, created_at: '2026-11-22T11:30:00Z' }], next_cursor: { before_time: '2026-11-22T11:30:00Z', before_id: 'message-two' } }; }
function api(value = packet()) {
  return {
    reportDetail: vi.fn(async () => value), reportConversation: vi.fn(async () => messages()),
    reportAction: vi.fn(async () => ({ action_id: 'action-one', replayed: false, report_version: 4, target_state: null, account_state: null })),
    photoUrl: vi.fn(async () => 'https://images.example.test/luna.jpg'), rescueFileUrl: vi.fn(async () => 'https://images.example.test/profile.jpg'),
  } as unknown as AdminApi;
}
function open(client: AdminApi) {
  const close = vi.fn(), changed = vi.fn();
  const result = render(<ReportDetail reportId="report-one" api={client} close={close} changed={changed} />);
  return { ...result, user: userEvent.setup(), close, changed };
}
function deferred<T>() { let resolve!: (value: T) => void; let reject!: (cause: unknown) => void; const promise = new Promise<T>((yes, no) => { resolve = yes; reject = no; }); return { promise, resolve, reject }; }

describe('report dossier context', () => {
  it('shows publication, both people, current-snapshot warning and history without reading chat or acting', async () => {
    const value = packet(); value.history = [{ id: 'previous', actor_name: 'Moderadora', action: 'reviewing', reason: 'Revisar el contexto.', created_at: cutoff, previous_state: { report_status: 'open' }, next_state: { report_status: 'reviewing' } }];
    const client = api(value); open(client);
    expect(await screen.findByText('Historia pública de Luna.')).toBeInTheDocument();
    expect(screen.getByRole('region', { name: 'Quien reporta' })).toHaveTextContent('Ana');
    expect(screen.getByRole('region', { name: 'Responsable reportado' })).toHaveTextContent('Refugio Luna');
    expect(screen.getByText(/Contenido vigente/)).toBeInTheDocument();
    expect(screen.getByText('Moderadora', { exact: false })).toBeInTheDocument();
    expect(client.photoUrl).toHaveBeenCalledWith('approved/luna.jpg');
    expect(client.reportConversation).not.toHaveBeenCalled(); expect(client.reportAction).not.toHaveBeenCalled();
    expect(screen.getByRole('button', { name: 'Reactivar cuenta' })).toBeDisabled();
    expect(screen.getByText('La cuenta no está suspendida por este flujo.')).toBeInTheDocument();
  });
  it('explains the real nested moderation states without exposing unrelated account fields', async () => {
    const value = packet(); value.history = [{ id: 'withdrawn', actor_name: 'Moderadora', action: 'withdraw_publication', reason: 'Retirar contenido riesgoso.', created_at: cutoff,
      previous_state: { report_status: 'open', target: { status: 'published', version: 8 }, account: { status: 'active', updated_at: 'hidden-account-timestamp' } },
      next_state: { report_status: 'open', target: { status: 'archived', version: 9 }, account: { status: 'suspended', updated_at: 'hidden-account-timestamp', arbitrary_private_field: 'no-visible' } },
    }]; open(api(value));
    const history = await screen.findByRole('region', { name: 'Historial de moderación' });
    expect(within(history).getByText(/Publicación: Publicada/)).toHaveTextContent('Cuenta: Activa');
    expect(within(history).getByText(/Publicación: Retirada/)).toHaveTextContent('Cuenta: Suspendida');
    expect(within(history).getByText(/Versión de publicación: 9/)).toBeInTheDocument();
    expect(history).not.toHaveTextContent('hidden-account-timestamp'); expect(history).not.toHaveTextContent('no-visible');
  });
  it('has an accessible close target and escape closes without an action', async () => {
    const client = api(); const { close } = open(client);
    const dialog = await screen.findByRole('dialog', { name: 'Expediente del reporte' });
    expect(screen.getByRole('button', { name: 'Cerrar expediente' })).toHaveFocus();
    fireEvent(dialog, new Event('cancel', { cancelable: true }));
    expect(close).toHaveBeenCalledOnce(); expect(client.reportAction).not.toHaveBeenCalled();
  });
  it('states deletion and missing conversation explicitly without assuming active accounts', async () => {
    const value = packet(); value.reporter = null; value.subject = null; value.content = null; value.conversation = { available: false, reason: 'Publicación eliminada.', cutoff, threads: [] }; value.capabilities.suspend_account = { allowed: false, reason: 'La cuenta no está disponible.' };
    const client = api(value); open(client);
    expect(await screen.findByText('No hay contenido público aprobado disponible. La publicación pudo retirarse, cambiar o eliminarse después del reporte.')).toBeInTheDocument();
    expect(screen.getAllByText('Cuenta eliminada o no disponible.')).toHaveLength(2);
    expect(screen.queryByRole('button', { name: 'Abrir conversación' })).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Suspender cuenta' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Retirar publicación' })).toBeDisabled();
  });
  it('never fabricates a dossier when the response belongs to another report', async () => {
    const value = packet(); value.report.id = 'another-report'; const client = api(value); open(client);
    expect(await screen.findByRole('alert')).toHaveTextContent('No pudimos cargar el expediente');
    expect(screen.queryByText('Historia pública de Luna.')).not.toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Suspender cuenta' })).not.toBeInTheDocument();
  });
  it('fails closed when a report lacks capability contracts', async () => {
    const value = packet(); delete (value.capabilities as Partial<Packet['capabilities']>).suspend_account;
    const client = api(value); open(client);
    expect(await screen.findByRole('alert')).toHaveTextContent('No pudimos cargar el expediente');
    expect(screen.queryByText('Historia pública de Luna.')).not.toBeInTheDocument();
    expect(client.photoUrl).not.toHaveBeenCalled();
  });
  it('restores focus to the opening control when the dossier closes', async () => {
    const opener = document.createElement('button'); opener.textContent = 'Abrir reporte'; document.body.append(opener); opener.focus();
    const client = api(); const { unmount } = open(client); await screen.findByText('Historia pública de Luna.');
    unmount(); expect(opener).toHaveFocus(); opener.remove();
  });
  it('discards late responses when another report is opened quickly', async () => {
    const pending = deferred<Packet>(); const second = packet(); second.report.id = 'report-two'; second.content = { ...second.content!, title: 'Sol', description: 'Contexto de Sol.' };
    const client = api(); client.reportDetail = vi.fn().mockReturnValueOnce(pending.promise).mockResolvedValue(second);
    const { rerender, close, changed } = open(client);
    rerender(<ReportDetail reportId="report-two" api={client} close={close} changed={changed} />);
    expect(await screen.findByText('Contexto de Sol.')).toBeInTheDocument();
    await act(async () => pending.resolve(packet()));
    expect(screen.queryByText('Historia pública de Luna.')).not.toBeInTheDocument();
    expect(screen.getByText('Contexto de Sol.')).toBeInTheDocument();
  });
  it('retries failed public photographs without opening chat attachments', async () => {
    const client = api(); const { user } = open(client);
    fireEvent.error(await screen.findByAltText('Fotografía pública 1 de Luna'));
    expect(screen.getByRole('alert')).toHaveTextContent('No pudimos cargar todas las fotografías públicas.');
    await user.click(screen.getByRole('button', { name: 'Reintentar fotografías' }));
    await waitFor(() => expect(client.photoUrl).toHaveBeenCalledTimes(2));
    expect(client.rescueFileUrl).not.toHaveBeenCalled();
  });
  it('uses the other public-photo resolver for a profile and ignores unsafe public links', async () => {
    const value = packet(); value.report.target_type = 'rescuer'; value.content = { ...value.content!, kind: 'rescuer', public_url: 'javascript:alert(1)' }; value.conversation = { available: false, reason: 'Sólo adopciones.', cutoff, threads: [] };
    const client = api(value); open(client);
    expect(await screen.findByAltText('Fotografía pública 1 de Luna')).toBeInTheDocument();
    expect(client.rescueFileUrl).toHaveBeenCalledWith('approved/luna.jpg'); expect(client.photoUrl).not.toHaveBeenCalled();
    expect(screen.queryByRole('link', { name: 'Ver página pública' })).not.toBeInTheDocument();
  });
});

describe('bounded report conversation', () => {
  it('opens the verified historical thread even when no public snapshot remains', async () => {
    const value = packet(); value.content = null;
    const client = api(value); const { user } = open(client);
    await user.click(await screen.findByRole('button', { name: 'Abrir conversación' }));
    expect(await screen.findByText('Gracias por escribir.')).toBeInTheDocument();
    expect(client.reportConversation).toHaveBeenCalledWith('report-one', 3, 'thread-one', undefined);
    expect(client.photoUrl).not.toHaveBeenCalled(); expect(client.rescueFileUrl).not.toHaveBeenCalled();
    expect(screen.queryByText('Historia pública de Luna.')).not.toBeInTheDocument();
  });
  it('refuses a thread for another report target even when no public snapshot remains', async () => {
    const value = packet(); value.content = null; value.conversation.threads[0].post_id = 'another-pet';
    const client = api(value); open(client);
    expect(await screen.findByText(/Sin conversación vinculada/)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Abrir conversación' })).not.toBeInTheDocument();
    expect(client.reportConversation).not.toHaveBeenCalled();
  });
  it('preserves the server order for messages separated by fractions of a millisecond', async () => {
    const value = messages(); value.items = [
      { ...value.items[0], id: 'a-newer', body: 'Primero por fecha exacta.', created_at: '2026-11-22T11:30:00.0009Z' },
      { ...value.items[0], id: 'z-older', body: 'Segundo por fecha exacta.', created_at: '2026-11-22T11:30:00.0001Z' },
    ]; value.next_cursor = null; const client = api(); client.reportConversation = vi.fn(async () => value); const { user } = open(client);
    await user.click(await screen.findByRole('button', { name: 'Abrir conversación' })); await screen.findByText('Primero por fecha exacta.');
    const rows = within(screen.getByRole('region', { name: 'Conversación vinculada' })).getAllByRole('listitem');
    expect(rows[0]).toHaveTextContent('Primero por fecha exacta.'); expect(rows[1]).toHaveTextContent('Segundo por fecha exacta.');
  });
  it('reads explicitly, paginates the same report/version/thread, and shows only an attachment marker', async () => {
    const client = api(); const first = messages(); const older = { ...first, items: [{ id: 'message-one', sender_id: 'reporter', sender_role: 'reporter' as const, body: 'Quisiera conocer a Luna.', has_attachment: false, created_at: '2026-11-22T11:00:00Z' }], next_cursor: null };
    client.reportConversation = vi.fn().mockResolvedValueOnce(first).mockResolvedValueOnce(older);
    const { user } = open(client);
    await user.click(await screen.findByRole('button', { name: 'Abrir conversación' }));
    expect(await screen.findByText('Gracias por escribir.')).toBeInTheDocument();
    expect(screen.getByText('Adjunto privado').tagName).toBe('SPAN');
    expect(client.reportConversation).toHaveBeenNthCalledWith(1, 'report-one', 3, 'thread-one', undefined);
    await user.click(screen.getByRole('button', { name: 'Ver mensajes anteriores' }));
    expect(await screen.findByText('Quisiera conocer a Luna.')).toBeInTheDocument();
    expect(client.reportConversation).toHaveBeenNthCalledWith(2, 'report-one', 3, 'thread-one', first.next_cursor);
    expect(screen.queryByRole('button', { name: 'Ver mensajes anteriores' })).not.toBeInTheDocument();
    expect(client.photoUrl).toHaveBeenCalledTimes(1); expect(client.rescueFileUrl).not.toHaveBeenCalled();
  });
  it.each(['wrong-thread', 'wrong-participant', 'future-message', 'wrong-version'])('rejects %s responses without displaying their body', async kind => {
    const value = messages(); value.items[0].body = 'No debe mostrarse';
    if (kind === 'wrong-thread') value.thread_id = 'another-thread';
    if (kind === 'wrong-participant') value.items[0].sender_id = 'someone-else';
    if (kind === 'future-message') value.items[0].created_at = '2026-11-23T12:00:00Z';
    if (kind === 'wrong-version') value.report_version = 99;
    const client = api(); client.reportConversation = vi.fn(async () => value); const { user } = open(client);
    await user.click(await screen.findByRole('button', { name: 'Abrir conversación' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('No pudimos abrir esta página');
    expect(screen.queryByText('No debe mostrarse')).not.toBeInTheDocument();
  });
  it('does not offer a thread selector when the relationship is ambiguous', async () => {
    const value = packet(); value.conversation.threads.push({ ...value.conversation.threads[0], id: 'another-thread' }); const client = api(value); open(client);
    expect(await screen.findByText(/Sin conversación vinculada/)).toBeInTheDocument();
    expect(screen.queryByRole('button', { name: 'Abrir conversación' })).not.toBeInTheDocument();
    expect(screen.queryByRole('combobox')).not.toBeInTheDocument(); expect(client.reportConversation).not.toHaveBeenCalled();
  });
  it('removes all old chat pages after a version conflict and reloads context', async () => {
    const client = api(); client.reportConversation = vi.fn().mockResolvedValueOnce(messages()).mockRejectedValueOnce({ code: '40001' }); const fresh = packet(); fresh.report.version = 4; client.reportDetail = vi.fn().mockResolvedValueOnce(packet()).mockResolvedValue(fresh);
    const { user } = open(client);
    await user.click(await screen.findByRole('button', { name: 'Abrir conversación' }));
    expect(await screen.findByText('Gracias por escribir.')).toBeInTheDocument();
    await user.click(screen.getByRole('button', { name: 'Ver mensajes anteriores' }));
    expect(await screen.findByText(/El reporte cambió. Recargamos/)).toBeInTheDocument();
    await waitFor(() => expect(client.reportDetail).toHaveBeenCalledTimes(2));
    expect(screen.queryByText('Gracias por escribir.')).not.toBeInTheDocument();
    expect(await screen.findByRole('button', { name: 'Abrir conversación' })).toBeEnabled();
  });
  it('keeps historical cutoff clearly labelled', async () => {
    const value = packet(); value.report.cutoff_basis = 'legacy_created_at'; const client = api(value); open(client);
    expect(await screen.findByText(/Reporte histórico: el corte/)).toBeInTheDocument();
  });
  it('refuses an invalid pagination cursor instead of making it available to another request', async () => {
    const value = messages(); value.next_cursor = { before_time: 'not-a-date', before_id: 'message-two' };
    const client = api(); client.reportConversation = vi.fn(async () => value); const { user } = open(client);
    await user.click(await screen.findByRole('button', { name: 'Abrir conversación' }));
    expect(await screen.findByRole('alert')).toHaveTextContent('No pudimos abrir esta página');
    expect(screen.queryByRole('button', { name: 'Ver mensajes anteriores' })).not.toBeInTheDocument();
  });
});

describe('confirmed moderation actions', () => {
  it('requires a reason and confirmation naming the account, with all CAS tokens', async () => {
    const client = api(); const { user, changed } = open(client);
    await user.click(await screen.findByRole('button', { name: 'Suspender cuenta' }));
    const confirmation = screen.getByRole('region', { name: 'Confirmar: Suspender cuenta' });
    expect(confirmation).toHaveTextContent('Refugio Luna'); expect(client.reportAction).not.toHaveBeenCalled();
    await user.click(within(confirmation).getByRole('button', { name: 'Confirmar acción' }));
    expect(screen.getByRole('alert')).toHaveTextContent('Escribe un motivo de 5 a 1000 caracteres.');
    await user.type(screen.getByLabelText('Motivo de la decisión'), 'Revisamos la evidencia.');
    await user.click(within(confirmation).getByRole('button', { name: 'Confirmar acción' }));
    await waitFor(() => expect(changed).toHaveBeenCalledOnce());
    expect(client.reportAction).toHaveBeenCalledWith({ report_id: 'report-one', expected_version: 3, action: 'suspend_account', reason: 'Revisamos la evidencia.', request_id: expect.any(String), expected_target_version: 8, expected_account_updated_at: '2026-11-20T12:00:00Z', expected_suspension_action_id: null });
    expect(await screen.findByText(/Esta acción no resuelve el reporte/)).toBeInTheDocument();
  });
  it('keeps the exact UUID and payload after an uncertain response and blocks another action', async () => {
    const client = api(); client.reportAction = vi.fn().mockRejectedValueOnce(new Error('network')).mockResolvedValueOnce({ action_id: 'confirmed', replayed: true, report_version: 4, target_state: null, account_state: null });
    const { user } = open(client);
    await user.click(await screen.findByRole('button', { name: 'Retirar publicación' }));
    await user.type(screen.getByLabelText('Motivo de la decisión'), 'Contenido riesgoso.');
    await user.click(screen.getByRole('button', { name: 'Confirmar acción' }));
    expect(await screen.findByText(/No recibimos una confirmación/)).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Suspender cuenta' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Cerrar expediente' })).toBeDisabled();
    expect(screen.getByLabelText('Motivo de la decisión')).toBeDisabled();
    await user.click(screen.getByRole('button', { name: 'Reintentar misma acción' }));
    await waitFor(() => expect(client.reportAction).toHaveBeenCalledTimes(2));
    const calls = vi.mocked(client.reportAction!).mock.calls;
    expect(calls[1][0]).toEqual(calls[0][0]);
    expect(calls[0][0].request_id).toMatch(/^[0-9a-f-]{36}$/);
  });
  it('blocks double click and escape while a mutation is pending', async () => {
    const client = api(); const pending = deferred<Awaited<ReturnType<NonNullable<AdminApi['reportAction']>>>>(); client.reportAction = vi.fn(() => pending.promise);
    const { user, close } = open(client);
    await user.click(await screen.findByRole('button', { name: 'Resolver reporte' }));
    await user.type(screen.getByLabelText('Motivo de la decisión'), 'La revisión terminó.');
    await user.dblClick(screen.getByRole('button', { name: 'Confirmar acción' }));
    expect(client.reportAction).toHaveBeenCalledOnce();
    fireEvent(screen.getByRole('dialog'), new Event('cancel', { cancelable: true })); expect(close).not.toHaveBeenCalled();
    await act(async () => pending.resolve({ action_id: 'resolved', replayed: false, report_version: 4, target_state: null, account_state: null }));
  });
  it('reloads a conflict without success or reusing stale chat or confirmation', async () => {
    const client = api(); client.reportAction = vi.fn().mockRejectedValueOnce({ code: '40001' }); const { user, changed } = open(client);
    await user.click(await screen.findByRole('button', { name: 'Abrir conversación' })); await screen.findByText('Gracias por escribir.');
    await user.click(screen.getByRole('button', { name: 'Retirar publicación' })); await user.type(screen.getByLabelText('Motivo de la decisión'), 'Revisión de contenido.'); await user.click(screen.getByRole('button', { name: 'Confirmar acción' }));
    expect(await screen.findByText(/No se confirmó la acción/)).toBeInTheDocument();
    expect(changed).not.toHaveBeenCalled(); expect(screen.queryByText('Gracias por escribir.')).not.toBeInTheDocument();
    expect(screen.queryByLabelText('Motivo de la decisión')).not.toBeInTheDocument();
    await waitFor(() => expect(client.reportDetail).toHaveBeenCalledTimes(2));
  });
  it('keeps the report open after withdrawal and does not call a second resolution endpoint', async () => {
    const client = api(); const { user } = open(client);
    await user.click(await screen.findByRole('button', { name: 'Retirar publicación' }));
    await user.type(screen.getByLabelText('Motivo de la decisión'), 'Retiro por revisión.');
    await user.click(screen.getByRole('button', { name: 'Confirmar acción' }));
    expect(await screen.findByText(/Esta acción no resuelve el reporte/)).toBeInTheDocument();
    expect(client.reportAction).toHaveBeenCalledOnce();
    expect(vi.mocked(client.reportAction!).mock.calls[0][0].action).toBe('withdraw_publication');
  });
  it('allows cancellation without sending anything and explains closed reports', async () => {
    const client = api(); const { user } = open(client);
    await user.click(await screen.findByRole('button', { name: 'Descartar reporte' }));
    await user.type(screen.getByLabelText('Motivo de la decisión'), 'No debe enviarse.');
    await user.click(screen.getByRole('button', { name: 'Cancelar acción' }));
    expect(screen.queryByLabelText('Motivo de la decisión')).not.toBeInTheDocument(); expect(client.reportAction).not.toHaveBeenCalled();
  });
  it('retains readable context on resolved reports without reopening state decisions', async () => {
    const value = packet(); value.report.status = 'resolved'; value.report.resolution = 'Se atendió el reporte.'; const client = api(value); open(client);
    expect(await screen.findByText('Se atendió el reporte.')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Resolver reporte' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Descartar reporte' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Abrir conversación' })).toBeEnabled();
  });
  it('preserves a suspension action token for an eligible reactivation', async () => {
    const value = packet(); value.subject!.account_status = 'suspended'; value.subject!.active_suspension_action_id = 'previous-suspension'; value.capabilities.reactivate_account = { allowed: true, reason: null }; const client = api(value); const { user } = open(client);
    await user.click(await screen.findByRole('button', { name: 'Reactivar cuenta' })); await user.type(screen.getByLabelText('Motivo de la decisión'), 'La revisión permite reactivar.'); await user.click(screen.getByRole('button', { name: 'Confirmar acción' }));
    await waitFor(() => expect(client.reportAction).toHaveBeenCalledOnce());
    expect(vi.mocked(client.reportAction!).mock.calls[0][0]).toEqual(expect.objectContaining<Partial<ReportActionInput>>({ action: 'reactivate_account', expected_suspension_action_id: 'previous-suspension' }));
  });
});
