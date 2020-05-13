--
-- GlobalCompany - AddOn - Gc_Gui_AddOn_FieldLease
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 14.04.2020
-- @Version: 1.0.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
--
-- 	v1.0.0.0 (14.04.2020):
-- 		- initial Script Fs19 (kevink98)
--
-- Notes:
--
--
-- ToDo:
-- 
--
--

Gc_Gui_AddOn_FieldLease = {}
local Gc_Gui_AddOn_FieldLease_mt = Class(Gc_Gui_AddOn_FieldLease)
Gc_Gui_AddOn_FieldLease.xmlFilename = g_currentModDirectory .. "gui/GcMain_FieldLease.xml"
Gc_Gui_AddOn_FieldLease.debugIndex = g_company.debug:registerScriptName("Gc_Gui_AddOn_FieldLease")

Gc_Gui_AddOn_FieldLease.MODE_BUY = 1
Gc_Gui_AddOn_FieldLease.MODE_SELL = 2
Gc_Gui_AddOn_FieldLease.MODE_LEASE = 3
Gc_Gui_AddOn_FieldLease.MODE_LEASESTOP = 4

function Gc_Gui_AddOn_FieldLease:new()
	local self = setmetatable({}, Gc_Gui_AddOn_FieldLease_mt)    
	self.name = "AddOnFieldLease"	
	return self
end

function Gc_Gui_AddOn_FieldLease:keyEvent(unicode, sym, modifier, isDown, eventUsed) end
function Gc_Gui_AddOn_FieldLease:onClose() 
	g_company.addOnFieldLease:removeUpdateableList(self)
end
function Gc_Gui_AddOn_FieldLease:onCreate() end
function Gc_Gui_AddOn_FieldLease:update(dt) end

function Gc_Gui_AddOn_FieldLease:onOpen()
	self:loadTable()
	self:setInfo()
	self.gui_btn_buy:setDisabled(true)
	self.gui_btn_sell:setDisabled(true)
	self.gui_btn_lease:setDisabled(true)
	self.gui_btn_leaseStop:setDisabled(true)
	self.currentSelectedField = nil
	g_company.addOnFieldLease:addUpdateableList(self, self.loadTable)
end

function Gc_Gui_AddOn_FieldLease:onClickClose()
    g_company.gui:closeActiveGui()
end

function Gc_Gui_AddOn_FieldLease:loadTable()
	self.gui_fieldList:removeElements()
	for _,field in pairs(g_fieldManager.fields) do
		self.currentField = field
		local item = self.gui_fieldList:createItem()
		item.field = field
	end
end

function Gc_Gui_AddOn_FieldLease:onCreateTextField(element)
	if self.currentField ~= nil then
		element:setText(string.format(g_company.languageManager:getText("GlobalCompanyAddOn_FieldLease_field"), self.currentField.fieldId))
	end
end

function Gc_Gui_AddOn_FieldLease:onCreateTextState(element)
	if self.currentField ~= nil then
		local posX, posZ = self.currentField:getCenterOfFieldWorldPosition()
		local farmland = g_farmlandManager:getFarmlandAtWorldPosition(posX, posZ)
		if farmland.isOwned then
			if g_company.addOnFieldLease.leasedMapping[farmland.id] then
				element:setText(g_company.languageManager:getText("GlobalCompanyAddOn_FieldLease_state_leased"))
			else
				element:setText(g_company.languageManager:getText("GlobalCompanyAddOn_FieldLease_state_sold"))
			end
		else
			element:setText(g_company.languageManager:getText("GlobalCompanyAddOn_FieldLease_state_empty"))
		end
	end
end

function Gc_Gui_AddOn_FieldLease:onSelect(element)
	self.currentSelectedField = element.field
	local posX, posZ = self.currentSelectedField:getCenterOfFieldWorldPosition()
	local farmland = g_farmlandManager:getFarmlandAtWorldPosition(posX, posZ)
	self.gui_btn_buy:setDisabled(farmland.isOwned)
	self.gui_btn_sell:setDisabled((farmland.isOwned == false and g_farmlandManager.farmlandMapping[farmland.id] ~= g_currentMission:getFarmId()) or (farmland.isOwned and g_company.addOnFieldLease.leasedMapping[farmland.id]))
	self.gui_btn_lease:setDisabled(farmland.isOwned or g_company.addOnFieldLease.leasedMapping[farmland.id])
	self.gui_btn_leaseStop:setDisabled(farmland.isOwned == false or farmland.isLeased ~= true or g_farmlandManager.farmlandMapping[farmland.id] ~= g_currentMission:getFarmId())
end

