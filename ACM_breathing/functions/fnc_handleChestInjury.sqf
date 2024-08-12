#include "..\script_component.hpp"
/*
 * 作成者: Blue
 * 胸部外傷の結果を処理 (ローカル)
 *
 * 引数:
 * 0: 患者 <OBJECT>
 * 1: 傷のID <NUMBER>
 *
 * 戻り値:
 * なし
 *
 * 例:
 * [player, 60] call ACM_breathing_fnc_handleChestInjury;
 *
 * 公開: いいえ
 */

params ["_patient", "_woundID"];

// 胸部外傷の状態が設定されていない場合、設定する
if !(_patient getVariable [QGVAR(ChestInjury_State), false]) then {
    _patient setVariable [QGVAR(ChestInjury_State), true, true];
};

// 傷のIDに基づいて確率を取得
private _chance = GVAR(ChestInjury_Chances) get _woundID;

// 確率に基づいて胸部外傷の結果を処理
if (random 100 < (_chance * GVAR(chestInjuryChance))) then {
    // 20%の確率で血胸を処理
    if (random 1 < 0.2) then {
        [_patient] call FUNC(handleHemothorax);
    } else {
        // それ以外の場合は気胸を処理
        [_patient] call FUNC(handlePneumothorax);
    };
    // 肺の状態を更新
    [_patient] call FUNC(updateLungState);
};
