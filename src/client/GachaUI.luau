-- 룰렛 화면: 슬롯 · 확률표 · 가방 · 공지
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Rarity = require(Shared:WaitForChild("Rarity"))
local Gacha = require(Shared:WaitForChild("Gacha"))
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local player = Players.LocalPlayer

local GachaUI = {}

local COLORS = {
	panel = Color3.fromRGB(20, 28, 40),
	panelLight = Color3.fromRGB(32, 43, 60),
	text = Color3.fromRGB(242, 245, 250),
	subText = Color3.fromRGB(160, 172, 190),
	green = Color3.fromRGB(40, 168, 92),
	gold = Color3.fromRGB(226, 170, 40),
	disabled = Color3.fromRGB(68, 76, 90),
	error = Color3.fromRGB(255, 110, 110),
}

local state = nil
local spinning = false
local ui = {}

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

local function panel(props)
	local frame = create("Frame", {
		Name = props.Name,
		Size = props.Size,
		Position = props.Position,
		AnchorPoint = props.AnchorPoint,
		BackgroundColor3 = COLORS.panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
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
		BackgroundColor3 = props.Color,
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Font = Enum.Font.GothamBold,
		TextSize = 18,
		TextColor3 = COLORS.text,
		Text = props.Text,
		Parent = props.Parent,
	})
	corner(btn, 10)
	return btn
end

-- 등급 목록 패널 (확률표, 가방)
local function rarityListPanel(name: string, title: string, anchor: Vector2, position: UDim2, parent)
	local frame = panel({
		Name = name,
		Size = UDim2.fromOffset(210, 54 + Rarity.Count * 28),
		AnchorPoint = anchor,
		Position = position,
		Parent = parent,
	})
	local titleLabel = label({
		Name = "Title",
		Text = title,
		Size = UDim2.new(1, 0, 0, 24),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = frame,
	})
	local list = create("Frame", {
		Name = "List",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, 30),
		Size = UDim2.new(1, 0, 1, -30),
		Parent = frame,
	})
	create("UIListLayout", { Padding = UDim.new(0, 4), SortOrder = Enum.SortOrder.LayoutOrder, Parent = list })

	local valueLabels = {}
	for i, r in Rarity.List do
		local row = create("Frame", {
			Name = r.id,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, 24),
			LayoutOrder = i,
			Parent = list,
		})
		local dot = create("Frame", {
			BackgroundColor3 = r.color,
			BorderSizePixel = 0,
			Size = UDim2.fromOffset(10, 10),
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 0, 0.5, 0),
			Parent = row,
		})
		corner(dot, 5)
		label({
			Text = r.name,
			TextColor3 = r.color,
			Size = UDim2.new(0.55, -16, 1, 0),
			Position = UDim2.fromOffset(16, 0),
			TextXAlignment = Enum.TextXAlignment.Left,
			Parent = row,
		})
		valueLabels[i] = label({
			Text = "-",
			Font = Enum.Font.Gotham,
			TextColor3 = COLORS.subText,
			Size = UDim2.new(0.45, 0, 1, 0),
			Position = UDim2.fromScale(0.55, 0),
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = row,
		})
	end
	return titleLabel, valueLabels
end

