/*
	Little Anti-Cheat
	Copyright (C) 2018-2020 J_Tanzanite

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

void lilac_macro_check(int client, int buttons, int last_buttons)
{
	static int index[MAXPLAYERS + 1];

	if (++index[client] >= tick_rate)
		index[client] = 0;

	for (int i = 0; i < MACRO_ARRAY; i++) {
		// Skip macros we aren't checking for.
		if (!process_macro_type(i))
			continue;

		int input = get_macro_input(i);

		// Player pressed the key.
		bool key = (!(last_buttons & input) && (buttons & input)) ? true : false;
		playerinfo_macro_log[client][i][index[client]] = key;

		// Only check for spam when the key is pressed.
		if (!key)
			continue;

		int acc = 0;

		for (int k = 0; k < tick_rate; k++) {
			if (playerinfo_macro_log[client][i][k])
				acc++;
		}

		if (acc >= macro_max)
			lilac_detected_macro(client, i);
	}
}

static bool process_macro_type(int macro_type)
{
	// Invalid macro type.
	if (macro_type >= MACRO_ARRAY || macro_type < 0)
		return false;

	// 0 == Test for all types.
	if (!icvar[CVAR_MACRO_MODE])
		return true;

	// Check bit.
	return (icvar[CVAR_MACRO_MODE] & (1 << macro_type)) ? true : false;
}

static int get_macro_input(int macro_type)
{
	switch (macro_type) {
	case MACRO_AUTOJUMP: return IN_JUMP;
	case MACRO_AUTOSHOOT: return IN_ATTACK;
	default: return 0;
	}
}

static void lilac_detected_macro(int client, int type)
{
	char string[16];

	// Clear history, prevents overlap.
	for (int i = 0; i < MACRO_LOG_LENGTH; i++)
		playerinfo_macro_log[client][type][i] = false;

	// Already been logged once, ignore.
	if (playerinfo_banned_flags[client][CHEAT_MACRO])
		return;

	// Spam prevention.
	if (playerinfo_time_forward[client][CHEAT_MACRO] > GetGameTime())
		return;

	if (lilac_forward_allow_cheat_detection(client, CHEAT_MACRO) == false) {
		playerinfo_time_forward[client][CHEAT_MACRO] = GetGameTime() + 5.0;
		return;
	}

	lilac_forward_client_cheat(client, CHEAT_MACRO);

	switch (type) {
	case MACRO_AUTOJUMP: { strcopy(string, sizeof(string), "Auto-Jump"); }
	case MACRO_AUTOSHOOT: { strcopy(string, sizeof(string), "Auto-Shoot"); }
	default: { return; } // Invalid type.
	}

	// Ignore the first detection.
	if (++playerinfo_macro[client][type] < 2)
		return;

	// Log.
	if (icvar[CVAR_LOG]) {
		lilac_log_setup_client(client);
		Format(line, sizeof(line),
			"%s was detected of using Macro %s (Detection: %d | Max presses: %d).",
			line, string, playerinfo_macro[client][type], macro_max);

		lilac_log(true);

		if (icvar[CVAR_LOG_EXTRA])
			lilac_log_extra(client);
	}

	// If we are using log-only, then don't warn, there's no point.
	if (icvar[CVAR_MACRO] > -1) {
		// Warnings.
		switch (icvar[CVAR_MACRO_WARNING]) {
		case 1: {
			PrintCenterText(client, "[Little Anti-Cheat] Warning: Macro usage isn't allowed!");
			PrintToChat(client, "[Little Anti-Cheat] Warning: Macro usage isn't allowed!");
		}
		case 2: {
			for (int i = 1; playerinfo_macro[client][type] == 2 && i <= MaxClients; i++) {
				if (!is_player_valid(i) || IsFakeClient(i))
					continue;
	
				if (!is_player_admin(i))
					continue;
	
				PrintToChat(i, "[Little Anti-Cheat] %N was detected of using Macro %s.",
					client, string);
			}
		}
		case 3: {
			// Warn everyone once...
			if (playerinfo_macro[client][type] == 2)
				PrintToChatAll("[Little Anti-Cheat] %N was detected of using Macro %s.",
					client, string);
		}
		}
	}

	if (playerinfo_macro[client][type] < 5)
		return;

	playerinfo_banned_flags[client][CHEAT_MACRO] = true;

	if (icvar[CVAR_MACRO] == -1)
		return;

	if (icvar[CVAR_MACRO_DEAL_METHOD] == 0)
		KickClient(client, "[Lilac] %T", "kick_macro", client, string);
	else
		lilac_ban_client(client, CHEAT_MACRO);
}

// Macro detections decrement every 5 minutes.
// Todo: Might wanna make it more frequent?
public Action timer_decrement_macro(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++) {
		for (int k = 0; k < MACRO_ARRAY; k++) {
			if (playerinfo_macro[i][k] > 0)
				playerinfo_macro[i][k]--;
		}
	}
}
