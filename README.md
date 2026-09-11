# Client/Tools Repo
This repository contains the source for the SWG Client as well as the tools that support certain aspects of development.

## Build Instructions
The legacy Win32 projects were originally configured for **Visual Studio 2013**. The regular gameplay client and Qt-based God client now have modern `Release|x64` builds. See the [x64 gameplay client guide](docs/x64-gameplay-client.md) and [God client guide](docs/god-client.md) for prerequisites, commands, outputs, and current runtime limitations.

The project has 3 configurations for building the applications:
* **Release** which is the version intended for public dissemination and gameplay. You may recognize this as the `_r` in the client name `SwgClient_r.exe`. 
* **Optimized** which is similar to the release client but has additional options and displays in-game for testing and is ideal for Quality Assurance or Support related activities. For example, this configuration allows for additional options like targeting static world objects, printing object information in the user interface, and releasing the camera from player attachment for custom views.
* **Debug** which is a development client that has extra features for testing and extensive logging and reporting. This build isn't particularly useful for any present application.

At present, only the `Release` version of the projects will build, but we're working on cleaning up the remainder of the configurations. As a temporary solution to accessing the features of the optimized version, you can set the constant in `production.h` to `0` regardless of the configuration. 

To build the client, find the `SwgClient` project in solution explorer and right click then select `Build`. Note that other projects may have similar names (like `ClientGame`) but these are shared across multiple tools. The actual game client you need for playing the game is the `SwgClient` project.

### x64 Quick Start

Check the build environment, or install missing Microsoft prerequisites from an elevated PowerShell window:

```powershell
.\scripts\Test-X64BuildPrerequisites.ps1
.\scripts\Setup-X64BuildPrerequisites.ps1 -Install
```

