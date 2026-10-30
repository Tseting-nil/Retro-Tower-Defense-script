-- 復古塔防 (Retro Tower Defense) - 排程追蹤器
-- 錄製玩家的 放置 / 升級 / 賣出 / 倍速 / 自動跳波 / 跳波投票，並生成可執行的重播腳本。
-- 放置與升級走「金錢閘門」（以 Cash 減少量為準），其餘動作走「時間閘門」。
-- 攔截方式：ByteNetworking monkey-patch（與 user-scripts/動作追蹤器.lua 相同）。

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local TowerSharedService = require(ReplicatedStorage.Teawork.Shared.Services.TowerSharedService)
local ByteNetworking = require(ReplicatedStorage.Teawork.Shared.Services.ByteNetworking)
local TowerController = require(ReplicatedStorage.Teawork.Client.Services.Game.TowerController)

-- 重複執行時先卸載舊版
local globalEnv = (getgenv and getgenv()) or _G
if globalEnv.__RTDTrackerCleanup then
	pcall(globalEnv.__RTDTrackerCleanup)
end
local cleanups = {}

local Lang = "zh" -- 預設為中文
local i18n = {
	zh = {
		title = "復古塔防 | 排程追蹤器",
		btn_copy = "📋 複製",
		btn_save = "💾 儲存",
		btn_param = "⚙️ 參數",
		btn_reset = "🔄 重置",
		param_title = "  ⚙️ 參數設定",
		on = "開",
		opt_autoscroll = "自動捲軸",
		opt_costmode = "金錢閘門（放置/升級）",
		opt_timeroundup = "時間無條件進位",
		comment_label = "腳本註解（寫入生成檔案開頭）",
		comment_placeholder = "例如：地圖 / 難度 / 備註",
		info_title = "ℹ️ 遊戲資訊",
		save_title = "  💾 儲存腳本",
		filename_label = "輸入腳本名稱:",
		filename_placeholder = "輸入腳本名稱...",
		btn_confirm_save = "✅ 確認儲存",
		btn_cancel = "❌ 取消",
		log_new_round = "🆕 新的一局開始，已清除上一局記錄",
		log_timer_start = "⏱ 開始計時（第一個操作）",
		remote_not_found = "[RTD Tracker] 找不到 %s",
		log_place = "放置塔 #%d: %s %s  %s",
		log_place_failed = "⚠️ 放置失敗: %s (%s)",
		log_upgrade = "升級 #%d: %s%s  %s",
		log_upgrade_untracked = "升級 [uid:%s] (未追蹤)%s  +%.1fs",
		log_sell = "賣出塔 #%d: %s  +%.1fs",
		log_sell_untracked = "賣出 [uid:%s] (未追蹤)  +%.1fs",
		log_speed = "速度設定: %dx  +%.1fs",
		log_autoskip = "自動跳波: %s  +%.1fs",
		log_skipvote = "跳過波次投票: %s  +%.1fs",
		state_ended = "已結束",
		not_detected = "尚未偵測",
		info_text = "地圖: %s\n難度: %s\n狀態: %s\n已錄製操作: %d　塔: %d\n時間: %.1fs",
		time_not_final = "  (單局尚未結束，暫用目前時間)",
		log_no_ops = "⚠️ 沒有可生成的操作記錄",
		log_copied = "✅ 腳本已複製到剪貼板！",
		log_printed = "⚠️ 腳本已輸出到控制台（F9查看）",
		log_bad_name = "⚠️ 請輸入有效的腳本名稱",
		log_saved = "✅ 已儲存: %s",
		log_save_failed = "❌ 儲存失敗: %s",
		log_reset = "🔄 追蹤器已重置（下次操作或準備完畢時重新計時）",
		victory = "勝利",
		waves = " 波次 %s",
		log_game_over = "🏁 遊戲結束  總時間: %s%s  共 %d 項操作",
		roundinfo_missing = "[RTD Tracker] 找不到 ReplicatedStorage.RoundInfo，無法以 Running 偵測結束",
		roundresult_failed = "[RTD Tracker] RoundResult.Show 監聽失敗",
		log_howto = "怎麼使用: 像個正常玩家一樣操作，所有操作都會被腳本記錄!! 祝你遊戲愉快",
		log_howto2 = "計時從第一個操作（開局前放置）開始，按下 Start 會記錄開始時間點",
		log_map = "🗺️ 地圖: %s  難度: %s",
		defeat = "失敗",
		agree = "同意",
		disagree = "反對",
		off = "關",
		state_running = "進行中",
		state_waiting = "待開局",
	},
	en = {
		title = "Retro Tower Defense | Schedule Tracker",
		btn_copy = "📋 Copy",
		btn_save = "💾 Save",
		btn_param = "⚙️ Settings",
		btn_reset = "🔄 Reset",
		param_title = "  ⚙️ Settings",
		on = "On",
		opt_autoscroll = "Auto scroll",
		opt_costmode = "Cash gate (place/upgrade)",
		opt_timeroundup = "Round time up",
		comment_label = "Script comment (written at top of file)",
		comment_placeholder = "e.g. map / difficulty / notes",
		info_title = "ℹ️ Game info",
		save_title = "  💾 Save script",
		filename_label = "Script name:",
		filename_placeholder = "Enter script name...",
		btn_confirm_save = "✅ Save",
		btn_cancel = "❌ Cancel",
		log_new_round = "🆕 New round started, previous record cleared",
		log_timer_start = "⏱ Timer started (first action)",
		remote_not_found = "[RTD Tracker] Not found: %s",
		log_place = "Place tower #%d: %s %s  %s",
		log_place_failed = "⚠️ Place failed: %s (%s)",
		log_upgrade = "Upgrade #%d: %s%s  %s",
		log_upgrade_untracked = "Upgrade [uid:%s] (untracked)%s  +%.1fs",
		log_sell = "Sell tower #%d: %s  +%.1fs",
		log_sell_untracked = "Sell [uid:%s] (untracked)  +%.1fs",
		log_speed = "Speed: %dx  +%.1fs",
		log_autoskip = "Auto skip: %s  +%.1fs",
		log_skipvote = "Skip wave vote: %s  +%.1fs",
		state_ended = "Ended",
		not_detected = "Not detected",
		info_text = "Map: %s\nDifficulty: %s\nState: %s\nRecorded ops: %d  Towers: %d\nTime: %.1fs",
		time_not_final = "  (round not ended, using current time)",
		log_no_ops = "⚠️ No recorded actions to generate",
		log_copied = "✅ Script copied to clipboard!",
		log_printed = "⚠️ Script printed to console (press F9)",
		log_bad_name = "⚠️ Please enter a valid script name",
		log_saved = "✅ Saved: %s",
		log_save_failed = "❌ Save failed: %s",
		log_reset = "🔄 Tracker reset (timer restarts at next action or ready vote)",
		victory = "Victory",
		waves = " wave %s",
		log_game_over = "🏁 Game over  Total time: %s%s  %d actions",
		roundinfo_missing = "[RTD Tracker] ReplicatedStorage.RoundInfo not found, cannot detect end via Running",
		roundresult_failed = "[RTD Tracker] RoundResult.Show listen failed",
		log_howto = "How to use: play like a normal player, every action is recorded!! Have fun",
		log_howto2 = "Timer starts at the first action (pre-start placement); pressing Start records the start time",
		log_map = "🗺️ Map: %s  Difficulty: %s",
		defeat = "Defeat",
		agree = "Agree",
		disagree = "Disagree",
		off = "Off",
		state_running = "In progress",
		state_waiting = "Waiting",
	},
}

