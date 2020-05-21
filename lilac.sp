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
#tryinclude <materialadmin>
#tryinclude <sourcebanspp>
#include <tf2>
#include <tf2_stocks>

#define VERSION "1.5.0"

#define CMD_LENGTH 	330

#define GAME_UNKNOWN 	0
#define GAME_TF2 	1
#define GAME_CSGO 	2
#define GAME_DODS 	3
#define GAME_L4D2 	4
#define GAME_L4D 	5

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
#define CVAR_MA 		3
#define CVAR_LOG 		4
#define CVAR_LOG_EXTRA 		5
#define CVAR_LOG_MISC 		6
#define CVAR_LOG_DATE 		7
#define CVAR_BAN 		8
#define CVAR_BAN_LENGTH 	9
#define CVAR_ANGLES 		10
#define CVAR_PATCH_ANGLES 	11
#define CVAR_CHAT 		12
#define CVAR_CONVAR 		13
#define CVAR_NOLERP 		14
#define CVAR_BHOP 		15
#define CVAR_AIMBOT 		16
#define CVAR_AIMBOT_AUTOSHOOT 	17
#define CVAR_AIMLOCK 		18
#define CVAR_AIMLOCK_LIGHT 	19
#define CVAR_BACKTRACK_PATCH 	20
#define CVAR_MAX_PING		21
#define CVAR_MAX_LERP 		22
#define CVAR_LOSS_FIX 		23
#define CVAR_MAX 		24

#define ACTION_SHOT 	1

#define QUERY_MAX_FAILURES 	24
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

// Banlength overwrite.
int ban_length_overwrite[CHEAT_MAX];

// Misc.
int ggame;
char line[2048];
char dateformat[512] = "%Y/%m/%d %H:%M:%S";
float max_angles[3] = {89.01, 0.0, 50.01};
Handle forwardhandle = INVALID_HANDLE;
Handle forwardhandleban = INVALID_HANDLE;
Handle forwardhandleallow = INVALID_HANDLE;
bool sourcebans_exist = false;
bool materialadmin_exist = false;

