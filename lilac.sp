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

#include <sourcemod>
#include <sdktools_engine>
#undef REQUIRE_PLUGIN
#undef REQUIRE_EXTENSIONS
#include <sourcebanspp>
#include <tf2>
#include <tf2_stocks>

#define VERSION "1.1.0"

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
#define CVAR_WELCOME 		1
#define CVAR_SB			2
#define CVAR_LOG 		3
#define CVAR_LOG_EXTRA 		4
#define CVAR_LOG_MISC 		5
#define CVAR_LOG_DATE 		6
#define CVAR_ANGLES 		7
#define CVAR_PATCH_ANGLES 	8
#define CVAR_CHAT 		9
#define CVAR_CONVAR 		10
#define CVAR_NOLERP 		11
#define CVAR_BHOP 		12
#define CVAR_AIMBOT 		13
#define CVAR_AIMLOCK 		14
#define CVAR_AIMLOCK_LIGHT 	15
#define CVAR_BACKTRACK_PATCH 	16
#define CVAR_MAX_PING		17
#define CVAR_MAX_LERP 		18
#define CVAR_LOSS_FIX 		19
#define CVAR_MAX 		20

#define ACTION_SHOT 	1

#define QUERY_MAX_FAILURES 	12
#define QUERY_TIMEOUT 		30
#define QUERY_TIMER 		5.0

#define AIMLOCK_BAN_MIN 	5

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
int sv_cheats = 0;
int time_sv_cheats = 0;
int cvar_bhop_value = 0;
int sv_maxupdaterate = 0;

// Misc.
int ggame;
char line[2048];
char dateformat[512] = "%Y/%m/%d %H:%M:%S";
float max_angles[3] = {89.01, 0.0, 50.01};
Handle forwardhandle = INVALID_HANDLE;
Handle forwardhandleban = INVALID_HANDLE;
Handle forwardhandleallow = INVALID_HANDLE;
bool sourcebans_exist = false;

// Logging.
enum struct struct_player {
	int index;
	int tickcount;
	int buttons[CMD_LENGTH];
	int actions[CMD_LENGTH];
	int autoshoot;
	int jumps;
	int high_ping;
	int query_index;
	int query_failed;
	int aimlock_sus;
	int aimlock;
	int aimbot;
	int bhop;
	float time_teleported;
	float time_aimlock;
	float time_backtrack;
	float time_process_aimlock;
	// Two dimentional arrays aren't allowed yet.
	float angles[CMD_LENGTH * 3];
	float time_usercmd[CMD_LENGTH];
	bool banned_flags[CHEAT_MAX];
	bool ignore_lerp;

	// Basic wrapers to make the code easier to follow.
	float get_pitch(int tick)
	{
		if (tick < 0 || tick >= CMD_LENGTH)
			ThrowError("get_pitch(int tick) - Illegal tick request (%d).", tick);

		return this.angles[tick * 3];
	}

	float get_pitch_latest()
	{
		return this.angles[this.index * 3];
	}

	float get_yaw(int tick)
	{
		if (tick < 0 || tick >= CMD_LENGTH)
			ThrowError("get_yaw(int tick) - Illegal tick request (%d).", tick);

		return this.angles[(tick * 3) + 1];
	}

	float get_yaw_latest()
	{
		return this.angles[(this.index * 3) + 1];
	}

	float get_roll(int tick)
	{
		if (tick < 0 || tick >= CMD_LENGTH)
			ThrowError("get_roll(int tick) - Illegal tick request (%d).", tick);

		return this.angles[(tick * 3) + 2];
	}

	float get_roll_latest()
	{
		return this.angles[(this.index * 3) + 2];
	}

