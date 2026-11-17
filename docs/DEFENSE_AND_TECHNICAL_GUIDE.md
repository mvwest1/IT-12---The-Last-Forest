<!-- Markdown copy of Defense_Guide_The_Last_Forest.docx (images are in the .docx and docs/figures/). -->
**THE LAST FOREST**

Defense Guide and Technical Briefing - v1.0.0



*The Last Forest: A 2D Platform Exploring Deforestation, Reforestation
Mechanics, and Climate Literacy*

| Researchers       | John Matthew T. Alaban, Zhedderic Ahlen L. Cañeda, Karl Andrei F. Ofler, Franz Chester A. Pabalan |
|-------------------|---------------------------------------------------------------------------------------------------|
| Technical Adviser | Mr. Jaime V. Yatco, MIT                                                                           |
| Instructor        | Grachel Greta                                                                                     |
| School            | University of Perpetual Help System Laguna - BS Information Technology (IT 12)                    |
| Build             | v1.0.0 - Android APK (arm64, signed) and Windows 64-bit .exe, both 100 % offline                  |

*How to use this guide: read Sections 1-4 the night before. Section 5 is
the live demo script. Section 9 is the list of likely panel questions.
Section 8 lists the limits you must say out loud before the panel finds
them.*

# 1. The project in one minute

- **Problem.** Grade 3-4 learners meet deforestation and reforestation
  only as textbook text; cause-and-effect (roots hold soil, young trees
  need protection, water must reach dry land) is hard to picture, and
  many classrooms have weak internet.

- **Solution.** An offline, bilingual (English/Filipino) 2D platformer
  for Android phones/tablets and Windows lab PCs. The learner plays
  Eco-Ranger Lunti restoring Sierra Verde in four stages.

- **Learning design.** Every stage: 3-item pre-test \> play \> picture
  fact cards (English + Filipino side by side) \> 3-item post-test. The
  same items are used before and after, so the difference measures
  learning in that stage.

- **Data.** A local SQLite database stores scores, play metrics, the
  Leaf Journal and Forest Points. The learner LRN is stored only as a
  salted SHA-256 hash; names are never stored.

- **Teacher.** A PIN-protected dashboard shows class averages per stage
  (before, after, gain, time) and exports a CSV with no names and no
  LRNs.

## Four stages

| **Stage**          | **What the child does**                                                            | **Ecology idea**                                 |
|--------------------|------------------------------------------------------------------------------------|--------------------------------------------------|
| 1 Burnt Grove      | Collect native seeds (Narra, Lauan, Dao), plant 3 trees in burnt soil              | Trees store carbon; burning forests releases CO2 |
| 2 Pest Control     | Protect 6 saplings: bump beetles/caterpillars away, place bamboo tree guards       | Young trees need care after planting             |
| 3 Water Management | Turn the lever so the wooden sluice sends rain to the dry gully, then grow 3 trees | Roots hold soil; trees help make rain            |
| 4 Forest Sanctuary | Restore the last canopy tree; wildlife returns                                     | Forests are homes for wildlife                   |

# 2. Opening statement (about 2 minutes)

*"Good day to our Chair and panel. We present The Last Forest, an
offline, bilingual 2D platformer that teaches Grade 3 and 4 learners how
forests are lost and restored. Climate and environmental education is
required by Republic Act 9512 and the MATATAG curriculum, but children
mostly meet it as text. Our game lets them do the restoration
themselves: they collect native seeds, plant and protect young trees,
guide rainwater, and watch the burnt hills turn green as their trees
mature.*

*Each stage begins with a three-item pre-test and ends with the same
three items as a post-test, with short picture fact cards in English and
Filipino in between. Results are saved in a local SQLite database. To
protect minors under the Data Privacy Act, we never store names, and the
LRN is stored only as a salted SHA-256 hash. Teachers see class averages
and export a CSV through a PIN-protected panel. The game runs fully
offline on Android phones and tablets and on Windows lab PCs. We will
now demonstrate it."*

