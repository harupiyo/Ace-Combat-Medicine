#include "..\script_component.hpp"
/*
 * Author: Brett Mayson
 * Update the oxygen levels
 *
 * Arguments:
 * 0: The Unit <OBJECT>
 * 1: Time since last update <NUMBER>
 * 2: Sync value? <BOOL>
 *
 * ReturnValue:
 * Current SPO2 <NUMBER>
 *
 * Example:
 * [player, 1, false] call ace_medical_vitals_fnc_updateOxygen
 *
 * Public: No
 */

params ["_unit", "_deltaT", "_syncValue"];

if (!GVAR(simulateSpO2)) exitWith {}; // デフォルトに戻す処理は initSettings.inc.sqf で行われる

#define IDEAL_PPO2 0.255 // 理想的な酸素分圧

private _current = GET_SPO2(_unit); // 現在の酸素飽和度を取得
private _heartRate = GET_HEART_RATE(_unit); // 心拍数を取得

private _altitude = EGVAR(common,mapAltitude) + ((getPosASL _unit) select 2); // 高度を取得
private _po2 = if (missionNamespace getVariable [QEGVAR(weather,enabled), false]) then {
    private _temperature = _altitude call EFUNC(weather,calculateTemperatureAtHeight); // 高度での温度を計算
    private _pressure = _altitude call EFUNC(weather,calculateBarometricPressure); // 気圧を計算
    [_temperature, _pressure, EGVAR(weather,currentHumidity)] call EFUNC(weather,calculateOxygenDensity) // 酸素密度を計算
} else {
    // 空気中の酸素分圧の大まかな近似
    0.25725 * (_altitude / 1000 + 1)
};

private _oxygenSaturation = (IDEAL_PPO2 min _po2) / IDEAL_PPO2; // 酸素飽和度を計算

// 酸素供給のための装備をチェック
[goggles _unit, headgear _unit, vest _unit] findIf {
    _x in GVAR(oxygenSupplyConditionCache) &&
    {ACE_player call (GVAR(oxygenSupplyConditionCache) get _x)} &&
    { // 他の条件が満たされた場合にのみ実行
        _oxygenSaturation = 1;
        _po2 = IDEAL_PPO2;
        true
    }
};

// 基本的な酸素消費率
private _negativeChange = BASE_OXYGEN_USE;

// 疲労と運動はより多くの酸素を必要とする
// 訓練された男性がピーク運動中に約180 BPMのピーク心拍数を持つと仮定
// 参考: https://academic.oup.com/bjaed/article-pdf/4/6/185/894114/mkh050.pdf 表2、ただしストロークボリュームの変化は考慮しない
if (_unit == ACE_player && {missionNamespace getVariable [QEGVAR(advanced_fatigue,enabled), false]}) then {
    _negativeChange = _negativeChange - ((1 - EGVAR(advanced_fatigue,aeReservePercentage)) * 0.1) - ((1 - EGVAR(advanced_fatigue,anReservePercentage)) * 0.05);
};

// 酸素捕捉の効果
// po2が低下し始めるとわずかに増加
// しかし、po2がさらに低下すると急速に減少
private _capture = 1 max ((_po2 / IDEAL_PPO2) ^ (-_po2 * 3));
private _positiveChange = _heartRate * 0.00368 * _oxygenSaturation * _capture;

private _breathingEffectiveness = 1;

private _rateOfChange = _negativeChange + (_positiveChange * _breathingEffectiveness);

private _spo2 = (_current + (_rateOfChange * _deltaT)) max 0 min 100;

_unit setVariable [VAR_OXYGEN_DEMAND, _negativeChange - BASE_OXYGEN_USE];
_unit setVariable [VAR_SPO2, _spo2, _syncValue]; // 酸素飽和度を設定
