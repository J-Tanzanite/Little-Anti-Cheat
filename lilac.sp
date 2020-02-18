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

/*
	This Anti-Cheat was written for TF2 in mind, there is some
	vague support for CS:GO, a game I don't play. Hopefully it works
	ok on that game, if it doesn't, I'll get around to it eventually.
	You can use this Anti-Cheat for other games, but there may be some
	false positives. I'm not going to prevent people testing it out for
	others games, just warn you that it may cause issues and false bans.

	Little Anti-Cheat detection features:
		Basic Hitscan/Projectile Aimbots.
		Aimlock (Constant snaps, shooting or not).
		Chat Clear.
		NoLerp.
		Basic ConVars.
		Bhop.
		Basic Anti-Aim.
			Legit Anti-Backstab.
			Duckspeed.
	Other features:
		Basic Anti-Aim patch.
			Legit Anti-Backstab patch.
			Duckspeed patch.
		Backtrack patch (DISABLED by default).
		Max ping kicker (Bans players for 3 minutes, DISABLED by default).
		Interp exploit kicker (Kicks players for exploiting interp).

	Some things I wanna mention:
		This Anti-Cheat will be bypassed rather easily.
		Just like SMAC was, fact of the matter is that having an
		opensource Anti-Cheat means it will be bypassed.

		So why am I releasing this?
		Well although updated and maintained cheats will bypass
		this Anti-Cheat, there are so many pastes and opensource
		bases out there which a lot of cheaters use. Many of them
		don't even bypass SMAC. Thus, this Anti-Cheat should be
		helpful in detecting those cheats faster.
		Some bad cheats do bypass SMAC, but are unmaintained, so this
		should be helpful for those cases as well.

		Although this Anti-Cheat does detect premium cheats at the
		time of release, that won't last long, at all.
		This Anti-Cheat was written with the intention to help servers
		deal with free cheats, common cheat bases and terrible cheats.

		The ConVar detection system in this Anti-Cheat is just a
		basic one. It doesn't check for much and is rather simplistic
		and bad. But since since a lot of servers don't even run an
		Anti-Cheat in the first place, it's better than nothing.

		When it comes to my Backtrack patch, it may affect your
		hitreg, so I recommend leaving it off... Sorta...
		In my testing, it hasn't ever caused any hitreg issues.
		Quite literally, I've tested this patch for months now, and
		no legit player has ever had any issues.
		That said, it is interfering with lagcomp, so it is better
		to leave it off as there is a chance that it will make
		some players miss. I recommend testing it out and seeing
		if it's going to work for you and your players.

		As for my max ping check, I know there are plenty of other
		plugins that handle high ping players, the main difference
		between those and this implementation is that this plugin
		bans those players for 3 minutes, so they can't instantly
		rejoin/reconnect.
		This is sorta meant to handle fakelatency, but not every
		sever owner mind having laggy players, so it is off
		by default.
		This is the sort of thing every single server owner have to
		decide for themselves if they wanna use, just as with the
		backtrack patch.

		Lastly, my interp exploit patch is on by default due to how
		often players try to abuse it.
		I've seen enough servers now where admins have to manually
		ban players who they think are abusing it...
*/

#include <sourcemod>
#include <sdktools_engine>
#undef REQUIRE_PLUGIN
#include <sourcebanspp>

#define VERSION "0.7.1"

#define CMD_LENGTH 	330

#define GAME_UNKNOWN 	0
#define GAME_TF2 	1
#define GAME_CSGO 	2

#define CHEAT_ANGLES 		0
#define CHEAT_CHATCLEAR 	1
#define CHEAT_CONVAR 		2
#define CHEAT_NOLERP 		3
#define CHEAT_BHOP 		4
#define CHEAT_AIMBOT 		5
#define CHEAT_AIMLOCK 		6
#define CHEAT_MAX 		7

#define CVAR_ENABLE 		0
#define CVAR_SB			1
#define CVAR_LOG 		2
#define CVAR_LOG_EXTRA 		3
#define CVAR_LOG_DATE 		4
#define CVAR_ANGLES 		5
#define CVAR_PATCH_ANGLES 	6
#define CVAR_CHAT 		7
#define CVAR_CONVAR 		8
#define CVAR_NOLERP 		9
#define CVAR_BHOP 		10
#define CVAR_AIMBOT 		11
#define CVAR_AIMLOCK 		12
#define CVAR_BACKTRACK_PATCH 	13
#define CVAR_MAX_PING		14
#define CVAR_MAX_LERP 		15
#define CVAR_MAX 		16

#define COND_TAUNT 	(1 << 7)

#define ACTION_SHOT 	1

#define QUERY_MAX_FAILURES 	30
#define QUERY_TIMEOUT 		30.0

#define AIMBOT_BAN_MIN 			5
#define AIMBOT_MAX_TOTAL_DELTA 		(180.0 * 2.5)
#define AIMBOT_FLAG_REPEAT 		(1 << 0)
#define AIMBOT_FLAG_AUTOSHOOT 		(1 << 1)
#define AIMBOT_FLAG_SNAP 		(1 << 2)
#define AIMBOT_FLAG_SNAP2 		(1 << 3)

// Convars.
Handle cvar_bhop = null;
Handle cvar[CVAR_MAX];
int icvar[CVAR_MAX];
int cvar_bhop_value = 0;
int sv_maxupdaterate = 0;
int sv_cheats = 0;
int time_sv_cheats = 0;

// Misc.
int ggame;
char line[2048];
char dateformat[512] = "%Y/%m/%d %H:%M:%S";
float max_angles[3] = {89.01, 0.0, 50.01};
Handle forwardhandle = INVALID_HANDLE;
bool sourcebans_exist = false;
bool ignore_lerp[MAXPLAYERS + 1];

// Logging.
int log_index[MAXPLAYERS + 1];
int log_tickcount[MAXPLAYERS + 1];
int log_buttons[MAXPLAYERS + 1][CMD_LENGTH];
int log_actions[MAXPLAYERS + 1][CMD_LENGTH];
float log_angles[MAXPLAYERS + 1][CMD_LENGTH][3];
float log_death_pos[MAXPLAYERS + 1][MAXPLAYERS + 1][2][3];
bool log_banned_flags[MAXPLAYERS + 1][CHEAT_MAX];

// Misc logging.
int log_autoshoot[MAXPLAYERS + 1];
int log_jumps[MAXPLAYERS + 1];
int log_high_ping[MAXPLAYERS + 1];
int log_query_index[MAXPLAYERS + 1];
int log_failed_query[MAXPLAYERS + 1];
int log_aimlock_sus[MAXPLAYERS + 1];

// Detections.
int log_bhop[MAXPLAYERS + 1];
int log_aimbot[MAXPLAYERS + 1];
int log_aimlock[MAXPLAYERS + 1];

// Timestamps.
float time_teleported[MAXPLAYERS + 1];
float time_aimlock[MAXPLAYERS + 1];
float time_backtrack[MAXPLAYERS + 1];

// Basic query list.
char query_list[][] = {
	"sv_cheats",
	"r_drawothermodels",
	"mat_wireframe",
	"snd_show",
	"snd_visualize",
	"mat_proxy",
	"r_drawmodelstatsoverlay",
	"r_shadowwireframe",
	"r_showenvcubemap",
	"r_drawrenderboxes",
	"mat_fullbright",
	"r_modelwireframedecal"
};