# 3. Who explains what

| **Member**                | **Part to own**                                                           | **Must be able to open and explain**                    |
|---------------------------|---------------------------------------------------------------------------|---------------------------------------------------------|
| John Matthew T. Alaban    | Opening, problem, objectives, learning design (pre/post test, fact cards) | quiz_modal.gd, learning_director.gd, data/facts/\*.tres |
| Zhedderic Ahlen L. Cañeda | Live demo on the phone/tablet, gameplay mechanics of the 4 stages         | forest_player.gd, sapling.gd, pest.gd, diverter.gd      |
| Karl Andrei F. Ofler      | Database, privacy, transactions, leaderboard, teacher dashboard           | database_manager.gd, app_flow.gd, local_settings.gd     |
| Franz Chester A. Pabalan  | Art, audio, mobile build, testing evidence, limitations                   | tools/\*.py, export_presets.cfg, tests/\*.gd            |

This split is a suggestion: change it to match who actually built each
part. The panel will ask the person who presents a part to open its file
and explain a few lines.

# 4. How it works (technical)

## 4.1 Architecture

- **Engine:** Godot 4.7, GDScript, GL Compatibility renderer (runs on
  low-end Android GPUs and old lab PCs).

- **Autoload singletons:** EventBus (signals), GameState (counters,
  hearts, pause ownership), LearningDirector (quizzes and fact-card
  timing), DatabaseManager (SQLite), AppFlow (screens, login, saving),
  Settings (language, volume), Sfx (sounds).

- **Event-driven:** gameplay scripts only emit signals (seed_collected,
  tree_planted, sapling_matured...). HUD, sounds, restoration visuals
  and the journal listen. No script polls another.

- **Restoration visuals:** one global shader value "restoration" (0 =
  burnt, 1 = green) is tweened as trees mature; at 25/50/75/100 % smoke
  and snags fade, butterflies (50 %) and birds (100 %) appear.

## 4.2 Screen flow

Main Menu (Play, Leaf Journal, Leaderboard, Settings, Teacher) \> Story
(first time only) \> LRN login \> Stage Select (My Records, Story) \>
Stage: pre-test \> play + fact cards \> post-test \> database save \>
Stage Clear (stars, quiz before/after, Forest Points, rank).

## 4.3 Database (SQLite, schema v3)

| **Table**       | **Key columns**                                                                                      | **Purpose**                                   |
|-----------------|------------------------------------------------------------------------------------------------------|-----------------------------------------------|
| students        | student_id, lrn ("h:" + SHA-256 hash), grade_section, nickname (optional), registered_at             | One row per learner. name column stays empty. |
| quiz_results    | quiz_id, attempt_id (unique), student_id, stage_index, pre_score, post_score                         | Pre/post test of one attempt                  |
| session_records | session_id, attempt_id, quiz_id, seeds_collected, trees_matured, completion_time, tips_viewed, score | Play metrics and Forest Points of one attempt |
| journal_entries | student_id + fact_id (primary key), unlocked_at                                                      | Leaf Journal remembered across sessions       |

- **attempt_id** links the pre-test, post-test and play record of the
  same attempt, so replays are never mixed up.

- **Transactions:** the post-test score and the play record are saved
  inside one BEGIN/COMMIT. If either fails, everything is rolled back,
  the next stage stays locked and Stage Clear shows "Retry Save".

- **Migration:** databases from v0.1.x are upgraded in place (new
  columns added, Forest Points back-filled with the same formula) - no
  data is lost.

- **Backup:** if the SQLite add-on is missing, writes go to a JSON-lines
  backup file and the main menu says so honestly ("add-on missing").

## 4.4 Privacy and security (RA 10173)

- LRN: validated as exactly 12 digits, then stored as "h:" +
  SHA-256(salt + LRN). The raw LRN is never written.

- Names: never stored. The optional nickname (letters, digits and
  spaces, max 12) is what the leaderboard shows; otherwise the learner
  appears as "Ranger \#A9F2" (first 4 hex characters of the hash).