	void set_angles(float ang[3], int tick)
	{
		if (tick < 0 || tick >= CMD_LENGTH)
			ThrowError("set_angles(float ang[3], int tick) - Illegal tick request (%d).", tick);

		this.angles[(tick * 3)] = ang[0];
		this.angles[(tick * 3) + 1] = ang[1];
		this.angles[(tick * 3) + 2] = ang[2];
	}
}
struct_player player[MAXPLAYERS + 1];

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

	LoadTranslations("lilac.phrases.txt");

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
	cvar[CVAR_WELCOME] = CreateConVar("lilac_welcome", "0",
		"Welcome connecting players saying that the server is protected.",
		FCVAR_PROTECTED, true, 0.0, true, 1.0);
	cvar[CVAR_SB] = CreateConVar("lilac_sourcebans", "1",
		"Ban players via sourcebans++ (If it isn't installed, it will default to basebans).",
		FCVAR_PROTECTED, true, 0.0, true, 1.0);
	cvar[CVAR_LOG] = CreateConVar("lilac_log", "1",
		"Enable cheat logging.",
		FCVAR_PROTECTED, true, 0.0, true, 1.0);
	cvar[CVAR_LOG_EXTRA] = CreateConVar("lilac_log_extra", "1",
		"0 = Disabled.\n1 = Log extra information on player banned.\n2 = Log extra information on everything.",
		FCVAR_PROTECTED, true, 0.0, true, 2.0);
	cvar[CVAR_LOG_MISC] = CreateConVar("lilac_log_misc", "0",
		"Log when players are kicked for misc features, like interp exploits, too high ping and on convar response failure.",
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
	cvar[CVAR_AIMLOCK_LIGHT] = CreateConVar("lilac_aimlock_light", "1",
		"Only process at most 5 suspicious players for aimlock.\nDO NOT DISABLE THIS UNLESS YOUR SERVER CAN HANDLE IT!",
		FCVAR_PROTECTED, true, 0.0, true, 1.0);
	cvar[CVAR_BACKTRACK_PATCH] = CreateConVar("lilac_backtrack_patch", "0",
		"Patch Backtrack.\n0 = Disabled (Recommended).\n1 = Enabled (Not recommended, may cause hitreg issues).",
		FCVAR_PROTECTED, true, 0.0, true, 1.0);
	cvar[CVAR_MAX_PING] = CreateConVar("lilac_max_ping", "0",
		"Ban players with too high of a ping for 3 minutes.\nThis is meant to deal with fakelatency, the ban length is just to prevent instant reconnects.\n0 = no ling limit, minimum possible is 100.",
		FCVAR_PROTECTED, true, 0.0, true, 1000.0);
	cvar[CVAR_MAX_LERP] = CreateConVar("lilac_max_lerp", "105",
		"Kick players with an interp higher than this in ms (minimum possible is 105ms, default value in Source games is 100ms).\nThis is done to patch an exploit in the game that makes facestabbing players in TF2 easier (aka cl_interp 0.5).",
		FCVAR_PROTECTED, true, 105.0, true, 510.0); // 500 is max possible.
	cvar[CVAR_LOSS_FIX] = CreateConVar("lilac_loss_fix", "1",
		"Ignore some cheat detections for players who have too much packet loss (bad connection to the server).",
		FCVAR_PROTECTED, true, 0.0, true, 1.0);

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
	// 	Reset all stats on all players already in-game, but ignore lerp.
	for (int i = 1; i <= MaxClients; i++) {
		lilac_reset_client(i);
		player[i].ignore_lerp = true;
	}

	RegServerCmd("lilac_date_list", lilac_date_list,
		"Lists date formatting options", 0);

	AutoExecConfig(true, "lilac_config", "");

	forwardhandle = CreateGlobalForward("lilac_cheater_detected",
		ET_Ignore, Param_Cell, Param_Cell);
	forwardhandleban = CreateGlobalForward("lilac_cheater_banned",
		ET_Ignore, Param_Cell, Param_Cell);
	forwardhandleallow = CreateGlobalForward("lilac_allow_cheat_detection",
		ET_Event, Param_Cell, Param_Cell);

	CreateTimer(QUERY_TIMER, timer_query, _, TIMER_REPEAT);
	CreateTimer(5.0, timer_check_ping, _, TIMER_REPEAT);
	CreateTimer(5.0, timer_check_nolerp, _, TIMER_REPEAT);
	CreateTimer(0.5, timer_check_aimlock, _, TIMER_REPEAT);

	if (icvar[CVAR_LOG])
		lilac_log_first_time_setup();
}

public void OnAllPluginsLoaded()
{
	// Sourcebans compat...
	sourcebans_exist = LibraryExists("sourcebans++");

	// Startup message.
	PrintToServer("[Little Anti-Cheat %s] Successfully loaded!", VERSION);
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
	PrintToServer("\t{year}    = Numerical year  (2020).");
	PrintToServer("\t{month}   = Numerical month   (12).");
	PrintToServer("\t{day}     = Numerical day     (28).");
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
	PrintToServer("Using flags example: {year}/{month}/{day} {hour}:{minute}:{second}");
}

public APLRes AskPluginLoad2(Handle hMyself, bool bLate, char[] sError, int err_max)
{
	// Been told this isn't needed, but just in case.
	MarkNativeAsOptional("SBPP_BanPlayer");

	return APLRes_Success;
}

public void OnLibraryAdded(const char []name)
{
	if (StrEqual(name, "sourcebans++"))
		sourcebans_exist = true;
}

public void OnLibraryRemoved(const char []name)
{
	if (StrEqual(name, "sourcebans++"))
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
	} else if (StrEqual(cvarname, "lilac_welcome", false)) {
		icvar[CVAR_WELCOME] = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "lilac_sourcebans", false)) {
		icvar[CVAR_SB] = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "lilac_log", false)) {
		icvar[CVAR_LOG] = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "lilac_log_extra", false)) {
		icvar[CVAR_LOG_EXTRA] = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "lilac_log_misc", false)) {
		icvar[CVAR_LOG_MISC] = StringToInt(newValue, 10);
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
			&& icvar[CVAR_AIMLOCK] < AIMLOCK_BAN_MIN)
			icvar[CVAR_AIMLOCK] = 5;
	} else if (StrEqual(cvarname, "lilac_aimlock_light", false)) {
		icvar[CVAR_AIMLOCK_LIGHT] = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "lilac_backtrack_patch", false)) {
		icvar[CVAR_BACKTRACK_PATCH] = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "lilac_max_ping", false)) {
		icvar[CVAR_MAX_PING] = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "lilac_max_lerp", false)) {
		icvar[CVAR_MAX_LERP] = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "lilac_loss_fix", false)) {
		icvar[CVAR_LOSS_FIX] = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "sv_autobunnyhopping", false)) {
		cvar_bhop_value = StringToInt(newValue, 10);
	} else if (StrEqual(cvarname, "sv_maxupdaterate", false)) {
		sv_maxupdaterate = StringToInt(newValue);

		// Changing this convar mid-game can cause false positives.
		// 	Ignore players already in-game.
		for (int i = 1; i <= MaxClients; i++)
			player[i].ignore_lerp = true;
	} else if (StrEqual(cvarname, "sv_cheats", false)) {
		sv_cheats = StringToInt(newValue);

		// Delay convar checks for 30 seconds.
		time_sv_cheats = GetTime() + QUERY_TIMEOUT;
	}
}

public void OnClientPutInServer(int client)
{
	lilac_reset_client(client);

	CreateTimer(20.0, timer_welcome, GetClientUserId(client));
}

