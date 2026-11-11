# Scriptguide (dansk)

Hvad hvert script gør. Hold den i trit med `tools/guide_rows.py`, og kør `python3 tools/check_script_guides.py --write`.

| Script | Formål |
|---|---|
| `src/core/paths.gd` | Kommandolinje-argumenter, brugermapper, isolering pr. instans, mapper til eksterne erstatninger. |
| `src/core/safe_file.gd` | Beskyttet JSON-skrivning (temp → kontrol → .bak → erstat) og sikker læsning. |
| `src/core/session_log.gd` | Autoload `Log`: lille logfil pr. kørsel, advarsler til konsollen. |
| `src/core/settings_service.gd` | Autoload `Settings`: settings.cfg, input-handlinger og omlægning af taster, anvender lyd/vindue/sprog. |
| `src/core/asset_catalog.gd` | Læser asset-manifestet; stier til skabelon/medfølgende/ekstern erstatning. |
| `src/core/asset_resolver.gd` | Autoload `Assets`: finder grafik/lyd efter prioritet og tilpasser sprites til visningsboksen. |
| `src/core/audio_service.gd` | Autoload `Audio`: lydbusser, navngivne enkeltlyde og løkker. |
| `src/sim/content.gd` | Skrivebeskyttede data: balance, genstande, lokation; zoneopslag. |
| `src/sim/thermal.gd` | Ren varmemodel: varme ind/ud, ligevægt, nødstop, slid. |
| `src/sim/game_state.gd` | Opretter og renser spillets rene datatilstand; hjælpere til inventar. |
| `src/sim/game_session.gd` | Autoload `Session`: ejer det kørende spil, tik, tilstande, interaktioner, autogem. |
| `src/sim/drive.gd` | Fælles bildynamik set ovenfra: speeder/brems/bak, hastighedsafhængig styring, dækgreb og udskridning, håndbremsedrift, varmehæmning (spiller og rivaler). |
| `src/sim/combat.gd` | Projektiler som data, træfzoner for køler vs. skrog, skade. |
| `src/sim/enemy_ai.gd` | Rivalbil-AI: patrulje, opdagelse (varme + motorstøj), forfølgelse og cirkling, taggevær med varslede skud, tilbagetog/flugt. |
| `src/sim/encounter.gd` | Parkeret-bil-møde: føreren reagerer, løber til bilen, stiger ind, motoren starter; flugt; indlæsning. |
| `src/sim/weather.gd` | KLART/SANDSTORM-vejr: gradvis opbygning, zoners stormudsættelse, effekt på køling/dragt/sigtbarhed. |
| `src/sim/turret.gd` | Skrotternes perimetertårn: begrænset drejning, sigtelinje, varslet langsom ild. |
| `src/persistence/save_codec.gd` | Gemmefilens kuvert, validering, migreringer. |
| `src/persistence/save_service.gd` | Autoload `Saves`: gemmepladser, gendannelse fra backup, resuméer. |
| `src/presentation/app/main.gd` | Rod: skifter mellem menu og spil, starter testdriveren. |
| `src/presentation/app/game_screen.gd` | Spilskærm: verden, atmosfære, HUD, overlejringer, pause. |
| `src/presentation/app/menu_backdrop.gd` | Baggrund bag hovedmenuen. |
| `src/presentation/world/world_view.gd` | Bygger lokationens visning; markører, tagtoning, pladstjek. |
| `src/presentation/world/ground_builder.gd` | Jordfliser, områder og sporstrimler. |
| `src/presentation/world/scatter.gd` | Seedet dekorativ spredning af sten og mineralskorper. |
| `src/presentation/world/prop_view.gd` | Én fast genstand: sprite, kollisionsfodaftryk, kastet skygge, tagtoning. |
| `src/presentation/world/car_view.gd` | Spillerens bil: karosseri, styrende forhjul, tagring med tvillinggeværer og rekyl, krængning, bremsespor, varmeglød, skadeeffekter, kollisionsfeedback. |
| `src/presentation/world/pilot_view.gd` | Piloten i dragt til fods: bevægelse, retning, proceduremæssig gang. |
| `src/presentation/world/camera_rig.gd` | Følgekamera med fremsyn, zoom og grænser. |
| `src/presentation/world/player_input.gd` | Input-handlinger → hensigter og forespørgsler til Session. |
| `src/presentation/world/sound_director.gd` | Kobler tilstand/hændelser til lydløkker og enkeltlyde. |
| `src/presentation/world/enemy_view.gd` | Rivalbil: hjul, drejeligt taggevær, sigtelinje, fører til fods, skadeeffekter, vragtilstand. |
| `src/presentation/world/projectiles_view.gd` | Tegner projektiler; nedslag, kølertræf og mundingsglimt. |
| `src/presentation/world/terrain_view.gd` | Klippemasser, overdækninger der toner ud, byggede vægge og strømkabler. |
| `src/presentation/world/turret_view.gd` | Tårnvisning: roterende hus, lasersigte, rekyl, skade, vrag. |
| `src/presentation/world/light_kit.gd` | Delt glødtekstur, roterende lys- og skyggeshadere. |
| `src/presentation/world/fx_kit.gd` | Partikelforudindstillinger (damp, støv). |
| `src/presentation/world/atmosphere.gd` | Fase B-atmosfære: dagslys, farvekorrektion, støvdis, varmeflimmer, støvpartikler. |
| `src/presentation/world/wind_streaks.gd` | Svage vindstriber i skærmrummet under farvekorrektionen. |
| `src/presentation/ui/ui_theme.gd` | Flad UI-stil og små hjælpere. |
| `src/presentation/ui/ui_root.gd` | UI-rod der anvender brugerflade-skalaen. |
| `src/presentation/ui/hud.gd` | HUD: mech, dragt, mål, handlinger, last, beskeder, farekant. |
| `src/presentation/ui/objective_pointer.gd` | Pil ved skærmkanten / ring mod det aktuelle mål. |
| `src/presentation/ui/reticle.gd` | Musesigte, mens man styrer mechen. |
| `src/presentation/ui/dev_menu.gd` | F10 udvikler-/snydemenu (kun under kørsel, gemmes aldrig). |
| `src/presentation/ui/main_menu.gd` | Fortsæt / nyt spil med pladsvalg / indstillinger / afslut. |
| `src/presentation/ui/settings_menu.gd` | Lyd, skærm, UI-skala, zoom, sprog, tastomlægning, genindlæsning af grafik. |
| `src/presentation/ui/pause_menu.gd` | Genoptag / gem / indstillinger / afslut. |
| `src/presentation/ui/dev_overlay.gd` | F3-diagnostik og fejlsøgningstaster. |
| `src/dev/autotest_driver.gd` | Fjernstyring kun til test (`--autotest`) af rigtige spilprocesser. |
| `tests/test_runner.gd` | Enheds-/regressionstests (uden vindue). |
| `tools/hs_driver.py` | Python-hjælper der styrer spilprocesser. |
| `tools/regression.py` | Kørselsregression: løkke, vedvarende gem efter genstart, erstatninger, indstillinger. |
| `tools/regression_encounter.py` | Kørselsregression for fjendemødet (kamp, AI, vrag, skygge, genstart). |
| `tools/shots_encounter.py` | Skærmbilleder af fjendemødet. |
| `tools/regression_refuge.py` | Kørselsregression: tårn/tvillingkanoner, kløft, overhæng, værksted, tilflugtsvarme, musik, parkeret-mech-møde. |
| `tools/shots_refuge.py` | Skærmbilleder af tilflugten + ombordstignings-sekvens. |
| `tools/import_audio.py` | Importerer udvalgt lyd fra indbakken til skabeloner. |
| `tools/regression_junkers.py` | Kørselsregression: rekyl, sandstorm, udviklermenu, udforskning, skrotterbase, tårne, forsvarere. |
| `tools/shots_junkers.py` | Skærmbilleder + rekyl-GIF for Sydskrotter-iterationen. |
| `tools/build_world_south.py` | Skriver og validerer det udvidede kort / skrotterbasen i lokationsfilen. |
| `tools/heat_balance.py` | Udskriver varmebalancetabellen (ligevægt, tid til advarsel/kritisk) fra tuning.json. |
| `tools/regression_balance.py` | Kørselsregression: fart/respons og gradvist varmepres. |
| `tools/shots_balance.py` | Skærmbilleder af bevægelses-/varmeomlægningen. |
| `tools/shots.py` | Tager skærmbilleder af det kørende spil. |
| `tools/shots_b.py` | Fase B-skærmbilleder; `--backdrop` optager menu-baggrunden. |
| `tools/art/inkkit.py` | Blækpipeline (Red Thaw-sæt + desertize, top-down finish, sømløse fliser). |
| `tools/art/gen_art.py` | Genererer alle illustrerede skabeloner og FX-teksturer. |
| `tools/gen_placeholders.py` | Diagnostiske pladsholder-sprites (fase A). |
| `tools/gen_audio.py` | Syntetiserer de medfølgende pladsholderlyde. |
| `tools/locale_src.py` | Kilde til al UI-tekst (EN/DA) → locale/strings.csv. |
| `tools/guide_rows.py` | Beskrivelser brugt til scriptguiderne. |
| `tools/check_script_guides.py` | Kontrollerer/skriver EN- og DA-scriptguiderne. |
| `src/sim/creatures.gd` | Det optøede økosystem: skirr-flok, sliberyg-graver og rimeryg-bytte — sanser, varslede angreb, brækbare dele, flugt/nedgravning (rene data). |
| `src/sim/garage.gd` | Tilflugtens garagemoduler (panser, køling, dæk, våben, lastrig): pris, niveauer, effekt på bilens balance. |
| `src/sim/loot.gd` | Fysisk bytte på jorden med sjældenhed: oprettelse, droptabeller, opslag. |
| `src/presentation/world/creature_view.gd` | Ét dyr: kropsdele, gang, varsler i verden (baner, revneringe, buer, glødende kirtler), træf-/brudeffekter, kadaver. |
| `src/presentation/world/hunt_marks.gd` | Spor der falmer med alderen (blodmærkede), bytte på jorden med sjældenhedsglød og legendarisk stjerne, bremsespor. |
| `src/presentation/ui/garage_menu.gd` | Garageskærm: tilstand, last, fuld reparation, moduler med har/mangler og effektvisning. |
| `src/presentation/ui/help_overlay.gd` | Felthåndbog i spillet (H): kørsel, skydning, varme, sporing, jagt, slagtning, garage, til fods. |
| `src/presentation/ui/tracker_widget.gd` | Sporkompas: art, friskhed, blod, pil langs sporet. |
| `tools/art/gen_thawborn.py` | Tusch-pipeline-skabeloner til biler, rivaler, dyr, spor og jagtmaterialer; registrerer manifestposter. |
| `tools/regression_hunt.py` | Kørselsregression af hele Thawborn-løkken: tilflugt → kørsel → sporing → jagt → slagtning → bytte → garage → gem/indlæs; rivalbil, skirrer, sliberyg, sandstorm. |
| `tools/build_windows.py` | Windows-build: Godot-eksport, bærbar zip og NSIS-installationsprogram (export/). |
| `tools/shots_thawborn.py` | Skærmbilleder af Thawborn-konverteringen og optagelse af menubaggrunden. |
