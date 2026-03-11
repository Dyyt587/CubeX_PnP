#pragma once

#include <QObject>
#include <QStringList>

class QTimer;

class SerialPortManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList portNames READ portNames NOTIFY portNamesChanged)

public:
    explicit SerialPortManager(QObject *parent = nullptr);

    QStringList portNames() const;

    Q_INVOKABLE void refreshPorts();

signals:
    void portNamesChanged();

private:
    void updatePortsIfChanged(const QStringList &newPorts);

private:
    QStringList m_portNames;
    QTimer *m_scanTimer;
};
