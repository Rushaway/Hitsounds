#if defined _hitsounds_included
	#endinput
#endif
#define _hitsounds_included

enum SoundType
{
	Sound_Boss,
	Sound_Zombie,
	Sound_Detailed,
}

native bool GetHitsoundStatus(int client, SoundType type);
native float GetHitsoundVolume(int client);

native void ToggleHitsound(int client, SoundType type);
native void SetHitsoundVolume(int client, float volume);

native void OpenHitsoundMenu(int client);

public SharedPlugin __pl_hitsounds = 
{
	name = "hitsounds",
	file = "hitsounds.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_hitsounds_SetNTVOptional()
{
	MarkNativeAsOptional("GetHitsoundStatus");
	MarkNativeAsOptional("GetHitsoundVolume");
	MarkNativeAsOptional("ToggleHitsound");
	MarkNativeAsOptional("SetHitsoundVolume");
	MarkNativeAsOptional("OpenHitsoundMenu");
}
#endif