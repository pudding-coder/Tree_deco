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

-- 버튼 아이콘 (Basic_UI_Pack의 이미지 id). 바꾸려면 id만 고치고, 빼려면 "" 로 둔다
-- 팩의 다른 아이콘: Settings 109558273647021, Rebirth 138533388378565, Gift 98765217070709, Gems 108846984313264,
--   Play 104915011936755, Confirm 82767374889976, SoundOn 91961227251741, Music 125047975849256,
--   Friends 138393293744051, Leaderboard 122400187905753, Quests 77359789350483, DailyReward 97419429998550,
--   Teleport 128940707580259, Help 71148853828725
local ICONS = {
	bag = "rbxassetid://95338657327605", -- 가방 버튼 (팩 Inventory)
	upgrade = "rbxassetid://113532507482722", -- 업그레이드 버튼 (팩 Upgrade)
	tree = "rbxassetid://100186608972356", -- 내 트리 버튼 (팩 Home)
	roulette = "rbxassetid://104915011936755", -- 룰렛 버튼 (팩 Play)
	shop = "rbxassetid://132000942692847", -- 상점 버튼 (팩 Shop)
	coins = "rbxassetid://132123388448433", -- 오른쪽 아래 코인 칸 (팩 Coins)
	close = "rbxassetid://93352627659643", -- 창 닫기 X 버튼 (팩 Close)
}
local MENU_ICON_SIZE = 40 -- 왼쪽 아래 메뉴 버튼 아이콘 크기(픽셀)

local COLORS = {
	panel = Color3.fromRGB(30, 42, 78), -- 창 배경
	panelLight = Color3.fromRGB(52, 70, 120), -- 창 안 버튼·칸 배경
	panelHover = Color3.fromRGB(78, 100, 160), -- 고른 칸·끄기 버튼
	text = Color3.fromRGB(242, 245, 250),
	subText = Color3.fromRGB(160, 172, 190),
	green = Color3.fromRGB(40, 168, 92),
	gold = Color3.fromRGB(226, 170, 40),
	disabled = Color3.fromRGB(68, 76, 90),
	error = Color3.fromRGB(230, 80, 80),
	errorText = Color3.fromRGB(255, 110, 110),
}

-- 창·버튼 모양 (docs/UI.md)
local THEME = {
	font = Enum.Font.FredokaOne, -- 버튼·창 제목 글꼴 (한글은 Roblox 기본 한글 글꼴로 나온다)
	outline = Color3.fromRGB(14, 18, 34), -- 창·버튼 테두리 색
	panelOutline = 3, -- 창 테두리 두께
	buttonOutline = 2.5, -- 버튼 테두리 두께
	panelRadius = 18, -- 창 모서리 둥글기
	shine = 0.78, -- 버튼 아래쪽 어둡기 (1이면 그라데이션 없음, 작을수록 위가 밝고 아래가 어둡다)
	hoverScale = 1.05, -- 마우스를 올리면 커지는 배율
	pressScale = 0.93, -- 누르면 작아지는 배율
}

-- 왼쪽 아래 메뉴 버튼 색
local MENU_COLORS = {
	bag = Color3.fromRGB(244, 146, 40), -- 가방 (주황)
	upgrade = Color3.fromRGB(150, 92, 232), -- 업그레이드 (보라)
	tree = Color3.fromRGB(56, 182, 90), -- 내 트리 (초록)
	roulette = Color3.fromRGB(236, 78, 140), -- 룰렛 (분홍)
	shop = Color3.fromRGB(46, 140, 240), -- 상점 (파랑)
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

-- 크기 글자색 (룰렛 크기 칸, 확률표)
local SIZE_COLORS = {
	Small = Color3.fromRGB(150, 210, 255),
	Normal = Color3.fromRGB(160, 172, 190),
	Big = Color3.fromRGB(255, 170, 80),
	Huge = Color3.fromRGB(255, 90, 90),
}

local function sizeColor(size): Color3
	return SIZE_COLORS[size.id] or Color3.fromRGB(242, 245, 250)
end

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
local function itemName(deco, trait, paintId: string?, sizeId: string?): string
	return Catalog.ItemName(deco, trait, paintId, sizeId)
end

-- "분홍 공" (특성 이름 없이)
local function paintedName(deco, paintId: string?, sizeId: string?): string
	return Catalog.ItemName(deco, Catalog.BaseTrait, paintId, sizeId)
end

local function stackInfo(stack)
	return Catalog.DecorationById[stack.d], Catalog.TraitById[stack.t]
end

local function stackKey(stack): string
	return Catalog.StackKey(stack.d, stack.t, stack.p, stack.s)
end

local function stackSellPrice(stack): number
	local deco, trait = stackInfo(stack)
	return Gacha.GetSellPrice(deco.rarity, Catalog.ValueMult(trait, stack.s))
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
	corner(frame, THEME.panelRadius)
	create("UIStroke", { Color = THEME.outline, Thickness = THEME.panelOutline, Parent = frame })
	create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(190, 195, 210)),
		Parent = frame,
	})
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
		Font = THEME.font,
		TextSize = props.TextSize or 18,
		TextColor3 = COLORS.text,
		TextStrokeColor3 = THEME.outline,
		TextStrokeTransparency = 0.55,
		Text = props.Text,
		Parent = props.Parent,
	})
	corner(btn, props.Radius or 10)
	-- 테두리 (닫기 아이콘 버튼은 끈다. 룰렛 버튼은 열려 있으면 금색)
	create("UIStroke", {
		Name = "Stroke",
		Color = THEME.outline,
		Thickness = THEME.buttonOutline,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = btn,
	})
	-- 위가 밝고 아래가 어두운 광택 (버튼 색은 BackgroundColor3 그대로 바꿀 수 있다)
	local shade = math.floor(255 * THEME.shine)
	create("UIGradient", {
		Rotation = 90,
		Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(shade, shade, shade)),
		Parent = btn,
	})
	-- 마우스를 올리면 살짝 커지고, 누르면 눌린다
	local scale = create("UIScale", { Parent = btn })
	local function to(value: number)
		TweenService:Create(scale, TweenInfo.new(0.1, Enum.EasingStyle.Quad), { Scale = value }):Play()
	end
	local hovering = false
	btn.MouseEnter:Connect(function()
		hovering = true
		to(THEME.hoverScale)
	end)
	btn.MouseLeave:Connect(function()
		hovering = false
		to(1)
	end)
	btn.MouseButton1Down:Connect(function()
		to(THEME.pressScale)
	end)
	btn.MouseButton1Up:Connect(function()
		to(if hovering then THEME.hoverScale else 1)
	end)
	return btn
