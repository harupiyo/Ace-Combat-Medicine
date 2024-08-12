#include "..\script_component.hpp"
/*
 * 作成者: Blue
 * AEDのバイタル追跡を処理
 *
 * 引数:
 * 0: 医療担当者 <OBJECT>
 * 1: 患者 <OBJECT>
 * 2: 体の部位インデックス <NUMBER>
 *
 * 戻り値:
 * なし
 *
 * 例:
 * [player, cursorTarget, 2] call ACM_circulation_fnc_handleAED;
 *
 * 公開: いいえ
 */

params ["_medic", "_patient"];

// AED_PFH変数が-1でない場合は終了
if ((_patient getVariable [QGVAR(AED_PFH), -1]) != -1) exitWith {};

// 医療担当者が車両に乗っているかどうかを確認
private _inVehicle = !(isNull (objectParent _medic));

// 患者と医療担当者のAED関連変数を設定
_patient setVariable [QGVAR(AED_Provider), _patient, true];
_medic setVariable [QGVAR(AED_Target_Patient), _patient, true];
_medic setVariable [QGVAR(AED_Medic_InUse), false, true];

// AEDの開始時間を設定
_patient setVariable [QGVAR(AED_StartTime), CBA_missionTime, true];
// アラームをミュート
_patient setVariable [QGVAR(AED_MuteAlarm), true, true];
// AEDが使用中でないことを設定
_patient setVariable [QGVAR(AED_InUse), false, true];

// 患者の心停止リズム状態を確認
if (_patient getVariable [QGVAR(CardiacArrest_RhythmState), 0] in [1,2,3]) then {
    // 心停止状態のアラームを設定
    _patient setVariable [QGVAR(AED_Alarm_CardiacArrest_State), true];
    _patient setVariable [QGVAR(AED_Alarm_State), true];

    // AEDがないか使用中でない場合にサウンドを再生
    [{
        params ["_patient"];

        !([_patient] call FUNC(hasAED)) || (_patient getVariable [QGVAR(AED_InUse), false]);
    }, {}, [_patient], 5, {
        params ["_patient"];

        playSound3D [QPATHTO_R(sound\aed_pushanalyze.wav), _patient, false, getPosASL _patient, 15, 1, 15]; // 1.715秒
    }] call CBA_fnc_waitUntilAndExecute;
} else {
    // 心停止状態のアラームを解除
    _patient setVariable [QGVAR(AED_Alarm_CardiacArrest_State), false];
    _patient setVariable [QGVAR(AED_Alarm_State), false];

    // アラームをミュート解除
    [{
        params ["_patient"];

        _patient setVariable [QGVAR(AED_MuteAlarm), false, true];
    }, [_patient], 5] call CBA_fnc_waitAndExecute;
}
;

