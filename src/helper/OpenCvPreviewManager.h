#pragma once

#include <QImage>
#include <QMediaCaptureSession>
#include <QObject>
#include <QPointer>
#include <QQuickImageProvider>
#include <QMutex>
#include <QVideoSink>
#include <QElapsedTimer>
#include <QAtomicInt>
#include <QVariantList>
#include <QVariantMap>

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
    Q_PROPERTY(int topTemplateToken READ topTemplateToken NOTIFY topTemplateTokenChanged)
    Q_PROPERTY(int bottomTemplateToken READ bottomTemplateToken NOTIFY bottomTemplateTokenChanged)
    Q_PROPERTY(int topMatchPreviewToken READ topMatchPreviewToken NOTIFY topMatchPreviewTokenChanged)
    Q_PROPERTY(int bottomMatchPreviewToken READ bottomMatchPreviewToken NOTIFY bottomMatchPreviewTokenChanged)
    Q_PROPERTY(double topFps READ topFps NOTIFY topFpsChanged)
    Q_PROPERTY(double bottomFps READ bottomFps NOTIFY bottomFpsChanged)
    Q_PROPERTY(double topProcessingMs READ topProcessingMs NOTIFY topProcessingMsChanged)
    Q_PROPERTY(double bottomProcessingMs READ bottomProcessingMs NOTIFY bottomProcessingMsChanged)
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
    Q_PROPERTY(double topContourMinArea READ topContourMinArea WRITE setTopContourMinArea NOTIFY topContourMinAreaChanged)
    Q_PROPERTY(double bottomContourMinArea READ bottomContourMinArea WRITE setBottomContourMinArea NOTIFY bottomContourMinAreaChanged)
    Q_PROPERTY(double topContourMaxArea READ topContourMaxArea WRITE setTopContourMaxArea NOTIFY topContourMaxAreaChanged)
    Q_PROPERTY(double bottomContourMaxArea READ bottomContourMaxArea WRITE setBottomContourMaxArea NOTIFY bottomContourMaxAreaChanged)
    Q_PROPERTY(bool topBinInvert READ topBinInvert WRITE setTopBinInvert NOTIFY topBinInvertChanged)
    Q_PROPERTY(bool bottomBinInvert READ bottomBinInvert WRITE setBottomBinInvert NOTIFY bottomBinInvertChanged)

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
    ~OpenCvPreviewManager() override;

    int topFrameToken() const;
    int bottomFrameToken() const;
    int topTemplateToken() const;
    int bottomTemplateToken() const;
    int topMatchPreviewToken() const;
    int bottomMatchPreviewToken() const;
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

    double topContourMinArea() const;
    void setTopContourMinArea(double v);
    double bottomContourMinArea() const;
    void setBottomContourMinArea(double v);
    double topContourMaxArea() const;
    void setTopContourMaxArea(double v);
    double bottomContourMaxArea() const;
    void setBottomContourMaxArea(double v);

    bool topBinInvert() const;
    void setTopBinInvert(bool v);
    bool bottomBinInvert() const;
    void setBottomBinInvert(bool v);

    Q_INVOKABLE void setTopCamera(QObject *cameraObject);
    Q_INVOKABLE void setBottomCamera(QObject *cameraObject);
    Q_INVOKABLE bool captureTemplate(int cameraRole, const QVariantList &points);
    Q_INVOKABLE QVariantMap runTemplateMatch(int cameraRole, const QVariantList &points);
    Q_INVOKABLE QVariantMap runTemplateMatchInRegion(int cameraRole, const QVariantList &templatePoints,
                                                     const QVariantList &searchRegionPoints);

    QQuickImageProvider *createImageProvider();
    QImage imageForId(const QString &id) const;

signals:
    void topFrameTokenChanged();
    void bottomFrameTokenChanged();
    void topTemplateTokenChanged();
    void bottomTemplateTokenChanged();
    void topMatchPreviewTokenChanged();
    void bottomMatchPreviewTokenChanged();
    void topFpsChanged();
    void bottomFpsChanged();
    void topBinAlgorithmChanged();
    void bottomBinAlgorithmChanged();
    void topBinParam1Changed();
    void bottomBinParam1Changed();
    void topBinParam2Changed();
    void bottomBinParam2Changed();
    void topContourMinAreaChanged();
    void bottomContourMinAreaChanged();
    void topContourMaxAreaChanged();
    void bottomContourMaxAreaChanged();
    void topBinInvertChanged();
    void bottomBinInvertChanged();
    void topProcessingMsChanged();
    void bottomProcessingMsChanged();

private:
    void processTopFrame(const QVideoFrame &frame);
    void processBottomFrame(const QVideoFrame &frame);
    void onTopProcessed(const QImage &bw, const QImage &color, double frameMs, int w, int h);
    void onBottomProcessed(const QImage &bw, const QImage &color, double frameMs, int w, int h);
    void updateTopFps();
    void updateBottomFps();
    static QImage processFrameToBlackWhite(const QImage &source, BinAlgorithm algo, double param1, double param2, bool invert);
    static QImage detectAndDrawContours(const QImage &bwSource, const QImage &colorSource, double minArea, double maxArea);
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
    QImage m_topTemplateImage;
    QImage m_bottomTemplateImage;
    QImage m_topMatchPreviewImage;
    QImage m_bottomMatchPreviewImage;
    int m_topFrameToken;
    int m_bottomFrameToken;
    int m_topTemplateToken = 0;
    int m_bottomTemplateToken = 0;
    int m_topMatchPreviewToken = 0;
    int m_bottomMatchPreviewToken = 0;
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
    double m_topProcessingMaxMs = 0;
    double m_bottomProcessingMaxMs = 0;
    qint64 m_topProcWindowStartMs = 0;
    qint64 m_bottomProcWindowStartMs = 0;
    int m_topResWidth = 0;
    int m_topResHeight = 0;
    int m_bottomResWidth = 0;
    int m_bottomResHeight = 0;

    double m_topContourMinArea = 100;
    double m_bottomContourMinArea = 100;
    double m_topContourMaxArea = 50000;
    double m_bottomContourMaxArea = 50000;

    bool m_topBinInvert = false;
    bool m_bottomBinInvert = false;

    QAtomicInt m_topBusy{0};
    QAtomicInt m_bottomBusy{0};
};
