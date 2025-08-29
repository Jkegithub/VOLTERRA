# ============================================================================
#                         board_3d.gd - Consolidated Final Version
# ============================================================================
@tool
extends Node3D

# ============================================================================
# 1. Exports & Klassenvariablen
# ============================================================================

# --- Szenen & Nodes (im Editor zugewiesen) ---
@export var tower_piece_scene: PackedScene
@export var pawn_scene: PackedScene
@export var foundation_tile_scene: PackedScene
@export var obstacle_scenes: Array[PackedScene]

# --- Direkte Node-Referenzen (im Editor zugewiesen) ---
@export var camera_controller: Node3D
@export var camera_pivot: Node3D
@export var cursor: Node3D
@export var floor_mesh_instance: MeshInstance3D
@export var directional_light: DirectionalLight3D
@export var world_environment: WorldEnvironment

# --- UI-Elemente (im Editor zugewiesen) ---
@export var move_amount_ui: Control
@export var player_turn_label: Label
@export var action_hint_label: Label
@export var cancel_action_button: Button
@export var undo_button: Button
@export var invalid_move_overlay: ColorRect
@export var steinmetz_button: Button
@export var baumeister_button: Button

# --- Sounds (im Editor zugewiesen) ---
@export var move_sound_player: AudioStreamPlayer
@export var pawn_move_sound_player: AudioStreamPlayer
@export var victory_sound_player: AudioStreamPlayer
@export var undo_sound_player: AudioStreamPlayer
@export var ui_click_sound_player: AudioStreamPlayer
@export var select_sound_player: AudioStreamPlayer
@export var error_sound_player: AudioStreamPlayer

# --- Materials (im Editor zugewiesen) ---
@export var light_material: StandardMaterial3D
@export var dark_material: StandardMaterial3D
@export var gold_material: StandardMaterial3D
@export var dark_pawn_color : Color = Color(0.45, 0.45, 0.45)
@export var light_pawn_color : Color = Color(1, 1, 1)

# --- Interne Zustandsvariablen ---
var board_grid = {}
var foundation_grid = {}
var light_pawn: Node3D
var dark_pawn: Node3D
var selected_pawn: Node3D = null
var selected_source_tower_coords: Vector2i = Vector2i(-1, -1)
var pieces_to_move = 0
var is_in_steinmetz_mode: bool = false
var is_in_baumeister_mode: bool = false
var islands: Array = []
var marketplace_coords: Array = []
var is_game_over: bool = false
var board_offset := Vector3.ZERO
# Standard-Brettgröße für die Editor-Vorschau
var board_width: int = 8
var board_height: int = 8

# in board_3d.gd, nach den Konstanten

# --- Licht-Presets für schnelles Umschalten ---
var current_lighting_preset = 2
var lighting_presets = [
		{
				"name": "Klarer Mittag",
				"light_color": Color("#FFF4D4"),
				"light_rotation_x": -45.0,
				"shadow_blur": 1.5,
				"sky_top_color": Color("#87CEEB"),
				"sky_horizon_color": Color("#FDB813"),
				"ambient_color": Color("#CCDDEE"),
				"ambient_energy": 0.8,
				"glow_enabled": false
		},
		{
				"name": "Dramatische Dämmerung",
				"light_color": Color("#FF8C00"),
				"light_rotation_x": -75.0,
				"shadow_blur": 1.0,
				"sky_top_color": Color("#191970"),
				"sky_horizon_color": Color("#FF4500"),
				"ambient_color": Color("#465569"),
				"ambient_energy": 0.5,
				"glow_enabled": true,
				"glow_intensity": 0.6,
				"glow_strength": 1.2
		},
		{
				"name": "Warmer Nachmittag",
				"light_color": Color("#FFFFFF"),
				"light_rotation_x": -35.0,
				"shadow_blur": 1.0,
				"sky_top_color": Color("#D3D3D3"), # Wird als Umgebungsfarbe genutzt
				"sky_horizon_color": Color("#B0B0B0"),
				"ambient_color": Color("#B0B0B0"),
				"ambient_energy": 1.0,
				"glow_enabled": false
		}
]

# --- Konstanten ---
const SPACING = 1.05
const PIECE_HEIGHT = 0.25
const PAWN_HEIGHT = 0.9


# ============================================================================
# 2. Godot Lifecycle Functions
# ============================================================================

func _ready():
	# --- Visueller Aufbau (läuft immer, auch im Editor) ---
	# Baut das Spielfeld an der richtigen Position auf.
	_calculate_layout_and_build_board()
	update_tower_labels()
	_apply_lighting_preset(2)

	# --- Gameplay-Logik (läuft NUR, wenn das Spiel mit F5 gestartet wird) ---
	if not Engine.is_editor_hint():
		# 1. Signale verbinden
		GameManager.game_over.connect(_on_game_over)
		GameManager.player_switched.connect(_on_player_switched)
		GameManager.turn_ended.connect(_on_turn_ended)
		GameManager.restore_state_requested.connect(restore_board_state)
		GameManager.history_updated.connect(_on_history_updated)

		# 2. UI und Spielfiguren initialisieren
		undo_button.hide()
		var rock_positions = [] # Wird im Spiel nicht mehr gebraucht, daher leer
		place_pawns()
		_print_start_log(rock_positions)

		# 3. Den ersten Zug des Spiels initialisieren
		_start_new_turn()

# ============================================================================
# 3. Signal-Callbacks (von GameManager)
# ============================================================================

# Wird aufgerufen, wenn GameManager das Spielende signalisiert.
func _on_game_over(winner_player):
	is_game_over = true
	set_process_input(false) # Stoppt weitere Spieler-Inputs
	
	# Alle Aktions-UI ausblenden
	cancel_action_button.hide()
	steinmetz_button.hide()
	baumeister_button.hide()
	move_amount_ui.hide()
	
	# Sound abspielen und Gewinnertext anzeigen
	victory_sound_player.play()
	var winner_label = get_node("../GameOverUI/WinnerLabel")
	if winner_player == null:
		winner_label.text = "Unentschieden!"
	else:
		var winner_text = "SPIELER " + GameManager.get_player_name(winner_player)
		winner_label.text = winner_text + " hat gewonnen!"
	
	# Kamera optional auf den höchsten Turm des Gewinners schwenken
	if winner_player != null:
		var highest_tower_pos = _find_highest_tower(winner_player)
		var camera = get_viewport().get_camera_3d()
		var camera_start_transform = camera.global_transform
		if highest_tower_pos != Vector3.ZERO:
			var tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_OUT)
			tween.tween_property(camera, "global_transform", camera_start_transform.looking_at(highest_tower_pos), 2.0)
			await tween.finished
	
	# Game-Over-UI einblenden
	var game_over_ui = get_node("../GameOverUI")
	game_over_ui.modulate.a = 0.0
	game_over_ui.show()
	var ui_tween = create_tween()
	ui_tween.tween_property(game_over_ui, "modulate:a", 1.0, 1.0)

# Wird aufgerufen, wenn der Spieler gewechselt hat.
func _on_player_switched():
	_start_new_turn()

# Wird aufgerufen, wenn ein kompletter Zug (beide Spieler) vorbei ist.
func _on_turn_ended():
	_check_for_repetition()

# Wird aufgerufen, um den Undo-Button basierend auf der Historie ein-/auszublenden.
func _on_history_updated(history_size: int):
	undo_button.visible = history_size > 0


# ============================================================================
# 4. Haupt-Spiellogik (Zugablauf)
# ============================================================================

# Initialisiert einen neuen Zug für den aktuellen Spieler.
# in board_3d.gd
func _start_new_turn():
	_reset_selection_state()
	_clear_visual_highlights()
	_update_cursor_position()
	
	var can_move_pawn = _can_player_move_pawn(GameManager.current_player)
	var can_move_tower = _can_player_move_tower(GameManager.current_player)
	
	if not (can_move_pawn and can_move_tower):
		var player_name = GameManager.get_player_name(GameManager.current_player)
		GameManager.debug_log("SPIELENDE: Spieler %s kann nicht mehr beide Aktionen ausführen." % player_name)
		GameManager.end_the_game(determine_winner())
		return

	_update_turn_instructions()

