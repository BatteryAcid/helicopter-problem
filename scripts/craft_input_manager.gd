extends Node

var _heli_scene = preload("res://scenes/world/aircraft/helicopter1.tscn")
@export var craft_spawn_point: Node3D
@export var player_spawn_point: Node3D

func _physics_process(delta):
	if Input.is_action_just_pressed("spawn_heli_1"):
		# The input is capture on the local peer, but the craft must be added by the authority.
		# The craft will spawn in the world as host-authority, but the player can take over authority.
		print("player wants to spawn heli. %s" % is_multiplayer_authority())
		spawn_craft_on_auth.rpc_id(get_multiplayer_authority())
		
# Must have call_local to allow for Host setups  
@rpc("any_peer", "call_local") 
func spawn_craft_on_auth():
	print("Adding craft to spawn point: %s" % is_multiplayer_authority())
	var heli_scene = _heli_scene.instantiate()
	craft_spawn_point.add_child(heli_scene, true)


#func _on_craft_spawner_spawned(node):
	#print("craft spawned %s" % [node.name])
