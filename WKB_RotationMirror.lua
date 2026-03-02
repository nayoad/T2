-- Wakaba Rotation Mirror (Retail 12.1 Midnight)
-- SPELL_ACTIVATION_OVERLAY_GLOW_SHOW イベントを使用してスペルグローをミラーリングします。
-- C_AssistedCombat は不使用 (penalty なし)。
-- ミニマル: プロック/バフ/スタックの追跡なし。
--
-- 機能:
--  - 3重ボーダー: 黒(2) -> アクア(4) -> 黒(2) -> アイコン
--  - ホットキー表示 (実際に表示されているアクションボタンからコピー), 太字アウトライン
--  - ホットキー短縮: MouseWheelUp/Down -> MUP/MDN, SHIFT/CTRL/ALT -> S/C/A
--  - プレスフィードバック: 実際のボタンが押されている間、明るい黄色の半透明オーバーレイを表示
--    (ActionButtonDown/Up + MultiActionButtonDown/Up をフック)
--  - クリック可能: SecureActionButtonTemplate でミラー/トリンケット/フリースロットをクリックして使用可能
--  - クリック時フラッシュ: 押下時に黄色のフラッシュオーバーレイで視覚的フィードバック
--  - トリンケットCD: 2つの小さなアイコン; オプションで位置(上/下/左/右)を設定可能
--  - スペア(その他)行: アイテム/スペルCD用の2つのアイコン; オプションで設定(リンクを貼り付け or Ctrl+クリック)
--  - /wrm : オプションを開く; /wrm size N, /wrm reset
--  - アイコンの下に小さな黄色いテキストでサイズヒントを表示
--  - マップ変更後も維持: フレームをHide()せず(alpha 0)、ゾーン移動後に遅延更新

WKB_RotationMirrorDB = WKB_RotationMirrorDB or {}

-- =========================
-- Defaults
-- =========================
local DB_DEFAULTS = {
  iconSize = 64,
  point = "CENTER",
  relativePoint = "CENTER",
  x = 0,
  y = 0,
  trinketPosition = "UP",   -- UP, DOWN, LEFT, RIGHT
  freePosition = "DOWN",   -- UP, DOWN, LEFT, RIGHT
  free1 = "",
  free2 = "",
  useLowRankFirst = true,  -- true = use lower iLevel first, false = higher first (for ranked items)
  hotkeyScale = 1.0,       -- ホットキー文字の倍率 (1.0 = 100%)
  hotkeyOutline = true,    -- ホットキー文字にアウトラインを付けるか
  borderThickness = 1.0,   -- フレーム枠の太さ (0.5 = 薄い, 2 = 厚い), スライダー対応
  iconGap = 4,             -- サブアイコン同士の隙間（ピクセル）
  centerHotkey = false,    -- メインホットキーをアイコン中央に配置するか
  subIconScale = 0.5,      -- サブアイコンセルのスケール (0.3–0.7 = メイン枠サイズの30–70%)
}

local function ApplyDefaults()
  for k, v in pairs(DB_DEFAULTS) do
    if WKB_RotationMirrorDB[k] == nil then
      WKB_RotationMirrorDB[k] = v
    end
  end
end

-- =========================
-- LibDataBroker / LibDBIcon
-- =========================
local WKB_RotationMirror_LDB
do
  local ldb = LibStub and LibStub("LibDataBroker-1.1", true)
  if ldb then
    WKB_RotationMirror_LDB = ldb:NewDataObject("WKB_RotationMirror", {
      type = "data source",
      text = "Wakaba Rotation Mirror",
      icon = "Interface\\AddOns\\WKB_RotationMirror\\media\\icon.tga",

      OnClick = function(frame, button)
        if button == "LeftButton" then
          local panel = _G["WKB_RotationMirrorOptions"]
          if panel and panel:IsShown() then
            panel:Hide()
          else
            OpenOptions()
          end
        end
      end,

      OnTooltipShow = function(tooltip)
        if not tooltip or not tooltip.AddLine then return end
        tooltip:AddLine("Wakaba Rotation Mirror")
        tooltip:AddLine("Left-click to toggle options.", 1, 1, 1)
      end,
    })
  end
end

-- =========================
-- Constants & Tables
-- =========================
local BUTTON_GROUPS = {
  "ActionButton",
  "MultiBarBottomLeftButton",
  "MultiBarBottomRightButton",
  "MultiBarRightButton",
  "MultiBarLeftButton",
  "MultiBar5Button", "MultiBar6Button", "MultiBar7Button", "MultiBar8Button",
}

-- ホットキー短縮用ルックアップテーブル (大文字キー名 -> 短縮表記)
local HOTKEY_SUBS = {
  ["MOUSEWHEELUP"] = "MUP", ["MOUSE WHEEL UP"] = "MUP", ["MWUP"] = "MUP",
  ["MOUSEWHEELDOWN"] = "MDN", ["MOUSE WHEEL DOWN"] = "MDN", ["MWDOWN"] = "MDN",
  ["MIDDLE MOUSE"] = "MMB", ["MIDDLE MOUSE BUTTON"] = "MMB", ["MIDDLEMOUSE"] = "MMB",
  ["MOUSE BUTTON 3"] = "MB3", ["MOUSEBUTTON3"] = "MB3", ["BUTTON 3"] = "MB3", ["BUTTON3"] = "MB3",
  ["MOUSE BUTTON 4"] = "MB4", ["MOUSEBUTTON4"] = "MB4", ["BUTTON 4"] = "MB4", ["BUTTON4"] = "MB4",
  ["MOUSE BUTTON 5"] = "MB5", ["MOUSEBUTTON5"] = "MB5", ["BUTTON 5"] = "MB5", ["BUTTON5"] = "MB5",
  ["MOUSE BUTTON 6"] = "MB6", ["MOUSEBUTTON6"] = "MB6", ["BUTTON 6"] = "MB6", ["BUTTON6"] = "MB6",
  ["MOUSE BUTTON 7"] = "MB7", ["MOUSEBUTTON7"] = "MB7", ["BUTTON 7"] = "MB7", ["BUTTON7"] = "MB7",
  ["NUM PAD 0"] = "NP0", ["NUMPAD 0"] = "NP0", ["NUMPAD0"] = "NP0",
  ["NUM PAD 1"] = "NP1", ["NUMPAD 1"] = "NP1", ["NUMPAD1"] = "NP1",
  ["NUM PAD 2"] = "NP2", ["NUMPAD 2"] = "NP2", ["NUMPAD2"] = "NP2",
  ["NUM PAD 3"] = "NP3", ["NUMPAD 3"] = "NP3", ["NUMPAD3"] = "NP3",
  ["NUM PAD 4"] = "NP4", ["NUMPAD 4"] = "NP4", ["NUMPAD4"] = "NP4",
  ["NUM PAD 5"] = "NP5", ["NUMPAD 5"] = "NP5", ["NUMPAD5"] = "NP5",
  ["NUM PAD 6"] = "NP6", ["NUMPAD 6"] = "NP6", ["NUMPAD6"] = "NP6",
  ["NUM PAD 7"] = "NP7", ["NUMPAD 7"] = "NP7", ["NUMPAD7"] = "NP7",
  ["NUM PAD 8"] = "NP8", ["NUMPAD 8"] = "NP8", ["NUMPAD8"] = "NP8",
  ["NUM PAD 9"] = "NP9", ["NUMPAD 9"] = "NP9", ["NUMPAD9"] = "NP9",
  ["NUM PAD PLUS"] = "NP+", ["NUMPAD PLUS"] = "NP+", ["NUMPADPLUS"] = "NP+",
  ["NUM PAD MINUS"] = "NP-", ["NUMPAD MINUS"] = "NP-", ["NUMPADMINUS"] = "NP-",
  ["NUM PAD MULTIPLY"] = "NP*", ["NUMPAD MULTIPLY"] = "NP*", ["NUMPADMULTIPLY"] = "NP*",
  ["NUM PAD DIVIDE"] = "NP/", ["NUMPAD DIVIDE"] = "NP/", ["NUMPADDIVIDE"] = "NP/",
  ["NUM PAD ENTER"] = "NPE", ["NUMPAD ENTER"] = "NPE", ["NUMPADENTER"] = "NPE",
  ["NUM PAD DECIMAL"] = "NP.", ["NUMPAD DECIMAL"] = "NP.", ["NUMPADDECIMAL"] = "NP.",
  ["NUM PAD EQUALS"] = "NP=", ["NUMPAD EQUALS"] = "NP=", ["NUMPADEQUALS"] = "NP=",
  ["PAGE UP"] = "PgUp", ["PAGEUP"] = "PgUp",
  ["PAGE DOWN"] = "PgDn", ["PAGEDOWN"] = "PgDn",
  ["INSERT"] = "Ins",
  ["DELETE"] = "Del",
  ["SPACE BAR"] = "Spc", ["SPACEBAR"] = "Spc", ["SPACE"] = "Spc",
  ["BACK SPACE"] = "BSp", ["BACKSPACE"] = "BSp",
  ["CAPS LOCK"] = "Cap", ["CAPSLOCK"] = "Cap",
  ["SCROLL LOCK"] = "Scr", ["SCROLLLOCK"] = "Scr",
  ["PRINT SCREEN"] = "Prt", ["PRINTSCREEN"] = "Prt",
  ["HOME"] = "Home",
  ["END"] = "End",
  -- Japanese terms
  ["マウスホイールアップ"] = "MUP", ["マウスホイールダウン"] = "MDN",
  ["中ボタン"] = "MMB", ["マウスボタン 3"] = "MB3", ["マウスボタン3"] = "MB3",
  ["マウスボタン 4"] = "MB4", ["マウスボタン4"] = "MB4",
  ["マウスボタン 5"] = "MB5", ["マウスボタン5"] = "MB5",
  ["マウスボタン 6"] = "MB6", ["マウスボタン6"] = "MB6",
  ["マウスボタン 7"] = "MB7", ["マウスボタン7"] = "MB7",
  ["テンキー 0"] = "NP0", ["テンキー0"] = "NP0",
  ["テンキー 1"] = "NP1", ["テンキー1"] = "NP1",
  ["テンキー 2"] = "NP2", ["テンキー2"] = "NP2",
  ["テンキー 3"] = "NP3", ["テンキー3"] = "NP3",
  ["テンキー 4"] = "NP4", ["テンキー4"] = "NP4",
  ["テンキー 5"] = "NP5", ["テンキー5"] = "NP5",
  ["テンキー 6"] = "NP6", ["テンキー6"] = "NP6",
  ["テンキー 7"] = "NP7", ["テンキー7"] = "NP7",
  ["テンキー 8"] = "NP8", ["テンキー8"] = "NP8",
  ["テンキー 9"] = "NP9", ["テンキー9"] = "NP9",
  ["テンキー /"] = "NP/", ["テンキー/"] = "NP/",
  ["テンキー *"] = "NP*", ["テンキー*"] = "NP*",
  ["テンキー -"] = "NP-", ["テンキー-"] = "NP-",
  ["テンキー +"] = "NP+", ["テンキー+"] = "NP+",
  ["テンキー ."] = "NP.", ["テンキー."] = "NP.",
  ["テンキー Enter"] = "NPE", ["テンキーEnter"] = "NPE",  ["テンキー ENTER"] = "NPE", 
  ["スペース"] = "Spc",
}

-- 事前に「キーが長い順」にソートしたリストを作っておく
-- lua の pairs() は順序が不定なため、短い単語(SPACEなど)が
-- 長い単語(BACK SPACEなど)の一部を先に置換してしまうバグを防ぐ
local SORTED_HOTKEYS = {}
for k, v in pairs(HOTKEY_SUBS) do
  table.insert(SORTED_HOTKEYS, {
    orig = k,
    -- gsub用の安全なパターンにエスケープする
    pattern = k:gsub("([%(%)%.%%%+%-%*%?%[%^%$])", "%%%1"),
    short = v
  })
