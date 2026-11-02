import { render, screen, within } from '@testing-library/react';
import { expect, test, vi } from 'vitest';
import NeedFeedback, { validateNeedComments } from './NeedFeedback';
import type { NeedComment, NeedCommentInput } from './api';

const current:NeedComment={id:'event:planned:need',request_id:'request',case_id:'case',case_version:4,target_kind:'planned',target_id:'need',target_version:4,target_title:'Consulta',body:'Revisa el detalle <script>',created_at:'2026-11-02T10:00:00Z'};

test('matches comments by case, kind, ID and both versions; a reused ID stays in history',()=>{
  render(<NeedFeedback kind="planned" id="need" version={4} caseId="case" caseVersion={4} title="Consulta" comments={[current,{...current,id:'older',case_version:3,target_version:3,body:'Comentario de la necesidad anterior'},{...current,id:'unrelated',target_id:'different',body:'Mismo título, otro ID'},{...current,id:'different-kind',target_kind:'expense',body:'Otro tipo'}]} value="" disabled={false} editable onChange={vi.fn()}/>);
  expect(within(screen.getByRole('region',{name:'Comentarios guardados'})).getByText(current.body)).toBeInTheDocument();
  expect(within(screen.getByRole('region',{name:'Comentarios de versiones anteriores'})).getByText('Comentario de la necesidad anterior')).toBeInTheDocument();
  expect(screen.queryByText('Mismo título, otro ID')).not.toBeInTheDocument();
  expect(screen.queryByText('Otro tipo')).not.toBeInTheDocument();
  expect(document.querySelector('script')).toBeNull();
});

test('checks batch, Unicode body total and serialized UTF-8 size before saving',()=>{
  const comment:NeedCommentInput={target_kind:'planned',target_id:'need',target_version:4,body:'Revisa'};
  expect(validateNeedComments([comment])).toBeNull();
  expect(validateNeedComments([])).toContain('1 y 40');
  expect(validateNeedComments(Array.from({length:41},()=>comment))).toContain('1 y 40');
  expect(validateNeedComments([{...comment,body:' '.repeat(5)}])).toContain('1 y 1000');
  expect(validateNeedComments(Array.from({length:21},()=>({...comment,body:'x'.repeat(1000)})))).toContain('20000');
  expect(validateNeedComments(Array.from({length:20},()=>({...comment,body:'\u0001'.repeat(1000)})))).toContain('tamaño');
});
