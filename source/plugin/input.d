module plugin.input;

import std.stdio;
import plugin.byte_pattern;
import plugin.constant;
import plugin.misc; // get_branch_destination_offset を使用するためインポート
import plugin.patcher.patcher : ScopedPatch, PatchManager, makeJmp; // ScopedPatch, PatchManager, makeJmpを使用するためにインポート
import plugin.process.process : get_executable_memory_range; // get_executable_memory_range を使用するためにインポート

// FIXME: escape_tool.d を後で作成し、インポートする

// DllErrorに相当する構造体
// 実際のDllErrorはdllmain.dの周辺で定義されているはずだが、
// 現状は最小限の定義とする
struct DllError
{
    bool unmatchdInputProc1Injector;
    bool versionInputProc1Injector;
    bool unmatchdInputProc2Injector;
    bool versionInputProc2Injector;

    bool unmatchdDateProc1Injector;
    bool versionDateProc1Injector;

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

    bool unmatchdImeProc1Injector;
    bool versionImeProc1Injector;
    bool unmatchdImeProc2Injector;
    bool versionImeProc2Injector;

    bool unmatchdMainTextProc1Injector;
    bool versionMainTextProc1Injector;
    bool unmatchdMainTextProc2Injector;
    bool versionMainTextProc2Injector;
    bool unmatchdMainTextProc3Injector;
    bool versionMainTextProc3Injector;
    bool unmatchdMainTextProc4Injector;
    bool versionMainTextProc4Injector;

    bool unmatchdMapAdjustmentProc1Injector;
    bool versionMapAdjustmentProc1Injector;
    bool unmatchdMapAdjustmentProc2Injector;
    bool versionMapAdjustmentProc2Injector;
    bool unmatchdMapAdjustmentProc3Injector;
    bool versionMapAdjustmentProc3Injector;
    bool unmatchdMapAdjustmentProc4Injector;
    bool versionMapAdjustmentProc4Injector;
    bool unmatchdMapAdjustmentProc5Injector;
    bool versionMapAdjustmentProc5Injector;

    bool unmatchdMapJustifyProc1Injector;
    bool versionMapJustifyProc1Injector;
    bool unmatchdMapJustifyProc2Injector;
    bool versionMapJustifyProc2Injector;
    bool unmatchdMapJustifyProc3Injector;
    bool versionMapJustifyProc3Injector;
    bool unmatchdMapJustifyProc4Injector;
    bool versionMapJustifyProc4Injector;

    bool unmatchdMapViewProc1Injector;
    bool versionMapViewProc1Injector;
    bool unmatchdMapViewProc2Injector;
    bool versionMapViewProc2Injector;
    bool unmatchdMapViewProc3Injector;
    bool versionMapViewProc3Injector;

    bool unmatchdMapPopupProc1Injector;
    bool versionMapPopupProc1Injector;
    bool unmatchdMapPopupProc2Injector;
    bool versionMapPopupProc2Injector;
    bool unmatchdMapPopupProc3Injector;
    bool versionMapPopupProc3Injector;

    bool unmatchdLocalizationProc1Injector;
    bool versionLocalizationProc1Injector;
    bool unmatchdLocalizationProc2Injector;
    bool versionLocalizationProc2Injector;
    bool unmatchdLocalizationProc3Injector;
    bool versionLocalizationProc3Injector;
    bool unmatchdLocalizationProc4Injector;
    bool versionLocalizationProc4Injector;

    bool unmatchdListFieldAdjustmentProc1Injector;
    bool versionListFieldAdjustmentProc1Injector;
    bool unmatchdListFieldAdjustmentProc2Injector;
    bool versionListFieldAdjustmentProc2Injector;
    bool unmatchdListFieldAdjustmentProc3Injector;
    bool versionListFieldAdjustmentProc3Injector;

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

    bool unmatchdEventDialog1Injector;
    bool versionEventDialog1Injector;
    bool unmatchdEventDialog2Injector;
    bool versionEventDialog2Injector;
    bool unmatchdEventDialog3Injector;
    bool versionEventDialog3Injector;

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

    bool unmatchdOptionsProc1Injector;
    bool versionOptionsProc1Injector;

