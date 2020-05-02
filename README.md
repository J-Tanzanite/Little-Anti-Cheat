# Little Anti-Cheat

Little Anti-Cheat is a free and open source anti-cheat for source games, and runs on SourceMod.\
It was originally developed for some secret servers I had back in the day.\
But, as I quit cheating and quit having servers, I decided to release this project to help the community out.\
This Anti-Cheat is by no means perfect, and it is bypassable to some extent, but it should still be a nice alternative (or just complementary) to SMAC (SourceMod Anti-Cheat).

### Current Cheat Detections:
 - Angle-Cheats (Legit Anti-Backstab (TF2), Basic Anti-Aims and Duckspeed).
 - Chat-Clear (When cheaters clear the chat).
 - Basic Invalid ConVar Detector (Checks if clients have sv_cheats turned on and such).
 - BunnyHop (Bhop).
 - Basic Projectile and Hitscan Aimbot.
 - Basic Aimlock.

### Misc features:
 - Angle-Cheats Patch (Patches Angle-Cheats from working).
 - Max Interp Kicker (Kicks players for attempting to exploit interp (cl_interp 0.5)).
 - Max Ping Kicker (Kicks players for having too high ping (Disabled by default)).
 - Backtrack Patch (Patches backtrack cheats (Disabled by default)).

### Supported Games:
 - [TF2] Team Fortress 2
 - [CS:GO] Counter-Strike:Global Offensive
 - [L4D2] Left 4 Dead 2
 - [DoD:S] Day of Defeat: Source

### Untested, but should work in:
 - [CS:S] Counter-Strike:Source
 - [HL2:DM] Half-Life 2:DeathMatch
 - [GMOD] Garry's Mod

## HEADS-UP:
Version 1.2.0 & 1.3.0 changed where detection logs are stored!\
Detections are **NO LONGER** stored in {gamefolder}/lilac.log\
Detections are **NOW STORED** here: {gamefolder}/addons/sourcemod/logs/lilac.log\
\
Configuration files have also changed location, but won't break if you are using the old location.\
If your config file is in cfg/lilac_config.cfg, it will still read that file and work fine.\
If you are just installing Lilac or wanna use the new config location, it is at **cfg/sourcemod/lilac_config.cfg**

### Credits / Special Thanks to:
 - J_Tanzanite... Yeah I'm crediting myself for writing this AC...
 - foon, for fixing sourcebans++ not working (https://forums.alliedmods.net/showthread.php?p=2689297#post2689297).
 - Rasi, for French translations.
 - Bottiger, for fixing this plugin not working in CS:GO and general criticisms.
 - MAGNAT2645 for suggesting a cleaner method of handling convar changes.
 - Larry/LarryBrains for informing me of false Angle-Cheat detections in L4D2.

### Current languages supported:
 - Norwegian (By me, the translations could be better).
 - French (By Rasi / GreenGuyRasi).
 - English (By me lol duh hue hue hue).
 - Russian (By an awesome person c:).
 - Czech (By an awesome person <3).\
\
I do hope to add more languages in the future.\
But at least you can add or improve on the translations already provided.\
My friends who did some of the translations were told by me that the translations don't have to be perfect.\
Just understandable to those who don't speak English too well.

### Optional:
 - Sourcebans++
 - MaterialAdmin