func _update_turn_instructions():
	# Spieleranzeige und Aktionshinweis
	var player_text = GameManager.get_player_name(GameManager.current_player)
	player_turn_label.text = "Spieler " + player_text + " ist am Zug."

	if not GameManager.pawn_has_moved and not GameManager.tower_has_moved:
		action_hint_label.text = "Aktion 1/2: Wähle Figur ODER Turm"
	elif not GameManager.pawn_has_moved:
		action_hint_label.text = "Aktion 2/2: Figur bewegen"
	elif not GameManager.tower_has_moved:
		action_hint_label.text = "Aktion 2/2: Turm bewegen"
	else:
		action_hint_label.text = ""

	# Sonderregel-Buttons initial ausblenden
	steinmetz_button.hide()
	baumeister_button.hide()
	
	# Buttons nur anzeigen, wenn die Turm-Aktion noch nicht ausgeführt wurde
	if not GameManager.tower_has_moved:
		if GameManager.rule_steinmetz_enabled:
			steinmetz_button.show()

		# KORREKTUR: Der gesamte Block wird nur ausgeführt, wenn die Regel aktiv ist.
		if GameManager.rule_baumeister_enabled:
			var player_name = GameManager.get_player_name(GameManager.current_player)
			GameManager.debug_log("DEBUG (Baumeister) für Spieler %s: Regel ist aktiv." % player_name)
			var player_has_used_baumeister = (GameManager.current_player == GameManager.Player.LIGHT and GameManager.light_baumeister_used) or \
				(GameManager.current_player == GameManager.Player.DARK and GameManager.dark_baumeister_used)
			GameManager.debug_log("DEBUG (Baumeister) für Spieler %s: Fähigkeit bereits benutzt? %s" % [player_name, player_has_used_baumeister])
	
			if not player_has_used_baumeister:
				GameManager.debug_log("DEBUG (Baumeister) für Spieler %s: Zeige Button." % player_name)
				if is_instance_valid(baumeister_button):
					baumeister_button.show()
				else:
					print("!!!! DEBUG-FEHLER (Baumeister): Die Variable 'baumeister_button' ist nicht zugewiesen!")

func _reset_selection_state():
	selected_pawn = null
	selected_source_tower_coords = Vector2i(-1, -1)
	pieces_to_move = 0
	is_in_steinmetz_mode = false
	is_in_baumeister_mode = false
	cancel_action_button.hide()
	steinmetz_button.hide()
	baumeister_button.hide()


# ============================================================================
# 5. Input-Verarbeitung (Spieler-Klicks)
# ============================================================================

# Wird von der Spielfigur selbst aufgerufen, wenn sie geklickt wird.
func on_pawn_clicked(pawn_node: Node3D):
	if is_game_over: return
	# --- DEBUG-SPION HINZUFÜGEN ---
	print("----------- PAWN KLICK-CHECK -----------")
	print("Aktueller Spieler laut GameManager: ", GameManager.get_player_name(GameManager.current_player))
	print("Farbe des geklickten Pawns: ", GameManager.get_player_name(pawn_node.player_color))
	print("Pawn wurde bereits bewegt? ", GameManager.pawn_has_moved)
	print("Bedingung 'Farbe stimmt': ", pawn_node.player_color == GameManager.current_player)
	print("Bedingung 'Pawn nicht bewegt': ", not GameManager.pawn_has_moved)
	print("------------------------------------")
	# --- PRÄZISER DIAGNOSE-SPION ---
	print("----------- PAWN KLICK-DIAGNOSE -----------")
	print("Aktueller Spieler: %s (Wert: %d)" % [GameManager.get_player_name(GameManager.current_player), GameManager.current_player])
	print("Geklickter Pawn: %s (Wert: %d)" % [GameManager.get_player_name(pawn_node.player_color), pawn_node.player_color])
	print("Pawn wurde bereits bewegt? ", GameManager.pawn_has_moved)
	print("-----------------------------------------")
	# --- ENDE DIAGNOSE-SPION ---
	# --- ENDE DEBUG-SPION ---
	
	if not GameManager.pawn_has_moved and pawn_node.player_color == GameManager.current_player:
		if is_instance_valid(select_sound_player): select_sound_player.play()
		show_valid_pawn_moves(pawn_node)
		cancel_action_button.show()
		
		# ===================================================================
		# NEU: Direkte Aktualisierung des Hinweistextes & Debug-Meldung
		# ===================================================================
		action_hint_label.text = "Aktion 1/2: Wähle ein Zielfeld"
		var player_name = GameManager.get_player_name(pawn_node.player_color)
		GameManager.debug_log("Figur " + player_name + " ist ausgewählt.")
		# ===================================================================
		
	else:
		if is_instance_valid(error_sound_player): error_sound_player.play()
		_flash_invalid_move_indicator()
		if GameManager.pawn_has_moved:
			GameManager.debug_log("Ungültiger Zug: Figur wurde bereits bewegt.")
		else:
			GameManager.debug_log("Ungültiger Zug: Das ist nicht deine Figur.")
			
# Wird von einem Turmstein aufgerufen, wenn er geklickt wird.
func on_tower_piece_clicked(coords: Vector2i):
	if is_game_over: return # WÄCHTER

	# Sonderregel-Modi haben Vorrang
	if is_in_steinmetz_mode:
		_handle_steinmetz_click(coords)
		return
	if is_in_baumeister_mode:
		_handle_baumeister_click(coords)
		return

	# Fall 1: Eine Figur ist bereits ausgewählt -> dies ist der Ziel-Klick
	if selected_pawn != null:
		var top_piece = board_grid.get(coords, []).back()
		if not top_piece or not top_piece.get_node("HighlightMesh").visible:
			GameManager.debug_log("Ungültiger Zug: Turm bei %s ist kein gültiges Ziel für die Figur." % _coords_to_notation(coords))
			if is_instance_valid(error_sound_player): error_sound_player.play()
			_flash_invalid_move_indicator()
			return
		_execute_pawn_move(coords)
		return

	# Fall 2: Ein Quell-Turm ist bereits ausgewählt -> dies ist der Ziel-Klick
	if selected_source_tower_coords != Vector2i(-1, -1):
		var is_foundation_highlighted = foundation_grid.has(coords) and foundation_grid[coords].get_node("HighlightMesh").visible
		var top_piece = board_grid.get(coords, []).back()
		if (not top_piece or not top_piece.get_node("HighlightMesh").visible) and not is_foundation_highlighted:
			GameManager.debug_log("Ungültiger Zug: Feld bei %s ist kein gültiges Ziel für den Turm." % _coords_to_notation(coords))
			if is_instance_valid(error_sound_player): error_sound_player.play()
			_flash_invalid_move_indicator()
			return
		_execute_tower_move(selected_source_tower_coords, coords)
		return
	
	# Fall 3: Nichts ist ausgewählt -> dies ist der Quell-Klick für einen Turmzug
	if not GameManager.tower_has_moved and _is_valid_source_tower(coords):
		if is_instance_valid(select_sound_player): select_sound_player.play()
		selected_source_tower_coords = coords
		
		# KORREKTUR: Sonderregel-Buttons ausblenden, SOBALD der normale Turmzug beginnt.
		steinmetz_button.hide()
		baumeister_button.hide()
		
		move_amount_ui.get_node("CenterContainer/VBoxContainer/Button2").disabled = (board_grid[coords].size() < 2)
		board_grid[coords].back().get_node("HighlightMesh").show()
		move_amount_ui.show()
		cancel_action_button.show()
	else:
		GameManager.debug_log("Ungültiger Zug: Turm bei %s kann nicht als Quelle gewählt werden." % _coords_to_notation(coords))
		if is_instance_valid(error_sound_player): error_sound_player.play()
		_flash_invalid_move_indicator()

# Wird von einem leeren Baufeld aufgerufen, wenn es geklickt wird.
func on_foundation_tile_clicked(coordinates: Vector2i):
	if selected_source_tower_coords != Vector2i(-1, -1):
		var foundation = foundation_grid[coordinates]
		if foundation and foundation.get_node("HighlightMesh").visible:
			_execute_tower_move(selected_source_tower_coords, coordinates)


