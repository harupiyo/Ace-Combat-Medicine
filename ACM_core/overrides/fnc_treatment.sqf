#include "..\script_component.hpp"
/*
 * Author: Glowbal, KoffeinFlummi, mharis001
 * Starts the treatment process.
 *
 * Arguments:
 * 0: Medic <OBJECT> // 医療担当者
 * 1: Patient <OBJECT> // 患者
 * 2: Body Part <STRING> // 体の部位
 * 3: Treatment <STRING> // 治療
 *
 * Return Value:
 * Treatment Started <BOOL> // 治療が開始されたかどうか
 *
 * Example:
 * [player, cursorObject, "Head", "BasicBandage"] call ace_medical_treatment_fnc_treatment
 *
 * Public: No
 */

params ["_medic", "_patient", "_bodyPart", "_classname"]; // パラメータの取得

// カーソルメニューが開いている場合、プログレスバーの失敗を防ぐためにフレームを遅延
if (uiNamespace getVariable [QACEGVAR(interact_menu,cursorMenuOpened), false]) exitWith {
    [ACEFUNC(medical_treatment,treatment), _this] call CBA_fnc_execNextFrame;
};

if !(_this call ACEFUNC(medical_treatment,canTreat)) exitWith {false}; // 治療が可能かどうかを確認

private _config = configFile >> QACEGVAR(medical_treatment,actions) >> _classname; // コンフィグを取得

// コンフィグから治療時間を取得し、治療時間がゼロの場合は終了
private _treatmentTime = if (isText (_config >> "treatmentTime")) then {
    GET_FUNCTION(_treatmentTime,_config >> "treatmentTime");

    if (_treatmentTime isEqualType {}) then {
        _treatmentTime = call _treatmentTime;
    };

    _treatmentTime
} else {
    getNumber (_config >> "treatmentTime");
};

if (_treatmentTime == 0) exitWith {false}; // 治療時間がゼロの場合は終了

// 必要に応じて治療アイテムを消費
// 失敗時に使用されたアイテムを返すためにアイテムユーザーを保存
private _userAndItem = if (GET_NUMBER_ENTRY(_config >> "consumeItem") == 1) then {
    [_medic, _patient, getArray (_config >> "items")] call ACEFUNC(medical_treatment,useItem);
} else {
    [objNull, ""]; // 治療にアイテムの消費が必要ない場合
};

_userAndItem params ["_itemUser", "_usedItem", "_createLitter"]; // アイテムユーザー、使用されたアイテム、リッターの作成を取得

private _isInZeus = !isNull findDisplay 312; // Zeusモードかどうかを確認
private _isSelf = _medic isEqualTo _patient; // 自己治療かどうかを確認

private _rollToBack = false; // 背中に転がるかどうか
private _cancelsRecoveryPosition = false; // 回復位置をキャンセルするかどうか
private _ignoreAnimCoef = false; // アニメーション係数を無視するかどうか

if (isNumber (_config >> "ACM_ignoreAnimCoef")) then {
    _ignoreAnimCoef = [false,true] select (getNumber (_config >> "ACM_ignoreAnimCoef"));
};

if (isNumber (_config >> "ACM_rollToBack")) then {
    _rollToBack = [false,true] select (getNumber (_config >> "ACM_rollToBack"));
    if !(_rollToBack) then {
        _rollToBack = (_bodyPart == "Body");
    };
};

if (isNumber (_config >> "ACM_cancelRecovery")) then {
    _cancelsRecoveryPosition = [false,true] select (getNumber (_config >> "ACM_cancelRecovery"));

    if ((_patient getVariable [QEGVAR(airway,RecoveryPosition_State), false]) && _cancelsRecoveryPosition) then {
        _patient setVariable [QEGVAR(airway,RecoveryPosition_State), false, true];
    };
};

