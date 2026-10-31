-- ============================================================
--                 復古塔防 | 大廳介面 (Lobby UI)
-- ============================================================
-- 設計同花園塔房大廳介面（ReGui TabsWindow），目前只有「本地腳本」分頁：
--   Script 資料夾列表（資訊 / 執行 / 刪除）、儲存上次運行的腳本
-- 不依賴 RTD API：不需要先載入密鑰系統，單獨執行即可。
-- 執行存檔的腳本時，腳本標頭自己會在需要時載入 API。
-- ============================================================

-- 側邊通知模組
if not getgenv().NotificationModule then
	pcall(function()
		assert(loadstring(game:HttpGet("https://gist.githubusercontent.com/Tseting-nil/08653e6aa9fc12a9f097bfb10e6654e7/raw/00001d614d928fc5dafce59133a012dd78419afd/%25E5%2581%25B4%25E9%2582%258A%25E9%2580%259A%25E7%259F%25A5%25E6%25A8%25A1%25E7%25B5%2584.lua")))()
	end)
end

local RTD_DIR = "Tsetingnil_script/RTD"
local RTD_API_URL = "https://raw.githubusercontent.com/Tseting-nil/Retro-Tower-Defense-script/refs/heads/main/%E5%AF%86%E9%91%B0%E7%B3%BB%E7%B5%B1.lua"
local RTD_TRACKER_URL = "https://raw.githubusercontent.com/Tseting-nil/Retro-Tower-Defense-script/refs/heads/main/Tool/%E6%94%BE%E7%BD%AE%E8%BF%BD%E8%B9%A4%E5%99%A8.lua"

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

-- i18n（語言取自 keysystem.json）
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
		windowTitle = "大廳介面",
		tab_localscript = "本地腳本",
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
		localscript_save_running = "儲存上次運行的腳本",
		localscript_save = "儲存",
		localscript_save_name_title = "輸入儲存名稱",
		localscript_save_name_ph = "腳本名稱...",
		localscript_save_success = "已儲存",
		localscript_save_error = "儲存失敗",
		localscript_save_no_running = "無正在運行的腳本",
		info_map = "地圖",
		info_difficulty = "難度",
		info_time = "時間",
		info_towers_used = "使用塔",
	},
	en = {
		windowTitle = "Lobby UI",
		tab_localscript = "Local Script",
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
		localscript_save_running = "Save Last Run Script",
		localscript_save = "Save",
		localscript_save_name_title = "Enter Save Name",
		localscript_save_name_ph = "Script name...",
		localscript_save_success = "Saved",
		localscript_save_error = "Save failed",
		localscript_save_no_running = "No running script",
		info_map = "Map",
		info_difficulty = "Difficulty",
		info_time = "Time",
		info_towers_used = "Towers used",
	},
}

local L = i18n[currentLang] or i18n.zh
local fontSize = currentLang == "en" and 14 or nil

local Msg = getgenv().NotificationModule
local function notify(kind, text)
	if Msg and Msg[kind] then
		pcall(function()
			Msg[kind](Msg, text)
		end)
	end
end

-- ========================================================================== --
-- GUI
local ReGui = assert(loadstring(game:HttpGet("https://gist.githubusercontent.com/Tseting-nil/169b7303e1418cb301bad5ab427e9351/raw/93e90190f628387b545eef62b49e4ce146d1dad8/GUI:ReGui")))()

local UserInputService = game:GetService("UserInputService")
local isMobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

local TabsWindow = ReGui:TabsWindow({
	Title = L.windowTitle,
	Visible = true,
	Size = UDim2.fromOffset(450, 300),
})

local Tab = TabsWindow:CreateTab({ Name = L.tab_localscript })

-- 修改 Tab 字體和大小
task.spawn(function()
	task.wait(0.1)
	local label = Tab.TabButton.Button:FindFirstChildWhichIsA("TextLabel")
	if label then
		label.TextSize = currentLang == "en" and 14 or 18
		label.Font = Enum.Font.Ubuntu
	end
end)

local Tab_Localscript = Tab:ScrollingCanvas({ Fill = true, UiPadding = UDim.new(0, 0) })

-- ========================================================================== --
-- Tab_Localscript
local Localscript = {
	path = RTD_DIR .. "/Script",
	ScriptListTable = nil,
}

local function trim(s)
	return (s:gsub("^%s*(.-)%s*$", "%1"))
end

local function isScriptFile(name)
	return name:match("%.lua$") or name:match("%.txt$") or name:match("%.text$")
end

local function userKey()
	return tostring(LocalPlayer.UserId)
end

-- 上次運行的腳本（追蹤器 / 儲存後由 API 寫入的 main 檔）
local function mainPath()
	return RTD_DIR .. "/main_" .. userKey() .. ".lua"
end

local function ensureFolders()
	pcall(function()
		if not isfolder or not makefolder then
			return
		end
		for _, dir in ipairs({ "Tsetingnil_script", RTD_DIR, Localscript.path }) do
			if not isfolder(dir) then
				makefolder(dir)
			end
		end
	end)
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
		local row1 = L.info_map .. ": " .. map .. " | " .. L.info_difficulty .. ": " .. diff
		if timeStr then
			row1 = row1 .. " | " .. L.info_time .. ": " .. timeStr
		end
		out[#out + 1] = row1
	end
	if #towers > 0 then
		out[#out + 1] = "<font color='#5BC8F5'>" .. L.info_towers_used .. ":</font>"
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

-- 執行按鈕 0.2 秒攔截：所有列共用同一個時間戳，連點/雙擊只算一次，避免腳本重複執行
local RUN_DEBOUNCE_SEC = 0.2
local lastRunClock = 0

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
		actionsFrame.Size = UDim2.new(0, 150, 1, 0)

		local ActionRow = ActionsCol:Row({ Expanded = true })

		ActionRow:SmallButton({
			Text = L.localscript_run,
			Callback = function()
				local now = os.clock()
				if now - lastRunClock < RUN_DEBOUNCE_SEC then
					return
				end
				lastRunClock = now
				local ok3, raw = pcall(readfile, script.path)
				if not ok3 or not raw then
					notify("Warning", L.localscript_info_read_fail .. ": " .. script.name)
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
			Text = L.localscript_info,
			Callback = function()
				local ok3, raw = pcall(readfile, script.path)
				local content = (ok3 and raw) and buildInfoText(raw) or L.localscript_info_read_fail
				showInfoModal(script.name, content, ok3 and raw or nil)
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

-- 儲存上次運行的腳本：把 main_<UserId>.lua 加上標頭與 RTD 載入器，存進 Script 資料夾
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

						ensureFolders()
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
