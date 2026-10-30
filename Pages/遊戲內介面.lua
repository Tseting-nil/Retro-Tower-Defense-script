-- ============================================================
--                 復古塔防 | 遊戲內介面 (In-Game UI)
-- ============================================================
-- 設計同花園塔房遊戲內介面（ReGui TabsWindow）：
--   Main      狀態 / 控制按鈕 / 自動重新開局 / 腳本輪換池
--   玩家資訊   玩家資料 + 累計統計
--   本地腳本   Script 資料夾列表（資訊 / 執行 / 刪除）、儲存正在運行的腳本
--   設置       密鑰剩餘時間
-- 資料全部讀 RTD API（getgenv().RTD），與花園版不同處：沒有 Event 分頁，
-- 輸贏 / 獎勵走 RTD.OnRoundEnd，統計的「賺取」是結算獎勵裡的 Money（TIX）。
-- ============================================================

-- 側邊通知模組
if not getgenv().NotificationModule then
	pcall(function()
		assert(loadstring(game:HttpGet("https://gist.githubusercontent.com/Tseting-nil/08653e6aa9fc12a9f097bfb10e6654e7/raw/00001d614d928fc5dafce59133a012dd78419afd/%25E5%2581%25B4%25E9%2582%258A%25E9%2580%259A%25E7%259F%25A5%25E6%25A8%25A1%25E7%25B5%2584.lua")))()
	end)
end

-- 生成當前腳本執行的唯一實例 ID，用於清理舊線程，防重複運行
local myInstanceId = tostring(tick()) .. "_" .. tostring(math.random(1000, 9999))
getgenv().RTD_UI_InstanceId = myInstanceId

-- 局部掛機狀態控制（每個 UI 獨立，每次加載皆從 0 開始）
local matchCount = 0
local alrEnabled = true

local RTD_DIR = "Tsetingnil_script/RTD"
local RTD_API_URL = "https://raw.githubusercontent.com/Tseting-nil/Retro-Tower-Defense-script/refs/heads/main/%E5%AF%86%E9%91%B0%E7%B3%BB%E7%B5%B1.lua"
local RTD_TRACKER_URL = "https://raw.githubusercontent.com/Tseting-nil/Retro-Tower-Defense-script/refs/heads/main/Tool/%E6%94%BE%E7%BD%AE%E8%BF%BD%E8%B9%A4%E5%99%A8.lua"

