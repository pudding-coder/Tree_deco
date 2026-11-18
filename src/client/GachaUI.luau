-- 룰렛 화면: 슬롯 3칸 · 확률표 · 가방(인벤토리) · 공지
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local Gacha = require(Shared:WaitForChild("Gacha"))
local Catalog = require(Shared:WaitForChild("Catalog"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer

local GachaUI = {}

-- 자물쇠 그림 (assets/textures/lock.png를 올린 이미지 id). 비워 두면 "잠금" 글자로 나온다
local LOCK_IMAGE = "rbxassetid://133145630160436" -- assets/textures/lock.png

local COLORS = {
	panel = Color3.fromRGB(20, 28, 40),
	panelLight = Color3.fromRGB(32, 43, 60),
	panelHover = Color3.fromRGB(48, 62, 84),
	text = Color3.fromRGB(242, 245, 250),
	subText = Color3.fromRGB(160, 172, 190),
	green = Color3.fromRGB(40, 168, 92),
	gold = Color3.fromRGB(226, 170, 40),
	disabled = Color3.fromRGB(68, 76, 90),
	error = Color3.fromRGB(230, 80, 80),
	errorText = Color3.fromRGB(255, 110, 110),
}

-- 특성 글자색 (여기 없는 특성은 흰색)
local TRAIT_COLORS = {
	None = COLORS.subText,
	Glitter = Color3.fromRGB(255, 240, 150),
	Frost = Color3.fromRGB(170, 220, 255),
	Golden = Color3.fromRGB(255, 200, 40),
	Rainbow = Color3.fromRGB(255, 120, 200),
	Aurora = Color3.fromRGB(120, 255, 200),
	Smoge = Color3.fromRGB(150, 150, 150),
}

local function traitColor(trait): Color3
	return TRAIT_COLORS[trait.id] or COLORS.text
end

local state = nil
local spinning = false
local selectedKey = nil
local ui = {}

----------------------------------------------------------------
-- 장식 정보 헬퍼
----------------------------------------------------------------

-- "반짝이 분홍 공" (기본 특성이면 특성 이름 없이, 색이 없으면 색 이름 없이)
local function itemName(deco, trait, paintId: string?): string
	return Catalog.ItemName(deco, trait, paintId)
end

-- "분홍 공" (특성 이름 없이)
local function paintedName(deco, paintId: string?): string
	return Catalog.ItemName(deco, Catalog.BaseTrait, paintId)
end

local function stackInfo(stack)
	return Catalog.DecorationById[stack.d], Catalog.TraitById[stack.t]
end

local function stackKey(stack): string
	return Catalog.StackKey(stack.d, stack.t, stack.p)
end

local function stackSellPrice(stack): number
	local deco, trait = stackInfo(stack)
	return Gacha.GetSellPrice(deco.rarity, trait.mult)
end

----------------------------------------------------------------
-- UI 헬퍼
----------------------------------------------------------------

local function create(className: string, props)
	local inst = Instance.new(className)
	local parent = props.Parent
	props.Parent = nil
	for key, value in props do
		inst[key] = value
	end
	if parent then
		inst.Parent = parent
	end
	return inst
end

local function corner(parent, radius: number?)
	create("UICorner", { CornerRadius = UDim.new(0, radius or 12), Parent = parent })
end

local function padding(parent, px: number)
	create("UIPadding", {
		PaddingTop = UDim.new(0, px),
		PaddingBottom = UDim.new(0, px),
		PaddingLeft = UDim.new(0, px),
		PaddingRight = UDim.new(0, px),
		Parent = parent,
	})
end

local function label(props)
	props.BackgroundTransparency = props.BackgroundTransparency or 1
	props.Font = props.Font or Enum.Font.GothamBold
	props.TextColor3 = props.TextColor3 or COLORS.text
	props.TextSize = props.TextSize or 16
	return create("TextLabel", props)
end

-- 글자가 칸보다 길면 자동으로 작아지는 라벨
local function scaledLabel(props, maxSize: number, minSize: number?)
	props.TextScaled = true
	props.TextWrapped = true
	local lbl = label(props)
	create("UITextSizeConstraint", { MaxTextSize = maxSize, MinTextSize = minSize or 8, Parent = lbl })
	return lbl
end

local function panel(props)
	local frame = create("Frame", {
		Name = props.Name,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = COLORS.panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Visible = if props.Visible == nil then true else props.Visible,
		Parent = props.Parent,
	})
	corner(frame, 14)
	create("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.85, Thickness = 1.5, Parent = frame })
	padding(frame, 12)
	return frame
end

local function button(props)
	local btn = create("TextButton", {
		Name = props.Name,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = props.Color or COLORS.panelLight,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = props.TextSize or 18,
		TextColor3 = COLORS.text,
		Text = props.Text,
		Parent = props.Parent,
	})
	corner(btn, props.Radius or 10)
	return btn
end

local function setButton(btn: TextButton, text: string, enabled: boolean, color: Color3)
	btn.Text = text
	btn.BackgroundColor3 = if enabled then color else COLORS.disabled
	btn.TextColor3 = if enabled then COLORS.text else COLORS.subText
end

----------------------------------------------------------------
-- 화면 만들기
----------------------------------------------------------------

local REEL_TITLES = { "등급", "장식", "특성" }

local function buildSlot(gui)
	local slot = panel({
		Name = "Slot",
		Size = UDim2.fromOffset(520, 330),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Visible = false, -- 룰렛 버튼으로 열고 닫는다
		Parent = gui,
	})
	ui.slot = slot
	label({
		Text = "장식 룰렛",
		TextSize = 20,
		Size = UDim2.new(0.6, 0, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = slot,
	})
	ui.potionLabel = label({
		Text = "",
		TextSize = 13,
		TextColor3 = COLORS.gold,
		Size = UDim2.new(0.2, 0, 0, 28),
		Position = UDim2.fromScale(0.28, 0),
		Visible = false,
		Parent = slot,
	})

	-- 슬롯 3칸: 등급 · 장식 · 특성
	local reels = create("Frame", {
		Name = "Reels",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 36),
		Size = UDim2.new(1, 0, 0, 96),
		Parent = slot,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = reels,
	})
	ui.reels = {}
	local widths = { 0.27, 0.46, 0.27 } -- 장식 이름이 길어서 가운데 칸을 넓게
	for i, title in REEL_TITLES do
		local cell = create("Frame", {
			Name = "Reel" .. i,
			BackgroundColor3 = COLORS.panelLight,
			BorderSizePixel = 0,
			Size = UDim2.new(widths[i], -6, 1, 0),
			LayoutOrder = i,
			ClipsDescendants = true,
			Parent = reels,
		})
		corner(cell, 10)
		local stroke = create("UIStroke", { Color = COLORS.subText, Thickness = 3, Parent = cell })
		label({
			Text = title,
			TextSize = 12,
			Font = Enum.Font.Gotham,
			TextColor3 = COLORS.subText,
			Size = UDim2.new(1, 0, 0, 18),
			Position = UDim2.fromOffset(0, 4),
			Parent = cell,
		})
		local text = scaledLabel({
			Text = "?",
			Font = Enum.Font.GothamBlack,
			Size = UDim2.new(1, -12, 0, 60),
			Position = UDim2.fromOffset(6, 26),
			Parent = cell,
		}, 30, 10)
		ui.reels[i] = { stroke = stroke, text = text, scale = create("UIScale", { Parent = text }) }
	end

	ui.reelSub = label({
		Text = "버튼을 눌러 룰렛을 돌려 주세요",
		TextSize = 15,
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.subText,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 138),
		Parent = slot,
	})

	ui.freeButton = button({
		Name = "FreeSpin",
		Text = "무료 돌리기",
		Color = COLORS.green,
		Size = UDim2.new(0.5, -6, 0, 54),
		Position = UDim2.fromOffset(0, 166),
		Parent = slot,
	})
	ui.coinButton = button({
		Name = "CoinSpin",
		Text = "코인 돌리기",
		Color = COLORS.gold,
		Size = UDim2.new(0.5, -6, 0, 54),
		Position = UDim2.new(0.5, 6, 0, 166),
		Parent = slot,
	})

	-- 자동 판매: 등급마다 자물쇠 칸. 자물쇠를 풀면 그 등급은 뽑자마자 판다 (실수로 좋은 장식을 팔지 않도록 처음엔 모두 잠김)
	label({
		Text = "자동 판매 (자물쇠를 풀면 그 등급은 뽑자마자 팝니다)",
		TextSize = 12,
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.subText,
		Size = UDim2.new(1, 0, 0, 16),
		Position = UDim2.fromOffset(0, 228),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = slot,
	})
	local chips = create("Frame", {
		Name = "AutoSell",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 246),
		Parent = slot,
	})
	create("UIListLayout", {
		FillDirection = Enum.FillDirection.Horizontal,
		Padding = UDim.new(0, 5),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = chips,
	})
	ui.autoSellChips = {}
	for i, r in Rarity.List do
		local chip = create("TextButton", {
			Text = "",
			AutoButtonColor = false,
			BackgroundColor3 = COLORS.panelLight,
			BorderSizePixel = 0,
			Size = UDim2.new(1 / Rarity.Count, -5, 1, 0),
			LayoutOrder = i,
			Parent = chips,
		})
		corner(chip, 6)
		local stroke = create("UIStroke", { Color = r.color, Thickness = 1.5, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = chip })
		-- 등급 이름: 자물쇠가 풀렸을 때(자동 판매 켬)
		local name = scaledLabel({
			Text = r.name,
			TextColor3 = r.color,
			Size = UDim2.new(1, -4, 1, -4),
			Position = UDim2.fromOffset(2, 2),
			Parent = chip,
		}, 12, 7)
		-- 자물쇠: 잠겼을 때(보관, 자동 판매 안 함). 그림 id가 없으면 글자로
		local lock = if LOCK_IMAGE ~= ""
			then create("ImageLabel", {
				Image = LOCK_IMAGE,
				BackgroundTransparency = 1,
				ScaleType = Enum.ScaleType.Fit,
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.new(1, -8, 1, -8),
				Parent = chip,
			})
			else scaledLabel({
				Text = "잠금",
				TextColor3 = r.color,
				Size = UDim2.new(1, -4, 1, -4),
				Position = UDim2.fromOffset(2, 2),
				Parent = chip,
			}, 12, 7)
		ui.autoSellChips[i] = { button = chip, name = name, lock = lock, stroke = stroke }
	end

	ui.status = label({
		Text = "",
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.errorText,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 284),
		Parent = slot,
	})
