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
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <colors_csgo>	// https://forums.alliedmods.net/showthread.php?p=2205447#post2205447
#include <smlib>		// https://github.com/bcserv/smlib
#include <emitsoundany> // https://forums.alliedmods.net/showthread.php?t=237045

#define __LAST_REV__ 		"v:0.1.0"

#pragma newdecls required
#include <roleplay.inc>	// https://www.ts-x.eu

//#define DEBUG
#define MAX_AREA_DIST 		500
#define STEAL_TIME			30.0
#define ITEM_PIEDBICHE		1
#define ITEM_KITCROCHTAGE	2
#define ITEM_KITEXPLOSIF	3

// TODO: Repensé le /vol pour fusionner doublon.

public Plugin myinfo = {
	name = "Jobs: Mafia", author = "KoSSoLaX",
	description = "RolePlay - Jobs: Mafia",
	version = __LAST_REV__, url = "https://www.ts-x.eu"
};

int g_iDoorDefine_LOCKER[2049];
Handle g_hForward_RP_OnClientStealItem;
int g_cBeam;
bool doRP_CanClientStealItem(int client, int target) {
	Action a;
	Call_StartForward(g_hForward_RP_OnClientStealItem);
	Call_PushCell(client);
	Call_PushCell(target);
	Call_Finish(a);
	if( a == Plugin_Handled || a == Plugin_Stop )
		return false;
	return true;
}
// ----------------------------------------------------------------------------
public Action Cmd_Reload(int args) {
	char name[64];
	GetPluginFilename(INVALID_HANDLE, name, sizeof(name));
	ServerCommand("sm plugins reload %s", name);
	return Plugin_Continue;
}
public void OnPluginStart() {
	RegServerCmd("rp_quest_reload", Cmd_Reload);
	RegServerCmd("rp_item_piedbiche", 	Cmd_ItemPiedBiche,		"RP-ITEM",	FCVAR_UNREGISTERED);	
	RegServerCmd("rp_item_picklock", 	Cmd_ItemPickLock,		"RP-ITEM",	FCVAR_UNREGISTERED); 
	RegServerCmd("rp_item_picklock2", 	Cmd_ItemPickLock,		"RP-ITEM",	FCVAR_UNREGISTERED);	
	// Epicier
	RegServerCmd("rp_item_doorDefine",	Cmd_ItemDoorDefine,		"RP-ITEM",	FCVAR_UNREGISTERED);
	
	g_hForward_RP_OnClientStealItem = CreateGlobalForward("RP_CanClientStealItem", ET_Event, Param_Cell, Param_Cell);
	
	for (int i = 1; i <= MaxClients; i++)
		if( IsValidClient(i) )
			OnClientPostAdminCheck(i);
}
public void OnMapStart() {
	g_cBeam = PrecacheModel("materials/sprites/laserbeam.vmt", true);
}
public void OnClientPostAdminCheck(int client) {
	rp_HookEvent(client, RP_OnPlayerUse,	fwdOnPlayerUse);
	rp_HookEvent(client, RP_OnPlayerSteal,	fwdOnPlayerSteal);
	rp_HookEvent(client, RP_OnPlayerBuild,	fwdOnPlayerBuild);
	rp_SetClientBool(client, b_MaySteal, true);
}
public void OnClientDisconnect(int client) {
	for(int i=0; i<2049; i++){
		if(g_iDoorDefine_LOCKER[i] == client)
			g_iDoorDefine_LOCKER[i] = 0;
	}
}
public Action fwdOnPlayerBuild(int client, float& cooldown){
	if( rp_GetClientJobID(client) != 91 )
		return Plugin_Continue;
	
	if( disapear(client) ) {
		cooldown = 60.0;
	}
	else {
		cooldown = 0.1;
	}
	return Plugin_Stop;
}
public Action fwdOnPlayerSteal(int client, int target, float& cooldown) {
	if( rp_GetClientJobID(client) != 91 )
		return Plugin_Continue;
	static int RandomItem[MAX_ITEMS];
	static char tmp[128], szQuery[1024];
	
	if( rp_GetClientJobID(target) == 91 ) {
		ACCESS_DENIED(client);
	}
	if( rp_GetZoneBit( rp_GetPlayerZone(target) ) & BITZONE_BLOCKSTEAL ) {
		ACCESS_DENIED(client);
	}
	
	if( rp_ClientFloodTriggered(client, target, fd_vol) ) {
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous ne pouvez pas voler %N, pour le moment.", target);
		return Plugin_Handled;
	}
	
	int VOL_MAX, amount, money, job, prix;
	money = rp_GetClientInt(target, i_Money);
	VOL_MAX = (money+rp_GetClientInt(target, i_Bank)) / 200;
	
	if( rp_IsClientNew(target) )
		amount = Math_GetRandomPow(1, VOL_MAX);
	else
		amount = Math_GetRandomInt(1, VOL_MAX);
	
	if( VOL_MAX > 0 && money <= 0 && rp_GetClientInt(client, i_Job) <= 93 && !rp_IsClientNew(target) && doRP_CanClientStealItem(client, target) ) {
		amount = 0;
		
		for(int i = 0; i < MAX_ITEMS; i++) {
			
			if( rp_GetClientItem(target, i) <= 0 )
				continue;
				
			job = rp_GetItemInt(i, item_type_job_id);
			if( job == 0|| job == 91 || job == 101 || job == 181 )
				continue;
			if( job == 51 && !(rp_GetClientItem(target, i) >= 1 && Math_GetRandomInt(0, 1) == 1) ) // TODO: Double vérif voiture
				continue;
			
			RandomItem[amount++] = i;
		}
		
		if( amount == 0  ) {
			CPrintToChat(client, "{lightblue}[TSX-RP]{default} %N n'a pas d'argent, ni d'item sur lui.", target);
			cooldown = 1.0;
			return Plugin_Stop;
		}
		
		int i = RandomItem[ Math_GetRandomInt(0, (amount-1)) ];
		prix = rp_GetItemInt(i, item_type_prix) / 2;
		
		rp_ClientGiveItem(target, i, -1);
		rp_ClientGiveItem(client, i, 1);
		
		rp_SetClientInt(client, i_LastVolTime, GetTime());
		rp_SetClientInt(client, i_LastVolAmount, prix);
		rp_SetClientInt(client, i_LastVolTarget, target);
		rp_SetClientInt(target, i_LastVol, client);		
		rp_SetClientFloat(target, fl_LastVente, GetGameTime() + 10.0);
		
		rp_GetItemData(i, item_type_name, tmp, sizeof(tmp));
		
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous avez volé %s à %N.", tmp, target);
		CPrintToChat(target, "{lightblue}[TSX-RP]{default} Quelqu'un vous a volé: %s.", tmp);
					
		LogToGame("[TSX-RP] [VOL] %L a vole %L 1 %s", client, target, tmp);
		
		GetClientAuthId(client, AuthId_Engine, tmp, sizeof(tmp), false);
		Format(szQuery, sizeof(szQuery), "INSERT INTO `rp_sell` (`id`, `steamid`, `job_id`, `timestamp`, `item_type`, `item_id`, `item_name`, `amount`) VALUES (NULL, '%s', '%i', '%i', '2', '%i', '%s', '%i');",
			tmp, rp_GetClientJobID(client), GetTime(), i, "Vol: Objet", amount);

		SQL_TQuery( rp_GetDatabase(), SQL_QueryCallBack, szQuery);
		
		int alpha[4];
		alpha[1] = 255;
		alpha[3] = 50;
		
		if( rp_IsNight() ) {
			cooldown *= 1.5;
			alpha[3] = 25;
		}
		else {
			cooldown *= 2.0;
		}
		
		if( amount < 50 )
			cooldown *= 0.5;
		if( amount < 5 )
			cooldown *= 0.5;
		
		rp_ClientFloodIncrement(client, target, fd_vol, cooldown);
		
		float vecTarget[3];
		GetClientAbsOrigin(client, vecTarget);

		ServerCommand("sm_effect_particles %d Aura2 3", client);
		
		//g_iSuccess_last_pas_vu_pas_pris[target] = GetTime();

		int cpt = rp_GetRandomCapital(91);
		rp_SetJobCapital(91, rp_GetJobCapital(91) + prix);
		rp_SetJobCapital(cpt, rp_GetJobCapital(cpt) - prix);
		
	}
	else if( VOL_MAX > 0 && money >= 1 ) {
		if( amount > money )
			amount = money;
			
		rp_SetClientStat(target, i_MoneySpent_Stolen, rp_GetClientStat(target, i_MoneySpent_Stolen) + amount);
		rp_SetClientInt(client, i_AddToPay, rp_GetClientInt(client, i_AddToPay) + amount);
		rp_SetClientInt(target, i_Money, rp_GetClientInt(target, i_Money) - amount);
		rp_SetClientInt(client, i_LastVolTime, GetTime());
		rp_SetClientInt(client, i_LastVolAmount, amount);
		rp_SetClientInt(client, i_LastVolTarget, target);
		rp_SetClientInt(target, i_LastVol, client);
		
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous avez volé %d$ à %N.", amount, target);
		CPrintToChat(target, "{lightblue}[TSX-RP]{default} Quelqu'un vous a volé %d$.", amount);

		//g_iSuccess_last_mafia[client][1] = GetTime();
		//g_iSuccess_last_pas_vu_pas_pris[target] = GetTime();
		LogToGame("[TSX-RP] [VOL] %L a vole %L %i$", client, target, amount);
		
		GetClientAuthId(client, AuthId_Engine, tmp, sizeof(tmp), false);
		Format(szQuery, sizeof(szQuery), "INSERT INTO `rp_sell` (`id`, `steamid`, `job_id`, `timestamp`, `item_type`, `item_id`, `item_name`, `amount`) VALUES (NULL, '%s', '%i', '%i', '4', '%i', '%s', '%i');",
			tmp, rp_GetClientJobID(client), GetTime(), 0, "Vol: Argent", amount);
		SQL_TQuery(rp_GetDatabase(), SQL_QueryCallBack, szQuery);
		
		if( rp_IsNight() )
			cooldown *= 0.5;
		
		if( amount < 50 )
			cooldown *= 0.5;
		if( amount < 5 )
			cooldown *= 0.5;
			
		if( amount > 500 )
			rp_SetClientFloat(client, fl_LastVente, GetGameTime() + 10.0);
		if( amount > 2000 )
			rp_SetClientFloat(client, fl_LastVente, GetGameTime() + 30.0);
		
		rp_ClientFloodIncrement(client, target, fd_vol, cooldown);
		
		ServerCommand("sm_effect_particles %d Aura2 2", client);
		
		int cpt = rp_GetRandomCapital(91);
		rp_SetJobCapital(91, rp_GetJobCapital(91) + (amount/4));
		rp_SetJobCapital(cpt, rp_GetJobCapital(cpt) - (amount/4));
	}
	else {
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} %N n'a pas d'argent sur lui.", target);
		cooldown = 1.0;
	}
	
	return Plugin_Stop;
}

