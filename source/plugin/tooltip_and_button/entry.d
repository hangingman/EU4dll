module plugin.tooltip_and_button.entry;

import plugin.input; // For DllError and RunOptions
import plugin.constant;
import plugin.tooltip_and_button.proc1;
import plugin.tooltip_and_button.proc2;
import plugin.tooltip_and_button.proc3;
import plugin.tooltip_and_button.proc4;
import plugin.tooltip_and_button.proc5;
import plugin.tooltip_and_button.proc6;
import plugin.tooltip_and_button.proc7;

DllError init(EU4Ver eu4Version) {
    DllError result;
    RunOptions options;
    options.eu4Version = eu4Version;

    result = result | tooltipAndButtonProc1Injector(options);
    result = result | tooltipAndButtonProc2Injector(options);
    result = result | tooltipAndButtonProc3Injector(options);
    result = result | tooltipAndButtonProc4Injector(options);
    result = result | tooltipAndButtonProc5Injector(options);
    result = result | tooltipAndButtonProc6Injector(options);
    result = result | tooltipAndButtonProc7Injector(options);

    return result;
}
