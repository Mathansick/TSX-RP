/*
 * Cette oeuvre, création, site ou texte est sous licence Creative Commons Attribution
 * - Pas d’Utilisation Commerciale
 * - Partage dans les Mêmes Conditions 4.0 International. 
 * Pour accéder à une copie de cette licence, merci de vous rendre à l'adresse suivante
 * http://creativecommons.org/licenses/by-nc-sa/4.0/ .
 *
 * Merci de respecter le travail fourni par le ou les auteurs 
 * https://www.ts-x.eu/ - kossolax@ts-x.eu
 */
#pragma semicolon 1

#include <sourcemod>
#include <sdkhooks>
#include <colors_csgo>	// https://forums.alliedmods.net/showthread.php?p=2205447#post2205447
#include <smlib>		// https://github.com/bcserv/smlib

#define __LAST_REV__ 		"v:0.1.0"

#pragma newdecls required
#include <roleplay.inc>	// https://www.ts-x.eu

//#define DEBUG

public Plugin myinfo = {
	name = "Jobs: EPICIER", author = "KoSSoLaX",
	description = "RolePlay - Jobs: Epicier",
	version = __LAST_REV__, url = "https://www.ts-x.eu"
};

Handle g_hCigarette[65];
int g_cBeam;

// ----------------------------------------------------------------------------
public void OnPluginStart() {
	RegServerCmd("rp_item_cig", 		Cmd_ItemCigarette,		"RP-ITEM",	FCVAR_UNREGISTERED);	
	RegServerCmd("rp_item_sanandreas",	Cmd_ItemSanAndreas,		"RP-ITEM",	FCVAR_UNREGISTERED);
	RegServerCmd("rp_item_needforspeed",Cmd_ItemNeedForSpeed,	"RP-ITEM",	FCVAR_UNREGISTERED);
	RegServerCmd("rp_item_lessive",		Cmd_ItemLessive,		"RP-ITEM",	FCVAR_UNREGISTERED);
	RegServerCmd("rp_item_cafe",		Cmd_ItemCafe,			"RP-ITEM",	FCVAR_UNREGISTERED);
	RegServerCmd("rp_item_crayons",		Cmd_ItemCrayons,		"RP-ITEM",	FCVAR_UNREGISTERED);
	RegServerCmd("rp_item_map",			Cmd_ItemMaps,			"RP-ITEM",	FCVAR_UNREGISTERED);
	RegServerCmd("rp_item_ruban",		Cmd_ItemRuban,			"RP-ITEM",	FCVAR_UNREGISTERED);
	
	for (int i = 1; i <= MaxClients; i++)
		if( IsValidClient(i) )
			if( rp_GetClientBool(i, b_Crayon) )
				rp_HookEvent(i, RP_PrePlayerTalk, fwdTalkCrayon);
}
public void OnMapStart() {
	g_cBeam = PrecacheModel("materials/sprites/laserbeam.vmt", true);
}
public void OnClientDisconnect(int client) {
	if( rp_GetClientBool(client, b_Crayon) ) 
		rp_UnhookEvent(client, RP_PrePlayerTalk, fwdTalkCrayon);
	
}
// ----------------------------------------------------------------------------
public Action Cmd_ItemCigarette(int args) {
	#if defined DEBUG
	PrintToServer("Cmd_ItemCigarette");
	#endif
	
	char Arg1[32];
	GetCmdArg(1, Arg1, 31);
	int client = GetCmdArgInt(2);
	
	
	if( StrEqual(Arg1, "deg") ) {
		int item_id = GetCmdArgInt(args);
		if( rp_GetZoneBit( rp_GetPlayerZone(client) ) & BITZONE_PEACEFULL ) {
			ITEM_CANCEL(client, item_id);
			CPrintToChat(client, "{lightblue}[TSX-RP]{default} Cet objet est interdit où vous êtes.");
			return Plugin_Handled;
		}
		
		float origin[3];
		GetClientAbsOrigin(client, origin);
		origin[2] -= 1.0;
		rp_Effect_Push(origin, 500.0, 1000.0, client);
	}
	else if( StrEqual(Arg1, "flame") ) {
		UningiteEntity(client);
		for(float i=0.1; i<=30.0; i+= 0.50) {
			CreateTimer(i, Task_UningiteEntity, client);
		}
	}
	else if( StrEqual(Arg1, "light") ) {
		rp_HookEvent(client, RP_PrePlayerPhysic, fwdCigGravity, 30.0);
	}
	else if( StrEqual(Arg1, "choco") ) {
		// Ne fait absolument rien.
	}
	else { // WHAT IS THAT KIND OF SORCELERY?
		rp_HookEvent(client, RP_PrePlayerPhysic, fwdCigSpeed, 30.0);
	}
	
	rp_Effect_Smoke(client, 30.0);
	
	if( g_hCigarette[client] )
		delete g_hCigarette[client];
	
	g_hCigarette[client] = CreateTimer( 30.0, ItemStopCig, client);
	rp_SetClientBool(client, b_Smoking, true);
	
	return Plugin_Handled;
}
public Action Task_UningiteEntity(Handle timer, any client) {
	#if defined DEBUG
	PrintToServer("Task_UningiteEntity");
	#endif
	UningiteEntity(client);
}
public Action ItemStopCig(Handle timer, any client) {
	#if defined DEBUG
	PrintToServer("ItemStopCig");
	#endif
	
	rp_SetClientBool(client, b_Smoking, false);
}
public Action fwdCigSpeed(int client, float& speed, float& gravity) {
	#if defined DEBUG
	PrintToServer("fwdCigSpeed");
	#endif
	speed += 0.15;
	
	return Plugin_Changed;
}
public Action fwdCigGravity(int client, float& speed, float& gravity) {
	#if defined DEBUG
	PrintToServer("fwdCigGravity");
	#endif
	gravity -= 0.15;
	
	return Plugin_Changed;
}
// ----------------------------------------------------------------------------
public Action Cmd_ItemRuban(int args) {
	#if defined DEBUG
	PrintToServer("Cmd_ItemRuban");
	#endif

	int color[4];
	color[0] = GetCmdArgInt(1);
	color[1] = GetCmdArgInt(2);
	color[2] = GetCmdArgInt(3);
	color[3] = 200;
	
	int client = GetCmdArgInt(4);
	int target = GetClientAimTarget(client, false);

	int item_id = GetCmdArgInt(args);
	
	if( target == 0 || !IsValidEdict(target) || !IsValidEntity(target) ) {
		ITEM_CANCEL(client, item_id);
		return Plugin_Handled;
	}
	
	char classname[64];
	GetEdictClassname(target, classname, sizeof(classname));
	
	if( StrContains("chicken|player|weapon|prop_physics|", classname) == -1 ) {
		ITEM_CANCEL(client, item_id);
		return Plugin_Handled;
	}
	if( !rp_IsEntitiesNear(client, target) ) {
		ITEM_CANCEL(client, item_id);
		return Plugin_Handled;
	}
	
	TE_SetupBeamFollow(target, g_cBeam, 0, 180.0, 4.0, 0.1, 5, color);
	TE_SendToAll();
	
	return Plugin_Handled;
}
// ----------------------------------------------------------------------------
public Action Cmd_ItemSanAndreas(int args) {
	#if defined DEBUG
	PrintToServer("Cmd_ItemSanAndreas");
	#endif
	
	int client = GetCmdArgInt(1);
	int item_id = GetCmdArgInt(args);
	int wepid = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
	char classname[64];
	
	if( !IsValidEntity(wepid) ) {
		ITEM_CANCEL(client, item_id);
		return Plugin_Handled;
	}
	
	GetEdictClassname(wepid, classname, sizeof(classname));
		
	if( StrContains(classname, "weapon_bayonet") == 0 || StrContains(classname, "weapon_knife") == 0 ) {
		ITEM_CANCEL(client, item_id);
		return Plugin_Handled;
	}
		
	int ammo = Weapon_GetPrimaryClip(wepid);
	ammo += 1000; if( ammo > 5000 ) ammo = 5000;
	Weapon_SetPrimaryClip(wepid, ammo);
			
	CPrintToChat(client, "{lightblue}[TSX-RP]{default} Votre arme à maintenant %i balles", ammo);
	return Plugin_Handled;
}
public Action Cmd_ItemNeedForSpeed(int args) {
	#if defined DEBUG
	PrintToServer("Cmd_ItemNeedForSpeed");
	#endif
	
	int client = GetCmdArgInt(1);
	
	rp_HookEvent(client, RP_PrePlayerPhysic, fwdCigSpeed, 60.0);
	rp_HookEvent(client, RP_PrePlayerPhysic, fwdCigSpeed, 10.0);
	
}
public Action Cmd_ItemLessive(int args) {
	#if defined DEBUG
	PrintToServer("Cmd_ItemLessive");
	#endif
	
	int client = GetCmdArgInt(1);
	int item_id = GetCmdArgInt(args);
	
	if( rp_IsInPVP(client) ) {
		ITEM_CANCEL(client, item_id);
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Cet objet est interdit en PvP.");
		return Plugin_Handled;
	}
	
	SDKHooks_TakeDamage(client, client, client, 5000.0);
	ForcePlayerSuicide(client);
	
	rp_ClientRespawn(client);
	return Plugin_Handled;
}
public Action Cmd_ItemCafe(int args) {
	#if defined DEBUG
	PrintToServer("Cmd_ItemCafe");
	#endif
	
	int client = GetCmdArgInt(1);
	
	rp_HookEvent(client, RP_PrePlayerPhysic, fwdCigSpeed, 10.0);
	rp_HookEvent(client, RP_PrePlayerPhysic, fwdCigSpeed, 10.0);
	
	rp_IncrementSuccess(client, success_list_cafeine);
}
public Action Cmd_ItemCrayons(int args) {
	#if defined DEBUG
	PrintToServer("Cmd_ItemCrayons");
	#endif
	
	int client = GetCmdArgInt(1);
	int item_id = GetCmdArgInt(args);
	
	bool crayon = rp_GetClientBool(client, b_Crayon);
	
	if( crayon ) {
		ITEM_CANCEL(client, item_id);
		return Plugin_Handled;
	}
	
	rp_IncrementSuccess(client, success_list_rainbow);
	rp_HookEvent(client, RP_PrePlayerTalk, fwdTalkCrayon);	
	rp_SetClientBool(client, b_Crayon, true);
	return Plugin_Handled;
}
public Action fwdTalkCrayon(int client, char[] szSayText, int length) {
	
	char tmp[64];
	int hours, minutes;
	rp_GetTime(hours, minutes);
	
	IntToString( GetClientHealth(client), tmp, sizeof(tmp));
	ReplaceString(szSayText, length, "{hp}", tmp);
	
	IntToString( rp_GetClientInt(client, i_Kevlar), tmp, sizeof(tmp));
	ReplaceString(szSayText, length, "{ap}", tmp);
	
	IntToString( hours, tmp, sizeof(tmp));
	ReplaceString(szSayText, length, "{heure}", tmp);

	if(hours != 23)
		IntToString( hours+1, tmp, sizeof(tmp));
	else
		tmp="0";

	ReplaceString(szSayText, length, "{h+1}", tmp);

	IntToString( minutes, tmp, sizeof(tmp));
	ReplaceString(szSayText, length, "{minute}", tmp);
	
	rp_GetDate(tmp, length);
	ReplaceString(szSayText, length, "{date}", tmp);
	GetClientName(client, tmp, sizeof(tmp));							ReplaceString(szSayText, length, "{me}", tmp);
	
	int target = GetClientTarget(client);
	if( IsValidClient(target) ) {
		GetClientName(target, tmp, sizeof(tmp));
		ReplaceString(szSayText, length, "{target}", tmp);
	}
	else {
		ReplaceString(szSayText, length, "{target}", "Personne");
	}
	
	rp_GetZoneData(rp_GetPlayerZone( rp_IsValidDoor(target) ? target : client ), zone_type_name, tmp, sizeof(tmp));
	ReplaceString(szSayText, length, "{door}", tmp);
	
	rp_GetJobData(rp_GetClientInt(client, i_Job), job_type_name, tmp, sizeof(tmp));
	ReplaceString(szSayText, length, "{job}", tmp);
	
	rp_GetJobData(rp_GetClientInt(client, i_Group), job_type_name, tmp, sizeof(tmp));
	ReplaceString(szSayText, length, "{gang}", tmp);
	
	rp_GetZoneData(rp_GetPlayerZone( client ), zone_type_name, tmp, sizeof(tmp));
	ReplaceString(szSayText, length, "{zone}", tmp);
	
	
	ReplaceString(szSayText, length, "[TSX-RP]", "");	
	ReplaceString(szSayText, length, "{white}", "{default}");
	
	return Plugin_Changed;
}