-- 語言：Tsetingnil_script/keysystem.json 的 script_language（與花園版、RTD API 相同）
pcall(function()
	if isfile and isfile("Tsetingnil_script/keysystem.json") then
		local content = readfile("Tsetingnil_script/keysystem.json")
		if content then
			local scriptLang = nil
			local ok, data = pcall(function()
				return game:GetService("HttpService"):JSONDecode(content)
			end)
			if ok and data and data.script_language then
				scriptLang = data.script_language
			else
				scriptLang = content:match('"script_language"%s*:%s*"([^"]+)"')
			end
			if scriptLang then
				local sl = scriptLang:lower()
				if sl:find("chinese") or sl:find("zh") then
					Lang = "zh"
				elseif sl:find("english") or sl:find("en") then
					Lang = "en"
				end
			end
		end
	end
end)

local function tr(key, ...)
	local langTable = i18n[Lang] or i18n["zh"]
	local template = langTable[key] or i18n["zh"][key] or key
	if select("#", ...) > 0 and type(template) == "string" then
		local ok, res = pcall(string.format, template, ...)
		if ok then
			return res
		end
	end
	return template
end

-- 生成腳本載入的重播 API 網址（API 完成後填入）
local RTD_API_URL = "https://raw.githubusercontent.com/Tseting-nil/Retro-Tower-Defense-script/refs/heads/main/%E5%AF%86%E9%91%B0%E7%B3%BB%E7%B5%B1.lua"
local RTD_TRACKER_URL = "https://raw.githubusercontent.com/Tseting-nil/Retro-Tower-Defense-script/refs/heads/main/Tool/%E6%94%BE%E7%BD%AE%E8%BF%BD%E8%B9%A4%E5%99%A8.lua"
local SCRIPT_SAVE_PATH = "Tsetingnil_script/RTD/Script"

----------------------------------------------------------------------
-- 主題與尺寸
----------------------------------------------------------------------
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local UISizes = {
	mainFrame = isMobile and UDim2.new(0, 320, 0, 350) or UDim2.new(0, 550, 0, 480),
	mainFrameMinimized = isMobile and UDim2.new(0, 320, 0, 50) or UDim2.new(0, 550, 0, 50),
	parameterFrame = isMobile and UDim2.new(0, 280, 0, 400) or UDim2.new(0, 360, 0, 410),
	parameterFramePosition = isMobile and UDim2.new(0.5, -140, 0.5, -200) or UDim2.new(0.5, -180, 0.5, -205),
	saveFrame = isMobile and UDim2.new(0, 280, 0, 190) or UDim2.new(0, 350, 0, 190),
	saveFramePosition = isMobile and UDim2.new(0.5, -140, 0.5, -95) or UDim2.new(0.5, -175, 0.5, -95),
}

local Theme = {
	Background = Color3.fromRGB(25, 27, 30),
	Surface = Color3.fromRGB(35, 38, 42),
	SurfaceHighlight = Color3.fromRGB(45, 48, 52),
	Border = Color3.fromRGB(60, 65, 70),
	Text = Color3.fromRGB(230, 230, 230),
	TextDark = Color3.fromRGB(30, 30, 30),
	TextDim = Color3.fromRGB(160, 160, 160),
	Accent = Color3.fromRGB(60, 160, 255),
	Success = Color3.fromRGB(100, 220, 120),
	Warning = Color3.fromRGB(255, 180, 60),
	Error = Color3.fromRGB(255, 80, 80),
	CornerRadius = UDim.new(0, 10),
	Font = Enum.Font.GothamMedium,
	FontBold = Enum.Font.GothamBold,
	SizeLarge = 24,
	SizeMedium = 16,
	SizeNormal = 16,
}

local ScriptSettings = {
	CostMode = true, -- true = 放置/升級用金錢閘門；false = 全部用時間閘門
	TimeRoundUp = false,
	AutoScroll = true,
	Comment = "",
}

----------------------------------------------------------------------
-- 金錢追蹤（Cash 減少 → 依序配給等待中的放置/升級）
----------------------------------------------------------------------
local CostTracker = { LastMoney = nil, Connection = nil, Queue = {} }

-- 遊戲的 Cash 是字串：1000 以下 / 一萬以下顯示 "17,824"，大額縮寫成 "40.3K"、"1.2M"。
-- 只刪掉非數字字元會把 "40.3K" 讀成 403，所以要認 K / M / B / T 後綴。
local MONEY_SUFFIX = { K = 1e3, M = 1e6, B = 1e9, T = 1e12 }
local function parseMoney(raw)
	if type(raw) == "number" then
		return raw
	end
	local text = tostring(raw):gsub(",", ""):gsub("[%s$]", "")
	local num, suffix = text:match("^(%-?[%d%.]+)(%a?)$")
	if not num then
		return tonumber((text:gsub("[^%d%-]", "")))
	end
	local value = tonumber(num)
	if not value then
		return nil
	end
	return value * (MONEY_SUFFIX[suffix:upper()] or 1)
end

local function readMoney()
	local ok, value = pcall(function()
		local ls = LocalPlayer:FindFirstChild("leaderstats")
		local cash = ls and ls:FindFirstChild("Cash")
		if not cash then
			return nil
		end
		-- 精確數值：Cash 實體的 "Value" 屬性（數字；遊戲自己的 PlayerController:GetLeaderstat("Cash") 也是讀這個）。
		-- StringValue.Value 只是顯示用字串（大額會縮寫成 "40.3K"），僅作備援。
		local exact = cash:GetAttribute("Value")
		if type(exact) == "number" then
			return exact
		end
		return parseMoney(cash.Value)
	end)
	return ok and tonumber(value) or nil
end

local function onMoneyChanged()
	local now = readMoney()
	if not now then
		return
	end
	local last = CostTracker.LastMoney
	CostTracker.LastMoney = now
	if not last or now >= last then
		return
	end
	local pending = table.remove(CostTracker.Queue, 1)
	if pending then
		pending.cost = last - now
	end
end

local function pushCostAction()
	local action = { cost = nil }
	table.insert(CostTracker.Queue, action)
	return action
end

local function cancelCostAction(action)
	for i, v in ipairs(CostTracker.Queue) do
		if v == action then
			table.remove(CostTracker.Queue, i)
			break
		end
	end
end

