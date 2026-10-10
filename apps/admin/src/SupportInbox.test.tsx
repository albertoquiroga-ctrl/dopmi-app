import {render,screen,waitFor} from '@testing-library/react';
import {describe,it,expect,vi} from 'vitest';
import SupportInbox from './SupportInbox';
import type {AdminApi} from './api';
import type {SupportPage} from './supportApi';
describe('Support inbox',()=>{
  it('loads a private attachment and renews its signed URL after an image failure',async()=>{
    const item={request_id:'photo',owner_id:'owner',topic:'account',case_name:'',message:'Foto del problema',display_name:'Ana',email:null,created_at:'2026-10-02',attachment_path:'owner/request/photo.jpg'};
    const sign=vi.fn().mockRejectedValueOnce(new Error('unavailable')).mockResolvedValueOnce('https://example.test/signed-photo');
    render(<SupportInbox api={{listSupportRequests:vi.fn().mockResolvedValue({total:1,items:[item]}),supportAttachmentUrl:sign} as unknown as AdminApi}/>);
    expect(await screen.findByRole('alert')).toHaveTextContent('No pudimos cargar');
    screen.getByRole('button',{name:'Reintentar imagen'}).click();
    expect(await screen.findByRole('img',{name:'Imagen adjunta a la solicitud'})).toHaveAttribute('src','https://example.test/signed-photo');
    expect(sign).toHaveBeenCalledTimes(2);
    expect(sign).toHaveBeenCalledWith(item.attachment_path);
  });
  it('renders authored content as text and supplies a response link without claiming a reply was sent',async()=>{
    const list=vi.fn().mockResolvedValue({total:1,items:[{request_id:'one',owner_id:'owner',topic:'guardian',case_name:'Luna',message:'<script>privado</script>',display_name:'Ana',email:'ana@example.test',created_at:'2026-10-02T10:00:00Z'}]});
    render(<SupportInbox api={{listSupportRequests:list} as unknown as AdminApi}/>);
    expect(await screen.findByText('<script>privado</script>')).toBeInTheDocument();
    expect(document.querySelector('script')).toBeNull();
    expect(list).toHaveBeenCalledWith(1);
    expect(screen.getByRole('link',{name:'Responder por correo'})).toHaveAttribute('href',expect.stringContaining('mailto:'));
    expect(screen.getByRole('button',{name:'Siguiente'})).toBeDisabled();
  });
  it('drops an obsolete response when the API changes and shows authorization failure',async()=>{
    let resolve!:(value:SupportPage)=>void;
    const old={listSupportRequests:()=>new Promise<SupportPage>(done=>{resolve=done;})} as unknown as AdminApi;
    const view=render(<SupportInbox api={old}/>);
    view.rerender(<SupportInbox api={{listSupportRequests:vi.fn().mockRejectedValue({code:'42501'})} as unknown as AdminApi}/>);
    expect(await screen.findByRole('alert')).toHaveTextContent('acceso administrativo');
    resolve({total:1,items:[{request_id:'one',owner_id:'owner',topic:'account',message:'obsolete private content',case_name:'',display_name:'Ana',email:null,created_at:'2026-10-02'}]});
    await waitFor(()=>expect(screen.queryByText('obsolete private content')).not.toBeInTheDocument());
  });
});
