#pragma newdecls required
#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <cstrike>
#include <clientprefs>
#include <hitsounds>
#include <multicolors>

Cookie g_cVolume;
Cookie g_cEnable;
Cookie g_cBoss;
Cookie g_cDetailed;

#define DEFAULT_VOLUME 0.8
#define DEFAULT_VOLUME_INT 80

enum struct PlayerData
{
	int volume;
	float fVolume;
	bool boss;
	bool enable;
	bool detailed;
	int lastTick;

	void Reset()
	{
		this.volume = DEFAULT_VOLUME_INT;
		this.fVolume = DEFAULT_VOLUME;
		this.boss = true;
		this.enable = true;
		this.detailed = false;
		this.lastTick = -1;
	}
}

PlayerData g_pData[MAXPLAYERS+1];

ConVar g_cvHitsound;
ConVar g_cvHitsoundHead;
ConVar g_cvHitsoundBody;
ConVar g_cvHitsoundKill;
char g_sHitsoundPath[PLATFORM_MAX_PATH];
char g_sHitsoundHeadPath[PLATFORM_MAX_PATH];
char g_sHitsoundBodyPath[PLATFORM_MAX_PATH];
char g_sHitsoundKillPath[PLATFORM_MAX_PATH];

public Plugin myinfo =
{
	name        = "Hit Sounds",
	author      = "koen, tilgep",
	description = "",
	version     = "1.1.0",
	url         = "https://github.com/notkoen & https://github.com/tilgep"
};

public void OnPluginStart()
{
	// Hitsound Convars
	g_cvHitsound = CreateConVar("sm_hitsound_path", "hitmarker/hitmarker.mp3", "File location of normal hitsound relative to sound folder.");
	g_cvHitsoundHead = CreateConVar("sm_hitsound_head_path", "hitmarker/headshot.mp3", "File location of head hitsound relative to sound folder.");
	g_cvHitsoundBody = CreateConVar("sm_hitsound_body_path", "hitmarker/bodyshot.mp3", "File location of body hitsound relative to sound folder.");
	g_cvHitsoundKill = CreateConVar("sm_hitsound_kill_path", "hitmarker/killshot.mp3", "File location of kill hitsound relative to sound folder.");
	AutoExecConfig(true, "Hitsounds");

	// Client cookies
	g_cEnable = new Cookie("hitsound_enable", "Toggle hitsounds", CookieAccess_Private);
	g_cVolume = new Cookie("hitsound_volume", "Hitsound volume", CookieAccess_Private);
	g_cBoss = new Cookie("hitsound_boss", "Toggle boss hitsounds", CookieAccess_Private);
	g_cDetailed = new Cookie("hitsound_detailed", "Toggle detailed hitsounds", CookieAccess_Private);

	// Add HitSound menu to !settings cookie menu
	SetCookieMenuItem(CookieMenu_HitMarker, INVALID_HANDLE, "Hit Sound Settings");

	// Hook onto entities so plugin detects when we hit a boss (or a breakable)
	HookEntityOutput("func_physbox", "OnHealthChanged", Hook_EntityOnDamage);
	HookEntityOutput("func_physbox_multiplayer", "OnHealthChanged", Hook_EntityOnDamage);
	HookEntityOutput("func_breakable", "OnHealthChanged", Hook_EntityOnDamage);
	HookEntityOutput("math_counter", "OutValue", Hook_EntityOnDamage);

	// Hook onto when we hit zombies
	HookEvent("player_hurt", Hook_EventOnDamage);

	// Console Commands
	RegConsoleCmd("sm_hits", Command_Hitsound, "Bring up hitsounds settings menu");
	RegConsoleCmd("sm_hitsound", Command_Hitsound, "Bring up hitsounds settings menu");
	RegConsoleCmd("sm_hitsounds", Command_Hitsound, "Bring up hitsounds settings menu");

	// Late load
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && AreClientCookiesCached(i))
			OnClientCookiesCached(i);
	}
}

public void OnMapStart()
{
	PrecacheSounds();
	GetConVarString(g_cvHitsound, g_sHitsoundPath, sizeof(g_sHitsoundPath));
	GetConVarString(g_cvHitsoundBody, g_sHitsoundBodyPath, sizeof(g_sHitsoundBodyPath));
	GetConVarString(g_cvHitsoundHead, g_sHitsoundHeadPath, sizeof(g_sHitsoundHeadPath));
	GetConVarString(g_cvHitsoundKill, g_sHitsoundKillPath, sizeof(g_sHitsoundKillPath));
}

