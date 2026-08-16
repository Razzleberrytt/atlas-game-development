--!strict

--[[
	One client-local design-token system for Living Kingdoms interface surfaces.

	Every adopted screen shares the same visual grammar: cool charcoal surfaces,
	warm amber action emphasis, restrained status colours, compact type hierarchy,
	and consistent spacing/edge treatment. Keep visual policy here instead of
	rebuilding corners, strokes, gradients, and label styling in each controller.

	It is presentation only. It holds no gameplay authority, reads no server state,
	owns no connection or timer, and cannot change any consequential fact. The
	builders only construct and style GuiObjects the caller then owns.
]]

local InterfaceTheme = {}

-- A low-chroma field palette keeps world content readable behind the HUD while
-- amber remains the one dominant interaction/high-value signal. Additional
-- surface steps provide depth without introducing competing accent colours.
InterfaceTheme.Palette = table.freeze({
	Void = Color3.fromRGB(4, 6, 8),
	VoidRaised = Color3.fromRGB(8, 11, 13),
	PanelDeep = Color3.fromRGB(10, 13, 15),
	Panel = Color3.fromRGB(15, 19, 21),
	PanelRaised = Color3.fromRGB(23, 28, 30),
	PanelHighlight = Color3.fromRGB(34, 39, 40),
	Accent = Color3.fromRGB(246, 196, 76),
	AccentBright = Color3.fromRGB(255, 224, 128),
	AccentDim = Color3.fromRGB(157, 112, 39),
	Danger = Color3.fromRGB(218, 86, 76),
	Success = Color3.fromRGB(118, 188, 137),
	TextPrimary = Color3.fromRGB(238, 241, 235),
	TextMuted = Color3.fromRGB(174, 182, 172),
	TextFaint = Color3.fromRGB(126, 136, 128),
	Ink = Color3.fromRGB(6, 8, 9),
	Line = Color3.fromRGB(104, 114, 108),
})

-- Three font weights are enough to create hierarchy without making adjacent
-- systems feel like separate products.
InterfaceTheme.Font = table.freeze({
	Display = Enum.Font.GothamBlack,
	Heading = Enum.Font.GothamBold,
	Body = Enum.Font.GothamMedium,
})

-- A compact, strictly descending type scale. Display/title sizes gain a little
-- more separation while normal HUD copy stays dense enough for action play.
InterfaceTheme.TextSize = table.freeze({
	Display = 32,
	Title = 22,
	Subtitle = 17,
	Body = 15,
	Caption = 12,
})

-- 4-based spacing with one extra top step for large modal breathing room.
InterfaceTheme.Spacing = table.freeze({
	XSmall = 4,
	Small = 8,
	Medium = 12,
	Large = 20,
	XLarge = 28,
	XXLarge = 36,
})

InterfaceTheme.Radius = table.freeze({
	Panel = 16,
	Control = 10,
	Chip = 8,
})

InterfaceTheme.Stroke = table.freeze({
	Hairline = 1,
	Bold = 2,
})

-- Central transparency policy prevents each surface from independently drifting
-- between opaque debug boxes and unreadably transparent overlays.
InterfaceTheme.Opacity = table.freeze({
	BackdropTransparency = 0.18,
	PanelTransparency = 0.03,
	RaisedTransparency = 0.06,
	QuietStrokeTransparency = 0.52,
	TextStrokeTransparency = 0.68,
})

-- Rounds a GuiObject's corners.
function InterfaceTheme.corner(instance: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

-- Adds an outline. Transparency defaults to a quiet edge treatment so strokes
-- establish silhouette instead of reading like high-contrast debug borders.
function InterfaceTheme.stroke(instance: Instance, color: Color3, transparency: number?, thickness: number?)
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Transparency = if transparency == nil then InterfaceTheme.Opacity.QuietStrokeTransparency else transparency
	stroke.Thickness = thickness or InterfaceTheme.Stroke.Hairline
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
end

-- Adds a subtle vertical material shift. The gradient is intentionally shallow:
-- it gives panels depth without fighting text, icons, or world silhouettes.
function InterfaceTheme.surfaceGradient(instance: Instance, topColor: Color3?, bottomColor: Color3?)
	local gradient = Instance.new("UIGradient")
	gradient.Name = "SurfaceGradient"
	gradient.Rotation = 90
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, topColor or InterfaceTheme.Palette.PanelRaised),
		ColorSequenceKeypoint.new(1, bottomColor or InterfaceTheme.Palette.PanelDeep),
	})
	gradient.Parent = instance
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

-- Builds a themed transparent text label. The ink edge is intentionally subtle:
-- enough separation for world-backed HUD text without the chunky outlined look
-- that makes polished interface typography feel like debug telemetry.
function InterfaceTheme.label(parent: Instance, options: LabelOptions): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = options.name or "Label"
	label.BackgroundTransparency = 1
	label.BorderSizePixel = 0
	label.Font = InterfaceTheme.Font[options.role or "Body"]
	label.TextSize = options.size or InterfaceTheme.TextSize.Body
	label.TextColor3 = options.color or InterfaceTheme.Palette.TextPrimary
	label.TextStrokeColor3 = InterfaceTheme.Palette.Ink
	label.TextStrokeTransparency = InterfaceTheme.Opacity.TextStrokeTransparency
	label.TextWrapped = if options.wrapped == nil then true else options.wrapped
	label.TextXAlignment = options.xAlign or Enum.TextXAlignment.Left
	label.TextYAlignment = options.yAlign or Enum.TextYAlignment.Top
	label.Text = ""
	label.Parent = parent
	return label
end

-- Builds the primary modal/card surface. Fill, material shift, radius, and edge
-- highlight all come from one owner so adopted screens share the same depth model.
function InterfaceTheme.panel(parent: Instance, name: string): Frame
	local frame = Instance.new("Frame")
	frame.Name = name
	frame.BackgroundColor3 = InterfaceTheme.Palette.Panel
	frame.BackgroundTransparency = InterfaceTheme.Opacity.PanelTransparency
	frame.BorderSizePixel = 0
	frame.Parent = parent
	InterfaceTheme.corner(frame, InterfaceTheme.Radius.Panel)
	InterfaceTheme.surfaceGradient(frame)
	InterfaceTheme.stroke(
		frame,
		InterfaceTheme.Palette.AccentDim,
		InterfaceTheme.Opacity.QuietStrokeTransparency,
		InterfaceTheme.Stroke.Bold
	)
	return frame
end

-- Builds the full-screen dim behind modal content with a shallow vertical value
-- shift so the overlay feels integrated with the scene instead of flat black.
function InterfaceTheme.backdrop(parent: Instance): Frame
	local frame = Instance.new("Frame")
	frame.Name = "Backdrop"
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = InterfaceTheme.Palette.Void
	frame.BackgroundTransparency = InterfaceTheme.Opacity.BackdropTransparency
	frame.BorderSizePixel = 0
	frame.Parent = parent
	InterfaceTheme.surfaceGradient(frame, InterfaceTheme.Palette.VoidRaised, InterfaceTheme.Palette.Void)
	return frame
end

return table.freeze(InterfaceTheme)
