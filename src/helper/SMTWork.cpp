#include "SMTWork.h"

#include <QMetaObject>
#include <QThread>
#include <QTimer>
#include <QtGlobal>

namespace {
class SMTWorkWorker : public QObject
{
    Q_OBJECT

public:
    explicit SMTWorkWorker(int intervalMs)
    {
        m_timer = new QTimer(this);
        m_timer->setSingleShot(false);
        m_timer->setInterval(intervalMs);
        connect(m_timer, &QTimer::timeout, this, &SMTWorkWorker::tick);
    }

public slots:
    void setIntervalMs(int intervalMs)
    {
        if (m_timer) {
            m_timer->setInterval(intervalMs);
        }
    }

    void start()
    {
        if (m_timer && !m_timer->isActive()) {
            m_timer->start();
        }
    }

    void pause()
    {
        if (m_timer && m_timer->isActive()) {
            m_timer->stop();
        }
    }

    void stop()
    {
        pause();
    }

    void stepOnce()
    {
        emit tick();
    }

signals:
    void tick();

private:
    QTimer *m_timer = nullptr;
};
}

SMTWork::SMTWork(QObject *parent)
    : QObject(parent)
{
    m_workerThread = new QThread(this);
    m_worker = new SMTWorkWorker(m_intervalMs);
    m_worker->moveToThread(m_workerThread);
    connect(m_workerThread, &QThread::finished, m_worker, &QObject::deleteLater);
    connect(m_worker, SIGNAL(tick()), this, SIGNAL(tick()), Qt::QueuedConnection);
    m_workerThread->start();
}

SMTWork::~SMTWork()
{
    if (m_workerThread) {
        m_workerThread->quit();
        m_workerThread->wait();
    }
}

void SMTWork::setIntervalMs(int intervalMs)
{
    const int bounded = qMax(1, intervalMs);
    if (m_intervalMs == bounded) {
        return;
    }

    m_intervalMs = bounded;
    if (m_worker) {
        QMetaObject::invokeMethod(m_worker, "setIntervalMs", Qt::QueuedConnection, Q_ARG(int, m_intervalMs));
    }
    emit intervalMsChanged();
}

void SMTWork::start()
{
    if (m_worker) {
        QMetaObject::invokeMethod(m_worker, "start", Qt::QueuedConnection);
    }
    if (!m_running) {
        m_running = true;
        emit runningChanged();
    }
}

void SMTWork::pause()
{
    if (m_worker) {
        QMetaObject::invokeMethod(m_worker, "pause", Qt::QueuedConnection);
    }
    if (m_running) {
        m_running = false;
        emit runningChanged();
    }
}

void SMTWork::stop()
{
    pause();
}

void SMTWork::stepOnce()
{
    if (m_worker) {
        QMetaObject::invokeMethod(m_worker, "stepOnce", Qt::QueuedConnection);
    }
}

#include "SMTWork.moc"
