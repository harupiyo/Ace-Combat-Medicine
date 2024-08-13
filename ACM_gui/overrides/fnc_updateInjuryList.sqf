#include "..\script_component.hpp"
/*
 * Author: mharis001
 * 対象の特定の部位に対する負傷リストを更新します。
 *
 * Arguments:
 * 0: Injury list <CONTROL>
 * 1: Target <OBJECT>
 * 2: Body part, -1 to only show overall health info <NUMBER>
 *
 * Return Value:
 * None
 *
 * Example:
 * [_ctrlInjuries, _target, 0] call ace_medical_gui_fnc_updateInjuryList
 *
 * Public: No
 */

params ["_ctrl", "_target", "_selectionN"];

private _entries = [];
private _nonissueColor = [1, 1, 1, 0.33];

private _airwayColor = [0.19, 0.91, 0.93, 1];
private _breathingColor = [0.3, 0.8, 0.8, 1];
private _circulationColor = [0.2, 0.6, 0.2, 1];

private _addListSpacer = false;

// ユニットが出血しているかどうかを示す
if (IS_BLEEDING(_target)) then {
    switch (ACEGVAR(medical_gui,showBleeding)) do {
        case 1: {
        // ユニットが出血しているかどうかだけを表示
            _entries pushBack [localize ACELSTRING(medical_gui,Status_Bleeding), [1, 0, 0, 1]];
        };
        case 2: {
            // 出血速度の定性的な説明を表示
            private _cardiacOutput = [_target] call ACEFUNC(medical_status,getCardiacOutput);
            private _bleedRate = GET_BLOOD_LOSS(_target);
            private _bleedRateKO = BLOOD_LOSS_KNOCK_OUT_THRESHOLD_DEFAULT * (_cardiacOutput max 0.05);
            // 心停止中にすべての出血が大量出血として表示されるのを防ぐために、非ゼロの最小心拍出量を使用
            switch (true) do {
                case (_bleedRate < _bleedRateKO * BLEED_RATE_SLOW): {
                    _entries pushBack [localize ACELSTRING(medical_gui,Bleed_Rate1), [1, 1, 0, 1]];
                };
                case (_bleedRate < _bleedRateKO * BLEED_RATE_MODERATE): {
                    _entries pushBack [localize ACELSTRING(medical_gui,Bleed_Rate2), [1, 0.67, 0, 1]];
                };
                case (_bleedRate < _bleedRateKO * BLEED_RATE_SEVERE): {
                    _entries pushBack [localize ACELSTRING(medical_gui,Bleed_Rate3), [1, 0.33, 0, 1]];
                };
                default {
                    _entries pushBack [localize ACELSTRING(medical_gui,Bleed_Rate4), [1, 0, 0, 1]];
                };
            };
        };
    };
} else {
    if (GVAR(showInactiveStatuses)) then {_entries pushBack ["No external bleeding", _nonissueColor];}; // TODO stringtable this
};

if (ACEGVAR(medical_gui,showBloodlossEntry)) then {
    // 失血量の定性的な説明を表示
    switch (GET_HEMORRHAGE(_target)) do {
        case 0: {
           if (GVAR(showInactiveStatuses)) then {_entries pushBack [localize ACELSTRING(medical_gui,Lost_Blood0), _nonissueColor];};
        };
        case 1: {
            _addListSpacer = true;
            _entries pushBack [localize ACELSTRING(medical_gui,Lost_Blood1), [1, 1, 0, 1]];
        };
        case 2: {
            _addListSpacer = true;
            _entries pushBack [localize ACELSTRING(medical_gui,Lost_Blood2), [1, 0.67, 0, 1]];
        };
        case 3: {
            _addListSpacer = true;
            _entries pushBack [localize ACELSTRING(medical_gui,Lost_Blood3), [1, 0.33, 0, 1]];
        };
        case 4: {
            _addListSpacer = true;
            _entries pushBack [localize ACELSTRING(medical_gui,Lost_Blood4), [1, 0, 0, 1]];
        };
    };
};

