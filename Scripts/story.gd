extends RefCounted

const HERO := "VEGA"
const HANDLER := "CENTRAL"
const BOSS := "CONTRATISTA"
const BOSS_NAME := "EL CONTRATISTA"
const BOSS_TITLE := "EL QUE APAGA LOS PÍXELES"

const SPEAKER_COLORS := {
	"VEGA": Color("#E9E5D8"),
	"CENTRAL": Color("#22D3EE"),
	"CONTRATISTA": Color("#EF3E4A"),
}

const PROLOGUE: Array[String] = [
	"CIUDAD MERIDIANA · 03:12 A. M.\n\nHace seis semanas alguien entró a mi casa mientras yo estaba de guardia.",
	"No se llevaron nada.\n\nSolo a mi familia.",
	"En la pared dejaron un cuadro pintado de rojo. Un píxel.\n\nEs la firma del Contratista: cada encargo es un punto rojo en su pantalla. Cuando el trabajo termina, el punto se apaga.",
	"El departamento cerró el caso en dos días.\n\nAlguien de adentro quería que se cerrara rápido.",
	"Esta noche dejé la placa sobre el escritorio. Me quedé con el uniforme, el rifle y una sola pista: la calle donde sus hombres cobran los encargos.",
	"Soy el último píxel rojo en su pantalla.\n\nY no pienso apagarme.",
]

const EPILOGUE: Array[String] = [
	"El Contratista vino en persona a apagar su último píxel.\n\nFue el suyo el que se apagó.",
	"Esa madrugada, uno por uno, los puntos rojos de su pantalla se fueron quedando quietos. Ya nadie iba a cobrar por ellos.",
	"El expediente 0417 llegó a la prensa antes del amanecer. Con él salió el nombre del informante que vendía nuestras rutas.",
	"Ríos me devolvió la placa en la puerta del edificio.\n\nNo la acepté.",
	"Hay más pantallas como esa en la ciudad, con más puntos rojos esperando.\n\nYo sigo encendido.",
]

