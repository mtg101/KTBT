extends Control
## The night's posts (ui/social_post.gd: rules/socials.gd picks them) stuck round the diary page,
## over the whole window with the page in the middle: the first top left, the next top right, a
## third under the first, each at a tilt. At 3am (visit.gd, while the diary page shows) and in the
## diary book, with whichever entry's open; an entry from before the posts, or a quiet night with
## none, has nothing round it. Never takes a click; the posts' hovers still show.

const SocialPost = preload("res://scripts/ui/social_post.gd")

const SCREEN := Vector2(1920, 1080)
const SPOTS := [Vector2(110, 150), Vector2(1460, 190), Vector2(130, 590)]
const TILTS := [-0.045, 0.04, 0.03]


func _init() -> void:
	name = "SocialFeed"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SCREEN


## An entry's posts (its "socials"); bar_id: whose pictures folder their snapshots are in.
func show_posts(posts: Array, bar_id: String) -> void:
	for old in get_children():
		remove_child(old)
		old.queue_free()
	for post in posts:
		if not post is Dictionary or get_child_count() >= SPOTS.size():
			continue
		var card := SocialPost.new()
		var k := get_child_count()
		card.setup(post, bar_id, float(TILTS[k]))
		card.position = SPOTS[k]
		add_child(card)


## Whose posts are up, in order (their full names).
func posters() -> Array:
	return get_children().map(func(card): return str(card.poster))


## How each post's picture came: "snapshot", "drawn" or "words".
func pictures() -> Array:
	return get_children().map(func(card): return str(card.how))
