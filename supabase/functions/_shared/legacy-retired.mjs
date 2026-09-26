// Shared tombstone for pre-pivot endpoints. No provider, database or environment access.
export function legacyRetiredResponse(request) {
  const headers = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
    'Access-Control-Allow-Methods': 'GET, POST, PUT, PATCH, DELETE, OPTIONS',
    'Cache-Control': 'no-store',
  };
  if (request.method === 'OPTIONS') return new Response(null, {status:204,headers});
  return new Response(JSON.stringify({
    error:'legacy_endpoint_retired',
    message:'Esta función pertenece a una versión anterior de Dopmi. Actualiza la app para continuar.',
  }), {status:410,headers:{...headers,'Content-Type':'application/json; charset=utf-8'}});
}
