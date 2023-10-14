#include <sourcemod>
#include <shavit>
#include <convar_class>
#include <clientprefs>
#include <closestpos>
#include <sdktools>
#include <mycolors>
#include <myreplay>

#pragma newdecls required
#pragma semicolon 1

#define MAX_BEAM_WIDTH  10
#define MAX_JUMP_SIZE   16
#define MAX_JUMPS_AHEAD 5

enum RouteType
{
    RouteType_Auto,           //use personal replay, otherwise use server record for the current style
    RouteType_PersonalReplay, //only use personal replay, disabled if one isn't already saved
    RouteType_ServerRecord,   //use the server record for the current style
    RouteType_Size
};

enum struct JumpMarker
{
    int id;
    int frameNum;

    //float square[4][3]
    float line1[3];
    float line2[3];
    float line3[3];
    float line4[3];

    void Initialize(frame_t frame, int size, int id, int frameNum)
    {
        float jumpSize = float(size);

        this.id = id;
        this.frameNum = frameNum;

        this.line1[0] = frame.pos[0] + jumpSize;
        this.line1[1] = frame.pos[1] + jumpSize;
        this.line1[2] = frame.pos[2];

        this.line2[0] = frame.pos[0] + jumpSize;
        this.line2[1] = frame.pos[1] - jumpSize;
        this.line2[2] = frame.pos[2];

        this.line3[0] = frame.pos[0] - jumpSize;
        this.line3[1] = frame.pos[1] - jumpSize;
        this.line3[2] = frame.pos[2];

        this.line4[0] = frame.pos[0] - jumpSize;
        this.line4[1] = frame.pos[1] + jumpSize;
        this.line4[2] = frame.pos[2];
    }

    void Draw(int client, int color[4])
    {
        BeamEffect(client, this.line1, this.line2, 0.7, 1.0, color);
        BeamEffect(client, this.line2, this.line3, 0.7, 1.0, color);
        BeamEffect(client, this.line3, this.line4, 0.7, 1.0, color);
        BeamEffect(client, this.line4, this.line1, 0.7, 1.0, color);
    }
}

Convar gCV_NumAheadFrames = null;
Convar gCV_VelDiffScalar = null;

Cookie gH_ShowRouteCookie = null;
Cookie gH_RouteTypeCookie = null;
Cookie gH_ShowPathCookie = null;
Cookie gH_PathSizeCookie = null;
Cookie gH_PathColorCookie = null;
Cookie gH_PathOpacityCookie = null;
Cookie gH_ShowJumpsCookie = null;
Cookie gH_JumpSizeCookie = null;
Cookie gH_JumpMarkerColorCookie = null;
Cookie gH_JumpsAheadCookie = null;

//Path settings
int gI_PathColorIndex[MAXPLAYERS + 1] = {-1, ...};
int gI_PathSize[MAXPLAYERS + 1] = {MAX_BEAM_WIDTH, ...};
int gI_PathOpacity[MAXPLAYERS + 1] = {250, ...};

//Jump marker settings
int gI_JumpColorIndex[MAXPLAYERS + 1];
int gI_JumpSize[MAXPLAYERS + 1] = {MAX_JUMP_SIZE, ...};
int gI_JumpsAhead[MAXPLAYERS + 1];
int gI_JumpsIndex[MAXPLAYERS + 1];
ArrayList gA_JumpMarkerCache[MAXPLAYERS + 1];

int gI_BeamSprite = -1;
int gI_PrevStep[MAXPLAYERS + 1];
int gI_Color[MAXPLAYERS + 1][4];
int gI_PrevFrame[MAXPLAYERS + 1];

RouteType gRT_RouteType[MAXPLAYERS + 1] = {RouteType_Auto, ...};

char gS_Map[PLATFORM_MAX_PATH];
char gS_ReplayFolder[PLATFORM_MAX_PATH];
char gS_ReplayPath[MAXPLAYERS + 1][PLATFORM_MAX_PATH];

frame_cache_t gA_FrameCache[MAXPLAYERS + 1];

ClosestPos gH_ClosestPos[MAXPLAYERS + 1];

bool gB_Debug;
bool gB_Late;
bool gB_MyReplay;
bool gB_ReplayRecorder;
bool gB_ReplayPlayback;
bool gB_ClosestPos;
bool gB_LoadedReplay[MAXPLAYERS + 1];
bool gB_ShowRoute[MAXPLAYERS + 1] = {true, ...};
bool gB_ShowPath[MAXPLAYERS + 1] = {true, ...};
bool gB_ShowJumps[MAXPLAYERS + 1] = {true, ...};

public Plugin myinfo =
{
    name        = "shavit - Personal Route",
    author      = "BoomShot",
    description = "Lets players create their route and use it for practice.",
    version     = "1.0.0",
    url         = "https://github.com/BoomShotKapow"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    gB_Late = late;

    return APLRes_Success;
}