-- i18n
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LocalPlayer = Players.LocalPlayer

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
		windowTitle = "遊戲內介面",
		tab_main = "Main",
		tab_playinfo = "玩家資訊",
		tab_localscript = "本地腳本",
		tab_settings = "設置",
		sectionStatus = "當前狀態",
		envChecking = "環境檢查中...",
		gameState = "遊戲當前狀態",
		autoReplay = "重開",
		sectionControl = "控制按鈕",
		btnToggleAutoReplay = "控制自動重開",
		btnManualReplay = "手動重開",
		btnLobby = "回大廳",
		noEnv = "無環境",
		stateLobby = "當前遊戲狀態：在大廳",
		stateCombat = "當前遊戲狀態：戰鬥中",
		stateGameOver = "當前遊戲狀態：結束",
		stateUnknown = "當前遊戲狀態：未知",
		envExist = "環境檢查：本地環境存在",
		envNotExist = "環境檢查：本地環境不存在",
		autoReplayOn = "自動重新戰鬥：已開啟",
		autoReplayOff = "自動重新戰鬥：未開啟",
		queueRemaining = "佇列剩餘：",
		queueNA = "---",
		queueOvertime = "（超時）",
		replayConfirm_title = "確認手動重開?",
		lobbyConfirm_title = "確認回到大廳?",
		alreadyRunning = "自動化佇列已在運行中",
		replay_no_main = "找不到正在運行的腳本（main 檔不存在）",
		replay_started = "已重新執行腳本",
		replay_timeout = "重開超時，直接嘗試在當前局執行腳本",
		-- 玩家資訊
		playTixInit = "TIX：---",
		playLevelInit = "等級：---",
		playCashInit = "局內金錢：---",
		playRevivesInit = "復活券：---",
		playTixFmt = "TIX：%s",
		playLevelFmt = "等級：%s（XP %s）",
		playCashFmt = "局內金錢：%s",
		playRevivesFmt = "復活券：%s",
		-- 統計
		stats_section = "累計統計",
		stats_wins = "勝：",
		stats_losses = "輸：",
		stats_total = "總場：",
		stats_winrate = "勝率：",
		stats_money = "賺取 TIX：",
		stats_lastReset = "上次重置：",
		stats_reset = "重置統計",
		stats_reset_confirm = "確認重置統計？",
		stats_never_reset = "從未重置",
		stats_round_done = "[RTD統計] 🏁 戰鬥結束！勝負: %s，賺取 TIX: +%d",
		stats_round_unknown = "[RTD統計] 🏁 戰鬥結束（結果未知，不計入勝負）",
		stats_win = "勝利",
		stats_loss = "失敗",
		stats_match_count = "[RTD統計] 📊 當前掛機累計場數: %d / %d",
		stats_rotation_trigger = "[RTD統計] 🚨 累計達到 %d 場，自動返回大廳以釋放記憶體！",
		-- 自動重開 / 輪換
		autoLobbyReplay_title = "自動重新開局設定",
		autoLobbyReplay_label = "自動重開場數：%d / %d",
		autoLobbyReplay_btn_reset = "手動重置場數",
		autoLobbyReplay_reset_msg = "場數已手動重設為 0",
		autoLobbyReplay_toggle = "自動重開",
		rotation_pool_header = "輪換腳本池（可多選，每 N 場換一支）",
		rotation_interval_label = "每幾場輪換",
		rotation_refresh_btn = "重新整理清單",
		rotation_save_btn = "儲存輪換設定",
		rotation_no_scripts = "Script 資料夾內沒有可用腳本",
		rotation_saved_msg = "輪換設定已儲存：%d 支腳本，每 %d 場輪換",
		rotation_empty_pool = "未選任何輪換腳本，將以同一支腳本重開",
		rotation_picked_msg = "本輪換到腳本：%s",
		rotation_apply_fail = "套用輪換腳本失敗，沿用目前腳本",
		-- 本地腳本
		localscript_path = "路徑: ",
		localscript_list = "腳本列表",
		localscript_refresh = "重新整理",
		localscript_run = "執行",
		localscript_no_scripts = "目錄中無腳本",
		localscript_done = "執行完成",
		localscript_error = "執行錯誤",
		localscript_refreshed = "清單已重新整理",
		localscript_delete = "刪除",
		localscript_confirm_title = "確認刪除?",
		localscript_confirm_title2 = "⚠ 此操作無法復原",
		localscript_confirm_yes = "確認",
		localscript_confirm_no = "取消",
		localscript_delete_final = "永久刪除",
		localscript_deleted = "已刪除",
		localscript_delete_error = "刪除失敗",
		localscript_info = "i",
		localscript_info_no_block = "（無資訊區塊）",
		localscript_info_read_fail = "讀取失敗",
		localscript_info_close = "關閉",
		localscript_info_copy = "複製",
		localscript_info_copied = "已複製到剪貼簿",
		localscript_save_running = "儲存正在運行的腳本",
		localscript_save = "儲存",
		localscript_save_name_title = "輸入儲存名稱",
		localscript_save_name_ph = "腳本名稱...",
		localscript_save_success = "已儲存",
		localscript_save_error = "儲存失敗",
		localscript_save_no_running = "無正在運行的腳本",
		-- 設置
		keyTimeLabel = "密鑰剩餘時間：",
		keyTimePerm = "永久",
		keyExpired = "已過期",
		unitDay = "天",
		unitHour = "時",
		unitMin = "分",
	},
	en = {
		windowTitle = "In-Game UI",
		tab_main = "Main",
		tab_playinfo = "Player Info",
		tab_localscript = "Local Script",
		tab_settings = "Settings",
		sectionStatus = "Current Status",
		envChecking = "Checking environment...",
		gameState = "Game State",
		autoReplay = "Auto Replay",
		sectionControl = "Control Buttons",
		btnToggleAutoReplay = "Toggle Auto Replay",
		btnManualReplay = "Replay",
		btnLobby = "To Lobby",
		noEnv = "No Environment",
		stateLobby = "Game State: In Lobby",
		stateCombat = "Game State: In Combat",
		stateGameOver = "Game State: Game Over",
		stateUnknown = "Game State: Unknown",
		envExist = "Environment: Local env exists",
		envNotExist = "Environment: Local env missing",
		autoReplayOn = "Auto Replay: Enabled",
		autoReplayOff = "Auto Replay: Disabled",
		queueRemaining = "Queue Remaining: ",
		queueNA = "---",
		queueOvertime = " (overtime)",
		replayConfirm_title = "Confirm Replay?",
		lobbyConfirm_title = "Confirm back to Lobby?",
		alreadyRunning = "Automation queue is already running",
		replay_no_main = "No running script found (main file missing)",
		replay_started = "Script re-executed",
		replay_timeout = "Restart timed out, trying to run the script in the current round",
		playTixInit = "TIX: ---",
		playLevelInit = "Level: ---",
		playCashInit = "In-game Cash: ---",
		playRevivesInit = "Revives: ---",
		playTixFmt = "TIX: %s",
		playLevelFmt = "Level: %s (XP %s)",
		playCashFmt = "In-game Cash: %s",
		playRevivesFmt = "Revives: %s",
		stats_section = "Cumulative Stats",
		stats_wins = "Wins: ",
		stats_losses = "Losses: ",
		stats_total = "Total: ",
		stats_winrate = "Win Rate: ",
		stats_money = "TIX Earned: ",
		stats_lastReset = "Last Reset: ",
		stats_reset = "Reset Stats",
		stats_reset_confirm = "Confirm Reset?",
		stats_never_reset = "Never reset",
		stats_round_done = "[RTD Stats] 🏁 Round over! Result: %s, TIX earned: +%d",
		stats_round_unknown = "[RTD Stats] 🏁 Round over (result unknown, not counted)",
		stats_win = "Victory",
		stats_loss = "Defeat",
		stats_match_count = "[RTD Stats] 📊 Matches since start: %d / %d",
		stats_rotation_trigger = "[RTD Stats] 🚨 Reached %d matches, returning to lobby to free memory!",
		autoLobbyReplay_title = "Auto Lobby Replay Config",
		autoLobbyReplay_label = "Auto Lobby Replay: %d / %d",
		autoLobbyReplay_btn_reset = "Reset Match Count",
		autoLobbyReplay_reset_msg = "Match count has been reset to 0",
		autoLobbyReplay_toggle = "Auto Lobby Replay",
		rotation_pool_header = "Script Rotation Pool (multi-select, swap every N games)",
		rotation_interval_label = "Games per rotation",
		rotation_refresh_btn = "Refresh List",
		rotation_save_btn = "Save Rotation Config",
		rotation_no_scripts = "No scripts available in the Script folder",
		rotation_saved_msg = "Rotation saved: %d scripts, swap every %d games",
		rotation_empty_pool = "No rotation scripts selected; restarting with the same script",
		rotation_picked_msg = "Rotated to script: %s",
		rotation_apply_fail = "Failed to apply rotation script; keeping current script",
		localscript_path = "Path: ",
		localscript_list = "Script List",
		localscript_refresh = "Refresh",
		localscript_run = "Run",
		localscript_no_scripts = "No scripts in directory",
		localscript_done = "Executed",
		localscript_error = "Error",
		localscript_refreshed = "List refreshed",
		localscript_delete = "Delete",
		localscript_confirm_title = "Confirm Delete?",
		localscript_confirm_title2 = "⚠ This cannot be undone",
		localscript_confirm_yes = "Confirm",
		localscript_confirm_no = "Cancel",
		localscript_delete_final = "Delete Forever",
		localscript_deleted = "Deleted",
		localscript_delete_error = "Delete failed",
		localscript_info = "i",
		localscript_info_no_block = "(No info block)",
		localscript_info_read_fail = "Read failed",
		localscript_info_close = "Close",
		localscript_info_copy = "Copy",
		localscript_info_copied = "Copied to clipboard",
		localscript_save_running = "Save Running Script",
		localscript_save = "Save",
		localscript_save_name_title = "Enter Save Name",
		localscript_save_name_ph = "Script name...",
		localscript_save_success = "Saved",
		localscript_save_error = "Save failed",
		localscript_save_no_running = "No running script",
		keyTimeLabel = "Key time left: ",
		keyTimePerm = "Permanent",
		keyExpired = "Expired",
		unitDay = "d",
		unitHour = "h",
		unitMin = "m",
	},
}

