# THE LAST FOREST: Overhaul Guide (demo → capstone)

**Status:** everything below exists in `res://the_last_forest/` and was tested headless on Godot 4.4.1 (your project targets 4.7).
- **Tested:** every script and scene loads and instantiates. A scripted run covered: login, then Stage 1 (pre-quiz, fact cards, planting by holding E, milestone cards, post-quiz), then the database write, Stage Clear and Stage 2 unlocking. It also covered the Stage 3 water stream, Stage 2 pests and tree guards, the CSV export, and the no-SQLite backup mode.
- **Not tested:** the real godot-sqlite binary (GitHub was unreachable from my workspace; a stand-in ran the same SQL on real SQLite), and your Windows lab PCs.
- **Rollback:** git snapshot `f47e26f` holds the project exactly as it was before this overhaul.

---

## 0. Setup (in this order)

1. **Close any other AI agent session** (the Ziva addon) while you do this. Two agents writing the same files is how work gets lost.
2. Delete the three leftover git lock files in Explorer: `.git\HEAD.lock`, `.git\index.lock`, `.git\objects\maintenance.lock`.
3. In Godot: **AssetLib → search "Godot SQLite" (2shady4u) → Download → Install**, then restart the editor.
4. Open `res://the_last_forest/tools/setup_project_settings.gd` and choose **File → Run**. Then choose **Project → Reload Current Project**. This one run handles all of the following:
   - Autoloads, including the new DatabaseManager and AppFlow.
   - Removes the shoot and split-screen inputs, adds `interact` (E / gamepad Y), and adds Space to jump.
   - Names the physics layers, adds the `restoration` shader global, registers the EN/FIL translations, and sets the main scene to the Main Menu.
5. Before the pilot, change `LRN_SALT` in `database_manager.gd` and `TEACHER_PIN` in `main_menu.gd`.
6. Press F5. The Main Menu shows database readiness; when the SQLite extension is absent, student/session data uses the JSONL fallback and CSV export remains available.

---

## 1. Demo cleanup: what was removed and what replaced it

Checked against your actual demo code:

- **Enemy stomp-to-kill:** the demo had no stomp handler; its former bullet-driven destroy method is now removed.
- **Player invincibility:** it isn't a function you can switch off. The demo simply has no damage code anywhere.

Both are *additions* in the new game, not removals.

| Demo system | Files / nodes | Replacement |
|---|---|---|
| Gun + shooting | `player/gun.gd`, `Sprite2D/Gun`, `Gun/Shoot`, `Gun/Cooldown`, `ShootAnimation` timer, `UI/Fire` touch button | Not ported into `the_last_forest/player/forest_player.tscn` |
| Bullets / projectile physics | Former `player/bullet.*`, `bullet.webp`, `shoot.wav` | Removed. Pests flee when touched or when the player taps E nearby. |
| Weapon animations | `idle_weapon`, `jumping_weapon`, `run_weapon`, `standing_weapon_ready`, `falling_weapon` | Removed from the new player's AnimationLibrary. `crouch` is reused as the planting pose. |
| Shoot / split-screen inputs | `shoot`, `shoot_p1/p2`, `*_p1/p2`, `splitscreen`, `action_suffix` | Removed by the setup script. The new `interact` action is E / gamepad Y. |
| Invincibility | (no damage code) | `GameState` 3 hearts, `Hazard` areas, a kill plane, 1.2 s of invulnerability with blinking, and a gentle respawn that keeps your trees |
| Enemy + bullet kill | `enemy/*` | `pests/pest.gd` (Area2D, **non-lethal**): bump into it and it flies away. `TreeGuardPickup` + a guard on the sapling makes pests ignore that tree. |
| Coins / score | `level/coin.*`, `gui/coins_counter.*`, `coin_pickup.wav`, the `coin_collected` signal | `SeedPickup` → `GameState.add_seeds()` |
| Pause menu with coins and split-screen | `gui/pause_menu*.tscn/.gd`, `game.gd` | `ui/pause_overlay.gd` inside `hud.tscn` (uses pause ownership) |
| Game shells | `game_singleplayer.tscn`, `game_splitscreen.*` | `stages/stage_N_*.tscn` + `AppFlow` |

