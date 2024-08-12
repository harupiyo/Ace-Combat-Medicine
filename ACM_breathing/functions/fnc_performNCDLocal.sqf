#include "..\script_component.hpp"
/*
 * 作成者: Blue
 * 患者に対する針胸腔減圧を実施 (ローカル)
 *
 * 引数:
 * 0: 医療担当者 <OBJECT>
 * 1: 患者 <OBJECT>
 *
 * 戻り値:
 * なし
 *
 * 例:
 * [player, cursorTarget] call ACM_breathing_fnc_performNCDLocal;
 *
 * 公開: いいえ
 */

params ["_medic", "_patient"];

// 患者の痛みレベルを調整
[_patient, 0.5] call ACEFUNC(medical,adjustPainLevel);

// 患者が緊張性気胸の状態である場合の処理
if (_patient getVariable [QGVAR(TensionPneumothorax_State), false]) then {
    // 緊張性気胸の状態を解除
    _patient setVariable [QGVAR(TensionPneumothorax_State), false, true];

    // 気胸の状態が0より大きい場合の処理
    if (_patient getVariable [QGVAR(Pneumothorax_State), 0] > 0) then {
        // 気胸の状態を0に設定
        _patient setVariable [QGVAR(Pneumothorax_State), 0, true];

        // 胸部シールがない場合の処理
        if !(_patient getVariable [QGVAR(ChestSeal_State), false]) then {
            // 気胸の処理を実行
            [_patient] call FUNC(handlePneumothorax);
        } else {
            // 呼吸状態を更新
            [_patient] call FUNC(updateBreathingState);
        };
    } else {
        // 呼吸状態を更新
        [_patient] call FUNC(updateBreathingState);
    };
} else {
    // 胸部シールがない場合の処理
    if !(_patient getVariable [QGVAR(ChestSeal_State), false]) then {
        // 気胸の状態を3に設定
        _patient setVariable [QGVAR(Pneumothorax_State), 3, true];
    };
};
