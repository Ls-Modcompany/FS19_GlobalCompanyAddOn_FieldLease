--
-- GlobalCompany - AddOn - FieldLease
--
-- @Interface: --
-- @Author: LS-Modcompany / kevink98
-- @Date: 13.05.2020
-- @Version: 1.1.0.0
--
-- @Support: LS-Modcompany
--
-- Changelog:
-- 	v1.1.0.0 (13.05.2020):
-- 		- fix log error
--		- fix error at rejoin
-- 		- fix error at save and load
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

GC_AddOnFieldLease = {}
GC_AddOnFieldLease._mt = Class(GC_AddOnFieldLease, g_company.gc_staticClass);
InitObjectClass(GC_AddOnFieldLease, "GC_AddOnFieldLease");

GC_AddOnFieldLease.LEASEFACTORBUY = 0.2
GC_AddOnFieldLease.LEASEFACTORUPKEEP = 0.02

source(g_currentModDirectory .. "gui/GcMain_FieldLease.lua")

function GC_AddOnFieldLease:initGlobalCompany(customEnvironment, baseDirectory, xmlFile)
	if (g_company == nil) or (GC_AddOnFieldLease.isInitiated ~= nil) then
		return;
	end

	GC_AddOnFieldLease.debugIndex = g_company.debug:registerScriptName("GC_AddOnFieldLease");
	GC_AddOnFieldLease.modName = customEnvironment;
	GC_AddOnFieldLease.baseDirectory = baseDirectory
	GC_AddOnFieldLease.isInitiated = true;

	local self =  GC_AddOnFieldLease:superClass():new(GC_AddOnFieldLease._mt, g_server ~= nil, g_dedicatedServerInfo == nil);

	g_company.networkManager.addReadWriteStream(self)

	self.updateableList = {}
	self.leasedMapping = {}

	g_company.addOnFieldLease = self

	g_company.addInit(self, GC_AddOnFieldLease.init);	
end

function GC_AddOnFieldLease:init()
    
	if self.isClient then
		g_company.gui:registerUiElements("g_gcAddOnFieldLease_menuIcon", GC_AddOnFieldLease.baseDirectory .. "images/menuIcon.dds")
		g_company.gui:loadGuiTemplates(GC_AddOnFieldLease.baseDirectory .. "gui/guiTemplates.xml")
		g_company.gui:loadGui(Gc_Gui_AddOn_FieldLease, "gcAddOnFieldLease")		

		g_company.gui:registerSiteForGcMenu("g_gcAddOnFieldLease_menuIcon", "icon_addOnFieldLease_menuIcon", g_company.gui:getGui("gcAddOnFieldLease"))
	end	

	self.eventId_sell = self:registerEvent(self, self.buyFarmlandEvent, false, false)
	self.eventId_lease = self:registerEvent(self, self.leaseFarmlandEvent, false, false)   

	
	g_currentMission.environment:addHourChangeListener(self)


	g_company.addOnFieldLease = self
end

function GC_AddOnFieldLease:addUpdateableList(target, loadF)
	table.insert(self.updateableList, {loadF=loadF, target=target})
end

function GC_AddOnFieldLease:removeUpdateableList(target)
	for key, u in pairs(self.updateableList) do
		if u.target == target then
			table.remove(self.updateableList, key);
			break;
		end;
	end;
end

function GC_AddOnFieldLease:calcPrice(price)
	if g_seasons ~= nil then
		price = price * 3 / (g_seasons.environment.daysPerSeason * 4)
	end
	return price
end

function GC_AddOnFieldLease:buyFarmlandEvent(data, noEventSend) 
    self:raiseEvent(self.eventId_sell, data, noEventSend)
	g_farmlandManager:setLandOwnership(data[1], data[2])
	if g_company.addOnFieldLease.isServer then
		if data[2] ~= 0 then
			g_currentMission:addMoney(g_farmlandManager.farmlands[data[1]].price * -1, data[2], MoneyType.FIELD_BUY, true, false)
		else
			g_currentMission:addMoney(g_farmlandManager.farmlands[data[1]].price, data[3], MoneyType.FIELD_SELL, true, false)
		end
	end
	
	if not g_company.addOnFieldLease.isServer and g_company.addOnFieldLease.isClient then
		for _, updateable in pairs(self.updateableList) do
			updateable.loadF(updateable.target, dt)
		end
	end
end

