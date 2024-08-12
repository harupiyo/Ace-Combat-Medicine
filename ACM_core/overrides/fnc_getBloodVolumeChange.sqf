#include "..\script_component.hpp"
/*
 * 作成者: Glowbal
 * 血液量の変化を計算し、ユニットに与えられたIV（点滴）を減少させます。
 *
 * 引数:
 * 0: ユニット <OBJECT>
 * 1: 最後の更新からの時間 <NUMBER>
 * 2: グローバル同期値（液体バッグ） <BOOL>
 *
 * 戻り値:
 * 血液量 <NUMBER>
 *
 * 例:
 * [player, 1, true] call ace_medical_status_fnc_getBloodVolumeChange
 *
 * 公開: いいえ
 */

params ["_unit", "_deltaT", "_syncValues"];

// 血液量、血漿量、生理食塩水量を取得
private _bloodVolume = _unit getVariable [QEGVAR(circulation,Blood_Volume), 6];
private _plasmaVolume = _unit getVariable [QEGVAR(circulation,Plasma_Volume), 0];
private _salineVolume = _unit getVariable [QEGVAR(circulation,Saline_Volume), 0];

// 血小板数とその変化量を取得
private _plateletCount = _unit getVariable [QEGVAR(circulation,Platelet_Count), 3];
private _plateletCountChange = 0;

// 血液量、血漿量、生理食塩水量の変化量を初期化
private _bloodVolumeChange = 0;
private _plasmaVolumeChange = 0;
private _salineVolumeChange = 0;

// アクティブなボリュームの数を初期化
private _activeVolumes = 0;

// 出血量と内部出血量を計算
private _bloodLoss = -_deltaT * GET_BLOOD_LOSS(_unit);
private _internalBleeding = -_deltaT * GET_INTERNAL_BLEEDRATE(_unit);

// TXA（トラネキサム酸）の効果を取得
private _TXAEffect = ([_unit, "TXA_IV", false] call ACEFUNC(medical_status,getMedicationCount));

// 内部出血の重症度を初期化
private _internalBleedingSeverity = 0;

// 内部出血が0.3を超える場合、または血小板数とTXAの効果が低い場合の処理
if (GET_INTERNAL_BLEEDING(_unit) > 0.3 || (_plateletCount < 0.1 && _TXAEffect < 0.1)) then {
    _internalBleedingSeverity = 1;
};

// 血胸の状態と出血量を取得
private _HTXState = _unit getVariable [QEGVAR(breathing,Hemothorax_State), 0];
private _hemothoraxBleeding = 0;

// 血胸の状態がある場合の処理
if (_HTXState > 0) then {
    _hemothoraxBleeding = -_deltaT * GET_HEMOTHORAX_BLEEDRATE(_unit);
    private _thoraxBlood = _unit getVariable [QEGVAR(breathing,Hemothorax_Fluid), 0];
    _thoraxBlood = _thoraxBlood - _hemothoraxBleeding;
    _unit setVariable [QEGVAR(breathing,Hemothorax_Fluid), (_thoraxBlood min 1.5), _syncValues];
};

// アクティブなボリュームの数を更新
if (_bloodVolume > 0) then {
    _activeVolumes = _activeVolumes + 1;
};

if (_plasmaVolume > 0) then {
    _activeVolumes = _activeVolumes + 1;
};

if (_salineVolume > 0) then {
    _activeVolumes = _activeVolumes + 1;
};

// 血液量、血漿量、生理食塩水量の変化量を計算
if (_bloodVolume > 0) then {
    _bloodVolumeChange = (_bloodLoss + _internalBleeding * _internalBleedingSeverity + _hemothoraxBleeding) / _activeVolumes;
};

if (_plasmaVolume > 0) then {
    _plasmaVolumeChange = (_bloodLoss + _internalBleeding * _internalBleedingSeverity + _hemothoraxBleeding) / _activeVolumes;
};

if (_salineVolume > 0) then {
    _salineVolumeChange = (_bloodLoss + _internalBleeding * _internalBleedingSeverity + _hemothoraxBleeding) / _activeVolumes;
};

// 血小板数が0.1を超える場合の処理
if (_plateletCount > 0.1) then {
    _plateletCountChange = (_internalBleeding * 0.5) + (_bloodLoss * 0.5) + (_hemothoraxBleeding * 0.5);
    if (_TXAEffect > 0.1) then {
        _plateletCountChange = _plateletCountChange / 2;
    };
};