public Action fwdOnPlayerUse(int client) {
	#if defined DEBUG
	PrintToServer("fwdOnPlayerUse");
	#endif
	static char tmp[128];
	
	if( rp_GetClientJobID(client) == 91 && rp_GetZoneInt(rp_GetPlayerZone(client), zone_type_type) == 91 ) {
		bool changed = false;
		
		for(int itemID=1; itemID<=3; itemID++) {
		
			int mnt = rp_GetClientItem(client, itemID);
			int max = GetMaxKit(client, itemID);
			if( mnt <  max ) {
				rp_ClientGiveItem(client, itemID, max - mnt);
				rp_GetItemData(itemID, item_type_name, tmp, sizeof(tmp));
				CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous avez récupéré %i %s.", max - mnt, tmp);
				
				changed = true;
			}
			
		}
		
		if(changed == true) {
			FakeClientCommand(client, "say /item");
		}
		
	}
}
// ----------------------------------------------------------------------------
public Action Cmd_ItemDoorDefine(int args) {
	#if defined DEBUG
	PrintToServer("Cmd_ItemDoorDefine");
	#endif
	char Arg1[12];	GetCmdArg(1, Arg1, 11);	
	int client = GetCmdArgInt(2);
	int item_id = GetCmdArgInt(args);
	
	int door = getDoor(client);
	
	if( door == 0 ) {
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous devez viser une porte.");
		ITEM_CANCEL(client, item_id);
		return Plugin_Handled;
	}
	
	int doorID = rp_GetDoorID(door);
	if(g_iDoorDefine_LOCKER[doorID] != 0 ) {
			CPrintToChat(client, "{lightblue}[TSX-RP]{default} Un cadenas est déja présent sur cette porte.");
			ITEM_CANCEL(client, item_id);
			return Plugin_Handled;
		}
	g_iDoorDefine_LOCKER[doorID] = client;
	CPrintToChat(client, "{lightblue}[TSX-RP]{default} Le cadenas a été placé avec succès.");
	
	return Plugin_Handled;
}
public Action Cmd_ItemPiedBiche(int args) {
	#if defined DEBUG
	PrintToServer("Cmd_ItemPiedBiche");
	#endif
	
	int client = GetCmdArgInt(1);
	int item_id = GetCmdArgInt(args);
	
	if( rp_GetClientJobID(client) != 91 ) {
		return Plugin_Continue;
	}
	
	if( rp_GetClientBool(client, b_MaySteal) == false ) {
		ITEM_CANCEL(client, item_id);
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous ne pouvez pas voler pour le moment.");
		return Plugin_Handled;
	}
	
	int type;
	int target = getDistrib(client, type);
	if( target <= 0 ) {
		ITEM_CANCEL(client, item_id);
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous devez viser un distributeur, un téléphone, ou une imprimante.");
		return Plugin_Handled;
	}
	
	float start = 0.0;
	
	if( type == 3 || type == 4  )
		start = Math_GetRandomFloat(0.5, 0.66);
		
	
	rp_SetClientStat(client, i_JobFails, rp_GetClientStat(client, i_JobFails) + 1);

	rp_ClientGiveItem(client, item_id, -rp_GetClientItem(client, item_id));
	rp_SetClientBool(client, b_MaySteal, false);
	rp_SetClientInt(client, i_LastVolTime, GetTime());
	rp_SetClientInt(client, i_LastVolAmount, 100);
	rp_SetClientInt(client, i_LastVolTarget, -1);	
	rp_ClientReveal(client);
	
	char classname[64];
	GetEdictClassname(target, classname, sizeof(classname));
	
	ServerCommand("sm_effect_particles %d weapon_sensorgren_detonate 1 facemask", client);
	ServerCommand("sm_effect_particles %d Trail2 2 legacy_weapon_bone", client);
	
	Handle dp;
	CreateDataTimer(0.1, ItemPiedBiche_frame, dp, TIMER_DATA_HNDL_CLOSE|TIMER_REPEAT);
	WritePackCell(dp, client);
	WritePackCell(dp, target);
	WritePackCell(dp, start);
	WritePackCell(dp, type);
	
	return Plugin_Handled;
}
public Action ItemPiedBiche_frame(Handle timer, Handle dp) {
	ResetPack(dp);
	int client = ReadPackCell(dp);
	int target = ReadPackCell(dp);
	float percent = ReadPackCell(dp);
	int type = ReadPackCell(dp);
	int type2;
	
	
	if( !IsValidClient(client ) ) {
		return Plugin_Stop;
	}
	if( getDistrib(client, type2) != target ) {
		MENU_ShowPickLock(client, percent, -1, type);
		rp_ClientColorize(client);
		CreateTimer(0.1, AllowStealing, client);
		rp_ClientGiveItem(client, ITEM_PIEDBICHE, 1);
		return Plugin_Stop;
	}
	if( percent >= 1.0 ) {
		rp_ClientColorize(client);
		
		rp_SetClientStat(client, i_JobSucess, rp_GetClientStat(client, i_JobSucess) + 1);
		rp_SetClientStat(client, i_JobFails, rp_GetClientStat(client, i_JobFails) - 1);
		
		float time = (rp_IsNight() ? STEAL_TIME:STEAL_TIME*2.0);
		int stealAMount;
		
		switch(type) {
			case 2: { // Banque
				time *= 2.0;
				int count = countPolice(client), rand = 4 + Math_GetRandomPow(0, 4), i;
				
				for (i = 0; i < count; i++)
					rand += (4 + Math_GetRandomPow(0, 12));
				for (i = 0; i < rand; i++)
					CreateTimer(i / 5.0, SpawnMoney, EntIndexToEntRef(target));
				
				CPrintToChat(client, "{lightblue}[TSX-RP]{default} %d billets ont été sorti du distributeur.", rand);
				stealAMount = 25*rand;
			}
			case 3: { // Armu
				time /= 2.0;
				rp_ClientDrawWeaponMenu(client, target, true);
				stealAMount = 100; 
				
			}
			case 4: { // Imprimante
				time /= 4.0;
				CreateTimer(0.1, SpawnMoney, EntIndexToEntRef(target));
				stealAMount = 25;
				rp_ClientDamage(target, 25, client);
				
				int owner = rp_GetBuildingData(target, BD_owner);
				if( IsValidClient(owner) ) {
					rp_SetClientInt(owner, i_Bank, rp_GetClientInt(owner, i_Bank) - 25);
					CPrintToChat(owner, "{lightblue}[TSX-RP]{default} Quelqu'un vol vos faux billets.");
				}
			}
			case 5: { // Photocopieuse
				time *= 4.0;
				
				for (int i = 0; i < 15; i++)
					CreateTimer(i / 5.0, SpawnMoney, EntIndexToEntRef(target));
				
				int owner = rp_GetBuildingData(target, BD_owner);
				if( IsValidClient(owner) ) {
					rp_SetClientInt(owner, i_Bank, rp_GetClientInt(owner, i_Bank) - (25 * 15));
					CPrintToChat(owner, "{lightblue}[TSX-RP]{default} Quelqu'un vol vos faux billets.");
				}
				
				
				stealAMount = 25 * 15;
				rp_ClientDamage(target, 250, client);
				
			}
			case 6: { // Téléphone
				time *= 6.0;
				stealAMount = 250;
				missionTelephone(client);
			}
			case 7: { // Plant de drogue
				
				int count = rp_GetBuildingData(target, BD_count);
				if( count > 0  ) {
					char classname[64], tmp[4][12];
					GetEdictClassname(target, classname, sizeof(classname));
					ExplodeString(classname, "_", tmp, sizeof(tmp), sizeof(tmp[]));
					int sub = StringToInt(tmp[3]);
					
					rp_GetItemData(sub, item_type_name, classname, sizeof(classname));
					rp_ClientGiveItem(client, sub, count);
					rp_SetBuildingData(target, BD_count, 0);
					stealAMount = 75 * count;
					
					int owner = rp_GetBuildingData(target, BD_owner);
					if( IsValidClient(owner) ) {
						CPrintToChat(owner, "{lightblue}[TSX-RP]{default} Quelqu'un vol votre drogue.");
					}
					CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous avez ramassé %d %s.", count, classname);
				}
			}
		}
		
		rp_SetClientInt(client, i_LastVolTime, GetTime());
		rp_SetClientInt(client, i_LastVolTarget, -1);
		rp_SetClientInt(client, i_LastVolAmount, stealAMount); 
		
		CreateTimer(time, AllowStealing, client);
		return Plugin_Stop;
	}
	
	if( Math_GetRandomInt(1, 10) == 8 )
		ServerCommand("sm_effect_particles %d Trail2 2 legacy_weapon_bone", client);
	if( Math_GetRandomInt(1, 30) == 8 )
		ServerCommand("sm_effect_particles %d Aura2 1 footplant_L", client);
	if( Math_GetRandomInt(1, 30) == 8 )
		ServerCommand("sm_effect_particles %d Aura2 1 footplant_R", client);
		
	if( Math_GetRandomInt(1, 500) == 42 )
		CreateTimer(0.01, timerAlarm, target); 
	
	float ratio = 15.0 / 2500.0;
	
	if( type )
		ratio *= 2.0;
	
	rp_SetClientFloat(client, fl_CoolDown, GetGameTime() + 0.15);
	
	ResetPack(dp);
	WritePackCell(dp, client);
	WritePackCell(dp, target);
	WritePackCell(dp, percent + ratio);
	WritePackCell(dp, type);
	MENU_ShowPickLock(client, percent, 0, type);
	return Plugin_Continue;
}
public Action SpawnMoney(Handle timer, any target) {
	
	target = EntRefToEntIndex(target);
	if( !IsValidEdict(target) )
		return Plugin_Handled;
	
	char classname[64];
	GetEdictClassname(target, classname, sizeof(classname));
	
	float vecOrigin[3], vecAngle[3], vecPos[3], min[3], max[3];
	Entity_GetAbsOrigin(target, vecOrigin);
	Entity_GetAbsAngles(target, vecAngle);
	
	if( StrContains(classname, "rp_bank") == 0 ) {
		
		Math_RotateVector( view_as<float>({ 7.0, 0.0, 40.0 }), vecAngle, vecPos);
		vecOrigin[0] += vecPos[0];
		vecOrigin[1] += vecPos[1];
		vecOrigin[2] += vecPos[2];
		
		vecAngle[0] += Math_GetRandomFloat(-5.0, 5.0);
		vecAngle[1] += Math_GetRandomFloat(-5.0, 5.0);	
		Math_RotateVector( view_as<float>({ 0.0, 250.0, 40.0 }), vecAngle, vecPos);
		
		int rnd = Math_GetRandomInt(2, 5) * 10;
		int job = rp_GetRandomCapital(91);
		rp_SetJobCapital(job, rp_GetJobCapital(job) - rnd);
	}
	else {
		Entity_GetMinSize(target, min);
		Entity_GetMaxSize(target, max);
		
		vecOrigin[2] += max[2] - min[2];
		
		vecPos[0] += Math_GetRandomFloat(-100.0, 100.0);
		vecPos[1] += Math_GetRandomFloat(-100.0, 100.0);
		vecPos[2] += Math_GetRandomFloat(200.0, 300.0);
	}
	
	int m = rp_Effect_SpawnMoney(vecOrigin);
	TeleportEntity(m, NULL_VECTOR, NULL_VECTOR, vecPos);
	ServerCommand("sm_effect_particles %d Trail9 3", m);
	return Plugin_Handled;
}
// ----------------------------------------------------------------------------
public Action Cmd_ItemPickLock(int args) {
	#if defined DEBUG
	PrintToServer("Cmd_ItemPickLock");
	#endif
	
	int client = GetCmdArgInt(1);
	int item_id = GetCmdArgInt(args);
	bool fast = false;
	char arg[64];
	GetCmdArg(0, arg, sizeof(arg));
	if( StrEqual(arg, "rp_item_picklock2") )
		fast = true;
		
	if( rp_GetClientJobID(client) != 91 ) {
		return Plugin_Continue;
	}
	
	int door = getDoor(client);
	if( door == 0 ) {
		ITEM_CANCEL(client, item_id);
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous devez viser une porte.");
		return Plugin_Handled;
	}
	
	// Anti-cheat:
	if( rp_GetClientItem(client, item_id) >= GetMaxKit(client, item_id)-1 ) {
		rp_ClientGiveItem(client, item_id, -rp_GetClientItem(client, item_id) + GetMaxKit(client, item_id) - 1);
	}
	
	ServerCommand("sm_effect_particles %d weapon_sensorgren_detonate 1 facemask", client);
	ServerCommand("sm_effect_particles %d Trail2 2 legacy_weapon_bone", client);
	
	rp_SetClientStat(client, i_JobFails, rp_GetClientStat(client, i_JobFails) + 1);
	rp_SetClientInt(client, i_LastVolTime, GetTime());
	rp_SetClientInt(client, i_LastVolAmount, 100);
	rp_SetClientInt(client, i_LastVolTarget, -1);
	
	rp_ClientReveal(client);
	runAlarm(client, door);	
	
	Handle dp;
	CreateDataTimer(0.1, ItemPickLockOver_frame, dp, TIMER_DATA_HNDL_CLOSE|TIMER_REPEAT); 
	WritePackCell(dp, client);
	WritePackCell(dp, door);
	WritePackCell(dp, rp_GetDoorID(door));
	WritePackCell(dp, (fast?0.75:0.0));
	
	return Plugin_Handled;
}
public Action ItemPickLockOver_frame(Handle timer, Handle dp) {
	#if defined DEBUG
	PrintToServer("ItemPickLockOver_frame");
	#endif	
	ResetPack(dp);
	int client 	 = ReadPackCell(dp);
	int door = ReadPackCell(dp);
	int doorID = ReadPackCell(dp);
	float percent = ReadPackCell(dp);
	int target = getDoor(client);
	
	if( !IsValidClient(client ) ) {
		return Plugin_Stop;
	}
	if( target <= 0 || rp_GetDoorID(target) != doorID ) {
		MENU_ShowPickLock(client, percent, -1, 1);
		rp_ClientColorize(client);
		return Plugin_Stop;
	}
	if( percent >= 1.0 ) {
		
		if( IsValidClient(g_iDoorDefine_LOCKER[doorID]) ) {
			char zone[128];
 			rp_GetZoneData(rp_GetPlayerZone(door), zone_type_name, zone, sizeof(zone));
 			
			CPrintToChat(client, "{lightblue}[TSX-RP]{default} Quelqu'un a ouvert votre porte cadnacée (%s).", zone);
			
			if( Math_GetRandomInt(1, 10) == 5 ) {
				CPrintToChat(client, "{lightblue}[TSX-RP]{default} Votre cadenas a été détruit.");
				g_iDoorDefine_LOCKER[doorID] = 0;
			}
		}
		
		rp_ClientColorize(client);
		
		rp_SetDoorLock(doorID, false); 
		rp_ClientOpenDoor(client, doorID, true);
		
		rp_SetClientStat(client, i_JobSucess, rp_GetClientStat(client, i_JobSucess) + 1);
		rp_SetClientStat(client, i_JobFails, rp_GetClientStat(client, i_JobFails) - 1);
		
		rp_SetClientFloat(client, fl_LastCrochettage, GetGameTime());
		
		CPrintToChat(client, "{lightblue}[TSX-RP]{default} La porte a été ouverte.");
		
		return Plugin_Stop;
	}
	
	rp_SetClientFloat(client, fl_CoolDown, GetGameTime() + 0.15);
	float ratio = getKitDuration(client) / 5000.0;
	int difficulte = 1;
	
	if( rp_IsInPVP(client) )
		difficulte += 1;
	if( rp_GetZoneBit( rp_GetPlayerZone(door)) & BITZONE_HAUTESECU )
		difficulte += 1;
	if( g_iDoorDefine_LOCKER[doorID] )
		difficulte += 2;
	
	if( Math_GetRandomInt(1, 10) == 8 )
		ServerCommand("sm_effect_particles %d Trail2 2 legacy_weapon_bone", client);
	
	ratio = ratio / float(difficulte);
	ResetPack(dp);
	WritePackCell(dp, client);
	WritePackCell(dp, door);
	WritePackCell(dp, doorID);
	WritePackCell(dp, percent + ratio);
	MENU_ShowPickLock(client, percent, difficulte, 1);
	return Plugin_Continue;
}
// ----------------------------------------------------------------------------
public Action timerAlarm(Handle timer, any door) {
	#if defined DEBUG
	PrintToServer("timerAlarm");
	#endif
	
	EmitSoundToAllAny("UI/arm_bomb.wav", door, _, _, _, 0.5);
	return Plugin_Handled;
}
public Action AllowStealing(Handle timer, any client) {
	#if defined DEBUG
	PrintToServer("AllowStealing");
	#endif
	
	rp_SetClientBool(client, b_MaySteal, true);
	CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous pouvez à nouveau voler.");
}
int GetMaxKit(int client, int itemID) {
	#if defined DEBUG
	PrintToServer("GetMaxKit");
	#endif
	int max, job = rp_GetClientInt(client, i_Job);
	
	switch( job ) {
		case 91:	max = 7;
		case 92:	max = 6;
		case 93:	max = 5; // parrain
		case 94:	max = 5; // pro
		case 95:	max = 4; // mafieux
		case 96:	max = 3; // apprenti
		default:	max = 0;
	}
	
	if( itemID == ITEM_PIEDBICHE )
		max = 1;
	if( itemID == ITEM_KITEXPLOSIF )
		max = RoundToCeil(max / 3.0);
	
	return max;
}
int getDoor(int client) {
	if( !IsPlayerAlive(client) )
		return 0;
	int door = rp_GetClientTarget(client);
	if( !rp_IsValidDoor(door) && IsValidEdict(door) && rp_IsValidDoor(Entity_GetParent(door)) )
		door = Entity_GetParent(door);
	
	if( !rp_IsValidDoor(door) || !rp_IsEntitiesNear(client, door, true) )
		door = 0;
	return door;
}
int getDistrib(int client, int& type) {
	if( !IsPlayerAlive(client) )
		return 0;
	int target = rp_GetClientTarget(client);
	
	if( target <= MaxClients )
		return 0;
	if( !rp_IsEntitiesNear(client, target, true) )
		return 0;
	
	char classname[128];
	GetEdictClassname(target, classname, sizeof(classname));
	
	
	if( StrContains(classname, "rp_bank_") == 0 && StrContains(classname, "rp_bank__") != 0 )
		type = 2;
	if( StrContains(classname, "rp_weaponbox_") == 0 )
		type = 3;
	if( (StrContains(classname, "rp_cashmachine_") == 0) && rp_GetClientJobID(rp_GetBuildingData(target, BD_owner)) != 91 && !rp_GetClientBool(rp_GetBuildingData(target, BD_owner), b_IsAFK) && !rp_IsClientNew(rp_GetBuildingData(target, BD_owner)))
		type = 4;
	if( (StrContains(classname, "rp_bigcashmachine_") == 0) && rp_GetClientJobID(rp_GetBuildingData(target, BD_owner)) != 91 && !rp_GetClientBool(rp_GetBuildingData(target, BD_owner), b_IsAFK))
		type = 5;
	if( StrContains(classname, "rp_phone_") == 0 )
		type = 6;
	if( (StrContains(classname, "rp_plant_") == 0) && rp_GetClientJobID(rp_GetBuildingData(target, BD_owner)) != 91 && !rp_GetClientBool(rp_GetBuildingData(target, BD_owner), b_IsAFK) && rp_GetBuildingData(target, BD_count) > 0 )
		type = 7;
		
	return (type > 0 ? target : 0);
}
void runAlarm(int client, int door) {
	int doorID = rp_GetDoorID(door);
	int alarm = g_iDoorDefine_LOCKER[doorID];
	if( alarm ) {
		
		if( IsValidClient(alarm) ) {
			char zone[128];
			rp_GetZoneData(rp_GetPlayerZone(door), zone_type_name, zone, sizeof(zone));
			
			CPrintToChat(alarm, "{lightblue}[TSX-RP]{default} Quelqu'un crochette votre porte (%s).", zone );
			rp_Effect_BeamBox(alarm, client);
		}
		
		EmitSoundToAllAny("UI/arm_bomb.wav", door);
		CreateTimer(10.0, timerAlarm, door); 
	}
}
int getKitDuration(int client) {
	int job = rp_GetClientInt(client, i_Job);
	int ratio = 0;
	switch( job ) {
		case 91: ratio = 75;	// Chef
		case 92: ratio = 80;	// Co-chef
		case 93: ratio = 85; 	// Parrain
		case 94: ratio = 90;	// Pro
		case 95: ratio = 95;	// Mafieu
		case 96: ratio = 100;	// Apprenti
	}
	return ratio;
}
int countPolice(int client) {
	int job, count;
	for(int i=1; i<MaxClients; i++) {
		if( !IsValidClient(i) )
			continue;
		
		job = rp_GetClientInt(i, i_Job);
		
		if( GetClientTeam(i) == CS_TEAM_CT || (job >= 1 && job <= 7 ) ) {
			if( Entity_GetDistance(client, i) < (MAX_AREA_DIST+100) ) {
				count++;
			}
		}
	}
	return count;
}
// ----------------------------------------------------------------------------
void MENU_ShowPickLock(int client, float percent, int difficulte, int type) {

	Handle menu = CreateMenu(eventMenuNone);
	switch( type ) {
		case 1: SetMenuTitle(menu, "== Mafia: Ouverture d'une porte");
		case 2: SetMenuTitle(menu, "== Mafia: Crochetage d'un distributeur");
		case 3: SetMenuTitle(menu, "== Mafia: Crochetage d'une armurerie");
		case 4: SetMenuTitle(menu, "== Mafia: Crochetage d'une imprimante");
		case 5: SetMenuTitle(menu, "== Mafia: Crochetage d'une photocopieuse");
		case 6: SetMenuTitle(menu, "== Mafia: Crochetage d'un téléphone");
		case 7: SetMenuTitle(menu, "== Mafia: Crochetage d'un plant de drogue");
	}
	
	char tmp[64];
	rp_Effect_LoadingBar(tmp, sizeof(tmp), percent );
	AddMenuItem(menu, tmp, tmp, ITEMDRAW_DISABLED);
	
	switch( difficulte ) {
		case -1: AddMenuItem(menu, ".", "Difficulté: Échec", ITEMDRAW_DISABLED);
		case 1: AddMenuItem(menu, ".", "Difficulté: Facile", ITEMDRAW_DISABLED);
		case 2: AddMenuItem(menu, ".", "Difficulté: Moyenne", ITEMDRAW_DISABLED);
		case 3: AddMenuItem(menu, ".", "Difficulté: Difficile", ITEMDRAW_DISABLED);
		case 4: AddMenuItem(menu, ".", "Difficulté: Très difficile", ITEMDRAW_DISABLED);
	}
	
	Format(tmp, sizeof(tmp), "Policier proche: %d", countPolice(client));
	AddMenuItem(menu, ".", tmp, ITEMDRAW_DISABLED);
	
	SetMenuExitBackButton(menu, false);
	DisplayMenu(menu, client, 1);
}
public int eventMenuNone(Handle menu, MenuAction action, int client, int param2) {	
	if( action == MenuAction_End ) {
		CloseHandle(menu);
	}
}
void missionTelephone(int client) {
	float vecDir[3];
	vecDir[0] = Math_GetRandomFloat(-3250.0, 2000.0);
	vecDir[1] = Math_GetRandomFloat(-5000.0, 900.0);
	
	float tmp[3];
	GetClientAbsOrigin(client, tmp);
	TE_SetupBeamPoints(vecDir, tmp, g_cBeam, 0, 0, 0, 17.5, 1.0, 10.0, 0, 0.0, {255, 255, 255, 100}, 20);
	TE_SendToClient(client);
	
	TE_SetupBeamRingPoint(vecDir, 50.0, 250.0, g_cBeam, 0, 0, 30, 17.5, 20.0, 0.0, { 255, 255, 255, 100 }, 10, 0);
	TE_SendToClient(client);
	
	vecDir[2] -= 2000.0;
	
	Handle dp;
	CreateDataTimer(7.5, Copter_Post, dp);
	WritePackFloat(dp, vecDir[0]);
	WritePackFloat(dp, vecDir[1]);
	
	char msg[256];
	rp_GetZoneData(rp_GetZoneFromPoint(vecDir), zone_type_name, msg, sizeof(msg));
	Handle menu = CreateMenu(eventMenuNone);
	SetMenuTitle(menu, "== MISSION TELEPHONE == ");
	AddMenuItem(menu, "_", "Un hélicoptère vous envois un colis.", ITEMDRAW_DISABLED);
	AddMenuItem(menu, "_", "Il sera envoyé près de:", ITEMDRAW_DISABLED);
	AddMenuItem(menu, "_", msg, ITEMDRAW_DISABLED);
	
	SetMenuExitButton(menu, true);
	DisplayMenu(menu, client, 30);	
}
public Action Copter_Post(Handle timer, Handle dp ) {
	float vecDest[2];
	
	ResetPack(dp);
	vecDest[0] = ReadPackFloat(dp);
	vecDest[1] = ReadPackFloat(dp);
	
	ServerCommand("sm_effect_copter %f %f", vecDest[0], vecDest[1]);
	
	return Plugin_Stop;
}

