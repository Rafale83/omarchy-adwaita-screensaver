.pragma library

var ALL_EFFECTS = [
  "beams", "binarypath", "blackhole", "bouncyballs", "bubbles", "burn",
  "colorshift", "crumble", "decrypt", "errorcorrect", "expand", "fireworks",
  "highlight", "laseretch", "matrix", "middleout", "orbittingvolley",
  "overflow", "pour", "print", "rain", "randomsequence", "rings", "scattered",
  "slice", "slide", "smoke", "spotlights", "spray", "swarm", "sweep",
  "synthgrid", "thunderstorm", "unstable", "vhstape", "waves", "wipe"
]

var DEFAULT_EXCLUDES = [
  "matrix", "decrypt", "vhstape", "thunderstorm", "overflow", "print",
  "binarypath", "synthgrid", "errorcorrect", "orbittingvolley"
]

var LOGOS = [
  { value: "grok", label: "Grok / xAI" },
  { value: "openai", label: "OpenAI" },
  { value: "claude", label: "Claude / Anthropic" },
  { value: "gemini", label: "Gemini / Google" },
  { value: "kimi", label: "Kimi / Moonshot" },
  { value: "glm", label: "GLM / Zhipu" },
  { value: "deepseek", label: "DeepSeek" },
  { value: "qwen", label: "Qwen" },
  { value: "mistral", label: "Mistral" },
  { value: "llama", label: "Llama / Meta" }
]

var SOURCES = [
  { value: "text", label: "Text" },
  { value: "logo", label: "AI logo" },
  { value: "photo", label: "Photo" }
]

function effectOptions() {
  return ALL_EFFECTS.map(function(name) { return { value: name, label: name } })
}

var PLUGIN_ID = "rafale83.hires-screensaver"
var VERSION_URL = "https://raw.githubusercontent.com/Rafale83/omarchy-adwaita-screensaver/main/VERSION"

// -1 if a < b, 0 if equal, 1 if a > b. Missing or non-numeric parts count as 0,
// so "0.2" and "0.2.0" compare equal and garbage never reads as an upgrade.
function compareVersions(a, b) {
  var pa = String(a || "").trim().split(".")
  var pb = String(b || "").trim().split(".")
  for (var i = 0; i < 3; i++) {
    var na = parseInt(pa[i], 10)
    var nb = parseInt(pb[i], 10)
    if (isNaN(na)) na = 0
    if (isNaN(nb)) nb = 0
    if (na !== nb) return na < nb ? -1 : 1
  }
  return 0
}

function isVersion(s) {
  return /^[0-9]+(\.[0-9]+){0,2}$/.test(String(s || "").trim())
}
