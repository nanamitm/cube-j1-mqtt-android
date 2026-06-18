#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickStyle>

#include "CubeJClient.h"
#include "DeviceDiscovery.h"
#include "ThemeController.h"

int main(int argc, char *argv[])
{
    QQuickStyle::setStyle(QStringLiteral("Basic"));

    QGuiApplication app(argc, argv);

    CubeJClient client;
    DeviceDiscovery discovery;
    ThemeController themeController;

    QQmlApplicationEngine engine;
    engine.rootContext()->setContextProperty("cubeClient", &client);
    engine.rootContext()->setContextProperty("deviceDiscovery", &discovery);
    engine.rootContext()->setContextProperty("themeController", &themeController);
    engine.loadFromModule("CubeJ1", "Main");

    if (engine.rootObjects().isEmpty()) {
        return -1;
    }

    return app.exec();
}
