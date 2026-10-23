#ifndef INSTRUCTOR_H
#define INSTRUCTOR_H

#include <QList>
#include <QObject>
#include <QString>
#include <QStringList>

class Instructor : public QObject
{
    Q_OBJECT

    // Propiedades que ya usaba Main.qml.
    Q_PROPERTY(QString mode READ mode WRITE setMode NOTIFY modeChanged)
    Q_PROPERTY(QStringList turnNames READ turnNames CONSTANT)
    Q_PROPERTY(int currentTurnIndex READ currentTurnIndex
                   WRITE setCurrentTurnIndex NOTIFY currentTurnChanged)
    Q_PROPERTY(QString currentTurnName READ currentTurnName
                   NOTIFY currentTurnChanged)
    Q_PROPERTY(QString instruction READ instruction
                   NOTIFY instructionChanged)

    // Datos de la tarjeta de instrucciones.
    Q_PROPERTY(int targetSpeed READ targetSpeed NOTIFY currentTurnChanged)
    Q_PROPERTY(int targetGear READ targetGear NOTIFY currentTurnChanged)
    Q_PROPERTY(int brakeDistance READ brakeDistance NOTIFY currentTurnChanged)
    Q_PROPERTY(QString keyPrinciple READ keyPrinciple
                   NOTIFY currentTurnChanged)

    // Nueva: explicación completa de la curva para el modo navegación del mapa.
    Q_PROPERTY(QString briefing READ briefing NOTIFY instructionChanged)

public:
    explicit Instructor(QObject *parent = nullptr);

    QString mode() const;
    void setMode(const QString &mode);

    QStringList turnNames() const;
    int currentTurnIndex() const;
    void setCurrentTurnIndex(int index);

    QString currentTurnName() const;
    QString instruction() const;

    // Velocidad de paso por el vértice, en km/h.
    int targetSpeed() const;
    // Marcha en el vértice.
    int targetGear() const;
    // Metros desde el punto de frenada hasta la curva. 0 significa sin frenar.
    int brakeDistance() const;
    // Frase corta con el principio de conducción de la curva.
    QString keyPrinciple() const;
    // Explicación del ingeniero: posición, frenada, vértice, salida y datos.
    QString briefing() const;

signals:
    void modeChanged();
    void currentTurnChanged();
    void instructionChanged();

private:
    struct TurnData
    {
        QString name;
        QString kind;        // descripción corta del tipo de curva
        QString side;        // "izquierda" o "derecha": por dónde acercarse
        int approachSpeed;   // km/h al llegar al punto de frenada
        int brakeDistance;   // m hasta la curva (0 = sin frenar)
        int apexSpeed;       // km/h en el vértice
        int gear;            // marcha en el vértice
        int exitGear;        // marcha a la salida
        int difficulty;      // 1 a 5
        QString principle;   // principio clave
    };

    // Devuelve la curva actual, o nullptr si el índice no es válido.
    const TurnData *currentTurn() const;

    QString m_mode = "simple";
    int m_currentTurnIndex = 0;

    QList<TurnData> m_turns;
    QStringList m_turnNames;
};

#endif