// IVの残り量を表示
private _totalIvVolume = 0;
private _saline = 0;
private _blood = 0;
private _plasma = 0;
{
    _x params ["", "_type", "_volumeRemaining"];
    switch (_type) do {
        case "Saline": {
            _saline = _saline + _volumeRemaining;
        };
        case "Blood": {
            _blood = _blood + _volumeRemaining;
        };
        case "Plasma": {
            _plasma = _plasma + _volumeRemaining;
        };
    };
    _totalIvVolume = _totalIvVolume + _volumeRemaining;
} forEach (_target getVariable [QACEGVAR(medical,ivBags), []]);

if (_totalIvVolume > 0) then {
    if (_saline > 0) then {
        _entries pushBack [format [localize ACELSTRING(medical_treatment,receivingSalineIvVolume), floor _saline], [1, 1, 1, 1]];
    };
    if (_blood > 0) then {
        _entries pushBack [format [localize ACELSTRING(medical_treatment,receivingBloodIvVolume), floor _blood], [1, 1, 1, 1]];
    };
    if (_plasma > 0) then {
        _entries pushBack [format [localize ACELSTRING(medical_treatment,receivingPlasmaIvVolume), floor _plasma], [1, 1, 1, 1]];
    };
} else {
    if (GVAR(showInactiveStatuses)) then {_entries pushBack [localize ACELSTRING(medical_treatment,Status_NoIv), _nonissueColor];};
};

// ユニットの痛みの量を示す
if (_target call ACEFUNC(common,isAwake)) then {
    private _pain = GET_PAIN_PERCEIVED(_target);
    if (_pain > 0) then {
        _addListSpacer = true;
        private _painText = switch (true) do {
            case (_pain > PAIN_UNCONSCIOUS): {
                ACELSTRING(medical_treatment,Status_SeverePain);
            };
            case (_pain > (PAIN_UNCONSCIOUS / 5)): {
                ACELSTRING(medical_treatment,Status_Pain);
            };
            default {
                ACELSTRING(medical_treatment,Status_MildPain);
            };
        };
        _entries pushBack [localize _painText, [1, 1, 1, 1]];
    } else {
        if (GVAR(showInactiveStatuses)) then {_entries pushBack [localize ACELSTRING(medical_gui,Status_NoPain), _nonissueColor];};
    };
};

// 残りは体の部位ごとに特定のためスキップ
if (_selectionN == -1) exitWith {
    // すべてのエントリを傷害リストに追加
    lbClear _ctrl;

    {
        _x params ["_text", "_color"];

        _ctrl lbSetColor [_ctrl lbAdd _text, _color];
    } forEach _entries;

    _ctrl lbSetCurSel -1;
};

[QACEGVAR(medical_gui,updateInjuryListGeneral), [_ctrl, _target, _selectionN, _entries]] call CBA_fnc_localEvent;

if (count _entries > 0) then {_entries pushBack ["", [1, 1, 1, 1]];}; // エントリがある場合、空のエントリを追加

// 選択された体の部位の名前を追加
private _bodyPartName = [
    ACELSTRING(medical_gui,Head), // 頭
    ACELSTRING(medical_gui,Torso), // 胴体
    ACELSTRING(medical_gui,LeftArm), // 左腕
    ACELSTRING(medical_gui,RightArm), // 右腕
    ACELSTRING(medical_gui,LeftLeg), // 左脚
    ACELSTRING(medical_gui,RightLeg) // 右脚
] select _selectionN;

_entries pushBack [localize _bodyPartName, [1, 1, 1, 1]]; // 選択された体の部位の名前をエントリに追加

// 回復体位
if (_selectionN in [0,1] && _target getVariable [QEGVAR(airway,RecoveryPosition_State), false]) then {
    _entries pushBack ["In Recovery Position", _airwayColor]; // 回復体位にある場合
} else {
    if (_selectionN == 0 && _target getVariable [QEGVAR(airway,HeadTilt_State), false]) then {
        _entries pushBack ["Head Tilted & Chin Lifted", _airwayColor]; // 頭が傾いて顎が持ち上げられている場合
    };
};

// CPR
if (_selectionN == 1 && (_target getVariable [QEGVAR(circulation,CPR_Medic), objNull]) isNotEqualTo objNull) then {
    private _string = "Paused"; // 一時停止中
    if ([_target] call EFUNC(core,cprActive)) then {
        _string = "In Progress"; // 進行中
    };
    _entries pushBack [format ["CPR %1 (%2)", _string, ([(_target getVariable [QEGVAR(circulation,CPR_Medic), objNull]), false, true] call ACEFUNC(common,getName))], _circulationColor]; // CPRの状態をエントリに追加
};