public Action Cmd_ItemMaps(int args) {
	#if defined DEBUG
	PrintToServer("Cmd_ItemMaps");
	#endif
	
	int client = GetCmdArgInt(1);
	rp_SetClientBool(client, b_Map, true);
}
// ----------------------------------------------------------------------------
void UningiteEntity(int entity) {
	
	int ent = GetEntPropEnt(entity, Prop_Data, "m_hEffectEntity");
	if( IsValidEdict(ent) )
		SetEntPropFloat(ent, Prop_Data, "m_flLifetime", 0.0); 
}

public Action Cmd_ItemPilule(int args){
	#if defined DEBUG
	PrintToServer("Cmd_ItemPilule");
	#endif

	int type = GetCmdArgInt(1);	// 1 Pour Appart, 2 pour planque
	int client = GetCmdArgInt(2);
	int item_id = GetCmdArgInt(args);
	int tptozone = -1;

	if( !rp_GetClientBool(client, b_MaySteal) ) {
		ITEM_CANCEL(client, item_id);
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous ne pouvez pas utiliser cet item pour le moment.");
		return Plugin_Handled;
	}

	if(type == 1){ // Appart
		int appartcount = rp_GetClientInt(client, i_AppartCount);
		if(appartcount == 0){
			ITEM_CANCEL(client, item_id);
			CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous ne pouvez pas vous téléporter à votre appartement si vous n'en avez pas.");
			return Plugin_Handled;
		}
		else{
			for (int i = 1; i <= 48; i++) {
				if( rp_GetClientKeyAppartement(client, i) ) {
					tptozone = appartToZoneID(i);
				}
			}
		}
	}
	else if (type == 2){ // Planque
		if(rp_GetClientJobID(client)==0){
			ITEM_CANCEL(client, item_id);
			CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous ne pouvez pas vous teleporter à votre planque puisque vous êtes sans-emploi.");
			return Plugin_Handled;
		}
		for(int i=1; i<300;i++){
			if(rp_GetZoneInt(i, zone_type_type) == rp_GetClientJobID(client)){
				tptozone = i;
				continue;
			}
		}
	}

	if(tptozone == -1){
			ITEM_CANCEL(client, item_id);
			CPrintToChat(client, "{lightblue}[TSX-RP]{default} Nous n'avons pas trouvé d'endroit où vous teleporter.");
			return Plugin_Handled;
	}

	rp_ClientReveal(client);
	ServerCommand("sm_effect_panel %d 5.0 \"Téléportation en cours...\"", client);
	rp_HookEvent(client, RP_PrePlayerPhysic, fwdFrozen, 5.0);
	rp_ClientColorize(client, { 238, 148, 52, 255} );


	rp_SetClientBool(client, b_MaySteal, false);
	CreateTimer(35.0, AllowStealing, client);

	Handle dp;
	CreateDataTimer(4.80, ItemPiluleOver, dp, TIMER_DATA_HNDL_CLOSE);
	WritePackCell(dp, client);
	WritePackCell(dp, item_id);
	WritePackCell(dp, tptozone);
	return Plugin_Handled;
}