task.spawn(function()
	local ls = LocalPlayer:WaitForChild("leaderstats", 10)
	local cash = ls and ls:WaitForChild("Cash", 5)
	if not cash then
		return
	end
	CostTracker.LastMoney = readMoney()
	-- 監聽屬性而非 StringValue：縮寫字串（"40.3K"）在小額變動時不會改變，會漏掉消費
	CostTracker.Connection = cash:GetAttributeChangedSignal("Value"):Connect(onMoneyChanged)
end)
table.insert(cleanups, function()
	if CostTracker.Connection then
		CostTracker.Connection:Disconnect()
	end
end)

----------------------------------------------------------------------
-- UI
----------------------------------------------------------------------
local guiParent = (get_hidden_gui or gethui)
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "RTDTrackerUI"
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.Parent = guiParent and guiParent() or game:GetService("CoreGui")
table.insert(cleanups, function()
	screenGui:Destroy()
end)

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or Theme.CornerRadius
	c.Parent = parent
end

local function stroke(parent)
	local s = Instance.new("UIStroke")
	s.Thickness = 1.5
	s.Color = Theme.Border
	s.Transparency = 0.2
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
end

local function makePanel(size, position, zIndex, titleText, titleColor, closeable)
	local frame = Instance.new("Frame")
	frame.Size = size
	frame.Position = position
	frame.BackgroundColor3 = Theme.Background
	frame.BackgroundTransparency = 0.05
	frame.Active = true
	frame.BorderSizePixel = 0
	frame.ClipsDescendants = true
	frame.ZIndex = zIndex
	frame.Parent = screenGui
	corner(frame)
	stroke(frame)

	local bar = Instance.new("Frame")
	bar.Name = "TitleBar"
	bar.Size = UDim2.new(1, 0, 0, 45)
	bar.BackgroundColor3 = Theme.Surface
	bar.BorderSizePixel = 0
	bar.ZIndex = zIndex + 1
	bar.Parent = frame
	corner(bar)

	local cover = Instance.new("Frame")
	cover.Size = UDim2.new(1, 0, 0, 10)
	cover.Position = UDim2.new(0, 0, 1, -10)
	cover.BackgroundColor3 = Theme.Surface
	cover.BorderSizePixel = 0
	cover.ZIndex = zIndex + 1
	cover.Parent = bar

	local sep = Instance.new("Frame")
	sep.Size = UDim2.new(1, 0, 0, 1)
	sep.Position = UDim2.new(0, 0, 1, -1)
	sep.BackgroundColor3 = Theme.Border
	sep.BorderSizePixel = 0
	sep.ZIndex = zIndex + 1
	sep.Parent = bar

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -90, 1, 0)
	title.Position = UDim2.new(0, 10, 0, 0)
	title.BackgroundTransparency = 1
	title.Text = titleText
	title.TextColor3 = titleColor
	title.Font = Theme.FontBold
	title.TextSize = Theme.SizeLarge
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.ZIndex = zIndex + 2
	title.Parent = bar

	local closeBtn
	if closeable then
		closeBtn = Instance.new("TextButton")
		closeBtn.Size = UDim2.new(0, 35, 0, 35)
		closeBtn.Position = UDim2.new(1, -40, 0, 5)
		closeBtn.Text = "×"
		closeBtn.BackgroundColor3 = Theme.Error
		closeBtn.TextColor3 = Theme.Text
		closeBtn.Font = Theme.FontBold
		closeBtn.TextSize = 24
		closeBtn.BorderSizePixel = 0
		closeBtn.ZIndex = zIndex + 2
		closeBtn.Parent = bar
		corner(closeBtn, UDim.new(0, 8))
	end
	return frame, bar, closeBtn
end

-- 拖曳
local function makeDraggable(frame, handle)
	local dragging, dragStart, startPos = false, nil, nil
	handle.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
		end
	end)
	local conn = UserInputService.InputChanged:Connect(function(input)
		if
			dragging
			and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch)
		then
			local d = input.Position - dragStart
			frame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y)
		end
	end)
	local conn2 = UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)
	table.insert(cleanups, function()
		conn:Disconnect()
		conn2:Disconnect()
	end)
end

local mainFrame, titleBar = makePanel(UISizes.mainFrame, UDim2.new(0.2, 0, 0.2, 0), 1, tr("title"), Theme.Accent, false)
makeDraggable(mainFrame, titleBar)

local minimizeBtn = Instance.new("TextButton")
minimizeBtn.Size = UDim2.new(0, 35, 0, 35)
minimizeBtn.Position = UDim2.new(1, -40, 0, 5)
minimizeBtn.Text = "-"
minimizeBtn.BackgroundColor3 = Theme.SurfaceHighlight
minimizeBtn.TextColor3 = Theme.Text
minimizeBtn.Font = Theme.FontBold
minimizeBtn.TextSize = 26
minimizeBtn.BorderSizePixel = 0
minimizeBtn.ZIndex = 3
minimizeBtn.Parent = titleBar
corner(minimizeBtn, UDim.new(0, 8))

local scrollFrame = Instance.new("ScrollingFrame")
scrollFrame.Size = UDim2.new(1, -20, 1, -100)
scrollFrame.Position = UDim2.new(0, 10, 0, 50)
scrollFrame.CanvasSize = UDim2.new(0, 0, 0, 0)
scrollFrame.ScrollBarThickness = 4
scrollFrame.BackgroundTransparency = 1
scrollFrame.ScrollBarImageColor3 = Theme.Border
scrollFrame.BorderSizePixel = 0
scrollFrame.Parent = mainFrame

local listLayout = Instance.new("UIListLayout")
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Padding = UDim.new(0, 8)
listLayout.Parent = scrollFrame

listLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scrollFrame.CanvasSize = UDim2.new(0, 0, 0, listLayout.AbsoluteContentSize.Y + 10)
	if ScriptSettings.AutoScroll then
		scrollFrame.CanvasPosition = Vector2.new(0, scrollFrame.CanvasSize.Y.Offset)
	end
end)

local buttonContainer = Instance.new("Frame")
buttonContainer.Size = UDim2.new(1, -20, 0, 40)
buttonContainer.Position = UDim2.new(0, 10, 1, -45)
buttonContainer.BackgroundTransparency = 1
buttonContainer.Parent = mainFrame
do
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Padding = UDim.new(0, 6)
	l.Parent = buttonContainer
end

local function makeBtn(text, bg, fg, order)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.25, -5, 1, 0)
	btn.BackgroundColor3 = bg
	btn.TextColor3 = fg
	btn.Text = text
	btn.Font = Theme.FontBold
	btn.TextSize = Theme.SizeMedium
	btn.BorderSizePixel = 0
	btn.LayoutOrder = order
	btn.Parent = buttonContainer
	corner(btn)
	return btn
end

local copyBtn = makeBtn(tr("btn_copy"), Theme.Success, Theme.TextDark, 1)
local saveBtn = makeBtn(tr("btn_save"), Theme.Accent, Theme.Text, 2)
local paramBtn = makeBtn(tr("btn_param"), Theme.SurfaceHighlight, Theme.Text, 3)
local resetBtn = makeBtn(tr("btn_reset"), Theme.SurfaceHighlight, Theme.Warning, 4)

