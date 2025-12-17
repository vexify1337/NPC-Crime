# 🚗 NPC Crime – Reactive NPC Vehicle Theft System for FiveM

NPC Crime is a lightweight, fully automated vehicle theft system for FiveM where ambient NPCs opportunistically steal real, player-owned vehicles when they’re left unattended.

The script continuously scans nearby empty vehicles, selects a valid target based on distance and configurable chance, then turns an existing ambient NPC into a thief. The NPC approaches the vehicle, lockpicks the driver door, enters, and aggressively drives the stolen car to a chop-shop style destination where it is stripped and damaged.

Designed to be immersive, framework-agnostic, and performance-friendly.

## ✨ Key Features
# 🔍 Smart Vehicle Detection

Only targets empty, player-owned vehicles

Distance-based selection with configurable chance

Vehicle class filtering

Cooldowns to prevent repeated thefts and spam

# 🔗 Framework-Agnostic (via oeva_bridge)

Supports QBCore and ESX out of the box

Ownership checks via database plate lookups

Easily extendable for custom frameworks

# 🧍 Uses Existing Ambient NPCs

No obvious NPC pop-ins

Takes control of nearby ambient peds

Seamlessly converts them into vehicle thieves

# 🔐 Lockpicking Interaction

NPC walks to the driver’s door

Plays a lockpicking / key animation with a prop

Enters the vehicle naturally (no teleporting)

🏎️ Aggressive Getaway Driving

Ignores traffic rules

Runs red lights and drives aggressively

Heads toward one of several configurable chop-shop destinations

# 🔧 Vehicle Stripping System

Once the destination is reached, the vehicle is stripped and damaged:

Tires popped

Doors broken

Engine and body health reduced

Dirt and visual damage applied
(All values fully configurable)

# 📍 Owner Feedback & Immersion 

Theft notification when the vehicle is stolen

Live client-side GPS blip tracking the moving vehicle

Final notification once the car is stripped

Player GPS automatically sets a waypoint to the wreck location
