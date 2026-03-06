#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <opencv2/opencv.hpp>

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("CubeX_PnP", "Main");

    return app.exec();
}
