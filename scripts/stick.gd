extends RefCounted
## Dónde se clava una flecha: el piso, las paredes, los portones y las plataformas (estas solo si la
## flecha les cae desde arriba). Lo usan la flecha de Pip y la del esqueleto arquero.

const MASK := 3  # capa 1 (piso, paredes y portones) y capa 2 (plataformas de un solo lado)
const GATE_TOP := 82.0  # arriba del portón está el muro del arco


## Tira un rayo de `from` a `to` y devuelve el choque ({position, normal, collider...}) o {} si no hay.
static func cast(node: Node2D, from: Vector2, to: Vector2) -> Dictionary:
	if from.is_equal_approx(to):
		return {}
	var space := node.get_world_2d().direct_space_state
	var q := PhysicsRayQueryParameters2D.create(from, to, MASK)
	q.collide_with_areas = false
	var skip: Array[RID] = []
	for i in 4:
		q.exclude = skip
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return {}
		var body = hit["collider"]
		var n: Vector2 = hit["normal"]
		# las plataformas se atraviesan desde abajo y de costado: solo frenan lo que viene cayendo
		if body is CollisionObject2D and not body.get_collision_layer_value(1):
			if n.y > -0.5 or to.y <= from.y:
				skip.append(hit["rid"])
				continue
		return hit
	return {}


## Cuánto subió el portón en el que quedó clavada la flecha (0 si no es un portón).
static func gate_lift(body: Object) -> float:
	if body == null or not is_instance_valid(body) or not body.has_meta("gate_art"):
		return 0.0
	var art: Object = body.get_meta("gate_art")
	if art == null or not is_instance_valid(art):
		return 0.0
	return roundf(float(art.get("open")) * 44.0)


## Polvo y astillas donde pega: tierra en el piso, piedra en las paredes, chispas en el portón.
static func dust(parent: Node, at: Vector2, normal: Vector2, body: Object) -> void:
	var cols: Array = [Pal.SS, Pal.S, Color("c8b090")]
	if body != null and body.has_meta("gate_art"):
		cols = [Pal.Y, Pal.W, Pal.S]
	Fx.burst(parent, at + normal, 4, cols, 35.0, 20.0, 0.3, 160.0)
