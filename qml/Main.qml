import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    width: 440
    height: 800
    visible: true
    title: "Cube J1 MQTT"
    color: palette.window

    palette.window: "#f5f6f8"
    palette.windowText: "#15171a"
    palette.base: "#ffffff"
    palette.alternateBase: "#eef1f4"
    palette.text: "#15171a"
    palette.button: "#eef1f4"
    palette.buttonText: "#15171a"
    palette.highlight: "#1769aa"
    palette.highlightedText: "#ffffff"
    palette.mid: "#c9ced6"
    palette.dark: "#7a8491"
    palette.light: "#ffffff"
    palette.placeholderText: "#687180"

    property var status: ({})
    property var values: ({})
    property var config: ({})
    property var powerSamples: []
    property string logText: ""
    property string logName: ""
    property string message: ""
    property bool autoRefresh: true

    function textValue(key, fallback) {
        var value = root.config[key]
        if (value === undefined || value === null)
            return fallback || ""
        return String(value)
    }

    function numberValue(key, fallback) {
        var value = Number(root.config[key])
        return isNaN(value) ? fallback : value
    }

    function saveConfigFromFields() {
        cubeClient.saveConfig({
            "br_id": brIdField.text,
            "br_pwd": brPwdField.text,
            "mqtt_host": mqttHostField.text,
            "mqtt_port": mqttPortField.value,
            "mqtt_user": mqttUserField.text,
            "mqtt_pass": mqttPassField.text,
            "device_id": deviceIdField.text,
            "serial_port": serialPortField.text,
            "poll_interval": pollIntervalField.value,
            "web_port": webPortField.value,
            "web_user": webUserField.text,
            "web_pass": webPassField.text,
            "restart_bridge": restartBridgeCheck.checked ? "1" : ""
        })
    }

    Connections {
        target: cubeClient

        function onStatusReceived(s) {
            root.status = s
            root.values = s.last_values || {}
            if (root.values.power_w !== undefined) {
                var next = root.powerSamples.slice()
                next.push(Number(root.values.power_w))
                while (next.length > 60)
                    next.shift()
                root.powerSamples = next
                powerChart.requestPaint()
            }
        }

        function onConfigReceived(c) {
            root.config = c
            root.message = "Config loaded"
        }

        function onLogReceived(name, text) {
            root.logName = name
            root.logText = text
        }

        function onCommandSucceeded(command) {
            root.message = command + " accepted"
            if (command === "save")
                cubeClient.fetchConfig()
        }
    }

    Timer {
        interval: 5000
        running: root.autoRefresh
        repeat: true
        triggeredOnStart: true
        onTriggered: cubeClient.fetchStatus()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12

        RowLayout {
            Layout.fillWidth: true

            TextField {
                text: cubeClient.host
                placeholderText: "cubej1.local"
                Layout.fillWidth: true
                onEditingFinished: cubeClient.host = text
            }

            SpinBox {
                from: 1
                to: 65535
                value: cubeClient.port
                onValueModified: cubeClient.port = value
            }
        }

        RowLayout {
            Layout.fillWidth: true

            TextField {
                text: cubeClient.user
                placeholderText: "User"
                Layout.fillWidth: true
                onEditingFinished: cubeClient.user = text
            }

            TextField {
                text: cubeClient.password
                placeholderText: "Password"
                echoMode: TextInput.Password
                Layout.fillWidth: true
                onEditingFinished: cubeClient.password = text
            }
        }

        RowLayout {
            Layout.fillWidth: true

            Button {
                text: "Find"
                onClicked: deviceDiscovery.start()
            }

            Button {
                text: "Refresh"
                onClicked: cubeClient.fetchStatus()
            }

            CheckBox {
                text: "Auto"
                checked: root.autoRefresh
                onToggled: root.autoRefresh = checked
            }

            BusyIndicator {
                running: cubeClient.busy
                visible: cubeClient.busy
                implicitWidth: 28
                implicitHeight: 28
            }

            Item { Layout.fillWidth: true }
        }

        Label {
            visible: cubeClient.lastError.length > 0
            text: cubeClient.lastError
            color: "crimson"
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        Label {
            visible: root.message.length > 0
            text: root.message
            color: "#2d6a4f"
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        TabBar {
            id: tabs
            Layout.fillWidth: true

            TabButton { text: "Status" }
            TabButton { text: "Config" }
            TabButton { text: "Logs" }
            TabButton { text: "Maintenance" }
        }

        StackLayout {
            currentIndex: tabs.currentIndex
            Layout.fillWidth: true
            Layout.fillHeight: true

            ScrollView {
                contentWidth: availableWidth

                ColumnLayout {
                    width: parent.width
                    spacing: 12

                    GroupBox {
                        title: "Connection"
                        Layout.fillWidth: true

                        GridLayout {
                            columns: 2
                            anchors.fill: parent

                            Label { text: "MQTT" }
                            Label { text: status.mqtt_connected ? "Connected" : "Disconnected" }
                            Label { text: "Wi-SUN" }
                            Label { text: status.wisun_connected ? "Connected" : "Disconnected" }
                            Label { text: "Required" }
                            Label { text: status.configuration_required ? "Configuration required" : "Ready" }
                            Label { text: "Device ID" }
                            Label { text: status.device_id || "-" }
                            Label { text: "Updated" }
                            Label { text: status.updated_at || "-" }
                            Label { text: "Last Error" }
                            Label {
                                text: status.last_error || "-"
                                wrapMode: Text.Wrap
                                Layout.fillWidth: true
                            }
                        }
                    }

                    GroupBox {
                        title: "Measurements"
                        Layout.fillWidth: true

                        GridLayout {
                            columns: 2
                            anchors.fill: parent

                            Label { text: "Power" }
                            Label { text: values.power_w !== undefined ? values.power_w + " W" : "-" }
                            Label { text: "Forward Energy" }
                            Label { text: values.energy_forward_kwh !== undefined ? values.energy_forward_kwh + " kWh" : "-" }
                            Label { text: "Reverse Energy" }
                            Label { text: values.energy_reverse_kwh !== undefined ? values.energy_reverse_kwh + " kWh" : "-" }
                            Label { text: "Current R" }
                            Label { text: values.current_r_a !== undefined ? values.current_r_a + " A" : "-" }
                            Label { text: "Current T" }
                            Label { text: values.current_t_a !== undefined ? values.current_t_a + " A" : "-" }
                            Label { text: "Measured" }
                            Label { text: status.last_measurement_at || "-" }
                        }
                    }

                    GroupBox {
                        title: "Power Trend"
                        Layout.fillWidth: true

                        Canvas {
                            id: powerChart
                            height: 180
                            anchors.left: parent.left
                            anchors.right: parent.right

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                ctx.fillStyle = "#fafafa"
                                ctx.fillRect(0, 0, width, height)
                                ctx.strokeStyle = "#d0d0d0"
                                ctx.lineWidth = 1
                                for (var g = 1; g < 4; ++g) {
                                    var y = height * g / 4
                                    ctx.beginPath()
                                    ctx.moveTo(0, y)
                                    ctx.lineTo(width, y)
                                    ctx.stroke()
                                }
                                if (root.powerSamples.length < 2)
                                    return

                                var maxValue = 1
                                for (var i = 0; i < root.powerSamples.length; ++i)
                                    maxValue = Math.max(maxValue, root.powerSamples[i])

                                ctx.strokeStyle = "#1769aa"
                                ctx.lineWidth = 2
                                ctx.beginPath()
                                for (var p = 0; p < root.powerSamples.length; ++p) {
                                    var x = width * p / (root.powerSamples.length - 1)
                                    var py = height - (root.powerSamples[p] / maxValue) * (height - 12) - 6
                                    if (p === 0)
                                        ctx.moveTo(x, py)
                                    else
                                        ctx.lineTo(x, py)
                                }
                                ctx.stroke()

                                ctx.fillStyle = "#333"
                                ctx.font = "12px sans-serif"
                                ctx.fillText("max " + Math.round(maxValue) + " W", 8, 18)
                            }
                        }
                    }
                }
            }

            ScrollView {
                contentWidth: availableWidth

                ColumnLayout {
                    width: parent.width
                    spacing: 10

                    RowLayout {
                        Button {
                            text: "Load Config"
                            onClicked: cubeClient.fetchConfig()
                        }

                        Button {
                            text: "Save"
                            onClicked: root.saveConfigFromFields()
                        }

                        CheckBox {
                            id: restartBridgeCheck
                            text: "Restart bridge"
                            checked: true
                        }
                    }

                    GridLayout {
                        columns: 2
                        Layout.fillWidth: true

                        Label { text: "B-route ID" }
                        TextField { id: brIdField; text: root.textValue("br_id"); Layout.fillWidth: true }
                        Label { text: "B-route Password" }
                        TextField { id: brPwdField; text: root.textValue("br_pwd"); echoMode: TextInput.Password; Layout.fillWidth: true }
                        Label { text: "MQTT Host" }
                        TextField { id: mqttHostField; text: root.textValue("mqtt_host"); Layout.fillWidth: true }
                        Label { text: "MQTT Port" }
                        SpinBox { id: mqttPortField; from: 1; to: 65535; value: root.numberValue("mqtt_port", 1883); Layout.fillWidth: true }
                        Label { text: "MQTT User" }
                        TextField { id: mqttUserField; text: root.textValue("mqtt_user"); Layout.fillWidth: true }
                        Label { text: "MQTT Password" }
                        TextField { id: mqttPassField; text: root.textValue("mqtt_pass"); echoMode: TextInput.Password; Layout.fillWidth: true }
                        Label { text: "Device ID" }
                        TextField { id: deviceIdField; text: root.textValue("device_id", "cubej1"); Layout.fillWidth: true }
                        Label { text: "Serial Port" }
                        TextField { id: serialPortField; text: root.textValue("serial_port", "/dev/ttyS1"); Layout.fillWidth: true }
                        Label { text: "Poll Interval" }
                        SpinBox { id: pollIntervalField; from: 1; to: 3600; value: root.numberValue("poll_interval", 60); Layout.fillWidth: true }
                        Label { text: "Web Port" }
                        SpinBox { id: webPortField; from: 1; to: 65535; value: root.numberValue("web_port", 8080); Layout.fillWidth: true }
                        Label { text: "Web User" }
                        TextField { id: webUserField; text: root.textValue("web_user", "admin"); Layout.fillWidth: true }
                        Label { text: "Web Password" }
                        TextField { id: webPassField; text: root.textValue("web_pass", "cubej1"); echoMode: TextInput.Password; Layout.fillWidth: true }
                    }
                }
            }

            ColumnLayout {
                spacing: 10

                RowLayout {
                    Button {
                        text: "Bridge"
                        onClicked: cubeClient.fetchBridgeLog()
                    }

                    Button {
                        text: "Serial"
                        onClicked: cubeClient.fetchSerialLog()
                    }

                    Label {
                        text: root.logName
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                    }
                }

                TextArea {
                    text: root.logText
                    readOnly: true
                    wrapMode: TextArea.NoWrap
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    font.family: "monospace"
                }
            }

            ScrollView {
                contentWidth: availableWidth

                ColumnLayout {
                    width: parent.width
                    spacing: 12

                    GroupBox {
                        title: "Discovered"
                        Layout.fillWidth: true

                        ColumnLayout {
                            anchors.fill: parent

                            Button {
                                text: deviceDiscovery.scanning ? "Scanning..." : "Find Cube J1"
                                enabled: !deviceDiscovery.scanning
                                onClicked: deviceDiscovery.start()
                            }

                            Repeater {
                                model: deviceDiscovery.devices
                                delegate: Button {
                                    Layout.fillWidth: true
                                    text: modelData.name + "  " + modelData.host + ":" + modelData.port
                                    onClicked: {
                                        cubeClient.host = modelData.host
                                        cubeClient.port = modelData.port
                                        cubeClient.fetchStatus()
                                    }
                                }
                            }
                        }
                    }

                    GroupBox {
                        title: "Device"
                        Layout.fillWidth: true

                        ColumnLayout {
                            anchors.fill: parent

                            Button {
                                text: "Reboot Cube J1"
                                onClicked: confirmReboot.open()
                            }
                        }
                    }
                }
            }
        }
    }

    Dialog {
        id: confirmReboot
        title: "Reboot Cube J1"
        modal: true
        standardButtons: Dialog.Ok | Dialog.Cancel
        anchors.centerIn: parent

        Label {
            text: "Send reboot command?"
        }

        onAccepted: cubeClient.reboot()
    }
}
