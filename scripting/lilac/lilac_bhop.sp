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

static int jump_ticks[MAXPLAYERS + 1];
static int perfect_bhops[MAXPLAYERS + 1];

void lilac_bhop_reset_client(int client)
{
	jump_ticks[client] = 0;
	perfect_bhops[client] = 0;
}

void lilac_bhop_check(int client, int buttons, int last_buttons)
{
	if ((buttons & IN_JUMP))
		jump_ticks[client]++;

	int flags = GetEntityFlags(client);
	if ((buttons & IN_JUMP) && !(last_buttons & IN_JUMP)) {
		if ((flags & FL_ONGROUND)) {
			lilac_check_bhop(client);

			perfect_bhops[client]++;
		}
	}
	else if ((flags & FL_ONGROUND)) {
		lilac_bhop_reset_client(client);
	}
}

static void lilac_check_bhop(int client)
{
	if (playerinfo_banned_flags[client][CHEAT_BHOP])
		return;

	switch (intabs(icvar[CVAR_BHOP])) {
	// Simplistic mode.
	case 1: {
		if (perfect_bhops[client] < bhop_max[BHOP_SIMPLISTIC])
			return;
	}
	// Advanced mode.
	case 2: {
		if (perfect_bhops[client] < bhop_max[BHOP_ADVANCED])
			return;
		else if (perfect_bhops[client] < bhop_max[BHOP_SIMPLISTIC]
			&& jump_ticks[client] > 15)
			return;
	}
	}

	lilac_detected_bhop(client);
}

static void lilac_detected_bhop(int client)
{
	if (lilac_forward_allow_cheat_detection(client, CHEAT_BHOP) == false)
		return;

	playerinfo_banned_flags[client][CHEAT_BHOP] = true;

	lilac_forward_client_cheat(client, CHEAT_BHOP);

	if (icvar[CVAR_LOG]) {
		lilac_log_setup_client(client);
		Format(line, sizeof(line),
			"%s was detected and banned for Bhop (Jumps Presses: %d | Bhops: %d).",
			line,
			jump_ticks[client] - 1, // Initial jump doesn't count.
			perfect_bhops[client]);
		// We don't need to subtract 1 from the bhop counter, as it
		// 	increments after this function is called.

		lilac_log(true);

		if (icvar[CVAR_LOG_EXTRA])
			lilac_log_extra(client);
	}

	lilac_ban_client(client, CHEAT_BHOP);
}
