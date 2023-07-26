#if defined _mycolors_included
 #endinput
#endif
#define _mycolors_included

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

//Example for RED: gI_Colors[RED]
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

stock Menu CreateColorMenu(int client, Color current)
{
    Menu menu = new Menu(Color_MenuHandler);
    menu.SetTitle("Select a color");
    menu.ExitBackButton = true;

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

    return menu;
}