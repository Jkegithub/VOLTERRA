# ============================================================================
# FINAL SCRIPT (COMPLETE V4) - pawn.gd (Restored with Area3D logic)
# ============================================================================
extends Node3D

var player_color: GameManager.Player

# KORREKTUR: Diese Funktion wird vom Area3D-Signal aufgerufen
func _on_area_3d_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var board = get_tree().get_root().get_node("Game/BOARD")
		if is_instance_valid(board):
			board.on_pawn_clicked(self)
			get_viewport().set_input_as_handled()
