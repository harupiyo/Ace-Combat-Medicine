#include "..\script_component.hpp"
/*
 * 作成者: Blue
 * 患者の呼吸をチェック (ローカル)
 *
 * 引数:
 * 0: 医療担当者 <OBJECT>
 * 1: 患者 <OBJECT>
 *
 * 戻り値:
 * なし
 *
 * 例:
 * [player, cursorTarget] call ACM_breathing_fnc_checkBreathingLocal;
 *
 * 公開: いいえ
 */

params ["_medic", "_patient"];

// 初期メッセージとログを設定
private _hint = "Patient is breathing normally";
private _hintLog = "Normal";

// 患者の呼吸数を取得
private _respirationRate = GET_RESPIRATION_RATE(_patient);

// 患者の気胸、緊張性気胸、血胸の状態を取得
private _pneumothorax = _patient getVariable [QGVAR(Pneumothorax_State), 0] > 0;
private _tensionPneumothorax = _patient getVariable [QGVAR(TensionPneumothorax_State), false];
private _hemothorax = (_patient getVariable [QGVAR(Hemothorax_Fluid), 0]) > 1.4;

// 呼吸停止、気道閉塞、気道崩壊、気道反射の状態を取得
private _respiratoryArrest = (_respirationRate < 1 || (GET_HEART_RATE(_patient) < 20) || !(alive _patient) || _tensionPneumothorax || _hemothorax);
    // 患者が呼吸停止状態にあるかどうかを判定するための条件を設定しています。
    // 呼吸率が非常に低い、心拍数が非常に低い、患者が死亡している、緊張性気胸や血胸を患っている場合に、_respiratoryArrest 変数が真になります。
    // Arrest = 停止
private _airwayBlocked = (GET_AIRWAYSTATE(_patient)) == 0;
private _airwayCollapsed = (_patient getVariable [QEGVAR(airway,AirwayCollapse_State), 0]) > 0;
private _airwayReflexIntact = _patient getVariable [QEGVAR(airway,AirwayReflex_State), false];

// 気道操作と気道補助具の状態を取得
private _airwayManeuver = _patient getVariable [QEGVAR(airway,RecoveryPosition_State), false] || _patient getVariable [QEGVAR(airway,HeadTilt_State), false];
private _airwayAdjunct = (_patient getVariable [QEGVAR(airway,AirwayItem_Oral), ""]) == "OPA" || (_patient getVariable [QEGVAR(airway,AirwayItem_Nasal), ""]) == "NPA" || _airwayManeuver;
private _airwaySecure = (_patient getVariable [QEGVAR(airway,AirwayItem_Oral), ""]) == "SGA" || _airwayManeuver;

// 呼吸状態に応じたメッセージとログを設定
switch (true) do {
    // 呼吸停止または気道閉塞の場合
    case (_respiratoryArrest || _airwayBlocked): {
        _hint = "Patient is not breathing"; // 患者は呼吸していない
        _hintLog = "None"; // ログには「None」と記録
    };
    // 気胸または気道が崩壊している場合、かつ気道が確保されていない場合、または気道反射がない場合
    case (_pneumothorax || _airwayCollapsed && !_airwaySecure || !_airwayReflexIntact && !_airwayAdjunct): {
        _hint = "Patient breathing is shallow"; // 患者の呼吸が浅い
        _hintLog = "Shallow"; // ログには「Shallow」と記録

        if (_respirationRate < 15.9) then { // 呼吸率が15.9未満の場合
            _hint = "Patient breathing is slow and shallow"; // 患者の呼吸が遅くて浅い
            _hintLog = "Slow and shallow"; // ログには「Slow and shallow」と記録
        } else {
            if (_respirationRate > 22) then { // 呼吸率が22を超える場合
                _hint = "Patient breathing is rapid and shallow"; // 患者の呼吸が速くて浅い
                _hintLog = "Rapid and shallow"; // ログには「Rapid and shallow」と記録
            };
        };
    };
    // 呼吸率が15.9未満の場合
    case (_respirationRate < 15.9): {
        _hint = "Patient breathing is slow"; // 患者の呼吸が遅い
        _hintLog = "Slow"; // ログには「Slow」と記録
    };
    // 呼吸率が22を超える場合
    case (_respirationRate > 22): {
        _hint = "Patient breathing is rapid"; // 患者の呼吸が速い
        _hintLog = "Rapid"; // ログには「Rapid」と記録
    };
    default {}; // デフォルトケース
};

// メッセージを表示
[QACEGVAR(common,displayTextStructured), [_hint, 1.5, _medic], _medic] call CBA_fnc_targetEvent;
// ログに追加
[_patient, "quick_view", "%1 checked breathing: %2", [[_medic, false, true] call ACEFUNC(common,getName), _hintLog]] call ACEFUNC(medical_treatment,addToLog);