end

-- 확률표 (오른쪽 아래): 등급 확률 + 특성 확률
local function buildOdds(gui)
	local rowHeight = 22
	local traitCount = 0
	for _, trait in Catalog.Traits do
		if not trait.retired then
			traitCount += 1
		end
	end
	local height = 30 + Rarity.Count * rowHeight + 10 + 30 + traitCount * rowHeight + 24

	local frame = panel({
		Name = "Odds",
		Size = UDim2.fromOffset(220, height),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -84), -- 코인 표시 위
		Visible = false, -- 룰렛과 같이 열고 닫는다
		Parent = gui,
	})
	ui.odds = frame
	local list = create("Frame", { BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), Parent = frame })
	create("UIListLayout", { SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	local function titleRow(text: string)
		return label({
			Text = text,
			Size = UDim2.new(1, 0, 0, 30),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = nextOrder(),
			Parent = list,
		})
	end
	local function row(name: string, color: Color3)
		local r = create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, rowHeight),
			LayoutOrder = nextOrder(),
			Parent = list,
		})
		label({
			Text = name,
			TextSize = 14,
			TextColor3 = color,
			Size = UDim2.fromScale(0.5, 1),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = r,
		})
		return label({
			Text = "-",
			TextSize = 14,
			Font = Enum.Font.Gotham,
			TextColor3 = COLORS.subText,
			Size = UDim2.fromScale(0.5, 1),
			Position = UDim2.fromScale(0.5, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = r,
		})
	end

	ui.oddsTitle = titleRow("확률")
	ui.oddsLabels = {}
	for i, r in Rarity.List do
		ui.oddsLabels[i] = row("● " .. r.name, r.color)
	end
	create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 10), LayoutOrder = nextOrder(), Parent = list })
	titleRow("특성")
	for _, trait in Catalog.Traits do
		if trait.retired then
			continue
		end
		local odds = if trait.n then Gacha.FormatOdds(1 / trait.n) else "나머지"
		local valueLabel = row(trait.name, traitColor(trait))
		valueLabel.Text = string.format("%s · ×%s", odds, tostring(trait.mult))
	end
end

-- 코인 표시 (오른쪽 아래 구석, 항상 보임)
local function buildCoins(gui)
	local frame = panel({
		Name = "Coins",
		Size = UDim2.fromOffset(220, 56),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -16, 1, -20),
		Parent = gui,
	})
	ui.coins = scaledLabel({
		Text = "코인 0",
		TextColor3 = COLORS.gold,
		Size = UDim2.fromScale(1, 1),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = frame,
	}, 18, 10)
end

-- 가방 버튼 (왼쪽 아래)
local function buildBagButton(gui)
	ui.bagButton = button({
		Name = "BagButton",
		Text = "가방",
		Color = COLORS.panel,
		Size = UDim2.fromOffset(200, 56),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -20),
		Radius = 14,
		Parent = gui,
	})
	create("UIStroke", {
		Color = Color3.new(1, 1, 1),
		Transparency = 0.85,
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = ui.bagButton,
	})
end

-- 인벤토리 창 (가운데, 가방 버튼으로 열고 닫음)
local function buildInventory(gui)
	local window = panel({
		Name = "Inventory",
		Size = UDim2.fromOffset(620, 500),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Visible = false,
		Parent = gui,
	})
	window.ZIndex = 5 -- 슬롯·확률표 위에 보이게
	ui.inventory = window

	ui.invTitle = label({
		Text = "가방",
		TextSize = 20,
		Size = UDim2.new(1, -40, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	ui.invClose = button({
		Text = "X",
		TextSize = 18,
		Size = UDim2.fromOffset(32, 30),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Parent = window,
	})

	-- 격자
	ui.grid = create("ScrollingFrame", {
		Name = "Grid",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 1, -38 - 70 - 44 - 12),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = window,
	})
	create("UIGridLayout", {
		CellSize = UDim2.fromOffset(86, 96),
		CellPadding = UDim2.fromOffset(8, 8),
		SortOrder = Enum.SortOrder.LayoutOrder,
		Parent = ui.grid,
	})
	create("UIPadding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), Parent = ui.grid })
	ui.emptyLabel = label({
		Text = "아직 장식이 없습니다. 룰렛을 돌려 주세요.",
		TextSize = 15,
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.subText,
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 60),
		Visible = false,
		Parent = window,
	})

	-- 선택한 칸 정보
	local detail = create("Frame", {
		Name = "Detail",
		BackgroundColor3 = COLORS.panelLight,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -70 - 44 - 6),
		Size = UDim2.new(1, 0, 0, 70),
		Parent = window,
	})
	corner(detail, 10)
	padding(detail, 10)
	ui.detailName = scaledLabel({
		Text = "",
		Size = UDim2.new(1, -350, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = detail,
	}, 18, 10)
	ui.detailInfo = scaledLabel({
		Text = "칸을 눌러 장식을 골라 주세요",
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.subText,
		Size = UDim2.new(1, -350, 0, 20),
		Position = UDim2.fromOffset(0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = detail,
	}, 13, 9)
	ui.detailPlace = button({
		Text = "트리에 걸기",
		TextSize = 14,
		Color = COLORS.green,
		Size = UDim2.fromOffset(110, 40),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -228, 0.5, 0),
		Parent = detail,
	})
	ui.detailLock = button({
		Text = "잠그기",
		TextSize = 14,
		Size = UDim2.fromOffset(104, 40),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -116, 0.5, 0),
		Parent = detail,
	})
	ui.detailSell = button({
		Text = "판매",
		TextSize = 14,
		Size = UDim2.fromOffset(110, 40),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, 0, 0.5, 0),
		Parent = detail,
	})

	-- 아래 버튼: 모두 판매 (자동 판매는 룰렛 창의 자물쇠 칸에서 정한다)
	ui.sellAllButton = button({
		Text = "모두 판매",
		TextSize = 15,
		Size = UDim2.new(1, 0, 0, 44),
		Position = UDim2.new(0, 0, 1, -44),
		Parent = window,
	})
end

-- 업그레이드 버튼 (가방 버튼 위)
local function buildUpgradeButton(gui)
	ui.upgradeButton = button({
		Name = "UpgradeButton",
		Text = "업그레이드",
		Color = COLORS.panel,
		Size = UDim2.fromOffset(200, 56),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -84),
		Radius = 14,
		Parent = gui,
	})
	create("UIStroke", {
		Color = Color3.new(1, 1, 1),
		Transparency = 0.85,
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = ui.upgradeButton,
	})
end

