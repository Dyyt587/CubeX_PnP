#include "CsvFileReader.h"
#include <QFile>
#include <QTextStream>
#include <QUrl>
#include <QDebug>
#include <QFileInfo>
#include <QDir>
#include <QStandardPaths>
#include <QByteArray>
#include <QRegularExpression>

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
    : QObject(parent), m_packageLibraryCacheValid(false)
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

bool CsvFileReader::isPackageLibraryCacheValid()
{
    // 检查缓存是否有效
    if (!m_packageLibraryCacheValid || m_packageLibraryCache.isEmpty()) {
        return false;
    }
    
    // 检查缓存是否过期（60秒）
    QDateTime now = QDateTime::currentDateTime();
    if (m_packageLibraryCacheTime.isValid()) {
        qint64 elapsedMs = m_packageLibraryCacheTime.msecsTo(now);
        if (elapsedMs > PACKAGE_LIBRARY_CACHE_TIMEOUT_MS) {
            qDebug() << "[PACKAGE_LIB_CACHE] Cache expired (" << elapsedMs << "ms > " << PACKAGE_LIBRARY_CACHE_TIMEOUT_MS << "ms)";
            return false;
        }
    }
    
    // 检查外部CSV文件是否修改过
    QFileInfo csvFile(packageLibraryCsvPath());
    if (csvFile.exists() && m_packageLibraryCacheTime.isValid()) {
        QDateTime fileModTime = csvFile.lastModified();
        if (fileModTime > m_packageLibraryCacheTime) {
            qDebug() << "[PACKAGE_LIB_CACHE] CSV file was modified, invalidating cache";
            return false;
        }
    }
    
    return true;
}

