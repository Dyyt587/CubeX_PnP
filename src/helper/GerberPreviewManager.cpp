#include "GerberPreviewManager.h"

#include <QDir>
#include <QFileInfo>
#include <QDateTime>
#include <QUrl>

#include "GerberPreviewRenderer.h"

GerberPreviewManager::GerberPreviewManager(QObject *parent)
    : QObject(parent)
{
}

QString GerberPreviewManager::previewUrl() const
{
    return previewUrl_;
}

QString GerberPreviewManager::lastError() const
{
    return lastError_;
}

double GerberPreviewManager::boardWidthMm() const
{
    return boardSizeMm_.width();
}

double GerberPreviewManager::boardHeightMm() const
{
    return boardSizeMm_.height();
}

bool GerberPreviewManager::initFromWorkspace(const QString &workspaceRoot)
{
    const QString outputPath = QDir(workspaceRoot).filePath("out/gerber_preview.png");
    QString error;
    QSizeF boardSize;
    const QString rendered = renderWorkspaceGerberPreview(workspaceRoot, outputPath, &error, &boardSize);
    if (rendered.isEmpty()) {
        setLastError(error);
        return false;
    }

    setBoardSizeMm(boardSize);
    setPreviewUrl(QUrl::fromLocalFile(rendered).toString() + "?t=" + QString::number(QDateTime::currentMSecsSinceEpoch()));
    setLastError(QString());
    return true;
}

bool GerberPreviewManager::importGerber(const QString &fileUrlOrPath)
{
    QString input = fileUrlOrPath;
    if (input.startsWith("file:///")) {
        input = QUrl(input).toLocalFile();
    }

    QString error;
    const QString outputPath = QDir::current().filePath("out/gerber_preview.png");
    QSizeF boardSize;
    const QString rendered = renderGerberPreviewFromInput(input, outputPath, &error, &boardSize);
    if (rendered.isEmpty()) {
        setLastError(error.isEmpty() ? QStringLiteral("Gerber import failed") : error);
        return false;
    }

    setBoardSizeMm(boardSize);
    setPreviewUrl(QUrl::fromLocalFile(rendered).toString() + "?t=" + QString::number(QDateTime::currentMSecsSinceEpoch()));
    setLastError(QString());
    return true;
}

void GerberPreviewManager::setPreviewUrl(const QString &url)
{
    if (previewUrl_ == url) {
        return;
    }
    previewUrl_ = url;
    emit previewUrlChanged();
}

void GerberPreviewManager::setLastError(const QString &error)
{
    if (lastError_ == error) {
        return;
    }
    lastError_ = error;
    emit lastErrorChanged();
}

void GerberPreviewManager::setBoardSizeMm(const QSizeF &sizeMm)
{
    if (boardSizeMm_ == sizeMm) {
        return;
    }
    boardSizeMm_ = sizeMm;
    emit boardSizeChanged();
}
