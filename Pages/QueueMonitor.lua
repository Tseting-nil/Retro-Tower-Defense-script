-- ============================================================
--                 復古塔防 | 佇列監視器 GUI (Queue Monitor)
-- ============================================================
-- 說明：獨立工具，直接讀取 RTD API 的佇列狀態（RTD.GetQueue / GetQueueIndex /
--       GetQueueElapsed / GetQueueRemaining / GetMoney），不掛鉤、不修改重播核心。
--       UI 與花園塔房佇列監視器同款。
-- ============================================================

-- === i18n 國際化設定（與 API、追蹤器相同：Tsetingnil_script/keysystem.json）===
local HttpService = game:GetService("HttpService")
local currentLang = "zh"
do
	pcall(function()
		local path = "Tsetingnil_script/keysystem.json"
		if isfile and isfile(path) and readfile then
			local raw = readfile(path)
			if raw and raw ~= "" then
				local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
				local scriptLang = nil
				if ok and type(data) == "table" then
					scriptLang = data.script_language or data.language
				else
					scriptLang = raw:match('"script_language"%s*:%s*"([^"]+)"') or raw:match('"language"%s*:%s*"([^"]+)"')
				end
				if scriptLang then
					local sl = tostring(scriptLang):lower()
					if sl:find("chinese") or sl:find("zh") then
						currentLang = "zh"
					elseif sl:find("english") or sl:find("en") then
						currentLang = "en"
					end
				end
			end
		end
	end)
end

local i18n = {
	zh = {
		warn_no_api = "[RTD Monitor] ❌ 找不到 RTD API，無法啟動監視器！",
		default_tower = "塔 #%d",
		title = "復古塔防 | 佇列監視器",
		progress_wait = "進度：等待佇列啟動...",
		op_place = "放置 %s (#%d)",
		op_upgrade = "升級 %s (#%d)",
		op_sell = "售出 %s (#%d)",
		op_start = "開始遊戲 (Start)",
		op_skipwave = "手動跳波",
		op_skipwave_vote_no = "跳波投票：反對",
		op_autoskip_on = "設定自動跳波：開",
		op_autoskip_off = "設定自動跳波：關",
		op_speed = "設定速度：%dx",
		op_end = "結束標記",
		gate_completed = "已完成",
		gate_failed = "失敗",
		gate_skipped = "已略過",
		gate_running = "執行中...",
		game_victory = "已結束 (勝利)",
		game_defeat = "已結束 (失敗)",
		game_unknown = "已結束 (未知)",
		time_countdown = "倒數：%.1fs",
		time_elapsed = "時間：%.1fs",
		summary_format = "進度：%d/%d (%.1f%%) | %s | 金錢：$%s",
		queue_empty = "佇列為空，請載入腳本...",
		log_new_queue = "[RTD Monitor] 🔄 偵測到新的佇列，重新建立清單",
		log_started = "[RTD Monitor] ✅ 佇列監視器啟動完成",
	},
	en = {
		warn_no_api = "[RTD Monitor] ❌ RTD API not found, failed to start monitor!",
		default_tower = "Tower #%d",
		title = "Retro TD | Queue Monitor",
		progress_wait = "Progress: Waiting for queue...",
		op_place = "Place %s (#%d)",
		op_upgrade = "Upgrade %s (#%d)",
		op_sell = "Sell %s (#%d)",
		op_start = "Start Game (Start)",
		op_skipwave = "Manual Skip Wave",
		op_skipwave_vote_no = "Skip Wave Vote: No",
		op_autoskip_on = "Set Auto Skip: On",
		op_autoskip_off = "Set Auto Skip: Off",
		op_speed = "Set Speed: %dx",
		op_end = "End Marker",
		gate_completed = "Completed",
		gate_failed = "Failed",
		gate_skipped = "Skipped",
		gate_running = "Running...",
		game_victory = "Finished (Victory)",
		game_defeat = "Finished (Defeat)",
		game_unknown = "Finished (Unknown)",
		time_countdown = "Countdown: %.1fs",
		time_elapsed = "Time: %.1fs",
		summary_format = "Progress: %d/%d (%.1f%%) | %s | Cash: $%s",
		queue_empty = "Queue is empty, please load script...",
		log_new_queue = "[RTD Monitor] 🔄 New queue detected, rebuilding list",
		log_started = "[RTD Monitor] ✅ Queue monitor started",
	},
}

local L = i18n[currentLang] or i18n.zh

