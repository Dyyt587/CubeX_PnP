/*
 * @Author: YingTian Yang 805207319@qq.com
 * @Date: 2026-03-10 22:06:35
 * @LastEditors: YingTian Yang 805207319@qq.com
 * @LastEditTime: 2026-04-03 05:02:45
 * @FilePath: \CubeX_PnP\src\helper\SettingsHelper.cpp
 * @Description: 这是默认设置,请设置`customMade`, 打开koroFileHeader查看配置 进行设置: https://github.com/OBKoro1/koro1FileHeader/wiki/%E9%85%8D%E7%BD%AE
 */
#include "SettingsHelper.h"

#include <QDataStream>
#include <QStandardPaths>
#include <QDebug>
#include <QDir>
#include <QFileInfo>

SettingsHelper::SettingsHelper(QObject *parent) : QObject(parent) {
}

SettingsHelper::~SettingsHelper() = default;

void SettingsHelper::save(const QString &key, QVariant val) {
    if (!m_settings) {
        qWarning() << "[SettingsHelper] Cannot save:" << key << "- Settings not initialized";
        return;
    }
    m_settings->setValue(key, val);
    qDebug() << "[SettingsHelper] Saved" << key << "=" << val;
}


QVariant SettingsHelper::get(const QString &key, QVariant def) {
    if (!m_settings) {
        qWarning() << "[SettingsHelper] Cannot get:" << key << "- Settings not initialized";
        return def;
    }
    QVariant data = m_settings->value(key);
    if (!data.isNull() && data.isValid()) {
        return data;
    }
    return def;
}

void SettingsHelper::init(char *argv[]) {
    QString applicationPath = QString::fromStdString(argv[0]);
    const QFileInfo fileInfo(applicationPath);
    const QString iniFileName = fileInfo.completeBaseName() + ".ini";
    
    // 保存到与 package library 相同的文件夹
    const QString base = QStandardPaths::writableLocation(QStandardPaths::AppLocalDataLocation);
    const QString dataDir = QDir(base).filePath("data");
    QDir().mkpath(dataDir);  // 确保目录存在
    const QString iniFilePath = QDir(dataDir).filePath(iniFileName);
    
    m_settings.reset(new QSettings(iniFilePath, QSettings::IniFormat));
    qDebug() << "[SettingsHelper] Configuration file path:" << iniFilePath;
    
    // Ensure the file is created by syncing immediately
    m_settings->sync();
    qDebug() << "[SettingsHelper] Settings synchronized";
}
