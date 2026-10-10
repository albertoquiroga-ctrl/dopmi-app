import type { Adoption } from './api';

// Additive fields returned by the moderated adoption contract. Keeping this
// local preserves the existing API surface and the caller's changes in api.ts.
export type AdoptionReview = Adoption & {
  age_band?: string | null;
  coexistence?: readonly string[];
  personality?: readonly string[];
};

export const ageBandLabels: Record<string, string> = {
  puppy: 'Cachorro', adult: 'Adulto', senior: 'Senior',
};
export const coexistenceLabels: Record<string, string> = {
  children: 'Social con niños',
  pets: 'Social con otras mascotas',
  apartment: 'Ideal para departamento',
  yard: 'Necesita patio',
  first_time: 'Ideal para primerizos',
  experienced: 'Mejor para alguien con experiencia',
};
export const personalityLabels: Record<string, string> = {
  alegre: 'Alegre', playful: 'Juguetón', tranquilo: 'Tranquilo',
  nervioso: 'Nervioso', dormilon: 'Dormilón', protector: 'Protector',
  obediente: 'Obediente', affectionate: 'Cariñoso', timido: 'Tímido',
  calm: 'Tranquilo', active: 'Activo', sociable: 'Sociable',
  independent: 'Independiente', feliz: 'Feliz', esperanzado: 'Esperanzado',
  emocionado: 'Emocionado', triste: 'Triste', enojado: 'Enojado',
  ansioso: 'Ansioso', contento: 'Contento', satisfecho: 'Satisfecho', solo: 'Solo',
};

export function reviewTraitLabels(values: readonly string[] | undefined, labels: Record<string, string>): string[] {
  return [...new Set((values ?? []).map(value => labels[value] ?? `Dato no reconocido: ${value}`))];
}
