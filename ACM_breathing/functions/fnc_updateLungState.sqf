#include "..\script_component.hpp"
/*
 * 作成者: Blue
 * 患者の肺の状態を更新
 *
 * 引数:
 * 0: 患者 <OBJECT>
 * 1: 治癒されたかどうか <BOOL>
 *
 * 戻り値:
 * なし
 *
 * 例:
 * [player, false] call ACM_airway_fnc_updateLungState;
 *
 * 公開: いいえ
 */

params ["_patient", ["_healed", false]];

// 治癒された場合の処理
if (_healed) exitWith {
    _patient setVariable [QGVAR(Stethoscope_LungState), [0,0], true];
};

// 現在の肺の状態を取得
private _lungState = _patient getVariable [QGVAR(Stethoscope_LungState), [0,0]];

// 影響を受けた肺のインデックスを取得
private _affectedIndex = _lungState findIf {_x > 0};

// 影響を受けた肺がない場合、ランダムにインデックスを設定
if (_affectedIndex == -1) then {
    _affectedIndex = round (random 1);
};

// 初期状態を0に設定
private _state = 0;

// 気胸、緊張性気胸、血胸の状態を取得
private _PTXState = _patient getVariable [QGVAR(Pneumothorax_State), 0];
private _TPTXState = _patient getVariable [QGVAR(TensionPneumothorax_State), false];
private _HTXFluid = _patient getVariable [QGVAR(Hemothorax_Fluid), 0];

// 状態に応じて肺の状態を設定
switch (true) do {
    // 緊張性気胸または血胸の液体量が1.1を超える場合
    case (_TPTXState ||_HTXFluid > 1.1): {
        _state = 2;
    };
    // 気胸の状態が0より大きい場合または血胸の液体量が0.3を超える場合
    case (_PTXState > 0 || _HTXFluid > 0.3): {
        _state = 1;
    };
    default {};
};

// 状態が0の場合、肺の状態をリセット
if (_state == 0) exitWith {
    _patient setVariable [QGVAR(Stethoscope_LungState), [0,0], true];
};

// 影響を受けた肺の状態を設定
_lungState set [_affectedIndex, _state];

// 更新された肺の状態を設定
_patient setVariable [QGVAR(Stethoscope_LungState), _lungState, true];