**How to delete the old files:** in Godot's FileSystem dock, right-click → Delete. Don't use Explorer: Godot shows you what still depends on each file.
- **Now stripped from active routes:** gun/projectile scripts, shoot input, coin pickup scripts and instances, and coin HUD counter. `player/player.tscn` delegates to the typed forest player. The four THE LAST FOREST scenes are the project entry route; the original sample assets remain in the repo for reference.
- **Keep:** `level/tileset.tres`, `level/tiles.webp`, `level/props/*`, `level/background/*`. You'll paint the real stage art with these.

---

## 2. Player state machine (`player/forest_player.gd`)

```
            jump                      land
GROUNDED ─────────▶ AIRBORNE ─────────────▶ GROUNDED
   │  interactor.is_busy() (E held on a target, on floor)
   ▼
PLANTING  – move input + jump IGNORED, x-velocity braked to 0, "crouch" anim
   │  hold complete / E released / jump (cancel)       → GROUNDED
any ── EventBus.player_damaged ──▶ HURT (0.35 s, input ignored, knockback from Hazard)
                                    └──▶ GROUNDED / AIRBORNE
```
Measured in the test: holding **right** during a hold moved the player **0.0 px**.

---

## 3. Database (`autoload/database_manager.gd`)

- **Path:** `user://the_last_forest_eval.db`. On Windows that's `%APPDATA%\Godot\app_userdata\The Last Forest\`.
- **Schema:** your exact columns, plus foreign keys, `CHECK` constraints (stage 1–4, no negative values) and two indexes. `PRAGMA user_version = 1`, WAL journal.

**API:**
- `init_db()`
- `register_student(lrn, name, grade_section) -> int`. Returns the existing ID if that LRN is already registered.
- `save_stage_record(student_id, stage_idx, seeds, trees, duration, tips) -> bool`
- `export_eval_csv() -> String`. Returns an absolute path in `user://exports/`.
- Extras the flow needs:
  - `save_pre_quiz(student_id, stage_idx, score) -> int quiz_id`
  - `save_post_quiz(quiz_id, student_id, stage_idx, score)`
  - `get_highest_completed_stage(student_id)`
  - `is_available()`

**Recorded fields:**
- **completion_time:** seconds of *actual play*. Pause-menu, fact-card and quiz time are excluded.
- **tips_viewed:** fact cards and climate tips shown during the stage.
- **seeds_collected:** seeds picked up. Starting seeds don't count.

**Export:** one row per stage attempt. It includes pre-score, post-score and gain, and never names or LRNs.

**If the extension is missing:** nothing crashes. Writes go to `user://eval_fallback.jsonl` and every stage stays unlocked.

**Privacy (RA 10173):**
- By default the `lrn` column stores a salted SHA-256 hash of the LRN, and `name` stays empty. The name only lives in memory for on-screen greetings.
- Set `STORE_IDENTIFIERS_IN_CLEAR = true` only if your adviser and the school require raw identifiers, with written consent.
- This is pseudonymisation, not anonymisation. Anyone with the salt and a class list can link rows back to children.

**Known schema limitation:** `quiz_results` has no `session_id`, so the export pairs quizzes to sessions by student, stage and time. That was tested correctly on a replay. If your panel asks, adding a `session_id` column is the clean fix.

---

## 4. Flow and stages

