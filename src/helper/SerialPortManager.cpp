#include "SerialPortManager.h"

#include <QProcess>
#include <QRegularExpression>
#include <QTimer>

SerialPortManager::SerialPortManager(QObject *parent)
    : QObject(parent),
      m_scanTimer(new QTimer(this))
{
    m_scanTimer->setInterval(2000);
    connect(m_scanTimer, &QTimer::timeout, this, &SerialPortManager::refreshPorts);
    m_scanTimer->start();
    refreshPorts();
}

QStringList SerialPortManager::portNames() const
{
    return m_portNames;
}

void SerialPortManager::refreshPorts()
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
    updatePortsIfChanged(ports);
}

void SerialPortManager::updatePortsIfChanged(const QStringList &newPorts)
{
    if (m_portNames == newPorts) {
        return;
    }
    m_portNames = newPorts;
    emit portNamesChanged();
}
