/*
 * @Author: YingTian Yang 805207319@qq.com
 * @Date: 2026-03-03 17:50:27
 * @LastEditors: YingTian Yang 805207319@qq.com
 * @LastEditTime: 2026-03-13 22:57:33
 * @FilePath: \CubeX_PnP\main.cpp
 * @Description: 这是默认设置,请设置`customMade`, 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
 */
#include <QGuiApplication>
#include <QFileInfo>
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
#include <QStandardPaths>
#include <QUrl>


#include "src/component/CircularReveal.h"

#include "src/helper/CameraDeviceManager.h"
#include "src/helper/SerialPortManager.h"
#include "src/helper/CsvFileReader.h"
#include "src/helper/GerberPreviewManager.h"
#include "src/helper/GerberPreviewRenderer.h"
#include "src/helper/OpenCvPreviewManager.h"
#include "src/helper/SMTWork.h"

static QString resolveInteractiveBomUrl()
{
    const QString fileName = QStringLiteral("InteractiveBOM_PCB5_2026-3-13.html");
    const QString appDir = QCoreApplication::applicationDirPath();
    const QString currentDir = QDir::currentPath();

    const QStringList candidates = {
        QDir(currentDir).filePath(fileName),
        QDir(appDir).filePath(fileName),
        QDir(appDir).filePath(QStringLiteral("../") + fileName),
        QDir(appDir).filePath(QStringLiteral("../../") + fileName),
        QDir(appDir).filePath(QStringLiteral("../../../") + fileName)
    };

    for (const QString &path : candidates) {
        QFileInfo info(QDir::cleanPath(path));
        if (info.exists() && info.isFile()) {
            return QUrl::fromLocalFile(info.absoluteFilePath()).toString();
        }
    }
    return QStringLiteral("about:blank");
}

static QString resolveWorkspaceRoot()
{
    const QString appDir = QCoreApplication::applicationDirPath();
    const QString currentDir = QDir::currentPath();
    const QStringList candidates = {
        currentDir,
        appDir,
        QDir(appDir).filePath(".."),
        QDir(appDir).filePath("../.."),
        QDir(appDir).filePath("../../..")
    };

    for (const QString &candidate : candidates) {
        const QString root = QDir::cleanPath(candidate);
        if (QFileInfo::exists(QDir(root).filePath("CMakeLists.txt"))) {
            return root;
        }
    }
    return currentDir;
}

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
    QCoreApplication::setOrganizationName(QStringLiteral("CubeX"));
    QCoreApplication::setOrganizationDomain(QStringLiteral("cubex.local"));
    QCoreApplication::setApplicationName(QStringLiteral("CubeX_PnP"));

    QQmlApplicationEngine engine;
    SerialPortManager serialPortManager;
    CameraDeviceManager cameraDeviceManager;
    CsvFileReader csvFileReader;
    GerberPreviewManager gerberPreviewManager;
    OpenCvPreviewManager openCvPreviewManager;
    SMTWork smtWork;

    if (!gerberPreviewManager.initFromWorkspace(resolveWorkspaceRoot())) {
        qWarning() << "Gerber preview init failed:" << gerberPreviewManager.lastError();
    }
    
    // 连接 smtWork 和 serialPortManager
    smtWork.setSerialPortManager(&serialPortManager);
    
    engine.rootContext()->setContextProperty("serialPortManager", &serialPortManager);
    engine.rootContext()->setContextProperty("cameraDeviceManager", &cameraDeviceManager);
    engine.rootContext()->setContextProperty("csvFileReader", &csvFileReader);
    engine.rootContext()->setContextProperty("gerberPreviewManager", &gerberPreviewManager);
    engine.rootContext()->setContextProperty("openCvPreviewManager", &openCvPreviewManager);
    engine.rootContext()->setContextProperty("smtWork", &smtWork);
    engine.rootContext()->setContextProperty("interactiveBomUrl", resolveInteractiveBomUrl());
    engine.addImageProvider("opencvpreview", openCvPreviewManager.createImageProvider());

    // Preload package library during startup for diagnosing CSV parsing
    qDebug().nospace() << "[STARTUP] Preloading package library...";
    auto pkgMap = csvFileReader.getPackageLibraryMap();
    qDebug().nospace() << "[STARTUP] Package library returned " << pkgMap.size() << " entries";

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
