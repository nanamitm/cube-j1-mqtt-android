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

    palette.window: themeController.dark ? "#181b20" : "#f5f6f8"
    palette.windowText: themeController.dark ? "#edf1f5" : "#15171a"
    palette.base: themeController.dark ? "#22262d" : "#ffffff"
    palette.alternateBase: themeController.dark ? "#2b3038" : "#eef1f4"
    palette.text: themeController.dark ? "#edf1f5" : "#15171a"
    palette.button: themeController.dark ? "#303640" : "#eef1f4"
    palette.buttonText: themeController.dark ? "#edf1f5" : "#15171a"
    palette.highlight: "#1769aa"
    palette.highlightedText: "#ffffff"
    palette.mid: themeController.dark ? "#566170" : "#c9ced6"
    palette.dark: themeController.dark ? "#111317" : "#7a8491"
    palette.light: themeController.dark ? "#3a414c" : "#ffffff"
    palette.placeholderText: themeController.dark ? "#a8b1bd" : "#687180"

    property var status: ({})
    property var values: ({})
    property var config: ({})
    property var powerSamples: []
    property var currentRSamples: []
    property var currentTSamples: []
    property string logText: ""
    property string logName: ""
    property string message: ""
    property bool autoRefresh: true
    property bool showSettings: false
    property bool autoConnectDone: false
    property color panelColor: themeController.dark ? "#20242a" : "#ffffff"
    property color chartBackground: themeController.dark ? "#242932" : "#fafafa"
    property color chartGrid: themeController.dark ? "#3a414c" : "#d0d0d0"
    property color chartText: themeController.dark ? "#dce3ea" : "#333333"
    property color successColor: themeController.dark ? "#7bd88f" : "#2d6a4f"
    property color errorColor: themeController.dark ? "#ff8a9a" : "crimson"

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

    function formatKwh(value) {
        if (value === undefined || value === null || value === "")
            return "-"
        var num = Number(value)
        if (isNaN(num))
            return "-"
        return (Math.floor(num * 1000) / 1000).toFixed(3)
    }

    function pushSample(samples, value) {
        var next = samples.slice()
        next.push(value)
        while (next.length > 60)
            next.shift()
        return next
    }

    function combinedRange(seriesList) {
        var minValue = null
        var maxValue = null
        for (var s = 0; s < seriesList.length; ++s) {
            var samples = seriesList[s]
            for (var i = 0; i < samples.length; ++i) {
                if (minValue === null || samples[i] < minValue)
                    minValue = samples[i]
                if (maxValue === null || samples[i] > maxValue)
                    maxValue = samples[i]
            }
        }
        if (minValue === null) {
            minValue = 0
            maxValue = 1
        }
        var range = maxValue - minValue
        if (range < 1e-6)
            range = 1
        return { "min": minValue, "range": range }
    }

    function paintSeries(ctx, samples, color, width, height, minValue, range) {
        if (samples.length < 2)
            return

        ctx.strokeStyle = color
        ctx.lineWidth = 2
        ctx.beginPath()
        for (var p = 0; p < samples.length; ++p) {
            var x = width * p / (samples.length - 1)
            var py = height - ((samples[p] - minValue) / range) * (height - 12) - 6
            if (p === 0)
                ctx.moveTo(x, py)
            else
                ctx.lineTo(x, py)
        }
        ctx.stroke()
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

    function retryAutoDiscovery() {
        root.autoConnectDone = false
        deviceDiscovery.start()
        discoveryTimeoutTimer.restart()
    }

    Component.onCompleted: {
        deviceDiscovery.start()
        discoveryTimeoutTimer.start()
    }

    Connections {
        target: cubeClient

        function onStatusReceived(s) {
            root.status = s
            root.values = s.last_values || {}
            if (root.values.power_w !== undefined)
                root.powerSamples = root.pushSample(root.powerSamples, Number(root.values.power_w))
            if (root.values.current_r_a !== undefined)
                root.currentRSamples = root.pushSample(root.currentRSamples, Number(root.values.current_r_a))
            if (root.values.current_t_a !== undefined)
                root.currentTSamples = root.pushSample(root.currentTSamples, Number(root.values.current_t_a))
            powerChart.requestPaint()
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

    Connections {
        target: themeController

        function onDarkChanged() {
            powerChart.requestPaint()
            refreshIcon.requestPaint()
        }
    }

    Connections {
        target: deviceDiscovery

        function onDevicesChanged() {
            if (root.autoConnectDone || deviceDiscovery.devices.length === 0)
                return
            var device = deviceDiscovery.devices[0]
            root.autoConnectDone = true
            discoveryTimeoutTimer.stop()
            deviceDiscovery.stop()
            cubeClient.host = device.host
            cubeClient.port = device.port
            cubeClient.fetchStatus()
        }
    }

    Timer {
        id: discoveryTimeoutTimer
        interval: 8000
        onTriggered: {
            if (!root.autoConnectDone)
                deviceDiscovery.stop()
        }
    }

    Timer {
        interval: 5000
        running: root.autoRefresh
        repeat: true
        triggeredOnStart: true
        onTriggered: cubeClient.fetchStatus()
    }

    header: ToolBar {
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 4

            Label {
                text: root.showSettings ? "Settings" : "Cube J1 MQTT"
                font.bold: true
                font.pixelSize: 18
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            BusyIndicator {
                visible: !root.showSettings && (cubeClient.busy || deviceDiscovery.scanning)
                running: visible
                implicitWidth: 24
                implicitHeight: 24
            }

            ToolButton {
                visible: !root.showSettings
                onClicked: cubeClient.fetchStatus()

                contentItem: Canvas {
                    id: refreshIcon
                    implicitWidth: 16
                    implicitHeight: 16

                    onPaint: {
                        var ctx = getContext("2d")
                        ctx.reset()
                        var cx = width / 2
                        var cy = height / 2
                        var r = Math.min(width, height) / 2 - 3

                        ctx.strokeStyle = palette.buttonText
                        ctx.lineWidth = 2
                        ctx.beginPath()
                        ctx.arc(cx, cy, r, -Math.PI * 0.85, Math.PI * 0.6, false)
                        ctx.stroke()

                        var endAngle = Math.PI * 0.6
                        var ex = cx + r * Math.cos(endAngle)
                        var ey = cy + r * Math.sin(endAngle)
                        var headLen = 5
                        ctx.beginPath()
                        ctx.moveTo(ex, ey)
                        ctx.lineTo(ex - headLen * Math.cos(endAngle - 0.5), ey - headLen * Math.sin(endAngle - 0.5))
                        ctx.lineTo(ex - headLen * Math.cos(endAngle + 0.6), ey - headLen * Math.sin(endAngle + 0.6))
                        ctx.closePath()
                        ctx.fillStyle = palette.buttonText
                        ctx.fill()
                    }
                }
            }

            ToolButton {
                text: root.showSettings ? "←" : "⚙"
                onClicked: root.showSettings = !root.showSettings
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        visible: !root.showSettings

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Label {
                Layout.fillWidth: true
                wrapMode: Text.Wrap
                color: palette.placeholderText
                text: {
                    if (deviceDiscovery.scanning)
                        return "Searching for Cube J1..."
                    if (!root.autoConnectDone)
                        return "Cube J1 not found on the network"
                    var name = status.device_id || cubeClient.host
                    return name + "  (" + cubeClient.host + ":" + cubeClient.port + ")"
                }
            }

            Button {
                visible: !deviceDiscovery.scanning && !root.autoConnectDone
                text: "Retry"
                onClicked: root.retryAutoDiscovery()
            }
        }

        Label {
            visible: !root.autoConnectDone && !deviceDiscovery.scanning
            text: "Open Settings (⚙) to enter the address manually"
            color: palette.placeholderText
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        Label {
            visible: cubeClient.lastError.length > 0
            text: cubeClient.lastError
            color: root.errorColor
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth

            ColumnLayout {
                width: parent.width
                spacing: 12

                GroupBox {
                    title: "Connection"
                    Layout.fillWidth: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 18

                            RowLayout {
                                spacing: 6
                                Rectangle {
                                    width: 10; height: 10; radius: 5
                                    color: status.mqtt_connected ? root.successColor : root.errorColor
                                }
                                Label { text: "MQTT" }
                            }

                            RowLayout {
                                spacing: 6
                                Rectangle {
                                    width: 10; height: 10; radius: 5
                                    color: status.wisun_connected ? root.successColor : root.errorColor
                                }
                                Label { text: "Wi-SUN" }
                            }

                            RowLayout {
                                spacing: 6
                                Rectangle {
                                    width: 10; height: 10; radius: 5
                                    color: status.configuration_required ? root.errorColor : root.successColor
                                }
                                Label { text: status.configuration_required ? "Config required" : "Ready" }
                            }

                            Item { Layout.fillWidth: true }
                        }

                        Label {
                            text: (status.device_id || "-") + "  ·  Updated " + (status.updated_at || "-")
                            color: palette.placeholderText
                            elide: Text.ElideRight
                            Layout.fillWidth: true
                        }

                        Label {
                            visible: !!status.last_error
                            text: status.last_error
                            color: root.errorColor
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
                        Label { text: "Energy" }
                        RowLayout {
                            spacing: 16
                            Label { text: "Fwd " + root.formatKwh(values.energy_forward_kwh) + " kWh" }
                            Label { text: "Rev " + root.formatKwh(values.energy_reverse_kwh) + " kWh" }
                        }
                        Label { text: "Measured" }
                        Label { text: status.last_measurement_at || "-" }
                    }
                }

                GroupBox {
                    title: "Trends"
                    Layout.fillWidth: true

                    ColumnLayout {
                        anchors.fill: parent
                        spacing: 8

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 16

                            RowLayout {
                                spacing: 6
                                Rectangle { width: 10; height: 10; radius: 5; color: "#1769aa" }
                                Label {
                                    font.pixelSize: 12
                                    text: "Power " + (values.power_w !== undefined ? values.power_w + "W" : "-")
                                }
                            }

                            RowLayout {
                                spacing: 6
                                Rectangle { width: 10; height: 10; radius: 5; color: "#e8871e" }
                                Label {
                                    font.pixelSize: 12
                                    text: "R " + (values.current_r_a !== undefined ? values.current_r_a + "A" : "-")
                                }
                            }

                            RowLayout {
                                spacing: 6
                                Rectangle { width: 10; height: 10; radius: 5; color: "#8e44ad" }
                                Label {
                                    font.pixelSize: 12
                                    text: "T " + (values.current_t_a !== undefined ? values.current_t_a + "A" : "-")
                                }
                            }

                            Item { Layout.fillWidth: true }
                        }

                        Label {
                            text: "R/T scaled ×100 to align with Power"
                            font.pixelSize: 11
                            color: palette.placeholderText
                        }

                        Canvas {
                            id: powerChart
                            Layout.fillWidth: true
                            Layout.preferredHeight: 180

                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.reset()
                                ctx.fillStyle = root.chartBackground
                                ctx.fillRect(0, 0, width, height)
                                ctx.strokeStyle = root.chartGrid
                                ctx.lineWidth = 1
                                for (var g = 1; g < 4; ++g) {
                                    var y = height * g / 4
                                    ctx.beginPath()
                                    ctx.moveTo(0, y)
                                    ctx.lineTo(width, y)
                                    ctx.stroke()
                                }

                                var scaledR = root.currentRSamples.map(function(v) { return v * 100 })
                                var scaledT = root.currentTSamples.map(function(v) { return v * 100 })
                                var shared = root.combinedRange([root.powerSamples, scaledR, scaledT])

                                root.paintSeries(ctx, root.powerSamples, "#1769aa", width, height, shared.min, shared.range)
                                root.paintSeries(ctx, scaledR, "#e8871e", width, height, shared.min, shared.range)
                                root.paintSeries(ctx, scaledT, "#8e44ad", width, height, shared.min, shared.range)
                            }
                        }
                    }
                }
            }
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        visible: root.showSettings

        Label {
            visible: root.message.length > 0
            text: root.message
            color: root.successColor
            wrapMode: Text.Wrap
            Layout.fillWidth: true
        }

        TabBar {
            id: tabs
            Layout.fillWidth: true

            TabButton { text: "Connection" }
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

                    RowLayout {
                        Layout.fillWidth: true

                        TextField {
                            text: cubeClient.host
                            placeholderText: "cubej1.local"
                            Layout.fillWidth: true
                            onEditingFinished: {
                                cubeClient.host = text
                                root.autoConnectDone = true
                            }
                        }

                        SpinBox {
                            from: 1
                            to: 65535
                            value: cubeClient.port
                            onValueModified: {
                                cubeClient.port = value
                                root.autoConnectDone = true
                            }
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
                            text: deviceDiscovery.scanning ? "Stop" : "Find"
                            onClicked: {
                                if (deviceDiscovery.scanning)
                                    deviceDiscovery.stop()
                                else
                                    deviceDiscovery.start()
                            }
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
                        color: root.errorColor
                        wrapMode: Text.Wrap
                        Layout.fillWidth: true
                    }
                }
            }

            ScrollView {
                contentWidth: availableWidth

                ColumnLayout {
                    width: parent.width
                    spacing: 10

                    Flow {
                        Layout.fillWidth: true
                        spacing: 8

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

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2

                        Label { text: "B-route ID"; font.pixelSize: 12; color: palette.placeholderText }
                        TextField { id: brIdField; text: root.textValue("br_id"); Layout.fillWidth: true }
                        Label { text: "B-route Password"; font.pixelSize: 12; color: palette.placeholderText }
                        TextField { id: brPwdField; text: root.textValue("br_pwd"); echoMode: TextInput.Password; Layout.fillWidth: true }
                        Label { text: "MQTT Host"; font.pixelSize: 12; color: palette.placeholderText }
                        TextField { id: mqttHostField; text: root.textValue("mqtt_host"); Layout.fillWidth: true }
                        Label { text: "MQTT Port"; font.pixelSize: 12; color: palette.placeholderText }
                        SpinBox { id: mqttPortField; from: 1; to: 65535; value: root.numberValue("mqtt_port", 1883); Layout.fillWidth: true }
                        Label { text: "MQTT User"; font.pixelSize: 12; color: palette.placeholderText }
                        TextField { id: mqttUserField; text: root.textValue("mqtt_user"); Layout.fillWidth: true }
                        Label { text: "MQTT Password"; font.pixelSize: 12; color: palette.placeholderText }
                        TextField { id: mqttPassField; text: root.textValue("mqtt_pass"); echoMode: TextInput.Password; Layout.fillWidth: true }
                        Label { text: "Device ID"; font.pixelSize: 12; color: palette.placeholderText }
                        TextField { id: deviceIdField; text: root.textValue("device_id", "cubej1"); Layout.fillWidth: true }
                        Label { text: "Serial Port"; font.pixelSize: 12; color: palette.placeholderText }
                        TextField { id: serialPortField; text: root.textValue("serial_port", "/dev/ttyS1"); Layout.fillWidth: true }
                        Label { text: "Poll Interval"; font.pixelSize: 12; color: palette.placeholderText }
                        SpinBox { id: pollIntervalField; from: 1; to: 3600; value: root.numberValue("poll_interval", 60); Layout.fillWidth: true }
                        Label { text: "Web Port"; font.pixelSize: 12; color: palette.placeholderText }
                        SpinBox { id: webPortField; from: 1; to: 65535; value: root.numberValue("web_port", 8080); Layout.fillWidth: true }
                        Label { text: "Web User"; font.pixelSize: 12; color: palette.placeholderText }
                        TextField { id: webUserField; text: root.textValue("web_user", "admin"); Layout.fillWidth: true }
                        Label { text: "Web Password"; font.pixelSize: 12; color: palette.placeholderText }
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
                                text: deviceDiscovery.scanning ? "Stop discovery" : "Find Cube J1"
                                onClicked: {
                                    if (deviceDiscovery.scanning)
                                        deviceDiscovery.stop()
                                    else
                                        deviceDiscovery.start()
                                }
                            }

                            Label {
                                visible: !deviceDiscovery.scanning && deviceDiscovery.devices.length === 0
                                text: "No devices discovered yet"
                                color: palette.placeholderText
                            }

                            Repeater {
                                model: deviceDiscovery.devices
                                delegate: Button {
                                    Layout.fillWidth: true
                                    text: modelData.name + "  " + modelData.host + ":" + modelData.port
                                    onClicked: {
                                        root.autoConnectDone = true
                                        deviceDiscovery.stop()
                                        cubeClient.host = modelData.host
                                        cubeClient.port = modelData.port
                                        cubeClient.fetchStatus()
                                        root.showSettings = false
                                    }
                                }
                            }

                            RowLayout {
                                Layout.fillWidth: true

                                Label {
                                    text: "Discovery Log"
                                    Layout.fillWidth: true
                                    color: palette.placeholderText
                                }

                                Button {
                                    text: "Clear"
                                    onClicked: deviceDiscovery.clearDebugLog()
                                }
                            }

                            TextArea {
                                text: deviceDiscovery.debugLog
                                readOnly: true
                                wrapMode: TextArea.WrapAnywhere
                                Layout.fillWidth: true
                                Layout.preferredHeight: 180
                                placeholderText: "Discovery events will appear here"
                                font.family: "monospace"
                            }
                        }
                    }

                    GroupBox {
                        title: "Appearance"
                        Layout.fillWidth: true

                        RowLayout {
                            anchors.fill: parent

                            Label {
                                text: "Theme"
                            }

                            ComboBox {
                                id: themeModeBox
                                textRole: "label"
                                valueRole: "value"
                                Layout.fillWidth: true
                                model: [
                                    { "label": "System", "value": "system" },
                                    { "label": "Light", "value": "light" },
                                    { "label": "Dark", "value": "dark" }
                                ]
                                Component.onCompleted: {
                                    for (var i = 0; i < model.length; ++i) {
                                        if (model[i].value === themeController.mode) {
                                            currentIndex = i
                                            break
                                        }
                                    }
                                }
                                onActivated: themeController.mode = currentValue

                                Connections {
                                    target: themeController
                                    function onModeChanged() {
                                        for (var i = 0; i < themeModeBox.model.length; ++i) {
                                            if (themeModeBox.model[i].value === themeController.mode) {
                                                themeModeBox.currentIndex = i
                                                break
                                            }
                                        }
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
