import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "rafale83.hires-screensaver"
  ipcTarget: "rafale83.hires-screensaver"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  property bool openedFromHotkey: false
  readonly property var barIdentity: hostWidget || root
  readonly property string overlayDir: Quickshell.env("HOME") + "/.config/omarchy/screensaver-overlay"
  readonly property string settingsPath: overlayDir + "/settings.json"
  property var draft: ({
    source: "text",
    text: "",
    logo: "grok",
    photo: "",
    excludeEffects: Model.DEFAULT_EXCLUDES.slice(),
    screensaverSeconds: 150,
    lockSeconds: 300,
    font: Model.DEFAULT_FONT,
    fortuneLang: "en",
    artworkCols: Model.DEFAULT_COLS
  })
  property string statusText: ""
  property bool applying: false

  readonly property string pluginDir: Quickshell.env("HOME") + "/.config/omarchy/plugins/" + Model.PLUGIN_ID
  property string localVersion: ""
  property string remoteVersion: ""
  property string updateStatus: ""
  property bool updateAvailable: false
  property bool updating: false
  property bool verifyingUpdate: false
  property var fontOptions: Model.fontOptions([])
  property string fontWarning: ""

  function open() {
    openedFromHotkey = false
    setCenterHoverRevealSuppressed(false)
    settingsFile.reload()
    root.checkForUpdate()
    root.loadFonts()
    root.controller.show()
  }

  function openFromHotkey() {
    openedFromHotkey = true
    settingsFile.reload()
    root.checkForUpdate()
    root.loadFonts()
    root.controller.show()
    Qt.callLater(function() {
      if (root.opened) setCenterHoverRevealSuppressed(true)
    })
  }

  function close() {
    setCenterHoverRevealSuppressed(false)
    root.controller.hide()
  }

  function toggle() {
    if (root.opened) root.close()
    else root.openFromHotkey()
  }

  function switchPanel(direction) {
    if (root.bar && typeof root.bar.switchPanelFrom === "function")
      return root.bar.switchPanelFrom(root.barIdentity, direction)
    return false
  }

  function setCenterHoverRevealSuppressed(value) {
    if (root.bar && "centerHoverRevealSuppressed" in root.bar)
      root.bar.centerHoverRevealSuppressed = value
  }

  function mergeDraft(raw) {
    var next = {
      source: "text",
      text: "",
      logo: "grok",
      photo: "",
      excludeEffects: Model.DEFAULT_EXCLUDES.slice(),
      screensaverSeconds: 150,
      lockSeconds: 300,
      font: Model.DEFAULT_FONT,
      fortuneLang: "en",
      artworkCols: Model.DEFAULT_COLS
    }
    try {
      var parsed = JSON.parse(raw || "{}")
      for (var k in parsed) next[k] = parsed[k]
    } catch (e) {}
    root.draft = next
    if (textField) textField.text = next.text || ""
    if (fontField) fontField.text = next.font || Model.DEFAULT_FONT
  }

  function numberFieldValue(field, fallback) {
    if (!field) return fallback
    var spin = field.field
    if (!spin) return field.value
    var raw = ""
    try {
      raw = spin.contentItem ? String(spin.contentItem.text) : ""
    } catch (e) {}
    var n = parseInt(raw, 10)
    if (isNaN(n)) n = spin.value
    if (n < spin.from) n = spin.from
    if (n > spin.to) n = spin.to
    return n
  }

  function snapshotDraft() {
    var d = JSON.parse(JSON.stringify(root.draft))
    d.text = textField ? textField.text : d.text
    if (sourceDropdown) d.source = sourceDropdown.value
    if (logoDropdown) d.logo = logoDropdown.value
    d.screensaverSeconds = root.numberFieldValue(screensaverField, d.screensaverSeconds)
    d.lockSeconds = root.numberFieldValue(lockField, d.lockSeconds)
    if (excludeSelect) d.excludeEffects = excludeSelect.values
    if (fontField && fontField.text.trim() !== "") d.font = fontField.text.trim()
    if (langDropdown) d.fortuneLang = langDropdown.value
    d.artworkCols = root.numberFieldValue(colsField, d.artworkCols)
    root.draft = d
    return d
  }

  function scheduleApply() {
    applyDebounce.restart()
  }

  function apply() {
    var d = snapshotDraft()
    root.applying = true
    root.statusText = "Applying…"
    applyProc.running = false
    applyProc.command = ["python3", root.overlayDir + "/apply-settings.py", "--json", JSON.stringify(d)]
    Qt.callLater(function() { applyProc.running = true })
  }

  function pickPhoto() {
    pickProc.running = false
    pickProc.running = true
  }

  function preview() {
    root.close()
    previewTimer.restart()
  }

  function loadFonts() {
    fontsProc.running = false
    Qt.callLater(function() { fontsProc.running = true })
  }

  function validateFont(name) {
    var wanted = String(name || "").trim()
    if (wanted === "") {
      root.fontWarning = ""
      return
    }
    fontCheckProc.running = false
    fontCheckProc.wanted = wanted
    Qt.callLater(function() { fontCheckProc.running = true })
  }

  function checkForUpdate() {
    if (root.updating) return
    root.updateStatus = "Checking…"
    checkProc.running = false
    Qt.callLater(function() { checkProc.running = true })
  }

  function runUpdate() {
    if (root.updating || !root.updateAvailable) return
    root.updating = true
    root.updateStatus = "Updating…"
    updateProc.running = false
    Qt.callLater(function() { updateProc.running = true })
  }

  function restartShell() {
    if (root.bar) root.bar.run("omarchy restart shell")
  }

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.mergeDraft(text())
    onLoadFailed: root.mergeDraft("{}")
  }

  FileView {
    id: versionFile
    path: root.pluginDir + "/VERSION"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      root.localVersion = String(text() || "").trim()
      if (root.verifyingUpdate) {
        root.verifyingUpdate = false
        // `omarchy plugin update` can exit 0 without pulling anything -- a dirty
        // checkout, or already at the newest commit. Trust VERSION, not the exit code.
        if (root.remoteVersion && Model.compareVersions(root.localVersion, root.remoteVersion) >= 0) {
          root.updateAvailable = false
          root.updateStatus = "Updated to v" + root.localVersion + " — restart the shell to load it"
        } else {
          root.updateAvailable = true
          root.updateStatus = "Update did not apply — still v" + root.localVersion
                              + " (local changes in the plugin folder?)"
        }
      }
    }
    onLoadFailed: {
      root.localVersion = ""
      root.verifyingUpdate = false
    }
  }

  Process {
    id: fontsProc
    command: ["bash", "-lc", "fc-list :spacing=100 family | tr ',' '\\n' | sed 's/^ *//;s/ *$//' | sort -u"]
    stdout: StdioCollector { waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) return
      var families = String(stdout.text || "").split("\n").filter(function(s) { return s.trim() !== "" })
      root.fontOptions = Model.fontOptions(families)
    }
  }

  Process {
    id: fontCheckProc
    property string wanted: ""
    command: ["bash", "-lc", "fc-list :family=\"$0\" family | head -1", fontCheckProc.wanted]
    stdout: StdioCollector { waitForEnd: true }
    onExited: function(code) {
      var found = String(stdout.text || "").trim() !== ""
      root.fontWarning = found ? "" : "Font not installed — Adwaita Mono will be used"
    }
  }

  Process {
    id: checkProc
    command: ["curl", "-fsSL", "--max-time", "10", Model.VERSION_URL]
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) {
        root.updateStatus = "Update check failed (offline?)"
        root.updateAvailable = false
        return
      }
      var remote = String(stdout.text || "").trim()
      if (!Model.isVersion(remote)) {
        root.updateStatus = "Update check failed (unexpected reply)"
        root.updateAvailable = false
        return
      }
      root.remoteVersion = remote
      if (!root.localVersion) {
        root.updateStatus = "Latest is v" + remote
        root.updateAvailable = false
      } else if (Model.compareVersions(remote, root.localVersion) > 0) {
        root.updateStatus = "v" + remote + " is available"
        root.updateAvailable = true
      } else {
        root.updateStatus = "Up to date"
        root.updateAvailable = false
      }
    }
  }

  Process {
    id: updateProc
    command: ["bash", "-lc",
      "omarchy plugin update " + Model.PLUGIN_ID + " --yes && " +
      "\"$HOME/.config/omarchy/plugins/" + Model.PLUGIN_ID + "/install.sh\""]
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(code) {
      root.updating = false
      if (code === 0) {
        root.updateStatus = "Verifying…"
        root.verifyingUpdate = true
        versionFile.reload()
      } else {
        root.updateStatus = String(stderr.text || stdout.text || "update failed").trim()
      }
    }
  }

  Process {
    id: applyProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(code) {
      root.applying = false
      if (code === 0) {
        root.statusText = String(stdout.text || "Saved").trim()
        settingsFile.reload()
      } else {
        root.statusText = String(stderr.text || stdout.text || "apply failed").trim()
      }
    }
  }

  Timer {
    id: applyDebounce
    interval: 400
    repeat: false
    onTriggered: root.apply()
  }

  Timer {
    id: previewTimer
    interval: 250
    repeat: false
    onTriggered: {
      var launcher = Quickshell.env("HOME") + "/.local/bin/omarchy-launch-screensaver"
      if (root.bar) root.bar.run(launcher + " force")
    }
  }

  Process {
    id: pickProc
    command: ["omarchy-file-select", "--title", "Screensaver photo", "--extensions", "jpg jpeg png webp"]
    stdout: StdioCollector { waitForEnd: true }
    onExited: function(code) {
      if (code !== 0) return
      var path = String(stdout.text || "").trim()
      if (!path) return
      var d = JSON.parse(JSON.stringify(root.draft))
      d.source = "photo"
      d.photo = path
      root.draft = d
      root.scheduleApply()
    }
  }

  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.openFromHotkey() }
    function close(): void { root.close() }
    function show(): void { root.openFromHotkey() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: true
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(460))
    contentHeight: panel.fittedContentHeight(body.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: textField.activeFocus
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onReturnRequested: root.apply()

      Flickable {
        anchors.fill: parent
        contentWidth: width
        contentHeight: body.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: body
          width: parent.width
          spacing: Style.space(12)
          topPadding: Style.space(14)
          bottomPadding: Style.space(14)
          leftPadding: Style.space(16)
          rightPadding: Style.space(16)

          Row {
            width: parent.width - Style.space(32)
            spacing: Style.space(8)

            Text {
              textFormat: Text.PlainText
              text: "Hires screensaver"
              color: root.bar ? root.bar.foreground : Color.foreground
              font.family: root.bar ? root.bar.fontFamily : Style.font.family
              font.pixelSize: Style.font.display
              font.bold: true
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: root.localVersion !== ""
              textFormat: Text.PlainText
              text: "v" + root.localVersion
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
              font.pixelSize: Style.font.caption
            }
          }

          Row {
            spacing: Style.space(8)
            visible: root.updateStatus !== ""

            Text {
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: root.updateStatus
              color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
              font.pixelSize: Style.font.caption
            }

            Button {
              visible: root.updateAvailable && !root.updating
              text: "Update to v" + root.remoteVersion
              onClicked: root.runUpdate()
            }

            Button {
              visible: !root.updateAvailable && !root.updating
                       && root.updateStatus.indexOf("restart the shell") >= 0
              text: "Restart shell"
              onClicked: root.restartShell()
            }
          }

          PanelSectionHeader { text: "Artwork" }

          Dropdown {
            id: sourceDropdown
            width: parent.width - Style.space(32)
            label: "Source"
            value: root.draft.source
            options: Model.SOURCES
            onChanged: function(v) {
              var d = JSON.parse(JSON.stringify(root.draft))
              d.source = v
              root.draft = d
              root.scheduleApply()
            }
          }

          TextField {
            id: textField
            visible: root.draft.source === "text"
            width: parent.width - Style.space(32)
            placeholderText: "hello world"
            onEditingFinished: root.scheduleApply()
          }

          Dropdown {
            id: langDropdown
            visible: root.draft.source === "fortune"
            width: parent.width - Style.space(32)
            label: "Fortune language"
            value: root.draft.fortuneLang
            options: Model.FORTUNE_LANGS
            onChanged: function(v) {
              var d = JSON.parse(JSON.stringify(root.draft))
              d.fortuneLang = v
              root.draft = d
              root.scheduleApply()
            }
          }

          Text {
            visible: root.draft.source === "fortune"
            width: parent.width - Style.space(32)
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: "A new quote before every effect cycle. Uses the system fortune command when it has a database for the language, otherwise the bundled short ones."
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
            font.pixelSize: Style.font.caption
          }

          Dropdown {
            id: logoDropdown
            visible: root.draft.source === "logo"
            width: parent.width - Style.space(32)
            label: "AI logo"
            value: root.draft.logo
            options: Model.LOGOS
            onChanged: function(v) {
              var d = JSON.parse(JSON.stringify(root.draft))
              d.logo = v
              root.draft = d
              root.scheduleApply()
            }
          }

          Button {
            visible: root.draft.source === "photo"
            text: root.draft.photo ? root.draft.photo.split("/").pop() : "Choose JPEG / PNG"
            onClicked: root.pickPhoto()
          }

          Text {
            visible: root.draft.source === "photo"
            width: parent.width - Style.space(32)
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: "Phone photos are fine. EXIF rotation, 25 MB cap, auto-downscale, truecolor ASCII (not 2-tone)."
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
            font.pixelSize: Style.font.caption
          }

          PanelSectionHeader {
            text: "Font"
            visible: root.draft.source === "text" || root.draft.source === "fortune"
          }

          Dropdown {
            id: fontDropdown
            visible: root.draft.source === "text" || root.draft.source === "fortune"
            width: parent.width - Style.space(32)
            label: "Installed monospace"
            value: root.draft.font
            options: root.fontOptions
            onChanged: function(v) {
              if (fontField) fontField.text = v
              var d = JSON.parse(JSON.stringify(root.draft))
              d.font = v
              root.draft = d
              root.fontWarning = ""
              root.scheduleApply()
            }
          }

          TextField {
            id: fontField
            visible: root.draft.source === "text" || root.draft.source === "fortune"
            width: parent.width - Style.space(32)
            placeholderText: "Or type any installed family"
            onEditingFinished: {
              root.validateFont(text)
              root.scheduleApply()
            }
          }

          Text {
            visible: (root.draft.source === "text" || root.draft.source === "fortune")
                     && root.fontWarning !== ""
            width: parent.width - Style.space(32)
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: root.fontWarning
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
            font.pixelSize: Style.font.caption
          }

          NumberField {
            id: colsField
            visible: root.draft.source === "text" || root.draft.source === "fortune"
            label: "Size (mosaic columns)"
            value: root.draft.artworkCols
            from: 120
            to: 640
            stepSize: 20
            onModified: function(v) {
              var d = JSON.parse(JSON.stringify(root.draft))
              d.artworkCols = v
              root.draft = d
              root.scheduleApply()
            }
          }

          Text {
            visible: root.draft.source === "text" || root.draft.source === "fortune"
            width: parent.width - Style.space(32)
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: "Width of the mosaic in terminal cells, and the height follows. Lower is smaller. 400 is the default and fills most of the screen."
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
            font.pixelSize: Style.font.caption
          }

          Text {
            visible: root.draft.source === "fortune" && root.draft.fortuneLang === "zh"
            width: parent.width - Style.space(32)
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: "Mandarin needs CJK glyphs. A font without them is swapped for Noto Sans CJK automatically."
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
            font.pixelSize: Style.font.caption
          }

          PanelSectionHeader { text: "Lock (Omarchy policy)" }

          Text {
            width: parent.width - Style.space(32)
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: "Uses Omarchy's lock screen. Delays are seconds since you went idle, and apply immediately. Stay Awake, video, or an active agent can still inhibit idle."
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
            font.pixelSize: Style.font.caption
          }

          NumberField {
            id: screensaverField
            label: "Screensaver after (seconds)"
            value: root.draft.screensaverSeconds
            from: 10
            to: 3600
            stepSize: 10
            onModified: function(v) {
              var d = JSON.parse(JSON.stringify(root.draft))
              d.screensaverSeconds = v
              root.draft = d
              root.scheduleApply()
            }
          }

          NumberField {
            id: lockField
            label: "Lock after (seconds)"
            value: root.draft.lockSeconds
            from: 10
            to: 7200
            stepSize: 10
            onModified: function(v) {
              var d = JSON.parse(JSON.stringify(root.draft))
              d.lockSeconds = v
              root.draft = d
              root.scheduleApply()
            }
          }

          PanelSectionHeader { text: "Ugly effects" }

          MultiSelect {
            id: excludeSelect
            width: parent.width - Style.space(32)
            label: "Exclude from random rotation"
            values: root.draft.excludeEffects
            options: Model.effectOptions()
            onChanged: function(vals) {
              var d = JSON.parse(JSON.stringify(root.draft))
              d.excludeEffects = vals
              root.draft = d
              root.scheduleApply()
            }
          }

          Row {
            spacing: Style.space(8)
            Button {
              text: root.applying ? "Saving…" : "Apply"
              enabled: !root.applying
              onClicked: root.apply()
            }
            Button {
              text: "Preview"
              onClicked: root.preview()
            }
          }

          Text {
            width: parent.width - Style.space(32)
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: root.statusText
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
            font.pixelSize: Style.font.caption
          }
        }
      }
    }
  }
}
