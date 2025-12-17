NPC Crime – Reactive NPC Vehicle Theft System for FiveM
NPC Crime is a lightweight, fully-automatic vehicle theft system where ambient NPCs will steal real players’ owned cars when they leave them unattended. The script checks empty, owned vehicles around players, picks one based on distance and a configurable chance, then takes over a nearby ped, makes them lockpick the driver’s door, get in, and drive the car at high speed to a chop-shop style destination where the vehicle is stripped and damaged.
Key features:
Smart vehicle detection – Only empty, player-owned vehicles are considered, filtered by distance, class and simple cooldowns to avoid spam.
Framework-agnostic via oeva_bridge – Supports QBCore and ESX ownership checks out of the box (via database plate lookups).
Uses existing NPCs – No obvious “pop-in” ped spawn in the middle of the road; the script takes control of a nearby ambient ped and turns them into the thief.
Lockpicking animation + prop – NPC walks to the driver door, plays a key/lockpick animation with a prop, then enters the vehicle instead of teleporting.
Aggressive driving to destinations – NPC ignores traffic rules, runs red lights and pushes hard to reach one of several configurable chop-shop destinations.
Vehicle stripping – Once at the destination, the car is stripped for parts: tyres popped, doors broken, engine/body health reduced, dirt applied, etc., all configurable.
Owner feedback & immersion
When the theft starts: owner gets a notification that their car is being stolen and a client-side blip tracking the moving vehicle.
When the car is stripped: owner gets a second notification that the vehicle has been stripped and broken, and their GPS is automatically set to the final location of the wreck.
