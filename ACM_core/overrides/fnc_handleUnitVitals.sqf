#include "..\script_component.hpp"
/*
 * 作成者: Glowbal
 * バイタルを更新します。ステートマシンのonState関数から呼び出されます。
 *
 * 引数:
 * 0: ユニット <OBJECT>
 *
 * 戻り値:
 * 更新が実行されたかどうか（実行間隔は少なくとも1秒） <BOOL>
 *
 * 例:
 * [player] call ace_medical_vitals_fnc_handleUnitVitals
 *
 * 公開: いいえ
 */

params ["_unit"];

// 最後に更新された時間を取得
private _lastTimeUpdated = _unit getVariable [QACEGVAR(medical_vitals,lastTimeUpdated), 0];
private _deltaT = (CBA_missionTime - _lastTimeUpdated) min 10;
if (_deltaT < 1) exitWith { false }; // ステートマシンはローカルユニットの数に応じて非常に迅速にこれを呼び出す可能性があります

BEGIN_COUNTER(Vitals);

// 現在の時間を最後に更新された時間として設定
_unit setVariable [QACEGVAR(medical_vitals,lastTimeUpdated), CBA_missionTime];
private _lastTimeValuesSynced = _unit getVariable [QACEGVAR(medical_vitals,lastMomentValuesSynced), 0];
private _syncValues = (CBA_missionTime - _lastTimeValuesSynced) >= (10 + floor(random 10));

// 同期が必要な場合の処理
if (_syncValues) then {
    _unit setVariable [QACEGVAR(medical_vitals,lastMomentValuesSynced), CBA_missionTime];
};

// 血液量の変化を取得
private _bloodVolume = ([_unit, _deltaT, _syncValues] call ACEFUNC(medical_status,getBloodVolumeChange));
_bloodVolume = 0 max _bloodVolume min DEFAULT_BLOOD_VOLUME;

// @todo: これと他のsetVariableをEFUNC(common,setApproximateVariablePublic)に置き換える
_unit setVariable [VAR_BLOOD_VOL, _bloodVolume, _syncValues];

// ネットワーク全体で情報を同期するための変数を設定
private _hemorrhage = switch (true) do {
    case (_bloodVolume < BLOOD_VOLUME_CLASS_4_HEMORRHAGE): { 4 };
    case (_bloodVolume < BLOOD_VOLUME_CLASS_3_HEMORRHAGE): { 3 };
    case (_bloodVolume < BLOOD_VOLUME_CLASS_2_HEMORRHAGE): { 2 };
    case (_bloodVolume < BLOOD_VOLUME_CLASS_1_HEMORRHAGE): { 1 };
    default {0};
};

// 出血の状態が変わった場合の処理
if (_hemorrhage != GET_HEMORRHAGE(_unit)) then {
    _unit setVariable [VAR_HEMORRHAGE, _hemorrhage, true];
};

// 傷からの出血量を取得
private _woundBloodLoss = GET_WOUND_BLEEDING(_unit);

// 痛みの状態を取得
private _inPain = GET_PAIN_PERCEIVED(_unit) > 0;
if (_inPain isNotEqualTo IS_IN_PAIN(_unit)) then {
    _unit setVariable [VAR_IN_PAIN, _inPain, true];
};

// 120秒以上前に適用された止血帯からの痛みを処理
private _tourniquetPain = 0;
private _tourniquets = _unit getVariable [QEGVAR(disability,Tourniquet_ApplyTime), [-1,-1,-1,-1,-1,-1]];
{
    if (_x != -1 && {CBA_missionTime - _x > 120}) then {
        _tourniquetPain = _tourniquetPain max (CBA_missionTime - _x - 120) * 0.001;
    };
} forEach _tourniquets;
if (_tourniquetPain > 0) then {
    [_unit, _tourniquetPain] call ACEFUNC(medical_status,adjustPainLevel);
};

