class_name SpellCost
extends Resource
## What casting one Spell costs. The values live in the Spell's cost file, such as
## data/pull.tres, not here.

## How much Health casting it spends. He cannot cast unless his Health stays above this much.
@export var health_cost: float

## How much Stamina casting it spends. He cannot cast with less than this much.
@export var stamina_cost: float
