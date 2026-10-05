import { fireEvent, render, screen, waitFor } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import Adoptions from './Adoptions';
import type { Adoption, AdminApi } from './api';
import { coexistenceLabels, personalityLabels, type AdoptionReview } from './adoptionReviewTraits';

const post: Adoption = { id: 'post-one', owner_id: 'owner', pet_name: 'Luna', species: 'dog', sex: 'female', age_months: 24, size: 'medium', breed: 'Mestiza', city: 'Monterrey', region: 'Nuevo León', story: 'Necesita una familia paciente.', special_care: '', publisher_name: 'Refugio Luna', publisher_bio: 'Acompañamos adopciones.', vaccinated: true, sterilized: null, social_dogs: true, social_cats: null, social_children: false, photos: ['private/photo.jpg'], status: 'submitted', version: 7, review_feedback: '', submitted_at: '2026-09-13T20:00:00Z', updated_at: '2026-09-13T20:00:00Z' };
function client(overrides: Partial<AdminApi> = {}): AdminApi {
  return { listRescue: async () => ({total:0,items:[]}), rescueDetail: async () => { throw new Error('unused'); }, reviewRescue: async (record) => record, rescueFileUrl: async () => 'https://example.test/file', session: vi.fn(async () => true), watch: () => () => {}, login: vi.fn(async () => {}), logout: vi.fn(async () => {}), isAdmin: vi.fn(async () => true), listUsers: vi.fn(async () => ({ total: 0, users: [] })), listAdoptions: vi.fn(async () => ({ total: 1, items: [post] })), reviews: vi.fn(async () => []), photoUrl: vi.fn(async () => 'https://example.test/signed-photo'), listContributions: vi.fn(async () => ({ total: 0, items: [] })), reviewAdoption: vi.fn(async () => ({ ...post, status: 'published', version: 8 })), ...overrides };
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
  it('exposes every new and legacy authored personality and home label before review', async () => {
    const reviewed: AdoptionReview = {
      ...post, age_band: 'adult', coexistence: Object.keys(coexistenceLabels),
      personality: Object.keys(personalityLabels),
    };
    const api = client({ listAdoptions: vi.fn(async () => ({ total: 1, items: [reviewed] })) });
    const user = await open(api);
    expect(screen.getByText('Adulto')).toBeInTheDocument();
    for (const label of new Set(Object.values(personalityLabels))) {
      expect(screen.getByText(label)).toBeInTheDocument();
    }
    for (const label of Object.values(coexistenceLabels)) {
      expect(screen.getByText(label)).toBeInTheDocument();
    }
    expect(screen.getAllByText('Tranquilo')).toHaveLength(1);
    await user.click(screen.getByRole('button', { name: 'Aprobar publicación' }));
    await waitFor(() => expect(api.reviewAdoption).toHaveBeenCalledWith(reviewed, 'published', ''));
  });
  it('keeps a missing legacy age category unselected instead of inferring it from months', async () => {
    const reviewed: AdoptionReview = { ...post, age_months: 180, age_band: null };
    const api = client({ listAdoptions: vi.fn(async () => ({ total: 1, items: [reviewed] })) });
    await open(api);
    expect(screen.getByText('180 meses · Mediano')).toBeInTheDocument();
    expect(screen.getByText('Sin seleccionar')).toBeInTheDocument();
    expect(screen.queryByText('Senior')).not.toBeInTheDocument();
    expect(screen.queryByText('Adulto')).not.toBeInTheDocument();
    expect(screen.getByText('Sin rasgos seleccionados')).toBeInTheDocument();
    expect(screen.getByText('Sin preferencias seleccionadas')).toBeInTheDocument();
  });
  it.each([['puppy', 'Cachorro'], ['adult', 'Adulto'], ['senior', 'Senior']])('uses explicit age category %s without changing authored months', async (value, label) => {
    const reviewed: AdoptionReview = { ...post, age_months: 0, age_band: value };
    await open(client({ listAdoptions: vi.fn(async () => ({ total: 1, items: [reviewed] })) }));
    expect(screen.getByText(label)).toBeInTheDocument();
    expect(screen.getByText('0 meses · Mediano')).toBeInTheDocument();
  });
  it('requires all six image elements to load before approving the exact reviewed version', async () => {
    const reviewed: AdoptionReview = { ...post, photos: Array.from({ length: 6 }, (_, i) => `private/photo-${i}.jpg`) };
    // Equal URLs also occur for duplicate paths in legacy drafts; each image
    // element must still finish loading instead of sharing a URL-based counter.
    const api = client({ listAdoptions: vi.fn(async () => ({ total: 1, items: [reviewed] })) });
    render(<Adoptions api={api} />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Revisar Luna' }));
    await screen.findByAltText('Foto 6 de Luna');
    const approve = screen.getByRole('button', { name: 'Aprobar publicación' });
    expect(approve).toBeDisabled();
    for (let i = 1; i <= 5; i++) fireEvent.load(screen.getByAltText(`Foto ${i} de Luna`));
    fireEvent.load(screen.getByAltText('Foto 1 de Luna'));
    expect(approve).toBeDisabled();
    expect(api.reviewAdoption).not.toHaveBeenCalled();
    fireEvent.load(screen.getByAltText('Foto 6 de Luna'));
    expect(approve).toBeEnabled();
    await user.click(approve);
    await waitFor(() => expect(api.reviewAdoption).toHaveBeenCalledWith(reviewed, 'published', ''));
    expect(api.photoUrl).toHaveBeenCalledTimes(6);
  });
  it('reloads all six photos after a failed image and discards the previous loaded count', async () => {
    const reviewed = { ...post, photos: Array.from({ length: 6 }, (_, i) => `private/photo-${i}.jpg`) };
    const api = client({ listAdoptions: vi.fn(async () => ({ total: 1, items: [reviewed] })) });
    render(<Adoptions api={api} />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Revisar Luna' }));
    await screen.findByAltText('Foto 6 de Luna');
    for (let i = 1; i <= 6; i++) fireEvent.load(screen.getByAltText(`Foto ${i} de Luna`));
    fireEvent.error(screen.getByAltText('Foto 6 de Luna'));
    expect(screen.getByRole('button', { name: 'Aprobar publicación' })).toBeDisabled();
    await user.click(screen.getByRole('button', { name: 'Recargar fotos e historial' }));
    await waitFor(() => expect(api.photoUrl).toHaveBeenCalledTimes(12));
    await screen.findByAltText('Foto 6 de Luna');
    expect(screen.getByRole('button', { name: 'Aprobar publicación' })).toBeDisabled();
    for (let i = 1; i <= 5; i++) fireEvent.load(screen.getByAltText(`Foto ${i} de Luna`));
    expect(screen.getByRole('button', { name: 'Aprobar publicación' })).toBeDisabled();
    fireEvent.load(screen.getByAltText('Foto 6 de Luna'));
    expect(screen.getByRole('button', { name: 'Aprobar publicación' })).toBeEnabled();
    expect(api.reviewAdoption).not.toHaveBeenCalled();
  });
  it('cannot approve a draft that contains no photos', async () => {
    const api = client({ listAdoptions: vi.fn(async () => ({ total: 1, items: [{ ...post, photos: [] }] })) });
    render(<Adoptions api={api} />);
    const user = userEvent.setup();
    await user.click(await screen.findByRole('button', { name: 'Revisar Luna' }));
    await screen.findByText('La publicación necesita una foto antes de aprobarse.');
    expect(screen.getByRole('button', { name: 'Aprobar publicación' })).toBeDisabled();
    expect(api.reviewAdoption).not.toHaveBeenCalled();
  });
});