end
table.sort(SORTED_HOTKEYS, function(a, b) return #a.orig > #b.orig end)

local function ShortenHotkeyText(t)
  if not t or t == "" then return "" end
  if t == RANGE_INDICATOR then return "" end

  local upperT = t:upper()

  -- 1. 直接ルックアップ
  if HOTKEY_SUBS[upperT] then
    upperT = HOTKEY_SUBS[upperT]
  else
    -- 2. 修飾キー (SHIFT-A など) を短縮
    upperT = upperT:gsub("SHIFT%-", "S-")
    upperT = upperT:gsub("CTRL%-", "C-")
    upperT = upperT:gsub("CONTROL%-", "C-")
    upperT = upperT:gsub("ALT%-", "A-")
    upperT = upperT:gsub("META%-", "M-")

    -- 3. 長いキーから順に短縮化を試みる
    for _, item in ipairs(SORTED_HOTKEYS) do
      if upperT:find(item.orig, 1, true) then
        upperT = upperT:gsub(item.pattern, item.short)
      end
    end
  end

  -- 4. 修飾キーとメインキーを分離し、修飾キーのみをまとめて色付けする
  local hasC, hasS, hasA, hasM = false, false, false, false
  local mainParts = {}
  for part in string.gmatch(upperT, "[^%-]+") do
    if part == "C" then
      hasC = true
    elseif part == "S" then
      hasS = true
    elseif part == "A" then
      hasA = true
    elseif part == "M" then
      hasM = true
    else
      table.insert(mainParts, part)
    end
  end

  local mods = ""
  if hasC then mods = mods .. "C" end
  if hasS then mods = mods .. "S" end
  if hasA then mods = mods .. "A" end
  if hasM then mods = mods .. "M" end

  local main = table.concat(mainParts, "-")
  if mods == "" then
    return main ~= "" and main or upperT
  end

  local coloredMods = "|cff00ffff" .. mods .. "|r"
  if main ~= "" then
    return coloredMods .. "-" .. main
  else
    return coloredMods
  end
end

local function FindActionButtonForSlot(slot)
  for _, prefix in ipairs(BUTTON_GROUPS) do
    for i = 1, 12 do
      local btn = _G[prefix .. i]
      if btn and btn.action == slot then
        return btn
      end
    end
  end
  return nil
end

local function GetHotkeyTextForSlot(slot)
  local btn = FindActionButtonForSlot(slot)
  if not btn or not btn.HotKey then return "" end
  return ShortenHotkeyText(btn.HotKey:GetText())
end

-- =========================
-- Border sizing (dynamic: borderThickness scale 1.0 = 2/4/2)
-- =========================
local function GetBorderSizes()
  local scale = WKB_RotationMirrorDB.borderThickness
  if type(scale) ~= "number" or scale < 0.5 then scale = 0.5 end
  if scale > 2 then scale = 2 end
  return 2 * scale, 4 * scale, 2 * scale  -- outer black, aqua, inner black
end

-- Trinket row (above main icon)
local TRINKET_SLOTS = { 13, 14 } -- INVSLOT_TRINKET1, INVSLOT_TRINKET2
local TRINKET_BORDER = 2
local TRINKET_GAP = 4  -- ベースの隙間（実際の値は DB の iconGap で上書き）

-- Trinket API (12.1-safe: combat/Secret Value can make APIs return nil)
-- =========================
local function SafeGetInventoryItemID(unit, slot)
  local ok, id = pcall(GetInventoryItemID, unit, slot)
  if ok and type(id) == "number" and id > 0 then return id end
  return nil
end

local function SafeGetItemCooldown(itemId)
  if not itemId or type(itemId) ~= "number" then return nil, 0, 0 end
  if C_Item and C_Item.GetItemCooldown then
    local ok, start, duration = pcall(C_Item.GetItemCooldown, itemId)
    if ok and type(start) == "number" and type(duration) == "number" then
      return start, duration, 1
    end
  end
  local ok, start, duration, enable = pcall(GetItemCooldown, itemId)
  if ok and type(start) == "number" and type(duration) == "number" then
    return start, duration, (enable == 1 and 1 or 0)
  end
  return nil, 0, 0
end

-- =========================
-- Combat-safe cooldown display (12.x Duration object / Private Aura 緩和対応)
-- SetCooldownDuration(duration) は Duration オブジェクトを受け取り戦闘中も表示可能。
-- 利用可能な場合は C_ActionBar.GetActionCooldownDuration / C_Item の Duration を優先する。
-- =========================
local function ApplyCooldownToFrame(cdFrame, kind, id)
  if not cdFrame then return end
  
  -- (1) Duration object API (戦闘中も表示可能) - 12.0.0で追加
  -- C_ActionBar.GetActionCooldownDuration は DurationObject を返す
  -- Cooldown:SetCooldownFromDurationObject を使用する必要がある
  local dur = nil
  if kind == "action" and C_ActionBar and type(C_ActionBar.GetActionCooldownDuration) == "function" then
    local ok, d = pcall(C_ActionBar.GetActionCooldownDuration, id)
    if ok and d then dur = d end
  elseif kind == "item" then
    -- アイテム用のDuration APIはまだ確認できていないが、将来の拡張に備えて準備
    if C_Item and type(C_Item.GetItemCooldownDuration) == "function" then
      local ok, d = pcall(C_Item.GetItemCooldownDuration, id)
      if ok and d then dur = d end
    end
  end
  
  if dur and type(cdFrame.SetCooldownFromDurationObject) == "function" then
    local setOk = pcall(cdFrame.SetCooldownFromDurationObject, cdFrame, dur, false)
    if setOk then return end -- 成功したら終了
  end
  
  -- (2) Fallback: 従来の start/duration 数値 (Duration APIが使えない場合、または失敗した場合)
  local start, duration, enable
  if kind == "action" then
    local ok, s, d, e = pcall(function() return GetActionCooldown(id) end)
    if ok then start, duration, enable = s, d, e end
  elseif kind == "item" then
    start, duration, enable = SafeGetItemCooldown(id)
  end
  
  -- Secret Value対策: すべての操作をpcallで保護
  if not start or not duration then
    pcall(function() cdFrame:Clear() end)
    return
  end
  
  local sn, dn = tonumber(start), tonumber(duration)
  -- tonumber()の結果が数値かどうかを確認（Secret Value対策）
  if not sn or not dn or type(sn) ~= "number" or type(dn) ~= "number" then
    pcall(function() cdFrame:Clear() end)
    return
  end
  
  -- Secret Valueの比較をpcall内で行う（duration > 0 のみチェック）
  local shouldSet = false
  pcall(function()
    if dn > 0 then
      shouldSet = true
    end
  end)
  
  if shouldSet then
    local setOk = pcall(function()
      cdFrame:SetCooldown(sn, dn)
    end)
    if not setOk then
      pcall(function() cdFrame:Clear() end)
    end
  else
    pcall(function() cdFrame:Clear() end)
  end
end

-- Returns texture path (string), fileDataID (number), or nil. SetTexture accepts both.
local function SafeGetItemTexture(itemId)
  if not itemId or type(itemId) ~= "number" then return nil, nil end
  
  -- Try GetItemIcon directly (usually returns FileDataID or path)
  if GetItemIcon then
    local tex = GetItemIcon(itemId)
    if tex then
      if type(tex) == "string" then return tex, nil end
      if type(tex) == "number" then return nil, tex end
    end
  end
  
  -- Fallback to C_Item.GetItemInfo if needed (sometimes covers edge cases)
  if C_Item and C_Item.GetItemInfo then
    local ok, a, b, c, d, e, f, g, h, i, tex = pcall(C_Item.GetItemInfo, itemId)
    if ok then
      if type(a) == "table" then tex = a.texture or a.icon or a[10] end
      if tex then
        if type(tex) == "string" then return tex, nil end
        if type(tex) == "number" then return nil, tex end
      end
    end
  end
  
  return nil, nil
end

local function ParseActionBarString(text)
  local actBar, actNo = text:match("ActBar%s+(%d+)%s+ActNo%s+(%d+)")
  if not actBar then
     -- Short alias: "1-10" => ActBar 1 ActNo 10
     local barIdx, slotIdx = text:match("(%d+)%s*%-%s*(%d+)")
     if barIdx and slotIdx then
        actBar, actNo = tonumber(barIdx), tonumber(slotIdx)
     end
  else
     actBar, actNo = tonumber(actBar), tonumber(actNo)
  end
  
  if actBar and actNo and actBar >= 1 and actBar <= 8 and actNo >= 1 and actNo <= 12 then
      local barName = BUTTON_GROUPS[actBar]
      if barName then
         local btn = _G[barName .. actNo]
         if btn and btn.action then
            return btn.action
         end
      end
  end
  return nil
end

-- 単一エントリ: "item"|"spell"|"action", id (itemID/spellID/actionSlot) を返す
local function ParseOtherEntry(text)
  if not text or type(text) ~= "string" or text:match("^%s*$") then return nil, nil end
  text = text:gsub("^%s+", ""):gsub("%s+$", "")
  
  local id = text:match("|Hitem:(%d+)") or text:match("item:(%d+)")
  if id then return "item", tonumber(id) end
  
  id = text:match("|Hspell:(%d+)") or text:match("spell:(%d+)")
  if id then return "spell", tonumber(id) end
  
  id = text:match("action:(%d+)")
  if id then
    id = tonumber(id)
    if id and id >= 1 and id <= 168 then return "action", id end
  end
  
  local actionID = ParseActionBarString(text)
  if actionID then return "action", actionID end

  return nil, nil
end

-- カンマ区切りリスト: アイテム (ランク用) または単一のスペル/アクション
local function ParseOtherEntryList(text)
  if not text or type(text) ~= "string" or text:match("^%s*$") then return {} end
  local out = {}
  local trimmed = text:gsub("^%s+", ""):gsub("%s+$", "")
  for part in trimmed:gmatch("[^,]+") do
    -- Parsing each part via ParseOtherEntryReuse would be ideal to avoid redundant string ops, 
    -- but simplify by reusing ParseOtherEntry logic logic or just calling it?
    -- Since ParseOtherEntry strips whitespace, we can just call it.
    local kind, id = ParseOtherEntry(part)
    if kind and id then
       out[#out + 1] = { kind = kind, id = id }
    end
  end
  return out
end

local function SafeGetItemName(itemId)
  if not itemId or type(itemId) ~= "number" then return nil end
  if C_Item and C_Item.GetItemInfo then
    local ok, name = pcall(C_Item.GetItemInfo, itemId)
    if ok and type(name) == "string" and name ~= "" then return name end
    if ok and type(name) == "table" and name.name then return name.name end
  end
  return nil
end

-- Rank ★1–3 from item name (not iLevel)
local function GetItemRankFromName(name)
  if not name or type(name) ~= "string" then return nil end
  local r = name:match("★%s*([1-3])") or name:match("★([1-3])")
  if r then return tonumber(r) end
  return nil
end

-- API-first rank detection: tries C_TradeSkillUI first, falls back to name pattern
local function GetItemRank(itemId)
  if not itemId or type(itemId) ~= "number" then return nil end
  -- Primary: WoW 12.0 API for reagent/consumable quality
  if C_TradeSkillUI and C_TradeSkillUI.GetItemReagentQualityByItemInfo then
    local ok, quality = pcall(C_TradeSkillUI.GetItemReagentQualityByItemInfo, itemId)
    if ok and type(quality) == "number" and quality >= 1 and quality <= 3 then
      return quality
    end
  end
  -- Fallback: name-based detection for items with ★ in the name
  local name = SafeGetItemName(itemId)
  return GetItemRankFromName(name)
end

-- Inline atlas markup for rank badge stars (bronze/silver/gold)
local RANK_ATLAS = {
  [1] = "|A:Professions-ChatIcon-Quality-Tier1:24:24|a",
  [2] = "|A:Professions-ChatIcon-Quality-Tier2:24:24|a",
  [3] = "|A:Professions-ChatIcon-Quality-Tier3:24:24|a",
}
local function GetRankAtlasMarkup(rank)
  if not rank or type(rank) ~= "number" then return "" end
  return RANK_ATLAS[rank] or ""
end

local function GetBaseItemName(name)
  if not name or type(name) ~= "string" then return name end
  return name:gsub("%s*★%s*[1-3]%s*$", ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function SafeGetItemCount(itemId)
   if not itemId or type(itemId) ~= "number" then return nil end
   if C_Item and C_Item.GetItemCount then
      return C_Item.GetItemCount(itemId)
   end
   if GetItemCount then
      return GetItemCount(itemId)
   end
   return nil
end

-- ベース名が一致するアイテムをバッグからスキャン (同じポーションの★1/★2/★3など)
-- 結果をキャッシュして毎フレームのバッグスキャンを回避 (BAG_UPDATE でのみクリア)
local scanCache = {}
local getContainerItemID = (C_Container and C_Container.GetContainerItemID) or GetContainerItemID
local getContainerNumSlots = (C_Container and C_Container.GetContainerNumSlots) or GetContainerNumSlots

local function ScanBagsForItemsMatchingBaseName(baseName)
  if not baseName or baseName == "" or not getContainerItemID or not getContainerNumSlots then return {} end
  if scanCache[baseName] then return scanCache[baseName] end

  local seen = {}
  local out = {}
  for bag = 0, 4 do
    local numSlots = getContainerNumSlots(bag) or 0
    for slot = 1, numSlots do
      local itemId = getContainerItemID(bag, slot)
      if itemId and itemId > 0 and not seen[itemId] then
        seen[itemId] = true
        local name = SafeGetItemName(itemId)
        if name and GetBaseItemName(name) == baseName then
          local rank = GetItemRank(itemId) or 0
          out[#out + 1] = { kind = "item", id = itemId, rank = rank }
        end
      end
    end
  end
  
  scanCache[baseName] = out
  return out
end

local function SafeGetSpellCooldown(spellId)
  if not spellId or type(spellId) ~= "number" then return nil, 0, 0 end
  local ok, start, duration, enable = pcall(GetSpellCooldown, spellId)
  if ok and type(start) == "number" and type(duration) == "number" then
    return start, duration, (enable == 1 and 1 or 0)
  end
  return nil, 0, 0
end

local function SafeGetSpellTexture(spellId)
  if not spellId or type(spellId) ~= "number" then return nil end
  if GetSpellTexture then
     local tex = GetSpellTexture(spellId)
     if tex then return tex end
  end
  return nil
end

-- =========================
-- Frame
-- =========================
local RM = CreateFrame("Frame", "WKB_RotationMirrorFrame", UIParent)
RM:SetClampedToScreen(true)
RM:EnableMouse(true)
RM:SetMovable(true)
RM:RegisterForDrag("LeftButton")
-- Optionsパネル表示中のみドラッグ可にするためのフラグ
local optionsOpen = false

local function SavePosition()
  local p, _, rp, x, y = RM:GetPoint(1)
  WKB_RotationMirrorDB.point = p
  WKB_RotationMirrorDB.relativePoint = rp
  WKB_RotationMirrorDB.x = x
  WKB_RotationMirrorDB.y = y
  local iconLeft = RM.Icon and RM.Icon:GetLeft() or nil
  local iconBottom = RM.Icon and RM.Icon:GetBottom() or nil
  if iconLeft and iconBottom then
    WKB_RotationMirrorDB.mainIconLeft = iconLeft
    WKB_RotationMirrorDB.mainIconBottom = iconBottom
  end
end

local function RestorePosition()
  RM:ClearAllPoints()
  RM:SetPoint(
    WKB_RotationMirrorDB.point or DB_DEFAULTS.point,
    UIParent,
    WKB_RotationMirrorDB.relativePoint or DB_DEFAULTS.relativePoint,
    WKB_RotationMirrorDB.x or DB_DEFAULTS.x,
    WKB_RotationMirrorDB.y or DB_DEFAULTS.y
  )
end

RM:SetScript("OnDragStart", function(self)
  if InCombatLockdown() then return end
  if not optionsOpen then return end
  self:StartMoving()
end)

RM:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  SavePosition()
end)

-- Secure ボタン経由のクリックがメインフレームのドラッグをブロックしてしまうので、
-- メインの SecureActionButton からもドラッグ開始/終了を親フレームに委譲する
local function SetupMainDragProxy()
  if not RM.MainSecureButton then return end
  RM.MainSecureButton:RegisterForDrag("LeftButton")
  RM.MainSecureButton:SetScript("OnDragStart", function()
    if InCombatLockdown() then return end
    if not optionsOpen then return end
    RM:StartMoving()
  end)
  RM.MainSecureButton:SetScript("OnDragStop", function()
    RM:StopMovingOrSizing()
    SavePosition()
  end)
end


-- IMPORTANT: never Hide() this frame; alpha 0 keeps updates alive through zoning.
local function SetActive(active)
  if active then
    RM:SetAlpha(1)
    if not InCombatLockdown() then
      RM:EnableMouse(true)
    end
  else
    RM:SetAlpha(0)
    if not InCombatLockdown() then
      RM:EnableMouse(false)
    end
    if RM.PressedOverlay then RM.PressedOverlay:Hide() end
  end
end

-- =========================
-- Visual layers
-- =========================
RM.OuterBlack = RM:CreateTexture(nil, "BACKGROUND")
RM.OuterBlack:SetAllPoints()
RM.OuterBlack:SetColorTexture(0, 0, 0, 0.90)

RM.Aqua = RM:CreateTexture(nil, "BORDER")
RM.Aqua:SetColorTexture(0.35, 0.85, 1.00, 0.95)

RM.InnerBlack = RM:CreateTexture(nil, "BORDER")
RM.InnerBlack:SetColorTexture(0, 0, 0, 0.90)

RM.Icon = RM:CreateTexture(nil, "ARTWORK")
RM.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

RM.CD = CreateFrame("Cooldown", nil, RM, "CooldownFrameTemplate")

-- Press overlay (bright yellow, translucent)
RM.PressedOverlay = RM:CreateTexture(nil, "OVERLAY")
RM.PressedOverlay:SetColorTexture(1.00, 0.92, 0.25, 0.35)
RM.PressedOverlay:Hide()

-- （以前はここで Blizzard のグローをミラーしていたが、安定性のため機能を撤去）

-- =========================
-- SecureActionButton helper (clickable use + flash on press)
-- =========================
local function CreateSecureButtonWithFlash(parent, name)
  local btn = CreateFrame("Button", name, parent, "SecureActionButtonTemplate")
  btn:SetFrameLevel(parent:GetFrameLevel() + 10)
  btn:EnableMouse(true)
  -- Flash overlay when pushed (visual feedback on click)
  local flash = btn:CreateTexture(nil, "OVERLAY")
  flash:SetAllPoints()
  flash:SetColorTexture(1.00, 0.95, 0.40, 0.50)
  flash:SetBlendMode("ADD")
  btn:SetPushedTexture(flash)
  return btn
end

-- Main icon: secure button (positioned in Layout to match RM.Icon)
RM.MainSecureButton = CreateSecureButtonWithFlash(RM, "WKB_RotationMirror_MainSecure")
RM.MainSecureButton:RegisterForClicks("AnyUp", "AnyDown")
RM.MainSecureButton:SetAttribute("type", "action")
RM.MainSecureButton:SetAttribute("action", 0)
SetupMainDragProxy()

-- Hotkey (thick outline)
RM.Hotkey = RM:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
RM.Hotkey:SetJustifyH("RIGHT")
RM.Hotkey:SetText("")

-- メインアイコンのスタック/チャージ数
RM.Count = RM:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
RM.Count:SetJustifyH("RIGHT")
RM.Count:SetText("")

-- メインアイコンのツールチップ（GameTooltip をHUD側のデフォルト位置に）
RM:SetScript("OnEnter", function(self)
  if not currentSlot or not GameTooltip or not GameTooltip_SetDefaultAnchor then return end
  GameTooltip:SetOwner(self, "ANCHOR_NONE")
  GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
  GameTooltip:SetAction(currentSlot)
  GameTooltip:Show()
end)
RM:SetScript("OnLeave", function()
  if GameTooltip then GameTooltip:Hide() end
end)

-- Size hint under icon
RM.SizeHint = RM:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
RM.SizeHint:SetJustifyH("CENTER")
RM.SizeHint:SetTextColor(1.00, 0.90, 0.20, 0.85)
RM.SizeHint:SetText("")

-- Trinket row: two half-size icons above main icon
RM.Trinkets = {}
for i = 1, 2 do
  local slotId = TRINKET_SLOTS[i]
  local cell = CreateFrame("Frame", nil, RM)
  cell.slotId = slotId
  cell.kind = "trinket"
  cell.index = i
  cell.Bg = cell:CreateTexture(nil, "BACKGROUND")
  cell.Bg:SetColorTexture(0, 0, 0, 0.85)
  cell.Bg:SetAllPoints()
  cell.Icon = cell:CreateTexture(nil, "ARTWORK")
  cell.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  cell.CD = CreateFrame("Cooldown", nil, cell, "CooldownFrameTemplate")
  cell.CD:SetAllPoints(cell.Icon)
  
  -- Use-type border (thick yellow)
  cell.UseBorder = cell:CreateTexture(nil, "OVERLAY")
  cell.UseBorder:SetPoint("TOPLEFT", cell.Icon, "TOPLEFT", 2, -2)
  cell.UseBorder:SetPoint("BOTTOMRIGHT", cell.Icon, "BOTTOMRIGHT", -2, 2)
  cell.UseBorder:SetColorTexture(1, 1, 0, 0) -- shape only, will use 4-line approach for thickness or just color texture with inner cutout?
  -- "Thick outline" usually means 4 textures or a border texture file.
  -- Let's use 4 textures for a 2px yellow border INSIDE the icon.
  -- 黄枠がアイコンを潰しすぎないように、1px・外周寄りに薄く表示
  cell.UseBorderTop = cell:CreateTexture(nil, "OVERLAY")
  cell.UseBorderTop:SetColorTexture(1, 0.9, 0, 0.9)
  cell.UseBorderTop:SetPoint("TOPLEFT", cell.Icon, "TOPLEFT", 0, 0)
  cell.UseBorderTop:SetPoint("TOPRIGHT", cell.Icon, "TOPRIGHT", 0, 0)
  cell.UseBorderTop:SetHeight(1)
  
  cell.UseBorderBottom = cell:CreateTexture(nil, "OVERLAY")
  cell.UseBorderBottom:SetColorTexture(1, 0.9, 0, 0.9)
  cell.UseBorderBottom:SetPoint("BOTTOMLEFT", cell.Icon, "BOTTOMLEFT", 0, 0)
  cell.UseBorderBottom:SetPoint("BOTTOMRIGHT", cell.Icon, "BOTTOMRIGHT", 0, 0)
  cell.UseBorderBottom:SetHeight(1)
  
  cell.UseBorderLeft = cell:CreateTexture(nil, "OVERLAY")
  cell.UseBorderLeft:SetColorTexture(1, 0.9, 0, 0.9)
  cell.UseBorderLeft:SetPoint("TOPLEFT", cell.Icon, "TOPLEFT", 0, 0)
  cell.UseBorderLeft:SetPoint("BOTTOMLEFT", cell.Icon, "BOTTOMLEFT", 0, 0)
  cell.UseBorderLeft:SetWidth(1)
  
  cell.UseBorderRight = cell:CreateTexture(nil, "OVERLAY")
  cell.UseBorderRight:SetColorTexture(1, 0.9, 0, 0.9)
  cell.UseBorderRight:SetPoint("TOPRIGHT", cell.Icon, "TOPRIGHT", 0, 0)
  cell.UseBorderRight:SetPoint("BOTTOMRIGHT", cell.Icon, "BOTTOMRIGHT", 0, 0)
  cell.UseBorderRight:SetWidth(1)
  
  local function SetUseBorder(show)
    if show then
      cell.UseBorderTop:Show()
      cell.UseBorderBottom:Show()
      cell.UseBorderLeft:Show()
      cell.UseBorderRight:Show()
    else
      cell.UseBorderTop:Hide()
      cell.UseBorderBottom:Hide()
      cell.UseBorderLeft:Hide()
      cell.UseBorderRight:Hide()
    end
  end
  cell.SetUseBorder = SetUseBorder
  cell.SetUseBorder(false)

  cell:SetScript("OnEnter", function(self)
    if not self.itemId or not GameTooltip or not GameTooltip_SetDefaultAnchor then return end
    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    GameTooltip:SetItemByID(self.itemId)
    GameTooltip:Show()
  end)
  cell:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
  end)
  -- Secure button for click-to-use (positioned in Layout over cell.Icon)
  cell.SecureButton = CreateSecureButtonWithFlash(cell, "WKB_RotationMirror_Trinket" .. i .. "_Secure")
  cell.SecureButton:RegisterForClicks("AnyUp", "AnyDown")
  RM.Trinkets[i] = cell
end

-- Other row: two half-size icons (user-configured; item or spell; count + rank overlay)
RM.FreeSlots = {}
for i = 1, 2 do
  local cell = CreateFrame("Frame", nil, RM)
  cell.kind = "free"
  cell.index = i
  cell.Bg = cell:CreateTexture(nil, "BACKGROUND")
  cell.Bg:SetColorTexture(0.15, 0.08, 0.25, 0.9)
  cell.Bg:SetAllPoints()
  cell.Icon = cell:CreateTexture(nil, "ARTWORK")
  cell.Icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
  cell.CD = CreateFrame("Cooldown", nil, cell, "CooldownFrameTemplate")
  cell.CD:SetAllPoints(cell.Icon)
  cell.Count = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  cell.Count:SetPoint("BOTTOMRIGHT", cell.Icon, "BOTTOMRIGHT", -1, 1)
  cell.Count:SetJustifyH("RIGHT")
  cell.Count:SetText("")
  cell.RankFrame = CreateFrame("Frame", nil, cell)
  cell.RankFrame:SetFrameLevel(cell.CD:GetFrameLevel() + 2)
  cell.Rank = cell.RankFrame:CreateTexture(nil, "OVERLAY", nil, 7)
  cell.Rank:Hide()
  cell.Hotkey = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  cell.Hotkey:SetPoint("TOPRIGHT", cell.Icon, "TOPRIGHT", -1, -1)
  cell.Hotkey:SetJustifyH("RIGHT")
  cell.Hotkey:SetText("")
  cell:SetScript("OnEnter", function(self)
    if not self.kind or not self.id or not GameTooltip or not GameTooltip_SetDefaultAnchor then return end
    GameTooltip:SetOwner(self, "ANCHOR_NONE")
    GameTooltip_SetDefaultAnchor(GameTooltip, UIParent)
    if self.kind == "action" then
      GameTooltip:SetAction(self.id)
    elseif self.kind == "item" then
      GameTooltip:SetItemByID(self.id)
    elseif self.kind == "spell" then
      GameTooltip:SetSpellByID(self.id)
    end
    GameTooltip:Show()
  end)
  cell:SetScript("OnLeave", function()
    if GameTooltip then GameTooltip:Hide() end
  end)
  -- Secure button for click-to-use (positioned in Layout over cell.Icon)
  cell.SecureButton = CreateSecureButtonWithFlash(cell, "WKB_RotationMirror_Free" .. i .. "_Secure")
  cell.SecureButton:RegisterForClicks("AnyUp", "AnyDown")
  RM.FreeSlots[i] = cell
end

-- Combat state and base border color（推奨アイコンが無いとき用のフォールバック）
local inCombat = false
local function UpdateBorderColor()
  if not RM or not RM.Aqua then return end
  if inCombat then
    -- 戦闘中ベース: シアン寄り
    RM.Aqua:SetColorTexture(0.40, 0.80, 1.00, 0.95)
  else
    -- 戦闘外ベース: 暗めグレー
    RM.Aqua:SetColorTexture(0.30, 0.30, 0.30, 0.95)
  end
end

local function Layout(iconSize)
  local outerBlack, aqua, innerBlack = GetBorderSizes()
  local iconInset = outerBlack + aqua + innerBlack
  local frameSize = iconSize + (iconInset * 2)
  -- Sub cell = main total (frameSize) * user scale so sub-icons scale with border; visible icon = cell minus border
  local subScale = tonumber(WKB_RotationMirrorDB.subIconScale) or DB_DEFAULTS.subIconScale
  if subScale < 0.3 then subScale = 0.3 end
  if subScale > 0.7 then subScale = 0.7 end
  local trinketCellSize = math.floor(frameSize * subScale)
  local trinketIconSize = math.max(1, trinketCellSize - (TRINKET_BORDER * 2))
  local gap = tonumber(WKB_RotationMirrorDB.iconGap) or TRINKET_GAP
  if gap < 0 then gap = 0 end
  if gap > 32 then gap = 32 end
  local rowW_H = 2 * trinketCellSize + gap   -- horizontal row width (UP/DOWN)
  local rowH_H = trinketCellSize             -- horizontal row height
  local rowW_V = trinketCellSize             -- vertical column width (LEFT/RIGHT)
  local rowH_V = 2 * trinketCellSize + gap   -- vertical column height
  local tp = WKB_RotationMirrorDB.trinketPosition or DB_DEFAULTS.trinketPosition
  local op = WKB_RotationMirrorDB.freePosition or DB_DEFAULTS.freePosition
  
  -- Check if we should show Other frames
  local showOthers = optionsOpen or 
                     (WKB_RotationMirrorDB.free1 and WKB_RotationMirrorDB.free1 ~= "") or 
                     (WKB_RotationMirrorDB.free2 and WKB_RotationMirrorDB.free2 ~= "")

  local nUp, nDown, nLeft, nRight = 0, 0, 0, 0
  if tp == "UP" then nUp = nUp + 1 end
  if tp == "DOWN" then nDown = nDown + 1 end
  if tp == "LEFT" then nLeft = nLeft + 1 end
  if tp == "RIGHT" then nRight = nRight + 1 end
  
  if showOthers then
    if op == "UP" then nUp = nUp + 1 end
    if op == "DOWN" then nDown = nDown + 1 end
    if op == "LEFT" then nLeft = nLeft + 1 end
    if op == "RIGHT" then nRight = nRight + 1 end
  end

  local mainLeft = nLeft * (rowW_V + gap)
  local mainBottom = nDown * (rowH_H + gap)
  local totalWidth = mainLeft + frameSize + nRight * (rowW_V + gap)
  local totalHeight = mainBottom + frameSize + nUp * (rowH_H + gap)
  RM:SetSize(totalWidth, totalHeight)

  -- Main icon area (dynamic border thickness)
  RM.OuterBlack:ClearAllPoints()
  RM.OuterBlack:SetPoint("BOTTOMLEFT", RM, "BOTTOMLEFT", mainLeft, mainBottom)
  RM.OuterBlack:SetPoint("TOPRIGHT", RM, "BOTTOMLEFT", mainLeft + frameSize, mainBottom + frameSize)
  RM.Aqua:ClearAllPoints()
  RM.Aqua:SetPoint("BOTTOMLEFT", RM, "BOTTOMLEFT", mainLeft + outerBlack, mainBottom + outerBlack)
  RM.Aqua:SetPoint("TOPRIGHT", RM, "BOTTOMLEFT", mainLeft + frameSize - outerBlack, mainBottom + frameSize - outerBlack)
  local innerInset = outerBlack + aqua
  RM.InnerBlack:ClearAllPoints()
  RM.InnerBlack:SetPoint("BOTTOMLEFT", RM, "BOTTOMLEFT", mainLeft + innerInset, mainBottom + innerInset)
  RM.InnerBlack:SetPoint("TOPRIGHT", RM, "BOTTOMLEFT", mainLeft + frameSize - innerInset, mainBottom + frameSize - innerInset)
  RM.Icon:ClearAllPoints()
  RM.Icon:SetPoint("BOTTOMLEFT", RM, "BOTTOMLEFT", mainLeft + iconInset, mainBottom + iconInset)
  RM.Icon:SetPoint("TOPRIGHT", RM, "BOTTOMLEFT", mainLeft + frameSize - iconInset, mainBottom + frameSize - iconInset)
  if RM.CombatAnim then
    RM.CombatAnim:ClearAllPoints()
    RM.CombatAnim:SetPoint("BOTTOMLEFT", RM.InnerBlack, "BOTTOMLEFT", 0, 0)
    RM.CombatAnim:SetPoint("TOPRIGHT", RM.InnerBlack, "TOPRIGHT", 0, 0)
  end
  RM.CD:ClearAllPoints()
  RM.CD:SetAllPoints(RM.Icon)
  RM.PressedOverlay:ClearAllPoints()
  RM.PressedOverlay:SetAllPoints(RM.Icon)
  RM.Hotkey:ClearAllPoints()
  if WKB_RotationMirrorDB.centerHotkey then
    RM.Hotkey:SetPoint("CENTER", RM.Icon, "CENTER", 0, 0)
    RM.Hotkey:SetJustifyH("CENTER")
  else
    RM.Hotkey:SetPoint("TOPRIGHT", RM, "BOTTOMLEFT", mainLeft + frameSize - iconInset - 2, mainBottom + frameSize - iconInset - 1)
    RM.Hotkey:SetJustifyH("RIGHT")
  end
  local font, _, _ = RM.Hotkey:GetFont()
  local scale = WKB_RotationMirrorDB.hotkeyScale or DB_DEFAULTS.hotkeyScale
  if scale < 0.5 then scale = 0.5 end
  if scale > 1.5 then scale = 1.5 end
  local outlineFlag = (WKB_RotationMirrorDB.hotkeyOutline ~= false) and "THICKOUTLINE" or ""
  local hotkeySize = math.max(10, math.floor(iconSize * 0.38 * scale))
  RM.Hotkey:SetFont(font, hotkeySize, outlineFlag)
  -- メインスタック数
  RM.Count:ClearAllPoints()
  RM.Count:SetPoint("BOTTOMRIGHT", RM, "BOTTOMLEFT", mainLeft + frameSize - iconInset - 1, mainBottom + iconInset + 1)
  RM.Count:SetFont(font, math.max(10, math.floor(iconSize * 0.32)), "OUTLINE")
  RM.SizeHint:SetText("")
  RM.SizeHint:ClearAllPoints()
  RM.SizeHint:SetPoint("TOP", RM, "BOTTOM", 0, -2)
  RM.SizeHint:SetFont(font, math.max(9, math.floor(iconSize * 0.16)), "OUTLINE")

  -- Glow frame for proc overlay (same size as icon; Blizzard glow attaches here)
  if RM.GlowFrame then
    RM.GlowFrame:ClearAllPoints()
    RM.GlowFrame:SetPoint("BOTTOMLEFT", RM, "BOTTOMLEFT", mainLeft + iconInset, mainBottom + iconInset)
    RM.GlowFrame:SetPoint("TOPRIGHT", RM, "BOTTOMLEFT", mainLeft + frameSize - iconInset, mainBottom + frameSize - iconInset)
  end

  -- Main secure button: same size as main icon (clickable)
  if not InCombatLockdown() and RM.MainSecureButton then
    RM.MainSecureButton:ClearAllPoints()
    RM.MainSecureButton:SetPoint("BOTTOMLEFT", RM, "BOTTOMLEFT", mainLeft + iconInset, mainBottom + iconInset)
    RM.MainSecureButton:SetPoint("TOPRIGHT", RM, "BOTTOMLEFT", mainLeft + frameSize - iconInset, mainBottom + frameSize - iconInset)
  end

  UpdateBorderColor()

  -- Keep main icon fixed on screen: re-anchor RM so RM.Icon stays at saved coordinates
  local savedLeft = WKB_RotationMirrorDB.mainIconLeft
  local savedBottom = WKB_RotationMirrorDB.mainIconBottom
  if savedLeft and savedBottom then
    local rmLeft = savedLeft - (mainLeft + iconInset)
    local rmBottom = savedBottom - (mainBottom + iconInset)
    RM:ClearAllPoints()
    RM:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", rmLeft, rmBottom)
  else
    local curLeft = RM.Icon and RM.Icon:GetLeft() or nil
    local curBottom = RM.Icon and RM.Icon:GetBottom() or nil
    if curLeft and curBottom then
      WKB_RotationMirrorDB.mainIconLeft = curLeft
      WKB_RotationMirrorDB.mainIconBottom = curBottom
    end
  end

  local function rowAnchor(side, slot)
    local dx, dy = 0, 0
    if side == "UP" then
      dy = mainBottom + frameSize + gap + (slot - 1) * (rowH_H + gap)
      dx = mainLeft + (frameSize - rowW_H) / 2
    elseif side == "DOWN" then
      dy = mainBottom - rowH_H - gap - (slot - 1) * (rowH_H + gap)
      dx = mainLeft + (frameSize - rowW_H) / 2
    elseif side == "LEFT" then
      dx = mainLeft - rowW_V - gap - (slot - 1) * (rowW_V + gap)
      dy = mainBottom + (frameSize - rowH_V) / 2
    else
      dx = mainLeft + frameSize + gap + (slot - 1) * (rowW_V + gap)
      dy = mainBottom + (frameSize - rowH_V) / 2
    end
    return dx, dy
  end
  local trinketSlot = 1
  local otherSlot = (tp == op) and 2 or 1
  local tx, ty = rowAnchor(tp, trinketSlot)
  local ox, oy = rowAnchor(op, otherSlot)

  local font, _, _ = RM.Hotkey:GetFont()
  local subHotkeyFactor = 0.34
  -- サブ用ホットキーはユーザー設定scaleのうち最大110%までを反映
  local subScale = scale
  if subScale > 1.10 then
    subScale = 1.10
  end
  local smallHotkeySize = math.max(8, math.floor(trinketIconSize * subHotkeyFactor * subScale))
  local function placeCell(cell, side, baseX, baseY)
    cell:SetScale(1.0)
    cell:SetSize(trinketCellSize, trinketCellSize)
    cell.Bg:SetAllPoints()
    cell.Icon:ClearAllPoints()
    cell.Icon:SetPoint("TOPLEFT", cell, "TOPLEFT", TRINKET_BORDER, -TRINKET_BORDER)
    cell.Icon:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -TRINKET_BORDER, TRINKET_BORDER)
    cell.CD:ClearAllPoints()
    cell.CD:SetAllPoints(cell.Icon)
    if cell.SecureButton then
      if not InCombatLockdown() then
        cell.SecureButton:ClearAllPoints()
        cell.SecureButton:SetPoint("TOPLEFT", cell, "TOPLEFT", TRINKET_BORDER, -TRINKET_BORDER)
        cell.SecureButton:SetPoint("BOTTOMRIGHT", cell, "BOTTOMRIGHT", -TRINKET_BORDER, TRINKET_BORDER)
      end
    end
    if cell.Hotkey then cell.Hotkey:SetFont(font, smallHotkeySize, outlineFlag) end
    -- Dynamic rank badge: scale size & offset proportionally to sub-icon size
    if cell.RankFrame then
      cell.RankFrame:SetAllPoints(cell)
      local badgeSize = math.max(8, math.floor(trinketIconSize * 0.75))
      local badgeOffset = math.max(1, math.floor(trinketIconSize * 0.10))
      cell.Rank:ClearAllPoints()
      cell.Rank:SetSize(badgeSize, badgeSize)
      cell.Rank:SetPoint("CENTER", cell.Icon, "TOPLEFT", badgeOffset, -badgeOffset)
    end
  end

  for i = 1, 2 do
    local cell = RM.Trinkets[i]
    local cx, cy
    if tp == "UP" or tp == "DOWN" then
      cx = tx + (i - 1) * (trinketCellSize + gap)
      cy = ty
    else
      cx = tx
      cy = ty + (2 - i) * (trinketCellSize + gap)
    end
    cell:ClearAllPoints()
    cell:SetPoint("BOTTOMLEFT", RM, "BOTTOMLEFT", cx, cy)
    placeCell(cell, tp, cx, cy)
  end
  for i = 1, 2 do
    local cell = RM.FreeSlots[i]
    local cx, cy
    if op == "UP" or op == "DOWN" then
      cx = ox + (i - 1) * (trinketCellSize + gap)
      cy = oy
    else
      cx = ox
      cy = oy + (2 - i) * (trinketCellSize + gap)
    end
    cell:ClearAllPoints()
    cell:SetPoint("BOTTOMLEFT", RM, "BOTTOMLEFT", cx, cy)
    placeCell(cell, op, cx, cy)
    if showOthers then
      cell:SetAlpha(1)
      if not InCombatLockdown() then
        cell:Show()
      end
    else
      cell:SetAlpha(0)
      if not InCombatLockdown() then
        cell:Hide()
      end
    end
  end
end

local function SetIconSizePx(size)
  size = tonumber(size)
  if not size then return end
  size = math.floor(size + 0.5)
  if size < 24 then size = 24 end
  if size > 256 then size = 256 end
  WKB_RotationMirrorDB.iconSize = size
  Layout(size)
end



-- =========================
-- Slot selection: direct spell OR macro (spell inside macro)
-- =========================
local function FindSlotForSpellOrMacro(spellID)
  -- Direct spell on bars
  if C_ActionBar and C_ActionBar.FindSpellActionButtons then
    local slots = C_ActionBar.FindSpellActionButtons(spellID)
    if slots and slots[1] then
      return slots[1]
    end
  end

  -- Macro fallback: scan default slots
  for slot = 1, 108 do
    local actionType, id = GetActionInfo(slot)
    if actionType == "macro" and id then
      local macroSpellID = GetMacroSpell(id)
      if macroSpellID and macroSpellID == spellID then
        return slot
      end
    end
  end

  return nil
end

-- =========================
-- Press feedback (hooks)
-- =========================
local currentSlot = nil
local currentButton = nil

local function SetPressed(isDown)
  if isDown then
    RM.PressedOverlay:Show()
  else
    RM.PressedOverlay:Hide()
  end
end

-- ActionButtonDown/Up: typically id 1..12 (main/override/bonus handling in FrameXML)
if type(ActionButtonDown) == "function" then
  hooksecurefunc("ActionButtonDown", function(id)
    if not currentButton then return end
    local b = _G["ActionButton"..id] or _G["BonusActionButton"..id] or _G["OverrideActionBarButton"..id]
    if b and b == currentButton then
      SetPressed(true)
    end
  end)
end

if type(ActionButtonUp) == "function" then
  hooksecurefunc("ActionButtonUp", function(id)
    if not currentButton then return end
    local b = _G["ActionButton"..id] or _G["BonusActionButton"..id] or _G["OverrideActionBarButton"..id]
    if b and b == currentButton then
      SetPressed(false)
    end
  end)
end

-- MultiActionButtonDown/Up: used by multi bars (barName, id) -> barName.."Button"..id
if type(MultiActionButtonDown) == "function" then
  hooksecurefunc("MultiActionButtonDown", function(bar, id)
    if not currentButton then return end
    local b = _G[bar .. "Button" .. id]
    if b and b == currentButton then
      SetPressed(true)
    end
  end)
end

if type(MultiActionButtonUp) == "function" then
  hooksecurefunc("MultiActionButtonUp", function(bar, id)
    if not currentButton then return end
    local b = _G[bar .. "Button" .. id]
    if b and b == currentButton then
      SetPressed(false)
    end
  end)
end

-- =========================
-- Core update
-- =========================
local DEFAULT_EMPTY_TEXTURE = "Interface\\Icons\\INV_Misc_QuestionMark"

local lastSpellID, lastSlot, lastTex, lastKey = nil, nil, nil, nil
local lastInRange = nil  -- true/false/nil; only main icon uses out-of-range tint
local borderBlinkIndex = 1      -- 1..5 (シアン→紫→赤→紫→シアン)
local borderBlinkNextTime = 0   -- 次にインデックスを進める時刻

local WRM_DEBUG_GLOW = false  -- set to true to debug glow hook events
local currentGlowedSlot = nil   -- the currently highlighted action slot
local currentGlowedSpellID = nil -- the spellID of the currently glowed spell

local function GoInactive()
  currentSlot, currentButton = nil, nil
  SetPressed(false)
  lastInRange = nil
  RM.Icon:SetVertexColor(1, 1, 1)
  if not InCombatLockdown() and RM.MainSecureButton then
    RM.MainSecureButton:SetAttribute("type", "action")
    RM.MainSecureButton:SetAttribute("action", 0)
  end
  if optionsOpen then
    RM.Icon:SetTexture(DEFAULT_EMPTY_TEXTURE)
    RM.Icon:SetDesaturated(true)
    RM.Hotkey:SetText("")
    RM.Count:SetText("")
    RM.CD:Clear()
    lastSpellID, lastSlot, lastTex, lastKey = nil, nil, nil, nil
    SetActive(true)
  else
    SetActive(false)
  end
end

local function UpdateMirrorFromGlow()
  local slot = currentGlowedSlot
  if not slot then
    GoInactive()
    return
  end

  local tex = GetActionTexture(slot)
  if not tex then
    GoInactive()
    return
  end

  local key = GetHotkeyTextForSlot(slot)
  local btn = FindActionButtonForSlot(slot)

  if currentGlowedSpellID ~= lastSpellID or slot ~= lastSlot or tex ~= lastTex or key ~= lastKey then
    RM.Icon:SetTexture(tex)
    RM.Icon:SetDesaturated(false)
    RM.Hotkey:SetText(key or "")
    lastSpellID, lastSlot, lastTex, lastKey = currentGlowedSpellID, slot, tex, key
  end

  currentSlot = slot
  currentButton = btn

  -- Cooldown (戦闘中も表示: Duration API 優先)
  ApplyCooldownToFrame(RM.CD, "action", slot)

  -- アクションバーと同様のスタック/チャージ数表示（Secret Value 対策込み）
  local count = nil
  if C_ActionBar and C_ActionBar.GetActionDisplayCount then
    local ok, c = pcall(C_ActionBar.GetActionDisplayCount, slot)
    if ok and type(c) == "number" then count = c end
  end
  if not count and GetActionCount then
    local c = GetActionCount(slot)
    if type(c) == "number" then count = c end
  end
  local displayCount = nil
  pcall(function()
    if type(count) == "number" and count > 0 then
      displayCount = count
    end
  end)
  if displayCount then
    RM.Count:SetText(tostring(displayCount))
  else
    RM.Count:SetText("")
  end

  -- 射程判定:
  --  1) まず Blizzard ボタンの HotKey 色を見て「赤いかどうか」をチェック
  --  2) 分からない場合だけ IsActionInRange にフォールバック
  local outOfRange = false

  if currentButton and currentButton.HotKey and currentButton.HotKey.GetTextColor then
    local hr, hg, hb = currentButton.HotKey:GetTextColor()
    if hr and hg and hb then
      -- Blizzard の射程外ホットキーはだいたい (ほぼ赤) なので、簡易的なしきい値で判定
      if hr > 0.8 and hg < 0.3 and hb < 0.3 then
        outOfRange = true
      end
    end
  end

  if not outOfRange and currentSlot and IsActionInRange then
    local ok, range = pcall(IsActionInRange, currentSlot)
    if ok and range == 0 then
      outOfRange = true
    end
  end

  if outOfRange then
    RM.Icon:SetVertexColor(1, 0.25, 0.25)  -- 射程外: 赤
  else
    RM.Icon:SetVertexColor(1, 1, 1)        -- 射程内 or 判定不能: 通常色
  end

  -- 枠色:
  -- 1) 距離外 & 非戦闘   -> 暗いグレー
  -- 2) 距離内 & 非戦闘   -> 明るいイエロー
  -- 3) 距離内 & 戦闘中   -> 赤とシアンを 0.1 秒ごとに点滅
  -- 4) 距離外 & 戦闘中   -> 同上（メインアイコンは赤で距離を表現）
  local hasAttackableTarget = UnitExists("target") and UnitCanAttack("player", "target")
  if hasAttackableTarget then
    if inCombat then
      -- 点滅（シアン -> パープル -> レッド -> パープル -> シアン を 0.2 秒ごとに）
      local now = GetTime and GetTime() or 0
      if now >= (borderBlinkNextTime or 0) then
        borderBlinkIndex = (borderBlinkIndex % 5) + 1
        borderBlinkNextTime = now + 0.1
      end
      local r, g, b
      if borderBlinkIndex == 1 then
        r, g, b = 0.40, 0.80, 1.00   -- シアン
      elseif borderBlinkIndex == 2 then
        r, g, b = 0.75, 0.40, 1.00   -- パープル寄り
      elseif borderBlinkIndex == 3 then
        r, g, b = 1.00, 0.25, 0.25   -- 赤
      elseif borderBlinkIndex == 4 then
        r, g, b = 0.75, 0.40, 1.00   -- パープル
      else
        r, g, b = 0.40, 0.80, 1.00   -- シアン
      end
      RM.Aqua:SetColorTexture(r, g, b, 0.95)
    else
      if outOfRange then
        RM.Aqua:SetColorTexture(0.30, 0.30, 0.30, 0.95) -- 距離外: 暗いグレー
      else
        RM.Aqua:SetColorTexture(1.00, 0.95, 0.40, 0.95) -- 距離内: 明るいイエロー
      end
    end
  else
    -- ターゲットがいない / 攻撃不可: ベースカラー（戦闘中シアン / 非戦闘グレー）
    UpdateBorderColor()
  end

  -- Update main secure button for click-to-use (attributes only when not in combat)
  if not InCombatLockdown() then
    RM.MainSecureButton:SetAttribute("type", "action")
    RM.MainSecureButton:SetAttribute("action", currentSlot or 0)
  end

  SetActive(true)
