-----------------------------------------------------------------------------------------------
-- Client Lua Script for LootBot
-- Copyright (c) NCsoft. All rights reserved
-----------------------------------------------------------------------------------------------

require "Apollo"
require "GameLib"
require "Item"
require "Window"
require "ChatSystemLib"

local LootBot = {}

local tLootLevel = {
	"Inferior",
	"Average",
	"Good",
	"Excellent",
	"Superb",
	"Legendary",
	"Artifact"
}
 
local eLootOption = {}
eLootOption.greed = 1
eLootOption.need = 2
eLootOption.disable = 3

local eLootSigil = {}
eLootSigil.greed = 1
eLootSigil.need = 2
eLootSigil.custom = 3
eLootSigil.disable = 4

local tLootBotSettings = {
	"nLootOption",
	"nLootLevel",
	"nSigilOption",
	"nOtherOption",
	"btSigilType",
	"tFrameLoc"

}

function LootBot:new(o)
    o = o or {}
    setmetatable(o, self)
    self.__index = self 

	--Default Settings
	o.nLootOption = eLootOption.need
	o.nLootLevel = Item.CodeEnumItemQuality.Good
	o.nSigilOption = eLootSigil.greed
	o.nOtherOption = eLootOption.greed
		
	o.btSigilType = {}
	o.btSigilType[Item.CodeEnumSigilType.Air] = false
	o.btSigilType[Item.CodeEnumSigilType.Earth] = false
	o.btSigilType[Item.CodeEnumSigilType.Fire] = false
	o.btSigilType[Item.CodeEnumSigilType.Water] = false
	o.btSigilType[Item.CodeEnumSigilType.Fusion] = false
	o.btSigilType[Item.CodeEnumSigilType.Life] = false
	o.btSigilType[Item.CodeEnumSigilType.Logic] = false
	
	o.tFrameLoc = { -1010, -855, -677, -369 }
	
	o.needFlag = false
	
    return o
end

function LootBot:Init()
    Apollo.RegisterAddon(self, true, "LootBot")
end

function LootBot:OnSave(eType)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then return end
	
	local tSave = {}
	for idx, property in ipairs(tLootBotSettings) do tSave[property] = self[property] end
	
	return tSave			
end

function LootBot:OnRestore(eType, tSavedData)
	if eType ~= GameLib.CodeEnumAddonSaveLevel.Character then return end
	
	for idx, property in ipairs(tLootBotSettings) do
		if tSavedData[property] ~= nil then self[property] = tSavedData[property] end
	end
end

function LootBot:OnLoad()
	self.xmlDoc = XmlDoc.CreateFromFile("LootBot.xml")
	self.xmlDoc:RegisterCallback("OnDocLoaded", self)
end

