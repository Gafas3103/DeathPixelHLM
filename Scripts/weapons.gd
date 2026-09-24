extends RefCounted

## Definición de las armas. Para balancear o agregar una basta con editar LIST
## (mag, max_reserve, fire_rate, auto, damage, pellets, spread, speed, lifetime, reload, noise, shake).

const RIFLE := 0
const SHOTGUN := 1
const KNIFE := 2

const LIST := [
	{
		"id": "rifle", "name": "RIFLE", "melee": false,
		"mag": 20, "max_reserve": 120, "fire_rate": 0.1, "auto": true,
		"damage": 22.0, "pellets": 1, "spread": 2.0, "speed": 900.0, "lifetime": 2.0,
		"reload": 1.1, "noise": 180.0, "shake": 1.2, "ads_mult": 0.35,
	},
	{
		"id": "shotgun", "name": "ESCOPETA", "melee": false,
		"mag": 6, "max_reserve": 36, "fire_rate": 0.8, "auto": false,
		"damage": 13.0, "pellets": 8, "spread": 9.0, "speed": 780.0, "lifetime": 0.42,
		"reload": 1.5, "noise": 420.0, "shake": 4.5, "ads_mult": 0.7,
	},
	{
		"id": "knife", "name": "CUCHILLO", "melee": true,
		"mag": 0, "max_reserve": 0, "fire_rate": 0.42, "auto": false,
		"damage": 45.0, "pellets": 0, "spread": 0.0, "speed": 0.0, "lifetime": 0.0,
		"reload": 0.0, "noise": 0.0, "shake": 0.0, "ads_mult": 1.0,
	},
]