- Salt and PIN: kept in local_settings.cfg on the device, never in
  GitHub or inside the APK. On a new device the game creates a random
  256-bit salt and asks the teacher to create a PIN; the PIN is stored
  only as a salted hash.

- Brute force: 5 wrong PINs lock the panel for 30 seconds. Every export
  re-checks the PIN inside DatabaseManager, not only on the screen.

- CSV export: no names, no LRNs; cells starting with = + - @ are escaped
  (spreadsheet formula injection).

- Android backup of app data is disabled (user_data_backup/allow =
  false), so the database does not leave the device through cloud
  backup.

## 4.5 Forest Points and the leaderboard

Points for one cleared stage = 100 x correct post-test answers + 25 x
trees grown + 10 x fact cards read + speed bonus max(0, 150 - seconds /
2).

- **Why the pre-test is not in the formula:** if a gain bonus were used,
  a child could score more by answering the pre-test wrong on purpose,
  which would damage the research data. The pre-test is never rewarded.

- **Ranking:** each learner's best score on each stage is added up, so
  replays can only raise a score and never count twice. Ties share a
  rank. Filter: My class / Everyone.

- **Scope:** the leaderboard is per device (each phone or PC has its own
  database). It contains only real learners who played on that device -
  no sample players are added.

## 4.6 Quiz and stage flow (designed for 8-10 year olds)

- Stage loads \> quiz INTRO page: stage name, "3 quick questions, it is
  okay to guess - this is not a grade", Start button (the child is never
  dropped into a question without warning).

- Questions: the answer buttons fade in and are never shown greyed-out;
  the tapped answer lights up at once. A 0.35 s lock stops one tap from
  answering two questions.

- Pre-test: the chosen answer turns gold and the game says "Thank
  you!" - no right/wrong, no score (so the pre-test does not teach the
  answers).

- After the pre-test: a 3-second breather with a big "Stage 1 - Burnt
  Grove" banner and the goal, so the child sees the world before the
  first fact card.

- Fact cards and sign hints: the "Got it!" button is faded for 1.5 s,
  then lights up (no grey "broken" button).

- Post-test: intro "You restored the forest! Same 3 questions again";
  right answer green, wrong pick red, short message; result page with
  1-3 stars and the score.

- Pause \> Stage Select asks for a second tap, because leaving throws
  away the current try.

## 4.7 Mobile (Android)

- Landscape lock (sensor landscape), immersive full screen, base view
  800 x 480 that widens on 18:9-20:9 phones.

- Touch controls re-anchor to the real screen corners and scale to about
  20 % of screen height; a pause button sits top-right; all thumb
  buttons hide while a quiz, card or menu is open.

- Android Back button closes the open panel or goes up one screen; it
  never quits in the middle of a lesson.

- On phones the teacher uses "Copy CSV" (pastes into Google Sheets,
  Excel or an email) because the app folder is private on Android.

- Prompts say "Hold the sprout button" instead of "Hold E" on touch
  screens.

- User interface skin: Kenney "UI Pack - Pixel Adventure" (CC0) wooden
  panels, parchment cards, red ribbons and bars.

- SQLite runs natively on Android (arm64 library packaged in the APK).

# 5. Live demo script (8-10 minutes)

**Preparation.** Before the defense: install TheLastForest.apk on the
demo phone, open it once, create the teacher PIN, and play Stage 1 once
with a test LRN (e.g. 100000000001) so the leaderboard and dashboard are
not empty. Keep the Windows build on a laptop as a backup.

1.  Open the app: splash screen, then the main menu with logo. Point out
    "Database: ready" at the bottom right.

2.  Settings: switch English/Filipino live; show volume and "Tap once to
    plant" (accessibility).

3.  Play: (first time) the 4-page story of Sierra Verde, then LRN login.
    Type a 12-digit LRN, a nickname, grade & section. Explain: the LRN
    is hashed, the nickname is not a real name.

