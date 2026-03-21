#pragma once

#include <QString>
#include <QSizeF>

// Render gerber files found in workspace to a single preview image.
// Returns output image absolute path on success, empty string on failure.
QString renderWorkspaceGerberPreview(
	const QString &workspaceRoot,
	const QString &outputImagePath,
	QString *errorMessage = nullptr,
	QSizeF *boardSizeMm = nullptr);

// Render gerber preview from a selected input path (gerber file, folder, or zip file).
QString renderGerberPreviewFromInput(
	const QString &inputPath,
	const QString &outputImagePath,
	QString *errorMessage = nullptr,
	QSizeF *boardSizeMm = nullptr);
