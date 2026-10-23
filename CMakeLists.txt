cmake_minimum_required(VERSION 3.16)

project(GT7_copilot VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick Network)

qt_standard_project_setup(REQUIRES 6.10)

# Content of downloaded design from Figma to Qt or similar
if (EXISTS "${CMAKE_CURRENT_LIST_DIR}/importedcontent/CMakeLists.txt")
    add_subdirectory(${CMAKE_CURRENT_LIST_DIR}/importedcontent)
endif()

qt_add_executable(appGT7_copilot
    main.cpp
    instructor.h
    instructor.cpp
)

qt_add_qml_module(appGT7_copilot
    URI GT7_copilot

    QML_FILES
        Main.qml
        CircuitMap.qml
        MapEngine.js
        SpaData.js

    SOURCES
        instructor.h
        instructor.cpp
        telemetry.h
        telemetry.cpp
        telemetry_core.h
        gt7packet.h
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appGT7_copilot PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appGT7_copilot
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appGT7_copilot
    PRIVATE
        Qt6::Quick
        Qt6::Network
)

install(TARGETS appGT7_copilot
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
