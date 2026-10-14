import { guardianMonthlyAnchor } from './guardian-schedule.mjs';

// New registrations only. Always derive from the original anniversary, never
// from a clamped February date or the date of a delayed first contribution.
export function guardianRegistrationEvaluation(registeredAt, cycleNumber) {
  const { config } = guardianMonthlyAnchor(registeredAt);
  if (!Number.isSafeInteger(cycleNumber) || cycleNumber < 1 || cycleNumber > 1200)
    throw new RangeError('guardian_registration_cycle_invalid');
  const origin = new Date(registeredAt * 1000);
  const month = origin.getUTCMonth() + cycleNumber;
  const lastDay = new Date(Date.UTC(origin.getUTCFullYear(), month + 1, 0)).getUTCDate();
  return Date.UTC(origin.getUTCFullYear(), month, Math.min(config.day_of_month, lastDay),
    config.hour, config.minute, config.second) / 1000;
}
