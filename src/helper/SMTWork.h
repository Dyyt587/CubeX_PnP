#pragma once

#include <QObject>
#include <QString>
#include <QList>

class QThread;
class QObject;
class SerialPortManager;

// 单个工作项，可以包含串口命令
struct WorkItem {
    QString command;  // 要发送的命令
    QString expectedResponse;  // 期望的响应（如 "ok"）
    int timeout = 5000;  // 超时时间（毫秒）
};

class SMTWork : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(int intervalMs READ intervalMs WRITE setIntervalMs NOTIFY intervalMsChanged)
    Q_PROPERTY(bool waitingForResponse READ waitingForResponse NOTIFY waitingForResponseChanged)

public:
    explicit SMTWork(QObject *parent = nullptr);
    ~SMTWork() override;

    bool running() const { return m_running; }
    int intervalMs() const { return m_intervalMs; }
    bool waitingForResponse() const { return m_waitingForResponse; }

    void setIntervalMs(int intervalMs);
    void setSerialPortManager(SerialPortManager *manager);

    // 添加工作项到队列
    Q_INVOKABLE void addWorkItem(const QString &command, const QString &expectedResponse = "ok");
    Q_INVOKABLE void clearWorkQueue();
    Q_INVOKABLE int queuedItemCount() const;

    Q_INVOKABLE void start();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void stepOnce();
    
    // 当响应超时时的恢复操作
    Q_INVOKABLE void retryCurrentItem();  // 重试当前项
    Q_INVOKABLE void skipCurrentItem();   // 跳过当前项，继续处理下一项

signals:
    void runningChanged();
    void intervalMsChanged();
    void waitingForResponseChanged();
    void tick();
    void commandSent(const QString &command);
    void responseReceived(const QString &response);
    void workQueueCompleted();
    void workItemCompleted(int index);
    void timeoutOccurred(const QString &command);
    void queuePaused(int itemIndex, const QString &command);  // 队列暂停信号

private slots:
    void onSerialDataReceived(const QString &data);
    void onResponseTimeout();

private:
    void processNextWorkItem();
    void sendCurrentCommand();

    QObject *m_worker = nullptr;
    QThread *m_workerThread = nullptr;
    bool m_running = false;
    int m_intervalMs = 2000;
    bool m_waitingForResponse = false;
    SerialPortManager *m_serialPortManager = nullptr;
    
    // 工作队列
    QList<WorkItem> m_workQueue;
    int m_currentWorkItemIndex = -1;
    QObject *m_responseTimeoutTimer = nullptr;
    
    // 队列暂停状态
    bool m_paused = false;
};
