import type { InitialCasePacket, InitialExpenseReview, RescueDetail, RescueRecord } from './api';

export type ExpenseReviewDraft = { pesos: string; urgent: boolean; urgency: string };
export type InitialPacketCache = { identity: string; records: Record<string, RescueRecord> };
export function initialPacketIdentity(record: RescueRecord, packet: InitialCasePacket) {
  return JSON.stringify([record.id, record.version, record.status, record.owner_id, packet]);
}
function stale(): never { throw { code: '40001', message: 'El paquete inicial cambió. Recarga el expediente antes de continuar.' }; }

// Membership comes only from the private frozen manifest. Pages must cover its
// exact ordered slice; partial or mixed pages never enable a financial decision.
export function mergeInitialPacketPage(cache: InitialPacketCache | null, detail: RescueDetail): InitialPacketCache {
  const packet = detail.initial_packet, page = detail.expenses;
  if (!packet || !page || detail.record.kind !== 'case' || detail.record.status !== 'submitted' ||
    packet.case_version !== detail.record.version || !Number.isInteger(page.page) || page.page < 1 ||
    page.total !== packet.expense_ids.length || new Set(packet.expense_ids).size !== packet.expense_ids.length) stale();
  const identity = initialPacketIdentity(detail.record, packet);
  if (cache && cache.identity !== identity) stale();
  const expected = packet.expense_ids.slice((page.page - 1) * 20, page.page * 20);
  if (page.page > Math.max(1, Math.ceil(page.total / 20)) || expected.length !== page.items.length ||
    page.items.some((expense, index) => expense.id !== expected[index] || expense.parent_id !== detail.record.id ||
      expense.owner_id !== detail.record.owner_id || expense.kind !== 'expense' || expense.submission_id !== packet.id)) stale();
  const records = { ...cache?.records };
  for (const expense of page.items) {
    if (records[expense.id] && JSON.stringify(records[expense.id]) !== JSON.stringify(expense)) stale();
    records[expense.id] = expense;
  }
  return { identity, records };
}

export function packetExpenseReviews(packet: InitialCasePacket, records: Record<string, RescueRecord>, drafts: Record<string, ExpenseReviewDraft>, ready: (path: string) => boolean, parseAmount: (text: string) => number | null): InitialExpenseReview[] | null {
  if (Object.keys(records).length !== packet.expense_ids.length) return null;
  const reviews: InitialExpenseReview[] = [];
  for (const id of packet.expense_ids) {
    const record = records[id], draft = drafts[id];
    if (!record || !draft || record.submission_id !== packet.id) return null;
    const cents = parseAmount(draft.pesos), paid = Number(record.private_data.amount_cents);
    if (cents === null || !Number.isSafeInteger(paid) || cents > paid ||
      (draft.urgent && draft.urgency.trim().length < 5) || !record.files.every(file => ready(file.path))) return null;
    reviews.push({ expense_id: id, expense_version: record.version, amount_cents: cents, is_urgent: draft.urgent,
      urgency_note: draft.urgent ? draft.urgency.trim() : '', publish_content: true });
  }
  return reviews;
}
