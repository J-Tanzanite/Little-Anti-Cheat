/*
	Little Anti-Cheat
	Copyright (C) 2018-2023 J_Tanzanite

	This program is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with this program.  If not, see <https://www.gnu.org/licenses/>.
*/

#if defined _lilac_included
 #endinput
#endif
#define _lilac_included

/* In case anyone wants to change this later on in a pull request or whatever,
 * DON'T DON'T DON'T DON'T DON'T DON'T DON'T DON'T DON'T DON'T DON'T!!!
 * ...  DON'T...
 * These values cannot be changed due to forwards,
 *     changing them will cause issues for other plugins.
 * You can add new stuff, but not change the number of anything here. */
#define CHEAT_ANGLES             0
#define CHEAT_CHATCLEAR          1
#define CHEAT_CONVAR             2
#define CHEAT_NOLERP             3
#define CHEAT_BHOP               4
#define CHEAT_AIMBOT             5
#define CHEAT_AIMLOCK            6
#define CHEAT_ANTI_DUCK_DELAY    7
#define CHEAT_NOISEMAKER_SPAM    8
#define CHEAT_MACRO              9 /* Macros aren't actually cheats, but are forwarded as such. */
#define CHEAT_NEWLINE_NAME      10
#define CHEAT_MAX               11

/**
 * Called when a player is detected cheating.
 *
 * @param client     	Client index of the player.
 * @param cheat     	Cheat type. (See lilac_global #L38-#L48)
 * @noreturn
 */
forward void lilac_cheater_detected(int client, int cheat);

/**
 * Called before the player is about to be banned for cheating.
 *
 * @param client     	Client index of the player.
 * @param cheat     	Cheat type. (See lilac_global #L38-#L48)
 * @noreturn
 */
forward void lilac_cheater_banned(int client, int cheat);

/**
 * Interupt the cheat detection process.
 *
 * @param client     	Client index of the player.
 * @param cheat     	Cheat type. (See lilac_global #L38-#L48)
 * @return				1 If the cheat detection process should be interupted. Otherwise 0.
 */
forward bool lilac_allow_cheat_detection(int client, int cheat);

/**
 * Get the player details informations of the currently cheat flagged.
 * Best moment to call this function is in the lilac_cheater_detected callback.
 *
 * @param client		Client index of the player.
 * @param buffer		Buffer to store the informations in.
 * @param maxlen		Maximal length of the buffer.
 * @return				1 If informations found and stored into buffer. Otherwise -1.
 */
native int lilac_GetDetectedInfos(int client, char[] buffer, int maxlen);

// Instead of having to implant this into each plugin who want to use forwards
stock void GetCheatName(int type, char[] buffer, int maxlen)
{
	switch(type)
	{
		case CHEAT_ANGLES:Format(buffer, maxlen, "Angles");
		case CHEAT_CHATCLEAR:Format(buffer, maxlen, "Chat Clear");
		case CHEAT_CONVAR:Format(buffer, maxlen, "Convar");
		case CHEAT_NOLERP:Format(buffer, maxlen, "NoLerp");
		case CHEAT_BHOP:Format(buffer, maxlen, "Bhop");
		case CHEAT_AIMBOT:Format(buffer, maxlen, "Aimbot");
		case CHEAT_AIMLOCK:Format(buffer, maxlen, "Aimlock");
		case CHEAT_ANTI_DUCK_DELAY:Format(buffer, maxlen, "Anti Duck delay");
		case CHEAT_NOISEMAKER_SPAM:Format(buffer, maxlen, "NoiseMaker spam");
		case CHEAT_MACRO:Format(buffer, maxlen, "Macro");
		case CHEAT_NEWLINE_NAME:Format(buffer, maxlen, "NewLine Name");
	}
}

public SharedPlugin __pl_lilac =
{
	name = "lilac",
	file = "lilac.smx",
	#if defined REQUIRE_PLUGIN
	required = 1
	#else
	required = 0
	#endif
};

public void __pl_lilac_SetNTVOptional()
{
	MarkNativeAsOptional("lilac_GetDetectedInfos");
}