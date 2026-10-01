# THE LAST FOREST — Systems Architecture (Godot 4.x)

Base: official Godot 2D Platformer Demo (`platformer-2d-demo`, `config/features = 4.7`).
Code lives in `res://the_last_forest/` so the demo's own files stay recognisable.
All scripts parse on Godot 4.4.1 headless. A headless smoke test covered planting, wilt/revive, pause ownership, milestones and stage clear. **None of it has been run inside your real scenes yet.**

---

## 0. Read this first: problems found in your plan and the demo

| # | Issue | Evidence | Decision |
|---|---|---|---|
| 1 | **`ui_accept` must not be the plant key.** In this project **Space = `shoot`**, and `ui_accept` (Space/Enter) also presses whichever UI button has focus. One press would shoot, plant and close a card at the same time. | `project.godot` `[input] shoot` | New action **`interact`**: **E** + gamepad **Y (button 3)**, plus a touch button. |
| 2 | **The demo player cannot be hurt.** It has no health, no death and no fall-out-of-world handling. "Hearts" is a new system, not a small addition. | `project.godot` description; `player.gd` | Hearts live in `GameState`. Damage comes from `Hazard` and falling below `kill_y`. Losing all hearts only respawns you: trees are kept and hearts refill. |
| 3 | **Pause conflict.** `PauseMenu.close()` sets `get_tree().paused = false` directly, so closing the pause menu would unpause the game behind an open fact card. | `gui/pause_menu.gd` | All pausing goes through `GameState.request_pause(owner)` / `release_pause(owner)`. See the patches in §6. |
| 4 | **"Shooting bugs" sends the wrong ecological message** to 7–12-year-olds. | design | Pests **flee** when hit (they are not killed). The card is about *natural helpers* (ladybugs, birds). If you can, reskin the projectile as a water spray. |
| 5 | **Count trees that survive, not trees planted.** If the forest turns green as soon as a tree is planted, the game teaches the wrong lesson. In real reforestation, many seedlings die before they grow. | design | HUD shows *planted*. **Restoration and stage clear use *matured*.** |
| 6 | **"Primary" covers Grades 1–6.** A Grade 2 child and a Grade 6 child need very different text. | — | **You need to decide the pilot grade.** The system supports picture-first cards, voice-over and an English/Filipino toggle, but card text length depends on the grade. |
| 7 | **A capstone needs evidence that children learned something.** A game on its own does not prove that. | — | `SessionLog` writes anonymous CSVs. Pair them with a short pre/post test. You also need school and parent consent for research with minors. |
| 8 | **Every fact must be checked by a teacher.** One wrong fact can undermine your panel defence. | — | Each `ClimateFact` has a `source_note`. Avoid specific numbers (for example "kg of CO2 per tree"). |
| 9 | **Split-screen mode doubles the work.** Every counter, card and HUD element would need to handle two players. | `game_splitscreen.tscn` | Leave split-screen out of scope. Remove its button from the pause menu. |
| 10 | **The player scene already has touch buttons.** If the school uses tablets, hold-to-plant needs its own touch button. | `player.tscn` → `UI/Left, Right, Jump, Fire` | Add a `TouchScreenButton` with `action = "interact"`. |

**On the `SeedManager` autoload, I disagree**, because seeds, trees, water, hearts and milestones depend on each other. Planting spends a seed, and maturing a tree moves restoration and triggers milestones. If each lives in its own manager, those managers end up calling each other, which is the coupling you are trying to avoid.
Here's what I would do instead: have **one `GameState`** that owns all run data, plus **one `EventBus`** that only carries signals.
The risk in your approach is that `SeedManager`, `TreeManager` and `HealthManager` start referencing each other, and every rule change touches three files.

---

## 1. Scene tree architecture

### Autoloads (Project Settings → Globals, **in this order**)
```
Music             res://music.tscn                                  (existing)
EventBus          res://the_last_forest/autoload/Events.gd           signals only, no state
GameState         res://the_last_forest/autoload/game_state.gd       all counters + pause ownership
LearningDirector  res://the_last_forest/autoload/learning_director.gd  WHEN facts appear
SessionLog        res://the_last_forest/autoload/session_log.gd      anonymous CSV for evaluation
```
Order matters because `GameState` and `SessionLog` connect to `EventBus` in `_ready()`.

