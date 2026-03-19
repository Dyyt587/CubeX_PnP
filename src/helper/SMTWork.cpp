#include "SMTWork.h"
#include "SerialPortManager.h"

#include <QMetaObject>
#include <QThread>
#include <QTimer>
#include <QtGlobal>
#include <QDebug>

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
    
    // 响应超时定时器
    m_responseTimeoutTimer = new QObject(this);
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

void SMTWork::setSerialPortManager(SerialPortManager *manager)
{
    if (m_serialPortManager) {
        disconnect(m_serialPortManager, nullptr, this, nullptr);
    }
    m_serialPortManager = manager;
    if (m_serialPortManager) {
        connect(m_serialPortManager, &SerialPortManager::dataReceived, 
                this, &SMTWork::onSerialDataReceived, Qt::QueuedConnection);
    }
}

void SMTWork::addWorkItem(const QString &command, const QString &expectedResponse)
{
    WorkItem item;
    item.command = command;
    item.expectedResponse = expectedResponse;
    m_workQueue.append(item);
}

void SMTWork::clearWorkQueue()
{
    m_workQueue.clear();
    m_currentWorkItemIndex = -1;
    m_paused = false;
    if (m_waitingForResponse) {
        m_waitingForResponse = false;
        emit waitingForResponseChanged();
    }

    if (auto *timer = qobject_cast<QTimer *>(m_responseTimeoutTimer)) {
        timer->stop();
        timer->deleteLater();
    }
    m_responseTimeoutTimer = nullptr;
}

