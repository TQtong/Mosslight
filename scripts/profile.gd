extends RefCounted
## Campaign saves are separate from audio/preferences and written through a temp file.
const DEFAULT_PATH := "user://journey.json"
var path: String = DEFAULT_PATH
var data: Dictionary = {}
var recovered_backup: bool = false
var used_defaults_after_damage: bool = false
var last_error: Error = OK

func _init(save_path: String = DEFAULT_PATH) -> void:
	path = save_path
	reset_defaults()

func reset_defaults() -> void:
	data = {"version": 1, "unlocked": 0, "last_level": 0, "levels": {}, "active_run": {}, "seen_chapters": []}

func load_profile(level_count: int) -> void:
	reset_defaults()
	recovered_backup = false
	used_defaults_after_damage = false
	var loaded := _read_valid(path, level_count)
	if loaded.is_empty():
		loaded = _read_valid(path + ".bak", level_count)
		recovered_backup = not loaded.is_empty()
	if not loaded.is_empty():
		data = loaded
	else:
		used_defaults_after_damage=FileAccess.file_exists(path) or FileAccess.file_exists(path+".bak")

func _read_valid(file_path: String, level_count: int) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(file_path))!=OK: return {}
	var result = parser.data
	if not result is Dictionary or int(result.get("version", 0)) != 1:
		return {}
	if not result.get("levels") is Dictionary or not result.get("active_run") is Dictionary:
		return {}
	if not result.get("unlocked") is float and not result.get("unlocked") is int:
		return {}
	if not _integer(result["unlocked"],0,1000) or not _integer(result.get("last_level",0),0,1000): return {}
	result["unlocked"] = clampi(int(result["unlocked"]), 0, level_count - 1)
	result["last_level"] = clampi(int(result.get("last_level", 0)), 0, int(result["unlocked"]))
	for key in result["levels"]:
		if not str(key).is_valid_int(): return {}
		var record = result["levels"][key]
		if not record is Dictionary: return {}
		if not record.get("completed",false) is bool: return {}
		if not _number(record.get("best_time",0)) or float(record.get("best_time",0))<0: return {}
		if not _number(record.get("assist_time",0)) or float(record.get("assist_time",0))<0: return {}
		if not _integer(record.get("coins",0),0,100000) or not _integer(record.get("relics",0),0,3): return {}
		if not record.get("relic_ids",[]) is Array: return {}
		for value in record.get("relic_ids",[]):
			if not _integer(value,0,2): return {}
		if record.has("relic_ids"):
			record["relic_ids"]=_canonical_ids(record["relic_ids"])
			record["relics"]=record["relic_ids"].size()
	var seen: Array=[]
	if result.has("seen_chapters"):
		if not result["seen_chapters"] is Array: return {}
		for value in result["seen_chapters"]:
			if not _integer(value,0,2): return {}
		seen=_canonical_ids(result["seen_chapters"])
	else:
		# Existing completed chapters do not interrupt a returning player's journey.
		for key in result["levels"]:
			var chapter: int=int(key)/4
			if chapter in [0,1,2] and result["levels"][key].get("completed",false) and not chapter in seen: seen.append(chapter)
	result["seen_chapters"]=seen
	var active: Dictionary = result["active_run"]
	if not active.is_empty():
		if not active.get("coins") is Array or not active.get("relics") is Array or not active.get("spawn") is Array:
			result["active_run"] = {}
		elif active["spawn"].size() != 2 or not _integer(active.get("level",-1),0,result["unlocked"]):
			result["active_run"] = {}
		elif not _number(active["spawn"][0]) or not _number(active["spawn"][1]) or not _number(active.get("elapsed",0)) or not _integer(active.get("deaths",0),0,1000000) or not _integer(active.get("checkpoint",-1),-1,100):
			result["active_run"] = {}
		elif not active.get("assisted",false) is bool:
			result["active_run"]={}
		else:
			for value in active["coins"]:
				if not _integer(value,0,10000): result["active_run"]={}; break
			for value in active["relics"]:
				if not _integer(value,0,2): result["active_run"]={}; break
			if not result["active_run"].is_empty():
				active["coins"]=_canonical_ids(active["coins"])
				active["relics"]=_canonical_ids(active["relics"])
	return result

