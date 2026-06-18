#pragma once

#include <QObject>
#include <QVariantList>

class DeviceDiscovery : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged)

public:
    explicit DeviceDiscovery(QObject *parent = nullptr);

    bool scanning() const;
    QVariantList devices() const;

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();

signals:
    void scanningChanged();
    void devicesChanged();

private:
    void setScanning(bool scanning);
    void addDevice(const QString &name, const QString &host, int port);

    bool m_scanning = false;
    QVariantList m_devices;
};
