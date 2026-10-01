# THE LAST FOREST

**A 2D Platformer Exploring Deforestation, Reforestation Mechanics, and Climate Literacy**

Activity 5: Game Database Connectivity Prototype (Systems Fundamentals Lab, 1stBIT4120L)

## 1. Project title
The Last Forest (Capstone-based prototype)

## 2. Group number and members
- Group number: **[GROUP NUMBER]**
- Members: **[FULL NAME 1]**, **[FULL NAME 2]**, **[FULL NAME 3]**, **[FULL NAME 4]**

## 3. Short description
The Last Forest is a 2D platformer for Grade 4 learners (pilot school: Santa Rosa Elementary School Central 2). The player brings a burnt forest back to life over 4 stages:

1. Burnt Grove: collect seeds and plant trees.
2. Pest Control: protect young trees from pests.
3. Water Management: turn a lever so rain reaches dry land.
4. Forest Sanctuary: explore the restored forest.

Each stage starts with a 3-question pre-quiz and ends with the same post-quiz. Short climate fact cards appear while playing. All results are saved to a local SQLite database, which the game reads back to unlock stages and to show the player's **My Records** table.

## 4. Tools and technologies
| Tool | Use |
|---|---|
| Godot Engine 4.7 (GDScript), GL Compatibility renderer | Game engine and code |
| godot-sqlite 4.9 (GDExtension by 2shady4u) | SQLite connection from GDScript |
| Git + GitHub | Version control and submission |
| Python 3 + Pillow (optional) | Build tools in `the_last_forest/tools/`: art recolouring, level generation |

## 5. Database / storage option
**SQLite** (offline, a single file). It suits school computer labs that may not have internet.
- File location: `user://the_last_forest_eval.db`. On Windows this is `%APPDATA%\Godot\app_userdata\<project name>\`.
- Tables: `students`, `session_records`, `quiz_results` (schema in `the_last_forest/autoload/database_manager.gd`, constant `DDL`).
- If the SQLite add-on is missing, the game writes to a backup file (`user://eval_fallback.jsonl`) instead, so no session is lost.

## 6. How to run
1. Install **Godot 4.7** (standard version, not .NET).
2. Clone this repository and open the folder in Godot (Import → select `project.godot`).
3. **Settings (required once):** copy `local_settings.sample.cfg` to `local_settings.cfg` in the same folder, then set your own `teacher_pin` and a long random `lrn_salt`. The real file is git-ignored. Without it, the game runs on the sample values and prints a warning.
4. Press **F5** (Run Project).
5. Play → enter a 12-digit LRN (test example: `123456789012`), first name and grade/section → choose Stage 1.
6. Finish a stage (pre-quiz → grow the trees → walk through the green gate → post-quiz). The record is saved.
7. On **Stage Select**, press **My Records** to see the saved data read back from the database.
8. Teacher: Main Menu → Teacher → enter the PIN → **Export results (CSV)**.

Automated tests (optional):
```
godot --headless --path . -s res://tests/smoke_test.gd   # full play-through incl. save + retrieve: 74/74
godot --headless --path . -s res://tests/edge_test.gd    # edge cases: 28/28
python tests/static_check.py                              # paths, translations, secrets
```

## 7. What data is saved and retrieved
| When | What is SAVED | Function (file: `the_last_forest/autoload/database_manager.gd`) |
|---|---|---|
| Login | student code (salted SHA-256 hash of the LRN), grade/section, date | `register_student()` |
| After the pre-quiz | stage, pre-quiz score, time | `save_pre_quiz()` (called from `AppFlow.record_pre_quiz`) |
| After the post-quiz / stage finish | post-quiz score; seeds collected, trees grown, completion time, fact cards read, date | `save_post_quiz()`, `save_stage_record()` (called from `AppFlow.finish_stage`) |

| When | What is RETRIEVED | Where it is DISPLAYED |
|---|---|---|
| Login and Stage Select | highest stage completed (`get_highest_completed_stage()`) | Stage Select: which stages are unlocked or "Restored!" |
| My Records button | the player's last 8 attempts (`get_student_records()`, SQL `RECORDS_SQL`) | Stage Select → **My Records** table (stage, quiz before → after, trees, seeds, time, date) |
| Teacher export | all attempts, no names or LRNs (`export_eval_csv()`) | CSV file for the teacher/researchers |

**Not stored on purpose:** the student's name and raw LRN. These are personal data of minors under the Data Privacy Act of 2012 (RA 10173). The LRN is stored only as a salted hash.

## 8. Known limitations / unfinished parts
- Not yet tested on the actual school lab PCs, and no playtest with Grade 4 learners yet.
- Only jump and background-music sounds. Planting, quiz and stage-clear sounds are still to do.
- Environment art is recoloured from the Godot demo assets, and other sprites are generated placeholders.
- The Filipino translation still needs review by a teacher.
- The pre-test and post-test use the same 3 questions per stage, which still needs to be validated with our adviser.
- The Windows build must ship `local_settings.cfg` with the same salt on every PC.

## 9. References / tutorials used
- Godot Engine documentation: https://docs.godotengine.org/en/stable/
- Godot 2D Platformer Demo (MIT License; base project, player, tiles, props, background): https://github.com/godotengine/godot-demo-projects/tree/master/2d/platformer
- godot-sqlite by 2shady4u (MIT License): https://github.com/2shady4u/godot-sqlite
- Kenney Mini Square font (CC0): https://kenney.nl/assets/kenney-fonts
- SQLite documentation: https://www.sqlite.org/docs.html
- Republic Act No. 10173 (Data Privacy Act of 2012)
- AI assistance (cited as required): Claude (Anthropic) and Ziva (Godot AI agent) were used as coding assistants for parts of the code, tests and documentation. The group reviewed, modified and tested the work.

---
The original Godot demo README is kept in `docs/DEMO_README.md`. License: `LICENSE.md` (MIT, © Godot Engine contributors).