// Logging.
int playerinfo_index[MAXPLAYERS + 1];
int playerinfo_tickcount[MAXPLAYERS + 1];
int playerinfo_buttons[MAXPLAYERS + 1][CMD_LENGTH];
int playerinfo_actions[MAXPLAYERS + 1][CMD_LENGTH];
int playerinfo_autoshoot[MAXPLAYERS + 1];
int playerinfo_jumps[MAXPLAYERS + 1];
int playerinfo_high_ping[MAXPLAYERS + 1];
int playerinfo_query_index[MAXPLAYERS + 1];
int playerinfo_query_failed[MAXPLAYERS + 1];
int playerinfo_aimlock_sus[MAXPLAYERS + 1];
int playerinfo_aimlock[MAXPLAYERS + 1];
int playerinfo_aimbot[MAXPLAYERS + 1];
int playerinfo_bhop[MAXPLAYERS + 1];
float playerinfo_time_teleported[MAXPLAYERS + 1];
float playerinfo_time_aimlock[MAXPLAYERS + 1];
float playerinfo_time_backtrack[MAXPLAYERS + 1];
float playerinfo_time_process_aimlock[MAXPLAYERS + 1];
float playerinfo_angles[MAXPLAYERS + 1][CMD_LENGTH][3];
float playerinfo_time_usercmd[MAXPLAYERS + 1][CMD_LENGTH];
bool playerinfo_banned_flags[MAXPLAYERS + 1][CHEAT_MAX];
bool playerinfo_ignore_lerp[MAXPLAYERS + 1];

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
	}
	else if (StrEqual(gamefolder, "csgo", false)) {
		ggame = GAME_CSGO;

		// Pitch Anti-Aim doesn't work for CSGO anymore,
		// but horrible cheats may still attempt it.
		// max_angles = Float:{0.0, 0.0, 50.01};

		if ((cvar_bhop = FindConVar("sv_autobunnyhopping")) != null) {
			cvar_bhop_value = GetConVarInt(cvar_bhop);
			HookConVarChange(cvar_bhop, cvar_change);
		}
		else {
			// We weren't able to get the cvar,
			// disable bhop checks just in case.
			cvar_bhop_value = 1;

			PrintToServer("[Lilac] Unable to to find convar \"sv_autobunnyhopping\", bhop checks have been forcefully disabled.");
		}
	}
	else if (StrEqual(gamefolder, "left4dead2", false)) {
		ggame = GAME_L4D2;

		// Pitch AA isn't really used much in L4D2 afaik, plus,
		// 	like larrybrains reported, causes false positives for
		// 	the infected team memeber smoker.
		// Thanks to Larrybrains for reporting this!
		max_angles = Float:{0.0, 0.0, 50.01};
	}
	else if (StrEqual(gamefolder, "left4dead", false)) {
		ggame = GAME_L4D;
		
		// Same as L4D2, the smoker handles pitch differently it seems.
		// Thanks to finishlast for reporting this!
		max_angles = Float:{0.0, 0.0, 50.01};
	}
	else if (StrEqual(gamefolder, "dod", false)) {
		ggame = GAME_DODS;
	}
	else {
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
	cvar[CVAR_MA] = CreateConVar("lilac_materialadmin", "1",
		"Ban players via Material-Admin (Fork of Sourcebans++. If it isn't installed, will default to sourcebans++ or basebans).",
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
	cvar[CVAR_BAN] = CreateConVar("lilac_ban", "1",
		"Enable banning of cheaters, set to 0 if you want to test Lilac before fully trusting it with bans.",
		FCVAR_PROTECTED, true, 0.0, true, 1.0);
	cvar[CVAR_BAN_LENGTH] = CreateConVar("lilac_ban_length", "0",
		"How long bans should last in minutes (0 = forever).",
		FCVAR_PROTECTED, true, 0.0, false, 0.0);
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
	cvar[CVAR_AIMBOT_AUTOSHOOT] = CreateConVar("lilac_aimbot_autoshoot", "1",
		"Detect Autoshoot.",
		FCVAR_PROTECTED, true, 0.0, true, 1.0);
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
		"Kick players with an interp higher than this in ms (minimum possible is 105ms, default value in Source games is 100ms).\nThis is done to patch an exploit in the game that makes facestabbing players in TF2 easier (aka cl_interp 0.5).\n0 = Disabled.\n105+ = Kick larger than this.",
		FCVAR_PROTECTED, true, 0.0, true, 510.0); // 500 is max possible.
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
	}
	else {
		sv_cheats = 1;
	}

	for (int i = 0; i < CHEAT_MAX; i++)
		ban_length_overwrite[i] = -1;

	// If sv_maxupdaterate is changed mid-game and then this plugin
	// 	is loaded, then it could lead to false positives.
	// 	Reset all stats on all players already in-game, but ignore lerp.
	for (int i = 1; i <= MaxClients; i++) {
		lilac_reset_client(i);
		playerinfo_ignore_lerp[i] = true;
	}

	RegServerCmd("lilac_date_list", lilac_date_list,
		"Lists date formatting options", 0);
	RegServerCmd("lilac_set_ban_length", lilac_set_ban_length,
		"Sets custom ban lengths for specific cheats.", 0);

	// Server is using the old config location, execute it.
	if (FileExists("cfg/lilac_config.cfg", false, NULL_STRING)) {
		AutoExecConfig(true, "lilac_config", "");
	}
	else {
		// Server either just installed Lilac, or wants to use
		// 	the more traditional config folder.
		AutoExecConfig(true, "lilac_config", "sourcemod");
	}

	forwardhandle = CreateGlobalForward("lilac_cheater_detected",
		ET_Ignore, Param_Cell, Param_Cell);
	forwardhandleban = CreateGlobalForward("lilac_cheater_banned",
		ET_Ignore, Param_Cell, Param_Cell);
	forwardhandleallow = CreateGlobalForward("lilac_allow_cheat_detection",
		ET_Event, Param_Cell, Param_Cell);

	CreateTimer(QUERY_TIMER, timer_query, _, TIMER_REPEAT);
	CreateTimer(5.0, timer_check_ping, _, TIMER_REPEAT);
	CreateTimer(5.0, timer_check_lerp, _, TIMER_REPEAT);
	CreateTimer(0.5, timer_check_aimlock, _, TIMER_REPEAT);

	if (icvar[CVAR_LOG])
		lilac_log_first_time_setup();
}

public void OnAllPluginsLoaded()
{
	// Sourcebans compat...
	sourcebans_exist = LibraryExists("sourcebans++");
	materialadmin_exist = LibraryExists("materialadmin");

	// Startup message.
	PrintToServer("[Little Anti-Cheat %s] Successfully loaded!", VERSION);
}

public Action lilac_set_ban_length(int args)
{
	char feature[32], length[32];
	int index = -1;
	int time;

	if (args < 2) {
		PrintToServer("Error: Too few arguments.\n\nUsage:\t\tlilac_set_ban_length <cheat> <minutes>");
		PrintToServer("Example:\tlilac_set_ban_length bhop 15\n\nSets bhop ban to 15 minutes.");
		PrintToServer("If ban length is -1, then the length will be ConVar lilac_ban_length\n");
		PrintToServer("Possible cheat arguments:");
		PrintToServer("\tlilac_set_ban_length angles <minutes>");
		PrintToServer("\tlilac_set_ban_length chatclear <minutes>");
		PrintToServer("\tlilac_set_ban_length convar <minutes>");
		PrintToServer("\tlilac_set_ban_length nolerp <minutes>");
		PrintToServer("\tlilac_set_ban_length bhop <minutes>");
		PrintToServer("\tlilac_set_ban_length aimbot <minutes>");
		PrintToServer("\tlilac_set_ban_length aimlock <minutes>\n");

		return Plugin_Handled;
	}

	GetCmdArg(1, feature, sizeof(feature));
	
	if (StrEqual(feature, "angles", false) || StrEqual(feature, "angle", false)) {
		index = CHEAT_ANGLES;
	}
	else if (StrEqual(feature, "chat", false) || StrEqual(feature, "chatclear", false)) {
		index = CHEAT_CHATCLEAR;
	}
	else if (StrEqual(feature, "convar", false) || StrEqual(feature, "cvar", false)) {
		index = CHEAT_CONVAR;
	}
	else if (StrEqual(feature, "nolerp", false)) {
		index = CHEAT_NOLERP;
	}
	else if (StrEqual(feature, "bhop", false) || StrEqual(feature, "bunnyhop", false)) {
		index = CHEAT_BHOP;
	}
	else if (StrEqual(feature, "aimbot", false) || StrEqual(feature, "aim", false)) {
		index = CHEAT_AIMBOT;
	}
	else if (StrEqual(feature, "aimlock", false)) {
		index = CHEAT_AIMLOCK;
	}
	else {
		PrintToServer("Error: Unknown cheat feature \"%s\"", feature);
		return Plugin_Handled;
	}

	GetCmdArg(2, length, sizeof(length));
	time = StringToInt(length, 10);

	if (time < -1)
		time = -1;

	ban_length_overwrite[index] = time;

	return Plugin_Handled;
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
	MarkNativeAsOptional("MABanPlayer");

	return APLRes_Success;
}

