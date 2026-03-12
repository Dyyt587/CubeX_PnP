#include "OpenCvPreviewManager.h"

#include <QCamera>
#include <QMutex>
#include <QMutexLocker>
#include <QVideoFrame>

#include <opencv2/imgproc.hpp>

#include <QtConcurrent/QtConcurrent>

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

OpenCvPreviewManager::~OpenCvPreviewManager()
{
    // Wait for any in-flight tasks to finish
    while (m_topBusy.loadAcquire() || m_bottomBusy.loadAcquire()) {
        QThread::msleep(1);
    }
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

double OpenCvPreviewManager::topContourMinArea() const { return m_topContourMinArea; }
void OpenCvPreviewManager::setTopContourMinArea(double v) {
    if (!qFuzzyCompare(m_topContourMinArea, v)) { m_topContourMinArea = v; emit topContourMinAreaChanged(); }
}
double OpenCvPreviewManager::bottomContourMinArea() const { return m_bottomContourMinArea; }
void OpenCvPreviewManager::setBottomContourMinArea(double v) {
    if (!qFuzzyCompare(m_bottomContourMinArea, v)) { m_bottomContourMinArea = v; emit bottomContourMinAreaChanged(); }
}
double OpenCvPreviewManager::topContourMaxArea() const { return m_topContourMaxArea; }
void OpenCvPreviewManager::setTopContourMaxArea(double v) {
    if (!qFuzzyCompare(m_topContourMaxArea, v)) { m_topContourMaxArea = v; emit topContourMaxAreaChanged(); }
}
double OpenCvPreviewManager::bottomContourMaxArea() const { return m_bottomContourMaxArea; }
void OpenCvPreviewManager::setBottomContourMaxArea(double v) {
    if (!qFuzzyCompare(m_bottomContourMaxArea, v)) { m_bottomContourMaxArea = v; emit bottomContourMaxAreaChanged(); }
}

bool OpenCvPreviewManager::topBinInvert() const { return m_topBinInvert; }
void OpenCvPreviewManager::setTopBinInvert(bool v) {
    if (m_topBinInvert != v) { m_topBinInvert = v; emit topBinInvertChanged(); }
}
bool OpenCvPreviewManager::bottomBinInvert() const { return m_bottomBinInvert; }
void OpenCvPreviewManager::setBottomBinInvert(bool v) {
    if (m_bottomBinInvert != v) { m_bottomBinInvert = v; emit bottomBinInvertChanged(); }
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
    // Drop frame if previous processing is still running
    if (!m_topBusy.testAndSetAcquire(0, 1)) {
        return;
    }

    const QImage source = frame.toImage();
    if (source.isNull()) {
        m_topBusy.storeRelease(0);
        return;
    }

    // Capture parameters by value for thread safety
    const auto algo = static_cast<BinAlgorithm>(m_topBinAlgorithm);
    const double param1 = m_topBinParam1;
    const double param2 = m_topBinParam2;
    const bool invert = m_topBinInvert;
    const double cMinArea = m_topContourMinArea;
    const double cMaxArea = m_topContourMaxArea;

    QtConcurrent::run([this, source, algo, param1, param2, invert, cMinArea, cMaxArea]() {
        QElapsedTimer timer;
        timer.start();

        const QImage color = cropToSquare(source);
        const QImage bw = processFrameToBlackWhite(color, algo, param1, param2, invert);
        const QImage contourImage = detectAndDrawContours(bw, color, cMinArea, cMaxArea);
        const double frameMs = timer.nsecsElapsed() / 1000000.0;

        QMetaObject::invokeMethod(this, [this, contourImage, color, frameMs,
                                         w = color.width(), h = color.height()]() {
            onTopProcessed(contourImage, color, frameMs, w, h);
        }, Qt::QueuedConnection);
    });
}

void OpenCvPreviewManager::processBottomFrame(const QVideoFrame &frame)
{
    // Drop frame if previous processing is still running
    if (!m_bottomBusy.testAndSetAcquire(0, 1)) {
        return;
    }

    const QImage source = frame.toImage();
    if (source.isNull()) {
        m_bottomBusy.storeRelease(0);
        return;
    }

    // Capture parameters by value for thread safety
    const auto algo = static_cast<BinAlgorithm>(m_bottomBinAlgorithm);
    const double param1 = m_bottomBinParam1;
    const double param2 = m_bottomBinParam2;
    const bool invert = m_bottomBinInvert;
    const double cMinArea = m_bottomContourMinArea;
    const double cMaxArea = m_bottomContourMaxArea;

    QtConcurrent::run([this, source, algo, param1, param2, invert, cMinArea, cMaxArea]() {
        QElapsedTimer timer;
        timer.start();

        const QImage color = cropToSquare(source);
        const QImage bw = processFrameToBlackWhite(color, algo, param1, param2, invert);
        const QImage contourImage = detectAndDrawContours(bw, color, cMinArea, cMaxArea);
        const double frameMs = timer.nsecsElapsed() / 1000000.0;

        QMetaObject::invokeMethod(this, [this, contourImage, color, frameMs,
                                         w = color.width(), h = color.height()]() {
            onBottomProcessed(contourImage, color, frameMs, w, h);
        }, Qt::QueuedConnection);
    });
}

void OpenCvPreviewManager::onTopProcessed(const QImage &bw, const QImage &color, double frameMs, int w, int h)
{
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
    m_topResWidth = w;
    m_topResHeight = h;

    {
        QMutexLocker locker(&m_imageMutex);
        m_topBwImage = bw;
        m_topColorImage = color;
    }
    ++m_topFrameToken;
    emit topFrameTokenChanged();
    updateTopFps();

    m_topBusy.storeRelease(0);
}

void OpenCvPreviewManager::onBottomProcessed(const QImage &bw, const QImage &color, double frameMs, int w, int h)
{
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
    m_bottomResWidth = w;
    m_bottomResHeight = h;

    {
        QMutexLocker locker(&m_imageMutex);
        m_bottomBwImage = bw;
        m_bottomColorImage = color;
    }
    ++m_bottomFrameToken;
    emit bottomFrameTokenChanged();
    updateBottomFps();

    m_bottomBusy.storeRelease(0);
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

QImage OpenCvPreviewManager::processFrameToBlackWhite(const QImage &source, BinAlgorithm algo, double param1, double param2, bool invert)
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

    if (invert) {
        cv::bitwise_not(binary, binary);
    }

    QImage result(binary.data, binary.cols, binary.rows, static_cast<int>(binary.step), QImage::Format_Grayscale8);
    return result.copy();
}

QImage OpenCvPreviewManager::detectAndDrawContours(const QImage &bwSource, const QImage &colorSource, double minArea, double maxArea)
{
    if (bwSource.isNull()) {
        return bwSource;
    }

    // Convert BW to cv::Mat for findContours
    const QImage gray = bwSource.convertToFormat(QImage::Format_Grayscale8);
    cv::Mat binaryMat(gray.height(), gray.width(), CV_8UC1,
                      const_cast<uchar *>(gray.constBits()), gray.bytesPerLine());

    std::vector<std::vector<cv::Point>> contours;
    cv::findContours(binaryMat, contours, cv::RETR_EXTERNAL, cv::CHAIN_APPROX_SIMPLE);

    // Convert BW to BGR so we can draw colored annotations
    cv::Mat display;
    cv::cvtColor(binaryMat, display, cv::COLOR_GRAY2BGR);

    // Draw reference rectangles for min/max area thresholds at image center
    const cv::Point2f center(display.cols / 2.0f, display.rows / 2.0f);
    const int minSide = static_cast<int>(std::sqrt(minArea));
    const int maxSide = static_cast<int>(std::sqrt(maxArea));
    // Dark blue for min area
    cv::rectangle(display,
                  cv::Point(static_cast<int>(center.x) - minSide / 2, static_cast<int>(center.y) - minSide / 2),
                  cv::Point(static_cast<int>(center.x) + minSide / 2, static_cast<int>(center.y) + minSide / 2),
                  cv::Scalar(255, 100, 50), 8);
    // Light blue for max area
    cv::rectangle(display,
                  cv::Point(static_cast<int>(center.x) - maxSide / 2, static_cast<int>(center.y) - maxSide / 2),
                  cv::Point(static_cast<int>(center.x) + maxSide / 2, static_cast<int>(center.y) + maxSide / 2),
                  cv::Scalar(255, 200, 100), 8);

    for (const auto &contour : contours) {
        const double area = cv::contourArea(contour);
        if (area < minArea || area > maxArea) {
            continue;
        }

        // Multi-criteria circle detection
        const double perimeter = cv::arcLength(contour, true);
        const double circularity = (perimeter > 0) ? (4.0 * CV_PI * area / (perimeter * perimeter)) : 0;

        // Aspect ratio of bounding rect (circle ≈ 1.0)
        const cv::Rect boundRect = cv::boundingRect(contour);
        const double aspectRatio = (boundRect.height > 0)
            ? static_cast<double>(boundRect.width) / boundRect.height : 0;

        // Area fill ratio: contour area vs enclosing circle area
        float encRadius;
        cv::Point2f encCenter;
        cv::minEnclosingCircle(contour, encCenter, encRadius);
        const double encCircleArea = CV_PI * encRadius * encRadius;
        const double fillRatio = (encCircleArea > 0) ? (area / encCircleArea) : 0;

        // Circle if: circularity > 0.7, aspect ratio close to 1, fill ratio high
        const bool isCircle = (circularity > 0.7)
                           && (aspectRatio > 0.75 && aspectRatio < 1.33)
                           && (fillRatio > 0.8);

        cv::Point2f ctr;
        if (isCircle && contour.size() >= 5) {
            // Use fitEllipse for sub-pixel accuracy
            const cv::RotatedRect ellipse = cv::fitEllipse(contour);
            ctr = ellipse.center;
            const float avgRadius = (ellipse.size.width + ellipse.size.height) / 4.0f;
            cv::circle(display, cv::Point(static_cast<int>(ctr.x), static_cast<int>(ctr.y)),
                       static_cast<int>(avgRadius), cv::Scalar(0, 255, 255), 4);
        } else {
            // Non-circular: draw rotated rectangle
            cv::RotatedRect rect = cv::minAreaRect(contour);
            ctr = rect.center;
            cv::Point2f pts[4];
            rect.points(pts);
            for (int i = 0; i < 4; ++i) {
                cv::line(display, pts[i], pts[(i + 1) % 4], cv::Scalar(0, 255, 0), 4);
            }
        }

        // Draw red cross at center, size proportional to area
        const int crossSize = std::max(5, static_cast<int>(std::sqrt(area) * 0.3));
        const cv::Point c(static_cast<int>(ctr.x), static_cast<int>(ctr.y));
        cv::line(display, cv::Point(c.x - crossSize, c.y), cv::Point(c.x + crossSize, c.y),
                 cv::Scalar(0, 0, 255), 8);
        cv::line(display, cv::Point(c.x, c.y - crossSize), cv::Point(c.x, c.y + crossSize),
                 cv::Scalar(0, 0, 255), 8);
    }

    QImage result(display.data, display.cols, display.rows,
                  static_cast<int>(display.step), QImage::Format_RGB888);
    // BGR -> RGB
    return result.rgbSwapped().copy();
}