local logOrder = 1
local function renderLog(text, color)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -10, 0, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Theme.Text
	label.Font = Theme.Font
	label.TextSize = 14
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.AutomaticSize = Enum.AutomaticSize.Y
	label.LayoutOrder = logOrder
	label.Parent = scrollFrame
	logOrder += 1
end

-- 遊戲端的呼叫（如 ReadyButton）跑在受限能力執行緒，無法 Instance.new；
-- 攔截函式只把訊息排入佇列，由自己的執行緒負責建立 UI。
local logQueue = {}
local function addLog(text, color)
	table.insert(logQueue, { text, color })
end

local pumpRunning = true
task.spawn(function()
	while pumpRunning do
		task.wait(0.1)
		local q = logQueue
		logQueue = {}
		for _, item in ipairs(q) do
			if item.clear then
				pcall(function()
					for _, c in ipairs(scrollFrame:GetChildren()) do
						if c:IsA("TextLabel") then
							c:Destroy()
						end
					end
					logOrder = 1
				end)
			else
				pcall(renderLog, item[1], item[2])
			end
		end
	end
end)
table.insert(cleanups, function()
	pumpRunning = false
end)

-- 清除也走佇列（可能從遊戲執行緒呼叫，不能直接碰 Instance）
local function clearLog()
	logQueue = { { clear = true } }
end

local minimized = false
minimizeBtn.MouseButton1Click:Connect(function()
	minimized = not minimized
	mainFrame.Size = minimized and UISizes.mainFrameMinimized or UISizes.mainFrame
	scrollFrame.Visible = not minimized
	buttonContainer.Visible = not minimized
	minimizeBtn.Text = minimized and "+" or "-"
end)

-- 參數面板
local paramFrame, _, paramClose = makePanel(UISizes.parameterFrame, UISizes.parameterFramePosition, 10, tr("param_title"), Theme.Text, true)
paramFrame.Visible = false
makeDraggable(paramFrame, paramFrame.TitleBar)
paramClose.MouseButton1Click:Connect(function()
	paramFrame.Visible = false
end)

local toggleRows = 0
local function makeToggleRow(labelText, key)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, -20, 0, 36)
	row.Position = UDim2.new(0, 10, 0, 55 + toggleRows * 44)
	row.BackgroundColor3 = Theme.Surface
	row.BorderSizePixel = 0
	row.ZIndex = 11
	row.Parent = paramFrame
	corner(row, UDim.new(0, 8))
	toggleRows += 1

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -80, 1, 0)
	lbl.Position = UDim2.new(0, 10, 0, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = labelText
	lbl.TextColor3 = Theme.Text
	lbl.Font = Theme.Font
	lbl.TextSize = Theme.SizeNormal
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.ZIndex = 12
	lbl.Parent = row

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 60, 0, 26)
	btn.Position = UDim2.new(1, -68, 0, 5)
	btn.BorderSizePixel = 0
	btn.Font = Theme.FontBold
	btn.TextSize = 14
	btn.ZIndex = 12
	btn.Parent = row
	corner(btn, UDim.new(0, 6))

	local function refresh()
		local on = ScriptSettings[key] == true
		btn.Text = on and tr("on") or tr("off")
		btn.BackgroundColor3 = on and Theme.Success or Theme.SurfaceHighlight
		btn.TextColor3 = on and Theme.TextDark or Theme.TextDim
	end
	btn.MouseButton1Click:Connect(function()
		ScriptSettings[key] = not ScriptSettings[key]
		refresh()
	end)
	refresh()
end

makeToggleRow(tr("opt_autoscroll"), "AutoScroll")
makeToggleRow(tr("opt_costmode"), "CostMode")
makeToggleRow(tr("opt_timeroundup"), "TimeRoundUp")

do
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -20, 0, 20)
	lbl.Position = UDim2.new(0, 10, 0, 55 + toggleRows * 44)
	lbl.BackgroundTransparency = 1
	lbl.Text = tr("comment_label")
	lbl.TextColor3 = Theme.TextDim
	lbl.Font = Theme.Font
	lbl.TextSize = 14
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.ZIndex = 11
	lbl.Parent = paramFrame

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -20, 0, 35)
	box.Position = UDim2.new(0, 10, 0, 80 + toggleRows * 44)
	box.BackgroundColor3 = Theme.SurfaceHighlight
	box.PlaceholderColor3 = Theme.TextDim
	box.PlaceholderText = tr("comment_placeholder")
	box.Text = ""
	box.TextColor3 = Theme.Text
	box.Font = Theme.Font
	box.TextSize = Theme.SizeNormal
	box.BorderSizePixel = 0
	box.ClearTextOnFocus = false
	box.ZIndex = 12
	box.Parent = paramFrame
	corner(box, UDim.new(0, 6))
	box:GetPropertyChangedSignal("Text"):Connect(function()
		ScriptSettings.Comment = box.Text
	end)
end

-- 遊戲資訊（地圖 / 難度 / 狀態 / 操作數）
local infoLabel
local refreshInfo = nil -- 下方（地圖偵測定義之後）賦值
do
	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, -20, 0, 20)
	lbl.Position = UDim2.new(0, 10, 0, 262)
	lbl.BackgroundTransparency = 1
	lbl.Text = tr("info_title")
	lbl.TextColor3 = Theme.TextDim
	lbl.Font = Theme.Font
	lbl.TextSize = 14
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.ZIndex = 11
	lbl.Parent = paramFrame

	infoLabel = Instance.new("TextLabel")
	infoLabel.Size = UDim2.new(1, -20, 0, 100)
	infoLabel.Position = UDim2.new(0, 10, 0, 285)
	infoLabel.BackgroundColor3 = Theme.Surface
	infoLabel.BackgroundTransparency = 0.5
	infoLabel.TextColor3 = Theme.Success
	infoLabel.Font = Theme.Font
	infoLabel.TextSize = 15
	infoLabel.TextWrapped = true
	infoLabel.Text = "—"
	infoLabel.BorderSizePixel = 0
	infoLabel.ZIndex = 13
	infoLabel.Parent = paramFrame
	corner(infoLabel, UDim.new(0, 6))
end

paramBtn.MouseButton1Click:Connect(function()
	paramFrame.Visible = not paramFrame.Visible
	if paramFrame.Visible and refreshInfo then
		refreshInfo()
	end
end)

-- 儲存面板
local saveFrame, _, saveClose = makePanel(UISizes.saveFrame, UISizes.saveFramePosition, 10, tr("save_title"), Theme.Text, true)
saveFrame.Visible = false
makeDraggable(saveFrame, saveFrame.TitleBar)
saveClose.MouseButton1Click:Connect(function()
	saveFrame.Visible = false
end)

