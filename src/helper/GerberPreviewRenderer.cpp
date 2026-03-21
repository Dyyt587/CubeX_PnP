#include "GerberPreviewRenderer.h"

#include <QDir>
#include <QDirIterator>
#include <QFileInfo>
#include <QImage>
#include <QPainter>
#include <QProcess>
#include <QRegularExpression>
#include <QSet>

#include <algorithm>
#include <cmath>

#include "bound_box.h"
#include "engine/qt_engine.h"
#include "gerber.h"
#include "gerber_renderer.h"

namespace {

QStringList gerberExts()
{
    return {
        ".gbr", ".gtl", ".gbl", ".gto", ".gbo", ".gts", ".gbs",
        ".gko", ".gdl", ".gdd", ".gtp", ".gbp"
    };
}

bool isRenderableExt(const QString &extNoDot)
{
    static const QSet<QString> kExts = {
        "gbr", "gtl", "gbl", "gto", "gbo", "gts", "gbs", "gko"
    };
    return kExts.contains(extNoDot.toLower());
}

QStringList selectRenderFiles(const QStringList &allFiles)
{
    QStringList topSet;
    QStringList bottomSet;
    QStringList fallback;

    for (const QString &path : allFiles) {
        const QString ext = QFileInfo(path).suffix().toLower();
        if (!isRenderableExt(ext)) {
            continue;
        }
        if (ext == "gtl" || ext == "gto" || ext == "gko" || ext == "gts") {
            topSet.push_back(path);
        }
        if (ext == "gbl" || ext == "gbo" || ext == "gko" || ext == "gbs") {
            bottomSet.push_back(path);
        }
        fallback.push_back(path);
    }

    auto hasLayer = [](const QStringList &files, const QString &targetExt) {
        for (const QString &f : files) {
            if (QFileInfo(f).suffix().compare(targetExt, Qt::CaseInsensitive) == 0) {
                return true;
            }
        }
        return false;
    };

    if (hasLayer(topSet, "gtl")) {
        return topSet;
    }
    if (hasLayer(bottomSet, "gbl")) {
        return bottomSet;
    }
    return fallback;
}

bool isValidBox(const BoundBox &b)
{
    const double left = b.Left();
    const double right = b.Right();
    const double top = b.Top();
    const double bottom = b.Bottom();
    return std::isfinite(left) && std::isfinite(right) && std::isfinite(top) && std::isfinite(bottom)
        && right >= left && top >= bottom;
}

QColor layerColor(const QString &filePath)
{
    const QString ext = QFileInfo(filePath).suffix().toLower();
    if (ext == "gtl") return QColor(220, 55, 45, 255);
    if (ext == "gto") return QColor(255, 194, 0, 255);
    if (ext == "gko") return QColor(30, 160, 60, 255);
    if (ext == "gts") return QColor(20, 120, 220, 220);
    return QColor(180, 70, 180, 200);
}

QStringList collectGerberFiles(const QString &root)
{
    const QStringList extList = gerberExts();
    const QSet<QString> exts = QSet<QString>(extList.begin(), extList.end());
    QStringList files;
    QDirIterator it(root, QDir::Files, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const QString path = it.next();
        const QString ext = "." + QFileInfo(path).suffix().toLower();
        if (exts.contains(ext)) {
            files.push_back(path);
        }
    }
    files.sort();
    return files;
}

QStringList collectGerberFilesInDirectory(const QString &dirPath)
{
    const QStringList extList = gerberExts();
    const QSet<QString> exts = QSet<QString>(extList.begin(), extList.end());
    QStringList files;
    QDir dir(dirPath);
    const QFileInfoList list = dir.entryInfoList(QDir::Files | QDir::NoDotAndDotDot);
    for (const QFileInfo &fi : list) {
        const QString ext = "." + fi.suffix().toLower();
        if (exts.contains(ext)) {
            files.push_back(fi.absoluteFilePath());
        }
    }
    files.sort();
    return files;
}

bool tryExtractGerberZip(const QString &root, QString *outExtractDir)
{
    QDir dir(root);
    const QStringList zips = dir.entryList(QStringList() << "Gerber*.zip" << "gerber*.zip", QDir::Files);
    if (zips.isEmpty()) {
        return false;
    }

    const QString zipPath = dir.filePath(zips.first());
    const QString extractDir = dir.filePath("out/gerber_unpack");
    QDir().mkpath(extractDir);

    QStringList args;
    args << "-NoProfile" << "-ExecutionPolicy" << "Bypass" << "-Command"
         << "Expand-Archive -Path \"" + zipPath + "\" -DestinationPath \"" + extractDir + "\" -Force";

    QProcess p;
    p.start("powershell", args);
    p.waitForFinished(120000);
    const bool ok = p.exitStatus() == QProcess::NormalExit && p.exitCode() == 0;
    if (ok && outExtractDir) {
        *outExtractDir = extractDir;
    }
    return ok;
}

bool extractGerberZipFile(const QString &zipPath, const QString &extractDir)
{
    QDir().mkpath(extractDir);
    QStringList args;
    args << "-NoProfile" << "-ExecutionPolicy" << "Bypass" << "-Command"
         << "Expand-Archive -Path \"" + zipPath + "\" -DestinationPath \"" + extractDir + "\" -Force";

    QProcess p;
    p.start("powershell", args);
    p.waitForFinished(120000);
    return p.exitStatus() == QProcess::NormalExit && p.exitCode() == 0;
}

QImage tintLayer(const QImage &layer, const QColor &color)
{
    QImage out(layer.size(), QImage::Format_ARGB32_Premultiplied);
    out.fill(Qt::transparent);

    for (int y = 0; y < layer.height(); ++y) {
        const QRgb *src = reinterpret_cast<const QRgb *>(layer.constScanLine(y));
        QRgb *dst = reinterpret_cast<QRgb *>(out.scanLine(y));
        for (int x = 0; x < layer.width(); ++x) {
            const QColor c = QColor::fromRgba(src[x]);
            const bool isInk = (c.red() < 250 || c.green() < 250 || c.blue() < 250);
            if (isInk) {
                dst[x] = color.rgba();
            } else {
                dst[x] = qRgba(0, 0, 0, 0);
            }
        }
    }

    return out;
}

QString renderFromGerberFiles(const QStringList &gerberFiles, const QString &outputImagePath, QString *errorMessage, QSizeF *boardSizeMm)
{
    if (gerberFiles.isEmpty()) {
        if (errorMessage) {
            *errorMessage = QStringLiteral("No gerber files found in input.");
        }
        return QString();
    }

    const QStringList selectedFiles = selectRenderFiles(gerberFiles);

    std::vector<std::shared_ptr<Gerber>> gerbers;
    gerbers.reserve(static_cast<size_t>(selectedFiles.size()));

    BoundBox bbox;
    bool hasBox = false;
    for (const QString &path : selectedFiles) {
        const QString ext = QFileInfo(path).suffix().toLower();
        if (!isRenderableExt(ext)) {
            continue;
        }
        auto g = std::make_shared<Gerber>(path.toStdString());
        const BoundBox b = g->GetBBox();
        if (!isValidBox(b)) {
            continue;
        }
        if (!hasBox) {
            bbox = b;
            hasBox = true;
        } else {
            bbox.UpdateBox(b);
        }
        gerbers.push_back(std::move(g));
    }

    if (!hasBox || gerbers.empty()) {
        if (errorMessage) {
            *errorMessage = QStringLiteral("Failed to parse gerber bounding box.");
        }
        return QString();
    }

    const double width = std::max(1e-6, bbox.Right() - bbox.Left());
    const double height = std::max(1e-6, bbox.Top() - bbox.Bottom());
    if (boardSizeMm) {
        *boardSizeMm = QSizeF(width, height);
    }
    const int maxSide = 2200;
    const int imgW = width >= height ? maxSide : std::max(1, int(maxSide * width / height));
    const int imgH = width >= height ? std::max(1, int(maxSide * height / width)) : maxSide;

    QImage merged(imgW, imgH, QImage::Format_ARGB32_Premultiplied);
    merged.fill(Qt::white);
    QPainter painter(&merged);
    painter.setRenderHint(QPainter::Antialiasing, true);

    for (size_t i = 0; i < gerbers.size(); ++i) {
        QImage layer(imgW, imgH, QImage::Format_ARGB32_Premultiplied);
        layer.fill(Qt::white);

        QtEngine engine(&layer, bbox, BoundBox(0.0, 0.0, 0.0, 0.0));
        GerberRender renderer(&engine);
        renderer.RenderGerber(gerbers[i]);

        const QColor color = layerColor(QString::fromStdString(gerbers[i]->FileName()));
        painter.drawImage(0, 0, tintLayer(layer, color));
    }

    painter.end();

    QFileInfo outInfo(outputImagePath);
    QDir().mkpath(outInfo.absolutePath());
    if (!merged.save(outputImagePath)) {
        if (errorMessage) {
            *errorMessage = QStringLiteral("Failed to save gerber preview image.");
        }
        return QString();
    }

    return QFileInfo(outputImagePath).absoluteFilePath();
}

} // namespace

