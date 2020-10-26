project(plugin CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(plugin_SRCS
    ButtonAndToolTip.cpp
    DateFormat.cpp
    FileSave.cpp
    IME.cpp
    Input.cpp
    InputIssue19.cpp
    ListChars.cpp
    NameOrder.cpp
    Popup.cpp
    ShowFileName.cpp
    Text.cpp
    ToolTipApx.cpp
    byte_pattern.cpp
    dllmain.cpp
    eventDialog.cpp
    font.cpp
    mapAdj.cpp
    mapJustify.cpp
    mapView.cpp
    misc.cpp
    moddl.cpp
    version.cpp)

add_library(plugin SHARED ${plugin_SRCS})