public void OnLibraryAdded(const char []name)
{
	if (StrEqual(name, "sourcebans++"))
		sourcebans_exist = true;
	else if (StrEqual(name, "materialadmin"))
		materialadmin_exist = true;
}

public void OnLibraryRemoved(const char []name)
{
	if (StrEqual(name, "sourcebans++"))
		sourcebans_exist = false;
	else if (StrEqual(name, "materialadmin"))
		materialadmin_exist = false;
}

public void cvar_change(ConVar convar, const char[] oldValue,
				const char[] newValue)
{
	char cvarname[64];
	char testdate[512];

	// Thanks to MAGNAT2645 for informing me I could do this!
	if (view_as<Handle>(convar) == cvar[CVAR_ENABLE]) {
		icvar[CVAR_ENABLE] = StringToInt(newValue, 10);
	}
	else if (view_as<Handle>(convar) == cvar[CVAR_WELCOME]) {
		icvar[CVAR_WELCOME] = StringToInt(newValue, 10);
	}
	else if (view_as<Handle>(convar) == cvar[CVAR_SB]) {
		icvar[CVAR_SB] = StringToInt(newValue, 10);
	}
	else if (view_as<Handle>(convar) == cvar[CVAR_MA]) {
		icvar[CVAR_MA] = StringToInt(newValue, 10);
	}
	else if (view_as<Handle>(convar) == cvar[CVAR_LOG]) {
		icvar[CVAR_LOG] = StringToInt(newValue, 10);
	}
	else if (view_as<Handle>(convar) == cvar[CVAR_LOG_EXTRA]) {
		icvar[CVAR_LOG_EXTRA] = StringToInt(newValue, 10);
	}
	else if (view_as<Handle>(convar) == cvar[CVAR_LOG_MISC]) {
		icvar[CVAR_LOG_MISC] = StringToInt(newValue, 10);
	}
	else if (view_as<Handle>(convar) == cvar[CVAR_LOG_DATE]) {
		lilac_setup_date_format(newValue);

		FormatTime(testdate, sizeof(testdate), dateformat, GetTime());
		PrintToServer("Date Format Preview: %s", testdate);
	}
	else if (view_as<Handle>(convar) == cvar[CVAR_BAN]) {
		icvar[CVAR_BAN] = StringToInt(newValue, 10);

		if (!icvar[CVAR_BAN])
			PrintToServer("[Little Anti-Cheat %s] WARNING: 'lilac_ban' has been set to 0, banning of cheaters has been disabled.", VERSION);
	}
	else if (view_as<Handle>(convar) == cvar[CVAR_BAN_LENGTH]) {
		icvar[CVAR_BAN_LENGTH] = StringToInt(newValue, 10);
	}
	else if (view_as<Handle>(convar) == cvar[CVAR_ANGLES]) {
		icvar[CVAR_ANGLES] = StringToInt(newValue, 10);
	}
	else if (view_as<Handle>(convar) == cvar[CVAR_PATCH_ANGLES]) {
		icvar[CVAR_PATCH_ANGLES] = StringToInt(newValue, 10);
	}
	else if (view_as<Handle>(convar) == cvar[CVAR_CHAT]) {
		icvar[CVAR_CHAT] = StringToInt(newValue, 10);
	}
	else if (view_as<Handle>(convar) == cvar[CVAR_CONVAR]) {
		icvar[CVAR_CONVAR] = StringToInt(newValue, 10);
	}
	else if (view_as<Handle>(convar) == cvar[CVAR_NOLERP]) {
		icvar[CVAR_NOLERP] = StringToInt(newValue, 10);
	}
	else if (view_as<Handle>(convar) == cvar[CVAR_BHOP]) {
		icvar[CVAR_BHOP] = StringToInt(newValue, 10);
	}
	else if (view_as<Handle>(convar) == cvar[CVAR_AIMBOT]) {
		icvar[CVAR_AIMBOT] = StringToInt(newValue, 10);

		if (icvar[CVAR_AIMBOT] > 1 &&
			icvar[CVAR_AIMBOT] < AIMBOT_BAN_MIN)
			icvar[CVAR_AIMBOT] = 5;
	}
	else if (view_as<Handle>(convar) == cvar[CVAR_AIMBOT_AUTOSHOOT]) {
		icvar[CVAR_AIMBOT_AUTOSHOOT] = StringToInt(newValue, 10);
	}
	else if (view_as<Handle>(convar) == cvar[CVAR_AIMLOCK]) {
		icvar[CVAR_AIMLOCK] = StringToInt(newValue, 10);

		if (icvar[CVAR_AIMLOCK] > 1
			&& icvar[CVAR_AIMLOCK] < AIMLOCK_BAN_MIN)
			icvar[CVAR_AIMLOCK] = 5;
	}
	else if (view_as<Handle>(convar) == cvar[CVAR_AIMLOCK_LIGHT]) {
		icvar[CVAR_AIMLOCK_LIGHT] = StringToInt(newValue, 10);
	}
	else if (view_as<Handle>(convar) == cvar[CVAR_BACKTRACK_PATCH]) {
		icvar[CVAR_BACKTRACK_PATCH] = StringToInt(newValue, 10);
	}
	else if (view_as<Handle>(convar) == cvar[CVAR_MAX_PING]) {
		icvar[CVAR_MAX_PING] = StringToInt(newValue, 10);
	}
	else if (view_as<Handle>(convar) == cvar[CVAR_MAX_LERP]) {
		icvar[CVAR_MAX_LERP] = StringToInt(newValue, 10);
	}
	else if (view_as<Handle>(convar) == cvar[CVAR_LOSS_FIX]) {
		icvar[CVAR_LOSS_FIX] = StringToInt(newValue, 10);
	}
	else {
		GetConVarName(convar, cvarname, sizeof(cvarname));

		if (StrEqual(cvarname, "sv_autobunnyhopping", false)) {
			cvar_bhop_value = StringToInt(newValue, 10);
		}
		else if (StrEqual(cvarname, "sv_maxupdaterate", false)) {
			sv_maxupdaterate = StringToInt(newValue);

			// Changing this convar mid-game can cause false positives.
			// 	Ignore players already in-game.
			for (int i = 1; i <= MaxClients; i++)
				playerinfo_ignore_lerp[i] = true;
		}
		else if (StrEqual(cvarname, "sv_cheats", false)) {
			sv_cheats = StringToInt(newValue);

			// Delay convar checks for 30 seconds.
			time_sv_cheats = GetTime() + QUERY_TIMEOUT;
		}
	}
}