end

-- 버튼 왼쪽에 아이콘을 붙이고 글자를 그만큼 오른쪽으로 민다 (image가 ""이면 아무것도 안 함)
local function addIcon(parent: GuiObject, image: string?, size: number, noPadding: boolean?)
	if not image or image == "" then
		return
	end
	create("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Image = image,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromOffset(size, size),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Parent = parent,
	})
	if not noPadding then
		create("UIPadding", { PaddingLeft = UDim.new(0, size + 8), Parent = parent })
	end
end

-- X 글자 버튼을 닫기 아이콘으로 바꾼다 (ICONS.close가 ""이면 X 글자 그대로)
local function useCloseIcon(btn: TextButton)
	if ICONS.close == "" then
		return
	end
	btn.Text = ""
	btn.BackgroundTransparency = 1
	local stroke = btn:FindFirstChild("Stroke")
	if stroke then
		stroke.Enabled = false
	end
	create("ImageLabel", {
		Name = "Icon",
		BackgroundTransparency = 1,
		Image = ICONS.close,
		ScaleType = Enum.ScaleType.Fit,
		Size = UDim2.fromScale(1, 1),
		Parent = btn,
	})
end

local function setButton(btn: TextButton, text: string, enabled: boolean, color: Color3)
	btn.Text = text
	btn.BackgroundColor3 = if enabled then color else COLORS.disabled
	btn.TextColor3 = if enabled then COLORS.text else COLORS.subText
end

----------------------------------------------------------------
-- 화면 만들기
----------------------------------------------------------------

local REEL_TITLES = { "특성", "크기", "장식" } -- 장식 칸은 이름 아래 작게 등급. 멈추는 순서는 결과에 따라 (playReel)
local REEL_ROW_H = 74 -- 슬롯 한 칸 높이(픽셀). 칸 안에서 위에서 아래로 굴러간다

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
		Font = THEME.font,
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

	-- 오른쪽 위: 지금 행운 배수와 한 번 돌리는 데 걸리는 시간 (업그레이드·물약이 반영된 값)
	ui.spinStats = label({
		Text = "",
		TextSize = 13,
		TextColor3 = COLORS.subText,
		Size = UDim2.new(0.5, 0, 0, 28),
		Position = UDim2.fromScale(0.5, 0),
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
	ui.reelsFrame = reels
	local widths = { 0.27, 0.27, 0.46 } -- 장식 이름이 길어서 오른쪽 칸을 넓게
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
		-- 굴러가는 창: 제목 아래 영역만 보이고, 위·아래 끝은 흐리게 (슬롯머신 창처럼)
		local window = create("CanvasGroup", {
			Name = "Window",
			BackgroundTransparency = 1,
			Position = UDim2.fromOffset(0, 22),
			Size = UDim2.new(1, 0, 0, REEL_ROW_H),
			Parent = cell,
		})
		create("UIGradient", {
			Rotation = 90,
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 0.9),
				NumberSequenceKeypoint.new(0.22, 0),
				NumberSequenceKeypoint.new(0.78, 0),
				NumberSequenceKeypoint.new(1, 0.9),
			}),
			Parent = window,
		})
		-- 줄 3개를 돌려 쓴다 (가운데 · 위에서 들어오는 것 · 아래로 나가는 것)
		local rows = {}
		for r = 1, 3 do
			local row = create("Frame", {
				Name = "Row" .. r,
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, REEL_ROW_H),
				Visible = r == 1,
				Parent = window,
			})
			local text = scaledLabel({
				Text = "?",
				Font = Enum.Font.GothamBlack,
				Size = UDim2.new(1, -12, 0, if i == 3 then 46 else 60),
				Position = UDim2.fromOffset(6, if i == 3 then 4 else 7),
				Parent = row,
			}, 30, 10)
			-- 장식 칸만: 이름 아래 작게 등급 이름
			local sub = if i == 3
				then label({
					Text = "",
					TextSize = 13,
					Size = UDim2.new(1, 0, 0, 16),
					Position = UDim2.fromOffset(0, 52),
					Parent = row,
				})
				else nil
			rows[r] = { frame = row, text = text, sub = sub }
		end
		ui.reels[i] = {
			stroke = stroke,
			rows = rows,
			center = rows[1], -- 지금 가운데에 보이는 줄
			current = nil, -- 가운데에 보이는 결과 (다음에 돌릴 때 여기서부터 굴러간다)
			scale = create("UIScale", { Parent = window }),
		}
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
	local height = 30 + Rarity.Count * rowHeight + 10 + 30 + traitCount * rowHeight + 10 + 30 + #Catalog.Sizes * rowHeight + 24

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
	create("Frame", { BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 10), LayoutOrder = nextOrder(), Parent = list })
	titleRow("크기")
	for _, size in Catalog.Sizes do
		local odds = if size.n then Gacha.FormatOdds(1 / size.n) else "나머지"
		local valueLabel = row(size.name, sizeColor(size))
		valueLabel.Text = string.format("%s · ×%s", odds, tostring(size.mult))
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
		Color = MENU_COLORS.bag,
		TextSize = 22,
		Size = UDim2.fromOffset(200, 56),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -20),
		Radius = 14,
		Parent = gui,
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
		Font = THEME.font,
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
		Color = MENU_COLORS.upgrade,
		TextSize = 22,
		Size = UDim2.fromOffset(200, 56),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -84),
		Radius = 14,
		Parent = gui,
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
		Font = THEME.font,
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