public Plugin:myinfo = {
	name = "[Lilac] Little Anti-Cheat",
	author = "J_Tanzanite",
	description = "An opensource Anti-Cheat.",
	version = VERSION,
	url = ""
};


public void OnPluginStart()
{
	Handle tcvar;
	char gamefolder[32];
	GetGameFolderName(gamefolder, sizeof(gamefolder));

	if (StrEqual(gamefolder, "tf", false)) {
		ggame = GAME_TF2;

		HookEvent("player_teleported",
			event_teleported, EventHookMode_Post);
	} else if (StrEqual(gamefolder, "csgo", false)) {
		ggame = GAME_CSGO;

		// Pitch Anti-Aim doesn't work for CSGO anymore,
		// but horrible cheats may still attempt it.
		// max_angles = Float:{0.0, 0.0, 50.01};

		if ((cvar_bhop = FindConVar("sv_autobunnyhopping")) != null) {
			cvar_bhop_value = GetConVarInt(cvar_bhop);
			HookConVarChange(cvar_bhop, cvar_change);
		} else {
			// We weren't able to get the cvar,
			// disable bhop checks just in case.
			cvar_bhop_value = 1;

			PrintToServer("[Lilac] Unable to to find convar \"sv_autobunnyhopping\", bhop checks have been forcefully disabled.");
		}
	} else {
		ggame = GAME_UNKNOWN;
		PrintToServer("[Lilac] This game currently isn't supported, Little Anti-Cheat will still run, but expect some bugs and false positives/bans!");
	}

	if (ggame == GAME_TF2)
		HookEvent("player_death",
			event_player_death_tf2, EventHookMode_Pre);
	else
		HookEvent("player_death",
			event_player_death, EventHookMode_Pre);

	HookEvent("player_spawn", event_teleported, EventHookMode_Post);

	cvar[CVAR_ENABLE] = CreateConVar("lilac_enable", "1",
		"Enable Little Anti-Cheat.",
		FCVAR_PROTECTED, true, 0.0, true, 1.0);
	cvar[CVAR_SB] = CreateConVar("lilac_sourcebans", "1",
		"Ban players via sourcebans++ (If it isn't installed, it will default to basebans).",
		FCVAR_PROTECTED, true, 0.0, true, 1.0);
	cvar[CVAR_LOG] = CreateConVar("lilac_log", "1",
		"Enable cheat logging.",
		FCVAR_PROTECTED, true, 0.0, true, 1.0);
	cvar[CVAR_LOG_EXTRA] = CreateConVar("lilac_log_extra", "1",
		"Log extra information when players are banned.",
		FCVAR_PROTECTED, true, 0.0, true, 1.0);
	cvar[CVAR_LOG_DATE] = CreateConVar("lilac_log_date", "{year}/{month}/{day} {hour}:{minute}:{second}",
		"Which date & time format to use when logging. Type: \"lilac_date_list\" for more info.",
		FCVAR_PROTECTED, false, 0.0, false, 0.0);
	cvar[CVAR_ANGLES] = CreateConVar("lilac_angles", "1",
		"Detect Angle-Cheats (Basic Anti-Aim, Legit Anti-Backstab and Duckspeed).",
		FCVAR_PROTECTED, true, 0.0, true, 1.0);
	cvar[CVAR_PATCH_ANGLES] = CreateConVar("lilac_angles_patch", "1",
		"Patch Angle-Cheats (Basic Anti-Aim, Legit Anti-Backstab and Duckspeed).",
		FCVAR_PROTECTED, true, 0.0, true, 1.0);
	cvar[CVAR_CHAT] = CreateConVar("lilac_chatclear", "1",
		"Detect Chat-Clear.",
		FCVAR_PROTECTED, true, 0.0, true, 1.0);
	cvar[CVAR_CONVAR] = CreateConVar("lilac_convar", "1",
		"Detect basic invalid ConVars.",
		FCVAR_PROTECTED, true, 0.0, true, 1.0);
	cvar[CVAR_NOLERP] = CreateConVar("lilac_nolerp", "1",
		"Detect NoLerp.",
		FCVAR_PROTECTED, true, 0.0, true, 1.0);
	cvar[CVAR_BHOP] = CreateConVar("lilac_bhop", "2",
		"Detect Bhop.\n0 = Disabled.\n1 = Simplistic, ban on 10 Bhops.\n2 = Advanced, ban on 5 Bhops depending on jump count, defaults to 10 on jump spam.",
		FCVAR_PROTECTED, true, 0.0, true, 2.0);
	cvar[CVAR_AIMBOT] = CreateConVar("lilac_aimbot", "5",
		"Detect basic Aimbots.\n0 = Disabled.\n1 = Log only.\n5 or more = ban on n'th detection (Minimum possible is 5)",
		FCVAR_PROTECTED, true, 0.0, false, 0.0);
	cvar[CVAR_AIMLOCK] = CreateConVar("lilac_aimlock", "10",
		"Detect Aimlock.\n0 = Disabled.\n1 = Log only.\n5 or more = ban on n'th detection (Minimum possible is 5).",
		FCVAR_PROTECTED, true, 0.0, false, 0.0);
	cvar[CVAR_BACKTRACK_PATCH] = CreateConVar("lilac_backtrack_patch", "0",
		"Patch Backtrack.\n0 = Disabled (Recommended).\n1 = Enabled (Not recommended, may cause hitreg issues).",
		FCVAR_PROTECTED, true, 0.0, true, 1.0);
	cvar[CVAR_MAX_PING] = CreateConVar("lilac_max_ping", "0",
		"Ban players with too high of a ping for 3 minutes.\nThis is meant to deal with fakelatency, the ban length is just to prevent instant reconnects.\n0 = no ling limit, minimum possible is 100.",
		FCVAR_PROTECTED, true, 0.0, true, 1000.0);
	cvar[CVAR_MAX_LERP] = CreateConVar("lilac_max_lerp", "105",
		"Kick players with an interp higher than this in ms (minimum possible is 105ms, default value in Source games is 100ms).\nThis is done to patch an exploit in the game that makes facestabbing players easier (aka cl_interp 0.5).",
		FCVAR_PROTECTED, true, 105.0, true, 510.0); // 500 is max possible.

	for (int i = 0; i < CVAR_MAX; i++) {
		if (i != CVAR_LOG_DATE)
			icvar[i] = GetConVarInt(cvar[i]);

		HookConVarChange(cvar[i], cvar_change);
	}

	if ((tcvar = FindConVar("sv_maxupdaterate")) != null) {
		HookConVarChange(tcvar, cvar_change);
		sv_maxupdaterate = GetConVarInt(tcvar);
	}

	if ((tcvar = FindConVar("sv_cheats")) != null) {
		HookConVarChange(tcvar, cvar_change);
		sv_cheats = GetConVarInt(tcvar);
	} else {
		sv_cheats = 1;
	}

	// If sv_maxupdaterate is changed mid-game and then this plugin
	// 	is loaded, then it could lead to false positives.
	// 	Ignore nolerp on all players already in game.
	for (int i = 1; i <= MaxClients; i++)
		ignore_lerp[i] = true;

	RegServerCmd("lilac_date_list", lilac_date_list,
		"Lists date formatting options", 0);

	AutoExecConfig(true, "lilac_config", "");

	CreateTimer(5.0, timer_check_nolerp, _, TIMER_REPEAT);
	CreateTimer(5.0, timer_check_latency, _, TIMER_REPEAT);
	CreateTimer(2.0, timer_query, _, TIMER_REPEAT);
	CreateTimer(0.5, timer_check_aimlock, _, TIMER_REPEAT);

	// Create a forward for other plugins to use.
	// 	Like Auto-SourceTV, discord/IRC alerts etc.
	forwardhandle = CreateGlobalForward("lilac_cheater_detected",
		ET_Ignore, Param_Cell, Param_Cell);

	if (icvar[CVAR_LOG])
		lilac_log_first_time_setup();
}

