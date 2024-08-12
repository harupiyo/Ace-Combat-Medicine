#include "..\script_component.hpp"
/*
 * 作成者: Blue
 * 患者の循環系の状態を更新
 *
 * 引数:
 * 0: 患者 <OBJECT>
 *
 * 戻り値:
 * なし
 *
 * 例:
 * [player] call ACM_circulation_fnc_updateCirculationState;
 *
 * 公開: いいえ
 */

params ["_patient"];

// 初期状態をtrueに設定
private _state = true;

// 患者の状態に応じて循環系の状態を更新
switch (true) do {
    // 酸素レベルが低酸素症の閾値を下回る場合
    case (GET_OXYGEN(_patient) < ACM_OXYGEN_HYPOXIA);
    // 緊張性気胸の状態の場合
    case (_patient getVariable [QEGVAR(breathing,TensionPneumothorax_State), false]);
    // 血胸の液体量が閾値を超える場合
    case ((_patient getVariable [QEGVAR(breathing,Hemothorax_Fluid), 0]) > ACM_TENSIONHEMOTHORAX_THRESHOLD);
    // 血液量がクラス4出血の閾値を下回る場合
    case (GET_BLOOD_VOLUME(_patient) < BLOOD_VOLUME_CLASS_4_HEMORRHAGE): {
        _state = false;
    };
    default {};
};

// 循環系の状態を設定
_patient setVariable [QGVAR(CirculationState), _state, true];