-- 1. 等待 RTD API 載入
local globalEnv = (getgenv and getgenv()) or _G
local waited = 0
while not (globalEnv.RTD and globalEnv.RTD.GetQueue) and waited < 30 do
	task.wait(0.5)
	waited += 0.5
end
if not (globalEnv.RTD and globalEnv.RTD.GetQueue) then
	warn(L.warn_no_api)
	return
end

local function getRTD()
	return globalEnv.RTD
end

-- 重複載入保護：每次載入產生新的實例 ID，舊實例的更新迴圈發現 ID 變了就自行結束
local myInstanceId = tostring(tick()) .. "_" .. tostring(math.random(1000, 9999))
globalEnv.__RTDQueueMonitorId = myInstanceId

-- ============================================================
-- 服務與常數定義
-- ============================================================
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- === UI 主題（同花園佇列監視器）===
local Theme = {
	Background = Color3.fromRGB(25, 27, 30),
	Surface = Color3.fromRGB(35, 38, 42),
	SurfaceHighlight = Color3.fromRGB(45, 48, 52),
	Border = Color3.fromRGB(60, 65, 70),
	Text = Color3.fromRGB(230, 230, 230),
	TextDim = Color3.fromRGB(150, 150, 150),
	Accent = Color3.fromRGB(60, 160, 255),
	Success = Color3.fromRGB(100, 220, 120),
	SuccessBg = Color3.fromRGB(25, 45, 30),
	Warning = Color3.fromRGB(255, 180, 60),
	Error = Color3.fromRGB(255, 80, 80),
	ErrorBg = Color3.fromRGB(45, 25, 25),
	CornerRadius = UDim.new(0, 8),
	Font = Enum.Font.GothamMedium,
	FontBold = Enum.Font.GothamBold,
}

-- === 執行狀態變數 ===
local uiRows = {}
local shownQueue = nil -- 目前清單對應的佇列表（API 換新佇列時重建）
local autoScrollEnabled = true
local isMinimized = false
local lastActiveIndex = 0

-- ============================================================
-- 輔助函式
-- ============================================================
local function formatNumber(amount)
	local formatted = tostring(math.floor(amount))
	while true do
		local k
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	return formatted
end

local function readCash()
	local ok, cash = pcall(function()
		return getRTD().GetMoney()
	end)
	return ok and tonumber(cash) or 0
end

local function getElapsed()
	local ok, el = pcall(function()
		return getRTD().GetQueueElapsed()
	end)
	if ok and el then
		return el
	end
	return 0
end

-- 依 order 找對應放置塔的名稱
local function getTowerNameForOrder(queue, order)
	for _, item in ipairs(queue) do
		if item.kind == "place" and item.order == order then
			return item.towerId
		end
	end
	return string.format(L.default_tower, order or 0)
end

-- ============================================================
-- GUI 界面建立與佈局
-- ============================================================
local guiParent = get_hidden_gui or gethui
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RTDQueueMonitorUI"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false

local parentGui = guiParent and guiParent() or game:GetService("CoreGui")
-- 確保只保留一個 UI 實例
local oldUI = parentGui:FindFirstChild(screenGui.Name)
if oldUI then
	oldUI:Destroy()
end
screenGui.Parent = parentGui

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 330, 0, 420)
mainFrame.Position = UDim2.new(0.72, 0, 0.25, 0)
mainFrame.BackgroundColor3 = Theme.Background
mainFrame.BackgroundTransparency = 0.05
mainFrame.Active = true
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

do
	local c = Instance.new("UICorner")
	c.CornerRadius = Theme.CornerRadius
	c.Parent = mainFrame
	local s = Instance.new("UIStroke")
	s.Thickness = 1.5
	s.Color = Theme.Border
	s.Transparency = 0.2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = mainFrame
end

-- === 標題欄 ===
local titleBar = Instance.new("Frame")
titleBar.Name = "TitleBar"
titleBar.Size = UDim2.new(1, 0, 0, 45)
titleBar.BackgroundColor3 = Theme.Surface
titleBar.BorderSizePixel = 0
titleBar.Parent = mainFrame

do
	local c = Instance.new("UICorner")
	c.CornerRadius = Theme.CornerRadius
	c.Parent = titleBar
end

local titleBarCover = Instance.new("Frame")
titleBarCover.Size = UDim2.new(1, 0, 0, 10)
titleBarCover.Position = UDim2.new(0, 0, 1, -10)
titleBarCover.BackgroundColor3 = Theme.Surface
titleBarCover.BorderSizePixel = 0
titleBarCover.Parent = titleBar

