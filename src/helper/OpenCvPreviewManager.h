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
    Q_PROPERTY(double topProcessingMs READ topProcessingMs NOTIFY topFrameTokenChanged)
    Q_PROPERTY(double bottomProcessingMs READ bottomProcessingMs NOTIFY bottomFrameTokenChanged)
    Q_PROPERTY(int topResWidth READ topResWidth NOTIFY topFrameTokenChanged)
    Q_PROPERTY(int topResHeight READ topResHeight NOTIFY topFrameTokenChanged)
    Q_PROPERTY(int bottomResWidth READ bottomResWidth NOTIFY bottomFrameTokenChanged)
    Q_PROPERTY(int bottomResHeight READ bottomResHeight NOTIFY bottomFrameTokenChanged)
    Q_PROPERTY(int topBinAlgorithm READ topBinAlgorithm WRITE setTopBinAlgorithm NOTIFY topBinAlgorithmChanged)
    Q_PROPERTY(int bottomBinAlgorithm READ bottomBinAlgorithm WRITE setBottomBinAlgorithm NOTIFY bottomBinAlgorithmChanged)
    Q_PROPERTY(double topBinParam1 READ topBinParam1 WRITE setTopBinParam1 NOTIFY topBinParam1Changed)
    Q_PROPERTY(double bottomBinParam1 READ bottomBinParam1 WRITE setBottomBinParam1 NOTIFY bottomBinParam1Changed)
    Q_PROPERTY(double topBinParam2 READ topBinParam2 WRITE setTopBinParam2 NOTIFY topBinParam2Changed)
    Q_PROPERTY(double bottomBinParam2 READ bottomBinParam2 WRITE setBottomBinParam2 NOTIFY bottomBinParam2Changed)

public:
    enum BinAlgorithm {
        ManualThreshold = 0,
        Otsu,
        Triangle,
        AdaptiveGaussian,
        AdaptiveMean
    };
    Q_ENUM(BinAlgorithm)

    explicit OpenCvPreviewManager(QObject *parent = nullptr);

    int topFrameToken() const;
    int bottomFrameToken() const;
    double topFps() const;
    double bottomFps() const;
    double topProcessingMs() const;
    double bottomProcessingMs() const;
    int topResWidth() const;
    int topResHeight() const;
    int bottomResWidth() const;
    int bottomResHeight() const;

    int topBinAlgorithm() const;
    void setTopBinAlgorithm(int algo);
    int bottomBinAlgorithm() const;
    void setBottomBinAlgorithm(int algo);
    double topBinParam1() const;
    void setTopBinParam1(double v);
    double bottomBinParam1() const;
    void setBottomBinParam1(double v);
    double topBinParam2() const;
    void setTopBinParam2(double v);
    double bottomBinParam2() const;
    void setBottomBinParam2(double v);

    Q_INVOKABLE void setTopCamera(QObject *cameraObject);
    Q_INVOKABLE void setBottomCamera(QObject *cameraObject);

    QQuickImageProvider *createImageProvider();
    QImage imageForId(const QString &id) const;

signals:
    void topFrameTokenChanged();
    void bottomFrameTokenChanged();
    void topFpsChanged();
    void bottomFpsChanged();
    void topBinAlgorithmChanged();
    void bottomBinAlgorithmChanged();
    void topBinParam1Changed();
    void bottomBinParam1Changed();
    void topBinParam2Changed();
    void bottomBinParam2Changed();

private:
    void processTopFrame(const QVideoFrame &frame);
    void processBottomFrame(const QVideoFrame &frame);
    void updateTopFps();
    void updateBottomFps();
    static QImage processFrameToBlackWhite(const QImage &source, BinAlgorithm algo, double param1, double param2);
    static QImage cropToSquare(const QImage &source);

private:
    QMediaCaptureSession m_topCaptureSession;
    QMediaCaptureSession m_bottomCaptureSession;
    QVideoSink m_topSink;
    QVideoSink m_bottomSink;
    QPointer<QCamera> m_topCamera;
    QPointer<QCamera> m_bottomCamera;
    QImage m_topBwImage;
    QImage m_topColorImage;
    QImage m_bottomBwImage;
    QImage m_bottomColorImage;
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

    int m_topBinAlgorithm = ManualThreshold;
    int m_bottomBinAlgorithm = ManualThreshold;
    double m_topBinParam1 = 127;
    double m_bottomBinParam1 = 127;
    double m_topBinParam2 = 5;
    double m_bottomBinParam2 = 5;
    double m_topProcessingMs = 0;
    double m_bottomProcessingMs = 0;
    int m_topResWidth = 0;
    int m_topResHeight = 0;
    int m_bottomResWidth = 0;
    int m_bottomResHeight = 0;
};
