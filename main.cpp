#include <QCoreApplication>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQmlContext>

#include "instructor.h"
#include "telemetry.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);

    // (NUEVO) Necesario para que QSettings recuerde la IP de la consola.
    // Debe ir antes de crear Telemetry.
    QCoreApplication::setOrganizationName(QStringLiteral("GT7_Copilot"));
    QCoreApplication::setApplicationName(QStringLiteral("GT7_Copilot"));

    QQmlApplicationEngine engine;

    Instructor instructor;
    Telemetry telemetry;

    engine.rootContext()->setContextProperty(
        "instructor", &instructor
        );
    engine.rootContext()->setContextProperty(
        "telemetry", &telemetry
        );

    // Si ya conectaste antes, vuelve a conectar solo con la última IP.
    if (!telemetry.consoleAddress().isEmpty())
        telemetry.start(telemetry.consoleAddress());


    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection
        );

    engine.loadFromModule("GT7_copilot", "Main");

    return QGuiApplication::exec();
}

