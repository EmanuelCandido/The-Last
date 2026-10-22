extends ColorRect
## Tela preta que escurece ou clareia sob pedido (Events.screen_fade_requested).

var _tween: Tween


func _ready() -> void:
	modulate.a = 0.0
	Events.screen_fade_requested.connect(_on_fade_requested)


func _on_fade_requested(alpha: float, duration: float) -> void:
	if _tween != null:
		_tween.kill()
	if duration <= 0.0:
		modulate.a = alpha
		return
	_tween = create_tween()
	_tween.tween_property(self, "modulate:a", alpha, duration).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