func save_profile() -> Error:
	last_error = _write_profile()
	return last_error

func _write_profile() -> Error:
	var temp := path + ".tmp"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data, "\t"))
	file.flush()
	file.close()
	# Keep a known-valid previous generation rather than backing up corrupt data.
	if FileAccess.file_exists(path) and not _read_valid(path, 1000).is_empty():
		var backup_error := DirAccess.copy_absolute(path, path + ".bak")
		if backup_error != OK:
			return backup_error
	return DirAccess.rename_absolute(temp, path)

func _number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

func _integer(value: Variant, low: int, high: int) -> bool:
	return _number(value) and float(value)>=low and float(value)<=high and is_equal_approx(float(value),roundf(float(value)))

func _canonical_ids(values: Array) -> Array:
	var ids: Array=[]
	for value in values:
		var id:=int(value)
		if not id in ids: ids.append(id)
	return ids

func begin_level(index: int) -> void:
	data["last_level"] = index
	data["active_run"] = {}
	save_profile()

func checkpoint(index: int, at: Vector2, coin_ids: Array, relic_ids: Array, elapsed: float, deaths: int, checkpoint_index: int, assisted: bool = false) -> void:
	data["last_level"] = index
	data["active_run"] = {"level": index, "spawn": [at.x, at.y], "coins": coin_ids.duplicate(), "relics": relic_ids.duplicate(), "elapsed": elapsed, "deaths": deaths, "checkpoint": checkpoint_index,"assisted":assisted}
	save_profile()

func complete(index: int, elapsed: float, coins: int, relics: int, level_count: int, assisted: bool = false) -> bool:
	var record := level_record(index)
	var time_key: String="assist_time" if assisted else "best_time"
	var is_best := float(record.get(time_key, 0)) <= 0 or elapsed < float(record[time_key])
	record["completed"] = true
	if is_best:
		record[time_key] = elapsed
	record["coins"] = maxi(coins, int(record.get("coins", 0)))
	record["relics"] = maxi(relics, int(record.get("relics", 0)))
	data["levels"][str(index)] = record
	data["unlocked"] = maxi(int(data["unlocked"]), mini(index + 1, level_count - 1))
	data["last_level"] = mini(index + 1, level_count - 1)
	data["active_run"] = {}
	save_profile()
	return is_best

func level_record(index: int) -> Dictionary:
	var record = data["levels"].get(str(index), {})
	return record.duplicate(true) if record is Dictionary else {}

func record_relic(index: int, relic_id: int) -> void:
	if relic_id<0 or relic_id>2: return
	var record:=level_record(index)
	var ids: Array=record.get("relic_ids",[])
	if not relic_id in ids: ids.append(relic_id)
	record["relic_ids"]=ids
	record["relics"]=maxi(int(record.get("relics",0)),ids.size())
	data["levels"][str(index)]=record
	save_profile()

func has_progress() -> bool:
	return not data["levels"].is_empty() or not data["active_run"].is_empty()

func finished(level_count: int) -> bool:
	return bool(level_record(level_count - 1).get("completed", false))

func chapter_seen(chapter: int) -> bool:
	return chapter in data["seen_chapters"]

func remember_chapter(chapter: int) -> void:
	if chapter<0 or chapter>2 or chapter_seen(chapter): return
	data["seen_chapters"].append(chapter)
	save_profile()

func lightseed_count() -> int:
	var total:=0
	for key in data["levels"]:
		if str(key).is_valid_int() and int(key)>=0 and int(key)<12:
			total+=clampi(int(data["levels"][key].get("relics",0)),0,3)
	return total
