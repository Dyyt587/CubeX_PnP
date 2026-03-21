#pragma once

#include <QObject>
#include <QString>
#include <QSizeF>

class GerberPreviewManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString previewUrl READ previewUrl NOTIFY previewUrlChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(double boardWidthMm READ boardWidthMm NOTIFY boardSizeChanged)
    Q_PROPERTY(double boardHeightMm READ boardHeightMm NOTIFY boardSizeChanged)

public:
    explicit GerberPreviewManager(QObject *parent = nullptr);

    QString previewUrl() const;
    QString lastError() const;
    double boardWidthMm() const;
    double boardHeightMm() const;

    Q_INVOKABLE bool importGerber(const QString &fileUrlOrPath);
    bool initFromWorkspace(const QString &workspaceRoot);

signals:
    void previewUrlChanged();
    void lastErrorChanged();
    void boardSizeChanged();

private:
    void setPreviewUrl(const QString &url);
    void setLastError(const QString &error);
    void setBoardSizeMm(const QSizeF &sizeMm);

    QString previewUrl_;
    QString lastError_;
    QSizeF boardSizeMm_;
};
