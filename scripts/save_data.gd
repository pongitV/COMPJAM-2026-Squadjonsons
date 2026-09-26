class_name SaveData
extends RefCounted
## Recorde salvo entre partidas (lido pelo menu principal e pelo jogo).

const PATH := "user://save.cfg"


static func best_score() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return 0
	return int(cfg.get_value("stats", "best_score", 0))


static func save_best_score(value: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(PATH)
	cfg.set_value("stats", "best_score", value)
	cfg.save(PATH)
