extends RefCounted
## Where things are on the tent's stage (pixels): shared by the tent's scene and its parts.

const SEAT_X := [470.0, 760.0, 1050.0, 1340.0, 1630.0]  # the middle of each stool
const CUSTOMER_Y := 156.0  # the top of a customer (a person's 216 tall, standing on the ground at 372: sitting, coming in or leaving, they stay on the ground)
const STROLL_Y := CUSTOMER_Y + 6  # the pavement: a little lower (nearer to us) than the stools
const PERSON_SIZE := Vector2(96, 216)  # a person on the stage (people_art.gd: 32 x 72 pixels, a pixel to 3)
# Off-stage spots either side (far enough out that the name tag is hidden too).
const OFFSCREEN_LEFT_X := -200.0
const OFFSCREEN_RIGHT_X := 2072.0
const PEEK_X := 865.0  # where a passer-by stops to look in: the gap between the second and third stools
