// GT7 Copilot: pantalla principal (versión rediseñada).
//
// Contrato con el backend
// -----------------------
// instructor (definido en instructor.h):
//     mode, currentTurnIndex, currentTurnName, turnNames, instruction
//     targetSpeed           velocidad de paso por el vértice, en km/h
//     targetGear            marcha en el vértice
//     brakeDistance         metros hasta la curva donde frenar (0 = sin frenar)
//     keyPrinciple          frase corta con el principio de la curva
// telemetry (opcional: si no existe, el panel muestra datos simulados):
//     connected             bool, true si llegan paquetes UDP
//     speedKmh, rpm, rpmMax real
//     gear                  int (-1 = R, 0 = N, 1 en adelante = marcha)
//     throttle, brake       real de 0 a 1
//     lap                   int
//     lastLapMs, bestLapMs  int en milisegundos
//     Se registra desde C++ con:
//     engine.rootContext()->setContextProperty("telemetry", &telemetryObject);

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic

ApplicationWindow {
    id: window

    visible: true
    width: 1100
    height: 720
    minimumWidth: 640
    minimumHeight: 520
    title: "GT7 Copilot | Sistema de Desarrollo de Pilotos"
    color: backgroundColor
    // Si la fuente no está instalada, Qt usa la del sistema.
    font.family: "Bahnschrift"

    // ------------------------------------------------------------------
    // Estado
    // ------------------------------------------------------------------
    property bool guideVisible: true
    readonly property string trackName: "Spa-Francorchamps"

    // Imágenes satelitales del mapa (opcional). Plantilla con {z}, {x} e {y}.
    // Vacía = el mapa se dibuja sin imágenes. Revisa los términos de uso y la
    // atribución del proveedor que elijas.
    property string satelliteTileUrl: ""
    property string satelliteAttribution: ""
    readonly property string trackCountry: "Bélgica"

    // ------------------------------------------------------------------
    // Tema
    // ------------------------------------------------------------------
    property color backgroundColor: "#0B0F14"
    property color panelColor: "#121922"
    property color cardColor: "#19232F"
    property color canvasColor: "#0B1118"
    property color accentColor: "#67E8F9"
    property color accentSoft: "#17313A"
    property color accentHover: "#1D3E48"
    property color accentDown: "#24505B"
    property color mainText: "#F1F5F9"
    property color mutedText: "#94A3B8"
    property color borderColor: "#283544"
    property color gridColor: "#182632"
    property color trackColor: "#334654"
    property color good: "#4ADE80"
    property color warn: "#FBBF24"
    property color danger: "#F87171"

    readonly property int fsCaption: 12
    readonly property int fsBody: 14
    readonly property int fsLead: 16
    readonly property int fsTitle: 20

    // ------------------------------------------------------------------
    // Fuente de telemetría: backend real si existe, simulación si no.
    // ------------------------------------------------------------------
    readonly property bool hasBackend: (typeof telemetry !== "undefined") && telemetry !== null
    readonly property var tele: hasBackend ? telemetry : demoTelemetry
    readonly property string linkState: !hasBackend ? "demo" : (tele.connected ? "live" : "idle")
    // true cuando hay valores que mostrar (datos reales o simulados); en reposo se muestran guiones.
    readonly property bool dataLive: linkState !== "idle"
    readonly property color linkColor: linkState === "live" ? good
                                       : (linkState === "demo" ? warn : mutedText)
    readonly property string linkText: linkState === "live" ? "Telemetría en vivo"
                                       : (linkState === "demo" ? "Modo demo" : "Sin señal UDP")
    readonly property string linkShort: linkState === "live" ? "En vivo"
                                        : (linkState === "demo" ? "Demo" : "Sin señal")

    readonly property real rpmRatio: {
        if (!dataLive)
            return 0
        var t = tele
        if (isNum(t.rpm) && isNum(t.rpmMax) && t.rpmMax > 0)
            return Math.max(0, Math.min(1, t.rpm / t.rpmMax))
        return 0
    }

    // ------------------------------------------------------------------
    // Utilidades
    // ------------------------------------------------------------------
    function connectConsole(ip) {
        if (hasBackend)
            telemetry.start(ip)
    }

    function stopConsole() {
        if (hasBackend)
            telemetry.stop()
    }

    function withAlpha(c, a) {
        return Qt.rgba(c.r, c.g, c.b, a)
    }

    function pad2(n) {
        return (n < 10 ? "0" : "") + n
    }

    function isNum(v) {
        return v !== undefined && v !== null && !isNaN(v)
    }

    function clamp01(v) {
        return isNum(v) ? Math.max(0, Math.min(1, v)) : 0
    }

    function intText(v) {
        return isNum(v) ? String(Math.round(v)) : "—"
    }

    function gearText(g) {
        if (!isNum(g))
            return "—"
        return g < 0 ? "R" : (g === 0 ? "N" : String(g))
    }

    function lapText(ms) {
        if (!isNum(ms) || ms <= 0)
            return "—"
        var m = Math.floor(ms / 60000)
        var s = Math.floor((ms % 60000) / 1000)
        var t = Math.floor(ms % 1000)
        return m + ":" + (s < 10 ? "0" : "") + s + "." + ("00" + t).slice(-3)
    }

    // Lee una propiedad del instructor que quizá todavía no exista.
    function optional(name) {
        var v = instructor[name]
        return (v === undefined || v === null) ? "" : String(v)
    }

    function cue(name) {
        var v = optional(name)
        return v === "" ? "—" : v
    }

    // ------------------------------------------------------------------
    // Telemetría simulada (solo se usa si no hay backend)
    // ------------------------------------------------------------------
    QtObject {
        id: demoTelemetry

        property bool connected: true
        property real phase: 0
        property real speedKmh: 0
        property int gear: 1
        property real rpm: 3000
        property real rpmMax: 8000
        property real throttle: 0
        property real brake: 0
        property int lap: 1
        property int lastLapMs: 0
        property int bestLapMs: 0
    }

    Timer {
        interval: 50
        repeat: true
        running: !window.hasBackend && window.visible
        onTriggered: {
            var d = demoTelemetry
            var lapSeconds = 24
            d.phase += 0.05

            var u = (d.phase % lapSeconds) / lapSeconds * Math.PI * 2
            var speed = 140 + 100 * Math.sin(u * 3)
            var accel = Math.cos(u * 3)
            var g = Math.min(6, Math.floor(speed / 42) + 1)
            var inGear = Math.max(0, Math.min(1, (speed - (g - 1) * 42) / 42))

            d.speedKmh = speed
            d.gear = g
            d.rpm = 3400 + inGear * 4300
            d.throttle = Math.max(0, accel)
            d.brake = Math.max(0, -accel)
            d.lap = 1 + Math.floor(d.phase / lapSeconds)
            d.lastLapMs = d.lap > 1 ? 138482 : 0
            d.bestLapMs = d.lap > 1 ? 137901 : 0
        }
    }

    // ------------------------------------------------------------------
    // Página
    // ------------------------------------------------------------------
    Flickable {
        id: pageScroll

        anchors.fill: parent
        clip: true
        contentWidth: width
        contentHeight: pageContent.height
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick

        ScrollBar.vertical: ScrollBar {
            policy: ScrollBar.AsNeeded

            contentItem: Rectangle {
                implicitWidth: 6
                radius: 3
                color: parent.pressed ? window.accentColor : window.borderColor
                opacity: parent.size < 1.0 ? 1 : 0
            }
        }

        Item {
            id: pageContent

            width: pageScroll.width
            height: pageLayout.implicitHeight + 48

            ColumnLayout {
                id: pageLayout

                x: 24
                y: 24
                width: Math.max(0, pageContent.width - 48)
                spacing: 22

                // ==========================================================
                // Cabecera
                // ==========================================================
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    Rectangle {
                        Layout.preferredWidth: 46
                        Layout.preferredHeight: 46
                        radius: 12
                        color: window.accentSoft
                        border.color: window.withAlpha(window.accentColor, 0.45)

                        Label {
                            anchors.centerIn: parent
                            text: "GT"
                            color: window.accentColor
                            font.pixelSize: 21
                            font.bold: true
                        }
                    }

                    ColumnLayout {
                        spacing: 2

                        Label {
                            text: "GT7 Copilot"
                            color: window.mainText
                            font.pixelSize: 24
                            font.bold: true
                        }

                        Label {
                            text: "Sistema de desarrollo de pilotos"
                            color: window.mutedText
                            font.pixelSize: window.fsCaption
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Rectangle {
                        radius: height / 2
                        color: window.withAlpha(window.linkColor, 0.12)
                        border.color: window.withAlpha(window.linkColor, 0.40)
                        implicitWidth: statusRow.implicitWidth + 28
                        implicitHeight: 34

                        RowLayout {
                            id: statusRow

                            anchors.centerIn: parent
                            spacing: 8

                            Rectangle {
                                Layout.preferredWidth: 8
                                Layout.preferredHeight: 8
                                radius: 4
                                color: window.linkColor
                            }

                            Label {
                                text: window.linkText
                                color: window.linkColor
                                font.pixelSize: window.fsCaption
                                font.bold: true
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: window.borderColor
                }

                // ==========================================================
                // Contenido principal: crece con su contenido
                // ==========================================================
                GridLayout {
                    id: mainGrid

                    Layout.fillWidth: true
                    columns: width < 760 ? 1 : 2
                    columnSpacing: 20
                    rowSpacing: 24

                    // ------------------------------------------------------
                    // Columna izquierda: contexto
                    // ------------------------------------------------------
                    ColumnLayout {
                        id: leftColumn

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        spacing: 14

                        Label {
                            text: "Ingeniería de carreras"
                            color: window.mutedText
                            font.pixelSize: window.fsBody
                            font.bold: true
                        }

                        // Circuito seleccionado
                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: circuitContent.implicitHeight + 40
                            radius: 14
                            color: window.panelColor
                            border.color: window.borderColor

                            ColumnLayout {
                                id: circuitContent

                                x: 20
                                y: 20
                                width: parent.width - 40
                                spacing: 10

                                Label {
                                    text: "Circuito seleccionado"
                                    color: window.mutedText
                                    font.pixelSize: window.fsCaption
                                }

                                Label {
                                    Layout.fillWidth: true
                                    text: window.trackName
                                    color: window.mainText
                                    font.pixelSize: 28
                                    font.bold: true
                                    wrapMode: Text.WordWrap
                                }

                                Label {
                                    text: window.trackCountry + ", guía del circuito"
                                    color: window.mutedText
                                    font.pixelSize: window.fsBody
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.topMargin: 4
                                    Layout.preferredHeight: 1
                                    color: window.borderColor
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Label {
                                        text: "Conocimiento del trazado"
                                        color: window.mutedText
                                        font.pixelSize: window.fsCaption
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }

                                    Rectangle {
                                        radius: height / 2
                                        color: window.accentSoft
                                        implicitWidth: levelLabel.implicitWidth + 20
                                        implicitHeight: 24

                                        Label {
                                            id: levelLabel

                                            anchors.centerIn: parent
                                            text: "Configuración inicial"
                                            color: window.accentColor
                                            font.pixelSize: window.fsCaption
                                            font.bold: true
                                        }
                                    }
                                }

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Repeater {
                                        model: [
                                            { "label": "Curvas guiadas", "key": "total" },
                                            { "label": "Curva actual", "key": "current" }
                                        ]

                                        delegate: Rectangle {
                                            id: chip

                                            required property var modelData

                                            radius: 8
                                            color: window.cardColor
                                            implicitWidth: chipRow.implicitWidth + 24
                                            implicitHeight: 36

                                            RowLayout {
                                                id: chipRow

                                                anchors.centerIn: parent
                                                spacing: 8

                                                Label {
                                                    text: chip.modelData.label
                                                    color: window.mutedText
                                                    font.pixelSize: window.fsCaption
                                                }

                                                Label {
                                                    text: chip.modelData.key === "total"
                                                          ? String(instructor.turnNames.length)
                                                          : "T" + (instructor.currentTurnIndex + 1)
                                                    color: window.mainText
                                                    font.pixelSize: window.fsBody
                                                    font.bold: true
                                                }
                                            }
                                        }
                                    }

                                    Item {
                                        Layout.fillWidth: true
                                    }
                                }
                            }
                        }

                        // Mapa del circuito: modo satélite y modo navegación
                        Rectangle {
                            id: mapCard

                            Layout.fillWidth: true
                            Layout.preferredHeight: 820
                            radius: 14
                            color: window.panelColor
                            border.color: window.borderColor

                            CircuitMap {
                                id: circuitMap

                                anchors.fill: parent
                                anchors.margins: 16

                                accent: window.accentColor
                                accentSoft: window.accentSoft
                                good: window.good
                                warn: window.warn
                                danger: window.danger
                                textColor: window.mainText
                                mutedColor: window.mutedText
                                panelColor: window.canvasColor
                                cardColor: window.cardColor
                                lineColor: window.borderColor

                                selected: instructor.currentTurnIndex
                                briefing: instructor.briefing
                                tileUrl: window.satelliteTileUrl
                                attribution: window.satelliteAttribution

                                onCornerPicked: function(index) {
                                    instructor.currentTurnIndex = index
                                }

                                // En navegación, la curva que se aproxima pasa a ser la actual.
                                onCornerAhead: function(index) {
                                    instructor.currentTurnIndex = index
                                }
                            }
                        }

                        Label {
                            Layout.topMargin: 4
                            text: "Perfil del instructor"
                            color: window.mutedText
                            font.pixelSize: window.fsBody
                            font.bold: true
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 12

                            Repeater {
                                model: [
                                    { "key": "simple", "title": "Simple",
                                      "subtitle": "Instrucciones sencillas" },
                                    { "key": "rally", "title": "Rally",
                                      "subtitle": "Instrucciones detalladas" }
                                ]

                                delegate: Button {
                                    id: modeButton

                                    required property var modelData
                                    readonly property bool isCurrent: instructor.mode === modelData.key

                                    Layout.fillWidth: true
                                    Layout.preferredWidth: 1
                                    Layout.preferredHeight: 80
                                    onClicked: instructor.mode = modelData.key

                                    background: Rectangle {
                                        radius: 12
                                        color: modeButton.isCurrent ? window.accentSoft
                                               : (modeButton.hovered ? window.cardColor
                                                                     : window.panelColor)
                                        border.width: modeButton.visualFocus ? 2 : 1
                                        border.color: (modeButton.isCurrent || modeButton.visualFocus)
                                                      ? window.accentColor : window.borderColor
                                    }

                                    contentItem: Item {
                                        ColumnLayout {
                                            anchors.centerIn: parent
                                            spacing: 4

                                            Label {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: modeButton.modelData.title
                                                color: modeButton.isCurrent ? window.accentColor
                                                                            : window.mainText
                                                font.bold: true
                                                font.pixelSize: window.fsLead
                                            }

                                            Label {
                                                Layout.alignment: Qt.AlignHCenter
                                                text: modeButton.modelData.subtitle
                                                color: window.mutedText
                                                font.pixelSize: window.fsCaption
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // ------------------------------------------------------
                    // Columna derecha: qué hacer ahora y qué está pasando
                    // ------------------------------------------------------
                    ColumnLayout {
                        id: rightColumn

                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        spacing: 14

                        Label {
                            text: "Indicaciones del piloto"
                            color: window.mutedText
                            font.pixelSize: window.fsBody
                            font.bold: true
                        }

                        // Tarjeta principal: la instrucción de la curva actual
                        Rectangle {
                            id: instructionCard

                            Layout.fillWidth: true
                            implicitHeight: Math.max(320, instructionContent.implicitHeight + 44)
                            radius: 14
                            color: window.panelColor
                            border.color: window.withAlpha(window.accentColor, 0.45)

                            ColumnLayout {
                                id: instructionContent

                                x: 22
                                y: 22
                                width: parent.width - 44
                                spacing: 16
                                visible: window.guideVisible

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Label {
                                        Layout.fillWidth: true
                                        text: "Instrucciones del instructor"
                                        color: window.mainText
                                        font.pixelSize: window.fsLead
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        radius: height / 2
                                        color: window.accentSoft
                                        implicitWidth: modeLabel.implicitWidth + 20
                                        implicitHeight: 26

                                        Label {
                                            id: modeLabel

                                            anchors.centerIn: parent
                                            text: instructor.mode === "simple" ? "Modo simple" : "Modo rally"
                                            color: window.accentColor
                                            font.pixelSize: window.fsCaption
                                            font.bold: true
                                        }
                                    }

                                    Button {
                                        id: hideButton

                                        text: "Ocultar"
                                        leftPadding: 12
                                        rightPadding: 12
                                        topPadding: 4
                                        bottomPadding: 4
                                        onClicked: window.guideVisible = false

                                        background: Rectangle {
                                            radius: height / 2
                                            color: hideButton.down ? window.cardColor : "transparent"
                                            border.color: hideButton.visualFocus ? window.accentColor
                                                          : window.borderColor
                                        }

                                        contentItem: Label {
                                            text: hideButton.text
                                            color: hideButton.hovered ? window.mainText : window.mutedText
                                            font.pixelSize: window.fsCaption
                                            font.bold: true
                                            horizontalAlignment: Text.AlignHCenter
                                            verticalAlignment: Text.AlignVCenter
                                        }
                                    }
                                }

                                // Curva actual
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 14

                                    Rectangle {
                                        Layout.preferredWidth: 56
                                        Layout.preferredHeight: 56
                                        radius: 12
                                        color: window.accentSoft
                                        border.color: window.withAlpha(window.accentColor, 0.45)

                                        Label {
                                            anchors.centerIn: parent
                                            text: window.pad2(instructor.currentTurnIndex + 1)
                                            color: window.accentColor
                                            font.pixelSize: 24
                                            font.bold: true
                                        }
                                    }

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        spacing: 2

                                        Label {
                                            text: "Curva actual"
                                            color: window.mutedText
                                            font.pixelSize: window.fsCaption
                                        }

                                        Label {
                                            Layout.fillWidth: true
                                            text: instructor.currentTurnName
                                            color: window.mainText
                                            font.pixelSize: window.fsTitle
                                            font.bold: true
                                            wrapMode: Text.WordWrap
                                        }
                                    }
                                }

                                // Avance por curvas
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 6

                                    Repeater {
                                        model: instructor.turnNames.length

                                        delegate: Rectangle {
                                            required property int index

                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 4
                                            radius: 2
                                            color: index === instructor.currentTurnIndex
                                                   ? window.accentColor
                                                   : (index < instructor.currentTurnIndex
                                                      ? window.withAlpha(window.accentColor, 0.35)
                                                      : window.borderColor)
                                        }
                                    }
                                }

                                // Texto de la instrucción
                                Label {
                                    Layout.fillWidth: true
                                    text: instructor.instruction
                                    color: window.mainText
                                    font.pixelSize: window.fsLead
                                    wrapMode: Text.WordWrap
                                    lineHeight: 1.15
                                }

                                // Datos de la instrucción: velocidad, marcha y metros.
                                // Se llenan cuando el instructor exponga las propiedades.
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Repeater {
                                        model: [
                                            { "label": "Velocidad", "key": "targetSpeed", "unit": "km/h" },
                                            { "label": "Marcha", "key": "targetGear", "unit": "" },
                                            { "label": "Frenada", "key": "brakeDistance", "unit": "m" }
                                        ]

                                        delegate: Rectangle {
                                            id: cueChip

                                            required property var modelData
                                            readonly property string raw: window.cue(modelData.key)
                                            readonly property bool noBrake: modelData.key === "brakeDistance"
                                                                            && raw === "0"
                                            readonly property string shown: noBrake ? "Sin frenar" : raw

                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            implicitHeight: 76
                                            radius: 10
                                            color: window.cardColor

                                            ColumnLayout {
                                                anchors.fill: parent
                                                anchors.margins: 12
                                                spacing: 2

                                                Label {
                                                    text: cueChip.modelData.label
                                                    color: window.mutedText
                                                    font.pixelSize: window.fsCaption
                                                }

                                                RowLayout {
                                                    spacing: 5

                                                    Label {
                                                        text: cueChip.shown
                                                        color: cueChip.shown === "—" ? window.mutedText
                                                                                    : window.accentColor
                                                        font.pixelSize: cueChip.noBrake ? 18 : 28
                                                        font.bold: true
                                                        // Se encoge si el texto no cabe en la caja.
                                                        fontSizeMode: Text.HorizontalFit
                                                        minimumPixelSize: 11
                                                        Layout.maximumWidth: cueChip.width - 24
                                                    }

                                                    Label {
                                                        Layout.alignment: Qt.AlignBottom
                                                        bottomPadding: 4
                                                        text: cueChip.noBrake ? "" : cueChip.modelData.unit
                                                        color: window.mutedText
                                                        font.pixelSize: window.fsCaption
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                // Solo aparece si el instructor entrega un principio clave.
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 6
                                    visible: window.optional("keyPrinciple") !== ""

                                    Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 1
                                        color: window.borderColor
                                    }

                                    Label {
                                        text: "Principio clave"
                                        color: window.mutedText
                                        font.pixelSize: window.fsCaption
                                        font.bold: true
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: window.optional("keyPrinciple")
                                        color: window.mainText
                                        font.pixelSize: window.fsBody
                                        wrapMode: Text.WordWrap
                                    }
                                }
                            }

                            // Estado oculto
                            ColumnLayout {
                                anchors.centerIn: parent
                                spacing: 10
                                visible: !window.guideVisible

                                Label {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Indicaciones pausadas"
                                    color: window.mainText
                                    font.bold: true
                                    font.pixelSize: window.fsTitle
                                }

                                Label {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: "Las notas están ocultas."
                                    color: window.mutedText
                                    font.pixelSize: window.fsBody
                                }

                                Button {
                                    id: showButton

                                    Layout.alignment: Qt.AlignHCenter
                                    Layout.topMargin: 4
                                    text: "Mostrar notas"
                                    leftPadding: 18
                                    rightPadding: 18
                                    topPadding: 9
                                    bottomPadding: 9
                                    onClicked: window.guideVisible = true

                                    background: Rectangle {
                                        radius: height / 2
                                        color: showButton.down ? window.accentDown
                                               : (showButton.hovered ? window.accentHover
                                                                     : window.accentSoft)
                                        border.color: window.accentColor
                                    }

                                    contentItem: Label {
                                        text: showButton.text
                                        color: window.accentColor
                                        font.bold: true
                                        font.pixelSize: window.fsBody
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }
                                }
                            }
                        }

                        Label {
                            Layout.topMargin: 4
                            text: "Telemetría"
                            color: window.mutedText
                            font.pixelSize: window.fsBody
                            font.bold: true
                        }

                        // Panel de telemetría UDP
                        Rectangle {
                            id: telemetryCard

                            Layout.fillWidth: true
                            implicitHeight: telemetryContent.implicitHeight + 44
                            radius: 14
                            color: window.panelColor
                            border.color: window.borderColor

                            ColumnLayout {
                                id: telemetryContent

                                x: 22
                                y: 22
                                width: parent.width - 44
                                spacing: 18

                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 10

                                    Label {
                                        Layout.fillWidth: true
                                        text: "Datos del auto"
                                        color: window.mainText
                                        font.pixelSize: window.fsLead
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        radius: height / 2
                                        color: window.withAlpha(window.linkColor, 0.12)
                                        border.color: window.withAlpha(window.linkColor, 0.40)
                                        implicitWidth: teleStatusRow.implicitWidth + 20
                                        implicitHeight: 26

                                        RowLayout {
                                            id: teleStatusRow

                                            anchors.centerIn: parent
                                            spacing: 6

                                            Rectangle {
                                                Layout.preferredWidth: 7
                                                Layout.preferredHeight: 7
                                                radius: 3.5
                                                color: window.linkColor
                                            }

                                            Label {
                                                text: window.linkShort
                                                color: window.linkColor
                                                font.pixelSize: window.fsCaption
                                                font.bold: true
                                            }
                                        }
                                    }
                                }

                                // Instrumentos (velocidad, marcha, RPM) y pedales en barras verticales
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 18

                                    ColumnLayout {
                                        Layout.fillWidth: true
                                        Layout.alignment: Qt.AlignTop
                                        spacing: 14

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 14

                                            ColumnLayout {
                                                spacing: 0

                                                Label {
                                                    text: "Velocidad"
                                                    color: window.mutedText
                                                    font.pixelSize: window.fsCaption
                                                }

                                                RowLayout {
                                                    spacing: 6

                                                    Label {
                                                        Layout.preferredWidth: 96
                                                        text: window.intText(window.dataLive ? window.tele.speedKmh : undefined)
                                                        color: window.mainText
                                                        font.pixelSize: 46
                                                        font.bold: true
                                                    }

                                                    Label {
                                                        Layout.alignment: Qt.AlignBottom
                                                        bottomPadding: 9
                                                        text: "km/h"
                                                        color: window.mutedText
                                                        font.pixelSize: window.fsBody
                                                    }
                                                }
                                            }

                                            Item {
                                                Layout.fillWidth: true
                                            }

                                            ColumnLayout {
                                                spacing: 4

                                                Label {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    text: "Marcha"
                                                    color: window.mutedText
                                                    font.pixelSize: window.fsCaption
                                                }

                                                Rectangle {
                                                    Layout.preferredWidth: 64
                                                    Layout.preferredHeight: 58
                                                    radius: 12
                                                    color: window.accentSoft
                                                    border.color: window.withAlpha(window.accentColor, 0.45)

                                                    Label {
                                                        anchors.centerIn: parent
                                                        text: window.gearText(window.dataLive ? window.tele.gear : undefined)
                                                        color: window.accentColor
                                                        font.pixelSize: 36
                                                        font.bold: true
                                                    }
                                                }
                                            }
                                        }

                                        // RPM como luces de cambio
                                        ColumnLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            RowLayout {
                                                Layout.fillWidth: true

                                                Label {
                                                    text: "RPM"
                                                    color: window.mutedText
                                                    font.pixelSize: window.fsCaption
                                                }

                                                Item {
                                                    Layout.fillWidth: true
                                                }

                                                Label {
                                                    text: window.intText(window.dataLive ? window.tele.rpm : undefined)
                                                    color: window.mainText
                                                    font.pixelSize: window.fsBody
                                                    font.bold: true
                                                }
                                            }

                                            RowLayout {
                                                Layout.fillWidth: true
                                                spacing: 3

                                                Repeater {
                                                    model: 16

                                                    delegate: Rectangle {
                                                        required property int index
                                                        readonly property bool lit: window.rpmRatio * 16 > index

                                                        Layout.fillWidth: true
                                                        Layout.preferredHeight: 10
                                                        radius: 2
                                                        color: !lit ? window.borderColor
                                                               : (index < 10 ? window.accentColor
                                                                  : (index < 13 ? window.warn : window.danger))
                                                    }
                                                }
                                            }
                                        }
                                    }

                                    // Pedales: barras verticales que se llenan desde abajo
                                    RowLayout {
                                        Layout.alignment: Qt.AlignTop
                                        spacing: 10

                                        Repeater {
                                            model: [
                                                { "label": "Acel.", "key": "throttle", "tint": window.good },
                                                { "label": "Freno", "key": "brake", "tint": window.danger }
                                            ]

                                            delegate: ColumnLayout {
                                                id: pedal

                                                required property var modelData
                                                readonly property real level: window.dataLive ? window.clamp01(window.tele[modelData.key]) : 0

                                                spacing: 6

                                                Label {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    text: Math.round(pedal.level * 100) + "%"
                                                    color: window.mainText
                                                    font.pixelSize: window.fsCaption
                                                    font.bold: true
                                                }

                                                Rectangle {
                                                    id: pedalTrack

                                                    Layout.alignment: Qt.AlignHCenter
                                                    Layout.preferredWidth: 30
                                                    Layout.preferredHeight: 132
                                                    radius: 6
                                                    color: window.borderColor
                                                    clip: true

                                                    Rectangle {
                                                        anchors.bottom: parent.bottom
                                                        width: parent.width
                                                        height: parent.height * pedal.level
                                                        radius: 6
                                                        color: pedal.modelData.tint

                                                        Behavior on height {
                                                            NumberAnimation { duration: 60 }
                                                        }
                                                    }

                                                    // Marcas al 25, 50 y 75 %
                                                    Repeater {
                                                        model: 3

                                                        delegate: Rectangle {
                                                            required property int index

                                                            width: pedalTrack.width
                                                            height: 1
                                                            y: pedalTrack.height * (index + 1) / 4
                                                            color: Qt.rgba(0, 0, 0, 0.35)
                                                        }
                                                    }
                                                }

                                                Label {
                                                    Layout.alignment: Qt.AlignHCenter
                                                    text: pedal.modelData.label
                                                    color: window.mutedText
                                                    font.pixelSize: window.fsCaption
                                                }
                                            }
                                        }
                                    }
                                }

                                Rectangle {
                                    Layout.fillWidth: true
                                    Layout.preferredHeight: 1
                                    color: window.borderColor
                                }

                                // Vueltas
                                RowLayout {
                                    Layout.fillWidth: true
                                    spacing: 12

                                    Repeater {
                                        model: [
                                            { "label": "Vuelta", "key": "lap" },
                                            { "label": "Última", "key": "lastLapMs" },
                                            { "label": "Mejor", "key": "bestLapMs" }
                                        ]

                                        delegate: ColumnLayout {
                                            id: lapBlock

                                            required property var modelData

                                            Layout.fillWidth: true
                                            Layout.preferredWidth: 1
                                            spacing: 2

                                            Label {
                                                text: lapBlock.modelData.label
                                                color: window.mutedText
                                                font.pixelSize: window.fsCaption
                                            }

                                            Label {
                                                text: !window.dataLive ? "—"
                                                      : (lapBlock.modelData.key === "lap"
                                                         ? window.intText(window.tele.lap)
                                                         : window.lapText(window.tele[lapBlock.modelData.key]))
                                                color: window.mainText
                                                font.pixelSize: window.fsLead
                                                font.bold: true
                                            }
                                        }
                                    }
                                }

                                // Conexión con la consola
                                ColumnLayout {
                                    Layout.fillWidth: true
                                    spacing: 8

                                    Label {
                                        Layout.fillWidth: true
                                        text: !window.hasBackend
                                              ? "Datos simulados. Registra el objeto telemetry en main.cpp para recibir la telemetría real."
                                              : window.tele.statusText + (window.linkState === "live"
                                                                          ? ", " + window.tele.packetsPerSecond + " paquetes/s" : "")
                                        color: window.mutedText
                                        font.pixelSize: window.fsCaption
                                        wrapMode: Text.WordWrap
                                    }

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 8
                                        visible: window.hasBackend

                                        TextField {
                                            id: ipField

                                            Layout.fillWidth: true
                                            implicitHeight: 38
                                            leftPadding: 12
                                            rightPadding: 12
                                            placeholderText: "IP de la consola, por ejemplo 192.168.1.84"
                                            placeholderTextColor: window.mutedText
                                            text: window.hasBackend ? window.tele.consoleAddress : ""
                                            color: window.mainText
                                            font.pixelSize: window.fsBody
                                            selectByMouse: true
                                            inputMethodHints: Qt.ImhPreferNumbers | Qt.ImhNoPredictiveText
                                            onAccepted: window.connectConsole(text)

                                            background: Rectangle {
                                                radius: 10
                                                color: window.cardColor
                                                border.color: ipField.activeFocus ? window.accentColor : window.borderColor
                                            }
                                        }

                                        Button {
                                            id: connectButton

                                            text: window.hasBackend && window.tele.running ? "Reconectar" : "Conectar"
                                            leftPadding: 16
                                            rightPadding: 16
                                            implicitHeight: 38
                                            onClicked: window.connectConsole(ipField.text)

                                            background: Rectangle {
                                                radius: 10
                                                color: connectButton.down ? window.accentDown
                                                       : (connectButton.hovered ? window.accentHover : window.accentSoft)
                                                border.color: connectButton.visualFocus ? window.accentColor
                                                              : window.withAlpha(window.accentColor, 0.45)
                                            }

                                            contentItem: Label {
                                                text: connectButton.text
                                                color: window.accentColor
                                                font.pixelSize: window.fsBody
                                                font.bold: true
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }

                                        Button {
                                            id: stopButton

                                            visible: window.hasBackend && window.tele.running === true
                                            text: "Detener"
                                            leftPadding: 14
                                            rightPadding: 14
                                            implicitHeight: 38
                                            onClicked: window.stopConsole()

                                            background: Rectangle {
                                                radius: 10
                                                color: stopButton.down ? window.cardColor : "transparent"
                                                border.color: stopButton.visualFocus ? window.accentColor : window.borderColor
                                            }

                                            contentItem: Label {
                                                text: stopButton.text
                                                color: window.mutedText
                                                font.pixelSize: window.fsBody
                                                font.bold: true
                                                horizontalAlignment: Text.AlignHCenter
                                                verticalAlignment: Text.AlignVCenter
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // ==========================================================
                // Pie
                // ==========================================================
                RowLayout {
                    Layout.fillWidth: true

                    Label {
                        text: "GT7 Copilot, prototipo 0.1"
                        color: window.mutedText
                        font.pixelSize: window.fsCaption
                    }

                    Item {
                        Layout.fillWidth: true
                    }

                    Label {
                        text: window.linkState === "live" ? "Telemetría conectada"
                              : (window.linkState === "demo" ? "Sin telemetría, datos simulados"
                                                             : "Esperando telemetría")
                        color: window.mutedText
                        font.pixelSize: window.fsCaption
                    }
                }
            }
        }
    }
}
