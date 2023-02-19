# Little Anti-Cheat

Little Anti-Cheat is a free and open source anti-cheat for source games, and runs on SourceMod.\
It was originally developed for some secret servers I had back in the day.\
But, as I quit cheating and quit having servers, I decided to release this project to help the community out.\
This Anti-Cheat is by no means perfect, and it is bypassable to some extent, but it should still be helpful in dealing with cheaters :)

### Current Cheat Detections:
 - Angle-Cheats (Legit Anti-Backstab (TF2), Basic Anti-Aims and Duckspeed).
 - Chat-Clear (When cheaters clear the chat).
 - Basic Invalid ConVar Detector (Checks if clients have sv_cheats turned on and such).
 - BunnyHop (Bhop).
 - Basic Projectile and Hitscan Aimbot.
 - Basic Aimlock.
 - Anti-Duck-Delay/FastDuck (CS:GO only).
 - Newlines in names.

### Misc features:
 - Angle-Cheats Patch (Patches Angle-Cheats from working).
 - Max Interp Kicker (Kicks players for attempting to exploit interp (cl_interp 0.5)).
 - Max Ping Kicker (Kicks players for having too high ping (Disabled by default)).
 - Backtrack Patch (Patches backtrack cheats (Disabled by default)).
 - Macro detection.
 - Invalid name detection.
 - Invalid characters in chat patch (+ chat clear exploit fix).

### Supported Games:
 - [TF2] Team Fortress 2
 - [CS:GO] Counter-Strike:Global Offensive
 - [CS:S] Counter-Strike:Source
 - [L4D2] Left 4 Dead 2
 - [L4D] Left 4 Dead
 - [DoD:S] Day of Defeat: Source

### Untested, but should work in:
 - [HL2:DM] Half-Life 2:DeathMatch

## Non-Steam versions / CS:S v34 / CS:S v91 / ETC...
Non-Steam versions (IE: Cracks) **ARE NOT SUPPORTED!**\
I am sorry to say, but non-steam versions aren't supported.\
This is because of technical problems with cracks, as they tend to be of older versions of the game, which means they'll have bugs that can conflict with some cheat detections.\
And I just don't want to support piracy.\
I also just don't want to download sketchy unofficial cracked versions of games...

So Little Anti-Cheat may not work out of the box for cracked versions of games.\
That said, I've decided to be a little helpful based on feedback from others.

For Non-Steam/Cracked version of CS:S (like v34 or v91), Angle-Cheat detections won't work.\
You can fix this by updating these ConVars: `lilac_angles 0` and `lilac_angles_patch 0`.\
These **HAVE** to be disabled.

### Credits / Special Thanks to:
 - J_Tanzanite... Yeah I'm crediting myself for writing this AC...
 - Azalty, for being (rightly) stubborn regarding an issue and for contributing database logging.
 - foon, for fixing sourcebans++ not working (https://forums.alliedmods.net/showthread.php?p=2689297#post2689297).
 - Bottiger, for fixing this plugin not working in CS:GO and general criticisms.
 - MAGNAT2645 for suggesting a cleaner method of handling convar changes.
 - Larry/LarryBrains for informing me of false Angle-Cheat detections in L4D2.
 - VintagePC (https://github.com/vintagepc) for SourceIRC support and basepath fix.

### Current languages supported:
 - Simplified Chinese (by RoyZ https://github.com/RoyZ-CSGO ^-^).
 - Dutch (by snowy UwU OwO EwE).
 - Danish (by kS the Man / ksgoescoding c:).
 - Norwegian (by me, the translations could be better).
 - French (by Rasi / GreenGuyRasi).
 - Finnish (By [Veeti](https://forums.alliedmods.net/member.php?u=317665)).
 - English (by me lol duh hue hue hue).
 - Russian (by an awesome person c:).
 - Czech (by luk27official and someone else).
 - Brazilian Portuguese by SheepyChris (https://github.com/SheepyChris), Tiagoquix (https://github.com/Tiagoquix) and Crashzk (https://github.com/crashzk).
 - German (by two humble nice Germans c:).
 - Spanish (by ALEJANDRO ^-^).
 - Ukrainian (by panikajo ;D).
 - Polish (by https://github.com/qawery-just-sad).
 - Turkish (by ShiroNje and R3nzTheCodeGOD).
 - Hungarian (by The Solid Lad).
 - Swedish (by Teamkiller324).\
\
I do hope to add more languages in the future.\
But at least you can add or improve on the translations already provided.\
My friends who did some of the translations were told by me that the translations don't have to be perfect.\
Just understandable to those who don't speak English too well.

### Optional:
 - Sourcebans++
 - MaterialAdmin
 - Updater


## Donations / Sponsors / Support:
If you wish you support this project, I accept steam/game items: https://steamcommunity.com/tradeoffer/new/?partner=883337522&token=D4Ku6oDJ

As of right now, that's the only platform I'll accept.