-- 상점 버튼 (룰렛 버튼 위)
local function buildShopButton(gui)
	ui.shopButton = button({
		Name = "ShopButton",
		Text = "상점",
		Color = MENU_COLORS.shop,
		TextSize = 22,
		Size = UDim2.fromOffset(200, 56),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -276),
		Radius = 14,
		Parent = gui,
	})
end

-- 상점 창: 트리 효과·바닥 아이템 목록 (Catalog/TreeEffects.luau)
local function buildShopWindow(gui)
	local window = panel({
		Name = "Shop",
		Size = UDim2.fromOffset(560, 440),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.45),
		Visible = false,
		Parent = gui,
	})
	window.ZIndex = 5
	ui.shopWindow = window

	label({
		Text = "트리 꾸미기 상점",
		Font = THEME.font,
		TextSize = 20,
		Size = UDim2.new(1, -40, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	ui.shopClose = button({
		Text = "X",
		TextSize = 18,
		Size = UDim2.fromOffset(32, 30),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Parent = window,
	})
	scaledLabel({
		Text = string.format(
			"트리 효과는 하나, 바닥 아이템은 %d개까지 켤 수 있습니다. 꾸미기 전용이라 수입에는 영향이 없습니다.",
			Config.MAX_FLOOR_ITEMS
		),
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.subText,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 32),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	}, 14, 9)

	local list = create("ScrollingFrame", {
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 60),
		Size = UDim2.new(1, 0, 1, -60),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 6,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		Parent = window,
	})
	create("UIListLayout", { Padding = UDim.new(0, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	ui.shopRows = {}
	for order, fx in Catalog.TreeEffects do
		local frame = create("Frame", {
			BackgroundColor3 = COLORS.panelLight,
			BorderSizePixel = 0,
			Size = UDim2.new(1, -10, 0, 74),
			LayoutOrder = order,
			Parent = list,
		})
		corner(frame, 10)
		padding(frame, 12)
		local title = label({
			Text = fx.name,
			TextSize = 18,
			Size = UDim2.new(1, -170, 0, 24),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = frame,
		})
		local info = scaledLabel({
			Text = "",
			Font = Enum.Font.Gotham,
			TextColor3 = COLORS.subText,
			Size = UDim2.new(1, -170, 0, 22),
			Position = UDim2.fromOffset(0, 26),
			TextXAlignment = Enum.TextXAlignment.Left,
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
		ui.shopRows[fx.id] = { frame = frame, title = title, info = info, button = btn }
	end
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
		Color = MENU_COLORS.roulette,
		TextSize = 22,
		Size = UDim2.fromOffset(200, 56),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -212),
		Radius = 14,
		Parent = gui,
	})
	ui.rouletteStroke = ui.rouletteButton:FindFirstChild("Stroke")
end

-- 트리 버튼 (업그레이드 버튼 위)
local function buildTreeButton(gui)
	ui.treeButton = button({
		Name = "TreeButton",
		Text = "내 트리",
		Color = MENU_COLORS.tree,
		TextSize = 22,
		Size = UDim2.fromOffset(200, 56),
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.new(0, 16, 1, -148),
		Radius = 14,
		Parent = gui,
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
		Font = THEME.font,
		TextSize = 20,
		Size = UDim2.new(1, -200, 0, 30),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = window,
	})
	-- 빈자리 자동 채우기 켜고 끄기
	ui.autoFillButton = button({
		Text = "자동 채우기: 켬",
		TextSize = 13,
		Size = UDim2.fromOffset(150, 30),
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -40, 0, 0),
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
	create("UIStroke", { Color = THEME.outline, Thickness = THEME.panelOutline, Parent = picker })
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
	buildShopButton(gui)
	buildInventory(gui)
	buildUpgradeWindow(gui)
	buildTreeWindow(gui)
	buildShopWindow(gui)
	applySlotOrder()

	-- 아이콘 (위 ICONS 표)
	addIcon(ui.bagButton, ICONS.bag, MENU_ICON_SIZE)
	addIcon(ui.upgradeButton, ICONS.upgrade, MENU_ICON_SIZE)
	addIcon(ui.treeButton, ICONS.tree, MENU_ICON_SIZE)
	addIcon(ui.rouletteButton, ICONS.roulette, MENU_ICON_SIZE)
	addIcon(ui.shopButton, ICONS.shop, MENU_ICON_SIZE)
	addIcon(ui.coins.Parent, ICONS.coins, 32, true) -- 코인 칸은 이미 여백이 있고 글자가 오른쪽 정렬이라 밀지 않는다
	for _, btn in { ui.invClose, ui.upgradeClose, ui.shopClose, ui.treeClose } do
		useCloseIcon(btn)
	end
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
	return Gacha.GetCoinSpinCost(state.costLuck or state.luck, currentIncome())
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
		local valueA = Gacha.GetItemValue(decoA.rarity, Catalog.ValueMult(traitA, a.s))
		local valueB = Gacha.GetItemValue(decoB.rarity, Catalog.ValueMult(traitB, b.s))
		if valueA ~= valueB then
			return valueA > valueB
		end
		return itemName(decoA, traitA, a.p, a.s) < itemName(decoB, traitB, b.p, b.s)
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
	local value = Gacha.GetItemValue(deco.rarity, Catalog.ValueMult(trait, stack.s))
	ui.detailName.Text = string.format("%s ×%s", itemName(deco, trait, stack.p, stack.s), Gacha.FormatNumber(stack.c))
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
		Text = paintedName(deco, stack.p, stack.s),
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

-- 상점 창 갱신
local function isEffectOn(fx): boolean
	if fx.area == "Effect" then
		return state.effect == fx.id
	end
	return table.find(state.floor or {}, fx.id) ~= nil
end

local function refreshShop()
	if not ui.shopRows then
		return
	end
	local owned = {}
	for _, id in state.ownedEffects or {} do
		owned[id] = true
	end
	local floorCount = #(state.floor or {})
	for _, fx in Catalog.TreeEffects do
		local row = ui.shopRows[fx.id]
		local has = owned[fx.id] == true
		-- 그만 파는 효과는 가진 사람에게만 보인다
		row.frame.Visible = has or not fx.retired

		local areaName = Catalog.TREE_EFFECT_AREAS[fx.area]
		local info = "[" .. areaName .. "]"
		if has then
			local on = isEffectOn(fx)
			info ..= if on then " 켜져 있습니다" else " 가지고 있습니다"
			if not on and fx.area == "Floor" and floorCount >= Config.MAX_FLOOR_ITEMS then
				info ..= string.format(" (바닥 %d개가 모두 켜져 있습니다)", Config.MAX_FLOOR_ITEMS)
			end
			setButton(row.button, if on then "끄기" else "켜기", true, if on then COLORS.panelHover else COLORS.green)
		else
			if fx.robux then
				info ..= string.format(" 로벅스 %d (준비 중)", fx.robux)
			end
			if fx.cost then
				setButton(row.button, Gacha.FormatNumber(fx.cost) .. "코인", state.coins >= fx.cost, COLORS.gold)
			else
				setButton(row.button, "준비 중", false, COLORS.gold)
			end
		end
		row.info.Text = info
	end
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
			Text = string.format("%s ×%s", itemName(deco, trait, stack.p, stack.s), Gacha.FormatNumber(stack.c)),
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
	local autoFill = state.autoFill ~= false
	ui.autoFillButton.Text = if autoFill then "자동 채우기: 켬" else "자동 채우기: 끔"
	ui.autoFillButton.BackgroundColor3 = if autoFill then COLORS.green else COLORS.panelLight
	ui.autoFillButton.TextColor3 = if autoFill then COLORS.text else COLORS.subText
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
				cell.name.Text = paintedName(deco, entry.p, entry.s)
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
				itemName(deco, trait, entry.p, entry.s),
				r.name,
				Gacha.FormatNumber(Gacha.GetItemValue(deco.rarity, Catalog.ValueMult(trait, entry.s)))
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
				total += Gacha.GetItemValue(deco.rarity, Catalog.ValueMult(trait, entry.s))
			end
		end
		ui.treeDetail.Text = string.format("%d개를 골랐습니다 · 가치 합 %s코인", #chosen, Gacha.FormatNumber(total))
		ui.treeDetail.TextColor3 = COLORS.text
	end
	if #chosen > 0 then
		ui.treeRemove.Visible = true
		setButton(ui.treeRemove, if #chosen == 1 then "빼기" else string.format("%d개 빼기", #chosen), true, COLORS.panelHover)
	else
		ui.treeDetail.Text = if state.autoFill ~= false
			then "빈자리는 뽑을 때마다 가방에서 등급이 가장 높은 장식으로 채워집니다. 걸린 칸을 여러 개 눌러 한 번에 뺄 수 있습니다."
			else "빈 자리를 누르면 장식을 걸 수 있습니다. 걸린 칸을 여러 개 눌러 한 번에 뺄 수 있습니다."
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

local function refreshSpinStats()
	ui.spinStats.Text = string.format("행운 ×%.2f · 회전 %.1f초", state.luck or 1, state.reelTime or Config.REEL_STOP_TIME)
end

local function applyState(newState)
	state = newState
	refreshSpinStats()
	refreshAutoSell()
	refreshCoins()
	refreshOdds()
	GachaUI.RefreshBag()
	refreshUpgrades()
	refreshTree()
	refreshShop()
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

-- 칸 종류마다 결과 하나를 줄에 그린다: 글자 · 색 (장식 칸은 아래 작게 등급)
local function reelLook(i: number, item): (string, Color3, string?)
	if item == nil then
		return "?", COLORS.text, nil
	elseif i == 1 then
		return item.name, traitColor(item), nil
	elseif i == 2 then
		return item.name, sizeColor(item), nil
	end
	local r = Rarity.List[item.rarity]
	return item.name, r.color, r.name
end

local function drawRow(i: number, row, item)
	local text, color, subText = reelLook(i, item)
	row.text.Text = text
	row.text.TextColor3 = color
	if row.sub then
		row.sub.Text = subText or ""
		row.sub.TextColor3 = color
	end
end

-- 칸을 굴린 위치에 맞춰 그린다. f는 sequence에서 몇 번째 결과가 가운데에 있는지 (소수면 사이를 지나는 중)
-- 결과 k는 가운데에서 (f - k)칸 아래에 있다: f가 커지면 위에서 새 결과가 내려오고 지난 결과는 아래로 나간다
local function layoutReel(i: number, sequence, f: number)
	local reel = ui.reels[i]
	local base = math.floor(f)
	local nearest = math.clamp(math.floor(f + 0.5), 0, #sequence)
	for r, row in reel.rows do
		local k = base - 1 + r -- base-1(아래로 나가는 중, 되튈 때) · base · base+1(위에서 들어오는 중)
		local offset = f - k
		if k < 0 or k > #sequence or math.abs(offset) >= 1 then
			row.frame.Visible = false
		else
			row.frame.Visible = true
			row.frame.Position = UDim2.fromOffset(0, offset * REEL_ROW_H)
			drawRow(i, row, sequence[k])
			if k == nearest then
				reel.center = row
			end
		end
	end
	local _, color = reelLook(i, sequence[nearest])
	reel.stroke.Color = color
end

-- 한 칸에 결과 하나만 가운데에 보여 준다 (굴러가지 않을 때)
local function showReel(i: number, item)
	ui.reels[i].current = item
	layoutReel(i, { [0] = item }, 0)
end

local function showTraitReel(trait)
	showReel(1, trait)
end

local function showSizeReel(size)
	showReel(2, size)
end

local function showDecoReel(deco)
	showReel(3, deco)
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
-- 마지막 칸이 혼자 천천히 돌 때 지나가며 기대하게 만드는 희귀한 것들 (결과는 서버가 이미 정했다. 보여 주기만 한다)
local tempting = { {}, {}, {} }
for _, trait in activeTraits do
	if trait.n then
		table.insert(tempting[1], trait)
	end
end
for _, size in Catalog.Sizes do
	if size.n then
		table.insert(tempting[2], size)
	end
end
for _, deco in activeDecos do
	if deco.rarity >= Config.EFFECT_MIN_RARITY then
		table.insert(tempting[3], deco)
	end
end

local function randomFrom(list)
	return list[math.random(1, #list)]
end

-- 결과가 나올 확률 (칸마다). 낮을수록 먼저 멈춘다
local function traitChance(trait): number
	if trait.n then
		return 1 / trait.n
	end
	local rest = 1
	for _, t in activeTraits do
		if t.n then
			rest -= 1 / t.n
		end
	end
	return rest
end

local function sizeChance(size, deco): number
	if deco.area == "Garland" then
		return 1 -- 띠는 크기를 뽑지 않고 항상 보통
	end
	if size.n then
		return 1 / size.n
	end
	local rest = 1
	for _, s in Catalog.Sizes do
		if s.n then
			rest -= 1 / s.n
		end
	end
	return rest
end

-- 슬롯 3칸이 같이 위에서 아래로(일직선) 굴러가다가, 높은 등급(급)이 나온 칸부터 멈춘다
-- 장식 칸은 장식 등급, 특성·크기 칸은 그 결과가 나올 확률을 등급 확률표(행운 1배)에 대어 정한 등급급
-- 예) 특성 커먼급 · 크기 커먼급 · 장식 에픽이면 장식 → 특성 → 크기. 같은 등급이면 왼쪽 칸부터(세 칸이 같으면 원래 순서)
-- 긴박함은 내려오는 속도로만 준다: 마지막 칸은 점점 느려지다가 확정 직전 한 칸을 아주 천천히 기어 들어온다
-- 마지막 칸이 끝나는 방식 (ending)
--   slow     : 마지막 한 칸을 아주 천천히 기어 들어와 멈춘다 (기본)
--   fakeStop : 희귀한 것에서 멈춘 척 서 있다가, 아주 천천히 한 칸 더 내려가 진짜 결과에 멈춘다
--   reverse  : 진짜 결과가 가운데를 지나 아래로 내려가고 위에서 미스틱이 거의 가운데까지 내려오다가, 거꾸로 튕겨 올라가 진짜 결과로 돌아온다
-- 긴장 연출: 두 칸이 REEL_SUSPENSE_MIN_RARITY급 이상이고 남은 칸이 그보다 낮으면, 두 칸이 멈춘 뒤 정해진 시간과 상관없이
-- 마지막 칸을 REEL_SUSPENSE_TIME초 더 돌리고 fakeStop 또는 reverse로 끝낸다
-- 세 칸은 서로 따로 굴러간다(특성·크기는 장식과 따로 뽑으므로 거짓 결과를 보여 주지 않는다). 결과는 서버가 이미 정했다
local REEL_STOP_FRACTIONS = { 0.25, 0.55, 1.0 } -- 첫째 · 둘째 · 마지막으로 멈추는 칸이 멈추는 시점 (전체 시간 비율)
-- 기대 연출: 첫째 칸이 REEL_HOPE_MIN_RARITY급 이상으로 멈추면 둘째·마지막 칸을 REEL_HOPE_EXTRA초씩 늦추고,
-- 둘째 칸은 희귀한 것들을 지나가며 금색으로 깜빡이다 마지막 한 칸을 HOPE_CRAWL초 동안 기어 들어와 멈춘다
local HOPE_CRAWL = 1.1
local REEL_FAST_GAP = 1 / 14 -- 빠르게 돌 때 한 칸 넘어가는 간격(초)
-- 앞 두 칸: 멈추기 직전 마지막 간격(멈추는 시간에 대한 비율)과, 한 칸 앞으로 갈수록 간격에 곱하는 값
local REEL_LAST_GAP = { 0.1, 0.08 }
local REEL_GAP_RATIO = { 0.75, 0.75 }
local REEL_SLOW_RATIO = 0.82 -- 마지막 칸: 한 칸 앞으로 갈수록 간격에 곱하는 값 (작을수록 끝에서 확 느려진다)
local REEL_SETTLE = 0.35 -- 멈춘 뒤 살짝 더 내려갔다가 제자리로 돌아오는 시간(초)
-- 마지막 칸 끝내기 (초)
local LAST_CRAWL = 1.4 -- slow: 마지막 한 칸을 기어 들어오는 시간 (보통 판)
local SUSPENSE_CRAWL = 2.6 -- slow: 긴장 연출일 때
local FAKE_HOLD = 0.9 -- fakeStop: 희귀한 것에서 멈춘 척 서 있는 시간
local FAKE_CRAWL = 2.0 -- fakeStop: 그다음 한 칸 기어 내려가는 시간
local REVERSE_CRAWL = 3.0 -- reverse: 진짜 결과를 지나 미스틱이 거의 가운데까지 기어 내려오는 시간
local REVERSE_REACH = 0.85 -- reverse: 미스틱이 가운데에 얼마나 가까이 오는지 (1이면 딱 가운데)
local REVERSE_HOLD = 0.5 -- reverse: 미스틱 직전에서 버티는 시간
local REVERSE_BACK = 0.55 -- reverse: 거꾸로 튕겨 올라가 진짜 결과로 돌아오는 시간
local SUSPENSE_GOLD = Color3.fromRGB(255, 214, 80)

-- 칸이 바뀌는 시각들 (마지막이 stopTime). 끝에서부터 간격을 늘려 가며 거꾸로 만든다
local function reelTimes(stopTime: number, lastGap: number, ratio: number): { number }
	local backwards = { stopTime }
	local t = stopTime
	local gap = lastGap
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

-- 확률 → 등급급 (등급 확률표에서 그 확률 이하인 가장 높은 등급)
local BASE_PROBS = Gacha.GetProbabilities(1)
local function tierOf(chance: number): number
	local tier = 1
	for r = 2, Rarity.Count do
		if chance <= BASE_PROBS[r] * 1.0001 then
			tier = r
		end
	end
	return tier
end

-- reverse에서 위에서 내려오는 미스틱(칸마다 미스틱급, 없으면 가장 드문 것)
local MYSTIC = 6
local mysticPool = { {}, {}, {} }
do
	local function collect(i, list, chanceOf)
		local rarest, rarestChance = nil, math.huge
		for _, item in list do
			local c = chanceOf(item)
			if tierOf(c) >= MYSTIC then
				table.insert(mysticPool[i], item)
			end
			if item.n and c < rarestChance then
				rarest, rarestChance = item, c
			end
		end
		if #mysticPool[i] == 0 and rarest then
			table.insert(mysticPool[i], rarest)
		end
	end
	collect(1, activeTraits, traitChance)
	collect(2, Catalog.Sizes, function(size)
		return sizeChance(size, { area = "Ornament" })
	end)
	for _, deco in activeDecos do
		if deco.rarity == MYSTIC then
			table.insert(mysticPool[3], deco)
		end
	end
end

-- 역류 후보가 되는 판의 비율 (모든 등급·특성·크기 조합 중 결과물 확률이 1/MIN_N ~ 1/MAX_N인 것들의 확률 합)
local candidateRateCache = {}
local function reverseCandidateRate(luck: number, garland: boolean): number
	local key = string.format("%.4f/%s", luck, tostring(garland))
	if candidateRateCache[key] then
		return candidateRateCache[key]
	end
	local lo, hi = 1 / Config.REEL_REVERSE_MAX_N, 1 / Config.REEL_REVERSE_MIN_N
	local sizeProbs = {}
	if garland then
		sizeProbs = { 1 }
	else
		for _, size in Catalog.Sizes do
			table.insert(sizeProbs, sizeChance(size, { area = "Ornament" }))
		end
	end
	local total = 0
	for _, pr in Gacha.GetProbabilities(luck) do
		for _, trait in activeTraits do
			local pt = traitChance(trait)
			for _, ps in sizeProbs do
				local p = pr * pt * ps
				if p >= lo and p <= hi then
					total += p
				end
			end
		end
	end
	candidateRateCache[key] = total
	return total
end

local function easeOut(u: number): number
	return 1 - (1 - u) ^ 3
end

-- 거꾸로 튕길 때: 목표를 살짝 넘었다가 돌아온다
local function easeOutBack(u: number): number
	local k = 1.9
	return 1 + (k + 1) * (u - 1) ^ 3 + k * (u - 1) ^ 2
end

-- 지난 시간 → 굴린 위치 f (0이면 처음 보이던 결과, steps면 최종 결과가 가운데). 위아래로만 움직인다
local function reelPosition(reel, elapsed: number): number
	local times = reel.times
	if reel.ending == nil then
		-- 앞 두 칸: 칸마다 일정한 속도로 내려오다 멈춘 뒤 살짝 되튄다
		if elapsed >= reel.stopTime then
			local u = math.clamp((elapsed - reel.stopTime) / REEL_SETTLE, 0, 1)
			return reel.steps + 0.22 * math.sin(math.pi * u) * (1 - u)
		end
		if elapsed < times[1] then
			return elapsed / times[1]
		end
		local s = 1
		while s < reel.steps and times[s + 1] <= elapsed do
			s += 1
		end
		return s + (elapsed - times[s]) / (times[s + 1] - times[s])
	end

	-- 마지막 칸: times는 steps-1번째 결과가 가운데에 오는 시각(t0)까지
	local m = reel.steps - 1
	local t0 = times[m]
	if elapsed < t0 then
		if elapsed < times[1] then
			return elapsed / times[1]
		end
		local s = 1
		while s < m and times[s + 1] <= elapsed do
			s += 1
		end
		return s + (elapsed - times[s]) / (times[s + 1] - times[s])
	end
	local e = elapsed - t0
	if reel.ending == "slow" then
		local f = m + easeOut(math.clamp(e / reel.crawl, 0, 1))
		if e >= reel.crawl then
			local u = math.clamp((e - reel.crawl) / REEL_SETTLE, 0, 1)
			f = reel.steps + 0.15 * math.sin(math.pi * u) * (1 - u)
		end
		return f
	elseif reel.ending == "fakeStop" then
		if e < FAKE_HOLD then
			return m
		end
		local f = m + easeOut(math.clamp((e - FAKE_HOLD) / FAKE_CRAWL, 0, 1))
		if e >= FAKE_HOLD + FAKE_CRAWL then
			local u = math.clamp((e - FAKE_HOLD - FAKE_CRAWL) / REEL_SETTLE, 0, 1)
			f = reel.steps + 0.15 * math.sin(math.pi * u) * (1 - u)
		end
		return f
	end
	-- reverse: m → (진짜 결과 지나) 미스틱 직전까지 기어 내려왔다가 → 거꾸로 튕겨 진짜 결과로
	local far = reel.steps + REVERSE_REACH
	if e < REVERSE_CRAWL then
		return m + (far - m) * easeOut(e / REVERSE_CRAWL)
	end
	e -= REVERSE_CRAWL
	if e < REVERSE_HOLD then
		return far
	end
	e -= REVERSE_HOLD
	return far + (reel.steps - far) * easeOutBack(math.clamp(e / REVERSE_BACK, 0, 1))
end

-- 마지막 칸이 끝나는 데 걸리는 시간 (t0부터)
local function endingTime(ending: string, crawl: number): number
	if ending == "fakeStop" then
		return FAKE_HOLD + FAKE_CRAWL
	elseif ending == "reverse" then
		return REVERSE_CRAWL + REVERSE_HOLD + REVERSE_BACK
	end
	return crawl
end

local function playReel(deco, trait, size, duration: number)
	local finals = { trait, size, deco }
	local pickers = {
		function()
			return randomFrom(activeTraits)
		end,
		function()
			return randomFrom(Catalog.Sizes)
		end,
		function()
			return randomFrom(activeDecos)
		end,
	}

	-- 멈추는 순서: 높은 등급(급)이 나온 칸부터. 같으면 왼쪽 칸부터
	local tiers = { tierOf(traitChance(trait)), tierOf(sizeChance(size, deco)), deco.rarity }
	local order = { 1, 2, 3 }
	table.sort(order, function(a, b)
		if tiers[a] ~= tiers[b] then
			return tiers[a] > tiers[b]
		end
		return a < b
	end)
	local lastReel = order[3]
	local hope = tiers[order[1]] >= Config.REEL_HOPE_MIN_RARITY -- 첫째 칸이 좋은 것으로 멈춘다
	local hopeExtra = if hope then Config.REEL_HOPE_EXTRA else 0
	local firstStop = duration * REEL_STOP_FRACTIONS[1]
	local slowStart = duration * REEL_STOP_FRACTIONS[2] + hopeExtra -- 앞 두 칸이 멈춘 뒤 마지막 칸만 남았을 때
	local minTier = Config.REEL_SUSPENSE_MIN_RARITY
	local suspense = tiers[order[2]] >= minTier and tiers[lastReel] < minTier

	-- 마지막 칸이 끝나는 방식: 나온 결과물 전체 확률(특성 × 크기 × 장식 등급)이 약 1/10이면 역류 후보
	-- 후보 판 중 일부만 역류시켜, 전체 판의 REEL_REVERSE_RATE(10번에 1번)만 역류하게 한다
	local pTrait, pSize = traitChance(trait), sizeChance(size, deco)
	local pDeco = Gacha.GetProbabilities(state.luck)[deco.rarity] or 1
	local resultChance = pTrait * pSize * pDeco
	local oneIn = if resultChance > 0 then 1 / resultChance else math.huge
	local candidate = oneIn >= Config.REEL_REVERSE_MIN_N and oneIn <= Config.REEL_REVERSE_MAX_N and #mysticPool[lastReel] > 0
	local reverseOdds = math.min(1, Config.REEL_REVERSE_RATE / math.max(reverseCandidateRate(state.luck, deco.area == "Garland"), 1e-6))
	local canReverse = candidate and math.random() < reverseOdds
	local ending = if canReverse then "reverse" elseif suspense then "fakeStop" else "slow"
	local forced = Config.STUDIO_FORCE_REEL_ENDING
	if RunService:IsStudio() and forced ~= "" then
		suspense = forced ~= "slow"
		ending = if forced == "reverse" and #mysticPool[lastReel] > 0 then "reverse" elseif forced == "slow" then "slow" else "fakeStop"
	end
	local crawl = if suspense then SUSPENSE_CRAWL else LAST_CRAWL
	if RunService:IsStudio() then
		local names = {}
		for _, i in order do
			table.insert(names, string.format("%s(%s급)", REEL_TITLES[i], Rarity.List[tiers[i]].name))
		end
		print(string.format(
			"[룰렛] 멈추는 순서: %s · 결과 확률 특성 1/%.1f × 크기 1/%.1f × 장식(%s) 1/%.1f = 1/%.1f%s · 끝내기 %s%s",
			table.concat(names, " → "),
			1 / pTrait,
			1 / pSize,
			Rarity.List[deco.rarity].name,
			1 / pDeco,
			oneIn,
			if candidate then string.format(" (역류 후보, %d%%)", math.floor(reverseOdds * 100 + 0.5)) else "",
			ending,
			(if suspense then " · 긴장 연출" else "") .. (if hope then " · 기대 연출" else "")
		))
	end

	local reels = {}
	for rank, i in order do
		local isLast = rank == 3
		local times, stopTime
		local hopeReel = hope and rank == 2 -- 기대 연출로 늦게 멈추는 둘째 칸
		if hopeReel then
			stopTime = slowStart
			local t0 = stopTime - HOPE_CRAWL
			times = reelTimes(t0, HOPE_CRAWL / 3, REEL_SLOW_RATIO)
		elseif isLast then
			-- 끝내기 직전(t0)까지는 점점 느려지며 내려오고, 끝내기는 정해진 시간만큼 (긴장 연출이면 전체 시간보다 길어진다)
			local finish = if suspense then slowStart + Config.REEL_SUSPENSE_TIME else duration + hopeExtra
			local t0 = math.max(finish - endingTime(ending, crawl), slowStart * 0.6)
			-- t0 직전 간격: 끝내기의 처음 속도와 이어지게
			local firstSpeed = if ending == "reverse" then 3 * (1 + REVERSE_REACH) / REVERSE_CRAWL else 3 / crawl
			times = reelTimes(t0, 1 / firstSpeed, REEL_SLOW_RATIO)
			stopTime = t0 + endingTime(ending, crawl)
		else
			stopTime = duration * REEL_STOP_FRACTIONS[rank]
			times = reelTimes(stopTime, stopTime * REEL_LAST_GAP[rank], REEL_GAP_RATIO[rank])
		end
		local steps = if isLast or hopeReel then #times + 1 else #times
		local sequence = table.create(steps + 1)
		sequence[0] = ui.reels[i].current -- 지금 보이는 결과에서부터 굴러간다
		local prev = sequence[0]
		for s = 1, steps - 1 do
			-- 마지막 칸이 혼자 천천히 넘어갈 때는 희귀한 것들을 보여 준다. fakeStop이면 멈추기 바로 앞은 반드시 희귀한 것
			local tempt = ((isLast and times[s] >= slowStart) or (hopeReel and times[s] >= firstStop)) and #tempting[i] > 0
			local mustTempt = isLast and ending == "fakeStop" and s == steps - 1 and #tempting[i] > 0
			local pick
			local tries = 0
			repeat
				pick = if mustTempt or (tempt and math.random() < 0.75) then randomFrom(tempting[i]) else pickers[i]()
				tries += 1
			until (pick ~= prev and (s < steps - 1 or pick ~= finals[i])) or tries > 10
			sequence[s] = pick
			prev = pick
		end
		sequence[steps] = finals[i]
		if isLast and ending == "reverse" then
			sequence[steps + 1] = randomFrom(mysticPool[i]) -- 진짜 결과 위에서 내려오는 미스틱
		end
		reels[i] = {
			stopTime = stopTime,
			times = times,
			steps = steps,
			sequence = sequence,
			stopped = false,
			done = false,
			ending = if isLast then ending elseif hopeReel then "slow" else nil,
			crawl = if hopeReel then HOPE_CRAWL else crawl,
		}
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
			layoutReel(i, reel.sequence, reelPosition(reel, elapsed))
			if not reel.stopped and elapsed >= reel.stopTime then
				-- 멈춘 칸은 크게 튕긴다. 마지막 칸은 더 크게
				reel.stopped = true
				popReel(i, if i == lastReel then 1.35 else 1.2, if i == lastReel then 0.45 else 0.3, Enum.EasingStyle.Back)
			end
			if hope and i == order[2] and elapsed >= firstStop and not reel.stopped then
				-- 첫째 칸이 좋은 것으로 멈추면 둘째 칸 테두리가 금색으로 깜빡인다
				local pulse = (math.sin(elapsed * 10) + 1) / 2
				ui.reels[i].stroke.Color = ui.reels[i].stroke.Color:Lerp(SUSPENSE_GOLD, pulse)
			end
			if suspense and i == lastReel and elapsed >= slowStart and not reel.stopped then
				-- 테두리가 금색으로 깜빡인다
				local pulse = (math.sin(elapsed * 14) + 1) / 2
				ui.reels[i].stroke.Color = ui.reels[i].stroke.Color:Lerp(SUSPENSE_GOLD, pulse)
				ui.reelSub.Text = "레어 이상이 두 칸 나왔습니다!"
			end
			if elapsed >= reel.stopTime + REEL_SETTLE then
				reel.done = true
				showReel(i, finals[i])
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

local function playResultEffect(rarityIndex: number, deco, trait, paintId: string?, sizeId: string?)
	local r = Rarity.List[rarityIndex]
	local probs = Gacha.GetProbabilities(state.luck)
	local value = Gacha.GetItemValue(rarityIndex, Catalog.ValueMult(trait, sizeId))
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
		showToast(string.format("%s [%s] 뽑았습니다!", itemName(deco, trait, paintId, sizeId), r.name), r.color)
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
				local center = ui.reels[3].center
				center.text.TextColor3 = color
				center.sub.TextColor3 = color
				RunService.RenderStepped:Wait()
			end
			showTraitReel(trait)
			showSizeReel(Catalog.SizeOf(sizeId))
			showDecoReel(deco)
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

	playReel(deco, trait, Catalog.SizeOf(result.sizeId), result.reelTime)
	applyState(result.state)
	playResultEffect(result.rarity, deco, trait, result.paintId, result.sizeId)
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

local function shopPress(fx)
	if not state then
		return
	end
	local owned = table.find(state.ownedEffects or {}, fx.id) ~= nil
	if not owned then
		local result = bagRequest(Remotes.BuyTreeEffect, fx.id)
		if result then
			local text = "구매했습니다: " .. fx.name
			if result.note then
				showToast(text .. ". " .. result.note, COLORS.gold)
			else
				showToast(text .. ". 내 트리에 켜졌습니다", COLORS.gold)
			end
		end
		return
	end
	bagRequest(Remotes.SetTreeEffect, fx.id, not isEffectOn(fx))
end

-- 룰렛 창과 확률표. 열려 있으면 버튼 테두리를 금색으로 표시한다
local function setRouletteOpen(open: boolean)
	ui.slot.Visible = open
	ui.odds.Visible = open
	ui.rouletteStroke.Color = if open then COLORS.gold else THEME.outline
	ui.rouletteStroke.Thickness = if open then 4 else THEME.buttonOutline
end

local function setTreeOpen(open: boolean)
	ui.treeWindow.Visible = open
	selectedSlots = {}
	pickingSlot = nil
	if open then
		ui.inventory.Visible = false
		ui.upgradeWindow.Visible = false
		ui.shopWindow.Visible = false
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
		ui.shopWindow.Visible = false
		selectedKey = nil
	end
end

local function setShopOpen(open: boolean)
	ui.shopWindow.Visible = open
	if open then
		ui.inventory.Visible = false
		ui.treeWindow.Visible = false
		ui.upgradeWindow.Visible = false
		selectedKey = nil
		if state then
			refreshShop()
		end
	end
end

local function setInventoryOpen(open: boolean)
	if open then
		ui.upgradeWindow.Visible = false
		ui.treeWindow.Visible = false
		ui.shopWindow.Visible = false
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
			itemName(deco, trait, nil, if type(data.sizeId) == "string" then data.sizeId else nil),
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
	ui.shopButton.Activated:Connect(function()
		setShopOpen(not ui.shopWindow.Visible)
	end)
	ui.shopClose.Activated:Connect(function()
		setShopOpen(false)
	end)
	for _, fx in Catalog.TreeEffects do
		ui.shopRows[fx.id].button.Activated:Connect(function()
			shopPress(fx)
		end)
	end
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
	ui.autoFillButton.Activated:Connect(function()
		if not state then
			return
		end
		local turningOn = state.autoFill == false
		local result = bagRequest(Remotes.SetAutoFill, turningOn)
		if result and turningOn and (result.placed or 0) > 0 then
			showToast(string.format("빈자리에 장식 %d개를 걸었습니다", result.placed), COLORS.green)
		end
	end)
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
				refreshShop()
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
