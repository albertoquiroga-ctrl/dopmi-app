### 2026-10-04 — Parity loop 726: Saved remove glyph position

- Prior loop725 verified held render/cancellation. Reference revalidated start/end a3c969cd9103fd46dc5cd886999912526ce75efb.
- Source377×852/fonts ready, local mock empty toggle off and Rocky liked: saved row16/144.59375/345/95; name button96/171.59375/215/40; remove40px button321/171.59375;20px icon331/181.59375 center341/191.59375.
- New client telemetry confirms before icon center337/191, name96/173. Translate only adoption remove SVG+4px horizontally; target and behavior remain intact. Final geometry center341/191, name96/173. Horizontal equality proven, vertical difference .59375px and text/button linebox differences still pending. Different photo/name fixture prevents full visual-equivalence claim.
- Capturebefore17460 exit0,1/1 in6s; final33635 exit0,1/1 in6s, normal final inspected. Analyzer9224 exit0 clean38.7s. No new behavioral test run for glyph-only adjustment; existing community35 pass723 predates this change. Installed Android724 predates new adjustment. No native acceptance or Codemagic; goal active.