void lilac_reset_client(int client)
{
	player[client].ignore_lerp = false;
	player[client].index = 0;
	player[client].tickcount = 0;
	player[client].autoshoot = 0;
	player[client].jumps = 0;
	player[client].high_ping = 0;
	player[client].query_index = 0;
	player[client].query_failed = 0;
	player[client].aimlock_sus = 0;
	player[client].aimlock = 0;
	player[client].aimbot = 0;
	player[client].bhop = 0;
	player[client].time_teleported = 0.0;
	player[client].time_aimlock = 0.0;
	player[client].time_backtrack = 0.0;
	player[client].time_process_aimlock = 0.0;

	for (int i = 0; i < CHEAT_MAX; i++)
		player[client].banned_flags[i] = false;

	for (int i = 0; i < CMD_LENGTH; i++) {
		player[client].buttons[i] = 0;
		player[client].actions[i] = 0;
		player[client].time_usercmd[i] = 0.0;

		player[client].set_angles(Float:{0.0, 0.0, 0.0}, i);
	}
}

public void TF2_OnConditionRemoved(int client, TFCond condition)
{
	if (condition == TFCond_Taunting)
		player[client].time_teleported = GetGameTime();
}

public Action event_teleported(Event event, const char[] name,
				bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid", -1));

	if (is_player_valid(client))
		player[client].time_teleported = GetGameTime();
}

public Action event_player_death(Event event, const char[] name,
					bool dontBroadcast)
{
	if (!icvar[CVAR_ENABLE])
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
	if (!icvar[CVAR_ENABLE])
		return Plugin_Continue;

	char wep[64];
	int userid = GetEventInt(event, "attacker", -1);
	int client = GetClientOfUserId(userid);
	int victim = GetClientOfUserId(GetEventInt(event, "userid", -1));
	int killtype = GetEventInt(event, "customkill", 0);
	GetEventString(event, "weapon_logclassname", wep, sizeof(wep), "");

	// Ignore sentries in TF2.
	if (!strncmp(wep, "obj_", 4, false))
		return Plugin_Continue;

	// Killtype 3 = flamethrower.
	event_death_shared(userid, client, victim,
		((killtype == 3) ? true : false));

	return Plugin_Continue;
}

void event_death_shared(int userid, int client, int victim, bool skip_delta)
{
	DataPack pack;
	float killpos[3], deathpos[3];
	int skip_snap = 0;

	if (client == victim)
		return;

	if (!is_player_valid(client)
		|| IsFakeClient(client)
		|| player[client].banned_flags[CHEAT_AIMBOT]
		|| GetClientTime(client) < 10.1)
		return;

	if (icvar[CVAR_AIMLOCK_LIGHT])
		lilac_aimlock_light_test(client);

	if (!icvar[CVAR_AIMBOT])
		return;

	GetClientEyePosition(client, killpos);
	GetClientEyePosition(victim, deathpos);

	// Killer and victim are too close to each other,
	// Skip some detections.
	if (GetVectorDistance(killpos, deathpos) < 350.0 || skip_delta)
		skip_snap = 1;

	CreateDataTimer(0.5, timer_check_aimbot, pack);
	pack.WriteCell(userid);
	pack.WriteCell(skip_snap);
	// Fallback to this tick if the shot isn't found.
	pack.WriteCell(player[client].index);
	pack.WriteFloat(killpos[0]);
	pack.WriteFloat(killpos[1]);
	pack.WriteFloat(killpos[2]);
	pack.WriteFloat(deathpos[0]);
	pack.WriteFloat(deathpos[1]);
	pack.WriteFloat(deathpos[2]);
}

public Action timer_welcome(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if (is_player_valid(client) && icvar[CVAR_WELCOME] && icvar[CVAR_ENABLE])
		PrintToChat(client, "[Lilac] %T", "welcome_msg", client, VERSION);
}

public Action timer_query(Handle timer)
{
	if (!icvar[CVAR_ENABLE] || !icvar[CVAR_CONVAR])
		return Plugin_Continue;

	// sv_cheats recently changed or is set to 1, abort.
	if (GetTime() < time_sv_cheats || sv_cheats)
		return Plugin_Continue;

	for (int i = 1; i <= MaxClients; i++) {
		if (!is_player_valid(i) || IsFakeClient(i))
			continue;

		// Player recently joined, wait before querying.
		if (GetClientTime(i) < 60.0)
			continue;

		// Don't query already banned players.
		if (player[i].banned_flags[CHEAT_CONVAR])
			continue;

		// Only increments query index if the player
		// 	has responded to the last one.
		if (!player[i].query_failed) {
			if (++(player[i].query_index) >= 12)
				player[i].query_index = 0;
		}

		QueryClientConVar(i, query_list[player[i].query_index], query_reply, 0);

		if (++(player[i].query_failed) > QUERY_MAX_FAILURES) {
			if (icvar[CVAR_LOG_MISC]) {
				lilac_log_setup_client(i);
				Format(line, sizeof(line),
					"%s was kicked for failing to respond to %d queries in %.0f seconds.",
					line, QUERY_MAX_FAILURES, QUERY_TIMER * QUERY_MAX_FAILURES);

				lilac_log(true);

				if (icvar[CVAR_LOG_EXTRA] == 2)
					lilac_log_extra(i);
			}

			KickClient(i, "[Lilac] %T", "kick_query_failure", i);
		}
	}

	return Plugin_Continue;
}