public void OnPluginStart()
{
    gH_ShowRouteCookie = new Cookie("sm_myroute_enabled", "Toggles the display of the whole plugin.", CookieAccess_Protected);
    gH_RouteTypeCookie = new Cookie("sm_myroute_type", "Defines the route type for the replay path.", CookieAccess_Protected);
    gH_ShowPathCookie = new Cookie("sm_myroute_path", "Toggles the display of the route path beam.", CookieAccess_Protected);
    gH_PathSizeCookie = new Cookie("sm_myroute_path_size", "Sets the width of the route path beam.", CookieAccess_Protected);
    gH_PathColorCookie = new Cookie("sm_myroute_path_color", "Sets the color of the route path beam.", CookieAccess_Protected);
    gH_PathOpacityCookie = new Cookie("sm_myroute_path_opacity", "Sets the opacity of the route path beam.", CookieAccess_Protected);
    gH_ShowJumpsCookie = new Cookie("sm_myroute_jump", "Toggles the display of the jump markers.", CookieAccess_Protected);
    gH_JumpSizeCookie = new Cookie("sm_myroute_jump_size", "Sets the size of the jump markers.", CookieAccess_Protected);
    gH_JumpMarkerColorCookie = new Cookie("sm_myroute_jump_color", "Sets the color of the jump markers.", CookieAccess_Protected);
    gH_JumpsAheadCookie = new Cookie("sm_myroute_jumps_ahead", "The number of jumps to draw ahead of the route path beam.", CookieAccess_Protected);

    RegConsoleCmd("sm_route", Command_Route, "Shows the menu for customizing the display of the route.");
    RegConsoleCmd("sm_path", Command_Route, "Shows the menu for customizing the display of the route.");
    RegConsoleCmd("sm_botpath", Command_Route, "Shows the menu for customizing the display of the route.");
    RegConsoleCmd("sm_routepath", Command_Route, "Shows the menu for customizing the display of the route.");

    RegConsoleCmd("sm_resetroute", Command_ResetRoute, "Resets the route path to the beginning.");

    RegAdminCmd("sm_myroute_debug", Command_Debug, ADMFLAG_ROOT);

    gB_MyReplay = LibraryExists("shavit-myreplay");
    gB_ReplayRecorder = LibraryExists("shavit-replay-recorder");
    gB_ReplayPlayback = LibraryExists("shavit-replay-playback");
    gB_ClosestPos = LibraryExists("closestpos");

    if(gB_ReplayPlayback)
    {
        Shavit_GetReplayFolderPath_Stock(gS_ReplayFolder);
    }

    gCV_NumAheadFrames = new Convar("smr_ahead_frames", "75", "Number of frames to draw ahead of the client.", 0, true, 0.0);
    gCV_VelDiffScalar = new Convar("smr_veldiff_scalar", "0.20", "Scalar for velocity difference.", 0, true, 0.0);

    Convar.AutoExecConfig();
}

public void OnAllPluginsLoaded()
{
    gB_MyReplay = LibraryExists("shavit-myreplay");
    gB_ReplayRecorder = LibraryExists("shavit-replay-recorder");
    gB_ReplayPlayback = LibraryExists("shavit-replay-playback");
    gB_ClosestPos = LibraryExists("closestpos");

    if(!gB_MyReplay)
    {
        SetFailState("shavit-myreplay is required for this plugin!");
    }
    else if(!gB_ReplayRecorder)
    {
        SetFailState("shavit-replay-recorder is required for this plugin!");
    }
    else if(!gB_ReplayPlayback)
    {
        SetFailState("shavit-replay-playback is required for this plugin!");
    }
    else if(!gB_ClosestPos)
    {
        SetFailState("closestpos is required for this plugin!");
    }

    Shavit_GetReplayFolderPath(gS_ReplayFolder, sizeof(gS_ReplayFolder));
}

public void OnLibraryAdded(const char[] name)
{
    if(StrEqual(name, "shavit-myreplay"))
    {
        gB_MyReplay = true;
    }
    else if(StrEqual(name, "shavit-replay-recorder"))
    {
        gB_ReplayRecorder = true;
    }
    else if(StrEqual(name, "shavit-replay-playback"))
    {
        gB_ReplayPlayback = true;
    }
    else if(StrEqual(name, "closestpos"))
    {
        gB_ClosestPos = true;
    }
}

public void OnLibraryRemoved(const char[] name)
{
    if(StrEqual(name, "shavit-myreplay"))
    {
        gB_MyReplay = false;
    }
    else if(StrEqual(name, "shavit-replay-recorder"))
    {
        gB_ReplayRecorder = false;
    }
    else if(StrEqual(name, "shavit-replay-playback"))
    {
        gB_ReplayPlayback = false;
    }
    else if(StrEqual(name, "closestpos"))
    {
        gB_ClosestPos = false;
    }
}

public void OnMapStart()
{
    GetLowercaseMapName(gS_Map);

    if(gB_Late)
    {
        gB_Late = false;

        for(int i = 1; i <= MaxClients; i++)
        {
            if(IsValidClient(i))
            {
                OnClientPutInServer(i);
            }
        }
    }
}

public void OnMapEnd()
{
    for(int i = 1; i <= MaxClients; i++)
    {
        if(gA_JumpMarkerCache[i] != null)
        {
            delete gA_JumpMarkerCache[i];
        }
    }
}

