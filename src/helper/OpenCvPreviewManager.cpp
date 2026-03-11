#include "OpenCvPreviewManager.h"

#include <QCamera>
#include <QMutex>
#include <QMutexLocker>
#include <QVideoFrame>

#if CUBEXPNP_ENABLE_OPENCV
#include <opencv2/imgproc.hpp>
#endif

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
        return m_topImage;
    }
    if (key == QStringLiteral("bottom")) {
        return m_bottomImage;
    }
    return QImage();
}

void OpenCvPreviewManager::processTopFrame(const QVideoFrame &frame)
{
    const QImage image = processFrameToBlackWhite(frame);
    if (image.isNull()) {
        return;
    }

    {
        QMutexLocker locker(&m_imageMutex);
        m_topImage = image;
    }
    ++m_topFrameToken;
    emit topFrameTokenChanged();
    updateTopFps();
}

void OpenCvPreviewManager::processBottomFrame(const QVideoFrame &frame)
{
    const QImage image = processFrameToBlackWhite(frame);
    if (image.isNull()) {
        return;
    }

    {
        QMutexLocker locker(&m_imageMutex);
        m_bottomImage = image;
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

QImage OpenCvPreviewManager::processFrameToBlackWhite(const QVideoFrame &frame)
{
    const QImage source = frame.toImage();
    if (source.isNull()) {
        return QImage();
    }

#if CUBEXPNP_ENABLE_OPENCV
    // const QImage rgbaImage = source.convertToFormat(QImage::Format_RGBA8888);
    // cv::Mat rgba(rgbaImage.height(), rgbaImage.width(), CV_8UC4,
    //              const_cast<uchar *>(rgbaImage.constBits()), rgbaImage.bytesPerLine());

    // cv::Mat gray;
    // cv::cvtColor(rgba, gray, cv::COLOR_RGBA2GRAY);

    // cv::Mat binary;
    // cv::threshold(gray, binary, 127, 255, cv::THRESH_BINARY);

    // QImage result(binary.data, binary.cols, binary.rows, static_cast<int>(binary.step), QImage::Format_Grayscale8);
    // return result.copy();
    QImage gray = source.convertToFormat(QImage::Format_Grayscale8);
    for (int y = 0; y < gray.height(); ++y) {
        uchar *line = gray.scanLine(y);
        for (int x = 0; x < gray.width(); ++x) {
            line[x] = line[x] > 127 ? 255 : 0;
        }
    }
    return gray;
#else
    QImage gray = source.convertToFormat(QImage::Format_Grayscale8);
    for (int y = 0; y < gray.height(); ++y) {
        uchar *line = gray.scanLine(y);
        for (int x = 0; x < gray.width(); ++x) {
            line[x] = line[x] > 127 ? 255 : 0;
        }
    }
    return gray;
#endif
}
