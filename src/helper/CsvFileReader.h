#ifndef CSVFILEREADER_H
#define CSVFILEREADER_H

#include <QObject>
#include <QList>
#include <QVariantList>
#include <QVariantMap>
#include <QString>
#include <QStringList>

class CsvFileReader : public QObject {
    Q_OBJECT

public:
    explicit CsvFileReader(QObject *parent = nullptr);

    Q_INVOKABLE QVariantList readCsvFile(const QString &filePath);
    Q_INVOKABLE bool writeCsvFile(const QString &filePath, const QVariantList &rows, const QStringList &headers);
    Q_INVOKABLE QStringList csvFilesInWorkingDirectory() const;
    Q_INVOKABLE QString appDataFolderPath() const;
    Q_INVOKABLE QString packageLibraryCsvPath() const;
    Q_INVOKABLE bool packageLibraryCsvExists() const;
    Q_INVOKABLE QVariantList readPackageLibraryCsv();
    Q_INVOKABLE bool writePackageLibraryCsv(const QVariantList &rows, const QStringList &headers);
    Q_INVOKABLE QString getLastError() const;

private:
    QVariantList parseCSV(const QString &content, const QStringList &headers);
    QStringList parseCSVLine(const QString &line);
    QString lastError;

signals:
    void fileParsed(const QVariantList &data);
    void parseError(const QString &error);
};

#endif // CSVFILEREADER_H