-- 업그레이드 창: 행운 · 속도 · 물약 세 줄
local function buildUpgradeWindow(gui)
	local window = panel({
		Name = "Upgrades",
		Size = UDim2.fromOffset(560, 340),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Visible = false,
		Parent = gui,
	})
	window.ZIndex = 5
	ui.upgradeWindow = window

	label({
		Text = "업그레이드",
		TextSize = 20,
		Size = UDim2.new(1, -40, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	ui.upgradeClose = button({
		Text = "X",
		TextSize = 18,
		Size = UDim2.fromOffset(32, 30),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Parent = window,
	})

	local list = create("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 40),
		Size = UDim2.new(1, 0, 1, -40),
		Parent = window,
	})
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local function row(order: number)
		local frame = create("Frame", {
			BackgroundColor3 = COLORS.panelLight,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 86),
			LayoutOrder = order,
			Parent = list,
		})
		corner(frame, 10)
		padding(frame, 12)
		local title = label({
			Text = "",
			TextSize = 18,
			Size = UDim2.new(1, -170, 0, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		local info = scaledLabel({
			Text = "",
			Font = Enum.Font.Gotham,
			TextColor3 = COLORS.subText,
			Size = UDim2.new(1, -170, 0, 32),
			Position = UDim2.fromOffset(0, 28),
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Top,
			Parent = frame,
		}, 14, 9)
		local btn = button({
			Text = "",
			TextSize = 15,
			Size = UDim2.fromOffset(150, 46),
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.fromScale(1, 0.5),
			Parent = frame,
		})
		return { title = title, info = info, button = btn }
	end

	ui.upgradeRows = {
		luck = row(1),
		speed = row(2),
		potion = row(3),
	}
end

-- 트리 영역 (Config의 자리 수)
local TREE_AREAS = {
	{ id = "Topper", name = "토퍼", count = Config.MAX_TOPPER },
	{ id = "Ornament", name = "오너먼트", count = Config.MAX_ORNAMENT },
	{ id = "Garland", name = "띠", count = Config.MAX_GARLAND },
}

-- 자리 번호 → 화면 순서(아래에서 몇 번째). 서버가 ReplicatedStorage 속성 TreeSlotOrder_<영역>으로 알려 준다
local slotRank = {} -- [영역][자리 번호] = 순서
for _, area in TREE_AREAS do
	slotRank[area.id] = {}
	for index = 1, area.count do
		slotRank[area.id][index] = index
	end
end

-- 안내 글에 쓰는 자리 이름: "오너먼트 3번 자리" (번호는 빈 칸에 보이는 번호와 같다. 토퍼는 하나뿐이라 "토퍼 자리")
local function slotName(area: string, index: number): string
	if area == "Topper" then
		return "토퍼 자리"
	end
	return string.format("%s %d번 자리", Catalog.AREAS[area], slotRank[area][index] or index)
end

-- 룰렛 버튼 (트리 버튼 위): 룰렛 창과 확률표를 열고 닫는다
local function buildRouletteButton(gui)
	ui.rouletteButton = button({
		Name = "RouletteButton",
		Text = "룰렛",
		Color = COLORS.panel,
		Size = UDim2.fromOffset(200, 56),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -212),
		Radius = 14,
		Parent = gui,
	})
	ui.rouletteStroke = create("UIStroke", {
		Color = Color3.new(1, 1, 1),
		Transparency = 0.85,
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = ui.rouletteButton,
	})
end

-- 트리 버튼 (업그레이드 버튼 위)
local function buildTreeButton(gui)
	ui.treeButton = button({
		Name = "TreeButton",
		Text = "내 트리",
		Color = COLORS.panel,
		Size = UDim2.fromOffset(200, 56),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -148),
		Radius = 14,
		Parent = gui,
	})
	create("UIStroke", {
		Color = Color3.new(1, 1, 1),
		Transparency = 0.85,
		Thickness = 1.5,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = ui.treeButton,
	})
end

-- 트리 창: 영역별 자리 칸. 칸을 누르면 아래에 정보와 빼기 버튼
local function buildTreeWindow(gui)
	local window = panel({
		Name = "Tree",
		Size = UDim2.fromOffset(620, 470),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Visible = false,
		Parent = gui,
	})
	window.ZIndex = 5
	ui.treeWindow = window

	ui.treeTitle = label({
		Text = "내 트리",
		TextSize = 20,
		Size = UDim2.new(1, -40, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	ui.treeClose = button({
		Text = "X",
		TextSize = 18,
		Size = UDim2.fromOffset(32, 30),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Parent = window,
	})
	ui.treeInfo = label({
		Text = "",
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.subText,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})

	local scroll = create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 1, -58 - 62),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = window,
	})
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = scroll })

	ui.treeCells = {}
	for order, area in TREE_AREAS do
		label({
			Text = string.format("%s (%d자리)", area.name, area.count),
			TextSize = 14,
			Size = UDim2.new(1, 0, 0, 22),
			TextXAlignment = Enum.TextXAlignment.Left,
			LayoutOrder = order * 2 - 1,
			Parent = scroll,
		})
		local grid = create("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.new(1, -8, 0, 0),
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order * 2,
			Parent = scroll,
		})
		create("UIGridLayout", {
			CellSize = UDim2.fromOffset(106, 52),
			CellPadding = UDim2.fromOffset(6, 6),
			SortOrder = Enum.SortOrder.LayoutOrder,
			Parent = grid,
		})
		ui.treeCells[area.id] = {}
		for index = 1, area.count do
			local cell = create("TextButton", {
				Text = "",
				AutoButtonColor = false,
				BackgroundColor3 = COLORS.panelLight,
				BorderSizePixel = 0,
				LayoutOrder = index,
				Parent = grid,
			})
			corner(cell, 8)
			local stroke = create("UIStroke", {
				Color = COLORS.subText,
				Thickness = 2,
				ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
				Parent = cell,
			})
			local trait = label({
				Text = "",
				TextSize = 10,
				Size = UDim2.new(1, -8, 0, 14),
				Position = UDim2.fromOffset(4, 2),
				TextXAlignment = Enum.TextXAlignment.Left,
				Parent = cell,
			})
			local name = scaledLabel({
				Text = "빈 자리",
				Size = UDim2.new(1, -8, 0, 32),
				Position = UDim2.fromOffset(4, 16),
				Parent = cell,
			}, 13, 8)
			ui.treeCells[area.id][index] = { button = cell, stroke = stroke, trait = trait, name = name }
		end
	end

	-- 빈 자리를 누르면 뜨는 장식 고르기 (자리 칸 위를 덮는다)
	local picker = create("Frame", {
		Name = "Picker",
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 58),
		Size = UDim2.new(1, 0, 1, -58 - 62),
		Visible = false,
		ZIndex = 3,
		Parent = window,
	})
	corner(picker, 10)
	create("UIStroke", { Color = Color3.new(1, 1, 1), Transparency = 0.8, Thickness = 1.5, Parent = picker })
	padding(picker, 8)
	ui.treePicker = picker
	ui.treePickerTitle = label({
		Text = "",
		TextSize = 15,
		Size = UDim2.new(1, -90, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 3,
		Parent = picker,
	})
	ui.treePickerClose = button({
		Text = "닫기",
		TextSize = 14,
		Size = UDim2.fromOffset(80, 30),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Parent = picker,
	})
	ui.treePickerClose.ZIndex = 3
	ui.treePickerList = create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 1, -38),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 3,
		Parent = picker,
	})
	create("UIListLayout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder, Parent = ui.treePickerList })
	ui.treePickerEmpty = label({
		Text = "가방에 이 자리에 걸 수 있는 장식이 없습니다",
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.subText,
		Size = UDim2.new(1, 0, 0, 40),
		Visible = false,
		ZIndex = 3,
		LayoutOrder = 0,
		Parent = ui.treePickerList,
	})

	local footer = create("Frame", {
		BackgroundColor3 = COLORS.panelLight,
		BorderSizePixel = 0,
		Position = UDim2.new(0, 0, 1, -56),
		Size = UDim2.new(1, 0, 0, 56),
		Parent = window,
	})
	corner(footer, 10)
	padding(footer, 8)
	ui.treeDetail = scaledLabel({
		Text = "",
		Size = UDim2.new(1, -140, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = footer,
	}, 15, 9)
	ui.treeRemove = button({
		Text = "빼기",
		TextSize = 15,
		Size = UDim2.fromOffset(120, 40),
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Parent = footer,
	})
end

-- 서버가 알려 준 순서대로 자리 칸을 아래부터 늘어놓는다
local function applySlotOrder()
	for _, area in TREE_AREAS do
		local order = ReplicatedStorage:GetAttribute("TreeSlotOrder_" .. area.id)
		if type(order) ~= "string" then
			continue
		end
		local rank = 0
		for text in string.gmatch(order, "%d+") do
			local index = tonumber(text)
			if index and slotRank[area.id][index] then
				rank += 1
				slotRank[area.id][index] = rank
			end
		end
		for index, cell in ui.treeCells[area.id] do
			cell.button.LayoutOrder = slotRank[area.id][index]
		end
	end
end

local function buildUI()
	local gui = create("ScreenGui", {
		Name = "GachaGui",
		ResetOnSpawn = false,
		IgnoreGuiInset = true,
		ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
		Parent = player:WaitForChild("PlayerGui"),
	})

	-- 화면 크기에 맞춰 전체 크기 조절 (폰에서도 보이게)
	local uiScale = create("UIScale", { Parent = gui })
	local camera = workspace.CurrentCamera
	local function updateScale()
		local size = camera.ViewportSize
		uiScale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 720), 0.5, 1.2)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	updateScale()

	buildSlot(gui)
	buildOdds(gui)
	buildCoins(gui)
	buildBagButton(gui)
	buildUpgradeButton(gui)
	buildTreeButton(gui)
	buildRouletteButton(gui)
	buildInventory(gui)
	buildUpgradeWindow(gui)
	buildTreeWindow(gui)
	applySlotOrder()
	for _, area in TREE_AREAS do
		ReplicatedStorage:GetAttributeChangedSignal("TreeSlotOrder_" .. area.id):Connect(applySlotOrder)
	end

	-- 공지
	ui.toast = create("CanvasGroup", {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(640, 48),
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Visible = false,
		ZIndex = 8,
		Parent = gui,
	})
	corner(ui.toast, 12)
	ui.toastStroke = create("UIStroke", { Thickness = 2, Color = COLORS.gold, Parent = ui.toast })
	ui.toastLabel = scaledLabel({
		Text = "",
		Size = UDim2.new(1, -24, 1, -8),
		Position = UDim2.fromOffset(12, 4),
		Parent = ui.toast,
	}, 18, 10)

	-- 희귀 등급 화면 번쩍임
	ui.flash = create("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Active = false,
		ZIndex = 10,
		Parent = gui,
	})