public void OnConfigsExecuted()
{
    gI_BeamSprite = PrecacheModel("sprites/laserbeam.vmt");
}

public void OnClientPutInServer(int client)
{
    if(IsFakeClient(client))
    {
        return;
    }

    gB_LoadedReplay[client] = false;
    gB_ShowRoute[client] = true;
    gRT_RouteType[client] = RouteType_Auto;
    gB_ShowPath[client] = true;
    gB_ShowJumps[client] = true;

    if(gA_JumpMarkerCache[client] != null)
    {
        delete gA_JumpMarkerCache[client];
    }

    gA_JumpMarkerCache[client] = new ArrayList(sizeof(JumpMarker));

    if(AreClientCookiesCached(client))
    {
        OnClientCookiesCached(client);
    }

    if(IsClientAuthorized(client))
    {
        OnClientAuthorized(client, "");
    }
}

public void OnClientAuthorized(int client, const char[] auth)
{
    if(IsFakeClient(client))
    {
        return;
    }

    LoadMyRoute(client);
}

public void OnClientDisconnect(int client)
{
    if(gA_JumpMarkerCache[client] != null)
    {
        delete gA_JumpMarkerCache[client];
    }
}

public void OnClientCookiesCached(int client)
{
    char cookie[4];

    gH_ShowRouteCookie.Get(client, cookie, sizeof(cookie));
    gB_ShowRoute[client] = (strlen(cookie) > 0) ? view_as<bool>(StringToInt(cookie)) : true;

    gH_RouteTypeCookie.Get(client, cookie, sizeof(cookie));
    gRT_RouteType[client] = (strlen(cookie) > 0) ? view_as<RouteType>(StringToInt(cookie)) : RouteType_Auto;

    gH_ShowPathCookie.Get(client, cookie, sizeof(cookie));
    gB_ShowPath[client] = (strlen(cookie) > 0) ? view_as<bool>(StringToInt(cookie)) : true;

    gH_PathSizeCookie.Get(client, cookie, sizeof(cookie));
    gI_PathSize[client] = (strlen(cookie) > 0) ? StringToInt(cookie) : MAX_BEAM_WIDTH;

    gH_PathColorCookie.Get(client, cookie, sizeof(cookie));
    gI_PathColorIndex[client] = (strlen(cookie) > 0) ? StringToInt(cookie) : -1;

    gH_PathOpacityCookie.Get(client, cookie, sizeof(cookie));
    gI_PathOpacity[client] = (strlen(cookie) > 0) ? StringToInt(cookie) : 250;

    gH_ShowJumpsCookie.Get(client, cookie, sizeof(cookie));
    gB_ShowJumps[client] = (strlen(cookie) > 0) ? view_as<bool>(StringToInt(cookie)) : true;

    gH_JumpSizeCookie.Get(client, cookie, sizeof(cookie));
    gI_JumpSize[client] = (strlen(cookie) > 0) ? StringToInt(cookie) : MAX_JUMP_SIZE;

    gH_JumpMarkerColorCookie.Get(client, cookie, sizeof(cookie));
    gI_JumpColorIndex[client] = (strlen(cookie) > 0) ? StringToInt(cookie) : view_as<int>(WHITE);

    gH_JumpsAheadCookie.Get(client, cookie, sizeof(cookie));
    gI_JumpsAhead[client] = (strlen(cookie) > 0) ? StringToInt(cookie) : 0;
}

bool GetMyRoute(int client)
{
    if(gS_ReplayFolder[0] == '\0')
    {
        Shavit_GetReplayFolderPath(gS_ReplayFolder, sizeof(gS_ReplayFolder));
    }

    char steamID[64];
    if(!GetClientAuthId(client, AuthId_Steam3, steamID, sizeof(steamID)))
    {
        LogError("Failed to authenticate [%N]!", client);
        return false;
    }

    FormatEx(gS_ReplayPath[client], PLATFORM_MAX_PATH, "%s/copy/%d_%s.replay", gS_ReplayFolder, SteamIDToAccountID(steamID), gS_Map);

    RouteType routeType = gRT_RouteType[client];

    //Set the player's route path to the server record
    if(routeType == RouteType_ServerRecord || (!FileExists(gS_ReplayPath[client]) && routeType == RouteType_Auto))
    {
        Shavit_GetReplayFilePath(Shavit_GetBhopStyle(client), Shavit_GetClientTrack(client), gS_Map, gS_ReplayFolder, gS_ReplayPath[client]);
    }

    char type[16];
    GetClientRouteType(client, type, sizeof(type));

    PrintDebug("[%N]'s route path | Type: [%s] | Path [%s]", client, type, gS_ReplayPath[client]);

    return true;
}