// CBA_fnc_addPerFrameHandler関数を呼び出して、PerFrameHandlerを追加します。この関数は、指定されたコードブロックを毎フレーム実行するように設定します。
private _PFH = [{
    // 引数とIDを取得
    params ["_args", "_idPFH"];
    _args params ["_patient", "_medic"];

    // 患者の各種センサーの状態を取得
    private _padsStatus = _patient getVariable [QGVAR(AED_Placement_Pads), false];
    private _pulseOximeterPlacement = _patient getVariable [QGVAR(AED_Placement_PulseOximeter), -1];
    private _pulseOximeterPlacementStatus = (_pulseOximeterPlacement != -1 && {HAS_TOURNIQUET_APPLIED_ON(_patient,_pulseOximeterPlacement)});
    private _pressureCuffPlacement = _patient getVariable [QGVAR(AED_Placement_PressureCuff), -1];
    private _capnographStatus = _patient getVariable [QGVAR(AED_Placement_Capnograph), false];

    // すべてのセンサーが未装着の場合の処理
    if (!_padsStatus && _pulseOximeterPlacement == -1 && _pressureCuffPlacement == -1 && !_capnographStatus) exitWith {
        // 各種表示をリセット
        _patient setVariable [QGVAR(AED_Pads_Display), 0, true];
        _patient setVariable [QGVAR(AED_Pads_LastSync), -1];
        _patient setVariable [QGVAR(AED_PulseOximeter_Display), -1, true];
        _patient setVariable [QGVAR(AED_PulseOximeter_LastSync), -1];

        _patient setVariable [QGVAR(AED_Capnograph_LastSync), -1];
        _patient setVariable [QGVAR(AED_RR_Display), 0, true];
        _patient setVariable [QGVAR(AED_CO2_Display), 0, true];

        // AEDの変数をリセット
        _patient setVariable [QGVAR(AED_PFH), -1];

        _medic setVariable [QGVAR(AED_Target_Patient), objNull, true];
        _patient setVariable [QGVAR(AED_Provider), objNull, true];

        _patient setVariable [QGVAR(AED_MuteAlarm), false, true];

        // PerFrameHandlerを削除
        [_idPFH] call CBA_fnc_removePerFrameHandler;
    };

    // 患者のSpO2を取得
    private _spO2 = [_patient] call EFUNC(breathing,getSpO2);

    // パッドが装着されている場合の処理
    if (_padsStatus) then {
        // 最後の同期時間を取得
        private _lastSync = _patient getVariable [QGVAR(AED_Pads_LastSync), -1];

        // 心拍数とリズム状態を取得
        private _ekgHR = [_patient] call FUNC(getEKGHeartRate);
        private _rhythmState = _patient getVariable [QGVAR(CardiacArrest_RhythmState), 0];

        // 5.25秒ごとに心拍数を表示
        if (_lastSync + 5.25 < CBA_missionTime) then {
            _patient setVariable [QGVAR(AED_Pads_LastSync), CBA_missionTime];
            _patient setVariable [QGVAR(AED_Pads_Display), round(_ekgHR), true];
        };

        // AEDが静かかどうかを確認
        if ([_patient] call FUNC(AED_IsSilent)) then {
            _patient setVariable [QGVAR(AED_Alarm_CardiacArrest_State), false];
            _patient setVariable [QGVAR(AED_Alarm_State), false];
        };

        // AEDが使用中でなく、静かでなく、CPRが実行されていない場合の処理
        if (!(_patient getVariable [QGVAR(AED_InUse), false]) && !([_patient] call FUNC(AED_IsSilent)) && !([_patient] call EFUNC(core,cprActive))) then {
            if (_ekgHR > 0) then {
                // 最後のビープ音の時間を取得
                private _lastBeep = _patient getVariable [QGVAR(AED_Pads_LastBeep), -1];
                private _hrDelay = 60 / _ekgHR;

                // アラーム状態でない場合の処理
                if (!(_patient getVariable [QGVAR(AED_Alarm_State), false]) && {_rhythmState in [2,3]}) then {
                    _patient setVariable [QGVAR(AED_Alarm_State), true];

                    // 2秒後にアラームを再生
                    [{
                        params ["_patient"];

                        if !(_patient getVariable [QGVAR(CardiacArrest_RhythmState), 0] in [0,5]) then {
                            [_patient] call FUNC(AED_PlayAlarm);
                            _patient setVariable [QGVAR(AED_Alarm_CardiacArrest_State), true];
                        } else {
                            _patient setVariable [QGVAR(AED_Alarm_State), false];
                        };
                    }, [_patient], 2] call CBA_fnc_waitAndExecute;
                };

                // 心停止状態のアラームが有効な場合の処理
                if (_patient getVariable [QGVAR(AED_Alarm_CardiacArrest_State), false]) exitWith {
                    if (_rhythmState in [0,5]) then {
                        _patient setVariable [QGVAR(AED_Alarm_CardiacArrest_State), false];
                        _patient setVariable [QGVAR(AED_Alarm_State), false];
                        playSound3D [QPATHTO_R(sound\aed_3beep.wav), _patient, false, getPosASL _patient, 15, 1, 15]; // 0.369秒
                    };
                };

                // 心拍数に応じてビープ音を再生
                if ((_lastBeep + _hrDelay) < CBA_missionTime) then {
                    _patient setVariable [QGVAR(AED_Pads_LastBeep), CBA_missionTime];

                    private _pitch = 1;
                    if (_pulseOximeterPlacement != -1) then { // SpO2に応じてビープ音のピッチを変更
                        _pitch = linearConversion [50, 90, ([_patient, true] call EFUNC(breathing,getSpO2)), 0.5, 1, true];
                    };

                    playSound3D [QPATHTO_R(sound\aed_hr_beep.wav), _patient, false, getPosASL _patient, 15, _pitch, 15]; // 0.15秒
                };
            } else {
                // 心拍数が0の場合の処理
                if !(_patient getVariable [QGVAR(AED_Alarm_State), false]) then {
                    _patient setVariable [QGVAR(AED_Alarm_State), true];

                    // 2秒後にアラームを再生
                    [{
                        params ["_patient"];

                        if !(_patient getVariable [QGVAR(CardiacArrest_RhythmState), 0] in [0,5]) then {
                            [_patient] call FUNC(AED_PlayAlarm);
                            _patient setVariable [QGVAR(AED_Alarm_CardiacArrest_State), true];
                        } else {
                            _patient setVariable [QGVAR(AED_Alarm_State), false];
                        };
                    }, [_patient], 2] call CBA_fnc_waitAndExecute;
                };
            };
        };
    };

    // パルスオキシメータが装着されている場合の処理
    if (_pulseOximeterPlacement != -1) then {
        // 最後の同期時間を取得
        private _lastSync = _patient getVariable [QGVAR(AED_PulseOximeter_LastSync), -1];

        // 3秒ごとに同期
        if (_lastSync + 3 < CBA_missionTime) then {
            _patient setVariable [QGVAR(AED_PulseOximeter_LastSync), CBA_missionTime];

            // 患者に止血帯が装着されていない場合の処理
            if (!(HAS_TOURNIQUET_APPLIED_ON(_patient,_pulseOximeterPlacement))) then {
                // SpO2を表示
                _patient setVariable [QGVAR(AED_PulseOximeter_Display), round(_spO2), true];
                if !(_padsStatus) then {
                    // 心拍数を表示
                    _patient setVariable [QGVAR(AED_Pads_Display), round(GET_HEART_RATE(_patient)), true];
                };
            } else {
                // 止血帯が装着されている場合の処理
                _patient setVariable [QGVAR(AED_PulseOximeter_Display), 0, true];
                if !(_padsStatus) then {
                    _patient setVariable [QGVAR(AED_Pads_Display), 0, true];
                };
            };
        };
    };

    // カプノグラフが装着されている場合の処理
    if (_capnographStatus) then {
        // 最後の同期時間を取得
        private _lastSync = _patient getVariable [QGVAR(AED_Capnograph_LastSync), -1];

        // 4秒ごとに同期
        if (_lastSync + 4 < CBA_missionTime) then {
            // 呼吸数とCO2濃度を表示
            _patient setVariable [QGVAR(AED_RR_Display), round(GET_RESPIRATION_RATE(_patient)), true];
            _patient setVariable [QGVAR(AED_CO2_Display), round([_patient] call EFUNC(breathing,getEtCO2)), true];
        };
    };

}, 0, [_patient, _medic]] call CBA_fnc_addPerFrameHandler;

