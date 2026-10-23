extends Node
## Os arquivos de verdade (§7): o que a história deixa fora do jogo, no disco de quem joga.
## - ciclo_346.sav, ao lado do save, quando o flag "old_save" liga (flash 2). Aparece em
##   "Carregar", e carregar mostra a memória do ciclo 346 (Game.play_memory);
## - leia_me_se_lembrar.txt, na pasta do jogo, quando o flag "letter_left" liga (R1). É a carta
##   de Ari para Ari e termina com a senha do Final 3 (Story.password).
## Os textos ficam em StoryBeats. Se o arquivo sumir (alguém apagou), volta ao carregar o save.

const OLD_SAVE_PATH := "user://ciclo_346.sav"
const OLD_SAVE_FLAG := &"old_save"
const LETTER_NAME := "leia_me_se_lembrar.txt"
const LETTER_FLAG := &"letter_left"


func _ready() -> void:
	Story.flag_changed.connect(func(flag: StringName, value: bool) -> void:
		if value and flag in [OLD_SAVE_FLAG, LETTER_FLAG]:
			ensure())


## Escreve o que a história já liberou e ainda não está no disco.
func ensure() -> void:
	if Story.has_flag(OLD_SAVE_FLAG) and not has_old_save():
		_write(OLD_SAVE_PATH, StoryBeats.OLD_SAVE % _garbage())
	if Story.has_flag(LETTER_FLAG) and not has_letter():
		if _write(letter_path(), StoryBeats.LETTER % [Story.password(), Story.cycle]):
			print("[MetaFiles] Carta deixada em %s" % letter_path())


func has_old_save() -> bool:
	return FileAccess.file_exists(OLD_SAVE_PATH)


func has_letter() -> bool:
	return FileAccess.file_exists(letter_path())


func letter_path() -> String:
	return game_folder().path_join(LETTER_NAME)


## A pasta do jogo: a do executável exportado, se der para escrever nela; senão (no editor, ou
## sem permissão) a pasta de dados do usuário.
func game_folder() -> String:
	if not OS.has_feature("editor"):
		var folder := OS.get_executable_path().get_base_dir()
		if _writable(folder):
			return folder
	return ProjectSettings.globalize_path("user://")


## Abre a pasta do jogo no gerenciador de arquivos, com a carta selecionada se ela existir.
func open_game_folder() -> void:
	if has_letter():
		OS.shell_show_in_file_manager(letter_path())
	else:
		OS.shell_open(game_folder())


## Apaga os dois arquivos (os roteiros de teste usam).
func remove_all() -> void:
	for path: String in [ProjectSettings.globalize_path(OLD_SAVE_PATH), letter_path()]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)


func _write(path: String, text: String) -> bool:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("MetaFiles: não deu para escrever %s (%s)." % [path, error_string(FileAccess.get_open_error())])
		return false
	file.store_string(text)
	return true


func _writable(folder: String) -> bool:
	var probe := folder.path_join(".toca")
	var file := FileAccess.open(probe, FileAccess.WRITE)
	if file == null:
		return false
	file.close()
	DirAccess.remove_absolute(probe)
	return true


## O fim do save antigo, corrompido: a palavra se repetindo até virar lixo.
func _garbage() -> String:
	var rng := RandomNumberGenerator.new()
	rng.seed = 346
	var text := "DA"
	for i in 40:
		text += "\", \"ACORDA" if rng.randf() < 0.6 else "AC0R░D"
	for i in 400:
		text += char(rng.randi_range(0x21, 0x7e) if rng.randf() < 0.7 else rng.randi_range(0xa1, 0x24f))
	return text