### Stage scene (one per stage; build `stage_base.tscn`, then use *New Inherited Scene* for each stage)
```
Game (Node, game.gd — patched)
├─ Level (Node2D, level.gd)
│  ├─ StageController (Node)            data = stage_X.tres, player, spawn_point
│  ├─ RestorationController (Node)
│  ├─ ParallaxBackground                 material: restoration.gdshader
│  ├─ TileMapLayer "Ground"             material: restoration.gdshader
│  ├─ TileMapLayer "Decor" (optional)   burnt stumps → group vanish_at_2 …
│  ├─ Props (Node2D)                    grass/trees: restoration_wind.gdshader
│  ├─ Pickups (Node2D)                  SeedPickup ×N, WaterDrop ×N
│  ├─ PlantingZones (Node2D)            PlantingZone ×N  (+ arid_zone link in Stage 3)
│  ├─ AridZones (Node2D)                Stage 3 only
│  ├─ PestSpawner (Node2D)              Stage 2 only; Marker2D children = spawn points
│  ├─ Hazards / Checkpoints / FactTriggers (Area2D)
│  ├─ SpawnPoint (Marker2D)
│  └─ Player (instance)
│     ├─ …existing nodes…
│     ├─ PlayerInteractor (Area2D, player_interactor.gd)
│     │  └─ CollisionShape2D  (RectangleShape2D ≈ 48×40)
│     └─ UI/Interact (TouchScreenButton, action = "interact")
└─ InterfaceLayer (CanvasLayer, layer 10)
   ├─ GameHUD (Control, full rect, game_hud.gd)
   │  ├─ TopLeft: %Hearts, %SeedLabel, %WaterBox/%WaterLabel
   │  ├─ TopRight: %TreeLabel ("3 / 5")
   │  ├─ %ObjectiveLabel, %TipPanel/%TipLabel, %HoldBar
   │  └─ FactCardPopup (instance, process_mode = Always)
   └─ PauseMenu (existing, patched)
```

### Reusable scenes to build
| Scene | Root | Script | Layers |
|---|---|---|---|
| `seed_pickup.tscn` | Area2D | `seed_pickup.gd` | layer none, **mask 1** |
| `planting_zone.tscn` | Area2D + `SaplingAnchor`, `Soil`, `Prompt` | `planting_zone.gd` | set in code (layer 6) |
| `sapling.tscn` | Area2D + `Sprite`, `ThirstyIcon`, `Prompt` | `sapling.gd` | set in code (layer 6) |
| `pest.tscn` | CharacterBody2D | `pest.gd` | **layer 7**, mask 0 |
| `water_drop.tscn` | Area2D | `water_drop.gd` | mask 1 |
| `arid_zone.tscn` | Area2D + `Ground`, `Meter`, `Prompt` | `arid_zone.gd` | set in code (layer 6) |
| `fact_card_popup.tscn`, `game_hud.tscn` | Control | see script headers | — |

Every script has its node tree written in its header comment.

### Planting zones: Area2D or TileMapLayer?
Use **Area2D `PlantingZone` scenes**. You place a small number of zones by hand (5–8 per stage), each owns its sapling, milestones are simple to count, and Stage 3 can link a zone to an `AridZone` in the Inspector.
A TileMapLayer custom-data layer (`plantable: bool`) only makes sense for free planting anywhere. That route needs a `Dictionary[Vector2i → Sapling]`, a check on which cell is under the player, and handling for slopes. It adds complexity without a teaching benefit.
Use the TileMapLayer for **visuals only**: the restoration shader, plus a separate decor layer for burnt stumps.

### Physics layers (Project Settings → Layer Names → 2D Physics)
Layers 1–5 already exist. Add **6 `interactables`** and **7 `pests`**. Change the bullet's `collision_mask` from **26 to 90** (26 + 64).
Don't put pests on layer 2 ("enemies"): the player's mask is 30, so the player would collide with every bug.

---

## 2. Signal architecture (event bus)

The rules are at the top of `Events.gd`. The data flow always runs one way:

```
World object ──calls──▶ GameState method ──emits──▶ EventBus ──▶ HUD / Restoration / Log / Stage
World object ──emits (domain event)──▶ EventBus ──▶ GameState counts it ──▶ EventBus *_changed
```