public void OnClientPutInServer(int client)
{
	lilac_reset_client(client);

	CreateTimer(20.0, timer_welcome, GetClientUserId(client));
}

void lilac_reset_client(int client)
{
	playerinfo_ignore_lerp[client] = false;
	playerinfo_index[client] = 0;
	playerinfo_tickcount[client] = 0;
	playerinfo_autoshoot[client] = 0;
	playerinfo_jumps[client] = 0;
	playerinfo_high_ping[client] = 0;
	playerinfo_query_index[client] = 0;
	playerinfo_query_failed[client] = 0;
	playerinfo_aimlock_sus[client] = 0;
	playerinfo_aimlock[client] = 0;
	playerinfo_aimbot[client] = 0;
	playerinfo_bhop[client] = 0;
	playerinfo_time_teleported[client] = 0.0;
	playerinfo_time_aimlock[client] = 0.0;
	playerinfo_time_backtrack[client] = 0.0;
	playerinfo_time_process_aimlock[client] = 0.0;

	for (int i = 0; i < CHEAT_MAX; i++)
		playerinfo_banned_flags[client][i] = false;

	for (int i = 0; i < CMD_LENGTH; i++) {
		playerinfo_buttons[client][i] = 0;
		playerinfo_actions[client][i] = 0;
		playerinfo_time_usercmd[client][i] = 0.0;

		set_player_log_angles(client, Float:{0.0, 0.0, 0.0}, i);
	}
}

public void TF2_OnConditionRemoved(int client, TFCond condition)
{
	if (condition == TFCond_Taunting)
		playerinfo_time_teleported[client] = GetGameTime();
}

public Action event_teleported(Event event, const char[] name,
				bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid", -1));

	if (is_player_valid(client))
		playerinfo_time_teleported[client] = GetGameTime();
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
		|| !is_player_valid(victim)
		|| IsFakeClient(client)
		|| playerinfo_banned_flags[client][CHEAT_AIMBOT]
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
	pack.WriteCell(playerinfo_index[client]);
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

	if (is_player_valid(client) && icvar[CVAR_WELCOME] && icvar[CVAR_ENABLE] && icvar[CVAR_BAN])
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
		if (playerinfo_banned_flags[i][CHEAT_CONVAR])
			continue;

		// Only increments query index if the player
		// 	has responded to the last one.
		if (!playerinfo_query_failed[i]) {
			if (++playerinfo_query_index[i] >= 11)
				playerinfo_query_index[i] = 0;
		}

		QueryClientConVar(i, query_list[playerinfo_query_index[i]], query_reply, 0);

		if (++playerinfo_query_failed[i] > QUERY_MAX_FAILURES) {
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
	playerinfo_query_failed[client] = 0;

	// Any response the server may recieve may also be faulty, ignore.
	if (GetTime() < time_sv_cheats || sv_cheats)
		return;

	// Already banned.
	if (playerinfo_banned_flags[client][CHEAT_CONVAR])
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

		playerinfo_banned_flags[client][CHEAT_CONVAR] = true;
		lilac_ban_client(client, CHEAT_CONVAR);
	}
}

