#include "DeviceDiscovery.h"

#include <QVariantMap>

DeviceDiscovery::DeviceDiscovery(QObject *parent)
    : QObject(parent)
{
}

bool DeviceDiscovery::scanning() const { return m_scanning; }

QVariantList DeviceDiscovery::devices() const { return m_devices; }

void DeviceDiscovery::start()
{
    setScanning(true);
    m_devices.clear();

    // Placeholder until Android NsdManager is wired through JNI.
    addDevice(QStringLiteral("cubej1.local"), QStringLiteral("cubej1.local"), 8080);

    setScanning(false);
}

void DeviceDiscovery::stop()
{
    setScanning(false);
}

void DeviceDiscovery::setScanning(bool scanning)
{
    if (m_scanning == scanning) {
        return;
    }
    m_scanning = scanning;
    emit scanningChanged();
}

void DeviceDiscovery::addDevice(const QString &name, const QString &host, int port)
{
    QVariantMap device;
    device.insert(QStringLiteral("name"), name);
    device.insert(QStringLiteral("host"), host);
    device.insert(QStringLiteral("port"), port);
    m_devices.append(device);
    emit devicesChanged();
}
