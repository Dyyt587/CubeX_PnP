#pragma once

#include <QObject>
#include <QStringList>

class QThread;
class QTimer;

class CameraScanManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList cameraNames READ cameraNames NOTIFY cameraNamesChanged)

public:
    explicit CameraScanManager(QObject *parent = nullptr);
    ~CameraScanManager() override;

    QStringList cameraNames() const;

    Q_INVOKABLE void refreshCameras();

signals:
    void cameraNamesChanged();
    void requestScan();

private:
    void updateCameraNames(const QStringList &names);

private:
    QStringList m_cameraNames;
    QThread *m_workerThread;
    QObject *m_worker;
    QTimer *m_scanTimer;
};
