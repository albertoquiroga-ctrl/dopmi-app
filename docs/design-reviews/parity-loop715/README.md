### 2026-10-04 — Parity loop 715: Help group line height

- Reference branch revalidated at `a3c969cd9103fd46dc5cd886999912526ce75efb`. Fresh Source DOM at 377×852, fonts ready, confirms group labels line-height 18.6px, measured height 18.59375 and y 165.09375 / 331.6875.
- Set help group label height to 1.55 at font size 12, matching Source inherited paragraph styling while allowing natural growth at enlarged text. No FAQ, financial rule or support behavior changed.
- Chip rows move from y 191/235/279/357/401 to 192/236/280/359/403. Source rows 191.6875/235.6875/279.6875/358.28125/402.28125. Absolute differences improve from .6875 and 1.28125 to .3125 and .71875 respectively; fractional line-box rounding remains, so exact visual parity is not claimed.
- Help navigation/dialog/route tests session 48637 exit 0: 14/14 (4s), including 2.0 text scale. Analyze session 98608 exit 0: clean (39.5s). Help captures session 65499 exit 0: 1/1 (13s), 19 valid PNGs hashed; large initial help screen visually inspected. Geometry archived in this review folder.
- Previous loop714 made verified progress (commit `672e541`). Objective remains active; global visual, motion and device acceptance is incomplete. No Codemagic until objective completion.
