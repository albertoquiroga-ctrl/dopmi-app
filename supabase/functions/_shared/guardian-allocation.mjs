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
