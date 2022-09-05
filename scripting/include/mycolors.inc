#if defined _mycolors_included
 #endinput
#endif
#define _mycolors_included

ColorCB gH_ColorCallback;

/**
 * Callback for when the client selects a color.
 */
typedef ColorCB = function void(int client, Color color, bool exitBack);

enum Color
{
    WHITE,
    RED,
    CYAN,
    PURPLE,
    GREEN,
    BLUE,
    YELLOW,
    ORANGE = 7,
    COLORS_SIZE
};

int gI_ColorIndex[COLORS_SIZE][4] =
{
    {255, 255, 255, 255}, //WHITE
    {255, 0,   0,   255}, //RED
    {0,   255, 255, 255}, //CYAN
    {128, 0,   128, 255}, //PURPLE
    {0,   255, 0,   255}, //GREEN
    {0,   0,   255, 255}, //BLUE
    {255, 255, 0,   255}, //YELLOW
    {255, 165, 0,   255}  //ORANGE
};

stock void GetColorString(Color color, char[] buffer, int length)
{
    if(color == WHITE)
    {
        strcopy(buffer, length, "White");
    }
    else if(color == RED)
    {
        strcopy(buffer, length, "Red");
    }
    else if(color == CYAN)
    {
        strcopy(buffer, length, "Cyan");
    }
    else if(color == PURPLE)
    {
        strcopy(buffer, length, "Purple");
    }
    else if(color == GREEN)
    {
        strcopy(buffer, length, "Green");
    }
    else if(color == BLUE)
    {
        strcopy(buffer, length, "Blue");
    }
    else if(color == YELLOW)
    {
        strcopy(buffer, length, "Yellow");
    }
    else if(color == ORANGE)
    {
        strcopy(buffer, length, "Orange");
    }
}

stock bool CreateColorMenu(int client, Color current, ColorCB callback)
{
    Menu menu = new Menu(Color_MenuHandler);

    char info[4];

    IntToString(view_as<int>(WHITE), info, sizeof(info));
    menu.AddItem(info, "White", current == WHITE ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

    IntToString(view_as<int>(RED), info, sizeof(info));
    menu.AddItem(info, "Red", current == RED ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

    IntToString(view_as<int>(CYAN), info, sizeof(info));
    menu.AddItem(info, "Cyan", current == CYAN ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

    IntToString(view_as<int>(PURPLE), info, sizeof(info));
    menu.AddItem(info, "Purple", current == PURPLE ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

    IntToString(view_as<int>(GREEN), info, sizeof(info));
    menu.AddItem(info, "Green", current == GREEN ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

    IntToString(view_as<int>(BLUE), info, sizeof(info));
    menu.AddItem(info, "Blue", current == BLUE ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

    IntToString(view_as<int>(YELLOW), info, sizeof(info));
    menu.AddItem(info, "Yellow", current == YELLOW ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

    IntToString(view_as<int>(ORANGE), info, sizeof(info));
    menu.AddItem(info, "Orange", current == ORANGE ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

    gH_ColorCallback = callback;

    menu.ExitBackButton = true;
    return menu.Display(client, MENU_TIME_FOREVER);
}

public int Color_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
    switch(action)
    {
        case MenuAction_Select:
        {
            char info[64];
            menu.GetItem(param2, info, sizeof(info));

            Call_StartFunction(INVALID_HANDLE, gH_ColorCallback);
            Call_PushCell(param1);
            Call_PushCell(view_as<Color>(StringToInt(info)));
            Call_PushCell(false);
            Call_Finish();

            CreateColorMenu(param1, view_as<Color>(StringToInt(info)), gH_ColorCallback);
        }

        case MenuAction_Cancel:
        {
            if(param2 == MenuCancel_ExitBack)
            {
                Call_StartFunction(INVALID_HANDLE, gH_ColorCallback);
                Call_PushCell(param1);
                Call_PushCell(-1);
                Call_PushCell(true);
                Call_Finish();
            }
        }
    }

    return 0;
}