# ============================================================================
# 6. UI-Signal Callbacks (Buttons etc.)
# ============================================================================

func _on_cancel_action_button_pressed():
	if is_instance_valid(ui_click_sound_player): ui_click_sound_player.play()
	_clear_visual_highlights()
	_reset_selection_state()
	_update_turn_instructions()
	
func _on_undo_button_pressed():
	if is_instance_valid(undo_sound_player): undo_sound_player.play()
	GameManager.undo_last_move()

func _on_move_amount_ui_move_one_piece():
	move_amount_ui.hide()
	pieces_to_move = 1
	show_valid_target_towers(selected_source_tower_coords)

func _on_move_amount_ui_move_two_pieces():
	move_amount_ui.hide()
	pieces_to_move = 2
	show_valid_target_towers(selected_source_tower_coords)

func _on_abbrechen_pressed():
	move_amount_ui.hide()
	_clear_visual_highlights()
	_reset_selection_state()

func _on_steinmetz_button_pressed():
	if is_instance_valid(ui_click_sound_player): ui_click_sound_player.play()
	_clear_visual_highlights(); _reset_selection_state()
	is_in_steinmetz_mode = true
	action_hint_label.text = "STEINMETZ: Wähle einen deiner Türme als Quelle"
	cancel_action_button.show()
	for coord in board_grid:
		if _is_valid_source_tower(coord):
			board_grid[coord].back().get_node("HighlightMesh").show()

func _on_baumeister_button_pressed():
	if is_instance_valid(ui_click_sound_player): ui_click_sound_player.play()
	is_in_baumeister_mode = true
	_clear_visual_highlights()
	action_hint_label.text = "BAUMEISTER: Wähle einen blockierten Turm"
	steinmetz_button.hide()
	baumeister_button.hide()
	cancel_action_button.show()
	
	var current_pawn = light_pawn if GameManager.current_player == GameManager.Player.LIGHT else dark_pawn
	var pawn_coords = Vector2i(round((current_pawn.position.x + board_offset.x) / SPACING), round((current_pawn.position.z + board_offset.z) / SPACING))
	for coord in get_neighbor_coords(pawn_coords):
		if _is_valid_baumeister_source(coord):
			board_grid[coord].back().get_node("HighlightMesh").show()


# ============================================================================
# 7. Aktionsausführung (Logik der Züge)
# ============================================================================

func _execute_pawn_move(coords: Vector2i):
	GameManager.save_state(capture_board_state())
	var pawn_grid_pos = Vector2i(round((selected_pawn.position.x + board_offset.x) / SPACING), round((selected_pawn.position.z + board_offset.z) / SPACING))
	GameManager.debug_log("FIGUR BEWEGT: von %s nach %s" % [_coords_to_notation(pawn_grid_pos), _coords_to_notation(coords)])
	
	selected_pawn.position = Vector3(coords.x * SPACING, board_grid[coords].size() * PIECE_HEIGHT, coords.y * SPACING) - self.board_offset
	pawn_move_sound_player.play()
	_update_cursor_position()
	GameManager.pawn_has_moved = true
	
	# Alte Aktionen löschen und Auswahl zurücksetzen
	_clear_visual_highlights()
	_reset_selection_state()
	
	# Nächste gültige Aktionen anzeigen
	if not GameManager.tower_has_moved: 
		show_valid_source_towers()
	
	# KORREKTUR: Aktionstext explizit aktualisieren
	_update_turn_instructions()
	
	GameManager.action_completed()

# Führt die Bewegung eines Turms aus.
# Ersetze die komplette Funktion mit dieser korrigierten Version.
func _execute_tower_move(source_coords: Vector2i, target_coords: Vector2i):
	GameManager.save_state(capture_board_state())
	GameManager.debug_log("TURM VERSETZT: %s Stein(e) von %s nach %s" % [pieces_to_move, _coords_to_notation(source_coords), _coords_to_notation(target_coords)])
	
	var source_stack = board_grid[source_coords]
	if not board_grid.has(target_coords): board_grid[target_coords] = []
	var target_stack = board_grid[target_coords]
	
	var pieces_to_move_nodes = []
	for i in range(pieces_to_move):
		if not source_stack.is_empty(): pieces_to_move_nodes.append(source_stack.pop_back())
	
	pieces_to_move_nodes.reverse()
	for piece in pieces_to_move_nodes:
		target_stack.push_back(piece)
		piece.coordinates = target_coords
	
	var top_piece = target_stack.back()
	if target_coords in marketplace_coords:
		top_piece.get_node("MeshInstance3D").set_surface_override_material(0, gold_material)
	elif top_piece.color == GameManager.Player.LIGHT:
		top_piece.get_node("MeshInstance3D").set_surface_override_material(0, light_material)
	else:
		top_piece.get_node("MeshInstance3D").set_surface_override_material(0, dark_material)

	for i in range(target_stack.size()):
		var piece = target_stack[i]
		piece.position = Vector3(target_coords.x * SPACING, i * PIECE_HEIGHT, target_coords.y * SPACING) - self.board_offset
	
	update_tower_labels()
	move_sound_player.play()
	if source_stack.is_empty(): handle_board_split()
	GameManager.tower_has_moved = true
	
	# Alte Aktionen löschen und Auswahl zurücksetzen
	_clear_visual_highlights()
	_reset_selection_state()
	
	# Nächste gültige Aktionen anzeigen
	if not GameManager.pawn_has_moved:
		var current_pawn = light_pawn if GameManager.current_player == GameManager.Player.LIGHT else dark_pawn
		show_valid_pawn_moves(current_pawn)
	
	# KORREKTUR: Aktionstext explizit aktualisieren
	_update_turn_instructions()
	
	GameManager.action_completed()


# ============================================================================
# 8. Sonderregel-Logik (Steinmetz, Baumeister)
# ============================================================================

# Behandelt die Klick-Logik für den Baumeister-Zug.
func _handle_baumeister_click(coords: Vector2i):
	if not _is_valid_baumeister_source(coords):
		if is_instance_valid(error_sound_player): error_sound_player.play()
		_flash_invalid_move_indicator()
		GameManager.debug_log("Ungültiger Baumeister-Zug: Turm bei %s kann nicht gewählt werden." % _coords_to_notation(coords))
		return

	if GameManager.current_player == GameManager.Player.LIGHT:
		GameManager.light_baumeister_used = true
	else:
		GameManager.dark_baumeister_used = true
	
	var player_name = GameManager.get_player_name(GameManager.current_player)
	GameManager.debug_log("BAUMEISTER-FÄHIGKEIT von Spieler %s eingesetzt." % player_name)
	
	if is_instance_valid(select_sound_player): select_sound_player.play()
	is_in_baumeister_mode = false
	
	var top_piece = board_grid[coords].back()
	selected_source_tower_coords = coords
	move_amount_ui.get_node("CenterContainer/VBoxContainer/Button2").disabled = (board_grid[coords].size() < 2)
	top_piece.get_node("HighlightMesh").show()
	move_amount_ui.show()
	
	action_hint_label.text = "BAUMEISTER: Wähle Anzahl der Steine"
	steinmetz_button.hide()
	baumeister_button.hide()
	cancel_action_button.show()