public void OnClientCookiesCached(int client)
{
	char buffer[8];
	g_cEnable.Get(client, buffer, sizeof(buffer));

	if (buffer[0] == '\0')
	{
		g_cEnable.Set(client, "1");
		g_cBoss.Set(client, "1");
		g_cDetailed.Set(client, "1");
		g_cVolume.Set(client, "0.80");
	}

	g_pData[client].enable = strcmp(buffer, "1", false) == 0;

	g_cBoss.Get(client, buffer, sizeof(buffer));
	g_pData[client].boss = strcmp(buffer, "1", false) == 0;

	g_cDetailed.Get(client, buffer, sizeof(buffer));
	g_pData[client].detailed = strcmp(buffer, "1", false) == 0;

	g_cVolume.Get(client, buffer, sizeof(buffer));
	g_pData[client].fVolume = StringToFloat(buffer);
	g_pData[client].volume = RoundToNearest(g_pData[client].fVolume * 100);
}

public void OnClientDisconnect(int client)
{
	g_pData[client].Reset();
}

/* ---------------[ Natives ]--------------- */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	RegPluginLibrary("hitsounds");

	// Get client settings native
	CreateNative("GetHitsoundStatus", Native_GetHitsoundStatus);
	CreateNative("GetHitsoundVolume", Native_GetHitsoundVolume);

	// Change client settings native
	CreateNative("ToggleHitsound", Native_ToggleHitsound);
	CreateNative("SetHitsoundVolume", Native_SetHitsoundVolume);

	// Menu native
	CreateNative("OpenHitsoundMenu", Native_OpenHitsoundMenu);

	return APLRes_Success;
}

public int Native_GetHitsoundStatus(Handle plugin, int numParams)
{
	SoundType type = view_as<SoundType>(GetNativeCell(2));
	switch (type)
	{
		case Sound_Zombie:
			return g_pData[GetNativeCell(1)].enable;
		case Sound_Boss:
			return g_pData[GetNativeCell(1)].boss;
		case Sound_Detailed:
			return g_pData[GetNativeCell(1)].detailed;
	}
	return 1;
}

public any Native_GetHitsoundVolume(Handle plugin, int numParams)
{
	return g_pData[GetNativeCell(1)].volume;
}

public int Native_ToggleHitsound(Handle plugin, int numParams)
{
	SoundType type = view_as<SoundType>(GetNativeCell(2));
	switch (type)
	{
		case Sound_Zombie:
			ToggleZombieHitsound(GetNativeCell(1));
		case Sound_Boss:
			ToggleBossHitsound(GetNativeCell(1));
		case Sound_Detailed:
			ToggleDetailedHitsound(GetNativeCell(1));
	}
	return 1;
}

public int Native_SetHitsoundVolume(Handle plugin, int numParams)
{
	char buffer[4];
	Format(buffer, sizeof(buffer), "%.2f", GetNativeCell(2) / 100.0);
	g_pData[GetNativeCell(1)].volume = GetNativeCell(2);
	g_pData[GetNativeCell(1)].fVolume = StringToFloat(buffer);
	g_cVolume.Set(GetNativeCell(1), buffer);
	return 1;
}

public int Native_OpenHitsoundMenu(Handle plugin, int numParams)
{
	DisplayCookieMenu(GetNativeCell(1));
	return 1;
}

/* ---------------[ Toggle Functions ]--------------- */
public void ToggleZombieHitsound(int client)
{
	g_pData[client].enable = !g_pData[client].enable;
	CPrintToChat(client, "{green}[HitSound]{default} Zombie hitsounds are now %s", g_pData[client].enable ? "{green}enabled" : "{red}disabled");
	g_pData[client].enable ? g_cEnable.Set(client, "1") : g_cEnable.Set(client, "0");
}

public void ToggleBossHitsound(int client)
{
	g_pData[client].boss = !g_pData[client].boss;
	CPrintToChat(client, "{green}[HitSound]{default} Boss hitsounds are now %s", g_pData[client].boss ? "{green}enabled" : "{red}disabled");
	g_pData[client].boss ? g_cBoss.Set(client, "1") : g_cBoss.Set(client, "0");
}

