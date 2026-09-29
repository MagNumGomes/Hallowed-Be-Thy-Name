extends RefCounted
## Paleta comum: ferro, pergaminho, bronze e sinal ciano.

static func panel(color: Color, border: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = color
	box.border_color = border
	box.set_border_width_all(1)
	box.set_content_margin_all(12.0)
	return box


static func create() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 18
	theme.set_color("font_color", "Label", Color("ded6bd"))
	theme.set_stylebox("panel", "PanelContainer", panel(Color("11191ff2"), Color("806344")))
	for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
		var border := Color("59b4b0") if state in ["hover", "focus"] else Color("806344")
		var background := Color("25373c") if state == "hover" else Color("151c23")
		if state == "focus":
			background = Color.TRANSPARENT
		theme.set_stylebox(state, "Button", panel(background, border))
	theme.set_color("font_color", "Button", Color("ded6bd"))
	theme.set_color("font_disabled_color", "Button", Color("73777a"))
	theme.set_stylebox("background", "ProgressBar", panel(Color("080d12"), Color("493e33")))
	theme.set_stylebox("fill", "ProgressBar", panel(Color("59b4b0"), Color("7ac4bb")))
	return theme
