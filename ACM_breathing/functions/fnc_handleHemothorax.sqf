#include "..\script_component.hpp"
/*
 * 作成者: Blue
 * 血胸の処理 (ローカル)
 *
 * 引数:
 * 0: 患者 <OBJECT>
 *
 * 戻り値:
 * なし
 *
 * 例:
 * [player] call ACM_breathing_fnc_handleHemothorax;
 *
 * 公開: いいえ
 */

params ["_patient"];

// 現在の血胸の状態を取得
private _state = _patient getVariable [QGVAR(Hemothorax_State), 0];

// 血胸の状態が2を超える場合は終了
if (_state > 2) exitWith {};

// 血胸の状態を更新
if (_state == 0) then {
    _state = 1 + round (random 1);
} else {
    _state = _state + 1;
};

// 更新された血胸の状態を設定
_patient setVariable [QGVAR(Hemothorax_State), _state, true];

// 患者の痛みレベルを調整
[_patient, 0.3] call ACEFUNC(medical,adjustPainLevel);

// 呼吸状態を更新
[_patient] call FUNC(updateBreathingState);

// 血胸のPerFrameHandlerが既に設定されている場合は終了
if (_patient getVariable [QGVAR(Hemothorax_PFH), -1] != -1) exitWith {};

// PerFrameHandlerを追加
private _PFH = [{
    params ["_args", "_idPFH"];
    _args params ["_patient"];

    // 現在の血胸の状態を取得
    private _hemothoraxState = _patient getVariable [QGVAR(Hemothorax_State), 0];

    // ハードコア血胸出血が有効で血胸の状態が1の場合は終了
    if (GVAR(Hardcore_HemothoraxBleeding) && _hemothoraxState == 1) exitWith {};

    // 血小板数とTXAの効果を取得
    private _plateletCount = _patient getVariable [QEGVAR(circulation,Platelet_Count), 3];
    private _TXAEffect = [_patient, "TXA_IV", false] call ACEFUNC(medical_status,getMedicationCount);

    // 患者が生存していない、または血胸の状態が0の場合は終了
    if (!(alive _patient) || _hemothoraxState == 0) exitWith {
        _patient setVariable [QGVAR(Hemothorax_PFH), -1];
        [_patient] call FUNC(updateBreathingState);
        [_idPFH] call CBA_fnc_removePerFrameHandler;
    };

    // 血小板数またはTXAの効果がある場合の処理
    if (_plateletCount > 1 || _TXAEffect > 0.1) then {
        if (random 1 < ((0.2 * _plateletCount / 4) max (0.8 * (_TXAEffect min 1.2)))) then {
            _hemothoraxState = (_hemothoraxState - 1) max 0;

            _patient setVariable [QGVAR(Hemothorax_State), _hemothoraxState, true];
        };
    };

    // 呼吸状態を更新
    [_patient] call FUNC(updateBreathingState);
}, (30 + (random 30)), [_patient]] call CBA_fnc_addPerFrameHandler;

// 血胸のPerFrameHandlerを設定
_patient setVariable [QGVAR(Hemothorax_PFH), _PFH];
