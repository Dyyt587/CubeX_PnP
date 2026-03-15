#pragma once

#include <QObject>
#include <QStringList>

class QMutex;

class QThread;
class QTimer;
class QSerialPort;

class SerialPortManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList portNames READ portNames NOTIFY portNamesChanged)
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectedChanged)

public:
    explicit SerialPortManager(QObject *parent = nullptr);
    ~SerialPortManager() override;

    QStringList portNames() const;
    bool isConnected() const;

    Q_INVOKABLE void refreshPorts();
    Q_INVOKABLE bool connectPort(const QString &portName, int baudRate);
    Q_INVOKABLE void disconnectPort();
    Q_INVOKABLE bool sendData(const QString &text);

public slots:
    bool sendWithConsole(const QString &text);
    QString readBufferedData();
    void clearBufferedData();

signals:
    void portNamesChanged();
    void connectedChanged();
    void dataReceived(const QString &text);
    void consoleMessage(const QString &message);
    void errorOccurred(const QString &message);
    void requestScan();

private:
    void updatePortsIfChanged(const QStringList &newPorts);

private:
    QStringList m_portNames;
    QString m_receivedBuffer;
    QMutex *m_bufferMutex;
    QSerialPort *m_serialPort;
    QThread *m_workerThread;
    QObject *m_worker;
    QTimer *m_scanTimer;
};
