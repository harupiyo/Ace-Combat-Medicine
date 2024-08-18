#include "..\script_component.hpp"
/*
 * 作成者: Blue
 * 気胸の悪化を処理 (ローカル)
 *
 * 引数:
 * 0: 患者 <OBJECT>
 *
 * 戻り値:
 * なし
 *
 * 例:
 * [player] call ACM_breathing_fnc_handlePneumothorax;
 *
 * 公開: いいえ
 */

params ["_patient"];

// 患者が緊張性気胸の状態である場合は終了
if (_patient getVariable [QGVAR(TensionPneumothorax_State), false]) exitWith {};

// 現在の気胸の状態を取得
private _state = _patient getVariable [QGVAR(Pneumothorax_State), 0];

// 気胸の状態が3を超えている場合は緊張性気胸に設定
if (_state > 3) then {
    _patient setVariable [QGVAR(TensionPneumothorax_State), true, true];
} else {
    // 気胸の状態を1増加
    _state = _state + 1;
    _patient setVariable [QGVAR(Pneumothorax_State), _state, true];
};

// 呼吸状態を更新
[_patient] call FUNC(updateBreathingState);

// 気胸のPerFrameHandlerが既に設定されている場合は終了
if (_patient getVariable [QGVAR(Pneumothorax_PFH), -1] != -1) exitWith {};

// PerFrameHandlerを追加
private _PFH = [{
    params ["_args", "_idPFH"];
    _args params ["_patient"];

    // 呼吸状態と気胸の状態を取得
    private _breathingState = GET_BREATHINGSTATE(_patient);
    private _isBreathing = (GET_AIRWAYSTATE(_patient) > 0 && _breathingState > 0);
    private _pneumothoraxState = _patient getVariable [QGVAR(Pneumothorax_State), 0];

    // 患者が生存していない、胸部外傷がない、気胸の状態が1未満、緊張性気胸、または胸腔穿刺がある場合は終了
    // 緊張性気胸の場合に処理を終了するのはこれ以上悪くなりようが無いから
    if (!(alive _patient) || !(_patient getVariable [QGVAR(ChestInjury_State), false]) || (_pneumothoraxState < 1 && (_patient getVariable [QGVAR(ChestSeal_State), false])) || _patient getVariable [QGVAR(TensionPneumothorax_State), false] || _patient getVariable [QGVAR(Thoracostomy_State), 0] > 0) exitWith {
        _patient setVariable [QGVAR(Pneumothorax_PFH), -1];
        [_idPFH] call CBA_fnc_removePerFrameHandler;
    };

    // 患者が呼吸していない場合は終了
    if !(_isBreathing) exitWith {};

    // 気胸の悪化確率に基づいて気胸の状態を更新
    // ランダムな数値が悪化確率より小さい場合、気胸状態が悪化します
    if (random 100 < ((40 + _breathingState * 15) * GVAR(pneumothoraxDeteriorateChance))) then {
        _pneumothoraxState = _pneumothoraxState + 1;    // 悪化
        // 気胸状態に基づいて痛みのレベルを設定します
        [_patient, (_pneumothoraxState / 4)] call ACEFUNC(medical,adjustPainLevel);

        if (_pneumothoraxState > 4) then {
            _patient setVariable [QGVAR(Pneumothorax_State), 4, true];              // 気胸状態を最大値の4に設定
            _patient setVariable [QGVAR(TensionPneumothorax_State), true, true];    // 緊張性気胸の状態を true に設定
            if (GVAR(Hardcore_ChestInjury)) then {
                _patient setVariable [QGVAR(Hardcore_Pneumothorax), true, true];    // ハードコアモードでの気胸状態を true に設定
            };
        } else {
            _patient setVariable [QGVAR(Pneumothorax_State), _pneumothoraxState, true]; // 気胸状態を現在の値に設定
        };

        // 患者の呼吸状態を更新
        [_patient] call FUNC(updateBreathingState);
    };

}, (40 + (random 40)), [_patient]] call CBA_fnc_addPerFrameHandler;
    // (40 + (random 40)) は、ハンドラが実行される間隔をミリ秒単位で指定します。40ミリ秒から80ミリ秒の間でランダムに決定されます。

// 気胸のPerFrameHandlerを設定
_patient setVariable [QGVAR(Pneumothorax_PFH), _PFH];
