#pragma semicolon 1

#define DEBUG

#define PLUGIN_AUTHOR ""
#define PLUGIN_VERSION "0.00"

#include <sourcemod>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>
#include <sdkhooks>

public Plugin myinfo = 
{
	name = "", 
	author = PLUGIN_AUTHOR, 
	description = "", 
	version = PLUGIN_VERSION, 
	url = ""
};

bool g_eReleaseFreeze[2048 + 1] =  { true, ... };
int g_bCount[2048 + 1] =  { 0, ... };
int g_offsCollisionGroup;
bool IsPropBeingHeld[2048 + 1] =  { false, ... };
int g_iHoldingClient[MAXPLAYERS + 1]; //The player who is holding the prop.
bool g_bIsClientHoldingProp[MAXPLAYERS + 1];



public void OnPluginStart()
{
	g_offsCollisionGroup = FindSendPropInfo("CBaseEntity", "m_CollisionGroup");
	HookEvent("teamplay_round_start", OnRound);
}
public void OnMapStart() {
	PrecacheModel("models/crossbow_bolt.mdl", true);
	PrecacheSound("weapons/crowbar/crowbar_impact1.wav", true);
	for (new i = 1; i <= 2048; i++) {
		g_eReleaseFreeze[i] = true;
		g_bCount[i] = 0;
	}
}
public Action OnRound(Handle event, const String:name[], bool dontBroadcast) {
	for (new i = 0; i <= 2048; i++) {
		g_eReleaseFreeze[i] = true;
		g_bCount[i] = 0;
	}
}
public Action OnPlayerRunCmd(client, &buttons) {
	if ((buttons & IN_ATTACK2)) {
		int TracedEntity = TraceRayToEntity(client, 80.0);
		if (TracedEntity != -1) {
			float vec[3];
			GetClientEyeAngles(client, vec);
			if (vec[0] > 46.0) {
				EntityNailAttachTo(client, TracedEntity);
				UpgradeStatusOfProp(TracedEntity);
			}
		}
	}
	if ((buttons & IN_RELOAD)) {
		//TraceRayToEntityToConfirmNail(client, 90.0);
		//float vec[3];
		//GetClientEyeAngles(client, vec);
		//PrintHintText(client, "X:%f, Y:%f, Z:%f", vec[0], vec[1], vec[2]);
		int TracedEntity = TraceRayToEntity(client, 100.0);
		if (TracedEntity != -1) {
			if (IsPlayerStuckInEnt(client, TracedEntity) && GetClientTeam(client) == 3) {
				SetEntData(client, g_offsCollisionGroup, 2, 4, true);
				
			} else if (!IsPlayerStuckInEnt(client, TracedEntity) && GetClientTeam(client) == 3) {
				SetEntData(client, g_offsCollisionGroup, 3, 4, true);
			}
		}
	}
}

//This for physical entities
stock TraceRayToEntity(int iClient, float Distance) {
	float vecEyeAngle[3];
	float vecEyePos[3];
	
	GetClientEyePosition(iClient, vecEyePos); //Eyes
	GetClientEyeAngles(iClient, vecEyeAngle); //Where the client is looking at
	vecEyePos[2] += 10;
	TR_TraceRayFilter(vecEyePos, vecEyeAngle, MASK_SOLID, RayType_Infinite, TraceRayHitSelf, iClient);
	
	if (TR_DidHit(INVALID_HANDLE)) {
		float EndPos[3];
		vecEyePos[2] -= 10;
		char surfaceName[128];
		int iEnt = TR_GetEntityIndex(INVALID_HANDLE);
		TR_GetEndPosition(EndPos, INVALID_HANDLE);
		TR_GetSurfaceName(null, surfaceName, sizeof(surfaceName));
		float flDistance = GetVectorDistance(vecEyePos, EndPos);
		//GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", EndPos);
		if (flDistance < Distance) {
			//PrintHintText(iClient, "Prop:%d, Distance:%f", iEnt, flDistance);
			return iEnt;
		}
		return -1;
	}
	return -1;
	
}
//This for walls
stock TraceRayToEntityToConfirmNail(int iClient, float Distance) {
	float vecEyeAngle[3];
	float vecEyePos[3];
	
	//-2 means it's not a floor. Or the distance is far away than the initial distance limit
	//-1 means it's floor or wall. 
	GetClientEyePosition(iClient, vecEyePos); //Eyes
	GetClientEyeAngles(iClient, vecEyeAngle); //Where the client is looking at
	vecEyePos[2] += 10;
	TR_TraceRayFilter(vecEyePos, vecEyeAngle, MASK_SOLID, RayType_Infinite, TraceRayHitSelf, iClient);
	if (TR_DidHit(INVALID_HANDLE)) {
		float EndPos[3];
		vecEyePos[2] -= 10;
		char surfaceName[128];
		int iEnt = TR_GetEntityIndex(INVALID_HANDLE);
		TR_GetEndPosition(EndPos, INVALID_HANDLE);
		TR_GetSurfaceName(null, surfaceName, sizeof(surfaceName));
		PrintHintText(iClient, "%s", surfaceName);
		float flDistance = GetVectorDistance(vecEyePos, EndPos);
		//GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", EndPos);
		if (StrContains(surfaceName, "floor", false) != -1 && flDistance < Distance) {
			PrintToChat(iClient, "Distance:%f", flDistance);
			return -1;
		}
		return -2;
	}
	return -2;
}

public bool TraceRayHitSelf(entity, mask, any:data) {
	return (entity != data);
}

