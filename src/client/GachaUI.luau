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

-- "반짝이 빨간 공" (기본 특성이면 장식 이름만)
local function itemName(deco, trait): string
	if trait == Catalog.BaseTrait then
		return deco.name
	end
	return trait.name .. " " .. deco.name
end

local function stackInfo(stack)
	return Catalog.DecorationById[stack.d], Catalog.TraitById[stack.t]
end

local function stackKey(stack): string
	return stack.d .. ":" .. stack.t
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
		Size = UDim2.fromOffset(520, 280),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Parent = gui,
	})
	label({
		Text = "장식 룰렛",
		TextSize = 20,
		Size = UDim2.new(0.6, 0, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = slot,
	})
	ui.coins = label({
		Text = "코인 0",
		TextSize = 18,
		TextColor3 = COLORS.gold,
		Size = UDim2.new(0.4, 0, 0, 28),
		Position = UDim2.fromScale(0.6, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
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
		Text = "버튼을 눌러 룰렛을 돌리십시오",
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
	ui.status = label({
		Text = "",
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.errorText,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 230),
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
		Position = UDim2.new(1, -16, 1, -20),
		Parent = gui,
	})
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
		Text = "아직 장식이 없습니다. 룰렛을 돌려 보십시오.",
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
		Size = UDim2.new(1, -230, 0, 26),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = detail,
	}, 18, 10)
	ui.detailInfo = scaledLabel({
		Text = "칸을 눌러 장식을 고르십시오",
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.subText,
		Size = UDim2.new(1, -230, 0, 20),
		Position = UDim2.fromOffset(0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = detail,
	}, 13, 9)
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

	-- 아래 버튼: 모두 판매 · 자동 판매
	ui.sellAllButton = button({
		Text = "모두 판매",
		TextSize = 15,
		Size = UDim2.new(0.55, -4, 0, 44),
		Position = UDim2.new(0, 0, 1, -44),
		Parent = window,
	})
	ui.autoSellButton = button({
		Text = "자동 판매: 끔",
		TextSize = 14,
		Size = UDim2.new(0.45, -4, 0, 44),
		Position = UDim2.new(0.55, 4, 1, -44),
		Parent = window,
	})
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
	buildBagButton(gui)
	buildInventory(gui)

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

local function setStatus(text: string)
	ui.status.Text = text
end

local function refreshCoins()
	ui.coins.Text = "코인 " .. Gacha.FormatNumber(state.coins)
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
		return itemName(decoA, traitA) < itemName(decoB, traitB)
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

	-- 자동 판매
	local level = state.autoSellMax
	ui.autoSellButton.BackgroundColor3 = COLORS.panelLight
	if level <= 0 then
		ui.autoSellButton.Text = "자동 판매: 끔"
		ui.autoSellButton.TextColor3 = COLORS.subText
	else
		local r = Rarity.List[level]
		ui.autoSellButton.Text = string.format("자동 판매: %s 이하", r.name)
		ui.autoSellButton.TextColor3 = r.color
	end

	-- 선택한 칸
	local stack = findStateStack(selectedKey)
	if not stack then
		ui.detailName.Text = ""
		ui.detailInfo.Text = "칸을 눌러 장식을 고르십시오"
		ui.detailLock.Visible = false
		ui.detailSell.Visible = false
		return
	end
	local deco, trait = stackInfo(stack)
	local r = Rarity.List[deco.rarity]
	local value = Gacha.GetItemValue(deco.rarity, trait.mult)
	ui.detailName.Text = string.format("%s ×%s", itemName(deco, trait), Gacha.FormatNumber(stack.c))
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
		Text = deco.name,
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

local function applyState(newState)
	state = newState
	refreshCoins()
	refreshOdds()
	GachaUI.RefreshBag()
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

	local cost = state.coinSpinCost
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

-- 슬롯 3칸이 같이 돌다가 등급 → 장식 → 특성 순서로 멈춘다 (전체 시간의 45% · 75% · 100% 지점)
local REEL_STOP_FRACTIONS = { 0.45, 0.75, 1.0 }

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
		local steps = math.max(8, math.floor(stopTime * 14))
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
		reels[i] = { stopTime = stopTime, steps = steps, sequence = sequence, shown = 0, done = false }
	end

	ui.reelSub.Text = ""
	local start = os.clock()
	while true do
		local elapsed = os.clock() - start
		local allDone = true
		for i, reel in reels do
			if reel.done then
				continue
			end
			local alpha = math.clamp(elapsed / reel.stopTime, 0, 1)
			local eased = 1 - (1 - alpha) ^ 3
			local step = if alpha >= 1
				then reel.steps
				else math.clamp(math.floor(eased * (reel.steps - 1)) + 1, 1, reel.steps)
			if step ~= reel.shown then
				reel.shown = step
				showers[i](reel.sequence[step])
				if step == reel.steps then
					popReel(i, 1.3, 0.3, Enum.EasingStyle.Back) -- 멈춘 칸은 크게 튕긴다
				else
					popReel(i, 1.08, 0.08)
				end
			end
			if alpha >= 1 then
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

local function playResultEffect(rarityIndex: number, deco, trait)
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
		showToast(string.format("%s [%s] 뽑았습니다!", itemName(deco, trait), r.name), r.color)
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
		setStatus("서버와 연결이 불안정합니다. 다시 눌러 주십시오")
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
	playResultEffect(result.rarity, deco, trait)
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
		setStatus("서버와 연결이 불안정합니다. 다시 눌러 주십시오")
		return nil
	end
	if not result.ok then
		setStatus(result.reason or "지금은 할 수 없습니다")
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

local function cycleAutoSell()
	if not state then
		return
	end
	local nextLevel = (state.autoSellMax + 1) % (Config.AUTO_SELL_MAX_OPTION + 1)
	bagRequest(Remotes.SetAutoSell, nextLevel)
end

local function setInventoryOpen(open: boolean)
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
	ui.bagButton.Activated:Connect(function()
		setInventoryOpen(not ui.inventory.Visible)
	end)
	ui.invClose.Activated:Connect(function()
		setInventoryOpen(false)
	end)
	ui.sellAllButton.Activated:Connect(sellAll)
	ui.autoSellButton.Activated:Connect(cycleAutoSell)
	ui.detailLock.Activated:Connect(toggleSelectedLock)
	ui.detailSell.Activated:Connect(sellSelected)
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
			end
		end)
	end)

	task.spawn(function()
		while true do
			refreshSpinButtons()
			task.wait(0.1)
		end
	end)
end

return GachaUI