bool LoadMyRoute(int client)
{
    gB_LoadedReplay[client] = false;

    if(!IsValidClient(client) || IsFakeClient(client) || !GetMyRoute(client))
    {
        return false;
    }

    char type[16];
    GetClientRouteType(client, type, sizeof(type));

    if(FileExists(gS_ReplayPath[client]) && !LoadReplayCache2(gA_FrameCache[client], Shavit_GetClientTrack(client), gS_ReplayPath[client], gS_Map))
    {
        LogError("Failed to load [%N]'s replay cache using route type: [%s]", client, type);

        return false;
    }

    if(gA_FrameCache[client].aFrames != null && gA_FrameCache[client].aFrames.Length > 0)
    {
        gH_ClosestPos[client] = new ClosestPos(gA_FrameCache[client].aFrames, 0, gA_FrameCache[client].iPreFrames, gA_FrameCache[client].iFrameCount);

        if(gA_JumpMarkerCache[client] == null)
        {
            gA_JumpMarkerCache[client] = new ArrayList(sizeof(JumpMarker));
        }
        else
        {
            gA_JumpMarkerCache[client].Clear();
        }

        int markerId;

        //Cache each jump marker in the client's route
        for(int i = 0; i < gA_FrameCache[client].aFrames.Length; i++)
        {
            int lookAhead = (i + 1) < gA_FrameCache[client].aFrames.Length ? (i + 1) : i;

            frame_t prev, cur;
            gA_FrameCache[client].aFrames.GetArray(lookAhead, cur, sizeof(frame_t));
            gA_FrameCache[client].aFrames.GetArray(lookAhead <= 0 ? 0 : lookAhead - 1, prev, sizeof(frame_t));

            if(IsJump(prev, cur))
            {
                JumpMarker marker;
                marker.Initialize(cur, gI_JumpSize[client], markerId, i);

                markerId++;

                gA_JumpMarkerCache[client].PushArray(marker, sizeof(marker));
            }
        }

        PrintDebug("Cached [%N]'s jump markers | Size: [%d]", client, gA_JumpMarkerCache[client].Length);
    }

    ResetMyRoute(client, Shavit_GetTimerStatus(client) == Timer_Running && gH_ClosestPos[client] != null);

    gB_LoadedReplay[client] = true;

    return true;
}

int GetClientClosestFrame(int client)
{
    float clientPos[3];
    GetClientAbsOrigin(client, clientPos);

    return gH_ClosestPos[client].Find(clientPos);
}

//public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
public void OnPlayerRunCmdPost(int client, int buttons, int impulse, const float vel[3], const float angles[3], int weapon, int subtype, int cmdnum, int tickcount, int seed, const int mouse[2])
{
    if(!IsValidClient(client, true) || !gB_LoadedReplay[client] || !gB_ShowRoute[client])
    {
        return;
    }
    else if(gA_FrameCache[client].aFrames == null || (gA_FrameCache[client].aFrames.Length < 1) || gH_ClosestPos[client] == null)
    {
        return;
    }

    int iClosestFrame = GetClientClosestFrame(client);
    int iEndFrame = gA_FrameCache[client].aFrames.Length - 1;

    //Client isn't moving, so there's no need to redraw redundant frames
    if(iClosestFrame == gI_PrevFrame[client])
    {
        return;
    }

    //Fill in the missing frames from ClosestPos
    if((iClosestFrame - gI_PrevFrame[client]) > 1)
    {
        iClosestFrame = gI_PrevFrame[client] + 1;
    }

    gI_PrevFrame[client] = iClosestFrame;

    int lookAhead = iClosestFrame + gCV_NumAheadFrames.IntValue;

    if(iClosestFrame == iEndFrame)
    {
        return;
    }
    else if(lookAhead >= iEndFrame)
    {
        lookAhead -= (lookAhead - iEndFrame) + 1;
    }

    frame_t replay_prevframe, replay_frame;
    gA_FrameCache[client].aFrames.GetArray(lookAhead, replay_frame, sizeof(frame_t));
    gA_FrameCache[client].aFrames.GetArray(lookAhead <= 0 ? 0 : lookAhead - 1, replay_prevframe, sizeof(frame_t));

    DrawMyRoute(client, replay_prevframe, replay_frame, GetVelocityDifference(client, iClosestFrame));
}

