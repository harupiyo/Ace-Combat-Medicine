#include "\a3\ui_f\hpp\defineCommonGrids.inc"

#define IDC_SYRINGEDRAW 84000
#define IDC_SYRINGEDRAW_TEXT 84001
#define IDC_SYRINGEDRAW_BOTTOMTEXT 84002
#define IDC_SYRINGEDRAW_BUTTON_DRAW 84003
#define IDC_SYRINGEDRAW_BUTTON_PUSH 84004
#define IDC_SYRINGEDRAW_PLUNGER 84005
#define IDC_SYRINGEDRAW_SYRINGE_IV_GROUP 84006
#define IDC_SYRINGEDRAW_SYRINGE_IV_PLUNGER 84007
#define IDC_SYRINGEDRAW_SYRINGE_IM_GROUP 84008
#define IDC_SYRINGEDRAW_SYRINGE_IM_PLUNGER 84009

#define SYRINGEDRAW_MOUSE_X (safezoneX + (safezoneW / 2))
#define SYRINGEDRAW_LIMIT_IV_TOP (safezoneY + (safezoneH / 1.43))
#define SYRINGEDRAW_LIMIT_IV_BOTTOM (safezoneY + (safezoneH / 1.13))
#define SYRINGEDRAW_LIMIT_IV_BOTTOM_MOUSE (safezoneY + (safezoneH / 1.11))

#define SYRINGEDRAW_LIMIT_IM_TOP (safezoneY + (safezoneH / 1.457))
#define SYRINGEDRAW_LIMIT_IM_TOP_MOUSE (safezoneY + (safezoneH / 1.452))