    bool unmatchdVersionProc1Injector;
    bool versionVersionProc1Injector;

    // ビットOR演算子をオーバーロードして、複数のエラーを結合できるようにする
    DllError opBinary(string op : "|")(DllError rhs) const
    {
        DllError result;
        result.unmatchdInputProc1Injector = this.unmatchdInputProc1Injector || rhs
            .unmatchdInputProc1Injector;
        result.versionInputProc1Injector = this.versionInputProc1Injector || rhs
            .versionInputProc1Injector;
        result.unmatchdInputProc2Injector = this.unmatchdInputProc2Injector || rhs
            .unmatchdInputProc2Injector;
        result.versionInputProc2Injector = this.versionInputProc2Injector || rhs
            .versionInputProc2Injector;

        result.unmatchdDateProc1Injector = this.unmatchdDateProc1Injector || rhs
            .unmatchdDateProc1Injector;
        result.versionDateProc1Injector = this.versionDateProc1Injector || rhs
            .versionDateProc1Injector;

        result.unmatchdCharCodePointLimiterPatchInjector = this.unmatchdCharCodePointLimiterPatchInjector || rhs
            .unmatchdCharCodePointLimiterPatchInjector;
        result.versionCharCodePointLimiterPatchInjector = this.versionCharCodePointLimiterPatchInjector || rhs
            .versionCharCodePointLimiterPatchInjector;
        result.unmatchdFontBufferHeapZeroClearInjector = this.unmatchdFontBufferHeapZeroClearInjector || rhs
            .unmatchdFontBufferHeapZeroClearInjector;
        result.versionFontBufferHeapZeroClearInjector = this.versionFontBufferHeapZeroClearInjector || rhs
            .versionFontBufferHeapZeroClearInjector;
        result.unmatchdFontBufferClear1Injector = this.unmatchdFontBufferClear1Injector || rhs
            .unmatchdFontBufferClear1Injector;
        result.versionFontBufferClear1Injector = this.versionFontBufferClear1Injector || rhs
            .versionFontBufferClear1Injector;
        result.unmatchdFontBufferClear2Injector = this.unmatchdFontBufferClear2Injector || rhs
            .unmatchdFontBufferClear2Injector;
        result.versionFontBufferClear2Injector = this.versionFontBufferClear2Injector || rhs
            .versionFontBufferClear2Injector;
        result.unmatchdFontBufferExpansionInjector = this.unmatchdFontBufferExpansionInjector || rhs
            .unmatchdFontBufferExpansionInjector;
        result.versionFontBufferExpansionInjector = this.versionFontBufferExpansionInjector || rhs
            .versionFontBufferExpansionInjector;
        result.unmatchdFontSizeLimitInjector = this.unmatchdFontSizeLimitInjector || rhs
            .unmatchdFontSizeLimitInjector;
        result.versionFontSizeLimitInjector = this.versionFontSizeLimitInjector || rhs
            .versionFontSizeLimitInjector;

        result.unmatchdImeProc1Injector = this.unmatchdImeProc1Injector || rhs
            .unmatchdImeProc1Injector;
        result.versionImeProc1Injector = this.versionImeProc1Injector || rhs
            .versionImeProc1Injector;
        result.unmatchdImeProc2Injector = this.unmatchdImeProc2Injector || rhs
            .unmatchdImeProc2Injector;
        result.versionImeProc2Injector = this.versionImeProc2Injector || rhs
            .versionImeProc2Injector;

        result.unmatchdMainTextProc1Injector = this.unmatchdMainTextProc1Injector || rhs
            .unmatchdMainTextProc1Injector;
        result.versionMainTextProc1Injector = this.versionMainTextProc1Injector || rhs
            .versionMainTextProc1Injector;
        result.unmatchdMainTextProc2Injector = this.unmatchdMainTextProc2Injector || rhs
            .unmatchdMainTextProc2Injector;
        result.versionMainTextProc2Injector = this.versionMainTextProc2Injector || rhs
            .versionMainTextProc2Injector;
        result.unmatchdMainTextProc3Injector = this.unmatchdMainTextProc3Injector || rhs
            .unmatchdMainTextProc3Injector;
        result.versionMainTextProc3Injector = this.versionMainTextProc3Injector || rhs
            .versionMainTextProc3Injector;
        result.unmatchdMainTextProc4Injector = this.unmatchdMainTextProc4Injector || rhs
            .unmatchdMainTextProc4Injector;
        result.versionMainTextProc4Injector = this.versionMainTextProc4Injector || rhs
            .versionMainTextProc4Injector;

        result.unmatchdMapAdjustmentProc1Injector = this.unmatchdMapAdjustmentProc1Injector || rhs
            .unmatchdMapAdjustmentProc1Injector;
        result.versionMapAdjustmentProc1Injector = this.versionMapAdjustmentProc1Injector || rhs
            .versionMapAdjustmentProc1Injector;
        result.unmatchdMapAdjustmentProc2Injector = this.unmatchdMapAdjustmentProc2Injector || rhs
            .unmatchdMapAdjustmentProc2Injector;
        result.versionMapAdjustmentProc2Injector = this.versionMapAdjustmentProc2Injector || rhs
            .versionMapAdjustmentProc2Injector;
        result.unmatchdMapAdjustmentProc3Injector = this.unmatchdMapAdjustmentProc3Injector || rhs
            .unmatchdMapAdjustmentProc3Injector;
        result.versionMapAdjustmentProc3Injector = this.versionMapAdjustmentProc3Injector || rhs
            .versionMapAdjustmentProc3Injector;
        result.unmatchdMapAdjustmentProc4Injector = this.unmatchdMapAdjustmentProc4Injector || rhs
            .unmatchdMapAdjustmentProc4Injector;
        result.versionMapAdjustmentProc4Injector = this.versionMapAdjustmentProc4Injector || rhs
            .versionMapAdjustmentProc4Injector;
        result.unmatchdMapAdjustmentProc5Injector = this.unmatchdMapAdjustmentProc5Injector || rhs
            .unmatchdMapAdjustmentProc5Injector;
        result.versionMapAdjustmentProc5Injector = this.versionMapAdjustmentProc5Injector || rhs
            .versionMapAdjustmentProc5Injector;

        result.unmatchdMapJustifyProc1Injector = this.unmatchdMapJustifyProc1Injector || rhs
            .unmatchdMapJustifyProc1Injector;
        result.versionMapJustifyProc1Injector = this.versionMapJustifyProc1Injector || rhs
            .versionMapJustifyProc1Injector;
        result.unmatchdMapJustifyProc2Injector = this.unmatchdMapJustifyProc2Injector || rhs
            .unmatchdMapJustifyProc2Injector;
        result.versionMapJustifyProc2Injector = this.versionMapJustifyProc2Injector || rhs
            .versionMapJustifyProc2Injector;
        result.unmatchdMapJustifyProc3Injector = this.unmatchdMapJustifyProc3Injector || rhs
            .unmatchdMapJustifyProc3Injector;
        result.versionMapJustifyProc3Injector = this.versionMapJustifyProc3Injector || rhs
            .versionMapJustifyProc3Injector;
        result.unmatchdMapJustifyProc4Injector = this.unmatchdMapJustifyProc4Injector || rhs
            .unmatchdMapJustifyProc4Injector;
        result.versionMapJustifyProc4Injector = this.versionMapJustifyProc4Injector || rhs
            .versionMapJustifyProc4Injector;

        result.unmatchdMapViewProc1Injector = this.unmatchdMapViewProc1Injector || rhs
            .unmatchdMapViewProc1Injector;
        result.versionMapViewProc1Injector = this.versionMapViewProc1Injector || rhs
            .versionMapViewProc1Injector;
        result.unmatchdMapViewProc2Injector = this.unmatchdMapViewProc2Injector || rhs
            .unmatchdMapViewProc2Injector;
        result.versionMapViewProc2Injector = this.versionMapViewProc2Injector || rhs
            .versionMapViewProc2Injector;
        result.unmatchdMapViewProc3Injector = this.unmatchdMapViewProc3Injector || rhs
            .unmatchdMapViewProc3Injector;
        result.versionMapViewProc3Injector = this.versionMapViewProc3Injector || rhs
            .versionMapViewProc3Injector;

        result.unmatchdMapPopupProc1Injector = this.unmatchdMapPopupProc1Injector || rhs
            .unmatchdMapPopupProc1Injector;
        result.versionMapPopupProc1Injector = this.versionMapPopupProc1Injector || rhs
            .versionMapPopupProc1Injector;
        result.unmatchdMapPopupProc2Injector = this.unmatchdMapPopupProc2Injector || rhs
            .unmatchdMapPopupProc2Injector;
        result.versionMapPopupProc2Injector = this.versionMapPopupProc2Injector || rhs
            .versionMapPopupProc2Injector;
        result.unmatchdMapPopupProc3Injector = this.unmatchdMapPopupProc3Injector || rhs
            .unmatchdMapPopupProc3Injector;
        result.versionMapPopupProc3Injector = this.versionMapPopupProc3Injector || rhs
            .versionMapPopupProc3Injector;

        result.unmatchdLocalizationProc1Injector = this.unmatchdLocalizationProc1Injector || rhs
            .unmatchdLocalizationProc1Injector;
        result.versionLocalizationProc1Injector = this.versionLocalizationProc1Injector || rhs
            .versionLocalizationProc1Injector;
        result.unmatchdLocalizationProc2Injector = this.unmatchdLocalizationProc2Injector || rhs
            .unmatchdLocalizationProc2Injector;
        result.versionLocalizationProc2Injector = this.versionLocalizationProc2Injector || rhs
            .versionLocalizationProc2Injector;
        result.unmatchdLocalizationProc3Injector = this.unmatchdLocalizationProc3Injector || rhs
            .unmatchdLocalizationProc3Injector;
        result.versionLocalizationProc3Injector = this.versionLocalizationProc3Injector || rhs
            .versionLocalizationProc3Injector;
        result.unmatchdLocalizationProc4Injector = this.unmatchdLocalizationProc4Injector || rhs
            .unmatchdLocalizationProc4Injector;
        result.versionLocalizationProc4Injector = this.versionLocalizationProc4Injector || rhs
            .versionLocalizationProc4Injector;

        result.unmatchdListFieldAdjustmentProc1Injector = this.unmatchdListFieldAdjustmentProc1Injector || rhs
            .unmatchdListFieldAdjustmentProc1Injector;
        result.versionListFieldAdjustmentProc1Injector = this.versionListFieldAdjustmentProc1Injector || rhs
            .versionListFieldAdjustmentProc1Injector;
        result.unmatchdListFieldAdjustmentProc2Injector = this.unmatchdListFieldAdjustmentProc2Injector || rhs
            .unmatchdListFieldAdjustmentProc2Injector;
        result.versionListFieldAdjustmentProc2Injector = this.versionListFieldAdjustmentProc2Injector || rhs
            .versionListFieldAdjustmentProc2Injector;
        result.unmatchdListFieldAdjustmentProc3Injector = this.unmatchdListFieldAdjustmentProc3Injector || rhs
            .unmatchdListFieldAdjustmentProc3Injector;
        result.versionListFieldAdjustmentProc3Injector = this.versionListFieldAdjustmentProc3Injector || rhs
            .versionListFieldAdjustmentProc3Injector;

        result.unmatchdTooltipAndButtonProc1Injector = this.unmatchdTooltipAndButtonProc1Injector || rhs
            .unmatchdTooltipAndButtonProc1Injector;
        result.versionTooltipAndButtonProc1Injector = this.versionTooltipAndButtonProc1Injector || rhs
            .versionTooltipAndButtonProc1Injector;
        result.unmatchdTooltipAndButtonProc2Injector = this.unmatchdTooltipAndButtonProc2Injector || rhs
            .unmatchdTooltipAndButtonProc2Injector;
        result.versionTooltipAndButtonProc2Injector = this.versionTooltipAndButtonProc2Injector || rhs
            .versionTooltipAndButtonProc2Injector;
        result.unmatchdTooltipAndButtonProc3Injector = this.unmatchdTooltipAndButtonProc3Injector || rhs
            .unmatchdTooltipAndButtonProc3Injector;
        result.versionTooltipAndButtonProc3Injector = this.versionTooltipAndButtonProc3Injector || rhs
            .versionTooltipAndButtonProc3Injector;
        result.unmatchdTooltipAndButtonProc4Injector = this.unmatchdTooltipAndButtonProc4Injector || rhs
            .unmatchdTooltipAndButtonProc4Injector;
        result.versionTooltipAndButtonProc4Injector = this.versionTooltipAndButtonProc4Injector || rhs
            .versionTooltipAndButtonProc4Injector;
        result.unmatchdTooltipAndButtonProc5Injector = this.unmatchdTooltipAndButtonProc5Injector || rhs
            .unmatchdTooltipAndButtonProc5Injector;
        result.versionTooltipAndButtonProc5Injector = this.versionTooltipAndButtonProc5Injector || rhs
            .versionTooltipAndButtonProc5Injector;
        result.unmatchdTooltipAndButtonProc6Injector = this.unmatchdTooltipAndButtonProc6Injector || rhs
            .unmatchdTooltipAndButtonProc6Injector;
        result.versionTooltipAndButtonProc6Injector = this.versionTooltipAndButtonProc6Injector || rhs
            .versionTooltipAndButtonProc6Injector;
        result.unmatchdTooltipAndButtonProc7Injector = this.unmatchdTooltipAndButtonProc7Injector || rhs
            .unmatchdTooltipAndButtonProc7Injector;
        result.versionTooltipAndButtonProc7Injector = this.versionTooltipAndButtonProc7Injector || rhs
            .versionTooltipAndButtonProc7Injector;

        result.unmatchdEventDialog1Injector = this.unmatchdEventDialog1Injector || rhs
            .unmatchdEventDialog1Injector;
        result.versionEventDialog1Injector = this.versionEventDialog1Injector || rhs
            .versionEventDialog1Injector;
        result.unmatchdEventDialog2Injector = this.unmatchdEventDialog2Injector || rhs
            .unmatchdEventDialog2Injector;
        result.versionEventDialog2Injector = this.versionEventDialog2Injector || rhs
            .versionEventDialog2Injector;
        result.unmatchdEventDialog3Injector = this.unmatchdEventDialog3Injector || rhs
            .unmatchdEventDialog3Injector;
        result.versionEventDialog3Injector = this.versionEventDialog3Injector || rhs
            .versionEventDialog3Injector;

        result.unmatchdFileSaveProc1Injector = this.unmatchdFileSaveProc1Injector || rhs
            .unmatchdFileSaveProc1Injector;
        result.versionFileSaveProc1Injector = this.versionFileSaveProc1Injector || rhs
            .versionFileSaveProc1Injector;
        result.unmatchdFileSaveProc2Injector = this.unmatchdFileSaveProc2Injector || rhs
            .unmatchdFileSaveProc2Injector;
        result.versionFileSaveProc2Injector = this.versionFileSaveProc2Injector || rhs
            .versionFileSaveProc2Injector;
        result.unmatchdFileSaveProc3Injector = this.unmatchdFileSaveProc3Injector || rhs
            .unmatchdFileSaveProc3Injector;
        result.versionFileSaveProc3Injector = this.versionFileSaveProc3Injector || rhs
            .versionFileSaveProc3Injector;
        result.unmatchdFileSaveProc4Injector = this.unmatchdFileSaveProc4Injector || rhs
            .unmatchdFileSaveProc4Injector;
        result.versionFileSaveProc4Injector = this.versionFileSaveProc4Injector || rhs
            .versionFileSaveProc4Injector;
        result.unmatchdFileSaveProc5Injector = this.unmatchdFileSaveProc5Injector || rhs
            .unmatchdFileSaveProc5Injector;
        result.versionFileSaveProc5Injector = this.versionFileSaveProc5Injector || rhs
            .versionFileSaveProc5Injector;
        result.unmatchdFileSaveProc6Injector = this.unmatchdFileSaveProc6Injector || rhs
            .unmatchdFileSaveProc6Injector;
        result.versionFileSaveProc6Injector = this.versionFileSaveProc6Injector || rhs
            .versionFileSaveProc6Injector;
        result.unmatchdFileSaveProc7Injector = this.unmatchdFileSaveProc7Injector || rhs
            .unmatchdFileSaveProc7Injector;
        result.versionFileSaveProc7Injector = this.versionFileSaveProc7Injector || rhs
            .versionFileSaveProc7Injector;

        result.unmatchdOptionsProc1Injector = this.unmatchdOptionsProc1Injector || rhs
            .unmatchdOptionsProc1Injector;
        result.versionOptionsProc1Injector = this.versionOptionsProc1Injector || rhs
            .versionOptionsProc1Injector;

        result.unmatchdVersionProc1Injector = this.unmatchdVersionProc1Injector || rhs
            .unmatchdVersionProc1Injector;
        result.versionVersionProc1Injector = this.versionVersionProc1Injector || rhs
            .versionVersionProc1Injector;

        return result;
    }
}