int SMTWork::queuedItemCount() const
{
    return m_workQueue.count();
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
    
    // 如果有工作队列，开始处理
    if (!m_workQueue.isEmpty() && !m_waitingForResponse && !m_paused) {
        if (m_currentWorkItemIndex < 0 || m_currentWorkItemIndex >= m_workQueue.count()) {
            m_currentWorkItemIndex = 0;
        }
        processNextWorkItem();
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

void SMTWork::onSerialDataReceived(const QString &data)
{
    if (!m_waitingForResponse || m_currentWorkItemIndex < 0 || 
        m_currentWorkItemIndex >= m_workQueue.count()) {
        qDebug() << "[SMTWork] Received data but not waiting for response:" << data;
        return;
    }

    const WorkItem &item = m_workQueue[m_currentWorkItemIndex];
    
    qDebug() << "[SMTWork] Received data:" << data;
    qDebug() << "[SMTWork] Looking for:" << item.expectedResponse;
    qDebug() << "[SMTWork] Current command index:" << m_currentWorkItemIndex;
    
    // 检查响应是否包含期望的内容（不区分大小写）
    if (data.contains(item.expectedResponse, Qt::CaseInsensitive)) {
        const int completedIndex = m_currentWorkItemIndex;

        // 收到期望的响应
        qDebug() << "[SMTWork] ✓ Received expected response for command at index" << m_currentWorkItemIndex;
        emit responseReceived(data);
        
        m_waitingForResponse = false;
        emit waitingForResponseChanged();
        
        // 清理超时定时器
        if (auto *timer = qobject_cast<QTimer *>(m_responseTimeoutTimer)) {
            timer->stop();
            timer->deleteLater();
            m_responseTimeoutTimer = nullptr;
        }
        
        // 处理下一个项目
        m_currentWorkItemIndex++;
        if (m_currentWorkItemIndex < m_workQueue.count()) {
            qDebug() << "[SMTWork] Processing next work item:" << m_currentWorkItemIndex;
            // 延迟处理，确保信号都发出去了
            QTimer::singleShot(50, this, &SMTWork::processNextWorkItem);
        } else {
            // 队列完成
            m_currentWorkItemIndex = -1;
            qDebug() << "[SMTWork] ✓ All work items completed";
            emit workQueueCompleted();
        }

        // 异步发出完成信号，避免重入修改队列状态导致索引错乱
        QTimer::singleShot(0, this, [this, completedIndex]() {
            emit workItemCompleted(completedIndex);
        });
    } else {
        // 响应与期望不符，但可能后续会收到正确的响应
        qDebug() << "[SMTWork] ✗ Response mismatch. Received:" << data << "Expected:" << item.expectedResponse;
    }
}

void SMTWork::onResponseTimeout()
{
    if (!m_waitingForResponse || m_currentWorkItemIndex < 0 || 
        m_currentWorkItemIndex >= m_workQueue.count()) {
        return;
    }

    const WorkItem &item = m_workQueue[m_currentWorkItemIndex];
    qDebug() << "[SMTWork] Response timeout for command:" << item.command;
    emit timeoutOccurred(item.command);
    
    m_waitingForResponse = false;
    emit waitingForResponseChanged();
    
    // 清理超时定时器
    if (auto *timer = qobject_cast<QTimer *>(m_responseTimeoutTimer)) {
        timer->stop();
    }
    
    // 暂停队列处理，不自动跳过
    // 需要用户手动调用 retryCurrentItem() 或 skipCurrentItem()
    m_paused = true;
    qDebug() << "[SMTWork] Queue paused due to timeout at index" << m_currentWorkItemIndex;
    emit queuePaused(m_currentWorkItemIndex, item.command);
}

void SMTWork::processNextWorkItem()
{
    if (m_currentWorkItemIndex < 0 || m_currentWorkItemIndex >= m_workQueue.count()) {
        qWarning() << "[SMTWork] Invalid work index:" << m_currentWorkItemIndex
                   << "queue size:" << m_workQueue.count();
        return;
    }

    if (!m_serialPortManager || !m_serialPortManager->isConnected()) {
        qWarning() << "[SMTWork] Serial port not connected, cannot send command at index"
                   << m_currentWorkItemIndex;
        m_paused = true;
        emit queuePaused(m_currentWorkItemIndex, m_workQueue[m_currentWorkItemIndex].command);
        return;
    }

    sendCurrentCommand();
}

void SMTWork::sendCurrentCommand()
{
    if (m_currentWorkItemIndex < 0 || m_currentWorkItemIndex >= m_workQueue.count()) {
        return;
    }

    const WorkItem &item = m_workQueue[m_currentWorkItemIndex];
    
    qDebug() << "[SMTWork] Sending command:" << item.command;
    emit commandSent(item.command);

    if (auto *oldTimer = qobject_cast<QTimer *>(m_responseTimeoutTimer)) {
        oldTimer->stop();
        oldTimer->deleteLater();
        m_responseTimeoutTimer = nullptr;
    }
    
    // 发送命令到串口
    const bool sent = m_serialPortManager->sendWithConsole(item.command);
    if (!sent) {
        qWarning() << "[SMTWork] Failed to send command:" << item.command;
        m_waitingForResponse = false;
        emit waitingForResponseChanged();
        m_paused = true;
        emit queuePaused(m_currentWorkItemIndex, item.command);
        return;
    }
    
    // 标记为等待响应
    m_waitingForResponse = true;
    emit waitingForResponseChanged();
    
    // 设置超时定时器
    auto *timer = new QTimer(this);
    connect(timer, &QTimer::timeout, this, &SMTWork::onResponseTimeout);
    m_responseTimeoutTimer = timer;
    timer->setSingleShot(true);
    timer->start(m_workQueue[m_currentWorkItemIndex].timeout);
}

void SMTWork::retryCurrentItem()
{
    if (m_currentWorkItemIndex < 0 || m_currentWorkItemIndex >= m_workQueue.count()) {
        qWarning() << "[SMTWork] Cannot retry: invalid index" << m_currentWorkItemIndex;
        return;
    }
    
    m_paused = false;
    const WorkItem &item = m_workQueue[m_currentWorkItemIndex];
    qDebug() << "[SMTWork] Retrying current item at index" << m_currentWorkItemIndex << ":" << item.command;
    
    // 重新发送当前命令
    sendCurrentCommand();
}

void SMTWork::skipCurrentItem()
{
    if (m_currentWorkItemIndex < 0 || m_currentWorkItemIndex >= m_workQueue.count()) {
        qWarning() << "[SMTWork] Cannot skip: invalid index" << m_currentWorkItemIndex;
        return;
    }
    
    m_paused = false;
    const WorkItem &item = m_workQueue[m_currentWorkItemIndex];
    qDebug() << "[SMTWork] Skipping item at index" << m_currentWorkItemIndex << ":" << item.command;
    
    // 清理定时器
    if (auto *timer = qobject_cast<QTimer *>(m_responseTimeoutTimer)) {
        timer->stop();
        timer->deleteLater();
        m_responseTimeoutTimer = nullptr;
    }
    
    // 移到下一项
    m_currentWorkItemIndex++;
    if (m_currentWorkItemIndex < m_workQueue.count()) {
        qDebug() << "[SMTWork] Processing next work item after skip:" << m_currentWorkItemIndex;
        QTimer::singleShot(50, this, &SMTWork::processNextWorkItem);
    } else {
        m_currentWorkItemIndex = -1;
        qDebug() << "[SMTWork] ✓ All work items completed (after skips)";
        emit workQueueCompleted();
    }
}

#include "SMTWork.moc"
