import { PaymentError } from './payments.mjs';

// The registration SQL uses this exact exception only for an absent attempt.
// A 42501 from permissions/RLS is an operational fault, never proof of absence.
export function registrationPaymentReply(operation, result) {
  if (result.error) {
    if (operation === 'get' && result.error.code === '42501' &&
        result.error.message === 'Intento no disponible') return null;
    throw new PaymentError('guardian_database_unavailable', 503);
  }
  return result.data;
}
