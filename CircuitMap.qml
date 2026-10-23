// Mapa del circuito con dos modos.
//   satellite : norte arriba, sobre imágenes satelitales (si configuras tileUrl).
//               Elige una curva para ver su nombre, dificultad, características
//               y analizar frenada, entrada, vértices y salida.
//   nav       : vista tipo navegación. La flecha es el auto, el mapa gira con el
//               rumbo, y se resalta la próxima curva con marcadores de frenada
//               y alertas. Hoy lo mueve una simulación; luego lo moverá la telemetría.
//
// La posición en el modo navegación sale de "lapS" (metros desde la meta) y la
// velocidad de "speedKmh". Cuando exista la telemetría basta con enlazar esas
// dos propiedades y poner simulate en false.

import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import "SpaData.js" as Spa
import "MapEngine.js" as Engine

Item {
    id: root

    // ------------------------------------------------------------------
    // API
    // ------------------------------------------------------------------
    property string mode: "satellite"        // "satellite" o "nav"
    property int selected: 0                 // curva elegida (el padre la actualiza)
    property real lapS: 0                    // posición en la vuelta, en metros
    property real speedKmh: 140
    property bool simulate: true             // avanza solo mientras no haya telemetría
    property string briefing: ""             // explicación del instructor para la curva en foco

    // Imágenes satelitales: plantilla de URL con {z}, {x} e {y}. Vacía = sin imágenes.
    // Revisa los términos de uso y la atribución del proveedor que elijas.
    property string tileUrl: ""
    property int tileZoom: 16
    property string attribution: ""

    signal cornerPicked(int index)           // el usuario eligió una curva en el mapa
    signal cornerAhead(int index)            // en navegación cambió la curva en foco

    // Tema
    property color accent: "#67E8F9"
    property color accentSoft: "#17313A"
    property color good: "#4ADE80"
    property color warn: "#FBBF24"
    property color danger: "#F87171"
    property color textColor: "#F1F5F9"
    property color mutedColor: "#94A3B8"
    property color panelColor: "#121922"
    property color cardColor: "#19232F"
    property color lineColor: "#283544"
    property color terrain: "#0E1A16"

    implicitHeight: 720

    // ------------------------------------------------------------------
    // Estado interno
    // ------------------------------------------------------------------
    readonly property var track: Engine.buildTrack(Spa.SPA)
    readonly property var corners: track.corners
    property real zoom: 1.0
    property var camX: null
    property var camY: null
    property real navScale: 1.6
    property var layers: ({ "line": true, "brake": true, "apex": true, "boxes": true,
                            "names": true, "grade": true })

    readonly property var focusInfo: Engine.focus(track, lapS)
    readonly property int focusIdx: focusInfo.idx
    readonly property var alertInfo: Engine.alerts(track, lapS, speedKmh, focusInfo)
    readonly property var selCorner: corners[Math.max(0, Math.min(selected, corners.length - 1))]
    readonly property var navCorner: focusInfo.corner
    readonly property bool tilesActive: mode === "satellite" && tileUrl !== ""
    readonly property var tileModel: tileUrl !== "" ? Engine.tileList(track, tileZoom, tileUrl) : []

    readonly property var themeObj: ({
        "accent": "" + accent, "good": "" + good, "warn": "" + warn, "danger": "" + danger,
        "text": "" + textColor, "muted": "" + mutedColor, "terrain": "" + terrain,
        "asphalt": "#2b333b"
    })

    function levelColor(level) {
        return level >= 3 ? danger : (level === 2 ? warn : (level === 1 ? accent : mutedColor))
    }
    function repaint() { cv.requestPaint() }
    function toggleLayer(key) {
        var next = {}
        for (var k in layers) next[k] = layers[k]
        next[key] = !next[key]
        layers = next
    }
    function resetView() { zoom = 1.0; camX = null; camY = null }
    function focusSelected() {
        var v = Engine.focusView(track, viewport.width, viewport.height, selCorner)
        zoom = v.zoom
        camX = v.cx
        camY = v.cy
    }
    function brakeText(c) { return c.brake_m > 0 ? c.brake_m + " m" : "Sin frenar" }

    onLapSChanged: repaint()
    onSelectedChanged: repaint()
    onModeChanged: { repaint(); if (mode === "nav") cornerAhead(focusIdx) }
    onZoomChanged: repaint()
    onCamXChanged: repaint()
    onCamYChanged: repaint()
    onNavScaleChanged: repaint()
    onLayersChanged: repaint()
    onFocusIdxChanged: { if (mode === "nav") cornerAhead(focusIdx) }

    Timer {
        interval: 33
        repeat: true
        running: root.simulate && root.mode === "nav" && root.visible
        onTriggered: root.lapS = (root.lapS + root.speedKmh / 3.6 * 0.033) % root.track.L
    }

    // ------------------------------------------------------------------
    // Botón reutilizable (no depende de ids externos)
    // ------------------------------------------------------------------
    component PillButton: Button {
        id: pb

        property bool active: false
        property color accent: "#67E8F9"
        property color soft: "#17313A"
        property color idleText: "#94A3B8"
        property color line: "#283544"

        implicitHeight: 30
        leftPadding: 14
        rightPadding: 14
        topPadding: 4
        bottomPadding: 4

        background: Rectangle {
            radius: height / 2
            color: pb.active ? pb.soft : (pb.hovered ? Qt.rgba(1, 1, 1, 0.06) : "transparent")
            border.color: (pb.active || pb.visualFocus) ? pb.accent : pb.line
        }

        contentItem: Label {
            text: pb.text
            color: pb.active ? pb.accent : pb.idleText
            font.pixelSize: 12
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        // ==============================================================
        // Barra superior: modo y zoom
        // ==============================================================
        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: [
                    { "key": "satellite", "label": "Satélite" },
                    { "key": "nav", "label": "Navegación" }
                ]

                delegate: PillButton {
                    required property var modelData

                    text: modelData.label
                    active: root.mode === modelData.key
                    accent: root.accent
                    soft: root.accentSoft
                    idleText: root.mutedColor
                    line: root.lineColor
                    onClicked: root.mode = modelData.key
                }
            }

            Item {
                Layout.fillWidth: true
            }

            Label {
                text: root.mode === "satellite" ? Math.round(root.zoom * 100) + " %"
                                                : root.navScale.toFixed(1) + " px/m"
                color: root.mutedColor
                font.pixelSize: 12
            }

            Repeater {
                model: [
                    { "glyph": "−", "tip": "Alejar", "d": -1 },
                    { "glyph": "+", "tip": "Acercar", "d": 1 },
                    { "glyph": "↺", "tip": "Restablecer vista", "d": 0 }
                ]

                delegate: Button {
                    id: zb

                    required property var modelData

                    text: modelData.glyph
                    implicitWidth: 34
                    implicitHeight: 30
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                    ToolTip.text: modelData.tip
                    Accessible.name: modelData.tip

                    onClicked: {
                        if (modelData.d === 0) {
                            if (root.mode === "satellite") root.resetView()
                            else root.navScale = 1.6
                        } else if (root.mode === "satellite") {
                            root.zoom = Math.max(1, Math.min(12, root.zoom * (modelData.d > 0 ? 1.3 : 1 / 1.3)))
                        } else {
                            root.navScale = Math.max(0.6, Math.min(4, root.navScale * (modelData.d > 0 ? 1.2 : 1 / 1.2)))
                        }
                    }

                    background: Rectangle {
                        radius: 8
                        color: zb.down ? Qt.darker(root.accentSoft, 0.8) : (zb.hovered ? Qt.lighter(root.accentSoft, 1.2) : root.accentSoft)
                        border.color: zb.visualFocus ? root.accent : Qt.rgba(root.accent.r, root.accent.g, root.accent.b, 0.35)
                    }

                    contentItem: Label {
                        text: zb.text
                        color: root.accent
                        font.pixelSize: 16
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }

        // ==============================================================
        // Visor del mapa
        // ==============================================================
        Rectangle {
            id: viewport

            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 300
            radius: 12
            color: root.terrain
            clip: true

            // Teselas satelitales, con la misma cámara que el dibujo vectorial.
            Item {
                id: tileLayer

                anchors.fill: parent
                visible: root.tilesActive
                readonly property var cam: Engine.overviewCam(root.track, width, height,
                                                              { "zoom": root.zoom, "cx": root.camX, "cy": root.camY })

                Item {
                    x: tileLayer.cam.px - tileLayer.cam.cx * tileLayer.cam.sc
                    y: tileLayer.cam.py + tileLayer.cam.cy * tileLayer.cam.sc
                    scale: tileLayer.cam.sc
                    transformOrigin: Item.TopLeft

                    Repeater {
                        model: root.tilesActive ? root.tileModel : []

                        delegate: Image {
                            required property var modelData

                            source: modelData.url
                            x: modelData.x
                            y: modelData.y
                            width: modelData.w
                            height: modelData.h
                            asynchronous: true
                            smooth: true
                        }
                    }
                }
            }

            Canvas {
                id: cv

                anchors.fill: parent
                onWidthChanged: requestPaint()
                onHeightChanged: requestPaint()
                onPaint: {
                    var ctx = getContext("2d")
                    Engine.draw(ctx, width, height, root.track, {
                        "mode": root.mode, "theme": root.themeObj, "layers": root.layers,
                        "lapS": root.lapS, "focus": root.focusInfo, "selected": root.selected,
                        "zoom": root.zoom, "cx": root.camX, "cy": root.camY,
                        "navScale": root.navScale, "hasTiles": root.tilesActive
                    })
                }
                Component.onCompleted: requestPaint()
            }

            MouseArea {
                id: ma

                anchors.fill: parent
                acceptedButtons: Qt.LeftButton
                preventStealing: true
                cursorShape: root.mode === "satellite" ? ((pressed && moved) ? Qt.ClosedHandCursor : Qt.OpenHandCursor)
                                                       : Qt.ArrowCursor

                property real px0: 0
                property real py0: 0
                property real cx0: 0
                property real cy0: 0
                property bool moved: false

                function camNow() {
                    return Engine.overviewCam(root.track, width, height,
                                              { "zoom": root.zoom, "cx": root.camX, "cy": root.camY })
                }

                onPressed: function(mouse) {
                    px0 = mouse.x
                    py0 = mouse.y
                    var c = camNow()
                    cx0 = c.cx
                    cy0 = c.cy
                    moved = false
                }

                onPositionChanged: function(mouse) {
                    if (!pressed || root.mode !== "satellite")
                        return
                    var dx = mouse.x - px0
                    var dy = mouse.y - py0
                    if (Math.abs(dx) > 3 || Math.abs(dy) > 3)
                        moved = true
                    if (moved) {
                        var c = camNow()
                        root.camX = cx0 - dx / c.sc
                        root.camY = cy0 + dy / c.sc
                    }
                }

                onReleased: function(mouse) {
                    if (root.mode !== "satellite" || moved)
                        return
                    var idx = Engine.hitCorner(root.track, width, height,
                                               { "zoom": root.zoom, "cx": root.camX, "cy": root.camY },
                                               mouse.x, mouse.y)
                    if (idx >= 0)
                        root.cornerPicked(idx)
                }

                onWheel: function(wheel) {
                    if (wheel.angleDelta.y === 0)
                        return
                    var f = wheel.angleDelta.y > 0 ? 1.15 : 1 / 1.15
                    if (root.mode === "satellite")
                        root.zoom = Math.max(1, Math.min(12, root.zoom * f))
                    else
                        root.navScale = Math.max(0.6, Math.min(4, root.navScale * f))
                }
            }

            // Alerta prioritaria (solo navegación)
            Rectangle {
                visible: root.mode === "nav"
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 10
                height: alertColumn.implicitHeight + 20
                radius: 10
                color: Qt.rgba(0.03, 0.05, 0.07, 0.88)
                border.color: root.levelColor(root.alertInfo.level)
                border.width: root.alertInfo.level >= 2 ? 2 : 1

                Rectangle {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.bottom: parent.bottom
                    anchors.margins: 1
                    width: 6
                    radius: 3
                    color: root.levelColor(root.alertInfo.level)
                }

                ColumnLayout {
                    id: alertColumn

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: 20
                    anchors.rightMargin: 12
                    spacing: 2

                    Label {
                        Layout.fillWidth: true
                        text: root.alertInfo.title
                        color: root.levelColor(root.alertInfo.level)
                        font.pixelSize: 20
                        font.bold: true
                        elide: Text.ElideRight
                    }

                    Label {
                        Layout.fillWidth: true
                        text: root.alertInfo.sub
                        color: root.textColor
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                }
            }

            // Mensaje cuando faltan imágenes satelitales
            Label {
                visible: root.mode === "satellite" && root.tileUrl === ""
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.margins: 10
                text: "Sin imágenes satelitales: configura tileUrl"
                color: root.mutedColor
                font.pixelSize: 11
            }
        }

        // ==============================================================
        // Capas (satélite) o simulación (navegación)
        // ==============================================================
        Flow {
            Layout.fillWidth: true
            spacing: 6
            visible: root.mode === "satellite"

            Repeater {
                model: [
                    { "key": "line", "label": "Trazada" },
                    { "key": "brake", "label": "Frenada" },
                    { "key": "apex", "label": "Vértices" },
                    { "key": "boxes", "label": "Boxes" },
                    { "key": "names", "label": "Nombres" }
                ]

                delegate: PillButton {
                    required property var modelData

                    text: modelData.label
                    active: root.layers[modelData.key] === true
                    accent: root.accent
                    soft: root.accentSoft
                    idleText: root.mutedColor
                    line: root.lineColor
                    onClicked: root.toggleLayer(modelData.key)
                }
            }

            PillButton {
                text: "Enfocar curva"
                accent: root.accent
                soft: root.accentSoft
                idleText: root.accent
                line: root.accent
                onClicked: root.focusSelected()
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: root.mode === "nav"

            RowLayout {
                Layout.fillWidth: true
                spacing: 8

                PillButton {
                    text: root.simulate ? "Pausar simulación" : "Reanudar simulación"
                    active: root.simulate
                    accent: root.accent
                    soft: root.accentSoft
                    idleText: root.mutedColor
                    line: root.lineColor
                    onClicked: root.simulate = !root.simulate
                }

                PillButton {
                    text: "Pendiente"
                    active: root.layers["grade"] === true
                    accent: root.accent
                    soft: root.accentSoft
                    idleText: root.mutedColor
                    line: root.lineColor
                    onClicked: root.toggleLayer("grade")
                }

                PillButton {
                    text: "Trazada"
                    active: root.layers["line"] === true
                    accent: root.accent
                    soft: root.accentSoft
                    idleText: root.mutedColor
                    line: root.lineColor
                    onClicked: root.toggleLayer("line")
                }

                Item {
                    Layout.fillWidth: true
                }

                Label {
                    text: Math.round(root.speedKmh) + " km/h"
                    color: root.textColor
                    font.pixelSize: 12
                    font.bold: true
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: 10

                Label {
                    text: "Velocidad"
                    color: root.mutedColor
                    font.pixelSize: 12
                }

                Slider {
                    Layout.fillWidth: true
                    from: 40
                    to: 300
                    value: root.speedKmh
                    onMoved: root.speedKmh = value
                }

                Label {
                    text: "Posición"
                    color: root.mutedColor
                    font.pixelSize: 12
                }

                Slider {
                    Layout.fillWidth: true
                    from: 0
                    to: root.track.L
                    value: root.lapS
                    onMoved: root.lapS = value
                }
            }

            Label {
                Layout.fillWidth: true
                text: "Simulación de conducción. Cuando conectemos la telemetría, la posición y la velocidad vendrán del juego."
                color: root.mutedColor
                font.pixelSize: 11
                wrapMode: Text.WordWrap
            }
        }

        // ==============================================================
        // Panel inferior: análisis de la curva (satélite) o instructor (nav)
        // ==============================================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: infoColumn.implicitHeight + 28
            radius: 12
            color: root.panelColor
            border.color: root.lineColor

            ColumnLayout {
                id: infoColumn

                x: 14
                y: 14
                width: parent.width - 28
                spacing: 8

                // ---- Satélite: ficha de la curva elegida ----
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: root.mode === "satellite"

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        Rectangle {
                            Layout.preferredWidth: 30
                            Layout.preferredHeight: 30
                            radius: 15
                            color: "transparent"
                            border.width: 3
                            border.color: root.selCorner.difficulty >= 4 ? root.danger
                                          : (root.selCorner.difficulty === 3 ? root.warn : root.good)

                            Label {
                                anchors.centerIn: parent
                                text: root.selCorner.idx + 1
                                color: root.textColor
                                font.pixelSize: 13
                                font.bold: true
                            }
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 0

                            Label {
                                Layout.fillWidth: true
                                text: root.selCorner.name
                                color: root.textColor
                                font.pixelSize: 18
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Label {
                                Layout.fillWidth: true
                                text: root.selCorner.kind
                                color: root.mutedColor
                                font.pixelSize: 12
                                elide: Text.ElideRight
                            }
                        }

                        ColumnLayout {
                            spacing: 2

                            Label {
                                Layout.alignment: Qt.AlignRight
                                text: "Dificultad"
                                color: root.mutedColor
                                font.pixelSize: 11
                            }

                            Row {
                                Layout.alignment: Qt.AlignRight
                                spacing: 4

                                Repeater {
                                    model: 5

                                    delegate: Rectangle {
                                        required property int index

                                        width: 12
                                        height: 12
                                        radius: 6
                                        color: index < root.selCorner.difficulty
                                               ? (root.selCorner.difficulty >= 4 ? root.danger
                                                  : (root.selCorner.difficulty === 3 ? root.warn : root.good))
                                               : root.lineColor
                                    }
                                }
                            }
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: root.selCorner.desc
                        color: root.textColor
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: [
                                { "label": "Entrada", "key": "approach", "unit": "km/h" },
                                { "label": "Vértice", "key": "apex", "unit": "km/h" },
                                { "label": "Marcha", "key": "gear", "unit": "" },
                                { "label": "Frenada", "key": "brake_m", "unit": "m" }
                            ]

                            delegate: Rectangle {
                                id: statChip

                                required property var modelData
                                readonly property var raw: root.selCorner[modelData.key]
                                readonly property bool none: modelData.key === "brake_m" && raw === 0

                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                implicitHeight: 52
                                radius: 8
                                color: root.cardColor

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 0

                                    Label {
                                        text: statChip.modelData.label
                                        color: root.mutedColor
                                        font.pixelSize: 11
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: statChip.none ? "Sin frenar" : statChip.raw + (statChip.modelData.unit !== "" ? " " + statChip.modelData.unit : "")
                                        color: root.accent
                                        font.pixelSize: statChip.none ? 13 : 16
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: "Elevación: " + root.selCorner.elev + (root.selCorner.blind ? " Curva ciega." : "")
                        color: root.mutedColor
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }

                    Label {
                        Layout.fillWidth: true
                        text: "Consejo: " + root.selCorner.tip
                        color: root.accent
                        font.pixelSize: 12
                        wrapMode: Text.WordWrap
                    }
                }

                // ---- Navegación: el instructor ----
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    visible: root.mode === "nav"

                    RowLayout {
                        Layout.fillWidth: true

                        Label {
                            Layout.fillWidth: true
                            text: "Próxima curva: " + root.navCorner.name
                            color: root.accent
                            font.pixelSize: 15
                            font.bold: true
                            elide: Text.ElideRight
                        }

                        Label {
                            text: root.focusInfo.dIn > 0 ? "a " + Math.round(root.focusInfo.dIn / 5) * 5 + " m" : "en curso"
                            color: root.textColor
                            font.pixelSize: 13
                            font.bold: true
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: root.briefing !== "" ? root.briefing : root.navCorner.desc
                        color: root.textColor
                        font.pixelSize: 13
                        wrapMode: Text.WordWrap
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Repeater {
                            model: [
                                { "label": "Velocidad", "key": "apex", "unit": "km/h" },
                                { "label": "Marcha", "key": "gear", "unit": "" },
                                { "label": "Frenada", "key": "brake_m", "unit": "m" }
                            ]

                            delegate: Rectangle {
                                id: navChip

                                required property var modelData
                                readonly property var raw: root.navCorner[modelData.key]
                                readonly property bool none: modelData.key === "brake_m" && raw === 0

                                Layout.fillWidth: true
                                Layout.preferredWidth: 1
                                implicitHeight: 52
                                radius: 8
                                color: root.cardColor

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 8
                                    spacing: 0

                                    Label {
                                        text: navChip.modelData.label
                                        color: root.mutedColor
                                        font.pixelSize: 11
                                    }

                                    Label {
                                        Layout.fillWidth: true
                                        text: navChip.none ? "Sin frenar" : navChip.raw + (navChip.modelData.unit !== "" ? " " + navChip.modelData.unit : "")
                                        color: root.accent
                                        font.pixelSize: navChip.none ? 13 : 16
                                        font.bold: true
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }

                    Label {
                        Layout.fillWidth: true
                        text: "Marcadores de frenada: 3, 2 y 1 barras a 150, 100 y 50 m del punto de frenada (línea roja)."
                        color: root.mutedColor
                        font.pixelSize: 11
                        wrapMode: Text.WordWrap
                    }
                }

                Label {
                    Layout.fillWidth: true
                    text: Spa.SPA.source + (root.tilesActive && root.attribution !== "" ? " Imágenes: " + root.attribution : "")
                              + " Velocidades, marchas, frenadas, dificultad, pianos, escapatorias, boxes y elevación son aproximados."
                    color: root.mutedColor
                    font.pixelSize: 10
                    wrapMode: Text.WordWrap
                }
            }
        }
    }
}
