# Little Anti-Cheat - Development Notes:

### Notes:

1. NoLerp\
Oddly enough, two server owners are having issues with NoLerp detections detecting legit players.\
Sadly, I have not been able to reproduce any false positives at all, and these server owners haven't really responded to my questions regarding their server settings.\
I suspect the problem lies with the interp settings the server allows... But not sure.\
It is something I will look more into.

2. Auto Update\
Autoupdate is now added in version 1.6.0 (Development), I haven't tested it, but it should in theory work.\
You MUST install this plugin for Auto-Update to work: https://forums.alliedmods.net/showthread.php?p=1570806

3. Anti-Wallhack\
Some people have asked me to add Anti-Wallhack support.\
So fine, I'll make an **ALPHA** Anti-Wallhack plugin soon.

4. CS:GO detections\
Just added Anti-Duck-Delay after some people privately messaged me, telling me about this: https://www.unknowncheats.me/forum/counterstrike-global-offensive/308838-duck-cooldown.html \
I did some basic tests, and seems like IN_BULLRUSH isn't an input legit players can actually do.\
So, this should be something only cheaters can do, but just in case, the default ban length will be for 1 week.\
If I get some feedback that this isn't producing false bans - then it will be changed to permanent bans. 
