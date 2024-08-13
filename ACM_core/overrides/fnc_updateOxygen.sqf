#include "..\script_component.hpp"
/*
 * Author: Brett Mayson
 * Update the oxygen levels
 *
 * Arguments:
 * 0: The Unit <OBJECT> // ユニット
 * 1: Respiration Rate Adjustment <NUMBER> // 呼吸率の調整
 * 2: Carbon Dioxide Sensitivity Adjustment <NUMBER> // 二酸化炭素感受性の調整
 * 3: Breathing Effectiveness Adjustment <NUMBER> // 呼吸効率の調整
 * 4: Time since last update <NUMBER> // 最終更新からの時間
 * 5: Sync value? <BOOL> // 同期値？
 *
 * ReturnValue:
 * Current SPO2 <NUMBER> // 現在の酸素飽和度
 *
 * Example:
 * [player, 1, false] call ace_medical_vitals_fnc_updateOxygen;
 *
 * Public: No
 */

params ["_unit", "_respirationRateAdjustment", "_coSensitivityAdjustment", "_breathingEffectivenessAdjustment", "_deltaT", "_syncValue"];

//if (!ACEGVAR(medical_vitals,simulateSpO2)) exitWith {}; // デフォルトに戻す処理は initSettings.inc.sqf で行われる

private _desiredOxygenSaturation = ACM_TARGETVITALS_OXYGEN(_unit); // 目標酸素飽和度を取得

#define IDEAL_PPO2 0.255 // 理想的な酸素分圧

private _currentOxygenSaturation = GET_OXYGEN(_unit); // 現在の酸素飽和度を取得
private _heartRate = GET_HEART_RATE(_unit); // 心拍数を取得

private _altitude = ACEGVAR(common,mapAltitude) + ((getPosASL _unit) select 2); // 高度を取得
private _po2 = if (missionNamespace getVariable [QACEGVAR(weather,enabled), false]) then {
    private _temperature = _altitude call ACEFUNC(weather,calculateTemperatureAtHeight); // 高度での温度を計算
    private _pressure = _altitude call ACEFUNC(weather,calculateBarometricPressure); // 気圧を計算
    [_temperature, _pressure, ACEGVAR(weather,currentHumidity)] call ACEFUNC(weather,calculateOxygenDensity) // 酸素密度を計算
} else {
    // 空気中の酸素分圧の大まかな近似
    0.25725 * (_altitude / 1000 + 1)
};

private _airOxygenSaturation = 1; // 空気中の酸素飽和度

if (EGVAR(breathing,altitudeAffectOxygen)) then {
    _airOxygenSaturation = (IDEAL_PPO2 min _po2) / IDEAL_PPO2; // 酸素飽和度を計算

    // 酸素供給のための装備をチェック
    [goggles _unit, headgear _unit, vest _unit] findIf {
        _x in ACEGVAR(medical_vitals,oxygenSupplyConditionCache) &&
        {ACE_player call (ACEGVAR(medical_vitals,oxygenSupplyConditionCache) get _x)} &&
        { // 他の条件が満たされた場合にのみ実行
            _airOxygenSaturation = 1;
            _po2 = IDEAL_PPO2;
            true
        }
    };
} else {
    _po2 = IDEAL_PPO2;
    _airOxygenSaturation = 1;
};

// 疲労と運動はより多くの酸素を必要とする
// 訓練された男性がピーク運動中に約180 BPMのピーク心拍数を持つと仮定
// 参考: https://academic.oup.com/bjaed/article-pdf/4/6/185/894114/mkh050.pdf 表2、ただしストロークボリュームの変化は考慮しない
private _negativeChange = BASE_OXYGEN_USE; // 基本的な酸素消費率

// 「advanced_fatigue」モジュールが有効になっている場合に、酸素消費率を調整する
if (_unit == ACE_player && {missionNamespace getVariable [QACEGVAR(advanced_fatigue,enabled), false]}) then {
    // _negativeChange は、ユニットの疲労状態に基づいて調整されます。疲労が多いほど、酸素消費が増加します。
    _negativeChange = _negativeChange -
        // 有酸素運動の予備力に基づいて酸素消費率を調整します。予備力が低いほど、酸素消費が多くなります。
        ((1 - ACEGVAR(advanced_fatigue,aeReservePercentage)) * 0.1) -
        ((1 - ACEGVAR(advanced_fatigue,anReservePercentage)) * 0.05);
};

private _respirationRate = [_unit, _currentOxygenSaturation, (_negativeChange - BASE_OXYGEN_USE), _respirationRateAdjustment, _coSensitivityAdjustment, _deltaT, _syncValue] call EFUNC(breathing,updateRespirationRate); // 呼吸率を更新

private _targetOxygenSaturation = _desiredOxygenSaturation; // 目標酸素飽和度

// 酸素捕捉の効果
// po2が低下し始めるとわずかに増加
// しかし、po2がさらに低下すると急速に減少
private _capture = 1 max ((_po2 / IDEAL_PPO2) ^ (-_po2 * 3));

private _effectiveBloodVolume = ((sin (deg ((GET_EFF_BLOOD_VOLUME(_unit) ^ 2) / 21.1))) * 1.01) min 1; // 有効血液量
private _airwayState = GET_AIRWAYSTATE(_unit); // 気道の状態
private _breathingState = GET_BREATHINGSTATE(_unit); // 呼吸の状態

private _oxygenSaturation = _currentOxygenSaturation; // 現在の酸素飽和度
private _oxygenChange = 0; // 酸素変化量