void DrawMyRoute(int client, frame_t prev, frame_t cur, float velDiff)
{
    UpdateColor(client, velDiff);

    //Draw the client's routed path
    if(gB_ShowPath[client])
    {
        BeamEffect(client, prev.pos, cur.pos, 0.7, gI_PathSize[client] / float(MAX_BEAM_WIDTH), gI_PathColorIndex[client] == -1 ? gI_Color[client] : gI_ColorIndex[gI_PathColorIndex[client]]);
    }

    if(!gB_ShowJumps[client] || gA_JumpMarkerCache[client].Length < 1)
    {
        return;
    }

    int iClosestFrame = GetClientClosestFrame(client);

    //Find the closest jump marker to the client
    for(int i = 0; i < gA_JumpMarkerCache[client].Length; i++)
    {
        JumpMarker current;
        gA_JumpMarkerCache[client].GetArray(i, current, sizeof(current));

        if(current.frameNum >= iClosestFrame)
        {
            //Update the jump marker index, so we can draw the jump markers that are ahead of the client
            gI_JumpsIndex[client] = current.id;
            break;
        }
    }

    JumpMarker marker;
    gA_JumpMarkerCache[client].GetArray(gI_JumpsIndex[client], marker, sizeof(marker));
    marker.Draw(client, gI_ColorIndex[gI_JumpColorIndex[client]]);

    if(gI_JumpsAhead[client] == 0)
    {
        return;
    }

    int max = gA_JumpMarkerCache[client].Length;

    //For loop too expensive to use for every frame, so we hardcode the number of jumps ahead to draw
    if(gI_JumpsAhead[client] >= (MAX_JUMPS_AHEAD - 4) && gI_JumpsIndex[client] + 1 < max)
    {
        gA_JumpMarkerCache[client].GetArray(gI_JumpsIndex[client] + 1, marker, sizeof(marker));
        marker.Draw(client, gI_ColorIndex[gI_JumpColorIndex[client]]);
    }

    if(gI_JumpsAhead[client] >= (MAX_JUMPS_AHEAD - 3) && (gI_JumpsIndex[client] + 2 < max))
    {
        gA_JumpMarkerCache[client].GetArray(gI_JumpsIndex[client] + 2, marker, sizeof(marker));
        marker.Draw(client, gI_ColorIndex[gI_JumpColorIndex[client]]);
    }

    if(gI_JumpsAhead[client] >= (MAX_JUMPS_AHEAD - 2) && (gI_JumpsIndex[client] + 3 < max))
    {
        gA_JumpMarkerCache[client].GetArray(gI_JumpsIndex[client] + 3, marker, sizeof(marker));
        marker.Draw(client, gI_ColorIndex[gI_JumpColorIndex[client]]);
    }

    if(gI_JumpsAhead[client] >= (MAX_JUMPS_AHEAD - 1) && (gI_JumpsIndex[client] + 4 < max))
    {
        gA_JumpMarkerCache[client].GetArray(gI_JumpsIndex[client] + 4, marker, sizeof(marker));
        marker.Draw(client, gI_ColorIndex[gI_JumpColorIndex[client]]);
    }

    if(gI_JumpsAhead[client] >= MAX_JUMPS_AHEAD && (gI_JumpsIndex[client] + 5 < max))
    {
        gA_JumpMarkerCache[client].GetArray(gI_JumpsIndex[client] + 5, marker, sizeof(marker));
        marker.Draw(client, gI_ColorIndex[gI_JumpColorIndex[client]]);
    }
}

bool IsJump(frame_t prev, frame_t cur)
{
    return (!(cur.flags & FL_ONGROUND) && (prev.flags & FL_ONGROUND));
}

public void Shavit_OnTrackChanged(int client, int oldtrack, int newtrack)
{
    if(oldtrack != newtrack || gRT_RouteType[client] == RouteType_ServerRecord)
    {
        LoadMyRoute(client);
    }
    else
    {
        ResetMyRoute(client);
    }
}

public void Shavit_OnStyleChanged(int client, int oldstyle, int newstyle, int track, bool manual)
{
    if(oldstyle != newstyle || gRT_RouteType[client] == RouteType_ServerRecord)
    {
        LoadMyRoute(client);
    }
    else
    {
        ResetMyRoute(client);
    }
}

public void Shavit_OnWorldRecord(int client, int style, float time, int jumps, int strafes, float sync, int track, float oldwr, float oldtime, float perfs, float avgvel, float maxvel, int timestamp)
{
    for(int i = 1; i <= MaxClients; i++)
    {
        if(!IsValidClient(i) || IsFakeClient(i))
        {
            continue;
        }
        else if(style != Shavit_GetBhopStyle(i) && track != Shavit_GetClientTrack(i))
        {
            continue;
        }
        else if(gRT_RouteType[i] == RouteType_PersonalReplay && i != client)
        {
            continue;
        }

        //Update current user's route path to the new WR
        LoadMyRoute(i);
    }
}

public Action Shavit_OnTeleport(int client, int index)
{
    if(Shavit_GetTimerStatus(client) != Timer_Running || !gH_ClosestPos[client])
    {
        return Plugin_Continue;
    }

    ResetMyRoute(client, true);

    return Plugin_Continue;
}

public void Shavit_OnPersonalReplaySaved(int client, int style, int track, const char[] path)
{
    strcopy(gS_ReplayPath[client], PLATFORM_MAX_PATH, path);
    LoadMyRoute(client);
}

public void Shavit_OnPersonalReplayDeleted(int client)
{
    LoadMyRoute(client);
}

public void Shavit_OnRestart(int client, int track)
{
    ResetMyRoute(client);
}

void ResetMyRoute(int client, bool closestFrame = false)
{
    int iClosestFrame = -1;

    if(gB_ClosestPos && gH_ClosestPos[client] != null)
    {
        iClosestFrame = GetClientClosestFrame(client);
    }

    if(closestFrame)
    {
        UpdateColor(client, GetVelocityDifference(client, iClosestFrame));

        return;
    }

    gI_Color[client] = gI_ColorIndex[view_as<int>(GREEN)];
    gI_PrevStep[client] = 0;
    gI_PrevFrame[client] = iClosestFrame;
    gI_JumpsIndex[client] = 0;
}

/**
 * Sets up a point to point beam effect.
 *
 * @param client        Client to display the beam effect to.
 * @param start         Start position of the beam.
 * @param end           End position of the beam.
 * @param duration      Time duration of the beam.
 * @param width         Initial beam width.
 * @param EndWidth      Final beam width.
 * @param color         Color array (r, g, b, a).
 * @param amplitude     Beam amplitude.
 * @param speed         Speed of the beam.
 */
