#include "..\script_component.hpp"
/*
 * Author: Glowbal, KoffeinFlummi, mharis001
 * Starts the treatment process.
 *
 * Arguments:
 * 0: Medic <OBJECT>
 * 1: Patient <OBJECT>
 * 2: Body Part <STRING>
 * 3: Treatment <STRING>
 *
 * Return Value:
 * Treatment Started <BOOL>
 *
 * Example:
 * [player, cursorObject, "Head", "BasicBandage"] call ace_medical_treatment_fnc_treatment
 *
 * Public: No
 */

params ["_medic", "_patient", "_bodyPart", "_classname"];

// カーソルメニューが開いている場合、プログレスバーの失敗を防ぐためにフレームを遅延
if (uiNamespace getVariable [QEGVAR(interact_menu,cursorMenuOpened), false]) exitWith {
    [FUNC(treatment), _this] call CBA_fnc_execNextFrame;
};

if !(_this call FUNC(canTreat)) exitWith {false};

private _config = configFile >> QGVAR(actions) >> _classname;

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

if (_treatmentTime == 0) exitWith {false};

// 必要に応じて治療アイテムを消費
// 失敗時に使用されたアイテムを返すためにアイテムユーザーを保存
private _userAndItem = if (GET_NUMBER_ENTRY(_config >> "consumeItem") == 1) then {
    [_medic, _patient, getArray (_config >> "items")] call FUNC(useItem);
} else {
    [objNull, ""]; // 治療にアイテムの消費が必要ない場合
};

_userAndItem params ["_itemUser", "_usedItem", "_createLitter"];

private _isInZeus = !isNull findDisplay 312;

if (_medic isNotEqualTo player || {!_isInZeus}) then {
    // メディックの治療アニメーションを取得
    private _medicAnim = if (_medic isEqualTo _patient) then {
        getText (_config >> ["animationMedicSelf", "animationMedicSelfProne"] select (stance _medic == "PRONE"));
    } else {
        getText (_config >> ["animationMedic", "animationMedicProne"] select (stance _medic == "PRONE"));
    };

    _medic setVariable [QGVAR(selectedWeaponOnTreatment), weaponState _medic];

    // メディックの現在の武器に基づいてアニメーションを調整
    private _wpn = ["non", "rfl", "lnr", "pst"] param [["", primaryWeapon _medic, secondaryWeapon _medic, handgunWeapon _medic] find currentWeapon _medic, "non"];
    _medicAnim = [_medicAnim, "[wpn]", _wpn] call CBA_fnc_replace;

    // このアニメーションが欠けている場合、代替を使用
    if (_medicAnim == "AinvPknlMstpSlayWlnrDnon_medic") then {
        _medicAnim = "AinvPknlMstpSlayWlnrDnon_medicOther";
    };

    // アニメーションの長さを決定
    private _animDuration = GVAR(animDurations) getVariable _medicAnim;
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
        if (_animRatio > ANIMATION_SPEED_MAX_COEFFICIENT) exitWith {};

        [QEGVAR(common,setAnimSpeedCoef), [_medic, _animRatio]] call CBA_fnc_globalEvent;

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

        [_medic, _medicAnim] call EFUNC(common,doAnimation);
        [_medic, _endInAnim] call EFUNC(common,doAnimation);
        _medic setVariable [QGVAR(endInAnim), _endInAnim];

        if (!isNil QEGVAR(advanced_fatigue,setAnimExclusions)) then {
            EGVAR(advanced_fatigue,setAnimExclusions) pushBack QUOTE(ADDON);
        };
    };

    // 定義されている場合、ランダムな治療音をグローバルに再生
    private _soundsConfig = _config >> "sounds";

    if (isArray _soundsConfig) then {
        (selectRandom (getArray _soundsConfig)) params ["_file", ["_volume", 1], ["_pitch", 1], ["_distance", 10]];
        playSound3D [_file, objNull, false, getPosASL _medic, _volume, _pitch, _distance];
    };
};

if (_isInZeus) then {
    _treatmentTime = _treatmentTime * GVAR(treatmentTimeCoeffZeus);
};

GET_FUNCTION(_callbackStart,_config >> "callbackStart");
GET_FUNCTION(_callbackProgress,_config >> "callbackProgress");

if (_callbackProgress isEqualTo {}) then {
    _callbackProgress = {true};
};

[_medic, _patient, _bodyPart, _classname, _itemUser, _usedItem, _createLitter] call _callbackStart;

["ace_treatmentStarted", [_medic, _patient, _bodyPart, _classname, _itemUser, _usedItem, _createLitter]] call CBA_fnc_localEvent;

[
    _treatmentTime,
    [_medic, _patient, _bodyPart, _classname, _itemUser, _usedItem, _createLitter],
    FUNC(treatmentSuccess),
    FUNC(treatmentFailure),
    getText (_config >> "displayNameProgress"),
    _callbackProgress,
    ["isNotInside", "isNotSwimming", "isNotInZeus"]
] call EFUNC(common,progressBar);

true