end

-- =========================
-- Trinket update (12.1-safe): per-slot for frame splitting
-- =========================
local function UpdateTrinketSlotOne(i)
  if not RM.Trinkets or not RM.Trinkets[i] then return end
  local cell = RM.Trinkets[i]
  local slotId = cell.slotId
  local itemId = SafeGetInventoryItemID("player", slotId)
  if itemId then
    cell.itemId = itemId
    local texPath, texFileId = SafeGetItemTexture(itemId)
    if texPath or texFileId then
      if texPath then cell.Icon:SetTexture(texPath) else cell.Icon:SetTexture(texFileId) end
      cell.Icon:SetDesaturated(false)
    else
      cell.Icon:SetTexture(DEFAULT_EMPTY_TEXTURE)
      cell.Icon:SetDesaturated(true)
    end
    ApplyCooldownToFrame(cell.CD, "item", itemId)
    local spellName = GetItemSpell and GetItemSpell(itemId)
    cell.SetUseBorder(spellName and true or false)
    if not InCombatLockdown() and cell.SecureButton then
      cell.SecureButton:SetAttribute("type", "item")
      cell.SecureButton:SetAttribute("item", "item:" .. itemId)
    end
    cell:SetAlpha(1)
    if not InCombatLockdown() then cell:Show() end
  else
    cell.itemId = nil
    if not InCombatLockdown() and cell.SecureButton then
      cell.SecureButton:SetAttribute("type", "macro")
      cell.SecureButton:SetAttribute("macrotext", "")
    end
    if optionsOpen then
      cell.Icon:SetTexture(DEFAULT_EMPTY_TEXTURE)
      cell.Icon:SetDesaturated(true)
      cell.CD:Clear()
      cell.SetUseBorder(false)
      cell:SetAlpha(0.4)
      if not InCombatLockdown() then cell:Show() end
    else
      cell:SetAlpha(0)
      if not InCombatLockdown() then cell:Hide() end
    end
  end
