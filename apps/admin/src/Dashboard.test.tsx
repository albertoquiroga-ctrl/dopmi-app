import { act, render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import Dashboard from './Dashboard';
import type { AdminApi } from './api';

function api(overrides: Partial<AdminApi> = {}): AdminApi {
  return {
    session: vi.fn(async () => true), watch: () => () => {},
    login: vi.fn(async () => {}), logout: vi.fn(async () => {}), isAdmin: vi.fn(async () => true),
    listUsers: vi.fn(async () => ({ total: 0, users: [] })),
    listAdoptions: vi.fn(async () => ({ total: 3, items: [] })),
    reviews: vi.fn(async () => []), reviewAdoption: vi.fn(async post => post), photoUrl: vi.fn(async () => ''),
    listRescue: vi.fn(async kind => ({ total: kind === 'case' ? 24 : 2, items: [] })),
    rescueDetail: vi.fn(async () => { throw new Error('not needed'); }),
    reviewRescue: vi.fn(async record => record), rescueFileUrl: vi.fn(async () => ''),
    listContributions: vi.fn(async () => ({ total: 0, items: [] })),
    ...overrides,
  };
}

describe('pending review dashboard', () => {
  it('uses first-page server totals, avoids per-record reads and opens the right case queue', async () => {
    const client = api(); const open = vi.fn();
    render(<Dashboard api={client} onOpen={open}/>);
    const cases = await screen.findByRole('button', { name: /Casos para apoyo.*24 pendientes/ });
    expect(within(cases).getByLabelText('24 pendientes')).toHaveTextContent('24');
    expect(client.listRescue).toHaveBeenCalledTimes(3);
    expect(client.listRescue).toHaveBeenCalledWith('case', 'submitted', 1);
    expect(client.listRescue).toHaveBeenCalledWith('verification', 'submitted', 1);
    expect(client.listRescue).toHaveBeenCalledWith('expense', 'submitted', 1);
    expect(client.listAdoptions).toHaveBeenCalledOnce();
    expect(client.listAdoptions).toHaveBeenCalledWith('submitted', 1);
    expect(client.rescueDetail).not.toHaveBeenCalled();
    expect(client.listUsers).not.toHaveBeenCalled();
    expect(screen.queryByRole('region', { name: 'Contenido y reportes' })).not.toBeInTheDocument();
    await userEvent.click(cases);
    expect(open).toHaveBeenLastCalledWith({ section: 'rescues', kind: 'case' });
    await userEvent.click(screen.getByRole('button', { name: /Sellos de refugio/ }));
    expect(open).toHaveBeenLastCalledWith({ section: 'rescues', kind: 'verification' });
  });

  it('keeps successful queues usable on a partial failure without presenting a failed count as zero', async () => {
    const listRescue = vi.fn<AdminApi['listRescue']>().mockImplementation(async kind => {
      if (kind === 'case') throw new Error('private-provider-message');
      return { total: 2, items: [] };
    });
    const client = api({ listRescue, listReports: vi.fn(async () => ({ total: 4, items: [] })) });
    render(<Dashboard api={client} onOpen={vi.fn()}/>);
    expect(await screen.findByRole('alert')).toHaveTextContent('No pudimos consultar: Casos para apoyo');
    expect(screen.queryByText(/private-provider-message/)).not.toBeInTheDocument();
    const cases = screen.getByRole('button', { name: /Casos para apoyo/ });
    expect(within(cases).getByLabelText('Recuento no disponible')).toHaveTextContent('—');
    expect(screen.getByRole('button', { name: /Mascotas en adopción.*3 pendientes/ })).toBeEnabled();
    expect(screen.getByRole('button', { name: 'Reportes: 4 pendientes' })).toBeEnabled();
    listRescue.mockImplementation(async kind => ({ total: kind === 'case' ? 1 : 2, items: [] }));
    await userEvent.click(screen.getByRole('button', { name: 'Actualizar pendientes' }));
    await waitFor(() => expect(screen.queryByRole('alert')).not.toBeInTheDocument());
    expect(screen.getByRole('button', { name: /Casos para apoyo.*1 pendiente/ })).toBeEnabled();
    expect(client.listReports).toHaveBeenCalledTimes(2);
  });

  it('discards an old API response after the authenticated source changes', async () => {
    let complete!: (value: { total: number; items: [] }) => void;
    const pending = new Promise<{ total: number; items: [] }>(resolve => { complete = resolve; });
    const previous = api({ listRescue: vi.fn(async kind => kind === 'case' ? pending : { total: 0, items: [] }) });
    const next = api({ listRescue: vi.fn(async () => ({ total: 1, items: [] })) });
    const { rerender } = render(<Dashboard api={previous} onOpen={vi.fn()}/>);
    rerender(<Dashboard api={next} onOpen={vi.fn()}/>);
    await screen.findByRole('button', { name: /Casos para apoyo.*1 pendiente/ });
    await act(async () => complete({ total: 999, items: [] }));
    expect(screen.getByRole('button', { name: /Casos para apoyo.*1 pendiente/ })).toBeInTheDocument();
    expect(screen.queryByText('999')).not.toBeInTheDocument();
  });

  it('treats an invalid total as unavailable and counts every optional moderation queue at page one', async () => {
    const client = api({
      listAdoptions: vi.fn(async () => ({ total: -1, items: [] })),
      listReports: vi.fn(async () => ({ total: 2, items: [] })),
      listCaseUpdates: vi.fn(async () => ({ total: 3, items: [] })),
      listRescuerProfiles: vi.fn(async () => ({ total: 4, items: [] })),
    });
    render(<Dashboard api={client} onOpen={vi.fn()}/>);
    expect(await screen.findByRole('alert')).toHaveTextContent('Mascotas en adopción');
    const moderation = screen.getByRole('region', { name: 'Contenido y reportes' });
    expect(within(moderation).getByLabelText('9 pendientes')).toBeInTheDocument();
    expect(within(moderation).getByRole('button', { name: 'Reportes: 2 pendientes' })).toBeEnabled();
    expect(within(moderation).getByRole('button', { name: 'Avances: 3 pendientes' })).toBeEnabled();
    expect(within(moderation).getByRole('button', { name: 'Perfiles públicos: 4 pendientes' })).toBeEnabled();
    expect(client.listReports).toHaveBeenCalledWith('open', 1);
    expect(client.listCaseUpdates).toHaveBeenCalledWith('submitted', 1);
    expect(client.listRescuerProfiles).toHaveBeenCalledWith('submitted', 1);
  });

  it('opens support directly without treating all support history as a pending count', async () => {
    const client = api({ listSupportRequests: vi.fn(async () => ({ total: 400, items: [] })) });
    const open = vi.fn();
    render(<Dashboard api={client} onOpen={open}/>);
    await screen.findByRole('button', { name: /Casos para apoyo.*24 pendientes/ });
    await userEvent.click(screen.getByRole('button', { name: 'Revisar soporte' }));
    expect(open).toHaveBeenCalledWith({ section: 'moderation', view: 'support' });
    expect(client.listSupportRequests).not.toHaveBeenCalled();
    expect(screen.queryByText('400')).not.toBeInTheDocument();
  });
  it('opens a pending report queue directly even when advances are empty', async () => {
    const client = api({
      listReports: vi.fn(async () => ({ total: 2, items: [] })),
      listCaseUpdates: vi.fn(async () => ({ total: 0, items: [] })),
      listRescuerProfiles: vi.fn(async () => ({ total: 0, items: [] })),
    });
    const open = vi.fn();
    render(<Dashboard api={client} onOpen={open}/>);
    const reports = await screen.findByRole('button', { name: 'Reportes: 2 pendientes' });
    await userEvent.click(reports);
    expect(open).toHaveBeenLastCalledWith({ section: 'moderation', view: 'reports' });
    await userEvent.click(screen.getByRole('button', { name: 'Avances: 0 pendientes' }));
    expect(open).toHaveBeenLastCalledWith({ section: 'moderation', view: 'updates' });
    await userEvent.click(screen.getByRole('button', { name: 'Perfiles públicos: 0 pendientes' }));
    expect(open).toHaveBeenLastCalledWith({ section: 'moderation', view: 'profiles' });
  });

  it('includes submitted paid expenses in the total and opens that queue when cases are clear', async () => {
    const client = api({
      listRescue: vi.fn(async kind => ({ total: kind === 'expense' ? 5 : 0, items: [] })),
      listAdoptions: vi.fn(async () => ({ total: 0, items: [] })),
    });
    const open = vi.fn();
    render(<Dashboard api={client} onOpen={open}/>);
    await screen.findByRole('heading', { name: '5 pendientes por revisar' });
    expect(screen.queryByRole('heading', { name: 'Estas colas están al día' })).not.toBeInTheDocument();
    await userEvent.click(screen.getByRole('button', { name: /Necesidades con comprobante.*5 pendientes/ }));
    expect(open).toHaveBeenLastCalledWith({ section: 'rescues', kind: 'expense' });
    expect(client.listRescue).toHaveBeenCalledWith('expense', 'submitted', 1);
  });

});
