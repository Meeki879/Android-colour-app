extends Node
## Screen router: Home <-> Canvas, Home <-> Grown-ups.
## Android Back is ignored on the canvas so a child cannot leave by accident.

const HomeScreen := preload("res://scenes/home/home.gd")
const CanvasScreen := preload("res://scenes/canvas/canvas.gd")
const GrownupsScreen := preload("res://scenes/grownups/grownups.gd")

enum Screen { HOME, CANVAS, GROWNUPS }

var _screen := Screen.HOME
var _current: Node


func _ready() -> void:
	_show_home()


func _notification(what: int) -> void:
	if what != NOTIFICATION_WM_GO_BACK_REQUEST:
		return
	match _screen:
		Screen.HOME:
			get_tree().quit()
		Screen.GROWNUPS:
			_show_home()
		Screen.CANVAS:
			pass


func _show_home() -> void:
	var home := HomeScreen.new()
	home.play_requested.connect(_show_canvas)
	home.grownups_requested.connect(_show_grownups)
	_swap(home, Screen.HOME)


func _show_canvas() -> void:
	var canvas := CanvasScreen.new()
	canvas.exit_requested.connect(_show_home)
	_swap(canvas, Screen.CANVAS)


func _show_grownups() -> void:
	var grownups := GrownupsScreen.new()
	grownups.back_requested.connect(_show_home)
	grownups.play_requested.connect(_show_canvas)
	_swap(grownups, Screen.GROWNUPS)


func _swap(node: Node, screen: Screen) -> void:
	if _current:
		_current.queue_free()
	_current = node
	_screen = screen
	add_child(node)