function LootBot:OnDocLoaded()

	if self.xmlDoc ~= nil and self.xmlDoc:IsLoaded() then
	    self.wndMain = Apollo.LoadForm(self.xmlDoc, "LootBotForm", nil, self)
		if self.wndMain == nil then
			Apollo.AddAddonErrorText(self, "Could not load the main window for some reason.")
			return
		end
		
	    self.wndMain:Show(false, true)

		Apollo.RegisterEventHandler("LootRollUpdate",		"OnGroupLoot", self)
		Apollo.RegisterEventHandler("LootRollSelected", 	"OnLootRollSelected", self)
		
		-- declare additional frames for future reference
		self.wndLootOption = self.wndMain:FindChild("LootBotForm:BGMain:EquipmentSettings")
		self.QualityDropDownBtn = self.wndMain:FindChild("LootBotForm:BGMain:EquipmentSettings:QualityComboFrame:QualityDropDownBtn")
		self.wndSigilOption = self.wndMain:FindChild("LootBotForm:BGMain:SigilSettings")
		self.wndOtherOption = self.wndMain:FindChild("LootBotForm:BGMain:OtherItemsSettings")
		
		self.wndQualityMenu = self.wndMain:FindChild("LootBotForm:BGMain:EquipmentSettings:QualityComboFrame:QualityDropDownBtn:QualityMenu")
		self.wndQualityMenu:Show(false)
		
		self.btnSigilTypeWater = self.wndMain:FindChild("LootBotForm:BGMain:SigilSettings:CustomSigilSettings:SigilTypeWater")
		self.btnSigilTypeLife = self.wndMain:FindChild("LootBotForm:BGMain:SigilSettings:CustomSigilSettings:SigilTypeLife")
		self.btnSigilTypeEarth = self.wndMain:FindChild("LootBotForm:BGMain:SigilSettings:CustomSigilSettings:SigilTypeEarth")
		self.btnSigilTypeFusion = self.wndMain:FindChild("LootBotForm:BGMain:SigilSettings:CustomSigilSettings:SigilTypeFusion")
		self.btnSigilTypeFire = self.wndMain:FindChild("LootBotForm:BGMain:SigilSettings:CustomSigilSettings:SigilTypeFire")
		self.btnSigilTypeLogic = self.wndMain:FindChild("LootBotForm:BGMain:SigilSettings:CustomSigilSettings:SigilTypeLogic")
		self.btnSigilTypeAir = self.wndMain:FindChild("LootBotForm:BGMain:SigilSettings:CustomSigilSettings:SigilTypeAir")

		--store value from Item:GetItemQuality() 
		self.BtnToQuality = {}
		self.BtnToQuality[1] = Item.CodeEnumItemQuality.Inferior
		self.BtnToQuality[2] = Item.CodeEnumItemQuality.Average
		self.BtnToQuality[3] = Item.CodeEnumItemQuality.Good
		self.BtnToQuality[4] = Item.CodeEnumItemQuality.Excellent
		self.BtnToQuality[5] = Item.CodeEnumItemQuality.Superb
		self.BtnToQuality[6] = Item.CodeEnumItemQuality.Legendary
		self.BtnToQuality[7] = Item.CodeEnumItemQuality.Artifact
		
		-- convert value to Int to make Loot Level checks
		self.QualityToBtn = {}
		self.QualityToBtn[Item.CodeEnumItemQuality.Inferior] = 1
		self.QualityToBtn[Item.CodeEnumItemQuality.Average] = 2
		self.QualityToBtn[Item.CodeEnumItemQuality.Good] = 3
		self.QualityToBtn[Item.CodeEnumItemQuality.Excellent] = 4
		self.QualityToBtn[Item.CodeEnumItemQuality.Superb] = 5
		self.QualityToBtn[Item.CodeEnumItemQuality.Legendary] = 6
		self.QualityToBtn[Item.CodeEnumItemQuality.Artifact] = 7
		
		-- identify sigil element based on GetItemType()
		self.ItemTypeToSigilEnum = {}
		self.ItemTypeToSigilEnum[339] = Item.CodeEnumSigilType.Water
		self.ItemTypeToSigilEnum[440] = Item.CodeEnumSigilType.Life
		self.ItemTypeToSigilEnum[441] = Item.CodeEnumSigilType.Earth
		self.ItemTypeToSigilEnum[442] = Item.CodeEnumSigilType.Fusion
		self.ItemTypeToSigilEnum[443] = Item.CodeEnumSigilType.Fire
		self.ItemTypeToSigilEnum[444] = Item.CodeEnumSigilType.Logic
		self.ItemTypeToSigilEnum[445] = Item.CodeEnumSigilType.Air
		
		Apollo.RegisterSlashCommand("lootbot", "OnConfigure", self)

		
		if GameLib.GetLootRolls() then 
			self:OnGroupLoot() 
		end

	end
end

function LootBot:OnGroupLoot()
	local tLoot = GameLib.GetLootRolls()
	
	-- roll on loot
	for k, tCurrentItem in ipairs(tLoot) do
		self.needFlag = false  -- control needing items, false is greed
		
		if self:GetRollInfo(tCurrentItem, bNeed) then
			local nLootID = tCurrentItem.nLootId
			GameLib.RollOnLoot(nLootID, self.needFlag)
		end
			
	end

end

