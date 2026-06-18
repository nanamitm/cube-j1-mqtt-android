#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>

#include "CubeJClient.h"
#include "DeviceDiscovery.h"

int main(int argc, char *argv[])
{
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QGuiApplication app(argc, argv);

    CubeJClient client;
    DeviceDiscovery discovery;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("cubeClient", &client);
    engine.rootContext()->setContextProperty("deviceDiscovery", &discovery);
    engine.loadFromModule("CubeJ1", "Main");

    if (engine.rootObjects().isEmpty()) {
        return -1;
    }

    return app.exec();
}
