#pragma once

#include <QObject>
#include <QVariantList>

class DeviceDiscovery : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool scanning READ scanning NOTIFY scanningChanged)
    Q_PROPERTY(QVariantList devices READ devices NOTIFY devicesChanged)
    Q_PROPERTY(QString debugLog READ debugLog NOTIFY debugLogChanged)

public:
    explicit DeviceDiscovery(QObject *parent = nullptr);

    bool scanning() const;
    QVariantList devices() const;
    QString debugLog() const;

    Q_INVOKABLE void start();
    Q_INVOKABLE void stop();
    Q_INVOKABLE void clearDebugLog();
    void onScanningChanged(bool scanning);
    void onDeviceFound(const QString &name, const QString &host, int port);
    void onDeviceLost(const QString &host, int port);
    void onDebugMessage(const QString &message);

signals:
    void scanningChanged();
    void devicesChanged();
    void debugLogChanged();

private:
    void clearDevices();
    void setScanning(bool scanning);
    void addOrUpdateDevice(const QString &name, const QString &host, int port);
    void removeDevice(const QString &host, int port);
    void appendDebugMessage(const QString &message);

    bool m_scanning = false;
    QVariantList m_devices;
    QStringList m_debugLines;
};