public Action lilac_date_list(int args)
{
	PrintToServer("=======[Lilac Date Formatting]=======");
	PrintToServer("Manual formatting:");
	PrintToServer("\t{raw} = Skips the special formatting listed here");
	PrintToServer("\t        and lets you insert your own formatting");
	PrintToServer("\t        (see: http://www.cplusplus.com/reference/ctime/strftime/).");
	PrintToServer("Example:\n\t{raw}%%Y/%%m/%%d %%H:%%M:%%S");
	PrintToServer("Dates:");
	PrintToServer("\t{year}  = Numerical year  (2020).");
	PrintToServer("\t{month} = Numerical month   (12).");
	PrintToServer("\t{day}   = Numerical day     (28).");
	PrintToServer("Time:");
	PrintToServer("\t{hour}    = 24 hour format.");
	PrintToServer("\t{hours}   = 24 hour format.");
	PrintToServer("\t{24hour}  = 24 hour format.");
	PrintToServer("\t{24hours} = 24 hour format.");
	PrintToServer("\t{12hour}  = 12 hour format.");
	PrintToServer("\t{12hours} = 12 hour format.");
	PrintToServer("\t{pm}      = Insert AM/PM.");
	PrintToServer("\t{am}      = Insert AM/PM.");
	PrintToServer("\t{minute}  = Minute.");
	PrintToServer("\t{minutes} = Minute.");
	PrintToServer("\t{second}  = Second.");
	PrintToServer("\t{seconds} = Second.");
}

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int err_max)
{
	MarkNativeAsOptional("SBPP_BanPlayer");

	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	sourcebans_exist = LibraryExists("sourcebans");
}

public void OnLibraryAdded(const char []name)
{
	if (StrEqual(name, "sourcebans"))
		sourcebans_exist = true;
}

public void OnLibraryRemoved(const char []name)
{
	if (StrEqual(name, "sourcebans"))
		sourcebans_exist = false;
}

public void cvar_change(ConVar convar, const char[] oldValue,
				const char[] newValue)
{
	char cvarname[64];
	char testdate[512];
	GetConVarName(convar, cvarname, sizeof(cvarname));

	// Todo: I find this to be a mess...
	// 	Maybe someone could inform me of a cleaner method of
	// 	doing this? :)
	if (StrEqual(cvarname, "lilac_enable", false)) {
		icvar[CVAR_ENABLE] = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "lilac_sourcebans", false)) {
		icvar[CVAR_SB] = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "lilac_log", false)) {
		icvar[CVAR_LOG] = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "lilac_log_extra", false)) {
		icvar[CVAR_LOG_EXTRA] = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "lilac_log_date", false)) {
		lilac_setup_date_format(newValue);

		FormatTime(testdate, sizeof(testdate), dateformat, GetTime());
		PrintToServer("Date Format Preview: %s", testdate);
	} else if (StrEqual(cvarname, "lilac_angles", false)) {
		icvar[CVAR_ANGLES] = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "lilac_angles_patch", false)) {
		icvar[CVAR_PATCH_ANGLES] = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "lilac_chatclear", false)) {
		icvar[CVAR_CHAT] = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "lilac_convar", false)) {
		icvar[CVAR_CONVAR] = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "lilac_nolerp", false)) {
		icvar[CVAR_NOLERP] = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "lilac_bhop", false)) {
		icvar[CVAR_BHOP] = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "lilac_aimbot", false)) {
		icvar[CVAR_AIMBOT] = StringToInt(newValue, 10);

		if (icvar[CVAR_AIMBOT] > 1 &&
			icvar[CVAR_AIMBOT] < AIMBOT_BAN_MIN)
			icvar[CVAR_AIMBOT] = 5;
	} else if (StrEqual(cvarname, "lilac_aimlock", false)) {
		icvar[CVAR_AIMLOCK] = StringToInt(newValue, 10);

		if (icvar[CVAR_AIMLOCK] > 1
			&& icvar[CVAR_AIMLOCK] < AIMBOT_BAN_MIN)
			icvar[CVAR_AIMLOCK] = 5;
	} else if (StrEqual(cvarname, "lilac_backtrack_patch", false)) {
		icvar[CVAR_BACKTRACK_PATCH] = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "lilac_max_ping", false)) {
		icvar[CVAR_MAX_PING] = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "lilac_max_lerp", false)) {
		icvar[CVAR_MAX_LERP] = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "sv_autobunnyhopping", false)) {
		cvar_bhop_value = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "sv_maxupdaterate", false)) {
		sv_maxupdaterate = StringToInt(newValue);

		// Changing this convar mid-game can cause false positives.
		// 	Ignore players already in-game.
		for (int i = 1; i <= MaxClients; i++)
			ignore_lerp[i] = true;
	} else if (StrEqual(cvarname, "sv_cheats", false)) {
		sv_cheats = StringToInt(newValue);

		// Delay convar checks for 30 seconds.
		time_sv_cheats = GetTime() + 30;
	}
}

public void OnGameFrame()
{
	if (ggame != GAME_TF2)
		return;

	for (int i = 1; i <= MaxClients; i++) {
		if (!is_player_valid(i)
			|| IsFakeClient(i)
			|| !IsPlayerAlive(i))
			continue;

		// Player's view may snap, use the teleport timestamp.
		if (is_player_taunting(i))
			time_teleported[i] = GetGameTime();
	}
}

public void OnClientPutInServer(int client)
{
	ignore_lerp[client] = false;

	log_index[client] = 0;
	log_tickcount[client] = 0;

	log_autoshoot[client] = 0;
	log_jumps[client] = 0;
	log_high_ping[client] = 0;
	log_query_index[client] = 0;
	log_failed_query[client] = 0;
	log_aimlock_sus[client] = 0;

	log_bhop[client] = 0;
	log_aimbot[client] = 0;
	log_aimlock[client] = 0;

	time_teleported[client] = 0.0;
	time_aimlock[client] = 0.0;
	time_backtrack[client] = 0.0;

	for (int i = 0; i < CHEAT_MAX; i++)
		log_banned_flags[client][i] = false;
}