public void ToggleDetailedHitsound(int client)
{
	g_pData[client].detailed = !g_pData[client].detailed;
	CPrintToChat(client, "{green}[HitSound]{default} Detailed hitsounds are now %s", g_pData[client].detailed ? "{green}enabled" : "{red}disabled");
	g_pData[client].detailed ? g_cDetailed.Set(client, "1") : g_cDetailed.Set(client, "0");
}

/* ---------------[ Plugin Commands ]--------------- */
public Action Command_Hitsound(int client, int args)
{
	char buffer[8];
	int len = GetCmdArg(1, buffer, sizeof(buffer));

	if (strcmp(buffer, "off", false) == 0)
	{
		if (g_pData[client].enable)
		{
			g_pData[client].enable = false;
			g_cEnable.Set(client, "0");
			CPrintToChat(client, "{green}[HitSound]{default} Hitsounds have been {red}disabled!");
		}
		else
			CPrintToChat(client, "{green}[HitSound]{default} Hitsounds are already {red}disabled!");
	}
	else if (strcmp(buffer, "on", false) == 0)
	{
		if (g_pData[client].enable)
			CPrintToChat(client, "{green}[HitSound]{default} Hitsounds are already {green}enabled!");
		else
		{
			g_pData[client].enable = true;
			g_cEnable.Set(client, "1");
			CPrintToChat(client, "{green}[HitSound]{default} Hitsounds have been {green}enabled!");
		}
	}
	else
	{
		int input;
		if (len != 0 && StringToIntEx(buffer, input) == len)
		{
			float fVolume = input / 100.0;
			char recalc[8];
			Format(recalc, sizeof(recalc), "%.2f", fVolume);

			g_pData[client].volume = input;
			g_pData[client].fVolume = fVolume;
			CPrintToChat(client, "{green}[HitSound]{default} Hitsound volume has been changed to {green}%d", input);
			g_cVolume.Set(client, recalc);
		}
		else
			DisplayCookieMenu(client);
	}
	return Plugin_Handled;
}

/* ---------------[ Client Menu ]--------------- */
public void CookieMenu_HitMarker(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	switch (action)
	{
		case CookieMenuAction_SelectOption:
			DisplayCookieMenu(client);
	}
}

public void DisplayCookieMenu(int client)
{
	Menu menu = new Menu(MenuHandler_HitMarker, MENU_ACTIONS_DEFAULT | MenuAction_DisplayItem);
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	SetMenuTitle(menu, "Hitsounds:\n \n");

	char buffer[128];
	Format(buffer, sizeof(buffer), "Hitsounds: %s\n ", g_pData[client].enable ? "On" : "Off");
	AddMenuItem(menu, "zombie", buffer);

	Format(buffer, sizeof(buffer), "Boss hitsounds: %s\n ", g_pData[client].boss ? "On" : "Off");
	AddMenuItem(menu, "boss", buffer);

	Format(buffer, sizeof(buffer), "Detailed hitsounds: %s\n \nUse \"!hitsound [0-100]\" to set volume", g_pData[client].detailed ? "On" : "Off");
	AddMenuItem(menu, "detailed", buffer);

	Format(buffer, sizeof(buffer), "Volume: %d", g_pData[client].volume);
	AddMenuItem(menu, "vol", buffer);
	DisplayMenu(menu, client, MENU_TIME_FOREVER);
}

public int MenuHandler_HitMarker(Menu menu, MenuAction action, int client, int selection)
{
	switch (action)
	{
		case MenuAction_End:
		{
			if (client != MenuEnd_Selected)
				delete menu;
		}
		case MenuAction_Cancel:
		{
			if (selection == MenuCancel_ExitBack)
				ShowCookieMenu(client);
		}
		case MenuAction_Select:
		{
			switch (selection)
			{
				case 0:
					ToggleZombieHitsound(client);
				case 1:
					ToggleBossHitsound(client);
				case 2:
					ToggleDetailedHitsound(client);
				case 3:
				{
					g_pData[client].fVolume = g_pData[client].fVolume - 0.1;
					if (g_pData[client].fVolume <= 0.0) g_pData[client].fVolume = 1.0;

					g_pData[client].volume = g_pData[client].volume - 10;
					if (g_pData[client].volume <= 0) g_pData[client].volume = 100;

					char buffer[8];
					Format(buffer, sizeof(buffer), "%.2f", g_pData[client].fVolume);
					g_cVolume.Set(client, buffer);

					CPrintToChat(client, "{green}[HitSound]{default} Hitsound volume has been changed to {green}%d", g_pData[client].volume);
				}
			}
			DisplayCookieMenu(client);
		}
	}
	return 0;
}