// 患者のアニメーションを再生
if (alive _patient) then {
    private _animationStatePatient = animationState _patient; // 患者のアニメーション状態を取得

    if (_animationStatePatient != "acm_recoveryposition" || (_animationStatePatient == "acm_recoveryposition" && _cancelsRecoveryPosition)) then {
        private _patientAnim = ""; // 患者のアニメーションを初期化

        if (IS_UNCONSCIOUS(_patient)) then { // 患者が意識不明の場合
            if (!(_animationStatePatient in (getArray (_config >> "animationPatientUnconsciousExcludeOn"))) && {isText (_config >> "animationPatientUnconscious")}) then {
                _patientAnim = getText (_config >> "animationPatientUnconscious");
            };
        } else {
            if (isText (_config >> "animationPatient")) then {
                _patientAnim = getText (_config >> "animationPatient");
            };
        };

        if (!_isSelf && {isNull objectParent _patient}) then { // 自己治療でなく、患者が乗り物に乗っていない場合
            if (_patientAnim == "" && _rollToBack && IS_UNCONSCIOUS(_patient) && {!(_animationStatePatient in LYING_ANIMATION)}) then {
                _patientAnim = "AinjPpneMstpSnonWrflDnon_rolltoback"; // 背中に転がるアニメーションを設定
            };

            if (_patientAnim != "") then {
                if (IS_UNCONSCIOUS(_patient)) then {
                    [_patient, _patientAnim, 2] call ACEFUNC(common,doAnimation); // 意識不明の場合のアニメーションを再生
                } else {
                    [_patient, _patientAnim, 1] call ACEFUNC(common,doAnimation); // 意識がある場合のアニメーションを再生
                };
            };
        };
    };
};

if (_medic isNotEqualTo player || {!_isInZeus}) then { // メディックがプレイヤーでない、またはZeusモードでない場合
    // メディックの治療アニメーションを取得
    private _medicAnim = if (_isSelf) then { // 自己治療の場合
        getText (_config >> ["animationMedicSelf", "animationMedicSelfProne"] select (stance _medic == "PRONE")); // 自己治療のアニメーションを取得
    } else {
        getText (_config >> ["animationMedic", "animationMedicProne"] select (stance _medic == "PRONE")); // 他者治療のアニメーションを取得
    };

    _medic setVariable [QACEGVAR(medical_treatment,selectedWeaponOnTreatment), weaponState _medic]; // 治療中の武器状態を保存

    // メディックの現在の武器に基づいてアニメーションを調整
    private _wpn = ["non", "rfl", "lnr", "pst"] param [["", primaryWeapon _medic, secondaryWeapon _medic, handgunWeapon _medic] find currentWeapon _medic, "non"];
    _medicAnim = [_medicAnim, "[wpn]", _wpn] call CBA_fnc_replace;

    // このアニメーションが欠けている場合、代替を使用
    if (_medicAnim == "AinvPknlMstpSlayWlnrDnon_medic") then {
        _medicAnim = "AinvPknlMstpSlayWlnrDnon_medicOther";
    };

    // アニメーションの長さを決定
    private _animDuration = ACEGVAR(medical_treatment,animDurations) getVariable _medicAnim;
    if (isNil "_animDuration") then {
        WARNING_2("animation [%1] for [%2] has no duration defined",_medicAnim,_classname);
        _animDuration = 10;
    };

    // これらのアニメーションには少し長い遷移がある...
    if (weaponLowered _medic) then {
        _animDuration = _animDuration + 0.5;

        // 武器の遷移の問題を修正するために、最初に武器を上げる
        if (currentWeapon _medic != "" && {_medicAnim != ""}) then {
            _medic action ["WeaponInHand", _medic];
        };
    };

    if (binocular _medic != "" && {binocular _medic == currentWeapon _medic}) then {
        _animDuration = _animDuration + 1;
    };

    // メディックの治療アニメーションを再生し、終了アニメーションを決定
    if (vehicle _medic == _medic && {_medicAnim != ""}) then {
        // 治療時間に基づいてアニメーションを高速化（ただし、奇妙なアニメーションやカメラの揺れを防ぐために最大値を制限）
        private _animRatio = _animDuration / _treatmentTime;
        TRACE_3("setAnimSpeedCoef",_animRatio,_animDuration,_treatmentTime);

        // アニメーションが面白く見えないように、アニメーションをあまり遅くしない
        if (_animRatio < ANIMATION_SPEED_MIN_COEFFICIENT) then {
            _animRatio = ANIMATION_SPEED_MIN_COEFFICIENT;
        };

        // プログレスバーが速すぎる場合、アニメーションを完全にスキップ
        if (_animRatio > ANIMATION_SPEED_MAX_COEFFICIENT && {!_ignoreAnimCoef}) exitWith {};

        [QACEGVAR(common,setAnimSpeedCoef), [_medic, _animRatio]] call CBA_fnc_globalEvent;

        // アニメーションを再生
        private _endInAnim = "AmovP[pos]MstpS[stn]W[wpn]Dnon";

        private _pos = ["knl", "pne"] select (stance _medic == "PRONE");
        private _stn = "non";

        if (_wpn != "non") then {
            _stn = ["ras", "low"] select (weaponLowered _medic);
        };

        _endInAnim = [_endInAnim, "[pos]", _pos] call CBA_fnc_replace;
        _endInAnim = [_endInAnim, "[stn]", _stn] call CBA_fnc_replace;
        _endInAnim = [_endInAnim, "[wpn]", _wpn] call CBA_fnc_replace;

        [_medic, _medicAnim] call ACEFUNC(common,doAnimation);
        [_medic, _endInAnim] call ACEFUNC(common,doAnimation);
        _medic setVariable [QACEGVAR(medical_treatment,endInAnim), _endInAnim];

        // advanced_fatigue モジュールが有効な場合に、Medical_Treatment アドオンのアニメーションを除外リストに追加します。
        if (!isNil QACEGVAR(advanced_fatigue,setAnimExclusions)) then {
            // advanced_fatigue モジュールの setAnimExclusions 変数は除外するアニメーションのリストを保持します。
            ACEGVAR(advanced_fatigue,setAnimExclusions) pushBack QUOTE(ACE_ADDON(Medical_Treatment));
        };
    };

    // 定義されている場合、ランダムな治療音をグローバルに再生
    private _soundsConfig = _config >> "sounds";

    if (isArray _soundsConfig && {count (getArray _soundsConfig) > 0}) then { // 空でない場合にのみ再生を試みる
        (selectRandom (getArray _soundsConfig)) params ["_file", ["_volume", 1], ["_pitch", 1], ["_distance", 10]];
        private _soundID = playSound3D [_file, objNull, false, getPosASL _medic, _volume, _pitch, _distance];

        [{
            !dialog;
        }, {
            params ["_soundID"];
            stopSound _soundID;
        }, [_soundID], _treatmentTime] call CBA_fnc_waitUntilAndExecute;
    };
};