public Action timer_check_latency(Handle timer)
{
	static bool toggle = true;
	char reason[128];
	float ping;

	if (!icvar[CVAR_ENABLE] || icvar[CVAR_MAX_PING] < 100)
		return Plugin_Continue;

	for (int i = 1; i <= MaxClients; i++) {
		if (!is_player_valid(i) || IsFakeClient(i))
			continue;

		// Player just joined, don't check yet.
		if (GetClientTime(i) < 100.0)
			continue;

		ping = GetClientAvgLatency(i, NetFlow_Outgoing) * 1000.0;

		if (ping < float(icvar[CVAR_MAX_PING])) {
			if (log_high_ping[i] > 0 && toggle)
				log_high_ping[i]--;

			continue;
		}

		// Player has had a higher ping than maximum for 45 seconds.
		if (++log_high_ping[i] < 9)
			continue;

		Format(reason, sizeof(reason),
			"[Lilac] Your ping is too high (%.0f / %d max)",
			ping, icvar[CVAR_MAX_PING]);

		// Ban for 3 minutes to prevent instant reconnects.
		BanClient(i, 3, BANFLAG_AUTHID, reason, reason, "lilac", 0);
	}

	toggle = !toggle;

	return Plugin_Continue;
}

public Action timer_check_nolerp(Handle timer)
{
	float min;

	if (!icvar[CVAR_ENABLE])
		return Plugin_Continue;

	for (int i = 1; i <= MaxClients; i++) {
		if (!is_player_valid(i) || IsFakeClient(i))
			continue;

		// Kinda useless...
		if (GetClientTime(i) < 5.0)
			continue;

		float lerp = GetEntPropFloat(i, Prop_Data, "m_fLerpTime");

		// People may see "Anti-Cheat" and assume someone were
		// hacking when they weren't. This is why this just says
		// "Exploit detected" instead of "Little Anti-Cheat".
		if (lerp * 1000.0 > float(icvar[CVAR_MAX_LERP])) {
			KickClient(i, "[Lilac] Exploit detected: Your interp is too high (%.0fms / %dms max).\nPlease set your cl_interp back to 0.1 or lower",
				lerp * 1000.0, icvar[CVAR_MAX_LERP]);

			continue;
		}

		if (sv_maxupdaterate > 0)
			min = 1.0 / float(sv_maxupdaterate);
		else
			min = 0.0;

		if (!icvar[CVAR_NOLERP]
			|| ignore_lerp[i] // Skip checking NoLerp for this player.
			|| log_banned_flags[i][CHEAT_NOLERP] // Already banned.
			|| min < 0.005) // Too low value or sv_maxupdaterate not found.
			continue;

		if (lerp > min * 0.95 /* Buffer */)
			continue;

		log_banned_flags[i][CHEAT_NOLERP] = true;
		lilac_forward_client_cheat(i, CHEAT_NOLERP);

		if (icvar[CVAR_LOG]) {
			lilac_log_setup_client(i);
			Format(line, sizeof(line),
				"%s was detected and banned for NoLerp (%fms)",
				line, lerp * 1000.0);

			lilac_log(true);

			if (icvar[CVAR_LOG_EXTRA])
				lilac_log_extra(i);
		}

		lilac_ban_client(i, CHEAT_NOLERP);
	}

	return Plugin_Continue;
}

public Action timer_query(Handle timer)
{
	if (!icvar[CVAR_ENABLE] || !icvar[CVAR_CONVAR])
		return Plugin_Continue;

	// sv_cheats recently changed or is set to 1, don't query.
	if (GetTime() < time_sv_cheats || sv_cheats)
		return Plugin_Continue;

	for (int i = 1; i <= MaxClients; i++) {
		if (!is_player_valid(i) || IsFakeClient(i))
			continue;

		if (GetClientTime(i) < 30.0)
			continue;

		if (log_banned_flags[i][CHEAT_CONVAR])
			continue;

		// Only increments query index if the player
		// 	has responded to the last one.
		if (!log_failed_query[i])
			log_query_index[i] = (log_query_index[i] + 1) % 12;

		QueryClientConVar(i, query_list[log_query_index[i]], query_reply, 0);

		if (++log_failed_query[i] > QUERY_MAX_FAILURES)
			KickClient(i, "[Lilac] Error: Query response failure, please restart your game if this issue persists");
	}

	return Plugin_Continue;
}

public void query_reply(QueryCookie cookie, int client,
			ConVarQueryResult result, const char[] cvarName,
			const char[] cvarValue, any value)
{
	if (result != ConVarQuery_Okay)
		return;

	// Client did respond to the query request, move on to the next convar.
	log_failed_query[client] = 0;

	// Any response the server may recieve may also be faulty, ignore.
	if (GetTime() < time_sv_cheats || sv_cheats)
		return;

	// Already banned.
	if (log_banned_flags[client][CHEAT_CONVAR])
		return;

	int val = StringToInt(cvarValue);

	if ((StrEqual("sv_cheats", cvarName, false) && val)
		|| (StrEqual("r_drawothermodels", cvarName, false) && val != 1)
		|| (StrEqual("mat_wireframe", cvarName, false) && val)
		|| (StrEqual("snd_show", cvarName, false) && val)
		|| (StrEqual("snd_visualize", cvarName, false) && val)
		|| (StrEqual("mat_proxy", cvarName, false) && val)
		|| (StrEqual("r_drawmodelstatsoverlay", cvarName, false) && val)
		|| (StrEqual("r_shadowwireframe", cvarName, false) && val)
		|| (StrEqual("r_showenvcubemap", cvarName, false) && val)
		|| (StrEqual("r_drawrenderboxes", cvarName, false) && val)
		|| (StrEqual("mat_fullbright", cvarName, false) && val)
		|| (StrEqual("r_modelwireframedecal", cvarName, false) && val)) {

		lilac_forward_client_cheat(client, CHEAT_CONVAR);

		if (icvar[CVAR_LOG]) {
			lilac_log_setup_client(client);
			Format(line, sizeof(line),
				"%s was detected and banned for an invalid ConVar (%s %s).",
				line, cvarName, cvarValue);

			lilac_log(true);

			if (icvar[CVAR_LOG_EXTRA])
				lilac_log_extra(client);
		}

		log_banned_flags[client][CHEAT_CONVAR] = true;
		lilac_ban_client(client, CHEAT_CONVAR);
	}
}

// Quite literally the worst function ever... Eww...
public Action timer_check_aimlock(Handle timer)
{
	float ang[3], lang[3], ideal[3], pos[3], pos2[3];
	float aimdist, laimdist;
	int lock = 0;
	bool process;

	if (!icvar[CVAR_ENABLE] || !icvar[CVAR_AIMLOCK])
		return Plugin_Continue;

	for (int i = 1; i <= MaxClients; i++) {
		if (!is_player_valid(i) || IsFakeClient(i))
			continue;

		if (!IsPlayerAlive(i) || GetClientTeam(i) < 2)
			continue;

		if (GetGameTime() - time_teleported[i] < 2.0)
			continue;

		if (log_banned_flags[i][CHEAT_AIMLOCK])
			continue;

		process = true;
		GetClientEyePosition(i, pos);

		for (int k = 1; k <= MaxClients && process; k++) {
			if (!is_player_valid(k) || k == i)
				continue;

			if (GetClientTeam(k) == GetClientTeam(i))
				continue;

			if (GetClientTeam(k) < 2 || !IsPlayerAlive(k))
				continue;

			GetClientEyePosition(k, pos2);
			aim_at_point(pos, pos2, ideal);

			lock = 0;
			int ind = log_index[i];
			for (int l = 0; l < time_to_ticks(0.5) + 2; l++) {
				if (ind < 0)
					ind = CMD_LENGTH - 1;

				ang = log_angles[i][ind];
				laimdist = angle_delta(ang, ideal);

				if (l) {
					if (aimdist < 10.0)
						lock++;
					else
						lock = 0;

					if (aimdist < laimdist * 0.1
						&& angle_delta(ang, lang) > 10.0
						&& lock > time_to_ticks(0.1)) {
						process = false;
						lilac_detected_aimlock(i);
					}
				}

				ind--;
				lang = ang;
				aimdist = laimdist;
			}
		}
	}

	return Plugin_Continue;
}