// 気道アイテム
if (_selectionN == 0) then {
    private _airwayItemTypeOral = _target getVariable [QEGVAR(airway,AirwayItem_Oral), ""];
    private _airwayItemTypeNasal = _target getVariable [QEGVAR(airway,AirwayItem_Nasal), ""];

    if (_airwayItemTypeNasal == "NPA") then {
        _entries pushBack ["NPA", _airwayColor]; // 鼻咽頭エアウェイが挿入されている場合
    };

    if (_airwayItemTypeOral != "") then {
        private _airwayItem = "Guedel Tube"; // グーデルチューブ

        if (_airwayItemTypeOral isEqualTo "SGA") then {
            _airwayItem = "i-gel"; // i-gel
        };

        _entries pushBack [_airwayItem, _airwayColor]; // 口腔エアウェイが挿入されている場合
    };
};

private _oxygenSaturation = GET_OXYGEN(_target); // 酸素飽和度を取得

// チアノーゼ
if (_selectionN in [0,2,3] && {!(alive _target) || (_oxygenSaturation < 91 || HAS_TOURNIQUET_APPLIED_ON(_target,_selectionN))}) then {
    private _tourniquetTime = 0;
    if !(alive _target) then {
        private _timeSinceDeath = CBA_missionTime - (_target getVariable [QEGVAR(core,TimeOfDeath), CBA_missionTime]);
        private _newOxygenSaturation = linearConversion [0, (330 - ((100 - _oxygenSaturation) * ACM_BREATHING_MAXDECREASE)), _timeSinceDeath, 99, 55, true];
        _oxygenSaturation = _oxygenSaturation min _newOxygenSaturation;
    };
    private _colorScale = linearConversion [91, 55, _oxygenSaturation, 0.47, 0.13, true];

    if (HAS_TOURNIQUET_APPLIED_ON(_target,_selectionN)) then {
        _tourniquetTime = CBA_missionTime - ((_target getVariable [QEGVAR(disability,Tourniquet_ApplyTime), [-1,-1,-1,-1,-1,-1]]) select _selectionN);
        _colorScale = _colorScale min (linearConversion [1, 90, _tourniquetTime, 0.47, 0.13, true]);
    };

    private _cyanosis = switch (true) do {
        case (_oxygenSaturation < 67 || _tourniquetTime > 120): {"Severe"}; // 重度
        case (_oxygenSaturation < 82 || _tourniquetTime > 60): {"Moderate"}; // 中等度
        default {"Slight"}; // 軽度
    };

    _entries pushBack [format ["%1 Cyanosis", _cyanosis], [0.16, _colorScale, 1, 1]]; // チアノーゼの状態をエントリに追加
};

// BVM
if (_selectionN == 0 && (_target getVariable [QEGVAR(breathing,BVM_Medic), objNull]) isNotEqualTo objNull) then {
    private _string = "Paused"; // 一時停止中
    if (alive (_target getVariable [QEGVAR(breathing,BVM_provider), objNull])) then {
        _string = "Active"; // アクティブ
    };
    _entries pushBack [format ["BVM %1 (%2)", _string, ([(_target getVariable [QEGVAR(breathing,BVM_Medic), objNull]), false, true] call ACEFUNC(common,getName))], _breathingColor]; // BVMの状態をエントリに追加
};

private _bodyPartIV = GET_IV(_target) select _selectionN;

// IV/IO
if (_bodyPartIV > 0) then {
    private _IVText = switch (_bodyPartIV) do {
        case ACM_IV_16G_M: {"16g IV"}; // 16ゲージIV
        case ACM_IV_14G_M: {"14g IV"}; // 14ゲージIV
        case ACM_IO_FAST1_M: {"FAST1 IO"}; // FAST1 IO
    };
    private _connectedBag = [_target, _selectionN] call FUNC(getBodyPartIVBags);

    private _IVEntry = "";
    
    if (_connectedBag != "") then {
        _IVEntry = format ["%1 [%2]", _IVText, _connectedBag]; // 接続されたバッグがある場合
    } else {
        _IVEntry = _IVText; // 接続されたバッグがない場合
    };

    _entries pushBack [_IVEntry, _circulationColor]; // IV/IOの状態をエントリに追加
};

