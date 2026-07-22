--!strict

--[[
	One client-local design-token system for Living Kingdoms interface surfaces.

	Before this, every controller hard-coded its own palette, fonts, corner radii,
	and re-implemented `addCorner` / `addStroke` / label builders, so the interface
	drifted screen to screen. This module is the single home for those tokens and a
	few small pure builders, so a touch-up made here reaches every screen that
	adopts it.

	It is presentation only. It holds no gameplay authority, reads no server state,
	owns no connection or timer, and cannot change any consequential fact. The
	builders only construct and style GuiObjects the caller then owns.
]]

local InterfaceTheme = {}

-- Palette. A cold ash/void ground with one warm amber accent for "act here" and a
-- single danger red, so the eye learns two signal colours rather than many.
InterfaceTheme.Palette = table.freeze({
	Void = Color3.fromRGB(4, 5, 6), -- full-screen dim behind a modal
	Panel = Color3.fromRGB(13, 16, 17), -- primary surface
	PanelRaised = Color3.fromRGB(20, 24, 26), -- interactive tiles on a panel
	Accent = Color3.fromRGB(255, 207, 90), -- primary call-to-action / headline
	AccentDim = Color3.fromRGB(185, 133, 45), -- accent stroke, quieter than fill
	Danger = Color3.fromRGB(216, 84, 74), -- failure / loss
	TextPrimary = Color3.fromRGB(232, 236, 230),
	TextMuted = Color3.fromRGB(178, 185, 174),
	Ink = Color3.fromRGB(10, 12, 13), -- text stroke / shadow
	Line = Color3.fromRGB(120, 128, 118), -- neutral separators and empty slots
})

-- Typography. Three roles only, so hierarchy reads at a glance.
InterfaceTheme.Font = table.freeze({
	Display = Enum.Font.GothamBlack,
	Heading = Enum.Font.GothamBold,
	Body = Enum.Font.GothamMedium,
})

-- A strictly descending type scale. Screens pick a role, not a magic number.
InterfaceTheme.TextSize = table.freeze({
	Display = 30,
	Title = 20,
	Subtitle = 16,
	Body = 15,
	Caption = 13,
})

-- A 4-based spacing scale, ascending. Consistent rhythm across every surface.
InterfaceTheme.Spacing = table.freeze({
	XSmall = 4,
	Small = 8,
	Medium = 12,
	Large = 20,
	XLarge = 28,
})

InterfaceTheme.Radius = table.freeze({
	Panel = 14,
	Control = 10,
	Chip = 8,
})

InterfaceTheme.Stroke = table.freeze({
	Hairline = 1,
	Bold = 2,
})

-- Rounds a GuiObject's corners.
function InterfaceTheme.corner(instance: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

-- Adds an outline. Transparency defaults to a quiet 0.35 so strokes read as edges,
-- not borders.
function InterfaceTheme.stroke(instance: Instance, color: Color3, transparency: number?, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = if transparency == nil then 0.35 else transparency
	stroke.Thickness = thickness or InterfaceTheme.Stroke.Hairline
	stroke.Parent = instance
end

-- Uniform inner padding on a container.
function InterfaceTheme.padding(instance: Instance, amount: number)
	local pad = Instance.new("UIPadding")
	local offset = UDim.new(0, amount)
	pad.PaddingTop = offset
	pad.PaddingBottom = offset
	pad.PaddingLeft = offset
	pad.PaddingRight = offset
	pad.Parent = instance
end

export type LabelOptions = {
	name: string?,
	role: "Display" | "Heading" | "Body"?,
	size: number?,
	color: Color3?,
	wrapped: boolean?,
	xAlign: Enum.TextXAlignment?,
	yAlign: Enum.TextYAlignment?,
}

-- Builds a themed transparent text label. Every readable string in the interface
-- carries its own ink stroke, so text stays legible over any world background —
-- an accessibility rule, not a style choice.
function InterfaceTheme.label(parent: Instance, options: LabelOptions): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = options.name or "Label"
	label.BackgroundTransparency = 1
	label.Font = InterfaceTheme.Font[options.role or "Body"]
	label.TextSize = options.size or InterfaceTheme.TextSize.Body
	label.TextColor3 = options.color or InterfaceTheme.Palette.TextPrimary
	label.TextStrokeColor3 = InterfaceTheme.Palette.Ink
	label.TextStrokeTransparency = 0.55
	label.TextWrapped = if options.wrapped == nil then true else options.wrapped
	label.TextXAlignment = options.xAlign or Enum.TextXAlignment.Left
	label.TextYAlignment = options.yAlign or Enum.TextYAlignment.Top
	label.Text = ""
	label.Parent = parent
	return label
end

-- Builds a primary surface: panel fill, panel radius, and a quiet accent edge.
function InterfaceTheme.panel(parent: Instance, name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = InterfaceTheme.Palette.Panel
	frame.BackgroundTransparency = 0.02
	frame.BorderSizePixel = 0
	frame.Parent = parent
	InterfaceTheme.corner(frame, InterfaceTheme.Radius.Panel)
	InterfaceTheme.stroke(frame, InterfaceTheme.Palette.AccentDim, 0.5, InterfaceTheme.Stroke.Bold)
	return frame
end

-- Builds the full-screen dim behind a modal surface.
function InterfaceTheme.backdrop(parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Backdrop"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = InterfaceTheme.Palette.Void
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = parent
	return frame
end

return table.freeze(InterfaceTheme)