// 薬物調整を取得
private _hrTargetAdjustment = 0;
private _painSupressAdjustment = 0;
private _peripheralResistanceAdjustment = 0;
private _respirationRateAdjustment = 0;
private _coSensitivityAdjustment = 0;
private _breathingEffectivenessAdjustment = 0;
private _adjustments = _unit getVariable [VAR_MEDICATIONS,[]];

private _painSuppressAdjustmentMap = +GVAR(MedicationTypes);

// 薬物調整がある場合の処理
if (_adjustments isNotEqualTo []) then {
    private _deleted = false;
    {
        _x params ["_medication", "_timeAdded", "_timeTillMaxEffect", "_maxTimeInSystem", "_hrAdjust", "_painAdjust", "_flowAdjust", "_administrationType", "_maxEffectTime", "_rrAdjust", "_coSensitivityAdjust", "_breathingEffectivenessAdjust", "_concentration", "_medicationType"];
        private _timeInSystem = CBA_missionTime - _timeAdded;
        if (_timeInSystem >= _maxTimeInSystem) then {
            _deleted = true;
            _adjustments set [_forEachIndex, objNull];
        } else {
            private _effectRatio = [_administrationType, _timeInSystem, _timeTillMaxEffect, _maxTimeInSystem, _maxEffectTime, _concentration] call EFUNC(circulation,getMedicationEffect);
            if (_hrAdjust != 0) then { _hrTargetAdjustment = _hrTargetAdjustment + _hrAdjust * _effectRatio; };
            if (_flowAdjust != 0) then { _peripheralResistanceAdjustment = _peripheralResistanceAdjustment + _flowAdjust * _effectRatio; };
            if (_rrAdjust != 0) then { _respirationRateAdjustment = _respirationRateAdjustment + _rrAdjust * _effectRatio; };
            if (_coSensitivityAdjust != 0) then { _coSensitivityAdjustment = _coSensitivityAdjustment + _coSensitivityAdjust * _effectRatio; };
            if (_breathingEffectivenessAdjust != 0) then { _breathingEffectivenessAdjustment = _breathingEffectivenessAdjustment + _breathingEffectivenessAdjust * _effectRatio; };

            if (_painAdjust != 0) then {
                if (_medicationType == "Default") then {
                    _medicationType = _medication;
                };
                (_painSuppressAdjustmentMap get _medicationType) params ["_medClassnames", "_medPainReduce", "_medMaxPainAdjust"];
                if (_medication in _medClassnames) then {
                    private _newPainAdjust = _medPainReduce + _painAdjust * _effectRatio;

                    if (_medPainReduce < (_newPainAdjust min _medMaxPainAdjust)) then {
                        _painSuppressAdjustmentMap set [_medicationType, [_medClassnames, (_newPainAdjust min _medMaxPainAdjust), _medMaxPainAdjust]];
                    };
                };
            };
        };
    } forEach _adjustments;

    {
        _y params ["", "_medPainAdjust", "_medMaxPainAdjust"];

        _painSupressAdjustment = _painSupressAdjustment + (_medPainAdjust min _medMaxPainAdjust);
    } forEach _painSuppressAdjustmentMap;

    if (_deleted) then {
        _unit setVariable [VAR_MEDICATIONS, _adjustments - [objNull], true];
        _syncValues = true;
    };
};

// 最後の更新以降のSPO2摂取量と使用量を更新
private _oxygenSaturation = [_unit, _respirationRateAdjustment, _coSensitivityAdjustment, _breathingEffectivenessAdjustment, _deltaT, _syncValues] call ACEFUNC(medical_vitals,updateOxygen);

// 酸素飽和度が低い場合の処理
if (_oxygenSaturation < ACM_OXYGEN_HYPOXIA) then { // 重度の低酸素症は心臓に影響を与える
    _hrTargetAdjustment = _hrTargetAdjustment - 10 * abs (ACM_OXYGEN_HYPOXIA - _oxygenSaturation);
};

