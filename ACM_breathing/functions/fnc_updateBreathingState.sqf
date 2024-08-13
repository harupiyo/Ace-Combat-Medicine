#include "..\script_component.hpp"
/*
 * 作成者: Blue
 * 患者の呼吸状態を更新
 *
 * 引数:
 * 0: 患者 <OBJECT>
 * 1: 治癒されたかどうか <BOOL>
 *
 * 戻り値:
 * なし
 *
 * 例:
 * [player, false] call ACM_airway_fnc_updateBreathingState;
 *
 * 公開: いいえ
 */

params ["_patient", ["_healed", false]];

// 初期状態を1に設定
private _state = 1;

// 血胸の状態と液体量を取得
private _HTXState = _patient getVariable [QGVAR(Hemothorax_State), 0];  // 使っていない
private _HTXFluid = _patient getVariable [QGVAR(Hemothorax_Fluid), 0];

// 気胸、緊張性気胸、ハードコア気胸の状態を取得
private _PTXState = _patient getVariable [QGVAR(Pneumothorax_State), 0];
private _TPTXState = _patient getVariable [QGVAR(TensionPneumothorax_State), false];
private _hardcorePTX = _patient getVariable [QGVAR(Hardcore_Pneumothorax), false];

// 血胸の液体量が0.3を超える場合の処理
if (_HTXFluid > 0.3) then {
    _state = 1 - (0.9 * (_HTXFluid / 1.5));
};

// 緊張性気胸の状態の場合の処理
if (_TPTXState) then {
    _state = 0.1;
} else {
    _state = _state - (_PTXState / 10);
};

// 肺の状態を更新
[_patient, _healed] call FUNC(updateLungState);

// ハードコア気胸の状態の場合の処理
if (_hardcorePTX) then {
    _state = _state min 0.8;
};

// 治癒された場合の処理
if (_healed) then {
    _state = 1;
};

// 呼吸状態を設定
_patient setVariable [QGVAR(BreathingState), _state, true];