local titleSeparator = Instance.new("Frame")
titleSeparator.Size = UDim2.new(1, 0, 0, 1)
titleSeparator.Position = UDim2.new(0, 0, 1, -1)
titleSeparator.BackgroundColor3 = Theme.Border
titleSeparator.BorderSizePixel = 0
titleSeparator.Parent = titleBar

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -90, 1, 0)
title.BackgroundTransparency = 1
title.TextColor3 = Theme.Accent
title.Font = Theme.FontBold
title.TextSize = 16
title.TextXAlignment = Enum.TextXAlignment.Left
title.Position = UDim2.new(0, 10, 0, 0)
title.Text = L.title
title.Parent = titleBar

-- === 拖拽功能 ===
local dragging = false
local dragStart = nil
local startPos = nil
local dragConn = nil

titleBar.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = UserInputService:GetMouseLocation()
		startPos = mainFrame.Position
		if not dragConn then
			dragConn = RunService.RenderStepped:Connect(function()
				if not dragging then
					return
				end
				local delta = UserInputService:GetMouseLocation() - dragStart
				mainFrame.Position = UDim2.new(
					startPos.X.Scale,
					startPos.X.Offset + delta.X,
					startPos.Y.Scale,
					startPos.Y.Offset + delta.Y
				)
			end)
		end
	end
end)

titleBar.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
		if dragConn then
			dragConn:Disconnect()
			dragConn = nil
		end
	end
end)

local function makeTitleButton(text, x, color)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 30, 0, 30)
	btn.Position = UDim2.new(1, x, 0, 7)
	btn.BackgroundColor3 = color
	btn.TextColor3 = Theme.Text
	btn.Font = Theme.FontBold
	btn.TextSize = 14
	btn.Text = text
	btn.BorderSizePixel = 0
	btn.Parent = titleBar
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = btn
	return btn
end

local minimizeBtn = makeTitleButton("[-]", -75, Theme.SurfaceHighlight)
local closeBtn = makeTitleButton("X", -38, Color3.fromRGB(150, 50, 50))

local running = true
closeBtn.MouseButton1Click:Connect(function()
	running = false
	screenGui:Destroy()
end)

-- === 滾動容器 ===
local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -16, 1, -85)
scrollFrame.Position = UDim2.new(0, 8, 0, 50)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.ScrollBarThickness = 4
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarImageColor3 = Theme.Border
scrollFrame.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 5)
listLayout.Parent = scrollFrame

listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 5)
end)

-- === 狀態摘要欄 ===
local statusBar = Instance.new("Frame")
statusBar.Size = UDim2.new(1, 0, 0, 30)
statusBar.Position = UDim2.new(0, 0, 1, -30)
statusBar.BackgroundColor3 = Theme.Surface
statusBar.BorderSizePixel = 0
statusBar.Parent = mainFrame

