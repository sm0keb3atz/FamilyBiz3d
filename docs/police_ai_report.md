# Police AI & Behavior Tree Findings Report

This document details the issues identified in the Police AI systems, Behavior Tree, and Cruiser dispatch routing, along with proposed fixes to address them.

---

## 1. Issue: Police Not Reacting to Gunshots / Immediately Forgetting Suspects

### A. The Search Initialization Deadlock (Circular Dependency)
There is a circular logical dependency between the behavior tree wanted conditions and the AI component's search state synchronization. 

*   **Behavior:** When a street cop (who is not response-assigned, i.e., `is_response_assigned() == false`) loses line of sight to a wanted player:
    1.  The behavior tree evaluates `BTSequence_arrest_search` -> `BTCondition_arrest_search_wanted` ([police_wanted_condition.gd](file:///c:/Users/smo0o/OneDrive/Documents/family-biz-prototype/Scripts/NPC/AI/police_wanted_condition.gd)).
    2.  For street cops, this condition returns `SUCCESS` only if they can see the player OR have a confirmed location (`has_confirmed_wanted_player_location()`).
    3.  `has_confirmed_wanted_player_location()` requires `_has_search_center` and `_has_search_destination` to be `true` ([police_ai_component.gd](file:///c:/Users/smo0o/OneDrive/Documents/family-biz-prototype/Scripts/NPC/Components/police_ai_component.gd)).
    4.  However, these search targets are *only* synchronized from the player's wanted component via `_sync_search_dispatch()`.
    5.  `_sync_search_dispatch()` is only called *after* entering search mode (inside `_tick_search` or `_chase_last_known` which requires the search sequence to be running, or when entering a non-patrol mode). But because the wanted condition returned `FAILURE`, the behavior tree never runs the search action! It falls back to `BTAction_patrol` (patrol mode).
*   **Result:** Street police officers completely forget about a wanted player the split second they lose line of sight (e.g., walking around a single corner) and return to their peaceful patrol routes rather than searching.

### B. Manually Placed Police NPCs are Disabled
If a `PoliceNPC` node is placed directly into a scene rather than spawned dynamically via the population managers or dispatch controller, it will not react to gunshots.
*   In `_ready()` ([police_npc.gd](file:///c:/Users/smo0o/OneDrive/Documents/family-biz-prototype/Scripts/NPC/police_npc.gd)), manually placed editor instances set:
    ```gdscript
    visible = false
    process_mode = Node.PROCESS_MODE_DISABLED
    ```
*   Because `_pool_active` remains `false` on these instances, `handle_world_event()` rejects all gunshot events, leaving them inert.

---

## 2. Issue: Police Cruisers Failing to Reach Staging Destinations

### A. Broken Stalled Vehicle Recovery Loop
When a dispatched cruiser is blocked or stalled by traffic or obstacles for more than `stalled_reroute_seconds` (4.0s), the dispatch controller attempts to reroute the vehicle to a different staging point. However, this recovery method is incomplete.

*   **The Code in Question ([police_dispatch_controller.gd](file:///c:/Users/smo0o/OneDrive/Documents/family-biz-prototype/Scripts/NPC/police_dispatch_controller.gd#L736-L750)):**
    ```gdscript
    func _recover_stalled_response(response: ResponseUnit) -> void:
        if response.recovery_count >= 2 or _incident == null:
            return
        var stage := _choose_nearest_free_stage(
            _incident.territory_id,
            _last_known_position,
            response.stage
        )
        if stage == null:
            return
        var destination := stage.call(
            "get_roadway_stop_waypoint"
        ) as TrafficWaypoint3D
        if destination == null or not response.ai.retarget_destination(destination):
            return
    ```
*   **What is missing:**
    If `retarget_destination` returns `true`, the code **never updates** the staging reference or reservations:
    1.  `response.stage = stage` is never set, so the cruiser still thinks its destination is the old (blocked) stage.
    2.  The old stage reservation is never released, and the new stage reservation is never claimed in `_reserved_stages`.
    3.  `response.recovery_count` is never incremented. 
*   **Result:** The cruiser enters an infinite loop, trying to recover every 4 seconds. It repeatedly overwrites its destination waypoints and steering controls, causing it to stutter, jitter, and fail to reach either destination.

### B. Missing Pursuit Retargeting Out of Sight
In `_tick_mobile_response()`, if the player is driving a vehicle, the dispatch controller only refreshes and retargets the pursuit if the cruiser has direct line of sight (`sees_target`). Once they lose visual contact, they stop retargeting the player's last known driving position and default back to static staging, making vehicle chases easily broken.

---

## 3. Other Behavior Tree and AI Logic Problems

### A. Hyperactive Investigation (No Search Pause)
When the player has a wanted level of 0 and fires a weapon, police within hearing range enter `MODE_INVESTIGATE` to walk over and check the source of the sound.
*   Once they arrive, the AI component immediately replans search locations every `search_replan_interval` (0.4s) using `_choose_search_position()`.
*   Unlike `_chase_last_known()`, `_tick_investigation()` completely ignores the pause timers (`_search_pause_pending` and `_search_pause_remaining`). 
*   **Result:** Investigating officers move erratically, walking back and forth near the gunshot location without ever stopping to look around.

### B. Direct Execution Routing Bypasses Behavior Tree Flow
Inside `_tick_search()`, if the perception component spots the player, it manually routes code execution to `_tick_combat()`, `_tick_challenge()`, or `_tick_arrest()` inline. While the behavior tree's `BTDynamicSelector` will eventually catch up on the next frame, executing child actions directly inside a different action's tick makes the system fragile and prone to state synchronization lag.

---

## Proposed Technical Solutions

Here are the proposed code edits to resolve these issues:

### Fix 1: Resolve Cruiser Stalled Recovery
Update `_recover_stalled_response` in [police_dispatch_controller.gd](file:///c:/Users/smo0o/OneDrive/Documents/family-biz-prototype/Scripts/NPC/police_dispatch_controller.gd) to update staging assignments, handle reservations, and increment recovery count:

```diff
 func _recover_stalled_response(response: ResponseUnit) -> void:
 	if response.recovery_count >= 2 or _incident == null:
 		return
 	var stage := _choose_nearest_free_stage(
 		_incident.territory_id,
 		_last_known_position,
 		response.stage
 	)
 	if stage == null:
 		return
 	var destination := stage.call(
 		"get_roadway_stop_waypoint"
 	) as TrafficWaypoint3D
 	if destination == null or not response.ai.retarget_destination(destination):
 		return
+
+	_release_stage(response)
+	response.stage = stage
+	_reserved_stages[StringName(stage.get("slot_id"))] = response
+	response.recovery_count += 1
```

### Fix 2: Break Search Deadlock
Sync the search dispatch whenever wanted level is active in [police_wanted_condition.gd](file:///c:/Users/smo0o/OneDrive/Documents/family-biz-prototype/Scripts/NPC/AI/police_wanted_condition.gd) or periodically check if street cops can sync active dispatch data during their `_tick` so they don't get trapped in the patrol state when sight is lost. Alternatively, we can let `_tick_patrol` periodically call `_sync_search_dispatch()` if `wanted.wanted_level > 0`.

### Fix 3: Add Pause to Gunshot Investigation
Update `_tick_investigation` in [police_ai_component.gd](file:///c:/Users/smo0o/OneDrive/Documents/family-biz-prototype/Scripts/NPC/Components/police_ai_component.gd) to honor the search pause timers:

```diff
 func _tick_investigation(delta: float) -> void:
 	npc.move_speed = patrol_speed
 	combat.clear_aim()
 	combat.set_equipped(false)
 	_search_elapsed += delta
 	if not has_active_investigation():
 		npc.clear_navigation_target()
 		return
 	if (
 		npc.global_position.distance_squared_to(_last_known_position)
 		> 1.5 * 1.5
 	):
 		npc.set_navigation_target(_last_known_position)
 		npc.advance_navigation(delta)
 		return
 	npc.stop_moving(delta)
+	if _search_pause_pending:
+		_search_pause_remaining = _random.randf_range(
+			search_pause_minimum,
+			search_pause_maximum
+		)
+		_search_pause_pending = false
+	if _search_pause_remaining > 0.0:
+		_search_pause_remaining = maxf(
+			_search_pause_remaining - delta,
+			0.0
+		)
+		return
 	if _search_replan_remaining <= 0.0:
 		_choose_search_position()
 		_search_replan_remaining = search_replan_interval
```
