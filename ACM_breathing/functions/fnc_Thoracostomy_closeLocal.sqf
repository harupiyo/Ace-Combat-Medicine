#include "..\script_component.hpp"
/*
 * Author: Blue
 * 胸腔切開部を閉じる処置（ローカル）
 *
 * Arguments:
 * 0: Medic <OBJECT> - 医療担当者
 * 1: Patient <OBJECT> - 患者
 *
 * Return Value:
 * None - 戻り値なし
 *
 * Example:
 * [player, cursorTarget] call ACM_breathing_fnc_Thoracostomy_closeLocal;
 *
 * Public: No - 公開されていない
 */

params ["_medic", "_patient"]; // 引数として医療担当者と患者を受け取る

// 胸腔切開部を閉じて一方向弁を設置したことを表示
[QACEGVAR(common,displayTextStructured), ["Thoracostomy incision sealed and one-way valve placed", 2, _medic], _medic] call CBA_fnc_targetEvent;

// 患者の胸腔切開状態をリセット
_patient setVariable [QGVAR(Thoracostomy_State), 0, true];
// 患者の気胸状態をリセット
_patient setVariable [QGVAR(Pneumothorax_State), 0, true];

// 患者の呼吸状態を更新
[_patient] call FUNC(updateBreathingState);