local fileNameLabel = Instance.new("TextLabel")
fileNameLabel.Size = UDim2.new(1, -20, 0, 20)
fileNameLabel.Position = UDim2.new(0, 10, 0, 55)
fileNameLabel.BackgroundTransparency = 1
fileNameLabel.Text = tr("filename_label")
fileNameLabel.TextColor3 = Theme.TextDim
fileNameLabel.Font = Theme.Font
fileNameLabel.TextSize = Theme.SizeNormal
fileNameLabel.TextXAlignment = Enum.TextXAlignment.Left
fileNameLabel.ZIndex = 12
fileNameLabel.Parent = saveFrame

local fileNameInput = Instance.new("TextBox")
fileNameInput.Size = UDim2.new(1, -20, 0, 35)
fileNameInput.Position = UDim2.new(0, 10, 0, 80)
fileNameInput.BackgroundColor3 = Theme.SurfaceHighlight
fileNameInput.PlaceholderColor3 = Theme.TextDim
fileNameInput.PlaceholderText = tr("filename_placeholder")
fileNameInput.Text = ""
fileNameInput.TextColor3 = Theme.Text
fileNameInput.Font = Theme.Font
fileNameInput.TextSize = Theme.SizeNormal
fileNameInput.BorderSizePixel = 0
fileNameInput.ClearTextOnFocus = false
fileNameInput.ZIndex = 12
fileNameInput.Parent = saveFrame
corner(fileNameInput, UDim.new(0, 6))

local saveBtnRow = Instance.new("Frame")
saveBtnRow.Size = UDim2.new(1, -20, 0, 40)
saveBtnRow.Position = UDim2.new(0, 10, 0, 130)
saveBtnRow.BackgroundTransparency = 1
saveBtnRow.ZIndex = 12
saveBtnRow.Parent = saveFrame
do
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, 10)
	l.Parent = saveBtnRow
end

local function makeSaveRowBtn(text, bg, fg)
	local b = Instance.new("TextButton")
	b.Size = UDim2.new(0.5, -5, 1, 0)
	b.BackgroundColor3 = bg
	b.Text = text
	b.TextColor3 = fg
	b.Font = Theme.FontBold
	b.TextSize = Theme.SizeMedium
	b.BorderSizePixel = 0
	b.ZIndex = 12
	b.Parent = saveBtnRow
	corner(b)
	return b
end
local confirmSaveBtn = makeSaveRowBtn(tr("btn_confirm_save"), Theme.Success, Theme.TextDark)
local cancelSaveBtn = makeSaveRowBtn(tr("btn_cancel"), Theme.SurfaceHighlight, Theme.Text)
cancelSaveBtn.MouseButton1Click:Connect(function()
	saveFrame.Visible = false
end)

----------------------------------------------------------------------
-- 錄製狀態
----------------------------------------------------------------------
local startTime = nil
local ops = {} -- 依發生順序的操作清單
local function pushOp(op)
	table.insert(ops, op)
end
local nextOrder = 1
local orderInfo = {} -- order -> { towerId, pos, ... }
local usedTowers, usedTowerSet = {}, {} -- 本局用到的塔（名稱，依首次放置順序、去重）
local uidToOrder = {} -- 伺服器塔 UID -> order
local pendingBind = {} -- 已放置成功、尚未取得 UID 的 order 記錄

local endTime = nil -- 本局結束時間點（結束後 elapsed 凍結）
local roundEnded = false

local onGameStart = nil -- 「準備完畢/開始遊戲」投票觸發（下方賦值）

local resetRecording = nil -- 下方賦值

-- 任何操作發生時呼叫：上一局已結束的話，這就是新一局（開局前的放置）的開始，先清掉舊記錄。
-- 計時從第一個操作（開局前的放置）開始；按下 Start 只是記一筆「開始」，不重新計時。
local startPressed = false

local function beginSession()
	if roundEnded and resetRecording then
		resetRecording()
		addLog(tr("log_new_round"), Theme.Warning)
	end
	if not startTime then
		startTime = tick()
		addLog(tr("log_timer_start"), Theme.Accent)
	end
end

local function elapsed()
	if not startTime then
		return 0
	end
	return (endTime or tick()) - startTime
end

local function fmtVec(v)
	return typeof(v) == "Vector3" and string.format("(%.2f, %.2f, %.2f)", v.X, v.Y, v.Z) or tostring(v)
end

local function closeTo(a, b)
	return typeof(a) == "Vector3" and typeof(b) == "Vector3" and (a - b).Magnitude < 0.5
end

local function entryTowerId(tower)
	if type(tower) ~= "table" then
		return nil
	end
	local entry = tower.TowerEntry
	return (entry and entry.ItemID) or tower.TowerID
end

-- 嘗試把 pendingBind 的記錄綁到伺服器配發的 UID
local function tryBindPending()
	if #pendingBind == 0 then
		return
	end
	local ok, towers = pcall(function()
		return TowerController:GetTowers()
	end)
	if not ok or type(towers) ~= "table" then
		return
	end
	for _, tower in pairs(towers) do
		local uid = type(tower) == "table" and tower.UID
		if uid and not uidToOrder[uid] and (tower.PlayerId == nil or tower.PlayerId == LocalPlayer.UserId) then
			for i, rec in ipairs(pendingBind) do
				if rec.towerId == entryTowerId(tower) and closeTo(rec.pos, tower.Position) then
					uidToOrder[uid] = rec.order
					rec.uid = uid
					table.remove(pendingBind, i)
					break
				end
			end
		end
	end
end

-- 牌價查詢（TowerSharedService）：升級 = 當前等級+1 的 Price；放置 = 1 級 Price（查不到回 nil，退回金錢差額）
local function getUpgradePrice(uid)
	local ok, price = pcall(function()
		local tower = TowerController:GetTower(uid)
		if not tower then
			return nil
		end
		local stats = TowerSharedService:GetTowerStats(tower.TowerEntry.ItemID, tower.Upgrade + 1, tower.Boosts, tower.TraitID)
		return stats and stats.Price
	end)
	return ok and tonumber(price) or nil
end

local function getPlacePrice(towerId)
	local ok, price = pcall(function()
		local stats = TowerSharedService:GetTowerStats(towerId, 1, nil, nil)
		return stats and stats.Price
	end)
	return ok and tonumber(price) or nil
end

local function cleanName(id)
	return tostring(id or "?")
end

----------------------------------------------------------------------
-- 攔截：放置 / 升級 / 賣出 / 倍速 / 自動跳波 / 跳波投票 / 開始遊戲
----------------------------------------------------------------------
local Towers = ByteNetworking.Towers
local function patchFn(tbl, name, key, wrapper)
	local target = tbl and tbl[name]
	if not target or not target[key] then
		warn(tr("remote_not_found", name .. "." .. key))
		return
	end
	local original = target[key]
	target[key] = wrapper(original)
	table.insert(cleanups, function()
		target[key] = original
	end)
end

