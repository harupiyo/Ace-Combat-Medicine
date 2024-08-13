#include "..\script_component.hpp"
/*
 * Author: Blue
 * 胸部損傷を手動で与えるためのモジュールダイアログ
 *
 * Arguments:
 * 0: Module Logic <OBJECT>
 *
 * Return Value:
 * None
 *
 * Example:
 * [CONTROL] call ACM_zeus_fnc_inflictChestInjury;
 *
 * Public: No
 */

params ["_control"];

// 一般的な初期化
private _display = ctrlParent _control; // コントロールの親ディスプレイを取得
private _ctrlButtonOK = _display displayCtrl 1; // OKボタンのコントロールを取得 (IDC_OK)
private _logic = GETMVAR(BIS_fnc_initCuratorAttributes_target,objNull); // モジュールのターゲットロジックを取得
TRACE_1("Logic Object",_logic); // ロジックオブジェクトをトレース

_control ctrlRemoveAllEventHandlers "SetFocus"; // コントロールの全てのイベントハンドラを削除

private _unit = effectiveCommander attachedTo _logic; // ロジックに付随するユニットを取得

// モジュールターゲットの検証
scopeName "Main"; // スコープ名を設定
private _fnc_errorAndClose = {
    params ["_msg"];
    deleteVehicle _logic; // ロジックオブジェクトを削除
    [_msg] call ACEFUNC(zeus,showMessage); // メッセージを表示
    breakOut "Main"; // スコープを抜ける
};

switch (true) do {
    case (isNull _unit): {
        [ACELSTRING(zeus,NothingSelected)] call _fnc_errorAndClose; // ユニットが選択されていない場合
    };
    case !(_unit isKindOf "CAManBase"): {
        [ACELSTRING(zeus,OnlyInfantry)] call _fnc_errorAndClose; // ユニットが歩兵でない場合
    };
    case !(alive _unit): {
        [ACELSTRING(zeus,OnlyAlive)] call _fnc_errorAndClose; // ユニットが生存していない場合
    };
};

// アンロード時の処理
private _fnc_onUnload = {
    private _logic = GETMVAR(BIS_fnc_initCuratorAttributes_target,objNull);
    if (isNull _logic) exitWith {}; // ロジックが存在しない場合は終了

    deleteVehicle _logic; // ロジックオブジェクトを削除
};

// 確認ボタンが押された時の処理
private _fnc_onConfirm = {
    params [["_ctrlButtonOK", controlNull, [controlNull]]];

    private _display = ctrlParent _ctrlButtonOK; // OKボタンの親ディスプレイを取得
    if (isNull _display) exitWith {}; // ディスプレイが存在しない場合は終了

    private _logic = GETMVAR(BIS_fnc_initCuratorAttributes_target,objNull); // モジュールのターゲットロジックを取得
    if (isNull _logic) exitWith {}; // ロジックが存在しない場合は終了

    private _patient = attachedTo _logic; // ロジックに付随する患者を取得

    private _selection = lbCurSel (_display displayCtrl IDC_MODULE_INFLICT_CHEST_INJURY_LIST); // リストから選択された項目を取得

    _patient setVariable [QEGVAR(breathing,ChestInjury_State), true, true]; // 胸部損傷の状態を設定

    switch (_selection) do {
        case 0: {
            [_patient] call EFUNC(breathing,handlePneumothorax); // 気胸の処理
        };
        case 1: {
            _patient setVariable [QEGVAR(breathing,Pneumothorax_State), 4, true]; // 気胸の状態を設定
            [_patient] call EFUNC(breathing,handlePneumothorax); // 気胸の処理
        };
        case 2: {
            _patient setVariable [QEGVAR(breathing,Hemothorax_State), 2, true]; // 血胸の状態を設定
            [_patient] call EFUNC(breathing,handleHemothorax); // 血胸の処理
        };
        case 3: {
            _patient setVariable [QEGVAR(breathing,Hemothorax_State), 2, true]; // 血胸の状態を設定
            _patient setVariable [QEGVAR(breathing,Hemothorax_Fluid), 1.2, true]; // 胸腔内液体の量を設定
            [_patient] call EFUNC(breathing,handleHemothorax); // 血胸の処理
        };
    };

    [_patient] call EFUNC(breathing,updateLungState); // 肺の状態を更新
};

// イベントハンドラの追加
_display displayAddEventHandler ["Unload", _fnc_onUnload]; // アンロード時のイベントハンドラを追加
_ctrlButtonOK ctrlAddEventHandler ["ButtonClick", _fnc_onConfirm]; // 確認ボタンが押された時のイベントハンドラを追加