public Action event_teleported(Event event, const char[] name,
				bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid", -1));

	if (is_player_valid(client))
		time_teleported[client] = GetGameTime();
}

public Action event_player_death(Event event, const char[] name,
					bool dontBroadcast)
{
	if (!icvar[CVAR_ENABLE] || !icvar[CVAR_AIMBOT])
		return Plugin_Continue;

	int userid = GetEventInt(event, "attacker", -1);
	int client = GetClientOfUserId(userid);
	int victim = GetClientOfUserId(GetEventInt(event, "userid", -1));

	event_death_shared(userid, client, victim, false);
	return Plugin_Continue;
}

// Todo: Ehh, needs some work, not pretty.
public Action event_player_death_tf2(Event event, const char[] name,
					bool dontBroadcast)
{
	if (!icvar[CVAR_ENABLE] || !icvar[CVAR_AIMBOT])
		return Plugin_Continue;

	char wep[64];
	int userid = GetEventInt(event, "attacker", -1);
	int client = GetClientOfUserId(userid);
	int victim = GetClientOfUserId(GetEventInt(event, "userid", -1));
	int killtype = GetEventInt(event, "customkill", 0);
	GetEventString(event, "weapon_logclassname", wep, sizeof(wep), "");

	if (!strncmp(wep, "obj_", 4, false)) // Ignore sentry
		return Plugin_Continue;

	// Killtype 3 = flamethrower.
	event_death_shared(userid, client, victim,
		((killtype == 3) ? true : false));

	return Plugin_Continue;
}

void event_death_shared(int userid, int client, int victim, bool skip_delta)
{
	char string[16];
	DataPack pack;

	if (client == victim)
		return;

	if (!is_player_valid(client)
		|| IsFakeClient(client)
		|| log_banned_flags[client][CHEAT_AIMBOT]
		|| GetClientTime(client) < 10.1)
		return;

	GetClientEyePosition(client, log_death_pos[client][victim][0]);
	GetClientEyePosition(victim, log_death_pos[client][victim][1]);

	// Killer and victim are close to each other,
	// Tell the aimbot test that we should ignore some detections.
	if (GetVectorDistance(log_death_pos[client][victim][0],
		log_death_pos[client][victim][1]) < 200.0
		|| skip_delta)
		userid *= -1;

	// For some reason, we can't send two ints...
	// So, we're going to send a string containing the number...
	// ... yeah not pretty, shush.
	IntToString(victim, string, sizeof(string));
	CreateDataTimer(0.5, timer_check_aimbot, pack);
	pack.WriteCell(userid);
	pack.WriteString(string);
}

