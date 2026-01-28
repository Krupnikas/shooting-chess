extends Node

# Settings manager for language and other preferences
# Handles auto-detection of device language and persistent storage

const SETTINGS_FILE = "user://settings.cfg"
const SECTION = "settings"
const KEY_LANGUAGE = "language"

# Supported languages
const LANG_EN = "en"
const LANG_RU = "ru"
const SUPPORTED_LANGUAGES = [LANG_EN, LANG_RU]

signal language_changed(locale: String)

var current_language: String = LANG_EN

func _ready():
	_load_settings()

func _load_settings():
	var config = ConfigFile.new()
	var err = config.load(SETTINGS_FILE)

	if err == OK:
		current_language = config.get_value(SECTION, KEY_LANGUAGE, _detect_system_language())
	else:
		# First launch - detect system language
		current_language = _detect_system_language()
		_save_settings()

	_apply_language(current_language)

func _detect_system_language() -> String:
	# OS.get_locale() returns locale like "en_US", "ru_RU", etc.
	var locale = OS.get_locale()
	var lang_code = locale.split("_")[0].to_lower()

	# If Russian, use Russian; otherwise default to English
	if lang_code == "ru":
		return LANG_RU
	return LANG_EN

func set_language(locale: String):
	if locale not in SUPPORTED_LANGUAGES:
		locale = LANG_EN

	current_language = locale
	_apply_language(locale)
	_save_settings()
	emit_signal("language_changed", locale)

func _apply_language(locale: String):
	TranslationServer.set_locale(locale)

func _save_settings():
	var config = ConfigFile.new()
	config.set_value(SECTION, KEY_LANGUAGE, current_language)
	config.save(SETTINGS_FILE)

func get_language_display_name(locale: String) -> String:
	match locale:
		LANG_EN:
			return "English"
		LANG_RU:
			return "Русский"
	return locale

func is_russian() -> bool:
	return current_language == LANG_RU

func is_english() -> bool:
	return current_language == LANG_EN
