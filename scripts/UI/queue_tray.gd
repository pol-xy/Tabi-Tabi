extends PanelContainer
## scripts/UI/queue_tray.gd
## Attached to QueueTray inside HUD.tscn.
## Detects drops on empty background spaces in the queue area and forwards them
## to the QueuePanel sibling node so they are returned to the queue.

var queue_panel: ScrollContainer = null

func _ready() -> void:
	# QueuePanel is a sibling of this node inside the CanvasLayer.
	# get_parent() navigates to HUD (CanvasLayer), then we search for QueuePanel.
	queue_panel = get_parent().get_node_or_null("QueuePanel")

func _can_drop_data(at_position: Vector2, data: Variant) -> bool:
	if queue_panel and queue_panel.has_method("_can_drop_data"):
		return queue_panel._can_drop_data(at_position, data)
	return false

func _drop_data(at_position: Vector2, data: Variant) -> void:
	if queue_panel and queue_panel.has_method("_drop_data"):
		queue_panel._drop_data(at_position, data)