bool disapear(int client) {
	int zoneJob = rp_GetZoneInt(rp_GetPlayerZone(client), zone_type_type);
	
	int rndClient[65], rndCount;
	if( zoneJob == 1 ) {
		for (int i = 1; i <= MaxClients; i++) {
			if( IsValidClient(i) && rp_GetClientJobID(i) == 1 ) {
				rndClient[rndCount++] = i;
			}
		}
	}
	else {
		for (int i = 1; i <= MaxClients; i++) {
			if( IsValidClient(i) && rp_GetClientJobID(i) != 1 ) {
				rndClient[rndCount++] = i;
			}
		}
	}
	if( rndCount == 0 )
		return false;
	int rnd = Math_GetRandomInt(0, rndCount - 1);
	char model[128];
	Entity_GetModel(rndClient[rnd], model, sizeof(model));
	Entity_SetModel(client, model);
	rp_SetClientInt(client, i_FakeClient, rndClient[rnd]);
	
	rp_HookEvent(client, RP_OnPlayerZoneChange, fwdZoneChange);
	rp_HookEvent(client, RP_OnPlayerDead, fwdDead);
	CreateTimer(10.0, appear, client);
	
	float vecCenter[3];
	Entity_GetAbsOrigin(client, vecCenter);
	TE_SetupBeamRingPoint(vecCenter, 1.0, 200.0, g_cBeam, g_cBeam, 0, 10, 0.25, 80.0, 0.0, {255, 255, 255, 255}, 1, 0);
	TE_SendToAll();
	CPrintToChat(client, "{lightblue}[TSX-RP]{default} Vous vous êtes déguisé en tant que %N.", rndClient[rnd]);
	return true;
}
public Action appear(Handle timer, any client) {
	if( rp_GetClientInt(client, i_FakeClient) != 0 ) {
		rp_SetClientInt(client, i_FakeClient, 0);
		rp_UnhookEvent(client, RP_OnPlayerZoneChange, fwdZoneChange);
		rp_UnhookEvent(client, RP_OnPlayerDead, fwdDead);
	}
}
public Action fwdZoneChange(int client, int oldZone, int newZone) {
	PrintToChatAll("%d %d %d", client, oldZone, newZone);
}
public Action fwdDead(int client, int attacker) {
	PrintToChatAll("%d %d", client, attacker);
	CreateTimer(0.1, appear, client);
}