public void query_reply(QueryCookie cookie, int client,
			ConVarQueryResult result, const char[] cvarName,
			const char[] cvarValue, any value)
{
	// Player NEEDS to answer the query.
	if (result != ConVarQuery_Okay)
		return;

	// Client did respond to the query request, move on to the next convar.
	player[client].query_failed = 0;

	// Any response the server may recieve may also be faulty, ignore.
	if (GetTime() < time_sv_cheats || sv_cheats)
		return;

	// Already banned.
	if (player[client].banned_flags[CHEAT_CONVAR])
		return;

	int val = StringToInt(cvarValue);

	// Check for invalid convar responses.
	// 	This is pretty ugly, but does the job for
	// 	a simple & basic query system.
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

		if (lilac_forward_allow_cheat_detection(client, CHEAT_CONVAR) == false)
			return;

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

		player[client].banned_flags[CHEAT_CONVAR] = true;
		lilac_ban_client(client, CHEAT_CONVAR);
	}
}

public Action timer_check_nolerp(Handle timer)
{
	float min;

	if (!icvar[CVAR_ENABLE])
		return Plugin_Continue;

	for (int i = 1; i <= MaxClients; i++) {
		if (!is_player_valid(i) || IsFakeClient(i))
			continue;

		float lerp = GetEntPropFloat(i, Prop_Data, "m_fLerpTime");

		if (lerp * 1000.0 > float(icvar[CVAR_MAX_LERP])) {
			if (icvar[CVAR_LOG_MISC]) {
				lilac_log_setup_client(i);
				Format(line, sizeof(line),
					"%s was kicked for exploiting interpolation (%.3fms / %dms max).",
					line, lerp * 1000.0, icvar[CVAR_MAX_LERP]);

				lilac_log(true);

				if (icvar[CVAR_LOG_EXTRA] == 2)
					lilac_log_extra(i);
			}

			KickClient(i, "[Lilac] %T", "kick_interp_exploit", i,
				lerp * 1000.0, icvar[CVAR_MAX_LERP], float(icvar[CVAR_MAX_LERP]) / 999.9);

			continue;
		}

		if (sv_maxupdaterate > 0)
			min = 1.0 / float(sv_maxupdaterate);
		else
			min = 0.0;

		if (!icvar[CVAR_NOLERP]
			|| player[i].ignore_lerp
			|| player[i].banned_flags[CHEAT_NOLERP]
			|| min < 0.005) // Minvalue invalid or too low.
			continue;

		if (lerp > min * 0.95 /* buffer */)
			continue;

		if (lilac_forward_allow_cheat_detection(i, CHEAT_NOLERP) == false)
			continue;

		player[i].banned_flags[CHEAT_NOLERP] = true;

		lilac_forward_client_cheat(i, CHEAT_NOLERP);

		if (icvar[CVAR_LOG]) {
			lilac_log_setup_client(i);
			Format(line, sizeof(line),
				"%s was detected and banned for NoLerp (%fms).",
				line, lerp * 1000.0);

			lilac_log(true);

			if (icvar[CVAR_LOG_EXTRA])
				lilac_log_extra(i);
		}

		lilac_ban_client(i, CHEAT_NOLERP);
	}

	return Plugin_Continue;
}

public Action timer_check_ping(Handle timer)
{
	static bool toggle = true;
	char reason[128];
	float ping;

	if (!icvar[CVAR_ENABLE] || icvar[CVAR_MAX_PING] < 100)
		return Plugin_Continue;

	for (int i = 1; i <= MaxClients; i++) {
		if (!is_player_valid(i) || IsFakeClient(i))
			continue;

		// Player recently joined, don't check ping yet.
		if (GetClientTime(i) < 100.0)
			continue;

		ping = GetClientAvgLatency(i, NetFlow_Outgoing) * 1000.0;

		if (ping < float(icvar[CVAR_MAX_PING])) {
			if (toggle && player[i].high_ping > 0)
				player[i].high_ping--;

			continue;
		}

		// Player has a higher ping than maximum for 45 seconds.
		if (++(player[i].high_ping) < 9)
			continue;

		if (icvar[CVAR_LOG_MISC]) {
			lilac_log_setup_client(i);
			Format(line, sizeof(line),
				"%s was kicked for having too high ping (%.3fms / %dms max).",
				line, ping, icvar[CVAR_MAX_PING]);

			lilac_log(true);

			if (icvar[CVAR_LOG_EXTRA] == 2)
				lilac_log_extra(i);
		}

		Format(reason, sizeof(reason),
			"[Lilac] %T", "tban_ping_high", i,
			ping, icvar[CVAR_MAX_PING]);

		// Ban the client for three minutes to avoid instant reconnects.
		BanClient(i, 3, BANFLAG_AUTHID, reason, reason, "lilac", 0);
	}

	toggle = !toggle;

	return Plugin_Continue;
}

