#include "CameraDeviceManager.h"

#include <QCameraDevice>
#include <QMediaDevices>
#include <QThread>
#include <QTimer>

namespace {
class CameraScanWorker : public QObject
{
    Q_OBJECT
public slots:
    void scan()
    {
        const QList<QCameraDevice> devices = QMediaDevices::videoInputs();
        QStringList names;
        names.reserve(devices.size());
        for (const QCameraDevice &dev : devices) {
            names.append(dev.description());
        }
        emit scanned(names);
    }
signals:
    void scanned(const QStringList &names);
};
}

CameraDeviceManager::CameraDeviceManager(QObject *parent)
    : QObject(parent),
    m_topCameraIndex(-1),
    m_bottomCameraIndex(-1),
    m_topCameraConnected(false),
    m_bottomCameraConnected(false),
    m_topCameraOpened(false),
    m_bottomCameraOpened(false),
    m_workerThread(new QThread(this)),
    m_worker(new CameraScanWorker),
    m_mediaDevices(new QMediaDevices(this)),
    m_scanTimer(new QTimer(this))
{
    auto *worker = static_cast<CameraScanWorker *>(m_worker);
    worker->moveToThread(m_workerThread);
    connect(m_workerThread, &QThread::finished, worker, &QObject::deleteLater);
    connect(this, &CameraDeviceManager::requestScan, worker, &CameraScanWorker::scan, Qt::QueuedConnection);
    connect(worker, &CameraScanWorker::scanned, this, [this](const QStringList &names) {
        updateCameraNames(names);
    }, Qt::QueuedConnection);
    m_workerThread->start();

    connect(m_mediaDevices, &QMediaDevices::videoInputsChanged, this, &CameraDeviceManager::refreshCameras);
}

CameraDeviceManager::~CameraDeviceManager()
{
    m_workerThread->quit();
    m_workerThread->wait();
}

QStringList CameraDeviceManager::cameraNames() const
{
    return m_cameraNames;
}

int CameraDeviceManager::topCameraIndex() const
{
    return m_topCameraIndex;
}

int CameraDeviceManager::bottomCameraIndex() const
{
    return m_bottomCameraIndex;
}

QString CameraDeviceManager::topCameraName() const
{
    return cameraNameByIndex(m_topCameraIndex);
}

QString CameraDeviceManager::bottomCameraName() const
{
    return cameraNameByIndex(m_bottomCameraIndex);
}

bool CameraDeviceManager::topCameraConnected() const
{
    return m_topCameraConnected;
}

bool CameraDeviceManager::bottomCameraConnected() const
{
    return m_bottomCameraConnected;
}

bool CameraDeviceManager::topCameraOpened() const
{
    return m_topCameraOpened;
}

bool CameraDeviceManager::bottomCameraOpened() const
{
    return m_bottomCameraOpened;
}

void CameraDeviceManager::refreshCameras()
{
    emit requestScan();
}

bool CameraDeviceManager::selectTopCamera(int index)
{
    if (index < 0 || index >= m_cameraNames.size()) {
        return false;
    }

    setTopCameraIndex(index);
    return true;
}

bool CameraDeviceManager::selectBottomCamera(int index)
{
    if (index < 0 || index >= m_cameraNames.size()) {
        return false;
    }

    setBottomCameraIndex(index);
    return true;
}

bool CameraDeviceManager::connectTopCamera(int index)
{
    if (index < 0 || index >= m_cameraNames.size()) {
        return false;
    }

    setTopCameraIndex(index);
    setTopCameraConnected(true);
    return true;
}

bool CameraDeviceManager::connectBottomCamera(int index)
{
    if (index < 0 || index >= m_cameraNames.size()) {
        return false;
    }

    setBottomCameraIndex(index);
    setBottomCameraConnected(true);
    return true;
}

void CameraDeviceManager::disconnectTopCamera()
{
    closeTopCamera();
    setTopCameraConnected(false);
}

