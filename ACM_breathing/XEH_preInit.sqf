#include "script_component.hpp"

ADDON = false;

PREP_RECOMPILE_START;
#include "XEH_PREP.hpp"
PREP_RECOMPILE_END;

call FUNC(generatePTXMap);

#define ACM_SETTINGS_CATEGORY "ACM: Breathing" // ACM: 呼吸の設定カテゴリ

[
    QGVAR(altitudeAffectOxygen),
    "CHECKBOX",
    ["Altitude Affect Oxygen", "Sets whether oxygen saturation calculations are affected by altitude of terrain"], // 高度が酸素飽和度の計算に影響するかどうかを設定
    [ACM_SETTINGS_CATEGORY, ""],
    [false],
    true
] call CBA_fnc_addSetting;

// 気胸
    
[
    QGVAR(pneumothoraxEnabled),
    "CHECKBOX",
    "Pneumothorax Enabled", // 気胸を有効にする
    [ACM_SETTINGS_CATEGORY, "Pneumothorax"],
    [true],
    true
] call CBA_fnc_addSetting;

[
    QGVAR(chestInjuryChance),
    "SLIDER",
    ["Chest Injury Severity Multiplier", "Chance that a chest injury causes pneumothorax"], // 胸部損傷が気胸を引き起こす確率
    [ACM_SETTINGS_CATEGORY, "Pneumothorax"],
    [0, 2, 1, 1],
    true
] call CBA_fnc_addSetting;

[
    QGVAR(pneumothoraxDeteriorateChance),
    "SLIDER",
    ["Pneumothorax Deterioration Multiplier", "Chance that pneumothorax will deteriorate"], // 気胸が悪化する確率
    [ACM_SETTINGS_CATEGORY, "Pneumothorax"],
    [0, 2, 1, 1],
    true
] call CBA_fnc_addSetting;

[
    QGVAR(Hardcore_ChestInjury),
    "CHECKBOX",
    ["[HARDCORE] Chest Injuries", "[HARDCORE] Sets whether Tension Pneumothorax should require further treatment to fully heal"], // 緊張性気胸が完全に治癒するために追加の治療が必要かどうかを設定
    [ACM_SETTINGS_CATEGORY, "Pneumothorax"],
    [false],
    true
] call CBA_fnc_addSetting;

[
    QGVAR(Hardcore_HemothoraxBleeding),
    "CHECKBOX",
    ["[HARDCORE] Hemothorax Bleeding", "[HARDCORE] Sets whether Hemothorax should require further treatment to fully stop internal bleeding"], // 血胸が完全に内部出血を止めるために追加の治療が必要かどうかを設定
    [ACM_SETTINGS_CATEGORY, "Pneumothorax"],
    [false],
    true
] call CBA_fnc_addSetting;

// 診断

[
    QGVAR(allowInspectChest),
    "LIST",
    ["Allow Inspect Chest", "Training level required to Inspect Chest"], // 胸部を検査するために必要な訓練レベル
    [ACM_SETTINGS_CATEGORY, "Diagnosis"],
    [SETTING_DROPDOWN_SKILL, 0],
    true
] call CBA_fnc_addSetting;

[
    QGVAR(treatmentTimeInspectChest),
    "SLIDER",
    "Inspect Chest Time", // 胸部検査の時間
    [ACM_SETTINGS_CATEGORY, "Diagnosis"],
    [1, 30, 6, 1],
    true
] call CBA_fnc_addSetting;

// 治療

[
    QGVAR(allowNCD),
    "LIST",
    ["Allow NCD Kit", "Training level required to use NCD Kit"], // NCDキットを使用するために必要な訓練レベル
    [ACM_SETTINGS_CATEGORY, "Treatment"],
    [SETTING_DROPDOWN_SKILL, 1],
    true
] call CBA_fnc_addSetting;

[
    QGVAR(allowThoracostomy),
    "LIST",
    ["Allow Thoracostomy", "Training level required to perform Thoracostomy"], // 胸腔切開を行うために必要な訓練レベル
    [ACM_SETTINGS_CATEGORY, "Treatment"],
    [SETTING_DROPDOWN_SKILL, 1],
    true
] call CBA_fnc_addSetting;

[
    QGVAR(locationThoracostomy),
    "LIST",
    ["Locations Thoracostomy", "Sets locations at which Thoracostomy can be performed"], // 胸腔切開を行う場所を設定
    [ACM_SETTINGS_CATEGORY, "Treatment"],
    [SETTING_DROPDOWN_LOCATION, 3],
    true
] call CBA_fnc_addSetting;

ADDON = true;
