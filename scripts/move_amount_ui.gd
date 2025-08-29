extends Control

signal move_one_piece
signal move_two_pieces

func _on_button_1_pressed():
	# KORREKTUR: Verständlicher Log-Text und Umstellung auf debug_log
	GameManager.debug_log("UI-INPUT: Spieler wählt '1 Stein versetzen'.")
	emit_signal("move_one_piece")
	hide() # Verstecke die UI nach der Auswahl

func _on_button_2_pressed():
	# KORREKTUR: Verständlicher Log-Text und Umstellung auf debug_log
	GameManager.debug_log("UI-INPUT: Spieler wählt '2 Steine versetzen'.")
	emit_signal("move_two_pieces")
	hide() # Verstecke die UI nach der Auswahl
