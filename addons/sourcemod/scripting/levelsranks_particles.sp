#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <clientprefs>
#include <sdktools>
#include <lvl_ranks>

#define PLUGIN_NAME "Levels Ranks"
#define PLUGIN_AUTHOR "RoadSide Romeo"

int		g_iRank[MAXPLAYERS+1],
		g_iAuraButton[MAXPLAYERS+1],
		g_iAuraChoose[MAXPLAYERS+1],
		g_iAura[MAXPLAYERS+1],
		g_iAuraCount,
		g_iAuraRank,
		g_iTrailButton[MAXPLAYERS+1],
		g_iTrailChoose[MAXPLAYERS+1],
		g_iTrail[MAXPLAYERS+1],
		g_iTrailCount,
		g_iTrailRank;
char		g_sAuraName[128][64],
		g_sAuraParticle[128][64],
		g_sTrailName[128][64],
		g_sTrailParticle[128][64];
Handle	g_hAura = null,
		g_hTrail = null;

/////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////
/////////////////////////////////////////////////////////////////////////

public Plugin myinfo = {name = "[LR] Module - Particles", author = PLUGIN_AUTHOR, version = PLUGIN_VERSION}
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	if(GetEngineVersion() != Engine_CSGO)
	{
		SetFailState("[%s Particles] Плагин работает только на CS:GO", PLUGIN_NAME);
	}
}

public void OnPluginStart()
{
	LR_ModuleCount();
	HookEvent("player_team", Event_Particles);
	HookEvent("player_death", Event_Particles);
	HookEvent("player_spawn", Event_Particles);

	g_hAura = RegClientCookie("LR_Aura", "LR_Aura", CookieAccess_Private);
	g_hTrail = RegClientCookie("LR_Trail", "LR_Trail", CookieAccess_Private);
	LoadTranslations("levels_ranks_particles.phrases");
	
	for(int iClient = 1; iClient <= MaxClients; iClient++)
    {
		if(IsClientInGame(iClient))
		{
			if(AreClientCookiesCached(iClient))
			{
				OnClientCookiesCached(iClient);
			}
		}
	}
}

public void OnMapStart() 
{
	DownloadParticlesMat();
	DownloadParticles();
	ReadTrail();
	ReadAura();
}

void DownloadParticlesMat()
{
	char sPath[PLATFORM_MAX_PATH];
	Handle hBuffer = OpenFile("addons/sourcemod/configs/levels_ranks/downloadsparticlesmat.ini", "r");
	if(hBuffer == null) SetFailState("Не удалось загрузить addons/sourcemod/configs/levels_ranks/downloadsparticlesmat.ini");

	while(ReadFileLine(hBuffer, sPath, 192))
    {
        TrimString(sPath);
        if(IsCharAlpha(sPath[0]))
		{
			AddFileToDownloadsTable(sPath);
		}
    }
	delete hBuffer;
}

void DownloadParticles()
{
	char sPath[PLATFORM_MAX_PATH];
	Handle hBuffer = OpenFile("addons/sourcemod/configs/levels_ranks/downloadsparticles.ini", "r");
	if(hBuffer == null) SetFailState("Не удалось загрузить addons/sourcemod/configs/levels_ranks/downloadsparticles.ini");

	while(ReadFileLine(hBuffer, sPath, 192))
    {
        TrimString(sPath);
        if(IsCharAlpha(sPath[0]))
		{
			AddFileToDownloadsTable(sPath);
			PrecacheGeneric(sPath, true);
		}
    }
	delete hBuffer;
}

void ReadTrail()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/trail.ini");
	KeyValues hLR_Trail = new KeyValues("LR_Trails");

	if(!hLR_Trail.ImportFromFile(sPath) || !hLR_Trail.GotoFirstSubKey())
	{
		SetFailState("[%s Particles] : фатальная ошибка - файл не найден (%s)", PLUGIN_NAME, sPath);
	}

	hLR_Trail.Rewind();

	if(hLR_Trail.JumpToKey("Trails"))
	{
		g_iTrailCount = 0;
		g_iTrailRank = hLR_Trail.GetNum("rank_trail", 0);
		hLR_Trail.GotoFirstSubKey();

		do
		{
			hLR_Trail.GetSectionName(g_sTrailName[g_iTrailCount], sizeof(g_sTrailName[]));
			hLR_Trail.GetString("particle", g_sTrailParticle[g_iTrailCount], sizeof(g_sTrailParticle[]));
			PrecacheModel(g_sTrailParticle[g_iTrailCount], true);
			g_iTrailCount++;
		}
		while(hLR_Trail.GotoNextKey() && g_iTrailCount < 128);
	}
	else SetFailState("[%s Particles] : фатальная ошибка - секция Trails не найдена (%s)", PLUGIN_NAME, sPath);
	delete hLR_Trail;
}

