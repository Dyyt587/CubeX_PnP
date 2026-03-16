#pragma once

#include <QObject>

class QThread;
class QObject;

class SMTWork : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool running READ running NOTIFY runningChanged)
    Q_PROPERTY(int intervalMs READ intervalMs WRITE setIntervalMs NOTIFY intervalMsChanged)

public:
    explicit SMTWork(QObject *parent = nullptr);
    ~SMTWork() override;

    bool running() const { return m_running; }
    int intervalMs() const { return m_intervalMs; }

    void setIntervalMs(int intervalMs);

    Q_INVOKABLE void start();
    Q_INVOKABLE void pause();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void stepOnce();

signals:
    void runningChanged();
    void intervalMsChanged();
    void tick();

private:
    QObject *m_worker = nullptr;
    QThread *m_workerThread = nullptr;
    bool m_running = false;
    int m_intervalMs = 2000;
};
