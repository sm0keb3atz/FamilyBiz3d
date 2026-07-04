# Vehicle component architecture

`BaseVehicle` is the stable public API and lifecycle coordinator. It owns the
`VehicleBody3D`, wheel references, shared definition, driver lifecycle, and
runtime construction of particle emitters.

Behavior is composed from children under `Components`:

- `VehicleDriveComponent`: input, steering, drive force, and braking.
- `VehiclePowertrainComponent`: gears, shift timing, force ratios, and RPM
  targets.
- `VehicleTireComponent`: grip, handbrake slip, drifting, burnouts, and
  traction recovery.
- `VehicleStabilityComponent`: anti-roll, roll correction, drift assistance,
  and downforce.
- `VehicleAudioComponent`: entry/ignition/shutdown sequence, engine pitch, and
  tire audio.
- `VehicleEffectsComponent`: skid marks, tire smoke, and exhaust playback.
- `VehicleCameraComponent`: chase-camera state and response.
- `VehicleWheelVisualComponent`: wheel skeleton binding and animation.
- `VehicleInteractionComponent`: interaction eligibility, safe exits, and
  upright recovery.
- `VehicleImpactComponent`: NPC impact handling.

Components may read the shared `VehicleDefinition`, but subsystem runtime state
belongs to the component responsible for it. Other systems consume that state
through the component rather than duplicating it in `BaseVehicle`.