// 緊張性気胸またはハードコア気胸の状態を確認
if ((_unit getVariable [QEGVAR(breathing,TensionPneumothorax_State), false]) || (_unit getVariable [QEGVAR(breathing,Hardcore_Pneumothorax), false])) then {
    _hrTargetAdjustment = _hrTargetAdjustment - ([25,35] select (_unit getVariable [QEGVAR(breathing,TensionPneumothorax_State), false]));
} else {
    if (_unit getVariable [QEGVAR(breathing,Pneumothorax_State), 0] > 0) then {
        _hrTargetAdjustment = _hrTargetAdjustment - (5 * (_unit getVariable [QEGVAR(breathing,Pneumothorax_State), 0]));
    };
};

// 心拍数を更新
private _heartRate = [_unit, _hrTargetAdjustment, _deltaT, _syncValues] call ACEFUNC(medical_vitals,updateHeartRate);
[_unit, _painSupressAdjustment, _deltaT, _syncValues] call ACEFUNC(m
// ステートメントは最も致命的なものから順に並べられています。
switch (true) do {
    // 血液量が致命的なレベルに達している場合
    case (_bloodVolume < BLOOD_VOLUME_FATAL): {
        TRACE_3("致命的な血液量",_unit,BLOOD_VOLUME_FATAL,_bloodVolume);
        [QACEGVAR(medical,Bleedout), _unit] call CBA_fnc_localEvent;
    };
    // 酸素飽和度が致命的なレベルに達している場合
    case (_oxygenSaturation < ACM_OXYGEN_DEATH): {
        if (ACM_OXYGEN_DEATH - (random 5) > _oxygenSaturation) then {
            [_unit, "酸素欠乏"] call ACEFUNC(medical_status,setDead);
        };
    };
    // 心停止状態の場合
    case (IN_CRDC_ARRST(_unit)): {}; // 心停止状態の場合、不要なイベントを避けるためにここで終了
    // 最近AEDショックを受けた場合
    case ([_unit] call EFUNC(circulation,recentAEDShock)): {};
    // クラスIVの出血の場合
    case (_hemorrhage == 4): {
        TRACE_3("クラスIVの出血",_unit,_hemorrhage,_bloodVolume);
        [QACEGVAR(medical,FatalVitals), _unit] call CBA_fnc_localEvent;
        [_unit] call EFUNC(circulation,updateCirculationState);
    };
    // 心拍数が20未満または220を超える場合
    case (_heartRate < 20 || {_heartRate > 220}): {
        TRACE_2("致命的な心拍数",_unit,_heartRate);
        if (_heartRate > 220) then {
            _unit setVariable [QEGVAR(circulation,CardiacArrest_TargetRhythm), 3];
        } else {
            _unit setVariable [QEGVAR(circulation,CardiacArrest_TargetRhythm), 2];
        };

        [QACEGVAR(medical,FatalVitals), _unit] call CBA_fnc_localEvent;
    };
    // 血圧が非常に低い場合
    case (_bloodPressureH < 50 && {_bloodPressureL < 40}): {
        _unit setVariable [QEGVAR(circulation,CardiacArrest_TargetRhythm), 2];
        [QACEGVAR(medical,FatalVitals), _unit] call CBA_fnc_localEvent;
    };
    // 血圧が非常に高い場合
    case (_bloodPressureL >= 190): {
        TRACE_2("血圧が限界を超えている",_unit,_bloodPressureL);
        _unit setVariable [QEGVAR(circulation,CardiacArrest_TargetRhythm), 3];
        [QACEGVAR(medical,FatalVitals), _unit] call CBA_fnc_localEvent;
    };
    // 心拍数が30未満の場合
    case (_heartRate < 30): {  // 心拍数が30未満だが20以上の場合、心停止状態に入る可能性がある
        private _nextCheck = _unit getVariable [QACEGVAR(medical_vitals,nextCheckCriticalHeartRate), CBA_missionTime];
        private _enterCardiacArrest = false;
        if (CBA_missionTime >= _nextCheck) then {
            _enterCardiacArrest = random 1 < (0.4 + 0.6*(30 - _heartRate)/10); // 心停止状態に入る変動の可能性。
            _unit setVariable [QACEGVAR(medical_vitals,nextCheckCriticalHeartRate), CBA_missionTime + 5];
        };
        if (_enterCardiacArrest) then {
            TRACE_2("心拍数が危険。心停止",_unit,_heartRate);
            _unit setVariable [QEGVAR(circulation,CardiacArrest_TargetRhythm), 2];
            [QACEGVAR(medical,FatalVitals), _unit] call CBA_fnc_localEvent;
        } else {
            TRACE_2("心拍数が危険。重要なバイタル",_unit,_heartRate);
            [QACEGVAR(medical,CriticalVitals), _unit] call CBA_fnc_localEvent;
        };
    };
    // 酸素飽和度が低い場合
    case (_oxygenSaturation < ACM_OXYGEN_HYPOXIA): {
        private _nextCheck = _unit getVariable [QEGVAR(circulation,ReversibleCardiacArrest_HypoxiaTime), CBA_missionTime];
        private _enterCardiacArrest = false;
        if (CBA_missionTime >= _nextCheck) then {
            _enterCardiacArrest = (ACM_OXYGEN_HYPOXIA - (random 10) > _oxygenSaturation);
            _unit setVariable [QEGVAR(circulation,ReversibleCardiacArrest_HypoxiaTime), CBA_missionTime + 5];
            [_unit] call EFUNC(circulation,updateCirculationState);
        };
        if (_enterCardiacArrest) then {
            [QACEGVAR(medical,FatalVitals), _unit] call CBA_fnc_localEvent;
        } else {
            [QACEGVAR(medical,CriticalVitals), _unit] call CBA_fnc_localEvent;
        };
    };
    // 傷からの出血量が閾値を超えた場合
    case (_woundBloodLoss > BLOOD_LOSS_KNOCK_OUT_THRESHOLD_DEFAULT): {
        [QACEGVAR(medical,CriticalVitals), _unit] call CBA_fnc_localEvent;
    };
    // 酸素飽和度が意識喪失レベルに達している場合
    case (_oxygenSaturation < ACM_OXYGEN_UNCONSCIOUS): {
        if (ACM_OXYGEN_UNCONSCIOUS - (random 10) > _oxygenSaturation) then {
            [QACEGVAR(medical,CriticalVitals), _unit] call CBA_fnc_localEvent;
        };
    };
    // 呼吸数が6未満の場合
    case (_respirationRate < 6): {
        [QACEGVAR(medical,CriticalVitals), _unit] call CBA_fnc_localEvent;
    };
    // 傷からの出血がある場合
    case (_woundBloodLoss > 0): {
        [QACEGVAR(medical,LoweredVitals), _unit] call CBA_fnc_localEvent;
    };
    // 痛みがある場合
    case (_inPain): {
        [QACEGVAR(medical,LoweredVitals), _unit] call CBA_fnc_localEvent;
    };
};

#ifdef DEBUG_MODE_FULL
// デバッグモードの場合の処理
private _cardiacOutput = [_unit] call ACEFUNC(medical_status,getCardiacOutput);
if (!isPlayer _unit) then {
    private _painLevel = _unit getVariable [VAR_PAIN, 0];
    hintSilent format["血液量: %1, 出血量: [%2, %3]\n心拍数: %4, 血圧: %5, 痛み: %6", round(_bloodVolume * 100) / 100, round(_woundBloodLoss * 1000) / 1000, round((_woundBloodLoss / (0.001 max _cardiacOutput)) * 100) / 100, round(_heartRate), _bloodPressure, round(_painLevel * 100) / 100];
};
#endif

END_COUNTER(Vitals);

// カウンターの外に配置されているため、サードパーティのコードがこのイベントから呼び出される可能性があります
[QACEGVAR(medical,handleUnitVitals), [_unit, _deltaT]] call CBA_fnc_localEvent;

true
