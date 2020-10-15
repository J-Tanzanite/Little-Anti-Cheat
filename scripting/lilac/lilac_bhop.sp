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

void lilac_bhop_check(int client, int buttons, int last_buttons)
{
	if ((buttons & IN_JUMP))
		playerinfo_jumps[client]++;

	int flags = GetEntityFlags(client);
	if ((buttons & IN_JUMP) && !(last_buttons & IN_JUMP)) {
		if ((flags & FL_ONGROUND)) {
			lilac_detected_bhop(client);

			playerinfo_bhop[client]++;
		}
	}
	else if ((flags & FL_ONGROUND)) {
		playerinfo_bhop[client] = 0;
		playerinfo_jumps[client] = 0;
	}
}

static void lilac_detected_bhop(int client)
{
	if (playerinfo_banned_flags[client][CHEAT_BHOP])
		return;

	switch (intabs(icvar[CVAR_BHOP])) {
	// Simplistic mode.
	case 1: {
		if (playerinfo_bhop[client] < bhop_max[BHOP_SIMPLISTIC])
			return;
	}
	// Advanced mode.
	case 2: {
		if (playerinfo_bhop[client] < bhop_max[BHOP_ADVANCED])
			return;
		else if (playerinfo_bhop[client] < bhop_max[BHOP_SIMPLISTIC]
			&& playerinfo_jumps[client] > 15)
			return;
	}
	}

	if (lilac_forward_allow_cheat_detection(client, CHEAT_BHOP) == false)
		return;

	playerinfo_banned_flags[client][CHEAT_BHOP] = true;

	lilac_forward_client_cheat(client, CHEAT_BHOP);

	if (icvar[CVAR_LOG]) {
		lilac_log_setup_client(client);
		Format(line, sizeof(line),
			"%s was detected and banned for Bhop (Jumps Presses: %d | Bhops: %d).",
			line,
			playerinfo_jumps[client] - 1, // Initial jump doesn't count.
			playerinfo_bhop[client]);
		// We don't need to subtract 1 from the bhop counter, as it
		// 	increments after this function is called.

		lilac_log(true);

		if (icvar[CVAR_LOG_EXTRA])
			lilac_log_extra(client);
	}

	lilac_ban_client(client, CHEAT_BHOP);
}
