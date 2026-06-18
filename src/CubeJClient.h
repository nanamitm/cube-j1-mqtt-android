#pragma once

#include <QNetworkAccessManager>
#include <QObject>
#include <QVariantMap>

class QNetworkReply;

class CubeJClient : public QObject
{
    Q_OBJECT
    Q_PROPERTY(QString host READ host WRITE setHost NOTIFY endpointChanged)
    Q_PROPERTY(int port READ port WRITE setPort NOTIFY endpointChanged)
    Q_PROPERTY(QString user READ user WRITE setUser NOTIFY credentialsChanged)
    Q_PROPERTY(QString password READ password WRITE setPassword NOTIFY credentialsChanged)
    Q_PROPERTY(QString lastError READ lastError NOTIFY lastErrorChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)

public:
    explicit CubeJClient(QObject *parent = nullptr);

    QString host() const;
    void setHost(const QString &host);

    int port() const;
    void setPort(int port);

    QString user() const;
    void setUser(const QString &user);

    QString password() const;
    void setPassword(const QString &password);

    QString lastError() const;
    bool busy() const;

    Q_INVOKABLE void fetchStatus();
    Q_INVOKABLE void fetchConfig();
    Q_INVOKABLE void fetchBridgeLog();
    Q_INVOKABLE void fetchSerialLog();
    Q_INVOKABLE void reboot();
    Q_INVOKABLE void saveConfig(const QVariantMap &config);

signals:
    void endpointChanged();
    void credentialsChanged();
    void lastErrorChanged();
    void busyChanged();
    void statusReceived(const QVariantMap &status);
    void configReceived(const QVariantMap &config);
    void logReceived(const QString &name, const QString &text);
    void commandSucceeded(const QString &command);

private:
    QNetworkRequest makeRequest(const QString &path) const;
    void setBusy(bool busy);
    void setLastError(const QString &message);
    void handleJsonReply(QNetworkReply *reply, const char *signalName);
    void handleTextReply(QNetworkReply *reply, const QString &name);
    static QByteArray formEncode(const QVariantMap &values);

    QNetworkAccessManager m_network;
    QString m_host = QStringLiteral("cubej1.local");
    int m_port = 8080;
    QString m_user = QStringLiteral("admin");
    QString m_password = QStringLiteral("cubej1");
    QString m_lastError;
    bool m_busy = false;
};