end

----------------------------------------------------------------
-- 화면 갱신
----------------------------------------------------------------

-- 지금 초당 수입 (서버와 같은 공식)
local function currentIncome(): number
	if not state then
		return 0
	end
	local minutes = (workspace:GetServerTimeNow() - state.displayStartedAt) / 60
	return Gacha.GetIncomePerSec(state.treeValue, state.votes, minutes)
end

local function currentCoinSpinCost(): number
	return Gacha.GetCoinSpinCost(state.luck, currentIncome())
end

local function currentPotionCost(): number
	return Gacha.GetPotionCost(currentIncome())
end

local function formatIncome(value: number): string
	if value < 10 then
		return string.format("%.1f", value)
	end
	return Gacha.FormatNumber(value)
end

local function setStatus(text: string)
	ui.status.Text = text
end

local function refreshCoins()
	local income = currentIncome()
	ui.coins.Text = "코인 " .. Gacha.FormatNumber(state.coins)
	if income > 0 then
		ui.coins.Text ..= string.format("  (+%s/초)", formatIncome(income))
	end
end

local function refreshOdds()
	local probs = Gacha.GetProbabilities(state.luck)
	for i, lbl in ui.oddsLabels do
		lbl.Text = Gacha.FormatOdds(probs[i])
	end
	ui.oddsTitle.Text = string.format("확률 · 행운 ×%.1f", state.luck)
end

-- 가방 정렬: 등급 높은 순 → 가치 높은 순 → 이름 순
local function sortedStacks()
	local list = table.clone(state.stacks)
	table.sort(list, function(a, b)
		local decoA, traitA = stackInfo(a)
		local decoB, traitB = stackInfo(b)
		if decoA.rarity ~= decoB.rarity then
			return decoA.rarity > decoB.rarity
		end
		local valueA = Gacha.GetItemValue(decoA.rarity, traitA.mult)
		local valueB = Gacha.GetItemValue(decoB.rarity, traitB.mult)
		if valueA ~= valueB then
			return valueA > valueB
		end
		return itemName(decoA, traitA, a.p) < itemName(decoB, traitB, b.p)
	end)
	return list
end

local function findStateStack(key: string?)
	if not key or not state then
		return nil
	end
	for _, stack in state.stacks do
		if stackKey(stack) == key then
			return stack
		end
	end
	return nil
end

-- 잠기지 않은 장식을 모두 팔면 받는 코인과, 확인이 필요한 등급이 들어 있는지
local function getSellAllPreview()
	local total = 0
	local needsConfirm = false
	for _, stack in state.stacks do
		if not stack.l then
			total += stackSellPrice(stack) * stack.c
			local deco = stackInfo(stack)
			if deco.rarity >= Config.SELL_CONFIRM_MIN_RARITY then
				needsConfirm = true
			end
		end
	end
	return total, needsConfirm
end

-- 한 번 더 눌러야 파는 버튼: [버튼 이름] = 이 시각 전에 다시 누르면 판매
local confirmUntil = {}

local function isConfirming(name: string): boolean
	return (confirmUntil[name] or 0) > os.clock()
end

local function refreshBagButton()
	local full = state.bagUsed >= state.bagCapacity
	ui.bagButton.Text = string.format("가방 %d/%d", state.bagUsed, state.bagCapacity)
	ui.bagButton.TextColor3 = if full then COLORS.errorText else COLORS.text
	ui.invTitle.Text = string.format("가방 %d/%d", state.bagUsed, state.bagCapacity)
end

local function refreshSellButtons()
	-- 모두 판매
	local total = getSellAllPreview()
	if total <= 0 then
		setButton(ui.sellAllButton, "팔 장식이 없습니다", false, COLORS.gold)
	elseif isConfirming("all") then
		setButton(ui.sellAllButton, string.format("한 번 더 누르면 판매 (+%s코인)", Gacha.FormatNumber(total)), true, COLORS.error)
	else
		setButton(ui.sellAllButton, string.format("잠금 빼고 모두 판매 +%s코인", Gacha.FormatNumber(total)), true, COLORS.gold)
	end

	-- 선택한 칸
	local stack = findStateStack(selectedKey)
	if not stack then
		ui.detailName.Text = ""
		ui.detailInfo.Text = "칸을 눌러 장식을 골라 주세요"
		ui.detailLock.Visible = false
		ui.detailSell.Visible = false
		ui.detailPlace.Visible = false
		return
	end
	local deco, trait = stackInfo(stack)
	local r = Rarity.List[deco.rarity]
	local value = Gacha.GetItemValue(deco.rarity, trait.mult)
	ui.detailName.Text = string.format("%s ×%s", itemName(deco, trait, stack.p), Gacha.FormatNumber(stack.c))
	ui.detailName.TextColor3 = r.color
	ui.detailInfo.Text = string.format(
		"%s · %s · 가치 %s코인 · 1개 판매 %s코인",
		r.name,
		Catalog.AREAS[deco.area],
		Gacha.FormatNumber(value),
		Gacha.FormatNumber(stackSellPrice(stack))
	)
	ui.detailLock.Visible = true
	ui.detailSell.Visible = true
	ui.detailPlace.Visible = true
	ui.detailLock.Text = if stack.l then "잠금 풀기" else "잠그기"
	ui.detailLock.BackgroundColor3 = if stack.l then COLORS.gold else COLORS.panelHover
	if stack.l then
		setButton(ui.detailSell, "잠겨 있습니다", false, COLORS.gold)
	elseif isConfirming("one") then
		setButton(ui.detailSell, "한 번 더 누르기", true, COLORS.error)
	else
		setButton(ui.detailSell, "판매 +" .. Gacha.FormatNumber(stackSellPrice(stack) * stack.c) .. "코인", true, COLORS.gold)
	end
end