/* ---------------[ Event Hooks ]--------------- */
public void Hook_EntityOnDamage(const char[] output, int caller, int activator, float delay)
{
	if (!(1 <= activator <= MaxClients) || !IsClientInGame(activator))
		return;
	
	if (!g_pData[activator].enable || !g_pData[activator].boss)
		return;

	if (!IsPlayerAlive(activator) || GetClientTeam(activator) != CS_TEAM_CT)
		return;

	int tick = GetGameTickCount();
	if (tick == g_pData[activator].lastTick)
		return;

	if (g_pData[activator].fVolume != 0.0)
	{
		EmitSoundToClient(activator, g_sHitsoundPath, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_pData[activator].fVolume);
		g_pData[activator].lastTick = tick;
	}
}

public void Hook_EventOnDamage(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
	if (!(1 <= attacker <= MaxClients) || !IsClientInGame(attacker))
		return;

	if (!g_pData[attacker].enable || g_pData[attacker].fVolume == 0.0)
		return;

	if (!IsPlayerAlive(attacker) || GetClientTeam(attacker) != CS_TEAM_CT)
		return;

	int tick = GetGameTickCount();
	if (tick == g_pData[attacker].lastTick)
		return;

	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsClientInGame(victim) || victim == attacker)
		return;

	int hitgroup = GetEventInt(event, "hitgroup");
	int hp = GetEventInt(event, "health");

	if (g_pData[attacker].detailed)
	{
		if (hp == 0)
			EmitSoundToClient(attacker, g_sHitsoundKillPath, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_pData[attacker].fVolume);
		else if (hitgroup == 1)
			EmitSoundToClient(attacker, g_sHitsoundHeadPath, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_pData[attacker].fVolume);
		else
			EmitSoundToClient(attacker, g_sHitsoundBodyPath, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_pData[attacker].fVolume);
	}
	else
		EmitSoundToClient(attacker, g_sHitsoundPath, SOUND_FROM_PLAYER, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_pData[attacker].fVolume);

	g_pData[attacker].lastTick = tick;
}

/* ---------------[ Stock Functions ]--------------- */
stock void PrecacheSounds()
{
	char sBuffer[PLATFORM_MAX_PATH];

	// Boss Hitmarker Sound
	GetConVarString(g_cvHitsound, g_sHitsoundPath, sizeof(g_sHitsoundPath));
	PrecacheSound(g_sHitsoundPath, true);
	Format(sBuffer, sizeof(sBuffer), "sound/%s", g_sHitsoundPath);
	AddFileToDownloadsTable(sBuffer);

	// Body Shot Sound
	GetConVarString(g_cvHitsoundBody, g_sHitsoundHeadPath, sizeof(g_sHitsoundHeadPath));
	PrecacheSound(g_sHitsoundHeadPath, true);
	Format(sBuffer, sizeof(sBuffer), "sound/%s", g_sHitsoundHeadPath);
	AddFileToDownloadsTable(sBuffer);

	// Head Shot Sound
	GetConVarString(g_cvHitsoundHead, g_sHitsoundBodyPath, sizeof(g_sHitsoundBodyPath));
	PrecacheSound(g_sHitsoundBodyPath, true);
	Format(sBuffer, sizeof(sBuffer), "sound/%s", g_sHitsoundBodyPath);
	AddFileToDownloadsTable(sBuffer);

	// Kill Shot Sound
	GetConVarString(g_cvHitsoundKill, g_sHitsoundKillPath, sizeof(g_sHitsoundKillPath));
	PrecacheSound(g_sHitsoundKillPath, true);
	Format(sBuffer, sizeof(sBuffer), "sound/%s", g_sHitsoundKillPath);
	AddFileToDownloadsTable(sBuffer);
}
