cmake_minimum_required(VERSION 3.21)

project(CubeJ1MqttAndroid VERSION 0.1.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Quick Network QuickControls2)

qt_standard_project_setup(REQUIRES 6.6)
qt_policy(SET QTP0004 NEW)

qt_add_executable(CubeJ1MqttAndroid
    src/main.cpp
    src/CubeJClient.cpp
    src/CubeJClient.h
    src/DeviceDiscovery.cpp
    src/DeviceDiscovery.h
    src/ThemeController.cpp
    src/ThemeController.h
)

qt_add_qml_module(CubeJ1MqttAndroid
    URI CubeJ1
    VERSION 1.0
    QML_FILES
        qml/Main.qml
)

target_link_libraries(CubeJ1MqttAndroid
    PRIVATE
        Qt6::Core
        Qt6::Quick
        Qt6::Network
        Qt6::QuickControls2
)

set_target_properties(CubeJ1MqttAndroid PROPERTIES
    QT_ANDROID_PACKAGE_SOURCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/android"
)

if(ANDROID)
    set_property(TARGET CubeJ1MqttAndroid APPEND PROPERTY
        QT_ANDROID_PACKAGE_SOURCE_FILES
            android/src/net/nanami/cubej1mqtt/CubeDiscovery.java
    )
endif()
