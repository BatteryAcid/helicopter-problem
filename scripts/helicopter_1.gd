extends Node3D

# TODO: this setup still has a bug for late-joining peers. Authority seems to be incorrect, at least on the synchronizer
# - I think this is fixed now!

# How to use scene:
# Use "C" to spawn a "craft"
# "F" to take control
# "R" to release
# Cannot take control if another player has it.

@export var _auth_peer_id: int = 1 : set = _update_auth_peer_id
@export var _player_controlled: bool = false
@export var pilot: Player
@export var player_spawn_point: Node3D
@export var action_area: Area3D
@export var _multiplayer_synchronizer: MultiplayerSynchronizer
@export var _auth_synchronizer: MultiplayerSynchronizer

var _init_new_spawn = false
var _pilot_model: Node3D
var _player_inside_area: bool = false # TODO: there's probably a better way to do this...

func _ready():
	print("helicopter ready: %s with auth %s" % [_auth_peer_id, get_multiplayer_authority()])
	player_spawn_point = get_tree().current_scene.find_child("PlayerSpawnPoint")

func _physics_process(delta):
	if _multiplayer_synchronizer.is_multiplayer_authority() && _player_controlled && pilot: #pilot: # Update position if we are authority and have a pilot set
		global_position = pilot.global_position # synch position to player's position
		global_transform.basis = _pilot_model.global_transform.basis
		
		if Input.is_action_just_pressed("action_2"): # release authority
				print("Player wants to release authority: %s:" % multiplayer.get_unique_id())
				_player_release_authority.rpc()
	else:
		if _player_inside_area:
			if Input.is_action_just_pressed("action_1"): # request authority
				print("Player wants to pilot heli: %s: " % multiplayer.get_unique_id())
				player_wants_authority.rpc()
			
# This is the auth_peer_id setter
func _update_auth_peer_id(peer_id: int):
	# TODO: this is repeatedly called on some or all peers, may update to OnChange? 
	
	#print("update auth peer %s, %s" % [peer_id, multiplayer.get_unique_id()])
	_auth_peer_id = peer_id
	
	# authority changes hands, stop the current auth from sending a few frames to reduce chance of synch data errors...
	_multiplayer_synchronizer.set_multiplayer_authority(_auth_peer_id)

# Access from any peer, need to be able to call locally if we're on a host (call_local).
# This RPC is hit on all peers.
@rpc("any_peer", "call_local")
func player_wants_authority():
	print("Player_wants_authority rpc: %s on peer: %s" % [multiplayer.get_remote_sender_id(), multiplayer.get_unique_id()])

	# Make sure no players are in control of craft
	if not _player_controlled:
		
		if multiplayer.get_unique_id() == 1:
			# only update on server authority peer, which will always be 1
			_player_controlled = true
			_update_auth_peer_id(multiplayer.get_remote_sender_id())
		
		if multiplayer.get_remote_sender_id() == multiplayer.get_unique_id():
			# if we are on the peer requesting authority over the craft, establish pilot
			for i in player_spawn_point.get_children():
				if i.name == str(multiplayer.get_remote_sender_id()):#_auth_peer_id):
					#print("found player on auth %s" % get_multiplayer_authority())
					pilot = i
					_pilot_model = pilot.get_node("MilitaryMale")
		
		# Un-pause/set public visibility on. 
		# This is in effort to stop the "on_sync_receive: Ignoring synch data from non-authority or for missing node" errors.
		_multiplayer_synchronizer.set_visibility_for(0, true)

# Releases the authority from the peer, and set's it back to the server/host (1)
# This RPC is hit on all peers.
@rpc("any_peer", "call_local")
func _player_release_authority():
	print("Player release authority rpc")
	
	# Make sure we have a player controlling craft before it can be released.
	if _player_controlled:

		if multiplayer.get_unique_id() == 1:
			# only update on server authority peer, which will always be 1
			_player_controlled = false # this is synched/controlled by server auth
			_update_auth_peer_id(1)

		# Pause/set public visibility off. 
		# This is in effort to stop the "on_sync_receive: Ignoring synch data from non-authority or for missing node" errors.
		_multiplayer_synchronizer.set_visibility_for(0, false)
		
		# Clean up can be applied generically across peers
		pilot = null
		_pilot_model = null


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
