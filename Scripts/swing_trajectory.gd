class_name SwingTrajectory
extends RefCounted
## Cubic Bezier-траектория переноса ступни.
##
## Работает в локальной системе координат бедра (hip frame):
##   Y — вверх (противоположно гравитации),
##   Z — вперёд по корпусу,
##   X — вправо.
##
## Траектория: P0 (старт на земле) → подъём по дуге → P3 (конец на земле).
## Контрольные точки P1, P2 подняты на lift_height и смещены вдоль оси переноса
## на control_offset — это задаёт форму дуги и "наклон" траектории вперёд.

var start_pos: Vector3
var end_pos: Vector3
var lift_height: float
var control_offset: float

## Конструктор.
## [param s] — стартовая позиция ступни (обычно = текущая позиция).
## [param e] — целевая позиция ступни (куда переставить).
## [param h] — высота подъёма над землёй в середине траектории (м).
## [param offset] — смещение контрольных точек вдоль направления переноса (м).
##                  0 = симметричная дуга, >0 = дуга "наклонена вперёд".
func _init(s: Vector3, e: Vector3, h: float, offset: float = 0.0) -> void:
	start_pos = s
	end_pos = e
	lift_height = h
	control_offset = offset

## Позиция ступни в момент t ∈ [0, 1].
## t=0 — старт, t=1 — конец. За пределами [0,1] — clamp.
func get_position(t: float) -> Vector3:
	t = clampf(t, 0.0, 1.0)
	var u := 1.0 - t
	var p1 := _control_point(start_pos, 1.0)
	var p2 := _control_point(end_pos, -1.0)
	# B(t) = u³P0 + 3u²tP1 + 3ut²P2 + t³P3
	return (u * u * u) * start_pos \
		+ 3.0 * (u * u) * t * p1 \
		+ 3.0 * u * (t * t) * p2 \
		+ (t * t * t) * end_pos

## Скорость ступни (производная B'(t)) в м/с, нормированная на единичную длительность.
## Для реальной скорости умножьте на 1/duration.
func get_velocity_normalized(t: float) -> Vector3:
	t = clampf(t, 0.0, 1.0)
	var u := 1.0 - t
	var p1 := _control_point(start_pos, 1.0)
	var p2 := _control_point(end_pos, -1.0)
	# B'(t) = 3u²(P1-P0) + 6ut(P2-P1) + 3t²(P3-P2)
	return 3.0 * (u * u) * (p1 - start_pos) \
		+ 6.0 * u * t * (p2 - p1) \
		+ 3.0 * (t * t) * (end_pos - p2)

## Высота траектории в середине (t=0.5). Полезно для отладки.
func get_mid_height() -> float:
	return get_position(0.5).y

## Внутренний метод: контрольная точка.
## [param base] — базовая точка (старт или конец).
## [param sign] — +1 для P1 (смещение вперёд от старта), -1 для P2 (назад от конца).
func _control_point(base: Vector3, sign: float) -> Vector3:
	var direction := (end_pos - start_pos).normalized()
	return base + Vector3(0, lift_height, 0) + direction * control_offset * sign