Installer URLs, pinned DirectX hashes, and the offline-cache workflow are documented in [the x64 prerequisite profile](deps/build-prerequisites/README.md).

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\scripts\Build-X64Client.ps1
```

The script builds the DX11 gameplay client, then verifies that every deployed runtime artifact is x64. Pass `-StagePath` to deploy those artifacts into an existing client data directory with automatic backups. Gameplay staging is DX11-only, removes backed-up `gl00`, `gl05`, `gl06`, and `gl07` renderer DLLs from the target runtime, and installs the tracked HLSL overrides required to render legacy Publish 14 shader assets through D3D11.

## Shared Files
Please note that certain projects and files are prepended with `shared` which means they are files that are used in both the game engine ([the `src` repository](https://github.com/Galaxies-Reborn/src)) and the client. There are many enums, for instance, that must match between the client and server or there may be crashes, errors, unintended functionality or some combination thereof. ***If you make changes to any of these shared files, you must make the changes both in the src and in client-tools.***

## Deprecated Components
Some specific features have been removed or disabled from the client as they are either no longer needed or outside the scope of the development work of Galaxies Reborn. Those removals include:
* The In-Game Web Browser (which uses libmozilla) and any UI elements or commands to activate it
* The Trading Card Game and any UI elements or commands to activate it
* The Customer Service "Help" Context Menu and the Bug Reporting Form, and any UI elements or commands to activate it
* Any references to Perforce, a version control solution that is no longer used.

## Documentation
Development and contribution information is maintained in the [Galaxies Reborn repositories](https://github.com/Galaxies-Reborn).

## History
This repository and code has undergone extensive renovations and refactoring since its release in 2013 and some history isn't included in GitHub. If you're looking for how these files were originally received from SOE without modification, see the [whitengold repository](https://github.com/Galaxies-Reborn/whitengold).

## Branches
* **master** - The primary development and release branch.
* **stdlib** - Current "work in progress" for building on Visual Studio 2015, which includes it's own, complete STL implementation.
* **wolfssl** - A test branch where Darth was trying to implement DTLS SSL to make the connection secure. Feel free to finish this implementation.

## Contributing and More Information
Contributions and improvements are welcome and encouraged, please submit a pull request. Please note that any changes to the client-tools that requires a rebuild of the SwgClient, will also mean a newly compiled client binary must be added to the [client-assets repository](https://github.com/Galaxies-Reborn/client-assets) so it can be shipped to end users.

The Publish 14.1 Skills mediator supports the complete 54-root profession
matrix without exposing the 21 specialized roots in the ordinary 33-row
catalog. See [the nonstandard profession graph guide](docs/precu-nonstandard-profession-graphs.md).

The background-input bridge also exposes the milestone-243
`QueueEmboldenPets` action. It admits the real nonqueued `emboldenpets`
command with no explicit target so the server-owned active-pet transaction can
be proved through an authenticated client session.

Milestone 244 adds `QueueHealMind` (bridge command 231). It submits the real
nonqueued `healMind` command with an explicit target OID; the server retains
all Combat Medic ownership, PvP, range, line-of-sight, power, wound, and
battle-fatigue authority.

Milestone 245 advances the bridge to protocol 156 and adds `QueueBerserk1`
(command 232). It submits the authentic nonqueued `berserk1` command without a
target; the server retains Brawler ownership, weapon, chance, adjusted HAM,
state-duration, persistence, and expiration authority.

Milestone 246 advances the bridge to protocol 157 and adds `QueueBerserk2`
(command 233). It submits the authentic Brawler-master tier without a target;
the server retains the +20 modifier, chance, adjusted HAM, durable 40-second
state, and expiration authority.

Milestone 247 advances the bridge to protocol 159 and adds the isolated
`TargetSquadCounterpart` identity mapping plus `QueueFormup` (commands 234 and
235). Two separately rooted x64 clients prove real invite/join/disband and
submit the retained nonqueued `formup`; group, cost, member eligibility,
state clearing, and PvP-help policy remain server-authoritative.

Milestone 248 advances the bridge to protocol 160 and adds `QueueRetreat`
(command 236). It submits the authentic nonqueued `retreat` command without a
target; the server retains Squad Leader Support III ownership, group and member
eligibility, adjusted Action/Mind cost, 1.822 speed/acceleration application,
30-second cooldown and expiry, and PvP-help authority.

Milestone 249 advances the bridge to protocol 161 and adds
`QueueBoostMorale` (command 237). It submits the authentic nonqueued
`boostmorale` command without a target; the server retains Squad Leader
Defense IV ownership, group eligibility, adjusted three-pool HAM cost,
nine-attribute wound conservation, redistribution, and PvP-help authority.

Milestone 250 advances the bridge to protocol 162 and adds `QueueSteadyAim`
(command 238). It submits the authentic nonqueued Squad Leader command while
the server owns group authority, adjusted HAM, ranged filtering, and the
five-minute `private_aim` modifier.

Milestone 251 advances the bridge to protocol 164 and adds targeted
`QueueApplyPoison` and `QueueApplyDisease` actions (commands 239 and 240).
They submit the authentic nonqueued Combat Medic commands with an explicit
target OID; the server remains authoritative for ownership, organic/PvP/LOS
admission, medicine selection, range, Mind cost, recovery, DOT resistance,
area targeting, combat effects, XP, and charge consumption.

Milestone 252 advances the bridge to protocol 165 and adds `QueueAreaTrack`
and `SelectAreaTrackType` (commands 241 and 242). The queue action submits the
authentic nonqueued Ranger command. The selector accepts only the exact
`skl_use:scan_type_d` production page, chooses one real row, and dispatches
the mediator's ordinary selection and OK callbacks; the server remains
authoritative for skill tiers, cooldown, movement/combat aborts, scan range,
candidate filters, direction, distance, and result construction.

Milestone 255 advances the bridge to protocol 176 and adds
`QueueActionShot1` and `ActionShot1WeaponStatus` (commands 256 and 257). The
status route proves a concrete CDEF carbine against mask `0x00000002`; the
queue route submits the production `actionShot1` command while the server
remains authoritative for adjusted HAM, Action-only damage and bleeding,
posture defense, posture transition, and recovery.

Milestone 256 advances the bridge to protocol 177 and adds
`QueueActionShot2` and `ActionShot2WeaponStatus` (commands 258 and 259). The
same identity-bound CDEF carbine proves mask `0x00000002`; the server remains
authoritative for the 15-degree cone, adjusted HAM, Action-only damage and
bleeding, `sapblast` prose, posture transition, and recovery.

Milestone 257 advances the bridge to protocol 178 and closes the two remaining
Marksman-novice attacks with `QueueOverChargeShot1`,
`OverChargeShot1WeaponStatus`, `QueuePointBlankSingle1`, and
`PointBlankSingle1WeaponStatus` (commands 260 through 263). The reversible
CDEF rifle proves aggregate-ranged mask `0x08000000`; the server remains
authoritative for exact HAM costs, RANDOM pool selection, the 12-meter
point-blank boundary, direct damage, combat prose, and generated animation.

Milestone 258 advances the bridge to protocol 179 and restores the two
Marksman support attacks with `QueueThreatenShot`, `ThreatenShotWeaponStatus`,
`QueueWarningShot`, and `WarningShotWeaponStatus` (commands 264 through 267).
The reversible CDEF rifle proves aggregate-ranged mask `0x08000000`; the
server remains authoritative for exact HAM costs, RANDOM pool selection,
direct damage, `threatenshot`/`warningshot` prose, and their distinct
generated ranged/intensity animation semantics.

Milestone 259 advances the bridge to protocol 180 and adds `QueueAim` and
`AimWeaponStatus` at commands 268/269. The reversible CDEF rifle proves the
aggregate-ranged mask before the native client queues the production command;
the server remains authoritative for the 12/0/0 adjusted HAM cost, five-second
`STATE_AIMING`/`private_aim` lifecycle, no-refresh repeat rule, expiry, and
consumption by the next successful combat action.

Milestone 260 advances the bridge to protocol 181 and adds
`QueueSuppressionFire1` and `SuppressionFire1WeaponStatus` at commands
270/271. The reversible CDEF rifle proves the aggregate-ranged mask before
the native client queues production `suppressionFire1`; the server remains
authoritative for exact HAM costs, Health damage, combat prose, exact
posture-down playback, state application, defense, and timed recovery.

Milestone 261 advances the bridge to protocol 182 and adds queue and
generated-weapon status routes for `rollShot`, `diveShot`, and `kipUpShot` at
commands 272-277. The reversible fixture exposes the retained Pistol II
grants, and authenticated clients exercise the complete
upright-to-crouched-to-prone-to-upright acrobatic posture lifecycle.

Milestone 262 advances the bridge to protocol 183 and adds `QueueTakeCover`
and `TakeCoverWeaponStatus` at commands 278/279. The identity-bound fixture
exposes the retained Marksman Rifle II ownership while the native client
queues production `takeCover`; the server remains authoritative for the
Quickness-adjusted Action debit, combat chance, dizzy-fall branch, cover
state, persistence evidence, and reversible cleanup.

Milestone 263 advances the bridge to protocol 184 and adds
`QueueFullAutoSingle1` and `FullAutoSingle1WeaponStatus` at commands 280/281.
The identity-bound CDEF carbine path proves the retained Marksman Carbine II
grant while the authenticated client queues production `fullAutoSingle1`;
the server remains authoritative for exact costs, random-pool damage,
full-auto prose and animation, three independent defended timed-state
attempts, persistence evidence, and ownership-safe cleanup.

Milestone 264 advances the bridge to protocol 185 and adds queue and
generated-weapon status routes for `scatterShot1` and `scatterShot2` at
commands 282-285. The identity-bound CDEF-carbine path proves retained
Carbineer Accuracy I/III ownership while authenticated clients exercise the
pinned Core3 independent Health/Action/Mind distribution rolls. The server
remains authoritative for exact costs, direct per-pool damage, historical
spillover, prose, animation, persistence evidence, and ownership-safe cleanup.

Milestone 265 advances the bridge to protocol 186 and adds queue and
generated-weapon status routes for `legShot2` and `legShot3` at commands
286-289. The identity-bound CDEF-carbine path proves retained Marksman
Carbine III and Carbineer Speed I ownership while the server remains
authoritative for Action-pool damage, exact costs, `legshot`/`kneecapshot`
prose, exact `test_homing` animation, defended timed stun effects,
persistence evidence, and ownership-safe cleanup.

Milestone 266 advances the bridge to protocol 187 and adds queue and
generated-weapon status routes for Carbineer-novice `fullAutoSingle2` at
commands 290-291. The server remains authoritative for RANDOM-pool damage,
exact costs, `s_auto` prose, generated `fire_7_single` animation, three
independent defended timed-state attempts, persistence evidence, and
ownership-safe cleanup.

Milestone 267 advances the bridge to protocol 188 and adds queue and
weapon-status routes for Carbineer Ability IV `suppressionFire2` at commands
292-293. The server remains authoritative for RANDOM-pool damage, exact
costs, `sup_fire` prose, exact posture-down animation, defended native
posture-down/recovery behavior, persistence evidence, and ownership-safe
cleanup.

Milestone 268 advances the bridge to protocol 189 and adds queue and
weapon-status routes for Carbineer Accuracy II `wildShot1` at commands
294-295. The server remains authoritative for RANDOM-pool damage, exact
costs, `wildshot` prose, generated `fire_7_single` animation, the defended
50-percent native stun attempt, persistence evidence, and ownership-safe
cleanup.

Milestone 269 advances the bridge to protocol 190 and adds queue and
weapon-status routes for Carbineer Accuracy IV `wildShot2` at commands
296-297. The server remains authoritative for the 30-degree cone,
RANDOM-pool damage, exact costs, `widewildshot` prose, generated
`fire_7_single` animation, the defended 50-percent native stun attempt,
persistence evidence, and ownership-safe cleanup.

Milestone 270 advances the bridge to protocol 191 and adds queue and
weapon-status routes for Carbineer Support I `fullAutoArea1` at commands
298-299. The server remains authoritative for the Patch 12 zero-time queue,
30-degree cone, RANDOM-pool damage, exact costs, `areashot` prose, generated
`fire_area` intensity animation, three defended native state attempts,
persistence evidence, and ownership-safe cleanup.

Milestone 271 advances the bridge to protocol 192 and adds queue and
weapon-status routes for Carbineer Support II `chargeShot1` at commands
300-301. The server remains authoritative for Patch 12's 1.5-second queue,
RANDOM-pool damage, exact costs, `chargeshot` prose, the `charge` animation,
native knockdown defense/recovery, persistence evidence, and ownership-safe
cleanup.

Milestone 272 advances the bridge to protocol 193 and adds queue and
weapon-status routes for Carbineer Support III `fullAutoArea2` at commands
302-303. The server remains authoritative for Patch 12's zero-time queue,
RANDOM-pool cone damage, exact costs, `a_auto` prose, generated `fire_area`
intensity animation, three defended native state attempts, persistence
evidence, and ownership-safe cleanup.

Milestone 273 advances the bridge to protocol 194 and adds queue and
weapon-status routes for Carbineer Support IV `chargeShot2` at commands
304-305. The server remains authoritative for Patch 12's 1.5-second queue,
RANDOM-pool cone damage, exact costs, `chargeblast` prose, the `charge`
animation, native knockdown defense/recovery, persistence evidence, and
ownership-safe cleanup.

Milestone 274 advances the bridge to protocol 195 and adds queue and
weapon-status routes for Rifleman novice `strafeShot1` at commands 306-307.
The server remains authoritative for Patch 12's 1.5-second queue,
RANDOM-pool rifle damage, exact costs, `strafeshot` prose, generated
`fire_5_special_single` animation, remove-cover resolution, the ten-second
next-attack delay, persistence evidence, and ownership-safe cleanup.

Milestone 275 advances the bridge to protocol 196 and adds queue and
weapon-status routes for Rifleman Accuracy I `mindShot2` at commands 308-309.
The server remains authoritative for Patch 12's 1.5-second queue, MIND-pool
rifle damage, exact HAM costs, `mindbender` prose, generated
`fire_1_special_single` animation, native bleeding resolution, persistence
evidence, and ownership-safe cleanup.

Milestone 276 advances the bridge to protocol 197 and adds queue and
weapon-status routes for Rifleman Accuracy III `surpriseShot` at commands
310-311. The server remains authoritative for Patch 12's 1.5-second queue,
3x RANDOM-pool rifle damage, exact costs, `surpriseshot` prose, generated
`fire_1_special_single` animation, persistence evidence, and ownership-safe
cleanup.

Milestone 277 advances the bridge to protocol 198 and adds queue and
weapon-status routes for Rifleman Accuracy IV `sniperShot` at commands
312-313. The server remains authoritative for Patch 12's 1.5-second queue,
fixed 135 RANDOM-pool rifle damage, exact costs, incapacitated-target
admission, death-blow semantics, persistence evidence, and ownership-safe
cleanup.

Milestone 278 advances the bridge to protocol 199 and adds targeted
`QueueConcealShot` plus `ConcealShotWeaponStatus` routes at commands 314-315.
The bridge transports only the fixture-owned AI OID; production combat owns
damage, miss accounting, distance/posture thresholds, persistence evidence,
threat removal, and ownership-safe cleanup.

Milestone 279 advances the bridge to protocol 200 and adds
`QueueFlurryShot1` plus `FlurryShot1WeaponStatus` at commands 316-317. The
identity-bound production queue remains server-authoritative for exact rifle
admission, random-pool damage, generated animation, the defended native dizzy
attempt, persistence evidence, and reversible cleanup.

Milestone 280 advances the bridge to protocol 201 and adds
`QueueFlurryShot2` plus `FlurryShot2WeaponStatus` at commands 318-319. The
bounded production queue remains server-authoritative for exact rifle
admission, 15-degree cone selection, random-pool damage, generated intensity
animation, defended native dizzy application, persistence, and cleanup.

Milestone 281 advances the bridge to protocol 202 and adds
`QueueStrafeShot2` plus `StrafeShot2WeaponStatus` at commands 320-321. The
bounded production queue remains server-authoritative for Rifleman-master
ownership, exact rifle admission, 60-degree cone selection, random-pool
damage, generated intensity animation, cover removal, delay, and cleanup.

Milestone 282 advances the bridge to protocol 203 and adds
`QueueStartleShot1` plus `StartleShot1WeaponStatus` at commands 322-323. The
bounded production queue remains server-authoritative for retained Rifleman
ability ownership, exact rifle admission, random-pool damage, posture-up
transition and recovery behavior, persistence, and reversible cleanup.

Milestone 283 advances the bridge to protocol 204 and adds
`QueueStartleShot2` plus `StartleShot2WeaponStatus` at commands 324-325. The
bounded production queue remains server-authoritative for Rifleman Ability IV
ownership, exact rifle admission, 60-degree cone selection, random-pool
damage, posture-up transition and recovery behavior, persistence, and
reversible cleanup.

Milestone 284 advances the bridge to protocol 205 and adds
`QueueFlushingShot1` plus `FlushingShot1WeaponStatus` at commands 326-327.
The bounded production queue remains server-authoritative for Rifleman Ability
I ownership, exact rifle admission, random-pool damage, ordered STUN and
posture-up application, recovery behavior, persistence, and reversible
cleanup.

Milestone 285 advances the bridge to protocol 206 and adds
`QueueFlushingShot2` plus `FlushingShot2WeaponStatus` at commands 328-329.
The bounded production queue remains server-authoritative for Rifleman Ability
III ownership, exact rifle admission, 15-degree cone selection, random-pool
damage, ordered STUN and posture-up application, recovery behavior,
persistence, and reversible cleanup.

Milestone 286 advances the bridge to protocol 207 and adds
`QueuePolearmLunge1` plus `PolearmLunge1WeaponStatus` at commands 330-331.
The bounded production queue remains server-authoritative for Brawler novice
ownership, exact polearm admission, random-pool damage, posture-down
application and recovery, restart persistence, and reversible cleanup.

Milestone 287 advances the bridge to protocol 208 and adds
`QueueUnarmedLunge1` plus `UnarmedLunge1WeaponStatus` at commands 332-333.
The bounded production queue remains server-authoritative for Brawler novice
ownership, exact unarmed admission, random-pool damage, posture-down
application and recovery, restart persistence, and reversible cleanup.

Milestone 288 advances the bridge to protocol 209 and adds
`QueueMelee1hLunge1` plus `Melee1hLunge1WeaponStatus` at commands 334-335.
The bounded production queue remains server-authoritative for Brawler novice
ownership, exact one-handed admission, random-pool damage, posture-down
application and recovery, restart persistence, and reversible cleanup.

Milestone 289 advances the bridge to protocol 210 and adds
`QueueMelee2hLunge1` plus `Melee2hLunge1WeaponStatus` at commands 336-337.
The bounded production queue remains server-authoritative for Brawler novice
ownership, exact two-handed admission, random-pool damage, posture-down
application and recovery, restart persistence, and reversible cleanup.

Milestone 290 advances the bridge to protocol 211 and adds
`QueueMelee1hDizzyHit1` plus `Melee1hDizzyHit1WeaponStatus` at commands
338-339. The bounded production queue remains server-authoritative for the
retained Brawler one-hand tier-three chain, exact one-handed admission,
random-pool damage, DIZZY application, restart persistence, and reversible
cleanup.

Milestone 291 advances the bridge to protocol 212 and adds
`QueueMelee2hSweep1` plus `Melee2hSweep1WeaponStatus` at commands 340-341.
The bounded production queue remains server-authoritative for the retained
Brawler two-hand tier-three chain, exact two-handed admission, random-pool
damage, posture-down application and active recovery, restart persistence,
and reversible cleanup.

Milestone 292 advances the bridge to protocol 213 and adds
`QueuePolearmStun1` plus `PolearmStun1WeaponStatus` at commands 342-343. The
bounded production queue remains server-authoritative for the retained
Brawler polearm tier-three chain, exact polearm admission, random-pool damage,
30-second STUN application, restart persistence, and reversible cleanup.

Milestone 293 advances the bridge to protocol 214 and adds
`QueueUnarmedBlind1` plus `UnarmedBlind1WeaponStatus` at commands 344-345. The
bounded production queue remains server-authoritative for the retained
Brawler unarmed tier-three chain, exact unarmed admission, random-pool damage,
50-second BLIND application, restart persistence, and reversible cleanup.

Milestone 294 advances the bridge to protocol 215 and adds
`QueueUnarmedStun1` plus `UnarmedStun1WeaponStatus` at commands 346-347. The
bounded production queue remains server-authoritative for the retained
Brawler unarmed tier-two chain, exact unarmed admission, random-pool damage,
generated-intensity animation, 60-second STUN application, restart
persistence, and reversible cleanup.

Milestone 295 advances the bridge to protocol 216 and adds
`QueueIntimidate1` plus `Intimidate1WeaponStatus` at commands 348-349. The
bounded production queue remains server-authoritative for the retained
Brawler novice command, zero-damage `NO_ATTRIBUTE` delivery, the Core3
`intimidate` accuracy skill, 30-second `STATE_INTIMIDATED` application,
restart persistence, and reversible cleanup.

Milestone 296 advances the bridge to protocol 217 and adds
`QueueIntimidate2` plus `Intimidate2WeaponStatus` at commands 350-351. The
bounded production queue remains server-authoritative for the retained
Brawler master command, master `intimidate=20` accuracy, zero-damage
`NO_ATTRIBUTE` delivery, 120-second `STATE_INTIMIDATED` application,
restart persistence, and reversible cleanup.

Milestone 297 advances the bridge to protocol 218 and adds `QueueWarcry1`
plus `Warcry1WeaponStatus` at commands 352-353. The bounded production queue
remains server-authoritative for the retained Brawler novice command, a
24-meter/15-degree zero-damage cone, resisted ten-second next-attack delay,
restart persistence, and reversible cleanup.

Milestone 298 advances the bridge to protocol 219 and adds `QueueWarcry2`
plus `Warcry2WeaponStatus` at commands 354-355. The bounded production queue
remains server-authoritative for the retained Brawler master command, a
24-meter/30-degree zero-damage cone, resisted twenty-second next-attack delay,
restart persistence, and reversible cleanup.

Milestone 299 advances the bridge to protocol 220 and adds the four Brawler
master Lunge II queue/status pairs at commands 356-363: polearm, unarmed,
one-handed, and two-handed. The bounded production queue remains
server-authoritative for exact weapon admission, per-command HAM and damage
multipliers, random-pool damage, knockdown/recovery behavior, restart
persistence, and reversible cleanup.

## Additional Dependencies
Most of the development tools use the [Qt framework](https://www.qt.io/) to render their user interface. You may wish to install the [Qt VS Tools for Visual Studio](https://marketplace.visualstudio.com/items?itemName=TheQtCompany.QtVisualStudioTools-19123) to ease development. 

## Known Issues
* For the debug build, and possibly the optimized versions, you will get linker errors about libmozilla, and in release, possibly Vivox - if you alter the project settings you can disable this from killing the output of an exe, as libmozilla is only needed for the ingame browser.
* Other linker errors sometimes throw, you have to work on these case by case. Please pull request any changes you make.
* cmd.exe issues sometimes occur as SOE originally had the build setup copying files to a proper game bin directory. You can just remove these from projects that complain about them, just copy the output files manually.
* Plenty of warnings and sometimes even errors regarding deprecated libs happen. Fixes for these are case by case.

## Galaxies Reborn community

Join the [Galaxies Reborn Discord](https://discord.gg/CEwKVvKxK5) for project discussion, support, and announcements.
