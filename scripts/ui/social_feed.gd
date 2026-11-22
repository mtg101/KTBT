extends Control
## The night's posts (ui/social_post.gd: rules/socials.gd picks them) stuck round the diary page,
## over the whole window with the page in the middle: the first top left, the next top right, a
## third under the first, each at a tilt. At 3am (visit.gd, while the diary page shows) and in the
## diary book, with whichever entry's open; an entry from before the posts, or a quiet night with
## none, has nothing round it. Never takes a click; the posts' hovers still show.

const SocialPost = preload("res://scripts/ui/social_post.gd")
const ViewerComments = preload("res://scripts/ui/viewer_comments.gd")

const SCREEN := Vector2(1920, 1080)
const SPOTS := [Vector2(110, 150), Vector2(1460, 190), Vector2(130, 590)]
const TILTS := [-0.045, 0.04, 0.03]
const COMMENTS_SPOT := Vector2(1440, 640)  # the viewers' comments: bottom right
const COMMENTS_TILT := -0.02

var comments: Control  # the viewers' comments up, or null


func _init() -> void:
	name = "SocialFeed"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = SCREEN


## An entry's posts (its "socials") and its viewers' comments (its "viewers": none for an entry
## from before them); bar_id: whose pictures folder their snapshots are in.
func show_posts(posts: Array, bar_id: String, viewers: Dictionary = {}) -> void:
	for old in get_children():
		remove_child(old)
		old.queue_free()
	comments = null
	var k := 0
	for post in posts:
		if not post is Dictionary or k >= SPOTS.size():
			continue
		var card := SocialPost.new()
		card.setup(post, bar_id, float(TILTS[k]))
		card.position = SPOTS[k]
		add_child(card)
		k += 1
	if not (viewers.get("comments", []) as Array).is_empty():
		var board := ViewerComments.new()
		board.setup(viewers, COMMENTS_TILT)
		board.position = COMMENTS_SPOT
		add_child(board)
		comments = board


## Whose posts are up, in order (their full names).
func posters() -> Array:
	return _cards().map(func(card): return str(card.poster))


## How each post's picture came: "snapshot", "drawn" or "words".
func pictures() -> Array:
	return _cards().map(func(card): return str(card.how))


## How many viewers' comments are up (none: 0).
func comment_count() -> int:
	return int(comments.rows) if comments != null else 0


func _cards() -> Array:
	return get_children().filter(func(child): return child is SocialPost)
