pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import "../core"

Singleton {
    id: root

    property bool loading: false
    property string errorMessage: ""
    property bool isRunning: activeProcess.running
    property bool isPaused: false
    property bool isInstalled: false
    property bool active: Config.ready && Config.options.appearance.background.liveWallpaperPath !== ""
    
    // Check if linux-wallpaperengine is installed on startup
    Process {
        id: checkInstallation
        command: ["which", "linux-wallpaperengine"]
        running: true
        onExited: (code) => { root.isInstalled = (code === 0); }
    }

    property int targetFps: 30
    property int volume: 15
    property bool silent: false
    property bool autoPause: true

    readonly property ListModel results: ListModel { id: resultsModel }
    readonly property string workshopPath: Directories.home.replace("file://", "") + "/.local/share/Steam/steamapps/workshop/content/431960"
    readonly property string screenshotPath: "/tmp/nandoroid_live_wp.png"

    function fetch() {
        if (loading) return;
        loading = true;
        errorMessage = "";
        results.clear();
        scanProcess.running = true;
    }

    Process {
        id: scanProcess
        command: ["python3", "-c", `
import os
import json
base_path = os.path.expanduser("${root.workshopPath}")
wallpapers = []
if os.path.exists(base_path):
    for folder in sorted(os.listdir(base_path)):
        folder_path = os.path.join(base_path, folder)
        if os.path.isdir(folder_path):
            project_json = os.path.join(folder_path, "project.json")
            if os.path.exists(project_json):
                try:
                    with open(project_json, "r", encoding="utf-8", errors="ignore") as f:
                        content = f.read()
                        if content.startswith("\ufeff"): content = content[1:]
                        data = json.loads(content)
                        wallpapers.append({
                            "id": folder,
                            "title": data.get("title", folder),
                            "preview": "file://" + os.path.join(folder_path, data.get("preview", "")),
                            "folder": folder_path,
                            "metadata": data
                        })
                except: pass
print(json.dumps(wallpapers))
        `]
        stdout: StdioCollector {
            onStreamFinished: {
                root.loading = false;
                try {
                    const data = JSON.parse(this.text);
                    if (data.length === 0) root.errorMessage = "No wallpapers found";
                    else { for (let item of data) root.results.append(item); }
                } catch (e) { root.errorMessage = "Error parsing wallpaper data"; }
            }
        }
    }

    Process {
        id: activeProcess
        onExited: (exitCode) => {
            console.log("[WallpaperEngine] Process exited with code:", exitCode);
            root.isPaused = false;
        }
        stderr: StdioCollector {
            onStreamFinished: {
                if (this.text.trim() !== "") {
                    console.warn("[WallpaperEngine] Log:", this.text.trim());
                }
            }
        }
    }

    function apply(folderPath, previewPath = "") {
        if (!folderPath) return;
        let cleanPath = folderPath.toString();
        if (cleanPath.startsWith("file://")) cleanPath = cleanPath.substring(7);

        root.active = true;
        stopInternal();
        
        if (Config.ready) {
            Config.options.appearance.background.liveWallpaperPath = cleanPath;
            if (previewPath !== "") Config.options.appearance.background.wallpaperPath = previewPath;
        }

        applyTimer.targetFolder = cleanPath;
        applyTimer.start();
    }

    Timer {
        id: applyTimer
        property string targetFolder
        interval: 500
        repeat: false
        onTriggered: {
            // Determine the accurate monitor
            let monitorName = "eDP-1"; // Default fallback
            if (HyprlandData.monitors.length > 0) {
                let primary = HyprlandData.monitors.find(m => m.focused) || HyprlandData.monitors[0];
                monitorName = primary.name;
            }

            console.log("[WallpaperEngine] Launching on:", monitorName, "Path:", targetFolder);
            Quickshell.execDetached(["rm", "-f", root.screenshotPath]);

            // Add Window Rules to Hyprland to ensure it doesn't appear as a rogue window
            Quickshell.execDetached(["hyprctl", "keyword", "windowrule", "stopanim,linux-wallpaperengine"]);
            Quickshell.execDetached(["hyprctl", "keyword", "windowrule", "noinitialfocus,linux-wallpaperengine"]);

            let args = ["linux-wallpaperengine"];
            
            // REQUIRED: --screen-root to prevent it from becoming a regular window
            args.push("--screen-root", monitorName);

            // Fixes for AMD GPU: Use OpenGL and disable PBO to prevent glitches
            args.push("--use-gl");
            args.push("--no-pbo");
            args.push("--disable-particles"); // Lighter for iGPU Lucienne

            // 'stretch' scaling is often more stable than 'fill' on Wayland EGL
            args.push("--scaling", "stretch");
            args.push("--clamp", "border");
            args.push("--no-fullscreen-pause"); 

            args.push("--fps", root.targetFps.toString()); // Use targetFps from property, default 30

            args.push("--volume", root.volume.toString());
            if (root.silent) args.push("--silent");
            args.push("--screenshot", root.screenshotPath);
            args.push("--screenshot-delay", "30");
            
            args.push(targetFolder);
            
            activeProcess.command = args;
            activeProcess.running = true;
            
            matugenWatchTimer.attempts = 0;
            matugenWatchTimer.restart();
        }
    }

    Process {
        id: checkFileProc
        command: ["ls", root.screenshotPath]
        onExited: (code) => {
            if (code === 0) {
                matugenWatchTimer.stop();
                Wallpapers.generateColors(root.screenshotPath);
            }
        }
    }

    Timer {
        id: matugenWatchTimer
        interval: 1500
        repeat: true
        property int attempts: 0
        onTriggered: {
            attempts++;
            if (attempts > 10) { stopInternal(); return; }
            checkFileProc.running = true;
        }
    }

    function stop() {
        root.active = false;
        stopInternal();
        if (Config.ready) Config.options.appearance.background.liveWallpaperPath = "";
    }

    function stopInternal() {
        activeProcess.running = false;
        Quickshell.execDetached(["pkill", "-9", "-f", "linux-wallpaperengine"]);
        root.isPaused = false;
    }

    function pause() {
        if (root.isRunning && !root.isPaused) {
            Quickshell.execDetached(["pkill", "-STOP", "-f", "linux-wallpaperengine"]);
            root.isPaused = true;
        }
    }

    function resume() {
        if (root.isRunning && root.isPaused) {
            Quickshell.execDetached(["pkill", "-CONT", "-f", "linux-wallpaperengine"]);
            root.isPaused = false;
        }
    }

    Timer {
        id: pauseDebounceTimer
        interval: 350
        repeat: false
        onTriggered: updatePauseState()
    }

    Connections {
        target: HyprlandData
        enabled: root.autoPause && root.isRunning
        function onWindowListChanged() { pauseDebounceTimer.restart(); }
        function onActiveWindowChanged() { pauseDebounceTimer.restart(); }
    }

    function updatePauseState() {
        if (!root.autoPause || !root.isRunning || !HyprlandData.activeWorkspace) return;
        const currentWsId = HyprlandData.activeWorkspace.id;
        const shellClasses = ["Quickshell", "nandoroid-settings", "nandoroid-monitor", "wayland-dashboard", "waybar", "ags", "fuzzel"];
        const realWindows = HyprlandData.windowList.filter(win => {
            return win.workspace.id === currentWsId && !shellClasses.includes(win.class) && win.mapped && win.class !== ""; 
        });
        if (realWindows.length > 0) root.pause();
        else root.resume();
    }

    Connections {
        target: Config
        function onReadyChanged() {
            if (Config.ready) {
                const lastPath = Config.options.appearance.background.liveWallpaperPath;
                if (lastPath && lastPath !== "") root.apply(lastPath);
            }
        }
    }

    Connections {
        target: Session
        function onLockedChanged() {
            if (Session.locked) {
                // Only pause if the user is using a separate static wallpaper for the lockscreen
                if (Config.options.lock && Config.options.lock.useSeparateWallpaper) {
                    root.pause();
                }
            } else {
                pauseDebounceTimer.restart();
            }
        }
    }
}
