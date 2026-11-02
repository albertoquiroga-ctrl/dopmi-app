import type { CaseRevisionExpense, CaseRevisionPacket, InitialExpenseReview } from './api';
import type { ExpenseReviewDraft } from './initialCasePacket';

export type RevisionPacketCache = { identity: string; records: Record<string, CaseRevisionExpense> };
function stale(): never { throw { code: '40001', message: 'La edición del caso cambió. Recarga el expediente antes de continuar.' }; }
export function revisionPacketIdentity(packet: CaseRevisionPacket) {
  return JSON.stringify([packet.revision, packet.record, packet.base_record, packet.public_version_visible, packet.publication_blockers, packet.expense_ids, packet.expense_versions, packet.preserved_media]);
}
export function revisionPageIdentity(packet: CaseRevisionPacket) {
  return JSON.stringify([revisionPacketIdentity(packet), packet.expenses]);
}

export function mergeRevisionPacketPage(cache: RevisionPacketCache | null, packet: CaseRevisionPacket): RevisionPacketCache {
  const { revision, record, base_record: base, expenses: page, expense_ids: ids, expense_versions: versions } = packet;
  if (!revision || revision.status !== 'submitted' || !Number.isSafeInteger(revision.version) || revision.version < 1 ||
    typeof revision.reason !== 'string' || revision.reason.trim().length < 5 || record.kind !== 'case' || base.kind !== 'case' || !['approved','changes_requested'].includes(base.status) ||
    typeof packet.public_version_visible !== 'boolean' || packet.public_version_visible && base.status !== 'approved' ||
    !Array.isArray(packet.publication_blockers) || packet.publication_blockers.some(blocker => typeof blocker !== 'string') ||
    revision.case_id !== record.id || base.id !== record.id || revision.owner_id !== record.owner_id || base.owner_id !== record.owner_id ||
    revision.base_case_version !== base.version || record.version !== base.version || record.status !== base.status ||
    !Array.isArray(ids) || new Set(ids).size !== ids.length || !versions || Object.keys(versions).length !== ids.length ||
    ids.some(id => !Number.isSafeInteger(versions[id]) || versions[id] < 1) ||
    !page || !Number.isSafeInteger(page.page) || page.page < 1 || page.total !== ids.length) stale();
  const identity = revisionPacketIdentity(packet);
  if (cache && cache.identity !== identity) stale();
  const expected = ids.slice((page.page - 1) * 20, page.page * 20);
  if (page.page > Math.max(1, Math.ceil(page.total / 20)) || expected.length !== page.items.length ||
    page.items.some((expense, index) => expense.id !== expected[index] || expense.version !== versions[expense.id] ||
      expense.parent_id !== record.id || expense.owner_id !== record.owner_id || expense.kind !== 'expense' ||
      typeof expense.financial_locked !== 'boolean' || typeof expense.financial_inactive !== 'boolean' || expense.financial_inactive !== (expense.status !== 'approved') || !Array.isArray(expense.locked_fields) ||
      expense.locked_fields.some(field => typeof field !== 'string'))) stale();
  const records = { ...cache?.records };
  for (const expense of page.items) {
    if (records[expense.id] && JSON.stringify(records[expense.id]) !== JSON.stringify(expense)) stale();
    records[expense.id] = expense;
  }
  return { identity, records };
}

// The server supplies the amount for this revision. A text-only edit can retain
// a historical partial authorization; the client must never replace it with paid.
export function revisionExpenseReviews(packet: CaseRevisionPacket, records: Record<string, CaseRevisionExpense>, drafts: Record<string, ExpenseReviewDraft>, ready: (path: string) => boolean): InitialExpenseReview[] | null {
  if (Object.keys(records).length !== packet.expense_ids.length) return null;
  const reviews: InitialExpenseReview[] = [];
  for (const id of packet.expense_ids) {
    const record = records[id];
    if (!record || record.version !== packet.expense_versions[id] || typeof record.financial_inactive !== 'boolean' || record.financial_inactive !== (record.status !== 'approved')) return null;
    const paid = Number(record.private_data.amount_cents), amount = record.review_amount_cents;
    const priority = record.financial_locked || record.financial_inactive ? { urgent: record.urgent, urgency: record.priority_reason } : drafts[id] ?? { urgent: record.urgent, urgency: record.priority_reason };
    if (!Number.isSafeInteger(paid) || paid <= 0 || paid > 100000000 || !Number.isSafeInteger(amount) || (record.financial_inactive ? amount !== 0 : amount <= 0 || amount > paid) ||
      priority.urgent && priority.urgency.trim().length < 5 || !record.files.every(file => ready(file.path))) return null;
    reviews.push({ expense_id: id, expense_version: record.version, amount_cents: amount, is_urgent: priority.urgent,
      urgency_note: record.financial_inactive ? record.priority_reason : priority.urgent ? priority.urgency.trim() : '', publish_content: true });
  }
  return reviews;
}
