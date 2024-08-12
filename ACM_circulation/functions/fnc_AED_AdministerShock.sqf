#include "..\script_component.hpp"
/*
 * 作成者: Blue
 * 除細動器ショックを実行
 *
 * 引数:
 * 0: 医療担当者 <OBJECT>
 * 1: 患者 <OBJECT>
 *
 * 戻り値:
 * なし
 *
 * 例:
 * [player, cursorTarget] call ACM_circulation_fnc_AED_AdministerShock;
 *
 * 公開: いいえ
 */

params ["_medic", "_patient"];

// 患者と医療担当者のAED変数をリセット
_patient setVariable [QGVAR(AED_Charged), false, true];
_patient setVariable [QGVAR(AED_InUse), false, true];
_medic setVariable [QGVAR(AED_Medic_InUse), false, true];

// 最後のショックの時間を記録
_patient setVariable [QGVAR(AED_LastShock), CBA_missionTime, true];

// 患者に対して実行されたショックの総数を増加
private _totalShocks = _patient getVariable [QGVAR(AED_ShockTotal), 0];
_patient setVariable [QGVAR(AED_ShockTotal), (_totalShocks + 1), true];

// AEDがリズム解析モードにあるかどうかを確認
if (_patient getVariable [QGVAR(AED_AnalyzeRhythm_State), false]) then { // AEDモード
    [{ // CPRを開始するリマインダー
        params ["_patient", "_medic"];

        [_patient] call FUNC(AED_TrackCPR);
        playSound3D [QPATHTO_R(sound\aed_startcpr.wav), _patient, false, getPosASL _patient, 15, 1, 15]; // 1.858秒

    }, [_patient, _medic], 2] call CBA_fnc_waitAndExecute;

    _patient setVariable [QGVAR(AED_Analyze_Busy), true, true];

    [{ // アドバイスを聞くために静かにする
        params ["_patient", "_medic"];

        _patient setVariable [QGVAR(AED_Analyze_Busy), false, true];

    }, [_patient, _medic], 4] call CBA_fnc_waitAndExecute;
    _patient setVariable [QGVAR(AED_AnalyzeRhythm_State), false, true];
} else {
    [{ // 3ビープ音を再生
        params ["_patient", "_medic"];

        playSound3D [QPATHTO_R(sound\aed_3beep.wav), _patient, false, getPosASL _patient, 15, 1, 15]; // 0.624秒

    }, [_patient, _medic], 0.7] call CBA_fnc_waitAndExecute;
};

// 患者が生存していない場合は終了
if !(alive _patient) exitWith {};

// 患者の現在の心臓リズム状態を取得
private _currentRhythm = _patient getVariable [QGVAR(CardiacArrest_RhythmState), 0];

// 現在のリズムが指定された状態のいずれかであるかを確認
if (_currentRhythm in [0,1,5]) exitWith {
    _patient setVariable [QGVAR(CardiacArrest_RhythmState), 1, true];
    if (_currentRhythm == 0) then {
        [QACEGVAR(medical,FatalVitals), [_patient], _patient] call CBA_fnc_targetEvent;
    };
};

// 患者に対するアミオダロンの効果を取得
private _amiodarone = ([_patient] call FUNC(getCardiacMedicationEffects)) get "amiodarone";

// CPRの効果を初期化
private _CPREffectiveness = 0;

// 患者に対して実行されたCPRの総量を取得
private _CPRAmount = _patient getVariable [QGVAR(CPR_StoppedTotal), 0];
if (_CPRAmount > 60) then {
    _CPREffectiveness = linearConversion [60, 120, _CPRAmount, 0, 10, false];
};

// 患者が自発循環回復（ROSC）を達成するかどうかを確認
if (random 100 < (_CPREffectiveness + (10 + (10 * _amiodarone)))) exitWith { // ROSC
    [QGVAR(attemptROSC), [_patient], _patient] call CBA_fnc_targetEvent;
};