4.  Stage Select: Stage 1 open, others locked. Start Stage 1.

5.  Pre-test: 3 questions, no right/wrong shown (explain why).

6.  Fact card: parchment card with English and Filipino together.

7.  Gameplay: collect seeds, hold the sprout button on burnt soil, watch
    the sapling grow; restoration meter goes up, the world turns green,
    butterflies then birds return.

8.  Exit gate opens \> post-test with feedback \> Stage Clear: quiz
    before \> after, Forest Points, rank, "progress is saved".

9.  Leaderboard: your learner listed with nickname; explain
    best-score-per-stage.

10. Leaf Journal: the facts just unlocked; open one page (bilingual).
    Explain it is saved in journal_entries.

11. Teacher: enter PIN \> dashboard averages per stage \> Copy CSV
    (phone) or Export CSV (PC). Show a wrong PIN, explain the 5-try
    lockout.

12. If asked: show Stage 2 pests (beetle flies, caterpillar crawls) and
    Stage 3 lever + sluice.

**Fallback.** If something fails during the demo: stay calm, say what
should happen, switch to the Windows build, and show the screenshots in
Section 10.

# 6. How each objective is met

| **Objective**                    | **Where it is in the game**                                                           | **Evidence**                           |
|----------------------------------|---------------------------------------------------------------------------------------|----------------------------------------|
| Measure baseline knowledge       | Pre-test at the start of every stage (no feedback)                                    | quiz_results.pre_score                 |
| Develop the offline 2D game      | 4 stages, restoration shader, bilingual cards, Leaf Journal, Android + Windows builds | APK and .exe; automated tests          |
| Measure post-test and gain       | Same 3 items after the stage, paired by attempt_id                                    | CSV: pre_score, post_score, score_gain |
| Software quality (ISO/IEC 25010) | Automated tests, transactions, PIN lockout, accessibility options                     | Section 7                              |

# 7. Testing evidence (run on the final build)

| **Test**                      | **What it checks**                                                                                                                                  | **Result**                |
|-------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------|---------------------------|
| smoke_test.gd                 | Full playthrough of all 4 stages, saving, records, CSV export                                                                                       | 74 / 74 passed            |
| edge_test.gd                  | Defeat/respawn, water, PIN lockout, transactions/rollback, untranslated keys                                                                        | 50 / 50 passed            |
| production_test.gd            | Schema v2\>v3 migration, Forest Points, leaderboard, journal, nickname cleaning, hashed PIN, new screens, Back button, quiz/pause flow, regressions | 68 / 68 passed            |
| reach_test.gd                 | Every seed, planting zone and gate reachable on foot                                                                                                | 34 / 34 targets reachable |
| release_smoke_test.gd         | Launch, version, SQLite, login, save, retrieve                                                                                                      | all true                  |
| load_all.gd + static_check.py | Every scene/script loads; every path and translation key exists                                                                                     | 0 failures                |
| Android build                 | Signed with the release key (APK signature v2 + v3), SQLite library inside                                                                          | verified with apksigner   |

# 8. Limitations - say these before the panel finds them

- The Android build has passed automated checks and signature
  verification, but it must be played on at least one real phone and one
  tablet before the defense; touch feel and performance on the school's
  devices are not yet measured.

- Each device has its own database and salt. The same learner on two
  tablets gets two different codes, and the leaderboard is per device.
  For a class pilot, use one device per learner or the shared
  local_settings.cfg on lab PCs.

- A forgotten teacher PIN on Android can only be reset by clearing the
  app's data, which also deletes the results. Export the CSV regularly.

- The pre/post test uses only 3 items per stage (12 total), so
  reliability is limited; the pilot data are indicative, not conclusive.

- Filipino text was written by the team with help and should be
  proofread by a Filipino teacher; fact sources must be confirmed by a
  science teacher.

- Art is original scripted pixel art plus tiles from the MIT-licensed
  Godot 2D platformer demo and Kenney's CC0 UI Pack - Pixel Adventure;
  credit both in the manuscript.