public void BeamEffect(int client, float start[3], float end[3], float duration, float width, const int color[4])
{
    TE_SetupBeamPoints(start, end, gI_BeamSprite, 0, 0, 5, duration, width, width, 0, 0.0, color, 0);
    TE_SendToClient(client);
}

void UpdateColor(int client, float velDiff)
{
    int stepsize = RoundToFloor(velDiff * gCV_VelDiffScalar.FloatValue);

    //Prevent the color from changing too fast
    if((gI_PrevStep[client] - stepsize) == 0)
    {
        return;
    }

    gI_PrevStep[client] = stepsize;

    //Positive/Negative step size means client is faster/slower than the replay
    gI_Color[client][0] -= stepsize;              //r (red), positive/negative step size decreases/increases the value of red
    gI_Color[client][1] += stepsize;              //g (green), positive/negative step size increases/decreases the value of green
    gI_Color[client][2] = 0;                      //b (blue)
    gI_Color[client][3] = gI_PathOpacity[client]; //a (alpha)

    if(gI_Color[client][0] <= 0)
    {
        gI_Color[client][0] = 0;
    }
    else if(gI_Color[client][0] >= 255)
    {
        gI_Color[client][0] = 255;
    }

    if(gI_Color[client][1] <= 0)
    {
        gI_Color[client][1] = 0;
    }
    else if(gI_Color[client][1] >= 255)
    {
        gI_Color[client][1] = 255;
    }
}

float GetVelocityDifference(int client, int frame)
{
    float clientVel[3];
    GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", clientVel);

    float fReplayPrevPos[3], fReplayClosestPos[3];
    gA_FrameCache[client].aFrames.GetArray(frame, fReplayClosestPos, 3);
    gA_FrameCache[client].aFrames.GetArray(frame <= 0 ? 0 : frame - 1, fReplayPrevPos, 3);

    int style = Shavit_GetBhopStyle(client);

    float replayVel[3];
    MakeVectorFromPoints(fReplayClosestPos, fReplayPrevPos, replayVel);
    ScaleVector(replayVel, (1.0 / GetTickInterval()) / Shavit_GetStyleSettingFloat(style, "speed") / Shavit_GetStyleSettingFloat(style, "timescale"));

    return (SquareRoot(Pow(clientVel[0], 2.0) + Pow(clientVel[1], 2.0))) - (SquareRoot(Pow(replayVel[0], 2.0) + Pow(replayVel[1], 2.0)));
}

void GetClientRouteType(int client, char[] buffer, int length)
{
    switch(gRT_RouteType[client])
    {
        case RouteType_Auto:
        {
            strcopy(buffer, length, "Automatically");
        }

        case RouteType_PersonalReplay:
        {
            strcopy(buffer, length, "Personal Replay");
        }

        case RouteType_ServerRecord:
        {
            strcopy(buffer, length, "Server Record");
        }
    }
}

void GetPathType(int client, char[] buffer, int length)
{
    switch(gI_PathColorIndex[client])
    {
        case -1:
        {
            strcopy(buffer, length, "Velocity Difference");
        }

        default:
        {
            strcopy(buffer, length, "Solid Color");
        }
    }
}

bool UpdateClientCookie(int client, Cookie cookie, const char[] newvalue = "")
{
    char value[4];
    cookie.Get(client, value, sizeof(value));

    if(newvalue[0] == '\0')
    {
        cookie.Set(client, (value[0] == '1') ? "0" : "1");
    }
    else
    {
        cookie.Set(client, newvalue);
    }

    return (value[0] == '1') ? false : true;
}

bool CreateMyRouteMenu(int client, int page = 0)
{
    Menu menu = new Menu(MyRoute_MenuHandler);
    menu.SetTitle("Route Settings:\n");

    char type[16];
    GetClientRouteType(client, type, sizeof(type));

    menu.AddItem("enabled", gB_ShowRoute[client] ? "[X] Enabled" : "[ ] Enabled");

    char display[64];
    FormatEx(display, sizeof(display), "[%s]", type);

    menu.AddItem("type", display);
    menu.AddItem("-1", "", ITEMDRAW_SPACER);
    menu.AddItem("pathsettings", "[Path Settings]");
    menu.AddItem("jumpmarker", "[Jump Marker]");

    return menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

public int MyRoute_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            if(StrEqual(info, "enabled"))
            {
                gB_ShowRoute[param1] = UpdateClientCookie(param1, gH_ShowRouteCookie);
                CreateMyRouteMenu(param1);
            }
            else if(StrEqual(info, "type"))
            {
                if(++gRT_RouteType[param1] >= RouteType_Size)
                {
                    gRT_RouteType[param1] = RouteType_Auto;
                }

                char newvalue[4];
                IntToString(view_as<int>(gRT_RouteType[param1]), newvalue, sizeof(newvalue));
                UpdateClientCookie(param1, gH_RouteTypeCookie, newvalue);

                LoadMyRoute(param1);

                CreateMyRouteMenu(param1);
            }
            else if(StrEqual(info, "pathsettings"))
            {
                CreatePathSettingsMenu(param1);
            }
            else if(StrEqual(info, "jumpmarker"))
            {
                CreateJumpMarkersMenu(param1);
            }
        }
    }

    return 0;
}

