#include "CameraScanManager.h"

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

CameraScanManager::CameraScanManager(QObject *parent)
    : QObject(parent),
      m_workerThread(new QThread(this)),
      m_worker(new CameraScanWorker),
      m_scanTimer(new QTimer(this))
{
    auto *worker = static_cast<CameraScanWorker *>(m_worker);
    worker->moveToThread(m_workerThread);

    connect(m_workerThread, &QThread::finished, worker, &QObject::deleteLater);
    connect(this, &CameraScanManager::requestScan, worker, &CameraScanWorker::scan, Qt::QueuedConnection);
    connect(worker, &CameraScanWorker::scanned, this, [this](const QStringList &names) {
        updateCameraNames(names);
    }, Qt::QueuedConnection);

    m_workerThread->start();

    m_scanTimer->setInterval(2000);
    connect(m_scanTimer, &QTimer::timeout, this, &CameraScanManager::refreshCameras);
    m_scanTimer->start();

    refreshCameras();
}

CameraScanManager::~CameraScanManager()
{
    if (m_workerThread) {
        m_workerThread->quit();
        m_workerThread->wait();
    }
}

QStringList CameraScanManager::cameraNames() const
{
    return m_cameraNames;
}

void CameraScanManager::refreshCameras()
{
    emit requestScan();
}

void CameraScanManager::updateCameraNames(const QStringList &names)
{
    if (m_cameraNames == names) {
        return;
    }
    m_cameraNames = names;
    emit cameraNamesChanged();
}

#include "CameraScanManager.moc"