// RunOptionsに相当する構造体（仮）
// 実際のRunOptionsはdllmain.dの周辺で定義されているはずだが、
// 現状はeu4Versionフィールドのみを持つ最小限の定義とする
struct RunOptions
{
    EU4Ver eu4Version; // 'version' を 'eu4Version' に変更
    int separateCharacterCodePoint; // 新しいプロパティを追加
}

// FIXME: inputProc1, inputProc1V130, inputProc2 のD言語版関数をasmファイルから移植する
// 現状はダミーの関数定義のみ
extern (C)
{
    void* inputProc1() { return null; }
    void* inputProc1V130() { return null; }
    void* inputProc2() { return null; }

    // FIXME: utf8ToEscapedStr3 のD言語版関数をescape_tool.dに定義し、ここで呼び出す
    // 現状はダミーの関数定義のみ
    size_t utf8ToEscapedStr3(size_t arg)
    {
        writeln("Dummy utf8ToEscapedStr3 called.");
        return arg;
    }
}

size_t inputProc1ReturnAddress1;
size_t inputProc1ReturnAddress2;
size_t inputProc1CallAddress;
size_t inputProc2ReturnAddress;

// Inputモジュール内で関数を定義
DllError inputProc1Injector(RunOptions options)
{
    DllError e;

    switch (options.eu4Version)
    { // 'options.version' を 'options.eu4Version' に変更
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0:
        {
            // mov     eax, dword ptr    [rbp+120h+var_198+0Ch]
            BytePattern.tempInstance().findPattern("8B 45 94 32 DB 3C 80 73 05 0F B6 D8 EB 10");
            if (BytePattern.tempInstance().hasSize(1, "入力した文字をutf8からエスケープ列へ変換する１"))
            {
                size_t address = BytePattern.tempInstance().getFirst().address;

                inputProc1CallAddress = cast(size_t)&utf8ToEscapedStr3;

                // mov     rax, [r13+0]
                inputProc1ReturnAddress1 = address + 0x1E;

                // Injector::MakeJMP に相当するD言語でのフック処理を実装する
                PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)inputProc1));
                writeln("JMP for inputProc1Injector (1) created using ScopedPatch.");
            }
            else
            {
                e.unmatchdInputProc1Injector = true;
            }

            // call    qword ptr [rax+18h]
            BytePattern.tempInstance().findPattern("FF 50 18 E9 ? ? 00 00 49 8B 45 00");
            if (BytePattern.tempInstance().hasSize(1, "入力した文字をutf8からエスケープ列へ変換する２"))
            {
                size_t address = BytePattern.tempInstance().getFirst().address;
                // jmp     loc_{xxxxx}
                // FIXME: Injector::GetBranchDestination に相当するD言語でのアドレス取得処理を実装する
                // inputProc1ReturnAddress2 = Injector.GetBranchDestination(address + 0x3).as_int();
                inputProc1ReturnAddress2 = address + 0x07 + get_branch_destination_offset(cast(void*)(address + 0x03), 4); // 仮のアドレス
                writeln("GetBranchDestination for inputProc1Injector (2) called.");
            }
            else
            {
                e.unmatchdInputProc1Injector = true;
            }

            break;
        }
    case EU4Ver.v1_31_1_0:
    case EU4Ver.v1_30_5_0:
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_30_3_0:
    case EU4Ver.v1_30_2_0:
    case EU4Ver.v1_30_1_0:
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_5_0:
    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_33_3_0:
        {
            // mov     eax, dword ptr    [rbp+120h+var_18C]
            BytePattern.tempInstance().findPattern("8B 45 94 32 DB 3C 80 73 05 0F B6 D8 EB 10");
            if (BytePattern.tempInstance().hasSize(1, "入力した文字をutf8からエスケープ列へ変換する１"))
            {
                size_t address = BytePattern.tempInstance().getFirst().address;

                inputProc1CallAddress = cast(size_t)&utf8ToEscapedStr3;

                // mov     rax, [r13+0]
                inputProc1ReturnAddress1 = address + 0x1E;

                // Injector::MakeJMP に相当するD言語でのフック処理を実装する
                PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)inputProc1));
                writeln("JMP for inputProc1Injector (2) created using ScopedPatch.");
            }
            else
            {
                e.unmatchdInputProc1Injector = true;
            }

            // call    qword ptr [rax+18h]
            BytePattern.tempInstance().findPattern("FF 50 18 E9 ? ? 00 00 49 8B 45 00");
            if (BytePattern.tempInstance().hasSize(1, "入力した文字をutf8からエスケープ列へ変換する２"))
            {
                size_t address = BytePattern.tempInstance().getFirst().address;
                // jmp     loc_{xxxxx}
                // inputProc1ReturnAddress2 = Injector.GetBranchDestination(address + 0x3).as_int();
                inputProc1ReturnAddress2 = address + 0x07 + get_branch_destination_offset(cast(void*)(address + 0x03), 4); // 仮のアドレス
                writeln("GetBranchDestination for inputProc1Injector (2) called.");
            }
            else
            {
                e.unmatchdInputProc1Injector = true;
            }

            break;
        }
    default:
        {
            e.versionInputProc1Injector = true;
            break;
        }
    }

    return e;
}

