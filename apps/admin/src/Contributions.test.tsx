import { render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import Contributions from './Contributions';
import { type Contribution, type AdminApi } from './api';

const donation: Contribution = {
  id: 'donation-one',
  donor_id: 'donor-one',
  donor_name: 'Ana López',
  donor_email: 'ana@example.test',
  status: 'allocated',
  processor: 'stripe',
  expense_title: 'Medicamentos para Luna',
  payment_status: 'confirmed',
  transfer_status: 'pending',
  refund_status: 'none',
  stripe_charge_id: 'ch_abc',
  stripe_transfer_id: null,
  gross_cents: 10000,
  stripe_fee_cents: 600,
  platform_fee_cents: 200,
  net_cents: 9200,
  allocated_cents: 9200,
  refund_cents: 0,
  created_at: '2026-09-13T12:00:00Z',
  updated_at: '2026-09-13T12:10:00Z',
  processed_at: '2026-09-13T12:10:00Z',
};

function client(overrides: Partial<AdminApi> = {}): AdminApi {
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
    listUsers: vi.fn(async () => ({ total: 0, users: [] })),
    listAdoptions: vi.fn(async () => ({ total: 0, items: [] })),
    reviews: vi.fn(async () => []),
    reviewAdoption: vi.fn(async (post) => post),
    photoUrl: vi.fn(async () => 'https://example.test/photo'),
    listContributions: vi.fn(async () => ({ total: 1, items: [donation] })),
    ...overrides,
  };
}

describe('contribuciones administrativas', () => {
  it('muestra la cola y los montos netos', async () => {
    render(<Contributions api={client()} />);
    expect(await screen.findByRole('heading', { name: 'Aportes' })).toBeInTheDocument();
    expect(await screen.findByText('Ana López')).toBeInTheDocument();
    expect(screen.getByText('$92.00')).toBeInTheDocument();
    expect(screen.getByText('Dopmi: $2.00')).toBeInTheDocument();
    expect(screen.getByText('Transferencia en proceso')).toBeInTheDocument();
  });

  it('recarga la cola cuando cambia filtro o se solicita refresco', async () => {
    const listContributions = vi.fn(async () => ({ total: 1, items: [] }));
    const api = client({ listContributions });
    render(<Contributions api={api} />);
    const user = userEvent.setup();

    await user.selectOptions(await screen.findByLabelText('Estado'), 'partial');
    await waitFor(() => expect(listContributions).toHaveBeenCalledWith('partial', 1));

    await user.click(screen.getByRole('button', { name: 'Actualizar' }));
    await waitFor(() => expect(listContributions).toHaveBeenCalledWith('partial', 1));
  });

  it('muestra error de administración y vuelve a intentar', async () => {
    const listContributions = vi.fn()
      .mockRejectedValueOnce({ code: '42501' })
      .mockResolvedValue({ total: 0, items: [] });
    render(<Contributions api={client({ listContributions })} />);

    await screen.findByRole('alert');
    await userEvent.setup().click(screen.getByRole('button', { name: 'Volver a intentar' }));
    await waitFor(() => expect(screen.queryByRole('alert')).not.toBeInTheDocument());
    expect(listContributions).toHaveBeenCalledTimes(2);
  });
});