- AI tools were used as coding/documentation assistants; this must be
  declared as required by the course (see README). The group must be
  able to explain every part.

# 9. Likely panel questions

**Q: Why Godot and not Unity?**

A: Free and open source (MIT) with no runtime fees, small exports,
GDScript is quick to learn, and the GL Compatibility renderer runs on
low-end Android devices and old lab PCs.

**Q: Why SQLite and not an online database?**

A: Many classrooms have weak or no internet. SQLite is a single local
file, needs no server, and supports transactions so results are not
half-saved.

**Q: How do you protect minors' data?**

A: No names stored; LRN only as a salted SHA-256 hash; secrets kept
outside the code and APK; teacher PIN hashed with lockout; CSV without
identifiers; Android cloud backup disabled.

**Q: Can the hash be reversed?**

A: Not directly. LRNs are only 12 digits, so without the salt someone
could try all of them; the random 256-bit salt kept only on the device
is what prevents that. This is pseudonymization, not anonymization -
whoever holds the salt and a class list can re-identify learners, so the
device must be protected.

**Q: Why the same questions before and after?**

A: So the gain measures learning on the same content. The pre-test gives
no feedback and choices are shuffled, so it does not teach the answers
or their positions.

**Q: Does the leaderboard pressure children or encourage cheating?**

A: Only nicknames/codes are shown; the pre-test never gives points, so
tanking it does not help; replays only keep the best score. Teachers can
simply not open it.

**Q: What if the phone dies while saving?**

A: The post-test and play record are one transaction with SQLite WAL
journaling; either both are saved or neither, and Retry Save keeps the
result in memory.

**Q: What if two learners share one device?**

A: Each logs in with their own LRN; "Change player" on Stage Select logs
out. Records and journals are separated by student_id.

**Q: How did you test it?**

A: Automated scripts that play every stage, attack the PIN, simulate
failed saves, upgrade an old database and check every file path and
translation (Section 7), plus manual play on PC and the phone.

**Q: Where did the art and sounds come from?**

A: Pixel art and sounds were generated by our Python scripts in
the_last_forest/tools/; tiles and the music come from the MIT-licensed
Godot platformer demo.

**Q: Why are pests not killed?**

A: The lesson is protecting young trees, not violence; bumping shoos
them away and tree guards keep them off.

**Q: How does the world turn green?**

A: One global shader parameter controls every tile and prop;
RestorationController tweens it as trees mature and shows/hides objects
by milestone groups.

**Q: What would you improve next?**

A: Pilot with real classes and item analysis of the quiz, more items per
stage, voice-over for early readers, and a way to merge results from
several devices.

# 10. Screenshots (final build)

*Leaderboard and dashboard screenshots use a test database created by
tests/production_shots.gd; the shipped game starts with an empty
leaderboard.*



*Main menu*



*Story intro (bilingual)*



*LRN login*



*Stage Select*



*Quiz intro page*



*Pre-test question*



*Stage banner after the pre-test*



*Post-test feedback (green right, red wrong pick)*



*Post-test result with stars*



*Bilingual fact card*



*Stage 1 on a 20:9 phone with touch controls*



*Stage 1 restored: green world, birds and butterflies*



*Stage 2: tree guards, beetle and caterpillar*



*Stage 3: lever and wooden sluice*



*Stage Clear with Forest Points*



*Leaderboard (test data)*



*Teacher dashboard (test data)*



*Leaf Journal page*



*Settings*

## 11. Build and release checklist

- Release keystore (thelastforest-release.keystore) and its password:
  keep two private copies (e.g. teacher USB + adviser). Without it you
  cannot publish an update that installs over this version. Never commit
  it.

- Android: Project \> Export \> "Android (Phones & Tablets)". Windows:
  "Windows Desktop (Lab PCs)"; copy the same local_settings.cfg next to
  TheLastForest.exe on every lab PC.

- Run the tests in README before every build.
