#include "SerialPortManager.h"

#include <QMutex>
#include <QMutexLocker>
#include <QProcess>
#include <QRegularExpression>
#include <QSerialPort>
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
    m_bufferMutex(new QMutex),
    m_serialPort(new QSerialPort(this)),
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

    connect(m_serialPort, &QSerialPort::readyRead, this, [this]() {
        const QByteArray data = m_serialPort->readAll();
        if (!data.isEmpty()) {
            const QString text = QString::fromUtf8(data);
            {
                QMutexLocker locker(m_bufferMutex);
                m_receivedBuffer.append(text);
            }
            emit dataReceived(text);
            emit consoleMessage(tr("[接收] ") + text);
        }
    });
    connect(m_serialPort, &QSerialPort::errorOccurred, this, [this](QSerialPort::SerialPortError error) {
        if (error == QSerialPort::NoError) {
            return;
        }
        emit errorOccurred(m_serialPort->errorString());
        if (error == QSerialPort::ResourceError || error == QSerialPort::DeviceNotFoundError
                || error == QSerialPort::PermissionError || error == QSerialPort::OpenError) {
            if (m_serialPort->isOpen()) {
                m_serialPort->close();
                emit connectedChanged();
            }
        }
    });

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
    delete m_bufferMutex;
}

QStringList SerialPortManager::portNames() const
{
    return m_portNames;
}

bool SerialPortManager::isConnected() const
{
    return m_serialPort->isOpen();
}

void SerialPortManager::refreshPorts()
{
    emit requestScan();
}

bool SerialPortManager::connectPort(const QString &portName, int baudRate)
{
    if (portName.isEmpty()) {
        emit errorOccurred(tr("未指定串口"));
        return false;
    }

    if (m_serialPort->isOpen()) {
        m_serialPort->close();
        emit connectedChanged();
    }

    m_serialPort->setPortName(portName);
    m_serialPort->setBaudRate(baudRate);
    m_serialPort->setDataBits(QSerialPort::Data8);
    m_serialPort->setParity(QSerialPort::NoParity);
    m_serialPort->setStopBits(QSerialPort::OneStop);
    m_serialPort->setFlowControl(QSerialPort::NoFlowControl);

    if (!m_serialPort->open(QIODevice::ReadWrite)) {
        emit errorOccurred(m_serialPort->errorString());
        return false;
    }

    emit connectedChanged();
    return true;
}

void SerialPortManager::disconnectPort()
{
    if (!m_serialPort->isOpen()) {
        return;
    }
    m_serialPort->close();
    emit connectedChanged();
}

bool SerialPortManager::sendData(const QString &text)
{
    if (!m_serialPort->isOpen()) {
        emit errorOccurred(tr("串口未连接"));
        return false;
    }

    const QByteArray payload = text.toUtf8();
    const qint64 written = m_serialPort->write(payload);
    if (written < 0) {
        emit errorOccurred(m_serialPort->errorString());
        return false;
    }
    return true;
}

bool SerialPortManager::sendWithConsole(const QString &text)
{
    if (sendData(text)) {
        emit consoleMessage(tr("[发送] ") + text);
        return true;
    }
    return false;
}

QString SerialPortManager::readBufferedData()
{
    QMutexLocker locker(m_bufferMutex);
    const QString data = m_receivedBuffer;
    m_receivedBuffer.clear();
    return data;
}

void SerialPortManager::clearBufferedData()
{
    QMutexLocker locker(m_bufferMutex);
    m_receivedBuffer.clear();
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