public Action ItemPiluleOver(Handle timer, Handle dp) {
	ResetPack(dp);
	int client = ReadPackCell(dp);
	int item_id = ReadPackCell(dp);
	int tptozone = ReadPackCell(dp);
	int clientzone = rp_GetPlayerZone(client);
	int clientzonebit = rp_GetZoneBit(clientzone);

	if(!IsValidClient(client) || !IsPlayerAlive(client) || ( clientzonebit & BITZONE_JAIL ||  clientzonebit & BITZONE_LACOURS ||  clientzonebit & BITZONE_HAUTESECU ) ){
		if(IsValidClient(client))
			rp_ClientColorize(client, { 255, 255, 255, 255} );
		return Plugin_Handled;
	}
	float zonemin[3];
	float zonemax[3];
	float tppos[3];
	char tmp[64];

	rp_GetZoneData(tptozone, zone_type_min_x, tmp, 63);
	zonemin[0] = StringToFloat(tmp);
	rp_GetZoneData(tptozone, zone_type_min_y, tmp, 63);
	zonemin[1] = StringToFloat(tmp);
	rp_GetZoneData(tptozone, zone_type_min_z, tmp, 63);
	zonemin[2] = StringToFloat(tmp)+5.0;

	rp_GetZoneData(tptozone, zone_type_max_x, tmp, 63);
	zonemax[0] = StringToFloat(tmp);
	rp_GetZoneData(tptozone, zone_type_max_y, tmp, 63);
	zonemax[1] = StringToFloat(tmp);
	rp_GetZoneData(tptozone, zone_type_max_z, tmp, 63);
	zonemax[2] = StringToFloat(tmp)-80.0;

	for(int i=0; i<30; i++){
		tppos[0]=Math_GetRandomFloat(zonemin[0],zonemax[0]);
		tppos[1]=Math_GetRandomFloat(zonemin[1],zonemax[1]);
		tppos[2]=Math_GetRandomFloat(zonemin[2],zonemax[2]);
		if(CanTP(tppos, client)){
			rp_ClientColorize(client, { 255, 255, 255, 255} );
			TeleportEntity(client, tppos, NULL_VECTOR, NULL_VECTOR);
			return Plugin_Handled;
		}
	}
	ITEM_CANCEL(client, item_id);
	CPrintToChat(client, "{lightblue}[TSX-RP]{default} Nous n'avons pas trouvé d'endroit où vous teleporter.");
	return Plugin_Handled;
}

public Action AllowStealing(Handle timer, any client) {
	#if defined DEBUG
	PrintToServer("AllowStealing");
	#endif

	rp_SetClientBool(client, b_MaySteal, true);
}

public Action fwdFrozen(int client, float& speed, float& gravity) {
	speed = 0.0;
	gravity = 0.0;
	return Plugin_Stop;
}

int appartToZoneID(int appartid){
	char appart[32];
	char tmp[32];
	Format(appart, 31, "appart_%d",appartid);
	for(int i=1;i<300;i++){
		rp_GetZoneData(i, zone_type_type, tmp, sizeof(tmp));
		if(StrEqual(tmp,appart,false)){
			return i;
		}
	}
	return -1;
}


bool CanTP(float pos[3], int client)
{
    float mins[3];
    float maxs[3];
    bool ret;

    GetClientMins(client, mins);
    GetClientMaxs(client, maxs);
    Handle tr;
    tr = TR_TraceHullEx(pos, pos, mins, maxs, MASK_SOLID);
    ret = TR_DidHit(tr);
    CloseHandle(tr);
    return ret;
}