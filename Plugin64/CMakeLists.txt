project(plugin64 CXX)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(plugin64_SRCS
    byte_pattern.cpp
    date.cpp
    debug.cpp
    dll_main.cpp
    escape_tool.cpp
    event_dialog.cpp
    file_save.cpp
    font.cpp
    ime.cpp
    input.cpp
    list_field_adjustment.cpp
    main_text.cpp
    map_adjustment.cpp
    map_justify.cpp
    map_nudge_view.cpp
    map_popup.cpp
    map_view.cpp
    mod_download.cpp
    options.cpp
    pch.cpp
    tooltip_and_button.cpp
    validator.cpp
    version.cpp
    word_order.cpp)

add_library(plugin64 SHARED ${plugin64_SRCS})