# Behandelt die Zwei-Klick-Logik für den Steinmetz-Zug.
func _handle_steinmetz_click(coords: Vector2i):
	# Erster Klick: Quelle des Steins auswählen
	if selected_source_tower_coords == Vector2i(-1, -1):
		if not _is_valid_source_tower(coords):
			_clear_visual_highlights(); _reset_selection_state()
			return
		
		selected_source_tower_coords = coords
		_clear_visual_highlights()
		steinmetz_button.hide()
		baumeister_button.hide()
		action_hint_label.text = "STEINMETZ: Wähle Ziel (nicht auf Figuren)"

		var light_pawn_coords = Vector2i(round((light_pawn.position.x + board_offset.x) / SPACING), round((light_pawn.position.z + board_offset.z) / SPACING))
		var dark_pawn_coords = Vector2i(round((dark_pawn.position.x + board_offset.x) / SPACING), round((dark_pawn.position.z + board_offset.z) / SPACING))

		for target_coord in board_grid:
			if target_coord == selected_source_tower_coords: continue
			if target_coord == light_pawn_coords or target_coord == dark_pawn_coords: continue
			
			if not board_grid[target_coord].is_empty() and not board_grid[target_coord].back().is_in_group("obstacles"):
				board_grid[target_coord].back().get_node("HighlightMesh").show()
				
	# Zweiter Klick: Ziel des Steins auswählen und Zug ausführen
	else:
		var light_pawn_coords = Vector2i(round((light_pawn.position.x + board_offset.x) / SPACING), round((light_pawn.position.z + board_offset.z) / SPACING))
		var dark_pawn_coords = Vector2i(round((dark_pawn.position.x + board_offset.x) / SPACING), round((dark_pawn.position.z + board_offset.z) / SPACING))
		if coords == light_pawn_coords or coords == dark_pawn_coords: return
		if coords == selected_source_tower_coords: return
		if not board_grid.has(coords) or board_grid[coords].is_empty() or board_grid[coords].back().is_in_group("obstacles"): return

		GameManager.save_state(capture_board_state())
		GameManager.debug_log("STEINMETZ-ZUG: 1 Stein von %s nach %s" % [_coords_to_notation(selected_source_tower_coords), _coords_to_notation(coords)])
		
		var source_stack = board_grid[selected_source_tower_coords]
		var target_stack = board_grid[coords]
		var piece_to_move = source_stack.pop_back()
		target_stack.push_back(piece_to_move)
		piece_to_move.coordinates = coords
		
		var top_piece = target_stack.back()
		if coords in marketplace_coords:
			top_piece.get_node("MeshInstance3D").set_surface_override_material(0, gold_material)
		elif top_piece.color == GameManager.Player.LIGHT:
			top_piece.get_node("MeshInstance3D").set_surface_override_material(0, light_material)
		else:
			top_piece.get_node("MeshInstance3D").set_surface_override_material(0, dark_material)
		
		for i in range(target_stack.size()):
			target_stack[i].position = Vector3(coords.x*SPACING, i*PIECE_HEIGHT, coords.y*SPACING) - self.board_offset
		
		update_tower_labels()
		move_sound_player.play()
		if source_stack.is_empty(): handle_board_split()
		
		GameManager.tower_has_moved = true
		_clear_visual_highlights(); _reset_selection_state()
		if not GameManager.pawn_has_moved:
			var current_pawn = light_pawn if GameManager.current_player == GameManager.Player.LIGHT else dark_pawn
			show_valid_pawn_moves(current_pawn)
		GameManager.action_completed()


# ============================================================================
# 9. Visuelles Feedback & Highlighting
# ============================================================================

func _clear_visual_highlights():
	# Entfernt Highlights von Türmen und Baufeldern
	for stack in board_grid.values():
		for piece in stack:
			if piece.has_node("HighlightMesh"): piece.get_node("HighlightMesh").hide()
	for foundation in foundation_grid.values():
		if foundation.has_node("HighlightMesh"): foundation.get_node("HighlightMesh").hide()
	
	# Highlights der Spielfiguren ebenfalls entfernen
	if is_instance_valid(light_pawn): light_pawn.get_node("HighlightMesh").hide()
	if is_instance_valid(dark_pawn): dark_pawn.get_node("HighlightMesh").hide()
	

func show_valid_pawn_moves(pawn_node: Node3D):
	_clear_visual_highlights()
	_update_turn_instructions()
	
	var pawn_coords_2d = Vector2i(round((pawn_node.position.x + board_offset.x) / SPACING), round((pawn_node.position.z + board_offset.z) / SPACING))
	selected_pawn = pawn_node
	
	var pawn_island = null
	if not islands.is_empty():
		for island in islands:
			if pawn_coords_2d in island:
				pawn_island = island
				break
				
	for target_coords in get_neighbor_coords(pawn_coords_2d):
		if pawn_island != null and not target_coords in pawn_island: continue
			
		if board_grid.has(target_coords) and not board_grid[target_coords].is_empty():
			var top_piece = board_grid[target_coords].back()
			if top_piece.color == pawn_node.player_color and not top_piece.is_in_group("obstacles"):
				top_piece.get_node("HighlightMesh").show()

func show_valid_source_towers():
	_clear_visual_highlights()
	_update_turn_instructions()

	var current_pawn = light_pawn if GameManager.current_player == GameManager.Player.LIGHT else dark_pawn
	var pawn_coords = Vector2i(round((current_pawn.position.x + board_offset.x) / SPACING), round((current_pawn.position.z + board_offset.z) / SPACING))
	var player_name = GameManager.get_player_name(current_pawn.player_color)
	GameManager.debug_log("SUCHE QUELL-TÜRME für Spieler %s bei %s" % [player_name, _coords_to_notation(pawn_coords)])
	
	var pawn_island = null
	if not islands.is_empty():
		for island in islands:
			if pawn_coords in island:
				pawn_island = island
				break
				
	var free_side_rule_active = (GameManager.game_variant == "arena")
	for target_coords in get_neighbor_coords(pawn_coords):
		if pawn_island != null and not target_coords in pawn_island: continue
			
		if board_grid.has(target_coords) and not board_grid[target_coords].is_empty():
			var top_piece = board_grid[target_coords].back()
			if top_piece.color == current_pawn.player_color and not top_piece.is_in_group("obstacles"):
				var is_on_marketplace = foundation_grid.has(target_coords) and foundation_grid[target_coords].is_in_group("marketplace")
				if free_side_rule_active and not has_free_side(target_coords) and not is_on_marketplace:
					continue
				top_piece.get_node("HighlightMesh").show()

func show_valid_target_towers(source_coords: Vector2i):
	# 1. Zuerst den neuen, korrekten UI-Zustand setzen.
	# Dies ist entscheidend und muss VOR _clear_visual_highlights passieren,
	# falls diese Funktion fälschlicherweise die UI zurücksetzen würde.
	steinmetz_button.hide()
	baumeister_button.hide()
	action_hint_label.text = "Wähle ZIEL für Turm"
	
	# 2. Dann die alten Highlights entfernen (diese Funktion ruft jetzt NICHT mehr
	# _update_turn_instructions auf und ist sicher).
	_clear_visual_highlights()
	
	var current_pawn = light_pawn if GameManager.current_player == GameManager.Player.LIGHT else dark_pawn
	var pawn_coords = Vector2i(round((current_pawn.position.x + board_offset.x) / SPACING), round((current_pawn.position.z + board_offset.z) / SPACING))
	GameManager.debug_log("SUCHE ZIEL-TÜRME. Figur bei %s, Quelle bei %s" % [_coords_to_notation(pawn_coords), _coords_to_notation(source_coords)])

	var pawn_island = null
	if not islands.is_empty():
		for island in islands:
			if pawn_coords in island:
				pawn_island = island
				break

	for target_coords in get_neighbor_coords(pawn_coords):
		if pawn_island != null and not target_coords in pawn_island: continue

		var other_pawn = dark_pawn if GameManager.current_player == GameManager.Player.LIGHT else light_pawn
		var other_pawn_coords = Vector2i(round((other_pawn.position.x + board_offset.x) / SPACING), round((other_pawn.position.z + board_offset.z) / SPACING))
		
		if target_coords == source_coords or target_coords == other_pawn_coords or target_coords == pawn_coords:
			continue
		
		var is_empty = not board_grid.has(target_coords) or board_grid[target_coords].is_empty()
		if is_empty:
			if GameManager.game_variant == "arena":
				if foundation_grid.has(target_coords):
					var foundation = foundation_grid[target_coords]
					if not foundation.is_in_group("obstacles"):
						foundation.get_node("HighlightMesh").show()
		else:
			var top_piece = board_grid[target_coords].back()
			if not top_piece.is_in_group("obstacles"):
				top_piece.get_node("HighlightMesh").show()

func _flash_invalid_move_indicator():
	if not is_instance_valid(invalid_move_overlay): return
	
	var tween = create_tween()
	invalid_move_overlay.modulate.a = 0.0
	invalid_move_overlay.show()
	tween.tween_property(invalid_move_overlay, "modulate:a", 0.5, 0.1)
	tween.tween_property(invalid_move_overlay, "modulate:a", 0.0, 0.2)
	tween.tween_callback(invalid_move_overlay.hide)


