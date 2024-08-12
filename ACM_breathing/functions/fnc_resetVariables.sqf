#include "..\script_component.hpp"
/*
 * 作成者: Blue
 * 呼吸変数をデフォルト値にリセット (ローカル)
 *
 * 引数:
 * 0: 患者 <OBJECT>
 *
 * 戻り値:
 * なし
 *
 * 例:
 * [player] call ACM_breathing_fnc_resetVariables;
 *
 * 公開: いいえ
 */

params ["_patient"];

// 胸部外傷の状態をリセット
_patient setVariable [QGVAR(ChestInjury_State), false, true];

// 気胸の状態をリセット
_patient setVariable [QGVAR(Pneumothorax_State), 0, true];
_patient setVariable [QGVAR(TensionPneumothorax_State), false, true];

// 血胸の状態をリセット
_patient setVariable [QGVAR(Hemothorax_State), 0, true];
_patient setVariable [QGVAR(Hemothorax_Fluid), 0, true];

// 胸部シールの状態をリセット
_patient setVariable [QGVAR(ChestSeal_State), false, true];

// 胸腔穿刺の状態をリセット
_patient setVariable [QGVAR(Thoracostomy_State), nil, true];

// パルスオキシメータの表示と配置をリセット
_patient setVariable [QGVAR(PulseOximeter_Display), [[0,0],[0,0]], true]; 
_patient setVariable [QGVAR(PulseOximeter_Placement), [false,false], true];
_patient setVariable [QGVAR(PulseOximeter_PFH), -1];
_patient setVariable [QGVAR(PulseOximeter_LastSync), [-1,-1]];

// ハードコア気胸の状態をリセット
_patient setVariable [QGVAR(Hardcore_Pneumothorax), false, true];

// 呼吸状態を更新
[_patient, true] call FUNC(updateBreathingState);

// BVM（バッグバルブマスク）の状態をリセット
_patient setVariable [QGVAR(BVM_provider), objNull, true];
_patient setVariable [QGVAR(BVM_Medic), objNull, true];
_patient setVariable [QGVAR(isUsingBVM), false, true];

// BVMに接続された酸素の状態をリセット
_patient setVariable [QGVAR(BVM_ConnectedOxygen), false, true];

// 最後の呼吸の時間をリセット
_patient setVariable [QGVAR(BVM_lastBreath), -1, true];

// 呼吸数をデフォルト値に設定
_patient setVariable [QGVAR(RespirationRate), (ACM_TARGETVITALS_RR(_patient)), true];
