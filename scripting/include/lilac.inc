/*
**
*/
#if defined _lilac_included
 #endinput
#endif
#define _lilac_included

enum CHEATS {
	ANGLES = 0,
	CHATCLEAR = 1,
	CONVAR = 2,
	NOLERP = 3,
	BHOP = 4,
	AIMBOT = 5,
	AIMLOCK = 6,
	ANTI_DUCK_DELAY = 7,
	NOISEMAKER_SPAM = 8,
	MACRO = 9,
	NEWLINE_NAME = 10,
}

stock void GetCheatName(CHEATS type, char[] buffer, int maxlen)
{
	switch(type)
	{
		case ANGLES:Format(buffer, maxlen, "Angles");
		case CHATCLEAR:Format(buffer, maxlen, "Chat Clear");
		case CONVAR:Format(buffer, maxlen, "Convar");
		case NOLERP:Format(buffer, maxlen, "NoLerp");
		case BHOP:Format(buffer, maxlen, "Bhop");
		case AIMBOT:Format(buffer, maxlen, "Aimbot");
		case AIMLOCK:Format(buffer, maxlen, "Aimlock");
		case ANTI_DUCK_DELAY:Format(buffer, maxlen, "Anti Duck delay");
		case NOISEMAKER_SPAM:Format(buffer, maxlen, "NoiseMaker spam");
		case MACRO:Format(buffer, maxlen, "Macro");
		case NEWLINE_NAME:Format(buffer, maxlen, "NewLine Name");
	}
}


// DECLARATION
forward void lilac_cheater_detected(int client, int cheat_type, char[] sLine);