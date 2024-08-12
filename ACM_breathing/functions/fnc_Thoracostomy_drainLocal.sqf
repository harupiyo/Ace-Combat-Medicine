#include "..\script_component.hpp"
/*
 * 作成者: Blue
 * 胸腔内の血液を排出する処理 (ローカル)
 *
 * 引数:
 * 0: 医療担当者 <OBJECT>
 * 1: 患者 <OBJECT>
 * 2: デバイスタイプ <NUMBER>
    * 0: 吸引バッグ
    * 1: ACCUVAC
 *
 * 戻り値:
 * なし
 *
 * 例:
 * [player, cursorTarget] call ACM_breathing_fnc_Thoracostomy_drainLocal;
 *
 * 公開: いいえ
 */

params ["_medic", "_patient", "_type"];

// 排液完了のメッセージを設定
private _hint = "Fluid draining complete";
// 患者の血胸の液体量を取得
private _fluid = _patient getVariable [QGVAR(Hemothorax_Fluid), 0];
// メッセージの幅を設定
private _width = 10;
// 排出された血液の量を設定
private _amount = "";

// デバイスタイプに応じて排出量のメッセージを設定
if (_type == 0) then {
    _amount = switch (true) do {
        case (_fluid <= 0): {
            "No blood drained";
        };
        case (_fluid < 0.3): {
            "Small amount of blood drained";
        };
        case (_fluid < 0.8): {
            _width = 12;
            "Significant amount of blood drained";
        };
        default {
            "Large amount of blood drained";
        };
    };
} else {
    if (_fluid <= 0) then {
        _amount = "No blood drained";
    } else {
        _amount = format ["~%1 ml of blood drained", round((_fluid * 1000))];
    };
};

// ログに排出量を追加
[_patient, "quick_view", "Thoracostomy Drain: %1", [_amount]] call ACEFUNC(medical_treatment,addToLog);
// メッセージを表示
[QACEGVAR(common,displayTextStructured), [(format ["%1<br/>%2", _hint, _amount]), 2, _medic], _medic] call CBA_fnc_targetEvent;

// 血胸の液体量をリセット
_patient setVariable [QGVAR(Hemothorax_Fluid), 0, true];

// 呼吸状態を更新
[_patient] call FUNC(updateBreathingState);
