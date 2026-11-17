# THE LAST FOREST (v1.0.0)

**The Last Forest: A 2D Platform Exploring Deforestation, Reforestation Mechanics, and Climate Literacy**
IT 12 Capstone Project, BS Information Technology, University of Perpetual Help System Laguna

- **Researchers:** John Matthew T. Alaban, Zhedderic Ahlen L. Cañeda, Karl Andrei F. Ofler, Franz Chester A. Pabalan
- **Technical Adviser:** Mr. Jaime V. Yatco, MIT  •  **Instructor:** Grachel Greta

## 1. What it is
An offline, bilingual (English / Filipino) 2D platformer for Grade 3-4 learners, for **Android phones and tablets** and **Windows lab PCs**. The player is Eco-Ranger **Lunti**, who restores the burnt forest of Sierra Verde in four stages:

1. **Burnt Grove** - collect native seeds (Narra, Lauan, Dao) and grow 3 trees.
2. **Pest Control** - protect 6 saplings from leaf beetles and caterpillars with bamboo tree guards (pests are shooed, never hurt).
3. **Water Management** - turn the lever so the wooden sluice sends rain to the dry gully.
4. **Forest Sanctuary** - restore the last canopy; birds and butterflies return.

Every stage: 3-item pre-test > play with bilingual picture fact cards > same 3-item post-test > saved to SQLite.

## 2. Features
- Burnt-to-green restoration shader, returning wildlife, original pixel art and sound effects, story intro.
- **Leaf Journal** (saved per learner), **Forest Rangers Leaderboard** (Forest Points, nicknames or "Ranger #A9F2" codes only), **My Records**.
- **Teacher panel**: PIN created on first launch (stored as a salted hash, 5-try lockout), class dashboard (average before / after / gain / time per stage), CSV export (file on PC, clipboard on phones).
- Mobile: landscape lock, touch controls that fit any phone shape, pause button, Android Back button, "tap once to plant" option, language and volume settings.

## 3. Tools
| Tool | Use |
|---|---|
| Godot Engine 4.7 (GDScript, GL Compatibility) | Engine, Android + Windows export |
| godot-sqlite 4.9 (GDExtension, 2shady4u, MIT) | SQLite on Windows, Linux and Android (arm64) |
| Python 3 + Pillow | Scripts in `the_last_forest/tools/` that generate the pixel art, icons, sounds and document figures |
| Kenney UI Pack - Pixel Adventure (CC0) | Wooden/parchment panels, buttons, ribbons and bars of the whole UI theme |
| Git + GitHub | Version control |

## 4. Database (SQLite, schema v3)
File: `user://the_last_forest_eval.db` (Windows: `%APPDATA%\Godot\app_userdata\THE LAST FOREST\`).
Tables `students`, `quiz_results`, `session_records`, `journal_entries` - see `DDL` in `the_last_forest/autoload/database_manager.gd`. Older databases are upgraded automatically.

**Privacy (RA 10173):** names are never stored; the LRN is stored only as `"h:" + SHA-256(salt + LRN)`; the CSV has no names or LRNs; Android cloud backup of app data is off.

**Secrets:** `local_settings.cfg` (salt + teacher PIN) is git-ignored and never packed into the APK/EXE. On a new device the game creates it with a random salt and asks the teacher to create a PIN. For lab PCs that must share learner codes, put the same `local_settings.cfg` next to `TheLastForest.exe` on every PC (format: `local_settings.sample.cfg`).

## 5. How to run
1. Open `project.godot` in **Godot 4.7** and press **F5**, or install the exported build.
2. Play > story (first time) > enter a 12-digit LRN, optional nickname, grade & section > Stage 1.
3. Teacher: Main Menu > Teacher > create/enter the PIN > dashboard and export.

**Export:** Project > Export > `Android (Phones & Tablets)` or `Windows Desktop (Lab PCs)`. The Android release key is NOT in this repository; set it in Editor Settings or with the `GODOT_ANDROID_KEYSTORE_RELEASE_*` environment variables.

## 6. Tests
```
godot --headless --path . -s res://tests/smoke_test.gd          # 4-stage playthrough, save, records, CSV      74/74
godot --headless --path . -s res://tests/edge_test.gd           # edge cases, PIN lockout, rollback/retry       50/50
godot --headless --path . -s res://tests/production_test.gd     # v3 migration, leaderboard, journal, PIN hash  68/68
godot --headless --path . -s res://tests/reach_test.gd          # every target reachable on foot
godot --headless --path . -s res://tests/release_smoke_test.gd  # release smoke test
python tests/static_check.py                                     # paths, translations, secrets
```

## 7. Known limitations
- Must still be played on the school's real phones/tablets and lab PCs, and piloted with learners.
- One database per device; a forgotten PIN on Android can only be reset by clearing app data (export the CSV regularly).
- 3 test items per stage; Filipino text and fact sources need review by teachers.

## 8. References and credits
- Godot Engine docs: https://docs.godotengine.org/en/stable/
- Godot 2D Platformer Demo (MIT; base project, tiles, props, background, music): https://github.com/godotengine/godot-demo-projects/tree/master/2d/platformer
- godot-sqlite (MIT): https://github.com/2shady4u/godot-sqlite
- Kenney Mini Square font (CC0): https://kenney.nl/assets/kenney-fonts
- Kenney "UI Pack - Pixel Adventure" (CC0; panels, buttons, ribbons, bars): https://kenney.nl/assets/ui-pack-pixel-adventure - tiles used are copied to `the_last_forest/art/ui_kenney/` by `tools/import_kenney_ui.py`; the full pack folder is ignored by Godot (`.gdignore`)
- RA 10173 (Data Privacy Act of 2012), RA 9512 (Environmental Awareness and Education Act of 2008)
- **AI assistance (declared as required by the course):** AI coding assistants (Claude by Anthropic, Ziva, and Google Antigravity) were used for parts of the code, tests, art scripts and documentation. The group reviewed, modified and tested the work and is responsible for it.

Documents: `Defense_Guide_The_Last_Forest.docx`, `Draft_of_IT12_The_Last_Forest_-_CHAPTER_1.docx`, `docs/figures/`. Original demo README: `docs/DEMO_README.md`. License: `LICENSE.md` (MIT).