public Action timer_check_aimbot(Handle timer, DataPack pack)
{
	int userid;
	int victim;
	char string[16];
	float delta = 0.0;
	float total_delta = 0.0;
	float aimdist = 0.0;
	float laimdist = 0.0;
	float tdelta = 0.0;
	float ang[3], lang[3], ideal[3];
	int detected = 0;
	int shotindex = -1;
	bool skip_snap = false;
	bool skip_autoshoot = false;
	bool skip_repeat = false;
	int client;
	int ind;
	int tmp;

	pack.Reset();
	userid = pack.ReadCell();
	pack.ReadString(string, sizeof(string));
	victim = StringToInt(string);

	if (!is_player_valid(victim)) {
		skip_snap = true;
		victim = 0;
	}

	if (userid < 0) {
		userid *= -1;
		skip_snap = true;
	}

	client = GetClientOfUserId(userid);

	if (!is_player_valid(client))
		return;

	// Locate the tick where the client shot.
	ind = log_index[client]-1;
	tmp = 0;
	for (int i = 0; i < CMD_LENGTH - time_to_ticks(1.1); i++) {
		if (ind < 0)
			ind += CMD_LENGTH;

		if ((log_actions[client][ind] & ACTION_SHOT)) {
			shotindex = ind;
			break;
		}

		ind--;
		tmp++;
	}

	// Shot not found; use the latest index.
	if (shotindex == -1) {
		skip_autoshoot = true;
		skip_repeat = true;
		shotindex = log_index[client] - time_to_ticks(0.5);
		tmp = time_to_ticks(0.5);
		if (shotindex < 0)
			shotindex += CMD_LENGTH;
	} else {
		// Don't check this shot in the future.
		log_actions[client][shotindex] = 0;
	}

	if (GetGameTime()
		- ticks_to_time(tmp /* Time since taunt */ + 5 /* Buffer */)
		- GetClientAvgLatency(client, NetFlow_Outgoing)
		- time_teleported[client] < 0.5)
		skip_snap = true;

	// Total delta and AimSnap test.
	if (skip_snap == false) {
		aim_at_point(log_death_pos[client][victim][0],
			log_death_pos[client][victim][1], ideal);
		ind = shotindex;

		for (int i = 0; i < time_to_ticks(0.5); i++) {
			if (ind < 0)
				ind += CMD_LENGTH;

			laimdist = angle_delta(log_angles[client][ind], ideal);
			ang = log_angles[client][ind];

			if (i) {
				tdelta = angle_delta(lang, ang);

				if (tdelta > delta)
					delta = tdelta;

				total_delta += tdelta;

				// Todo: Merge these and use one flag.
				// 	Currently using both in case of a
				// 	false positive. Makes fixing it easier.
				if (aimdist < laimdist * 0.2 && tdelta > 10.0)
					detected |= AIMBOT_FLAG_SNAP;

				if (aimdist < laimdist * 0.1 && tdelta > 5.0)
					detected |= AIMBOT_FLAG_SNAP2;
			}

			lang = ang;
			aimdist = laimdist;
			ind--;
		}
	}

	// Angle-Repeat test.
	if (skip_repeat == false) {
		ang = log_angles[client][normalize_index(shotindex-1)];
		lang = log_angles[client][normalize_index(shotindex+1)];
		tdelta = angle_delta(ang, lang);
		lang = log_angles[client][shotindex];

		if (tdelta < 10.0 && angle_delta(ang, lang) > 0.5
			&& angle_delta(ang, lang) > tdelta * 5.0)
			detected |= AIMBOT_FLAG_REPEAT;
	}

	// Autoshoot Test.
	if (skip_autoshoot == false) {
		tmp = 0;
		ind = shotindex+1;
		for (int i = 0; i < 3; i++) {
			if (ind < 0)
				ind += CMD_LENGTH;
			else if (ind >= CMD_LENGTH)
				ind -= CMD_LENGTH;

			if ((log_buttons[client][ind] & IN_ATTACK))
				tmp++;

			ind--;
		}

		if (tmp == 1) {
			if (++log_autoshoot[client] > 2 || detected)
				detected |= AIMBOT_FLAG_AUTOSHOOT;
		} else {
			log_autoshoot[client] = 0;
		}
	}

	if (total_delta > AIMBOT_MAX_TOTAL_DELTA || detected)
		lilac_detected_aimbot(client, delta, total_delta, detected);
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse,
				float vel[3], float angles[3], int& weapon,
				int& subtype, int& cmdnum, int& tickcount,
				int& seed, int mouse[2])
{
	static int lbuttons[MAXPLAYERS + 1];

	if (!is_player_valid(client) || IsFakeClient(client))
		return Plugin_Continue;

	// Log player information.
	log_index[client] = (log_index[client] + 1) % CMD_LENGTH;

	log_angles[client][log_index[client]] = angles;
	log_buttons[client][log_index[client]] = buttons;
	log_actions[client][log_index[client]] = 0; // Clear bits.

	if ((buttons & IN_ATTACK) && bullettime_can_shoot(client))
		log_actions[client][log_index[client]] = ACTION_SHOT;

	if (!icvar[CVAR_ENABLE]) {
		lbuttons[client] = buttons;
		log_tickcount[client] = tickcount;

		return Plugin_Continue;
	}

	// Patch backtracking.
	if (icvar[CVAR_BACKTRACK_PATCH]) {
		if (log_tickcount[client] + 1 != tickcount
			&& time_backtrack[client] < GetGameTime())
			time_backtrack[client] = GetGameTime() + 10.0;

		log_tickcount[client] = tickcount;

		if (GetGameTime() < time_backtrack[client])
			tickcount = log_tickcount[client]
				+ GetRandomInt(0, time_to_ticks(0.4))
				- time_to_ticks(0.2);
	} else {
		log_tickcount[client] = tickcount;
	}

	// Angles test (Detects out of range values).
	if (icvar[CVAR_ANGLES] && IsPlayerAlive(client)
		&& GetGameTime() > time_teleported[client] + 5.0) {
		for (int i = 0; i < 3; i++) {
			if (max_angles[i] == 0.0)
				continue;

			if (FloatAbs(angles[i]) > max_angles[i])
				lilac_detected_antiaim(client);
		}
	}

	// Patch Angles.
	// 	Players banned for angle cheats will still be
	// 	on the server for a few ticks, in the meantime,
	// 	their angles won't mess anything up.
	// 	Plus this prevents the console from getting spammed.
	if (icvar[CVAR_PATCH_ANGLES]) {
		// Patch Pitch.
		if (angles[0] > max_angles[0])
			angles[0] = max_angles[0];
		else if (angles[0] < (max_angles[0] * -1.0))
			angles[0] = (max_angles[0] * -1.0);

		// Patching yaw AA will interfere with aimbot/aimlock tests.

		// Patch roll.
		angles[2] = 0.0;
	}

	// Bhop test.
	// 	Todo: Should add air time check?
	if (!cvar_bhop_value && icvar[CVAR_BHOP]) {
		int flags = GetEntityFlags(client);
		if ((buttons & IN_JUMP) && !(lbuttons[client] & IN_JUMP)) {
			if ((flags & FL_ONGROUND)) {
				lilac_detected_bhop(client);

				log_bhop[client]++;
			}

			log_jumps[client]++;
		} else if ((flags & FL_ONGROUND)) {
			log_jumps[client] = 0;
			log_bhop[client] = 0;
		}
	}

	lbuttons[client] = buttons;
	return Plugin_Continue;
}

// Todo: Ok... This needs work... A lot of it too.
// 	Doesn't work on Huntsman or melee.
// 	Also, may not work correctly in other games?
// 	Seriously, I haven't changed this since 2018...
// 	It works for like 90% of weapons, so haven't bothered...
bool bullettime_can_shoot(int client)
{
	int weapon;

	if (!IsPlayerAlive(client))
		return false;

	weapon = GetEntPropEnt(client, Prop_Data, "m_hActiveWeapon");

	if (!IsValidEntity(weapon))
		return false;

	if (GetEntPropFloat(client, Prop_Data, "m_flSimulationTime")
		+ GetTickInterval()
		>= GetEntPropFloat(weapon, Prop_Data, "m_flNextPrimaryAttack"))
		return true;

	return false;
}

void lilac_detected_aimlock(int client)
{
	if (log_banned_flags[client][CHEAT_AIMLOCK])
		return;

	// Suspicions reset after 3 minutes.
	if (GetGameTime() - time_aimlock[client] < 180.0)
		log_aimlock_sus[client]++;
	else
		log_aimlock_sus[client] = 1;

	time_aimlock[client] = GetGameTime();

	if (log_aimlock_sus[client] < 2)
		return;

	log_aimlock_sus[client] = 0;

	lilac_forward_client_cheat(client, CHEAT_AIMLOCK);
	CreateTimer(600.0, timer_decrement_aimlock, GetClientUserId(client));

	// Ignore the first detection, not really needed
	// 	as it takes three snaps to get a detection...
	// 	But better safe than sorry.
	if (++log_aimlock[client] < 2)
		return;

	if (icvar[CVAR_LOG]) {
		lilac_log_setup_client(client);
		Format(line, sizeof(line),
			"%s is suspected of using an aimlock (Detection: %d).",
			line, log_aimlock[client]);

		lilac_log(true);
	}

	if (log_aimlock[client] >= icvar[CVAR_AIMLOCK]
		&& icvar[CVAR_AIMLOCK] >= 5) {
		log_banned_flags[client][CHEAT_AIMLOCK] = true;

		if (icvar[CVAR_LOG]) {
			lilac_log_setup_client(client);
			Format(line, sizeof(line),
				"%s was banned for Aimlock.", line);

			lilac_log(true);

			if (icvar[CVAR_LOG_EXTRA])
				lilac_log_extra(client);
		}

		lilac_ban_client(client, CHEAT_AIMLOCK);
	}
}

void lilac_detected_bhop(int client)
{
	if (log_banned_flags[client][CHEAT_BHOP])
		return;

	// Mode 1 = Simplistic, bans players on their 10th bhop.
	// Mode 2 = Advanced (not really), bans players on their 5th bhop,
	// 	if they are spamming the jump key then it
	// 	bans on the 10th.
	switch (icvar[CVAR_BHOP]) {
	case 1: {
		if (log_bhop[client] < 10)
			return;
	}
	case 2: {
		if (log_bhop[client] < 5)
			return;
		else if (log_jumps[client] > 15 && log_bhop[client] < 10)
			return;
	}
	default: return;
	}

	log_banned_flags[client][CHEAT_BHOP] = true;
	lilac_forward_client_cheat(client, CHEAT_BHOP);

	if (icvar[CVAR_LOG]) {
		lilac_log_setup_client(client);
		Format(line, sizeof(line),
			"%s was detected and banned for Bhop (Jumps Presses: %d | Bhops: %d).",
			line, log_jumps[client], log_bhop[client]);

		lilac_log(true);

		if (icvar[CVAR_LOG_EXTRA])
			lilac_log_extra(client);
	}

	lilac_ban_client(client, CHEAT_BHOP);
}

