#pragma once

#include <QObject>
#include <QtQml/qqml.h>
#include <QTranslator>
#include "src/singleton.h"
#include "src/stdafx.h"

class TranslateHelper : public QObject {
    Q_OBJECT
    Q_PROPERTY_AUTO(QString, current)
    Q_PROPERTY_READONLY_AUTO(QStringList, languages)
private:
    [[maybe_unused]] explicit TranslateHelper(QObject *parent = nullptr);

public:
    SINGLETON(TranslateHelper)
    ~TranslateHelper() override;
    void init(QQmlEngine *engine);
    Q_INVOKABLE void switchLanguage(const QString &language);

private:
    QQmlEngine *_engine = nullptr;
    QTranslator *_translator = nullptr;
};
