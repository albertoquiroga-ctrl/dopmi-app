/** Conservative editorial validation; PostgreSQL remains authoritative. */
export function exactMerchantUrl(value, domain) {
  try {
    const url = new URL(value);
    return url.protocol === 'https:' && /^[a-z0-9]+(?:[.-][a-z0-9]+)*\.[a-z]{2,}$/i.test(domain)
      && url.hostname === domain && !url.username && !url.password && !url.port
      && !/redirect|return_url|returnurl|destination|[?&](?:url|next|target)=/i.test(value)
      && !url.hash && !/[\s\\]/.test(value);
  } catch { return false; }
}

export function filterCatalog(items, filters = {}) {
  const result = items.filter(item => ['species', 'age', 'size', 'brand'].every(key => !filters[key] || item[key] === filters[key]));
  if (filters.sort === 'weight_asc' || filters.sort === 'weight_desc') {
    result.sort((a,b) => (a.weight_kg - b.weight_kg) * (filters.sort === 'weight_desc' ? -1 : 1) || a.id.localeCompare(b.id));
  } else result.sort((a,b) => (a.position ?? 0) - (b.position ?? 0) || a.id.localeCompare(b.id));
  return result;
}
