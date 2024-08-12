#include "..\script_component.hpp"
/*
 * 作成者: Glowbal
 * ユニットの血圧を計算します。
 *
 * 引数:
 * 0: ユニット <OBJECT>
 *
 * 戻り値:
 * 0: 血圧低 <NUMBER>
 * 1: 血圧高 <NUMBER>
 *
 * 例:
 * [player] call ace_medical_status_fnc_getBloodPressure
 *
 * 公開: いいえ
 */

// 心拍出量と抵抗がデフォルト値の場合、血圧高が120になるように値が設定されています。
#define MODIFIER_BP_HIGH    9.4736842

// 心拍出量と抵抗がデフォルト値の場合、血圧低が80になるように値が設定されています。
#define MODIFIER_BP_LOW     6.3157894

params ["_unit"];

// 心拍出量を取得
private _cardiacOutput = [_unit] call ACEFUNC(medical_status,getCardiacOutput);
// 抵抗を取得
private _resistance = _unit getVariable [VAR_PERIPH_RES, DEFAULT_PERIPH_RES];
// 血圧を計算
private _bloodPressure = _cardiacOutput * _resistance;

// 出血している場合、血圧を下げる
private _bleedEffect = 1 - (0.2 * GET_WOUND_BLEEDING(_unit)); 
private _hemothoraxBleeding = 0.4 * ((_unit getVariable [QEGVAR(breathing,Hemothorax_State), 0]) / 4);
private _internalBleedingEffect = 1 min (1 - (0.8 * (GET_INTERNAL_BLEEDING(_unit) + _hemothoraxBleeding))) max 0.5; // 内部出血が制御されていない場合、血圧を下げる

// 緊張効果の初期化
private _tensionEffect = 0;

// 血胸の液体量と気胸の状態を取得
private _HTXFluid = _unit getVariable [QEGVAR(breathing,Hemothorax_Fluid), 0];
private _PTXState = _unit getVariable [QEGVAR(breathing,Pneumothorax_State), 0];

// 気胸または血胸がある場合の処理
if (_PTXState > 0 || _HTXFluid > 0.1) then {
    _tensionEffect = (_PTXState * 8) max (_HTXFluid / 46);
};

// 緊張性気胸またはハードコア気胸の状態を確認
if ((_unit getVariable [QEGVAR(breathing,TensionPneumothorax_State), false]) || (_unit getVariable [QEGVAR(breathing,Hardcore_Pneumothorax), false])) then {
    _tensionEffect = 35;
};

// 血圧低と血圧高を計算して返す
[(round(((_bloodPressure * MODIFIER_BP_LOW) - _tensionEffect) * _bleedEffect * _internalBleedingEffect)) max 0, (round(((_bloodPressure * MODIFIER_BP_HIGH) - _tensionEffect) * _bleedEffect * _internalBleedingEffect)) max 0]
