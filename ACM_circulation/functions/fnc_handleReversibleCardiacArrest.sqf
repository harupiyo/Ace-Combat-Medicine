#include "..\script_component.hpp"
/*
 * 作成者: Blue
 * 可逆的心停止の処理 (ローカル)
 *
 * 引数:
 * 0: 患者 <OBJECT>
 *
 * 戻り値:
 * なし
 *
 * 例:
 * [player] call ACM_circulation_fnc_handleReversibleCardiacArrest;
 *
 * 公開: いいえ
 */

params ["_patient"];

// 心停止のリズム状態が0でない、または可逆的心停止のPerFrameHandlerが既に設定されている場合は終了
if (_patient getVariable [QGVAR(CardiacArrest_RhythmState), 0] != 0 || _patient getVariable [QGVAR(ReversibleCardiacArrest_PFH), -1] != -1) exitWith {};

// 可逆的心停止の状態と時間を設定
_patient setVariable [QGVAR(ReversibleCardiacArrest_State), true, true];
_patient setVariable [QGVAR(ReversibleCardiacArrest_Time), CBA_missionTime];
_patient setVariable [QGVAR(CardiacArrest_RhythmState), 5, true];

// 循環系の状態を更新
[_patient] call FUNC(updateCirculationState);

// PerFrameHandlerを追加
private _PFH = [{
    params ["_args", "_idPFH"];
    _args params ["_patient"];

    // 可逆的心停止の時間と原因を取得
    private _time = _patient getVariable [QGVAR(ReversibleCardiacArrest_Time), -1];
    // 可逆的な原因は緊張性気胸、胸腔内出血が重大である、低血液量（出血性ショック）、低酸素症からなる
    // 可逆的な原因がある時、_reversibleCause は true になる
    private _reversibleCause = _patient getVariable [QEGVAR(breathing,TensionPneumothorax_State), false] || ((_patient getVariable [QEGVAR(breathing,Hemothorax_Fluid), 0] > ACM_TENSIONHEMOTHORAX_THRESHOLD)) || (GET_BLOOD_VOLUME(_patient) <= ACM_REVERSIBLE_CA_BLOODVOLUME) || (GET_OXYGEN(_patient) < ACM_OXYGEN_HYPOXIA);
    
    // 心停止のリズム状態が5でない、可逆的原因がない、心停止状態でない、患者が生存していない、または時間が経過した場合は終了
    if (_patient getVariable [QGVAR(CardiacArrest_RhythmState), 0] != 5 || !_reversibleCause || !(IN_CRDC_ARRST(_patient)) || !(alive _patient) || ((_time + 360) < CBA_missionTime)) exitWith {
        _patient setVariable [QGVAR(ReversibleCardiacArrest_State), false, true];
        
        // 心停止状態で生存しており、時間が経過していない場合はROSCを試みる
        if (IN_CRDC_ARRST(_patient) && (alive _patient) && ((_time + 360) > CBA_missionTime) && _patient getVariable [QGVAR(CardiacArrest_RhythmState), 0] == 5) then { // Reversed
            [QGVAR(attemptROSC), _patient] call CBA_fnc_localEvent;
        } else {
            // 心停止状態で生存している場合は心停止を処理
            if (IN_CRDC_ARRST(_patient) && (alive _patient)) then { // Timed out (deteriorated)
                [QGVAR(handleCardiacArrest), _patient] call CBA_fnc_localEvent;
            };
        };

        // 可逆的心停止のPerFrameHandlerを解除
        _patient setVariable [QGVAR(ReversibleCardiacArrest_PFH), -1];

        // 循環系の状態を更新
        [_patient] call FUNC(updateCirculationState);

        // PerFrameHandlerを削除
        [_idPFH] call CBA_fnc_removePerFrameHandler;
    };
}, 5, [_patient]] call CBA_fnc_addPerFrameHandler;

// 可逆的心停止のPerFrameHandlerを設定
_patient setVariable [QGVAR(ReversibleCardiacArrest_PFH), _PFH];
