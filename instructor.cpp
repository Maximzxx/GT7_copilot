#include "instructor.h"

#include <algorithm>
#include <utility>

Instructor::Instructor(QObject *parent)
    : QObject(parent)
{
    // Tabla generada por build_spa.py + gen_instructor.py desde la misma fuente
    // que el mapa. Las curvas y su orden salen de la geometría real del circuito.
    //
    // VALORES DE REFERENCIA, NO MEDIDOS. Las velocidades, marchas, distancias de
    // frenada y la dificultad son aproximaciones para un auto de carreras de
    // potencia media. Ajústa con tus vueltas o con la telemetría.
    //
    //   nombre, tipo, lado de aproximación,
    //   entra (km/h), frena (m), vértice (km/h), marcha, salida (marcha), dificultad,
    //   principio clave
    m_turns = {
        {
            QStringLiteral("La Source"),
            QStringLiteral("Horquilla a derechas"),
            QStringLiteral("izquierda"),
            235, 110, 65, 2, 3, 3,
            QStringLiteral("Frena recto por la izquierda, gira tarde hacia el vértice interior y prioriza una salida limpia: lo que pierdas aquí lo arrastras hasta Eau Rouge.")
        },
        {
            QStringLiteral("Eau Rouge"),
            QStringLiteral("Izquierda rápida en el fondo del valle"),
            QStringLiteral("derecha"),
            245, 0, 235, 5, 5, 5,
            QStringLiteral("Entra desde la derecha, mantén el volante suave y el acelerador estable. Esta curva prepara la entrada al Raidillon.")
        },
        {
            QStringLiteral("Raidillon"),
            QStringLiteral("Derecha en subida con cresta ciega"),
            QStringLiteral("izquierda"),
            235, 0, 220, 5, 6, 5,
            QStringLiteral("Mira hacia la cima, no corrijas en la cresta y sal pegado a la izquierda para tomar la recta de Kemmel.")
        },
        {
            QStringLiteral("Les Combes"),
            QStringLiteral("Chicane derecha-izquierda"),
            QStringLiteral("izquierda"),
            285, 150, 110, 3, 4, 4,
            QStringLiteral("Frena recto desde la izquierda, entra desde adentro y ataca el piano interior. Prioriza la salida hacia Malmedy.")
        },
        {
            QStringLiteral("Malmedy"),
            QStringLiteral("Derecha media"),
            QStringLiteral("izquierda"),
            165, 40, 100, 3, 4, 2,
            QStringLiteral("Frenada corta, vértice interior y salida estable para llegar bien a Bruxelles.")
        },
        {
            QStringLiteral("Bruxelles"),
            QStringLiteral("Horquilla a derechas"),
            QStringLiteral("izquierda"),
            190, 80, 85, 2, 3, 3,
            QStringLiteral("Entra por la izquierda, gira tarde y acelera pronto. Una buena salida vale mucho en la subida siguiente.")
        },
        {
            QStringLiteral("Speaker's Corner"),
            QStringLiteral("Izquierda lenta"),
            QStringLiteral("derecha"),
            150, 40, 90, 3, 3, 2,
            QStringLiteral("Frena antes de girar y busca una salida recta hacia Pouhon.")
        },
        {
            QStringLiteral("Pouhon"),
            QStringLiteral("Doble vértice a izquierdas, rápida y en bajada"),
            QStringLiteral("derecha"),
            235, 60, 185, 4, 5, 5,
            QStringLiteral("Frenada ligera, un solo movimiento de volante y paciencia entre los dos vértices. No cierres de más el primero.")
        },
        {
            QStringLiteral("Fagnes"),
            QStringLiteral("Chicane derecha-izquierda"),
            QStringLiteral("izquierda"),
            205, 70, 105, 3, 4, 3,
            QStringLiteral("Frena recto, usa el piano interior de la derecha y prepara el cambio de dirección sin perder el equilibrio.")
        },
        {
            QStringLiteral("Stavelot"),
            QStringLiteral("Derecha larga de doble vértice"),
            QStringLiteral("izquierda"),
            190, 50, 95, 3, 4, 3,
            QStringLiteral("Entra desde la izquierda y espera el segundo vértice antes de acelerar.")
        },
        {
            QStringLiteral("Paul Frère"),
            QStringLiteral("Derecha leve y rápida"),
            QStringLiteral("izquierda"),
            250, 0, 245, 6, 6, 2,
            QStringLiteral("No la subestimes: mantén una línea limpia para llegar bien a Blanchimont.")
        },
        {
            QStringLiteral("Blanchimont"),
            QStringLiteral("Izquierda larga a fondo"),
            QStringLiteral("derecha"),
            265, 0, 255, 6, 6, 4,
            QStringLiteral("Acelerador firme, volante suave y trayectoria estable. Sal pegado a la derecha para preparar el Bus Stop.")
        },
        {
            QStringLiteral("Bus Stop"),
            QStringLiteral("Chicane derecha-izquierda lenta"),
            QStringLiteral("izquierda"),
            265, 110, 70, 2, 3, 4,
            QStringLiteral("Frena recto desde la izquierda, usa los pianos con cuidado y acelera al terminar el segundo giro.")
        }
    };

    for (const TurnData &turn : std::as_const(m_turns))
        m_turnNames.append(turn.name);
}