# ============================================================================
# 10. Zug-Validierung & Regel-Prüfungen
# ============================================================================

func _is_valid_source_tower(coords: Vector2i) -> bool:
	if not board_grid.has(coords) or board_grid[coords].is_empty():
		return false

	var top_piece = board_grid[coords].back()
	var current_pawn = light_pawn if GameManager.current_player == GameManager.Player.LIGHT else dark_pawn
	var pawn_coords = Vector2i(round((current_pawn.position.x + board_offset.x) / SPACING), round((current_pawn.position.z + board_offset.z) / SPACING))

	if top_piece.color == GameManager.current_player and coords in get_neighbor_coords(pawn_coords) and not top_piece.is_in_group("obstacles"):
		var free_side_rule_active = (GameManager.game_variant == "arena")
		var is_on_marketplace = foundation_grid.has(coords) and foundation_grid[coords].is_in_group("marketplace")
		
		if free_side_rule_active and not has_free_side(coords) and not is_on_marketplace:
			return false
		return true
	
	return false

func _is_valid_baumeister_source(coords: Vector2i) -> bool:
	if not board_grid.has(coords) or board_grid[coords].is_empty():
		return false

	var top_piece = board_grid[coords].back()
	var current_pawn = light_pawn if GameManager.current_player == GameManager.Player.LIGHT else dark_pawn
	var pawn_coords = Vector2i(round((current_pawn.position.x + board_offset.x) / SPACING), round((current_pawn.position.z + board_offset.z) / SPACING))

	if top_piece.color == GameManager.current_player and coords in get_neighbor_coords(pawn_coords) and not top_piece.is_in_group("obstacles"):
		return true
	
	return false

func _can_player_move_pawn(player: GameManager.Player) -> bool:
	var pawn = light_pawn if player == GameManager.Player.LIGHT else dark_pawn
	var pawn_coords = Vector2i(round((pawn.position.x + board_offset.x) / SPACING), round((pawn.position.z + board_offset.z) / SPACING))
	
	var pawn_island = null
	if not islands.is_empty():
		for island in islands:
			if pawn_coords in island:
				pawn_island = island
				break
	
	for target_coords in get_neighbor_coords(pawn_coords):
		if pawn_island != null and not target_coords in pawn_island:
			continue
			
		if board_grid.has(target_coords) and not board_grid[target_coords].is_empty():
			var top_piece = board_grid[target_coords].back()
			if top_piece.color == player and not top_piece.is_in_group("obstacles"):
				return true
	return false
	
# in board_3d.gd

func _can_player_move_tower(player: GameManager.Player) -> bool:
	# KORREKTUR: Die Variable "pawn" wird hier korrekt deklariert.
	var pawn = light_pawn if player == GameManager.Player.LIGHT else dark_pawn
	var pawn_coords = Vector2i(round((pawn.position.x + board_offset.x) / SPACING), round((pawn.position.z + board_offset.z) / SPACING))
	
	var pawn_island = null
	if not islands.is_empty():
		for island in islands:
			if pawn_coords in island:
				pawn_island = island
				break
	
	var possible_sources = []
	for source_coords in get_neighbor_coords(pawn_coords):
		if pawn_island != null and not source_coords in pawn_island:
			continue
		if _is_valid_source_tower(source_coords):
			possible_sources.append(source_coords)
			
	if possible_sources.is_empty(): return false

	for source in possible_sources:
		for target_coords in get_neighbor_coords(pawn_coords):
			if pawn_island != null and not target_coords in pawn_island: continue
			if target_coords == source: continue
			
			var other_pawn = dark_pawn if player == GameManager.Player.LIGHT else light_pawn
			var other_pawn_coords = Vector2i(round((other_pawn.position.x + board_offset.x) / SPACING), round((other_pawn.position.z + board_offset.z) / SPACING))
			if target_coords == other_pawn_coords or target_coords == pawn_coords: continue

			var is_empty = not board_grid.has(target_coords) or board_grid[target_coords].is_empty()
			
			if is_empty:
				if GameManager.game_variant == "arena":
					if foundation_grid.has(target_coords) and not foundation_grid[target_coords].is_in_group("obstacles"):
						return true
			else:

				if not board_grid[target_coords].back().is_in_group("obstacles"):
					return true
	return false
		
func can_player_perform_remaining_actions(player: GameManager.Player) -> bool:
	if not GameManager.pawn_has_moved and _can_player_move_pawn(player): return true
	if not GameManager.tower_has_moved and _can_player_move_tower(player): return true
	return false

func has_free_side(coords: Vector2i) -> bool:
	for neighbor_coords in get_neighbor_coords(coords):
		if not (foundation_grid.has(neighbor_coords) and board_grid.has(neighbor_coords) and not board_grid[neighbor_coords].is_empty()):
			return true
	return false


# ============================================================================
# 11. Spielende-Logik
# ============================================================================

func determine_winner():
	var light_towers = []
	var dark_towers = []
	for tower_stack in board_grid.values():
		if not tower_stack.is_empty():
			if not tower_stack.back().is_in_group("obstacles"):
				var height = tower_stack.size()
				if tower_stack.back().color == GameManager.Player.LIGHT:
					light_towers.append(height)
				else:
					dark_towers.append(height)
	light_towers.sort(); light_towers.reverse()
	dark_towers.sort(); dark_towers.reverse()
	
	var max_len = max(light_towers.size(), dark_towers.size())
	for i in range(max_len):
		var light_h = light_towers[i] if i < light_towers.size() else 0
		var dark_h = dark_towers[i] if i < dark_towers.size() else 0
		if light_h > dark_h: return GameManager.Player.LIGHT
		if dark_h > light_h: return GameManager.Player.DARK
	return null

func _check_for_repetition():
	var current_hash = _get_board_hash()
	GameManager.state_history.push_back(current_hash)
	var occurrences = 0
	for h in GameManager.state_history:
		if h == current_hash: occurrences += 1
	if occurrences >= 3:
		GameManager.debug_log("STALLMATE: Stellung wurde dreimal wiederholt. Spiel wird beendet.")
		GameManager.end_the_game(determine_winner())


# ============================================================================
# 12. Spielfeld-Aufbau & -Manipulation
# ============================================================================

func _calculate_layout_and_build_board() -> Array:
	# --- Vorheriges Brett sauber entfernen ---
	for i in range(get_child_count() - 1, -1, -1):
		var child = get_child(i)
		if child.is_in_group("board_element"):
			child.queue_free()
	board_grid.clear()
	foundation_grid.clear()
	marketplace_coords.clear()
	islands.clear()

	# --- Editor-sichere Variablen deklarieren ---
	var width: int
	var height: int
	var variant: String
	var use_marketplace: bool

	if Engine.is_editor_hint():
		# Im Editor: Nutze die lokalen Standardwerte des Skripts für die Vorschau
		width = self.board_width
		height = self.board_height
		variant = "classic"
		use_marketplace = false
	else:
		# Im Spiel: Nutze die Werte vom GameManager (aus dem Menü)
		width = GameManager.board_width
		height = GameManager.board_height
		variant = GameManager.game_variant
		use_marketplace = GameManager.rule_marktplatz_enabled
	
	# --- Marktplatz berechnen (Logik vollständig erhalten) ---
	if use_marketplace:
		var center_x1 = int(floor(width / 2.0))
		var center_x2 = center_x1 - 1
		var center_z = int(floor(height / 2.0))
		marketplace_coords = [
			Vector2i(center_x1, center_z), Vector2i(center_x2, center_z),
			Vector2i(center_x1, center_z - 1), Vector2i(center_x2, center_z - 1)
		]

	# --- Layout anpassen ---
	self.board_offset = Vector3((width - 1) * SPACING / 2.0, 0, (height - 1) * SPACING / 2.0)
	if is_instance_valid(camera_pivot):
		camera_pivot.position = self.board_offset
		
	# =======================================================================
	# KORREKTUR-LOGIK BEGINNT HIER
	# =======================================================================

	# PHASE 1: Erstelle das Fundament für ALLE Varianten
	# Erzeugt das Gitter aus (meist unsichtbaren) klickbaren Baufeldern
	for x in range(width):
		for z in range(height):
			_create_foundation_tile_at(Vector2i(x, z))

	# PHASE 2: Platziere die Start-Türme basierend auf der Variante
	var rock_positions = []
	match variant:
		"classic", "classic_large", "classic_free_side", "rocks":
			# Im Classic-Modus: Fülle das gesamte Fundament mit Türmen
			for x in range(width):
				for z in range(height):
					_create_tower_piece_at(Vector2i(x, z))
			
			if variant == "rocks" and not Engine.is_editor_hint():
				rock_positions = _place_obstacles_fairly()

		"arena":
			# Im Arena-Modus: Platziere nur die 3x3 Start-Insel
			var arena_pattern = [
				Vector2i(1,1), Vector2i(2,1), Vector2i(3,1),
				Vector2i(1,2), Vector2i(2,2), Vector2i(3,2),
				Vector2i(1,3), Vector2i(2,3), Vector2i(3,3)
			]
			for coord in arena_pattern:
				if coord.x < width and coord.y < height:
					_create_tower_piece_at(coord)

	# PHASE 3: Erstelle die Brett-Beschriftung
	_create_board_labels()
	
	return rock_positions

