# Police response and combat review — September 6, 2026

The active police stack uses `PoliceBrainComponent` for foot behavior, `PoliceCoordinator` and `PlayerWantedComponent` for shared intelligence and escalation, `PoliceDispatchController` for response crews, and `TrafficVehicleAIComponent` for road driving. The older `police_ai_report.md` describes an earlier staging/behavior-tree implementation; its proposed fixes should not be applied verbatim to the current stack.

## Findings and changes

| Problem | Change |
| --- | --- |
| Dispatch could favor a long approach around the block. | Evaluate nearby eligible starts and favor shorter reachable routes with a penalty for distance from the incident. Keep offscreen spawning, road checks, clearance and the route-search budget. |
| Changing a pursuit route to a stopping route could be ignored when the target barely moved. | Include stop mode in the retarget reuse condition. |
| Braking began only on the final segment; overshooting could cause acceleration back toward a destination behind the car. | Limit speed using remaining route distance and keep braking after passing the terminal destination. |
| Failed recovery attempts did not consume the retry budget. | Count unsuccessful searches too. Nearby blocked units can stop and finish a stationary incident response on foot; distant failures use the existing replacement path. |
| Unseen player movement could indefinitely prevent dismount at the last known location. | Require visual contact for live moving-vehicle decisions during arrival, stopping and deployment. Units can investigate the last reported location. |
| Officers could emerge at a distant pedestrian waypoint or an unchecked exit. | Try additional nearby sides/rear positions, reject missing ground and blocked positions, and bound the waypoint fallback to eight metres. Failed deployment retains the existing timeout. |
| Returning officers had two movement controllers active. | Deactivate the foot brain when dispatch takes over boarding; existing reengagement reactivates it. Keep parked cruisers braking during deployment and on-scene work. |
| Occupied player vehicles blocked officer perception of their driver. | Recognize the occupied car as the visual target and aim combat at that vehicle while the player drives. |
| Rapid alternating direct strafes could push officers into scenery. | Use longer strafe intervals, projected movement destinations, and retreating movement while reloading. |
| Beginning a reload returned the same success value as firing. | Start the reload but return false so burst accounting only advances on an actual shot. |
| Old gunshot observations could reopen a resolved incident. | Clear the brain's pending investigation when cancelling wanted engagement. |
| Both suburb mobility instances inherited Hood East connector and signal identifiers. | Assign each suburb distinct route, intersection and signal IDs. This prevents cross-territory identifier collisions. |

The six-level escalation, compliance, coordinated search roles, burst pauses, visual-memory pursuit, and gradual wanted decay remain the existing foundations. No character assets or shared animation libraries changed.

## Verification

Godot 4.7 headless runs returned exit code 0 and their explicit PASS markers:

- `Tests/police_system_smoke_test.gd`: physical approach/deployment, response strength, reengagement, vehicle pursuit and boarding; added checks for stop-mode retargeting, overshoot distance, failed recovery accounting and brain suspension while returning.
- `Tests/police_clean_brain_smoke_test.gd`: physical search movement, scanning, combat visual memory; added reload and stale-investigation regressions.
- `Tests/police_wanted_overhaul_smoke_test.gd`: escalation targets, evasion steps, search assignments and sight angles. The angle check now uses empty space rather than assuming random patrol scenery is unobstructed.
- `Tests/traffic_smoke_test.gd`: road-network validation and traffic behavior. Corrected an existing incompatible static type assertion so the suite can run on this engine.

`git diff --check` passed. Test user data was isolated under `.runtime_appdata`. Runs still report certificate-store, animation-track and teardown resource warnings; PASS markers and successful exits were checked separately.

## Limits and playtest focus

This is a behavior/routing pass, not a new animated vehicle-entry system. Door opening and fully animated boarding remain future presentation work. Vehicle body damage/occupant penetration was not redesigned. Road geometry, heavy traffic and narrow alleys still warrant hands-on testing; automated checks do not establish subjective combat feel or every possible pursuit route.

Restart the game to load the changed scripts and territory scenes. Useful scenarios are a foot pursuit around a corner, stopping and restarting a fleeing car, a blocked cruiser approaching a stationary incident, losing visual contact while driving, and clearing wanted before committing a new crime near returning officers.
