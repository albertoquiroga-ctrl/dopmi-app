import type { ContentReport } from './api';

export type ReportCursor = { before_time: string; before_id: string };
export type ReportPerson = {
  id: string; name: string; account_status: string; created_at: string; city: string;
  published_adoptions_count: number; reports_received_count: number;
};
export type ReportSubject = ReportPerson & {
  account_updated_at: string; active_suspension_action_id: string | null;
};
export type ReportCapability = { allowed: boolean; reason: string | null };
export type ReportState = Record<string, unknown> | string | null;
export type ReportAction = 'reviewing' | 'resolve' | 'dismiss' | 'withdraw_publication' | 'suspend_account' | 'reactivate_account';
export type ReportDetail = {
  report: ContentReport & { version: number; reported_at: string; cutoff_basis: 'reported_at' | 'legacy_created_at' };
  reporter: ReportPerson | null;
  subject: ReportSubject | null;
  content: {
    kind: 'adoption' | 'case' | 'rescuer'; id: string; title: string; status: string; version: number;
    description: string; city: string; region: string; public_photos: string[]; public_url: string | null; current_snapshot: true;
  } | null;
  conversation: {
    available: boolean; reason: string | null; cutoff: string;
    threads: { id: string; post_id: string; pet_name: string; message_count_before_cutoff: number }[];
  };
  capabilities: { withdraw_publication: ReportCapability; suspend_account: ReportCapability; reactivate_account: ReportCapability };
  history: {
    id: string; actor_name: string; action: string; reason: string; created_at: string;
    previous_state: ReportState; next_state: ReportState;
  }[];
};
export type ReportMessages = {
  report_id: string; report_version: number; thread_id: string; cutoff: string;
  items: { id: string; sender_id: string; sender_role: 'reporter' | 'subject'; body: string; has_attachment: boolean; created_at: string }[];
  next_cursor: ReportCursor | null;
};
export type ReportActionInput = {
  report_id: string; expected_version: number; action: ReportAction; reason: string; request_id: string;
  expected_target_version?: number | null; expected_account_updated_at?: string | null; expected_suspension_action_id?: string | null;
};
export type ReportActionResult = {
  action_id: string; replayed: boolean; report_version: number; target_state: ReportState; account_state: ReportState;
};
export type ReportModerationApi = {
  reportDetail: (id: string) => Promise<ReportDetail>;
  reportConversation: (id: string, version: number, threadId: string, cursor?: ReportCursor) => Promise<ReportMessages>;
  reportAction: (input: ReportActionInput) => Promise<ReportActionResult>;
};
type ReportRpcClient = {
  rpc: (name: string, args: Record<string, unknown>) => PromiseLike<{ data: unknown; error: unknown }>;
};

export function createReportModerationApi(client: ReportRpcClient): ReportModerationApi {
  async function call<T>(name: string, args: Record<string, unknown>, missing: string): Promise<T> {
    const { data, error } = await client.rpc(name, args);
    if (error) throw error;
    if (data === null || data === undefined) throw new Error(missing);
    return data as T;
  }
  return {
    reportDetail(id) {
      return call('dopmi_admin_report_detail', { report_id: id }, 'No se recibió el expediente');
    },
    reportConversation(id, version, threadId, cursor) {
      return call('dopmi_admin_report_conversation', {
        report_id: id, expected_report_version: version, thread_id: threadId,
        before_time: cursor?.before_time ?? null, before_id: cursor?.before_id ?? null,
      }, 'No se recibió la conversación');
    },
    reportAction(input) {
      return call('dopmi_admin_report_action', {
        report_id: input.report_id, expected_version: input.expected_version, action: input.action,
        reason: input.reason, request_id: input.request_id,
        expected_target_version: input.expected_target_version ?? null,
        expected_account_updated_at: input.expected_account_updated_at ?? null,
        expected_suspension_action_id: input.expected_suspension_action_id ?? null,
      }, 'No se recibió la confirmación de la acción');
    },
  };
}
