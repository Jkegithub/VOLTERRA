@tool
extends Node3D

@export var orbit_sensitivity: float = 0.005
@export var pan_speed: float = 0.01
@export var zoom_speed: float = 0.1
@export var min_zoom: float = 2.0
@export var max_zoom: float = 20.0

@onready var camera: Camera3D = $Camera3D

var is_orbiting: bool = false
var is_panning: bool = false
var pivot_point: Vector3 = Vector3.ZERO
var start_transform: Transform3D

func _ready():
	start_transform = self.transform

func _unhandled_input(event: InputEvent):
	if Engine.is_editor_hint(): return

	# --- Input-Events abfangen ---
	if event.is_action("camera_orbit"):
		is_orbiting = event.is_pressed()
	if event.is_action("camera_pan"):
		is_panning = event.is_pressed()

	# --- Kamera-Bewegung ausführen ---
	if event is InputEventMouseMotion:
		if is_orbiting:
			_orbit(event.relative)
		if is_panning:
			_pan(event.relative)

	# --- Kamera-Zoom (NEU: mit Mausrad) ---
	if event.is_action_pressed("zoom_in"):
		_zoom(1 - zoom_speed)
	if event.is_action_pressed("zoom_out"):
		_zoom(1 + zoom_speed)
		
	# --- Kamera-Reset ---
	if event.is_action_pressed("camera_reset"):
		self.transform = start_transform
		camera.rotation.x = 0

func _orbit(relative_motion: Vector2):
	translate(pivot_point)
	rotate_y(-relative_motion.x * orbit_sensitivity)
	camera.rotate_x(-relative_motion.y * orbit_sensitivity)
	camera.rotation.x = clamp(camera.rotation.x, -1.4, 0)
	translate(-pivot_point)

func _pan(relative_motion: Vector2):
	# KORREKTUR: Korrektes 3D-Panning
	var move_vec = (transform.basis.x * -relative_motion.x + transform.basis.y * relative_motion.y) * pan_speed
	self.position += move_vec

func _zoom(amount: float):
	# Stellt sicher, dass wir die richtige Zoom-Methode verwenden
	if camera.projection == Camera3D.PROJECTION_PERSPECTIVE:
		camera.position.z = clamp(camera.position.z * amount, min_zoom, max_zoom)
	else: # PROJECTION_ORTHOGONAL
		camera.size = clamp(camera.size * amount, min_zoom, max_zoom)

func focus_on_point(new_pivot: Vector3):
	pivot_point = to_local(new_pivot)