local function makeCell(stack, order: number)
	local deco, trait = stackInfo(stack)
	local r = Rarity.List[deco.rarity]
	local key = stackKey(stack)
	local selected = key == selectedKey

	local cell = create("TextButton", {
		Name = key,
		Text = "",
		AutoButtonColor = false,
		BackgroundColor3 = if selected then COLORS.panelHover else COLORS.panelLight,
		BorderSizePixel = 0,
		LayoutOrder = order,
		Parent = ui.grid,
	})
	corner(cell, 10)
	create("UIStroke", {
		Color = if selected then COLORS.text else r.color,
		Thickness = if selected then 3 else 2,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = cell,
	})
	if trait ~= Catalog.BaseTrait then
		label({
			Text = trait.name,
			TextSize = 11,
			TextColor3 = traitColor(trait),
			Size = UDim2.fromOffset(44, 18),
			Position = UDim2.fromOffset(5, 3),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = cell,
		})
	end
	if stack.l then
		label({
			Text = "잠금",
			TextSize = 11,
			TextColor3 = COLORS.gold,
			Size = UDim2.fromOffset(30, 18),
			Position = UDim2.new(1, -34, 0, 3),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = cell,
		})
	end
	scaledLabel({
		Text = paintedName(deco, stack.p),
		TextColor3 = if trait == Catalog.BaseTrait then COLORS.text else traitColor(trait),
		Size = UDim2.new(1, -10, 0, 44),
		Position = UDim2.fromOffset(5, 24),
		Parent = cell,
	}, 14, 8)
	label({
		Text = r.name,
		TextSize = 11,
		TextColor3 = r.color,
		Size = UDim2.new(0.6, -4, 0, 18),
		Position = UDim2.new(0, 5, 1, -22),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = cell,
	})
	label({
		Text = "×" .. Gacha.FormatNumber(stack.c),
		TextSize = 13,
		Size = UDim2.new(0.4, -4, 0, 18),
		Position = UDim2.new(0.6, 0, 1, -22),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = cell,
	})

	cell.Activated:Connect(function()
		selectedKey = if selectedKey == key then nil else key
		confirmUntil.one = 0
		GachaUI.RefreshBag()
	end)
end

function GachaUI.RefreshBag()
	refreshBagButton()
	if not findStateStack(selectedKey) then
		selectedKey = nil
	end

	if ui.inventory.Visible then
		for _, child in ui.grid:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
		for order, stack in sortedStacks() do
			makeCell(stack, order)
		end
		ui.emptyLabel.Visible = #state.stacks == 0
	end
	refreshSellButtons()
end

-- 0:00 형식
local function formatTime(seconds: number): string
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function potionRemaining(): number
	if not state then
		return 0
	end
	return state.potionEndsAt - workspace:GetServerTimeNow()
end

local function refreshPotionTimer()
	local remaining = potionRemaining()
	ui.potionLabel.Visible = remaining > 0
	ui.potionLabel.Text = "물약 " .. formatTime(remaining)

	local potion = ui.upgradeRows.potion
	local info = string.format(
		"%d분 동안 행운 ×%s, 돌리는 시간·무료 대기 ×%s",
		Config.POTION_DURATION // 60,
		tostring(Config.POTION_LUCK_MULT),
		tostring(Config.POTION_SPEED_MULT)
	)
	if remaining > 0 then
		info ..= "\n남은 시간 " .. formatTime(remaining) .. " (사면 시간이 늘어납니다)"
	end
	potion.info.Text = info
end

local function setUpgradeButton(btn: TextButton, cost: number?)
	if not cost then
		setButton(btn, "최대 단계", false, COLORS.gold)
	else
		setButton(btn, Gacha.FormatNumber(cost) .. "코인", state.coins >= cost, COLORS.gold)
	end
end

local function refreshUpgrades()
	local rows = ui.upgradeRows

	-- 행운
	local luckLevel = state.luckLevel
	local luckMax = #Config.LUCK_COST
	local luckCost = Config.LUCK_COST[luckLevel + 1]
	rows.luck.title.Text = string.format("행운  Lv %d/%d", luckLevel, luckMax)
	if luckCost then
		rows.luck.info.Text = string.format(
			"레어 이상 확률 ×%.1f → ×%.1f",
			Config.LUCK_MULT[luckLevel],
			Config.LUCK_MULT[luckLevel + 1]
		)
	else
		rows.luck.info.Text = string.format("레어 이상 확률 ×%.1f (최대)", Config.LUCK_MULT[luckLevel])
	end
	setUpgradeButton(rows.luck.button, luckCost)

	-- 속도 (물약 효과는 빼고 업그레이드만의 값)
	local speedLevel = state.speedLevel
	local speedMax = #Config.SPEED_COST
	local speedCost = Config.SPEED_COST[speedLevel + 1]
	rows.speed.title.Text = string.format("속도  Lv %d/%d", speedLevel, speedMax)
	local reelNow = Gacha.GetReelTime(speedLevel, 1)
	local cooldownNow = Gacha.GetFreeCooldown(speedLevel, 1)
	if speedCost then
		rows.speed.info.Text = string.format(
			"돌리는 시간 %.1f초 → %.1f초\n무료 대기 %.1f초 → %.1f초",
			reelNow,
			Gacha.GetReelTime(speedLevel + 1, 1),
			cooldownNow,
			Gacha.GetFreeCooldown(speedLevel + 1, 1)
		)
	else
		rows.speed.info.Text = string.format("돌리는 시간 %.1f초, 무료 대기 %.1f초 (최대)", reelNow, cooldownNow)
	end
	setUpgradeButton(rows.speed.button, speedCost)

	-- 물약
	rows.potion.title.Text = "물약"
	setButton(
		rows.potion.button,
		Gacha.FormatNumber(currentPotionCost()) .. "코인",
		state.coins >= currentPotionCost(),
		COLORS.gold
	)
	refreshPotionTimer()
end

local selectedSlots = {} -- ["영역:자리 번호"] = { area, index } 빼려고 고른 자리들 (여러 개)
local pickingSlot = nil -- { area, index } 장식을 고르는 중인 빈 자리
local placeIntoSlot -- (stack, area, index) 아래에서 정한다

local function slotKey(area: string, index: number): string
	return area .. ":" .. index
end

local function treeEntry(area: string, index: number)
	for _, entry in state.tree do
		if entry.a == area and entry.i == index then
			return entry
		end
	end
	return nil
end

local function refreshTreeIncome()
	if not state then
		return
	end
	local minutes = (workspace:GetServerTimeNow() - state.displayStartedAt) / 60
	ui.treeInfo.Text = string.format(
		"초당 %s코인 · 전시 보너스 ×%.2f (접속해 있는 동안 최대 ×%s까지 오릅니다)",
		formatIncome(currentIncome()),
		Gacha.GetDisplayBonus(minutes),
		tostring(Config.DISPLAY_BONUS_MAX)
	)
end

