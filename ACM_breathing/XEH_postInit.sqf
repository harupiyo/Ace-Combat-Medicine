#include "script_component.hpp"

[QGVAR(handleChestInjury), LINKFUNC(handleChestInjury)] call CBA_fnc_addEventHandler;

[QGVAR(inspectChestLocal), LINKFUNC(inspectChestLocal)] call CBA_fnc_addEventHandler;
[QGVAR(checkBreathingLocal), LINKFUNC(checkBreathingLocal)] call CBA_fnc_addEventHandler;

[QGVAR(applyChestSealLocal), LINKFUNC(applyChestSealLocal)] call CBA_fnc_addEventHandler;
[QGVAR(performNCDLocal), LINKFUNC(performNCDLocal)] call CBA_fnc_addEventHandler;

[QGVAR(Thoracostomy_startLocal), LINKFUNC(Thoracostomy_startLocal)] call CBA_fnc_addEventHandler;
[QGVAR(Thoracostomy_closeLocal), LINKFUNC(Thoracostomy_closeLocal)] call CBA_fnc_addEventHandler;
[QGVAR(Thoracostomy_insertChestTubeLocal), LINKFUNC(Thoracostomy_insertChestTubeLocal)] call CBA_fnc_addEventHandler;
[QGVAR(Thoracostomy_drainLocal), LINKFUNC(Thoracostomy_drainLocal)] call CBA_fnc_addEventHandler;

[QGVAR(setPulseOximeterLocal), LINKFUNC(setPulseOximeterLocal)] call CBA_fnc_addEventHandler;

["isNotUsingBVM", {!((_this select 0) getVariable [QGVAR(isUsingBVM), false])}] call ACEFUNC(common,addCanInteractWithCondition);

// このコードは、気胸の状態に基づいてDuty Factorを計算し、追加するためのものです。
// 気胸の状態が悪化している場合や特定の条件が満たされている場合に、Duty Factorが異なる値に設定されます。

// 気胸の機能が有効になっているかどうかを確認
if (GVAR(pneumothoraxEnabled)) then {
    // 気胸のDuty Factorを追加
    // `ACEFUNC(advanced_fatigue,addDutyFactor)`関数を呼び出して、計算されたDuty Factorを追加します。
    // Duty Factor（デューティファクタ）とは、ある負荷がオンになっている時間の割合を示すものです。
    [QGVAR(Pneumothorax), {
        // 気胸の状態に基づいてDuty Factorを計算
        // select の条件が`true`の場合、`2`を選択し、そうでない場合は`linearConversion`の結果を選択します。
        ([
            // Pneumothorax_State は0-4の範囲、それを1-2 の範囲にマッピングする
            (linearConversion [0, 4, (_this getVariable [QGVAR(Pneumothorax_State), 0]), 1, 2, true]),
            // もしくは 2
            2
         ]
            select (
                // 緊張性気胸の状態ではない
                (_this getVariable [QGVAR(TensionPneumothorax_State), false])
                // ハードコア気胸モードではない
                || (_this getVariable [QGVAR(Hardcore_Pneumothorax), false])
                // 血胸の血の流量が1より多い
                || ((_this getVariable [QGVAR(Hemothorax_Fluid), 0]) > 1)
            )
        );
    }] call ACEFUNC(advanced_fatigue,addDutyFactor);
}

