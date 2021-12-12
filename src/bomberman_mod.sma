/* 	
	Bomberman Mod
	Versión 1.13
	Autora: Mia2904
	Lima, Perú. 2015 - 2020.
	
	Créditos:
	ErikMav94 - Me ayudó un montón con el mod en sus tiempos de desarrollo.
	jay-jay - Los bonitos models.
	Exolent - Utilizo algo de código de su plugin Team Manager All-In-One.
	Totopizza - Me ayudó a probar el mod con personas reales y fixear algunos bugs que había pasado por alto.
	metita - Ayudó a probar el modo (2020), búsqueda de bugs, sugerencias e ideas, modificación de modelos nuevos.
	
	Historial de cambios:
	
	* 0.1	-	14/03/2015	
	- Primera versión. Bombas.
	
	* 0.2	-	15/03/2015
	- Personajes.
	- Mapa con cajas.
	- Las bombas remueven las cajas.
	
	* 0.3	-	18/03/2015
	- Extra items.
	- Salones de juego.
	
	* 0.3.1	-	19/03/2015
	- Añadido código para impedir que un jugador espectee.
	- Mod lanzado en Xtreme-Addictions.
	
	* 1.0	-	23/10/2016
	- Primera versión pública.
	- Corregido el código de impedir que un jugador espectee.
	- Corregidos varios bugs al plantar bombas muy seguido.
	- Corregido bug que hacía explotar la bomba de inmediato al intentar lanzarla.
	
	* 1.01	-	30/10/2016
	- Pequeñas optimizaciones en el código.
	- Mejora en la cinemática de las bombas en el aire.
	- Comentarios en la fuente para un mejor entendimiento.
	
	* 1.10	-	14/10/2017
	- Añadido código para evitar la visibilidad de las cajas cuando no sea necesario.
	- Jointeam reparado.
	- Ya no se requiere Orpheu.
	- Score arreglado.
	- Configuración de cámara en el menú de juego.
	
	* 1.11 - 09/01/2020
	- Score y menú de juego reparados.
	- Cinemática de las bombas en el aire mejorada, acorde al juego original.
	
	* 1.12 - 05/05/2020
	- Algoritmo de distribucion de powerups recodeado.
	- Código limpiado.
	- Removido código para controlar jointeam y chooseteam. Ahora esto debe hacerse con cvars de ReGameDLL.
	
	* 1.13 - 01/06/2020
	- Agregadas varias funciones para tener una buena experiencia de juego con la camara desde arriba.
		
	Algunos recursos utilizados en este mod pertenecen a Hudson Soft Co., Ltd.
*/

#include <amxmodx>
#include <cstrike>
#include <engine>
#include <fakemeta>
#include <fun>
#include <hamsandwich>
#include <xs>

#if AMXX_VERSION_NUM < 183
#include <dhudmessage>
#define client_disconnected client_disconnect
#endif

#pragma semicolon 1;

enum _:POWERUPS // Don't touch this!
{
	MAXBOMBS = 0,
	FIRE,
	SKATE,
	HEART,
	GLOVES,
	KICK,
	FULL_FIRE
};

/*================================================================================
 [Editable constants]
=================================================================================*/

const Float:PLANT_DELAY = 0.1; // Time interval in seconds, since E is pressed until the bomb is placed.
const Float:DETONATE_DELAY = 2.5; // Time in seconds it takes a bomb to explode (it's 2.5 seconds in Super Bomberman).
const Float:KICK_SPEED = 500.0; // Speed the bomb will move when kicked (it's actually lower due to friction).
const Float:THROW_SPEED = 200.0; // Horizontal speed the bomb will move when thrown.
const Float:BOMB_Z_POS = 70.0; // Height (absolute Z coord) the bombs will be placed at when planted. I suggest not to edit this.
const Float:EXP_RADIUS = 12.0; // Explosion radius in each block, used to find victims.
const Float:GRAVITY = 1700.0; // Server gravity. Kind of bugfix because the blocks in the map are too small and can be climbed without this.

// How many powerups are spawned in each round
new const MAX_ITEMS[POWERUPS] = { 
		8 // Bomb
	,	6 // Fire
	,	8 // Skates (for extra speed)
	,	2 // Extra live
	,	2 // Gloves
	,	2 // Shoes (for kicking bombs)
	,	1 // Full fire
};

// Amount of blank spaces (not spawned boxes) when the map is generated
const MAX_BLANKS = 15;

// How many boxes are created in each iteration when starting a new round (prevents packet overflow, reduce if too laggy)
const LOOP_BOXES = 15;

new const BOMB_CLASSNAME[] = "BM_BOMB";
new const BOX_CLASSNAME[] = "BM_BOX";
stock const WALL_CLASSNAME[] = "BM_WALL";
new const POWERUP_CLASSNAME[] = "BM_POWERUP";

new const BOMB_MODEL[] = "models/bomberman_mod/w_bomb.mdl";
new const BLOCK_MODEL[] = "models/bomberman_mod/block.mdl";
new const PLAYER_MODEL[] = "bomberman"; // models/player/bomberman/bomberman.mdl

new const BOMB_V_MODEL[] = "models/bomberman_mod/v_throw_bomb.mdl";
new const DEFAULT_V_MODEL[] = "models/bomberman_mod/v_hands.mdl";

new const SPRITE_BOMB[] = "sprites/bomberman_mod/bomb.spr";
new const SPRITE_FIRE[] = "sprites/bomberman_mod/fire.spr";
new const SPRITE_FULL_FIRE[] = "sprites/bomberman_mod/full_fire.spr";
new const SPRITE_GLOVES[] = "sprites/bomberman_mod/glove.spr";
new const SPRITE_HEART[] = "sprites/bomberman_mod/heart.spr";
new const SPRITE_KICK[] = "sprites/bomberman_mod/kick.spr";
new const SPRITE_SKATE[] = "sprites/bomberman_mod/skate.spr";

new const SOUND_BATTLE_BG[][] = 
{
	"bomberman_mod/bm_battle_1.mp3",
	"bomberman_mod/bm_battle_2.mp3",
	"bomberman_mod/bm_battle_3.mp3",
	"bomberman_mod/bm_battle_4.mp3",
	"bomberman_mod/bm_battle_5.mp3",
	"bomberman_mod/bm_battle_6.mp3",
	"bomberman_mod/bm_battle_7.mp3",
	"bomberman_mod/bm_battle_8.mp3"
};

new const SOUND_DIE[] = "bomberman_mod/die.wav";
new const SOUND_EXPLODE[] = "bomberman_mod/explode.wav";
new const SOUND_BOUNCE[] = "bomberman_mod/bouncing.wav";
new const SOUND_INFECT[] = "bomberman_mod/infect.wav";
new const SOUND_ITEM[] = "bomberman_mod/item.wav";
new const SOUND_KICK[] = "bomberman_mod/kick.wav";
new const SOUND_PLANT[] = "bomberman_mod/plant.wav";
new const SOUND_THROW[] = "bomberman_mod/throw.wav";
new const SOUND_WIN[] = "bomberman_mod/win.wav";

/*================================================================================
 [Variables / Constantes / Macros]
=================================================================================*/

new Float:g_nextplant[33], g_bombs[33], g_holding[33];
new g_SprFlame, g_menucallback;
new g_musicenabled, g_camera[33], g_direction[33], g_battle[33], g_character[33], g_canbattle[33], g_alive[33], g_inbattle[8], g_freeze[8], g_music[8], g_score[33], g_boxdata[8][225 char];
new g_msgHideWeapon, g_msgSayText;
new g_menuintro, g_menuinfo, g_menuconfirm;

#define music_enabled(%0) (g_musicenabled & (1<<(%0&31)))
#define music_toggle(%0) (g_musicenabled ^= (1<<(%0&31)))
#define music_clear(%0) (g_musicenabled &= ~(1<<(%0&31)))
#define music_activate(%0) (g_musicenabled |= (1<<(%0&31)))

new g_powerups[33][POWERUPS-1];

enum
{
	STATUS_DISCONNECTED = 0,
	STATUS_CONNECTED,
	STATUS_JOINING,
	STATUS_JOINED
};

new g_status[33];

enum (+= 100)
{
	BOMB_CONST = 5001,
	BLOCK_CONST,
	POWERUP_CONST,
	TASK_START,
	TASK_SCORES,
	TASK_DISAPPEAR,
	TASK_END
};

// Those constants were not defined in AMXX 1.8.2 (HIDEHUD_*)
const HIDE_RHA = (1<<3);
const HIDE_MONEY = (1<<5);
const HIDE_CROSSHAIR = (1<<6);
const HIDE_UNNEEDED = HIDE_MONEY | HIDE_RHA | HIDE_CROSSHAIR;

new g_regamedll;
new g_msgShowMenu;
#define m_iUserPrefs 510
#define PREFS_VGUIMENUS (1<<0)
#define HasVGUIMenus(%1) (get_pdata_int(%1, m_iUserPrefs) & PREFS_VGUIMENUS)
#define SetVGUIMenus(%1) set_pdata_int(%1, m_iUserPrefs, (get_pdata_int(%1, m_iUserPrefs) | PREFS_VGUIMENUS))
#define RemoveVGUIMenus(%1) set_pdata_int(%1, m_iUserPrefs, (get_pdata_int(%1, m_iUserPrefs) & ~PREFS_VGUIMENUS))

#define PLUGIN "Bomberman Mod"
#define VERSION "1.13"
#define AUTHOR "Mia2904"

#define REPOSITORY "https://github.com/Mia2904/Bomberman-Mod"
#define SUPPORT_THREAD "https://amxmodx-es.com/showthread.php?tid=13587"

/*================================================================================
 [Inicio del plugin]
=================================================================================*/