// AED
private _allowOnArm = (_target getVariable [QEGVAR(circulation,AED_Placement_PulseOximeter), -1] == (_selectionN max 0)) || (_target getVariable [QEGVAR(circulation,AED_Placement_PressureCuff), -1] == (_selectionN max 0));
private _allowOnHead = _target getVariable [QEGVAR(circulation,AED_Placement_Capnograph), false];
if ((_selectionN == 1 || (_selectionN in [2,3] && _allowOnArm) || (_selectionN == 0 && _allowOnHead)) && [_target] call EFUNC(circulation,hasAED)) then {
    private _padsStatus = _target getVariable [QEGVAR(circulation,AED_Placement_Pads), false];
    private _pulseOximeterStatus = (_target getVariable [QEGVAR(circulation,AED_Placement_PulseOximeter), -1] != -1);

    private _entry = "AED ";

    private _displayedHR = _target getVariable [QEGVAR(circulation,AED_Pads_Display), 0];

    if (_displayedHR < 1) then {
        _displayedHR = "--"; // 表示される心拍数が1未満の場合
    };

    if (_padsStatus) then {
        _entry = _entry + (format ["[HR: %1", _displayedHR]); // パッドが装着されている場合
    } else {
        _entry = _entry + (format ["[PR: %1", _displayedHR]); // パッドが装着されていない場合
    };

    if (_pulseOximeterStatus) then {
        private _displayedSPO2 = _target getVariable [QEGVAR(circulation,AED_PulseOximeter_Display), 0];

        if (_displayedSPO2 < 1) then {
            _displayedSPO2 = "--"; // 表示されるSpO2が1未満の場合
        };

        _entry = _entry + (format [" SpO2: %1", _displayedSPO2]); // SpO2の状態をエントリに追加
    } else {
        _entry = _entry + " SpO2: --"; // SpO2が表示されない場合
    };

    private _measuredBP = _target getVariable [QEGVAR(circulation,AED_NIBP_Display), [0,0]];

    private _displayedBP = _measuredBP;

    if ((_measuredBP select 1) < 1) then {
        _displayedBP = ["--","--"]; // 表示される血圧が1未満の場合
    };

    _entry = _entry + (format [" BP: %1/%2", (_displayedBP select 0), (_displayedBP select 1)]); // 血圧の状態をエントリに追加

    private _measuredEtCO2 = _target getVariable [QEGVAR(circulation,AED_CO2_Display), 0];
    private _measuredRR = _target getVariable [QEGVAR(circulation,AED_RR_Display), 0];

    if (_measuredEtCO2 > 0 && _measuredRR > 0) then {
        _entry = _entry + format [" RR: %1 CO2: %2", _measuredRR, _measuredEtCO2]; // 呼吸数とCO2の状態をエントリに追加
    } else {
        _entry = _entry + " RR: -- CO2: --"; // 呼吸数とCO2が表示されない場合
    };

    _entries pushBack [format ["%1]",_entry], [0.18, 0.6, 0.96, 1]]; // AEDの状態をエントリに追加
};

// パルスオキシメーター
if (_selectionN in [2,3] && {HAS_PULSEOX(_target,(_selectionN - 2))}) then {
    private _pr = (_target getVariable [QEGVAR(breathing,PulseOximeter_Display), [[0,0],[0,0]]] select (_selectionN - 2)) select 1;
    private _spO2 = (_target getVariable [QEGVAR(breathing,PulseOximeter_Display), [[0,0],[0,0]]] select (_selectionN - 2)) select 0; 
    
    if (_spO2 < 1 || _pr < 1) then {
        _pr = "--"; // 表示される脈拍数が1未満の場合
        _spO2 = "--"; // 表示されるSpO2が1未満の場合
    };

    _entries pushBack [format ["Pulse Oximeter [PR: %1 SpO2: %2]", _pr, _spO2], _breathingColor]; // パルスオキシメーターの状態をエントリに追加
};