stock int EntityNailAttachTo(int client, int iEnt) {
	g_bCount[iEnt]++;
	char oldEntName[64];
	char classNameCheck[64];
	GetEntityClassname(iEnt, classNameCheck, sizeof(classNameCheck));
	if (StrContains(classNameCheck, "physics", false) != -1) {
		PrintHintText(client, "Succesfully nailed classname :%s", classNameCheck);
		GetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName, sizeof(oldEntName));
		float end[3];
		float start[3];
		float angle[3];
		
		GetClientEyePosition(client, start);
		GetClientEyeAngles(client, angle);
		TR_TraceRayFilter(start, angle, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayer, client);
		if (TR_DidHit(INVALID_HANDLE))
		{
			TR_GetEndPosition(end, INVALID_HANDLE);
		}
		char strName[126], strClass[64];
		GetEntityClassname(iEnt, strClass, sizeof(strClass));
		Format(strName, sizeof(strName), "%s%i", strClass, iEnt);
		DispatchKeyValue(iEnt, "targetname", strName);
		if (g_bCount[iEnt] < 2) {
			int ent = CreateEntityByName("prop_dynamic_override");
			DispatchKeyValue(ent, "model", "models/crossbow_bolt.mdl");
			DispatchKeyValue(ent, "target", strName);
			DispatchKeyValue(ent, "Mode", "0");
			DispatchSpawn(ent);
			
			SetEntProp(ent, Prop_Data, "m_iHealth", 100);
			SetEntProp(ent, Prop_Data, "m_takedamage", 2);
			
			TeleportEntity(ent, end, angle, NULL_VECTOR);
			TF2_CreateGlow(ent);
			SetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName);
			g_eReleaseFreeze[iEnt] = false; //Cuz it's nailed
			EmitSoundToAll("weapons/crowbar/crowbar_impact1.wav", client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, 100, client, end, NULL_VECTOR, true, 0.0);
		}
	} else {
		PrintHintText(client, "Failed at nailing classname:%s", classNameCheck);
	}
}

stock GrabProp(int iClient, int iEnt) {
	
}
stock int TF2_CreateGlow(int iEnt)
{
	char oldEntName[64];
	GetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName, sizeof(oldEntName));
	
	char strName[126], strClass[64];
	GetEntityClassname(iEnt, strClass, sizeof(strClass));
	Format(strName, sizeof(strName), "%s%i", strClass, iEnt);
	DispatchKeyValue(iEnt, "targetname", strName);
	
	int ent = CreateEntityByName("tf_glow");
	DispatchKeyValue(ent, "targetname", "RainbowGlow");
	DispatchKeyValue(ent, "target", strName);
	DispatchKeyValue(ent, "Mode", "0");
	DispatchSpawn(ent);
	
	int color[4];
	color[0] = 0;
	color[1] = 255;
	color[2] = 0;
	color[3] = 255;
	
	SetVariantColor(color);
	AcceptEntityInput(ent, "SetGlowColor");
	
	AcceptEntityInput(ent, "Enable");
	
	SetEntPropString(iEnt, Prop_Data, "m_iName", oldEntName);
	
	return ent;
}

UpgradeStatusOfProp(iEntity) {
	if (iEntity != -1) {
		if (!g_eReleaseFreeze[iEntity]) {
			SetEntityMoveType(iEntity, MOVETYPE_NONE);
			SetEntProp(iEntity, Prop_Data, "m_iHealth", 100);
			SetEntProp(iEntity, Prop_Data, "m_takedamage", 2);
			//HookSingleEntityOutput(iEntity, "OnBreak", propBreak, true);
			SDKHook(iEntity, SDKHook_OnTakeDamage, OnTakeDamage);
		}
	}
}
public Action OnTakeDamage(victim, &attacker, &inflictor, &Float:damage, &damagetype)
{
	int iHealth = GetEntProp(victim, Prop_Data, "m_iHealth");
	if (iHealth < 10) {
		PrintToChatAll("Low than 10!");
	}
}
public void propBreak(const char[] output, int caller, int activator, float delay)
{
	PrintToChatAll("Prop destroyed!");
	UnhookSingleEntityOutput(caller, "OnBreak", propBreak);
	RemoveRemainNails(caller);
}


public bool TraceEntityFilterPlayer(entity, contentsMask, any:data)
{
	return entity > MaxClients;
}

//Stuck and phasing here.
stock bool IsPlayerStuckInEnt(int client, int ent)
{
	float vecMin[3], vecMax[3], vecOrigin[3];
	
	GetClientMins(client, vecMin);
	GetClientMaxs(client, vecMax);
	
	GetClientEyeAngles(client, vecOrigin);
	
	TR_TraceHullFilter(vecOrigin, vecOrigin, vecMin, vecMax, MASK_ALL, TraceRayHitOnlyEnt, ent);
	return TR_DidHit();
}

public bool TraceRayHitOnlyEnt(int entity, int contentsMask, any data)
{
	return entity == data;
}

stock RemoveRemainNails(int iEnt) {
	char m_ModelName[PLATFORM_MAX_PATH];
	GetEntPropString(iEnt, Prop_Data, "m_ModelName", m_ModelName, sizeof(m_ModelName));
	int index = -1;
	while ((index = FindEntityByClassname(index, "prop_dynamic_override")) != -1) {
		PrintToChatAll("Nail spotted!");
		if (GetEntPropEnt(index, Prop_Send, "m_hTarget") == iEnt && StrContains(m_ModelName, "bolt", false) != -1) {
			AcceptEntityInput(index, "Kill");
			PrintToChatAll("Nail removed!");
		}
	}
} 