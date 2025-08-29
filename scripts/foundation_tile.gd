@tool
extends Node3D

var coordinates: Vector2i


func _on_static_body_3d_input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.is_pressed():
		var board = get_tree().get_root().get_node("Game/BOARD")
		if is_instance_valid(board):
			# KORREKTUR: Ruft die richtige Funktion für ein Baufeld auf
			board.on_foundation_tile_clicked(self.coordinates)
			get_viewport().set_input_as_handled()
