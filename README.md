# Cube J1 MQTT Android Client

Qt 6/C++ Android client for Cube J1 MQTT.

## Scope

- Connect to the Cube J1 Web UI API over HTTP Basic authentication.
- Display `/status.json`.
- Fetch logs from `/mqtt_bridge.log` and `/serial.log`.
- Switch between system, light, and dark UI themes.
- Keep device discovery behind `DeviceDiscovery` so Android `NsdManager` can be wired in without touching the UI.

## Discovery Plan

The preferred discovery mechanism is DNS-SD/mDNS:

- Service type: `_cubej1-mqtt._tcp.`
- Port: `8080`
- TXT candidates: `device_id`, `api=/status.json`, `path=/`

Until the Cube J1 side advertises that service, the client exposes `cubej1.local:8080` as a placeholder candidate.

## Build

Open this folder in Qt Creator with an Android Qt 6 kit, then build the `CubeJ1MqttAndroid` target.

The project also configures and builds as a desktop Qt target, which is useful for quick UI and API-client checks.

Current local note: command-line Android CMake configuration depends on the Android NDK path registered in Qt Creator. If `qt-cmake` reports an `/opt/android/...` NDK path on Windows, open the project in Qt Creator and select the installed Android SDK/NDK there before building an APK.