-- 빈 자리에 걸 장식 목록 (그 영역 장식만)
local function refreshPicker()
	for _, child in ui.treePickerList:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	if not pickingSlot then
		ui.treePicker.Visible = false
		return
	end
	ui.treePicker.Visible = true
	ui.treePickerTitle.Text = string.format("%s에 걸 장식을 골라 주세요", slotName(pickingSlot.area, pickingSlot.index))

	local count = 0
	for _, stack in sortedStacks() do
		local deco, trait = stackInfo(stack)
		if deco.area ~= pickingSlot.area or stack.c <= 0 then
			continue
		end
		count += 1
		local r = Rarity.List[deco.rarity]
		local row = create("TextButton", {
			Text = "",
			AutoButtonColor = true,
			BackgroundColor3 = COLORS.panelLight,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -8, 0, 40),
			LayoutOrder = count,
			ZIndex = 3,
			Parent = ui.treePickerList,
		})
		corner(row, 8)
		create("UIStroke", { Color = r.color, Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = row })
		scaledLabel({
			Text = string.format("%s ×%s", itemName(deco, trait, stack.p), Gacha.FormatNumber(stack.c)),
			TextColor3 = if trait == Catalog.BaseTrait then COLORS.text else traitColor(trait),
			Size = UDim2.new(1, -110, 1, 0),
			Position = UDim2.fromOffset(10, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			ZIndex = 3,
			Parent = row,
		}, 15, 9)
		label({
			Text = r.name,
			TextSize = 13,
			TextColor3 = r.color,
			Size = UDim2.new(0, 90, 1, 0),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -10, 0, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			ZIndex = 3,
			Parent = row,
		})
		local slot = pickingSlot
		row.Activated:Connect(function()
			placeIntoSlot(stack, slot.area, slot.index)
		end)
	end
	ui.treePickerEmpty.Visible = count == 0
end

local function refreshTree()
	ui.treeTitle.Text = "내 트리 · 가치 " .. Gacha.FormatNumber(state.treeValue) .. "코인"
	refreshTreeIncome()

	-- 고른 자리 중 이제 비어 있는 곳은 빼고, 고르는 중인 자리가 채워졌으면 닫는다
	for key, slot in selectedSlots do
		if not treeEntry(slot.area, slot.index) then
			selectedSlots[key] = nil
		end
	end
	if pickingSlot and treeEntry(pickingSlot.area, pickingSlot.index) then
		pickingSlot = nil
	end

	for _, area in TREE_AREAS do
		for index, cell in ui.treeCells[area.id] do
			local entry = treeEntry(area.id, index)
			local deco = entry and Catalog.DecorationById[entry.d]
			local trait = entry and Catalog.TraitById[entry.t]
			local selected = selectedSlots[slotKey(area.id, index)] ~= nil
				or (pickingSlot ~= nil and pickingSlot.area == area.id and pickingSlot.index == index)
			if deco and trait then
				local color = Rarity.List[deco.rarity].color
				cell.name.Text = paintedName(deco, entry.p)
				cell.name.TextColor3 = color
				cell.trait.Text = if trait == Catalog.BaseTrait then "" else trait.name
				cell.trait.TextColor3 = traitColor(trait)
				cell.trait.TextXAlignment = Enum.TextXAlignment.Left
				cell.trait.TextSize = 10
				cell.stroke.Color = if selected then COLORS.text else color
			else
				cell.name.Text = "빈 자리"
				cell.name.TextColor3 = COLORS.subText
				-- 빈 칸 위쪽 가운데에 자리 번호 (아래에서 몇 번째. 토퍼는 하나라 표시 안 함)
				cell.trait.Text = if area.count > 1 then tostring(slotRank[area.id][index] or index) else ""
				cell.trait.TextColor3 = COLORS.subText
				cell.trait.TextXAlignment = Enum.TextXAlignment.Center
				cell.trait.TextSize = 13
				cell.stroke.Color = if selected then COLORS.text else COLORS.disabled
			end
			cell.stroke.Thickness = if selected then 3 else 2
			cell.button.BackgroundColor3 = if selected then COLORS.panelHover else COLORS.panelLight
		end
	end

	refreshPicker()

	-- 고른 자리들
	local chosen = {}
	for _, slot in selectedSlots do
		table.insert(chosen, slot)
	end
	if #chosen == 1 then
		local entry = treeEntry(chosen[1].area, chosen[1].index)
		local deco = entry and Catalog.DecorationById[entry.d]
		local trait = entry and Catalog.TraitById[entry.t]
		if deco and trait then
			local r = Rarity.List[deco.rarity]
			ui.treeDetail.Text = string.format(
				"%s [%s] 가치 %s코인",
				itemName(deco, trait, entry.p),
				r.name,
				Gacha.FormatNumber(Gacha.GetItemValue(deco.rarity, trait.mult))
			)
			ui.treeDetail.TextColor3 = r.color
		end
	elseif #chosen > 1 then
		local total = 0
		for _, slot in chosen do
			local entry = treeEntry(slot.area, slot.index)
			local deco = entry and Catalog.DecorationById[entry.d]
			local trait = entry and Catalog.TraitById[entry.t]
			if deco and trait then
				total += Gacha.GetItemValue(deco.rarity, trait.mult)
			end
		end
		ui.treeDetail.Text = string.format("%d개를 골랐습니다 · 가치 합 %s코인", #chosen, Gacha.FormatNumber(total))
		ui.treeDetail.TextColor3 = COLORS.text
	end
	if #chosen > 0 then
		ui.treeRemove.Visible = true
		setButton(ui.treeRemove, if #chosen == 1 then "빼기" else string.format("%d개 빼기", #chosen), true, COLORS.panelHover)
	else
		ui.treeDetail.Text = "빈 자리를 누르면 장식을 걸 수 있습니다. 걸린 칸을 여러 개 눌러 한 번에 뺄 수 있습니다."
		ui.treeDetail.TextColor3 = COLORS.subText
		ui.treeRemove.Visible = false
	end
end

local function isAutoSold(rarityIndex: number): boolean
	return bit32.btest(state.autoSellMask or 0, 2 ^ (rarityIndex - 1))
end

-- 자동 판매 칸: 잠김(자물쇠) = 보관, 풀림(등급 이름) = 뽑자마자 판매. 켤 수 없는 높은 등급은 늘 흐린 자물쇠
local function refreshAutoSell()
	if not state then
		return
	end
	for i, chip in ui.autoSellChips do
		local r = Rarity.List[i]
		local selling = isAutoSold(i)
		local allowed = i <= Config.AUTO_SELL_MAX_OPTION
		chip.name.Visible = selling
		chip.lock.Visible = not selling
		chip.button.BackgroundColor3 = if selling then COLORS.panelHover else COLORS.panelLight
		chip.stroke.Thickness = if selling then 2.5 else 1.5
		chip.stroke.Transparency = if allowed then 0 else 0.6
		if chip.lock:IsA("ImageLabel") then
			chip.lock.ImageTransparency = if allowed then 0 else 0.6
		end
	end
end

local function applyState(newState)
	state = newState
	refreshAutoSell()
	refreshCoins()
	refreshOdds()
	GachaUI.RefreshBag()
	refreshUpgrades()
	refreshTree()
end

local function refreshSpinButtons()
	if not state then
		return
	end
	if spinning then
		setButton(ui.freeButton, "돌리는 중...", false, COLORS.green)
		setButton(ui.coinButton, "돌리는 중...", false, COLORS.gold)
		return
	end

	local remaining = state.nextFreeSpinAt - workspace:GetServerTimeNow()
	if remaining > 0 then
		setButton(ui.freeButton, string.format("무료 · %d초", math.ceil(remaining)), false, COLORS.green)
	else
		setButton(ui.freeButton, "무료 돌리기", true, COLORS.green)
	end

	local cost = currentCoinSpinCost()
	setButton(ui.coinButton, Gacha.FormatNumber(cost) .. "코인 돌리기", state.coins >= cost, COLORS.gold)
end

local toastToken = 0
local function showToast(text: string, color: Color3)
	toastToken += 1
	local token = toastToken
	ui.toastLabel.Text = text
	ui.toastStroke.Color = color
	ui.toast.Visible = true
	TweenService:Create(ui.toast, TweenInfo.new(0.25), { GroupTransparency = 0 }):Play()
	task.delay(4, function()
		if token ~= toastToken then
			return
		end
		local tween = TweenService:Create(ui.toast, TweenInfo.new(0.5), { GroupTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		if token == toastToken then
			ui.toast.Visible = false
		end
	end)
end

----------------------------------------------------------------
-- 연출
----------------------------------------------------------------

local function setReel(i: number, text: string, color: Color3)
	local reel = ui.reels[i]
	reel.text.Text = text
	reel.text.TextColor3 = color
	reel.stroke.Color = color
end

local function showRarityReel(index: number)
	local r = Rarity.List[index]
	setReel(1, r.name, r.color)
end

local function showDecoReel(deco)
	setReel(2, deco.name, Rarity.List[deco.rarity].color)
end

local function showTraitReel(trait)
	setReel(3, trait.name, traitColor(trait))
end

local function popReel(i: number, size: number, duration: number, style: Enum.EasingStyle?)
	local scale = ui.reels[i].scale
	scale.Scale = size
	TweenService:Create(scale, TweenInfo.new(duration, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()
end

-- 연출에서 무작위로 보여줄 목록 (그만 나오는 것 제외)
local activeDecos = {}
local activeTraits = {}
for _, deco in Catalog.Decorations do
	if not deco.retired then
		table.insert(activeDecos, deco)
	end
end
for _, trait in Catalog.Traits do
	if not trait.retired then
		table.insert(activeTraits, trait)
	end
end

local function randomFrom(list)
	return list[math.random(1, #list)]
end

-- 슬롯 3칸이 같이 돌다가 등급·장식이 함께 멈추고, 마지막에 특성이 멈춘다 (전체 시간의 60% · 60% · 100% 지점)
-- 특성 칸이 혼자 남는 시간(5초면 2초)에 한 칸씩 뜸을 들여 긴장감을 준다
-- 등급이 먼저 멈추면 나올 수 없는 장식이 계속 지나가서 기대가 없으므로 둘을 같은 순간에 멈춘다
-- 도는 동안에는 두 칸이 따로 무작위로 돌고, 멈출 때만 실제 결과로 맞춰진다
-- 전체 시간은 서버가 정한다(REEL_STOP_TIME). 여기서는 칸이 넘어가는 간격만 정한다
local REEL_STOP_FRACTIONS = { 0.6, 0.6, 1.0 }
local REEL_FAST_GAP = 1 / 14 -- 빠르게 돌 때 한 칸 넘어가는 간격(초)
-- 멈추기 직전 마지막 간격(그 칸이 멈추는 시간에 대한 비율)과, 한 칸 앞으로 갈수록 간격에 곱하는 값
-- 특성 칸(3번)은 마지막 간격이 길어서 끝에서 한 칸씩 뜸을 들이며 넘어간다 (5초면 0.5 → 0.64 → 0.8초)
-- 비율이라 속도 업그레이드로 전체 시간이 줄어도 느려지는 느낌은 같다
local REEL_LAST_GAP = { 0.08, 0.08, 0.16 }
local REEL_GAP_RATIO = { 0.75, 0.75, 0.8 }

-- 칸이 바뀌는 시각들 (마지막이 stopTime). 끝에서부터 간격을 늘려 가며 거꾸로 만든다
local function reelTimes(stopTime: number, lastGapFraction: number, ratio: number): { number }
	local backwards = { stopTime }
	local t = stopTime
	local gap = stopTime * lastGapFraction
	while true do
		t -= gap
		if t <= 0 then
			break
		end
		table.insert(backwards, t)
		gap = math.max(gap * ratio, REEL_FAST_GAP)
	end
	local times = {}
	for i = #backwards, 1, -1 do
		table.insert(times, backwards[i])
	end
	return times
end

local function playReel(rarityIndex: number, deco, trait, duration: number)
	local finals = { rarityIndex, deco, trait }
	local showers = { showRarityReel, showDecoReel, showTraitReel }
	local pickers = {
		function()
			return math.random(1, Rarity.Count)
		end,
		function()
			return randomFrom(activeDecos)
		end,
		function()
			return randomFrom(activeTraits)
		end,
	}

	local reels = {}
	for i = 1, 3 do
		local stopTime = duration * REEL_STOP_FRACTIONS[i]
		local times = reelTimes(stopTime, REEL_LAST_GAP[i], REEL_GAP_RATIO[i])
		local steps = #times
		local sequence = table.create(steps)
		local prev = nil
		for s = 1, steps - 1 do
			local pick
			local tries = 0
			repeat
				pick = pickers[i]()
				tries += 1
			until (pick ~= prev and (s < steps - 1 or pick ~= finals[i])) or tries > 10
			sequence[s] = pick
			prev = pick
		end
		sequence[steps] = finals[i]
		reels[i] = { stopTime = stopTime, times = times, steps = steps, sequence = sequence, shown = 0, done = false }
	end

	ui.reelSub.Text = ""
	local slowStart = duration * REEL_STOP_FRACTIONS[2] -- 앞 두 칸이 멈춘 뒤 특성 칸만 남았을 때
	local start = os.clock()
	while true do
		local elapsed = os.clock() - start
		local allDone = true
		for i, reel in reels do
			if reel.done then
				continue
			end
			-- 지금까지 지난 칸 수
			local step = 1
			while step < reel.steps and reel.times[step] <= elapsed do
				step += 1
			end
			if elapsed >= reel.stopTime then
				step = reel.steps
			end
			if step ~= reel.shown then
				reel.shown = step
				showers[i](reel.sequence[step])
				if step == reel.steps then
					-- 멈춘 칸은 크게 튕긴다. 특성 칸은 더 크게
					popReel(i, if i == 3 then 1.45 else 1.3, if i == 3 then 0.45 else 0.3, Enum.EasingStyle.Back)
				elseif i == 3 and elapsed >= slowStart then
					popReel(i, 1.14, 0.15) -- 특성 칸만 남으면 넘어갈 때마다 쿵쿵 크게 뛴다
				else
					popReel(i, 1.08, 0.08)
				end
			end
			if elapsed >= reel.stopTime then
				reel.done = true
			else
				allDone = false
			end
		end
		if allDone then
			break
		end
		RunService.RenderStepped:Wait()
	end
end

local function playResultEffect(rarityIndex: number, deco, trait, paintId: string?)
	local r = Rarity.List[rarityIndex]
	local probs = Gacha.GetProbabilities(state.luck)
	local value = Gacha.GetItemValue(rarityIndex, trait.mult)
	ui.reelSub.Text = string.format("%s · 가치 %s코인", Gacha.FormatOdds(probs[rarityIndex]), Gacha.FormatNumber(value))

	if rarityIndex < Config.EFFECT_MIN_RARITY then
		return
	end

	-- 등급이 높을수록 더 많이 번쩍인다
	local flashes = rarityIndex - Config.EFFECT_MIN_RARITY + 1
	task.spawn(function()
		for _ = 1, flashes do
			ui.flash.BackgroundColor3 = r.color
			ui.flash.BackgroundTransparency = 0.45
			local tween = TweenService:Create(ui.flash, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
			tween:Play()
			tween.Completed:Wait()
		end
	end)

	-- 서버 공지가 안 뜨는 등급은 본인에게만 알림
	if rarityIndex < Config.SERVER_ANNOUNCE_MIN_RARITY then
		showToast(string.format("%s [%s] 뽑았습니다!", itemName(deco, trait, paintId), r.name), r.color)
	end

	-- 시크릿은 무지개색으로 반짝인다
	if rarityIndex == Rarity.Count then
		task.spawn(function()
			local start = os.clock()
			while os.clock() - start < 3 do
				local color = Color3.fromHSV(((os.clock() - start) * 0.8) % 1, 0.8, 1)
				for i = 1, 3 do
					ui.reels[i].stroke.Color = color
				end
				ui.reels[1].text.TextColor3 = color
				RunService.RenderStepped:Wait()
			end
			showRarityReel(rarityIndex)
			showDecoReel(deco)
			showTraitReel(trait)
		end)
	end
end

----------------------------------------------------------------
-- 동작
----------------------------------------------------------------

local function spin(kind: string)
	if spinning or not state then
		return
	end
	spinning = true
	setStatus("")
	refreshSpinButtons()

	local ok, result = pcall(function()
		return Remotes.Spin:InvokeServer(kind)
	end)
	if not ok or type(result) ~= "table" then
		spinning = false
		setStatus("서버와 연결이 불안정합니다. 다시 눌러 주세요")
		return
	end
	if not result.ok then
		spinning = false
		setStatus(result.reason or "지금은 돌릴 수 없습니다")
		return
	end

	local deco = Catalog.DecorationById[result.decoId]
	local trait = Catalog.TraitById[result.traitId]

	-- 쓴 코인과 쿨타임은 바로, 가방과 자동 판매 코인은 슬롯이 멈춘 뒤에 반영
	state.coins = result.coinsAfterCost
	state.nextFreeSpinAt = result.state.nextFreeSpinAt
	refreshCoins()

	playReel(result.rarity, deco, trait, result.reelTime)
	applyState(result.state)
	playResultEffect(result.rarity, deco, trait, result.paintId)
	if result.autoSold then
		ui.reelSub.Text = string.format("자동 판매 +%s코인", Gacha.FormatNumber(result.saleCoins))
	end
	spinning = false
end

-- 가방 요청 공통 처리
local function bagRequest(remote: RemoteFunction, ...)
	if spinning or not state then
		setStatus("룰렛이 멈춘 뒤에 할 수 있습니다")
		return nil
	end
	local args = table.pack(...)
	local ok, result = pcall(function()
		return remote:InvokeServer(table.unpack(args, 1, args.n))
	end)
	if not ok or type(result) ~= "table" then
		setStatus("서버와 연결이 불안정합니다. 다시 눌러 주세요")
		return nil
	end
	if not result.ok then
		setStatus(result.reason or "지금은 할 수 없습니다")
		if not ui.slot.Visible then
			-- 룰렛 창이 닫혀 있으면 안내 글이 안 보이므로 공지로 띄운다
			showToast(result.reason or "지금은 할 수 없습니다", COLORS.error)
		end
		return nil
	end
	setStatus("")
	applyState(result.state)
	return result
end

-- 확인이 필요하면 첫 번째 누름에서는 버튼만 바꾸고 false를 돌려준다
local function confirmFirst(name: string, needsConfirm: boolean): boolean
	if not needsConfirm or isConfirming(name) then
		confirmUntil[name] = 0
		return true
	end
	confirmUntil[name] = os.clock() + 3
	refreshSellButtons()
	task.delay(3.05, function()
		if state then
			refreshSellButtons()
		end
	end)
	return false
end

local function showSaleToast(result)
	showToast(
		string.format("장식 %s개 판매 +%s코인", Gacha.FormatNumber(result.sold), Gacha.FormatNumber(result.gained)),
		COLORS.gold
	)
end

local function sellAll()
	if not state then
		return
	end
	local total, needsConfirm = getSellAllPreview()
	if total <= 0 or not confirmFirst("all", needsConfirm) then
		return
	end
	local result = bagRequest(Remotes.Sell)
	if result then
		showSaleToast(result)
	end
end

local function sellSelected()
	local stack = findStateStack(selectedKey)
	if not stack or stack.l then
		return
	end
	local deco = stackInfo(stack)
	if not confirmFirst("one", deco.rarity >= Config.SELL_CONFIRM_MIN_RARITY) then
		return
	end
	local result = bagRequest(Remotes.Sell, stackKey(stack))
	if result then
		showSaleToast(result)
	end
end

local function toggleSelectedLock()
	local stack = findStateStack(selectedKey)
	if stack then
		bagRequest(Remotes.SetLock, stackKey(stack), not stack.l)
	end
end

local function upgrade(kind: string)
	local result = bagRequest(Remotes.Upgrade, kind)
	if result then
		local name = if kind == "luck" then "행운" else "속도"
		showToast(string.format("%s Lv %d이 되었습니다", name, result.level), COLORS.gold)
	end
end

local function buyPotion()
	local result = bagRequest(Remotes.BuyPotion)
	if result then
		showToast("물약을 마셨습니다. 남은 시간 " .. formatTime(potionRemaining()), COLORS.gold)
	end
end

local function placeSelected()
	local stack = findStateStack(selectedKey)
	if not stack then
		return
	end
	local result = bagRequest(Remotes.PlaceDecoration, stackKey(stack))
	if result then
		showToast(
			string.format("트리의 %s에 걸었습니다", slotName(result.area, result.index)),
			COLORS.green
		)
	end
end

local function removeSelectedSlots()
	local slots = {}
	for _, slot in selectedSlots do
		table.insert(slots, { a = slot.area, i = slot.index })
	end
	if #slots == 0 then
		return
	end
	local result = bagRequest(Remotes.RemoveDecoration, slots)
	if result then
		selectedSlots = {}
		refreshTree()
		showToast(string.format("장식 %d개를 가방에 넣었습니다", result.removed or #slots), COLORS.gold)
	end
end

-- 고른 빈 자리에 가방의 장식을 건다
placeIntoSlot = function(stack, area: string, index: number)
	local result = bagRequest(Remotes.PlaceDecoration, stackKey(stack), index)
	if result then
		pickingSlot = nil
		refreshTree()
		showToast(string.format("트리의 %s에 걸었습니다", slotName(area, index)), COLORS.green)
	end
end

-- 룰렛 창과 확률표. 열려 있으면 버튼 테두리를 금색으로 표시한다
local function setRouletteOpen(open: boolean)
	ui.slot.Visible = open
	ui.odds.Visible = open
	ui.rouletteStroke.Color = if open then COLORS.gold else Color3.new(1, 1, 1)
	ui.rouletteStroke.Transparency = if open then 0 else 0.85
end

local function setTreeOpen(open: boolean)
	ui.treeWindow.Visible = open
	selectedSlots = {}
	pickingSlot = nil
	if open then
		ui.inventory.Visible = false
		ui.upgradeWindow.Visible = false
		selectedKey = nil
	end
	if state then
		refreshTree()
	end
end

local function setUpgradeOpen(open: boolean)
	ui.upgradeWindow.Visible = open
	if open then
		ui.inventory.Visible = false
		ui.treeWindow.Visible = false
		selectedKey = nil
	end
end

local function setInventoryOpen(open: boolean)
	if open then
		ui.upgradeWindow.Visible = false
		ui.treeWindow.Visible = false
	end
	ui.inventory.Visible = open
	if not open then
		selectedKey = nil
	end
	if state then
		GachaUI.RefreshBag()
	end
end

local function onAnnounce(data)
	if type(data) ~= "table" then
		return
	end
	local deco = Catalog.DecorationById[data.decoId]
	local trait = Catalog.TraitById[data.traitId]
	if not deco or not trait then
		return
	end
	local r = Rarity.List[deco.rarity]
	local prefix = if data.global then "[전체]" else "[서버]"
	showToast(
		string.format(
			"%s %s님이 뽑았습니다: %s [%s] (%s)",
			prefix,
			tostring(data.playerName),
			itemName(deco, trait),
			r.name,
			Gacha.FormatOdds(1 / r.n)
		),
		r.color
	)
end

function GachaUI.Start()
	buildUI()

	-- 서버에 내 데이터가 준비될 때까지 기다린다
	local initial
	repeat
		local ok, result = pcall(function()
			return Remotes.GetState:InvokeServer()
		end)
		if ok then
			initial = result
		end
		if not initial then
			task.wait(0.5)
		end
	until initial
	applyState(initial)

	ui.freeButton.Activated:Connect(function()
		spin("free")
	end)
	ui.coinButton.Activated:Connect(function()
		spin("coin")
	end)
	for i, chip in ui.autoSellChips do
		chip.button.Activated:Connect(function()
			if not state or i > Config.AUTO_SELL_MAX_OPTION then
				return
			end
			-- 설정만 바꾸는 요청이라 룰렛이 도는 중에도 된다
			local ok, result = pcall(function()
				return Remotes.SetAutoSellRarity:InvokeServer(i, not isAutoSold(i))
			end)
			if ok and type(result) == "table" and result.ok then
				applyState(result.state)
			end
		end)
	end
	ui.rouletteButton.Activated:Connect(function()
		setRouletteOpen(not ui.slot.Visible)
	end)
	ui.bagButton.Activated:Connect(function()
		setInventoryOpen(not ui.inventory.Visible)
	end)
	ui.invClose.Activated:Connect(function()
		setInventoryOpen(false)
	end)
	ui.upgradeButton.Activated:Connect(function()
		setUpgradeOpen(not ui.upgradeWindow.Visible)
	end)
	ui.upgradeClose.Activated:Connect(function()
		setUpgradeOpen(false)
	end)
	ui.upgradeRows.luck.button.Activated:Connect(function()
		upgrade("luck")
	end)
	ui.upgradeRows.speed.button.Activated:Connect(function()
		upgrade("speed")
	end)
	ui.upgradeRows.potion.button.Activated:Connect(buyPotion)
	ui.sellAllButton.Activated:Connect(sellAll)
	ui.detailLock.Activated:Connect(toggleSelectedLock)
	ui.detailSell.Activated:Connect(sellSelected)
	ui.detailPlace.Activated:Connect(placeSelected)
	ui.treeButton.Activated:Connect(function()
		setTreeOpen(not ui.treeWindow.Visible)
	end)
	ui.treeClose.Activated:Connect(function()
		setTreeOpen(false)
	end)
	ui.treeRemove.Activated:Connect(removeSelectedSlots)
	ui.treePickerClose.Activated:Connect(function()
		pickingSlot = nil
		refreshTree()
	end)
	for _, area in TREE_AREAS do
		for index, cell in ui.treeCells[area.id] do
			cell.button.Activated:Connect(function()
				if treeEntry(area.id, index) then
					-- 걸린 칸: 빼기 목록에 넣거나 뺀다 (여러 개 고를 수 있다)
					local key = slotKey(area.id, index)
					selectedSlots[key] = if selectedSlots[key] then nil else { area = area.id, index = index }
					pickingSlot = nil
				else
					-- 빈 칸: 그 자리에 걸 장식 고르기를 연다 (같은 칸을 다시 누르면 닫는다)
					local same = pickingSlot and pickingSlot.area == area.id and pickingSlot.index == index
					pickingSlot = if same then nil else { area = area.id, index = index }
				end
				refreshTree()
			end)
		end
	end
	Remotes.Announce.OnClientEvent:Connect(onAnnounce)

	-- 리더보드 코인이 바뀌면 화면에도 반영
	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats")
		local coinsValue = leaderstats:WaitForChild("Coins")
		coinsValue.Changed:Connect(function(value)
			-- 돌리는 중에는 자동 판매 코인이 결과를 미리 알려주지 않도록 무시한다
			if state and not spinning then
				state.coins = value
				refreshCoins()
				refreshUpgrades()
			end
		end)
	end)

	task.spawn(function()
		local potionWasActive = potionRemaining() > 0
		while true do
			refreshSpinButtons()
			refreshPotionTimer()
			if ui.treeWindow.Visible then
				refreshTreeIncome()
			end

			-- 물약이 끝나면 행운·속도가 바뀌므로 서버 값을 다시 받는다
			local potionActive = potionRemaining() > 0
			if potionWasActive and not potionActive and not spinning then
				local ok, result = pcall(function()
					return Remotes.GetState:InvokeServer()
				end)
				if ok and result then
					applyState(result)
				end
			end
			potionWasActive = potionActive
			task.wait(0.1)
		end
	end)
end

return GachaUI