void lilac_detected_antiaim(int client)
{
	if (log_banned_flags[client][CHEAT_ANGLES])
		return;

	log_banned_flags[client][CHEAT_ANGLES] = true;
	lilac_forward_client_cheat(client, CHEAT_ANGLES);

	if (icvar[CVAR_LOG]) {
		lilac_log_setup_client(client);
		Format(line, sizeof(line),
			"%s was detected and banned for Angle-Cheats (Pitch: %.2f, Yaw: %.2f, Roll: %.2f).",
			line,
			log_angles[client][log_index[client]][0],
			log_angles[client][log_index[client]][1],
			log_angles[client][log_index[client]][2]);

		lilac_log(true);

		if (icvar[CVAR_LOG_EXTRA])
			lilac_log_extra(client);
	}

	lilac_ban_client(client, CHEAT_ANGLES);
}

void lilac_detected_aimbot(int client, float delta, float td, int flags)
{
	if (log_banned_flags[client][CHEAT_AIMBOT])
		return;

	lilac_forward_client_cheat(client, CHEAT_AIMBOT);

	// Detection expires in 10 minutes.
	CreateTimer(600.0, timer_decrement_aimbot, GetClientUserId(client));

	// Don't log the first detection.
	if (++log_aimbot[client] < 2)
		return;

	if (icvar[CVAR_LOG]) {
		lilac_log_setup_client(client);
		Format(line, sizeof(line),
			"%s is suspected of using an aimbot (Detection: %d | Delta: %.0f | TotalDelta: %.0f | Detected:%s%s%s%s%s).",
			line, log_aimbot[client], delta, td,
			((flags & AIMBOT_FLAG_SNAP)      ? " Aim-Snap"     : ""),
			((flags & AIMBOT_FLAG_SNAP2)     ? " Aim-Snap2"    : ""),
			((flags & AIMBOT_FLAG_AUTOSHOOT) ? " Autoshoot"    : ""),
			((flags & AIMBOT_FLAG_REPEAT)    ? " Angle-Repeat" : ""),
			((td > AIMBOT_MAX_TOTAL_DELTA)   ? " Total-Delta"  : ""));

		lilac_log(true);
	}

	if (log_aimbot[client] >= icvar[CVAR_AIMBOT]
		&& icvar[CVAR_AIMBOT] >= AIMBOT_BAN_MIN) {

		if (icvar[CVAR_LOG]) {
			lilac_log_setup_client(client);
			Format(line, sizeof(line),
				"%s was banned for Aimbot.", line);

			lilac_log(true);

			if (icvar[CVAR_LOG_EXTRA])
				lilac_log_extra(client);
		}

		log_banned_flags[client][CHEAT_AIMBOT] = true;
		lilac_ban_client(client, CHEAT_AIMBOT);
	}
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	// Prevent players banned for Chat-Clear
	// 	from spamming chat.
	// 	Helps legit players see the cheater
	// 	was banned in chat (disconnect reason).
	if (log_banned_flags[client][CHEAT_CHATCLEAR])
		return Plugin_Stop;

	return Plugin_Continue;
}

public void OnClientSayCommand_Post(int client, const char[] command,
					const char[] sArgs)
{
	// As far as I know, CSGO is the only game where this doesn't work.
	if (ggame == GAME_CSGO)
		return;

	if (!icvar[CVAR_CHAT] || !icvar[CVAR_ENABLE])
		return;

	// Don't log chat-clear more than once.
	if (log_banned_flags[client][CHEAT_CHATCLEAR])
		return;

	if (does_string_contain_newline(sArgs)) {
		log_banned_flags[client][CHEAT_CHATCLEAR] = true;
		lilac_forward_client_cheat(client, CHEAT_CHATCLEAR);

		if (icvar[CVAR_LOG]) {
			lilac_log_setup_client(client);
			Format(line, sizeof(line),
				"%s was detected and banned for Chat-Clear (Chat message: %s)",
				line, sArgs);

			lilac_log(true);

			if (icvar[CVAR_LOG_EXTRA])
				lilac_log_extra(client);
		}

		lilac_ban_client(client, CHEAT_CHATCLEAR);
	}
}

bool does_string_contain_newline(const char []string)
{
	for (int i = 0; string[i]; i++) {
		// Newline or carriage return.
		if (string[i] == '\n' || string[i] == 0x0d)
			return true;
	}

	return false;
}

// Todo: / Debate: Add everything listed here?
// 	http://www.cplusplus.com/reference/ctime/strftime/
void lilac_setup_date_format(const char []format)
{
	strcopy(dateformat, sizeof(dateformat), format);

	if (ReplaceString(dateformat, sizeof(dateformat), "{raw}", "", false))
		return;

	ReplaceString(dateformat, sizeof(dateformat), "%%", "%%%%", false);

	ReplaceString(dateformat, sizeof(dateformat), "{year}", "%Y", false);
	ReplaceString(dateformat, sizeof(dateformat), "{month}", "%m", false);
	ReplaceString(dateformat, sizeof(dateformat), "{day}", "%d", false);

	ReplaceString(dateformat, sizeof(dateformat), "{hour}", "%H", false);
	ReplaceString(dateformat, sizeof(dateformat), "{hours}", "%H", false);
	ReplaceString(dateformat, sizeof(dateformat), "{24hour}", "%H", false);
	ReplaceString(dateformat, sizeof(dateformat), "{24hours}", "%H", false);
	ReplaceString(dateformat, sizeof(dateformat), "{12hour}", "%I", false);
	ReplaceString(dateformat, sizeof(dateformat), "{12hours}", "%I", false);
	ReplaceString(dateformat, sizeof(dateformat), "{pm}", "%p", false);
	ReplaceString(dateformat, sizeof(dateformat), "{am}", "%p", false);

	ReplaceString(dateformat, sizeof(dateformat), "{minute}", "%M", false);
	ReplaceString(dateformat, sizeof(dateformat), "{minutes}", "%M", false);
	ReplaceString(dateformat, sizeof(dateformat), "{second}", "%S", false);
	ReplaceString(dateformat, sizeof(dateformat), "{seconds}", "%S", false);
}

void lilac_log_setup_client(int client)
{
	char date[512], steamid[64], ip[64];

	FormatTime(date, sizeof(date), dateformat, GetTime());

	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid), true);
	GetClientIP(client, ip, sizeof(ip), true);

	Format(line, sizeof(line),
		"%s [Version %s] {Name: \"%N\" | SteamID: %s | IP: %s}",
		date, VERSION, client, steamid, ip);
}