QVariantMap CsvFileReader::getPackageLibraryMap()
{
    qDebug().nospace() << "[PACKAGE_LIB] getPackageLibraryMap() called ====================";
    
    // 检查是否有有效的缓存
    if (isPackageLibraryCacheValid()) {
        qDebug() << "[PACKAGE_LIB_CACHE] Using cached package library (" << m_packageLibraryCache.size() << "entries)";
        return m_packageLibraryCache;
    }
    
    qDebug() << "[PACKAGE_LIB_CACHE] Cache invalid or expired, rebuilding...";
    
 QVariantMap result;
    
    // 获取应用数据路径
    QString appDataPath = appDataFolderPath();
    QString csvPath = packageLibraryCsvPath();
    QString logPath = csvPath.replace("package_library.csv", "package_parse_debug.log");
    
    qDebug() << "[PACKAGE_LIB] appDataPath:" << appDataPath;
    qDebug() << "[PACKAGE_LIB] csvPath:" << csvPath;
    qDebug() << "[PACKAGE_LIB] logPath:" << logPath;
    
    // 打开日志文件用于调试
    QFile logFile(logPath);
    if (!logFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
        qDebug() << "[PACKAGE_LIB] Failed to open log file:" << logFile.errorString();
        // Write test file to verify writability
        QFile testFile(appDataPath + "/test_write.txt");
        if (testFile.open(QIODevice::WriteOnly | QIODevice::Text)) {
            testFile.write("Test write OK\n");
            testFile.close();
            qDebug() << "[PACKAGE_LIB] Test file write succeeded at:" << appDataPath + "/test_write.txt";
        } else {
            qDebug() << "[PACKAGE_LIB] Test file write FAILED:" << testFile.errorString();
        }
        return result;  // Return empty if cannot write log
    }
    QTextStream logStream(&logFile);
    
    // 尝试从外部 CSV 文件读取，如果不存在则使用内置库
    if (packageLibraryCsvExists()) {
        QVariantList data = readPackageLibraryCsv();
        logStream << QString("[PACKAGE_LIB] Read %1 package entries from CSV\n").arg(data.length());
        qDebug() << "[PACKAGE_LIB] Read " << data.length() << " package entries from CSV";
        
        if (data.isEmpty()) {
            qDebug() << "[PACKAGE_LIB] CSV data is empty, using internal library";
        } else {
            // 检查第一行的结构和所有可用的列
            if (data.length() > 0) {
                const QVariantMap firstRow = data[0].toMap();
                QStringList allKeys = firstRow.keys();
                qDebug() << "[PACKAGE_LIB] First row keys:" << allKeys;
                qDebug() << "[PACKAGE_LIB] Total keys:" << allKeys.length();
                
                // 打印每个键的值
                for (const QString &key : allKeys) {
                    qDebug() << "  " << key << "=" << firstRow[key];
                }
            }
        }
        
        int successCount = 0;
        int failedCount = 0;
        
        for (int idx = 0; idx < data.length(); ++idx) {
            const QVariant &row = data[idx];
            const QVariantMap rowMap = row.toMap();
            
            if (rowMap.isEmpty()) {
                if (idx < 3) qDebug() << "[PACKAGE_LIB] Row" << idx << "is empty map";
                failedCount++;
                continue;
            }
            
            // 获取所有键用于调试
            QStringList rowKeys = rowMap.keys();
            
            // 查找PackageName/Package列 - 递归检查所有可能的变体
            QString packageName;
            // 首先尝试常见的英文列名
            for (const QString &key : rowKeys) {
                QString keyUpper = key.toUpper();
                if (keyUpper.contains("PACKAGE") || keyUpper.contains("NAME") || keyUpper == "PKG" || 
                    keyUpper == "FOOTPRINT" || keyUpper == "DEVICE") {
                    QString candidate = rowMap[key].toString().trimmed();
                    if (!candidate.isEmpty() && candidate != "PackageName" && candidate != "Name") {
                        packageName = candidate;
                        if (idx < 3) qDebug() << "[PACKAGE_LIB] Row" << idx << "found package name via key" << key << "=" << packageName;
                        break;
                    }
                }
            }
            
            if (packageName.isEmpty()) {
                if (idx < 3) {
                    qDebug() << "[PACKAGE_LIB] Row" << idx << "no package name found. Available keys and values:";
                    for (const QString &key : rowKeys) {
                        qDebug() << "  " << key << "=" << rowMap[key];
                    }
                }
                failedCount++;
                continue;
            }
            
            // 查找Width和Height列
            double widthMm = 0;
            double heightMm = 0;
            
            // 首先尝试找到包含 "x" 分隔符的 size 列 (格式: "0.30 x 0.15" 或 "0.30 x 0.15 x 0.10")
            for (const QString &key : rowKeys) {
                QString keyUpper = key.toUpper();
                if (keyUpper.contains("SIZE") || keyUpper.contains("DIMENSION") || keyUpper == "SIZE") {
                    QString sizeStr = rowMap[key].toString().trimmed();
                    if (sizeStr.contains("x") || sizeStr.contains("X")) {
                        // 按 "x" 分割
                        QStringList parts = sizeStr.split(QRegularExpression("[xX]"), Qt::SkipEmptyParts);
                        if (parts.length() >= 2) {
                            bool okW = false, okH = false;
                            double w = parts[0].trimmed().toDouble(&okW);
                            double h = parts[1].trimmed().toDouble(&okH);
                            
                            if (okW && okH && w > 0 && h > 0 && w < 1000 && h < 1000) {
                                widthMm = w;
                                heightMm = h;
                                if (idx < 3) qDebug() << "[PACKAGE_LIB] Row" << idx << "parsed size from key" << key << "=" << sizeStr << "-> width=" << widthMm << "height=" << heightMm;
                                break;
                            }
                        }
                    }
                }
            }
            
            // 如果没有找到 size 列，尝试查找单独的 Width 和 Height 数值列
            if (widthMm == 0 || heightMm == 0) {
                // 查找Width列
                for (const QString &key : rowKeys) {
                    QString keyUpper = key.toUpper();
                    if (keyUpper.contains("WIDTH") || keyUpper.contains("LENGTH")) {
                        bool ok = false;
                        QString valStr = rowMap[key].toString().trimmed();
                        double val = valStr.toDouble(&ok);
                        if (ok && val > 0 && val < 1000) {  // 合理的尺寸范围 0-1000mm
                            widthMm = val;
                            if (idx < 3) qDebug() << "[PACKAGE_LIB] Row" << idx << "found width via key" << key << "=" << widthMm;
                            break;
                        }
                    }
                }
                
                // 查找Height列
                for (const QString &key : rowKeys) {
                    QString keyUpper = key.toUpper();
                    if (keyUpper.contains("HEIGHT") || keyUpper.contains("DEPTH")) {
                        bool ok = false;
                        QString valStr = rowMap[key].toString().trimmed();
                        double val = valStr.toDouble(&ok);
                        if (ok && val > 0 && val < 1000) {
                            heightMm = val;
                            if (idx < 3) qDebug() << "[PACKAGE_LIB] Row" << idx << "found height via key" << key << "=" << heightMm;
                            break;
                        }
                    }
                }
                
                // 如果只找到了 width，尝试从其他数值列中推断 height
                if (widthMm > 0 && heightMm == 0) {
                    for (const QString &key : rowKeys) {
                        if (key.toUpper().contains("WIDTH") || key.toUpper().contains("NAME") || key.toUpper().contains("PACKAGE")) 
                            continue;
                        bool ok = false;
                        QString valStr = rowMap[key].toString().trimmed();
                        double val = valStr.toDouble(&ok);
                        if (ok && val > 0 && val < 1000 && val != widthMm) {
                            heightMm = val;
                            if (idx < 3) qDebug() << "[PACKAGE_LIB] Row" << idx << "inferred height from key" << key << "=" << heightMm;
                            break;
                        }
                    }
                }
            }
            
            if (widthMm > 0 && heightMm > 0) {
                // 规范化包名称（大写，去除特殊符号）
                QString normalizedName = packageName.toUpper().replace(QRegularExpression("[\\s_-]"), "");
                QVariantMap sizeMap;
                sizeMap["width"] = widthMm;
                sizeMap["height"] = heightMm;
                result[normalizedName] = sizeMap;
                successCount++;
                
                if (successCount <= 5) {
                    logStream << QString("[PACKAGE_LIB] Successfully loaded package: %1 size: (%2 x %3)\n").arg(normalizedName).arg(widthMm).arg(heightMm);
                    qDebug() << "[PACKAGE_LIB] Successfully loaded package:" << normalizedName << "size: (" << widthMm << "x" << heightMm << ")";
                }
            } else {
                if (idx < 3) {
                    qDebug() << "[PACKAGE_LIB] Row" << idx << "invalid dimensions: width=" << widthMm << "height=" << heightMm << "packageName=" << packageName;
                }
                failedCount++;
            }
        }
        
        logStream << QString("[PACKAGE_LIB] CSV parse summary: success=%1 failed=%2 total=%3\n").arg(successCount).arg(failedCount).arg(data.length());
        qDebug() << "[PACKAGE_LIB] CSV parse summary: success=" << successCount << "failed=" << failedCount << "total=" << data.length();
        
        if (!result.isEmpty()) {
            logStream << QString("[PACKAGE_LIB] Successfully loaded %1 packages from CSV\n").arg(result.size());
            qDebug() << "[PACKAGE_LIB] Successfully loaded " << result.size() << " packages from CSV";
            
            // 更新缓存
            m_packageLibraryCache = result;
            m_packageLibraryCacheTime = QDateTime::currentDateTime();
            m_packageLibraryCacheValid = true;
            qDebug() << "[PACKAGE_LIB_CACHE] Package library cached, expires in " << PACKAGE_LIBRARY_CACHE_TIMEOUT_MS << "ms";
            
            logStream.flush();
            logFile.close();
            return result;
        } else {
            logStream << "[PACKAGE_LIB] CSV file exists but no valid entries parsed, falling back to internal library\n";
            qDebug() << "[PACKAGE_LIB] CSV file exists but no valid entries parsed, falling back to internal library";
        }
    } else {
        logStream << QString("[PACKAGE_LIB] Package library CSV not found at: %1, using internal library\n").arg(packageLibraryCsvPath());
        qDebug() << "[PACKAGE_LIB] Package library CSV not found at:" << packageLibraryCsvPath() << ", using internal library";
    }
    
    // 内置默认库（回退方案）
    result["0201"] = QVariantMap{{"width", 0.6}, {"height", 0.3}};
    result["0402"] = QVariantMap{{"width", 1.0}, {"height", 0.5}};
    result["0603"] = QVariantMap{{"width", 1.6}, {"height", 0.8}};
    result["0805"] = QVariantMap{{"width", 2.0}, {"height", 1.25}};
    result["1206"] = QVariantMap{{"width", 3.2}, {"height", 1.6}};
    result["1210"] = QVariantMap{{"width", 3.2}, {"height", 2.5}};
    result["1812"] = QVariantMap{{"width", 4.5}, {"height", 3.2}};
    result["2010"] = QVariantMap{{"width", 5.0}, {"height", 2.5}};
    result["2512"] = QVariantMap{{"width", 6.35}, {"height", 3.2}};
    result["C0201"] = QVariantMap{{"width", 0.6}, {"height", 0.3}};
    result["C0402"] = QVariantMap{{"width", 1.0}, {"height", 0.5}};
    result["C0603"] = QVariantMap{{"width", 1.6}, {"height", 0.8}};
    result["C0805"] = QVariantMap{{"width", 2.0}, {"height", 1.25}};
    result["C1206"] = QVariantMap{{"width", 3.2}, {"height", 1.6}};
    result["C1210"] = QVariantMap{{"width", 3.2}, {"height", 2.5}};
    result["C1812"] = QVariantMap{{"width", 4.5}, {"height", 3.2}};
    result["C2010"] = QVariantMap{{"width", 5.0}, {"height", 2.5}};
    result["C2512"] = QVariantMap{{"width", 6.35}, {"height", 3.2}};
    result["R0201"] = QVariantMap{{"width", 0.6}, {"height", 0.3}};
    result["R0402"] = QVariantMap{{"width", 1.0}, {"height", 0.5}};
    result["R0603"] = QVariantMap{{"width", 1.6}, {"height", 0.8}};
    result["R0805"] = QVariantMap{{"width", 2.0}, {"height", 1.25}};
    result["R1206"] = QVariantMap{{"width", 3.2}, {"height", 1.6}};
    result["R1210"] = QVariantMap{{"width", 3.2}, {"height", 2.5}};
    result["R1812"] = QVariantMap{{"width", 4.5}, {"height", 3.2}};
    result["R2010"] = QVariantMap{{"width", 5.0}, {"height", 2.5}};
    result["R2512"] = QVariantMap{{"width", 6.35}, {"height", 3.2}};
    result["SOT23"] = QVariantMap{{"width", 2.9}, {"height", 1.3}};
    result["SOT25"] = QVariantMap{{"width", 2.8}, {"height", 1.3}};
    result["SOT53"] = QVariantMap{{"width", 2.9}, {"height", 1.3}};
    result["TSSOP20"] = QVariantMap{{"width", 6.5}, {"height", 4.4}};
    result["DIP8"] = QVariantMap{{"width", 9.81}, {"height", 6.35}};
    result["DIP14"] = QVariantMap{{"width", 19.81}, {"height", 6.35}};
    result["DIP16"] = QVariantMap{{"width", 19.81}, {"height", 7.62}};
    result["QFP32"] = QVariantMap{{"width", 7.0}, {"height", 7.0}};
    result["QFP48"] = QVariantMap{{"width", 9.0}, {"height", 9.0}};
    result["BGA"] = QVariantMap{{"width", 5.0}, {"height", 5.0}};
    result["LED0603"] = QVariantMap{{"width", 1.6}, {"height", 0.8}};
    result["LEDRDBLUERED0603"] = QVariantMap{{"width", 1.6}, {"height", 0.8}};
    result["SOD123"] = QVariantMap{{"width", 2.7}, {"height", 1.8}};
    result["SMFD5CA"] = QVariantMap{{"width", 2.7}, {"height", 1.8}};
    
    logStream << QString("[PACKAGE_LIB] Using internal library with %1 entries\n").arg(result.size());
    qDebug() << "[PACKAGE_LIB] Using internal library with" << result.size() << "entries";
    
    // 应用缓存内置库
    m_packageLibraryCache = result;
    m_packageLibraryCacheTime = QDateTime::currentDateTime();
    m_packageLibraryCacheValid = true;
    qDebug() << "[PACKAGE_LIB_CACHE] Internal library cached, expires in " << PACKAGE_LIBRARY_CACHE_TIMEOUT_MS << "ms";
    
    logStream.flush();
    logFile.close();
    
    return result;
}