private _activeBVM = [_unit] call EFUNC(core,bvmActive); // BVMがアクティブかどうか
private _BVMOxygenAssisted = _unit getVariable [QEGVAR(breathing,BVM_ConnectedOxygen), false]; // BVMが酸素補助されているかどうか

private _timeSinceLastBreath = CBA_missionTime - (_unit getVariable [QEGVAR(breathing,BVM_lastBreath), -1]); // 最後の呼吸からの時間

private _BVMLastingEffect = 0; // BVMの持続効果

if (_timeSinceLastBreath < 35) then {
    _BVMLastingEffect = 1 min 15 / (_timeSinceLastBreath max 0.001);
};

private _maxDecrease = -ACM_BREATHING_MAXDECREASE; // 最大減少量
private _maxPositiveGain = 0.5; // 最大増加量

if !(_activeBVM) then {
    if IS_UNCONSCIOUS(_unit) then {
        _maxPositiveGain = _maxPositiveGain * 0.25;
    };
    _maxDecrease = _maxDecrease * (1 - (0.5 * _BVMLastingEffect));
} else {
    if (_BVMOxygenAssisted) then {
        _maxPositiveGain = _maxPositiveGain * 0.85;
        if (IN_CRDC_ARRST(_unit)) then {
            _maxDecrease = _maxDecrease * 0.3;
        } else {
            _maxDecrease = _maxDecrease * 0.1;
        };
    } else {
        _maxPositiveGain = _maxPositiveGain * 0.7;
        if (IN_CRDC_ARRST(_unit)) then {
            _maxDecrease = _maxDecrease * 0.9;
        } else {
            _maxDecrease = _maxDecrease * 0.7;
        };
    };
};

if (_respirationRate > 0 && (GET_HEART_RATE(_unit) > 20)) then { // 呼吸率が0より大きく、心拍数が20を超えている場合
    private _airSaturation = _airOxygenSaturation * _capture; // 空気中の酸素飽和度と捕捉効果を掛け合わせた値

    private _hyperVentilationEffect = 0.8 max (35 / _respirationRate) min 1; // 過呼吸の効果を計算
    private _breathingEffectiveness = _effectiveBloodVolume min _airwayState * _breathingState * _hyperVentilationEffect; // 呼吸効率を計算

    if (_activeBVM) then { // BVMがアクティブな場合
        if (IN_CRDC_ARRST(_unit)) then { // 心停止状態の場合
            _breathingEffectiveness = _breathingEffectiveness * 1.2; // 呼吸効率を1.2倍にする
        } else {
            _breathingEffectiveness = _breathingEffectiveness * 1.9; // 呼吸効率を1.9倍にする
        };
        
        if (_BVMOxygenAssisted) then { // BVMが酸素補助されている場合
            _breathingEffectiveness = _breathingEffectiveness * 1.5; // 呼吸効率を1.5倍にする
        };
    } else {
        if (IN_CRDC_ARRST(_unit) && [_unit] call EFUNC(core,cprActive)) then { // 心停止状態でCPRがアクティブな場合
            _maxPositiveGain = _maxPositiveGain * (0.5 + (0.5 * _BVMLastingEffect)); // 最大増加量を調整
            _breathingEffectiveness = _breathingEffectiveness * 0.8 * (1 + (0.2 * _BVMLastingEffect)); // 呼吸効率を調整
        };
    };

    if (_breathingEffectivenessAdjustment != 0) then { // 呼吸効率の調整が0でない場合
        _breathingEffectiveness = (_breathingEffectiveness * (1 + _breathingEffectivenessAdjustment)) min ((_breathingEffectiveness + 0.01) min 1); // 呼吸効率を調整
    };

    private _fatigueEffect = 0.99 max (-0.25 / _negativeChange) min 1; // 疲労の効果を計算

    private _respirationEffect = 1; // 呼吸の効果

    if (_respirationRate > ACM_TARGETVITALS_RR(_unit)) then { // 呼吸率が目標値を超えている場合
        _respirationEffect = 0.9 max (35 / _respirationRate) min 1.1; // 呼吸の効果を調整
    } else {
        _respirationEffect = 0.8 max (_respirationRate / 12) min 1.1; // 呼吸の効果を調整
    };

    _targetOxygenSaturation = _desiredOxygenSaturation min (_targetOxygenSaturation * _breathingEffectiveness * _airSaturation * _respirationEffect * _fatigueEffect); // 目標酸素飽和度を計算

    _oxygenChange = (_targetOxygenSaturation - _currentOxygenSaturation) / 5; // 酸素変化量を計算

    if (_oxygenChange < 0) then { // 酸素変化量が負の場合
        _oxygenSaturation = _currentOxygenSaturation + (_oxygenChange max _maxDecrease) * _deltaT; // 酸素飽和度を減少
    } else {
        _oxygenSaturation = _currentOxygenSaturation + ((_maxPositiveGain / 2) max _oxygenChange min _maxPositiveGain) * _deltaT; // 酸素飽和度を増加
    };
} else { // 呼吸率が0以下、または心拍数が20以下の場合
    _targetOxygenSaturation = 0; // 目標酸素飽和度を0に設定
    _oxygenSaturation = _currentOxygenSaturation + _maxDecrease * _deltaT; // 酸素飽和度を減少
};

_oxygenSaturation = 100 min _oxygenSaturation max 0; // 酸素飽和度を0から100の範囲に制限

_unit setVariable [VAR_OXYGEN_DEMAND, _negativeChange - BASE_OXYGEN_USE]; // 酸素需要を設定
_unit setVariable [VAR_SPO2, _oxygenSaturation, _syncValue]; // 酸素飽和度を設定

_oxygenSaturation; // 現在の酸素飽和度を返す