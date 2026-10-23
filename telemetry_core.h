#ifndef TELEMETRY_CORE_H
#define TELEMETRY_CORE_H

// Estado de la telemetría a partir de los paquetes decodificados.
// Sin dependencias de Qt: la clase Telemetry solo conecta sockets y propiedades.

#include <algorithm>
#include <cmath>

#include "gt7packet.h"

namespace gt7 {

struct State
{
    double speedKmh = 0;
    double rpm = 0;
    double rpmMax = 0;
    double throttle = 0;        // 0 a 1
    double brake = 0;           // 0 a 1
    int gear = 0;               // -1 = R, 0 = N, 1 en adelante = marcha
    int suggestedGear = 0;      // 0 si el juego no sugiere ninguna
    int lap = 0;
    int totalLaps = 0;
    int lastLapMs = -1;
    int bestLapMs = -1;
    double posX = 0, posY = 0, posZ = 0;     // metros; Y es la altura
    double heading = 0;         // radianes, atan2(vz, vx) en el plano del suelo
    bool onTrack = false;
    bool paused = false;
    bool loading = false;

    void apply(const Sample &s)
    {
        speedKmh = static_cast<double>(s.speedMs) * 3.6;
        rpm = s.rpm;
        // maxAlertRpm es el régimen donde el juego avisa del limitador: sirve de
        // línea roja. Si no viene, se usa el máximo visto.
        rpmMax = s.maxAlertRpm > 0 ? static_cast<double>(s.maxAlertRpm)
                                   : std::max({rpmMax, static_cast<double>(s.rpm), 1000.0});
        throttle = std::clamp(static_cast<double>(s.throttle), 0.0, 1.0);
        brake = std::clamp(static_cast<double>(s.brake), 0.0, 1.0);

        // Supuesto sin verificar: la marcha 0 con "en marcha" activo se interpreta como
        // reversa, y sin él como neutral. Compruébalo metiendo reversa en el juego.
        gear = (s.gear == 0 && s.inGear()) ? -1 : s.gear;
        suggestedGear = (s.suggestedGear == 15) ? 0 : s.suggestedGear;

        lap = s.lapCount;
        totalLaps = s.totalLaps;
        lastLapMs = s.lastLapMs;
        bestLapMs = s.bestLapMs;
        posX = s.posX;
        posY = s.posY;
        posZ = s.posZ;
        if (std::hypot(static_cast<double>(s.velX), static_cast<double>(s.velZ)) > 2.0)
            heading = std::atan2(static_cast<double>(s.velZ), static_cast<double>(s.velX));
        onTrack = s.onTrack();
        paused = s.paused();
        loading = s.loading();
    }
};

} // namespace gt7

#endif