-- function to determine if we want loot
function LootBot:GetRollInfo(tLoot, bNeed)
	local tItem = tLoot.itemDrop
	local bGreedIt = tItem:GetItemQuality() <= self.nLootLevel
	local tLink = tItem:GetChatLinkString()
	--local tLink = Event_FireGenericEvent("ItemLink", tLoot.nLootId)
	
	--debug
	local sItemTypeName = tItem:GetItemTypeName()
	ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_Debug, string.format("ItemTypeName:  "..sItemTypeName))

	
	-- reject rolling on equipment if it is above loot level
	if (tItem:IsEquippable() and not bGreedIt) then return false end
	
	-- make decision on equipment
	if (tItem:IsEquippable() and bGreedIt) then
		if self.nLootOption == eLootOption.need then
			if not GameLib.IsNeedRollAllowed(tLoot.nLootId) then -- item cannot be needed on
				ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, string.format("LootBot: You auto-roll greed on "..tLink))
				return true -- roll greed
			end
		elseif self.nLootOption == eLootOption.greed then
			ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, string.format("LootBot: You auto-roll greed on "..tLink))
			return true -- roll greed
		end
		
	end
	
	-- is item a sigil? make decision
	if tItem:GetItemType() <= 345 and tItem:GetItemType() >= 399 then
		-- if sigil options are not disabled do something
		if self.nSigilOption < eLootSigil.disabled then
			
			--handle rolls for Need/Greed-All option
			if self.nSigilOption < eLootSigil.custom then
				--roll Need if Need-All is selected
				if self.nSigilOption == eLootSigil.need then
					self.needFlag = true
				end
				--post to chat
				if self.needFlag then
					ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, string.format("LootBot: You auto-roll need on "..tLink))
				else
					ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, string.format("LootBot: You auto-roll greed on "..tLink))
				end
				
				return true
			end
			
			--handle rolls when Custom is selected
			if self.nSigilOption == eLootSigil.custom then
				-- if true then player has selected the button for the sigil type, need it
				if self.btSigilType[self.ItemTypeToSigilEnum[tItem:GetItemType()]] then
					self.needFlag = true
					ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, string.format("LootBot: You auto-roll need on "..tLink))
					return true
				else
					self.needFlag = false
					ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, string.format("LootBot: You auto-roll greed on "..tLink))
					return true
					
				end
			end
		
		end
		
		return false  -- Sigil Settings are disabled do not auto-roll
	
	end
	
	--handle rolls for non-equipment and non-sigils(other items)
	if self.nOtherOption < eLootOption.disable then
		local bGreedIt = tItem:GetItemQuality() <= self.nLootLevel
	
		if self.nOtherOption == eLootOption.need then --if need is selected, enable need flag and roll
			self.needFlag = true
			ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, string.format("LootBot: You auto-roll need on "..tLink))
			return true
		elseif (self.nOtherOption == eLootOption.greed and bGreedIt) then
			ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, string.format("LootBot: You auto-roll greed on "..tLink))
			return true
		end 
		
	end
	
	return false  -- implicit deny just in case

end

 --Need to Test function
--handler for when a loot item is rolled on 
function LootBot:OnLootRollSelected(nLootItem, strPlayer, bNeed)
	local tLink = nLootItem:GetChatLinkString()
	
	-- Example Message: strPlayer has selected to bNeed for nLootItem
	if bNeed then
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, string.format("LootBot: You have selected to need on "..tLink))
	else
		ChatSystemLib.PostOnChannel(ChatSystemLib.ChatChannel_System, string.format("LootBot: You have selected to greed on "..tLink))
	end
end

-- when the settings window is called, update settings shown
function LootBot:OnConfigure()

	--set Frame Location
	self.wndMain:SetAnchorOffsets(self.tFrameLoc[1],self.tFrameLoc[2],self.tFrameLoc[3],self.tFrameLoc[4])

	-- set Equipment Settings 		
	self.wndLootOption:SetRadioSel("Equipment_BtnGroup", self.nLootOption)
	self.wndQualityMenu:SetRadioSel("LootLevel_BtnGroup", self.QualityToBtn[self.nLootLevel])
	
	-- set Loot Level string
	self:UpdateLootLevel()
	
	-- set Sigil Settings
	self.wndSigilOption:SetRadioSel("SigilLootOption_BtnGroup", self.nSigilOption)
	
	self.btnSigilTypeWater:SetCheck(self.btSigilType[Item.CodeEnumSigilType.Water])
	self.btnSigilTypeLife:SetCheck(self.btSigilType[Item.CodeEnumSigilType.Life])
	self.btnSigilTypeEarth:SetCheck(self.btSigilType[Item.CodeEnumSigilType.Earth])
	self.btnSigilTypeFusion:SetCheck(self.btSigilType[Item.CodeEnumSigilType.Fusion])
	self.btnSigilTypeFire:SetCheck(self.btSigilType[Item.CodeEnumSigilType.Fire])
	self.btnSigilTypeLogic:SetCheck(self.btSigilType[Item.CodeEnumSigilType.Logic])
	self.btnSigilTypeAir:SetCheck(self.btSigilType[Item.CodeEnumSigilType.Air])
	
	-- set Other Settings
	self.wndOtherOption:SetRadioSel("OtherLootOption_BtnGroup", self.nOtherOption)
	
	self.wndMain:Invoke() -- call the window
end

---------------/ Main Frame Button Functions /---------------