const CHAPTERS := [
	{
		"title": "CAPÍTULO 1 · LA CALLE",
		"location": "CALLE PRINCIPAL · 03:40 A. M.",
		"briefing": "Los hombres del Contratista cobran sus encargos en esta calle. Si alguno sabe quién dio la orden contra mi familia, la llevará encima.",
		"note_title": "ORDEN CONFIDENCIAL",
		"note_text": "La familia del objetivo ya fue eliminada.\n\nEl siguiente en la lista es él: el agente que sigue nuestro rastro. Encuéntrenlo y acaben con él antes de que llegue a la sede.\n\nNo dejen testigos ni pruebas. Los demás equipos ya están en posición.",
		"note_signature": "— El Contratista",
		"radio_start": [
			["CENTRAL", "Vega, habla Ríos. Esto no es oficial: nadie en la central sabe que te estoy ayudando."],
			["CENTRAL", "Hay hombres armados en toda la calle. El último que caiga tendrá la llave del cuarto de cobros."],
		],
		"radio_clear": [
			["VEGA", "Llevaba una nota encima. Tengo que leerla."],
		],
		"radio_key": [
			["CENTRAL", "Esa orden lleva su firma, Vega. Y habla de ti. Abre el cuarto y sal de ahí."],
		],
		"radio_door": [],
	},
	{
		"title": "CAPÍTULO 2 · APAGÓN",
		"location": "COMPLEJO INDUSTRIAL · 04:55 A. M.",
		"briefing": "La nota traía el sello de una nave industrial. Cortaron la luz antes de que yo llegara: saben que voy.",
		"note_title": "REGISTRO DE PAGOS",
		"note_text": "Encargo 0417: familia Vega. PAGADO.\n\nComisión del informante del departamento: 40 %. En efectivo, como siempre.\n\nEl informante pide que el agente no llegue vivo al edificio de cuartos. Ahí guardamos los expedientes.",
		"note_signature": "— Contabilidad",
		"radio_start": [
			["CENTRAL", "Cortaron la electricidad de todo el complejo. Te están esperando a oscuras."],
			["CENTRAL", "Usa la oscuridad. Con la linterna apagada casi no te verán... pero cada disparo te delata."],
		],
		"radio_clear": [
			["VEGA", "Un informante dentro del departamento. Alguien de los nuestros."],
		],
		"radio_key": [
			["CENTRAL", "...Ve al edificio de cuartos. Yo averiguo quién es."],
		],
		"radio_door": [],
	},
	{
		"title": "CAPÍTULO 3 · ALARMA",
		"location": "EDIFICIO DE CUARTOS · 05:30 A. M.",
		"briefing": "Aquí guardan un expediente por cada encargo. La sala del fondo tiene los archivos, y el edificio entero está conectado a una alarma.",
		"note_title": "EXPEDIENTE 0417",
		"note_text": "Objetivo: agente Vega, unidad SWAT.\nEstado: ACTIVO. El único píxel que sigue encendido.\n\nEl informante confirma su ruta. Si pasa de aquí, me encargo yo en persona.\n\nNadie apaga mis píxeles más que yo.",
		"note_signature": "— C.",
		"radio_start": [
			["CENTRAL", "El edificio tiene alarma. Cuando toques algo importante, va a sonar."],
			["CENTRAL", "Cuando suene tendrás poco tiempo antes de que llegue todo su ejército."],
		],
		"radio_clear": [
			["VEGA", "Mi expediente. Sabía cada paso que iba a dar."],
		],
		"radio_key": [
			["CENTRAL", "¡Saltó la alarma! Vienen refuerzos. ¡Sal de ahí ya!"],
		],
		"radio_door": [],
	},
	{
		"title": "CAPÍTULO 4 · CACERÍA",
		"location": "LOS MUELLES · 06:10 A. M.",
		"briefing": "El informante me vendió otra vez: todos saben dónde estoy. Los muelles son la única ruta hacia la sede.",
		"note_title": "ÚLTIMO PAGO",
		"note_text": "Salgado:\n\nTu parte está en el contenedor doce. Si Vega llega a la sede, tu nombre sale en el expediente junto al mío.\n\nAsegúrate de que no llegue.",
		"note_signature": "— C.",
		"radio_start": [
			["CENTRAL", "Vega... el informante es alguien de mi equipo. Tu posición está en todas sus radios."],
			["CENTRAL", "No te quedes quieto. Cada vez que te localicen, irán todos hacia ti."],
		],
		"radio_clear": [
			["VEGA", "Salgado. El comisario Salgado."],
		],
		"radio_key": [
			["CENTRAL", "Lo tengo. Yo me encargo de Salgado. Tú termina esto."],
		],
		"radio_door": [],
	},
	{
		"title": "CAPÍTULO 5 · LA SEDE",
		"location": "TORRE MERIDIANA · 06:45 A. M.",
		"briefing": "En lo alto de esta torre está la pantalla con todos los puntos rojos de la ciudad.\n\nY él.",
		"note_title": "",
		"note_text": "",
		"note_signature": "",
		"radio_start": [
			["CENTRAL", "Estás en su casa, Vega. Sus mejores hombres están aquí."],
			["CENTRAL", "Pase lo que pase, no dejes que se escape."],
		],
		"radio_clear": [],
		"radio_key": [
			["VEGA", "Se acabó el camino. Solo falta una puerta."],
		],
		"radio_door": [],
	},
]

const BOSS_INTRO := [
	["CONTRATISTA", "Tanto ruido por un solo píxel, agente."],
	["CENTRAL", "¡Es él, Vega! ¡Es el Contratista!"],
	["CONTRATISTA", "Vine a apagarte yo mismo."],
]

const BOSS_ALARM_OFF := [
	["CENTRAL", "Cortó la alarma... quiere hacerlo en persona."],
]

const BOSS_PHASE_LINES := [
	[],
	[["CONTRATISTA", "¿Sabes a cuántos como tú he borrado? Ni recuerdo sus caras."]],
	[["CONTRATISTA", "¡Todos a mí! ¡Quiero ese píxel apagado!"]],
]

const BOSS_DEFEAT := [
	["VEGA", "Tu pantalla se quedó sin píxeles."],
	["CENTRAL", "Se acabó, Vega. Llega a la salida, voy por ti."],
]

const ALARM_EXPIRED := [
	["CENTRAL", "¡Se acabó el tiempo! Llegaron los pesados, Vega. ¡Corre!"],
]

const HUNT_PULSE := [
	["CONTRATISTA", "Ahí estás."],
	["CENTRAL", "¡Te localizaron otra vez! ¡Muévete!"],
	["CONTRATISTA", "Mis hombres ya van por ti, píxel."],
]

const TWIST_START := {
	"apagon": [["VEGA", "Linterna: [L]. Apagada no me ven, pero tampoco veo."]],
	"caceria": [["CENTRAL", "Cada cierto tiempo delatan tu posición. Mantente en movimiento."]],
}


static func chapter(index: int) -> Dictionary:
	if index < 0 or index >= CHAPTERS.size():
		return {}
	return CHAPTERS[index]


static func has_note(index: int) -> bool:
	return String(chapter(index).get("note_text", "")) != ""


static func speaker_color(speaker: String) -> Color:
	return SPEAKER_COLORS.get(speaker, Color("#E9E5D8"))
