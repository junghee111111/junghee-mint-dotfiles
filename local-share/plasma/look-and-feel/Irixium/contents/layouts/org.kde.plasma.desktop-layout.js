var panel = new Panel
var panelScreen = panel.screen
panel.height = 64

const geo = screenGeometry(panelScreen);
panel.alignment = "center";
panel.minimumLength = geo.width * 2 / 3
panel.maximumLength = geo.width * 2 / 3



panel.addWidget("org.kde.plasma.pager")
panel.addWidget("org.kde.plasma.panelspacer")

var kickoff = panel.addWidget("org.kde.plasma.kickoff")
kickoff.currentConfigGroup = ["Shortcuts"]
kickoff.writeConfig("global", "Alt+F1")



var tasks = panel.addWidget("org.kde.plasma.taskmanager")
tasks.currentConfigGroup = ["General"]
tasks.writeConfig("maxStripes", "2")
tasks.writeConfig("forceStripes", true)
tasks.writeConfig("launchers", "")

panel.addWidget("org.kde.plasma.panelspacer")

var langIds = ["as",    // Assamese
               "bn",    // Bengali
               "bo",    // Tibetan
               "brx",   // Bodo
               "doi",   // Dogri
               "gu",    // Gujarati
               "hi",    // Hindi
               "ja",    // Japanese
               "kn",    // Kannada
               "ko",    // Korean
               "kok",   // Konkani
               "ks",    // Kashmiri
               "lep",   // Lepcha
               "mai",   // Maithili
               "ml",    // Malayalam
               "mni",   // Manipuri
               "mr",    // Marathi
               "ne",    // Nepali
               "or",    // Odia
               "pa",    // Punjabi
               "sa",    // Sanskrit
               "sat",   // Santali
               "sd",    // Sindhi
               "si",    // Sinhala
               "ta",    // Tamil
               "te",    // Telugu
               "th",    // Thai
               "ur",    // Urdu
               "vi",    // Vietnamese
               "zh_CN", // Simplified Chinese
               "zh_TW"] // Traditional Chinese

if (langIds.indexOf(languageId) != -1) {
    panel.addWidget("org.kde.plasma.kimpanel");
}

panel.addWidget("org.kde.plasma.systemtray")

var aclock = panel.addWidget("org.kde.plasma.analogclock")
aclock.currentConfigGroup = ["General"]
aclock.writeConfig("showSecondHand", true)

panel.addWidget("org.kde.plasma.lock_logout")