function GC_AddOnFieldLease:leaseFarmlandEvent(data, noEventSend) 
    self:raiseEvent(self.eventId_lease, data, noEventSend)
	g_farmlandManager:setLandOwnership(data[1], data[2])
	self.leasedMapping[data[1]] = data[2] ~= 0

	if g_company.addOnFieldLease.isServer and data[2] ~= 0 then
		g_currentMission:addMoney(g_company.addOnFieldLease:calcPrice(g_farmlandManager.farmlands[data[1]].price * GC_AddOnFieldLease.LEASEFACTORBUY * -1), data[2], MoneyType.FIELD_BUY, true, false)
	end
	
	if not g_company.addOnFieldLease.isServer and g_company.addOnFieldLease.isClient then
		for _, updateable in pairs(self.updateableList) do
			updateable.target.update(updateable.target, dt)
		end
	end
end

function GC_AddOnFieldLease:hourChanged()
	if self.isServer then
		if g_currentMission.environment.currentHour == 0 then
			local leased = {}
			for _, farmland in pairs(g_farmlandManager.farmlands) do
				if farmland.isOwned and self.leasedMapping[farmland.id] then
					local farmId = g_farmlandManager.farmlandMapping[farmland.id]
					if leased[farmId] == nil then
						leased[farmId] = 0
					end
					leased[farmId] = leased[farmId] + (farmland.price * GC_AddOnFieldLease.LEASEFACTORUPKEEP)
				end
			end

			for farmId, money in pairs(leased) do
				g_currentMission:addMoney(g_company.addOnFieldLease:calcPrice(money * -1), farmId, MoneyType.OTHER, true, false)
			end
		end
	end
end

--function GC_AddOnFieldLease:farmlandNew()
	--self.isLeased = false
--end

function GC_AddOnFieldLease:farmlandManagerSaveToXmlFile(xmlFilename)
	local xmlFile = loadXMLFile("farmlandsXML", xmlFilename, "farmlands")
    if xmlFile ~= nil then
        local index = 0
		for farmlandId, farmId in pairs(g_farmlandManager.farmlandMapping) do
			if g_farmlandManager.farmlands[farmlandId] ~= nil then
				local farmlandKey = string.format("farmlands.leasedFarmlands(%d)", index)
				setXMLInt(xmlFile, farmlandKey.."#id", farmlandId)
				setXMLBool(xmlFile, farmlandKey.."#isLeased", Utils.getNoNil(g_company.addOnFieldLease.leasedMapping[farmlandId], false))
				index = index + 1
			end
        end
        saveXMLFile(xmlFile)
        delete(xmlFile)
    end
end

function GC_AddOnFieldLease:farmlandManagerLoadFromXMLFile(xmlFilename)
	if xmlFilename == nil then
        return false
    end
    local xmlFile = loadXMLFile("farmlandXML", xmlFilename)
    if xmlFile == 0 then
        return false
    end
    local farmlandCounter = 0
    while true do
        local key = string.format("farmlands.leasedFarmlands(%d)", farmlandCounter)
        local farmlandId = getXMLInt(xmlFile, key .. "#id")
        if farmlandId == nil then
            break
        end
        g_company.addOnFieldLease.leasedMapping[farmlandId] = getXMLBool(xmlFile, key .. "#isLeased")
        farmlandCounter = farmlandCounter + 1
    end
    delete(xmlFile)
end

--Farmland.new = g_company.utils.appendedFunction2(Farmland.new, GC_AddOnFieldLease.farmlandNew)
FarmlandManager.saveToXMLFile = g_company.utils.appendedFunction2(FarmlandManager.saveToXMLFile, GC_AddOnFieldLease.farmlandManagerSaveToXmlFile)
FarmlandManager.loadFromXMLFile = g_company.utils.appendedFunction2(FarmlandManager.loadFromXMLFile, GC_AddOnFieldLease.farmlandManagerLoadFromXMLFile)

function GC_AddOnFieldLease:readStream(streamId, connection)
	local lenght = streamReadInt16(streamId)	
	for i = 0, lenght do
		local id = streamReadInt16(streamId)
		local isLeased = streamReadBool(streamId)
		if id ~= nil then -- i dont't know why the last is nil...
			g_company.addOnFieldLease.leasedMapping[id] = isLeased
		end
	end
end

function GC_AddOnFieldLease:writeStream(streamId, connection)
	streamWriteInt16(streamId, g_company.utils.getTableLength(g_farmlandManager.farmlands))
	for id, farmland in pairs(g_farmlandManager.farmlands) do
		streamWriteInt16(streamId, id)
		streamWriteBool(streamId, Utils.getNoNil(g_company.addOnFieldLease.leasedMapping[farmland.id], false))
	end
end