| Signal | Emitted by | Main listeners |
|---|---|---|
| `seed_collected(amount, world_position)` | SeedPickup | SFX/VFX |
| `seeds_changed(total)` | GameState | HUD |
| `water_collected(amount)` / `water_changed(carried, capacity)` | GameState | HUD |
| `interaction_started / progress(ratio) / cancelled / completed (target)` | PlayerInteractor | HUD hold bar, target visuals |
| `interaction_denied(target, reason)` | PlayerInteractor, PlantingZone | HUD tip (`DENY_<REASON>`), SessionLog |
| `tree_planted(zone, sapling)` | PlantingZone | **GameState** (+1 planted), SessionLog |
| `trees_planted_changed(total, goal)` | GameState | HUD |
| `sapling_stage_changed(sapling, stage)` | Sapling | SFX, particles |
| `sapling_damaged(sapling, health)` / `sapling_wilted` / `sapling_revived` | Sapling | HUD alert, SessionLog |
| `sapling_matured(sapling)` | Sapling | **GameState** (+1 matured → restoration), StageController |
| `pest_spawned(pest)` / `pest_removed(pest)` | Pest | SFX, SessionLog |
| `water_delivered(zone, amount)` / `arid_zone_hydrated(zone)` | AridZone | StageController, VFX |
| `restoration_changed(ratio)` | GameState | RestorationController |
| `restoration_milestone_reached(index 0..3)` | GameState | RestorationController, StageController → milestone fact |
| `player_health_changed(current, maximum)` / `player_damaged(amount)` / `player_defeated()` | GameState | HUD, StageController (respawn) |
| `stage_started(id)` / `objective_updated(key)` / `stage_completed(id)` | StageController | HUD, SessionLog |
| `climate_fact_unlocked(id)` | GameState | Leaf Journal, SessionLog |
| `fact_card_opened(id)` / `fact_card_closed(id, seconds_open)` | LearningDirector | SessionLog, StageController (await) |
| `tip_requested(text_key)` | anyone | HUD tip bubble (no pause) |

Your proposed names map as follows: `seed_collected` is unchanged, `tree_planted` is unchanged, and `climate_fact_unlocked` is unchanged. I added `*_changed` signals for state and domain *events* for everything else, so the HUD never needs to know what a PlantingZone is.

---

## 3. Mechanics specification

### 3.1 Hold-to-interact: one verb for every mechanic
Planting, reviving a wilted sapling and watering all use **"Hold E"**. That leaves young players only one control to learn beyond movement.

```
IDLE
 │ interact just pressed, target in range, player on floor
 ▼
 target.get_block_reason() ── ≠ "" ──▶ interaction_denied → tip, stay IDLE
 │ == ""
 ▼
HOLDING  (elapsed += delta, emit progress ratio)
 │ released │ moved (|axis| > 0.5) │ jumped │ target left range / invalid
 ├────────────────────────────────────────────▶ CANCELLED → IDLE
 │ elapsed ≥ target.hold_time
 ▼
COMPLETE → target.complete_interaction() → IDLE
```
Hold times: planting **1.0 s**, reviving **1.2 s**, watering **0.6 s**. They are exported, so you can tune them during playtests.
`toggle_mode` (tap to start, tap to cancel) is an accessibility option for children who find holding a key difficult. Expose it in the pause menu.

### 3.2 Planting
1. The player enters a `PlantingZone` and the prompt "Hold E to plant" appears.
2. If there's no seed, `DENY_NO_SEEDS` shows: "You need a seed! Look for glowing seeds."
3. Completing the hold calls `GameState.try_spend_seed()`, instantiates a `Sapling` at `SaplingAnchor`, and emits `tree_planted`.
4. The zone becomes non-interactable. The sapling becomes the target only if it wilts.

### 3.3 Sapling growth
| Stage | Default time to next | Vulnerable to pests | Needs water (Stage 3) |
|---|---|---|---|
| SEEDLING | 4 s | yes | no |
| SPROUT | 6 s | yes | **yes, growth is frozen until the linked AridZone is hydrated** (a thirsty icon shows) |
| YOUNG | 8 s | yes | yes |
| TREE | — | no | — → emits `sapling_matured` |

Health (3) refills at each new stage. When health reaches 0 the sapling is **WILTED**: its growth freezes and it turns brown and tilts. Holding E revives it at the same stage. **A sapling is never destroyed.** The loss for the child is time, not progress.

