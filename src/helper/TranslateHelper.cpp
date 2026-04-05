#include "TranslateHelper.h"

#include <QGuiApplication>
#include <QQmlEngine>

#include "SettingsHelper.h"

[[maybe_unused]] TranslateHelper::TranslateHelper(QObject *parent) : QObject(parent) {
    _languages << "en_US";
    _languages << "zh_CN";
    _current = "en_US";  // 默认英文，延迟到 init() 时加载保存的语言设置
}

TranslateHelper::~TranslateHelper() = default;

void TranslateHelper::init(QQmlEngine *engine) {
    _engine = engine;
    
    // 现在 SettingsHelper 已经初始化，可以安全地加载保存的语言设置
    auto settings = SettingsHelper::getInstance();
    if (settings) {
        QString savedLang = settings->getLanguage();
        qDebug() << "[TranslateHelper] Saved language from SettingsHelper:" << savedLang;
        _current = savedLang;
    } else {
        qDebug() << "[TranslateHelper] SettingsHelper not available, using default:" << _current;
    }
    
    _translator = new QTranslator(this);
    QGuiApplication::installTranslator(_translator);
    
    QString translatorPath = QGuiApplication::applicationDirPath() + "/i18n";
    QString translationFile = QString("%1/CubeX_PnP_%2.qm").arg(translatorPath, _current);
    
    qDebug() << "[TranslateHelper] Application directory:" << QGuiApplication::applicationDirPath();
    qDebug() << "[TranslateHelper] Looking for translation file:" << translationFile;
    qDebug() << "[TranslateHelper] File exists:" << QFile::exists(translationFile);
    
    if (_translator->load(translationFile)) {
        qDebug() << "[TranslateHelper] ✓ Successfully loaded translation:" << _current;
        if (_engine) {
            _engine->retranslate();
            qDebug() << "[TranslateHelper] ✓ Engine retranslated";
        }
    } else {
        qWarning() << "[TranslateHelper] ✗ Failed to load translation file:" << translationFile;
    }
}

void TranslateHelper::switchLanguage(const QString &language) {
    if (!_languages.contains(language) || language == _current) {
        qDebug() << "[TranslateHelper] switchLanguage: Language not supported or already current:" << language;
        return;
    }
    
    qDebug() << "[TranslateHelper] switchLanguage: Switching to" << language;
    
    auto settings = SettingsHelper::getInstance();
    if (settings) {
        settings->saveLanguage(language);
        qDebug() << "[TranslateHelper] switchLanguage: Language saved to SettingsHelper";
    }
    
    // 重新加载翻译文件
    QString translatorPath = QGuiApplication::applicationDirPath() + "/i18n";
    QString translationFile = QString("%1/CubeX_PnP_%2.qm").arg(translatorPath, language);
    
    qDebug() << "[TranslateHelper] switchLanguage: Loading" << translationFile;
    
    if (_translator->load(translationFile)) {
        qDebug() << "[TranslateHelper] ✓ Successfully loaded new translation:" << language;
        _current = language;  // 更新属性，触发 currentChanged() 信号
        if (_engine) {
            _engine->retranslate();
            qDebug() << "[TranslateHelper] ✓ Engine retranslated";
        }
    } else {
        qWarning() << "[TranslateHelper] ✗ Failed to load translation file:" << translationFile;
    }
}
