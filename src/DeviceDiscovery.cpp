#include "DeviceDiscovery.h"

#include <functional>
#include <QDateTime>
#include <QMetaObject>
#include <QVariantMap>

#ifdef Q_OS_ANDROID
#include <QJniObject>
#include <QtCore/qcoreapplication_platform.h>
#endif

namespace {
int addressPriority(const QString &host)
{
    if (host.startsWith(QStringLiteral("192.168.100."))) {
        return 1;
    }
    if (host.startsWith(QStringLiteral("fe80:"), Qt::CaseInsensitive)) {
        return 2;
    }
    if (host.contains(QLatin1Char(':'))) {
        return 3;
    }
    return 4;
}

#ifdef Q_OS_ANDROID
DeviceDiscovery *g_deviceDiscovery = nullptr;

QString jstringToQString(jstring value)
{
    return QJniObject(value).toString();
}

void dispatchToQtThread(const std::function<void()> &fn)
{
    if (!g_deviceDiscovery) {
        return;
    }
    QMetaObject::invokeMethod(g_deviceDiscovery, fn, Qt::QueuedConnection);
}

extern "C" JNIEXPORT void JNICALL
Java_net_nanami_cubej1mqtt_CubeDiscovery_nativeSetScanning(JNIEnv *, jclass, jboolean scanning)
{
    dispatchToQtThread([scanning]() {
        if (g_deviceDiscovery) {
            g_deviceDiscovery->onScanningChanged(bool(scanning));
        }
    });
}

extern "C" JNIEXPORT void JNICALL
Java_net_nanami_cubej1mqtt_CubeDiscovery_nativeDeviceFound(JNIEnv *, jclass, jstring name, jstring host, jint port)
{
    const QString qName = jstringToQString(name);
    const QString qHost = jstringToQString(host);
    dispatchToQtThread([qName, qHost, port]() {
        if (g_deviceDiscovery) {
            g_deviceDiscovery->onDeviceFound(qName, qHost, int(port));
        }
    });
}

extern "C" JNIEXPORT void JNICALL
Java_net_nanami_cubej1mqtt_CubeDiscovery_nativeDeviceLost(JNIEnv *, jclass, jstring host, jint port)
{
    const QString qHost = jstringToQString(host);
    dispatchToQtThread([qHost, port]() {
        if (g_deviceDiscovery) {
            g_deviceDiscovery->onDeviceLost(qHost, int(port));
        }
    });
}

extern "C" JNIEXPORT void JNICALL
Java_net_nanami_cubej1mqtt_CubeDiscovery_nativeDebugMessage(JNIEnv *, jclass, jstring message)
{
    const QString qMessage = jstringToQString(message);
    dispatchToQtThread([qMessage]() {
        if (g_deviceDiscovery) {
            g_deviceDiscovery->onDebugMessage(qMessage);
        }
    });
}
#endif
} // namespace

DeviceDiscovery::DeviceDiscovery(QObject *parent)
    : QObject(parent)
{
#ifdef Q_OS_ANDROID
    g_deviceDiscovery = this;
#endif
}

bool DeviceDiscovery::scanning() const { return m_scanning; }

QVariantList DeviceDiscovery::devices() const { return m_devices; }

QString DeviceDiscovery::debugLog() const { return m_debugLines.join(QLatin1Char('\n')); }

void DeviceDiscovery::start()
{
    appendDebugMessage(QStringLiteral("Start requested"));
    clearDevices();

#ifdef Q_OS_ANDROID
    setScanning(true);
    QJniObject context = QNativeInterface::QAndroidApplication::context();
    QJniObject::callStaticMethod<void>(
        "net/nanami/cubej1mqtt/CubeDiscovery",
        "startDiscovery",
        "(Landroid/content/Context;)V",
        context.object<jobject>());
#else
    appendDebugMessage(QStringLiteral("Desktop stub discovery returned cubej1.local:8080"));
    setScanning(true);
    addOrUpdateDevice(QStringLiteral("cubej1.local"), QStringLiteral("cubej1.local"), 8080);
    setScanning(false);
#endif
}

void DeviceDiscovery::stop()
{
    appendDebugMessage(QStringLiteral("Stop requested"));
#ifdef Q_OS_ANDROID
    QJniObject::callStaticMethod<void>(
        "net/nanami/cubej1mqtt/CubeDiscovery",
        "stopDiscovery",
        "()V");
#endif
    setScanning(false);
}

void DeviceDiscovery::clearDebugLog()
{
    if (m_debugLines.isEmpty()) {
        return;
    }
    m_debugLines.clear();
    emit debugLogChanged();
}

void DeviceDiscovery::onScanningChanged(bool scanning)
{
    appendDebugMessage(QStringLiteral("Scanning %1").arg(scanning ? QStringLiteral("started") : QStringLiteral("stopped")));
    setScanning(scanning);
}

void DeviceDiscovery::onDeviceFound(const QString &name, const QString &host, int port)
{
    appendDebugMessage(QStringLiteral("Found %1 at %2:%3").arg(name, host).arg(port));
    addOrUpdateDevice(name, host, port);
}

void DeviceDiscovery::onDeviceLost(const QString &host, int port)
{
    appendDebugMessage(QStringLiteral("Lost %1:%2").arg(host).arg(port));
    removeDevice(host, port);
}

void DeviceDiscovery::onDebugMessage(const QString &message)
{
    appendDebugMessage(message);
}

void DeviceDiscovery::clearDevices()
{
    if (m_devices.isEmpty()) {
        return;
    }
    m_devices.clear();
    emit devicesChanged();
}

void DeviceDiscovery::setScanning(bool scanning)
{
    if (m_scanning == scanning) {
        return;
    }
    m_scanning = scanning;
    emit scanningChanged();
}

void DeviceDiscovery::addOrUpdateDevice(const QString &name, const QString &host, int port)
{
    QVariantMap device;
    device.insert(QStringLiteral("name"), name);
    device.insert(QStringLiteral("host"), host);
    device.insert(QStringLiteral("port"), port);

    for (int i = 0; i < m_devices.size(); ++i) {
        const QVariantMap existing = m_devices.at(i).toMap();
        const QString existingName = existing.value(QStringLiteral("name")).toString();
        const QString existingHost = existing.value(QStringLiteral("host")).toString();
        const int existingPort = existing.value(QStringLiteral("port")).toInt();

        if (existingHost == host && existingPort == port) {
            if (existing == device) {
                return;
            }
            m_devices[i] = device;
            emit devicesChanged();
            return;
        }

        if (existingName == name && existingPort == port) {
            if (addressPriority(host) >= addressPriority(existingHost)) {
                m_devices[i] = device;
                emit devicesChanged();
            }
            return;
        }
    }

    m_devices.append(device);
    emit devicesChanged();
}

void DeviceDiscovery::removeDevice(const QString &host, int port)
{
    for (int i = 0; i < m_devices.size(); ++i) {
        const QVariantMap existing = m_devices.at(i).toMap();
        if (existing.value(QStringLiteral("host")).toString() == host
            && existing.value(QStringLiteral("port")).toInt() == port) {
            m_devices.removeAt(i);
            emit devicesChanged();
            break;
        }
    }
}

void DeviceDiscovery::appendDebugMessage(const QString &message)
{
    const QString timestamp = QDateTime::currentDateTime().toString(QStringLiteral("HH:mm:ss"));
    m_debugLines.append(QStringLiteral("[%1] %2").arg(timestamp, message));
    while (m_debugLines.size() > 120) {
        m_debugLines.removeFirst();
    }
    emit debugLogChanged();
}