public Action timer_check_lerp(Handle timer)
{
	float min;

	if (!icvar[CVAR_ENABLE])
		return Plugin_Continue;

	if (sv_maxupdaterate > 0)
		min = 1.0 / float(sv_maxupdaterate);
	else
		min = 0.0;

	for (int i = 1; i <= MaxClients; i++) {
		if (!is_player_valid(i) || IsFakeClient(i))
			continue;

		float lerp = GetEntPropFloat(i, Prop_Data, "m_fLerpTime");

		if (lerp * 1000.0 > float(icvar[CVAR_MAX_LERP]) && icvar[CVAR_MAX_LERP] >= 105) {
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

		if (!icvar[CVAR_NOLERP]
			|| playerinfo_ignore_lerp[i]
			|| playerinfo_banned_flags[i][CHEAT_NOLERP]
			|| min < 0.005) // Minvalue invalid or too low.
			continue;

		if (lerp > min * 0.95 /* buffer */)
			continue;

		if (lilac_forward_allow_cheat_detection(i, CHEAT_NOLERP) == false)
			continue;

		playerinfo_banned_flags[i][CHEAT_NOLERP] = true;

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
			if (toggle && playerinfo_high_ping[i] > 0)
				playerinfo_high_ping[i]--;

			continue;
		}

		// Player has a higher ping than maximum for 45 seconds.
		if (++playerinfo_high_ping[i] < 9)
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

public Action timer_check_aimlock(Handle timer)
{
	float ang[3], lang[3], ideal[3], pos[3], pos2[3];
	float aimdist, laimdist;
	int lock;

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
		if (GetGameTime() - playerinfo_time_teleported[i] < 2.0)
			continue;

		// Player has too much packet loss.
		if (skip_due_to_loss(i))
			continue;

		// Player already banned for aimlock, don't need to check for it.
		if (playerinfo_banned_flags[i][CHEAT_AIMLOCK])
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
				process = false;
				continue;
			}

			// Player target teleported, skip testing.
			if (GetGameTime() - playerinfo_time_teleported[k] < 2.0)
				continue;

			aim_at_point(pos, pos2, ideal);

			lock = 0;
			int ind = playerinfo_index[i];
			for (int l = 0; l < time_to_ticks(0.5 + 0.1); l++) {
				if (ind < 0)
					ind += CMD_LENGTH;

				// Only process ticks that happened 0.5 seconds ago... Plus lock_time.
				if (GetGameTime() - playerinfo_time_usercmd[i][ind] < 0.5 + 0.1) {
					get_player_log_angles(i, ind, false, ang);
					laimdist = angle_delta(ang, ideal);

					if (l) {
						if (aimdist < 5.0)
							lock++;
						else
							lock = 0;

						if (aimdist < laimdist * 0.1
							&& angle_delta(ang, lang) > 20.0
							&& lock > time_to_ticks(0.1)) {

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
	ind = playerinfo_index[client];
	// 0.5 (datapacktimer delay) + 0.5 (snap test) + 0.1 (buffer).
	// We are looking this far back in case of a projectile aimbot shot,
	// 	as the death event happens way later after the shot.
	for (int i = 0; i < CMD_LENGTH - time_to_ticks(0.5 + 0.5 + 0.1); i++) {
		if (--ind < 0)
			ind += CMD_LENGTH;

		// The shot needs to have happened at least 0.3 seconds ago.
		if (GetGameTime() - playerinfo_time_usercmd[client][ind] < 0.3)
			continue;

		if ((playerinfo_actions[client][ind] & ACTION_SHOT)) {
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
		if (playerinfo_index[client] == fallback) {
			skip_autoshoot = true;
			skip_repeat = true;
		}
	}
	else {
		// Don't detect the same shot twice.
		playerinfo_actions[client][shotindex] = 0;
	}

	// Forgot to add this in the past, oops...
	// 	Skip repeat detections if players are too close to each other.
	if (skip_snap)
		skip_repeat = true;

	// Player taunted within 0.5 seconds of taking a shot leading to a kill.
	// Ignore snap detections.
	if (-0.1 < playerinfo_time_usercmd[client][shotindex] - playerinfo_time_teleported[client] < 0.5 + 0.1)
		skip_snap = true;

	// Aimsnap and total delta test.
	if (skip_snap == false) {
		aim_at_point(killpos, deathpos, ideal);

		ind = shotindex;
		for (int i = 0; i < time_to_ticks(0.5); i++) {
			if (ind < 0)
				ind += CMD_LENGTH;

			// We're looking back further than 0.5 seconds prior to the shot, abort.
			if (playerinfo_time_usercmd[client][shotindex] - playerinfo_time_usercmd[client][ind] > 0.5)
				break;

			laimdist = angle_delta(playerinfo_angles[client][ind], ideal);
			get_player_log_angles(client, ind, false, ang);

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
		get_player_log_angles(client, shotindex - 1, false, ang);
		get_player_log_angles(client, shotindex + 1, false, lang);
		tdelta = angle_delta(ang, lang);
		get_player_log_angles(client, shotindex, false, lang);

		if (tdelta < 10.0 && angle_delta(ang, lang) > 0.5
			&& angle_delta(ang, lang) > tdelta * 5.0)
			detected |= AIMBOT_FLAG_REPEAT;
	}

	// Autoshoot test.
	if (skip_autoshoot == false && icvar[CVAR_AIMBOT_AUTOSHOOT]) {
		int tmp = 0;
		ind = shotindex+1;
		for (int i = 0; i < 3; i++) {
			if (ind < 0)
				ind += CMD_LENGTH;
			else if (ind >= CMD_LENGTH)
				ind -= CMD_LENGTH;

			if ((playerinfo_buttons[client][ind] & IN_ATTACK))
				tmp++;

			ind--;
		}

		// Onetick perfect shot.
		// Players must get two of them in a row leading to a kill
		// 	or something else must have been detected to get this flag.
		if (tmp == 1) {
			if (detected || ++playerinfo_autoshoot[client] > 1)
				detected |= AIMBOT_FLAG_AUTOSHOOT;
		}
		else {
			playerinfo_autoshoot[client] = 0;
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
	if (++playerinfo_index[client] >= CMD_LENGTH)
		playerinfo_index[client] = 0;

	// Store when the tick was processed.
	playerinfo_time_usercmd[client][playerinfo_index[client]] = GetGameTime();

	// Store angles.
	set_player_log_angles(client, angles, playerinfo_index[client]);

	// Store actions.
	playerinfo_buttons[client][playerinfo_index[client]] = buttons;
	playerinfo_actions[client][playerinfo_index[client]] = 0;
	if ((buttons & IN_ATTACK) && bullettime_can_shoot(client))
		playerinfo_actions[client][playerinfo_index[client]] |= ACTION_SHOT;

	// We need to store information even if the plugin is disabled,
	// 	incase it gets turned on again mid-game.
	if (!icvar[CVAR_ENABLE]) {
		lbuttons[client] = buttons;
		playerinfo_tickcount[client] = tickcount;

		return Plugin_Continue;
	}

	// Patch backtracking.
	// 	This will cause hitreg issues for players with packetloss (and some teleporting??).
	if (icvar[CVAR_BACKTRACK_PATCH]) {
		if (lilac_client_tickcount_incremented(client, tickcount) == false
			&& lilac_is_player_in_backtrack_timeout(client) == false)
			lilac_set_client_in_backtrack_timeout(client);

		// Store tickcount before modifying (For future tests).
		playerinfo_tickcount[client] = tickcount;

		if (lilac_is_player_in_backtrack_timeout(client))
			tickcount = lilac_random_tickcount(client);
	}
	else {
		playerinfo_tickcount[client] = tickcount;
	}

	// Detect angles that are out of bounds.
	// 	Ignore players who recently teleported.
	if (icvar[CVAR_ANGLES] && IsPlayerAlive(client)
		&& GetGameTime() > playerinfo_time_teleported[client] + 5.0) {

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
		if (max_angles[0] != 0.0) {
			if (angles[0] > max_angles[0])
				angles[0] = max_angles[0];
			else if (angles[0] < (max_angles[0] * -1.0))
				angles[0] = (max_angles[0] * -1.0);
		}

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

				playerinfo_bhop[client]++;
			}

			playerinfo_jumps[client]++;
		}
		else if ((flags & FL_ONGROUND)) {
			playerinfo_bhop[client] = 0;
			playerinfo_jumps[client] = 0;
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
	return (tickcount == playerinfo_tickcount[client] + 1);
}

void lilac_set_client_in_backtrack_timeout(int client)
{
	// Set the player in backtrack timeout for 1 second.
	playerinfo_time_backtrack[client] = GetGameTime() + 1.0;
}

bool lilac_is_player_in_backtrack_timeout(int client)
{
	return (GetGameTime() < playerinfo_time_backtrack[client]);
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
	if (playerinfo_banned_flags[client][CHEAT_AIMLOCK])
		return;

	// Suspicions reset after 3 minutes.
	// 	This means you need to get two aimlocks within
	// 	three minutes of each other to get a single
	// 	detection.
	if (GetGameTime() - playerinfo_time_aimlock[client] < 180.0)
		playerinfo_aimlock_sus[client]++;
	else
		playerinfo_aimlock_sus[client] = 1;

	playerinfo_time_aimlock[client] = GetGameTime();

	if (playerinfo_aimlock_sus[client] < 2)
		return;

	playerinfo_aimlock_sus[client] = 0;

	if (lilac_forward_allow_cheat_detection(client, CHEAT_AIMLOCK) == false)
		return;

	// Detection expires in 10 minutes.
	CreateTimer(600.0, timer_decrement_aimlock, GetClientUserId(client));

	lilac_forward_client_cheat(client, CHEAT_AIMLOCK);

	// Don't log the first detection.
	if (++playerinfo_aimlock[client] < 2)
		return;

	if (icvar[CVAR_LOG]) {
		lilac_log_setup_client(client);
		Format(line, sizeof(line),
			"%s is suspected of using an aimlock (Detection: %d).",
			line, playerinfo_aimlock[client]);

		lilac_log(true);

		if (icvar[CVAR_LOG_EXTRA] == 2)
			lilac_log_extra(client);
	}

	if (playerinfo_aimlock[client] >= icvar[CVAR_AIMLOCK]
		&& icvar[CVAR_AIMLOCK] >= AIMLOCK_BAN_MIN) {
		playerinfo_banned_flags[client][CHEAT_AIMLOCK] = true;

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
	if (playerinfo_banned_flags[client][CHEAT_BHOP])
		return;

	// Mode 1:
	// 	Simplistic mode, only ban on the 10th bhop.
	// Mode 2:
	// 	Advanced mode, ban on 5th bhop if the jump count is lower than 15.
	// 	Else, ban on 10th bhop.
	switch (icvar[CVAR_BHOP]) {
	case 1: {
		if (playerinfo_bhop[client] < 10)
			return;
	}
	case 2: {
		if (playerinfo_bhop[client] < 5)
			return;
		else if (playerinfo_bhop[client] < 10 && playerinfo_jumps[client] > 15)
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
			line, playerinfo_jumps[client], playerinfo_bhop[client]);

		lilac_log(true);

		if (icvar[CVAR_LOG_EXTRA])
			lilac_log_extra(client);
	}

	lilac_ban_client(client, CHEAT_BHOP);
}

void lilac_detected_antiaim(int client)
{
	float ang[3];

	if (playerinfo_banned_flags[client][CHEAT_ANGLES])
		return;

	// Todo, set timeout to prevent constant spamming?
	if (lilac_forward_allow_cheat_detection(client, CHEAT_ANGLES) == false)
		return;

	playerinfo_banned_flags[client][CHEAT_ANGLES] = true;

	lilac_forward_client_cheat(client, CHEAT_ANGLES);

	if (icvar[CVAR_LOG]) {
		get_player_log_angles(client, 0, true, ang);

		lilac_log_setup_client(client);
		Format(line, sizeof(line),
			"%s was detected and banned for Angle-Cheats (Pitch: %.2f, Yaw: %.2f, Roll: %.2f).",
			line,
			ang[0], ang[1], ang[2]);

		lilac_log(true);

		if (icvar[CVAR_LOG_EXTRA])
			lilac_log_extra(client);
	}

	lilac_ban_client(client, CHEAT_ANGLES);
}

void lilac_detected_aimbot(int client, float delta, float td, int flags)
{
	if (playerinfo_banned_flags[client][CHEAT_AIMBOT])
		return;

	if (lilac_forward_allow_cheat_detection(client, CHEAT_AIMBOT) == false)
		return;

	// Detection expires in 10 minutes.
	CreateTimer(600.0, timer_decrement_aimbot, GetClientUserId(client));

	lilac_forward_client_cheat(client, CHEAT_AIMBOT);

	// Don't log the first detection.
	if (++playerinfo_aimbot[client] < 2)
		return;

	if (icvar[CVAR_LOG]) {
		lilac_log_setup_client(client);
		Format(line, sizeof(line),
			"%s is suspected of using an aimbot (Detection: %d | Delta: %.0f | TotalDelta: %.0f | Detected:%s%s%s%s%s).",
			line, playerinfo_aimbot[client], delta, td,
			((flags & AIMBOT_FLAG_SNAP)      ? " Aim-Snap"     : ""),
			((flags & AIMBOT_FLAG_SNAP2)     ? " Aim-Snap2"    : ""),
			((flags & AIMBOT_FLAG_AUTOSHOOT) ? " Autoshoot"    : ""),
			((flags & AIMBOT_FLAG_REPEAT)    ? " Angle-Repeat" : ""),
			((td > AIMBOT_MAX_TOTAL_DELTA)   ? " Total-Delta"  : ""));

		lilac_log(true);

		if (icvar[CVAR_LOG_EXTRA] == 2)
			lilac_log_extra(client);
	}

	if (playerinfo_aimbot[client] >= icvar[CVAR_AIMBOT]
		&& icvar[CVAR_AIMBOT] >= AIMBOT_BAN_MIN) {

		if (icvar[CVAR_LOG]) {
			lilac_log_setup_client(client);
			Format(line, sizeof(line),
				"%s was banned for Aimbot.", line);

			lilac_log(true);

			if (icvar[CVAR_LOG_EXTRA])
				lilac_log_extra(client);
		}

		playerinfo_banned_flags[client][CHEAT_AIMBOT] = true;
		lilac_ban_client(client, CHEAT_AIMBOT);
	}
}

public Action OnClientSayCommand(int client, const char[] command, const char[] sArgs)
{
	// Prevent players banned for Chat-Clear from spamming chat.
	// 	Helps legit players see the cheater was banned.
	if (playerinfo_banned_flags[client][CHEAT_CHATCLEAR])
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
	if (playerinfo_banned_flags[client][CHEAT_CHATCLEAR])
		return;

	if (does_string_contain_newline(sArgs)) {
		if (lilac_forward_allow_cheat_detection(client, CHEAT_CHATCLEAR) == false)
			return;

		playerinfo_banned_flags[client][CHEAT_CHATCLEAR] = true;
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
	if (GetGameTime() - playerinfo_time_teleported[client] < 3.0)
		return;

	ind = playerinfo_index[client];
	for (int i = 0; i < time_to_ticks(0.5); i++) {
		if (ind < 0)
			ind += CMD_LENGTH;

		get_player_log_angles(client, ind, false, ang);

		if (i) {
			// This player has a somewhat big delta,
			// 	test this player for aimlock for 200 seconds.
			// Even if we end up flagging more than 5 players
			// 	for this, that's fine as only 5 players
			// 	can be processed in the aimlock check timer.
			if (angle_delta(lastang, ang) > 20.0) {
				playerinfo_time_process_aimlock[client] = GetGameTime() + 200.0;
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
	return (GetGameTime() < playerinfo_time_process_aimlock[client] // Are in the que.
		|| playerinfo_aimlock[client] // Already has a detection.
		|| playerinfo_aimbot[client] > 1 // Already have been detected for aimbot twice.
		|| (GetGameTime() - playerinfo_time_aimlock[client] < 180.0 && playerinfo_time_aimlock[client] > 1.0)); // Had one aimlock the past three minutes.
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
	float pos[3], ang[3];

	GetClientAbsOrigin(client, pos);
	GetCurrentMap(map, sizeof(map));
	GetClientWeapon(client, weapon, sizeof(weapon));

	get_player_log_angles(client, 0, true, ang);

	Format(line, sizeof(line),
		"\tPos={%.0f,%.0f,%.0f}, Angles={%.5f,%.5f,%.5f}, Map=\"%s\", Team={%d}, Weapon=\"%s\", Latency={Inc:%f,Out:%f}, Loss={Inc:%f,Out:%f}, Choke={Inc:%f,Out:%f}, ConnectionTime={%f seconds}, GameTime={%f seconds}",
		pos[0], pos[1], pos[2],
		ang[0], ang[1], ang[2],
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
	Handle file = OpenFile("addons/sourcemod/logs/lilac.log", "a");

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

	WriteFileLine(file, "%s", line);
	CloseHandle(file);
}

void lilac_log_first_time_setup()
{
	// Some admins may not understand how to interpret cheat logs
	// correctly, thus, we should warn them so they don't panic
	// over trivial stuff.
	if (!FileExists("addons/sourcemod/logs/lilac.log", false, NULL_STRING)) {
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

	// Banning has been disabled, don't forward the ban and don't ban.
	if (!icvar[CVAR_BAN])
		return;

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

#if defined _materialadmin_included
	if (materialadmin_exist && icvar[CVAR_MA]) {
		MABanPlayer(0, client, MA_BAN_STEAM, get_ban_length(cheat), reason);
		CreateTimer(5.0, timer_kick, GetClientUserId(client));
		return;
	}
#endif


#if defined _sourcebanspp_included
	if (sourcebans_exist && icvar[CVAR_SB]) {
		SBPP_BanPlayer(0, client, get_ban_length(cheat), reason);
		CreateTimer(5.0, timer_kick, GetClientUserId(client));
		return;
	}
#endif

	// "Else"
	BanClient(client, get_ban_length(cheat), BANFLAG_AUTO, reason, reason, "lilac", 0);

	// Kick the client in case they are still on the server.
	CreateTimer(5.0, timer_kick, GetClientUserId(client));
}

public Action timer_kick(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if (is_player_valid(client))
		KickClient(client, "%T", "kick_ban_genetic", client);
}

int get_ban_length(int cheat)
{
	return ((ban_length_overwrite[cheat] <= -1) ? icvar[CVAR_BAN_LENGTH] : ban_length_overwrite[cheat]);
}

void get_player_log_angles(int client, int tick, bool latest, float writeto[3])
{
	int i = tick;

	if (latest) {
		i = playerinfo_index[client];
	}
	else {
		while (i < 0)
			i += CMD_LENGTH;
		while (i >= CMD_LENGTH)
			i -= CMD_LENGTH;
	}

	writeto[0] = playerinfo_angles[client][i][0];
	writeto[1] = playerinfo_angles[client][i][1];
	writeto[2] = playerinfo_angles[client][i][2];
}

void set_player_log_angles(int client, float ang[3], int tick)
{
	int i = tick;

	// Normalize tick.
	while (i < 0)
		i += CMD_LENGTH;
	while (i >= CMD_LENGTH)
		i -= CMD_LENGTH;

	playerinfo_angles[client][i][0] = ang[0];
	playerinfo_angles[client][i][1] = ang[1];
	playerinfo_angles[client][i][2] = ang[2];
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

	if (playerinfo_aimbot[client] > 0)
		playerinfo_aimbot[client]--;
}

public Action timer_decrement_aimlock(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);

	if (!is_player_valid(client))
		return;

	if (playerinfo_aimlock[client] > 0)
		playerinfo_aimlock[client]--;
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
