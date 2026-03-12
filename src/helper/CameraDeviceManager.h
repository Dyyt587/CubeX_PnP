#pragma once

#include <QObject>
#include <QStringList>

class QMediaDevices;
class QThread;
class QTimer;

class CameraDeviceManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QStringList cameraNames READ cameraNames NOTIFY cameraNamesChanged)
    Q_PROPERTY(int topCameraIndex READ topCameraIndex NOTIFY topCameraIndexChanged)
    Q_PROPERTY(int bottomCameraIndex READ bottomCameraIndex NOTIFY bottomCameraIndexChanged)
    Q_PROPERTY(QString topCameraName READ topCameraName NOTIFY topCameraNameChanged)
    Q_PROPERTY(QString bottomCameraName READ bottomCameraName NOTIFY bottomCameraNameChanged)
    Q_PROPERTY(bool topCameraConnected READ topCameraConnected NOTIFY topCameraConnectedChanged)
    Q_PROPERTY(bool bottomCameraConnected READ bottomCameraConnected NOTIFY bottomCameraConnectedChanged)
    Q_PROPERTY(bool topCameraOpened READ topCameraOpened NOTIFY topCameraOpenedChanged)
    Q_PROPERTY(bool bottomCameraOpened READ bottomCameraOpened NOTIFY bottomCameraOpenedChanged)

public:
    explicit CameraDeviceManager(QObject *parent = nullptr);
    ~CameraDeviceManager() override;

    QStringList cameraNames() const;
    int topCameraIndex() const;
    int bottomCameraIndex() const;
    QString topCameraName() const;
    QString bottomCameraName() const;
    bool topCameraConnected() const;
    bool bottomCameraConnected() const;
    bool topCameraOpened() const;
    bool bottomCameraOpened() const;

    Q_INVOKABLE void refreshCameras();
    Q_INVOKABLE bool selectTopCamera(int index);
    Q_INVOKABLE bool selectBottomCamera(int index);
    Q_INVOKABLE bool connectTopCamera(int index);
    Q_INVOKABLE bool connectBottomCamera(int index);
    Q_INVOKABLE void disconnectTopCamera();
    Q_INVOKABLE void disconnectBottomCamera();
    Q_INVOKABLE bool openTopCamera();
    Q_INVOKABLE bool openBottomCamera();
    Q_INVOKABLE void closeTopCamera();
    Q_INVOKABLE void closeBottomCamera();
    Q_INVOKABLE void startScanning();
    Q_INVOKABLE void stopScanning();

signals:
    void cameraNamesChanged();
    void topCameraIndexChanged();
    void bottomCameraIndexChanged();
    void topCameraNameChanged();
    void bottomCameraNameChanged();
    void topCameraConnectedChanged();
    void bottomCameraConnectedChanged();
    void topCameraOpenedChanged();
    void bottomCameraOpenedChanged();
    void requestScan();

private:
    void updateCameraNames(const QStringList &names);
    QString cameraNameByIndex(int index) const;
    void setTopCameraIndex(int index);
    void setBottomCameraIndex(int index);
    void setTopCameraConnected(bool connected);
    void setBottomCameraConnected(bool connected);
    void setTopCameraOpened(bool opened);
    void setBottomCameraOpened(bool opened);

private:
    QStringList m_cameraNames;
    int m_topCameraIndex;
    int m_bottomCameraIndex;
    bool m_topCameraConnected;
    bool m_bottomCameraConnected;
    bool m_topCameraOpened;
    bool m_bottomCameraOpened;
    QThread *m_workerThread;
    QObject *m_worker;
    QMediaDevices *m_mediaDevices;
    QTimer *m_scanTimer;
};
