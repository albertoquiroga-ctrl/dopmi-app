// Pure planning only. Callers must obtain eligible, current expense balances on
// the server and repeat all eligibility and capacity checks when reserving funds.
export function planGuardianAllocation(netCents, expenses) {
  if (!Number.isSafeInteger(netCents) || netCents <= 0 || !Array.isArray(expenses)) {
    throw new TypeError('Invalid Guardian allocation input');
  }
  const seen = new Set();
  const eligible = [];
  for (const expense of expenses) {
    if (typeof expense?.id !== 'string' || !expense.id || seen.has(expense.id)
      || !Number.isSafeInteger(expense.available_cents) || expense.available_cents < 0
      || typeof expense.urgent !== 'boolean'
      || typeof expense.approved_at !== 'string'
      || !Number.isFinite(Date.parse(expense.approved_at))) {
      throw new TypeError('Invalid Guardian expense');
    }
    seen.add(expense.id);
    if (expense.payable === true && expense.available_cents > 0) eligible.push(expense);
  }
  eligible.sort((a, b) => Number(b.urgent) - Number(a.urgent)
    || Date.parse(a.approved_at) - Date.parse(b.approved_at)
    || (a.id < b.id ? -1 : a.id > b.id ? 1 : 0));

  let remaining = netCents;
  const allocations = [];
  for (const expense of eligible) {
    if (remaining === 0) break;
    const amount = Math.min(remaining, expense.available_cents);
    allocations.push({ expense_id: expense.id, amount_cents: amount });
    remaining -= amount;
  }
  // A partial plan cannot be charged: discard it altogether.
  return remaining === 0 ? { fully_allocated: true, allocations }
    : { fully_allocated: false, allocations: [] };
}

// Stripe's actual fee is only known after payment. A reservation holds the
// maximum possible net; trim its tail to the confirmed net without silently
// changing the approved expense order. The database must repeat eligibility
// and balance checks under its rescuer locks before recording any transfer.
export function trimGuardianReservation(netCents, reservedCents, allocations) {
  if (!Number.isSafeInteger(netCents) || netCents <= 0
    || !Number.isSafeInteger(reservedCents) || reservedCents < netCents
    || !Array.isArray(allocations) || allocations.length === 0)
    throw new TypeError('Invalid Guardian reservation');
  const seen = new Set();
  let total = 0;
  for (const allocation of allocations) {
    if (typeof allocation?.expense_id !== 'string' || !allocation.expense_id
      || seen.has(allocation.expense_id) || !Number.isSafeInteger(allocation.amount_cents)
      || allocation.amount_cents <= 0)
      throw new TypeError('Invalid Guardian allocation');
    seen.add(allocation.expense_id);
    total += allocation.amount_cents;
    if (!Number.isSafeInteger(total)) throw new TypeError('Invalid Guardian allocation');
  }
  if (total !== reservedCents) throw new TypeError('Invalid Guardian reservation');
  let remaining = netCents;
  const trimmed = [];
  for (const allocation of allocations) {
    if (!remaining) break;
    const amount = Math.min(remaining, allocation.amount_cents);
    trimmed.push({ expense_id: allocation.expense_id, amount_cents: amount });
    remaining -= amount;
  }
  if (remaining) throw new TypeError('Invalid Guardian reservation');
  return trimmed;
}