void ReadAura()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/levels_ranks/aura.ini");
	KeyValues hLR_Aura = new KeyValues("LR_Aura");

	if(!hLR_Aura.ImportFromFile(sPath) || !hLR_Aura.GotoFirstSubKey())
	{
		SetFailState("[%s Particles] : фатальная ошибка - файл не найден (%s)", PLUGIN_NAME, sPath);
	}

	hLR_Aura.Rewind();
	if(hLR_Aura.JumpToKey("Aura"))
	{
		g_iAuraCount = 0;
		g_iAuraRank = hLR_Aura.GetNum("rank_aura", 0);
		hLR_Aura.GotoFirstSubKey();

		do
		{
			hLR_Aura.GetSectionName(g_sAuraName[g_iAuraCount], sizeof(g_sAuraName[]));
			hLR_Aura.GetString("particle", g_sAuraParticle[g_iAuraCount], sizeof(g_sAuraParticle[]));
			PrecacheModel(g_sAuraParticle[g_iAuraCount], true);
			g_iAuraCount++;
		}
		while(hLR_Aura.GotoNextKey() && g_iAuraCount < 128);
	}
	else SetFailState("[%s Particles] : фатальная ошибка - секция Aura не найдена (%s)", PLUGIN_NAME, sPath);
	delete hLR_Aura;
}

public void Event_Particles(Handle hEvent, char[] sEvName, bool bDontBroadcast)
{
	switch(sEvName[7])
	{
		case 't':
		{
			int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
			if(IsValidClient(iClient))
			{
				DeleteTrail(iClient);
				DeleteAura(iClient);
			}
		}

		case 's':
		{
			int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
			if(IsValidClient(iClient))
			{
				g_iRank[iClient] = LR_GetClientRank(iClient);

				if(!g_iTrailButton[iClient] && g_iRank[iClient] >= g_iTrailRank)
				{
					SetTrail(iClient);
				}

				if(!g_iAuraButton[iClient] && g_iRank[iClient] >= g_iAuraRank)
				{
					SetAura(iClient);
				}
			}
		}

		case 'd':
		{
			int iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));
			if(IsValidClient(iClient))
			{
				DeleteTrail(iClient);
				DeleteAura(iClient);
			}
		}
	}
}

public void LR_OnMenuCreated(int iClient, int iRank, Menu& hMenu)
{
	if(iRank == g_iTrailRank)
	{
		char sText[64];
		SetGlobalTransTarget(iClient);
		g_iRank[iClient] = LR_GetClientRank(iClient);

		if(g_iRank[iClient] >= g_iTrailRank)
		{
			FormatEx(sText, sizeof(sText), "%t", "Trail_RankOpened");
			hMenu.AddItem("Trails", sText);
		}
		else
		{
			FormatEx(sText, sizeof(sText), "%t", "Trail_RankClosed", g_iTrailRank);
			hMenu.AddItem("Trails", sText, ITEMDRAW_DISABLED);
		}
	}

	if(iRank == g_iAuraRank)
	{
		char sText[64];
		SetGlobalTransTarget(iClient);
		g_iRank[iClient] = LR_GetClientRank(iClient);

		if(g_iRank[iClient] >= g_iAuraRank)
		{
			FormatEx(sText, sizeof(sText), "%t", "Aura_RankOpened");
			hMenu.AddItem("Auras", sText);
		}
		else
		{
			FormatEx(sText, sizeof(sText), "%t", "Aura_RankClosed", g_iAuraRank);
			hMenu.AddItem("Auras", sText, ITEMDRAW_DISABLED);
		}
	}
}

public void LR_OnMenuItemSelected(int iClient, int iRank, const char[] sInfo)
{
	if(iRank == g_iTrailRank)
	{
		if(strcmp(sInfo, "Trails") == 0)
		{
			TrailsMenu(iClient, 0);
		}
	}

	if(iRank == g_iAuraRank)
	{
		if(strcmp(sInfo, "Auras") == 0)
		{
			AuraMenu(iClient, 0);
		}
	}
}