// AEDのPerFrameHandlerを設定
_patient setVariable [QGVAR(AED_PFH), _PFH];

// 医療担当者が車両に乗っている場合の処理
if (_inVehicle) then {
    // 医療担当者と患者が同じ車両にいない場合の処理
    [{
        params ["_patient", "_medic"];

        !((objectParent _medic) isEqualTo (objectParent _patient));
    }, {
        params ["_patient", "_medic"];

        // 患者が存在する場合の処理
        if !(isNull _patient) then {
            // AEDを設定
            [_medic, _patient, "body", 0, false, true] call FUNC(setAED);
            [_medic, _patient, "body", 1, false, true] call FUNC(setAED);
            [_medic, _patient, "body", 2, false, true] call FUNC(setAED);
            [_medic, _patient, "body", 3, false, true] call FUNC(setAED);
            // ログに追加
            [_patient, "activity", "%1 disconnected AED", [[_medic, false, true] call ACEFUNC(common,getName)]] call ACEFUNC(medical_treatment,addToLog);
            // メッセージを表示
            ["Patient Disconnected", 1.5, _medic] call ACEFUNC(common,displayTextStructured);
        };
    }, [_patient, _medic], 3600] call CBA_fnc_waitUntilAndExecute;
} else {
    // 医療担当者と患者が同じ車両にいない、または距離が離れている場合の処理
    [{
        params ["_patient", "_medic"];
    
        (!((objectParent _medic) isEqualTo (objectParent _patient)) || ((_patient distance _medic) > GVAR(AEDDistanceLimit)));
    }, {
        params ["_patient", "_medic"];
        
        // 患者が存在する場合の処理
        if !(isNull _patient) then {
            // AEDを設定
            [_medic, _patient, "body", 0, false, true] call FUNC(setAED);
            [_medic, _patient, "body", 1, false, true] call FUNC(setAED);
            [_medic, _patient, "body", 2, false, true] call FUNC(setAED);
            [_medic, _patient, "body", 3, false, true] call FUNC(setAED);
            // ログに追加
            [_patient, "activity", "%1 disconnected AED", [[_medic, false, true] call ACEFUNC(common,getName)]] call ACEFUNC(medical_treatment,addToLog);
            // メッセージを表示
            ["Patient Disconnected", 1.5, _medic] call ACEFUNC(common,displayTextStructured);
        };
    }, [_patient, _medic], 3600] call CBA_fnc_waitUntilAndExecute;
};
