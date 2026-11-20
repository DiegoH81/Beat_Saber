extends Control

const SPARK_INTERVAL := 0.0055

var tint := Color(0.64, 0.24, 1.0)

class Spark:
	var position: Vector2
	var velocity: Vector2
	var life: float
	var duration: float

var _rng := RandomNumberGenerator.new()
var _sparks: Array[Spark] = []
var _emission_time := 0.0
@onready var _bar := get_parent() as ProgressBar

func _ready() -> void:
	visibility_changed.connect(_update_visibility)
	_update_visibility()

func _update_visibility() -> void:
	set_process(is_visible_in_tree())
	_sparks.clear()
	_emission_time = 0.0
	queue_redraw()

func _process(delta: float) -> void:
	for index in range(_sparks.size() - 1, -1, -1):
		var spark := _sparks[index]
		spark.life -= delta
		if spark.life <= 0.0:
			_sparks.remove_at(index)
			continue
		spark.velocity.y += 230.0 * delta
		spark.position += spark.velocity * delta

	_emission_time = minf(_emission_time + delta, 0.08)
	while _emission_time >= SPARK_INTERVAL:
		_emission_time -= SPARK_INTERVAL
		var spark := Spark.new()
		spark.position = Vector2(_cut_x(), _rng.randf_range(4.0, size.y - 4.0))
		spark.velocity = Vector2(_rng.randf_range(55.0, 190.0), _rng.randf_range(-140.0, 70.0))
		spark.duration = _rng.randf_range(0.19, 0.36)
		spark.life = spark.duration
		_sparks.append(spark)
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(_bar) or not is_visible_in_tree():
		return
	var x := _cut_x()
	var top := Vector2(x, 2.0)
	var bottom := Vector2(x, size.y - 2.0)
	draw_line(top, bottom, Color(tint, 0.13), 20.0, true)
	draw_line(top, bottom, Color(tint, 0.36), 10.0, true)
	draw_line(top, bottom, Color(tint.lightened(0.28), 0.9), 4.0, true)
	draw_line(top, bottom, tint.lightened(0.82), 1.5, true)

	for spark in _sparks:
		var alpha := spark.life / spark.duration
		var tail := spark.position - spark.velocity * 0.037
		draw_line(tail, spark.position, Color(tint, alpha * 0.14), 14.0, true)
		draw_line(tail, spark.position, Color(tint, alpha * 0.34), 7.0, true)
		draw_line(tail, spark.position, Color(tint.lightened(0.55), alpha), 2.5, true)

func _cut_x() -> float:
	return roundf(_bar.ratio * size.x)
