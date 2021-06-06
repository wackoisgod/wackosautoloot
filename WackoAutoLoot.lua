WACKO_ = WACKO_ or {}

local function print(...) _G.print("|cff259054BugSack:|r", ...) end

local lootQualityThreshhold = 2 -- Uncommon
local addon = CreateFrame("Frame")


local GetNumLootItems = GetNumLootItems
local GetLootInfo = GetLootInfo
local GetLootSlotInfo = GetLootSlotInfo

-- NOTE The event fires twice upon opening a lootable container
addon:RegisterEvent("LOOT_READY")
addon:RegisterEvent("PLAYER_LOGIN")


function Wacko_init()
	WackoData = WackoData or {}
	WackoDataCData = WackoDataCData or {}

	WackoDataCData.currentCustomItems = WackoDataCData.currentCustomItems or ""
	WackoData.selectedLootThreashold = WackoData.selectedLootThreashold or 2
end


function Utility_Round(value, decimal)
	if (decimal) then
		return math.floor((value * 10^decimal) + 0.5) / (10^decimal)
	else
		return math.floor(value+0.5)
	end
end

function Utility_GetCoinsFromLootString(name, quantity, returnType)
	if not name or (quantity and type(quantity) == 'number' and quantity > 0) then return end
	returnType = returnType or 'copper'
	local coinTypes = {'Gold', 'Silver', 'Copper'}
	local coinTypeValues = {
		Gold = 10000,
		Silver = 100,
		Copper = 1,
	}
	local totalCopper
	if quantity == 0 and (string.find(name,'Gold') or string.find(name,'Silver') or string.find(name,'Copper')) then
		-- Coins
		local coinage = {}
		local coin1, coin2, coin3 = strsplit('\n', name)
		if coin1 then tinsert(coinage, coin1) end
		if coin2 then tinsert(coinage, coin2) end
		if coin3 then tinsert(coinage, coin3) end
		for _, coinString in ipairs(coinage) do
			for _, denomination in ipairs(coinTypes) do
				if string.find(coinString, denomination) then					
					local startPos, endPos = string.find(coinString, '(%d+)')
					if startPos then
						totalCopper = (totalCopper or 0) + (coinTypeValues[denomination] * tonumber(string.sub(coinString, startPos, endPos)))
					end
				end
			end
		end
	end
	if returnType == 'gold' then
		return Utility_Round(totalCopper / 10000, 2)
	elseif returnType == 'silver' then
		return Utility_Round(totalCopper / 100, 2)
	else -- copper
		return totalCopper
	end
end

-- TODO Write description
addon:SetScript("OnEvent", function (self,event,arg1,arg2,arg3,arg4)
	if event == "LOOT_READY" then
		local LootInfo = GetLootInfo()
		
		if (not LootInfo) then
			return
		end
		
		for i = 1, #LootInfo do
			Icon, Name, Quantity, CurrencyID, Quality, Locked, QuestItem, QuestID, IsActive = GetLootSlotInfo(i)
			local coins = Utility_GetCoinsFromLootString(Name, Quantity)

			if coins and not WackoData.disableAutoLootMoney then
				-- print(Icon, Name, Quantity, CurrencyID, Quality)
				LootSlot(i)
			else
				if Quality >= WackoData.selectedLootThreashold and not WackoData.disableAutoLootItem then
					-- we care about item quality
					-- print(Icon, Name, Quantity, CurrencyID, Quality)
					LootSlot(i)
				elseif QuestItem and not WackoData.disableAutoLootQuest then
					LootSlot(i)
				elseif not WackoData.disableAutoCustomLootItem then
					-- We are just going to do a check on the custom items
					local tbl = { strsplit("\r", WackoDataCData.currentCustomItems) }
					if tbl then 
						for l=0, getn(tbl) do
							local v = tbl[l]
							
							if v and string.find(v, Name) then
								LootSlot(i)
							end
						end
					end
				end
			end
		end
	elseif event == "PLAYER_LOGIN" then
		Wacko_init()
		WACKO_.CreateOptionsPanel()
	end
end)

function WACKO_.OnClickDropdown(self)
	UIDropDownMenu_SetSelectedValue(parentAutoQuality, self.value);
end

