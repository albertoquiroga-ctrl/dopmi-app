import test from 'node:test';
import assert from 'node:assert/strict';
import { exactMerchantUrl, filterCatalog } from '../../supabase/functions/_shared/store-catalog.mjs';

test('only HTTPS links on the exact merchant domain are accepted', () => {
  assert.equal(exactMerchantUrl('https://shop.example/a?affiliate=dopmi', 'shop.example'), true);
  for (const url of ['http://shop.example/a', 'https://shop.example.evil/a', 'https://user@shop.example/a', 'https://shop.example:8443/a', 'https://shop.example/redirect?url=https://evil.test']) {
    assert.equal(exactMerchantUrl(url, 'shop.example'), false, url);
  }
});

test('filters use the product brand and sort by numeric kilograms', () => {
  const rows = [
    {id:'a', species:'dog', age:'adult', size:'small', brand:'Marca real', weight_kg:10},
    {id:'b', species:'dog', age:'adult', size:'small', brand:'Marca real', weight_kg:2},
    {id:'c', species:'cat', age:'adult', size:'small', brand:'Otra', weight_kg:1},
  ];
  assert.deepEqual(filterCatalog(rows,{species:'dog',brand:'Marca real',sort:'weight_asc'}).map(x=>x.id),['b','a']);
  assert.deepEqual(filterCatalog(rows,{brand:'Inexistente'}),[]);
});
