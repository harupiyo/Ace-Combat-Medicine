#include "..\script_component.hpp"
/*
 * Author: Blue
 * Check Capillary Refill Time of patient (LOCAL)
 * 患者の毛細血管再充填時間をチェックする（ローカル）
 *
 * Arguments:
 * 0: Medic <OBJECT> - 医療担当者
 * 1: Patient <OBJECT> - 患者
 * 2: Body Part <STRING> - 体の部位
 *
 * Return Value:
 * None - 戻り値なし
 *
 * Example:
 * [player, cursorTarget, "leftarm"] call ACM_circulation_fnc_checkCapillaryRefillLocal;
 * 例：[player, cursorTarget, "leftarm"] call ACM_circulation_fnc_checkCapillaryRefillLocal;
 *
 * Public: No - 公開されていない
 */

params ["_medic", "_patient", "_bodyPart"]; // 引数として医療担当者、患者、体の部位を受け取る

private _partIndex = ALL_BODY_PARTS find _bodyPart; // 体の部位のインデックスを取得

private _CRT = 4; // 初期の毛細血管再充填時間を4秒に設定
private _bloodVolume = GET_BLOOD_VOLUME(_patient); // 患者の血液量を取得
private _bodyPartString = [ACELSTRING(medical_gui,Torso),ACELSTRING(medical_gui,LeftArm),ACELSTRING(medical_gui,RightArm)] select (_partIndex - 1); // 体の部位の文字列を取得

// 患者が心停止状態でない場合
if !(IN_CRDC_ARRST(_patient)) then {
    // 体の部位が左腕または右腕の場合
    if (_partIndex in [2,3]) then {
        // 患者に止血帯が適用されていない場合
        if !(HAS_TOURNIQUET_APPLIED_ON(_patient,_partIndex)) then {
            _CRT = linearConversion [6, 5, _bloodVolume, 2, 4, true]; // 血液量に基づいて毛細血管再充填時間を計算
        };
    } else {
        _CRT = linearConversion [6, 4.5, _bloodVolume, 2, 4, true]; // 血液量に基づいて毛細血管再充填時間を計算
    };
};

// 毛細血管再充填時間が3秒未満の場合
if (_CRT < 3) then {
    _CRT = _CRT - (linearConversion [65, 100, GET_HEART_RATE(_patient), -0.1, 1]); // 心拍数に基づいて毛細血管再充填時間を調整
};

private _hintLog = ""; // ヒントログの初期化
private _hint = ""; // ヒントの初期化
switch (true) do {
    case (_CRT < 2): {
        _hint = "~2 seconds"; // 毛細血管再充填時間が2秒未満の場合
        _hintLog = _hint;
    };
    case (_CRT < 3): {
        _hint = "<3 seconds"; // 毛細血管再充填時間が3秒未満の場合
        _hintLog = "<3 seconds";
    };
    case (_CRT < 4): {
        _hint = "~3 seconds"; // 毛細血管再充填時間が3秒未満の場合
        _hintLog = _hint;
    };
    default {
        _hint = ">4 seconds"; // 毛細血管再充填時間が4秒以上の場合
        _hintLog = ">4 seconds";
    };
};

// 毛細血管再充填時間を表示
[QACEGVAR(common,displayTextStructured), [(format ["Measured Capillary Refill Time<br />%1", _hint]), 2, _medic], _medic] call CBA_fnc_targetEvent;
// ログに毛細血管再充填時間を追加
[_patient, "quick_view", "%1 measured capillary refill time: %2 (%3)", [[_medic, false, true] call ACEFUNC(common,getName), _hintLog, _bodyPartString]] call ACEFUNC(medical_treatment,addToLog);
