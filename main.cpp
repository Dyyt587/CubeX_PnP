#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <opencv2/opencv.hpp>

#include <QtQml/qqmlextensionplugin.h>
#include <QDir>
#include <QLoggingCategory>
#include <QNetworkProxy>
#include <QProcess>
#include <QQmlContext>
#include <QQuickWindow>
#include <QSslConfiguration>


#include "src/component/CircularReveal.h"

#include "src/helper/CameraScanManager.h"
#include "src/helper/CameraDeviceManager.h"
#include "src/helper/SerialPortManager.h"
#include "src/helper/CsvFileReader.h"
#include "src/helper/OpenCvPreviewManager.h"

int main(int argc, char *argv[])
{

    const char *uri = "CubeX_PnP";
    int major = 1;
    int minor = 0;

    
    qputenv("QT_IM_MODULE", "qtvirtualkeyboard");
    qputenv("QT_VIRTUALKEYBOARD_DESKTOP_DISABLE", "1");
    qputenv("QT_AUTO_SCREEN_SCALE_FACTOR", "1");
    qputenv("QT_ENABLE_HIGHDPI_SCALING", "0");
    qputenv("QT_LOGGING_RULES", "qt.qml.connections=false");
    qputenv("QT_QUICK_CONTROLS_CONF", ":/qtquickcontrols2.conf");
    qputenv("QML_COMPAT_RESOLVE_URLS_ON_ASSIGNMENT", "1");
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    SerialPortManager serialPortManager;
    CameraScanManager cameraScanManager;
    CameraDeviceManager cameraDeviceManager;
    CsvFileReader csvFileReader;
    OpenCvPreviewManager openCvPreviewManager;
    
    engine.rootContext()->setContextProperty("serialPortManager", &serialPortManager);
    engine.rootContext()->setContextProperty("cameraScanManager", &cameraScanManager);
    engine.rootContext()->setContextProperty("cameraDeviceManager", &cameraDeviceManager);
    engine.rootContext()->setContextProperty("csvFileReader", &csvFileReader);
    engine.rootContext()->setContextProperty("openCvPreviewManager", &openCvPreviewManager);
    engine.addImageProvider("opencvpreview", openCvPreviewManager.createImageProvider());

    qmlRegisterType<CircularReveal>(uri, major, minor, "CircularReveal");


    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("CubeX_PnP", "Main");

    return app.exec();
}
