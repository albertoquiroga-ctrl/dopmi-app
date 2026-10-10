### 2026-10-04 — Parity loop 714: Match footer and horizontal drag

- Reference `irlanda/apoyar-detalle-perfil` revalidated at `a3c969cd9103fd46dc5cd886999912526ce75efb`.
- Source DOM at 377×300 with fonts ready: scroll container padding-bottom 100, match page padding-bottom 88, scrollHeight 679, scrollTop 379, last chat content bottom 111.96875. Align donor Match list bottom padding from 110 to 188; preserve real search and navigation.
- New gesture regression: dragging the horizontal favorites rail moves its scroll position, keeps `/messages`, and opens neither a pet route nor the contact confirmation.
- Scratch synchronized for the two edited files. Targeted community/thread search/match row tests: 39/39, terminal session 93256 exit 0 (12s). Analyze: session 52689 exit 0, no issues (36.1s). Match capture: session 11542 exit 0, 1/1 (8s), 14 valid PNGs with hashes archived in `docs/design-reviews/parity-loop714/captures.json`; only final normal empty capture visually inspected in this loop.
- This is component evidence, not full visual/device acceptance. Full gate remains loop709 and predates later edits. No physical Android device acceptance, Codemagic build, or Play publication claimed. User requests Codemagic only when the whole objective is complete.
