import { act, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import App from './App';
import { type AdminApi, type AdminUser, type Contribution } from './api';
const person: AdminUser = { id: 'one', display_name: 'Ana López', email: 'ana@example.test', phone: '', city: 'Monterrey', active_mode: 'donor', account_status: 'active', created_at: '2026-09-13T12:00:00Z', email_confirmed_at: '2026-09-13T12:00:00Z', last_sign_in_at: null };
const donation = {
  id: 'donation-one',
  donor_id: 'one',
  donor_name: 'Ana López',
  donor_email: 'ana@example.test',
  status: 'allocated',
  processor: 'stripe',
  expense_title: 'Medicamentos',
  payment_status: 'confirmed',
  transfer_status: 'pending',
  refund_status: 'none',
  stripe_charge_id: 'ch_1',
  stripe_transfer_id: null,
  gross_cents: 10000,
  stripe_fee_cents: 600,
  platform_fee_cents: 200,
  net_cents: 9200,
  allocated_cents: 9200,
  refund_cents: 0,
  created_at: '2026-09-13T12:00:00Z',
  updated_at: '2026-09-13T12:01:00Z',
  processed_at: '2026-09-13T12:01:00Z',
} satisfies Contribution;
function api(overrides: Partial<AdminApi> = {}): AdminApi {
  return {
    listRescue: async () => ({ total: 0, items: [] }),
    rescueDetail: async () => { throw new Error('unused'); },
    reviewRescue: async (record) => record,
    rescueFileUrl: async () => 'https://example.test/file',
    session: vi.fn(async () => true),
    watch: () => () => {},
    login: vi.fn(async () => {}),
    logout: vi.fn(async () => {}),
    isAdmin: vi.fn(async () => true),
    listUsers: vi.fn(async () => ({ total: 1, users: [person] })),
    listAdoptions: vi.fn(async () => ({ total: 0, items: [] })),
    reviews: vi.fn(async () => []),
    reviewAdoption: vi.fn(async (post) => post),
    photoUrl: vi.fn(async () => 'https://example.test/photo'),
    listContributions: vi.fn(async () => ({ total: 0, items: [] })),
    ...overrides,
  };
}
describe('administración de usuarios', () => {
  it('does not query users before the server authorizes the account', async () => {
    const client = api({ isAdmin: vi.fn(async () => false) }); render(<App api={client} />);
    await screen.findByText('Esta cuenta no tiene acceso'); expect(client.listUsers).not.toHaveBeenCalled();
  });
  it('shows a real sign-in failure without exposing internal errors', async () => {
    const client = api({ session: vi.fn(async () => false), login: vi.fn(async () => { throw { code: 'invalid_credentials' }; }) });
    render(<App api={client} />); const user = userEvent.setup();
    await user.type(await screen.findByLabelText('Correo electrónico'), 'ana@example.test');
    await user.type(screen.getByLabelText('Contraseña'), 'incorrecta'); await user.click(screen.getByRole('button', { name: 'Iniciar sesión' }));
    await screen.findByText('Revisa tu correo y contraseña.'); expect(client.listUsers).not.toHaveBeenCalled();
  });
  it('searches through the protected API and opens an accessible profile', async () => {
    const client = api(); render(<App api={client} />); const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Ver perfil de Ana López' }));
    expect(screen.getByRole('dialog')).toBeInTheDocument(); await user.click(screen.getByRole('button', { name: 'Cerrar' }));
    await user.type(screen.getByLabelText('Buscar por nombre o correo'), 'Ana'); await user.click(screen.getByRole('button', { name: 'Buscar' }));
    await waitFor(() => expect(client.listUsers).toHaveBeenLastCalledWith('Ana', 1));
  });
  it('clears user data when the next request is denied', async () => {
    const list = vi.fn().mockResolvedValueOnce({ total: 1, users: [person] }).mockRejectedValue({ code: '42501' });
    render(<App api={api({ listUsers: list })} />); const user = userEvent.setup();
    await screen.findByText('Ana López'); await user.click(screen.getByRole('button', { name: 'Buscar' }));
    await screen.findByRole('alert'); expect(screen.queryByText('ana@example.test')).not.toBeInTheDocument();
  });
  it('shows configuration rather than fabricated users when disconnected', () => { render(<App api={null} />); expect(screen.getByText('Conecta el panel a Dopmi')).toBeInTheDocument(); });
  it('navega y consulta la cola de aportes', async () => {
    const listContributions = vi.fn(async () => ({ total: 1, items: [donation] }));
    const client = api({ listContributions });
    render(<App api={client} />); const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Aportes' }));
    expect(await screen.findByRole('heading', { name: 'Aportes' })).toBeInTheDocument();
    await waitFor(() => expect(listContributions).toHaveBeenCalledWith('all', 1));
  });
  it('starts Google without password fields, blocks duplicate clicks and recovers from a safe error', async () => {
    let rejectGoogle!: (cause: unknown) => void;
    const loginWithGoogle = vi.fn(() => new Promise<void>((_resolve, reject) => { rejectGoogle = reject; }));
    const client = api({ session: vi.fn(async () => false), loginWithGoogle });
    render(<App api={client} />); const user = userEvent.setup();
    await user.dblClick(await screen.findByRole('button', { name: 'Continuar con Google' }));
    expect(loginWithGoogle).toHaveBeenCalledTimes(1);
    expect(client.login).not.toHaveBeenCalled();
    expect(screen.getByRole('button', { name: 'Iniciar sesión' })).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Conectando con Google…' })).toBeDisabled();
    await act(async () => rejectGoogle(new Error('provider_token=private-fixture')));
    expect(await screen.findByRole('alert')).toHaveTextContent('No pudimos completar el acceso con Google.');
    expect(screen.queryByText(/private-fixture/)).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Continuar con Google' })).toBeEnabled();
    expect(screen.getByRole('button', { name: 'Iniciar sesión' })).toBeEnabled();
    loginWithGoogle.mockResolvedValueOnce(undefined);
    await user.click(screen.getByRole('button', { name: 'Continuar con Google' }));
    expect(loginWithGoogle).toHaveBeenCalledTimes(2);
  });
  it('keeps the Google latch after success while navigation is still pending', async () => {
    const loginWithGoogle = vi.fn(async () => {});
    render(<App api={api({ session: vi.fn(async () => false), loginWithGoogle })} />); const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Continuar con Google' }));
    const pending = screen.getByRole('button', { name: 'Conectando con Google…' });
    expect(pending).toBeDisabled();
    expect(screen.getByRole('button', { name: 'Iniciar sesión' })).toBeDisabled();
    await user.click(pending);
    expect(loginWithGoogle).toHaveBeenCalledTimes(1);
  });
  it('recovers the login on a real Back return without automatically starting OAuth again', async () => {
    const loginWithGoogle = vi.fn(async () => {});
    render(<App api={api({ session: vi.fn(async () => false), loginWithGoogle })} />); const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Continuar con Google' }));
    await act(async () => window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: false })));
    expect(screen.getByRole('button', { name: 'Conectando con Google…' })).toBeDisabled();
    await act(async () => window.dispatchEvent(new PageTransitionEvent('pageshow', { persisted: true })));
    expect(screen.getByRole('button', { name: 'Continuar con Google' })).toBeEnabled();
    expect(screen.getByRole('button', { name: 'Iniciar sesión' })).toBeEnabled();
    expect(loginWithGoogle).toHaveBeenCalledTimes(1);
    await user.click(screen.getByRole('button', { name: 'Continuar con Google' }));
    expect(loginWithGoogle).toHaveBeenCalledTimes(2);
  });
  it.each([true, false])('rechecks the server after a Google auth event (membership %s)', async allowed => {
    let onAuthChange!: () => void;
    const session = vi.fn().mockResolvedValueOnce(false).mockResolvedValue(true);
    const client = api({ session, watch: callback => { onAuthChange = callback; return () => {}; }, loginWithGoogle: vi.fn(async () => {}), isAdmin: vi.fn(async () => allowed) });
    render(<App api={client} />); const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Continuar con Google' }));
    expect(client.isAdmin).not.toHaveBeenCalled();
    expect(client.listUsers).not.toHaveBeenCalled();
    await act(async () => onAuthChange());
    if (allowed) await screen.findByRole('heading', { name: 'Usuarios' });
    else await screen.findByText('Esta cuenta no tiene acceso');
    expect(client.isAdmin).toHaveBeenCalledTimes(1);
    if (allowed) expect(client.listUsers).toHaveBeenCalledTimes(1);
    else expect(client.listUsers).not.toHaveBeenCalled();
  });
  it('shows a failed callback on the login form instead of trapping the user on verification', async () => {
    const client = api({ session: vi.fn().mockRejectedValue({ code: 'google_sign_in_failed', message: 'private-fixture' }), loginWithGoogle: vi.fn(async () => {}) });
    render(<App api={client} />);
    expect(await screen.findByRole('alert')).toHaveTextContent('No pudimos completar el acceso con Google.');
    expect(screen.getByRole('button', { name: 'Continuar con Google' })).toBeEnabled();
    expect(screen.getByRole('button', { name: 'Iniciar sesión' })).toBeEnabled();
    expect(client.isAdmin).not.toHaveBeenCalled(); expect(client.listUsers).not.toHaveBeenCalled();
  });
});