```
Main Menu ─Play─▶ LRN Login ─▶ Stage Select (unlock = highest cleared + 1)
   │Teacher (PIN) → Export CSV / Open folder
Stage N: PRE-QUIZ (no feedback) → intro fact → play → milestone facts
         → goal met → outro fact → POST-QUIZ (with feedback)
         → AppFlow.finish_stage(): DB write FIRST → Stage Clear (Next / Stage Select)
```
| Stage | Goal (matured trees) | Mechanic | Data file |
|---|---|---|---|
| 1 Burnt Grove | 5 | seeds, hold-E planting, ember hazard, checkpoint, CO2 facts | `stage/stages/stage_1_burnt_grove.tres` |
| 2 Pest Control | 4 | pests (bump to shoo), tree guards (barrier), revive wilted | `stage_2_pest_control.tres` |
| 3 Water Mgmt | 3 + dry land hydrated | a `WaterSource` stream; flip the `Diverter` lever to aim it into the `AridZone` (30 drops) | `stage_3_water.tres` |
| 4 Sanctuary | 1 | no new mechanic: recap + final quiz + ending screen | `stage_4_sanctuary.tres` |

The stage scenes are **playable greybox**: flat ground, placeholder art in `the_last_forest/art/`. Paint the real levels with `level/tileset.tres`. Put the ground on layer 5 and platforms on layer 4, and give tiles `environment/restoration.gdshader` so they turn from burnt to green.

---

## 5. UI scenes (already on disk, and they load in Godot)

| Scene | Script | Key nodes (`%` = unique name) |
|---|---|---|
| `ui/main_menu.tscn` | `main_menu.gd` | %PlayButton, %LanguageButton (EN⇄FIL), %TeacherButton, %QuitButton, %DbStatus, %TeacherPanel{%PinEdit, %ExportButton, %OpenFolderButton, %TeacherStatus, %CloseTeacherButton} |
| `ui/login.tscn` | `login.gd` | %LrnEdit (digits only, max 12), %NameEdit (optional), %GradeEdit, %ErrorLabel, %BackButton, %ContinueButton |
| `ui/stage_select.tscn` | `stage_select.gd` | %StudentLabel, Grid{%Stage1Button..%Stage4Button}, %BackButton, %LogoutButton |
| `ui/hud.tscn` | `gui/game_hud.gd` | %Hearts, %SeedLabel, %GuardBox/%GuardLabel, %WaterBox/%WaterLabel, %TreeLabel, %ObjectiveLabel, %HoldBar, %TipPanel/%TipLabel, FactCardPopup, QuizModal{%QuizHeader, %QuizProgress, %QuizImage, %QuizPrompt, %Choice1-3, %QuizFeedback}, PauseOverlay{%ResumeButton, %HoldToggle, %StageSelectButton} |
| `ui/stage_clear.tscn` | `stage_clear.gd` | %ClearTitle, %StatsLabel, %QuizLabel, %SavedLabel, %StageSelectButton, %NextButton |
| `ui/fact_card_popup.tscn` | `gui/fact_card_popup.gd` | %Title, %Image, %Body, %ListenButton, %CloseButton, %Voice |

All visible text is a translation key (`data/translations/ui.csv`, `facts.csv`), so the Language button switches every screen. **Have a teacher review the Filipino column.** I drafted it.

---

## 6. Assessment design choices (for your methodology chapter)

- **The pre-quiz gives no right/wrong feedback.** If it did, the pre-test would teach the answers and inflate the gain.
- **The pre-test and post-test use the same 3 items per stage.** That makes them comparable, but it also carries a testing effect, and it only measures *short-term* recall within one session. Consider a delayed post-test a week later.
- **Choice order is shuffled** per question, and input is locked for 0.8 s so button-mashing can't answer.
- **The login is teacher-assisted.** [Likely] Most Grade 1–4 learners don't know their 12-digit LRN.

## 7. Still open

- Real godot-sqlite on the lab PCs (64-bit Windows only). Run one full stage and one export on the actual machines before pilot day.
- Real level art, a sapling growth sprite set, and touch-button textures. The demo's touch buttons have no textures, so tablet play doesn't work yet.
- Abandoned attempts aren't recorded, because the schema only stores completed stages. Say so in your limitations section.
