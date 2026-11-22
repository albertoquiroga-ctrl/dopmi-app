import { describe, expect, it, vi } from 'vitest';
import { createReportModerationApi } from './reportModeration';

describe('frontera de expedientes de reportes', () => {
  it('pide contexto sólo por el reporte, sin aceptar IDs de personas desde el cliente', async () => {
    const detail = { report: { id: 'report-1', version: 3 } };
    const rpc = vi.fn().mockResolvedValue({ data: detail, error: null });
    const api = createReportModerationApi({ rpc });
    await expect(api.reportDetail('report-1')).resolves.toEqual(detail);
    expect(rpc).toHaveBeenCalledOnce();
    expect(rpc).toHaveBeenCalledWith('dopmi_admin_report_detail', { report_id: 'report-1' });
  });

  it('envía versión y cursor estable al leer únicamente el hilo autorizado', async () => {
    const rpc = vi.fn().mockResolvedValue({ data: { items: [], next_cursor: null }, error: null });
    const api = createReportModerationApi({ rpc });
    await api.reportConversation('report-1', 3, 'thread-1');
    expect(rpc).toHaveBeenLastCalledWith('dopmi_admin_report_conversation', {
      report_id: 'report-1', expected_report_version: 3, thread_id: 'thread-1', before_time: null, before_id: null,
    });
    await api.reportConversation('report-1', 3, 'thread-1', { before_time: '2026-11-22T10:20:30.123456Z', before_id: 'message-1' });
    expect(rpc).toHaveBeenLastCalledWith('dopmi_admin_report_conversation', {
      report_id: 'report-1', expected_report_version: 3, thread_id: 'thread-1',
      before_time: '2026-11-22T10:20:30.123456Z', before_id: 'message-1',
    });
  });

  it('conserva exactamente el intento de sanción y sus tokens de concurrencia', async () => {
    const receipt = { action_id: 'action-1', replayed: true, report_version: 4, account_state: 'active', target_state: 'published' };
    const rpc = vi.fn().mockResolvedValue({ data: receipt, error: null });
    const api = createReportModerationApi({ rpc });
    const input = {
      report_id: 'report-1', expected_version: 3, action: 'reactivate_account' as const,
      reason: 'Revisión concluida', request_id: 'same-request', expected_target_version: 7,
      expected_account_updated_at: '2026-11-22T10:20:30.123456Z', expected_suspension_action_id: 'suspension-1',
    };
    await expect(api.reportAction(input)).resolves.toEqual(receipt);
    expect(rpc).toHaveBeenCalledWith('dopmi_admin_report_action', input);
    expect(input.request_id).toBe('same-request');
  });

  it('no transforma rechazo de acceso ni falta de respuesta en éxito', async () => {
    const denied = { code: '42501', message: 'Acceso administrativo requerido' };
    const rpc = vi.fn().mockResolvedValueOnce({ data: null, error: denied }).mockResolvedValueOnce({ data: null, error: null });
    const api = createReportModerationApi({ rpc });
    await expect(api.reportDetail('report-1')).rejects.toBe(denied);
    await expect(api.reportDetail('report-1')).rejects.toThrow('No se recibió el expediente');
    expect(rpc).toHaveBeenCalledTimes(2);
  });
});