patchFn(Towers, "PlaceTower", "invoke", function(original)
	return function(data)
		beginSession()
		local t = elapsed()
		local action = ScriptSettings.CostMode and pushCostAction() or nil
		local tablePrice = type(data) == "table" and getPlacePrice(data.TowerID) or nil
		local res = original(data)
		if type(data) == "table" and type(res) == "table" and res.Success then
			local order = nextOrder
			nextOrder += 1
			local rec = {
				order = order,
				towerId = data.TowerID,
				pos = data.Position,
				rot = tonumber(data.Rotation) or 0,
				up = data.UpVector,
				costAction = action,
				price = tablePrice,
			}
			orderInfo[order] = rec
			local towerName = tostring(data.TowerID)
			if not usedTowerSet[towerName] then
				usedTowerSet[towerName] = true
				table.insert(usedTowers, towerName)
			end
			pushOp({ type = "place", t = t, rec = rec })
			local uid = res.UID or res.TowerUID
			if uid then
				uidToOrder[uid] = order
				rec.uid = uid
			else
				table.insert(pendingBind, rec)
				tryBindPending()
				task.delay(0.5, tryBindPending)
			end
			addLog(tr("log_place", order, cleanName(data.TowerID), fmtVec(data.Position), tablePrice and ("$" .. math.floor(tablePrice + 0.5)) or string.format("+%.1fs", t)), Theme.Success)
		else
			if action then
				cancelCostAction(action)
			end
			if type(data) == "table" then
				addLog(tr("log_place_failed", cleanName(data.TowerID), tostring(type(res) == "table" and res.FailReason or "?")), Theme.Warning)
			end
		end
		return res
	end
end)

patchFn(Towers, "UpgradeTower", "invoke", function(original)
	return function(uid)
		beginSession()
		local t = elapsed()
		local action = ScriptSettings.CostMode and pushCostAction() or nil
		local tablePrice = getUpgradePrice(uid)
		local res = original(uid)
		if type(res) == "table" and res.Success then
			tryBindPending()
			local order = uidToOrder[uid]
			pushOp({ type = "upgrade", t = t, order = order, uid = uid, costAction = action, price = tablePrice })
			local lvl = res.Level and (" → Lv." .. tostring(res.Level)) or ""
			if order then
				local rec = orderInfo[order]
				addLog(tr("log_upgrade", order, cleanName(rec and rec.towerId), lvl, tablePrice and ("$" .. math.floor(tablePrice + 0.5)) or string.format("+%.1fs", t)), Theme.Accent)
			else
				addLog(tr("log_upgrade_untracked", tostring(uid), lvl, t), Theme.Warning)
			end
		elseif action then
			cancelCostAction(action)
		end
		return res
	end
end)

patchFn(Towers, "SellTower", "invoke", function(original)
	return function(uid)
		beginSession()
		local t = elapsed()
		local res = original(uid)
		if res then
			tryBindPending()
			local order = uidToOrder[uid]
			pushOp({ type = "sell", t = t, order = order, uid = uid })
			if order then
				addLog(tr("log_sell", order, cleanName(orderInfo[order].towerId), t), Theme.Error)
				uidToOrder[uid] = nil
			else
				addLog(tr("log_sell_untracked", tostring(uid), t), Theme.Warning)
			end
		end
		return res
	end
end)

patchFn(ByteNetworking.Timescale, "SetTimescale", "send", function(original)
	return function(speed)
		beginSession()
		local t = elapsed()
		local n = tonumber(speed)
		if n then
			pushOp({ type = "speed", t = t, speed = n })
			addLog(tr("log_speed", n, t))
		end
		return original(speed)
	end
end)

patchFn(ByteNetworking.SkipWave, "ToggleAutoSkip", "send", function(original)
	return function(enabled)
		beginSession()
		local t = elapsed()
		pushOp({ type = "autoskip", t = t, value = enabled == true })
		addLog(tr("log_autoskip", enabled and tr("on") or tr("off"), t))
		return original(enabled)
	end
end)

patchFn(ByteNetworking.SkipWave, "Vote", "send", function(original)
	return function(voteYes)
		beginSession()
		local t = elapsed()
		pushOp({ type = "skipwave", t = t, value = voteYes == true })
		addLog(tr("log_skipvote", voteYes and tr("agree") or tr("disagree"), t))
		return original(voteYes)
	end
end)

-- 開始遊戲投票：以第一次「準備完畢」作為時間零點
patchFn(ByteNetworking.ReadyVote, "Vote", "send", function(original)
	return function(voteReady)
		if voteReady and onGameStart then
			onGameStart()
		end
		return original(voteReady)
	end
end)

----------------------------------------------------------------------
-- 生成腳本
----------------------------------------------------------------------
local function timeGate(t)
	local v = ScriptSettings.TimeRoundUp and (math.ceil(t * 10) / 10) or (math.floor(t * 10) / 10)
	return string.format("%.1f", v)
end

-- 放置/升級：有金錢資料用金錢閘門（字串），否則退回時間閘門
local function costGate(op, costAction, price)
	local cost = price or (costAction and costAction.cost)
	if ScriptSettings.CostMode and cost and cost > 0 then
		local c = math.floor(cost + 0.5)
		return string.format('"%d"', c), "$" .. c
	end
	local g = timeGate(op.t)
	return g, "+" .. g .. "s"
end

-- 地圖 / 難度資訊（RoundInfo 屬性 + ItemDatabase 名稱轉換）；開局與結束時各刷新一次，保留最後一次有效值
local mapMeta = nil

local function readRoundMeta()
	local node = ReplicatedStorage:FindFirstChild("RoundInfo")
	if not node then
		return nil
	end
	local isCampaign = node:GetAttribute("IsCampaign") == true
	local id = isCampaign and node:GetAttribute("CampaignID") or node:GetAttribute("Map")
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local meta = {
		isCampaign = isCampaign,
		mapId = id,
		mapName = id,
		level = node:GetAttribute("CampaignLevel"),
		chapter = node:GetAttribute("CampaignChapter"),
		difficulty = tostring(node:GetAttribute("Difficulty") or "Normal"),
	}
	meta.difficultyName = meta.difficulty
	pcall(function()
		local db = ReplicatedStorage.Teawork.Shared.Services.ItemDatabase
		local item = require(isCampaign and db.Campaigns or db.Maps):GetItem(id)
		if item and item.Name then
			meta.mapName = item.Name
		end
		if isCampaign and item and item.Levels and meta.level and item.Levels[meta.level] then
			meta.levelName = item.Levels[meta.level].Name
		end
	end)
	pcall(function()
		local diff = require(ReplicatedStorage.Teawork.Shared.Modules.DifficultyShared)[meta.difficulty]
		if diff and diff.Name then
			meta.difficultyName = diff.Name
		end
	end)
	return meta
end

local function refreshMapMeta()
	local meta = readRoundMeta()
	if meta then
		mapMeta = meta
	end
	return mapMeta
end

local function mapText(meta)
	if not meta then
		return "Unknown"
	end
	if meta.isCampaign then
		return string.format("%s | %s - %s", meta.mapName, tostring(meta.levelName or meta.level or "?"), tostring(meta.chapter or "?"))
	end
	return tostring(meta.mapName)