void lilac_log_extra(int client)
{
	char map[128], weapon[64];
	float pos[3];

	GetClientAbsOrigin(client, pos);
	GetCurrentMap(map, sizeof(map));
	GetClientWeapon(client, weapon, sizeof(weapon));

	Format(line, sizeof(line),
		"\tPos={%.0f,%.0f,%.0f}, Angles={%.5f,%.5f,%.5f}, Map=\"%s\", Team={%d}, Weapon=\"%s\", Latency={Inc:%f,Out:%f}, Loss={Inc:%f,Out:%f}, Choke={Inc:%f,Out:%f}, ConnectionTime={%f seconds}, GameTime={%f seconds}",
		pos[0], pos[1], pos[2],
		log_angles[client][log_index[client]][0],
		log_angles[client][log_index[client]][1],
		log_angles[client][log_index[client]][2],
		map, GetClientTeam(client), weapon,
		GetClientAvgLatency(client, NetFlow_Incoming),
		GetClientAvgLatency(client, NetFlow_Outgoing),
		GetClientAvgLoss(client, NetFlow_Incoming),
		GetClientAvgLoss(client, NetFlow_Outgoing),
		GetClientAvgChoke(client, NetFlow_Incoming),
		GetClientAvgChoke(client, NetFlow_Outgoing),
		GetClientTime(client), GetGameTime());

	lilac_log(false);
}

void lilac_log(bool cleanup)
{
	Handle file = OpenFile("lilac.log", "a");

	if (file == null) {
		PrintToServer("[Lilac] Cannot open log file.");
		return;
	}

	// Remove invalid characters.
	// This doesn't care about invalid utf-8 formatting,
	// only ASCII control characters.
	if (cleanup) {
		for (int i = 0; line[i]; i++) {
			if (line[i] == '\n' || line[i] == 0x0d)
				line[i] = '*';
			else if (line[i] < 32)
				line[i] = '#';
		}
	}

	WriteFileLine(file, line);
	CloseHandle(file);
}

void lilac_log_first_time_setup()
{
	// Some admins may not understand how to interpret cheat logs
	// correctly, thus, we should warn them so they don't panic
	// over trivial stuff.
	if (!FileExists("lilac.log", false, NULL_STRING)) {
		Format(line, sizeof(line),
"=========[Notice]=========\n\
Thank you for installing Little Anti-Cheat %s!\n\
Just a few notes about this Anti-Cheat:\n\n\
If a player is logged as \"suspected\" of using cheats, they are not necessarily cheating.\n\
If the suspicions logged are few and rare, they are likely false positives.\n\
An automatic ban is triggered by 5 or more \"suspicions\" or by one \"detection\".\n\
If you think a ban may be incorrect, please do not hesitate to let me know.\n\n\
That is all, have a wonderful day~\n\n\n", VERSION);
		lilac_log(false);
	}
}

// Todo: Verify this works correctly.
// 	I have never used sourcebans, so...
// 	Someone help! D:
void lilac_ban_client(int client, int cheat)
{
	char reason[128];

	switch (cheat) {
	case CHEAT_ANGLES: { Format(reason, sizeof(reason),
		"[Little Anti-Cheat %s] Angle-Cheats Detected", VERSION); }
	case CHEAT_CHATCLEAR: { Format(reason, sizeof(reason),
		"[Little Anti-Cheat %s] Chat-Clear Detected", VERSION); }
	case CHEAT_CONVAR: { Format(reason, sizeof(reason),
		"[Little Anti-Cheat %s] Invalid ConVar Detected", VERSION); }
	// It saying "convar violation" for nolerp is intentional.
	case CHEAT_NOLERP: { Format(reason, sizeof(reason),
		"[Little Anti-Cheat %s] Invalid ConVar Detected", VERSION); }
	case CHEAT_BHOP: { Format(reason, sizeof(reason),
		"[Little Anti-Cheat %s] BHop Detected", VERSION); }
	case CHEAT_AIMBOT: { Format(reason, sizeof(reason),
		"[Little Anti-Cheat %s] Aimbot Detected", VERSION); }
	case CHEAT_AIMLOCK: { Format(reason, sizeof(reason),
		"[Little Anti-Cheat %s] Aimlock Detected", VERSION); }
	default: return;
	}

	if (sourcebans_exist && icvar[CVAR_SB])
		SBPP_BanPlayer(0, client, 0, reason);
	else
		BanClient(client, 0, BANFLAG_AUTO, reason, reason, "lilac", 0);

	// Kick the client in case they are still on the server.
	CreateTimer(5.0, timer_kick, GetClientUserId(client));
}

public Action timer_kick(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if (is_player_valid(client))
		KickClient(client, "You have been banned from this server");
}

void aim_at_point(const float p1[3], const float p2[3], float writeto[3])
{
	SubtractVectors(p2, p1, writeto);
	GetVectorAngles(writeto, writeto);

	while (writeto[0] > 90.0)
		writeto[0] -= 360.0;
	while (writeto[0] < -90.0)
		writeto[0] += 360.0;
	while (writeto[1] > 180.0)
		writeto[1] -= 360.0;
	while (writeto[1] < -180.0)
		writeto[1] += 360.0;

	writeto[2] = 0.0;
}

float angle_delta(float a1[3], float a2[3])
{
	int normal = 5;
	float p1[3], p2[3], delta;
	p1 = a1;
	p2 = a2;

	// Ignore roll.
	p1[2] = 0.0;
	p2[2] = 0.0;

	delta = GetVectorDistance(p1, p2);

	// Normalize maximum 5 times, yaw can sometimes be odd.
	while (delta > 180.0 && normal > 0) {
		normal--;
		delta = FloatAbs(delta - 360.0);
	}

	return delta;
}

int normalize_index(int index)
{
	int i = index;

	while (i >= CMD_LENGTH)
		i -= CMD_LENGTH;
	while (i < 0)
		i += CMD_LENGTH;

	return i;
}

int time_to_ticks(float time)
{
	if (time > 0.0)
		return RoundToNearest(time / GetTickInterval());

	return 0;
}

float ticks_to_time(int ticks)
{
	return ticks * GetTickInterval();
}

bool is_player_valid(int client)
{
	return (client >= 1 && client <= MaxClients
		&& IsClientConnected(client) && IsClientInGame(client));
}

public Action timer_decrement_aimbot(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if (!is_player_valid(client))
		return;

	if (log_aimbot[client] > 0)
		log_aimbot[client]--;
}

public Action timer_decrement_aimlock(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if (!is_player_valid(client))
		return;

	if (log_aimlock[client] > 0)
		log_aimlock[client]--;
}

void lilac_forward_client_cheat(int client, int cheat)
{
	int dummy;

	if (forwardhandle == null)
		return;

	Call_StartForward(forwardhandle);
	Call_PushCell(client);
	Call_PushCell(cheat);
	Call_Finish(dummy);
}

// Function borrowed from https://sm.alliedmods.net/new-api/tf2_stocks/__raw
// and heavily modified...
// Sadly, whenever I include tf2 or tf2_stocks, this plugin
// refuses to load for other games, like CS:GO...
// I don't know why, so this is a temp solution.
// Currently, taunting is the only condition that allows players to "snap"
// their view without cheating, so I only need to check for one cond.
bool is_player_taunting(int client)
{
	if ((GetEntProp(client, Prop_Send, "m_nPlayerCond") & COND_TAUNT) == COND_TAUNT)
		return true;

	if ((GetEntProp(client, Prop_Send, "_condition_bits") & COND_TAUNT) == COND_TAUNT)
		return true;

	return false;
}






























































//
