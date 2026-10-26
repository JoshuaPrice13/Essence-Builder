# Essence-Builder

Make essence combinations based on the *He Who Fights With Monsters* series: name an essence user, bond three essences, receive the confluence, awaken stones, and see a build sheet. Every power is written by the player's own AI, and finished builds can be published to a public registry and browsed by everyone.

Live site (after Pages is enabled): https://joshuaprice13.github.io/Essence-Builder/

## How it works

- **Static site.** `index.html` is generated from `src/template.html` and `src/data.json` by `python3 tools/build.py`. Commit the regenerated `index.html`.
- **AI login, no keys.** Players sign in with [Puter](https://puter.com) and choose a model (Claude, GPT, Gemini, ...). Power-writing requests go to their own account and usage. The site never asks for, sees or stores an API key.
- **Public registry.** Published builds are stored in a Supabase table that anyone can read and add to, but not edit or delete. The Browse page lists them and opens any build read-only.

## Setup

1. **GitHub Pages:** Settings > Pages > Build and deployment > Deploy from a branch > `main` / `(root)`. See the [Pages quickstart](https://docs.github.com/en/pages/quickstart).
2. **Database:** create a free [Supabase](https://supabase.com) project, open the SQL editor and run `supabase/schema.sql`.
3. **Connect it:** put the project URL and publishable (anon) key in `config.js` and commit. Both are meant to be public; row-level security limits what the key can do.

Until `config.js` is filled in, the builder still works but publishing and browsing are switched off.

## Notes

- Anyone can add rows to a public table. If it gets spammed, delete rows in the Supabase dashboard or tighten the insert policy.
- Essence and confluence data come from the series wiki and community confluence sheet; unknown-rarity essences are left out of the picker.