public void TrailsMenu(int iClient, int iList)
{
	char sID[4], sText[192];
	SetGlobalTransTarget(iClient);
	Menu Mmenu = new Menu(TrailsMenuHandler);

	FormatEx(sText, sizeof(sText), "%t", "Trail_RankOpened");
	Mmenu.SetTitle("%s | %s\n ", PLUGIN_NAME, sText);

	switch(g_iTrailButton[iClient])
	{
		case 0: FormatEx(sText, sizeof(sText), "%t\n ", "Trail_Off");
		case 1: FormatEx(sText, sizeof(sText), "%t\n ", "Trail_On");
	}

	Mmenu.AddItem("-1", sText);

	for(int i = 0; i < g_iTrailCount; i++)
	{
		IntToString(i, sID, sizeof(sID));
		FormatEx(sText, sizeof(sText), "%s", g_sTrailName[i]);
		Mmenu.AddItem(sID, sText);
	}

	Mmenu.ExitBackButton = true;
	Mmenu.ExitButton = true;
	Mmenu.DisplayAt(iClient, iList, MENU_TIME_FOREVER);
}

public int TrailsMenuHandler(Menu Mmenu, MenuAction mAction, int iClient, int iSlot)
{
	switch(mAction)
	{
		case MenuAction_End: delete Mmenu;
		case MenuAction_Cancel: if(iSlot == MenuCancel_ExitBack) {LR_MenuInventory(iClient);}
		case MenuAction_Select:
		{
			char sID[4];
			Mmenu.GetItem(iSlot, sID, sizeof(sID));

			if(StringToInt(sID) == -1)
			{
				switch(g_iTrailButton[iClient])
				{
					case 0:
					{
						g_iTrailButton[iClient] = 1;
						DeleteTrail(iClient);
						TrailsMenu(iClient, GetMenuSelectionPosition());
					}

					case 1:
					{
						g_iTrailButton[iClient] = 0;
						if(IsPlayerAlive(iClient)) SetTrail(iClient);
						TrailsMenu(iClient, GetMenuSelectionPosition());
					}
				}
			}
			else
			{
				g_iTrailChoose[iClient] = StringToInt(sID);
				if(IsPlayerAlive(iClient) && !g_iTrailButton[iClient]) SetTrail(iClient);
				TrailsMenu(iClient, GetMenuSelectionPosition());
			}
		}
	}
}

public void AuraMenu(int iClient, int iList)
{
	char sID[4], sText[192];
	SetGlobalTransTarget(iClient);
	Menu Mmenu = new Menu(AuraMenuHandler);

	FormatEx(sText, sizeof(sText), "%t", "Aura_RankOpened");
	Mmenu.SetTitle("%s | %s\n ", PLUGIN_NAME, sText);

	switch(g_iAuraButton[iClient])
	{
		case 0: FormatEx(sText, sizeof(sText), "%t\n ", "Aura_Off");
		case 1: FormatEx(sText, sizeof(sText), "%t\n ", "Aura_On");
	}

	Mmenu.AddItem("-1", sText);

	for(int i = 0; i < g_iAuraCount; i++)
	{
		IntToString(i, sID, sizeof(sID));
		FormatEx(sText, sizeof(sText), "%s", g_sAuraName[i]);
		Mmenu.AddItem(sID, sText);
	}

	Mmenu.ExitBackButton = true;
	Mmenu.ExitButton = true;
	Mmenu.DisplayAt(iClient, iList, MENU_TIME_FOREVER);
}

public int AuraMenuHandler(Menu Mmenu, MenuAction mAction, int iClient, int iSlot)
{
	switch(mAction)
	{
		case MenuAction_End: delete Mmenu;
		case MenuAction_Cancel: if(iSlot == MenuCancel_ExitBack) {LR_MenuInventory(iClient);}
		case MenuAction_Select:
		{
			char sID[4];
			Mmenu.GetItem(iSlot, sID, sizeof(sID));

			if(StringToInt(sID) == -1)
			{
				switch(g_iAuraButton[iClient])
				{
					case 0:
					{
						g_iAuraButton[iClient] = 1;
						DeleteAura(iClient);
						AuraMenu(iClient, GetMenuSelectionPosition());
					}

					case 1:
					{
						g_iAuraButton[iClient] = 0;
						if(IsPlayerAlive(iClient)) SetAura(iClient);
						AuraMenu(iClient, GetMenuSelectionPosition());
					}
				}
			}
			else
			{
				g_iAuraChoose[iClient] = StringToInt(sID);
				if(IsPlayerAlive(iClient) && !g_iAuraButton[iClient]) SetAura(iClient);
				AuraMenu(iClient, GetMenuSelectionPosition());
			}
		}
	}
}