### 3.4 Pests (Stage 2)
- `PestSpawner` spawns pests only while at least one sapling `is_vulnerable()`. It uses `max_alive` 3, `interval` 7 s and `first_delay` 5 s.
- A `Pest` has three states: `SEEKING` (flies to the nearest vulnerable sapling at 55 px/s; the player's walk speed is 300), `EATING` (1 damage every 1.5 s, so an unprotected sapling wilts in about 4.5 s), and `FLEEING` (after a hit it flies away and is freed after 1.5 s).
- `ForestPlayer` shooes a nearby pest when the player taps E; touching a pest also sends it fleeing. There is no projectile or stomp kill path.
- The mechanic teaches that saplings are vulnerable only while young. Once every tree matures, the pests stop coming.

### 3.5 Water (Stage 3)
- `WaterDrop` pickups can be static or dripping (`fall_speed > 0`). The player carries up to 3 (`GameState.water_capacity`). If the can is full, the drop stays and the tip says "Your water can is full…".
- An `AridZone` needs `water_needed` drops (default 3). Each hold of E pours one drop, and the ground colour moves from dry to wet.
- A `PlantingZone.arid_zone` link means saplings in that zone stop at SPROUT until the zone is hydrated. Water is a condition for reforestation, not a side quest.
- To clear the stage, the player needs `tree_goal` matured trees **and** every AridZone hydrated (`require_all_arid_zones = true`).
- Stretch goal (skip if time is short): *swales*, where a switch opens a channel and rain rolls into the arid zone. It teaches water management well, but a physics puzzle for young children needs a lot of playtesting.

### 3.6 Environmental feedback
- `restoration = lerp(stage.base_restoration, 1.0, matured / goal)` is pushed to the **global shader uniform** `restoration`. One call recolours every tile, prop and background layer. Add it under Project Settings → *Shader Globals*: `restoration`, float, 0.
- `restoration_wind.gdshader` replaces `level/props/wind_sway.tres` on props. Without it, grass and trees stay green while the ground is burnt. It also makes burnt plants sway less.
- Milestones at 25/50/75/100 % use **node groups**, so no per-level code is needed:
  - `appear_at_N`: flowers, birds and butterflies fade in.
  - `vanish_at_N`: ash, smoke and stumps fade out.
  - `celebrate_at_N`: leaf particles burst once.
- Stage bases: Stage 1 = 0.0, Stage 2 = 0.25, Stage 3 = 0.5, Stage 4 = 0.85. The world gets visibly greener across the whole game.
- [Likely] Global shader uniforms work in the Compatibility renderer. Test this in week 1. Fallback: give every node the *same* `ShaderMaterial` resource and call `material.set_shader_parameter("restoration", v)` from `RestorationController`.

### 3.7 Health
There are 3 hearts. `Hazard` areas (embers, thorns) cost 1 heart and apply knockback, and so does falling below `StageData.kill_y`. Damage is followed by 1.2 s of invulnerability. At 0 hearts the player respawns at the last `Checkpoint` with full hearts, and **every tree is kept**.

### 3.8 The four stages (`the_last_forest/stage/stages/*.tres`)
| Stage | Goal | New mechanic | Intro fact | Milestone / outro facts |
|---|---|---|---|---|
| 1 Burnt Grove | 5 matured | seeds, planting, growth | Trees clean the air | 50 %: burning releases CO2 · 100 %: roots hold soil |
| 2 Pest Control | 5 matured | pests, reviving | Nature's helpers | outro: planting is just the start |
| 3 Water Mgmt | 4 matured + all arid zones | carrying and pouring water | Trees help make rain | — |
| 4 Sanctuary | 1 (the "last tree") | none: explore, Leaf Journal, final quiz | A home for wildlife (Philippine eagle) | certificate screen |

Stage 4 should add **no new mechanic**. It's the reward and the recap, and it's where you give the post-test.

---

## 4. Climate literacy integration (without frustrating children)

**Delivery rules** (enforced in `LearningDirector` and `FactCardPopup`):
1. **Show each fact once.** Seen facts go into the **Leaf Journal** (`LearningDirector.get_unlocked_facts()`), which children can reread from the pause menu. Collecting facts becomes a reward.
2. **Pick the moment carefully.** Cards never open mid-jump or while E is held. NORMAL facts have a **35 s cooldown**. HIGH facts (stage intro, milestones) skip the cooldown. After 6 s of waiting, the card shows anyway, which is safe because the game pauses.
3. **Pick the right delivery:**
   - **CARD** pauses the game and uses a picture. Use it for about one fact per milestone, 3–4 per stage at most.
   - **TIP** is a 4 s speech bubble that doesn't pause. Use it for hints and "why can't I…" messages.
4. **Block button-mashing.** The close button is disabled for 1.5 s. The card closes on a fresh E press-and-release or a click. Jump, shoot and Esc are swallowed. The E press that closes a card can't also start planting.
5. **Attach facts to things children can see.** A `FactTrigger` sits by a burnt stump or a cracked riverbed, so the fact explains what's in front of them.
6. **Explain refusals with a reason and the next step:** "You need a seed! Look for glowing seeds." Never show only "Can't do that."
7. **Write for the pilot grade** (your decision, §0 #6):
   - Title: 5 words or fewer.
   - Body: no more than 2 sentences and about 25 words.
   - One idea per card, and the image carries the idea.
   - No numbers.
   - Use a large, clear font. [Certain] SIL's **Andika** was designed for beginning readers. At the 800×480 base resolution, keep body text at 16 px or larger.
8. **Support two languages.** All text is translation keys in `data/translations/facts.csv` (`en`, `fil`). Import it under Project Settings → Localization. **Have a teacher review the Filipino column. I drafted it and it isn't reviewed.** Add an optional `voice_over` per fact for Grades 1–3.
9. **Check understanding without penalising.** At each stage end, show one picture question with 2 choices (for example "Which helps the forest?" with a picture of cutting and a picture of planting). A right answer earns a bonus seed. A wrong answer shows the right one and gently explains why. Nothing is lost. This is not built yet. Add it as `ClimateFact.Delivery.QUIZ` with a two-button variant of the card.

**Evidence for your study:** `SessionLog` records when each card opened and for how long, plus trees planted, trees wilted, refusals and stage times. That gives you the "time on learning content" and "struggle points" data your evaluation chapter needs. Use teacher-assigned codes and never names.

---

## 5. Project settings checklist
- [ ] Autoloads in the order shown in §1
- [ ] Input Map: `interact` = E (physical) + Joypad button 3 (Y). Leave `ui_accept` alone.
- [ ] Layer names: 6 `interactables`, 7 `pests`. Bullet `collision_mask` 26 → 90.
- [ ] Shader Globals: `restoration` (float, 0.0)
- [ ] Localization → Translations: add `facts.en.translation` and `facts.fil.translation` (created on import of the CSV)
- [ ] `run/main_scene` → your title screen or `stage_1_burnt_grove.tscn`

## 6. Patches to existing demo files
**`game.gd`**, pause via GameState:
```gdscript
elif input_event.is_action_pressed(&"toggle_pause"):
	if LearningDirector.is_showing():
		return  # card owns the screen
	if GameState.is_paused_by(&"pause_menu"):
		_pause_menu.close()
	else:
		GameState.request_pause(&"pause_menu")
		_pause_menu.open()
	get_tree().root.set_input_as_handled()
```
The implementation is in place: the main project route uses the forest player and four stage scenes, `player/player.tscn` is a compatibility wrapper, and arcade coins, firing, projectiles, and their HUD counter have been removed. Do not re-add the deleted bullet patch; pest repelling uses E and contact.

## 7. Suggested build order (each step can be played)
1. Settings (§5) and the patches (§6). Check that pausing still works.
2. Seed pickups, planting zones and saplings in Stage 1, with the HUD counters. **Playtest with 2–3 children at this point**, before building anything else.
3. The restoration shader and milestone groups. Test the Compatibility renderer here (§3.6).
4. The fact card and LearningDirector, plus the translations.
5. Stage 2 pests, then Stage 3 water, then the Stage 4 sanctuary.
6. The SessionLog check, the quiz card and the certificate. Then the pilot.

## 8. File map
```
the_last_forest/
  autoload/     Events.gd  game_state.gd  learning_director.gd  session_log.gd  database_manager.gd  app_flow.gd
  interaction/  interactable.gd  player_interactor.gd
  planting/     seed_pickup.gd  planting_zone.gd  sapling.gd
  pests/        pest.gd  pest_spawner.gd
  water/        water_drop.gd  arid_zone.gd
  environment/  restoration_controller.gd  restoration.gdshader  restoration_wind.gdshader
  stage/        stage_data.gd  stage_controller.gd  hazard.gd  checkpoint.gd  fact_trigger.gd
  stage/stages/ stage_1_burnt_grove.tres … stage_4_sanctuary.tres
  data/         climate_fact.gd  facts/*.tres (7)  translations/facts.csv
  gui/          game_hud.gd  fact_card_popup.gd
```
The stage `.tres` files point to `res://stages/stage_N_*.tscn`. Create those scenes with those names, or change `next_scene` in the Inspector.
