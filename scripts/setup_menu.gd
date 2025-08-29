extends PanelContainer

@onready var rules_ui = $RulesUI
@onready var option_button = $VBoxContainer/OptionButton
@onready var width_spinbox = $VBoxContainer/BreiteTiefe/WidthSpinBox
@onready var height_spinbox = $VBoxContainer/BreiteTiefe/HeightSpinBox
@onready var debug_checkbox = $VBoxContainer/ControlTRICK/DebugCheckBox
@onready var steinmetz_checkbox = $VBoxContainer/SonderregelnContainer/SteinmetzCheckBox
@onready var baumeister_checkbox = $VBoxContainer/SonderregelnContainer/BaumeisterCheckBox
@onready var marktplatz_checkbox = $VBoxContainer/SonderregelnContainer/MarktplatzCheckBox


func _ready():
	# NEU: Angepasste Namen für die Spielvarianten
	option_button.add_item("Klassisch 4x5 original", 0)
	option_button.add_item("Klassisch Großes Brett", 1)
	option_button.add_item("Arena Modus mit Rand", 2)
	option_button.add_item("Spiel mit Hindernissen", 3)
	
	# Initial die korrekten Größen-Einstellungen für die erste Variante setzen
	_on_option_button_item_selected(0)


# NEU: Diese Funktion reagiert auf die Auswahl im Dropdown-Menü
func _on_option_button_item_selected(index):
	match index:
		0: # Klassisch 4x5 original
			width_spinbox.value = 4
			height_spinbox.value = 5
			width_spinbox.editable = false
			height_spinbox.editable = false
		1: # Klassisch Großes Brett
			width_spinbox.value = 8
			height_spinbox.value = 8
			width_spinbox.editable = true
			height_spinbox.editable = true
		2: # Arena Modus mit Rand
			# NEU: Feste Größe 5x5 und gesperrt
			width_spinbox.value = 5
			height_spinbox.value = 5
			width_spinbox.editable = false
			height_spinbox.editable = false
		3: # Felsen-Hindernisse
			width_spinbox.value = 6
			height_spinbox.value = 6
			width_spinbox.editable = true
			height_spinbox.editable = true

func _on_start_button_pressed():
	GameManager.board_width = width_spinbox.value
	GameManager.board_height = height_spinbox.value
	GameManager.is_debug_mode_enabled = debug_checkbox.button_pressed
	
	match option_button.selected:
		0: GameManager.game_variant = "classic"
		1: GameManager.game_variant = "classic_free_side"
		2: GameManager.game_variant = "arena"
		3: GameManager.game_variant = "rocks"

	GameManager.rule_steinmetz_enabled = steinmetz_checkbox.button_pressed
	GameManager.rule_baumeister_enabled = baumeister_checkbox.button_pressed
	GameManager.rule_marktplatz_enabled = marktplatz_checkbox.button_pressed

	# ============================================================================
	# NEUE DEBUG-AUSGABE
	# ============================================================================
	# print("MENÜ-CHECK: Marktplatz-Regel gesetzt auf: ", GameManager.rule_marktplatz_enabled)
	# print("MENÜ-CHECK: BAUMEISTER-Regel gesetzt auf: ", GameManager.rule_baumeister_enabled)
	# print("MENÜ-CHECK: STEINMETZ-Regel gesetzt auf: ", GameManager.rule_steinmetz_enabled)
	# ============================================================================

	get_tree().change_scene_to_file("res://scenes/game.tscn")


func _on_spielregeln_button_pressed():
	rules_ui.show()