QString Instructor::mode() const
{
    return m_mode;
}

void Instructor::setMode(const QString &mode)
{
    if (mode != "simple" && mode != "rally")
        return;

    if (m_mode == mode)
        return;

    m_mode = mode;
    emit modeChanged();
    emit instructionChanged();
}

QStringList Instructor::turnNames() const
{
    return m_turnNames;
}

int Instructor::currentTurnIndex() const
{
    return m_currentTurnIndex;
}

void Instructor::setCurrentTurnIndex(int index)
{
    if (m_turns.isEmpty())
        return;

    index = std::clamp(index, 0, static_cast<int>(m_turns.size()) - 1);

    if (m_currentTurnIndex == index)
        return;

    m_currentTurnIndex = index;

    emit currentTurnChanged();
    emit instructionChanged();
}

const Instructor::TurnData *Instructor::currentTurn() const
{
    if (m_currentTurnIndex < 0 || m_currentTurnIndex >= m_turns.size())
        return nullptr;

    return &m_turns.at(m_currentTurnIndex);
}

QString Instructor::currentTurnName() const
{
    const TurnData *turn = currentTurn();
    return turn ? turn->name : QString();
}

int Instructor::targetSpeed() const
{
    const TurnData *turn = currentTurn();
    return turn ? turn->apexSpeed : 0;
}

int Instructor::targetGear() const
{
    const TurnData *turn = currentTurn();
    return turn ? turn->gear : 0;
}

int Instructor::brakeDistance() const
{
    const TurnData *turn = currentTurn();
    return turn ? turn->brakeDistance : 0;
}

QString Instructor::keyPrinciple() const
{
    const TurnData *turn = currentTurn();
    return turn ? turn->principle : QString();
}

QString Instructor::instruction() const
{
    const TurnData *turn = currentTurn();
    if (!turn)
        return QString();

    const bool brakes = turn->brakeDistance > 0;

    if (m_mode == "rally") {
        // Modo detallado: velocidad de llegada, frenada, marchas y vértice.
        if (brakes) {
            return QStringLiteral("A %1 km/h, frena a %2 m. Baja a %3.ª. "
                                  "Vértice a %4 km/h. Salida en %5.ª.")
                .arg(turn->approachSpeed)
                .arg(turn->brakeDistance)
                .arg(turn->gear)
                .arg(turn->apexSpeed)
                .arg(turn->exitGear);
        }

        return QStringLiteral("Entra a %1 km/h sin frenar. Mantén %2.ª. "
                              "Vértice a %3 km/h. Salida en %4.ª.")
            .arg(turn->approachSpeed)
            .arg(turn->gear)
            .arg(turn->apexSpeed)
            .arg(turn->exitGear);
    }

    // Modo simple: lo mínimo para actuar.
    if (brakes) {
        return QStringLiteral("Frena a %1 m, baja a %2.ª y pasa a %3 km/h.")
            .arg(turn->brakeDistance)
            .arg(turn->gear)
            .arg(turn->apexSpeed);
    }

    return QStringLiteral("Sin frenar: mantén %1.ª y pasa a %2 km/h.")
        .arg(turn->gear)
        .arg(turn->apexSpeed);
}

QString Instructor::briefing() const
{
    const TurnData *turn = currentTurn();
    if (!turn)
        return QString();

    const bool brakes = turn->brakeDistance > 0;

    if (m_mode == "rally") {
        // Explicación completa del ingeniero, con los datos de la curva.
        QString text = QStringLiteral("Se aproxima %1. Colócate a la %2")
                           .arg(turn->name)
                           .arg(turn->side);

        if (brakes) {
            text += QStringLiteral(", prepara la frenada a %1 m desde %2 km/h y baja a %3.ª. ")
                        .arg(turn->brakeDistance)
                        .arg(turn->approachSpeed)
                        .arg(turn->gear);
        } else {
            text += QStringLiteral(" y mantén el acelerador: esta curva se toma sin frenar, en %1.ª. ")
                        .arg(turn->gear);
        }

        text += QStringLiteral("Busca una entrada limpia hacia el vértice interior, pasa a %1 km/h "
                               "y prioriza una buena salida en %2.ª. ")
                    .arg(turn->apexSpeed)
                    .arg(turn->exitGear);
        text += turn->principle;
        return text;
    }

    if (brakes) {
        return QStringLiteral("Se aproxima %1. Colócate a la %2, frena a %3 m, baja a %4.ª y pasa a %5 km/h.")
            .arg(turn->name)
            .arg(turn->side)
            .arg(turn->brakeDistance)
            .arg(turn->gear)
            .arg(turn->apexSpeed);
    }

    return QStringLiteral("Se aproxima %1. Colócate a la %2, sin frenar: mantén %3.ª y pasa a %4 km/h.")
        .arg(turn->name)
        .arg(turn->side)
        .arg(turn->gear)
        .arg(turn->apexSpeed);
}