// 輸血による痛みを初期化
private _transfusionPain = 0;

// IVバッグが存在する場合の処理
if (!isNil {_unit getVariable QACEGVAR(medical,ivBags)}) then {
    // 流量倍率を初期化
    private _flowMultiplier = 1;

    // アクティブなバッグタイプを取得
    private _activeBagTypes = _unit getVariable [QEGVAR(circulation,ActiveFluidBags), [1,1,1,1,1,1]];

    // 心停止状態の場合の処理
    if (IN_CRDC_ARRST(_unit)) then {
        _flowMultiplier = EGVAR(circulation,cardiacArrestBleedRate);
        if (alive (_unit getVariable [QACEGVAR(medical,CPR_provider), objNull])) then {
            _flowMultiplier = 0.9;
        };
    };

    // IVバッグと止血帯を取得
    private _fluidBags = _unit getVariable [QACEGVAR(medical,ivBags), []];
    private _tourniquets = GET_TOURNIQUETS(_unit);

    // バッグの数が変更されたかどうかを初期化
    private _bagCountChanged = false;

    // IVバッグの処理
    _fluidBags = _fluidBags apply {
        _x params ["_bodyPart", "_type", "_bagVolumeRemaining", ["_bloodType", -1], ["_accessType", 1]];

        // 止血帯が適用されていない部位の場合の処理
        if (_tourniquets select _bodyPart == 0) then {
            // 流量倍率を初期化
            private _fluidFlowRate = 1;

            // バッグのタイプに応じて流量倍率を設定
            switch (_type) do {
                case "Blood": {
                    _fluidFlowRate = 0.8;
                };
                case "Saline": {
                    _fluidFlowRate = 1.2;
                };
                default {};
            };

            // アクティブなバッグタイプの部位を取得
            private _activeBagTypesBodyPart = _activeBagTypes select _bodyPart;

            // バッグの変化量を計算
            private _bagChange = ((_deltaT * ACEGVAR(medical,ivFlowRate) * ([_unit, _bodypart] call EFUNC(circulation,getIVFlowRate))) * _flowMultiplier * _fluidFlowRate) min _bagVolumeRemaining; // ミリリットル単位の絶対値
            
            // バッグの残量が1未満でない場合の処理
            if !(_bagVolumeRemaining < 1) then {
                _bagChange = _bagChange / _activeBagTypesBodyPart;
            };

            // バッグの残量を更新
            _bagVolumeRemaining = _bagVolumeRemaining - _bagChange;

            // バッグのタイプに応じてボリュームの変化量を更新
            switch (_type) do {
                case "Plasma": {
                    _plasmaVolumeChange = _plasmaVolumeChange + (_bagChange / 1000);
                    _plateletCountChange = _plateletCountChange + (_bagChange / 1000);
                };
                case "Saline": {
                    _salineVolumeChange = _salineVolumeChange + (_bagChange / 1000);
                };
                default {
                    if ([GET_BLOODTYPE(_unit), _bloodType] call EFUNC(circulation,isBloodTypeCompatible)) then {
                        _bloodVolumeChange = _bloodVolumeChange + (_bagChange / 1000);
                        _plateletCountChange = _plateletCountChange + (_bagChange / 500);
                    } else {
                        _bloodVolumeChange = _bloodVolumeChange - (_bagChange / 1000);
                        _plateletCountChange = _plateletCountChange - (_bagChange / 4000);

                        _plasmaVolumeChange = _plasmaVolumeChange + (_bagChange / 4000);
                        _salineVolumeChange = _salineVolumeChange + (_bagChange / 1333.4);
                    };
                };
            };
            // IO（骨髄内輸液）の痛みを計算
            if (_accessType in [ACM_IO_FAST1_M, ACM_IO_EZ_M]) then {
                private _IOPain = _bagChange / 3.7;
                _transfusionPain = _transfusionPain + _IOPain;
            };
        };

        // バッグの残量が0.01未満の場合の処理
        if (_bagVolumeRemaining < 0.01) then {
            _bagCountChanged = true;
            []
        } else {
            [_bodyPart, _type, _bagVolumeRemaining, _bloodType, _accessType]
        };
    };

    _fluidBags = _fluidBags - [[]]; // 空のバッグを削除

    if (_fluidBags isEqualTo []) then {
        _unit setVariable [QACEGVAR(medical,ivBags), nil, true]; // バッグが残っていない - 変数をクリア（常にグローバルに同期）
        _bagCountChanged = true; // バッグの数が変更された
    } else {
        _unit setVariable [QACEGVAR(medical,ivBags), _fluidBags, _syncValues]; // バッグの数を更新
    };

    if (_bagCountChanged) then {
        [_unit] call EFUNC(circulation,updateActiveFluidBags); // アクティブな流体バッグを更新
    };
};

