#include "OpenCvPreviewManager.h"

#include <QCamera>
#include <QMutex>
#include <QMutexLocker>
#include <QVideoFrame>

#include <opencv2/imgproc.hpp>

OpenCvPreviewImageProvider::OpenCvPreviewImageProvider(OpenCvPreviewManager *manager)
    : QQuickImageProvider(QQuickImageProvider::Image),
    m_manager(manager)
{
}

QImage OpenCvPreviewImageProvider::requestImage(const QString &id, QSize *size, const QSize &requestedSize)
{
    if (!m_manager) {
        return QImage();
    }

    QImage image = m_manager->imageForId(id);
    if (size) {
        *size = image.size();
    }

    if (requestedSize.isValid() && !image.isNull() && image.size() != requestedSize) {
        image = image.scaled(requestedSize, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    }

    return image;
}

OpenCvPreviewManager::OpenCvPreviewManager(QObject *parent)
    : QObject(parent),
    m_topFrameToken(0),
    m_bottomFrameToken(0),
    m_topFrameCount(0),
    m_bottomFrameCount(0),
    m_topFpsWindowStartMs(0),
    m_bottomFpsWindowStartMs(0),
    m_topFps(0.0),
    m_bottomFps(0.0)
{
    m_fpsTimer.start();

    m_topCaptureSession.setVideoSink(&m_topSink);
    m_bottomCaptureSession.setVideoSink(&m_bottomSink);

    connect(&m_topSink, &QVideoSink::videoFrameChanged, this, [this](const QVideoFrame &frame) {
        processTopFrame(frame);
    });
    connect(&m_bottomSink, &QVideoSink::videoFrameChanged, this, [this](const QVideoFrame &frame) {
        processBottomFrame(frame);
    });
}

int OpenCvPreviewManager::topFrameToken() const
{
    return m_topFrameToken;
}

int OpenCvPreviewManager::bottomFrameToken() const
{
    return m_bottomFrameToken;
}

double OpenCvPreviewManager::topFps() const
{
    return m_topFps;
}

double OpenCvPreviewManager::bottomFps() const
{
    return m_bottomFps;
}

double OpenCvPreviewManager::topProcessingMs() const { return m_topProcessingMs; }
double OpenCvPreviewManager::bottomProcessingMs() const { return m_bottomProcessingMs; }
int OpenCvPreviewManager::topResWidth() const { return m_topResWidth; }
int OpenCvPreviewManager::topResHeight() const { return m_topResHeight; }
int OpenCvPreviewManager::bottomResWidth() const { return m_bottomResWidth; }
int OpenCvPreviewManager::bottomResHeight() const { return m_bottomResHeight; }

int OpenCvPreviewManager::topBinAlgorithm() const { return m_topBinAlgorithm; }
void OpenCvPreviewManager::setTopBinAlgorithm(int algo) {
    if (m_topBinAlgorithm != algo) { m_topBinAlgorithm = algo; emit topBinAlgorithmChanged(); }
}
int OpenCvPreviewManager::bottomBinAlgorithm() const { return m_bottomBinAlgorithm; }
void OpenCvPreviewManager::setBottomBinAlgorithm(int algo) {
    if (m_bottomBinAlgorithm != algo) { m_bottomBinAlgorithm = algo; emit bottomBinAlgorithmChanged(); }
}
double OpenCvPreviewManager::topBinParam1() const { return m_topBinParam1; }
void OpenCvPreviewManager::setTopBinParam1(double v) {
    if (!qFuzzyCompare(m_topBinParam1, v)) { m_topBinParam1 = v; emit topBinParam1Changed(); }
}
double OpenCvPreviewManager::bottomBinParam1() const { return m_bottomBinParam1; }
void OpenCvPreviewManager::setBottomBinParam1(double v) {
    if (!qFuzzyCompare(m_bottomBinParam1, v)) { m_bottomBinParam1 = v; emit bottomBinParam1Changed(); }
}
double OpenCvPreviewManager::topBinParam2() const { return m_topBinParam2; }
void OpenCvPreviewManager::setTopBinParam2(double v) {
    if (!qFuzzyCompare(m_topBinParam2, v)) { m_topBinParam2 = v; emit topBinParam2Changed(); }
}
double OpenCvPreviewManager::bottomBinParam2() const { return m_bottomBinParam2; }
void OpenCvPreviewManager::setBottomBinParam2(double v) {
    if (!qFuzzyCompare(m_bottomBinParam2, v)) { m_bottomBinParam2 = v; emit bottomBinParam2Changed(); }
}

void OpenCvPreviewManager::setTopCamera(QObject *cameraObject)
{
    auto *camera = qobject_cast<QCamera *>(cameraObject);
    if (m_topCamera == camera) {
        return;
    }

    m_topCamera = camera;
    m_topCaptureSession.setCamera(camera);

    if (!camera) {
        m_topFrameCount = 0;
        m_topFpsWindowStartMs = 0;
        if (m_topFps != 0.0) {
            m_topFps = 0.0;
            emit topFpsChanged();
        }
    }
}

void OpenCvPreviewManager::setBottomCamera(QObject *cameraObject)
{
    auto *camera = qobject_cast<QCamera *>(cameraObject);
    if (m_bottomCamera == camera) {
        return;
    }

    m_bottomCamera = camera;
    m_bottomCaptureSession.setCamera(camera);

    if (!camera) {
        m_bottomFrameCount = 0;
        m_bottomFpsWindowStartMs = 0;
        if (m_bottomFps != 0.0) {
            m_bottomFps = 0.0;
            emit bottomFpsChanged();
        }
    }
}

QQuickImageProvider *OpenCvPreviewManager::createImageProvider()
{
    return new OpenCvPreviewImageProvider(this);
}

QImage OpenCvPreviewManager::imageForId(const QString &id) const
{
    const QString key = id.section('?', 0, 0).trimmed().toLower();
    QMutexLocker locker(&m_imageMutex);
    if (key == QStringLiteral("top")) {
        return m_topBwImage;
    }
    if (key == QStringLiteral("top_color")) {
        return m_topColorImage;
    }
    if (key == QStringLiteral("bottom")) {
        return m_bottomBwImage;
    }
    if (key == QStringLiteral("bottom_color")) {
        return m_bottomColorImage;
    }
    return QImage();
}

void OpenCvPreviewManager::processTopFrame(const QVideoFrame &frame)
{
    QElapsedTimer timer;
    timer.start();

    const QImage source = frame.toImage();
    if (source.isNull()) {
        return;
    }

    const QImage color = cropToSquare(source);
    const QImage bw = processFrameToBlackWhite(
        color, static_cast<BinAlgorithm>(m_topBinAlgorithm), m_topBinParam1, m_topBinParam2);

    const double frameMs = timer.nsecsElapsed() / 1000000.0;
    if (frameMs > m_topProcessingMaxMs) {
        m_topProcessingMaxMs = frameMs;
    }
    const qint64 nowMs = m_fpsTimer.elapsed();
    if (m_topProcWindowStartMs == 0) {
        m_topProcWindowStartMs = nowMs;
    }
    if (nowMs - m_topProcWindowStartMs >= 1000) {
        m_topProcessingMs = m_topProcessingMaxMs;
        m_topProcessingMaxMs = 0;
        m_topProcWindowStartMs = nowMs;
        emit topProcessingMsChanged();
    }
    m_topResWidth = color.width();
    m_topResHeight = color.height();

    {
        QMutexLocker locker(&m_imageMutex);
        m_topBwImage = bw;
        m_topColorImage = color;
    }
    ++m_topFrameToken;
    emit topFrameTokenChanged();
    updateTopFps();
}

void OpenCvPreviewManager::processBottomFrame(const QVideoFrame &frame)
{
    QElapsedTimer timer;
    timer.start();

    const QImage source = frame.toImage();
    if (source.isNull()) {
        return;
    }

    const QImage color = cropToSquare(source);
    const QImage bw = processFrameToBlackWhite(
        color, static_cast<BinAlgorithm>(m_bottomBinAlgorithm), m_bottomBinParam1, m_bottomBinParam2);

    const double frameMs = timer.nsecsElapsed() / 1000000.0;
    if (frameMs > m_bottomProcessingMaxMs) {
        m_bottomProcessingMaxMs = frameMs;
    }
    const qint64 nowMs = m_fpsTimer.elapsed();
    if (m_bottomProcWindowStartMs == 0) {
        m_bottomProcWindowStartMs = nowMs;
    }
    if (nowMs - m_bottomProcWindowStartMs >= 1000) {
        m_bottomProcessingMs = m_bottomProcessingMaxMs;
        m_bottomProcessingMaxMs = 0;
        m_bottomProcWindowStartMs = nowMs;
        emit bottomProcessingMsChanged();
    }
    m_bottomResWidth = color.width();
    m_bottomResHeight = color.height();

    {
        QMutexLocker locker(&m_imageMutex);
        m_bottomBwImage = bw;
        m_bottomColorImage = color;
    }
    ++m_bottomFrameToken;
    emit bottomFrameTokenChanged();
    updateBottomFps();
}

void OpenCvPreviewManager::updateTopFps()
{
    const qint64 nowMs = m_fpsTimer.elapsed();
    if (m_topFpsWindowStartMs == 0) {
        m_topFpsWindowStartMs = nowMs;
    }

    ++m_topFrameCount;
    const qint64 durationMs = nowMs - m_topFpsWindowStartMs;
    if (durationMs >= 1000) {
        const double fps = static_cast<double>(m_topFrameCount) * 1000.0 / static_cast<double>(durationMs);
        m_topFrameCount = 0;
        m_topFpsWindowStartMs = nowMs;
        if (!qFuzzyCompare(m_topFps, fps)) {
            m_topFps = fps;
            emit topFpsChanged();
        }
    }
}

void OpenCvPreviewManager::updateBottomFps()
{
    const qint64 nowMs = m_fpsTimer.elapsed();
    if (m_bottomFpsWindowStartMs == 0) {
        m_bottomFpsWindowStartMs = nowMs;
    }

    ++m_bottomFrameCount;
    const qint64 durationMs = nowMs - m_bottomFpsWindowStartMs;
    if (durationMs >= 1000) {
        const double fps = static_cast<double>(m_bottomFrameCount) * 1000.0 / static_cast<double>(durationMs);
        m_bottomFrameCount = 0;
        m_bottomFpsWindowStartMs = nowMs;
        if (!qFuzzyCompare(m_bottomFps, fps)) {
            m_bottomFps = fps;
            emit bottomFpsChanged();
        }
    }
}

QImage OpenCvPreviewManager::cropToSquare(const QImage &source)
{
    if (source.isNull()) {
        return source;
    }
    const int side = qMin(source.width(), source.height());
    const int x = (source.width() - side) / 2;
    const int y = (source.height() - side) / 2;
    return source.copy(x, y, side, side);
}

QImage OpenCvPreviewManager::processFrameToBlackWhite(const QImage &source, BinAlgorithm algo, double param1, double param2)
{
    if (source.isNull()) {
        return QImage();
    }

    const QImage rgbaImage = source.convertToFormat(QImage::Format_RGBA8888);
    cv::Mat rgba(rgbaImage.height(), rgbaImage.width(), CV_8UC4,
                 const_cast<uchar *>(rgbaImage.constBits()), rgbaImage.bytesPerLine());

    cv::Mat gray;
    cv::cvtColor(rgba, gray, cv::COLOR_RGBA2GRAY);

    cv::Mat binary;
    switch (algo) {
    case Otsu:
        cv::threshold(gray, binary, 0, 255, cv::THRESH_BINARY | cv::THRESH_OTSU);
        break;
    case Triangle:
        cv::threshold(gray, binary, 0, 255, cv::THRESH_BINARY | cv::THRESH_TRIANGLE);
        break;
    case AdaptiveGaussian: {
        int blockSize = static_cast<int>(param1);
        if (blockSize < 3) blockSize = 3;
        if (blockSize % 2 == 0) blockSize += 1;
        cv::adaptiveThreshold(gray, binary, 255, cv::ADAPTIVE_THRESH_GAUSSIAN_C,
                              cv::THRESH_BINARY, blockSize, param2);
        break;
    }
    case AdaptiveMean: {
        int blockSize = static_cast<int>(param1);
        if (blockSize < 3) blockSize = 3;
        if (blockSize % 2 == 0) blockSize += 1;
        cv::adaptiveThreshold(gray, binary, 255, cv::ADAPTIVE_THRESH_MEAN_C,
                              cv::THRESH_BINARY, blockSize, param2);
        break;
    }
    case ManualThreshold:
    default:
        cv::threshold(gray, binary, param1, 255, cv::THRESH_BINARY);
        break;
    }

    QImage result(binary.data, binary.cols, binary.rows, static_cast<int>(binary.step), QImage::Format_Grayscale8);
    return result.copy();
}
