cmake_minimum_required(VERSION 3.16)

project(CubeX_PnP VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)
# 设置 OpenCV 路径
set(OpenCV_DIR "C:/Users/lzj/Github/OpenCV_MingW/OpenCV4.11_mingw13.1.0")
find_package(FluentUI)
find_package(Qt6 REQUIRED COMPONENTS Quick)
find_package(OpenCV REQUIRED)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appCubeX_PnP
    main.cpp
)

qt_add_qml_module(appCubeX_PnP
    URI CubeX_PnP
    QML_FILES
        Main.qml
        RESOURCES resource.qrc
        QML_FILES QML/AppMainWindow.qml
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
)
target_include_directories(appCubeX_PnP PRIVATE ${OpenCV_INCLUDE_DIRS})

include(GNUInstallDirs)
install(TARGETS appCubeX_PnP
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)