QString renderWorkspaceGerberPreview(const QString &workspaceRoot, const QString &outputImagePath, QString *errorMessage)
{
    QStringList gerberFiles = collectGerberFiles(workspaceRoot);
    if (gerberFiles.isEmpty()) {
        QString extracted;
        if (tryExtractGerberZip(workspaceRoot, &extracted)) {
            gerberFiles = collectGerberFiles(extracted);
        }
    }

    return renderFromGerberFiles(gerberFiles, outputImagePath, errorMessage, nullptr);
}

QString renderWorkspaceGerberPreview(
    const QString &workspaceRoot,
    const QString &outputImagePath,
    QString *errorMessage,
    QSizeF *boardSizeMm)
{
    QStringList gerberFiles = collectGerberFiles(workspaceRoot);
    if (gerberFiles.isEmpty()) {
        QString extracted;
        if (tryExtractGerberZip(workspaceRoot, &extracted)) {
            gerberFiles = collectGerberFiles(extracted);
        }
    }

    return renderFromGerberFiles(gerberFiles, outputImagePath, errorMessage, boardSizeMm);
}

QString renderGerberPreviewFromInput(const QString &inputPath, const QString &outputImagePath, QString *errorMessage)
{
    const QFileInfo inputInfo(inputPath);
    if (!inputInfo.exists()) {
        if (errorMessage) {
            *errorMessage = QStringLiteral("Selected gerber input does not exist.");
        }
        return QString();
    }

    QStringList files;
    if (inputInfo.isDir()) {
        files = collectGerberFilesInDirectory(inputInfo.absoluteFilePath());
    } else {
        const QString suffix = inputInfo.suffix().toLower();
        if (suffix == "zip") {
            const QString extractDir = QDir::current().filePath("out/gerber_import_unpack");
            if (!extractGerberZipFile(inputInfo.absoluteFilePath(), extractDir)) {
                if (errorMessage) {
                    *errorMessage = QStringLiteral("Failed to extract selected zip file.");
                }
                return QString();
            }
            files = collectGerberFiles(extractDir);
        } else {
            files = collectGerberFilesInDirectory(inputInfo.absolutePath());
            if (files.isEmpty()) {
                files = QStringList() << inputInfo.absoluteFilePath();
            }
        }
    }

    return renderFromGerberFiles(files, outputImagePath, errorMessage, nullptr);
}

