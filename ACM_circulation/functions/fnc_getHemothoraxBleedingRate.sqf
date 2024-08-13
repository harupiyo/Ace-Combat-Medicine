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
    // 血小板数と血胸出血に基づいて凝固修飾子を計算します。血小板数が多いほど、または血胸出血が多いほど、凝固修飾子の値が変化します。
    
    // 例えば、_plateletCount が 3 の場合、_plateletCountModifier は -0.1 になります。_plateletCount が 6 の場合、_plateletCountModifier は -0.2 になります。
    private _plateletCountModifier = ((_plateletCount / 3) - 1) * -0.1;
    // 0.5以上の値を追加（max は大きい方という意味）
    _coagulationModifier = _plateletCountModifier + (0.5 max (0.75 * _hemothoraxBleeding));
};

// 心臓が停止しても血液はゆっくりと流れる（重力）
// 胸腔内出血の量に心拍出量と心停止時の出血率の最大値を掛け合わせ、さらに凝固修飾子と出血係数を掛け合わせて、最終的な出血量を計算しています。
(_hemothoraxBleeding * (_cardiacOutput max GVAR(cardiacArrestBleedRate)) * _coagulationModifier * ACEGVAR(medical,bleedingCoefficient));