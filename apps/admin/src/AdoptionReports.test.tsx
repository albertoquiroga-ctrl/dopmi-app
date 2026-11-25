import { render, screen, waitFor, within } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import AdoptionReports from './AdoptionReports';
import { createAdoptionReportReader, type AdoptionReportPage } from './adoptionReportApi';
import type { SupabaseClient } from '@supabase/supabase-js';

const page: AdoptionReportPage = {
  total: 21, generated_at: '2026-11-25T20:00:00Z', detail_tracking_started_at: '2026-11-25T18:00:00Z',
  items: [{ id: 'pet-one', pet_name: 'Luna', species: 'dog', publisher_name: 'Patricia', city: 'Monterrey', region: 'Nuevo León', published_at: null,
    detail_viewers: 12, current_favorites: 4, contacts: 3, first_replies: 2 }],
};
describe('reportes de adopciones', () => {
  it('shows distinct detail people, current favorites, contacts and first replies with their definitions', async () => {
    render(<AdoptionReports api={{ adoptionReport: vi.fn(async () => page) }} />);
    const row = within(await screen.findByRole('row', { name: /Luna/ }));
    for (const count of ['12', '4', '3', '2']) expect(row.getByRole('cell', { name: count })).toBeInTheDocument();
    expect(screen.getByText(/sólo adopciones publicadas/i)).toBeInTheDocument();
    expect(screen.getByText(/Una persona cuenta una vez por mascota/i)).toBeInTheDocument();
    expect(screen.getByText(/no se incluyen vistas anteriores/i)).toBeInTheDocument();
  });
  it('queries server pagination and resets the page when applying name and species filters', async () => {
    const read = vi.fn(async () => page);
    render(<AdoptionReports api={{ adoptionReport: read }} />);
    const user = userEvent.setup();
    await screen.findByText('Luna');
    await user.click(screen.getByRole('button', { name: 'Siguiente' }));
    await waitFor(() => expect(read).toHaveBeenLastCalledWith('', '', 2));
    await user.type(screen.getByLabelText('Buscar mascota o rescatista'), 'Michi');
    await user.selectOptions(screen.getByLabelText('Especie'), 'cat');
    await user.click(screen.getByRole('button', { name: 'Filtrar' }));
    await waitFor(() => expect(read).toHaveBeenLastCalledWith('Michi', 'cat', 1));
  });
  it('clears prior counts on denial and supports retry without displaying false zeroes', async () => {
    const read = vi.fn().mockResolvedValueOnce(page).mockRejectedValueOnce({ code: '42501' }).mockResolvedValueOnce({ ...page, total: 0, items: [] });
    render(<AdoptionReports api={{ adoptionReport: read }} />);
    const user = userEvent.setup(); await screen.findByText('Luna');
    await user.click(screen.getByRole('button', { name: 'Actualizar' }));
    await screen.findByRole('alert'); expect(screen.queryByText('Luna')).not.toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Siguiente' })).toBeDisabled();
    await user.click(screen.getByRole('button', { name: 'Volver a intentar' }));
    await screen.findByText('No hay adopciones publicadas');
  });
  it('ignores stale responses after the user changes the query', async () => {
    let finish!: (value: AdoptionReportPage) => void;
    const read = vi.fn().mockImplementationOnce(() => new Promise(resolve => { finish = resolve; })).mockResolvedValue({ ...page, total: 0, items: [] });
    render(<AdoptionReports api={{ adoptionReport: read }} />);
    const user = userEvent.setup(); await user.type(screen.getByLabelText('Buscar mascota o rescatista'), 'Otro');
    await user.click(screen.getByRole('button', { name: 'Filtrar' }));
    await screen.findByText('No encontramos coincidencias');
    finish(page); await waitFor(() => expect(screen.queryByText('Luna')).not.toBeInTheDocument());
  });
  it('uses the aggregate RPC and rejects malformed counts rather than treating them as zero', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: page, error: null });
    const read = createAdoptionReportReader({ rpc } as unknown as SupabaseClient);
    expect(await read('Luna', 'dog', 2)).toEqual(page);
    expect(rpc).toHaveBeenCalledWith('dopmi_admin_adoption_report', { search_text: 'Luna', species_filter: 'dog', page_number: 2 });
    rpc.mockResolvedValue({ data: { ...page, items: [{ ...page.items[0], detail_viewers: null }] }, error: null });
    await expect(read('', '', 1)).rejects.toThrow('invalid_response');
  });
});