// ダメージを受けたツールチップ
if (ACEGVAR(medical_gui,showDamageEntry)) then {
    private _bodyPartDamage = (_target getVariable [QACEGVAR(medical,bodyPartDamage), [0, 0, 0, 0, 0, 0]]) select _selectionN;
    if (_bodyPartDamage > 0) then {
        private _damageThreshold = GET_DAMAGE_THRESHOLD(_target);
        switch (true) do {
            case (_selectionN > 3): { // 脚: インデックス 4 & 5
                _damageThreshold = LIMPING_DAMAGE_THRESHOLD_DEFAULT * 4;
            };
            case (_selectionN > 1): { // 腕: インデックス 2 & 3
                _damageThreshold = FRACTURE_DAMAGE_THRESHOLD_DEFAULT * 4;
            };
            case (_selectionN == 0): { // 頭: インデックス 0
                _damageThreshold = _damageThreshold * 1.25;
            };
            default { // 胴体: インデックス 1
                _damageThreshold = _damageThreshold * 1.5;
            };
        };
        _bodyPartDamage = (_bodyPartDamage / _damageThreshold) min 1;
        switch (true) do {
            case (_bodyPartDamage isEqualTo 1): {
                _entries pushBack [localize ACELSTRING(medical_gui,traumaSustained4), [_bodyPartDamage] call ACEFUNC(medical_gui,damageToRGBA)];
            };
            case (_bodyPartDamage >= 0.75): {
                _entries pushBack [localize ACELSTRING(medical_gui,traumaSustained3), [_bodyPartDamage] call ACEFUNC(medical_gui,damageToRGBA)];
            };
            case (_bodyPartDamage >= 0.5): {
                _entries pushBack [localize ACELSTRING(medical_gui,traumaSustained2), [_bodyPartDamage] call ACEFUNC(medical_gui,damageToRGBA)];
            };
            case (_bodyPartDamage >= 0.25): {
                _entries pushBack [localize ACELSTRING(medical_gui,traumaSustained1), [_bodyPartDamage] call ACEFUNC(medical_gui,damageToRGBA)];
            };
        };
    };
};

// 胸部シール
if (_selectionN == 1 && (_target getVariable [QEGVAR(breathing,ChestSeal_State), false])) then {
    _entries pushBack ["Chest Seal Applied", [1, 0.95, 0, 1]]; // 胸部シールが適用されている場合
};

// 独立した圧力カフ
if (_selectionN in [2,3] && {HAS_PRESSURECUFF(_target,(_selectionN - 2))}) then {
    _entries pushBack ["Pressure Cuff", _circulationColor]; // 圧力カフが適用されている場合
};

// 止血帯が適用されているかどうかを示す
if (HAS_TOURNIQUET_APPLIED_ON(_target,_selectionN)) then {
    _entries pushBack [format ["%1 [%2]",localize ACELSTRING(medical_gui,Status_Tourniquet_Applied), ((_target getVariable [QEGVAR(disability,Tourniquet_Time), [0,0,0,0,0,0]]) select _selectionN)], [0.77, 0.51, 0.08, 1]]; // 止血帯が適用されている場合
};

// 現在の体の部位の骨折状態を示す
switch (GET_FRACTURES(_target) select _selectionN) do {
    case 1: {
        _entries pushBack [localize ACELSTRING(medical_gui,Status_Fractured), [1, 0, 0, 1]]; // 骨折している場合
    };
    case -1: {
        if (ACEGVAR(medical,fractures) in [2, 3]) then { // スプリントが効果を持たない場合は無視
            private _splintStatus = GET_SPLINTS(_target) select _selectionN;
            if (_splintStatus > 0) then {
                if (_splintStatus == 1) then {
                    _entries pushBack ["SAM Splint Applied", [0.2, 0.2, 1, 1]]; // SAMスプリントが適用されている場合
                } else {
                    _entries pushBack ["SAM Splint Applied (Wrapped)", [0.2, 0.2, 1, 1]]; // 包帯で巻かれたSAMスプリントが適用されている場合
                };
            } else {
                _entries pushBack [localize ACELSTRING(medical_gui,Status_SplintApplied), [0.2, 0.2, 1, 1]]; // スプリントが適用されている場合
            };
        };
    };
};

