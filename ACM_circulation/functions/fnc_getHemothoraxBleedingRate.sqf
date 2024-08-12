#include "..\script_component.hpp"
/*
 * 作成者: Blue
 * 心拍出量と凝固に影響される血胸の出血率を取得
 *
 * 引数:
 * 0: ユニット <OBJECT>
 *
 * 戻り値:
 * ユニットの血胸出血率 <NUMBER>
 *
 * 例:
 * [player] call ACM_circulation_fnc_getHemothoraxBleedingRate;
 *
 * 公開: いいえ
 */

params ["_unit"];

// 血胸の出血率を計算
private _hemothoraxBleeding = (_unit getVariable [QEGVAR(breathing,Hemothorax_State), 0]) * 0.02;
if (_hemothoraxBleeding == 0) exitWith {0};

// 心拍出量を取得
private _cardiacOutput = [_unit] call ACEFUNC(medical_status,getCardiacOutput);

// 凝固修正値を初期化
private _coagulationModifier = 1;
// 血小板数を取得
private _plateletCount = _unit getVariable [QGVAR(Platelet_Count), 3];

// 血小板数が0より大きい場合の処理
if (_plateletCount > 0) then {
    // 血小板数の修正値を計算
    private _plateletCountModifier = ((_plateletCount / 3) - 1) * -0.1;
    _coagulationModifier = _plateletCountModifier + (0.5 max (0.75 * _hemothoraxBleeding));
};

// 心臓が停止しても血液はゆっくりと流れる（重力）
(_hemothoraxBleeding * (_cardiacOutput max GVAR(cardiacArrestBleedRate)) * _coagulationModifier * ACEGVAR(medical,bleedingCoefficient));
