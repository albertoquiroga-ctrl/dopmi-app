import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import Adoptions from './Adoptions';
import type { Adoption, AdminApi } from './api';

const post: Adoption = { id: 'post-one', owner_id: 'owner', pet_name: 'Luna', species: 'dog', sex: 'female', age_months: 24, size: 'medium', breed: 'Mestiza', city: 'Monterrey', region: 'Nuevo León', story: 'Necesita una familia paciente.', special_care: '', publisher_name: 'Refugio Luna', publisher_bio: 'Acompañamos adopciones.', vaccinated: true, sterilized: null, social_dogs: true, social_cats: null, social_children: false, photos: ['private/photo.jpg'], status: 'submitted', version: 7, review_feedback: '', submitted_at: '2026-09-13T20:00:00Z', updated_at: '2026-09-13T20:00:00Z' };
function client(overrides: Partial<AdminApi> = {}): AdminApi {
  return { session: vi.fn(async () => true), watch: () => () => {}, login: vi.fn(async () => {}), logout: vi.fn(async () => {}), isAdmin: vi.fn(async () => true), listUsers: vi.fn(async () => ({ total: 0, users: [] })), listAdoptions: vi.fn(async () => ({ total: 1, items: [post] })), reviews: vi.fn(async () => []), photoUrl: vi.fn(async () => 'https://example.test/signed-photo'), reviewAdoption: vi.fn(async () => ({ ...post, status: 'published', version: 8 })), ...overrides };
}
async function open(api: AdminApi) {
  render(<Adoptions api={api} />); const user = userEvent.setup();
  await user.click(await screen.findByRole('button', { name: 'Revisar Luna' }));
  fireEvent.load(await screen.findByAltText('Foto 1 de Luna'));
  return user;
}
describe('adoption moderation', () => {
  it('submits the exact reviewed version and refreshes the queue', async () => {
    const api = client(); const user = await open(api);
    await user.click(screen.getByRole('button', { name: 'Aprobar publicación' }));
    await waitFor(() => expect(api.reviewAdoption).toHaveBeenCalledWith(post, 'published', ''));
    await waitFor(() => expect(api.listAdoptions).toHaveBeenCalledTimes(2));
    expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });
  it('requires an explanation for corrections and preserves it on a stale review', async () => {
    const api = client({ reviewAdoption: vi.fn(async () => { throw { code: '40001' }; }) }); const user = await open(api);
    await user.click(screen.getByRole('button', { name: 'Pedir correcciones' }));
    expect(api.reviewAdoption).not.toHaveBeenCalled();
    await user.type(screen.getByLabelText('Respuesta para el responsable'), 'Aclara los cuidados que necesita.');
    await user.click(screen.getByRole('button', { name: 'Pedir correcciones' }));
    await screen.findByText('La publicación cambió. Cierra el detalle y actualiza la lista antes de revisarla otra vez.');
    expect(screen.getByLabelText('Respuesta para el responsable')).toHaveValue('Aclara los cuidados que necesita.');
  });
  it('does not approve when the reviewer cannot load a photo', async () => {
    const api = client({ photoUrl: vi.fn(async () => { throw new Error('offline'); }) }); render(<Adoptions api={api} />); const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Revisar Luna' }));
    await screen.findByRole('alert'); expect(screen.getByRole('button', { name: 'Aprobar publicación' })).toBeDisabled();
    expect(api.reviewAdoption).not.toHaveBeenCalled();
  });
  it('removes private detail and queue when server access is revoked', async () => {
    const api = client({ reviewAdoption: vi.fn(async () => { throw { code: '42501' }; }) }); const user = await open(api);
    await user.click(screen.getByRole('button', { name: 'Aprobar publicación' }));
    await screen.findByRole('alert'); expect(screen.queryByText('Refugio Luna')).not.toBeInTheDocument(); expect(screen.queryByRole('dialog')).not.toBeInTheDocument();
  });
});