-- when the Apply button is clicked
function LootBot:OnApply()

	
	--Equipment Settings
	self.nLootOption = self.wndLootOption:GetRadioSel("Equipment_BtnGroup")
	self.nLootLevel = self.BtnToQuality[self.wndQualityMenu:GetRadioSel("LootLevel_BtnGroup")]
	
	--Sigil Settings
	self.nSigilOption = self.wndSigilOption:GetRadioSel("SigilLootOption_BtnGroup")
	
	self.btSigilType[Item.CodeEnumSigilType.Water] = self.btnSigilTypeWater:IsChecked()
	self.btSigilType[Item.CodeEnumSigilType.Life] = self.btnSigilTypeLife:IsChecked()
	self.btSigilType[Item.CodeEnumSigilType.Earth] = self.btnSigilTypeEarth:IsChecked()
	self.btSigilType[Item.CodeEnumSigilType.Fusion] = self.btnSigilTypeFusion:IsChecked()
	self.btSigilType[Item.CodeEnumSigilType.Fire] = self.btnSigilTypeFire:IsChecked()
	self.btSigilType[Item.CodeEnumSigilType.Logic] = self.btnSigilTypeLogic:IsChecked()
	self.btSigilType[Item.CodeEnumSigilType.Air] = self.btnSigilTypeAir:IsChecked()
	
	--Other Settings
	self.nOtherOption = self.wndOtherOption:GetRadioSel("OtherLootOption_BtnGroup")
	
	--Save Frame Location
	self.tFrameLoc[1], self.tFrameLoc[2], self.tFrameLoc[3], self.tFrameLoc[4] = self.wndMain:GetAnchorOffsets()
	
	
	self.wndMain:Close() -- hide the window
end

-- when the Cancel button is clicked
function LootBot:OnCancel()
	self.QualityDropDownBtn:SetCheck(false)
	self.wndQualityMenu:Show(false)
	self.wndMain:Close() -- hide the window
end

-- update the dropdown menu string and color
function LootBot:UpdateLootLevel()
	self.QualityDropDownBtn:SetText("    "..tLootLevel[self.nLootLevel])
	self.QualityDropDownBtn:SetNormalTextColor("ItemQuality_"..tLootLevel[self.nLootLevel])
end

---------------/ Equipment Settings - Loot Level DropDown Functions /---------------
function LootBot:OnQualityDropDownBtnCheck( wndHandler, wndControl, eMouseButton )
	self.wndQualityMenu:Show(true)
	self.QualityDropDownBtn:SetCheck(true)
end

function LootBot:OnQualityDropDownBtnUncheck( wndHandler, wndControl, eMouseButton )
	self.wndQualityMenu:Show(false)
	self.QualityDropDownBtn:SetCheck(false)
end

---------------/ Equipment Settings - Quality Menu Button Functions /---------------
function LootBot:OnQualityBtnInferior( wndHandler, wndControl, eMouseButton )
	self.nLootLevel = Item.CodeEnumItemQuality.Inferior
	self.QualityDropDownBtn:SetCheck(false)
	self.wndQualityMenu:Show(false)
	self:UpdateLootLevel()
end

function LootBot:OnQualityBtnAverage( wndHandler, wndControl, eMouseButton )
	self.nLootLevel = Item.CodeEnumItemQuality.Average
	self.QualityDropDownBtn:SetCheck(false)
	self.wndQualityMenu:Show(false)
	self:UpdateLootLevel()
end

function LootBot:OnQualityBtnGood( wndHandler, wndControl, eMouseButton )
	self.nLootLevel = Item.CodeEnumItemQuality.Good
	self.QualityDropDownBtn:SetCheck(false)
	self.wndQualityMenu:Show(false)
	self:UpdateLootLevel()
end

function LootBot:OnQualityBtnExcellent( wndHandler, wndControl, eMouseButton )
	self.nLootLevel = Item.CodeEnumItemQuality.Excellent
	self.QualityDropDownBtn:SetCheck(false)
	self.wndQualityMenu:Show(false)
	self:UpdateLootLevel()
end

function LootBot:OnQualityBtnSuperb( wndHandler, wndControl, eMouseButton )
	self.nLootLevel = Item.CodeEnumItemQuality.Superb
	self.QualityDropDownBtn:SetCheck(false)
	self.wndQualityMenu:Show(false)
	self:UpdateLootLevel()
end

function LootBot:OnQualityBtnLegendary( wndHandler, wndControl, eMouseButton )
	self.nLootLevel = Item.CodeEnumItemQuality.Legendary
	self.QualityDropDownBtn:SetCheck(false)
	self.wndQualityMenu:Show(false)
	self:UpdateLootLevel()
end

function LootBot:OnQualityBtnArtifact( wndHandler, wndControl, eMouseButton )
	self.nLootLevel = Item.CodeEnumItemQuality.Artifact
	self.QualityDropDownBtn:SetCheck(false)
	self.wndQualityMenu:Show(false)
	self:UpdateLootLevel()
end

--run the addon
local LootBotInst = LootBot:new()
LootBotInst:Init()
