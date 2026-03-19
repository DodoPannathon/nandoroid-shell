import "../core"
import "../services"
import "."
import "../core/functions" as Functions
import QtQuick
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import Quickshell

/**
 * M3-styled media player card — Compact horizontal layout matching ii style.
 * Art (left) | Info & Progress (center) | Play/Pause (right).
 * Uses persistent data from MprisController.
 */
Rectangle {
    id: root
    implicitHeight: 118
    radius: Appearance.rounding.card
    color: Functions.ColorUtils.applyAlpha(MprisController.dynLayer0, 1)
    visible: MprisController.activePlayer !== null
    clip: true

    property bool showVisualizer: true
    readonly property var player: MprisController.activePlayer

    // --- Cava Lifecycle Management ---
    property bool _cavaActive: false
    readonly property bool shouldVisualize: root.visible && MprisController.isPlaying && root.showVisualizer
    onShouldVisualizeChanged: {
        if (shouldVisualize && !_cavaActive) {
            CavaService.refCount++;
            _cavaActive = true;
        } else if (!shouldVisualize && _cavaActive) {
            CavaService.refCount--;
            _cavaActive = false;
        }
    }
    Component.onDestruction: {
        if (_cavaActive) CavaService.refCount--;
    }

    // Background Art (Blurred)
    Item {
        id: backgroundWrapper
        anchors.fill: parent
        layer.enabled: true
        layer.effect: OpacityMask {
            maskSource: Rectangle {
                width: backgroundWrapper.width
                height: backgroundWrapper.height
                radius: root.radius
            }
        }

        Image {
            id: blurredArt
            anchors.fill: parent
            source: MprisController.displayedArtFilePath
            visible: source.toString() !== ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            
            layer.enabled: true
            layer.effect: GaussianBlur {
                radius: 64 
                samples: 48
                cached: true
            }

            Rectangle {
                anchors.fill: parent
                color: Functions.ColorUtils.transparentize(MprisController.dynLayer0, 0.3)
            }
        }

        // --- Wave Visualizer Overlay ---
        WaveVisualizer {
            anchors.fill: parent
            anchors.topMargin: parent.height * 0.4 // Position it towards the bottom half
            color: MprisController.dynPrimary
            opacityMultiplier: 0.2
            visible: root.shouldVisualize
        }
    }

    // Layout Container
    Item {
        anchors.fill: parent
        anchors.margins: 12

        // Left: Album art
        MaterialShape {
            id: artShape
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 86
            height: 86
            image: MprisController.displayedArtFilePath
            shape: MaterialShape.Shape.Square
            color: MprisController.dynLayer0
            
            MaterialSymbol {
                anchors.centerIn: parent
                text: "music_note"
                iconSize: 32
                fill: 1
                color: MprisController.dynSubtext
                visible: !parent.image || parent.image.toString() === ""
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: (mouse) => {
                    if (mouse.button === Qt.RightButton) {
                        MprisController.cyclePlayer()
                    } else {
                        MprisController.raisePlayer()
                    }
                }
            }
        }

        // Main Content Area (Right of Art)
        ColumnLayout {
            anchors.left: artShape.right
            anchors.right: parent.right
            anchors.top: artShape.top
            anchors.bottom: artShape.bottom
            anchors.leftMargin: 16
            spacing: 0

            // Top Row: Track Info + Play/Pause
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 52
                spacing: 8

                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignTop
                    spacing: 0

                    MouseArea {
                        Layout.fillWidth: true
                        implicitHeight: trackTitleText.implicitHeight + trackArtistText.implicitHeight
                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                        onClicked: (mouse) => {
                            if (mouse.button === Qt.RightButton) {
                                MprisController.cyclePlayer()
                            } else {
                                MprisController.raisePlayer()
                            }
                        }

                        ColumnLayout {
                            anchors.fill: parent
                            spacing: 0
                            StyledText {
                                id: trackTitleText
                                Layout.fillWidth: true
                                text: Functions.StringUtils.cleanMusicTitle(MprisController.trackTitle) || "No media"
                                font.pixelSize: Appearance.font.pixelSize.normal
                                font.weight: Font.Bold
                                color: MprisController.dynOnLayer0
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignTop
                            }
                            StyledText {
                                id: trackArtistText
                                Layout.fillWidth: true
                                text: MprisController.trackArtist || "Unknown Artist"
                                font.pixelSize: Appearance.font.pixelSize.smaller
                                color: MprisController.dynSubtext
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignTop
                            }
                        }
                    }
                }

                // Play/Pause Button
                RippleButton {
                    id: playPauseButton
                    padding: 0
                    implicitWidth: 52
                    implicitHeight: 52
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    Layout.alignment: Qt.AlignTop
                    buttonRadius: MprisController.isPlaying ? Appearance.rounding.large : Appearance.rounding.normal
                    
                    colBackground: MprisController.isPlaying ? MprisController.dynPrimary : MprisController.dynSecondaryContainer
                    colBackgroundHover: MprisController.isPlaying ? MprisController.dynPrimaryHover : MprisController.dynSecondaryContainerHover
                    colRipple: MprisController.isPlaying ? MprisController.dynPrimaryActive : MprisController.dynSecondaryContainerActive
                    
                    onClicked: MprisController.togglePlaying()
                    
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: MprisController.isPlaying ? "pause" : "play_arrow"
                        iconSize: 28
                        fill: 1
                        color: MprisController.isPlaying ? MprisController.dynOnPrimary : MprisController.dynOnSecondaryContainer
                    }
                }
            }

            // Fill space between top and bottom
            Item { Layout.fillHeight: true }

            // Bottom Row: Full Width Playback Controls
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 24
                spacing: 0 // Experimental: Remove base spacing

                // Skip Previous
                RippleButton {
                    id: prevBtn
                    padding: 0
                    implicitWidth: 24; implicitHeight: 24; buttonRadius: 12
                    colBackground: "transparent"
                    colBackgroundHover: "transparent"
                    colText: "transparent"
                    rippleEnabled: false
                    enabled: MprisController.canGoPrevious
                    onClicked: MprisController.previous()
                    
                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "skip_previous"; iconSize: 18; fill: 1
                        color: prevBtn.hovered ? MprisController.dynPrimary : MprisController.dynOnSecondaryContainer
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }

                // Current Time
                StyledText {
                    id: currentTimeText
                    text: Functions.StringUtils.friendlyTimeForSeconds(MprisController.position)
                    font.pixelSize: 10
                    font.family: Appearance.font.family.monospace
                    font.weight: Font.Medium
                    color: MprisController.dynSubtext
                    Layout.alignment: Qt.AlignVCenter
                    verticalAlignment: Text.AlignVCenter
                    Layout.leftMargin: 0 // Menempel ke arrow
                    Layout.rightMargin: 10 // Menjauh dari slider
                }

                // Slider
                StyledSlider {
                    id: progressSlider
                    Layout.fillWidth: true
                    Layout.preferredHeight: 14
                    handleMargins: 0 
                    configuration: StyledSlider.Configuration.Wavy
                    stopIndicatorValues: []
                    animateValue: false
                    value: (MprisController.length > 0 ? (MprisController.position / MprisController.length) : 0) || 0
                    wavy: MprisController.isPlaying
                    highlightColor: MprisController.dynPrimary
                    trackColor: MprisController.dynSecondaryContainer
                    handleColor: MprisController.dynPrimary
                    
                    onMoved: {
                        if (player && player.canSeek) {
                            player.position = value * player.length;
                        }
                    }

                    Connections {
                        target: MprisController
                        function onPositionChanged() {
                            if (!progressSlider.pressed) {
                                progressSlider.value = (MprisController.length > 0 ? (MprisController.position / MprisController.length) : 0) || 0;
                            }
                        }
                    }
                }

                // Total Time
                StyledText {
                    id: totalTimeText
                    text: Functions.StringUtils.friendlyTimeForSeconds(MprisController.length)
                    font.pixelSize: 10
                    font.family: Appearance.font.family.monospace
                    font.weight: Font.Medium
                    color: MprisController.dynSubtext
                    Layout.alignment: Qt.AlignVCenter
                    verticalAlignment: Text.AlignVCenter
                    Layout.leftMargin: 10 // Menjauh dari slider
                    Layout.rightMargin: 0 // Menempel ke arrow
                }

                // Skip Next
                RippleButton {
                    id: nextBtn
                    padding: 0
                    implicitWidth: 24; implicitHeight: 24; buttonRadius: 12
                    colBackground: "transparent"
                    colBackgroundHover: "transparent"
                    colText: "transparent"
                    rippleEnabled: false
                    enabled: MprisController.canGoNext
                    onClicked: MprisController.next()

                    MaterialSymbol {
                        anchors.centerIn: parent
                        text: "skip_next"; iconSize: 18; fill: 1
                        color: nextBtn.hovered ? MprisController.dynPrimary : MprisController.dynOnSecondaryContainer
                        Behavior on color { ColorAnimation { duration: 150 } }
                    }
                }
            }
        }
    }
}
