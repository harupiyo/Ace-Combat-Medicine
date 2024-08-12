#include "..\script_component.hpp"
/*
 * 作成者: Blue
 * 患者に対する指胸腔穿刺を実施 (ローカル)
 *
 * 引数:
 * 0: 医療担当者 <OBJECT>
 * 1: 患者 <OBJECT>
 *
 * 戻り値:
 * なし
 *
 * 例:
 * [player, cursorTarget] call ACM_breathing_fnc_Thoracostomy_startLocal;
 *
 * 公開: いいえ
 */

params ["_medic", "_patient"];

// 初期メッセージとログを設定
private _hint = "Finger Thoracostomy Performed";    // 指胸腔穿刺を実施
private _height = 2.5;
private _diagnose = "";
private _hintLog = "";

// 患者の呼吸数を取得
private _RR = GET_RESPIRATION_RATE(_patient);

// 患者の状態に応じた診断メッセージとログを設定
switch (true) do {
    case (_patient getVariable [QGVAR(Hemothorax_Fluid), 0] > 0.8): {
        _height = 3;
        _diagnose = "Large amount of blood in pleural space<br/>Lung is severely collapsed";
                        // 胸腔内に大量の血液<br/>肺がひどく虚脱している
        _hintLog = "Lung is collapsed, large amount of blood";
                        // 肺が虚脱、大量の血液
    };
    case (_patient getVariable [QGVAR(TensionPneumothorax_State), false]): {
        _diagnose = "Lung is severely collapsed";
                        // 肺がひどく虚脱している
        _hintLog = "Lung is collapsed";
                        // 肺が虚脱
    };
    case (_patient getVariable [QGVAR(Hemothorax_State), 0] > 0): {
        _diagnose = "Noticable bleeding inside pleural space";
                        // 胸腔内に顕著な出血
        _hintLog = "Bleeding in pleural space";
                        // 胸腔内に出血
    };
    case (_patient getVariable [QGVAR(Hemothorax_Fluid), 0] > 0): {
        _height = 3;
        if (_RR < 1) then {
            _diagnose = "Found blood in pleural space<br/>Lung is not inflating";
                        // 胸腔内に血液が見つかる<br/>肺が膨らんでいない
            _hintLog = "Blood in pleural space, lung is not inflating";
                        // 胸腔内に血液、肺が膨らんでいない
        } else {
            _diagnose = "Found blood in pleural space<br/>Lung is inflating normally";
                        // 胸腔内に血液が見つかる<br/>肺が正常に膨らんでいる
            _hintLog = "Blood in pleural space, lung inflating normally";
                        // 胸腔内に血液、肺が正常に膨らんでいる
        };
    };
    case (_RR < 1): {
        _diagnose = "Lung is not inflating";        // 肺が膨らんでいない
        _hintLog = "Lung is not inflating";
    };
    default {
        _diagnose = "Lung is inflating normally";   // 肺が正常に膨らんでいる
        _hintLog = "Lung is inflating normally";
    };
};

// メッセージを表示
[QACEGVAR(common,displayTextStructured), [(format ["%1<br/><br/>%2", _hint, _diagnose]), _height, _medic, 13], _medic] call CBA_fnc_targetEvent;
// ログに追加
[_patient, "quick_view", "Thoracostomy Sweep: %1", [_hintLog]] call ACEFUNC(medical_treatment,addToLog);

// 患者の胸腔穿刺状態を設定
_patient setVariable [QGVAR(Thoracostomy_State), 1, true];

// 患者の麻酔効果を取得
private _anestheticEffect = [_patient, "Lidocaine", false] call ACEFUNC(medical_status,getMedicationCount);

// 麻酔効果が不十分な場合の処理
if (_anestheticEffect < 0.5) then {
    // 患者の痛みレベルを調整
    [_patient, (1 - _anestheticEffect)] call ACEFUNC(medical,adjustPainLevel);
    // 重要なバイタルサインのイベントを発生
    [QACEGVAR(medical,CriticalVitals), _patient] call CBA_fnc_localEvent;
};

// 患者の緊張性気胸と気胸の状態を設定
_patient setVariable [QGVAR(TensionPneumothorax_State), false, true];
_patient setVariable [QGVAR(Pneumothorax_State), 4, true];

// 呼吸状態を更新
[_patient] call FUNC(updateBreathingState);
