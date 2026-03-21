#include "CsvFileReader.h"
#include <QFile>
#include <QTextStream>
#include <QUrl>
#include <QDebug>
#include <QFileInfo>
#include <QDir>

static QString csvEscapeField(const QString &input)
{
    QString field = input;
    const bool mustQuote = field.contains(',') || field.contains('"') || field.contains('\n') || field.contains('\r') || field.contains('\t');
    field.replace('"', "\"\"");
    return mustQuote ? QString("\"%1\"").arg(field) : field;
}

CsvFileReader::CsvFileReader(QObject *parent)
    : QObject(parent)
{
}

QStringList CsvFileReader::parseCSVLine(const QString &line)
{
    QStringList fields;
    QString field;
    bool insideQuotes = false;

    for (int i = 0; i < line.length(); ++i) {
        const QChar &c = line[i];

        if (c == '"') {
            insideQuotes = !insideQuotes;
        } else if (c == '\t' && !insideQuotes) {  // Use tab as delimiter (common in CSV)
            fields.append(field);
            field.clear();
        } else if (c == ',' && !insideQuotes) {   // Also support comma as delimiter
            fields.append(field);
            field.clear();
        } else {
            field.append(c);
        }
    }

    fields.append(field);
    return fields;
}

QVariantList CsvFileReader::parseCSV(const QString &content, const QStringList &headers)
{
    QVariantList result;
    QStringList lines = content.split('\n', Qt::SkipEmptyParts);

    if (lines.isEmpty() || headers.isEmpty()) {
        return result;
    }

    for (int i = 0; i < lines.length(); ++i) {
        const QString &line = lines[i].trimmed();
        if (line.isEmpty()) continue;

        QStringList fields = parseCSVLine(line);

        // Ensure we have enough fields
        while (fields.length() < headers.length()) {
            fields.append("");
        }

        QVariantMap row;
        for (int j = 0; j < headers.length() && j < fields.length(); ++j) {
            row[headers[j]] = fields[j].trimmed();
        }

        // Add index
        row["rowIndex"] = i + 1;
        result.append(row);
    }

    return result;
}

QVariantList CsvFileReader::readCsvFile(const QString &filePath)
{
    lastError.clear();

    // Convert file URL to local path
    QString localPath = filePath;
    if (filePath.startsWith("file:///")) {
        localPath = QUrl(filePath).toLocalFile();
    }

    QFileInfo fileInfo(localPath);
    if (fileInfo.suffix().toLower() != "csv") {
        lastError = QString("Unsupported file type: %1").arg(fileInfo.suffix());
        emit parseError(lastError);
        qWarning() << "CsvFileReader:" << lastError;
        return QVariantList();
    }

    QFile file(localPath);
    if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        lastError = QString("Failed to open file: %1").arg(localPath);
        emit parseError(lastError);
        qWarning() << "CsvFileReader:" << lastError;
        return QVariantList();
    }

    QTextStream in(&file);
    in.setEncoding(QStringConverter::Utf8);

    // Read header line
    QString headerLine = in.readLine();
    if (headerLine.isEmpty()) {
        lastError = "File is empty";
        file.close();
        emit parseError(lastError);
        return QVariantList();
    }

    QStringList headers = parseCSVLine(headerLine);

    // Stream parsing to avoid loading huge files fully into memory.
    QVariantList result;
    int rowIndex = 1;
    const int maxRows = 200000;
    while (!in.atEnd()) {
        const QString line = in.readLine().trimmed();
        if (line.isEmpty()) {
            continue;
        }

        QStringList fields = parseCSVLine(line);
        while (fields.length() < headers.length()) {
            fields.append("");
        }

        QVariantMap row;
        for (int j = 0; j < headers.length() && j < fields.length(); ++j) {
            row[headers[j]] = fields[j].trimmed();
        }
        row["rowIndex"] = rowIndex++;
        result.append(row);

        if (result.size() >= maxRows) {
            lastError = QString("CSV rows exceed limit (%1)").arg(maxRows);
            emit parseError(lastError);
            qWarning() << "CsvFileReader:" << lastError;
            break;
        }
    }

    file.close();

    if (result.isEmpty()) {
        lastError = "No data rows found";
    }

    emit fileParsed(result);
    return result;
}

bool CsvFileReader::writeCsvFile(const QString &filePath, const QVariantList &rows, const QStringList &headers)
{
    lastError.clear();

    QString localPath = filePath;
    if (filePath.startsWith("file:///")) {
        localPath = QUrl(filePath).toLocalFile();
    }

    if (localPath.trimmed().isEmpty()) {
        lastError = "Invalid file path";
        emit parseError(lastError);
        return false;
    }

    QFileInfo info(localPath);
    QDir().mkpath(info.absolutePath());

    QFile file(localPath);
    if (!file.open(QIODevice::WriteOnly | QIODevice::Text | QIODevice::Truncate)) {
        lastError = QString("Failed to write file: %1").arg(localPath);
        emit parseError(lastError);
        qWarning() << "CsvFileReader:" << lastError;
        return false;
    }

    QTextStream out(&file);
    out.setEncoding(QStringConverter::Utf8);

    QStringList finalHeaders = headers;
    if (finalHeaders.isEmpty() && !rows.isEmpty()) {
        const QVariantMap first = rows.first().toMap();
        finalHeaders = first.keys();
    }

    if (finalHeaders.isEmpty()) {
        lastError = "No headers for CSV export";
        file.close();
        emit parseError(lastError);
        return false;
    }

    QStringList escapedHeaders;
    escapedHeaders.reserve(finalHeaders.size());
    for (const QString &header : finalHeaders) {
        escapedHeaders.append(csvEscapeField(header));
    }
    out << escapedHeaders.join(',') << '\n';

    for (const QVariant &rowVar : rows) {
        const QVariantMap row = rowVar.toMap();
        QStringList fields;
        fields.reserve(finalHeaders.size());
        for (const QString &key : finalHeaders) {
            fields.append(csvEscapeField(row.value(key).toString()));
        }
        out << fields.join(',') << '\n';
    }

    file.close();
    return true;
}

QStringList CsvFileReader::csvFilesInWorkingDirectory() const
{
    QDir dir(QDir::currentPath());
    QStringList filters;
    filters << "*.csv" << "*.CSV";

    const QFileInfoList files = dir.entryInfoList(filters, QDir::Files, QDir::Name);
    QStringList result;
    result.reserve(files.size());

    for (const QFileInfo &info : files) {
        result.append(info.absoluteFilePath());
    }
    return result;
}

QString CsvFileReader::getLastError() const
{
    return lastError;
}
