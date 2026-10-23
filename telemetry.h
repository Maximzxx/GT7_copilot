#ifndef TELEMETRY_H
#define TELEMETRY_H

#include <QByteArray>
#include <QHostAddress>
#include <QObject>
#include <QString>
#include <QTimer>
#include <QUdpSocket>

#include "telemetry_core.h"

// Recibe la telemetría de Gran Turismo 7 por UDP.
//
// Cómo funciona el protocolo:
//   1. Esta clase abre el puerto UDP 33740 y envía un "latido" (la letra A) al
//      puerto 33739 de la consola.
//   2. Mientras reciba latidos, la consola envía paquetes cifrados, unas 60 veces
//      por segundo, a la IP que mandó el latido (puerto 33740).
//   3. Hay que repetir el latido; aquí se hace cada 5 s (la consola corta si pasan
//      unos 16 s sin recibirlo).
// La consola solo envía datos mientras estás conduciendo (carrera, contrarreloj, etc.).
class Telemetry : public QObject
{
    Q_OBJECT

    Q_PROPERTY(bool running READ running NOTIFY statusChanged)
    Q_PROPERTY(bool connected READ connected NOTIFY connectedChanged)
    Q_PROPERTY(QString statusText READ statusText NOTIFY statusChanged)
    Q_PROPERTY(QString consoleAddress READ consoleAddress NOTIFY statusChanged)
    Q_PROPERTY(int packetsPerSecond READ packetsPerSecond NOTIFY rateChanged)

    // Datos del auto. Todos avisan juntos con dataChanged.
    Q_PROPERTY(qreal speedKmh READ speedKmh NOTIFY dataChanged)
    Q_PROPERTY(qreal rpm READ rpm NOTIFY dataChanged)
    Q_PROPERTY(qreal rpmMax READ rpmMax NOTIFY dataChanged)
    Q_PROPERTY(int gear READ gear NOTIFY dataChanged)
    Q_PROPERTY(int suggestedGear READ suggestedGear NOTIFY dataChanged)
    Q_PROPERTY(qreal throttle READ throttle NOTIFY dataChanged)
    Q_PROPERTY(qreal brake READ brake NOTIFY dataChanged)
    Q_PROPERTY(int lap READ lap NOTIFY dataChanged)
    Q_PROPERTY(int totalLaps READ totalLaps NOTIFY dataChanged)
    Q_PROPERTY(int lastLapMs READ lastLapMs NOTIFY dataChanged)
    Q_PROPERTY(int bestLapMs READ bestLapMs NOTIFY dataChanged)
    Q_PROPERTY(qreal positionX READ positionX NOTIFY dataChanged)
    Q_PROPERTY(qreal positionY READ positionY NOTIFY dataChanged)
    Q_PROPERTY(qreal positionZ READ positionZ NOTIFY dataChanged)
    Q_PROPERTY(qreal heading READ heading NOTIFY dataChanged)
    Q_PROPERTY(bool onTrack READ onTrack NOTIFY dataChanged)
    Q_PROPERTY(bool paused READ paused NOTIFY dataChanged)

public:
    explicit Telemetry(QObject *parent = nullptr);

    // Empieza a recibir desde la consola con esa IP. Devuelve false si falla.
    Q_INVOKABLE bool start(const QString &address);
    Q_INVOKABLE void stop();

    bool running() const { return m_running; }
    bool connected() const { return m_connected; }
    QString statusText() const { return m_status; }
    QString consoleAddress() const { return m_consoleAddress; }
    int packetsPerSecond() const { return m_pps; }

    qreal speedKmh() const { return m_state.speedKmh; }
    qreal rpm() const { return m_state.rpm; }
    qreal rpmMax() const { return m_state.rpmMax; }
    int gear() const { return m_state.gear; }
    int suggestedGear() const { return m_state.suggestedGear; }
    qreal throttle() const { return m_state.throttle; }
    qreal brake() const { return m_state.brake; }
    int lap() const { return m_state.lap; }
    int totalLaps() const { return m_state.totalLaps; }
    int lastLapMs() const { return m_state.lastLapMs; }
    int bestLapMs() const { return m_state.bestLapMs; }
    qreal positionX() const { return m_state.posX; }
    qreal positionY() const { return m_state.posY; }
    qreal positionZ() const { return m_state.posZ; }
    qreal heading() const { return m_state.heading; }
    bool onTrack() const { return m_state.onTrack; }
    bool paused() const { return m_state.paused; }

signals:
    void statusChanged();
    void connectedChanged();
    void dataChanged();
    void rateChanged();

private slots:
    void readPending();
    void sendHeartbeat();
    void onTimeout();
    void updateRate();

private:
    void setStatus(const QString &text);
    void setConnected(bool value);

    QUdpSocket m_socket;
    QTimer m_heartbeat;
    QTimer m_watchdog;
    QTimer m_rateTimer;

    QHostAddress m_console;
    QString m_consoleAddress;
    QString m_status = QStringLiteral("Detenido");
    bool m_running = false;
    bool m_connected = false;

    gt7::State m_state;
    int m_pps = 0;
    int m_countThisSecond = 0;
    int m_datagrams = 0;       // llegados desde que se pulsó Conectar
    int m_good = 0;            // decodificados correctamente
};

#endif
