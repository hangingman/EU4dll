module plugin.input;

// DllErrorの定義
public struct DllError
{
    // input.d
    bool unmatchdInputProc1Injector;
    bool versionInputProc1Injector;
    bool unmatchdInputProc2Injector;
    bool versionInputProc2Injector;
    bool unmatchdInputProc3Injector;
    bool versionInputProc3Injector;
    bool unmatchdInputProc4Injector;
    bool versionInputProc4Injector;
    bool unmatchdInputProc5Injector;
    bool versionInputProc5Injector;
    bool unmatchdInputProc6Injector;
    bool versionInputProc6Injector;
    bool unmatchdInputProc7Injector;
    bool versionInputProc7Injector;
    bool unmatchdInputProc8Injector;
    bool versionInputProc8Injector;
    bool unmatchdInputProc9Injector;
    bool versionInputProc9Injector;
    bool unmatchdInputProc10Injector;
    bool versionInputProc10Injector;
    bool unmatchdInputProc11Injector;
    bool versionInputProc11Injector;
    bool unmatchdInputProc12Injector;
    bool versionInputProc12Injector;

    // event_dialog.d
    bool unmatchdEventDialog1Injector;
    bool versionEventDialog1Injector;
    bool unmatchdEventDialog2Injector;
    bool versionEventDialog2Injector;
    bool unmatchdEventDialog3Injector;
    bool versionEventDialog3Injector;
    bool unmatchdEventDialog4Injector;
    bool versionEventDialog4Injector;
    bool unmatchdEventDialog5Injector;
    bool versionEventDialog5Injector;
    bool unmatchdEventDialog6Injector;
    bool versionEventDialog6Injector;

    // font.d
    bool unmatchdCharCodePointLimiterPatchInjector;
    bool versionCharCodePointLimiterPatchInjector;
    bool unmatchdFontBufferHeapZeroClearInjector;
    bool versionFontBufferHeapZeroClearInjector;
    bool unmatchdFontBufferClear1Injector;
    bool versionFontBufferClear1Injector;
    bool unmatchdFontBufferClear2Injector;
    bool versionFontBufferClear2Injector;
    bool unmatchdFontBufferExpansionInjector;
    bool versionFontBufferExpansionInjector;
    bool unmatchdFontSizeLimitInjector;
    bool versionFontSizeLimitInjector;

    // ime.d
    bool unmatchdImeProc1Injector;
    bool versionImeProc1Injector;
    bool unmatchdImeProc2Injector; // 追加
    bool versionImeProc2Injector; // 追加
    bool unmatchdImeProc3Injector;
    bool versionImeProc3Injector;

    // list_field_adjustment.d
    bool unmatchdListFieldAdjustmentProc1Injector;
    bool versionListFieldAdjustmentProc1Injector;
    bool unmatchdListFieldAdjustmentProc2Injector; // 追加
    bool versionListFieldAdjustmentProc2Injector; // 追加
    bool unmatchdListFieldAdjustmentProc3Injector; // 追加
    bool versionListFieldAdjustmentProc3Injector; // 追加

    // main_text.d
    bool unmatchdMainTextProc1Injector;
    bool versionMainTextProc1Injector;
    bool unmatchdMainTextProc2Injector;
    bool versionMainTextProc2Injector;
    bool unmatchdMainTextProc3Injector;
    bool versionMainTextProc3Injector;
    bool unmatchdMainTextProc4Injector; // 追加
    bool versionMainTextProc4Injector; // 追加

    // map_adjustment.d
    bool unmatchdMapAdjustmentProc1Injector;
    bool versionMapAdjustmentProc1Injector;
    bool unmatchdMapAdjustmentProc2Injector;
    bool versionMapAdjustmentProc2Injector;
    bool unmatchdMapAdjustmentProc3Injector;
    bool versionMapAdjustmentProc3Injector;
    bool unmatchdMapAdjustmentProc4Injector;
    bool versionMapAdjustmentProc4Injector;
    bool unmatchdMapAdjustmentProc5Injector; // 追加
    bool versionMapAdjustmentProc5Injector; // 追加

