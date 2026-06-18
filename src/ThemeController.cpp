#include "ThemeController.h"

#include <QGuiApplication>
#include <QSettings>
#include <QStyleHints>

ThemeController::ThemeController(QObject *parent)
    : QObject(parent)
{
    QSettings settings;
    m_mode = settings.value(QStringLiteral("theme/mode"), QStringLiteral("system")).toString();
    if (m_mode != QStringLiteral("light") && m_mode != QStringLiteral("dark") && m_mode != QStringLiteral("system")) {
        m_mode = QStringLiteral("system");
    }

    m_dark = computeDark();
    connect(qGuiApp->styleHints(), &QStyleHints::colorSchemeChanged, this, [this]() {
        refreshDark();
    });
}

QString ThemeController::mode() const
{
    return m_mode;
}

void ThemeController::setMode(const QString &mode)
{
    QString normalized = mode.toLower();
    if (normalized != QStringLiteral("light") && normalized != QStringLiteral("dark") && normalized != QStringLiteral("system")) {
        normalized = QStringLiteral("system");
    }

    if (m_mode == normalized) {
        return;
    }

    m_mode = normalized;
    QSettings settings;
    settings.setValue(QStringLiteral("theme/mode"), m_mode);
    emit modeChanged();
    refreshDark();
}

bool ThemeController::dark() const
{
    return m_dark;
}

bool ThemeController::computeDark() const
{
    if (m_mode == QStringLiteral("dark")) {
        return true;
    }
    if (m_mode == QStringLiteral("light")) {
        return false;
    }
    return qGuiApp->styleHints()->colorScheme() == Qt::ColorScheme::Dark;
}

void ThemeController::refreshDark()
{
    const bool next = computeDark();
    if (m_dark == next) {
        return;
    }
    m_dark = next;
    emit darkChanged();
}