local L = i18n[currentLang] or i18n.zh
local fontSize = currentLang == "en" and 14 or nil
local LABEL_COLOR = Color3.fromRGB(240, 240, 240)

local Msg = getgenv().NotificationModule
local function notify(kind, text)
	if Msg and Msg[kind] then
		pcall(function()
			Msg[kind](Msg, text)
		end)
	end
end

local function getRTD()
	local api = getgenv().RTD
	if api and api.ExecuteQueue then
		return api
	end
	return nil
end

-- ========================================================================== --
-- GUI

local ReGui = assert(loadstring(game:HttpGet("https://gist.githubusercontent.com/Tseting-nil/169b7303e1418cb301bad5ab427e9351/raw/93e90190f628387b545eef62b49e4ce146d1dad8/GUI:ReGui")))()

local UserInputService = game:GetService("UserInputService")
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local TabsWindow = ReGui:TabsWindow({
	Title = L.windowTitle,
	Size = UDim2.new(0, 325, 0, 280),
	NoScroll = true,
})

local Tabs = {}
for _, Name in ipairs({ L.tab_main, L.tab_playinfo, L.tab_localscript, L.tab_settings }) do
	table.insert(Tabs, TabsWindow:CreateTab({ Name = Name }))
end

-- 修改 Tab 字體和大小
task.spawn(function()
	task.wait(0.1)
	for _, tab in ipairs(Tabs) do
		local label = tab.TabButton.Button:FindFirstChildWhichIsA("TextLabel")
		if label then
			label.TextSize = currentLang == "en" and 14 or 18
			label.Font = Enum.Font.Ubuntu
		end
	end
end)

local function newCanvas(tab)
	return tab:ScrollingCanvas({ Fill = true, UiPadding = UDim.new(0, 0) })
end

local Tab_main = newCanvas(Tabs[1])
local Tab_playinfo = newCanvas(Tabs[2])
local Tab_Localscript = newCanvas(Tabs[3])
local Tab_settings = newCanvas(Tabs[4])

local function addLabel(parent, text, size, color)
	return parent:Label({
		Text = text,
		TextSize = fontSize or size or 16,
		NoTheme = true,
		TextColor3 = color or LABEL_COLOR,
	})
end

-- ===== 設置分頁：密鑰剩餘時間 =====
local SETTINGS_API_VAR = "Tsetingnil_script/keysystem.json"

local function readApiVarTable()
	local ok, data = pcall(function()
		if isfile and readfile and isfile(SETTINGS_API_VAR) then
			return HttpService:JSONDecode(readfile(SETTINGS_API_VAR))
		end
		return nil
	end)
	return (ok and type(data) == "table") and data or {}
end

local function fmtKeyRemaining()
	local exp = tonumber(readApiVarTable().expires_at)
	if not exp then
		return L.keyTimeLabel .. L.keyTimePerm
	end
	if exp > 1e10 then
		exp = math.floor(exp / 1000) -- 毫秒→秒
	end
	local left = exp - os.time()
	if left <= 0 then
		return L.keyTimeLabel .. L.keyExpired
	end
	local d = math.floor(left / 86400)
	local h = math.floor((left % 86400) / 3600)
	local m = math.floor((left % 3600) / 60)
	return string.format("%s%d%s %d%s %d%s", L.keyTimeLabel, d, L.unitDay, h, L.unitHour, m, L.unitMin)
end

Tab_settings:Separator({ Text = L.tab_settings })
local KeyTime_Label = addLabel(Tab_settings, fmtKeyRemaining(), 16)

-- ===== Main：當前狀態 =====
Tab_main:Separator({ Text = L.sectionStatus })
local API_Check_Label = addLabel(Tab_main, L.envChecking, 18)
local GameState_Label = addLabel(Tab_main, L.gameState, 16)
local AutoReplay_Label = addLabel(Tab_main, L.autoReplay, 16)
local QueueRemaining_Label = addLabel(Tab_main, L.queueRemaining .. L.queueNA, 16)

-- ===== 執行腳本（重新跑 main 檔）=====
local function mainPath()
	return RTD_DIR .. "/main_" .. tostring(LocalPlayer.UserId) .. ".lua"
end

local function runMainScript()
	local path = mainPath()
	if not (isfile and isfile(path) and loadfile) then
		notify("Warning", L.replay_no_main)
		return false
	end
	local fn, err = loadfile(path)
	if not fn then
		notify("Warning", L.localscript_error .. ": " .. tostring(err))
		return false
	end
	task.spawn(fn)
	return true
end

local function roundInfoAttr(name)
	local info = ReplicatedStorage:FindFirstChild("RoundInfo")
	return info and info:GetAttribute(name)
end

-- ===== Main：控制按鈕 =====
Tab_main:Separator({ Text = L.sectionControl })
local ROW_QK = Tab_main:Row()

ROW_QK:Button({
	Text = L.btnToggleAutoReplay,
	TextSize = fontSize or 18,
	Callback = function()
		local RTD = getRTD()
		if RTD then
			RTD.AutoReplay(not RTD.GetAutoReplay())
		else
			notify("Warning", L.noEnv)
		end
	end,
	DoubleClick = false,
})