    // map_justify.d
    bool unmatchdMapJustifyProc1Injector;
    bool versionMapJustifyProc1Injector;
    bool unmatchdMapJustifyProc2Injector; // 追加
    bool versionMapJustifyProc2Injector; // 追加
    bool unmatchdMapJustifyProc4Injector; // 追加
    bool versionMapJustifyProc4Injector; // 追加

    // map_popup.d
    bool unmatchdMapPopupProc1Injector;
    bool versionMapPopupProc1Injector;
    bool unmatchdMapPopupProc2Injector;
    bool versionMapPopupProc2Injector;
    bool unmatchdMapPopupProc3Injector; // 追加
    bool versionMapPopupProc3Injector; // 追加

    // map_view.d
    bool unmatchdMapViewProc1Injector;
    bool versionMapViewProc1Injector;
    bool unmatchdMapViewProc2Injector; // 追加
    bool versionMapViewProc2Injector; // 追加
    bool unmatchdMapViewProc3Injector;
    bool versionMapViewProc3Injector;

    // options.d
    bool unmatchdOptionsProc1Injector;
    bool versionOptionsProc1Injector;

    // plugin_version.d
    bool unmatchdPluginVersionProc1Injector;
    bool versionPluginVersionProc1Injector;

    // localization.d (既存のものだが一応残す)
    bool unmatchdLocalizationProc1Injector;
    bool versionLocalizationProc1Injector;
    bool unmatchdLocalizationProc2Injector;
    bool versionLocalizationProc2Injector;
    bool unmatchdLocalizationProc3Injector;
    bool versionLocalizationProc3Injector;
    bool unmatchdLocalizationProc4Injector;
    bool versionLocalizationProc4Injector;

    // tooltip_and_button.d
    bool unmatchdTooltipAndButtonProc1Injector;
    bool versionTooltipAndButtonProc1Injector;
    bool unmatchdTooltipAndButtonProc2Injector;
    bool versionTooltipAndButtonProc2Injector;
    bool unmatchdTooltipAndButtonProc3Injector;
    bool versionTooltipAndButtonProc3Injector;
    bool unmatchdTooltipAndButtonProc4Injector;
    bool versionTooltipAndButtonProc4Injector;
    bool unmatchdTooltipAndButtonProc5Injector;
    bool versionTooltipAndButtonProc5Injector;
    bool unmatchdTooltipAndButtonProc6Injector;
    bool versionTooltipAndButtonProc6Injector;
    bool unmatchdTooltipAndButtonProc7Injector;
    bool versionTooltipAndButtonProc7Injector;

    // date.d
    bool unmatchdDateProc1Injector;
    bool versionDateProc1Injector;
    bool unmatchdDateProc2Injector;
    bool versionDateProc2Injector;
    bool unmatchdDateProc3Injector;
    bool versionDateProc3Injector;

    // file_save.d (既存のものだが一応残す)
    bool unmatchdFileSaveProc1Injector;
    bool versionFileSaveProc1Injector;
    bool unmatchdFileSaveProc2Injector;
    bool versionFileSaveProc2Injector;
    bool unmatchdFileSaveProc3Injector;
    bool versionFileSaveProc3Injector;
    bool unmatchdFileSaveProc4Injector;
    bool versionFileSaveProc4Injector;
    bool unmatchdFileSaveProc5Injector;
    bool versionFileSaveProc5Injector;
    bool unmatchdFileSaveProc6Injector;
    bool versionFileSaveProc6Injector;
    bool unmatchdFileSaveProc7Injector;
    bool versionFileSaveProc7Injector;


    this(this)
    {
    }

    DllError opBinary(string op)(DllError rhs)
    {
        static assert(op == "|");
        return this | rhs;
    }

    DllError opBinary(string op, D)(inout D rhs)
        if (op == "|=" && is(D : DllError))
    {
        return this | rhs;
    }
}

public import plugin.constant; // RunOptionsを公開
public import plugin.input.entry;
public import plugin.input.common;
public import plugin.input.proc1;
public import plugin.input.proc2;
public import plugin.input.proc3;
public import plugin.input.proc4;
public import plugin.input.proc5;
public import plugin.input.proc6;
public import plugin.input.proc7;
public import plugin.input.proc8;
public import plugin.input.proc9;
public import plugin.input.proc10;
public import plugin.input.proc11;
public import plugin.input.proc12;