bool CreatePathSettingsMenu(int client, int page = 0)
{
    Menu menu = new Menu(PathSettings_MenuHandler);
    menu.SetTitle("Path Settings:\n");

    char display[64];

    menu.AddItem("enabled", gB_ShowPath[client] ? "[X] Enabled" : "[ ] Enabled");
    menu.AddItem("-1", "", ITEMDRAW_SPACER);

    char type[32];
    GetPathType(client, type, sizeof(type));

    FormatEx(display, sizeof(display), "Path Type: [%s]", type);
    menu.AddItem("path_type", display);

    if(gI_PathColorIndex[client] != -1)
    {
        menu.AddItem("path_color", "[Path Colors]");
    }

    menu.AddItem("-1", "", ITEMDRAW_SPACER);

    FormatEx(display, sizeof(display), "Size: [%d]", gI_PathSize[client]);
    menu.AddItem("path_size", display, ITEMDRAW_DISABLED);
    menu.AddItem("increment", "++ Path Size ++");
    menu.AddItem("decrement", "-- Path Size --");

    FormatEx(display, sizeof(display), "Opacity: [%d]", gI_PathOpacity[client]);
    menu.AddItem("path_opacity", display, ITEMDRAW_DISABLED);
    menu.AddItem("opacity_increment", "++ Path Opacity ++");
    menu.AddItem("opacity_decrement", "-- Path Opacity --");

    menu.ExitBackButton = true;
    return menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

public int PathSettings_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            char newvalue[4];

            if(StrEqual(info, "enabled"))
            {
                gB_ShowPath[param1] = UpdateClientCookie(param1, gH_ShowPathCookie);
            }
            else if(StrEqual(info, "increment") || StrEqual(info, "decrement"))
            {
                int value = (StrEqual(info, "increment")) ? 1 : -1;

                gI_PathSize[param1] += value;

                if(gI_PathSize[param1] > MAX_BEAM_WIDTH)
                {
                    gI_PathSize[param1] = 1;
                }
                else if(gI_PathSize[param1] <= 0)
                {
                    gI_PathSize[param1] = MAX_BEAM_WIDTH;
                }

                IntToString(gI_PathSize[param1], newvalue, sizeof(newvalue));
                UpdateClientCookie(param1, gH_PathSizeCookie, newvalue);
            }
            else if(StrEqual(info, "path_type"))
            {
                if(gI_PathColorIndex[param1] == -1)
                {
                    gI_PathColorIndex[param1] = 0;
                }
                else
                {
                    gI_PathColorIndex[param1] = -1;
                }

                IntToString(gI_PathColorIndex[param1], newvalue, sizeof(newvalue));
                UpdateClientCookie(param1, gH_PathColorCookie, newvalue);
            }
            else if(StrEqual(info, "path_color"))
            {
                CreateColorMenu(param1, view_as<Color>(gI_PathColorIndex[param1]), PathColor_MenuHandler);

                return 0;
            }
            else if(StrEqual(info, "opacity_increment") || StrEqual(info, "opacity_decrement"))
            {
                int value = (StrEqual(info, "opacity_increment")) ? 50 : -50;

                gI_PathOpacity[param1] += value;

                if(gI_PathOpacity[param1] > 250)
                {
                    gI_PathOpacity[param1] = 0;
                }
                else if(gI_PathOpacity[param1] < 0)
                {
                    gI_PathOpacity[param1] = 250;
                }

                IntToString(gI_PathOpacity[param1], newvalue, sizeof(newvalue));
                UpdateClientCookie(param1, gH_PathOpacityCookie, newvalue);
            }

            CreatePathSettingsMenu(param1, menu.Selection);
        }

        case MenuAction_Cancel:
        {
            if(param2 == MenuCancel_ExitBack)
            {
                CreateMyRouteMenu(param1);
            }
        }
    }

    return 0;
}

public int PathColor_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            int color = StringToInt(info);

            char data[2];
            IntToString(color, data, sizeof(data));

            gI_PathColorIndex[param1] = color;
            gH_PathColorCookie.Set(param1, data);

            CreateColorMenu(param1, view_as<Color>(color), PathColor_MenuHandler);
        }

        case MenuAction_Cancel:
        {
            if(param2 == MenuCancel_ExitBack)
            {
                CreatePathSettingsMenu(param1);
            }
        }
    }

    return 0;
}