func _create_tower_piece_at(coords: Vector2i):
	var piece = tower_piece_scene.instantiate()
	add_child(piece)
	piece.add_to_group("board_element")
	piece.position = Vector3(coords.x * SPACING, 0, coords.y * SPACING) - self.board_offset
	piece.coordinates = coords
	
	var is_light_square = (coords.x + coords.y) % 2 == 0
	piece.color = GameManager.Player.LIGHT if is_light_square else GameManager.Player.DARK

	if coords in marketplace_coords:
		piece.get_node("MeshInstance3D").set_surface_override_material(0, gold_material)
	elif is_light_square:
		piece.get_node("MeshInstance3D").set_surface_override_material(0, light_material)
	else:
		piece.get_node("MeshInstance3D").set_surface_override_material(0, dark_material)
		
	board_grid[coords] = [piece]

func _create_foundation_tile_at(coords: Vector2i):
	var foundation = foundation_tile_scene.instantiate()
	add_child(foundation)
	foundation.add_to_group("board_element")
	foundation.position = Vector3(coords.x * SPACING, 0, coords.y * SPACING) - self.board_offset
	foundation.coordinates = coords
	foundation_grid[coords] = foundation
	
	if coords in marketplace_coords:
		foundation.add_to_group("marketplace")
		var mesh = foundation.get_node("NewBoxMesh")
		var mat = mesh.get_surface_override_material(0).duplicate() as StandardMaterial3D
		mat.albedo_color = Color.GOLD.lightened(0.3)
		mesh.set_surface_override_material(0, mat)
	
# Ersetze die komplette Funktion mit dieser bereinigten Version.
# Ersetze die komplette Funktion mit dieser verbesserten Version.
func _place_obstacles_fairly() -> Array:
	if obstacle_scenes.is_empty():
		push_warning("Keine Hindernis-Szenen im Inspektor zugewiesen!")
		return []

	var width = GameManager.board_width
	var height = GameManager.board_height
	var board_area = width * height
	
	# Bestimmt die Anzahl der Hindernis-Paare basierend auf der Brettgröße
	var num_obstacle_pairs = max(1, int(board_area / 25.0))

	# --- KORREKTUR: Nutze das GESAMTE Brett für mögliche Positionen ---
	var possible_coords = []
	for x in range(width):
		for y in range(height):
			possible_coords.append(Vector2i(x, y))
	
	# Die initialen Positionen der Figuren dürfen keine Hindernisse sein.
	# Wir holen uns die zentralen Felder, die von `place_pawns` bevorzugt werden.
	var center_point = Vector2((width - 1) / 2.0, (height - 1) / 2.0)
	possible_coords.sort_custom(func(a, b): return center_point.distance_to(a) < center_point.distance_to(b))
	if possible_coords.size() > 2:
		var pawn_pos_1 = possible_coords[0]
		var pawn_pos_2 = possible_coords[1]
		possible_coords.erase(pawn_pos_1)
		possible_coords.erase(pawn_pos_2)
		
	possible_coords.shuffle()
	
	var light_towers_to_remove = num_obstacle_pairs
	var dark_towers_to_remove = num_obstacle_pairs
	var placed_coords: Array[Vector2i] = []

	while (light_towers_to_remove > 0 or dark_towers_to_remove > 0) and not possible_coords.is_empty():
		var coord = possible_coords.pop_front()

		# --- NEU: Anti-Cluster-Prüfung ---
		# Prüfe, ob im direkten Umfeld bereits ein Hindernis platziert wurde.
		var is_cluster = false
		for neighbor in get_neighbor_coords(coord):
			if neighbor in placed_coords:
				is_cluster = true
				break
		if is_cluster:
			continue # Überspringe diese Koordinate, wenn sie ein Cluster bilden würde

		if board_grid.has(coord) and not board_grid[coord].is_empty():
			var tower_color = board_grid[coord].back().color
			
			if tower_color == GameManager.Player.LIGHT and light_towers_to_remove > 0:
				light_towers_to_remove -= 1
			elif tower_color == GameManager.Player.DARK and dark_towers_to_remove > 0:
				dark_towers_to_remove -= 1
			else:
				continue

			placed_coords.append(coord)
			
			for piece in board_grid[coord]: piece.queue_free()
			board_grid.erase(coord)
			if foundation_grid.has(coord):
				foundation_grid[coord].queue_free()
				foundation_grid.erase(coord)
			
			var random_obstacle_scene = obstacle_scenes.pick_random()
			if random_obstacle_scene == null: continue
			
			var obstacle = random_obstacle_scene.instantiate()
			add_child(obstacle)
			
			obstacle.position = Vector3(coord.x * SPACING, 0.0, coord.y * SPACING) - self.board_offset
			
	return placed_coords

func place_pawns():
	var width = GameManager.board_width
	var height = GameManager.board_height
	
	# Finde alle leeren, spielbaren Felder in der Nähe des Zentrums
	var center_point = Vector2((width - 1) / 2.0, (height - 1) / 2.0)
	var valid_start_positions = []
	for x in range(width):
		for y in range(height):
			var coord = Vector2i(x, y)
			# Ein Feld ist gültig, wenn ein Turm darauf steht (also kein Hindernis)
			if board_grid.has(coord) and not board_grid[coord].is_empty():
				var distance_to_center = center_point.distance_to(Vector2(x, y))
				valid_start_positions.append({"coord": coord, "distance": distance_to_center})
	
	# Sortiere die Liste, sodass die Felder mit der geringsten Distanz zum Zentrum vorne sind
	valid_start_positions.sort_custom(func(a, b): return a.distance < b.distance)
	
	# Wähle die zwei besten Positionen aus
	var light_pawn_pos = valid_start_positions[0].coord
	var dark_pawn_pos = valid_start_positions[1].coord
	
	if is_instance_valid(light_pawn): light_pawn.queue_free()
	if is_instance_valid(dark_pawn): dark_pawn.queue_free()

	light_pawn = pawn_scene.instantiate()
	add_child(light_pawn)
	light_pawn.player_color = GameManager.Player.LIGHT
	var light_mesh = light_pawn.get_node("MeshInstance3D")
	var light_material_instance = light_mesh.get_active_material(0).duplicate()
	light_material_instance.albedo_color = light_pawn_color
	light_material_instance.emission_enabled = true
	light_material_instance.emission = Color(0.2, 0.2, 0.2)
	light_mesh.material_override = light_material_instance

	dark_pawn = pawn_scene.instantiate()
	add_child(dark_pawn)
	dark_pawn.player_color = GameManager.Player.DARK
	var dark_mesh = dark_pawn.get_node("MeshInstance3D")
	var dark_material_instance = dark_mesh.get_active_material(0).duplicate()
	dark_material_instance.albedo_color = dark_pawn_color
	dark_mesh.material_override = dark_material_instance
	
	# Weise die finalen, sicheren Positionen zu
	var top_piece_light = board_grid[light_pawn_pos].back()
	if top_piece_light.color != GameManager.Player.LIGHT:
		# Wenn der beste Startplatz die falsche Farbe hat, tausche mit dem zweitbesten
		var temp = light_pawn_pos
		light_pawn_pos = dark_pawn_pos
		dark_pawn_pos = temp
	
	light_pawn.position = Vector3(light_pawn_pos.x * SPACING, board_grid[light_pawn_pos].size() * PIECE_HEIGHT, light_pawn_pos.y * SPACING) - self.board_offset
	dark_pawn.position = Vector3(dark_pawn_pos.x * SPACING, board_grid[dark_pawn_pos].size() * PIECE_HEIGHT, dark_pawn_pos.y * SPACING) - self.board_offset