// This still isn't a pretty function.
// Basically, it goes through every player
// 	and compares how player1 (i) looks at player2 (k)
// 	And if the aim snaps 10 degrees and stays on player2 (k)
// 	Then that counts as a single aimlock suspicion.
// If lilac_aimlock_light (lightmode) is on, then only 5 players
// 	are processed at a time.
public Action timer_check_aimlock(Handle timer)
{
	float ang[3], lang[3], ideal[3], pos[3], pos2[3];
	float aimdist, laimdist;
	int lock;

	// When player1 (i) gets detected for an aimlock.
	// 	Stop looking for more snaps for player1 (i).
	// 	If enemies are grouped together, it could
	// 	cause several detections based on one snap.
	// 	That's why only one snap is counter every 0.5 seconds.
	bool skip_report[MAXPLAYERS + 1]; // Skip reporting this player.
	bool report[MAXPLAYERS + 1]; // report this player.
	bool process; // Keep processing the player.
	int players_processed = 0;

	if (!icvar[CVAR_ENABLE] || !icvar[CVAR_AIMLOCK])
		return Plugin_Continue;

	for (int i = 1; i <= MaxClients; i++) {
		skip_report[i] = true;
		report[i] = false;

		// Don't process more than 5 players!
		if (players_processed >= 5 && icvar[CVAR_AIMLOCK_LIGHT] == 1)
			return Plugin_Continue;

		if (!is_player_valid(i) || IsFakeClient(i))
			continue;

		// Player must be alive and on a valid team.
		if (!IsPlayerAlive(i) || GetClientTeam(i) < 2)
			continue;

		// Player recently teleported or taunted, ignore angle snaps.
		if (GetGameTime() - player[i].time_teleported < 2.0)
			continue;

		// Player has too much packet loss.
		if (skip_due_to_loss(i))
			continue;

		// Player already banned for aimlock, don't need to check for it.
		if (player[i].banned_flags[CHEAT_AIMLOCK])
			continue;

		// If lightmode is enabled, the player must be in the process que.
		if (icvar[CVAR_AIMLOCK_LIGHT] == 1 && lilac_is_player_in_aimlock_que(i) == false)
			continue;

		skip_report[i] = false;

		players_processed++;
		process = true;
		GetClientEyePosition(i, pos);

		for (int k = 1; k <= MaxClients && process; k++) {
			if (!is_player_valid(k) || k == i)
				continue;

			// Ignore teammates.
			if (GetClientTeam(k) == GetClientTeam(i))
				continue;

			// Player2 needs to be alive and on a valid team as well.
			if (!IsPlayerAlive(k) || GetClientTeam(k) < 2)
				continue;

			GetClientEyePosition(k, pos2);

			// Players are too close, never report aimlock.
			if (GetVectorDistance(pos, pos2) < 300.0) {
				skip_report[i] = true;
				continue;
			}

			// Player target teleported, skip testing.
			if (GetGameTime() - player[k].time_teleported < 2.0)
				continue;

			aim_at_point(pos, pos2, ideal);

			lock = 0;
			int ind = player[i].index;
			for (int l = 0; l < time_to_ticks(0.5); l++) {
				if (ind < 0)
					ind += CMD_LENGTH;

				// Only process ticks that happened 0.5 seconds ago.
				if (GetGameTime() - player[i].time_usercmd[ind] < 0.5) {
					ang[0] = player[i].get_pitch(ind);
					ang[1] = player[i].get_yaw(ind);
					laimdist = angle_delta(ang, ideal);

					if (l) {
						if (aimdist < 10.0)
							lock++;
						else
							lock = 0;

						if (aimdist < laimdist * 0.1
							&& angle_delta(ang, lang) > 20.0
							&& lock > time_to_ticks(0.2)) {

							process = false;
							report[i] = true;
						}
					}

					lang = ang;
					aimdist = laimdist;
				}

				ind--;
			}
		}
	}

	for (int i = 1; i <= MaxClients; i++) {
		if (skip_report[i] || !report[i])
			continue;

		lilac_detected_aimlock(i);
	}

	return Plugin_Continue;
}

