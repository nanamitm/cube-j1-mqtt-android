#include "CubeJClient.h"

#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QUrl>
#include <QUrlQuery>

CubeJClient::CubeJClient(QObject *parent)
    : QObject(parent)
{
}

QString CubeJClient::host() const { return m_host; }

void CubeJClient::setHost(const QString &host)
{
    if (m_host == host) {
        return;
    }
    m_host = host.trimmed();
    emit endpointChanged();
}

int CubeJClient::port() const { return m_port; }

void CubeJClient::setPort(int port)
{
    if (m_port == port) {
        return;
    }
    m_port = port;
    emit endpointChanged();
}

QString CubeJClient::user() const { return m_user; }

void CubeJClient::setUser(const QString &user)
{
    if (m_user == user) {
        return;
    }
    m_user = user;
    emit credentialsChanged();
}

QString CubeJClient::password() const { return m_password; }

void CubeJClient::setPassword(const QString &password)
{
    if (m_password == password) {
        return;
    }
    m_password = password;
    emit credentialsChanged();
}

QString CubeJClient::lastError() const { return m_lastError; }

bool CubeJClient::busy() const { return m_busy; }

void CubeJClient::fetchStatus()
{
    setBusy(true);
    QNetworkReply *reply = m_network.get(makeRequest(QStringLiteral("/status.json")));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        handleJsonReply(reply, SIGNAL(statusReceived(QVariantMap)));
    });
}

void CubeJClient::fetchConfig()
{
    setBusy(true);
    QNetworkReply *reply = m_network.get(makeRequest(QStringLiteral("/config.json")));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        handleJsonReply(reply, SIGNAL(configReceived(QVariantMap)));
    });
}

void CubeJClient::fetchBridgeLog()
{
    setBusy(true);
    QNetworkReply *reply = m_network.get(makeRequest(QStringLiteral("/mqtt_bridge.log")));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        handleTextReply(reply, QStringLiteral("mqtt_bridge.log"));
    });
}

void CubeJClient::fetchSerialLog()
{
    setBusy(true);
    QNetworkReply *reply = m_network.get(makeRequest(QStringLiteral("/serial.log")));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        handleTextReply(reply, QStringLiteral("serial.log"));
    });
}

void CubeJClient::reboot()
{
    setBusy(true);
    QNetworkRequest request = makeRequest(QStringLiteral("/reboot"));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/x-www-form-urlencoded"));
    QNetworkReply *reply = m_network.post(request, QByteArray());
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const bool ok = reply->error() == QNetworkReply::NoError && status >= 200 && status < 300;
        if (ok) {
            emit commandSucceeded(QStringLiteral("reboot"));
        } else {
            const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            setLastError(QStringLiteral("HTTP %1: %2").arg(status).arg(reply->errorString()));
        }
        reply->deleteLater();
        setBusy(false);
    });
}

void CubeJClient::saveConfig(const QVariantMap &config)
{
    setBusy(true);
    QNetworkRequest request = makeRequest(QStringLiteral("/save"));
    request.setHeader(QNetworkRequest::ContentTypeHeader, QStringLiteral("application/x-www-form-urlencoded"));
    QNetworkReply *reply = m_network.post(request, formEncode(config));
    connect(reply, &QNetworkReply::finished, this, [this, reply]() {
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const bool ok = reply->error() == QNetworkReply::NoError && status >= 200 && status < 300;
        if (ok) {
            emit commandSucceeded(QStringLiteral("save"));
        } else {
            const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
            setLastError(QStringLiteral("HTTP %1: %2").arg(status).arg(reply->errorString()));
        }
        reply->deleteLater();
        setBusy(false);
    });
}

QNetworkRequest CubeJClient::makeRequest(const QString &path) const
{
    QUrl url;
    url.setScheme(QStringLiteral("http"));
    url.setHost(m_host);
    url.setPort(m_port);
    url.setPath(path);

    QNetworkRequest request(url);
    request.setTransferTimeout(8000);
    const QByteArray token = QStringLiteral("%1:%2").arg(m_user, m_password).toUtf8().toBase64();
    request.setRawHeader("Authorization", "Basic " + token);
    request.setRawHeader("Accept", "application/json, text/plain, */*");
    request.setHeader(QNetworkRequest::UserAgentHeader, QStringLiteral("CubeJ1QtAndroid/0.1"));
    return request;
}

void CubeJClient::setBusy(bool busy)
{
    if (m_busy == busy) {
        return;
    }
    m_busy = busy;
    emit busyChanged();
}

void CubeJClient::setLastError(const QString &message)
{
    if (m_lastError == message) {
        return;
    }
    m_lastError = message;
    emit lastErrorChanged();
}

void CubeJClient::handleJsonReply(QNetworkReply *reply, const char *signalName)
{
    const QByteArray body = reply->readAll();
    if (reply->error() != QNetworkReply::NoError) {
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        setLastError(QStringLiteral("HTTP %1: %2").arg(status).arg(reply->errorString()));
        reply->deleteLater();
        setBusy(false);
        return;
    }

    const QJsonDocument doc = QJsonDocument::fromJson(body);
    if (!doc.isObject()) {
        setLastError(QStringLiteral("Invalid JSON response"));
        reply->deleteLater();
        setBusy(false);
        return;
    }

    setLastError(QString());
    const QVariantMap map = doc.object().toVariantMap();
    if (qstrcmp(signalName, SIGNAL(statusReceived(QVariantMap))) == 0) {
        emit statusReceived(map);
    } else {
        emit configReceived(map);
    }
    reply->deleteLater();
    setBusy(false);
}

void CubeJClient::handleTextReply(QNetworkReply *reply, const QString &name)
{
    const QByteArray body = reply->readAll();
    if (reply->error() != QNetworkReply::NoError) {
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        setLastError(QStringLiteral("HTTP %1: %2").arg(status).arg(reply->errorString()));
    } else {
        setLastError(QString());
        emit logReceived(name, QString::fromUtf8(body));
    }
    reply->deleteLater();
    setBusy(false);
}

QByteArray CubeJClient::formEncode(const QVariantMap &values)
{
    QUrlQuery query;
    for (auto it = values.cbegin(); it != values.cend(); ++it) {
        query.addQueryItem(it.key(), it.value().toString());
    }
    return query.toString(QUrl::FullyEncoded).toUtf8();
}
