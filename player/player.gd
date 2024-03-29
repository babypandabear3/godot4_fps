extends CharacterBody3D

enum _CROUCHING_STATE {
	UNCROUCHED,
	CROUCHING,
	UNCROUCHING,
}

@export var mouse_sensitivity : float = 0.01
@export var air_control : bool = false
@export var speed : float = 5.0
@export var sprint_modifier : float = 2.0
@export var jump_velocity : float = 4.5
@export var camera_v_min : float = -85.0
@export var camera_v_max : float = 85.0
@export var camera_height : float = 1.6
@export var crouch_speed : float = 0.2

# Get the gravity from the project settings to be synced with RigidBody nodes.
var gravity : float = ProjectSettings.get_setting("physics/3d/default_gravity")
var crouch_state : _CROUCHING_STATE = _CROUCHING_STATE.UNCROUCHED
var speed_modifier : float = 1.0

@onready var axis_y : Node3D = $axis_y
@onready var axis_x : Node3D = $axis_y/axis_x
@onready var colshape : CollisionShape3D = $CollisionShape3D
@onready var capsule_shape : CapsuleShape3D = $CollisionShape3D.shape
@onready var ray_uncrouching : RayCast3D = $ray_uncrouching

var capsule_height_default : float = 0.0

func _ready():
	axis_x.position.y = camera_height - (capsule_shape.height * 0.5)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	camera_v_min = deg_to_rad(camera_v_min)
	camera_v_max = deg_to_rad(camera_v_max)
	capsule_height_default = capsule_shape.height  
	
func _input(event):
	if event is InputEventKey:
		if event.keycode == KEY_ESCAPE:
			get_tree().quit()
	
	if event is InputEventMouseMotion:
		axis_y.rotation.y -= event.relative.x * mouse_sensitivity
		axis_y.rotation.y = wrapf(axis_y.rotation.y, -PI, PI)
		axis_x.rotation.x -= event.relative.y * mouse_sensitivity
		axis_x.rotation.x = clampf(axis_x.rotation.x, camera_v_min, camera_v_max)

func _physics_process(delta):
	# Add the gravity.
	if not is_on_floor():
		velocity.y -= gravity * delta

	# Handle jump.
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = jump_velocity

	if Input.is_action_pressed("sprint"):
		speed_modifier = sprint_modifier
	else:
		speed_modifier = 1.0
	# Get the input direction and handle the movement/deceleration.
	# As good practice, you should replace UI actions with custom gameplay actions.
	var input_dir = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var direction = (axis_y.global_basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	
	if air_control: #allow input to affect movement direction only when on floor
		if is_on_floor():
			if direction:
				velocity.x = direction.x * speed * speed_modifier
				velocity.z = direction.z * speed * speed_modifier
			else:
				velocity.x = move_toward(velocity.x, 0, speed)
				velocity.z = move_toward(velocity.z, 0, speed)
	else: #allow input to affect movement direction anytime
		if direction:
			velocity.x = direction.x * speed * speed_modifier
			velocity.z = direction.z * speed * speed_modifier
		else:
			velocity.x = move_toward(velocity.x, 0, speed)
			velocity.z = move_toward(velocity.z, 0, speed)
		
	#CROUCHING
	match crouch_state:
		_CROUCHING_STATE.UNCROUCHED:
			if Input.is_action_just_pressed("crouch_toggle"):
				start_crouching()
			if Input.is_action_pressed("crouch_hold"):
				start_crouching()
		_CROUCHING_STATE.CROUCHING:
			if Input.is_action_just_pressed("crouch_toggle"):
				crouch_state = _CROUCHING_STATE.UNCROUCHING
			if Input.is_action_just_released("crouch_hold"):
				crouch_state = _CROUCHING_STATE.UNCROUCHING
		_CROUCHING_STATE.UNCROUCHING:
			if Input.is_action_just_released("crouch_hold"):
				crouch_state = _CROUCHING_STATE.UNCROUCHING
			start_uncrouching()
	
	move_and_slide()

func start_crouching():
	crouch_state = _CROUCHING_STATE.CROUCHING
	var tween = create_tween()
	tween.tween_property(capsule_shape, "height", capsule_shape.radius * 2, crouch_speed)
	tween.set_parallel(true)
	tween.tween_property(axis_x, "position:y", 0.0, crouch_speed)
	
func start_uncrouching():
	if not ray_uncrouching.is_colliding():
		var tween = create_tween()
		tween.tween_property(capsule_shape, "height", capsule_height_default, crouch_speed)
		tween.set_parallel(true)
		tween.tween_property(axis_x, "position:y", camera_height - (capsule_height_default * 0.5), crouch_speed)
		crouch_state = _CROUCHING_STATE.UNCROUCHED
	