local statusLabel = Instance.new("TextLabel")
statusLabel.Size = UDim2.new(1, -10, 1, 0)
statusLabel.Position = UDim2.new(0, 10, 0, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.TextColor3 = Theme.TextDim
statusLabel.Font = Theme.Font
statusLabel.TextSize = 12
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.Text = L.progress_wait
statusLabel.Parent = statusBar

minimizeBtn.MouseButton1Click:Connect(function()
	isMinimized = not isMinimized
	if isMinimized then
		mainFrame.Size = UDim2.new(0, 330, 0, 45)
		scrollFrame.Visible = false
		statusBar.Visible = false
		minimizeBtn.Text = "[+]"
	else
		mainFrame.Size = UDim2.new(0, 330, 0, 420)
		scrollFrame.Visible = true
		statusBar.Visible = true
		minimizeBtn.Text = "[-]"
	end
end)

-- ============================================================
-- UI 渲染生成器
-- ============================================================
local function describeOp(queue, op)
	local kind = op.kind
	if kind == "place" then
		return string.format(L.op_place, tostring(op.towerId), op.order or 0)
	elseif kind == "upgrade" then
		return string.format(L.op_upgrade, getTowerNameForOrder(queue, op.order), op.order or 0)
	elseif kind == "sell" then
		return string.format(L.op_sell, getTowerNameForOrder(queue, op.order), op.order or 0)
	elseif kind == "start" then
		return L.op_start
	elseif kind == "skipwave" then
		return op.value == false and L.op_skipwave_vote_no or L.op_skipwave
	elseif kind == "autoskip" then
		return op.value and L.op_autoskip_on or L.op_autoskip_off
	elseif kind == "speed" then
		return string.format(L.op_speed, tonumber(op.speed) or 1)
	elseif kind == "end" then
		return L.op_end
	end
	return tostring(kind)
end

local function initUIList(queue)
	for _, row in pairs(uiRows) do
		row:Destroy()
	end
	uiRows = {}
	shownQueue = queue
	lastActiveIndex = 0

	for idx, op in ipairs(queue) do
		local rowFrame = Instance.new("Frame")
		rowFrame.Size = UDim2.new(1, -4, 0, 38)
		rowFrame.BackgroundColor3 = Theme.Surface
		rowFrame.BorderSizePixel = 0
		rowFrame.LayoutOrder = idx
		rowFrame.Parent = scrollFrame

		local rowCorner = Instance.new("UICorner")
		rowCorner.CornerRadius = UDim.new(0, 5)
		rowCorner.Parent = rowFrame

		local rowStroke = Instance.new("UIStroke")
		rowStroke.Thickness = 1
		rowStroke.Color = Theme.Border
		rowStroke.Transparency = 0.5
		rowStroke.Parent = rowFrame

		local iconLbl = Instance.new("TextLabel")
		iconLbl.Name = "Icon"
		iconLbl.Size = UDim2.new(0, 25, 1, 0)
		iconLbl.Position = UDim2.new(0, 6, 0, 0)
		iconLbl.BackgroundTransparency = 1
		iconLbl.TextColor3 = Theme.Text
		iconLbl.Font = Theme.FontBold
		iconLbl.TextSize = 14
		iconLbl.Text = "⏳"
		iconLbl.Parent = rowFrame

		local detailLbl = Instance.new("TextLabel")
		detailLbl.Name = "Detail"
		detailLbl.Size = UDim2.new(1, -120, 1, 0)
		detailLbl.Position = UDim2.new(0, 36, 0, 0)
		detailLbl.BackgroundTransparency = 1
		detailLbl.TextColor3 = Theme.Text
		detailLbl.Font = Theme.Font
		detailLbl.TextSize = 13
		detailLbl.TextXAlignment = Enum.TextXAlignment.Left
		detailLbl.TextTruncate = Enum.TextTruncate.AtEnd
		detailLbl.Text = string.format("#%d %s", idx, describeOp(queue, op))
		detailLbl.Parent = rowFrame

		local gateLbl = Instance.new("TextLabel")
		gateLbl.Name = "Gate"
		gateLbl.Size = UDim2.new(0, 80, 1, 0)
		gateLbl.Position = UDim2.new(1, -85, 0, 0)
		gateLbl.BackgroundTransparency = 1
		gateLbl.TextColor3 = Theme.TextDim
		gateLbl.Font = Theme.Font
		gateLbl.TextSize = 11
		gateLbl.TextXAlignment = Enum.TextXAlignment.Right
		gateLbl.Parent = rowFrame

		uiRows[idx] = rowFrame
	end
end

-- ============================================================
-- UI 自動滾動聚焦
-- ============================================================
local function scrollToActiveOp(index)
	if not autoScrollEnabled or isMinimized then
		return
	end
	local activeRow = uiRows[index]
	if activeRow then
		pcall(function()
			local relativeY = activeRow.AbsolutePosition.Y - scrollFrame.AbsolutePosition.Y + scrollFrame.CanvasPosition.Y
			local targetY = relativeY - (scrollFrame.AbsoluteSize.Y / 2)
			targetY = math.clamp(targetY, 0, scrollFrame.CanvasSize.Y.Offset)
			TweenService:Create(scrollFrame, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CanvasPosition = Vector2.new(0, targetY),
			}):Play()
		end)
	end
end

