extends Node3D

# Dieses Skript wird ausgeführt, sobald die Szene dem Spiel hinzugefügt wird.
func _ready():
	# Rufe die Funktion auf, die alle Kind-Nodes durchsucht.
	_fix_materials_in_children(self)

# Diese Funktion durchsucht rekursiv alle Kind-Nodes nach Materialien.
func _fix_materials_in_children(node):
	# Prüfen, ob der aktuelle Node ein Mesh ist
	if node is MeshInstance3D:
		# Gehe durch alle Materialien dieses Meshes
		for i in range(node.get_surface_override_material_count()):
			var mat = node.get_surface_override_material(i)
			if mat is StandardMaterial3D:
				# Stelle sicher, dass das Material einzigartig ist, bevor wir es ändern
				if not mat.is_local_to_scene():
					mat = mat.duplicate()
					node.set_surface_override_material(i, mat)
				
				# DEAKTIVIERE Back Lighting
				mat.backlight_enabled = false

	# Wiederhole den Prozess für alle Kinder dieses Nodes
	for child in node.get_children():
		_fix_materials_in_children(child)
