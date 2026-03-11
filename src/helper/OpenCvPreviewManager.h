#pragma once

#include <QImage>
#include <QMediaCaptureSession>
#include <QObject>
#include <QPointer>
#include <QQuickImageProvider>
#include <QMutex>
#include <QVideoSink>
#include <QElapsedTimer>

class QCamera;
class QVideoFrame;

class OpenCvPreviewManager;

class OpenCvPreviewImageProvider : public QQuickImageProvider
{
public:
    explicit OpenCvPreviewImageProvider(OpenCvPreviewManager *manager);

    QImage requestImage(const QString &id, QSize *size, const QSize &requestedSize) override;

private:
    OpenCvPreviewManager *m_manager;
};

class OpenCvPreviewManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int topFrameToken READ topFrameToken NOTIFY topFrameTokenChanged)
    Q_PROPERTY(int bottomFrameToken READ bottomFrameToken NOTIFY bottomFrameTokenChanged)
    Q_PROPERTY(double topFps READ topFps NOTIFY topFpsChanged)
    Q_PROPERTY(double bottomFps READ bottomFps NOTIFY bottomFpsChanged)

public:
    explicit OpenCvPreviewManager(QObject *parent = nullptr);

    int topFrameToken() const;
    int bottomFrameToken() const;
    double topFps() const;
    double bottomFps() const;

    Q_INVOKABLE void setTopCamera(QObject *cameraObject);
    Q_INVOKABLE void setBottomCamera(QObject *cameraObject);

    QQuickImageProvider *createImageProvider();
    QImage imageForId(const QString &id) const;

signals:
    void topFrameTokenChanged();
    void bottomFrameTokenChanged();
    void topFpsChanged();
    void bottomFpsChanged();

private:
    void processTopFrame(const QVideoFrame &frame);
    void processBottomFrame(const QVideoFrame &frame);
    void updateTopFps();
    void updateBottomFps();
    static QImage processFrameToBlackWhite(const QVideoFrame &frame);

private:
    QMediaCaptureSession m_topCaptureSession;
    QMediaCaptureSession m_bottomCaptureSession;
    QVideoSink m_topSink;
    QVideoSink m_bottomSink;
    QPointer<QCamera> m_topCamera;
    QPointer<QCamera> m_bottomCamera;
    QImage m_topImage;
    QImage m_bottomImage;
    int m_topFrameToken;
    int m_bottomFrameToken;
    int m_topFrameCount;
    int m_bottomFrameCount;
    qint64 m_topFpsWindowStartMs;
    qint64 m_bottomFpsWindowStartMs;
    double m_topFps;
    double m_bottomFps;
    QElapsedTimer m_fpsTimer;
    mutable QMutex m_imageMutex;
};