----------------------------------------------------------------
-- 화면 만들기
----------------------------------------------------------------

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
		uiScale.Scale = math.clamp(math.min(size.X / 1280, size.Y / 720), 0.55, 1.2)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	updateScale()

	-- 슬롯머신
	local slot = panel({
		Name = "Slot",
		Size = UDim2.fromOffset(400, 274),
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -20),
		Parent = gui,
	})
	label({
		Text = "🎄 장식 룰렛",
		TextSize = 20,
		Size = UDim2.new(0.6, 0, 0, 28),
		TextXAlignment = Enum.TextXAlignment.Left,
		Parent = slot,
	})
	ui.coins = label({
		Text = "💰 0",
		TextSize = 18,
		TextColor3 = COLORS.gold,
		Size = UDim2.new(0.4, 0, 0, 28),
		Position = UDim2.fromScale(0.6, 0),
		TextXAlignment = Enum.TextXAlignment.Right,
		Parent = slot,
	})

	local reel = create("Frame", {
		Name = "Reel",
		BackgroundColor3 = COLORS.panelLight,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 38),
		Size = UDim2.new(1, 0, 0, 112),
		ClipsDescendants = true,
		Parent = slot,
	})
	corner(reel, 12)
	ui.reelStroke = create("UIStroke", { Color = COLORS.subText, Thickness = 3, Parent = reel })
	ui.reelText = label({
		Text = "?",
		TextSize = 44,
		Font = Enum.Font.GothamBlack,
		Size = UDim2.new(1, 0, 0, 70),
		Position = UDim2.fromOffset(0, 12),
		Parent = reel,
	})
	ui.reelScale = create("UIScale", { Parent = ui.reelText })
	ui.reelSub = label({
		Text = "버튼을 눌러 돌려보세요",
		TextSize = 15,
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.subText,
		Size = UDim2.new(1, 0, 0, 22),
		Position = UDim2.fromOffset(0, 82),
		Parent = reel,
	})

	ui.freeButton = button({
		Name = "FreeSpin",
		Text = "무료 돌리기",
		Color = COLORS.green,
		Size = UDim2.new(0.5, -6, 0, 54),
		Position = UDim2.fromOffset(0, 162),
		Parent = slot,
	})
	ui.coinButton = button({
		Name = "CoinSpin",
		Text = "코인 돌리기",
		Color = COLORS.gold,
		Size = UDim2.new(0.5, -6, 0, 54),
		Position = UDim2.new(0.5, 6, 0, 162),
		Parent = slot,
	})
	ui.status = label({
		Text = "",
		TextSize = 14,
		Font = Enum.Font.Gotham,
		TextColor3 = COLORS.error,
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromOffset(0, 226),
		Parent = slot,
	})

	-- 확률표 (오른쪽), 가방 (왼쪽)
	ui.oddsTitle, ui.oddsLabels =
		rarityListPanel("Odds", "확률", Vector2.new(1, 0.5), UDim2.new(1, -16, 0.5, 0), gui)
	ui.bagTitle, ui.bagLabels = rarityListPanel("Bag", "가방", Vector2.new(0, 0.5), UDim2.new(0, 16, 0.5, 0), gui)

	-- 공지
	ui.toast = create("CanvasGroup", {
		Name = "Toast",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 64),
		Size = UDim2.fromOffset(600, 48),
		BackgroundColor3 = COLORS.panel,
		BorderSizePixel = 0,
		GroupTransparency = 1,
		Visible = false,
		Parent = gui,
	})
	corner(ui.toast, 12)
	ui.toastStroke = create("UIStroke", { Thickness = 2, Color = COLORS.gold, Parent = ui.toast })
	ui.toastLabel = label({
		Text = "",
		TextSize = 18,
		Size = UDim2.fromScale(1, 1),
		TextWrapped = true,
		Parent = ui.toast,
	})

	-- 희귀 등급 화면 번쩍임
	ui.flash = create("Frame", {
		Name = "Flash",
		Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		ZIndex = 10,
		Active = false,
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
	ui.coins.Text = "💰 " .. Gacha.FormatNumber(state.coins)
end

local function refreshOdds()
	local probs = Gacha.GetProbabilities(state.luck)
	for i, lbl in ui.oddsLabels do
		lbl.Text = Gacha.FormatOdds(probs[i])
	end
	ui.oddsTitle.Text = string.format("확률 · 행운 ×%.1f", state.luck)
end

local function refreshBag()
	for i, lbl in ui.bagLabels do
		local count = state.bag[i] or 0
		lbl.Text = "×" .. Gacha.FormatNumber(count)
		lbl.TextColor3 = if count > 0 then COLORS.text else COLORS.subText
	end
	ui.bagTitle.Text = string.format("가방 %d/%d", state.bagUsed, state.bagCapacity)
end

local function applyState(newState)
	state = newState
	refreshCoins()
	refreshOdds()
	refreshBag()
end

local function setButton(btn: TextButton, text: string, enabled: boolean, color: Color3)
	btn.Text = text
	btn.BackgroundColor3 = if enabled then color else COLORS.disabled
	btn.TextColor3 = if enabled then COLORS.text else COLORS.subText
end

local function refreshButtons()
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
	setButton(ui.coinButton, "💰 " .. Gacha.FormatNumber(cost) .. " 돌리기", state.coins >= cost, COLORS.gold)
end

local function showRarity(index: number)
	local r = Rarity.List[index]
	ui.reelText.Text = r.name
	ui.reelText.TextColor3 = r.color
	ui.reelStroke.Color = r.color
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

-- 슬롯이 처음엔 빠르게, 끝으로 갈수록 느리게 바뀌다가 결과에서 멈춘다.
local function playReel(resultIndex: number, duration: number)
	local steps = math.max(12, math.floor(duration * 14))
	local sequence = table.create(steps, 1)
	local prev = 0
	for i = 1, steps - 1 do
		local pick
		repeat
			pick = math.random(1, Rarity.Count)
		until pick ~= prev and (i < steps - 1 or pick ~= resultIndex)
		sequence[i] = pick
		prev = pick
	end
	sequence[steps] = resultIndex

	ui.reelSub.Text = ""
	local start = os.clock()
	local shown = 0
	while true do
		local alpha = math.clamp((os.clock() - start) / duration, 0, 1)
		local eased = 1 - (1 - alpha) ^ 3
		local step = if alpha >= 1 then steps else math.clamp(math.floor(eased * (steps - 1)) + 1, 1, steps)
		if step ~= shown then
			shown = step
			showRarity(sequence[step])
			ui.reelScale.Scale = 1.08
			TweenService:Create(ui.reelScale, TweenInfo.new(0.08), { Scale = 1 }):Play()
		end
		if alpha >= 1 then
			break
		end
		RunService.RenderStepped:Wait()
	end
end

local function playResultEffect(index: number)
	local r = Rarity.List[index]
	local probs = Gacha.GetProbabilities(state.luck)
	ui.reelSub.Text = string.format("%s · 가치 💰%s", Gacha.FormatOdds(probs[index]), Gacha.FormatNumber(r.value))

	ui.reelScale.Scale = 1.35
	TweenService:Create(ui.reelScale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	}):Play()

	if index < Config.EFFECT_MIN_RARITY then
		return
	end

	-- 등급이 높을수록 더 많이 번쩍인다
	local flashes = index - Config.EFFECT_MIN_RARITY + 1
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
	if index < Config.SERVER_ANNOUNCE_MIN_RARITY then
		showToast(string.format("✨ [%s] 장식을 뽑았어요!", r.name), r.color)
	end

	-- 시크릿은 무지개색으로 반짝인다
	if index == Rarity.Count then
		task.spawn(function()
			local start = os.clock()
			while os.clock() - start < 3 do
				local hue = ((os.clock() - start) * 0.8) % 1
				local color = Color3.fromHSV(hue, 0.8, 1)
				ui.reelText.TextColor3 = color
				ui.reelStroke.Color = color
				RunService.RenderStepped:Wait()
			end
			showRarity(index)
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
	refreshButtons()

	local ok, result = pcall(function()
		return Remotes.Spin:InvokeServer(kind)
	end)
	if not ok or type(result) ~= "table" then
		spinning = false
		setStatus("서버와 연결이 불안정해요. 다시 눌러 주세요")
		return
	end
	if not result.ok then
		spinning = false
		setStatus(result.reason or "지금은 돌릴 수 없어요")
		return
	end

	-- 코인과 쿨타임은 바로, 가방은 슬롯이 멈춘 뒤에 반영
	state.coins = result.state.coins
	state.nextFreeSpinAt = result.state.nextFreeSpinAt
	refreshCoins()

	playReel(result.rarity, result.reelTime)
	applyState(result.state)
	playResultEffect(result.rarity)
	spinning = false
end

local function onAnnounce(data)
	if type(data) ~= "table" then
		return
	end
	local r = Rarity.List[data.rarity]
	if not r then
		return
	end
	local prefix = if data.global then "🌍" else "📢"
	showToast(
		string.format("%s %s님이 [%s] 장식을 뽑았어요! (%s)", prefix, tostring(data.playerName), r.name, Gacha.FormatOdds(1 / r.n)),
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
	Remotes.Announce.OnClientEvent:Connect(onAnnounce)

	-- 리더보드 코인이 바뀌면 화면에도 반영 (나중에 수입·판매가 생기면 필요)
	task.spawn(function()
		local leaderstats = player:WaitForChild("leaderstats")
		local coinsValue = leaderstats:WaitForChild("Coins")
		coinsValue.Changed:Connect(function(value)
			if state then
				state.coins = value
				refreshCoins()
			end
		end)
	end)

	task.spawn(function()
		while true do
			refreshButtons()
			task.wait(0.1)
		end
	end)
end

return GachaUI
