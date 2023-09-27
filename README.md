
# Hitsounds

Hitsounds plugin currently used on Zeddy.

I decided to open source this as CSGO is coming to a close soon, and figured open sourcing this would be in the best interest for the future developement of CS2. I plan to port this plugin to CS2 once a modding environment is finally decided on.

## Features

- Different hit sounds depending on where the zombie is hit
- Sounds can be toggled for bosses and zombies
- Adjustable hit sound volume

## ConVars

- `sm_hitsound_path [path]` - String. File location of normal hitsound relative to sound folder (Def. `hitmarker/hitmarker.mp3`)
- `sm_hitsound_head_path [path]` - String. File location of headshot hitsound relative to sound folder (Def. `hitmarker/headshot.mp3`)
- `sm_hitsound_body_path [path]` - String. File location of bodyshot hitsound relative to sound folder (Def. `hitmarker/bodyshot.mp3`)
- `sm_hitsound_kill_path [path]` - String. File location of kill shot hitsound relative to sound folder (Def. `hitmarker/killshot.mp3`)

## Commands

- `sm_hitsound [on|off|1-100]` - Toggle hitsounds, adjust hitsound volume, or bring up the menu if left balnk.
