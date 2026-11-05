# Audio

The creator's uploads live in `assets/audio inbox/`. They are kept **untouched** there, and a
`.gdignore` stops Godot importing all 306 files. Selected clips are processed by
`python3 tools/import_audio.py` (driven by `tools/audio_map.json`) into
`assets/templates/audio/...`, so they work with the normal override system (`assets/overrides/...`).
- *copy:* byte-identical (the theme MP3s).
- *loop:* the last 2 s are crossfaded into the start for a seamless loop point, then saved as OGG.
- *shot:* mono, leading and trailing silence trimmed, a short fade at the end, peak capped at −0.2 dBFS.

## Creator audio in use
| Sound ID | Source file | Mode | Used for |
|---|---|---|---|
| `music.theme` | `assets/audio inbox/Theme/Where the Ice Once Lay.mp3` | copy | Main menu; repeats with a crossfade |
| `music.theme_alt` | `assets/audio inbox/Theme/Where the Ice Once Lay - Alternate.mp3` | copy | Occasional cue during calm desert exploration |
| `amb.wind` | `assets/audio inbox/Ambiance/Ambiance_Storm_01.wav` | loop | Open-desert wind / blowing sand (filtered and quieter in the canyon and refuge) |
| `amb.distant` | `assets/audio inbox/Ambiance/Sci Fi Ambiences - Other World.wav` | loop | Very quiet distant mechanical ambience, open desert only |
| `sfx.gun_fire` | `assets/audio inbox/Gun sounds/Machine Gun Shot 5.wav` | shot | Player twin guns (left barrel) |
| `sfx.gun_fire_b` | `assets/audio inbox/Gun sounds/Machine Gun Shot 3.wav` | shot | Player twin guns (right barrel) |
| `sfx.enemy_fire` | `assets/audio inbox/Gun sounds/Assault Rifle Shot 13.wav` | shot | Scrapper cannon (played pitched down) |
| `sfx.impact_metal` | `assets/audio inbox/Bullet impact/Metal Heavy 1.wav` | shot | Shots hitting a mech |
| `sfx.impact` | `assets/audio inbox/Bullet impact/Dirt 2.wav` | shot | Shots hitting rock / ground props |
| `sfx.cooling_hit` | `assets/audio inbox/General effects/Fire Extinguisher Loop 4.wav` | shot | Radiator hit — coolant spray hiss |
| `sfx.armor_break` | `assets/audio inbox/Gun sounds/Armor Break 1.wav` | shot | Player hull damaged |
| `sfx.wreck` | `assets/audio inbox/Explosives/C4 Explosion.wav` | shot | Enemy mech disabled |
| `sfx.power_up` | `assets/audio inbox/UI sounds/Power up 8.wav` | shot | Enemy mech power-up layer |
| `sfx.hatch_close` | `assets/audio inbox/Gun sounds/Mag In.wav` | shot | Enemy cockpit closes after boarding |
| `sfx.climb` | `assets/audio inbox/Body drop/Body Drop 2.wav` | shot | Enemy pilot climbs onto the hull |
| `sfx.pilot_shout` | `assets/audio inbox/Hero Voice - Male/Enemy Spotted.wav` | shot | Enemy pilot reacts to the player |
| `ui.click` | `assets/audio inbox/UI sounds/Simple Click Sound 1.wav` | shot | Menu buttons |

All other inbox files are unused for now. They include voices, most UI sounds, fire and lava,
glass and wood impacts, and the second storm ambience.

## Generated effects (no suitable clip in the inbox)
`sfx.generator_hum`, `sfx.electric_hum`, `sfx.servo` and `sfx.mech_startup` are synthesised by
`tools/gen_audio.py`, alongside the earlier placeholder effects. No music is generated.

## Theme music — "Where the Ice Once Lay"
- **Main menu:** `music.theme` plays continuously. Shortly before the end, a fresh copy starts on the
  second player with a 5 s crossfade, so it repeats without a gap.
- **Gameplay:** silent by default. After about 1.5–2.5 min of calm exploration in the open desert,
  `music.theme_alt` fades in over 8 s, plays for about 105 s, then fades out over 10 s, followed by a
  4–7 min cooldown.
- **Transitions:** combat (an enemy alerted or engaged) fades the music out within 2.5 s. Entering
  the canyon or refuge (low exposure) fades it out over 6 s. Returning to the menu resumes the main theme.
- All music is on the **Music** bus, so the Settings slider controls it.

## Soundscape by location
- **Exposure** runs from 1.0 in the open desert, through about 0.5 in the canyon, down to about 0.12
  under the overhang, and changes smoothly. It drives:
  - wind volume (−5 → −24 dB) and a low-pass on the **Wind** bus (18 kHz → 0.7 kHz)
  - the distant mechanical layer (only audible in the open)
- **Refuge:** the generator hum is positional (`AudioStreamPlayer2D`, about 1500 px range), so it
  becomes audible on the canyon approach. Each lamp has a faint electrical buzz (about 260 px range).
- **Mechs:**
  - engine and cooling fan
  - housing servo (volume follows the turn speed)
  - twin guns (alternating barrels, pitched down)
  - metal impacts, armour-break on hull hits, coolant hiss on radiator hits
- **Enemy encounter (positional):** pilot shout, climb + cockpit clack, a rising startup hum plus
  power-up, then actuator clunks.
