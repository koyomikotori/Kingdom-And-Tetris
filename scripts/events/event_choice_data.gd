class_name EventChoiceData
extends Resource
## One answer to an event (GDD §9c): its cost is always shown (and must be affordable); what it
## leads to is only hinted at until it is chosen.

@export var text: String
## Shown under the choice instead of the exact result ("They may remember this…").
@export var hint: String
## Paid up front when chosen.
@export var cost: Dictionary[StringName, int] = {}
## One is rolled by weight. Empty = nothing else happens.
@export var outcomes: Array[EventOutcomeData] = []