bool CreateJumpMarkersMenu(int client, int page = 0)
{
    Menu menu = new Menu(JumpMarkers_MenuHandler);
    menu.SetTitle("Jump Marker Settings:\n");

    char display[64];

    menu.AddItem("enabled", gB_ShowJumps[client] ? "[X] Enabled" : "[ ] Enabled");
    menu.AddItem("-1", "", ITEMDRAW_SPACER);

    FormatEx(display, sizeof(display), "Size: [%d]", gI_JumpSize[client]);
    menu.AddItem("marker_size", display, ITEMDRAW_DISABLED);
    menu.AddItem("increment", "++ Jump Marker Size ++");
    menu.AddItem("decrement", "-- Jump Marker Size --");

    menu.AddItem("-1", "", ITEMDRAW_SPACER);

    FormatEx(display, sizeof(display), "[Marker Colors]");
    menu.AddItem("marker_color", display);

    FormatEx(display, sizeof(display), "# Jumps Ahead: [%d]", gI_JumpsAhead[client]);
    menu.AddItem("jumps_ahead", display);

    menu.ExitBackButton = true;
    return menu.DisplayAt(client, page, MENU_TIME_FOREVER);
}

public int JumpMarkers_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            char newvalue[4];

            if(StrEqual(info, "enabled"))
            {

                gB_ShowJumps[param1] = UpdateClientCookie(param1, gH_ShowJumpsCookie);
            }
            else if(StrEqual(info, "increment") || StrEqual(info, "decrement"))
            {
                int value = (StrEqual(info, "increment")) ? 1 : -1;

                gI_JumpSize[param1] += value;

                if(gI_JumpSize[param1] > MAX_JUMP_SIZE)
                {
                    gI_JumpSize[param1] = 1;
                }
                else if(gI_JumpSize[param1] <= 0)
                {
                    gI_JumpSize[param1] = MAX_JUMP_SIZE;
                }

                IntToString(gI_JumpSize[param1], newvalue, sizeof(newvalue));
                UpdateClientCookie(param1, gH_JumpSizeCookie, newvalue);
            }
            else if(StrEqual(info, "marker_color"))
            {
                CreateColorMenu(param1, view_as<Color>(gI_JumpColorIndex[param1]), JumpMarkerColor_MenuHandler);

                return 0;
            }
            else if(StrEqual(info, "jumps_ahead"))
            {
                if(gI_JumpsAhead[param1] + 1 <= MAX_JUMPS_AHEAD)
                {
                    gI_JumpsAhead[param1]++;
                }
                else
                {
                    gI_JumpsAhead[param1] = 0;
                }

                PrintDebug("Jumps Ahead: [%d]", gI_JumpsAhead[param1]);

                IntToString(gI_JumpsAhead[param1], newvalue, sizeof(newvalue));
                UpdateClientCookie(param1, gH_JumpsAheadCookie, newvalue);
            }

            CreateJumpMarkersMenu(param1, menu.Selection);
        }

        case MenuAction_Cancel:
        {
            if(param2 == MenuCancel_ExitBack)
            {
                CreateMyRouteMenu(param1);
            }
        }
    }

    return 0;
}

public int JumpMarkerColor_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            int color = StringToInt(info);

            char data[2];
            IntToString(color, data, sizeof(data));

            gI_JumpColorIndex[param1] = color;
            gH_JumpMarkerColorCookie.Set(param1, data);

            CreateColorMenu(param1, view_as<Color>(color), JumpMarkerColor_MenuHandler);
        }

        case MenuAction_Cancel:
        {
            if(param2 == MenuCancel_ExitBack)
            {
                CreateJumpMarkersMenu(param1);
            }
        }
    }

    return 0;
}

public Action Command_Route(int client, int args)
{
    if(!IsValidClient(client))
    {
        return Plugin_Handled;
    }

    if(!CreateMyRouteMenu(client))
    {
        LogError("Failed to create menu for [%N]", client);
    }

    return Plugin_Handled;
}

public Action Command_ResetRoute(int client, int args)
{
    if(!IsValidClient(client, true))
    {
        return Plugin_Handled;
    }

    ResetMyRoute(client);

    return Plugin_Handled;
}

public Action Command_Debug(int client, int args)
{
    gB_Debug = !gB_Debug;
    ReplyToCommand(client, "Debug Mode: %s", gB_Debug ? "Enabled" : "Disabled");

    return Plugin_Handled;
}

stock void PrintDebug(const char[] message, any ...)
{
    if(!gB_Debug)
    {
        return;
    }

    char buffer[255];
    VFormat(buffer, sizeof(buffer), message, 2);

    if(strlen(buffer) >= 255)
    {
        PrintToServer(buffer);
    }

    for(int client = 1; client <= MaxClients; client++)
    {
        if(IsClientConnected(client) && CheckCommandAccess(client, "sm_myroute_debug", ADMFLAG_ROOT))
        {
            if(strlen(buffer) >= 255)
            {
                PrintToConsole(client, buffer);
            }
            else
            {
                PrintToChat(client, buffer);
            }
        }
    }
}

bool LoadReplayCache2(frame_cache_t cache, int track, const char[] path, const char[] mapname)
{
    bool success = false;
    replay_header_t header;
    File fFile = ReadReplayHeader(path, header);

    if (fFile != null)
    {
        if (header.iReplayVersion > REPLAY_FORMAT_SUBVERSION)
        {
            // not going to try and read it
        }
        else if (header.iReplayVersion < 0x03 || (StrEqual(header.sMap, mapname, false) && header.iTrack == track))
        {
            success = ReadReplayFrames(fFile, header, cache);
        }

        delete fFile;
    }

    return success;
}
