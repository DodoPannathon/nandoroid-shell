import "../../../../core"
import "../../../../services"
import "../../../../widgets"
import "."
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Qt5Compat.GraphicalEffects
import Quickshell
import Quickshell.Io

ColumnLayout {
    Layout.fillWidth: true
    spacing: 0
    
    SearchHandler {
        searchString: "Theme Color"
        aliases: ["Colors", "Matugen", "Material You", "Accent Color"]
    }

    // ── Theme Section ──
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 16 * Appearance.effectiveScale

        SegmentedWrapper {
            Layout.fillWidth: true
            implicitHeight: themeToggleRow.implicitHeight + (36 * Appearance.effectiveScale)
            maxRadius: 20 * Appearance.effectiveScale
            color: Appearance.m3colors.m3surfaceContainerHigh

            RowLayout {
                id: themeToggleRow
                anchors.fill: parent
                anchors.margins: 16 * Appearance.effectiveScale
                spacing: 20 * Appearance.effectiveScale

                RowLayout {
                    spacing: 16 * Appearance.effectiveScale
                    Layout.preferredWidth: 70 * Appearance.effectiveScale
                    MaterialSymbol {
                        text: Config.options.appearance.background.darkmode ? "dark_mode" : "light_mode"
                        iconSize: 24 * Appearance.effectiveScale
                        color: Appearance.colors.colPrimary
                    }
                    StyledText {
                        text: "Dark theme"
                        color: Appearance.colors.colOnLayer1
                        Layout.fillWidth: true
                    }
                }

                Item { Layout.fillWidth: true }

                AndroidToggle {
                    checked: Config.ready && (Config.options.appearance && Config.options.appearance.background ? Config.options.appearance.background.darkmode : false)
                    onToggled: Wallpapers.toggleDarkMode()
                }
            }
        }

        // ── Color Settings ──
        ColumnLayout {
            id: colorSettingsCol
            Layout.fillWidth: true
            Layout.topMargin: 12 * Appearance.effectiveScale
            spacing: 24 * Appearance.effectiveScale
            
            property bool showAllMatugen: false
            property bool showAllBasic: false

            // Custom Segmented Style Switcher
            Row {
                id: colorSwitcherRow
                Layout.fillWidth: true
                Layout.preferredHeight: 52 * Appearance.effectiveScale
                spacing: 4 * Appearance.effectiveScale
                property string currentTab: {
                    if (!Config.ready || !Config.options.appearance.background) return "wallpaper";
                    const bg = Config.options.appearance.background;
                    if (bg.matugen || (bg.matugenCustomColor !== "" && bg.matugenThemeFile === "")) return "wallpaper";
                    return "basic";
                }
                
                SegmentedButton {
                    width: (parent.width - (4 * Appearance.effectiveScale)) / 2
                    height: parent.height
                    isHighlighted: parent.currentTab === "wallpaper"
                    buttonText: "Wallpaper color"
                    onClicked: {
                        Config.options.appearance.background.matugen = true
                        Config.options.appearance.background.matugenThemeFile = ""
                        Wallpapers.initializeMatugen()
                    }
                }

                SegmentedButton {
                    width: (parent.width - (4 * Appearance.effectiveScale)) / 2
                    height: parent.height
                    isHighlighted: parent.currentTab === "basic"
                    buttonText: "Basic colors"
                    onClicked: {
                        Config.options.appearance.background.matugen = false
                        if (Config.options.appearance.background.matugenThemeFile === "") {
                            Wallpapers.applyTheme("mocha.json")
                        }
                    }
                }
            }

            // --- Wallpaper Colors Grid ---
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 16 * Appearance.effectiveScale
                visible: colorSwitcherRow.currentTab === "wallpaper"

                GridLayout {
                    Layout.fillWidth: true
                    columns: 5
                    rowSpacing: 16 * Appearance.effectiveScale
                    columnSpacing: 16 * Appearance.effectiveScale

                    // Desktop Schemes (Show 8 when collapsed + 1 Picker + 1 Lockscreen = 10)
                    Repeater {
                        model: colorSettingsCol.showAllMatugen ? root.matugenSchemes : root.matugenSchemes.slice(0, 8)
                        delegate: ColorCard {
                            Layout.fillWidth: true
                            label: (Config.ready && Config.options.lock && Config.options.lock.useSeparateWallpaper) ? "Desktop\n" + modelData.name : modelData.name
                            cardColors: {
                                const key = "desktop_" + modelData.id;
                                if (root.matugenPreviews[key]) return root.matugenPreviews[key];
                                const def = Appearance.m3colors.m3surfaceContainerHigh;
                                return [def, def, def];
                            }
                            isSelected: Config.ready && (Config.options.appearance && Config.options.appearance.background) && Config.options.appearance.background.matugen && Config.options.appearance.background.matugenScheme === modelData.id && Config.options.appearance.background.matugenSource === "desktop"
                            onClicked: {
                                Config.options.appearance.background.matugen = true
                                Config.options.appearance.background.matugenCustomColor = ""
                                Config.options.appearance.background.matugenThemeFile = ""
                                Wallpapers.applyScheme(modelData.id, "desktop")
                            }
                        }
                    }

                    // Desktop Accent Picker (Always visible) - Card 9
                    ColorCard {
                        Layout.fillWidth: true
                        label: (Config.ready && Config.options.lock && Config.options.lock.useSeparateWallpaper) ? "Desktop\nAccent Picker" : "Accent Picker"
                        iconName: "colorize"
                        cardColors: [Appearance.m3colors.m3primary, Appearance.m3colors.m3secondary, Appearance.m3colors.m3tertiary]
                        isSelected: Config.ready && !Config.options.appearance.background.matugen && Config.options.appearance.background.matugenCustomColor !== "" && Config.options.appearance.background.matugenThemeFile === "" && Config.options.appearance.background.matugenSource === "desktop"
                        onClicked: {
                            GlobalStates.accentPickerTarget = "desktop"
                            GlobalStates.accentPickerOpen = true
                        }
                    }

                    // Lockscreen Schemes (Card 10 if collapsed)
                    Repeater {
                        model: {
                            if (!(Config.ready && Config.options.lock && Config.options.lock.useSeparateWallpaper)) return 0;
                            if (colorSettingsCol.showAllMatugen) return root.matugenSchemes;
                            return root.matugenSchemes.slice(0, 1); // Show exactly 1 to complete the 10 cards grid
                        }
                        delegate: ColorCard {
                            Layout.fillWidth: true
                            label: "Lockscreen\n" + modelData.name
                            cardColors: {
                                const key = "lockscreen_" + modelData.id;
                                if (root.matugenPreviews[key]) return root.matugenPreviews[key];
                                const def = Appearance.m3colors.m3surfaceContainerHigh;
                                return [def, def, def];
                            }
                            isSelected: Config.ready && (Config.options.appearance && Config.options.appearance.background) && Config.options.appearance.background.matugen && Config.options.appearance.background.matugenScheme === modelData.id && Config.options.appearance.background.matugenSource === "lockscreen"
                            onClicked: {
                                Config.options.appearance.background.matugen = true
                                Config.options.appearance.background.matugenCustomColor = ""
                                Config.options.appearance.background.matugenThemeFile = ""
                                Wallpapers.applyScheme(modelData.id, "lockscreen")
                            }
                        }
                    }

                    // Lockscreen Accent Picker (Only visible if expanded)
                    ColorCard {
                        visible: Config.ready && Config.options.lock && Config.options.lock.useSeparateWallpaper && colorSettingsCol.showAllMatugen
                        Layout.fillWidth: true
                        label: "Lockscreen\nAccent Picker"
                        iconName: "colorize"
                        cardColors: [Appearance.m3colors.m3primary, Appearance.m3colors.m3secondary, Appearance.m3colors.m3tertiary]
                        isSelected: Config.ready && !Config.options.appearance.background.matugen && Config.options.appearance.background.matugenCustomColor !== "" && Config.options.appearance.background.matugenThemeFile === "" && Config.options.appearance.background.matugenSource === "lockscreen"
                        onClicked: {
                            GlobalStates.accentPickerTarget = "lock"
                            GlobalStates.accentPickerOpen = true
                        }
                    }
                }

                // Show More Toggle for Matugen
                RippleButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48 * Appearance.effectiveScale
                    buttonRadius: 16 * Appearance.effectiveScale
                    colBackground: Appearance.m3colors.m3surfaceContainerHigh
                    onClicked: colorSettingsCol.showAllMatugen = !colorSettingsCol.showAllMatugen
                    
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8 * Appearance.effectiveScale
                        MaterialSymbol {
                            text: colorSettingsCol.showAllMatugen ? "expand_less" : "expand_more"
                            iconSize: 20 * Appearance.effectiveScale
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: colorSettingsCol.showAllMatugen ? "Show less" : "Show more colors"
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer1
                        }
                    }
                }
            }

            // --- Basic Colors Grid ---
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 16 * Appearance.effectiveScale
                visible: colorSwitcherRow.currentTab === "basic"
                
                GridLayout {
                    Layout.fillWidth: true
                    columns: 5
                    rowSpacing: 16 * Appearance.effectiveScale
                    columnSpacing: 16 * Appearance.effectiveScale

                    Repeater {
                        model: colorSettingsCol.showAllBasic ? root.basicColors : root.basicColors.slice(0, 10)
                        delegate: ColorCard {
                            Layout.fillWidth: true
                            label: modelData.name
                            cardColors: modelData.colors
                            isSelected: Config.ready && (Config.options.appearance && Config.options.appearance.background) && !Config.options.appearance.background.matugen && Config.options.appearance.background.matugenThemeFile === modelData.file
                            onClicked: {
                                Config.options.appearance.background.matugen = false
                                Config.options.appearance.background.matugenScheme = ""
                                Config.options.appearance.background.matugenSource = ""
                                Wallpapers.applyTheme(modelData.file)
                            }
                        }
                    }
                }

                // Show More Toggle for Basic Colors
                RippleButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48 * Appearance.effectiveScale
                    buttonRadius: 16 * Appearance.effectiveScale
                    colBackground: Appearance.m3colors.m3surfaceContainerHigh
                    onClicked: colorSettingsCol.showAllBasic = !colorSettingsCol.showAllBasic
                    
                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 8 * Appearance.effectiveScale
                        MaterialSymbol {
                            text: colorSettingsCol.showAllBasic ? "expand_less" : "expand_more"
                            iconSize: 20 * Appearance.effectiveScale
                            color: Appearance.colors.colPrimary
                        }
                        StyledText {
                            text: colorSettingsCol.showAllBasic ? "Show less" : "Show more colors"
                            font.weight: Font.Medium
                            color: Appearance.colors.colOnLayer1
                        }
                    }
                }
            }
        }
    }
}