if (_transfusionPain > 0) then {
    [_unit, (_transfusionPain min 0.8)] call ACEFUNC(medical_status,adjustPainLevel); // 輸血による痛みがある場合、痛みレベルを調整
};

if (_bloodVolume < 6) then { // 血液量が6未満の場合
    if (_plasmaVolume + _plasmaVolumeChange > 0) then { // 血漿量が正の場合
        private _leftToConvert = _plasmaVolume + _plasmaVolumeChange; // 変換する残りの血漿量
        private _conversionRate = (-_deltaT * (2 / 1000)) min _leftToConvert; // 変換率を計算
    
        _plasmaVolumeChange = _plasmaVolumeChange + _conversionRate; // 血漿量の変化を更新
        _bloodVolumeChange = _bloodVolumeChange - _conversionRate; // 血液量の変化を更新
    };
    
    if (_salineVolume + _salineVolumeChange > 0) then { // 生理食塩水の量が正の場合
        private _leftToConvert = _salineVolume + _salineVolumeChange; // 変換する残りの生理食塩水の量
        private _conversionRate = (-_deltaT * (0.5 / 1000)) min _leftToConvert; // 変換率を計算
        
        _salineVolumeChange = _salineVolumeChange + _conversionRate; // 生理食塩水の変化を更新
        _bloodVolumeChange = _bloodVolumeChange - _conversionRate; // 血液量の変化を更新
    };
};

_bloodVolume = 0 max _bloodVolume + _bloodVolumeChange min DEFAULT_BLOOD_VOLUME; // 血液量を更新
_plasmaVolume = 0 max _plasmaVolume + _plasmaVolumeChange min DEFAULT_BLOOD_VOLUME; // 血漿量を更新
_salineVolume = 0 max _salineVolume + _salineVolumeChange min DEFAULT_BLOOD_VOLUME; // 生理食塩水の量を更新

if (_plateletCount != 3) then { // 血小板数が3でない場合
    private _adjustSpeed = 1000 * linearConversion [3, 6, _bloodVolume, 10, 1, true]; // 調整速度を計算
    if (_TXAEffect > 0.1) then { // TXA効果が0.1を超える場合
        _adjustSpeed / 2; // 調整速度を半分にする
    };
    if ( !(IS_BLEEDING(_unit)) && !(IS_I_BLEEDING(_unit)) && _HTXState < 1 && _plateletCount > 3) then { // 出血していない場合
        _adjustSpeed = 100; // 調整速度を100に設定
    };
    _plateletCountChange = _plateletCountChange + ((3 - _plateletCount) / _adjustSpeed); // 血小板数の変化を更新
};

_plateletCount = 0 max (_plateletCount + _plateletCountChange) min DEFAULT_BLOOD_VOLUME; // 血小板数を更新

private _fluidOverload = 0 max ((_bloodVolume + _plasmaVolume + _salineVolume) - 6); // 体液過剰を計算

_unit setVariable [QEGVAR(circulation,Blood_Volume), _bloodVolume, _syncValues]; // 血液量を設定
_unit setVariable [QEGVAR(circulation,Plasma_Volume), _plasmaVolume, _syncValues]; // 血漿量を設定
_unit setVariable [QEGVAR(circulation,Saline_Volume), _salineVolume, _syncValues]; // 生理食塩水の量を設定

_unit setVariable [QEGVAR(circulation,Platelet_Count), _plateletCount, _syncValues]; // 血小板数を設定

_bloodVolume + _plasmaVolume + _salineVolume min DEFAULT_BLOOD_VOLUME; // 総体液量を計算
