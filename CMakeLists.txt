cmake_minimum_required(VERSION 3.16)

project(CubeX_PnP VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTORCC ON)

# 设置 OpenCV 路径
set(OpenCV_DIR "C:/Users/lzj/Github/OpenCV_MingW/OpenCV4.11_mingw13.1.0")
find_package(FluentUI)
find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick Network Multimedia Concurrent SerialPort)
find_package(OpenCV REQUIRED)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appCubeX_PnP
    main.cpp image.qrc
    src/singleton.h src/stdafx.h
    src/component/CircularReveal.cpp src/component/CircularReveal.h
)
qt_add_resources(appCubeX_PnP "configuration"
    PREFIX "/"
    FILES
        qtquickcontrols2.conf
        #resources.qrc
)

# 1. 单独处理资源文件，生成独立资源对象
qt_add_resources(RES resources.qrc)

qt_add_qml_module(appCubeX_PnP
    URI CubeX_PnP
    QML_FILES
        Main.qml
        RESOURCES resource.qrc
        QML_FILES
        QML/AppMainWindow.qml
        QML/component/CubexFluTableView.qml
        QML/component/DraggableFocusOverlay.qml
        QML/component/SerialConnectionPanel.qml
        QML/page/CameraCard.qml
        QML/page/DeviceConnectionPage.qml
        QML/page/HomePage.qml
        QML/page/SettingsPage.qml
        SOURCES src/helper/CameraDeviceManager.cpp src/helper/CameraDeviceManager.h src/helper/CameraScanManager.cpp src/helper/CameraScanManager.h src/helper/CsvFileReader.cpp src/helper/CsvFileReader.h src/helper/InitializrHelper.cpp src/helper/InitializrHelper.h src/helper/Log.cpp src/helper/Log.h src/helper/OpenCvPreviewManager.cpp src/helper/OpenCvPreviewManager.h src/helper/SerialPortManager.cpp src/helper/SerialPortManager.h src/helper/SettingsHelper.cpp src/helper/SettingsHelper.h src/helper/SMTWork.cpp src/helper/SMTWork.h src/helper/TranslateHelper.cpp src/helper/TranslateHelper.h
        SOURCES Version.h
        RESOURCES image.qrc
    )

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appCubeX_PnP PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appCubeX_PnP
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appCubeX_PnP
    PRIVATE ${OpenCV_LIBS}
    PRIVATE Qt6::Quick
        Qt6::Core
        Qt6::Gui
        Qt6::Qml
        Qt6::Multimedia
        Qt6::Concurrent
        Qt6::SerialPort
)
target_include_directories(appCubeX_PnP PRIVATE ${OpenCV_INCLUDE_DIRS})

include(GNUInstallDirs)
install(TARGETS appCubeX_PnP
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