public plugin_precache()
{
	for (new i = 0; i < sizeof(SOUND_BATTLE_BG); i++)
		precache_sound(SOUND_BATTLE_BG[i]);
	
	precache_model("models/rpgrocket.mdl");
	
	precache_sound(SOUND_DIE);
	precache_sound(SOUND_EXPLODE);
	precache_sound(SOUND_BOUNCE);
	precache_sound(SOUND_INFECT);
	precache_sound(SOUND_ITEM);
	precache_sound(SOUND_KICK);
	precache_sound(SOUND_PLANT);
	precache_sound(SOUND_THROW);
	precache_sound(SOUND_WIN);
	
	precache_model(BOMB_MODEL);
	precache_model(BLOCK_MODEL);
	
	new mdlfullpath[80];
	formatex(mdlfullpath, charsmax(mdlfullpath), "models/player/%s/%s.mdl", PLAYER_MODEL, PLAYER_MODEL);
	precache_model(mdlfullpath);
	
	precache_model(BOMB_V_MODEL);
	precache_model(DEFAULT_V_MODEL);
	
	precache_model(SPRITE_BOMB);
	precache_model(SPRITE_FIRE);
	precache_model(SPRITE_FULL_FIRE);
	precache_model(SPRITE_GLOVES);
	precache_model(SPRITE_HEART);
	precache_model(SPRITE_KICK);
	precache_model(SPRITE_SKATE);
	
	g_SprFlame = precache_model("sprites/fexplo1.spr");
}

public plugin_init()
{
	register_plugin(PLUGIN, VERSION, AUTHOR);
	
	new map[32];
	get_mapname(map, 31);
	if (containi(map, "bomberman") == -1)
	{
		set_fail_state("Not in bomberman map.");
		return;
	}
	
	g_msgShowMenu = get_user_msgid("ShowMenu");
	g_msgHideWeapon = get_user_msgid("HideWeapon");
	g_msgSayText = get_user_msgid("SayText");
	
	register_message(get_user_msgid("ShowMenu"), "message_showmenu");
	register_message(get_user_msgid("VGUIMenu"), "message_vguimenu");
	register_message(g_msgHideWeapon, "message_hideweapon");
	register_event("ResetHUD", "event_ResetHUD", "b");
	register_clcmd("say_team", "clcmd_say_team");
	register_clcmd("say /cam", "clcmd_say_cam");
	
	register_clcmd("radio1", "clcmd_radio");
	register_clcmd("radio2", "clcmd_radio");
	register_clcmd("radio3", "clcmd_radio");
	
	register_clcmd("chooseteam", "clcmd_chooseteam");
	register_clcmd("jointeam", "clcmd_chooseteam");
	
	RegisterHam(Ham_Spawn, "player", "fw_Spawn", 1);
	RegisterHam(Ham_Killed, "player", "fw_Killed", 1);
	
	register_forward(FM_CmdStart, "fw_CmdStart", 1);
	register_forward(FM_EmitSound, "fw_EmitSound", 0);
	register_forward(FM_AddToFullPack, "fw_AddToFullPack_Pre", 0);
	
	register_think(BOMB_CLASSNAME, "fw_BombThink");
	register_think(POWERUP_CLASSNAME, "fw_PowerUpThink");
	register_touch(BOMB_CLASSNAME, "player", "fw_BombTouch");
	register_touch(POWERUP_CLASSNAME, "player", "fw_PowerUpTouch");
	
	g_menucallback = menu_makecallback("cb_item_block");
	
	set_msg_block(get_user_msgid("ScoreInfo"), BLOCK_SET);
	set_msg_block(get_user_msgid("ClCorpse"), BLOCK_SET);

	register_dictionary("bomberman_mod.txt");
}

public plugin_cfg()
{
	// Creacion de los menus estaticos
	new szMenuItem[128];

	formatex(szMenuItem, charsmax(szMenuItem), "\y%L^n%L", LANG_PLAYER, "MENU_TAG", LANG_PLAYER, "MENU_INTRO_TITLE");
	g_menuintro = menu_create(szMenuItem, "menu_intro");
	formatex(szMenuItem, charsmax(szMenuItem), "%L", LANG_PLAYER, "MENU_INTRO_JOIN");
	menu_additem(g_menuintro, szMenuItem);
	formatex(szMenuItem, charsmax(szMenuItem), "%L^n", LANG_PLAYER, "MENU_INTRO_SPECT");
	menu_additem(g_menuintro, szMenuItem);
	formatex(szMenuItem, charsmax(szMenuItem), "%L", LANG_PLAYER, "MENU_INTRO_INFO");
	menu_additem(g_menuintro, szMenuItem);
	menu_setprop(g_menuintro, MPROP_EXIT, MEXIT_NEVER);
	
	formatex(szMenuItem, charsmax(szMenuItem), "\y%L^n%L", LANG_PLAYER, "MENU_TAG", LANG_PLAYER, "MENU_CONFIRM_TITLE");
	g_menuconfirm = menu_create(szMenuItem, "menu_confirm");
	formatex(szMenuItem, charsmax(szMenuItem), "%L", LANG_PLAYER, "MENU_CONFIRM_YES");
	menu_additem(g_menuconfirm, szMenuItem);
	formatex(szMenuItem, charsmax(szMenuItem), "%L^n", LANG_PLAYER, "MENU_CONFIRM_NO");
	menu_additem(g_menuconfirm, szMenuItem);
	menu_setprop(g_menuconfirm, MPROP_EXIT, MEXIT_NEVER);
	
	formatex(szMenuItem, charsmax(szMenuItem), "\y%L^n%L", LANG_PLAYER, "MENU_TAG", LANG_PLAYER, "MENU_INFO_TITLE");
	g_menuinfo = menu_create(szMenuItem, "menu_info");
	formatex(szMenuItem, charsmax(szMenuItem), "%L", LANG_PLAYER, "MENU_INFO_CHOOSE_ROOM");
	menu_additem(g_menuinfo, szMenuItem);
	formatex(szMenuItem, charsmax(szMenuItem), "%L", LANG_PLAYER, "MENU_INFO_HOW_TO");
	menu_additem(g_menuinfo, szMenuItem);
	formatex(szMenuItem, charsmax(szMenuItem), "%L", LANG_PLAYER, "MENU_INFO_ITEMS");
	menu_additem(g_menuinfo, szMenuItem);
	formatex(szMenuItem, charsmax(szMenuItem), "%L^n", LANG_PLAYER, "MENU_INFO_THROW");
	menu_additem(g_menuinfo, szMenuItem);
	formatex(szMenuItem, charsmax(szMenuItem), "%L^n", LANG_PLAYER, "MENU_INFO_ABOUT", LANG_PLAYER, "MENU_TAG");
	menu_additem(g_menuinfo, szMenuItem);
	formatex(szMenuItem, charsmax(szMenuItem), "%L", LANG_PLAYER, "MENU_OPT_BACK");
	menu_additem(g_menuinfo, szMenuItem);	
	menu_setprop(g_menuinfo, MPROP_EXIT, MEXIT_NEVER);
	
	g_regamedll = cvar_exists("mp_round_infinite");
	
	// Task para configurar cvars
	set_task(1.0, "set_cvars");
}

public set_cvars()
{
	set_cvar_num("mp_limitteams", 0);
	set_cvar_num("mp_autoteambalance", 0);
	set_cvar_num("mp_autokick", 0);
	set_cvar_num("mp_tkpunish", 0);
	set_cvar_num("mp_footsteps", 0);
	
	// Con gravity 800 se puede subir a las cajas
	set_cvar_float("sv_gravity", GRAVITY);

	// Cvars ReGameDLL
	if (g_regamedll)
	{
		set_cvar_num("mp_round_infinite", 1);
		set_cvar_num("mp_max_teamkills", 0);
		set_cvar_num("mp_roundrespawn_time", 0);
		set_cvar_num("mp_auto_join_team", 1);
		set_cvar_string("humans_join_team", "ANY");
	}
	
	// Tasks para huds de poderes y puntajes
	set_task(0.1, "task_hud", .flags="b");
	set_task(0.3, "task_hud2", .flags="b");
	set_task(0.2, "task_show_scores", .flags="b");
}

/*================================================================================
 [Eventos / Forwards de AMXX]
=================================================================================*/

public client_putinserver(id)
{
	g_status[id] = STATUS_CONNECTED;
	reset_vars(id, 1);
}

public client_disconnected(id)
{
	g_status[id] = STATUS_DISCONNECTED;
	
	new room;
	room = g_battle[id];
	
	// Reseteamos las variables
	reset_vars(id, 1);
	
	// No hay lios si el jugador no estaba en una sala.
	if (!room)
		return;
	
	check_endround(room, 1);
}

