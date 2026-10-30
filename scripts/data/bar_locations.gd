class_name BarLocations
extends RefCounted
## Os pontos onde o Pinguço pode ter bar. Cada um é um bar novo: tema visual completo
## (paredes, piso, móveis, decoração, vista lá de fora) e economia própria.
## A área de trabalho atrás do balcão tem sempre o mesmo formato, então a jogabilidade
## e os testes não dependem do ponto.

const ORDER: Array[StringName] = [&"boteco", &"choperia", &"praia"]

const DATA := {
	&"boteco": {
		"name": "Bar do Pinguço",
		"place": "Vila Esperança",
		"subtitle": "desde 1987  •  gelada de verdade",
		"blurb": "O buteco de bairro onde tudo começou: mesa de plástico, sinuca e fiado proibido.",
		# requisitos para mudar PARA este ponto
		"min_day": 1, "min_reforms": 0, "cost": 0,
		# economia
		"price_mult": 1.0, "cost_mult": 1.0, "base_seats": 4, "spawn_mult": 1.0,
		# visual
		"wall": {"tile_a": Color(0.93, 0.95, 0.92), "tile_b": Color(0.35, 0.7, 0.62),
			"paint": Color(0.98, 0.84, 0.45), "stripe": Color(0.16, 0.5, 0.36), "tile_top": 1.25},
		"wall_new": {"tile_a": Color(0.97, 0.98, 0.96), "tile_b": Color(0.22, 0.62, 0.78),
			"paint": Color(1.0, 0.68, 0.36), "stripe": Color(0.12, 0.36, 0.6), "tile_top": 1.25},
		"floor": {"pattern": 0},
		"floor_new": {"pattern": 1, "a": Color(0.92, 0.9, 0.84), "b": Color(0.62, 0.14, 0.12)},
		"counter_tile": [Color(0.18, 0.5, 0.38), Color(0.24, 0.6, 0.45)],
		"wood": Color(0.55, 0.3, 0.16), "wood_dark": Color(0.36, 0.19, 0.1),
		"ceiling": Color(0.5, 0.32, 0.2),
		"fridge": Color(0.85, 0.15, 0.15), "fridge_label": "GELADA",
		"stool": Color(0.85, 0.15, 0.15),
		"ambient": Color(0.85, 0.62, 0.45), "fog": Color(0.55, 0.38, 0.25),
		"outside": 0, "sidewalk": Color(0.45, 0.45, 0.48),
		# céu do fim de tarde até a noite fechada (ver BarAtmosphere)
		"sky": {
			"top_dusk": Color(0.13, 0.15, 0.32), "horizon_dusk": Color(0.86, 0.44, 0.22),
			"top_night": Color(0.028, 0.032, 0.075), "horizon_night": Color(0.17, 0.11, 0.15),
			"sun_dusk": Color(1.0, 0.56, 0.26), "sun_night": Color(0.52, 0.64, 1.0),
			"sun_energy": 1.0, "moon_energy": 0.22, "sun_yaw": 155.0,
		},
		"grade_shadow": Color(0.11, 0.08, 0.11), "grade_light": Color(1.0, 0.96, 0.88),
		"sign_bg": Color(0.12, 0.08, 0.16), "sign_fg": Color(1.6, 1.15, 0.45), "sign_sub": Color(1.6, 0.6, 0.8),
		"posters": [
			["FIADO?\nSÓ AMANHÃ!", Color(1.0, 0.95, 0.75), Color(0.86, 0.2, 0.2)],
			["PROIBIDO\nFALAR DE\nPOLÍTICA", Color(0.98, 0.85, 0.3), Color(0.16, 0.09, 0.06)],
			["TEM\nTORRESMO", Color(0.95, 0.4, 0.2), Color(1.0, 0.98, 0.9)],
			["CERVEJA\nESTUPIDAMENTE\nGELADA", Color(0.2, 0.45, 0.85), Color(1.0, 0.98, 0.9)],
			["PENDURA\nNÃO!", Color(0.95, 0.95, 0.9), Color(0.86, 0.2, 0.2)],
		],
	},
	&"choperia": {
		"name": "Choperia do Pinguço",
		"place": "Centro da cidade",
		"subtitle": "chopp tirado na pressão  •  happy hour",
		"blurb": "Ponto no Centro: painel de madeira, chopeira de cobre e a turma do escritório. Preços 50% maiores.",
		"min_day": 5, "min_reforms": 3, "cost": 1200,
		"price_mult": 1.5, "cost_mult": 1.6, "base_seats": 5, "spawn_mult": 0.9,
		"wall": {"tile_a": Color(0.36, 0.2, 0.12), "tile_b": Color(0.3, 0.16, 0.1),
			"paint": Color(0.2, 0.32, 0.24), "stripe": Color(0.78, 0.55, 0.25), "tile_top": 1.35},
		"wall_new": {"tile_a": Color(0.48, 0.27, 0.15), "tile_b": Color(0.42, 0.23, 0.13),
			"paint": Color(0.52, 0.12, 0.14), "stripe": Color(0.95, 0.72, 0.3), "tile_top": 1.35},
		"floor": {"pattern": 1, "a": Color(0.86, 0.84, 0.78), "b": Color(0.12, 0.12, 0.13)},
		"floor_new": {"pattern": 2, "a": Color(0.5, 0.3, 0.16), "b": Color(0.42, 0.24, 0.12)},
		"counter_tile": [Color(0.3, 0.16, 0.09), Color(0.36, 0.2, 0.11)],
		"wood": Color(0.42, 0.22, 0.11), "wood_dark": Color(0.24, 0.12, 0.07),
		"ceiling": Color(0.22, 0.13, 0.09),
		"fridge": Color(0.16, 0.38, 0.24), "fridge_label": "CHOPP",
		"stool": Color(0.45, 0.22, 0.1),
		"ambient": Color(0.9, 0.65, 0.42), "fog": Color(0.45, 0.32, 0.22),
		"outside": 1, "sidewalk": Color(0.38, 0.38, 0.42),
		"sky": {
			"top_dusk": Color(0.11, 0.12, 0.28), "horizon_dusk": Color(0.8, 0.4, 0.3),
			"top_night": Color(0.035, 0.03, 0.062), "horizon_night": Color(0.28, 0.15, 0.13),
			"sun_dusk": Color(1.0, 0.6, 0.32), "sun_night": Color(0.6, 0.66, 0.95),
			"sun_energy": 0.9, "moon_energy": 0.26, "sun_yaw": 140.0,
		},
		"grade_shadow": Color(0.09, 0.07, 0.1), "grade_light": Color(1.0, 0.94, 0.82),
		"sign_bg": Color(0.08, 0.14, 0.1), "sign_fg": Color(1.7, 1.25, 0.5), "sign_sub": Color(0.9, 1.6, 0.9),
		"posters": [
			["HAPPY HOUR\n18H ÀS 20H", Color(0.95, 0.72, 0.3), Color(0.16, 0.09, 0.06)],
			["CHOPP\nCLARO\nE ESCURO", Color(0.2, 0.32, 0.24), Color(1.0, 0.95, 0.82)],
			["PETISCO\nDA CASA:\nBOLINHO", Color(0.52, 0.12, 0.14), Color(1.0, 0.95, 0.82)],
			["COLARINHO\nDE DOIS\nDEDOS", Color(1.0, 0.98, 0.9), Color(0.42, 0.22, 0.11)],
			["RESERVE SUA\nMESA", Color(0.95, 0.95, 0.9), Color(0.16, 0.38, 0.24)],
		],
	},
	&"praia": {
		"name": "Pinguço Beach Club",
		"place": "Orla da praia",
		"subtitle": "pé na areia  •  sol, mar e caipirinha",
		"blurb": "Quiosque chique na orla: piso de deck, guarda-sol e o mar lá fora. Preços dobrados.",
		"min_day": 10, "min_reforms": 4, "cost": 3200,
		"price_mult": 2.2, "cost_mult": 2.4, "base_seats": 5, "spawn_mult": 0.8,
		"wall": {"tile_a": Color(0.95, 0.92, 0.82), "tile_b": Color(0.42, 0.78, 0.82),
			"paint": Color(0.98, 0.94, 0.86), "stripe": Color(0.15, 0.55, 0.65), "tile_top": 1.1},
		"wall_new": {"tile_a": Color(1.0, 0.97, 0.9), "tile_b": Color(1.0, 0.55, 0.42),
			"paint": Color(0.6, 0.9, 0.92), "stripe": Color(1.0, 0.75, 0.25), "tile_top": 1.1},
		"floor": {"pattern": 3, "a": Color(0.93, 0.82, 0.6), "b": Color(0.85, 0.72, 0.5)},
		"floor_new": {"pattern": 2, "a": Color(0.72, 0.55, 0.38), "b": Color(0.64, 0.47, 0.32)},
		"counter_tile": [Color(0.12, 0.55, 0.62), Color(0.95, 0.95, 0.9)],
		"wood": Color(0.78, 0.62, 0.4), "wood_dark": Color(0.55, 0.4, 0.24),
		"ceiling": Color(0.78, 0.65, 0.38),
		"fridge": Color(0.1, 0.6, 0.68), "fridge_label": "GELADA",
		"stool": Color(1.0, 0.55, 0.3),
		"ambient": Color(0.78, 0.76, 0.86), "fog": Color(0.34, 0.38, 0.52),
		"outside": 2, "sidewalk": Color(0.95, 0.86, 0.64),
		# quiosque: sem paredes na frente nem nas laterais, telhado de palha sobre pilares
		# e planta menor que a dos salões fechados (o salão vira a areia lá fora).
		"open": true,
		"room": {"min": Vector3(-4.5, 0.0, -2.6), "max": Vector3(4.5, 2.75, 3.6)},
		"sky": {
			"top_dusk": Color(0.15, 0.22, 0.46), "horizon_dusk": Color(1.0, 0.52, 0.26),
			"top_night": Color(0.04, 0.08, 0.2), "horizon_night": Color(0.16, 0.26, 0.44),
			"sun_dusk": Color(1.0, 0.6, 0.3), "sun_night": Color(0.62, 0.74, 1.0),
			"sun_energy": 1.5, "moon_energy": 0.8, "sun_yaw": 185.0,
		},
		"grade_shadow": Color(0.07, 0.11, 0.18), "grade_light": Color(1.0, 0.95, 0.86),
		"sign_bg": Color(0.06, 0.2, 0.26), "sign_fg": Color(0.6, 1.6, 1.7), "sign_sub": Color(1.7, 0.9, 0.5),
		"posters": [
			["ÁGUA DE\nCOCO\nGELADA", Color(0.42, 0.78, 0.4), Color(1.0, 0.98, 0.9)],
			["PROIBIDO\nAREIA NO\nBALCÃO", Color(1.0, 0.75, 0.25), Color(0.16, 0.09, 0.06)],
			["LUAU\nSEXTA", Color(0.06, 0.2, 0.26), Color(0.6, 0.95, 1.0)],
			["CAIPIRINHA\nDE FRUTA\nDA ESTAÇÃO", Color(1.0, 0.55, 0.42), Color(1.0, 0.98, 0.9)],
			["SALVA-VIDAS\nNÃO BEBE", Color(0.95, 0.2, 0.2), Color(1.0, 0.98, 0.9)],
		],
	},
}


static func get_location(id: StringName) -> Dictionary:
	return DATA.get(id, DATA[&"boteco"])


## O ponto seguinte na escada de mudanças ("" se já está no último).
static func next_after(id: StringName) -> StringName:
	var i := ORDER.find(id)
	return ORDER[i + 1] if i >= 0 and i + 1 < ORDER.size() else &""
