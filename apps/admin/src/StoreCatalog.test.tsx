import {render,screen,fireEvent} from '@testing-library/react';
import {describe,it,expect,vi} from 'vitest';
import StoreCatalog from './StoreCatalog';

describe('Store catalog',()=>{
 it('edits a merchant through the server without exposing an activation control',async()=>{
   const api={list:vi.fn().mockResolvedValue({enabled:false,merchants:[],products:[]}),save:vi.fn().mockResolvedValue({}),remove:vi.fn()};
   render(<StoreCatalog api={api}/>);
   expect(await screen.findByText(/Tienda oculta/)).toBeInTheDocument();
   fireEvent.change(screen.getByLabelText('Nombre'),{target:{value:'Comercio autorizado'}});
   fireEvent.change(screen.getByLabelText('Dominio autorizado'),{target:{value:'shop.example'}});
   fireEvent.click(screen.getByRole('button',{name:'Guardar comercio'}));
   expect(await screen.findByText('Cambios guardados.')).toBeInTheDocument();
   expect(api.save).toHaveBeenCalledWith('merchant',expect.objectContaining({data:expect.objectContaining({name:'Comercio autorizado',domain:'shop.example',enabled:false})}));
   expect(screen.queryByRole('button',{name:/Activar/})).not.toBeInTheDocument();
 });
 it('shows server validation errors and preserves the editor for correction',async()=>{
   const api={list:vi.fn().mockResolvedValue({enabled:false,merchants:[],products:[]}),save:vi.fn().mockRejectedValue({message:'Falta revisión comercial'}),remove:vi.fn()};
   render(<StoreCatalog api={api}/>);
   fireEvent.change(screen.getByLabelText('Nombre'),{target:{value:'Borrador'}});
   fireEvent.click(screen.getByRole('button',{name:'Guardar comercio'}));
   expect(await screen.findByRole('alert')).toHaveTextContent('Falta revisión comercial');
   expect(screen.getByLabelText('Nombre')).toHaveValue('Borrador');
 });
 it('retains the confirmed ID/version if refreshing the list fails after saving',async()=>{
   const state={enabled:false,merchants:[],products:[]};
   const api={list:vi.fn().mockResolvedValueOnce(state).mockRejectedValueOnce(new Error('offline')).mockResolvedValue(state),save:vi.fn().mockResolvedValueOnce({id:'confirmed',version:1}).mockResolvedValueOnce({id:'confirmed',version:2}),remove:vi.fn()};
   render(<StoreCatalog api={api}/>);
   await screen.findByRole('button',{name:'Nuevo comercio'});
   fireEvent.change(screen.getByLabelText('Nombre'),{target:{value:'Comercio guardado'}});
   fireEvent.click(screen.getByRole('button',{name:'Guardar comercio'}));
   expect(await screen.findByRole('alert')).toHaveTextContent('Los cambios se guardaron');
   fireEvent.click(screen.getByRole('button',{name:'Guardar comercio'}));
   expect(await screen.findByText('Cambios guardados.')).toBeInTheDocument();
   expect(api.save).toHaveBeenLastCalledWith('merchant',expect.objectContaining({id:'confirmed',version:1}));
 });
 it('reuses a preassigned creation UUID after a lost save response',async()=>{
   const state={enabled:false,merchants:[],products:[]};
   const api={list:vi.fn().mockResolvedValue(state),save:vi.fn().mockRejectedValueOnce(new Error('lost response')).mockResolvedValue({id:'recovered',version:1}),remove:vi.fn()};
   render(<StoreCatalog api={api}/>);
   fireEvent.change(screen.getByLabelText('Nombre'),{target:{value:'Comercio'}});
   fireEvent.click(screen.getByRole('button',{name:'Guardar comercio'}));
   await screen.findByRole('alert');
   fireEvent.click(screen.getByRole('button',{name:'Guardar comercio'}));
   await screen.findByText('Cambios guardados.');
   const first=api.save.mock.calls[0][1];
   expect(first.id).toMatch(/^[0-9a-f-]{36}$/);
   expect(api.save.mock.calls[1][1]).toEqual(first);
 });
});
