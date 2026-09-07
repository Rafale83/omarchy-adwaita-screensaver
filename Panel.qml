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
    lockSeconds: 300
  })
  property string statusText: ""
  property bool applying: false

  function open() {
    openedFromHotkey = false
    setCenterHoverRevealSuppressed(false)
    settingsFile.reload()
    root.controller.show()
  }

  function openFromHotkey() {
    openedFromHotkey = true
    settingsFile.reload()
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
      lockSeconds: 300
    }
    try {
      var parsed = JSON.parse(raw || "{}")
      for (var k in parsed) next[k] = parsed[k]
    } catch (e) {}
    root.draft = next
    if (textField) textField.text = next.text || ""
  }

  function snapshotDraft() {
    var d = JSON.parse(JSON.stringify(root.draft))
    d.text = textField ? textField.text : d.text
    if (sourceDropdown) d.source = sourceDropdown.value
    if (logoDropdown) d.logo = logoDropdown.value
    if (screensaverField) d.screensaverSeconds = screensaverField.value
    if (lockField) d.lockSeconds = lockField.value
    if (excludeSelect) d.excludeEffects = excludeSelect.values
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

  FileView {
    id: settingsFile
    path: root.settingsPath
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.mergeDraft(text())
    onLoadFailed: root.mergeDraft("{}")
  }

  Process {
    id: applyProc
    stdout: StdioCollector { waitForEnd: true }
    stderr: StdioCollector { waitForEnd: true }
    onExited: function(code) {
      root.applying = false
      if (code === 0) {
        root.statusText = "Saved"
        settingsFile.reload()
      } else {
        root.statusText = String(stderr.text || "apply failed").trim()
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

          Text {
            textFormat: Text.PlainText
            text: "Hires screensaver"
            color: root.bar ? root.bar.foreground : Color.foreground
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.display
            font.bold: true
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
            id: logoDropdown
            visible: root.draft.source === "logo"
            width: parent.width - Style.space(32)
            label: "AI parish"
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
            text: "Phone photos are fine. EXIF rotation, 25 MB cap, auto-downscale, contrast stretch, half-block mosaic."
            color: Qt.darker(root.bar ? root.bar.foreground : Color.foreground, 1.4)
            font.pixelSize: Style.font.caption
          }

          PanelSectionHeader { text: "Lock (Omarchy policy)" }

          Text {
            width: parent.width - Style.space(32)
            wrapMode: Text.WordWrap
            textFormat: Text.PlainText
            text: "Uses Omarchy's lock screen (password, fingerprint, FIDO2 — whatever you already set up). This only changes idle delays."
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