function CustomLoot_InsertLink(text)
	if ( not text ) then
		return false;
	end

	local item;
	if ( strfind(text, "item:", 1, true) ) then
		item = GetItemInfo(text);
	end
	if ( item ) then
		local currentText = WACKO_.f.Text:GetText();
		if not currentText then 
			return false
		end

		currentText = currentText.."\r"..item
		WackoDataCData.currentCustomItems = currentText
		WACKO_.f.Text:SetText(currentText)
		return true;
	end
end

local OriginalHandleModifiedItemClick = HandleModifiedItemClick
function HandleModifiedItemClick(link, ...)
	if WACKO_.f.Text.Focused then
		if ( not link ) then
			return false;
		end
		if ( IsModifiedClick("CHATLINK") ) then
			local linkType = string.match(link, "|H([^:]+)");
			if ( linkType == "instancelock" ) then	--People can't re-link instances that aren't their own.
				local guid = string.match(link, "|Hinstancelock:([^:]+)");
				if ( not string.find(UnitGUID("player"), guid) ) then
					return true;
				end
			end
			if ( CustomLoot_InsertLink(link) ) then
				return true;
			end
		end
	else
		return OriginalHandleModifiedItemClick(link, ...)
	end
end


function WACKO_.CreateOptionsPanel()
	local panel = CreateFrame("Frame","WACKOOptions")
    panel.name = "Wacko AutoLoot"
    InterfaceOptions_AddCategory(panel)

	panel.title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    panel.title:SetPoint("TOPLEFT", 16, -16)
    panel.title:SetText("Wacko's AutoLoot")

	local index = 0
    local options = {}
    local button = CreateFrame("CheckButton", "$parentAutoLootMoney", panel, "ChatConfigCheckButtonTemplate");
    table.insert(options,button)
    index = index + 1
    button:SetPoint("TOPLEFT",panel.title,"BOTTOMLEFT",0,-25)
    button:SetScript("PostClick",function(self) 
        WackoData.disableAutoLootMoney = not self:GetChecked()
    end)
    button:SetChecked(not WackoData.disableAutoLootMoney)
    button.Text:SetText("Auto Loot all money")
    button.tooltip = "This selects if you want to always loot money"

	button = CreateFrame("CheckButton", "$parentAutoQuest", panel, "ChatConfigCheckButtonTemplate");
    table.insert(options,button)
    button:SetPoint("TOPLEFT",options[index],"BOTTOMLEFT",0,0)
    index = index + 1
    button:SetScript("PostClick",function(self) 
        WackoData.disableAutoLootQuest = not self:GetChecked()
    end)
    button:SetChecked(not WackoData.disableAutoLootQuest)
    button.Text:SetText("Auto Loot Quest Items")
    button.tooltip = "Auto Loot items for current quests you have"

	button = CreateFrame("CheckButton", "$parentAutoItemLoot", panel, "ChatConfigCheckButtonTemplate");
    table.insert(options,button)
    button:SetPoint("TOPLEFT",options[index],"BOTTOMLEFT",0,0)
    index = index + 1
    button:SetScript("PostClick",function(self) 
        WackoData.disableAutoLootItem = not self:GetChecked()
		if WackoData.disableAutoLootItem  then
			WACKO_.drop:Hide();
			WACKO_.dropdownLabel:Hide();
		else 
			WACKO_.dropdownLabel:Show();
			WACKO_.drop:Show();
		end
    end)
    button:SetChecked(not WackoData.disableAutoLootItem)
    button.Text:SetText("Auto Loot Items")
    button.tooltip = "Auto Loot items at a current threshold"

	WACKO_.drop = CreateFrame("Frame", nil, panel, "UIDropDownMenuTemplate")
	table.insert(options,WACKO_.drop)
	WACKO_.drop:SetPoint("TOPLEFT",options[index],"BOTTOMLEFT",-16, -20)
	index = index + 1

	local function OpenDropdown(dropdownFrame, level, menuList)
		for i=0, getn(ITEM_QUALITY_COLORS) - 3  do
			local info = UIDropDownMenu_CreateInfo();
			info.text = ITEM_QUALITY_COLORS[i].color:GenerateHexColorMarkup().."".._G["ITEM_QUALITY"..i.."_DESC"].."|r";
			info.owner = dropdownFrame;
			info.func = function()
				WackoData.selectedLootThreashold = i
				UIDropDownMenu_SetText(dropdownFrame, ITEM_QUALITY_COLORS[i].color:GenerateHexColorMarkup().."".._G["ITEM_QUALITY"..WackoData.selectedLootThreashold.."_DESC"].."|r");
			end;
			info.value = i;
			if info.value == WackoData.selectedLootThreashold then
				info.checked = 1;
				UIDropDownMenu_SetText(dropdownFrame, info.text);
			else
				info.checked = nil;
			end
			UIDropDownMenu_AddButton(info, UIDROPDOWN_MENU_LEVEL);
		end
		
	end

	UIDropDownMenu_Initialize(WACKO_.drop, OpenDropdown);

	WACKO_.dropdownLabel = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
	WACKO_.dropdownLabel:SetText("Item Loot Threashold:");
	WACKO_.dropdownLabel:SetPoint("BOTTOMLEFT", WACKO_.drop, "TOPLEFT", 16, 3);

	button = CreateFrame("CheckButton", "$parentAutoItemLoot", panel, "ChatConfigCheckButtonTemplate");
    table.insert(options,button)
    button:SetPoint("TOPLEFT",options[index],"BOTTOMLEFT",16, 3)
    index = index + 1
    button:SetScript("PostClick",function(self) 
        WackoData.disableAutoCustomLootItem = not self:GetChecked()
		if WackoData.disableAutoCustomLootItem  then
			WACKO_.f:Hide();
		else 
			WACKO_.f:Show();
		end
    end)
    button:SetChecked(not WackoData.disableAutoCustomLootItem)
    button.Text:SetText("Auto Custom Loot Items")
    button.tooltip = "Auto Loot items at a current threshold"


	local backdrop = {
		bgFile   = "Interface/BUTTONS/WHITE8X8",
		edgeFile = "Interface/GLUES/Common/Glue-Tooltip-Border",
		tile     = true,
		edgeSize = 8,
		tileSize = 8,
		insets   = {
		  left   = 5,
		  right  = 5,
		  top    = 5,
		  bottom = 5,
		},
	  }
	
	WACKO_.f = CreateFrame("Frame", "$parent_MultilineEdit", panel, BackdropTemplateMixin and "BackdropTemplate")
	WACKO_.f:SetSize(600, 300)
	WACKO_.f:SetPoint("TOPLEFT",options[index],"BOTTOMLEFT",0,-25)
	WACKO_.f:SetFrameStrata("BACKGROUND")
	WACKO_.f:SetBackdrop(backdrop)
	WACKO_.f:SetBackdropColor(0, 0, 0)

	WACKO_.f.SF = CreateFrame("ScrollFrame", "$parent_ScrollFrame", WACKO_.f, "UIPanelScrollFrameTemplate")
	WACKO_.f.SF:SetPoint("TOPLEFT", WACKO_.f, 12, -30)
	WACKO_.f.SF:SetPoint("BOTTOMRIGHT", WACKO_.f, -30, 10)

	WACKO_.f.Text = CreateFrame("EditBox", "$parent_Edit", WACKO_.f)
	WACKO_.f.Text:SetMultiLine(true)
	WACKO_.f.Text:SetSize(600, 300)
	WACKO_.f.Text:SetPoint("TOPLEFT", WACKO_.f.SF)
	WACKO_.f.Text:SetPoint("BOTTOMRIGHT", WACKO_.f.SF)
	WACKO_.f.Text:SetText(WackoDataCData.currentCustomItems)
	WACKO_.f.Text:SetMaxLetters(99999)
	WACKO_.f.Text:SetFontObject(GameFontNormal)
	WACKO_.f.Text:SetAutoFocus(false) -- do not steal focus from the game
	WACKO_.f.Text:SetScript("OnEscapePressed",
		function(self)
			WackoDataCData.currentCustomItems = self:GetText();
			self:ClearFocus()
		end)
	WACKO_.f.Text:SetScript("OnEditFocusGained",function(self)
		self.Focused=1
	end)
	WACKO_.f.Text:SetScript("OnEditFocusLost",function(self)
		WackoDataCData.currentCustomItems = self:GetText();
		self.Focused=nil
	end)
	WACKO_.f.SF:SetScrollChild(WACKO_.f.Text)

	WACKO_.f.dropdownLabel = WACKO_.f:CreateFontString(nil, "ARTWORK", "GameFontHighlight");
	WACKO_.f.dropdownLabel:SetText("Custom items:");
	WACKO_.f.dropdownLabel:SetPoint("BOTTOMLEFT", WACKO_.f, "TOPLEFT", 0, 10);
end
