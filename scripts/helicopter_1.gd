extends Node3D

# TODO: this setup still has a bug for late-joining peers. Authority seems to be incorrect, at least on the synchronizer

@export var _auth_peer_id: int = 1 : set = _update_auth_peer_id
@export var pilot: Player
@export var player_spawn_point: Node3D
@export var action_area: Area3D
@export var _multiplayer_synchronizer: MultiplayerSynchronizer

var _init_new_spawn = false
var _pilot_model: Node3D
var _player_inside_area: bool = false # TODO: there's probably a better way to do this...

func _ready():
	print("helicopter ready: %s with auth %s" % [_auth_peer_id, get_multiplayer_authority()])
	player_spawn_point = get_tree().current_scene.find_child("PlayerSpawnPoint")

func _physics_process(delta):
	if is_multiplayer_authority() && pilot: # Update position if we are authority and have a pilot set
		global_position = pilot.global_position # synch position to player's position
		global_transform.basis = _pilot_model.global_transform.basis
	else:
		if _player_inside_area && Input.is_action_just_pressed("action_1"):
			print("Player wants to pilot heli: %s: " % multiplayer.get_unique_id())
			
			player_wants_authority.rpc() #rpc_id(get_multiplayer_authority())

# This is the auth_peer_id setter
func _update_auth_peer_id(peer_id: int):
	print("update auth peer %s, %s" % [peer_id, multiplayer.get_unique_id()])
	_auth_peer_id = peer_id
	set_multiplayer_authority(_auth_peer_id, true) # only use true on the recursive param if necessary

# Access from any peer, need to be able to call locally if we're on a host (call_local).
# TODO: not sure if this should be called only on the authority (rpc_id) or on all peers
@rpc("any_peer", "call_local")
func player_wants_authority():
	print("Player_wants_authority rpc: %s on peer: %s" % [multiplayer.get_remote_sender_id(), multiplayer.get_unique_id()])
	
	_update_auth_peer_id(multiplayer.get_remote_sender_id())
	
	# TODO: improve this process
	# Find the player from the PlayerSpawnPoint node array
	for i in player_spawn_point.get_children():
		if i.name == str(multiplayer.get_remote_sender_id()):#_auth_peer_id):
			#print("found player on auth %s" % get_multiplayer_authority())
			pilot = i
			_pilot_model = pilot.get_node("MilitaryMale")


# ---- Helpers to detect we are close to craft --- 

func _on_rigid_body_3d_body_entered(body):
	#print("body entered helicopter: %s" % body.name)
	# The first time in here, the authority will be the server/host
	if body.name == str(multiplayer.get_unique_id()):
		# we are on the peer that entered the area
		_player_inside_area = true


func _on_area_3d_body_exited(body):
	if body.name == str(multiplayer.get_unique_id()):
		# we are on the peer that exited the area
		_player_inside_area = false
