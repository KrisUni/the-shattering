class_name AreaLoadTuning
extends Resource
## The numbers of loading one space after another, such as through a Doorway. The values live in
## its data file, data/area_load.tres, not here.

## How long the screen takes to fade out before a space is loaded, and again to fade back in
## after it, in seconds. Zero loads without a fade.
@export var fade_seconds: float
