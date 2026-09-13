extends RefCounted
## Item database: id -> display name + slot color. Add new items here.

const ITEMS := {
	"flint": {"name": "Flint Shard", "color": Color(0.55, 0.55, 0.58)},
	"stick": {"name": "Driftwood Stick", "color": Color(0.62, 0.45, 0.25)},
	"vine": {"name": "Vine Cord", "color": Color(0.35, 0.55, 0.25)},
	"kana_charm": {"name": "Kana Charm", "color": Color(0.85, 0.2, 0.2)},
	"shell": {"name": "Spiral Shell", "color": Color(0.9, 0.85, 0.7)},
	"emberstone": {"name": "Emberstone", "color": Color(1.0, 0.4, 0.1)},
}


static func item_name(id: String) -> String:
	if ITEMS.has(id):
		return ITEMS[id]["name"]
	return id


static func item_color(id: String) -> Color:
	if ITEMS.has(id):
		return ITEMS[id]["color"]
	return Color(0.8, 0.8, 0.8)