end

local function UpdateTrinkets()
  QueueMirrorUpdate("trinket1")
  QueueMirrorUpdate("trinket2")
end

-- =========================
-- Other row update (item/spell; ★1-3 rank from name, priority option)
-- =========================
local function PickNextItemFromList(list)
  if not list or #list == 0 then return nil end
  local useLow = (WKB_RotationMirrorDB.useLowRankFirst ~= false)
  local items = {}
  local totalCount = 0
  for _, e in ipairs(list) do
    if e.kind == "item" then
      local rank = e.rank
      if rank == nil then rank = GetItemRank(e.id) end
      items[#items + 1] = { id = e.id, rank = rank or 0 }
      local cnt = SafeGetItemCount(e.id) or 0
      totalCount = totalCount + cnt
    end
  end
  if #items == 0 then return list[1].kind, list[1].id, nil, nil end
  table.sort(items, function(a, b)
    local rankA = a.rank or 999  -- Use high number for items without rank
    local rankB = b.rank or 999
    if useLow then 
      -- Low rank first: rank 1 < rank 2 < rank 3 < no rank
      return rankA < rankB
    else
      -- High rank first: rank 3 > rank 2 > rank 1 > no rank
      return rankB < rankA
    end
  end)
  for _, e in ipairs(items) do
    local cnt = SafeGetItemCount(e.id)
    if cnt and cnt > 0 then
      -- ランク無視で総スタック数を表示（全ランク合計）
      local displayCount = (totalCount > 0) and totalCount or cnt
      return "item", e.id, displayCount, e.rank
    end
  end
  -- どのランクにもスタックが無い場合は、単純に1つ目を表示（カウントは0）
  return "item", items[1].id, totalCount, items[1].rank
end

local function UpdateFreeSlotOne(slotIndex)
  if not RM.FreeSlots or not RM.FreeSlots[slotIndex] then return end
  local cell = RM.FreeSlots[slotIndex]
  local key = slotIndex == 1 and "free1" or "free2"
  local text = WKB_RotationMirrorDB[key] or ""
  cell.Count:SetText("")
  cell.Rank:Hide()
  local list = ParseOtherEntryList(text)
  if #list == 1 and list[1].kind == "item" then
    local baseName = GetBaseItemName(SafeGetItemName(list[1].id))
    if baseName and baseName ~= "" then
      local expanded = ScanBagsForItemsMatchingBaseName(baseName)
      if #expanded > 0 then list = expanded end
    end
  end
  local kind, id, count, rank
  if #list > 0 then
    kind, id, count, rank = PickNextItemFromList(list)
    if not kind then kind, id = list[1].kind, list[1].id end
  else
    kind, id = ParseOtherEntry(text)
    if kind == "item" then
      count = SafeGetItemCount(id)
      rank = GetItemRank(id)
    end
  end
  cell.Hotkey:SetText("")
  cell.kind, cell.id = nil, nil
  if not InCombatLockdown() and cell.SecureButton then
    cell.SecureButton:SetAttribute("type", nil)
    cell.SecureButton:SetAttribute("action", nil)
    cell.SecureButton:SetAttribute("item", nil)
    cell.SecureButton:SetAttribute("spell", nil)
  end
  if kind and id then
    cell.kind, cell.id = kind, id
    if not InCombatLockdown() and cell.SecureButton then
      if kind == "action" then
        cell.SecureButton:SetAttribute("type", "action")
        cell.SecureButton:SetAttribute("action", id)
        cell.SecureButton:SetAttribute("item", nil)
        cell.SecureButton:SetAttribute("spell", nil)
      elseif kind == "item" then
        cell.SecureButton:SetAttribute("type", "item")
        cell.SecureButton:SetAttribute("item", "item:" .. id)
        cell.SecureButton:SetAttribute("action", nil)
        cell.SecureButton:SetAttribute("spell", nil)
      elseif kind == "spell" then
        cell.SecureButton:SetAttribute("type", "spell")
        cell.SecureButton:SetAttribute("spell", id)
        cell.SecureButton:SetAttribute("action", nil)
        cell.SecureButton:SetAttribute("item", nil)
      end
    end
    local texPath, texFileId = nil, nil
    if kind == "item" then
      texPath, texFileId = SafeGetItemTexture(id)
    elseif kind == "action" then
      local tex = GetActionTexture(id)
      if tex then texPath = tex end
    else
      local tex = SafeGetSpellTexture(id)
      if tex then
        if type(tex) == "number" then texFileId = tex else texPath = tex end
      end
    end
    if texPath or texFileId then
      if texPath then cell.Icon:SetTexture(texPath) else cell.Icon:SetTexture(texFileId) end
      if kind == "item" and (count == nil or count == 0) then
        cell.Icon:SetDesaturated(true)
      else
        cell.Icon:SetDesaturated(false)
      end
    else
      cell.Icon:SetTexture(DEFAULT_EMPTY_TEXTURE)
      cell.Icon:SetDesaturated(true)
    end
    if kind == "spell" then
      local start, duration, enable = SafeGetSpellCooldown(id)
      pcall(function()
        if start and duration and (not enable or enable == 1) then
          local sn, dn = tonumber(start), tonumber(duration)
          if sn and dn and dn > 0 then cell.CD:SetCooldown(sn, dn) return end
        end
        cell.CD:Clear()
      end)
    else
      ApplyCooldownToFrame(cell.CD, kind, id)
    end
    if kind == "item" and (count or rank) then
      if count and count > 0 then cell.Count:SetText(tostring(count)) end
      if rank and rank >= 1 and rank <= 3 then
        cell.Rank:SetAtlas("Professions-ChatIcon-Quality-Tier" .. rank)
        cell.Rank:Show()
      end
    end
    if kind == "action" then
      cell.Hotkey:SetText(GetHotkeyTextForSlot(id) or "")
    elseif kind == "spell" then
      local slot = FindSlotForSpellOrMacro(id)
      cell.Hotkey:SetText(slot and GetHotkeyTextForSlot(slot) or "")
    end
    if kind == "action" then
      local ac = nil
      if C_ActionBar and C_ActionBar.GetActionDisplayCount then
        local ok, c = pcall(C_ActionBar.GetActionDisplayCount, id)
        if ok and type(c) == "number" then ac = c end
      end
      if not ac and GetActionCount then
        local c = GetActionCount(id)
        if type(c) == "number" then ac = c end
      end
      local displayAc = nil
      pcall(function()
        if type(ac) == "number" and ac > 0 then displayAc = ac end
      end)
      if displayAc then
        cell.Count:SetText(tostring(displayAc))
      elseif not (kind == "item" and count and count > 0) then
        cell.Count:SetText("")
      end
    end
    cell.Icon:SetVertexColor(1, 1, 1)
    cell:SetAlpha(1)
    if not InCombatLockdown() then cell:Show() end
  else
    if optionsOpen then
      cell.Icon:SetTexture(DEFAULT_EMPTY_TEXTURE)
      cell.Icon:SetDesaturated(true)
      cell.CD:Clear()
      cell:SetAlpha(0.4)
      if not InCombatLockdown() then cell:Show() end
    else
      cell:SetAlpha(0)
      if not InCombatLockdown() then cell:Hide() end
    end
  end
end

local function UpdateFreeSlots()
  QueueMirrorUpdate("free1")
  QueueMirrorUpdate("free2")
end

-- =========================
-- Update queue: 1–2 slots per frame so no single peak exceeds ~10ms
-- =========================
local updateQueue = {}
local SLOTS_PER_FRAME = 2
local queueScheduled = false

local function ProcessUpdateQueue()
  local n = math.min(SLOTS_PER_FRAME, #updateQueue)
  for _ = 1, n do
    local what = table.remove(updateQueue, 1)
    if what == "mirror" then
      UpdateMirrorFromGlow()
    elseif what == "trinket1" then
      UpdateTrinketSlotOne(1)
    elseif what == "trinket2" then
      UpdateTrinketSlotOne(2)
    elseif what == "free1" then
      UpdateFreeSlotOne(1)
    elseif what == "free2" then
      UpdateFreeSlotOne(2)
    end
  end
  queueScheduled = false
  if #updateQueue > 0 and C_Timer and C_Timer.After then
    queueScheduled = true
    C_Timer.After(0, ProcessUpdateQueue)
  end
end

function QueueMirrorUpdate(what)
  updateQueue[#updateQueue + 1] = what
  if not queueScheduled and C_Timer and C_Timer.After then
    queueScheduled = true
    C_Timer.After(0, ProcessUpdateQueue)
  end
end

-- =========================
-- Range ticker: refresh range/border-color only (no C_AssistedCombat call)
-- =========================
local RANGE_TICKER_INTERVAL = 0.25
local function StartRangeTicker()
  if RM._rangeTicker then
    RM._rangeTicker:Cancel()
    RM._rangeTicker = nil
  end
  RM._rangeTicker = C_Timer.NewTicker(RANGE_TICKER_INTERVAL, function()
    -- Only update range and border color when a slot is already active
    -- NO C_AssistedCombat call!
    if currentGlowedSlot then
      UpdateMirrorFromGlow()
    end
  end)
end

-- =========================
-- Events
-- =========================
RM:RegisterEvent("PLAYER_LOGIN")
RM:RegisterEvent("PLAYER_ENTERING_WORLD")
RM:RegisterEvent("ZONE_CHANGED_NEW_AREA")
RM:RegisterEvent("ACTIONBAR_SLOT_CHANGED")
RM:RegisterEvent("UPDATE_BINDINGS")
RM:RegisterEvent("SPELLS_CHANGED")
RM:RegisterEvent("ACTIONBAR_UPDATE_COOLDOWN")
RM:RegisterEvent("SPELL_UPDATE_COOLDOWN")
RM:RegisterEvent("PLAYER_REGEN_DISABLED")
RM:RegisterEvent("PLAYER_REGEN_ENABLED")
RM:RegisterUnitEvent("UNIT_INVENTORY_CHANGED", "player")
RM:RegisterEvent("GET_ITEM_INFO_RECEIVED")
RM:RegisterEvent("BAG_UPDATE")
RM:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_SHOW")
RM:RegisterEvent("SPELL_ACTIVATION_OVERLAY_GLOW_HIDE")

RM:SetScript("OnEvent", function(_, event, ...)
  if event == "SPELL_ACTIVATION_OVERLAY_GLOW_SHOW" then
    local spellID = ...
    if spellID then
      local slot = FindSlotForSpellOrMacro(spellID)
      if slot then
        currentGlowedSlot = slot
        currentGlowedSpellID = spellID
        QueueMirrorUpdate("mirror")
      end
    end
    return
  end

  if event == "SPELL_ACTIVATION_OVERLAY_GLOW_HIDE" then
    local spellID = ...
    if spellID and spellID == currentGlowedSpellID then
      currentGlowedSlot = nil
      currentGlowedSpellID = nil
      QueueMirrorUpdate("mirror")
    end
    return
  end

  if event == "PLAYER_REGEN_DISABLED" then
    inCombat = true
    UpdateBorderColor()
    return
  end
  if event == "PLAYER_REGEN_ENABLED" then
    inCombat = false
    UpdateBorderColor()
    QueueMirrorUpdate("mirror")
    QueueMirrorUpdate("trinket1")
    QueueMirrorUpdate("trinket2")
    QueueMirrorUpdate("free1")
    QueueMirrorUpdate("free2")
    return
  end
  if event == "PLAYER_LOGIN" then
    ApplyDefaults()
    RestorePosition()
    SetIconSizePx(WKB_RotationMirrorDB.iconSize or DB_DEFAULTS.iconSize)
    SetActive(false)
    StartRangeTicker()
    UpdateTrinkets()
    UpdateFreeSlots()

    -- LibDBIcon registration
    WKB_RotationMirrorMinimapDB = WKB_RotationMirrorMinimapDB or { hide = false }
    local iconLib = LibStub and LibStub("LibDBIcon-1.0", true)
    if iconLib and WKB_RotationMirror_LDB then
      iconLib:Register("WKB_RotationMirror", WKB_RotationMirror_LDB, WKB_RotationMirrorMinimapDB)
    end

    return
  end

  if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
    C_Timer.After(0.2, function()
      QueueMirrorUpdate("mirror")
      QueueMirrorUpdate("trinket1")
      QueueMirrorUpdate("trinket2")
      QueueMirrorUpdate("free1")
      QueueMirrorUpdate("free2")
    end)
    return
  end

  if event == "UNIT_INVENTORY_CHANGED" then
    local unit = ...
    if unit == "player" then
      QueueMirrorUpdate("trinket1")
      QueueMirrorUpdate("trinket2")
    end
    return
  end

  if event == "GET_ITEM_INFO_RECEIVED" then
    if not InCombatLockdown() then
      QueueMirrorUpdate("trinket1")
      QueueMirrorUpdate("trinket2")
      QueueMirrorUpdate("free1")
      QueueMirrorUpdate("free2")
    end
    return
  end

  if event == "BAG_UPDATE" then
    scanCache = {}
    if not InCombatLockdown() then
      QueueMirrorUpdate("free1")
      QueueMirrorUpdate("free2")
    end
    return
  end

  if event == "ACTIONBAR_SLOT_CHANGED" or event == "SPELLS_CHANGED" or event == "UPDATE_BINDINGS" then
    QueueMirrorUpdate("mirror")
    if not InCombatLockdown() then
      QueueMirrorUpdate("trinket1")
      QueueMirrorUpdate("trinket2")
      QueueMirrorUpdate("free1")
      QueueMirrorUpdate("free2")
    end
    return
  end

  if event == "ACTIONBAR_UPDATE_COOLDOWN" or event == "SPELL_UPDATE_COOLDOWN" then
    QueueMirrorUpdate("mirror")
    return
  end
end)

-- Ensure frame exists (shown), but can be transparent when inactive
RM:Show()

-- =========================
-- Options panel
-- =========================
local OPTIONS_WIDTH, OPTIONS_HEIGHT = 420, 480
local OptionPanel = CreateFrame("Frame", "WKB_RotationMirrorOptions", UIParent)
OptionPanel:SetSize(OPTIONS_WIDTH, OPTIONS_HEIGHT)
OptionPanel:SetPoint("CENTER")
OptionPanel:SetFrameStrata("DIALOG")
OptionPanel:EnableMouse(true)
OptionPanel:SetMovable(true)
OptionPanel:RegisterForDrag("LeftButton")
OptionPanel:SetScript("OnDragStart", function(f) f:StartMoving() end)
OptionPanel:SetScript("OnDragStop", function(f) f:StopMovingOrSizing() end)
OptionPanel:SetScript("OnShow", function()
  optionsOpen = true
  Layout(WKB_RotationMirrorDB.iconSize or DB_DEFAULTS.iconSize)
  UpdateTrinkets()
  UpdateFreeSlots()
end)
OptionPanel:SetScript("OnHide", function()
  optionsOpen = false
  Layout(WKB_RotationMirrorDB.iconSize or DB_DEFAULTS.iconSize)
  UpdateTrinkets()
  UpdateFreeSlots()
end)
OptionPanel:Hide()

local bg = OptionPanel:CreateTexture(nil, "BACKGROUND")
bg:SetAllPoints()
bg:SetColorTexture(0.1, 0.1, 0.2, 0.95)
local border = OptionPanel:CreateTexture(nil, "BORDER")
border:SetAllPoints()
border:SetColorTexture(0.4, 0.5, 0.6, 0.8)

local title = OptionPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
title:SetPoint("TOP", 0, -12)
title:SetText("Wakaba Rotation Mirror Options")

local mainHelpBtn = CreateFrame("Button", nil, OptionPanel, "UIPanelButtonTemplate")
mainHelpBtn:SetSize(24, 24)
mainHelpBtn:SetPoint("TOPRIGHT", -12, -12)
mainHelpBtn:SetText("?")

local MainHelpOverlay = CreateFrame("Frame", nil, OptionPanel, "BackdropTemplate")
MainHelpOverlay:SetPoint("TOPLEFT", 12, -40)
MainHelpOverlay:SetPoint("BOTTOMRIGHT", -12, 45)
if MainHelpOverlay.SetBackdrop then
  MainHelpOverlay:SetBackdrop({
    bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 16,
    insets = { left = 4, right = 4, top = 4, bottom = 4 }
  })
  MainHelpOverlay:SetBackdropColor(0.1, 0.1, 0.1, 0.95)
end
MainHelpOverlay:SetFrameLevel(OptionPanel:GetFrameLevel() + 10)
MainHelpOverlay:Hide()

local HelpScrollFrame = CreateFrame("ScrollFrame", "WKB_RotationMirrorHelpScroll", MainHelpOverlay, "UIPanelScrollFrameTemplate")
HelpScrollFrame:SetPoint("TOPLEFT", 8, -8)
HelpScrollFrame:SetPoint("BOTTOMRIGHT", -32, 8)

local HelpScrollChild = CreateFrame("Frame", nil, HelpScrollFrame)
HelpScrollChild:SetSize(360, 100)
HelpScrollFrame:SetScrollChild(HelpScrollChild)
HelpScrollChild.rows = {}

local helpData = {
  { "Basics:", "Use /wrm to open settings. This addon makes your 'Next Skill' icon bigger. Look at it and press your hotkey!" },
  { "Free Slots\n(Items):", "Drag items from your bag to the boxes." },
  { "Free Slots\n(Action Buttons):", "Click the box first, then click an action button to mirror it." },
  { "Size:", "Change the size of the main icon. Other icons will change size too." },
  { "Hotkey:", "Change the size of hotkey text. Check 'Outline' to make letters clearer." },
  { "Layout:", "Choose where to put Trinkets and Free Slots around the main icon using the checkboxes." },
  { "Trinkets:", "A yellow border means the item has a 'Use' effect." },
  { "Moving:", "You can move the icons by dragging them while this Options menu is open." },
  { "Click:", "You can click the mirrored icons to use the action/item/trinket (or use your hotkey). A brief flash shows when you click." },
}

for i, data in ipairs(helpData) do
  local row = CreateFrame("Frame", nil, HelpScrollChild)
  row:SetWidth(340)
  
  local titleStr = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  titleStr:SetTextColor(1, 0.82, 0)
  titleStr:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  titleStr:SetWidth(120)
  titleStr:SetJustifyH("RIGHT")
  titleStr:SetJustifyV("TOP")
  titleStr:SetWordWrap(true)
  titleStr:SetText(data[1])

  local descStr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  descStr:SetTextColor(1, 1, 1)
  descStr:SetPoint("TOPLEFT", titleStr, "TOPRIGHT", 10, 0)
  descStr:SetWidth(210)
  descStr:SetJustifyH("LEFT")
  descStr:SetJustifyV("TOP")
  descStr:SetWordWrap(true)
  descStr:SetText(data[2])
  
  row.title = titleStr
  row.desc = descStr
  table.insert(HelpScrollChild.rows, row)
end

local function LayoutHelpScroll()
  local self = HelpScrollChild
  if not self or not self.rows then return end
  local totalHeight = 10
  for _, r in ipairs(self.rows) do
    local th = r.title:GetStringHeight() or 10
    local dh = r.desc:GetStringHeight() or 10
    local h = math.max(th, dh)
    if h > 5 then
      r:SetHeight(h)
      r:SetPoint("TOPLEFT", self, "TOPLEFT", 10, -totalHeight)
      totalHeight = totalHeight + h + 16
    end
  end
  if totalHeight > 20 then
    self:SetHeight(totalHeight + 10)
  end
end
HelpScrollChild:SetScript("OnShow", function(self)
  if C_Timer and C_Timer.After then
    C_Timer.After(0, LayoutHelpScroll)
  else
    LayoutHelpScroll()
  end
end)

mainHelpBtn:SetScript("OnClick", function()
  if MainHelpOverlay:IsShown() then
    MainHelpOverlay:Hide()
  else
    MainHelpOverlay:Show()
    if C_Timer and C_Timer.After then
      C_Timer.After(0, LayoutHelpScroll)
    else
      LayoutHelpScroll()
    end
  end
end)

-- Size (icon size 24–256)
local sizeLbl = OptionPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
sizeLbl:SetPoint("TOPLEFT", 20, -44)
sizeLbl:SetText("Size:")
local sizeBox = CreateFrame("EditBox", nil, OptionPanel, "InputBoxTemplate")
sizeBox:SetPoint("LEFT", sizeLbl, "RIGHT", 8, 0)
sizeBox:SetSize(60, 20)
sizeBox:SetAutoFocus(false)
sizeBox:SetNumeric(true)
sizeBox:SetMaxLetters(3)
sizeBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
sizeBox:SetScript("OnEnterPressed", function(self)
  self:ClearFocus()
  local n = tonumber(self:GetText())
  if n then SetIconSizePx(n) end
  self:SetText(tostring(WKB_RotationMirrorDB.iconSize or DB_DEFAULTS.iconSize))
end)
sizeBox:SetScript("OnEditFocusLost", function(self)
  local n = tonumber(self:GetText())
  if n then SetIconSizePx(n) end
  self:SetText(tostring(WKB_RotationMirrorDB.iconSize or DB_DEFAULTS.iconSize))
end)

-- Border thickness (50–200%)
local borderThicknessLabel = OptionPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
borderThicknessLabel:SetPoint("TOPLEFT", 20, -76)
borderThicknessLabel:SetText("Border Thickness:")
local borderThicknessSlider = CreateFrame("Slider", "WKB_RotationMirrorBorderThicknessSlider", OptionPanel, "OptionsSliderTemplate")
borderThicknessSlider:SetPoint("LEFT", borderThicknessLabel, "RIGHT", 12, 0)
borderThicknessSlider:SetMinMaxValues(50, 200)
borderThicknessSlider:SetValueStep(5)
borderThicknessSlider:SetObeyStepOnDrag(true)
borderThicknessSlider:SetWidth(140)
_G[borderThicknessSlider:GetName() .. "Low"]:SetText("50%")
_G[borderThicknessSlider:GetName() .. "High"]:SetText("200%")
_G[borderThicknessSlider:GetName() .. "Text"]:SetText("")
borderThicknessSlider:SetScript("OnValueChanged", function(self, value)
  value = math.floor(value + 0.5)
  if value < 50 then value = 50 end
  if value > 200 then value = 200 end
  WKB_RotationMirrorDB.borderThickness = value / 100
  Layout(WKB_RotationMirrorDB.iconSize or DB_DEFAULTS.iconSize)
end)

-- Sub Icon Size (30–70%)
local subIconSizeLabel = OptionPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
subIconSizeLabel:SetPoint("TOPLEFT", 20, -108)
subIconSizeLabel:SetText("Sub Icon Size:")
local subIconSizeSlider = CreateFrame("Slider", "WKB_RotationMirrorSubIconSizeSlider", OptionPanel, "OptionsSliderTemplate")
subIconSizeSlider:SetPoint("LEFT", subIconSizeLabel, "RIGHT", 12, 0)
subIconSizeSlider:SetMinMaxValues(30, 70)
subIconSizeSlider:SetValueStep(1)
subIconSizeSlider:SetObeyStepOnDrag(true)
subIconSizeSlider:SetWidth(140)
_G[subIconSizeSlider:GetName() .. "Low"]:SetText("30%")
_G[subIconSizeSlider:GetName() .. "High"]:SetText("70%")
_G[subIconSizeSlider:GetName() .. "Text"]:SetText("")
subIconSizeSlider:SetScript("OnValueChanged", function(self, value)
  value = math.floor(value + 0.5)
  if value < 30 then value = 30 end
  if value > 70 then value = 70 end
  WKB_RotationMirrorDB.subIconScale = value / 100
  Layout(WKB_RotationMirrorDB.iconSize or DB_DEFAULTS.iconSize)
end)

-- Icon Spacing (0–32px)
local iconGapLabel = OptionPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
iconGapLabel:SetPoint("TOPLEFT", 20, -140)
iconGapLabel:SetText("Icon Spacing:")
local iconGapSlider = CreateFrame("Slider", "WKB_RotationMirrorIconGapSlider", OptionPanel, "OptionsSliderTemplate")
iconGapSlider:SetPoint("LEFT", iconGapLabel, "RIGHT", 12, 0)
iconGapSlider:SetMinMaxValues(0, 32)
iconGapSlider:SetValueStep(1)
iconGapSlider:SetObeyStepOnDrag(true)
iconGapSlider:SetWidth(140)
_G[iconGapSlider:GetName() .. "Low"]:SetText("0")
_G[iconGapSlider:GetName() .. "High"]:SetText("32")
_G[iconGapSlider:GetName() .. "Text"]:SetText("")
iconGapSlider:SetScript("OnValueChanged", function(self, value)
  value = math.floor(value + 0.5)
  if value < 0 then value = 0 end
  if value > 32 then value = 32 end
  WKB_RotationMirrorDB.iconGap = value
  Layout(WKB_RotationMirrorDB.iconSize or DB_DEFAULTS.iconSize)
end)

-- Hotkey scale (50–150%)
local hotkeyScaleLabel = OptionPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
hotkeyScaleLabel:SetPoint("TOPLEFT", 20, -172)
hotkeyScaleLabel:SetText("Hotkey Scale:")

local hotkeyScaleSlider = CreateFrame("Slider", "WKB_RotationMirrorHotkeyScaleSlider", OptionPanel, "OptionsSliderTemplate")
hotkeyScaleSlider:SetPoint("LEFT", hotkeyScaleLabel, "RIGHT", 12, 0)
hotkeyScaleSlider:SetMinMaxValues(50, 150)
hotkeyScaleSlider:SetValueStep(5)
hotkeyScaleSlider:SetObeyStepOnDrag(true)
hotkeyScaleSlider:SetWidth(160)
_G[hotkeyScaleSlider:GetName() .. "Low"]:SetText("50%")
_G[hotkeyScaleSlider:GetName() .. "High"]:SetText("150%")
_G[hotkeyScaleSlider:GetName() .. "Text"]:SetText("")
hotkeyScaleSlider:SetScript("OnValueChanged", function(self, value)
  value = math.floor(value + 0.5)
  if value < 50 then value = 50 end
  if value > 150 then value = 150 end
  WKB_RotationMirrorDB.hotkeyScale = value / 100
  Layout(WKB_RotationMirrorDB.iconSize or DB_DEFAULTS.iconSize)
end)

-- Hotkey outline toggle
local hotkeyOutlineCheck = CreateFrame("CheckButton", nil, OptionPanel, "UICheckButtonTemplate")
hotkeyOutlineCheck:SetPoint("LEFT", hotkeyScaleSlider, "RIGHT", 24, 0)
hotkeyOutlineCheck.text:SetText("Outline")
hotkeyOutlineCheck:SetScript("OnClick", function(self)
  WKB_RotationMirrorDB.hotkeyOutline = self:GetChecked() and true or false
  Layout(WKB_RotationMirrorDB.iconSize or DB_DEFAULTS.iconSize)
end)

-- Center Main Hotkey toggle
local centerHotkeyCheck = CreateFrame("CheckButton", nil, OptionPanel, "UICheckButtonTemplate")
centerHotkeyCheck:SetPoint("BOTTOMLEFT", hotkeyOutlineCheck, "TOPLEFT", 0, 4)
centerHotkeyCheck.text:SetText("Center Hotkey")
centerHotkeyCheck:SetScript("OnClick", function(self)
  WKB_RotationMirrorDB.centerHotkey = self:GetChecked() and true or false
  Layout(WKB_RotationMirrorDB.iconSize or DB_DEFAULTS.iconSize)
end)

local POSITIONS = { "UP", "DOWN", "LEFT", "RIGHT" }
local function MakePositionRow(parent, label, key, y)
  local lbl = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  lbl:SetPoint("TOPLEFT", 20, y)
  lbl:SetText(label)
  local buttons = {}
  for i, pos in ipairs(POSITIONS) do
    local btn = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
    btn:SetPoint("LEFT", lbl, "RIGHT", 20 + (i - 1) * 72, 0)
    btn.text:SetText(pos)
    btn.pos = pos
    btn.key = key
    btn:SetScript("OnClick", function(self)
      WKB_RotationMirrorDB[self.key] = self.pos
      for _, b in ipairs(buttons) do b:SetChecked(b.pos == self.pos) end
      Layout(WKB_RotationMirrorDB.iconSize or DB_DEFAULTS.iconSize)
    end)
    buttons[i] = btn
  end
  return buttons
end

-- 位置指定行は Hotkey 行より少し下に配置し、行間を広めにとる
local trinketY, freeY = -212, -252
local trinketBtns = MakePositionRow(OptionPanel, "Trinket", "trinketPosition", trinketY)
local freeBtns = MakePositionRow(OptionPanel, "Free Slot", "freePosition", freeY)

local function RefreshPositionButtons()
  local tp = WKB_RotationMirrorDB.trinketPosition or DB_DEFAULTS.trinketPosition
  local op = WKB_RotationMirrorDB.freePosition or DB_DEFAULTS.freePosition
  for _, b in ipairs(trinketBtns) do b:SetChecked(b.pos == tp) end
  for _, b in ipairs(freeBtns) do b:SetChecked(b.pos == op) end
end

local currentFocusedOtherBox = nil
local RefreshItemValueLabels  -- forward declaration; assigned after free edit boxes

local function CreateOtherEditBox(name, key, which, y)
  local lbl = OptionPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  lbl:SetPoint("TOPLEFT", 20, y)
  lbl:SetText(name .. ":")
  local eb = CreateFrame("EditBox", nil, OptionPanel, "InputBoxTemplate")
  eb:SetPoint("LEFT", lbl, "RIGHT", 8, 0)
  eb:SetPoint("RIGHT", OptionPanel, "RIGHT", -20, 0)
  eb:SetHeight(20)
  eb:SetAutoFocus(false)
  local defaultText
  if which == 1 then
    defaultText = "Drag items from your bags."
  else
    defaultText = "Click action buttons while focused."
  end
  eb.defaultText = defaultText
  local initial = WKB_RotationMirrorDB[key]
  if not initial or initial == "" then
    eb:SetText(defaultText)
    eb:SetCursorPosition(0)
    eb.isPlaceholder = true
    eb:SetTextColor(0.7, 0.7, 0.7)
  else
    eb:SetText(initial)
    eb.isPlaceholder = false
    eb:SetTextColor(1, 1, 1)
  end
  eb.key = key
  eb:EnableMouse(true)
  eb:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
  eb:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  eb:SetScript("OnEditFocusGained", function(self)
    currentFocusedOtherBox = self
    if self.isPlaceholder then
      self:SetText("")
      self:SetTextColor(1, 1, 1)
    end
  end)
  eb:SetScript("OnEditFocusLost", function(self)
    C_Timer.After(0.2, function()
      if currentFocusedOtherBox == self and not self:HasFocus() then
        currentFocusedOtherBox = nil
      end
    end)
    local text = self:GetText():gsub("^%s+", ""):gsub("%s+$", "")
    if text == "" or text == self.defaultText then
      WKB_RotationMirrorDB[self.key] = ""
      self:SetText(self.defaultText)
      self.isPlaceholder = true
      self:SetTextColor(0.7, 0.7, 0.7)
      self:SetCursorPosition(0)
    else
      WKB_RotationMirrorDB[self.key] = text
      self.isPlaceholder = false
      self:SetTextColor(1, 1, 1)
    end
    UpdateFreeSlots()
    if RefreshItemValueLabels then RefreshItemValueLabels() end
  end)
  -- Enable drag and drop for item links (always store as item:ID when可能)
  local function HandleItemDrop(self)
    local infoType, info1, info2 = GetCursorInfo()
    if infoType ~= "item" then return end

    local itemID
    -- Pattern 1: bag,slot (most common whenドラッグ from bags)
    if type(info1) == "number" and type(info2) == "number" then
      local bag, slot = info1, info2
      local ok, id = pcall(function()
        if C_Container and C_Container.GetContainerItemID then
          return C_Container.GetContainerItemID(bag, slot)
        elseif GetContainerItemID then
          return GetContainerItemID(bag, slot)
        end
      end)
      if ok and id and type(id) == "number" then
        itemID = id
      end
    end

    -- Pattern 2: direct itemID or itemLink
    if not itemID then
      local linkOrId = info1 or info2
      if type(linkOrId) == "number" then
        itemID = linkOrId
      elseif type(linkOrId) == "string" then
        local id = linkOrId:match("item:(%d+)")
        if id then itemID = tonumber(id) end
      end
    end

    local text
    if itemID then
      text = "item:" .. itemID
    else
      -- Fallback: if everything fails, at least store whatever we have
      text = (type(info2) == "string" and info2) or (type(info1) == "string" and info1) or nil
    end

    if text then
      self:SetText(text)
      WKB_RotationMirrorDB[self.key] = text
      self.isPlaceholder = false
      self:SetTextColor(1, 1, 1)
      UpdateFreeSlots()
      if RefreshItemValueLabels then RefreshItemValueLabels() end
      ClearCursor()
    end
  end
  eb:SetScript("OnReceiveDrag", function(self)
    HandleItemDrop(self)
  end)
  eb:SetScript("OnMouseUp", function(self, button)
    if button == "RightButton" then
      HandleItemDrop(self)
    end
  end)
  return eb
end

-- Free1/Free2 は説明文の十分下に配置
local free1Box = CreateOtherEditBox("Free 1", "free1", 1, -280)
local free2Box = CreateOtherEditBox("Free 2", "free2", 2, -312)

-- Resolve human-readable name for a free-slot DB value
local function ResolveEntryDisplayName(text)
  if not text or type(text) ~= "string" or text:match("^%s*$") then return "", nil end
  local kind, id = ParseOtherEntry(text)
  if not kind or not id then return "", nil end
  if kind == "item" then
    local name = SafeGetItemName(id)
    local rank = GetItemRank(id)
    return (name or ("item:" .. id)), rank
  elseif kind == "spell" then
    local name = GetSpellInfo and GetSpellInfo(id)
    return (name or ("spell:" .. id)), nil
  elseif kind == "action" then
    return text, nil
  end
  return "", nil
end

-- Item Value display labels (read-only, below Free Slot inputs)
local free1ValueLabel = OptionPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
free1ValueLabel:SetPoint("TOPLEFT", 20, -344)
free1ValueLabel:SetWidth(OPTIONS_WIDTH - 40)
free1ValueLabel:SetJustifyH("LEFT")
free1ValueLabel:SetText("")

local free2ValueLabel = OptionPanel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
free2ValueLabel:SetPoint("TOPLEFT", 20, -364)
free2ValueLabel:SetWidth(OPTIONS_WIDTH - 40)
free2ValueLabel:SetJustifyH("LEFT")
free2ValueLabel:SetText("")

RefreshItemValueLabels = function()
  local val1 = WKB_RotationMirrorDB.free1 or ""
  local val2 = WKB_RotationMirrorDB.free2 or ""
  local name1, rank1 = ResolveEntryDisplayName(val1)
  local name2, rank2 = ResolveEntryDisplayName(val2)
  local star1 = GetRankAtlasMarkup(rank1)
  local star2 = GetRankAtlasMarkup(rank2)
  free1ValueLabel:SetText(name1 ~= "" and ("Free 1: |cffffffff" .. name1 .. "|r " .. star1) or "")
  free2ValueLabel:SetText(name2 ~= "" and ("Free 2: |cffffffff" .. name2 .. "|r " .. star2) or "")
end

-- Use Highest Rank First checkbox
local useHighRankCheck = CreateFrame("CheckButton", nil, OptionPanel, "UICheckButtonTemplate")
useHighRankCheck:SetPoint("TOPLEFT", 16, -390)
useHighRankCheck.text:SetText("Use Highest Rank First")
useHighRankCheck:SetScript("OnClick", function(self)
  WKB_RotationMirrorDB.useLowRankFirst = not self:GetChecked()
  UpdateFreeSlots()
end)

local hooksSetup = false
local function SetupActionButtonsHook()
  if hooksSetup then return end
  hooksSetup = true
  
  local function OnActionBtnClick(self)
    if not optionsOpen then return end
    if currentFocusedOtherBox then
      local name = self:GetName()
      if not name then return end
      
      for barIdx, barPre in ipairs(BUTTON_GROUPS) do
        if name:find("^" .. barPre) then
          local s = name:match("^" .. barPre .. "(%d+)$")
          if s then
            local slot = tonumber(s)
            if slot then
              local val = string.format("%d-%d", barIdx, slot)
              currentFocusedOtherBox:SetText(val)
              WKB_RotationMirrorDB[currentFocusedOtherBox.key] = val
              currentFocusedOtherBox.isPlaceholder = false
              currentFocusedOtherBox:SetTextColor(1, 1, 1)
              UpdateFreeSlots()
              if RefreshItemValueLabels then RefreshItemValueLabels() end
              currentFocusedOtherBox:ClearFocus()
              currentFocusedOtherBox = nil
            end
            break
          end
        end
      end
    end
  end
  
  for barIdx, barPre in ipairs(BUTTON_GROUPS) do
    for slot = 1, 12 do
      local btn = _G[barPre .. slot]
      if btn then
        if btn:HasScript("OnClick") then
          btn:HookScript("OnClick", OnActionBtnClick)
        end
        if btn:HasScript("OnMouseDown") then
          btn:HookScript("OnMouseDown", OnActionBtnClick)
        end
      end
    end
  end
end

local closeBtn = CreateFrame("Button", nil, OptionPanel, "UIPanelButtonTemplate")
closeBtn:SetSize(100, 24)
closeBtn:SetPoint("BOTTOM", 0, 16)
closeBtn:SetText("Close")
closeBtn:SetScript("OnClick", function() OptionPanel:Hide() end)

-- Minimap Icon toggle (bottom-right, text stays inside window)
local minimapIconCheck = CreateFrame("CheckButton", nil, OptionPanel, "UICheckButtonTemplate")
minimapIconCheck:SetPoint("RIGHT", OptionPanel, "BOTTOMRIGHT", -20, 16)
minimapIconCheck.text:ClearAllPoints()
minimapIconCheck.text:SetPoint("RIGHT", minimapIconCheck, "LEFT", -2, 0)
minimapIconCheck.text:SetText("Minimap Icon")
minimapIconCheck:SetScript("OnClick", function(self)
  WKB_RotationMirrorMinimapDB = WKB_RotationMirrorMinimapDB or { hide = false }
  WKB_RotationMirrorMinimapDB.hide = not self:GetChecked()

  local iconLib = LibStub and LibStub("LibDBIcon-1.0", true)
  if iconLib then
    if WKB_RotationMirrorMinimapDB.hide then
      iconLib:Hide("WKB_RotationMirror")
    else
      iconLib:Show("WKB_RotationMirror")
    end
  end
end)

function OpenOptions()
  WKB_RotationMirrorDB.free1 = WKB_RotationMirrorDB.free1 or ""
  WKB_RotationMirrorDB.free2 = WKB_RotationMirrorDB.free2 or ""
  sizeBox:SetText(tostring(WKB_RotationMirrorDB.iconSize or DB_DEFAULTS.iconSize))
  do
    local function RefreshFreeEditBox(eb)
      local val = WKB_RotationMirrorDB[eb.key]
      if val and val ~= "" then
        eb:SetText(val)
        eb.isPlaceholder = false
        eb:SetTextColor(1, 1, 1)
      else
        eb:SetText(eb.defaultText)
        eb.isPlaceholder = true
        eb:SetTextColor(0.7, 0.7, 0.7)
        eb:SetCursorPosition(0)
      end
    end
    RefreshFreeEditBox(free1Box)
    RefreshFreeEditBox(free2Box)
  end
  RefreshPositionButtons()
   -- ホットキースケールとアウトラインの現在値を反映
  local scale = WKB_RotationMirrorDB.hotkeyScale or DB_DEFAULTS.hotkeyScale
  local sliderValue = math.floor((scale or 1) * 100 + 0.5)
  if sliderValue < 50 then sliderValue = 50 end
  if sliderValue > 150 then sliderValue = 150 end
  hotkeyScaleSlider:SetValue(sliderValue)
  hotkeyOutlineCheck:SetChecked(WKB_RotationMirrorDB.hotkeyOutline ~= false)
  -- Icon Spacing
  local gapVal = tonumber(WKB_RotationMirrorDB.iconGap) or DB_DEFAULTS.iconGap
  if gapVal < 0 then gapVal = 0 end
  if gapVal > 32 then gapVal = 32 end
  iconGapSlider:SetValue(gapVal)
  local borderVal = math.floor((WKB_RotationMirrorDB.borderThickness or DB_DEFAULTS.borderThickness) * 100 + 0.5)
  if borderVal < 50 then borderVal = 50 end
  if borderVal > 200 then borderVal = 200 end
  borderThicknessSlider:SetValue(borderVal)
  local subScale = tonumber(WKB_RotationMirrorDB.subIconScale) or DB_DEFAULTS.subIconScale
  if subScale < 0.3 then subScale = 0.3 end
  if subScale > 0.7 then subScale = 0.7 end
  subIconSizeSlider:SetValue(math.floor(subScale * 100 + 0.5))
  WKB_RotationMirrorMinimapDB = WKB_RotationMirrorMinimapDB or { hide = false }
  minimapIconCheck:SetChecked(not WKB_RotationMirrorMinimapDB.hide)
  centerHotkeyCheck:SetChecked(WKB_RotationMirrorDB.centerHotkey == true)
  useHighRankCheck:SetChecked(WKB_RotationMirrorDB.useLowRankFirst == false)
  RefreshItemValueLabels()
  OptionPanel:Show()
  SetupActionButtonsHook()
end

-- =========================
-- Interface Options (Settings)
-- =========================
local SettingsPanel = CreateFrame("Frame", "WKB_RotationMirrorSettingsPanel")
SettingsPanel.name = "Wakaba Rotation Mirror"

local banner = SettingsPanel:CreateTexture(nil, "ARTWORK")
banner:SetSize(128, 128)
banner:SetPoint("TOPLEFT", 16, -16)
banner:SetTexture("Interface\\AddOns\\WKB_RotationMirror\\media\\art.tga")

local title = SettingsPanel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
title:SetPoint("TOPLEFT", banner, "TOPRIGHT", 16, -8)
title:SetText("Wakaba Rotation Mirror")

local openBtn = CreateFrame("Button", nil, SettingsPanel, "UIPanelButtonTemplate")
openBtn:SetSize(160, 30)
openBtn:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -16)
openBtn:SetText("Open Main Window")
openBtn:SetScript("OnClick", function()
  OpenOptions()
  if SettingsPanel:IsVisible() then
    if Settings and Settings.Panel and Settings.Panel.Close then
      Settings.Panel:Close()
    else
      HideUIPanel(SettingsPanel:GetParent())
    end
  end
end)

local systemHelpData = {
  { "Command:", "Use /wrm to open settings." },
  { "Free Slots:", "Drag items from your bag or click action buttons." },
  { "Size:", "Change the size of all icons here." },
  { "Click:", "You can click the icons to use them, or use your keyboard. A flash shows on click." },
}

local listAnchor = openBtn
local yOffset = -24

for i, data in ipairs(systemHelpData) do
  local row = CreateFrame("Frame", nil, SettingsPanel)
  row:SetPoint("TOPLEFT", listAnchor, "BOTTOMLEFT", 0, yOffset)
  row:SetWidth(400)
  
  local titleStr = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  titleStr:SetTextColor(1, 0.82, 0)
  titleStr:SetPoint("TOPLEFT", row, "TOPLEFT", 0, 0)
  titleStr:SetWidth(100)
  titleStr:SetJustifyH("RIGHT")
  titleStr:SetJustifyV("TOP")
  titleStr:SetWordWrap(true)
  titleStr:SetText(data[1])

  local descStr = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  descStr:SetTextColor(1, 1, 1)
  descStr:SetPoint("TOPLEFT", titleStr, "TOPRIGHT", 10, 0)
  descStr:SetWidth(290)
  descStr:SetJustifyH("LEFT")
  descStr:SetJustifyV("TOP")
  descStr:SetWordWrap(true)
  descStr:SetText(data[2])
  
  -- Use a fixed height assumption or defer updating, but for static text in options,
  -- StringHeight is usually available early enough or we can give generous fixed height.
  row:SetHeight(math.max(16, titleStr:GetStringHeight() or 16, descStr:GetStringHeight() or 16))
  
  listAnchor = row
  yOffset = -16
end

if Settings and Settings.RegisterCanvasLayoutCategory then
  local category = Settings.RegisterCanvasLayoutCategory(SettingsPanel, "Wakaba Rotation Mirror")
  Settings.RegisterAddOnCategory(category)
else
  InterfaceOptions_AddCategory(SettingsPanel)
end

-- =========================
-- Slash commands
-- =========================
SLASH_WKB_ROTATIONMIRROR1 = "/wrm"
SlashCmdList["WKB_ROTATIONMIRROR"] = function(msg)
  msg = (msg or ""):gsub("^%s+", ""):gsub("%s+$", "")
  local cmd, arg = msg:match("^(%S+)%s*(.-)$")
  cmd = cmd and cmd:lower() or ""

  if cmd == "" then
    OpenOptions()
    return
  end

  if cmd == "help" then
    print("|cffffff00Wakaba Rotation Mirror|r:")
    print("  /wrm       (open options)")
    print("  /wrm reset (reset position)")
    return
  end

  if cmd == "size" and arg and arg ~= "" then
    SetIconSizePx(arg)
    return
  end

  if cmd == "reset" then
    WKB_RotationMirrorDB.point = DB_DEFAULTS.point
    WKB_RotationMirrorDB.relativePoint = DB_DEFAULTS.relativePoint
    WKB_RotationMirrorDB.x = DB_DEFAULTS.x
    WKB_RotationMirrorDB.y = DB_DEFAULTS.y
    WKB_RotationMirrorDB.mainIconLeft = nil
    WKB_RotationMirrorDB.mainIconBottom = nil
    RestorePosition()
    return
  end

  print("|cffffff00Wakaba Rotation Mirror|r: unknown command. Use /wrm help")
end

function WKB_RotationMirror_OnCompartmentClick(addonName, buttonName)
  OpenOptions()
end
