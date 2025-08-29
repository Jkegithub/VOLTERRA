@tool
# ============================================================================
# FINAL SCRIPT  - GameManager.gd (Editor-Safe Version)
# ============================================================================
extends Node

signal player_switched
signal game_over(winner)
signal turn_ended
signal restore_state_requested(state)
signal history_updated(history_size)

enum Player { LIGHT, DARK }

var board_width: int = 4
var board_height: int = 5
var game_variant: String = "classic"
var current_player: Player = Player.LIGHT
var pawn_has_moved: bool = false
var tower_has_moved: bool = false
var history = []
var state_history = []
var is_debug_mode_enabled: bool = false
# ============================================================================
# SONDERREGELN VARIABLEN
# ============================================================================
var rule_steinmetz_enabled: bool = false
var rule_baumeister_enabled: bool = false
var rule_marktplatz_enabled: bool = false

var light_baumeister_used: bool = false
var dark_baumeister_used: bool = false
# ============================================================================
const MAX_HISTORY = 20
# Jede Funktion, die Spiel-Logik enthält, wird jetzt im Editor blockiert.
# Nur reine Daten-Funktionen wie get_player_name laufen noch.

func _ready():
	if Engine.is_editor_hint(): return
	var player_name = get_player_name(current_player)
	print("GameManager ist bereit. Spieler ", player_name, " beginnt.")
		
func action_completed():
	if Engine.is_editor_hint(): return
	if pawn_has_moved and tower_has_moved:
		_switch_player()
		return

	var board = get_tree().get_root().get_node("Game/BOARD")
	if is_instance_valid(board):
		if not board.can_player_perform_remaining_actions(current_player):
			debug_log("Spieler kann keine weitere Aktion ausführen. Zug wird beendet.")
			_switch_player()

func _switch_player():
	if Engine.is_editor_hint(): return
	if current_player == Player.LIGHT:
		current_player = Player.DARK
	else:
		current_player = Player.LIGHT
	
	debug_log("--- SPIELERWECHSEL --- >> Jetzt ist Spieler %s am Zug." % get_player_name(current_player))
	pawn_has_moved = false
	tower_has_moved = false
	player_switched.emit()
	turn_ended.emit()
	print("DEBUG: Spieler gewechselt zu ", get_player_name(current_player), ". Flags zurückgesetzt.") #<-- DIESE ZEILE HINZUFÜGEN
	
func end_the_game(winner):
	if Engine.is_editor_hint(): return
	game_over.emit(winner)
	
func save_state(board_state):
	if Engine.is_editor_hint(): return
	history.push_back(board_state)
	if history.size() > MAX_HISTORY:
		history.pop_front()
	history_updated.emit(history.size())

func undo_last_move():
	if Engine.is_editor_hint(): return
	if history.is_empty():
		debug_log("Keine Züge zum Rückgängigmachen vorhanden.")
		return
	
	debug_log("Mache letzten Zug rückgängig.")
	var last_state = history.pop_back()
	restore_state_requested.emit(last_state)
	history_updated.emit(history.size())
	player_switched.emit()
	
func debug_log(message):
	if Engine.is_editor_hint(): return
	if is_debug_mode_enabled:
		print(message)

# Diese Funktion ist "rein" - sie greift nicht auf die Szene zu und kann
# daher sicher im Editor laufen, ohne einen Schutz zu benötigen.
func get_player_name(player: Player) -> String:
	if player == Player.LIGHT:
		return "HELL"
	else:
		return "DUNKEL"