QString renderGerberPreviewFromInput(
    const QString &inputPath,
    const QString &outputImagePath,
    QString *errorMessage,
    QSizeF *boardSizeMm)
{
    const QFileInfo inputInfo(inputPath);
    if (!inputInfo.exists()) {
        if (errorMessage) {
            *errorMessage = QStringLiteral("Selected gerber input does not exist.");
        }
        return QString();
    }

    QStringList files;
    if (inputInfo.isDir()) {
        files = collectGerberFilesInDirectory(inputInfo.absoluteFilePath());
    } else {
        const QString suffix = inputInfo.suffix().toLower();
        if (suffix == "zip") {
            const QString extractDir = QDir::current().filePath("out/gerber_import_unpack");
            if (!extractGerberZipFile(inputInfo.absoluteFilePath(), extractDir)) {
                if (errorMessage) {
                    *errorMessage = QStringLiteral("Failed to extract selected zip file.");
                }
                return QString();
            }
            files = collectGerberFiles(extractDir);
        } else {
            files = collectGerberFilesInDirectory(inputInfo.absolutePath());
            if (files.isEmpty()) {
                files = QStringList() << inputInfo.absoluteFilePath();
            }
        }
    }

    return renderFromGerberFiles(files, outputImagePath, errorMessage, boardSizeMm);
}