-- ============================================================
-- UI 定時更新
-- ============================================================
local function updateUIList()
	local RTD = getRTD()
	local queue = RTD.GetQueue() or {}
	if shownQueue ~= queue or #uiRows ~= #queue then
		if shownQueue ~= nil and shownQueue ~= queue then
			print(L.log_new_queue)
		end
		initUIList(queue)
	end

	local completedCount = 0
	local elapsed = getElapsed()
	local cash = readCash()
	local currentIndex = RTD.GetQueueIndex() or 0

	for idx, op in ipairs(queue) do
		local row = uiRows[idx]
		if row then
			local icon = row:FindFirstChild("Icon")
			local gate = row:FindFirstChild("Gate")
			local detail = row:FindFirstChild("Detail")
			local stroke = row:FindFirstChild("UIStroke")
			local status = op.status or "pending"

			if status == "completed" then
				completedCount += 1
				row.BackgroundColor3 = Theme.SuccessBg
				icon.Text, icon.TextColor3 = "✅", Theme.Success
				detail.TextColor3 = Theme.Text
				gate.Text, gate.TextColor3 = L.gate_completed, Theme.Success
				stroke.Color, stroke.Transparency = Theme.Success, 0.6
			elseif status == "failed" then
				row.BackgroundColor3 = Theme.ErrorBg
				icon.Text, icon.TextColor3 = "❌", Theme.Error
				detail.TextColor3 = Theme.Text
				gate.Text, gate.TextColor3 = L.gate_failed, Theme.Error
				stroke.Color, stroke.Transparency = Theme.Error, 0.6
			elseif status == "skipped" then
				row.BackgroundColor3 = Theme.Surface
				icon.Text, icon.TextColor3 = "⏭", Theme.Warning
				detail.TextColor3 = Theme.TextDim
				gate.Text, gate.TextColor3 = L.gate_skipped, Theme.Warning
				stroke.Color, stroke.Transparency = Theme.Warning, 0.7
			elseif status == "running" then
				row.BackgroundColor3 = Theme.SurfaceHighlight
				icon.Text, icon.TextColor3 = "▶️", Theme.Accent
				detail.TextColor3 = Theme.Accent
				stroke.Color, stroke.Transparency = Theme.Accent, 0.3

				-- 即時閘門進度
				local gateText
				if type(op.gate) == "number" then
					gateText = string.format("%.1fs / %.1fs", elapsed, op.gate)
				elseif type(op.gate) == "string" then
					local targetCash = tonumber((op.gate:gsub("[^%d%-]", ""))) or 0
					gateText = string.format("$%d / $%d", cash, targetCash)
				else
					gateText = L.gate_running
				end
				gate.Text, gate.TextColor3 = gateText, Theme.Accent
			else -- pending
				row.BackgroundColor3 = Theme.Surface
				icon.Text, icon.TextColor3 = "⏳", Theme.TextDim
				detail.TextColor3 = Theme.TextDim
				stroke.Color, stroke.Transparency = Theme.Border, 0.8

				local gateText = ""
				if type(op.gate) == "number" then
					gateText = string.format("[⏳ %.1fs]", op.gate)
				elseif type(op.gate) == "string" then
					gateText = "[$" .. op.gate .. "]"
				end
				gate.Text, gate.TextColor3 = gateText, Theme.TextDim
			end
		end
	end

	if currentIndex ~= lastActiveIndex and currentIndex > 0 then
		lastActiveIndex = currentIndex
		scrollToActiveOp(currentIndex)
	end

	-- 摘要
	local total = #queue
	if total > 0 then
		local pct = (completedCount / total) * 100
		local timeStr
		local isOver = false
		local okOver, over = pcall(RTD.IsRoundOver)
		if okOver and over then
			isOver = true
			local result = RTD.GetLastResult()
			if type(result) == "table" and result.IsVictory == true then
				timeStr = L.game_victory
			elseif type(result) == "table" and result.IsVictory == false then
				timeStr = L.game_defeat
			else
				timeStr = L.game_unknown
			end
		end
		if not isOver then
			local remaining = RTD.GetQueueRemaining()
			if remaining then
				timeStr = string.format(L.time_countdown, remaining)
			else
				timeStr = string.format(L.time_elapsed, elapsed)
			end
		end
		statusLabel.Text = string.format(L.summary_format, completedCount, total, pct, timeStr, formatNumber(cash))
	else
		statusLabel.Text = L.queue_empty
	end
end

-- === UI 刷新背景循環 ===
task.spawn(function()
	while running and screenGui.Parent and globalEnv.__RTDQueueMonitorId == myInstanceId do
		pcall(updateUIList)
		task.wait(0.2)
	end
end)

-- 迴圈因實例 ID 變更而結束時，確保自己的視窗也被清掉
task.spawn(function()
	while running and screenGui.Parent do
		if globalEnv.__RTDQueueMonitorId ~= myInstanceId then
			screenGui:Destroy()
			break
		end
		task.wait(0.5)
	end
end)

print(L.log_started)
