#include "CsvFileReader.h"
#include <QFile>
#include <QTextStream>
#include <QUrl>
#include <QDebug>
#include <QFileInfo>
#include <QDir>
#include <QStandardPaths>
#include <QByteArray>

static QString decodeCsvText(const QByteArray &bytes)
{
    qDebug() << "[CSV] Decoding" << bytes.size() << "bytes";
    
    if (bytes.size() >= 3
        && static_cast<unsigned char>(bytes[0]) == 0xEF
        && static_cast<unsigned char>(bytes[1]) == 0xBB
        && static_cast<unsigned char>(bytes[2]) == 0xBF) {
        qDebug() << "[CSV] Detected UTF-8 with BOM";
        return QString::fromUtf8(bytes.constData() + 3, bytes.size() - 3);
    }

    if (bytes.size() >= 2
        && static_cast<unsigned char>(bytes[0]) == 0xFF
        && static_cast<unsigned char>(bytes[1]) == 0xFE) {
        qDebug() << "[CSV] Detected UTF-16LE";
        // For UTF-16LE: BOM (2 bytes) + actual content
        int payloadSize = bytes.size() - 2;
        // Ensure even number of bytes (UTF-16 = 2 bytes per char)
        if (payloadSize % 2 == 1) {
            payloadSize--; // Drop last byte if odd
            qDebug() << "[CSV] ⚠️  Dropped odd byte from UTF-16LE payload";
        }
        
        // Decode UTF-16LE, but remove any NULL terminators that might cause truncation
        QString result = QString::fromUtf16(reinterpret_cast<const char16_t *>(bytes.constData() + 2), payloadSize / 2);
        
        // Remove embedded NULL characters which can break parsing
        result.replace(QChar('\0'), "");
        
        return result;
    }

    if (bytes.size() >= 2
        && static_cast<unsigned char>(bytes[0]) == 0xFE
        && static_cast<unsigned char>(bytes[1]) == 0xFF) {
        qDebug() << "[CSV] Detected UTF-16BE";
        const QByteArray payload = bytes.mid(2);
        QByteArray swapped;
        swapped.resize(payload.size() - (payload.size() % 2));  // Ensure even size
        for (int i = 0; i + 1 < swapped.size(); i += 2) {
            swapped[i] = payload[i + 1];
            swapped[i + 1] = payload[i];
        }
        QString result = QString::fromUtf16(reinterpret_cast<const char16_t *>(swapped.constData()), swapped.size() / 2);
        result.replace(QChar('\0'), "");
        return result;
    }

    qDebug() << "[CSV] Assuming UTF-8 (no BOM)";
    return QString::fromUtf8(bytes);
}

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

    const QByteArray rawBytes = file.readAll();
    const QString content = decodeCsvText(rawBytes);
    
    // 优先尝试使用 \r\n 分割（Windows 格式）
    QStringList contentLines;
    if (content.contains("\r\n")) {
        contentLines = content.split("\r\n");
        qDebug() << "[CSV] Split using \\r\\n (Windows format)";
    } else {
        contentLines = content.split('\n');
        qDebug() << "[CSV] Split using \\n (Unix format)";
    }
    
    // Remove empty lines only after the header
    QStringList filteredLines;
    for (const QString &line : contentLines) {
        QString trimmedLine = line.trimmed();
        if (!trimmedLine.isEmpty()) {
            filteredLines.append(trimmedLine);
        }
    }
    contentLines = filteredLines;
    
    qDebug() << "[CSV] Total lines after split:" << contentLines.length();
    
    if (contentLines.isEmpty()) {
        lastError = "File is empty";
        file.close();
        emit parseError(lastError);
        return QVariantList();
    }

    QString headerLine = contentLines.at(0).trimmed();
    if (headerLine.isEmpty()) {
        lastError = "File is empty";
        file.close();
        emit parseError(lastError);
        return QVariantList();
    }
    
    contentLines.removeFirst();  // 移除表头行

    QStringList headers = parseCSVLine(headerLine);
    qDebug() << "[CSV] Headers (" << headers.length() << "):" << headers;
    qDebug() << "[CSV] Data rows count:" << contentLines.length();

    // Find designator column index
    int designatorIndex = -1;
    for (int h = 0; h < headers.length(); ++h) {
        if (headers[h].toUpper().contains("DESIGNATOR") || headers[h].toUpper().contains("NAME")) {
            designatorIndex = h;
            break;
        }
    }
    qDebug() << "[CSV] Designator column index:" << designatorIndex;

    // Stream parsing to avoid loading huge files fully into memory.
    QVariantList result;
    int rowIndex = 1;
    const int maxRows = 200000;
    QSet<QString> seenDesignators;  // Track to detect if deduplication is happening
    
    for (const QString &rawLine : contentLines) {
        const QString line = rawLine.trimmed();
        if (line.isEmpty()) {
            qDebug() << "[CSV] Skipping empty line at index" << rowIndex;
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
        row["rowIndex"] = rowIndex;
        
        // Log designator to detect duplicates
        QString designator = designatorIndex >= 0 && designatorIndex < fields.length() ? fields[designatorIndex] : "";
        if (!designator.isEmpty()) {
            if (seenDesignators.contains(designator)) {
                qDebug() << "[CSV] WARNING: Duplicate designator found:" << designator << "at row" << rowIndex;
            }
            seenDesignators.insert(designator);
        }
        
        result.append(row);
        
        if (rowIndex <= 5 || rowIndex % 10 == 0) {
            qDebug() << "[CSV] Row" << rowIndex << "designator:" << designator << "fields:" << fields.mid(0, qMin(3, fields.length()));
        }
        
        rowIndex++;

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
    
    qDebug() << "[CSV] Parse complete: rows=" << result.length() << "headers=" << headers.length();

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

QString CsvFileReader::appDataFolderPath() const
{
    const QString base = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    const QString dataDir = QDir(base).filePath("data");
    QDir().mkpath(dataDir);
    return dataDir;
}

QString CsvFileReader::packageLibraryCsvPath() const
{
    return QDir(appDataFolderPath()).filePath("package_library.csv");
}

bool CsvFileReader::packageLibraryCsvExists() const
{
    QFileInfo info(packageLibraryCsvPath());
    return info.exists() && info.isFile();
}

QVariantList CsvFileReader::readPackageLibraryCsv()
{
    if (!packageLibraryCsvExists()) {
        lastError = QString("Package library file not found: %1").arg(packageLibraryCsvPath());
        return QVariantList();
    }
    return readCsvFile(packageLibraryCsvPath());
}

bool CsvFileReader::writePackageLibraryCsv(const QVariantList &rows, const QStringList &headers)
{
    return writeCsvFile(packageLibraryCsvPath(), rows, headers);
}

QString CsvFileReader::getLastError() const
{
    return lastError;
}