if (_isInZeus) then { // Zeusモードの場合
    _treatmentTime = _treatmentTime * ACEGVAR(medical_treatment,treatmentTimeCoeffZeus); // Zeusモードの治療時間係数を適用
};

// コールバック関数を取得
GET_FUNCTION(_callbackStart,_config >> "callbackStart");
GET_FUNCTION(_callbackProgress,_config >> "callbackProgress");

if (_callbackProgress isEqualTo {}) then { // コールバック関数が空の場合
    _callbackProgress = {true}; // デフォルトのコールバック関数を設定
};

// 治療開始のコールバック関数を呼び出し
[_medic, _patient, _bodyPart, _classname, _itemUser, _usedItem, _createLitter] call _callbackStart;

// ローカルイベントを呼び出し、治療開始を通知
["ace_treatmentStarted", [_medic, _patient, _bodyPart, _classname, _itemUser, _usedItem, _createLitter]] call CBA_fnc_localEvent;

// プログレスバーを表示し、治療の進行を管理
[
    _treatmentTime, // 治療時間
    [_medic, _patient, _bodyPart, _classname, _itemUser, _usedItem, _createLitter], // パラメータ
    ACEFUNC(medical_treatment,treatmentSuccess), // 治療成功時のコールバック関数
    ACEFUNC(medical_treatment,treatmentFailure), // 治療失敗時のコールバック関数
    getText (_config >> "displayNameProgress"), // プログレスバーに表示するテキスト
    _callbackProgress, // プログレスのコールバック関数
    ["isNotInside", "isNotSwimming", "isNotInZeus"] // 条件
] call ACEFUNC(common,progressBar);

true; // 処理が成功したことを示す
