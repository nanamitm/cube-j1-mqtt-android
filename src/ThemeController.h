#pragma once

#include <QObject>

class ThemeController : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY modeChanged)
    Q_PROPERTY(bool dark READ dark NOTIFY darkChanged)

public:
    explicit ThemeController(QObject *parent = nullptr);

    QString mode() const;
    void setMode(const QString &mode);

    bool dark() const;

signals:
    void modeChanged();
    void darkChanged();

private:
    bool computeDark() const;
    void refreshDark();

    QString m_mode;
    bool m_dark = false;
};
