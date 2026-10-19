class_name TorchTuning
extends Resource
## The numbers of the light a lit torch gives. The values live in data/torch_light.tres, not here.

## The gameplay light, from 0 (dark) to 1 (full light), within the torch's radius while it burns. It
## lifts the light there to at least this much, over any dark zone.
@export_range(0.0, 1.0) var light: float

## How far from the torch, in pixels, its light reaches.
@export var radius: float