func _create_board_labels():
	var width: int
	var height: int

	if Engine.is_editor_hint():
		# Im Editor: Nutze die lokalen Standardwerte des Skripts
		width = self.board_width
		height = self.board_height
	else:
		# Im Spiel: Nutze die Werte vom GameManager
		width = GameManager.board_width
		height = GameManager.board_height

	var label_height = 0.3
	var label_color = Color("#2C3E50")
	var outline_color = Color.WHITE
	var outline_size = 12
	var font_size = 90

	for i in range(width):
		var label = Label3D.new()
		label.add_to_group("board_element")
		label.text = char(65 + i)
		label.font_size = font_size
		label.modulate = label_color
		label.outline_modulate = outline_color
		label.outline_size = outline_size
		label.set_billboard_mode(BaseMaterial3D.BILLBOARD_ENABLED)
		add_child(label)
		label.position = Vector3(i * SPACING, label_height, height * SPACING) - self.board_offset

	for i in range(height):
		var label = Label3D.new()
		label.add_to_group("board_element")
		label.text = str(i + 1)
		label.font_size = font_size
		label.modulate = label_color
		label.outline_modulate = outline_color
		label.outline_size = outline_size
		label.set_billboard_mode(BaseMaterial3D.BILLBOARD_ENABLED)
		add_child(label)
		label.position = Vector3(width * SPACING, label_height, i * SPACING) - self.board_offset
		
func handle_board_split():
	var all_towers = []
	for coord in board_grid:
		if not board_grid.has(coord) or board_grid[coord].is_empty(): continue
		all_towers.append(coord)
	if all_towers.is_empty(): return

	var island1: Array[Vector2i] = _flood_fill(all_towers[0])
	if island1.size() == all_towers.size():
		islands.clear()
		return
	
	GameManager.debug_log("Spielfeld wurde geteilt!")
	var island2: Array[Vector2i] = []
	for tower_coord in all_towers:
		if not tower_coord in island1: island2.append(tower_coord)
	
	islands = [island1, island2]
	
	var light_pawn_coords = Vector2i(round((light_pawn.position.x + board_offset.x) / SPACING), round((light_pawn.position.z + board_offset.z) / SPACING))
	var dark_pawn_coords = Vector2i(round((dark_pawn.position.x + board_offset.x) / SPACING), round((dark_pawn.position.z + board_offset.z) / SPACING))
	var light_pawn_on_island1 = light_pawn_coords in island1
	var dark_pawn_on_island1 = dark_pawn_coords in island1
	
	if light_pawn_on_island1 == dark_pawn_on_island1:
		var island_to_remove: Array[Vector2i] = island2 if light_pawn_on_island1 else island1
		_animate_and_remove_towers(island_to_remove)
	else:
		GameManager.debug_log("Figuren auf getrennten Inseln. Spiel geht weiter.")
		
func _flood_fill(start_coord: Vector2i) -> Array[Vector2i]:
	var stack = [start_coord]; var visited = {start_coord: true}; var island_coords: Array[Vector2i] = [start_coord]
	while not stack.is_empty():
		var current_coord = stack.pop_back()
		for neighbor_coord in get_neighbor_coords(current_coord):
			if board_grid.has(neighbor_coord) and not board_grid[neighbor_coord].is_empty() and not visited.has(neighbor_coord):
				visited[neighbor_coord] = true
				stack.push_back(neighbor_coord)
				island_coords.append(neighbor_coord)
	return island_coords

func _animate_and_remove_towers(coords_to_remove: Array[Vector2i]):
	set_process_input(false)
	var tweens = []
	for coord in coords_to_remove:
		if board_grid.has(coord) and not board_grid[coord].is_empty():
			for piece in board_grid[coord]:
				var tween = create_tween()
				var mesh_instance = piece.get_node("MeshInstance3D")
				if not mesh_instance.material_override:
					mesh_instance.material_override = mesh_instance.get_active_material(0).duplicate()
				tween.tween_property(mesh_instance.material_override, "albedo_color:a", 0.0, 0.5)
				tweens.append(tween)
	if not tweens.is_empty(): await tweens.back().finished
	for coord in coords_to_remove:
		if board_grid.has(coord):
			for piece in board_grid[coord]: piece.queue_free()
			board_grid[coord].clear()
	set_process_input(true)

# ============================================================================
# 13. Zustandsspeicherung (Undo-System)
# ============================================================================

func capture_board_state() -> Dictionary:
	var state = {
		"board_grid_data": {},
		"light_pawn_pos": light_pawn.position,
		"dark_pawn_pos": dark_pawn.position,
		"current_player": GameManager.current_player,
		"pawn_has_moved": GameManager.pawn_has_moved,
		"tower_has_moved": GameManager.tower_has_moved,
		"light_baumeister_used": GameManager.light_baumeister_used,
		"dark_baumeister_used": GameManager.dark_baumeister_used
	}
	for coord in board_grid:
		var tower_data = [];
		for piece in board_grid[coord]:
			tower_data.push_back(piece.color)
		state.board_grid_data[coord] = tower_data

	# KORREKTUR: Speichert jetzt nicht nur die Koordinate, sondern auch den Szenen-Pfad
	var obstacle_data = []
	for child in get_children():
		if child.is_in_group("obstacles"):
			var obstacle_info = {
				"coord": Vector2i(round((child.position.x + board_offset.x) / SPACING), round((child.position.z + board_offset.z) / SPACING)),
				"scene_path": child.scene_file_path
			}
			obstacle_data.append(obstacle_info)
	state["obstacle_data"] = obstacle_data
	
	return state

func restore_board_state(state: Dictionary):
	# --- Vorheriges Spiel aufräumen ---
	for coord in board_grid:
		for piece in board_grid[coord]:
			if is_instance_valid(piece): piece.queue_free()
	board_grid.clear()
	
	# ACHTUNG: Wir löschen die Foundation-Tiles jetzt gezielter
	for coord in foundation_grid:
		var foundation = foundation_grid[coord]
		if is_instance_valid(foundation): foundation.queue_free()
	foundation_grid.clear()
	
	for child in get_children():
		if child.is_in_group("obstacles"):
			child.queue_free()
	
	# --- Brett-Layout wiederherstellen ---
	for x in range(GameManager.board_width):
		for z in range(GameManager.board_height):
			if not foundation_grid.has(Vector2i(x, z)):
				_create_foundation_tile_at(Vector2i(x, z))

	# --- Türme aus dem gespeicherten Zustand neu aufbauen ---
	for coord_variant in state.board_grid_data:
		var coord: Vector2i = coord_variant
		var tower_data = state.board_grid_data[coord]
		var new_stack = []
		for i in range(tower_data.size()):
			var piece_color = tower_data[i]
			var piece = tower_piece_scene.instantiate()
			add_child(piece)
			piece.position = Vector3(coord.x * SPACING, i * PIECE_HEIGHT, coord.y * SPACING) - self.board_offset
			piece.coordinates = coord
			piece.color = piece_color
			
			var material
			if coord in marketplace_coords:
				material = gold_material
			elif piece_color == GameManager.Player.LIGHT:
				material = light_material
			else:
				material = dark_material
			piece.get_node("MeshInstance3D").set_surface_override_material(0, material)
			
			new_stack.push_back(piece)
		if not new_stack.is_empty():
			board_grid[coord] = new_stack
			
	# KORREKTUR: Baut jetzt exakt die richtigen Hindernisse an den richtigen Positionen wieder auf
	if state.has("obstacle_data"):
		for obstacle_info in state.obstacle_data:
			var coord = obstacle_info.coord
			var scene_path = obstacle_info.scene_path
			
			if scene_path.is_empty(): continue # Sicherheitsabfrage
			
			var obstacle_scene = load(scene_path)
			var obstacle = obstacle_scene.instantiate()
			add_child(obstacle)
			obstacle.position = Vector3(coord.x * SPACING, 0.0, coord.y * SPACING) - self.board_offset
			
			if foundation_grid.has(coord):
				foundation_grid[coord].queue_free()
				foundation_grid.erase(coord)

	# --- Figuren und Spielstatus wiederherstellen ---
	light_pawn.position = state.light_pawn_pos
	dark_pawn.position = state.dark_pawn_pos
	
	GameManager.current_player = state.current_player
	GameManager.pawn_has_moved = state.pawn_has_moved
	GameManager.tower_has_moved = state.tower_has_moved
	if state.has("light_baumeister_used"):
		GameManager.light_baumeister_used = state.light_baumeister_used
	if state.has("dark_baumeister_used"):
		GameManager.dark_baumeister_used = state.dark_baumeister_used

	# --- UI aktualisieren ---
	update_tower_labels()
	_update_cursor_position()
	_start_new_turn()
	
