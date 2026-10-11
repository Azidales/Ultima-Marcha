extends RefCounted

# KEEP_WIDTH lets portrait viewports reveal more track vertically, while
# widening the world-space framing in landscape. Does not modify race physics.
static func aspect(view_size: Vector2) -> float:
	return maxf(view_size.x / maxf(view_size.y, 1.0), 0.2)

static func world_width(view_size: Vector2) -> float:
	var t: float = clampf((aspect(view_size) - 0.6) / 1.1, 0.0, 1.0)
	return lerpf(28.0, 46.0, t)

static func offset(view_size: Vector2) -> Vector3:
	var t: float = clampf((aspect(view_size) - 0.6) / 1.1, 0.0, 1.0)
	return Vector3(lerpf(16.0, 27.0, t), 34.0, lerpf(36.0, 41.0, t))

static func look_ahead(view_size: Vector2) -> float:
	return 7.0 if aspect(view_size) < 1.0 else 9.0

static func focus_distance(player_distance: float, rival_distance: float) -> float:
	var separation: float = absf(player_distance - rival_distance)
	# Keep both cars framed in duels; favor the player's car in large gaps.
	var player_priority: float = clampf((separation - 20.0) / 25.0, 0.0, 1.0)
	return lerpf((player_distance + rival_distance) * 0.5, player_distance, player_priority)