ROW_QK:Button({
	Text = L.btnManualReplay,
	TextSize = fontSize or 18,
	Callback = function(btn)
		local RTD = getRTD()
		if not RTD then
			notify("Warning", L.noEnv)
			return
		end
		if RTD.IsQueueRunning() and not RTD.IsRoundOver() then
			notify("Warning", L.alreadyRunning)
			return
		end
		local Popup = Tab_main:PopupModal({ RelativeTo = btn })
		Popup:Separator({ Text = L.replayConfirm_title })
		local PopupRow = Popup:Row({ Expanded = true })
		PopupRow:Button({
			Text = L.localscript_confirm_yes,
			Callback = function()
				Popup:ClosePopup()
				task.spawn(function()
					-- 單局已結束：先投「再玩一場」，等回到開局前階段再重跑腳本
					if RTD.IsRoundOver() then
						local ByteNetworking = require(ReplicatedStorage.Teawork.Shared.Services.ByteNetworking)
						local deadline = os.clock() + 30
						local lastVote = 0
						while os.clock() < deadline and roundInfoAttr("ReadyVoteActive") ~= true do
							if os.clock() - lastVote >= 2 then
								lastVote = os.clock()
								pcall(ByteNetworking.RoundResult.VoteForRestart.send, true)
							end
							task.wait(0.3)
						end
						if roundInfoAttr("ReadyVoteActive") ~= true then
							notify("Warning", L.replay_timeout)
						end
						task.wait(1)
					end
					if runMainScript() then
						notify("Success", L.replay_started)
					end
				end)
			end,
		})
		PopupRow:Button({
			Text = L.localscript_confirm_no,
			Callback = function()
				Popup:ClosePopup()
			end,
		})
	end,
	DoubleClick = false,
})

ROW_QK:Button({
	Text = L.btnLobby,
	TextSize = fontSize or 18,
	Callback = function(btn)
		local RTD = getRTD()
		if not RTD then
			notify("Warning", L.noEnv)
			return
		end
		local Popup = Tab_main:PopupModal({ RelativeTo = btn })
		Popup:Separator({ Text = L.lobbyConfirm_title })
		local PopupRow = Popup:Row({ Expanded = true })
		PopupRow:Button({
			Text = L.localscript_confirm_yes,
			Callback = function()
				Popup:ClosePopup()
				task.spawn(RTD.ReturnToLobby)
			end,
		})
		PopupRow:Button({
			Text = L.localscript_confirm_no,
			Callback = function()
				Popup:ClosePopup()
			end,
		})
	end,
	DoubleClick = false,
})

-- ===== 腳本輪換（每 N 場換一支錄製腳本，打散防巨集「每局同指紋」特徵）=====
-- 池 = 使用者勾選的腳本（Script 資料夾內檔名，可多選）。達到 interval 場時：隨機挑一支（排除上次）→
-- 覆寫進 main_<UserId>.lua（queue_on_teleport 的 resume 會 loadfile 它）→ 存 lastPicked → 回大廳自動執行。
-- 設定持久化於 Rotation_Config.json，跨傳送有效（getgenv 不過傳送，故用檔案）。
local Rotation = {
	configPath = RTD_DIR .. "/Config/Rotation_Config.json",
	scriptDir = RTD_DIR .. "/Script",
	pool = {},
	interval = 20,
	lastPicked = nil,
}

function Rotation.ensureFolder()
	pcall(function()
		if not isfolder or not makefolder then
			return
		end
		for _, dir in ipairs({ "Tsetingnil_script", RTD_DIR, RTD_DIR .. "/Config" }) do
			if not isfolder(dir) then
				makefolder(dir)
			end
		end
	end)
end

-- 以玩家 UserId 當外層 key：同帳號在大廳/關卡內共用同一份，多帳號各自獨立
local function userKey()
	return tostring(LocalPlayer.UserId)
end

function Rotation.load()
	local ok, data = pcall(function()
		if not (isfile and isfile(Rotation.configPath) and readfile) then
			return nil
		end
		return HttpService:JSONDecode(readfile(Rotation.configPath))
	end)
	if ok and type(data) == "table" then
		local entry = data[userKey()]
		if type(entry) == "table" then
			Rotation.pool = type(entry.pool) == "table" and entry.pool or {}
			Rotation.interval = tonumber(entry.interval) or 30
			Rotation.lastPicked = entry.lastPicked
		end
	end
	if Rotation.interval < 1 then
		Rotation.interval = 1
	end
end

function Rotation.save()
	pcall(function()
		if not writefile then
			return
		end
		Rotation.ensureFolder()
		local all = {}
		local ok, existing = pcall(function()
			if isfile and isfile(Rotation.configPath) and readfile then
				return HttpService:JSONDecode(readfile(Rotation.configPath))
			end
			return nil
		end)
		if ok and type(existing) == "table" then
			all = existing
		end
		all[userKey()] = {
			pool = Rotation.pool,
			interval = Rotation.interval,
			lastPicked = Rotation.lastPicked,
		}
		writefile(Rotation.configPath, HttpService:JSONEncode(all))
	end)
end

local function isScriptFile(name)
	return name:match("%.lua$") or name:match("%.txt$") or name:match("%.text$")
end

