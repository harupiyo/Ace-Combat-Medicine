#include "..\script_component.hpp"
/*
 * 作者: Blue
 * 患者に痛みを与える。
 *
 * 引数:
 * 0: モジュールロジック <OBJECT>
 *
 * 戻り値:
 * なし
 *
 * 例:
 * [CONTROL] call ACM_zeus_fnc_givePain;
 *
 * 公開: いいえ
 */

params ["_control"];

// 一般的な初期化
private _display = ctrlParent _control;
private _ctrlButtonOK = _display displayCtrl 1; // IDC_OK
private _logic = GETMVAR(BIS_fnc_initCuratorAttributes_target,objNull);
TRACE_1("Logic Object",_logic);

// コントロールからすべてのイベントハンドラを削除
_control ctrlRemoveAllEventHandlers "SetFocus";

// ロジックにアタッチされているユニットを取得
private _unit = effectiveCommander attachedTo _logic;

// モジュールターゲットを検証
scopeName "Main";
private _fnc_errorAndClose = {
    params ["_msg"];
    deleteVehicle _logic;
    [_msg] call ACEFUNC(zeus,showMessage);
    breakOut "Main";
};

// ユニットが有効かどうかをチェック
switch (true) do {
    case (isNull _unit): {
        [ACELSTRING(zeus,NothingSelected)] call _fnc_errorAndClose;
    };
    case !(_unit isKindOf "CAManBase"): {
        [ACELSTRING(zeus,OnlyInfantry)] call _fnc_errorAndClose;
    };
    case !(alive _unit): {
        [ACELSTRING(zeus,OnlyAlive)] call _fnc_errorAndClose;
    };
};

// アンロード時の処理を定義
private _fnc_onUnload = {
    private _logic = GETMVAR(BIS_fnc_initCuratorAttributes_target,objNull);
    if (isNull _logic) exitWith {};

    deleteVehicle _logic;
};

// 痛みの量を設定するスライダーを取得
private _ctrlPainAmount = _display displayCtrl IDC_MODULE_GIVE_PAIN_SLIDER;

// ロジックにアタッチされている患者を取得
private _patient = attachedTo _logic;

// 現在の痛みのレベルを取得
private _currentPain = GET_PAIN(_patient);

// スライダーの位置を現在の痛みのレベルに設定
_ctrlPainAmount sliderSetPosition _currentPain;

// スライダーの移動時の処理を定義
private _fnc_sliderMove = {
    params ["_slider"];

    private _logic = GETMVAR(BIS_fnc_initCuratorAttributes_target,objNull);
    if (isNull _logic) exitWith {};

    private _patient = attachedTo _logic;
    
    private _currentValue = (GET_PAIN(_patient) toFixed 2);

    _slider ctrlSetTooltip format ["%1 (was %2)", (sliderPosition _slider), _currentValue];
};

// スライダーを取得し、イベントハンドラを追加
private _slider = _display displayCtrl IDC_MODULE_GIVE_PAIN_SLIDER;
_slider ctrlAddEventHandler ["SliderPosChanged", _fnc_sliderMove];
_slider call _fnc_sliderMove;

// 確認ボタンのクリック時の処理を定義
private _fnc_onConfirm = {
    params [["_ctrlButtonOK", controlNull, [controlNull]]];

    private _display = ctrlParent _ctrlButtonOK;
    if (isNull _display) exitWith {};

    private _logic = GETMVAR(BIS_fnc_initCuratorAttributes_target,objNull);
    if (isNull _logic) exitWith {};

    private _patient = attachedTo _logic;

    private _currentPain = GET_PAIN(_patient);

    private _ctrlPainAmount = _display displayCtrl IDC_MODULE_GIVE_PAIN_SLIDER;

    private _setPain = (sliderPosition _ctrlPainAmount) - _currentPain;

    [QGVAR(givePain), [_patient, _setPain], _patient] call CBA_fnc_targetEvent;
};

// アンロード時のイベントハンドラを追加
_display displayAddEventHandler ["Unload", _fnc_onUnload];
// 確認ボタンのクリック時のイベントハンドラを追加
_ctrlButtonOK ctrlAddEventHandler ["ButtonClick", _fnc_onConfirm];