// Evitar el menu de seleccion de equipo
public message_vguimenu(junk1, junk2, id)
{
	const OFFSET_VGUI_JOINTEAM = 2;
	const OFFSET_VGUI_JOINCLASS1 = 26;
	const OFFSET_VGUI_JOINCLASS2 = 27;
	
	junk1 = get_msg_arg_int(1);
	
	if (junk1 == OFFSET_VGUI_JOINTEAM || junk1 == OFFSET_VGUI_JOINCLASS1 || junk1 == OFFSET_VGUI_JOINCLASS2)
	{
		if (g_status[id] >= STATUS_JOINING)
			show_menu_game(id);
		else
			show_menu_intro(id);
		
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

// Lo mismo que arriba, pero para oldemnu
public message_showmenu(junk1, junk2, id)
{
	static szCode[32];
	get_msg_arg_string(4, szCode, charsmax(szCode));
	
	if (contain(szCode, "#Team") != -1 || equal(szCode, "#Terrorist_Select") || equal(szCode, "#CT_Select"))
	{
		if (g_status[id] >= STATUS_JOINING)
			show_menu_game(id);
		else
			show_menu_intro(id);
		
		return PLUGIN_HANDLED;
	}
	
	return PLUGIN_CONTINUE;
}

// Comando "chooseteam"
public clcmd_chooseteam(id)
{
	switch (g_status[id])
	{
		// Si el jugador ya está jugando y por alguna razón mandó un jointeam a la consola
		case STATUS_JOINED, STATUS_JOINING:
		{
			show_menu_game(id);
		}
		// Si no está en alguna sala
		case STATUS_CONNECTED:
		{
			show_menu_intro(id);
		}
	}
	
	return PLUGIN_HANDLED;
}

// Ocultar el dinero, radar, vida, armadura
public message_hideweapon(junk1, junk2, id)
{
	set_msg_arg_int(1, ARG_BYTE, HIDE_UNNEEDED);
}

// Ocultar el dinero, radar, vida, armadura
public event_ResetHUD(id)
{
	if (g_status[id] < STATUS_CONNECTED)
		return;
	
	message_begin(MSG_ONE_UNRELIABLE, g_msgHideWeapon, _, id);
	write_byte(HIDE_UNNEEDED);
	message_end();
}

// Chat de salas
public clcmd_say_team(id)
{
	static arg[192], name[32];
	read_args(arg, 191);
	
	if (!arg[0] || (arg[0] == ' ' && (!arg[1] || arg[1] == ' ')) || !g_battle[id])
		return PLUGIN_HANDLED_MAIN;
	
	replace_all(arg, 191, "%", " ");
	replace_all(arg, 191, "#", " ");
	remove_quotes(arg);
	
	get_user_name(id, name, 31);
	
	format(arg, 191, "^x04%L^x03 %s^x01 : %s", LANG_PLAYER, "CHAT_ROOM", g_battle[id], name, arg);
	
	new room = g_battle[id];
	for (new i = 1; i <= 32; i++)
	{
    	// Si este jugador esta jugando en la sala
		if (g_battle[i] == room)
			print_color(i, arg);
	}
	
	return PLUGIN_HANDLED_MAIN;
}

public clcmd_say_cam(id)
{
	menu_game(id, 0, 2);
	return PLUGIN_CONTINUE;
}

public clcmd_radio(id)
{
	return PLUGIN_HANDLED;
}

/*================================================================================
 [Huds / Prints / Tasks / Menus]
=================================================================================*/

// Mostrar el hud a cada jugador, 8 a la vez para evitar sobrecargas
public task_hud()
{
	static id, num = 0, text[150], i, iTextLen;
	
	set_dhudmessage(0, 255, 0, -1.0, 0.70, 0, 0.5 , 0.5, 0.01, 0.01); 
	for (id = num; id <= 32; id += 4)
	{
		if (g_status[id] != STATUS_JOINED || !g_canbattle[id])
			continue;
		
		iTextLen = formatex(text, charsmax(text), "%L^n[", id, "HUD_INFO_BOMBS");
		for (i = 1; i <= g_powerups[id][MAXBOMBS]-g_bombs[id]; i++)
			iTextLen = add(text, charsmax(text), "•");
		for (i = g_powerups[id][MAXBOMBS]-g_bombs[id]; i < g_powerups[id][MAXBOMBS]; i++)
			iTextLen = add(text, charsmax(text), "_");
		
		iTextLen += formatex(text[iTextLen], charsmax(text) - iTextLen, "]^n%L^n[", id, "HUD_INFO_LIFES");
		for (i = 1; i <= g_powerups[id][HEART]; i++)
			iTextLen = add(text, charsmax(text), "•");
		
		formatex(text[iTextLen], charsmax(text) - iTextLen, "]^n%L^n[•", id, "HUD_INFO_FIRE");
		for (i = 1; i <= g_powerups[id][FIRE]; i++)
			add(text, charsmax(text), "•");
		
		add(text, charsmax(text), "]");
		show_dhudmessage(id, text);
	}
	
	if (++num > 4)
		num = 1;
}

// Mostrar el hud de velocidad, lanzar y patear bombas
public task_hud2()
{
	static id, num = 0, text[150], i, iTextLen;
	
	set_dhudmessage(0, 255, 0, 1.0, 0.74, 0, 1.3 , 1.3, 0.01, 0.01); 
	for (id = num; id <= 32; id += 4)
	{
		if (g_status[id] != STATUS_JOINED || !g_canbattle[id])
			continue;
		
		formatex(text, charsmax(text), "%L^n[", id, "HUD_INFO_SPEED");
		for (i = 1; i <= g_powerups[id][SKATE]; i++)
			add(text, charsmax(text), "•");
		
		iTextLen = add(text, charsmax(text), "]^n");
		if (g_powerups[id][KICK])
			iTextLen += formatex(text[iTextLen], charsmax(text) - iTextLen, "^n%L", id, "HUD_INFO_KICK_BOMBS");
		
		if (g_powerups[id][GLOVES])
			iTextLen += formatex(text[iTextLen], charsmax(text) - iTextLen, "^n%L", id, "HUD_INFO_THROW_BOMBS");
		
		show_dhudmessage(id, text);
	}
	
	if (++num > 4)
		num = 1;
}

// Mostrar el hud de scores (cada 2 segundos para cada room)
public task_show_scores()
{
	static room = 0;
	
	if (++room > 8)
		room = 1;
	
	if (!g_inbattle[room-1])
		return;
	
	static msg[120], i, j, k, len;
	new players[4];
	
	// Comprobar para todos los jugadores
	for (i = 1; i <= 32; i++)
	{
    	// Si este jugador esta jugando en la sala
		if (g_battle[i] == room)
		{
			for (j = 3; j >= 0; j--)
			{
				if (players[j] == 0)
				{
					players[j] = i;
					break;
				}
				
				if (g_score[players[j]] > g_score[i])
				{
					for (k = 1; k <= j; k++)
					{
						players[k-1] = players[k];
					}
					players[j] = i;
					break;
				}
			}
		}
	}
	
	len = formatex(msg, charsmax(msg), "%L:", LANG_PLAYER, "HUD_SCORE_TITLE");
	for (i = 0; i < 4; i++)
	{
		if (players[i] == 0)
			continue;
		
		len += formatex(msg[len], charsmax(msg)-len, "^n%d | ", g_score[players[i]]);
		len += get_user_name(players[i], msg[len], charsmax(msg)-len);
	}
	
	set_dhudmessage(255, 255, 0, 0.26, 0.1, 0, 1.7, 1.7, 0.01, 0.01);
	for (i = 3; i >= 0; i--)
	{
		if (players[i] == 0)
			break;
		
		show_dhudmessage(players[i], msg);
	}
}

// Mostrar el menu principal
show_menu_game(id)
{
	static szMenuItem[64];

	formatex(szMenuItem, charsmax(szMenuItem), "\y%L", id, "MENU_TAG");
	new menu = menu_create(szMenuItem, "menu_game");
	
	formatex(szMenuItem, charsmax(szMenuItem), "%L", id, "MENU_GAME_LEAVE_ROOM");
	menu_additem(menu, szMenuItem);
	
	formatex(szMenuItem, charsmax(szMenuItem), "%L", id,
		music_enabled(id) ? "MENU_GAME_MUSIC_ON" : "MENU_GAME_MUSIC_OFF");
	menu_additem(menu, szMenuItem);
	
	static const CAMARAS[][] =
	{
		"MENU_GAME_CAM_FIRST_PERSON",
		"MENU_GAME_CAM_UP"
	};
	
	formatex(szMenuItem, charsmax(szMenuItem), "%L", id, "MENU_GAME_CAM", id, CAMARAS[g_camera[id]]);
	menu_additem(menu, szMenuItem);
	
	formatex(szMenuItem, charsmax(szMenuItem), "%L^n", id, "MENU_INTRO_INFO");
	menu_additem(menu, szMenuItem);
	formatex(szMenuItem, charsmax(szMenuItem), "%L", id, "MENU_OPT_EXIT");
	menu_additem(menu, szMenuItem);
	
	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
	
	menu_display(id, menu);
}

public menu_game(id, menu, item)
{
	if (menu)
		menu_destroy(menu);
	
	if (!is_user_connected(id) || g_status[id] < STATUS_JOINING)
		return PLUGIN_HANDLED;
	
	switch (item)
	{
		// Salir de la sala
		case 0:
		{
			show_menu_confirm(id);
		}
		// Cambiar la musica
		case 1:
		{
			music_toggle(id);
			
			if (music_enabled(id) && g_battle[id])
			{
				client_cmd(id, "mp3 loop sound/%s", SOUND_BATTLE_BG[g_music[g_battle[id]-1]]);
			}
			else
			{
				client_cmd(id, "mp3 stop");
			}
			
			show_menu_game(id);
		}
		// Cambiar la camara
		case 2:
		{
			g_camera[id] = !g_camera[id];
			switch (g_camera[id])
			{
				case 0: set_view(id, 0);
				case 1:
				{
					set_view(id, 3);
					fix_camera_angles(id);
				}
			}
			
			show_menu_game(id);
		}
		// Menu de informacion
		case 3:
		{
			show_menu_info(id);
		}
	}
	
	return PLUGIN_HANDLED;
}

// Menu de confirmacion para salir de salon
show_menu_confirm(id)
{
	menu_display(id, g_menuconfirm);
}

public menu_confirm(id, menu, item)
{
	if (is_user_connected(id) && g_status[id] >= STATUS_JOINING) switch (item)
	{
		case 0:
		{
			g_canbattle[id] = g_character[id] = 0;
			g_status[id] = STATUS_CONNECTED;
			
			new room;
			room = g_battle[id];
			
			g_battle[id] = 0;
			
			if (is_user_alive(id))
			{
				ExecuteHamB(Ham_Killed, id, id, 0);
			}
			
			//cs_set_user_team(id, CS_TEAM_UNASSIGNED);
			
			if (room)
			{
				check_endround(room, 1);
			}
			
			if (music_enabled(id))
			{
				client_cmd(id, ";mp3 stop");
			}
			
			entity_set_origin(id, Float:{2880.0, 640.0, 150.0});
			show_menu_intro(id);
		}
		case 1:
		{
			show_menu_game(id);
		}
	}
	
	return PLUGIN_HANDLED;
}

// Mostrar el menu de entrada
show_menu_intro(id)
{
	menu_display(id, g_menuintro);
}

public menu_intro(id, menu, item)
{
	if (is_user_connected(id)) switch (item)
	{
		case 0:
		{
			show_menu_rooms(id);
		}
		case 1:
		{
			if (is_user_alive(id))
				ExecuteHamB(Ham_Killed, id, id, 0);
			
			print_color(id, "%L %L", id, "CHAT_TAG", id, "CHAT_MAIN_MENU");
		}
		case 2:
		{
			show_menu_info(id);
		}
	}
	
	return PLUGIN_HANDLED;
}

show_menu_info(id)
{
	menu_display(id, g_menuinfo);
}

public menu_info(id, menu, item)
{
	static szInfoHeader[32], szInfoBody[64];

	if (is_user_connected(id))
	{
		switch (item)
		{
			case 0:
			{
				formatex(szInfoHeader, charsmax(szInfoHeader), "%L", id, "MENU_INFO_CHOOSE_ROOM");
				formatex(szInfoBody, charsmax(szInfoBody), "%L", id, "MENU_MOTD_CHOOSE_ROOM");
				show_motd(id, szInfoBody, szInfoHeader);
			}
			case 1:
			{
				formatex(szInfoHeader, charsmax(szInfoHeader), "%L", id, "MENU_INFO_HOW_TO");
				formatex(szInfoBody, charsmax(szInfoBody), "%L", id, "MENU_MOTD_HOW_TO");
				show_motd(id, szInfoBody, szInfoHeader);
			}
			case 2:
			{
				formatex(szInfoHeader, charsmax(szInfoHeader), "%L", id, "MENU_INFO_ITEMS");
				formatex(szInfoBody, charsmax(szInfoBody), "%L", id, "MENU_MOTD_ITEMS");
				show_motd(id, szInfoBody, szInfoHeader);
			}
			case 3:
			{
				formatex(szInfoHeader, charsmax(szInfoHeader), "%L", id, "MENU_INFO_THROW");
				formatex(szInfoBody, charsmax(szInfoBody), "%L", id, "MENU_MOTD_THROW");
				show_motd(id, szInfoBody, szInfoHeader);
			}
			case 4:
			{
				print_color(id, "%L", id, "CHAT_INFO_MSG1", VERSION, AUTHOR);
				print_color(id, "%L", id, "CHAT_INFO_MSG2", REPOSITORY);
				print_color(id, "%L", id, "CHAT_INFO_MSG3", SUPPORT_THREAD);
			}
			case 5:
			{
				if (g_status[id] < STATUS_JOINING)
				{
					show_menu_intro(id);
				}
				else
				{
					show_menu_game(id);
				}
				
				return PLUGIN_HANDLED;
			}
		}
		
		show_menu_info(id);
	}
	
	return PLUGIN_HANDLED;
}

// Elegir una sala
show_menu_rooms(id)
{
	static szMenuItem[64];
	
	formatex(szMenuItem, charsmax(szMenuItem), "%L", id, "MENU_ROOMS_TITLE");
	new menu = menu_create(szMenuItem, "menu_rooms");
	
	for (new i = 0, players; i < 8; i++)
	{
		players = room_players(i+1);
		formatex(szMenuItem, charsmax(szMenuItem), "%L %d \%s[%d/4]%s", id, "MENU_ROOMS_ROOM", i+1, players == 4 ? "r" : "y", players, i == 7 ? "^n" : "");
		menu_additem(menu, szMenuItem, .callback = (players == 4) ? g_menucallback : -1);
	}
	
	formatex(szMenuItem, charsmax(szMenuItem), "%L", id, "MENU_OPT_CANCEL");
	menu_additem(menu, szMenuItem);
	
	menu_setprop(menu, MPROP_PERPAGE, 0);
	menu_setprop(menu, MPROP_EXIT, MEXIT_NEVER);
	
	menu_display(id, menu);
}

public menu_rooms(id, menu, item)
{
	menu_destroy(menu);
	
	if (!is_user_connected(id))
		return PLUGIN_HANDLED;
	
	if (item == 8)
	{
		show_menu_intro(id);
		return PLUGIN_HANDLED;
	}
	
	new room = item + 1;
	
	static players;
	players = room_players(room);
	if (players == 4)
	{
		client_print(id, print_center, "%L", id, "CHAT_ROOM_FULL");
		show_menu_rooms(id);
		
		return PLUGIN_HANDLED;
	}
	
	g_battle[id] = room;
	g_character[id] = get_free_character(room);
	g_status[id] = STATUS_JOINING;
		
	if (!g_regamedll)
	{
		set_pdata_int(id, 125, (get_pdata_int(id, 125) & ~(1 << 8)));
		
		if (cs_get_user_team(id) != CS_TEAM_CT)
		{
			//client_cmd(id, "jointeam 2");
			
			new restore = !!HasVGUIMenus(id);
			
			if (restore)
				RemoveVGUIMenus(id);
			
			new block = get_msg_block(g_msgShowMenu);
			set_msg_block(g_msgShowMenu, BLOCK_SET);
			
			engclient_cmd(id, "jointeam", "2");
			engclient_cmd(id, "joinclass", "5");
			
			set_msg_block(g_msgShowMenu, block);
			
			if (restore)
				SetVGUIMenus(id);
		}
	}
	
	if (music_enabled(id))
		client_cmd(id, "mp3 loop sound/%s", SOUND_BATTLE_BG[g_music[room-1]]);
	
	check_endround(room, 1);
	
	print_color(id, "%L %L", id, "CHAT_TAG", id, "CHAT_GAME_WILL_START");
	
	g_alive[id] = 0;
	kill_if_not_playing(id);
	
	cs_set_user_model(id, "bomberman");
	
	new Float:origin[3];
	origin[2] = 140.0;
	origin_from_block(room, 8, 8, origin);
	entity_set_origin(id, origin);
	entity_set_vector(id, EV_VEC_v_angle, Float:{ 0.0, 0.0, 0.0 });
	
	return PLUGIN_HANDLED;
}

// Callback que siempre retorna ITEM_DISABLED. Lo uso en todos los menus donde deseo desactivar algun item.
// La comprobacion la hago antes de llamar al callback (HACK)
public cb_item_block(id, menu, item)
{
	return ITEM_DISABLED;
}

/*================================================================================
 [Forwards de engine/fakemeta/hansandwich]
=================================================================================*/

public client_PreThink(id)
{
	if (!g_alive[id])
		return;
	
	if (g_canbattle[id])
	{
		// Quitar el slow down al saltar
		entity_set_float(id, EV_FL_fuser2, 0.0);
		
		return;
	}
	
	static room;
	room = g_battle[id];
	
	if (!room)
		return;
	
	// Inmovilizar a los jugadores mientras no haya iniciado la ronda.
	if (g_freeze[room - 1])
		entity_set_vector(id, EV_VEC_velocity, Float:{ 0.0, 0.0, 0.0 });
}

// Aqui comprobamos si el jugador presiona +USE (plantar) o +ATTACK1 (agarrar una bomba)
// Si lees este codigo y no entiendes las ecuaciones, te sugiero leer mis tutoriales de vectores
// https://amxmodx-es.com/showthread.php?tid=6751
public fw_CmdStart(id, uc, junk)
{
	static buttons, oldbuttons, direction, camera;
	
	// Si la ronda no ha iniciado, nada que hacer aqui
	if (!g_canbattle[id])
		return;
	
	buttons = get_uc(uc, UC_Buttons);
	oldbuttons = entity_get_int(id, EV_INT_oldbuttons);
	static Float:curtime;
	static Float:origin[3], Float:originT[3], Float:angles[3];
	curtime = halflife_time();
	camera = g_camera[id];
	
	// Si juega desde arriba, almacenamos la direccion de movimiento
	if (camera == 1)
	{
		const WALK_BUTTONS = IN_FORWARD|IN_MOVELEFT|IN_BACK|IN_MOVERIGHT;
		
		switch (buttons & WALK_BUTTONS)
		{
			case IN_FORWARD:
			{
				entity_get_vector(id, EV_VEC_angles, angles);
				g_direction[id] = angles_direction(angles);
			}
			case IN_MOVELEFT:
			{
				entity_get_vector(id, EV_VEC_angles, angles);
				direction = angles_direction(angles) + 1;
			
				if (direction > 4)
					direction -= 4;
				
				g_direction[id] = direction;
			}
			case IN_BACK:
			{
				entity_get_vector(id, EV_VEC_angles, angles);
				direction = angles_direction(angles) + 2;
			
				if (direction > 4)
					direction -= 4;
				
				g_direction[id] = direction;
			}
			case IN_MOVERIGHT:
			{
				entity_get_vector(id, EV_VEC_angles, angles);
				direction = angles_direction(angles) + 3;
			
				if (direction > 4)
					direction -= 4;
				
				g_direction[id] = direction;
			}
		}
	}
	
	// IN_USE
	if ((~oldbuttons & buttons) & IN_USE && is_user_alive(id))
	{
		// Si ya ha pasado PLANT_DELAY desde que plantó su última bomba y tiene bombas disponibles
		if (g_nextplant[id] < curtime && g_powerups[id][MAXBOMBS] - g_bombs[id] > 0)
		{
			// bugfix: no plantar mas de una bomba en el mismo lugar
			entity_get_vector(id, EV_VEC_origin, origin);
			adjust_to_map(origin);
			origin[2] = 87.0;
			if (find_sphere_class(0, BOMB_CLASSNAME, 18.0, "", 1, origin))
				return;
			
			// Creamos la bomba
			create_bomb(id);
			// Delay para plantar la siguiente
			g_nextplant[id] = curtime + PLANT_DELAY;
			
			// Paramos acá. Que se plante la bomba antes de poder agarrarla (BUGFIX)
			return;
		}
	}
	
	// Si tiene los guantes
	if (g_powerups[id][GLOVES])
	{
		// Si aún no está sujetando alguna bomba
		if (!g_holding[id])
		{
			// Si presiona ATTACK1 o JUMP
			if (((~oldbuttons & buttons) & IN_ATTACK) || (camera == 1 && (~oldbuttons & buttons) & IN_JUMP)) // Recoger
			{
				// Obtenemos la posicion del jugador
				entity_get_vector(id, EV_VEC_origin, origin);
				
				// Usaré la variable 'junk' para almacenar el id de la entidad que buscamos
				// Una bomba cerca!
				junk = -1;
				while ((junk = find_ent_in_sphere(junk, origin, 15.0)) > 0)
				{
					// Si es una bomba
					if (entity_get_int(junk, EV_INT_iuser1) == BOMB_CONST)
					{
						// Prevenir salto
						if (buttons & IN_JUMP)
							entity_set_int(id, EV_INT_oldbuttons, oldbuttons | IN_JUMP);
						
						// La agarramos
						g_holding[id] = junk;
						
						// Que el jugador vea la bomba
						entity_set_string(id, EV_SZ_viewmodel, BOMB_V_MODEL);
						
						// Ocultarla
						entity_set_int(junk, EV_INT_solid, SOLID_NOT);
						entity_set_int(junk, EV_INT_rendermode, kRenderTransAlpha);
						entity_set_float(junk, EV_FL_renderamt, 0.0);
						
						// Evitamos que explote
						entity_set_float(junk, EV_FL_nextthink, 9999999.9);
					}
				}
			}
		}
		else if (((oldbuttons & ~buttons) & IN_ATTACK) || (camera == 1 && ((oldbuttons & ~buttons) & IN_JUMP))) // Lanzar
		{
			// Ya no tienes la bomba
			entity_set_string(id, EV_SZ_viewmodel, DEFAULT_V_MODEL);
			
			// Obtener la posicion del jugador
			entity_get_vector(id, EV_VEC_origin, origin);
			
			// Esta funcion acomoda una posicion cualquiera dentro de una sala al centro del bloque donde esta
			// Asigna los valores del numero de caja correspondiente a X e Y
			// Nota: Las cajas tienen una posición que va de 1 a 15 en el eje horizontal y en el eje vertical
			static x, y;
			adjust_to_map(origin, x, y);
			
			// A donde mira el jugador?
			if (camera == 1)
			{
				velocity_by_direction(g_direction[id], 80.0, angles);
			}	
			else
			{
				entity_get_vector(id, EV_VEC_angles, angles);
				
				velocity_by_direction(angles_direction(angles), 80.0, angles);
			}
						
			const Float:Zo = 100.0;
			const Float:Zm = 140.0;
			const Float:Zf = 100.0;
			static Float:Vo = 0.0, Float:g, Float:t;
			if (Vo == 0.0)
			{
				t = 80.0 / THROW_SPEED; // distancia = 2 bloques (2*40)
				
				new Float:a = floatdiv(floatpower(t, 2.0), -4.0 * (Zm - Zo));
				
				Vo = (-t - floatsqroot(floatpower(t, 2.0) - 4.0*a*(Zo - Zf))) / (2.0 * a);
				g = floatdiv(floatpower(Vo, 2.0), 2.0*(Zm - Zo)) / GRAVITY;
			}
			
			junk = g_holding[id];
			
			// Establecemos la gravedad
			entity_set_float(junk, EV_FL_gravity, g);
			
			static Float:velocity[3];
			if (angles[0] == 0.0)
			{
				velocity[0] = 0.0;
				velocity[1] = angles[1] > 0.0 ? THROW_SPEED : -THROW_SPEED;
			}
			else
			{
				velocity[0] = angles[0] > 0.0 ? THROW_SPEED : -THROW_SPEED;
				velocity[1] = 0.0;
			}
			velocity[2] = Vo;
			
			// Seteamos la velocidad
			entity_set_vector(junk, EV_VEC_velocity, velocity);
			
			// Almacenamos la velocidad para usarla en otros calculos
			entity_set_vector(junk, EV_VEC_vuser2, velocity);
			
			// Nota: origin es la posicion del jugador.
			// Vamos a subir la altura a la bomba para que no se atore al lanzarla
			origin[2] = Zo;
			entity_set_origin(junk, origin);
							
			// Evitar que se atore
			entity_set_int(junk, EV_INT_movetype, MOVETYPE_TOSS);
			entity_set_float(junk, EV_FL_friction, 1.0);
			
			// Que vuelva a ser visible
			entity_set_float(junk, EV_FL_renderamt, 255.0);
			
			// En t segundos la acomodaremos en su posicion
			entity_set_float(junk, EV_FL_nextthink, curtime + t);
			
			// Almacenamos la posicion final deseada
			xs_vec_add(origin, angles, originT);
			entity_set_vector(junk, EV_VEC_vuser1, originT);
			
			// Un flag para saber que está en el aire
			entity_set_int(junk, EV_INT_iuser3, 2);
						
			// En cualquier version de bomberman donde existe el item guante, cuando la bomba cae tras ser lanzada se reinicia su contador para explotar
			entity_set_float(junk, EV_FL_fuser1, curtime + t + DETONATE_DELAY);
			
			// Ya no tienes nada en la mano
			g_holding[id] = 0;
			
			// Haz lanzado una bomba!
			emit_sound(id, CHAN_AUTO, SOUND_THROW, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
		}
	}
}

public fw_EmitSound(id, channel, const sample[], Float:volume, Float:attn, flags, pitch)
{
	// El clasico waaaa cuando bomberman muere
	if (equal(sample, "player/die", 10))
	{
		if (g_status[id] == STATUS_JOINED)
			emit_sound(id, channel, SOUND_DIE, volume, attn, flags, pitch);
			
		return FMRES_SUPERCEDE;
	}
	
	return FMRES_IGNORED;
}

// Si estamos procesando una caja para un jugador que no está vivo, no la enviamos (prevenir un packet flood en el cliente)
public fw_AddToFullPack_Pre(es, e, ent, id, hostflags, player, set)
{
	// La entidad no es valida
	if (e < 33 || pev_valid(e) != 2)
		return FMRES_IGNORED;
	
	// No es una caja
	if (entity_get_int(e, EV_INT_iuser1) != BLOCK_CONST)
		return FMRES_IGNORED;
	
	// Es una caja de la sala del jugador
	if (g_alive[id] && g_battle[id] == entity_get_int(e, EV_INT_iuser3))
		return FMRES_IGNORED;
	
	// Bye bye
	forward_return(FMV_CELL, 0);
	return FMRES_SUPERCEDE;
}

//=================================================
public fw_Spawn(id)
{
	reset_vars(id);
	
	static room;
	room = g_battle[id];
	
	remove_task(id + TASK_DISAPPEAR);
	
	if (!is_user_alive(id))
		return;
	
	g_alive[id] = 1;
	
	appear_player(id);
	
	remove_weapons(id);
	
	if (!room)
 	{
		show_menu_intro(id);
		return;
	}
	
	if (g_camera[id] == 1)
		set_task(0.2, "fix_camera_angles", id);
	
	static players;
	players = room_alive_players(room);
	
	// Si por alguna razon, este jugador ha nacido cuando hay otros que sí estan jugando (BUGFIX)
	if (players > 1 && players < 32)
	{
		set_task(2.0, "kill_if_not_playing", id);
		return;
	}
	
	// Estoy sola en esta sala!
	if (!task_exists(room + TASK_START) && !task_exists(room + TASK_END))
	{
		set_task(0.1, "start_battle", room + TASK_END);
	}
}

public kill_if_not_playing(id)
{
	if (g_status[id] >= STATUS_JOINING && !g_canbattle[id])
	{
		if (is_user_alive(id))
			ExecuteHamB(Ham_Killed, id, id, 0);
		else
			g_status[id] = STATUS_JOINED;
	}
}

remove_weapons(id)
{
	if (is_user_alive(id))
	{
		strip_user_weapons(id);
		//give_item(id, "weapon_knife");
		entity_set_string(id, EV_SZ_viewmodel, DEFAULT_V_MODEL);
	}
}

//=================================================

public fw_Killed(id, attacker, shouldgib)
{
	// Has muerto, ya no puedes jugar.
	g_alive[id] = 0;
	g_canbattle[id] = 0;
	
	static room;
	room = g_battle[id];
	
	// No está jugando, espectear inmediatamente
	if (g_status[id] < STATUS_JOINED)
	{
		disappear_player(id + TASK_DISAPPEAR);
		
		if (g_status[id] == STATUS_JOINING)
			g_status[id] = STATUS_JOINED;
		
		return;
	}
	
	set_task(1.0, "disappear_player", id + TASK_DISAPPEAR);
	
	// Si terminó la ronda en la sala, nada que hacer.
	if (room == 0 || task_exists(TASK_END + room))
		return;
	
	check_endround(room);
}

// Think de las bombas
public fw_BombThink(ent)
{
	static Float:curtime, Float:exptime;
	static id, victim, i, a, killed, maxiters, item;
	static Float:origin[3], Float:exporigin[3], Float:velocity[3];
	static Float:exppower;
	
	// Veamos si hay un flag.
	switch (entity_get_int(ent, EV_INT_iuser3))
	{
		// Flag de remover
		case 1:
		{
			remove_entity(ent);
			return;
		}
		// Flag de caer del aire
		case 2:
		{
			// Comprobemos si hay espacio aquí para la bomba
			entity_get_vector(ent, EV_VEC_vuser1, exporigin);
			exporigin[2] = 110.0;
			
			// Si no hay espacio
			if (trace_hull(exporigin, HULL_HUMAN, ent, 0))
			{
				// Rebotar!
				const Float:Zo = 100.0;
				const Float:Zm = 140.0;
				const Float:Zf = 100.0;
				
				// Acomodar
				exporigin[2] = Zo;
				entity_set_origin(ent, exporigin);
				
				// Velocidad
				entity_get_vector(ent, EV_VEC_vuser2, velocity);
				static Float:Vo = 0.0, Float:g, Float:t;
				if (Vo == 0.0)
				{
					t = 0.95 * 40.0 / THROW_SPEED; // distancia = 1 bloques
					
					new Float:a = floatdiv(floatpower(t, 2.0), -4.0 * (Zm - Zo));
					new Float:b = t;
					
					Vo = (-b - floatsqroot(floatpower(b, 2.0) - 4.0*a*(Zo - Zf))) / (2.0 * a);
					g = floatdiv(floatpower(Vo, 2.0), 2.0*(Zm - Zo)) / GRAVITY;
				}
				velocity[2] = Vo;
				entity_set_vector(ent, EV_VEC_velocity, velocity);
				
				// Almacenamos la posicion final deseada
				velocity[2] = 0.0;
				xs_vec_normalize(velocity, velocity);
				xs_vec_mul_scalar(velocity, 40.0, velocity);
				xs_vec_add(exporigin, velocity, exporigin);
				exporigin[2] = BOMB_Z_POS;
				entity_set_vector(ent, EV_VEC_vuser1, exporigin);
				
				// Si se va del mapa, remover la bomba
				id = entity_get_int(ent, EV_INT_iuser2);
				
				if (!is_origin_inside_room(exporigin, g_battle[id]))
				{
					remove_entity(ent);
					g_bombs[id]--;
					return;
				}
				
				// Establecemos la gravedad
				entity_set_float(ent, EV_FL_gravity, g);
								
				// En t segundos la acomodaremos en su posicion
				curtime = halflife_time();
				entity_set_float(ent, EV_FL_nextthink, curtime + t);
				
				// En cualquier version de bomberman donde existe el item guante, cuando la bomba cae tras ser lanzada, el contador para que explote se reinicia
				entity_set_float(ent, EV_FL_fuser1, curtime + t + DETONATE_DELAY);
								
				// Sonido de rebote
				emit_sound(ent, CHAN_AUTO, SOUND_BOUNCE, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
				
				return;
			}
			
			entity_get_vector(ent, EV_VEC_origin, origin);
			entity_set_int(ent, EV_INT_movetype, MOVETYPE_FLY);
			entity_set_int(ent, EV_INT_solid, SOLID_BBOX);
			//xs_vec_sub(exporigin, origin, velocity);
			//xs_vec_mul_scalar(velocity, 8, velocity); // dividir entre 0.1 segundos = multiplicar por 10, por tolerancia se pone 8
			velocity[0] = 0.0;
			velocity[1] = 0.0;
			velocity[2] = (BOMB_Z_POS - origin[2]) * 8; // dividir entre 0.1 segundos = multiplicar por 10, por tolerancia se pone 8
			entity_set_vector(ent, EV_VEC_velocity, velocity);
			exporigin[2] = origin[2];
			entity_set_origin(ent, origin);
			entity_set_float(ent, EV_FL_gravity, 0.001);
			curtime = halflife_time();
			entity_set_float(ent, EV_FL_nextthink, curtime + 0.1);
			entity_set_int(ent, EV_INT_iuser3, 3); // Flag de acomodar
			
			return;
		}
		// Flag de acomodar
		case 3:
		{
			entity_get_vector(ent, EV_VEC_vuser1, origin);
			origin[2] = BOMB_Z_POS;
			entity_set_origin(ent, origin);
			entity_set_vector(ent, EV_VEC_velocity, Float:{ 0.0, 0.0, 0.0 });
			exptime = entity_get_float(ent, EV_FL_fuser1);
			entity_set_float(ent, EV_FL_nextthink, exptime + 0.01);
			entity_set_int(ent, EV_INT_iuser3, 0);
			
			return;
		}
	}
	
	static trace, Float:fraction;
	curtime = halflife_time();
	exptime = entity_get_float(ent, EV_FL_fuser1);
	
	entity_get_vector(ent, EV_VEC_origin, origin);
	
	// Cuando la bomba se planta, no es sólida, esto para que el jugador no se atore hasta que se aleje
	
	// Aun no es tiempo de explotar
	if (exptime > curtime)
	{
		// Buscamos algún jugador en el lugar de la bomba		
		victim = -1;
		origin[2] = origin[2] + 30.0;
		while (1 <= (victim = find_ent_in_sphere(victim, origin, 16.0)) <= 32)
		{
			// Si encontramos al menos 1
			if (is_user_alive(victim))
			{
				// Aun no podemos volver sólida a esta bomba
				entity_set_float(ent, EV_FL_nextthink, curtime + 0.02);
				return;
			}
		}
		
		// Si llegamos aquí, es porque ya no hay nadie, procedemos a hacerla sólida
		entity_set_int(ent, EV_INT_solid, SOLID_BBOX);
		entity_set_int(ent, EV_INT_movetype, MOVETYPE_FLY);
		entity_set_float(ent, EV_FL_gravity, 0.001);
		entity_set_vector(ent, EV_VEC_velocity, Float:{0.0, 0.0, 0.0});
		entity_set_float(ent, EV_FL_nextthink, exptime + 0.01);
		return;
	}
	
	id = entity_get_int(ent, EV_INT_iuser2);
	
	// Si la bomba pertenece a un jugador ya muerto (o la ronda ya terminó), paramos aquí
	if (!g_canbattle[id])
	{
		remove_entity(ent);
		return;
	}
	
	// Explotar!
	emit_sound(ent, CHAN_AUTO, SOUND_EXPLODE, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	
	// Exporigin se usará para calcular las coordenadas de cada explosión
	adjust_to_map(origin);
	xs_vec_copy(origin, exporigin);

	engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, origin, 0);
	write_byte(TE_EXPLOSION);
	engfunc(EngFunc_WriteCoord, exporigin[0]);
	engfunc(EngFunc_WriteCoord, exporigin[1]);
	engfunc(EngFunc_WriteCoord, exporigin[2]+10.0);
	write_short(g_SprFlame);
	write_byte(6);
	write_byte(15);
	write_byte(TE_EXPLFLAG_NOSOUND);
	message_end();
	
	// 40.0 es el lado de cada bloque
	exppower = 40.0*float(g_powerups[id][FIRE]);
	exporigin[2] = exporigin[2] + 25.0;
	
	// Primera epxlosión: en la posicion de la bomba
	victim = -1;
	while ((victim = find_ent_in_sphere(victim, exporigin, EXP_RADIUS)) > 0)
	{
		// BUGFIX
		if (victim == ent)
		{
			continue;
		}
		// Es un jugador
		else if (1 <= victim <= 32)
		{
			// Si está muerto, nada que hacer
			if (!is_user_alive(victim))
				continue;
			
			// Pierdes una vida
			g_powerups[victim][HEART]--;
			
			// Si ya no tienes más, mueres
			if (!g_powerups[victim][HEART])
				ExecuteHamB(Ham_Killed, victim, id, 0);
			else
			{
				emit_sound(id, CHAN_AUTO, SOUND_INFECT, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
				screen_fade(id);
			}
		}
		else switch (entity_get_int(victim, EV_INT_iuser1))
		{
			case BOMB_CONST:
			{
				// de algun modo, hay otra bomba en la misma posicion
				// hagamoslo simple: remover la otra bomba, y que esta explote con la mayor fuerza de las dos bombas
				i = entity_get_int(victim, EV_INT_iuser2);
				exppower = 40.0*float(max(g_powerups[id][FIRE], g_powerups[i][FIRE]));
				entity_set_int(victim, EV_INT_iuser3, 1); // flag de remover
				entity_set_float(victim, EV_FL_nextthink, curtime + 0.01);
				g_bombs[i]--;
			}
			case POWERUP_CONST:
			{
				remove_entity(victim);
			}
		}
	}
	
	// Iteramos a los 4 lados de la bomba
	for (a = 1; a <= 4; a++)
	{
		switch (a)
		{
			case 1: // Eje X positivo
			{
				exporigin[0] = origin[0]+exppower;
				exporigin[1] = origin[1];
			}
			case 2: // Eje Y positivo
			{
				exporigin[0] = origin[0];
				exporigin[1] = origin[1]+exppower;
			}
			case 3: // Eje X negativo
			{
				exporigin[0] = origin[0]-exppower;
				exporigin[1] = origin[1];
			}
			case 4: // Eje Y negativo
			{
				exporigin[0] = origin[0];
				exporigin[1] = origin[1]-exppower;
			}
		}
		
		// Traceline
		engfunc(EngFunc_TraceLine, origin, exporigin, IGNORE_MONSTERS, ent, trace);
		get_tr2(trace, TR_flFraction, fraction);
		
		// No hay obstaculos, máximo poder!
		if (fraction == 1.0)
		{
			maxiters = g_powerups[id][FIRE];
		}
		else
		{
			// Hay un obstáculo. Calculemos a cuántos bloques está
			maxiters = floatround(float(g_powerups[id][FIRE]+1)*fraction)-1;
		}
		
		// Explosiones en cada bloque, hasta llegar al obstáculo
		for (i = 0; i <= maxiters; i++)
		{			
			// Calcular la posicion de la explosión
			switch (a)
			{
				case 1: // Primer cuadrante
				{
					exporigin[0] = origin[0]+40.0*float(i+1);
					exporigin[1] = origin[1];
				}
				case 2: // Segundo cuadrante
				{
					exporigin[0] = origin[0];
					exporigin[1] = origin[1]+40.0*float(i+1);
				}
				case 3: // Tercer cuadrante
				{
					exporigin[0] = origin[0]-40.0*float(i+1);
					exporigin[1] = origin[1];
				}
				case 4: // Cuarto cuadrante
				{
					exporigin[0] = origin[0];
					exporigin[1] = origin[1]-40.0*float(i+1);
				}
			}
			
			victim = -1;
			killed = 1;
			
			// Veamos si hay algo
			while ((victim = find_ent_in_sphere(victim, exporigin, EXP_RADIUS)) > 0)
			{
				// BUGFIX
				if (victim == ent)
				{
					continue;
				}
				// Un jugador
				else if (1 <= victim <= 32)
				{
					if (is_user_alive(victim))
					{
						g_powerups[victim][HEART]--;
						
						if (!g_powerups[victim][HEART])
							ExecuteHamB(Ham_Killed, victim, id, 0);
						else
						{
							emit_sound(victim, CHAN_AUTO, SOUND_INFECT, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
							screen_fade(victim);
						}
						
						killed++;
					}
				}
				// Alguna entidad conocida
				else switch (entity_get_int(victim, EV_INT_iuser1))
				{
					case BOMB_CONST:
					{
						entity_set_float(victim, EV_FL_fuser1, curtime + 0.01);
						entity_set_float(victim, EV_FL_nextthink, curtime + 0.1);
						killed = -1;
						break;
					}
					case BLOCK_CONST:
					{
						// Una caja. Veamos si contiene algún item
						item = entity_get_int(victim, EV_INT_iuser2);
						
						if (item)
						{
							create_powerup(exporigin, item-1);
						}
						
						remove_entity(victim);
						
						killed++;
					}
					case POWERUP_CONST:
					{
						remove_entity(victim);
						killed++;
					}
				}
			}
			
			// Había una bomba
			if (killed == -1)
				break;
			
			engfunc(EngFunc_MessageBegin, MSG_PVS, SVC_TEMPENTITY, exporigin, 0);
			write_byte(TE_EXPLOSION);
			engfunc(EngFunc_WriteCoord, exporigin[0]);
			engfunc(EngFunc_WriteCoord, exporigin[1]);
			engfunc(EngFunc_WriteCoord, exporigin[2]-10.0);
			write_short(g_SprFlame);
			write_byte(6);
			write_byte(15);
			write_byte(TE_EXPLFLAG_NOSOUND);
			message_end();
			
			// Había algo aquí, la explosión en este eje termina
			if (killed > 1)
				break;
		}
	}
	
	// Si remuevo la entidad aquí, el sonido de explosión se detendrá!
	// Seteamos el flag de remover y le damos un tiempo para que termine de sonar
	// Ocultamos la bomba
	entity_set_int(ent, EV_INT_solid, SOLID_NOT);
	entity_set_int(ent, EV_INT_rendermode, kRenderTransAlpha);
	entity_set_float(ent, EV_FL_renderamt, 0.0);
	entity_set_int(ent, EV_INT_iuser3, 1);
	entity_set_float(ent, EV_FL_nextthink, curtime + 1.3);
	
	g_bombs[id]--;
}

// El código aquí es bastante legible O.o
public fw_PowerUpThink(ent)
{
	entity_set_int(ent, EV_INT_solid, SOLID_TRIGGER);	
	entity_set_int(ent, EV_INT_iuser1, POWERUP_CONST);
	
	switch (entity_get_int(ent, EV_INT_iuser2))
	{
		case MAXBOMBS:
		{
			entity_set_model(ent, SPRITE_BOMB);
		}
		case FIRE:
		{
			entity_set_model(ent, SPRITE_FIRE);
		}
		case KICK:
		{
			entity_set_model(ent, SPRITE_KICK);
		}
		case SKATE:
		{
			entity_set_model(ent, SPRITE_SKATE);
		}
		case HEART:
		{
			entity_set_model(ent, SPRITE_HEART);
		}
		case GLOVES:
		{
			entity_set_model(ent, SPRITE_GLOVES);
		}
		case FULL_FIRE:
		{
			entity_set_model(ent, SPRITE_FULL_FIRE);
		}
	}
	
	entity_set_float(ent, EV_FL_scale, 0.85);	
	entity_set_size(ent, Float:{ -1.0, -1.0, -1.0 }, Float:{ 1.0, 1.0, 1.0 });
}

// Patear la bomba!
public fw_BombTouch(ent, id)
{
	if (!is_user_alive(id) || !g_powerups[id][KICK])
		return;
		
	static Float:curtime;
	curtime = halflife_time();
	
	// Evitar patear la bomba demasiadas veces
	if (entity_get_float(ent, EV_FL_fuser2) > curtime)
		return;
	
	static Float:origin[3], Float:originT[3];
	entity_get_vector(id, EV_VEC_origin, origin);
	entity_get_vector(ent, EV_VEC_origin, originT);
	xs_vec_sub(originT, origin, originT);
	originT[2] = 0.0;
	
	if (floatabs(originT[1]) > floatabs(originT[0]))
	{
		originT[0] = 0.0;
		originT[1] = originT[1] > 0.0 ? KICK_SPEED : -KICK_SPEED;
	}
	else
	{
		originT[0] = originT[0] > 0.0 ? KICK_SPEED : -KICK_SPEED;
		originT[1] = 0.0;
	}
	
	entity_set_vector(ent, EV_VEC_velocity, originT);
	entity_set_float(ent, EV_FL_fuser2, curtime + 0.3);
	
	emit_sound(ent, CHAN_AUTO, SOUND_KICK, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
}

// Recoger un item
public fw_PowerUpTouch(ent, id)
{
	if (!is_user_alive(id))
		return;
	
	static powerup;
	powerup = entity_get_int(ent, EV_INT_iuser2);
	client_cmd(id, "spk ^"%s^"", SOUND_ITEM);
	remove_entity(ent);
	
	switch (powerup)
	{
		case MAXBOMBS:
			print_color(id, "%L %L", id, "CHAT_TAG", id, "CHAT_POWERUP_MAXBOMBS");
		case FIRE:
		{
			print_color(id, "%L %L", id, "CHAT_TAG", id, "CHAT_POWERUP_FIRE");
			if (g_powerups[id][FIRE] == 15)
				return;
		}
		case SKATE:
		{
			print_color(id, "%L %L", id, "CHAT_TAG", id, "CHAT_POWERUP_SKATE");
			
			if (g_powerups[id][SKATE] >= 9)
				return;
			
			set_user_maxspeed(id, 220.0 + 30.0*float(g_powerups[id][SKATE]));
		}
		case HEART:
			print_color(id, "%L %L", id, "CHAT_TAG", id, "CHAT_POWERUP_HEART");
		case GLOVES:
			print_color(id, "%L %L", id, "CHAT_TAG", id, "CHAT_POWERUP_GLOVES");
		case KICK:
			print_color(id, "%L %L", id, "CHAT_TAG", id, "CHAT_POWERUP_KICK");
		case FULL_FIRE:
		{
			g_powerups[id][FIRE] = 15;
			print_color(id, "%L %L", id, "CHAT_TAG", id, "CHAT_POWERUP_FULLFIRE");
			return;
		}
	}
	
	g_powerups[id][powerup]++;
}

/*================================================================================
 [Funciones internas]
=================================================================================*/

public start_battle(room)
{
	//startorigin[0] = float(room/2)*704.0 + 20.0;
	//startorigin[1] = float((room+1)%2)*704.0 + 20.0;
	
	room -= TASK_END;
	remove_task(room + TASK_START);
	
	new i, j, x, y, vic, Float:origin[3];
	origin[2] = 110.0;
	
	// Remover todo lo que quedó del anterior juego
	for (i = 0; i < 225 /* 15x15 */; i++)
	{
		x = i%15;
		y = i/15;
		
		if ((x%2) && (y%2)) // Pared
			continue;
		
		vic = -1;
		origin_from_block(room, x+1, y+1, origin);
		while ((vic = find_ent_in_sphere(vic, origin, 20.0)) > 0)
		{
			switch (entity_get_int(vic, EV_INT_iuser1))
			{
				case BLOCK_CONST, BOMB_CONST, POWERUP_CONST:
				{
					remove_entity(vic);
				}
			}
		}
		
		// Esquinas
		if (((x < 2 || x > 12) && (y == 0 || y == 14)) || ((y < 2 || y > 12) && (x == 0 || x == 14)))
			continue;
		
		g_boxdata[room-1]{x + 15*y} = 1; // Caja limpia para la siguiente ronda
	}
	
	// Generar espacios en blanco
	for (i = 0; i < MAX_BLANKS; i++)
	{
		do
		{
			x = random(15);
			y = random(15);
		}
		while (g_boxdata[room-1]{x + 15*y} != 1);
		
		g_boxdata[room-1]{x + 15*y} = 0;
	}
	
	// Generar cajas para la ronda
	for (i = 0; i < POWERUPS; i++)
	{
		for (j = 0; j < MAX_ITEMS[i]; j++)
		{
			do
			{
				x = random(15);
				y = random(15);
			}
			while (g_boxdata[room-1]{x + 15*y} != 1);
			
			g_boxdata[room-1]{x + 15*y} = i + 2;
		}
	}
	
	new data[4];
	data[0] = -1;
	data[1] = _:(float((room-1)/2)*704.0 + 20.0);
	data[2] = _:(float((room+1)%2)*704.0 + 20.0);
	data[3] = _:80.0;
	
	// Las cajas se crean por partes, para no saturar enviando demasiadas entidades en muy poco tiempo
	set_task(0.5, "task_load_battle", room + TASK_START, data, 4);
	
	// Inmovilizar a los jugadores
	g_freeze[room - 1] = 1;
	
	// Cambiar la musica
	update_music(room);
}

// Se crean las cajas, en grupos no muy grandes
public task_load_battle(data[], room)
{
	room -= TASK_START;
	
	static id, i, x, y, maxiters;
	static Float:startorigin[3];
	static Float:origin[3] =  { 0.0, 0.0, 120.0 };
	startorigin[0] = Float:data[1];
	startorigin[1] = Float:data[2];
	startorigin[2] = Float:data[3];
		
	if (data[0] >= 0)
	{
		i = data[0]*LOOP_BOXES;
		maxiters = min(225, i + LOOP_BOXES);
		
		for (data[0]++; i < maxiters; i++)
		{
			x = i%15;
			y = i/15;
			
			if (g_boxdata[room-1]{x + 15*y} == 0)
				continue;
						
			origin[0] = startorigin[0] + 40.0*float(x);
			origin[1] = startorigin[1] + 40.0*float(y);
			
			create_box(origin, g_boxdata[room - 1]{x + 15*y} - 1, room);
		}
		
		if (data[0] * LOOP_BOXES < 225)
		{
			set_task(0.2, "task_load_battle", room + TASK_START, data, 15);
		}
		else
		{
			g_inbattle[room - 1] = 1;
			g_freeze[room - 1] = 0;
			set_hudmessage(255, 255, 255, -1.0, 0.2, 0, 5.0, 5.0, 0.1, 0.1, 2);
			for (id = 1; id <= 32; id++)
			{
				if (g_status[id] == STATUS_JOINED && g_battle[id] == room)
				{
					g_canbattle[id] = 1;
					set_user_maxspeed(id, 220.0);
					show_hudmessage(id, "%L", id, "HUD_GAME_START");
					entity_set_string(id, EV_SZ_viewmodel, DEFAULT_V_MODEL);
				}
			}
		}
	}
	else
	{
		for (id = 1; id <= 32; id++)
		{
			if (g_status[id] == STATUS_JOINED && g_battle[id] == room)
				spawn_to_origin(id, startorigin);
		}
		
		data[0]++;
		set_task(0.1, "task_load_battle", room + TASK_START, data, 4);
	}
}

check_endround(room, ignorewinner = 0)
{
	if (task_exists(room + TASK_END))
		return;
	
	new players = room_alive_players(room);
	
	if (players > 1 && players < 32)
		return;
	
	// Queda un jugador o ninguno, termina la ronda.
	set_task(3.0, "start_battle", room + TASK_END);
	g_inbattle[room-1] = 0;
		
	// Avisemos a todos los jugadores de la sala quien es el ganador
	if (!ignorewinner)
	{
		new name[32];
		if (players > 32)
		{
			players -= 32;
			get_user_name(players, name, 31);
			g_canbattle[players] = 0;
			g_score[players]++;
		}
		
		set_dhudmessage(255, 255, 0, -1.0, -1.0, 0, 5.0, 5.0, 0.1, 0.1);
		
		for (new i = 1; i <= 32; i++)
		{
			if (g_status[i] >= STATUS_JOINING && g_battle[i] == room)
			{
				client_cmd(i, "spk ^"%s^"", SOUND_WIN);
				g_canbattle[i] = 0;
				
				if (players)
					show_dhudmessage(i, "%L", i, "HUD_END_WIN", name);
				else
					show_dhudmessage(i, "%L", i, "HUD_END_DRAW");
			}
		}
	}
}

public disappear_player(id)
{
	id -= TASK_DISAPPEAR;
	
	if (!is_user_alive(id))
	{
		entity_set_string(id, EV_SZ_viewmodel, "");
		entity_set_int(id, EV_INT_deadflag, DEAD_DEAD);
		
		if (g_status[id] == STATUS_JOINED)
		{
			static Float:origin[3];
			entity_get_vector(id, EV_VEC_origin, origin);
			origin[2] = 140.0;
			entity_set_origin(id, origin);
		}
	}
}

appear_player(id)
{
	entity_set_string(id, EV_SZ_viewmodel, DEFAULT_V_MODEL);
}

// Crear una bomba
create_bomb(id)
{
	static ent, Float:curtime;
	ent = create_entity("info_target");
	
	entity_set_string(ent, EV_SZ_classname, BOMB_CLASSNAME);
	entity_set_int(ent, EV_INT_iuser1, BOMB_CONST);
	entity_set_model(ent, BOMB_MODEL);
	
	//entity_set_int(ent, EV_INT_movetype, MOVETYPE_FLY);
	
	// Obtenemos la posicion del jugador
	static Float:origin[3];
	entity_get_vector(id, EV_VEC_origin, origin);
	origin[2] = BOMB_Z_POS;
	
	// Ajustamos la posicion al centro del bloque donde se encuentra
	adjust_to_map(origin);
	
	entity_set_origin(ent, origin);
	entity_set_size(ent, Float:{ -16.0, -16.0, 20.0 }, Float:{ 16.0, 16.0, 70.0 });
	entity_set_int(ent, EV_INT_solid, SOLID_NOT);
		
	// Almacenamos el id de quien puso esta bomba
	entity_set_int(ent, EV_INT_iuser2, id);
	
	curtime = halflife_time();
	entity_set_float(ent, EV_FL_nextthink, curtime + 0.05);
	entity_set_float(ent, EV_FL_fuser1, curtime + DETONATE_DELAY);
	
	emit_sound(ent, CHAN_AUTO, SOUND_PLANT, VOL_NORM, ATTN_NORM, 0, PITCH_NORM);
	
	g_bombs[id]++;
	
	return ent;
}

// Crear una caja removible
create_box(Float:origin[3], item, room)
{
	static ent;
	ent = create_entity("info_target");
	
	entity_set_string(ent, EV_SZ_classname, BOX_CLASSNAME);
	
	entity_set_origin(ent, origin);
	
	entity_set_model(ent, BLOCK_MODEL);
	entity_set_size(ent, Float:{ -18.0, -18.0, -20.0 }, Float:{ 18.0, 18.0, 20.0 });
	entity_set_int(ent, EV_INT_skin, 2);
	entity_set_float(ent, EV_FL_gravity, 1.0);
	entity_set_float(ent, EV_FL_friction, 1.0);
	entity_set_float(ent, EV_FL_takedamage, 1.0);
	entity_set_float(ent, EV_FL_health, 99999.9);
	
	entity_set_int(ent, EV_INT_solid, SOLID_SLIDEBOX);
	
	entity_set_int(ent, EV_INT_iuser1, BLOCK_CONST);
	
	if (item)
	{
		entity_set_int(ent, EV_INT_iuser2, item);
	}
	
	entity_set_int(ent, EV_INT_iuser3, room);
	
	drop_to_floor(ent);
	entity_set_int(ent, EV_INT_movetype, MOVETYPE_FLY);
	
	return ent;
}

create_powerup(Float:origin[3], powerup)
{
	new ent = create_entity("info_target");
	
	entity_set_string(ent, EV_SZ_classname, POWERUP_CLASSNAME);
	entity_set_origin(ent, origin);
	entity_set_int(ent, EV_INT_iuser2, powerup);
	
	entity_set_float(ent, EV_FL_nextthink, halflife_time() + 0.3);
	
	return ent;
}

// Ajustar al mapa
// Dada una posicion cualquiera dentro de una sala, la ajusta al centro del bloque donde se encuentra
adjust_to_map(Float:origin[3], &x = 0, &y = 0)
{
	// Hardcode
	static iorigin[3];
	FVecIVec(origin, iorigin);
	
	// 704 es la distancia entre cada pared de cada sala en el mapa bomberman_final
	x = (iorigin[0] % 704)/40;
	y = (iorigin[1] % 704)/40;
	
	origin[0] = 20.0 + (704.0 * float(iorigin[0]/704)) + 40.0 * (float(x));
	
	if (iorigin[1] >= 700)
		origin[1] = 724.0 + 40.0 * float(y);
	else
		origin[1] = 20.0 + 40.0 * float(y);
}

// Obtener la posicion en coordenadas dado el numero de un bloque en un salon especifico
origin_from_block(room, block_x, block_y, Float:origin[3])
{
	origin[0] = (float((room-1)/2) * 704.0) - 20.0 + 40.0*float(block_x);
	origin[1] = ((room+1)%2) ? 684.0 : -20.0; 
	origin[1] = origin[1] + 40.0*float(block_y);
}

bool:is_origin_inside_room(Float:origin[3], room)
{
	new Float:minpos, Float:maxpos;
	minpos = (float((room-1)/2) * 704.0);
	maxpos = minpos + 600.0;
	
	if (origin[0] < minpos || origin[0] > maxpos)
		return false;
	
	minpos = ((room+1)%2) ? 704.0 : 0.0;
	maxpos = minpos + 600.0;
	
	if (origin[1] < minpos || origin[1] > maxpos)
		return false;
	
	return true;
}

// Cuandos jugadores hay en un salon
room_players(room)
{
	new pl = 0;
	for (new i = 1; i <= 32; i++)
	{
		if (g_status[i] >= STATUS_JOINING && g_battle[i] == room)
			pl++;
	}
	
	return pl;
}

// Cuandos jugadores vivos hay en un salon
// Si hay solo 1, retorna 32 + su id
room_alive_players(room)
{
	new pl = 0, last;
	for (new i = 1; i <= 32; i++)
	{
		if (g_status[i] == STATUS_JOINED && g_battle[i] == room && g_canbattle[i] && g_alive[i])
		{
			pl++;
			last = i;
		}
	}
	
	return (pl == 1) ? 32 + last : pl;
}

// En un salon entran 4 jugadores, a cada un se le asigna un color
// Esta funcion obtiene un color que no se esté usando
get_free_character(room)
{
	new pl = 0, i = 1;
	
	for ( ; i <= 32; i++)
	{
		if (g_status[i] >= STATUS_JOINING && g_battle[i] == room)
			pl |= (1<<g_character[i]);
	}
	
	for (i = 1; i <= 4; i++)
	{
		if (~pl & (1<<i))
			return i;
	}
	
	return 0;
}

spawn_to_origin(id, Float:startorigin[3])
{
	if (!is_user_alive(id))
		ExecuteHamB(Ham_CS_RoundRespawn, id);
	
	reset_vars(id);
	
	static Float:origin[3];
	switch (g_character[id])
	{
		case 1:
		{
			origin[0] = startorigin[0];
			origin[1] = startorigin[1];
		}
		case 2:
		{
			origin[0] = startorigin[0] + 14.0*40.0;
			origin[1] = startorigin[1] + 14.0*40.0;
		}
		case 3:
		{
			origin[0] = startorigin[0];
			origin[1] = startorigin[1] + 14.0*40.0;
		}
		case 4:
		{
			origin[0] = startorigin[0] + 14.0*40.0;
			origin[1] = startorigin[1];
		}
	}
	
	origin[2] = 120.0;
	entity_set_origin(id, origin);
	set_user_maxspeed(id, 0.1);
	entity_set_int(id, EV_INT_skin, g_character[id]);
}

angles_direction(Float:anglesIn[3])
{
	static Float:angleabs;
	angleabs = floatabs(anglesIn[1]);
	
	return angleabs < 45.0 ? 1 : ((angleabs > 135.0 ? 3 : (anglesIn[1] > 0.0 ? 2 : 4)));
}

velocity_by_direction(direction, Float:speed, Float:velOut[3])
{
	if (direction % 2)
	{
		velOut[0] = direction == 1 ? speed : -speed;
		velOut[1] = 0.0;
	}
	else
	{
		velOut[0] = 0.0;
		velOut[1] = direction == 2 ? speed : -speed;
	}
	velOut[2] = 0.0;
}

public fix_camera_angles(id)
{
	if (!is_user_alive(id))
		return;
	
	static Float:angles[3] = { 15.0, 0.0, 0.0 };
	
	switch (g_character[id])
	{
		case 1: angles[1] = -179.999;
		case 2: angles[1] = 0.0;
		case 3: angles[1] = 90.0;
		case 4: angles[1] = -90.0;
	}
	
	entity_set_vector(id, EV_VEC_angles, angles);
	entity_set_vector(id, EV_VEC_v_angle, angles);
	entity_set_int(id, EV_INT_fixangle, 1);
}

// La musica del mod es un tributo a los clasicos de Bomberman 1983-2003
update_music(room)
{
	new music = random(sizeof(SOUND_BATTLE_BG));
	g_music[room - 1] = music;
	
	for (new i = 1; i <= 32; i++)
	{
		if (g_status[i] == STATUS_JOINED && g_battle[i] == room && music_enabled(i) && is_user_connected(i))
			client_cmd(i, "mp3 loop sound/%s", SOUND_BATTLE_BG[music]);
	}
}

reset_vars(id, resetall = 0)
{
	g_bombs[id] = 0;
	g_powerups[id][MAXBOMBS] = g_powerups[id][FIRE] = g_powerups[id][SKATE] = g_powerups[id][HEART] = 1;
	g_powerups[id][GLOVES] = g_powerups[id][KICK] = g_holding[id] = g_canbattle[id] = 0;
	g_nextplant[id] = 0.0;
	g_direction[id] = 0;
	
	if (resetall)
	{
		g_alive[id] = g_battle[id] = g_score[id] = g_camera[id] = 0;
		music_activate(id);
		g_character[id] = 0;
	}
}

screen_fade(id)
{
	static msgScreenFade;
	if (!msgScreenFade)
		msgScreenFade = get_user_msgid("ScreenFade");
	
	message_begin(MSG_ONE_UNRELIABLE, msgScreenFade, _, id);
	write_short(2*4096); // duracion
	write_short(0); // tiempo de espera
	write_short(0x0000);
	write_byte(255); 		// R
	write_byte(0); 			// G
	write_byte(0);	 		// B
	write_byte(150);
	message_end();
}

print_color(id, text[], any:...)
{
	static msg[191], len;
	vformat(msg, charsmax(msg), text, 3);
	len = strlen(msg);

	replace_all(msg, len, "!y", "^x01");
	replace_all(msg, len, "!t", "^x03");
	replace_all(msg, len, "!g", "^x04");
	
	message_begin(MSG_ONE_UNRELIABLE, g_msgSayText, .player = id);
	write_byte(33);
	write_string(msg);
	message_end();
}