void SetTrail(int iClient)
{
	DeleteTrail(iClient);

	char sTargetName[32]; float fPos[3];
	GetClientAbsOrigin(iClient, fPos);
	FormatEx(sTargetName, 32, "client%d", iClient);

	g_iTrail[iClient] = CreateEntityByName("info_particle_system");
	DispatchKeyValue(g_iTrail[iClient], "effect_name", g_sTrailParticle[g_iTrailChoose[iClient]]);

	if(DispatchSpawn(g_iTrail[iClient]))
	{
		ActivateEntity(g_iTrail[iClient]);
		AcceptEntityInput(g_iTrail[iClient], "Start");
		TeleportEntity(g_iTrail[iClient], fPos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(iClient, "targetname", sTargetName);
		SetVariantString(sTargetName);
		AcceptEntityInput(g_iTrail[iClient], "SetParent");
	}
	else g_iTrail[iClient] = 0;
}

void SetAura(int iClient)
{
	DeleteAura(iClient);

	char sTargetName[32]; float fPos[3];
	GetClientAbsOrigin(iClient, fPos);
	FormatEx(sTargetName, 32, "client%d", iClient);

	g_iAura[iClient] = CreateEntityByName("info_particle_system");
	DispatchKeyValue(g_iAura[iClient], "effect_name", g_sAuraParticle[g_iAuraChoose[iClient]]);

	if(DispatchSpawn(g_iAura[iClient]))
	{
		ActivateEntity(g_iAura[iClient]);
		AcceptEntityInput(g_iAura[iClient], "Start");
		TeleportEntity(g_iAura[iClient], fPos, NULL_VECTOR, NULL_VECTOR);
		DispatchKeyValue(iClient, "targetname", sTargetName);
		SetVariantString(sTargetName);
		AcceptEntityInput(g_iAura[iClient], "SetParent");
	}
	else g_iAura[iClient] = 0;
}

void DeleteTrail(int iClient)
{
	if(g_iTrail[iClient] > 0 && IsValidEdict(g_iTrail[iClient]))
	{
		AcceptEntityInput(g_iTrail[iClient], "Kill");
	}
	g_iTrail[iClient] = 0;
}

void DeleteAura(int iClient)
{
	if(g_iAura[iClient] > 0 && IsValidEdict(g_iAura[iClient]))
	{
		AcceptEntityInput(g_iAura[iClient], "Kill");
	}
	g_iAura[iClient] = 0;
}

public void OnClientCookiesCached(int iClient)
{
	char sCookie[12], sBuffer[2][6];

	GetClientCookie(iClient, g_hAura, sCookie, sizeof(sCookie));
	ExplodeString(sCookie, ";", sBuffer, sizeof(sBuffer), sizeof(sBuffer[]));
	g_iAuraChoose[iClient] = StringToInt(sBuffer[0]);
	g_iAuraButton[iClient] = StringToInt(sBuffer[1]);

	GetClientCookie(iClient, g_hTrail, sCookie, sizeof(sCookie));
	ExplodeString(sCookie, ";", sBuffer, sizeof(sBuffer), sizeof(sBuffer[]));
	g_iTrailChoose[iClient] = StringToInt(sBuffer[0]);
	g_iTrailButton[iClient] = StringToInt(sBuffer[1]);
}

public void OnClientDisconnect(int iClient)
{
	DeleteTrail(iClient);
	DeleteAura(iClient);

	if(AreClientCookiesCached(iClient))
	{
		char sBuffer[12];
		Format(sBuffer, sizeof(sBuffer), "%i;%i;", g_iAuraChoose[iClient], g_iAuraButton[iClient]); SetClientCookie(iClient, g_hAura, sBuffer);
		Format(sBuffer, sizeof(sBuffer), "%i;%i;", g_iTrailChoose[iClient], g_iTrailButton[iClient]); SetClientCookie(iClient, g_hTrail, sBuffer);
	}
}

public void OnPluginEnd()
{
	for(int iClient = 1; iClient <= MaxClients; iClient++)
	{
		if(IsClientInGame(iClient))
		{
			OnClientDisconnect(iClient);
		}
	}
}