public Action timer_check_aimbot(Handle timer, DataPack pack)
{
	int ind;
	int client;
	int fallback;
	int shotindex = -1;
	int detected = 0;
	float delta = 0.0;
	float tdelta = 0.0;
	float total_delta = 0.0;
	float aimdist, laimdist;
	float ideal[3], ang[3], lang[3];
	float killpos[3], deathpos[3];
	bool skip_snap = false;
	bool skip_autoshoot = false;
	bool skip_repeat = false;

	pack.Reset();
	client = GetClientOfUserId(pack.ReadCell());
	skip_snap = pack.ReadCell();
	fallback = pack.ReadCell();
	killpos[0] = pack.ReadFloat();
	killpos[1] = pack.ReadFloat();
	killpos[2] = pack.ReadFloat();
	deathpos[0] = pack.ReadFloat();
	deathpos[1] = pack.ReadFloat();
	deathpos[2] = pack.ReadFloat();

	// Killer may have left the game, cancel.
	if (!is_player_valid(client))
		return;

	// Locate when the shot was fired.
	ind = player[client].index;
	// 0.5 (datapacktimer delay) + 0.5 (snap test) + 0.1 (buffer).
	// We are looking this far back in case of a projectile aimbot shot,
	// 	as the death event happens way later after the shot.
	for (int i = 0; i < CMD_LENGTH - time_to_ticks(0.5 + 0.5 + 0.1); i++) {
		if (--ind < 0)
			ind += CMD_LENGTH;

		// The shot needs to have happened at least 0.3 seconds ago.
		if (GetGameTime() - player[client].time_usercmd[ind] < 0.3)
			continue;

		if ((player[client].actions[ind] & ACTION_SHOT)) {
			shotindex = ind;
			break;
		}
	}

	// Shot not found, use fallback.
	if (shotindex == -1) {
		shotindex = fallback;

		// If the latest index is the same as the fallback, then no
		// 	more usercmds have been processed since the death event.
		// 	These detections are thus unstable and will be ignored
		// 	(They require at least one tick after the shot to work).
		if (player[client].index == fallback) {
			skip_autoshoot = true;
			skip_repeat = true;
		}
	} else {
		// Don't detect the same shot twice.
		player[client].actions[shotindex] = 0;
	}

	// Forgot to add this in the past, oops...
	// 	Skip repeat detections if players are too close to each other.
	if (skip_snap)
		skip_repeat = true;

	// Player taunted within 0.5 seconds of taking a shot leading to a kill.
	// Ignore snap detections.
	if (-0.1 < player[client].time_usercmd[shotindex] - player[client].time_teleported < 0.5 + 0.1)
		skip_snap = true;

	// Aimsnap and total delta test.
	if (skip_snap == false) {
		aim_at_point(killpos, deathpos, ideal);

		ind = shotindex;
		// Not needed: ang[2] = 0.0;
		for (int i = 0; i < time_to_ticks(0.5); i++) {
			if (ind < 0)
				ind += CMD_LENGTH;

			// We're looking back further than 0.5 seconds prior to the shot, abort.
			if (player[client].time_usercmd[shotindex] - player[client].time_usercmd[ind] > 0.5)
				break;

			laimdist = angle_delta(player[client].angles[ind * 3], ideal);
			ang[0] = player[client].angles[ind * 3];
			ang[1] = player[client].angles[(ind * 3) + 1];

			if (i) {
				tdelta = angle_delta(lang, ang);

				if (tdelta > delta)
					delta = tdelta;

				total_delta += tdelta;

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

	// Packetloss is too high, skip all detections but total_delta.
	if (skip_due_to_loss(client)) {
		skip_autoshoot = true;
		skip_repeat = true;
		detected = 0;
	}

	// Angle-repeat test.
	if (skip_repeat == false) {
		ang[0] = player[client].angles[normalize_index(shotindex-1) * 3];
		ang[1] = player[client].angles[(normalize_index(shotindex-1) * 3) + 1];

		lang[0] = player[client].angles[normalize_index(shotindex+1) * 3];
		lang[1] = player[client].angles[(normalize_index(shotindex+1) * 3) + 1];

		tdelta = angle_delta(ang, lang);

		lang[0] = player[client].angles[normalize_index(shotindex) * 3];
		lang[1] = player[client].angles[(normalize_index(shotindex) * 3) + 1];

		if (tdelta < 10.0 && angle_delta(ang, lang) > 0.5
			&& angle_delta(ang, lang) > tdelta * 5.0)
			detected |= AIMBOT_FLAG_REPEAT;
	}

	// Autoshoot test.
	if (skip_autoshoot == false) {
		int tmp = 0;
		ind = shotindex+1;
		for (int i = 0; i < 3; i++) {
			if (ind < 0)
				ind += CMD_LENGTH;
			else if (ind >= CMD_LENGTH)
				ind -= CMD_LENGTH;

			if ((player[client].buttons[ind] & IN_ATTACK))
				tmp++;

			ind--;
		}

		// Onetick perfect shot.
		// Players must get two of them in a row leading to a kill
		// 	or something else must have been detected to get this flag.
		if (tmp == 1) {
			if (detected || ++(player[client].autoshoot) > 1)
				detected |= AIMBOT_FLAG_AUTOSHOOT;
		} else {
			player[client].autoshoot = 0;
		}
	}

	if (detected || total_delta > AIMBOT_MAX_TOTAL_DELTA)
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

	// Increment the index.
	if (++(player[client].index) >= CMD_LENGTH)
		player[client].index = 0;

	// Store when the tick was processed.
	player[client].time_usercmd[player[client].index] = GetGameTime();

	// Store angles.
	player[client].set_angles(angles, player[client].index);

	// Store actions.
	player[client].buttons[player[client].index] = buttons;
	player[client].actions[player[client].index] = 0;
	if ((buttons & IN_ATTACK) && bullettime_can_shoot(client))
		player[client].actions[player[client].index] |= ACTION_SHOT;

	// We need to store information even if the plugin is disabled,
	// 	incase it gets turned on again mid-game.
	if (!icvar[CVAR_ENABLE]) {
		lbuttons[client] = buttons;
		player[client].tickcount = tickcount;

		return Plugin_Continue;
	}

	// Patch backtracking.
	// 	This will cause hitreg issues for players with packetloss (and some teleporting??).
	if (icvar[CVAR_BACKTRACK_PATCH]) {
		if (lilac_client_tickcount_incremented(client, tickcount) == false
			&& lilac_is_player_in_backtrack_timeout(client) == false)
			lilac_set_client_in_backtrack_timeout(client);

		// Store tickcount before modifying (For future tests).
		player[client].tickcount = tickcount;

		if (lilac_is_player_in_backtrack_timeout(client))
			tickcount = lilac_random_tickcount(client);
	} else {
		player[client].tickcount = tickcount;
	}

	// Detect angles that are out of bounds.
	// 	Ignore players who recently teleported.
	if (icvar[CVAR_ANGLES] && IsPlayerAlive(client)
		&& GetGameTime() > player[client].time_teleported + 5.0) {

		for (int i = 0; i < 3; i++) {
			if (max_angles[i] == 0.0)
				continue;

			if (FloatAbs(angles[i]) > max_angles[i])
				lilac_detected_antiaim(client);
		}
	}

	// Patch out of bounds angles.
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

	// Detect bhop.
	if (icvar[CVAR_BHOP] && !cvar_bhop_value) {
		int flags = GetEntityFlags(client);
		if ((buttons & IN_JUMP) && !(lbuttons[client] & IN_JUMP)) {
			if ((flags & FL_ONGROUND)) {
				lilac_detected_bhop(client);

				player[client].bhop++;
			}

			player[client].jumps++;
		} else if ((flags & FL_ONGROUND)) {
			player[client].bhop = 0;
			player[client].jumps = 0;
		}
	}

	lbuttons[client] = buttons;

	return Plugin_Continue;
}

int lilac_random_tickcount(int client)
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

bool lilac_client_tickcount_incremented(int client, int tickcount)
{
	// Tickcount should increment for legit players 99% of the time... Or at least it seems so.
	// Packetloss or teleporting players may get false detections tho.
	return (tickcount == player[client].tickcount + 1);
}

void lilac_set_client_in_backtrack_timeout(int client)
{
	// Set the player in backtrack timeout for 1 second.
	player[client].time_backtrack = GetGameTime() + 1.0;
}

bool lilac_is_player_in_backtrack_timeout(int client)
{
	return (GetGameTime() < player[client].time_backtrack);
}

// Todo: I should update this soon...
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
	if (player[client].banned_flags[CHEAT_AIMLOCK])
		return;

	// Suspicions reset after 3 minutes.
	// 	This means you need to get two aimlocks within
	// 	three minutes of each other to get a single
	// 	detection.
	if (GetGameTime() - player[client].time_aimlock < 180.0)
		player[client].aimlock_sus++;
	else
		player[client].aimlock_sus = 1;

	player[client].time_aimlock = GetGameTime();

	if (player[client].aimlock_sus < 2)
		return;

	player[client].aimlock_sus = 0;

	if (lilac_forward_allow_cheat_detection(client, CHEAT_AIMLOCK) == false)
		return;

	// Detection expires in 10 minutes.
	CreateTimer(600.0, timer_decrement_aimlock, GetClientUserId(client));

	lilac_forward_client_cheat(client, CHEAT_AIMLOCK);

	// Don't log the first detection.
	if (++(player[client].aimlock) < 2)
		return;

	if (icvar[CVAR_LOG]) {
		lilac_log_setup_client(client);
		Format(line, sizeof(line),
			"%s is suspected of using an aimlock (Detection: %d).",
			line, player[client].aimlock);

		lilac_log(true);

		if (icvar[CVAR_LOG_EXTRA] == 2)
			lilac_log_extra(client);
	}

	if (player[client].aimlock >= icvar[CVAR_AIMLOCK]
		&& icvar[CVAR_AIMLOCK] >= AIMLOCK_BAN_MIN) {
		player[client].banned_flags[CHEAT_AIMLOCK] = true;

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
	if (player[client].banned_flags[CHEAT_BHOP])
		return;

	// Mode 1:
	// 	Simplistic mode, only ban on the 10th bhop.
	// Mode 2:
	// 	Advanced mode, ban on 5th bhop if the jump count is lower than 15.
	// 	Else, ban on 10th bhop.
	switch (icvar[CVAR_BHOP]) {
	case 1: {
		if (player[client].bhop < 10)
			return;
	}
	case 2: {
		if (player[client].bhop < 5)
			return;
		else if (player[client].bhop < 10 && player[client].jumps > 15)
			return;
	}
	}

	if (lilac_forward_allow_cheat_detection(client, CHEAT_BHOP) == false)
		return;

	player[client].banned_flags[CHEAT_BHOP] = true;

	lilac_forward_client_cheat(client, CHEAT_BHOP);

	if (icvar[CVAR_LOG]) {
		lilac_log_setup_client(client);
		Format(line, sizeof(line),
			"%s was detected and banned for Bhop (Jumps Presses: %d | Bhops: %d).",
			line, player[client].jumps, player[client].bhop);

		lilac_log(true);

		if (icvar[CVAR_LOG_EXTRA])
			lilac_log_extra(client);
	}

	lilac_ban_client(client, CHEAT_BHOP);
}

void lilac_detected_antiaim(int client)
{
	if (player[client].banned_flags[CHEAT_ANGLES])
		return;

	// Todo, set timeout to prevent constant spamming?
	if (lilac_forward_allow_cheat_detection(client, CHEAT_ANGLES) == false)
		return;

	player[client].banned_flags[CHEAT_ANGLES] = true;

	lilac_forward_client_cheat(client, CHEAT_ANGLES);

	if (icvar[CVAR_LOG]) {
		lilac_log_setup_client(client);
		Format(line, sizeof(line),
			"%s was detected and banned for Angle-Cheats (Pitch: %.2f, Yaw: %.2f, Roll: %.2f).",
			line,
			player[client].get_pitch_latest(),
			player[client].get_yaw_latest(),
			player[client].get_roll_latest());

		lilac_log(true);

		if (icvar[CVAR_LOG_EXTRA])
			lilac_log_extra(client);
	}

	lilac_ban_client(client, CHEAT_ANGLES);
}

void lilac_detected_aimbot(int client, float delta, float td, int flags)
{
	if (player[client].banned_flags[CHEAT_AIMBOT])
		return;

	if (lilac_forward_allow_cheat_detection(client, CHEAT_AIMBOT) == false)
		return;

	// Detection expires in 10 minutes.
	CreateTimer(600.0, timer_decrement_aimbot, GetClientUserId(client));

	lilac_forward_client_cheat(client, CHEAT_AIMBOT);

	// Don't log the first detection.
	if (++(player[client].aimbot) < 2)
		return;

	if (icvar[CVAR_LOG]) {
		lilac_log_setup_client(client);
		Format(line, sizeof(line),
			"%s is suspected of using an aimbot (Detection: %d | Delta: %.0f | TotalDelta: %.0f | Detected:%s%s%s%s%s).",
			line, player[client].aimbot, delta, td,
			((flags & AIMBOT_FLAG_SNAP)      ? " Aim-Snap"     : ""),
			((flags & AIMBOT_FLAG_SNAP2)     ? " Aim-Snap2"    : ""),
			((flags & AIMBOT_FLAG_AUTOSHOOT) ? " Autoshoot"    : ""),
			((flags & AIMBOT_FLAG_REPEAT)    ? " Angle-Repeat" : ""),
			((td > AIMBOT_MAX_TOTAL_DELTA)   ? " Total-Delta"  : ""));

		lilac_log(true);

		if (icvar[CVAR_LOG_EXTRA] == 2)
			lilac_log_extra(client);
	}

	if (player[client].aimbot >= icvar[CVAR_AIMBOT]
		&& icvar[CVAR_AIMBOT] >= AIMBOT_BAN_MIN) {

		if (icvar[CVAR_LOG]) {
			lilac_log_setup_client(client);
			Format(line, sizeof(line),
				"%s was banned for Aimbot.", line);

			lilac_log(true);

			if (icvar[CVAR_LOG_EXTRA])
				lilac_log_extra(client);
		}

		player[client].banned_flags[CHEAT_AIMBOT] = true;
		lilac_ban_client(client, CHEAT_AIMBOT);
	}
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	// Prevent players banned for Chat-Clear from spamming chat.
	// 	Helps legit players see the cheater was banned.
	if (player[client].banned_flags[CHEAT_CHATCLEAR])
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
	if (player[client].banned_flags[CHEAT_CHATCLEAR])
		return;

	if (does_string_contain_newline(sArgs)) {
		if (lilac_forward_allow_cheat_detection(client, CHEAT_CHATCLEAR) == false)
			return;

		player[client].banned_flags[CHEAT_CHATCLEAR] = true;
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

void lilac_aimlock_light_test(int client)
{
	int ind;
	float lastang[3], ang[3];

	// Player recently teleported, spawned or taunted. Ignore.
	if (GetGameTime() - player[client].time_teleported < 3.0)
		return;

	ind = player[client].index;
	for (int i = 0; i < time_to_ticks(0.5); i++) {
		if (ind < 0)
			ind += CMD_LENGTH;

		ang[0] = player[client].get_pitch(ind);
		ang[1] = player[client].get_yaw(ind);

		if (i) {
			// This player has a somewhat big delta,
			// 	test this player for aimlock for 200 seconds.
			// Even if we end up flagging more than 5 players
			// 	for this, that's fine as only 5 players
			// 	can be processed in the aimlock check timer.
			if (angle_delta(lastang, ang) > 20.0) {
				player[client].time_process_aimlock = GetGameTime() + 200.0;
				return;
			}
		}

		lastang = ang;
		ind--;
	}
}

bool lilac_is_player_in_aimlock_que(int client)
{
	// Test for aimlock on players who:
	return (GetGameTime() < player[client].time_process_aimlock // Are in the que.
		|| player[client].aimlock // Already has a detection.
		|| (GetGameTime() - player[client].time_aimlock < 180.0 && player[client].time_aimlock > 1.0)); // Had one aimlock the past three minutes.
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
		player[client].get_pitch_latest(),
		player[client].get_yaw_latest(),
		player[client].get_roll_latest(),
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

void lilac_ban_client(int client, int cheat)
{
	char reason[128];

	switch (cheat) {
	case CHEAT_ANGLES: { Format(reason, sizeof(reason),
		"[Little Anti-Cheat %s] %T", VERSION, "ban_angle", client); }
	case CHEAT_CHATCLEAR: { Format(reason, sizeof(reason),
		"[Little Anti-Cheat %s] %T", VERSION, "ban_chat_clear", client); }
	case CHEAT_CONVAR: { Format(reason, sizeof(reason),
		"[Little Anti-Cheat %s] %T", VERSION, "ban_convar", client); }
	// It saying "convar violation" for nolerp is intentional.
	case CHEAT_NOLERP: { Format(reason, sizeof(reason),
		"[Little Anti-Cheat %s] %T", VERSION, "ban_convar", client); }
	case CHEAT_BHOP: { Format(reason, sizeof(reason),
		"[Little Anti-Cheat %s] %T", VERSION, "ban_bhop", client); }
	case CHEAT_AIMBOT: { Format(reason, sizeof(reason),
		"[Little Anti-Cheat %s] %T", VERSION, "ban_aimbot", client); }
	case CHEAT_AIMLOCK: { Format(reason, sizeof(reason),
		"[Little Anti-Cheat %s] %T", VERSION, "ban_aimlock", client); }
	default: return;
	}

	lilac_forward_client_ban(client, cheat);

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
		KickClient(client, "%T", "kick_ban_genetic", client);
}

void aim_at_point(const float p1[3], const float p2[3], float writeto[3])
{
	SubtractVectors(p2, p1, writeto);
	GetVectorAngles(writeto, writeto);

	// NormalizeVector() Doesn't work...
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

float angle_delta(float []a1, float []a2)
{
	int normal = 5;
	float p1[3], p2[3], delta;

	p1[0] = a1[0];
	p2[0] = a2[0];
	p2[1] = a2[1];
	p1[1] = a1[1];

	// We don't care about roll.
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

bool skip_due_to_loss(int client)
{
	// Debate: What percentage should this be at?
	// 	Skip detection if the loss is more than 50%
	if (icvar[CVAR_LOSS_FIX])
		return GetClientAvgLoss(client, NetFlow_Both) > 0.5;

	return false;
}

int time_to_ticks(float time)
{
	if (time > 0.0)
		return RoundToNearest(time / GetTickInterval());

	return 0;
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

	if (player[client].aimbot > 0)
		player[client].aimbot--;
}

public Action timer_decrement_aimlock(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if (!is_player_valid(client))
		return;

	if (player[client].aimlock > 0)
		player[client].aimlock--;
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

void lilac_forward_client_ban(int client, int cheat)
{
	int dummy;

	if (forwardhandleban == null)
		return;

	Call_StartForward(forwardhandleban);
	Call_PushCell(client);
	Call_PushCell(cheat);
	Call_Finish(dummy);
}

bool lilac_forward_allow_cheat_detection(int client, int cheat)
{
	Action result = Plugin_Continue;

	if (forwardhandleallow == null)
		return true;

	Call_StartForward(forwardhandleallow);
	Call_PushCell(client);
	Call_PushCell(cheat);
	Call_Finish(result);

	if (result == Plugin_Continue)
		return true;

	return false;
}





























































//