# ============================================================================
# 14. Allgemeine Helfer-Funktionen
# ============================================================================

# Wandelt interne Vector2i-Koordinaten in Schach-Notation (z.B. "A1") um.
func _coords_to_notation(coords: Vector2i) -> String:
	var letter = char(65 + coords.x) # Wandelt 0->A, 1->B, etc. um
	var number = str(coords.y + 1)   # Wandelt 0->1, 1->2, etc. um
	return letter + number
	
func get_neighbor_coords(coords: Vector2i) -> Array[Vector2i]:
	var neighbors: Array[Vector2i] = []
	for offset in [Vector2i(-1,-1),Vector2i(0,-1),Vector2i(1,-1),Vector2i(-1,0),Vector2i(1,0),Vector2i(-1,1),Vector2i(0,1),Vector2i(1,1)]:
		neighbors.append(coords + offset)
	return neighbors

func update_tower_labels():
	# Geht durch JEDEN Turm auf dem Brett
	for coord in board_grid:
		var tower_stack = board_grid[coord]
		
		# Versteckt zuerst ALLE Labels in jedem Turm
		for piece in tower_stack:
			piece.get_node("Label3D").hide()
			piece.get_node("ColorLabel").hide()

		# Setzt dann die Labels für den jeweils OBERSTEN Stein neu
		if not tower_stack.is_empty():
			var top_piece = tower_stack.back()
			if not top_piece.is_in_group("obstacles"):
				# Logik für Höhen-Label (wie bisher)
				var height_label = top_piece.get_node("Label3D")
				height_label.text = str(tower_stack.size())
				height_label.modulate = Color.BLACK if top_piece.color == GameManager.Player.LIGHT else Color.WHITE
				height_label.show()

				# KORREKTUR: Die Logik wird hierher verschoben und korrigiert
				if coord in marketplace_coords:
					var color_label = top_piece.get_node("ColorLabel")
					color_label.text = "W" if top_piece.color == GameManager.Player.LIGHT else "S"
					color_label.show()

func _find_highest_tower(player: GameManager.Player) -> Vector3:
	var highest_tower_height = 0; var highest_tower_pos = Vector3.ZERO
	if player == null: return Vector3.ZERO
	for coord in board_grid:
		var tower = board_grid[coord]
		if not tower.is_empty() and tower.back().color == player and not tower.back().is_in_group("obstacles"):
			if tower.size() > highest_tower_height:
				highest_tower_height = tower.size()
				highest_tower_pos = tower.back().global_position
	return highest_tower_pos

func _get_board_hash() -> String:
	var pawn_positions = str(light_pawn.position, dark_pawn.position)
	var tower_heights = ""
	var sorted_coords = board_grid.keys()
	sorted_coords.sort()
	for coord in sorted_coords:
		if not board_grid[coord].is_empty() and not board_grid[coord].back().is_in_group("obstacles"):
			tower_heights += str(coord, board_grid[coord].size(), board_grid[coord].back().color)
	return pawn_positions + tower_heights

# Ersetze die komplette Funktion
func _print_start_log(rock_positions: Array = []):
	GameManager.debug_log("=============================================")
	GameManager.debug_log("          VOLTERRA - SPIEL GESTARTET         ")
	GameManager.debug_log("=============================================")
	GameManager.debug_log("Variante: " + GameManager.game_variant)
	GameManager.debug_log("Brett-Größe: %sx%s" % [GameManager.board_width, GameManager.board_height])
	GameManager.debug_log("Sonderregeln:")
	GameManager.debug_log("  - Steinmetz: " + str(GameManager.rule_steinmetz_enabled))
	GameManager.debug_log("  - Baumeister: " + str(GameManager.rule_baumeister_enabled))
	GameManager.debug_log("  - Marktplatz: " + str(GameManager.rule_marktplatz_enabled))
	
	if GameManager.rule_marktplatz_enabled:
		# Konvertiere jede Koordinate für die Ausgabe
		var notation_coords = []
		for coord in marketplace_coords:
			notation_coords.append(_coords_to_notation(coord))
		GameManager.debug_log("Marktplatz-Felder: " + str(notation_coords))
	
	if not rock_positions.is_empty():
		# Konvertiere jede Koordinate für die Ausgabe
		var notation_coords = []
		for coord in rock_positions:
			notation_coords.append(_coords_to_notation(coord))
		GameManager.debug_log("Felsen-Positionen: " + str(notation_coords))
	
	GameManager.debug_log("=============================================")
	
	
func _update_cursor_position():
	var target_pawn = light_pawn if GameManager.current_player == GameManager.Player.LIGHT else dark_pawn
	if is_instance_valid(target_pawn):
		var cursor_y_pos = target_pawn.position.y + PAWN_HEIGHT + 0.1
		cursor.position = Vector3(target_pawn.position.x, cursor_y_pos, target_pawn.position.z)
		cursor.show()
	else:
		cursor.hide()

# in board_3d.gd

func _apply_lighting_preset(index: int):
	if not is_instance_valid(directional_light) or not is_instance_valid(world_environment):
		return

	var preset = lighting_presets[index]
	GameManager.debug_log("Licht-Preset wird geladen: " + preset.name)

	# Sonnenlicht anpassen
	directional_light.light_color = preset.light_color
	directional_light.rotation_degrees.x = preset.light_rotation_x
	directional_light.shadow_blur = preset.shadow_blur

	# Umgebung anpassen
	var env = world_environment.environment
	if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		env.sky.sky_material.sky_top_color = preset.sky_top_color
		env.sky.sky_material.sky_horizon_color = preset.sky_horizon_color
	
	env.ambient_light_color = preset.ambient_color
	env.ambient_light_energy = preset.ambient_energy
	
	env.glow_enabled = preset.glow_enabled
	if preset.glow_enabled:
		env.glow_intensity = preset.glow_intensity
		env.glow_strength = preset.glow_strength
		
# in board_3d.gd

# Die Funktion, die auf Klicks reagiert
# In board_3d.gd
func _unhandled_input(event: InputEvent):
	if Engine.is_editor_hint(): return

	if event.is_action_pressed("camera_focus"):
		var mouse_pos = get_viewport().get_mouse_position()
		var result = _raycast_from_camera(mouse_pos)
		if result:
			if is_instance_valid(camera_controller):
				camera_controller.focus_on_point(result.position)
								
# Eine Helfer-Funktion für den Raycast
func _raycast_from_camera(screen_position):
	var camera = get_viewport().get_camera_3d()
	if not camera: return {}

	var from = camera.project_ray_origin(screen_position)
	var to = from + camera.project_ray_normal(screen_position) * 1000
	var query = PhysicsRayQueryParameters3D.create(from, to)
	var result = get_world_3d().direct_space_state.intersect_ray(query)
	return result
	