void CameraDeviceManager::disconnectBottomCamera()
{
    closeBottomCamera();
    setBottomCameraConnected(false);
}

bool CameraDeviceManager::openTopCamera()
{
    if (!m_topCameraConnected || m_topCameraIndex < 0 || m_topCameraIndex >= m_cameraNames.size()) {
        return false;
    }

    setTopCameraOpened(true);
    return true;
}

bool CameraDeviceManager::openBottomCamera()
{
    if (!m_bottomCameraConnected || m_bottomCameraIndex < 0 || m_bottomCameraIndex >= m_cameraNames.size()) {
        return false;
    }

    setBottomCameraOpened(true);
    return true;
}

void CameraDeviceManager::closeTopCamera()
{
    setTopCameraOpened(false);
}

void CameraDeviceManager::closeBottomCamera()
{
    setBottomCameraOpened(false);
}

void CameraDeviceManager::startScanning()
{
    refreshCameras();
}

void CameraDeviceManager::stopScanning()
{
    m_scanTimer->stop();
}

void CameraDeviceManager::updateCameraNames(const QStringList &names)
{
    if (m_cameraNames == names) {
        return;
    }

    m_cameraNames = names;
    emit cameraNamesChanged();

    if (m_cameraNames.isEmpty()) {
        setTopCameraIndex(-1);
        setBottomCameraIndex(-1);
        disconnectTopCamera();
        disconnectBottomCamera();
        return;
    }

    if (m_topCameraIndex < 0 || m_topCameraIndex >= m_cameraNames.size()) {
        setTopCameraIndex(0);
        setTopCameraConnected(false);
        setTopCameraOpened(false);
    }

    if (m_bottomCameraIndex < 0 || m_bottomCameraIndex >= m_cameraNames.size()) {
        setBottomCameraIndex(m_cameraNames.size() > 1 ? 1 : 0);
        setBottomCameraConnected(false);
        setBottomCameraOpened(false);
    }

    if (m_cameraNames.size() > 1 && m_topCameraIndex == m_bottomCameraIndex) {
        setBottomCameraIndex(m_topCameraIndex == 0 ? 1 : 0);
        setBottomCameraConnected(false);
        setBottomCameraOpened(false);
    }
}

QString CameraDeviceManager::cameraNameByIndex(int index) const
{
    if (index < 0 || index >= m_cameraNames.size()) {
        return QString();
    }
    return m_cameraNames.at(index);
}

void CameraDeviceManager::setTopCameraIndex(int index)
{
    if (m_topCameraIndex == index) {
        return;
    }
    m_topCameraIndex = index;
    emit topCameraIndexChanged();
    emit topCameraNameChanged();
}

void CameraDeviceManager::setBottomCameraIndex(int index)
{
    if (m_bottomCameraIndex == index) {
        return;
    }
    m_bottomCameraIndex = index;
    emit bottomCameraIndexChanged();
    emit bottomCameraNameChanged();
}

void CameraDeviceManager::setTopCameraConnected(bool connected)
{
    if (m_topCameraConnected == connected) {
        return;
    }
    m_topCameraConnected = connected;
    emit topCameraConnectedChanged();
}

void CameraDeviceManager::setBottomCameraConnected(bool connected)
{
    if (m_bottomCameraConnected == connected) {
        return;
    }
    m_bottomCameraConnected = connected;
    emit bottomCameraConnectedChanged();
}

void CameraDeviceManager::setTopCameraOpened(bool opened)
{
    if (m_topCameraOpened == opened) {
        return;
    }
    m_topCameraOpened = opened;
    emit topCameraOpenedChanged();
}

void CameraDeviceManager::setBottomCameraOpened(bool opened)
{
    if (m_bottomCameraOpened == opened) {
        return;
    }
    m_bottomCameraOpened = opened;
    emit bottomCameraOpenedChanged();
}

#include "CameraDeviceManager.moc"
