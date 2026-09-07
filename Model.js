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
