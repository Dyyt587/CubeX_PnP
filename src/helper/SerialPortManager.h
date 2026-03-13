#pragma once

#include <QObject>
#include <QStringList>

class QThread;
class QTimer;

class SerialPortManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList portNames READ portNames NOTIFY portNamesChanged)

public:
    explicit SerialPortManager(QObject *parent = nullptr);
    ~SerialPortManager() override;

    QStringList portNames() const;

    Q_INVOKABLE void refreshPorts();

signals:
    void portNamesChanged();
    void requestScan();

private:
    void updatePortsIfChanged(const QStringList &newPorts);

private:
    QStringList m_portNames;
    QThread *m_workerThread;
    QObject *m_worker;
    QTimer *m_scanTimer;
};