DllError inputProc2Injector(RunOptions options)
{
    DllError e;

    switch (options.eu4Version)
    { // 'options.version' を 'options.eu4Version' に変更
    case EU4Ver.v1_29_3_0:
    case EU4Ver.v1_29_4_0:
    case EU4Ver.v1_30_1_0:
    case EU4Ver.v1_30_2_0:
    case EU4Ver.v1_30_3_0:
    case EU4Ver.v1_30_4_0:
    case EU4Ver.v1_30_5_0:
    case EU4Ver.v1_31_1_0:
    case EU4Ver.v1_31_2_0:
    case EU4Ver.v1_31_3_0:
    case EU4Ver.v1_31_4_0:
    case EU4Ver.v1_31_5_0:
    case EU4Ver.v1_31_6_0:
    case EU4Ver.v1_32_0_1:
    case EU4Ver.v1_33_0_0:
    case EU4Ver.v1_33_3_0:
        {
            // mov     rax, [rdi]
            BytePattern.tempInstance()
                .findPattern("48 8B 07 48 8B CF 85 DB 74 08 FF 90 40 01 00 00");
            if (BytePattern.tempInstance().hasSize(1, "バックスペース処理の修正"))
            {
                size_t address = BytePattern.tempInstance().getFirst().address;

                // movzx   r8d, word ptr [rdi+56h]
                inputProc2ReturnAddress = address + 0x18;

                // Injector::MakeJMP に相当するD言語でのフック処理を実装する
                PatchManager.instance().addPatch(cast(void*)address, makeJmp(cast(void*)address, cast(void*)inputProc2));
                writeln("JMP for inputProc2Injector created.");
            }
            else
            {
                e.unmatchdInputProc2Injector = true;
            }
            break;
        }
    default:
        {
            e.versionInputProc2Injector = true;
            break;
        }
    }

    return e;
}

DllError init(EU4Ver eu4Version)
{ // 'version' を 'eu4Version' に変更
    DllError result;
    RunOptions options;
    options.eu4Version = eu4Version; // 'options.version' を 'options.eu4Version' に変更

    result = result | inputProc1Injector(options);
    result = result | inputProc2Injector(options);

    return result;
}
