#include "telemetry.h"

#include <QNetworkDatagram>
#include <QSettings>

namespace {

constexpr quint16 kReceivePort = 33740;     // la consola envía los datos a este puerto
constexpr quint16 kHeartbeatPort = 33739;   // la consola recibe el latido en este puerto
constexpr int kHeartbeatMs = 5000;          // la consola corta si pasan ~16 s sin latido
constexpr int kTimeoutMs = 2000;            // sin paquetes durante este tiempo = sin señal
constexpr int kUnreadableAfter = 30;        // datagramas ilegibles antes de avisar

} // namespace

Telemetry::Telemetry(QObject *parent)
    : QObject(parent)
{
    // Requiere QCoreApplication::setOrganizationName/ApplicationName (ver main).
    m_consoleAddress = QSettings().value(QStringLiteral("telemetry/consoleAddress")).toString();

    connect(&m_socket, &QUdpSocket::readyRead, this, &Telemetry::readPending);

    m_heartbeat.setInterval(kHeartbeatMs);
    connect(&m_heartbeat, &QTimer::timeout, this, &Telemetry::sendHeartbeat);

    m_watchdog.setSingleShot(true);
    m_watchdog.setInterval(kTimeoutMs);
    connect(&m_watchdog, &QTimer::timeout, this, &Telemetry::onTimeout);

    m_rateTimer.setInterval(1000);
    connect(&m_rateTimer, &QTimer::timeout, this, &Telemetry::updateRate);
}

bool Telemetry::start(const QString &address)
{
    QHostAddress target;
    if (!target.setAddress(address.trimmed())
        || target.protocol() != QAbstractSocket::IPv4Protocol) {
        setStatus(QStringLiteral("La IP no es válida. Usa el formato 192.168.1.84"));
        return false;
    }

    stop();

    if (!m_socket.bind(QHostAddress::AnyIPv4, kReceivePort,
                       QAbstractSocket::ShareAddress | QAbstractSocket::ReuseAddressHint)) {
        setStatus(QStringLiteral("No se pudo abrir el puerto %1: %2. "
                                 "¿Hay otra aplicación de telemetría abierta?")
                      .arg(kReceivePort)
                      .arg(m_socket.errorString()));
        return false;
    }

    m_console = target;
    m_consoleAddress = target.toString();
    QSettings().setValue(QStringLiteral("telemetry/consoleAddress"), m_consoleAddress);

    m_running = true;
    m_datagrams = 0;
    m_good = 0;
    m_countThisSecond = 0;
    m_pps = 0;

    setStatus(QStringLiteral("Esperando datos de %1. Entra a una pista en GT7.")
                  .arg(m_consoleAddress));
    emit statusChanged();

    sendHeartbeat();
    m_heartbeat.start();
    m_rateTimer.start();
    return true;
}

void Telemetry::stop()
{
    m_heartbeat.stop();
    m_watchdog.stop();
    m_rateTimer.stop();

    if (m_socket.state() != QAbstractSocket::UnconnectedState)
        m_socket.close();

    m_running = false;
    m_pps = 0;
    emit rateChanged();

    setConnected(false);
    setStatus(QStringLiteral("Detenido"));
    emit statusChanged();
}

void Telemetry::sendHeartbeat()
{
    if (!m_running || m_console.isNull())
        return;

    // "A" pide el paquete de 296 bytes, el único disponible en todos los modos.
    m_socket.writeDatagram(QByteArrayLiteral("A"), m_console, kHeartbeatPort);
}

void Telemetry::readPending()
{
    bool changed = false;

    while (m_socket.hasPendingDatagrams()) {
        const QNetworkDatagram datagram = m_socket.receiveDatagram();
        if (!datagram.isValid())
            continue;

        // Solo aceptamos paquetes de la consola configurada.
        if (!datagram.senderAddress().isEqual(m_console, QHostAddress::TolerantConversion))
            continue;

        ++m_datagrams;

        const QByteArray bytes = datagram.data();
        gt7::Sample sample;
        if (!gt7::decode(reinterpret_cast<const std::uint8_t *>(bytes.constData()),
                         static_cast<std::size_t>(bytes.size()), sample)) {
            continue;
        }

        ++m_good;
        ++m_countThisSecond;
        m_state.apply(sample);
        changed = true;
    }

    if (changed) {
        m_watchdog.start();
        setConnected(true);
        emit dataChanged();
    } else if (!m_connected && m_good == 0 && m_datagrams >= kUnreadableAfter) {
        setStatus(QStringLiteral("Llegan datos pero no se pueden leer. "
                                 "Revisa que el juego sea Gran Turismo 7 y esté actualizado."));
    }
}

void Telemetry::onTimeout()
{
    setConnected(false);
    setStatus(QStringLiteral("Sin datos de %1. Entra a una pista en GT7: "
                             "no se envía telemetría en los menús.")
                  .arg(m_consoleAddress));
}

void Telemetry::updateRate()
{
    m_pps = m_countThisSecond;
    m_countThisSecond = 0;
    emit rateChanged();
}

void Telemetry::setStatus(const QString &text)
{
    if (m_status == text)
        return;

    m_status = text;
    emit statusChanged();
}

void Telemetry::setConnected(bool value)
{
    if (m_connected == value)
        return;

    m_connected = value;
    if (value)
        setStatus(QStringLiteral("Conectado a %1").arg(m_consoleAddress));
    emit connectedChanged();
}
