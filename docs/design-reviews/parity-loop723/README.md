### 2026-10-04 — Parity loop 723: Enlarged saved empty action flow

- Prior loop722 changed production CTA feedback and generated verified captures. Reference branch revalidated before/after at `a3c969cd9103fd46dc5cd886999912526ce75efb`.
- Added meaningful regression for the previously unproven enlarged empty CTA:320×640/text2.0, saved repository empty, scroll to actual FilledButton, hitTestable, offset>0; hold150ms then cancel asserts exact `/saved` route and unchanged saved scroll offset. Subsequent tap opens actual router `/adoptions` with no widget exception.
- Community1821 exit0:35/35 in11s. Analyze85221 exit0 clean32.2s. No production change required; existing scroll/navigation passes. Logs archived. This proves widget-level access/cancellation/navigation, not native phone gesture feel or full visual parity.
- Goal active; full mobile test count now expected788 but no new full gate run claimed. No Codemagic before complete objective, no real-money activation.