function Gc_Gui_AddOn_FieldLease:onClickBuy()
	self.currentMode = self.MODE_BUY
	local posX, posZ = self.currentSelectedField:getCenterOfFieldWorldPosition()
	local farmland = g_farmlandManager:getFarmlandAtWorldPosition(posX, posZ)

	local text = string.format(g_company.languageManager:getText("GlobalCompanyAddOn_FieldLease_dialog_1"), self.currentSelectedField.fieldId, g_i18n:formatMoney(farmland.price))
	g_company.gui:closeGui("gc_main")
	g_gui:showYesNoDialog({text = text, title = "", callback = self.onConfirm, target = self})
end

function Gc_Gui_AddOn_FieldLease:onClickSell()
	self.currentMode = self.MODE_SELL
	local posX, posZ = self.currentSelectedField:getCenterOfFieldWorldPosition()
	local farmland = g_farmlandManager:getFarmlandAtWorldPosition(posX, posZ)
	local text = string.format(g_company.languageManager:getText("GlobalCompanyAddOn_FieldLease_dialog_2"), self.currentSelectedField.fieldId, g_i18n:formatMoney(farmland.price))
	g_company.gui:closeGui("gc_main")
	g_gui:showYesNoDialog({text = text, title = "", callback = self.onConfirm, target = self})
end

function Gc_Gui_AddOn_FieldLease:onClickLease()
	self.currentMode = self.MODE_LEASE
	local posX, posZ = self.currentSelectedField:getCenterOfFieldWorldPosition()
	local farmland = g_farmlandManager:getFarmlandAtWorldPosition(posX, posZ)
	local text = string.format(g_company.languageManager:getText("GlobalCompanyAddOn_FieldLease_dialog_3"), self.currentSelectedField.fieldId, g_i18n:formatMoney(g_company.addOnFieldLease:calcPrice(farmland.price * g_company.addOnFieldLease.LEASEFACTORBUY)), g_i18n:formatMoney(g_company.addOnFieldLease:calcPrice(farmland.price * g_company.addOnFieldLease.LEASEFACTORUPKEEP)))
	g_company.gui:closeGui("gc_main")
	g_gui:showYesNoDialog({text = text, title = "", callback = self.onConfirm, target = self})
end

function Gc_Gui_AddOn_FieldLease:onClickLeaseStop()
	self.currentMode = self.MODE_LEASESTOP
	local posX, posZ = self.currentSelectedField:getCenterOfFieldWorldPosition()
	local farmland = g_farmlandManager:getFarmlandAtWorldPosition(posX, posZ)
	local text = string.format(g_company.languageManager:getText("GlobalCompanyAddOn_FieldLease_dialog_4"), self.currentSelectedField.fieldId)
	g_company.gui:closeGui("gc_main")
	g_gui:showYesNoDialog({text = text, title = "", callback = self.onConfirm, target = self})
end

function Gc_Gui_AddOn_FieldLease:onConfirm(confirm)
	if confirm then
		local posX, posZ = self.currentSelectedField:getCenterOfFieldWorldPosition()
		local farmland = g_farmlandManager:getFarmlandAtWorldPosition(posX, posZ)
		local farmlandId = farmland.id
		local farmId = g_currentMission:getFarmId()
		if self.currentMode == self.MODE_BUY then
			g_company.addOnFieldLease:buyFarmlandEvent({farmlandId, farmId})
		elseif self.currentMode == self.MODE_SELL then
			g_company.addOnFieldLease:buyFarmlandEvent({farmlandId, 0, farmId})
		elseif self.currentMode == self.MODE_LEASE then
			g_company.addOnFieldLease:leaseFarmlandEvent({farmlandId, farmId})
		elseif self.currentMode == self.MODE_LEASESTOP then
			g_company.addOnFieldLease:leaseFarmlandEvent({farmlandId, 0, farmId})		
		end
	end
	g_company.gui:openGui("gc_main")
	self.currentMode = nil
	self:loadTable()
	self:setInfo()
end

function Gc_Gui_AddOn_FieldLease:setInfo()
	local bought = 0
	local leased = 0
	for _, farmland in pairs(g_farmlandManager.farmlands) do
		if farmland.isOwned then
			if g_company.addOnFieldLease.leasedMapping[farmland.id] then
				leased = leased + (farmland.price * g_company.addOnFieldLease.LEASEFACTORUPKEEP) 
			else
				bought = bought + farmland.price
			end
		end
	end
	self.gui_info_1:setText(string.format(g_company.languageManager:getText("GlobalCompanyAddOn_FieldLease_info_1"), g_i18n:formatMoney(bought)))
	self.gui_info_2:setText(string.format(g_company.languageManager:getText("GlobalCompanyAddOn_FieldLease_info_2"), g_i18n:formatMoney(g_company.addOnFieldLease:calcPrice(leased))))
end