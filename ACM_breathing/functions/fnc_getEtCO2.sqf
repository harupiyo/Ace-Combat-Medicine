#include "..\script_component.hpp"
/*
 * Author: Blue
 * Get EtCO2 of patient.
 * 患者の呼気終末二酸化炭素（EtCO2）を取得する
 *
 * Arguments:
 * 0: Patient <OBJECT> - 患者
 *
 * Return Value:
 * End-Tidal Carbon Dioxide (mmHg) <NUMBER> - 呼気終末二酸化炭素（mmHg）
 *
 * Example:
 * [player] call ACM_breathing_fnc_getEtCO2;
 * 例：[player] call ACM_breathing_fnc_getEtCO2;
 *
 * Public: No - 公開されていない
 */

params ["_patient"]; // 引数として患者を受け取る

/* mmHg 
    Cardiac Arrest - 0 
    Effective CPR - 10-20
    Unconscious - 30-35
    Conscious (Normal) - 35-45
    ROSC (Momentary) - 45-50
    心停止 - 0
    効果的なCPR - 10-20
    無意識 - 30-35
    意識あり（正常） - 35-45
    ROSC（一時的） - 45-50
*/
private _timeSinceROSC = (CBA_missionTime - (_patient getVariable [QEGVAR(circulation,ROSC_Time), -30])); // ROSC（自発循環回復）からの経過時間を計算
private _exit = false; // 終了フラグ
private _minFrom = 0; // 線形変換の最小入力値
private _maxFrom = 0; // 線形変換の最大入力値
private _value = 0; // 計算値
private _minTo = 0; // 線形変換の最小出力値
private _maxTo = 0; // 線形変換の最大出力値

private _airwayState = (GET_AIRWAYSTATE(_patient) / 0.95) min 1; // 気道の状態を取得し、最大値を1に制限
private _breathingState = (GET_BREATHINGSTATE(_patient) / 0.85) min 1; // 呼吸の状態を取得し、最大値を1に制限

// ROSCから30秒未満の場合
if (_timeSinceROSC < 30) exitWith {
    linearConversion [0, 30, _timeSinceROSC, 50, 30, true]; // 線形変換を使用してEtCO2を計算
};

private _desiredRespirationRate = _patient getVariable [QEGVAR(core,TargetVitals_RespirationRate), 16]; // 目標呼吸数を取得

// 心拍数が20未満、心停止状態、または患者が生存していない場合
if ((GET_HEART_RATE(_patient) < 20) || IN_CRDC_ARRST(_patient) || !(alive _patient)) then {
    // CPRを提供している人が生存している場合
    if (alive (_patient getVariable [QACEGVAR(medical,CPR_provider), objNull])) then {
        _minFrom = 100; // 線形変換の最小入力値を設定
        _maxFrom = 120; // 線形変換の最大入力値を設定
        _value = GET_HEART_RATE(_patient); // 患者の心拍数を取得
        _minTo = 10; // 線形変換の最小出力値を設定
        _maxTo = 20; // 線形変換の最大出力値を設定
    } else {
        _exit = true; // 終了フラグを設定
    };
} else {
    _value = GET_RESPIRATION_RATE(_patient); // 患者の呼吸数を取得
    // 呼吸数が目標呼吸数未満の場合
    if (_value < _desiredRespirationRate) then {
        _minFrom = 1; // 線形変換の最小入力値を設定
        _maxFrom = _desiredRespirationRate; // 線形変換の最大入力値を設定
        // 患者が無意識の場合
        if (IS_UNCONSCIOUS(_patient)) then {
            _minTo = 35; // 線形変換の最小出力値を設定
            _maxTo = 30; // 線形変換の最大出力値を設定
        } else {
            _minTo = 45; // 線形変換の最小出力値を設定
            _maxTo = 35; // 線形変換の最大出力値を設定
        };
    } else {
        _minFrom = _desiredRespirationRate; // 線形変換の最小入力値を設定
        _maxFrom = 50; // 線形変換の最大入力値を設定
        // 患者が無意識の場合
        if (IS_UNCONSCIOUS(_patient)) then {
            _minTo = 30; // 線形変換の最小出力値を設定
            _maxTo = 15; // 線形変換の最大出力値を設定
        } else {
            _minTo = 35; // 線形変換の最小出力値を設定
            _maxTo = 20; // 線形変換の最大出力値を設定
        };
    };
};

// 終了フラグが設定されている場合
if (_exit) exitWith {0};

// 線形変換を使用してEtCO2を計算
linearConversion [_minFrom, _maxFrom, (_value * (_airwayState min _breathingState)), _minTo, _maxTo, true];