end

refreshInfo = function()
	local meta = refreshMapMeta()
	local state = roundEnded and tr("state_ended") or (startTime and tr("state_running") or tr("state_waiting"))
	local mapStr = meta and mapText(meta) or tr("not_detected")
	local diffStr = meta and meta.difficultyName or tr("not_detected")
	infoLabel.Text = string.format(
		tr("info_text"),
		mapStr, diffStr, state, #ops, nextOrder - 1, elapsed())
end

task.spawn(function()
	while pumpRunning do
		task.wait(1)
		if paramFrame.Visible and refreshInfo then
			pcall(refreshInfo)
		end
	end
end)

local function generateScript()
	if #ops == 0 then
		return nil
	end

	local meta = refreshMapMeta()
	local total = elapsed()
	local timeText = string.format("%dm %ds (%.1fs)", math.floor(total / 60), math.floor(total % 60), total)
	local loader = {
		"local RTD = getgenv().RTD",
		"if not RTD or not RTD.ExecuteQueue then",
		string.format('\tloadstring(game:HttpGet("%s"))()', RTD_API_URL),
		"    RTD = getgenv().RTD",
		"end",
	}

	local lines = {}
	table.insert(lines, "--[[")
	table.insert(lines, "")
	if meta then
		table.insert(lines, string.format("Map: %s  |  Difficulty: %s", mapText(meta), meta.difficultyName))
		table.insert(lines, string.format("MapID: %s  |  DifficultyID: %s%s", meta.mapId, meta.difficulty, meta.isCampaign and "  |  Campaign" or ""))
	end
	table.insert(lines, "Time: " .. timeText .. (roundEnded and "" or tr("time_not_final")))
	table.insert(lines, "")
	if ScriptSettings.Comment ~= "" then
		table.insert(lines, (ScriptSettings.Comment:gsub("[\r\n]+", " ")))
		table.insert(lines, "")
	end
	if #usedTowers > 0 then
		table.insert(lines, "Towers used:")
		for _, n in ipairs(usedTowers) do
			table.insert(lines, "  - " .. n)
		end
		table.insert(lines, "")
	end
	table.insert(lines, "]]")
	table.insert(lines, "")
	table.insert(lines, "-- RTD_API")
	for _, l in ipairs(loader) do
		table.insert(lines, l)
	end
	table.insert(lines, "")
	table.insert(lines, "if RTD.IsLobby() then")
	-- 大廳：先裝備錄製用到的塔
	if #usedTowers > 0 then
		local towerLits = {}
		for _, n in ipairs(usedTowers) do
			table.insert(towerLits, string.format('"%s"', n))
		end
		table.insert(lines, string.format("\tRTD.EquipLoadout({ %s })", table.concat(towerLits, ", ")))
	end
	-- 大廳自動開局：一般地圖開房並開始；戰役開單人戰役（章節 / 關卡）
	if meta and meta.isCampaign then
		table.insert(lines, string.format('\tRTD.SelectCampaign("%s", %d, %d)', meta.mapId, tonumber(meta.chapter) or 1, tonumber(meta.level) or 1))
	elseif meta then
		table.insert(lines, string.format('\tRTD.SelectMap("%s")', meta.mapId))
	end
	table.insert(lines, "\treturn")
	table.insert(lines, "end")
	table.insert(lines, "")
	table.insert(lines, "if RTD.IsInGame() then")
	table.insert(lines, "\t-- initialization")
	table.insert(lines, "\tRTD.DeBug(false)")
	table.insert(lines, "\tRTD.AutoReplay(true)")
	-- 一般地圖（非戰役）才有難度投票
	if meta and not meta.isCampaign and meta.difficulty and meta.difficulty ~= "" then
		table.insert(lines, string.format('\tRTD.SelectDifficulty("%s")', meta.difficulty))
	end
	table.insert(lines, "\tRTD.AddSetSpeed(1, 0)")
	table.insert(lines, "\tRTD.AddSetAutoSkip(false, 0)")
	table.insert(lines, "\t-- Start")
	for _, op in ipairs(ops) do
		if op.type == "place" then
			local rec = op.rec
			local gate, tag = costGate(op, rec.costAction, rec.price)
			local p = rec.pos
			local up = rec.up
			local upStr = ""
			if typeof(up) == "Vector3" and (up - Vector3.new(0, 1, 0)).Magnitude > 0.001 then
				upStr = string.format(", %.4f, %.4f, %.4f", up.X, up.Y, up.Z)
			end
			table.insert(lines, string.format(
				'\tRTD.AddPlaceTower("%s", %s, %.3f, %.3f, %.3f, %d%s) -- #%d %s',
				tostring(rec.towerId), gate, p.X, p.Y, p.Z, math.floor(rec.rot + 0.5), upStr, rec.order, tag))
		elseif op.type == "upgrade" then
			if op.order then
				local gate, tag = costGate(op, op.costAction, op.price)
				table.insert(lines, string.format("\tRTD.AddUpgradeTower(%d, %s) -- #%d %s", op.order, gate, op.order, tag))
			else
				table.insert(lines, string.format("\t-- WARN: 升級未追蹤的塔 [uid:%s] +%ss", tostring(op.uid), timeGate(op.t)))
			end
		elseif op.type == "sell" then
			if op.order then
				table.insert(lines, string.format("\tRTD.AddSellTower(%d, %s) -- #%d +%ss", op.order, timeGate(op.t), op.order, timeGate(op.t)))
			else
				table.insert(lines, string.format("\t-- WARN: 賣出未追蹤的塔 [uid:%s] +%ss", tostring(op.uid), timeGate(op.t)))
			end
		elseif op.type == "start" then
			table.insert(lines, string.format("\tRTD.AddStart(%s) -- Start +%ss", timeGate(op.t), timeGate(op.t)))
		elseif op.type == "speed" then
			table.insert(lines, string.format("\tRTD.AddSetSpeed(%d, %s) -- %dx +%ss", op.speed, timeGate(op.t), op.speed, timeGate(op.t)))
		elseif op.type == "autoskip" then
			table.insert(lines, string.format("\tRTD.AddSetAutoSkip(%s, %s) -- +%ss", tostring(op.value), timeGate(op.t), timeGate(op.t)))
		elseif op.type == "skipwave" then
			table.insert(lines, string.format("\tRTD.AddSkipWave(%s, %s) -- +%ss", tostring(op.value), timeGate(op.t), timeGate(op.t)))
		end
	end
	-- 結束時間：單局結束時凍結；尚未結束則用目前經過時間
	table.insert(lines, "")
	table.insert(lines, string.format("\tRTD.AddEnd(%s)", timeGate(total)))
	table.insert(lines, "\tRTD.ExecuteQueue()")
	table.insert(lines, '\tprint("[RTD] Queue loaded wait start!!")')
	table.insert(lines, "end")

	-- 外層啟動器：載入 API → SaveLocalScript（供自動重播/重連時載入）→ 執行佇列
	local outer = {}
	table.insert(outer, "--[[")
	table.insert(outer, "  Script By: RTD Place Tracker script ")
	table.insert(outer, string.format('  URL: loadstring(game:HttpGet("%s"))()', RTD_TRACKER_URL))
	if meta then
		table.insert(outer, string.format("  Map: %s  |  Difficulty: %s", mapText(meta), meta.difficultyName))
	end
	table.insert(outer, "  Time: " .. timeText)
	if #usedTowers > 0 then
		table.insert(outer, "")
		table.insert(outer, "  Towers used:")
		for _, n in ipairs(usedTowers) do
			table.insert(outer, "    - " .. n)
		end
	end
	table.insert(outer, "]]")
	table.insert(outer, "")
	table.insert(outer, "local fullScript = [=[")
	table.insert(outer, table.concat(lines, "\n"))
	table.insert(outer, "]=" .. "]")
	table.insert(outer, "")
	for _, l in ipairs(loader) do
		table.insert(outer, l)
	end
	table.insert(outer, "")
	table.insert(outer, "RTD.SaveLocalScript(fullScript)")
	table.insert(outer, "loadstring(fullScript)()")
	return table.concat(outer, "\n")
end

----------------------------------------------------------------------
-- 按鈕行為
----------------------------------------------------------------------
copyBtn.MouseButton1Click:Connect(function()
	local script = generateScript()
	if not script then
		addLog(tr("log_no_ops"), Theme.Warning)
		return
	end
	if setclipboard then
		setclipboard(script)
		addLog(tr("log_copied"), Theme.Success)
	else
		print(script)
		addLog(tr("log_printed"), Theme.Warning)
	end
end)

-- 預設檔名（同花園版）：<地圖>_<難度>_<日期>_<時間>，例如 Crossroads_Casual_20261030_153012
local function defaultScriptName()
	local meta = refreshMapMeta()
	local mapPart = meta and meta.mapId or "Map"
	if meta and meta.isCampaign then
		mapPart = string.format("%s_C%sL%s", mapPart, tostring(meta.chapter or 1), tostring(meta.level or 1))
	end
	local name = string.format("%s_%s_%s", mapPart, meta and meta.difficulty or "Diff", os.date("%Y%m%d_%H%M%S"))
	return (name:gsub("[^%w_%-]", "_"))
end

saveBtn.MouseButton1Click:Connect(function()
	saveFrame.Visible = not saveFrame.Visible
	if saveFrame.Visible then
		fileNameInput.Text = defaultScriptName()
	end
end)

confirmSaveBtn.MouseButton1Click:Connect(function()
	local name = fileNameInput.Text:gsub("[^%w_%-\128-\255 ]", ""):gsub("^%s+", ""):gsub("%s+$", "")
	if name == "" then
		addLog(tr("log_bad_name"), Theme.Warning)
		return
	end
	local script = generateScript()
	if not script then
		addLog(tr("log_no_ops"), Theme.Warning)
		return
	end
	local ok, err = pcall(function()
		if makefolder then
			for _, p in ipairs({ "Tsetingnil_script", "Tsetingnil_script/RTD", SCRIPT_SAVE_PATH }) do
				if isfolder and not isfolder(p) then
					makefolder(p)
				end
			end
		end
		writefile(SCRIPT_SAVE_PATH .. "/" .. name .. ".lua", script)
	end)
	if ok then
		addLog(tr("log_saved", name .. ".lua"), Theme.Success)
		saveFrame.Visible = false
	else
		addLog(tr("log_save_failed", tostring(err)), Theme.Error)
	end
end)

resetRecording = function()
	startPressed = false
	startTime = nil
	endTime = nil
	roundEnded = false
	ops = {}
	nextOrder = 1
	orderInfo = {}
	usedTowers, usedTowerSet = {}, {}
	uidToOrder = {}
	pendingBind = {}
	CostTracker.Queue = {}
	clearLog()
end

resetBtn.MouseButton1Click:Connect(function()
	resetRecording()
	addLog(tr("log_reset"), Theme.Warning)
end)

----------------------------------------------------------------------
-- 單局結束檢測 (RoundInfo.Running + RoundResult.Show)；開始 = ReadyVote
----------------------------------------------------------------------
local RoundInfo = ReplicatedStorage:FindFirstChild("RoundInfo")

local function formatDuration(sec)
	return string.format("%dm %ds (%.1fs)", math.floor(sec / 60), math.floor(sec % 60), sec)
end

onGameStart = function()
	beginSession()
	if startPressed then
		return
	end
	startPressed = true
	local t = elapsed()
	pushOp({ type = "start", t = t })
	addLog(string.format("Game Started  +%.1fs", t), Theme.Accent)
	pcall(refreshMapMeta)
end

local function onRoundEnd(result)
	if roundEnded or not startTime then
		return
	end
	pcall(refreshMapMeta)
	endTime = tick()
	roundEnded = true
	local total = elapsed()
	local outcome = ""
	if type(result) == "table" and result.IsVictory ~= nil then
		outcome = result.IsVictory and tr("victory") or tr("defeat")
		if result.WavesSurvived then
			outcome ..= tr("waves", tostring(result.WavesSurvived))
		end
		outcome = "  " .. outcome
	end
	addLog(tr("log_game_over", formatDuration(total), outcome, #ops), Theme.Success)
end

if RoundInfo then
	-- 只用來偵測結束（Running 變 false）；開始仍以「準備完畢」投票為準
	local conn = RoundInfo:GetAttributeChangedSignal("Running"):Connect(function()
		if RoundInfo:GetAttribute("Running") ~= true then
			onRoundEnd(nil)
		end
	end)
	table.insert(cleanups, function()
		conn:Disconnect()
	end)
else
	warn(tr("roundinfo_missing"))
end

do
	local okListen, disconnect = pcall(function()
		return ByteNetworking.RoundResult.Show.listen(function(result)
			onRoundEnd(result)
		end)
	end)
	if okListen and type(disconnect) == "function" then
		table.insert(cleanups, disconnect)
	else
		warn(tr("roundresult_failed"))
	end
end

----------------------------------------------------------------------
-- 清理
----------------------------------------------------------------------
globalEnv.__RTDTrackerCleanup = function()
	for _, fn in ipairs(cleanups) do
		pcall(fn)
	end
	cleanups = {}
	globalEnv.__RTDTrackerCleanup = nil
end
addLog(tr("log_howto"), Theme.TextDim)
addLog(tr("log_howto2"), Theme.TextDim)

-- 地圖 / 難度：載入完成就偵測，直到有資訊才輸出（RoundInfo 屬性可能稍晚才設好；卸載時結束）
task.spawn(function()
	local meta
	repeat
		meta = refreshMapMeta()
		if not meta then
			task.wait(0.5)
		end
	until meta or not pumpRunning
	if meta then
		addLog(tr("log_map", mapText(meta), meta.difficultyName), Theme.Success)
	end
end)