-- 列出 Script 資料夾內可選腳本，回傳排序後的檔名陣列
function Rotation.listScripts()
	local names = {}
	local ok, files = pcall(listfiles, Rotation.scriptDir)
	if ok and files then
		for _, fp in ipairs(files) do
			local name = fp:match("([^/\\]+)$") or fp
			if isScriptFile(name) then
				names[#names + 1] = name
			end
		end
	end
	table.sort(names)
	return names
end

-- 清掉輪換池中「Script 資料夾已不存在」的檔名（列表取不到時不動池，避免誤清）
function Rotation.prune()
	local names = Rotation.listScripts()
	if #names == 0 then
		return
	end
	local exists = {}
	for _, n in ipairs(names) do
		exists[n] = true
	end
	local kept = {}
	for _, n in ipairs(Rotation.pool) do
		if exists[n] then
			kept[#kept + 1] = n
		end
	end
	Rotation.pool = kept
	if Rotation.lastPicked and not exists[Rotation.lastPicked] then
		Rotation.lastPicked = nil
	end
end

function Rotation.inPool(name)
	for _, n in ipairs(Rotation.pool) do
		if n == name then
			return true
		end
	end
	return false
end

function Rotation.setInPool(name, on)
	if on then
		if not Rotation.inPool(name) then
			Rotation.pool[#Rotation.pool + 1] = name
		end
	else
		for i = #Rotation.pool, 1, -1 do
			if Rotation.pool[i] == name then
				table.remove(Rotation.pool, i)
			end
		end
	end
end

-- 從池中隨機挑下一支（排除上次挑中的；池 <= 1 不排除）。回傳檔名或 nil（池為空）
function Rotation.pickNext()
	Rotation.prune()
	local pool = Rotation.pool
	if #pool == 0 then
		return nil
	end
	if #pool == 1 then
		return pool[1]
	end
	local candidates = {}
	for _, n in ipairs(pool) do
		if n ~= Rotation.lastPicked then
			candidates[#candidates + 1] = n
		end
	end
	if #candidates == 0 then
		candidates = pool
	end
	math.randomseed(os.time() + math.floor((os.clock() % 1) * 1e6))
	return candidates[math.random(1, #candidates)]
end

-- 把選中的腳本內容覆寫進 main_<UserId>.lua（resume 的 loadfile 目標）。回傳 true/false
function Rotation.applyToMain(name)
	local applied = false
	pcall(function()
		local srcPath = Rotation.scriptDir .. "/" .. name
		if not (isfile and isfile(srcPath) and readfile) then
			return
		end
		local content = readfile(srcPath)
		if not content or content == "" then
			return
		end
		writefile(mainPath(), content)
		applied = true
	end)
	return applied
end

Rotation.load()
Rotation.prune()

-- === 自動重新開局 (防記憶體崩潰) GUI 元件 ===
Tab_main:Separator({ Text = L.autoLobbyReplay_title })

local AutoLobbyReplay_CountLabel = addLabel(Tab_main, string.format(L.autoLobbyReplay_label, 0, Rotation.interval), 16)

local AutoLobbyReplay_ROW = Tab_main:Row()
AutoLobbyReplay_ROW:Radiobox({
	Value = alrEnabled,
	Label = L.autoLobbyReplay_toggle,
	Callback = function(_, Value)
		alrEnabled = Value
	end,
})

AutoLobbyReplay_ROW:SmallButton({
	Text = L.autoLobbyReplay_btn_reset,
	TextSize = fontSize or 16,
	Callback = function()
		matchCount = 0
		notify("Success", L.autoLobbyReplay_reset_msg)
	end,
	DoubleClick = false,
})

-- === 腳本輪換池 UI（可折疊面板 = 多選下拉；每支錄製一個勾選框）===
do
	local rotHeader = Tab_main:CollapsingHeader({ Title = L.rotation_pool_header, Collapsed = true })

	rotHeader:InputInt({
		Value = Rotation.interval,
		Label = L.rotation_interval_label,
		Increment = 1,
		Minimum = 1,
		Maximum = 999,
		Callback = function(_, v)
			Rotation.interval = math.max(1, math.floor(tonumber(v) or 30))
		end,
	})

	local rotTable = rotHeader:Table()
	local function buildRotList()
		rotTable:ClearRows()
		local names = Rotation.listScripts()
		if #names == 0 then
			rotTable:NextRow():Column():Label({ Text = L.rotation_no_scripts })
			return
		end
		for _, name in ipairs(names) do
			rotTable:NextRow():Column():Checkbox({
				Value = Rotation.inPool(name),
				Label = name,
				Callback = function(_, on)
					Rotation.setInPool(name, on)
				end,
			})
		end
	end
	buildRotList()

	local rotBtnRow = rotHeader:Row()
	rotBtnRow:Button({
		Text = L.rotation_refresh_btn,
		Callback = function()
			buildRotList()
		end,
	})
	rotBtnRow:Button({
		Text = L.rotation_save_btn,
		Callback = function()
			Rotation.prune()
			Rotation.save()
			notify("Success", string.format(L.rotation_saved_msg, #Rotation.pool, Rotation.interval))
		end,
	})
end

-- ===== 狀態標籤更新 =====
local function GetGameState()
	local RTD = getRTD()
	if not RTD then
		return "Unknown"
	end
	if RTD.IsLobby() then
		return "Lobby"
	end
	if RTD.IsRoundOver() then
		return "GameOver"
	end
	if RTD.IsInGame() then
		return "Combat"
	end
	return "Unknown"
end

local function ReGameStateLabel()
	local state = GetGameState()
	if state == "Lobby" then
		GameState_Label.Text = L.stateLobby
	elseif state == "Combat" then
		GameState_Label.Text = L.stateCombat
	elseif state == "GameOver" then
		GameState_Label.Text = L.stateGameOver
	else
		GameState_Label.Text = L.stateUnknown
	end
end

local function UpdateQueueLabels()
	local RTD = getRTD()
	local remaining = RTD and RTD.GetQueueRemaining()
	if remaining then
		if remaining < 0 then
			QueueRemaining_Label.Text = L.queueRemaining .. string.format("%d s", -remaining) .. L.queueOvertime
		else
			QueueRemaining_Label.Text = L.queueRemaining .. string.format("%d s", remaining)
		end
	else
		QueueRemaining_Label.Text = L.queueRemaining .. L.queueNA
	end
end

-- ========================================================================== --
-- Tab_playinfo
local function formatWithCommas(n)
	if not n then
		return "---"
	end
	local s = tostring(math.floor(tonumber(n) or 0))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local play_tix = addLabel(Tab_playinfo, L.playTixInit, 16)
local play_level = addLabel(Tab_playinfo, L.playLevelInit, 16)
local play_cash = addLabel(Tab_playinfo, L.playCashInit, 16)
local play_revives = addLabel(Tab_playinfo, L.playRevivesInit, 16)

-- 玩家資料來自遊戲 DataSync：Money（TIX）、Level = { Level, XP }、OwnedItems.Revive
local DataSync = nil
pcall(function()
	DataSync = require(ReplicatedStorage.Teawork.Client.Services.DataSync)
end)

local function readKey(key)
	if not DataSync then
		return nil
	end
	local ok, value = pcall(function()
		return DataSync:GetKey(key)
	end)
	return ok and value or nil
end

local function updatePlayInfo()
	local tix = readKey("Money")
	play_tix.Text = string.format(L.playTixFmt, type(tix) == "number" and formatWithCommas(tix) or "---")

	local level = readKey("Level")
	if type(level) == "table" then
		play_level.Text = string.format(L.playLevelFmt, tostring(level.Level or "?"), formatWithCommas(level.XP))
	else
		play_level.Text = L.playLevelInit
	end

	local RTD = getRTD()
	local cash = RTD and RTD.GetMoney()
	play_cash.Text = string.format(L.playCashFmt, cash and formatWithCommas(cash) or "---")

	local items = readKey("OwnedItems")
	local revives = type(items) == "table" and (items.Revive or 0) or nil
	play_revives.Text = string.format(L.playRevivesFmt, revives and formatWithCommas(revives) or "---")
end

-- ========================================================================== --
-- 統計（合併至 Tab_playinfo 底下）
local STATS_DATA_PATH = RTD_DIR .. "/Config/Ingame_Data_Config.json"
local Stats_playerId = userKey()

local function statsReadAll()
	local ok, data = pcall(function()
		if not (isfile and isfile(STATS_DATA_PATH) and readfile) then
			return {}
		end
		return HttpService:JSONDecode(readfile(STATS_DATA_PATH))
	end)
	return (ok and type(data) == "table") and data or {}
end

local function statsWriteAll(allData)
	pcall(function()
		if not writefile then
			return
		end
		Rotation.ensureFolder()
		writefile(STATS_DATA_PATH, HttpService:JSONEncode(allData))
	end)
end

local function newStats()
	return { lastReset = os.time(), wins = 0, losses = 0, money = 0 }
end

local function statsGetOrInit(allData)
	if not allData[Stats_playerId] then
		allData[Stats_playerId] = newStats()
		statsWriteAll(allData)
	end
	return allData[Stats_playerId]
end

local function statsSave(isWin, earned)
	local allData = statsReadAll()
	local pd = statsGetOrInit(allData)
	if isWin then
		pd.wins = pd.wins + 1
	else
		pd.losses = pd.losses + 1
	end
	pd.money = pd.money + earned
	allData[Stats_playerId] = pd
	statsWriteAll(allData)
	return pd
end

local function statsReset()
	local allData = statsReadAll()
	allData[Stats_playerId] = newStats()
	statsWriteAll(allData)
	return allData[Stats_playerId]
end

local function statsFmtWinRate(wins, losses)
	local total = wins + losses
	if total == 0 then
		return "0.0%"
	end
	return string.format("%.1f%%", wins / total * 100)
end

local function statsFmtTime(ts)
	if not ts or ts == 0 then
		return L.stats_never_reset
	end
	return os.date("%Y-%m-%d %H:%M:%S", ts)
end

local _statsPd = statsGetOrInit(statsReadAll())

Tab_playinfo:Separator({ Text = L.stats_section })
local statsLabel_wins = addLabel(Tab_playinfo, L.stats_wins .. _statsPd.wins, 16)
local statsLabel_losses = addLabel(Tab_playinfo, L.stats_losses .. _statsPd.losses, 16)
local statsLabel_total = addLabel(Tab_playinfo, L.stats_total .. (_statsPd.wins + _statsPd.losses), 16)
local statsLabel_winrate = addLabel(Tab_playinfo, L.stats_winrate .. statsFmtWinRate(_statsPd.wins, _statsPd.losses), 16)
local statsLabel_money = addLabel(Tab_playinfo, L.stats_money .. formatWithCommas(_statsPd.money), 16)
local statsLabel_lastReset = addLabel(Tab_playinfo, L.stats_lastReset .. statsFmtTime(_statsPd.lastReset), 14, Color3.fromRGB(180, 180, 180))

local function refreshStatsUI(pd)
	statsLabel_wins.Text = L.stats_wins .. pd.wins
	statsLabel_losses.Text = L.stats_losses .. pd.losses
	statsLabel_total.Text = L.stats_total .. (pd.wins + pd.losses)
	statsLabel_winrate.Text = L.stats_winrate .. statsFmtWinRate(pd.wins, pd.losses)
	statsLabel_money.Text = L.stats_money .. formatWithCommas(pd.money)
	statsLabel_lastReset.Text = L.stats_lastReset .. statsFmtTime(pd.lastReset)
end

Tab_playinfo:Button({
	Text = L.stats_reset,
	TextSize = fontSize or 16,
	Callback = function(btn)
		local Popup = Tab_playinfo:PopupModal({ RelativeTo = btn })
		Popup:Separator({ Text = L.stats_reset_confirm })
		local PopupRow = Popup:Row({ Expanded = true })
		PopupRow:Button({
			Text = L.localscript_confirm_yes,
			Callback = function()
				Popup:ClosePopup()
				refreshStatsUI(statsReset())
			end,
		})
		PopupRow:Button({
			Text = L.localscript_confirm_no,
			Callback = function()
				Popup:ClosePopup()
			end,
		})
	end,
})

-- ========================================================================== --
-- Tab_Localscript
local Localscript = {
	path = RTD_DIR .. "/Script",
	ScriptListTable = nil,
}

local function trim(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

-- 解析腳本開頭的資訊區塊（Map / Difficulty / Time / Towers used），回傳顯示用的富文字
local function buildInfoText(raw)
	local map, diff, timeStr
	local towers = {}
	local inTowers = false
	local towersDone = false
	for line in (raw .. "\n"):gmatch("([^\n]*)\n") do
		line = line:gsub("\r", "")
		local m, d = line:match("^%s*Map:%s*(.-)%s*|%s*Difficulty:%s*(.-)%s*$")
		if m and not map then
			map, diff = trim(m), trim(d)
		elseif line:find("^%s*Time:") and not timeStr then
			timeStr = line:match("Time:%s*(.-)%s*%(") or line:match("Time:%s*(.-)%s*$")
			timeStr = timeStr and trim(timeStr)
		elseif line:find("Towers used") and not towersDone then
			inTowers = true
		elseif inTowers and line:find("%-%s+%S") then
			local tower = line:match("%-%s+(.-)%s*$")
			if tower and tower ~= "" then
				towers[#towers + 1] = tower
			end
		elseif inTowers and line:find("%S") then
			-- 存檔有外層與內層兩份標頭（都有 Towers used），只取第一份
			inTowers = false
			towersDone = true
		end
	end
	local out = {}
	if map and diff then
		local row1 = "Map: " .. map .. " | Difficulty: " .. diff
		if timeStr then
			row1 = row1 .. " | Time: " .. timeStr
		end
		out[#out + 1] = row1
	end
	if #towers > 0 then
		out[#out + 1] = "<font color='#5BC8F5'>Towers used:</font>"
		for _, tower in ipairs(towers) do
			out[#out + 1] = "  - " .. tower
		end
	end
	return #out > 0 and table.concat(out, "\n") or L.localscript_info_no_block
end

local function showInfoModal(title, content, raw)
	local InfoModal = TabsWindow:PopupModal({ Title = title })
	local BtnRow = InfoModal:Row({ Expanded = true })
	BtnRow:Button({
		Text = L.localscript_info_close,
		Callback = function()
			InfoModal:ClosePopup()
		end,
	})
	BtnRow:Button({
		Text = L.localscript_info_copy,
		Callback = function()
			if raw and pcall(setclipboard, raw) then
				notify("Success", L.localscript_info_copied)
			end
		end,
	})
	InfoModal:Console({
		Value = content,
		ReadOnly = true,
		RichText = true,
		Border = true,
		Size = UDim2.new(1, 0, 0, isMobile and 110 or 150),
	})
end

local BuildScriptList
BuildScriptList = function()
	Localscript.ScriptListTable:ClearRows()
	local ok, files = pcall(listfiles, Localscript.path)
	local scripts = {}
	if ok and files then
		for _, filePath in ipairs(files) do
			local name = filePath:match("([^/\\]+)$") or filePath
			if isScriptFile(name) then
				scripts[#scripts + 1] = { name = name, path = filePath }
			end
		end
	end
	if #scripts == 0 then
		Localscript.ScriptListTable:NextRow():Column():Label({ Text = L.localscript_no_scripts })
		return
	end
	for _, script in ipairs(scripts) do
		local Row = Localscript.ScriptListTable:NextRow()
		Row:Column():Label({ Text = script.name })

		local ActionsCol = Row:Column()
		local actionsFrame = ActionsCol.RawObject
		local actionsFlex = Instance.new("UIFlexItem", actionsFrame)
		actionsFlex.FlexMode = Enum.UIFlexMode.None
		actionsFrame.Size = UDim2.new(0, 110, 1, 0)

		local ActionRow = ActionsCol:Row({ Expanded = true })

		ActionRow:SmallButton({
			Text = L.localscript_info,
			Callback = function()
				local ok3, raw = pcall(readfile, script.path)
				local content = (ok3 and raw) and buildInfoText(raw) or L.localscript_info_read_fail
				showInfoModal(script.name, content, ok3 and raw or nil)
			end,
		})

		ActionRow:SmallButton({
			Text = L.localscript_run,
			Callback = function()
				local ok3, raw = pcall(readfile, script.path)
				if not ok3 or not raw then
					notify("Warning", L.localscript_info_read_fail)
					return
				end
				local fn, err = loadstring(raw)
				if not fn then
					notify("Warning", L.localscript_error .. ": " .. tostring(err))
					return
				end
				task.spawn(function()
					local okRun, runErr = pcall(fn)
					if okRun then
						notify("Success", L.localscript_done .. ": " .. script.name)
					else
						notify("Warning", L.localscript_error .. ": " .. tostring(runErr))
					end
				end)
			end,
		})

		ActionRow:SmallButton({
			Text = L.localscript_delete,
			Callback = function(delBtn)
				local Popup1 = Tab_Localscript:PopupModal({ RelativeTo = delBtn })
				Popup1:Separator({ Text = L.localscript_confirm_title })
				Popup1:Label({ Text = script.name, TextWrapped = true })
				local Row1 = Popup1:Row({ Expanded = true })
				Row1:Button({
					Text = L.localscript_confirm_yes,
					Callback = function()
						Popup1:ClosePopup()
						local Popup2 = Tab_Localscript:PopupModal({ RelativeTo = delBtn })
						Popup2:Separator({ Text = L.localscript_confirm_title2 })
						local Row2 = Popup2:Row({ Expanded = true })
						Row2:Button({
							Text = L.localscript_delete_final,
							Callback = function()
								Popup2:ClosePopup()
								local ok2, err = pcall(delfile, script.path)
								if ok2 then
									notify("Success", L.localscript_deleted .. ": " .. script.name)
									BuildScriptList()
								else
									notify("Warning", L.localscript_delete_error .. ": " .. tostring(err))
								end
							end,
						})
						Row2:Button({
							Text = L.localscript_confirm_no,
							Callback = function()
								Popup2:ClosePopup()
							end,
						})
					end,
				})
				Row1:Button({
					Text = L.localscript_confirm_no,
					Callback = function()
						Popup1:ClosePopup()
					end,
				})
			end,
		})
	end
end

Tab_Localscript:Label({
	Text = L.localscript_path .. Localscript.path,
	TextSize = fontSize,
})

Tab_Localscript:Separator({ Text = L.localscript_list })

local HeaderRow = Tab_Localscript:Row()

HeaderRow:Button({
	Text = L.localscript_refresh,
	Callback = function()
		BuildScriptList()
		notify("Success", L.localscript_refreshed)
	end,
})

-- 儲存正在運行的腳本：把 main_<UserId>.lua 加上標頭與 RTD 載入器，存進 Script 資料夾
HeaderRow:Button({
	Text = L.localscript_save_running,
	Callback = function()
		local okRead, raw = pcall(readfile, mainPath())
		if not okRead or not raw or raw == "" then
			notify("Warning", L.localscript_save_no_running)
			return
		end
		local InfoModal = TabsWindow:PopupModal({ Title = "main_" .. userKey() })
		local BtnRow = InfoModal:Row({ Expanded = true })
		BtnRow:Button({
			Text = L.localscript_save,
			Callback = function()
				local inputName = ""
				local NameModal = TabsWindow:PopupModal({ Title = L.localscript_save_name_title })
				NameModal:InputText({
					Placeholder = L.localscript_save_name_ph,
					Value = "",
					Callback = function(_, text)
						inputName = text
					end,
				})
				local NRow = NameModal:Row({ Expanded = true })
				NRow:Button({
					Text = L.localscript_confirm_yes,
					Callback = function()
						local name = trim(inputName)
						if name == "" then
							return
						end
						local savePath = Localscript.path .. "/" .. name .. ".lua"
						local outerBlock = raw:match("%-%-%[%[(.-)%]%]") or ""
						local mapVal = trim(outerBlock:match("Map:%s*([^|\n]+)") or "")
						local diffVal = trim(outerBlock:match("Difficulty:%s*([^|\n]+)") or "")
						local timeVal = trim(outerBlock:match("Time:%s*([^|\n]+)") or "")

						local header = "--[[\n  Script By: RTD Place Tracker script \n"
							.. string.format('  URL: loadstring(game:HttpGet("%s"))()\n', RTD_TRACKER_URL)
						if mapVal ~= "" and diffVal ~= "" then
							header = header .. "  Map: " .. mapVal .. "  |  Difficulty: " .. diffVal .. "\n"
						end
						if timeVal ~= "" then
							header = header .. "  Time: " .. timeVal .. "\n"
						end
						header = header .. "]]"

						local wrapped = header .. "\n\n"
							.. "local fullScript = [=[\n" .. raw .. "\n]=]\n\n"
							.. "local RTD = getgenv().RTD\n"
							.. "if not RTD or not RTD.ExecuteQueue then\n"
							.. string.format('\tloadstring(game:HttpGet("%s"))()\n', RTD_API_URL)
							.. "\tRTD = getgenv().RTD\n"
							.. "end\n\n"
							.. "RTD.SaveLocalScript(fullScript)\n"
							.. "loadstring(fullScript)()\n"

						Rotation.ensureFolder()
						pcall(function()
							if not isfolder(Localscript.path) then
								makefolder(Localscript.path)
							end
						end)
						local ok4, err = pcall(writefile, savePath, wrapped)
						if ok4 then
							notify("Success", L.localscript_save_success .. ": " .. name)
							NameModal:ClosePopup()
							InfoModal:ClosePopup()
							BuildScriptList()
						else
							notify("Warning", L.localscript_save_error .. ": " .. tostring(err))
						end
					end,
				})
				NRow:Button({
					Text = L.localscript_confirm_no,
					Callback = function()
						NameModal:ClosePopup()
					end,
				})
			end,
		})
		BtnRow:Button({
			Text = L.localscript_info_close,
			Callback = function()
				InfoModal:ClosePopup()
			end,
		})
		InfoModal:Console({
			Value = buildInfoText(raw),
			ReadOnly = true,
			RichText = true,
			Border = true,
			Size = UDim2.new(1, 0, 0, isMobile and 110 or 150),
		})
	end,
})

Localscript.ScriptListTable = Tab_Localscript:Table({
	RowBackground = true,
	Border = true,
})

BuildScriptList()

-- ========================================================================== --
-- 定時更新（狀態 / 場數 / 密鑰 / 玩家資訊）
task.spawn(function()
	while true do
		if getgenv().RTD_UI_InstanceId ~= myInstanceId then
			break
		end
		local RTD = getRTD()
		if RTD then
			API_Check_Label.Text = L.envExist
			AutoReplay_Label.Text = RTD.GetAutoReplay() and L.autoReplayOn or L.autoReplayOff
			pcall(ReGameStateLabel)
			pcall(UpdateQueueLabels)
		else
			API_Check_Label.Text = L.envNotExist
			AutoReplay_Label.Text = L.noEnv
		end

		pcall(function()
			AutoLobbyReplay_CountLabel.Text = string.format(L.autoLobbyReplay_label, matchCount, Rotation.interval)
		end)
		pcall(function()
			KeyTime_Label.Text = fmtKeyRemaining()
		end)
		pcall(updatePlayInfo)
		task.wait(1)
	end
end)

-- ========================================================================== --
-- 單局結算：統計 + 累計場數 + 達標回大廳輪換（RTD.OnRoundEnd）
local function onRoundEnd()
	if getgenv().RTD_UI_InstanceId ~= myInstanceId then
		return -- 舊的 UI 實例（API 的回呼清單會保留）
	end
	local RTD = getRTD()
	if not RTD then
		return
	end

	-- 只有 Running 變化時回呼的結果為 nil；等結算封包補上勝負（最多 3 秒）
	local result = RTD.GetLastResult()
	local deadline = os.clock() + 3
	while (type(result) ~= "table" or result.IsVictory == nil) and os.clock() < deadline do
		task.wait(0.2)
		result = RTD.GetLastResult()
	end

	if type(result) == "table" and result.IsVictory ~= nil then
		local earned = 0
		for _, reward in ipairs(RTD.GetLastRewards()) do
			if reward.Type == "Currency" and reward.Name == "Money" then
				earned += reward.Amount
			end
		end
		refreshStatsUI(statsSave(result.IsVictory == true, earned))
		print(string.format(L.stats_round_done, result.IsVictory and L.stats_win or L.stats_loss, earned))
	else
		print(L.stats_round_unknown)
	end

	-- 記憶體防崩潰 + 反巨集輪換：累計場數，達 interval 場時換腳本並回大廳重開
	matchCount += 1
	print(string.format(L.stats_match_count, matchCount, Rotation.interval))

	if alrEnabled and matchCount >= Rotation.interval then
		print(string.format(L.stats_rotation_trigger, Rotation.interval))
		matchCount = 0

		-- 關閉 AutoReplay，避免重播核心在傳送前搶先投「再玩一場」
		pcall(RTD.AutoReplay, false)

		-- 反巨集輪換：從池中隨機挑一支（排除上次）覆寫進 main_<UserId>.lua；resume 會載入新 main
		local picked = Rotation.pickNext()
		if picked then
			if Rotation.applyToMain(picked) then
				Rotation.lastPicked = picked
				Rotation.save()
				print("[RTD統計] 🔀 " .. string.format(L.rotation_picked_msg, picked))
				notify("Success", string.format(L.rotation_picked_msg, picked))
			else
				warn("[RTD統計] " .. L.rotation_apply_fail)
			end
		else
			print("[RTD統計] " .. L.rotation_empty_pool)
		end

		-- 武裝 queue_on_teleport（TPChange 旗標版）：回大廳後自動載入 main → 大廳分支 EquipLoadout + SelectMap → 進關卡 → ExecuteQueue
		pcall(function()
			RTD.Queueload_TPChangeQueue("4-場數輪換")
		end)

		task.wait(1)
		RTD.ReturnToLobby()
	end
end

do
	local RTD = getRTD()
	if RTD and RTD.OnRoundEnd then
		RTD.OnRoundEnd(function()
			task.spawn(onRoundEnd)
		end)
	end
end