// 内出血の指標
private _selectionN_InternalBleeding = [_target, _selectionN] call EFUNC(damage,getBodyPartInternalBleeding);
if (_selectionN_InternalBleeding > 0.15) then {
    private _colorAdjustment = linearConversion [0.15, 0.5, _selectionN_InternalBleeding, 0.75, 0.45, true];
    _entries pushBack ["Extensive Bruising", [_colorAdjustment, 0.1, 0.6, 1]]; // 広範な打撲
} else {
    private _HTXFluid = _target getVariable [QEGVAR(breathing,Hemothorax_Fluid), 0];
    if (_selectionN == 1 && _HTXFluid > 0.5) then {
        private _colorAdjustment = linearConversion [0.5, 1.5, _HTXFluid, 0.75, 0.45, true];
        _entries pushBack ["Extensive Bruising (Upper Chest)", [_colorAdjustment, 0.1, 0.6, 1]]; // 広範な打撲（上胸部）
    };
};

// 胸腔切開の状態
if (_selectionN == 1) then {
    switch (_target getVariable [QEGVAR(breathing,Thoracostomy_State), -1]) do {
        case 0: {_entries pushBack ["Thoracostomy Incision (Sealed)", _airwayColor];}; // 胸腔切開（封鎖）
        case 1: {_entries pushBack ["Thoracostomy Incision (Open)", _airwayColor];}; // 胸腔切開（開放）
        case 2: {_entries pushBack ["Thoracostomy Incision (Chest Tube)", _airwayColor];}; // 胸腔切開（胸管）
        default { };
    };
};

[QACEGVAR(medical_gui,updateInjuryListPart), [_ctrl, _target, _selectionN, _entries, _bodyPartName]] call CBA_fnc_localEvent;

// 開いた傷、包帯を巻いた傷、縫合された傷のエントリを追加
private _woundEntries = [];

private _fnc_processWounds = {
    params ["_wounds", "_format", "_color"];

    {
        _x params ["_woundClassID", "_amountOf"];

        if (_amountOf > 0) then {
            private _classIndex = _woundClassID / 10;
            private _category   = _woundClassID % 10;

            private _className = ACEGVAR(medical_damage,woundClassNames) select _classIndex;
            private _suffix = ["Minor", "Medium", "Large"] select _category;
            private _woundName = localize format [ACELSTRING(medical_damage,%1_%2), _className, _suffix];

            private _woundDescription = if (_amountOf >= 1) then {
                format ["%1x %2", ceil _amountOf, _woundName]
            } else {
                format [localize ACELSTRING(medical_gui,PartialX), _woundName]
            };

            _woundEntries pushBack [format [_format, _woundDescription], _color];
        };
    } forEach (_wounds getOrDefault [ALL_BODY_PARTS select _selectionN, []]);
};

[GET_OPEN_WOUNDS(_target), "%1", [1, 1, 1, 1]] call _fnc_processWounds;
[GET_BANDAGED_WOUNDS(_target), "[B] %1", [0.88, 0.7, 0.65, 1]] call _fnc_processWounds;
[GET_STITCHED_WOUNDS(_target), "[S] %1", [0.7, 0.7, 0.7, 1]] call _fnc_processWounds;
[GET_CLOTTED_WOUNDS(_target), "[C] %1", [1, 0.5, 0.1, 1]] call _fnc_processWounds;
[GET_WRAPPED_WOUNDS(_target), "[W] %1", [0.7, 0.5, 0.1, 1]] call _fnc_processWounds; // 包帯で巻かれた傷を処理

[QACEGVAR(medical_gui,updateInjuryListWounds), [_ctrl, _target, _selectionN, _woundEntries, _bodyPartName]] call CBA_fnc_localEvent; // 傷リストを更新

// 傷のエントリがない場合の処理
if (_woundEntries isEqualTo []) then {
    _entries pushBack [localize ACELSTRING(medical_treatment,NoInjuriesBodypart), _nonissueColor]; // 傷がない場合のエントリを追加
} else {
    _entries append _woundEntries; // 傷のエントリを追加
};

// すべてのエントリを傷リストに追加
lbClear _ctrl;

{
    _x params ["_text", "_color"];

    _ctrl lbSetColor [_ctrl lbAdd _text, _color]; // エントリの色を設定
} forEach _entries;

_ctrl lbSetCurSel -1; // 選択をクリア
