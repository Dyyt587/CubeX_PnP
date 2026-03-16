#include "SMTWork.h"

#include <QtGlobal>

SMTWork::SMTWork(QObject *parent)
    : QObject(parent)
{
    m_timer.setSingleShot(false);
    m_timer.setInterval(m_intervalMs);

    connect(&m_timer, &QTimer::timeout, this, [this]() {
        emit tick();
    });
}

void SMTWork::setIntervalMs(int intervalMs)
{
    const int bounded = qMax(1, intervalMs);
    if (m_intervalMs == bounded) {
        return;
    }

    m_intervalMs = bounded;
    m_timer.setInterval(m_intervalMs);
    emit intervalMsChanged();
}

void SMTWork::start()
{
    if (!m_timer.isActive()) {
        m_timer.start();
    }
    if (!m_running) {
        m_running = true;
        emit runningChanged();
    }
}

void SMTWork::pause()
{
    if (m_timer.isActive()) {
        m_timer.stop();
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
    emit tick();
}
