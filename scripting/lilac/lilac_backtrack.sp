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

int lilac_backtrack_patch(int client, int tickcount)
{
	if (lilac_valid_tickcount(client) == false && lilac_is_player_in_backtrack_timeout(client) == false)
		lilac_set_client_in_backtrack_timeout(client);

	if (lilac_is_player_in_backtrack_timeout(client)) {
		switch (icvar[CVAR_BACKTRACK_PATCH]) {
		case 1: return lilac_random_tickcount(client); // If you use mode 1... I won't like you >:I
		case 2: return lilac_lock_tickcount(client);
		}
	}

	return tickcount;
}

static int lilac_random_tickcount(int client)
{
	int tick, ping, forwardtrack;

	// Latency/Ping in ticks.
	ping = RoundToNearest(GetClientAvgLatency(client, NetFlow_Outgoing) / GetTickInterval());

	// Forwardtracking is maximum 200ms.
	forwardtrack = ping;
	if (forwardtrack > time_to_ticks(0.2))
		forwardtrack = time_to_ticks(0.2);

	// Randomize tickcount to be what it should be (server tickcount - ping)
	// 	- a random value between -200ms and forwardtracking (max 200ms).
	tick = GetGameTickCount() - ping + GetRandomInt(0, time_to_ticks(0.2) + forwardtrack) - time_to_ticks(0.2);

	// Tickcount cannot be larger than server tickcount.
	if (tick > GetGameTickCount())
		return GetGameTickCount();

	return tick;
}

static int lilac_lock_tickcount(int client)
{
	int ping, tick;

	ping = RoundToNearest(GetClientAvgLatency(client, NetFlow_Outgoing) / GetTickInterval());
	tick = playerinfo_tickcount_diff[client] + (GetGameTickCount() - ping);

	// Never return higher than server tick count.
	// Other than that, lock the tickcount to the player's
	// 	previous value for the durration of the patch.
	// 	This patch method shouldn't affect legit laggy players as much.
	return ((tick > GetGameTickCount()) ? GetGameTickCount() : tick);
}

static bool lilac_valid_tickcount(int client)
{
	return (intabs((playerinfo_tickcount_prev[client] + 1) - playerinfo_tickcount[client]) <= icvar[CVAR_BACKTRACK_TOLERANCE]);
}

static void lilac_set_client_in_backtrack_timeout(int client)
{
	// Set the player in backtrack timeout for 1.1 seconds.
	playerinfo_time_backtrack[client] = GetGameTime() + 1.1;

	// Lock value.
	playerinfo_tickcount_diff[client] = (playerinfo_tickcount_prev[client] - (GetGameTickCount() - RoundToNearest(GetClientAvgLatency(client, NetFlow_Outgoing) / GetTickInterval()))) + 1;

	// Clamp the value due to floating point errors and network variability.
	if (playerinfo_tickcount_diff[client] > time_to_ticks(0.2) - 3)
		playerinfo_tickcount_diff[client] = time_to_ticks(0.2) - 3;
	else if (playerinfo_tickcount_diff[client] < ((time_to_ticks(0.2) * -1) + 3))
		playerinfo_tickcount_diff[client] = (time_to_ticks(0.2) * -1) + 3;
}

static bool lilac_is_player_in_backtrack_timeout(int client)
{
	return (GetGameTime() < playerinfo_time_backtrack[client]);
}
