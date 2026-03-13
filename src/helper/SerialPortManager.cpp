#include "SerialPortManager.h"

#include <QProcess>
#include <QRegularExpression>
#include <QThread>
#include <QTimer>

namespace {
class SerialScanWorker : public QObject
{
    Q_OBJECT

public slots:
    void scan()
    {
        QStringList ports;
        QProcess process;
        process.start("powershell", {"-NoProfile", "-Command", "[System.IO.Ports.SerialPort]::GetPortNames()"});
        if (process.waitForFinished(2000)) {
            const QString output = QString::fromLocal8Bit(process.readAllStandardOutput());
            const QStringList lines = output.split(QRegularExpression("[\\r\\n]+"), Qt::SkipEmptyParts);
            for (const QString &line : lines) {
                const QString port = line.trimmed();
                if (!port.isEmpty()) {
                    ports.append(port);
                }
            }
        }
        ports.sort(Qt::CaseInsensitive);
        ports.removeDuplicates();
        emit scanned(ports);
    }

signals:
    void scanned(const QStringList &ports);
};
}

SerialPortManager::SerialPortManager(QObject *parent)
    : QObject(parent),
      m_workerThread(new QThread(this)),
      m_worker(new SerialScanWorker),
      m_scanTimer(new QTimer(this))
{
    auto *worker = static_cast<SerialScanWorker *>(m_worker);
    worker->moveToThread(m_workerThread);
    connect(m_workerThread, &QThread::finished, worker, &QObject::deleteLater);
    connect(this, &SerialPortManager::requestScan, worker, &SerialScanWorker::scan, Qt::QueuedConnection);
    connect(worker, &SerialScanWorker::scanned, this, [this](const QStringList &ports) {
        updatePortsIfChanged(ports);
    }, Qt::QueuedConnection);
    m_workerThread->start();

    m_scanTimer->setInterval(2000);
    connect(m_scanTimer, &QTimer::timeout, this, &SerialPortManager::refreshPorts);
    m_scanTimer->start();
    refreshPorts();
}

SerialPortManager::~SerialPortManager()
{
    if (m_workerThread) {
        m_workerThread->quit();
        m_workerThread->wait();
    }
}

QStringList SerialPortManager::portNames() const
{
    return m_portNames;
}

void SerialPortManager::refreshPorts()
{
    emit requestScan();
}

void SerialPortManager::updatePortsIfChanged(const QStringList &newPorts)
{
    if (m_portNames == newPorts) {
        return;
    }
    m_portNames = newPorts;
    emit portNamesChanged();
}

#include "SerialPortManager.moc"
