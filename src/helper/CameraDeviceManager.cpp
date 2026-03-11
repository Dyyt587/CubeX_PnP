#include "CameraDeviceManager.h"

#include <QProcess>
#include <QRegularExpression>
#include <QThread>
#include <QTimer>

namespace {
class CameraScanWorker : public QObject
{
    Q_OBJECT

public slots:
    void scan()
    {
        QProcess process;
        process.start("powershell", {
                                       "-NoProfile",
                                       "-Command",
                                       "Get-CimInstance Win32_PnPEntity | Where-Object { $_.PNPClass -in @('Camera','Image') } | Select-Object -ExpandProperty Name"
                                   });

        QStringList cameraNames;
        if (process.waitForFinished(3000)) {
            const QString output = QString::fromLocal8Bit(process.readAllStandardOutput());
            const QStringList lines = output.split(QRegularExpression("[\\r\\n]+"), Qt::SkipEmptyParts);
            for (const QString &line : lines) {
                const QString value = line.trimmed();
                if (!value.isEmpty()) {
                    cameraNames.append(value);
                }
            }
        }

        cameraNames.removeDuplicates();
        cameraNames.sort(Qt::CaseInsensitive);
        emit scanned(cameraNames);
    }

signals:
    void scanned(const QStringList &cameraNames);
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

    m_scanTimer->setInterval(1000);
    connect(m_scanTimer, &QTimer::timeout, this, &CameraDeviceManager::refreshCameras);
}

CameraDeviceManager::~CameraDeviceManager()
{
    if (m_workerThread) {
        m_workerThread->quit();
        m_workerThread->wait();
    }
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
    if (!m_scanTimer->isActive()) {
        m_scanTimer->start();
        refreshCameras();
    }
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
