util.require_natives(1676318796)

Print = util.toast
Wait = util.yield
joaat = util.joaat

local FileNameForSave = "StoredPath"
local PathDirSaveds = filesystem.scripts_dir().."Paths\\"
local LoadedFileName = FileNameForSave

filesystem.mkdirs(filesystem.scripts_dir().."Paths")

local GlobalSpd = 15.65
local SpeedMultiplier = 1.0545

local InterpolationFactor = 10.0

local FileListPTRs = {}

local FileListNoFolder = {}
local FileListOptions = {}
local FileList = {}
local FPS = 30

local function SetFilesList(directory, query, results)
	if results == nil then results = {} end
    for _, filepath in ipairs(filesystem.list_files(directory)) do
        if filesystem.is_dir(filepath) then
			local _2, filename, ext = string.match(filepath, "(.-)([^\\/]-%.?)[.]([^%.\\/]*)$")
			local PathsFile = {
				Is_Directory=true,
				FilePath=filepath.."\\",
				FileName=filename,
				Name="",
				Ext="",
				Directory = _2
			}
			table.insert(results, PathsFile)
            SetFilesList(filepath, query, results)
        else
            if string.match(filepath:lower(), query:lower()) then
                local _2, filename, ext = string.match(filepath, "(.-)([^\\/]-%.?)[.]([^%.\\/]*)$")
                if ext == "txt" then
                    local PathsFile = {
                        Is_Directory=false,
                        FilePath=filepath,
                        FileName=filename,
                        Name=filename,
                        Ext=ext,
						Directory = _2
                    }
                    table.insert(results, PathsFile)
                end
            end
        end
    end
    return results
end

local ReplaysToLoad = {}

local SoloRecordingMenu = menu.list(menu.my_root(), "Solo Recording", {}, "Record solo tools.")

local ResetPTRs = true
local FileSelectMenu = menu.list(SoloRecordingMenu, "Load Replay File", {"loadreplayfilemenu"}, "Now you can select multiple replays to load at once.", function() if ResetPTRs then CreateMenuItemsForFileList() end end
, function ()
	if ResetPTRs then CreateMenuItemsForFileList() end
end)

function CreateMenuItemsForFileList()
	FileList = SetFilesList(PathDirSaveds, "")
	FileListOptions = {}
	FileListNoFolder = {}
	for k = 1, #FileListPTRs do
		menu.delete(FileListPTRs[#FileListPTRs].PTR)
		table.remove(FileListPTRs, #FileListPTRs)
	end
	FileListPTRs = {}
	for k = 1, #FileList do
		if FileList[k].Is_Directory then
			local CanCreate = true
			for i = 1, #FileListOptions do
				if FileListOptions[i].DirectoryName == FileList[k].FilePath then
					CanCreate = false
				end
			end
			if CanCreate then
				FileListOptions[#FileListOptions+1] = {Contents = {}, DirectoryName = FileList[k].FilePath, DirectoryPath = FileList[k].FilePath}
			end
		end
	end
	for k = 1, #FileList do
		if not FileList[k].Is_Directory then
			local Dir = FileList[k].Directory
			local Inserted = false
			for i = 1, #FileListOptions do
				if FileListOptions[i].DirectoryPath == Dir then
					Inserted = true
					
					FileListOptions[i].Contents[#FileListOptions[i].Contents+1] = {FilePath = FileList[k].FilePath, FileName = FileList[k].FileName}
				end
			end
			if not Inserted then
				FileListNoFolder[#FileListNoFolder+1] = {FilePath = FileList[k].FilePath, FileName = FileList[k].FileName}
			end
		end
	end
	for k = 1, #FileListOptions do
		local PTR = menu.list(FileSelectMenu, FileListOptions[k].DirectoryName, {}, "")
		FileListPTRs[#FileListPTRs+1] = {PTR = PTR}
		for i = 1, #FileListOptions[k].Contents do
			FileListPTRs[#FileListPTRs+1] = {PTR = menu.toggle(PTR, FileListOptions[k].Contents[i].FileName, {}, "", function(toggle)
				local _FileName = FileListOptions[k].Contents[i].FilePath
				if toggle then
					ReplaysToLoad[_FileName] = {}
				else
					ReplaysToLoad[_FileName] = nil
				end
			end, ReplaysToLoad[FileListOptions[k].Contents[i].FilePath] ~= nil)}
		end
	end
	for k = 1, #FileListNoFolder do
		FileListPTRs[#FileListPTRs+1] = {PTR = menu.toggle(FileSelectMenu, FileListNoFolder[k].FileName, {}, "", function(toggle)
			_FileName = FileListNoFolder[k].FilePath
			if toggle then
				ReplaysToLoad[_FileName] = {}
			else
				ReplaysToLoad[_FileName] = nil
			end
		end, ReplaysToLoad[FileListNoFolder[k].FilePath] ~= nil)}
	end
	--Print("FileListOptions "..#FileListOptions.. " FileListNoFolder "..#FileListNoFolder)
end

menu.text_input(SoloRecordingMenu, "Set File Name", {"setfilename"}, "Set file name for saving.", function(OnChange) 
	FileNameForSave = OnChange
end, FileNameForSave)

CreateMenuItemsForFileList()

local AiHateRel = "rgFM_AiHate"
local AiLikeRel = "rgFM_AiLike"
local AiLikeHateAiHateRel = "rgFM_AiLike_HateAiHate"
local AiHateAiHateRel = "rgFM_HateAiHate"
local AiHateEveryone = "rgFM_HateEveryOne"

local RecordT = {}

local StartRecord = false
local StartRecordingPTR = menu.toggle(SoloRecordingMenu, "Start Recording", {}, "", function(toggle)
	StartRecord = toggle
	if StartRecord then
		while StartRecord do
			local PlayerPed = PLAYER.PLAYER_PED_ID()
			local Veh = PED.GET_VEHICLE_PED_IS_IN(PlayerPed, true)
			local GameTimer = MISC.GET_GAME_TIMER()
			if Veh ~= 0 then
				local Pos = ENTITY.GET_ENTITY_COORDS(Veh)
				local Rot = ENTITY.GET_ENTITY_ROTATION(Veh, 5)
				local Vel = ENTITY.GET_ENTITY_VELOCITY(Veh)
				local AngVel = ENTITY.GET_ENTITY_ROTATION_VELOCITY(Veh)
				local VehModel = ENTITY.GET_ENTITY_MODEL(Veh)
				RecordT[#RecordT+1] = ToTxt(Pos, Rot, Vel, AngVel, GameTimer, VehModel)
				local BigText = ""
				if #RecordT >= 1000 then
					for k = 1, #RecordT do
						BigText = BigText..RecordT[k]
					end
					RecordT = {}
					WriteFile(PathDirSaveds..FileNameForSave..".txt", BigText)
				end
			end
			--directx.draw_text(0.5, 0.5, "DeltaTime "..DeltaTime, ALIGN_CENTRE, 1.0, {r = 0.0, g = 1.0 , b = 1.0, a = 1.0}, false)
			--directx.draw_text(0.5, 0.6, "GameTimer "..GameTimer, ALIGN_CENTRE, 1.0, {r = 0.0, g = 1.0 , b = 1.0, a = 1.0}, false)
			Wait()
		end
		local BigText = ""
		for k = 1, #RecordT do
			BigText = BigText..RecordT[k]
		end
		RecordT = {}
		WriteFile(PathDirSaveds..FileNameForSave..".txt", BigText)
	end
end)

--menu.slider_float(menu.my_root(), "Slowing Power", {"slowpower"}, "The bigger the number, more slow the replay will be.", 100, 5000, math.floor(GlobalSpd * 100), 5, function(OnChange)
--	GlobalSpd = OnChange / 100
--end)
--
--local UseTickSpeed = false
--menu.toggle(menu.my_root(), "Use Tick Speed", {}, "", function(toggle)
--	UseTickSpeed = toggle
--end)
--
--local NormaliseSpeed = false
--menu.toggle(menu.my_root(), "Normalise Speed", {}, "", function(toggle)
--	NormaliseSpeed = toggle
--end)
--local NormalMul = 100.0
--menu.slider_float(menu.my_root(), "Normalised Speed", {"normalisedspeed"}, "", 100, 50000, math.floor(NormalMul * 100), 100, function(OnChange)
--	NormalMul = OnChange / 100
--end)

local Model = "shinobi"
menu.text_input(SoloRecordingMenu, "Set Veh Model", {"setvehmodel"}, "Vehicle model will be created to perform the replay.", function(OnChange)
	if STREAMING.IS_MODEL_VALID(joaat(OnChange)) then
		Model = OnChange
	end
end)

local UseStoredVehicleModel = true
menu.toggle(SoloRecordingMenu, "Use Stored Vehicle Model", {}, "Use vehicle model hash if is stored in the replay file", function(toggle)
	UseStoredVehicleModel = toggle
end, UseStoredVehicleModel)

local PedModel = "mp_m_bogdangoon"
menu.text_input(SoloRecordingMenu, "Set Ped Model", {"setpedmodel"}, "Ped model will be created inside vehicle.", function(OnChange)
	if STREAMING.IS_MODEL_VALID(joaat(OnChange)) then
		PedModel = OnChange
	end
end)

local CreatePedToReplay = false
menu.toggle(SoloRecordingMenu, "Create Ped To Replay Vehicles", {}, "", function(toggle)
	CreatePedToReplay = toggle
end, CreatePedToReplay)

local ReplayTeleportMode = false
menu.toggle(SoloRecordingMenu, "Replay Teleport Mode", {}, "Use teleportation instead of velocity physics.", function(toggle)
	ReplayTeleportMode = toggle
end, ReplayTeleportMode)

local StartedFromScript = false
local ReplayVehsT = {}
local StartReplay = false
local StartSelectedReplaysPTR = menu.toggle(SoloRecordingMenu, "Start Selected Replay", {}, "", function(toggle)
	StartReplay = toggle
	if StartReplay then
		for k, value in pairs(ReplaysToLoad) do
			ReplayVehsT[#ReplayVehsT+1] = {
				VehHandle = 0,
				ModelHash = 0,
				Paths = GetVectorsTable(k),
				Index = 0,
				Blip = 0,
				StartTimer = 0,
				CheckedPedForVeh = false,
				PedHandle = 0,
				PedBlip = 0
			}
		end
		for k = 1, #ReplayVehsT do
			ReplayVehsT[k].ModelHash = ReplayVehsT[k].Paths[1].ModelHash or joaat(Model)
			if ReplayVehsT[k].VehHandle == 0 then
				STREAMING.REQUEST_MODEL(ReplayVehsT[k].ModelHash)
				while not STREAMING.HAS_MODEL_LOADED(ReplayVehsT[k].ModelHash) do
					Wait()
				end
				ReplayVehsT[k].VehHandle = VEHICLE.CREATE_VEHICLE(ReplayVehsT[k].ModelHash, ReplayVehsT[k].Paths[1].x, ReplayVehsT[k].Paths[1].y, ReplayVehsT[k].Paths[1].z, ReplayVehsT[k].Paths[1].RotZ, true, true, false)
				if ReplayVehsT[k].VehHandle ~= 0 then
					STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(ReplayVehsT[k].ModelHash)
					ENTITY.SET_ENTITY_AS_MISSION_ENTITY(ReplayVehsT[k].VehHandle, false, true)
					entities.set_can_migrate(ReplayVehsT[k].VehHandle, false)
					ENTITY.SET_ENTITY_INVINCIBLE(ReplayVehsT[k].VehHandle, true)
					NETWORK.NETWORK_SET_ENTITY_CAN_BLEND(ReplayVehsT[k].VehHandle, true)
					ReplayVehsT[k].Blip = HUD.ADD_BLIP_FOR_ENTITY(ReplayVehsT[k].VehHandle)
					HUD.SET_BLIP_COLOUR(ReplayVehsT[k].Blip, 3)
					if CreatePedToReplay then
						if VEHICLE.IS_VEHICLE_DRIVEABLE(ReplayVehsT[k].VehHandle, false) then
							STREAMING.REQUEST_MODEL(joaat(PedModel))
							while not STREAMING.HAS_MODEL_LOADED(joaat(PedModel)) do
								Wait()
							end
							ReplayVehsT[k].PedHandle = PED.CREATE_PED_INSIDE_VEHICLE(ReplayVehsT[k].VehHandle, 28, joaat(PedModel), -1, true, true)
							if ReplayVehsT[k].PedHandle ~= 0 then
								STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(joaat(PedModel))
								ENTITY.SET_ENTITY_AS_MISSION_ENTITY(ReplayVehsT[k].PedHandle, false, true)
								entities.set_can_migrate(ReplayVehsT[k].PedHandle, false)
								ENTITY.SET_ENTITY_INVINCIBLE(ReplayVehsT[k].PedHandle, true)
								NETWORK.NETWORK_SET_ENTITY_CAN_BLEND(ReplayVehsT[k].PedHandle, true)
								ReplayVehsT[k].PedBlip = HUD.ADD_BLIP_FOR_ENTITY(ReplayVehsT[k].PedHandle)
								HUD.SET_BLIP_COLOUR(ReplayVehsT[k].PedBlip, 1)
								HUD.SHOW_HEADING_INDICATOR_ON_BLIP(ReplayVehsT[k].PedBlip, true)
								PED.SET_PED_COMBAT_ATTRIBUTES(ReplayVehsT[k].PedHandle, 3, false)
							else
								STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(joaat(PedModel))
							end
						end
					end
				else
					STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(ReplayVehsT[k].ModelHash)
				end
			end
		end
		local StartTimer = MISC.GET_GAME_TIMER()
		while StartReplay do
			--VEHICLE.SET_VEHICLE_DOOR_CONTROL(Veh, 2, 360, 360.0)
			local GameTimer = MISC.GET_GAME_TIMER()
			if StartedFromScript then
				StartedFromScript = false
				menu.set_value(StartRecordingPTR, true)
			end
			for k = 1, #ReplayVehsT do
				local Veh = ReplayVehsT[k].VehHandle
				if Veh ~= 0 and ENTITY.DOES_ENTITY_EXIST(Veh) then
					if ReplayVehsT[k].Index == 0 then
						ReplayVehsT[k].Index = ReplayVehsT[k].Index + 1
						ENTITY.SET_ENTITY_COORDS(Veh, ReplayVehsT[k].Paths[1].x, ReplayVehsT[k].Paths[1].y, ReplayVehsT[k].Paths[1].z)
						ENTITY.SET_ENTITY_ROTATION(Veh, ReplayVehsT[k].Paths[1].RotX, ReplayVehsT[k].Paths[1].RotY, ReplayVehsT[k].Paths[1].RotZ, 5)
						ReplayVehsT[k].StartTimer = GameTimer
					end
					if ReplayVehsT[k].Index > 0 and ReplayVehsT[k].Index < #ReplayVehsT[k].Paths then
						local CurrentTime = GameTimer - ReplayVehsT[k].StartTimer
						local Frame1, Frame2 = ReplayVehsT[k].Paths[ReplayVehsT[k].Index], ReplayVehsT[k].Paths[ReplayVehsT[k].Index + 1]
						if CurrentTime > (Frame2.CurGameTime - ReplayVehsT[k].Paths[1].CurGameTime) then
							ReplayVehsT[k].Index = ReplayVehsT[k].Index + 1
							if ReplayVehsT[k].Index >= #ReplayVehsT[k].Paths then
								ReplayVehsT[k].Index = #ReplayVehsT[k].Paths
							else
								Frame1, Frame2 = ReplayVehsT[k].Paths[ReplayVehsT[k].Index], ReplayVehsT[k].Paths[ReplayVehsT[k].Index + 1]
							end
						end
						--directx.draw_text(0.5, 0.5, "CurrentTime "..CurrentTime, ALIGN_CENTRE, 1.0, {r = 0.0, g = 1.0 , b = 1.0, a = 1.0}, false)
						--directx.draw_text(0.5, 0.6, "Frame2.CurGameTime - ReplayVehsT[k].Paths[1].CurGameTime "..Frame2.CurGameTime - ReplayVehsT[k].Paths[1].CurGameTime, ALIGN_CENTRE, 1.0, {r = 0.0, g = 1.0 , b = 1.0, a = 1.0}, false)
						local Coord = {
							x = ReplayVehsT[k].Paths[ReplayVehsT[k].Index].x,
							y = ReplayVehsT[k].Paths[ReplayVehsT[k].Index].y,
							z = ReplayVehsT[k].Paths[ReplayVehsT[k].Index].z
						}
						local Rot = {
							x = ReplayVehsT[k].Paths[ReplayVehsT[k].Index].RotX,
							y = ReplayVehsT[k].Paths[ReplayVehsT[k].Index].RotY,
							z = ReplayVehsT[k].Paths[ReplayVehsT[k].Index].RotZ
						}
						local Vel = {
							x = ReplayVehsT[k].Paths[ReplayVehsT[k].Index].VelX,
							y = ReplayVehsT[k].Paths[ReplayVehsT[k].Index].VelY,
							z = ReplayVehsT[k].Paths[ReplayVehsT[k].Index].VelZ
						}
						local AngVel = {
							x = ReplayVehsT[k].Paths[ReplayVehsT[k].Index].AngVelX,
							y = ReplayVehsT[k].Paths[ReplayVehsT[k].Index].AngVelY,
							z = ReplayVehsT[k].Paths[ReplayVehsT[k].Index].AngVelZ
						}
						if not ReplayTeleportMode then
							SetEntitySpeedToCoord(Veh, Coord, 1.0,
							false, false, false, Vel.x, Vel.y, Vel.z, false, false, nil)
							RotateEntityToTargetRotation(Veh, Rot, 10.0)
						else
							ENTITY.SET_ENTITY_COORDS(Veh, Coord.x, Coord.y, Coord.z)
							ENTITY.SET_ENTITY_ROTATION(Veh, Rot.x, Rot.y, Rot.z, 5)
							ENTITY.SET_ENTITY_VELOCITY(Veh, Vel.x, Vel.y, Vel.z)
							ENTITY.SET_ENTITY_ANGULAR_VELOCITY(Veh, AngVel.x, AngVel.y, AngVel.z)
						end
					else
						ReplayVehsT[k].Index = 0
						--ReplayVehsT[k].StartTimer = GameTimer
						--StartTimer = GameTimer
					end
				end
			end
			Wait()
		end
	else
		for k = 1, #ReplayVehsT do
			if ReplayVehsT[k].VehHandle ~= 0 and ENTITY.DOES_ENTITY_EXIST(ReplayVehsT[k].VehHandle) then
				if ReplayVehsT[k].Blip ~= 0 then
					util.remove_blip(ReplayVehsT[k].Blip)
				end
				entities.delete_by_handle(ReplayVehsT[k].VehHandle)
			end
			if ReplayVehsT[k].PedHandle ~= 0 and ENTITY.DOES_ENTITY_EXIST(ReplayVehsT[k].PedHandle) then
				if ReplayVehsT[k].PedBlip ~= 0 then
					util.remove_blip(ReplayVehsT[k].PedBlip)
				end
				entities.delete_by_handle(ReplayVehsT[k].PedHandle)
			end
		end
		ReplayVehsT = {}
	end
end)

menu.action(SoloRecordingMenu, "Load Replays And Start Recording", {}, "If you want to combine replays, this is useful.", function(toggle)
	StartedFromScript = true
	menu.set_value(StartSelectedReplaysPTR, true)
end)
--local StartReplayCurVeh = false
--menu.toggle(menu.my_root(), "Replay From Cur Veh", {}, "", function(toggle)
--	StartReplayCurVeh = toggle
--	if StartReplayCurVeh then
--		local Paths = GetVectorsTable(LoadedFileName)
--		local Index = 0
--		local PlayerPed = PLAYER.PLAYER_PED_ID()
--		local Veh = PED.GET_VEHICLE_PED_IS_IN(PlayerPed, true)
--		local StartTimer = MISC.GET_GAME_TIMER()
--		while StartReplayCurVeh do
--			local GameTimer = MISC.GET_GAME_TIMER()
--			if Veh ~= 0 then
--				if ENTITY.DOES_ENTITY_EXIST(Veh) then
--					if Index == 0 then
--						Index = Index + 1
--						ENTITY.SET_ENTITY_COORDS(Veh, Paths[1].x, Paths[1].y, Paths[1].z)
--						ENTITY.SET_ENTITY_ROTATION(Veh, Paths[1].RotX, Paths[1].RotY, Paths[1].RotZ)
--					end
--					Index = math.max(math.floor((GameTimer - StartTimer) * SpeedMultiplier), 1)
--					if Index <= #Paths then
--						local TPos = {x = Paths[Index].x, y = Paths[Index].y, z = Paths[Index].z}
--						local OPos = ENTITY.GET_ENTITY_COORDS(Veh)
--						local NewV3 = {
--							x = (TPos.x - OPos.x) * 10.0,
--							y = (TPos.y - OPos.y) * 10.0,
--							z = (TPos.z - OPos.z) * 10.0
--						}
--						local Rot = {x = Paths[Index].RotX, y = Paths[Index].RotY, z = Paths[Index].RotZ}
--						
--						RotateEntityToTargetRotation(Veh, Rot, InterpolationFactor)
--						ENTITY.SET_ENTITY_VELOCITY(Veh, NewV3.x, NewV3.y, NewV3.z)
--						
--					else
--						break
--					end
--				else
--					break
--				end
--			else
--				break
--			end
--			Wait()
--		end
--	end
--end)
--
--local ReplayFromOffset = false
--menu.toggle(menu.my_root(), "Replay From Offset For Cur Veh", {}, "", function(toggle)
--	ReplayFromOffset = toggle
--	if ReplayFromOffset then
--		local Paths = GetVectorsTable(LoadedFileName)
--		local Index = 0
--		local PlayerPed = PLAYER.PLAYER_PED_ID()
--		local Offset = ENTITY.GET_ENTITY_COORDS(PlayerPed)
--		local StartPath = {x = Paths[1].x, y = Paths[1].y, z = Paths[1].z}
--		local Veh = PED.GET_VEHICLE_PED_IS_IN(PlayerPed, false)
--		local StartTimer = MISC.GET_GAME_TIMER()
--		while ReplayFromOffset do
--			local GameTimer = MISC.GET_GAME_TIMER()
--			if Veh ~= 0 then
--				if ENTITY.DOES_ENTITY_EXIST(Veh) then
--					if Index == 0 then
--						Index = Index + 1
--						ENTITY.SET_ENTITY_ROTATION(Veh, Paths[1].RotX, Paths[1].RotY, Paths[1].RotZ)
--					end
--					Index = math.max(math.floor((GameTimer - StartTimer) * SpeedMultiplier), 1)
--					if Index <= #Paths then
--						local TPos = {x = Paths[Index].x, y = Paths[Index].y, z = Paths[Index].z}
--						local OPos = ENTITY.GET_ENTITY_COORDS(Veh)
--						local NewV3 = {
--							x = (((Offset.x + (TPos.x - StartPath.x))) - OPos.x) * 10.0,
--							y = (((Offset.y + (TPos.y - StartPath.y))) - OPos.y) * 10.0,
--							z = (((Offset.z + (TPos.z - StartPath.z))) - OPos.z) * 10.0
--						}
--						local Rot = {x = Paths[Index].RotX, y = Paths[Index].RotY, z = Paths[Index].RotZ}
--						RotateEntityToTargetRotation(Veh, Rot, InterpolationFactor)
--						ENTITY.SET_ENTITY_VELOCITY(Veh, NewV3.x, NewV3.y, NewV3.z)
--					else
--						if Index > #Paths then
--							break
--						end
--					end
--				else
--					break
--				end
--			else
--				break
--			end
--			Wait()
--		end
--	end
--end)

function WriteFile(FileName, Contents)
	local File = io.open(FileName, "a")
    if File then
        File:write(Contents)
        io.close(File)
    end
end

function file_exists(file)
	local f = io.open(file, "rb")
	if f then f:close() end
	return f ~= nil
end
  

function file_lines(file)
	if not file_exists(file) then return {} end
	local lines = {}
	for line in io.lines(file) do
	  lines[#lines + 1] = line
	end
	return lines
end

function split_number(str)
    local t = {}
    for n in str:gmatch("%S+") do
        table.insert(t, tonumber(n))
    end
	return t
end

function GetVectorsTable(FileName)
	local VectorTable = {}
	local Vectors = file_lines(FileName)
	for i = 1, #Vectors do
		local Number = split_number(Vectors[i])
		VectorTable[#VectorTable+1] = {
			x = Number[1], y = Number[2], z = Number[3],
			RotX = Number[4], RotY = Number[5], RotZ = Number[6],
			VelX = Number[7], VelY = Number[8], VelZ = Number[9],
			AngVelX = Number[10], AngVelY = Number[11], AngVelZ = Number[12],
			CurGameTime = Number[13], ModelHash = Number[14]
		}
	end
	return VectorTable
end

function ToTxt(Pos, Rot, Vel, AngVel, CurGameTimer, VehModel)
    return string.format("%0.3f", Pos.x).." "..string.format("%0.3f", Pos.y).." "..string.format("%0.3f", Pos.z)..
    " "..string.format("%0.3f", Rot.x).." "..string.format("%0.3f", Rot.y).." "..string.format("%0.3f", Rot.z)..
    " "..string.format("%0.3f", Vel.x).." "..string.format("%0.3f", Vel.y).." "..string.format("%0.3f", Vel.z)..
    " "..string.format("%0.3f", AngVel.x).." "..string.format("%0.3f", AngVel.y).." "..string.format("%0.3f", AngVel.z)..
    " "..CurGameTimer.." "..VehModel.."\n"
end

function TimerCount(TimerT)
	local TimeMillis = util.current_time_millis()
	if TimeMillis > TimerT.Timer+10 then
		TimerT.TimerCount = TimerT.TimerCount + 1
		TimerT.Timer = TimeMillis
	end
end

function RequestModel(Model)
	if not STREAMING.HAS_MODEL_LOADED(Model) then
		STREAMING.REQUEST_MODEL(Model)
		while not STREAMING.HAS_MODEL_LOADED(Model) do
			Wait()
		end
	end
end

function RequestControlOfEntity(Entity)
	if NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(Entity) then
		return true
	else
		return NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(Entity)
	end
end

-- Função para converter ângulos de Euler para matriz de rotação (ordem XYZ)
function EulerToRotationMatrix(pitch, yaw, roll)
    local cx = math.cos(pitch)
    local sx = math.sin(pitch)
    local cy = math.cos(yaw)
    local sy = math.sin(yaw)
    local cz = math.cos(roll)
    local sz = math.sin(roll)

    return {
        {cy * cz, -cy * sz, sy},
        {sx * sy * cz + cx * sz, -sx * sy * sz + cx * cz, -sx * cy},
        {-cx * sy * cz + sx * sz, cx * sy * sz + sx * cz, cx * cy}
    }
end

-- Função para multiplicar duas matrizes 3x3
function MatrixMultiply(m1, m2)
    local result = {}
    for i = 1, 3 do
        result[i] = {}
        for j = 1, 3 do
            result[i][j] = m1[i][1] * m2[1][j] + m1[i][2] * m2[2][j] + m1[i][3] * m2[3][j]
        end
    end
    return result
end

-- Função para calcular a matriz de rotação inversa
function MatrixInverse(m)
    local determinant = m[1][1] * (m[2][2] * m[3][3] - m[2][3] * m[3][2]) -
                        m[1][2] * (m[2][1] * m[3][3] - m[2][3] * m[3][1]) +
                        m[1][3] * (m[2][1] * m[3][2] - m[2][2] * m[3][1])
    local invDet = 1 / determinant

    return {
        {
            invDet * (m[2][2] * m[3][3] - m[2][3] * m[3][2]),
            invDet * (m[1][3] * m[3][2] - m[1][2] * m[3][3]),
            invDet * (m[1][2] * m[2][3] - m[1][3] * m[2][2])
        },
        {
            invDet * (m[2][3] * m[3][1] - m[2][1] * m[3][3]),
            invDet * (m[1][1] * m[3][3] - m[1][3] * m[3][1]),
            invDet * (m[1][3] * m[2][1] - m[1][1] * m[2][3])
        },
        {
            invDet * (m[2][1] * m[3][2] - m[2][2] * m[3][1]),
            invDet * (m[1][2] * m[3][1] - m[1][1] * m[3][2]),
            invDet * (m[1][1] * m[2][2] - m[1][2] * m[2][1])
        }
    }
end

-- Função para obter a matriz de rotação da entidade
function GetEntityRotationMatrix(entity)
    local rot = ENTITY.GET_ENTITY_ROTATION(entity, 5)
    return EulerToRotationMatrix(math.rad(rot.x), math.rad(rot.y), math.rad(rot.z))
end

-- Função para converter uma matriz de rotação para quaternion
function RotationMatrixToQuaternion(m)
    local w = math.sqrt(1 + m[1][1] + m[2][2] + m[3][3]) / 2
    local x = (m[3][2] - m[2][3]) / (4 * w)
    local y = (m[1][3] - m[3][1]) / (4 * w)
    local z = (m[2][1] - m[1][2]) / (4 * w)
    return {w = w, x = x, y = y, z = z}
end

-- Função para calcular a velocidade angular a partir da diferença de quaternions
function QuaternionToAngularVelocity(q)
    local theta = 2 * math.acos(q.w)
    local sinTheta = math.sqrt(1 - q.w * q.w)
    if sinTheta < 0.001 then
        return {x = q.x * theta, y = q.y * theta, z = q.z * theta}
    else
        return {x = q.x / sinTheta * theta, y = q.y / sinTheta * theta, z = q.z / sinTheta * theta}
    end
end

-- Função principal para girar a entidade até a rotação desejada usando matrizes de rotação
function RotateEntityToTargetRotation(entity, targetRotation, interpolationFactor)
    interpolationFactor = interpolationFactor or 0.1 -- Fator de interpolação para suavizar a rotação

    -- Obtenha a matriz de rotação atual da entidade
    local currentRotationMatrix = GetEntityRotationMatrix(entity)

    -- Calcule a matriz de rotação alvo a partir dos ângulos de Euler desejados
    local targetRotationMatrix = EulerToRotationMatrix(math.rad(targetRotation.x), math.rad(targetRotation.y), math.rad(targetRotation.z))

    -- Calcule a matriz de rotação delta
    local deltaRotationMatrix = MatrixMultiply(targetRotationMatrix, MatrixInverse(currentRotationMatrix))

    -- Converta a matriz de rotação delta para quaternion
    local deltaQuaternion = RotationMatrixToQuaternion(deltaRotationMatrix)

    -- Converta a diferença de quaternion em velocidade angular
    local angularVelocity = QuaternionToAngularVelocity(deltaQuaternion)

    -- Interpole a velocidade angular para suavizar a rotação
    angularVelocity.x = angularVelocity.x * interpolationFactor
    angularVelocity.y = angularVelocity.y * interpolationFactor
    angularVelocity.z = angularVelocity.z * interpolationFactor

    -- Aplique a velocidade angular à entidade
    ENTITY.SET_ENTITY_ANGULAR_VELOCITY(entity, angularVelocity.x, angularVelocity.y, angularVelocity.z)
end

local MultiplayerRecording = menu.list(menu.my_root(), "Multiplayer Recording", {}, "Record and load with more than 1 vehicle tools.")


local FolderSelectMenu = menu.list(MultiplayerRecording, "Load Multiplayer Replay", {"loadmultiplayerreplaymenu"}, "", function() CreateMenuItemsFolder() end
, function ()
	CreateMenuItemsFolder()
end)

local PlayersToRecord = {}
local PlayersToRecordMenu = menu.list(MultiplayerRecording, "Which Players Record", {}, "Select players to record.", function()UpdatePlayersList()end, function()UpdatePlayersList()end)

local RecordPlayerBits = 0
for i = 1, 30 do
    if PlayersToRecord[i] == nil then
        local PlayerName = "---"
        if NETWORK.NETWORK_IS_PLAYER_ACTIVE(i-1) then
            PlayerName = PLAYER.GET_PLAYER_NAME(i-1)
        end
        PlayersToRecord[i] = {}
        PlayersToRecord[i].Include = false
        PlayersToRecord[i].MenuPTR = menu.toggle(PlayersToRecordMenu, PlayerName, {}, "", function(OnChange)
			PlayersToRecord[i].Include = OnChange
			if PlayersToRecord[i].Include == true then
				if not is_bit_set(RecordPlayerBits, i) then
					RecordPlayerBits = set_bit(RecordPlayerBits, i)
				end
			else
				if is_bit_set(RecordPlayerBits, i) then
					RecordPlayerBits = clear_bit(RecordPlayerBits, i)
				end
			end
		end, PlayersToRecord[i].Include)
    end
end

function UpdatePlayersList()
    for i = 1, 30 do
        if PlayersToRecord[i] ~= nil then
            local PlayerName = "---"
            if NETWORK.NETWORK_IS_PLAYER_ACTIVE(i-1) then
                PlayerName = PLAYER.GET_PLAYER_NAME(i-1)
            end
            menu.set_menu_name(PlayersToRecord[i].MenuPTR, PlayerName)
        end
    end
end

function is_bit_set(value, bit)
    bit = bit - 1
    return (value & (1 << bit)) ~= 0
end

function clear_bit(value, bit)
    bit = bit - 1;
    return value & ~(1 << bit)
end

function set_bit(value, bit)
    bit = bit - 1;
    return value | 1 << bit
end

local FolderListPTRs = {}
local LoadedFolderContents = {}
local FolderListOptions = {}

function CreateMenuItemsFolder()
	local FolderList = SetFilesList(PathDirSaveds, "")
	FolderListOptions = {}
	for k = 1, #FolderListPTRs do
		menu.delete(FolderListPTRs[#FolderListPTRs].PTR)
		table.remove(FolderListPTRs, #FolderListPTRs)
	end
	for k = 1, #FolderList do
		if FolderList[k].Is_Directory then
			local CanCreate = true
			for i = 1, #FolderListOptions do
				if FolderListOptions[i].DirectoryName == FolderList[k].FilePath then
					CanCreate = false
				end
			end
			if CanCreate then
				FolderListOptions[#FolderListOptions+1] = {Contents = {}, DirectoryName = FolderList[k].FilePath, DirectoryPath = FolderList[k].FilePath}
			end
		end
	end
	for k = 1, #FolderList do
		if not FolderList[k].Is_Directory then
			local Dir = FolderList[k].Directory
			for i = 1, #FolderListOptions do
				if FolderListOptions[i].DirectoryPath == Dir then
					Inserted = true
					FolderListOptions[i].Contents[#FolderListOptions[i].Contents+1] = {FilePath = FolderList[k].FilePath, FileName = FolderList[k].FileName}
				end
			end
		end
	end
	for k = 1, #FolderListOptions do
		local PTR = menu.action(FolderSelectMenu, FolderListOptions[k].DirectoryPath, {}, "", function(toggle) LoadedFolderContents = FolderListOptions[k].Contents end)
		FolderListPTRs[#FolderListPTRs+1] = {PTR = PTR}
	end
end

local FolderNameForSave = "Stored"
menu.text_input(MultiplayerRecording, "Set Folder Name", {"setfoldername"}, "Set folder name for saving multiple recordings.", function(OnChange) 
	FolderNameForSave = OnChange
end, FolderNameForSave)

local StartRecordMultiplayer = false
menu.toggle(MultiplayerRecording, "Start Multiplayer Recording", {}, "", function(toggle)
	StartRecordMultiplayer = toggle
	if StartRecordMultiplayer then
		local Dir = PathDirSaveds..FolderNameForSave
		filesystem.mkdir(Dir)
		local PlayersT = {}
		Dir = Dir.."\\"
		for k = 1, 30 do
			if is_bit_set(RecordPlayerBits, k) then
				if NETWORK.NETWORK_IS_PLAYER_ACTIVE(k-1) then
					local PlayerPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(k-1)
					if PlayerPed ~= 0 then
						if PED.IS_PED_IN_ANY_VEHICLE(PlayerPed, false) then
							PlayersT[#PlayersT+1] = {PlayerID = k-1, Records = {}}
						end
					end
				end
			end
		end
		while StartRecordMultiplayer do
			local GameTimer = MISC.GET_GAME_TIMER()
			for k = 1, #PlayersT do
				if NETWORK.NETWORK_IS_PLAYER_ACTIVE(PlayersT[k].PlayerID) then
					local PlayerPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(PlayersT[k].PlayerID)
					local Veh = PED.GET_VEHICLE_PED_IS_IN(PlayerPed, true)
					if Veh ~= 0 then
						local Pos = ENTITY.GET_ENTITY_COORDS(Veh)
						local Rot = ENTITY.GET_ENTITY_ROTATION(Veh, 5)
						local Vel = ENTITY.GET_ENTITY_VELOCITY(Veh)
						local AngVel = ENTITY.GET_ENTITY_ROTATION_VELOCITY(Veh)
						local VehModel = ENTITY.GET_ENTITY_MODEL(Veh)
						PlayersT[k].Records[#PlayersT[k].Records+1] = ToTxt(Pos, Rot, Vel, AngVel, GameTimer, VehModel)
						if #PlayersT[k].Records >= 1000 then
							local BigText = ""
							for i = 1, #PlayersT[k].Records do
								BigText = BigText..PlayersT[k].Records[i]
							end
							for i = 1, #PlayersT[k].Records do
								table.remove(PlayersT[k].Records, #PlayersT[k].Records)
							end
							WriteFile(Dir..k..".txt", BigText)
						end
					end
				end
			end
			Wait()
		end
		for k = 1, #PlayersT do
			local BigText = ""
			for i = 1, #PlayersT[k].Records do
				BigText = BigText..PlayersT[k].Records[i]
			end
			for i = 1, #PlayersT[k].Records do
				table.remove(PlayersT[k].Records, #PlayersT[k].Records)
			end
			WriteFile(Dir..k..".txt", BigText)
		end
	end
end)

--local MultiplayerModel = "elegy"
--menu.text_input(MultiplayerRecording, "Set Veh Model", {"setmpvehmodel"}, "Vehicle model will be created to perform the replay.", function(OnChange)
--	if STREAMING.IS_MODEL_VALID(joaat(OnChange)) then
--		MultiplayerModel = OnChange
--	end
--end)
--
--local M_UseStoredVehicleModel = true
--menu.toggle(MultiplayerRecording, "Use Stored Vehicle Model", {}, "Use vehicle model hash if is stored in the replay file", function(toggle)
--	M_UseStoredVehicleModel = toggle
--end, M_UseStoredVehicleModel)
--
--local StartMultiplayerReplay = false
--menu.toggle(MultiplayerRecording, "Start Selected Multiplayer Replay", {}, "", function(toggle)
--	StartMultiplayerReplay = toggle
--	if StartMultiplayerReplay then
--		local Paths = {}
--		for k = 1, #LoadedFolderContents do
--			local Paths_ = GetVectorsTable(LoadedFolderContents[k].FilePath)
--			Paths[#Paths+1] = Paths_
--		end
--		local Vehs = {}
--		RequestModel(joaat(MultiplayerModel))
--		for k = 1, #Paths do
--			local Veh = VEHICLE.CREATE_VEHICLE(joaat(MultiplayerModel), Paths[k][1].x, Paths[k][1].y, Paths[k][1].z, Paths[k][1].RotZ, true, true, false)
--			ENTITY.SET_ENTITY_AS_MISSION_ENTITY(Veh, false, true)
--			entities.set_can_migrate(Veh, false)
--			ENTITY.SET_ENTITY_INVINCIBLE(Veh, true)
--			NETWORK.NETWORK_SET_ENTITY_CAN_BLEND(Veh, true)
--			local Blip = HUD.ADD_BLIP_FOR_ENTITY(Veh)
--			HUD.SET_BLIP_COLOUR(Blip, 3)
--			Vehs[#Vehs+1] = {Handle = Veh, PathsTable = Paths[k], Index = 0, Blip = Blip}
--		end
--		STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(joaat(MultiplayerModel))
--		--local NetworkTime = NETWORK.GET_NETWORK_TIME_ACCURATE()
--		local StartTimer = MISC.GET_GAME_TIMER()
--		while StartMultiplayerReplay do
--			local GameTimer = MISC.GET_GAME_TIMER()
--			for k = 1, #Vehs do
--				if ENTITY.DOES_ENTITY_EXIST(Vehs[k].Handle) then
--					if Vehs[k].Index < #Vehs[k].PathsTable then
--						if Vehs[k].Index == 0 then
--							local TPos = {x = Vehs[k].PathsTable[1].x, y = Vehs[k].PathsTable[1].y, z = Vehs[k].PathsTable[1].z}
--							local Rot = {x = Vehs[k].PathsTable[1].RotX, y = Vehs[k].PathsTable[1].RotY, z = Vehs[k].PathsTable[1].RotZ}
--							ENTITY.SET_ENTITY_COORDS(Vehs[k].Handle,  TPos.x, TPos.y, TPos.z)
--							ENTITY.SET_ENTITY_ROTATION(Vehs[k].Handle, Rot.x, Rot.y, Rot.z, 5)
--							Vehs[k].Index = 1
--						end
--						local TPos = {x = Vehs[k].PathsTable[Vehs[k].Index].x, y = Vehs[k].PathsTable[Vehs[k].Index].y, z = Vehs[k].PathsTable[Vehs[k].Index].z}
--						local OPos = ENTITY.GET_ENTITY_COORDS(Vehs[k].Handle)
--						local Rot = {x = Vehs[k].PathsTable[Vehs[k].Index].RotX, y = Vehs[k].PathsTable[Vehs[k].Index].RotY, z = Vehs[k].PathsTable[Vehs[k].Index].RotZ}
--						if DistanceBetween(OPos.x, OPos.y, OPos.z, TPos.x, TPos.y, TPos.z) < 100.0 then
--							local CurrentTime = GameTimer - StartTimer
--							local Frame1, Frame2 = Vehs[k].PathsTable[Vehs[k].Index], Vehs[k].PathsTable[Vehs[k].Index + 1]
--							if CurrentTime > (Frame2.CurGameTime - Vehs[k].PathsTable[1].CurGameTime) then
--								Vehs[k].Index = Vehs[k].Index + 1
--								if Vehs[k].Index >= #Vehs[k].PathsTable then
--									Vehs[k].Index = 1
--								else
--									Frame1, Frame2 = Vehs[k].PathsTable[Vehs[k].Index], Vehs[k].PathsTable[Vehs[k].Index + 1]
--								end
--							end
--							local Coord = {
--								x = Vehs[k].PathsTable[Vehs[k].Index].x,
--								y = Vehs[k].PathsTable[Vehs[k].Index].y,
--								z = Vehs[k].PathsTable[Vehs[k].Index].z
--							}
--							local Rot2 = {
--								x = Vehs[k].PathsTable[Vehs[k].Index].RotX,
--								y = Vehs[k].PathsTable[Vehs[k].Index].RotY,
--								z = Vehs[k].PathsTable[Vehs[k].Index].RotZ
--							}
--							local Vel = {
--								x = Vehs[k].PathsTable[Vehs[k].Index].VelX,
--								y = Vehs[k].PathsTable[Vehs[k].Index].VelY,
--								z = Vehs[k].PathsTable[Vehs[k].Index].VelZ
--							}
--							local AngVel = {
--								x = Vehs[k].PathsTable[Vehs[k].Index].AngVelX,
--								y = Vehs[k].PathsTable[Vehs[k].Index].AngVelY,
--								z = Vehs[k].PathsTable[Vehs[k].Index].AngVelZ
--							}
--							SetEntitySpeedToCoord(Vehs[k].Handle, Coord, 1.0,
--							false, false, false, Vel.x, Vel.y, Vel.z, false, false, nil)
--							RotateEntityToTargetRotation(Vehs[k].Handle, Rot2, 10.0)
--						else
--							ENTITY.SET_ENTITY_COORDS(Vehs[k].Handle,  TPos.x, TPos.y, TPos.z)
--							ENTITY.SET_ENTITY_ROTATION(Vehs[k].Handle, Rot.x, Rot.y, Rot.z, 5)
--						end
--					end
--				end
--			end
--			Wait()
--		end
--		for k = 1, #Vehs do
--			if ENTITY.DOES_ENTITY_EXIST(Vehs[k].Handle) then
--				util.remove_blip(Vehs[k].Blip)
--				entities.delete_by_handle(Vehs[k].Handle)
--			end
--		end
--	end
--end)

--local GameModesMenu = menu.list(menu.my_root(), "Game Modes", {}, "")
--
--local CargobobChaseWars = false
--menu.toggle(GameModesMenu, "Cargobob Chase Wars", {}, "", function(toggle)
--	CargobobChaseWars = toggle
--	if CargobobChaseWars then
--		local Paths1 = GetVectorsTable(PathDirSaveds.."CargobobJob_1.txt")
--		local Paths2 = GetVectorsTable(PathDirSaveds.."CargobobJob_2.txt")
--		local Paths = {Paths1, Paths2}
--		local Vehs = {}
--		local Objs = {}
--		local VehsLocal = SplitGlobals("Local_22960.f_834.f_81")
--		local ObjsLocal = SplitGlobals("Local_22960.f_834.f_147")
--		local Spd = {13, 10}
--		local NetworkTime = NETWORK.GET_NETWORK_TIME_ACCURATE()
--		local Started = false
--		while CargobobChaseWars do
--			if SCRIPT.GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH(joaat("fm_mission_controller")) > 0 then
--				if PLAYER.IS_PLAYER_CONTROL_ON(PLAYER.PLAYER_ID()) then
--				 	Started = true
--				end
--				if Started then
--					local TimeStep = SYSTEM.TIMESTEP()
--					local AccurateNetTime = NETWORK.GET_NETWORK_TIME_ACCURATE()
--					for k = 1, 4 do
--						if k <= 2 then
--							if Vehs[k] == nil then
--								local NetID = memory.read_int(memory.script_local("fm_mission_controller", VehsLocal+k))
--								if NetID ~= 0 then
--									local Handle = 0
--									util.spoof_script("fm_mission_controller", function()
--										Handle = NETWORK.NET_TO_VEH(NetID)
--									end)
--									if Handle ~= 0 then
--										Vehs[k] = {Handle = Handle, PathsTable = Paths[k], Spd = Spd[k]}
--										NetworkTime = NETWORK.GET_NETWORK_TIME_ACCURATE()
--									end
--								end
--							end
--						end
--						if k >= 3 then
--							if Vehs[k] == nil then
--								local NetID = memory.read_int(memory.script_local("fm_mission_controller", VehsLocal+k))
--								if NetID ~= 0 then
--									local Handle = 0
--									util.spoof_script("fm_mission_controller", function()
--										Handle = NETWORK.NET_TO_VEH(NetID)
--									end)
--									if Handle ~= 0 then
--										Vehs[k] = {Handle = Handle}
--									end
--								end
--							end
--						end
--					end
--					for k = 1, 4 do
--						if Vehs[k] ~= nil then
--							if ENTITY.DOES_ENTITY_EXIST(Vehs[k].Handle) then
--								if RequestControlOfEntity(Vehs[k].Handle) then
--									NETWORK.NETWORK_SET_ENTITY_CAN_BLEND(Vehs[k].Handle, true)
--									entities.set_can_migrate(Vehs[k].Handle, false)
--									ENTITY.SET_ENTITY_HAS_GRAVITY(Vehs[k].Handle, false)
--									--ENTITY.SET_ENTITY_INVINCIBLE(Vehs[k].Handle, true)
--								end
--								if k <= 2 then
--									ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(Vehs[1].Handle, Vehs[2].Handle, false)
--									--ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(Vehs[2].Handle, Vehs[1].Handle, false)
--									VEHICLE.SET_VEHICLE_DOOR_CONTROL(Vehs[k].Handle, 2, 180, 180.0)
--									VEHICLE.SET_DOOR_ALLOWED_TO_BE_BROKEN_OFF(Vehs[k].Handle, 2, false)
--									VEHICLE.SET_HELI_TAIL_ROTOR_HEALTH(Vehs[k].Handle, 100000.0)
--									VEHICLE.SET_HELI_MAIN_ROTOR_HEALTH(Vehs[k].Handle, 100000.0)
--									VEHICLE.SET_HELI_TAIL_BOOM_CAN_BREAK_OFF(Vehs[k].Handle, false) 
--									local Calc = NETWORK.GET_TIME_DIFFERENCE(AccurateNetTime, NetworkTime)
--									Calc = math.max(math.floor(Calc / Vehs[k].Spd), 1)
--									local Index = Calc
--									if Index <= #Vehs[k].PathsTable then
--										local TPos = {x = Vehs[k].PathsTable[Index].x, y = Vehs[k].PathsTable[Index].y, z = Vehs[k].PathsTable[Index].z}
--										local OPos = ENTITY.GET_ENTITY_COORDS(Vehs[k].Handle)
--										local NewV3 = {
--											x = (TPos.x - OPos.x) * 1.0,
--											y = (TPos.y - OPos.y) * 1.0,
--											z = (TPos.z - OPos.z) * 1.0
--										}
--										local Rot = {x = Vehs[k].PathsTable[Index].RotX, y = Vehs[k].PathsTable[Index].RotY, z = Vehs[k].PathsTable[Index].RotZ}
--										
--										RotateEntityToTargetRotation(Vehs[k].Handle, Rot, InterpolationFactor)
--										ENTITY.SET_ENTITY_VELOCITY(Vehs[k].Handle, NewV3.x, NewV3.y, NewV3.z)
--									end
--								end
--							end
--						end
--					end
--					if Vehs[1] ~= nil and Vehs[2] ~= nil then
--						for k = 1, 2 do
--							if Objs[k] == nil then
--								local NetID = memory.read_int(memory.script_local("fm_mission_controller", ObjsLocal+k))
--								if NetID ~= 0 then
--									local Handle = 0
--									util.spoof_script("fm_mission_controller", function()
--										Handle = NETWORK.NET_TO_OBJ(NetID)
--									end)
--									if Handle ~= 0 then
--										Objs[k] = {Handle = Handle}
--									end
--								end
--							end
--							if Objs[k] ~= nil then
--								if ENTITY.DOES_ENTITY_EXIST(Objs[k].Handle) then
--									if RequestControlOfEntity(Objs[k].Handle) then
--										entities.set_can_migrate(Objs[k].Handle, false)
--										ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION(Objs[k].Handle, false, true)
--									end
--									if k == 1 then
--										if not ENTITY.IS_ENTITY_ATTACHED(Vehs[3].Handle) then
--											ENTITY.ATTACH_ENTITY_TO_ENTITY(Vehs[3].Handle, Objs[k].Handle, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, false, false, false, 2, true, false)
--										end
--										--ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(Objs[k].Handle, Vehs[1].Handle, false)
--										local TPos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(Vehs[1].Handle, 0.0, 0.0, 0.0)
--										local OPos = ENTITY.GET_ENTITY_COORDS(Objs[k].Handle)
--										local Speed = ENTITY.GET_ENTITY_VELOCITY(Vehs[1].Handle)
--										local NewV3 = {
--											x = ((TPos.x + Speed.x) - OPos.x) * 1.0,
--											y = ((TPos.y + Speed.y) - OPos.y) * 1.0,
--											z = ((TPos.z + Speed.z) - OPos.z) * 1.0
--										}
--										local Rot = ENTITY.GET_ENTITY_ROTATION(Vehs[1].Handle, 5)
--										RotateEntityToTargetRotation(Objs[k].Handle, Rot, InterpolationFactor)
--										ENTITY.SET_ENTITY_VELOCITY(Objs[k].Handle, NewV3.x, NewV3.y, NewV3.z)
--									end
--									if k == 2 then
--										if not ENTITY.IS_ENTITY_ATTACHED(Vehs[4].Handle) then
--											ENTITY.ATTACH_ENTITY_TO_ENTITY(Vehs[4].Handle, Objs[k].Handle, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, false, false, false, 2, true, false)
--										end
--										--ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(Objs[k].Handle, Vehs[2].Handle, false)
--										local TPos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(Vehs[2].Handle, 0.0, 0.0, 0.0)
--										local OPos = ENTITY.GET_ENTITY_COORDS(Objs[k].Handle)
--										local Speed = ENTITY.GET_ENTITY_VELOCITY(Vehs[2].Handle)
--										local NewV3 = {
--											x = ((TPos.x + Speed.x) - OPos.x) * 1.0,
--											y = ((TPos.y + Speed.y) - OPos.y) * 1.0,
--											z = ((TPos.z + Speed.z) - OPos.z) * 1.0
--										}
--										local Rot = ENTITY.GET_ENTITY_ROTATION(Vehs[2].Handle, 5)
--										RotateEntityToTargetRotation(Objs[k].Handle, Rot, InterpolationFactor)
--										ENTITY.SET_ENTITY_VELOCITY(Objs[k].Handle, NewV3.x, NewV3.y, NewV3.z)
--									end
--								end
--							end
--						end
--					end
--				end
--			else
--				Started = false
--				for k = 1, 4 do
--					Vehs[k] = nil
--				end
--				for k = 1, 12 do
--					Objs[k] = nil
--				end
--			end
--			Wait()
--		end
--	end
--end)

function SplitGlobals(GlobalString)
	local String = GlobalString
	local Value = String:gsub("%[(.-)]", "+1")
	local NewValue = Value:gsub("%a", "")
	local NewValue2 = NewValue:gsub("._", "+")
	local NewValue3 = NewValue2:gsub("_", "")
	local _Text, SymbolCount = NewValue3:gsub("+", "")
	local PatternCount = "(%d+)"
	for i = 1, SymbolCount do
		PatternCount = PatternCount .. "+(%d+)"
	end
	local Global, Global2, Global3, Global4, Global5, Global6, Global7 = NewValue3:match(PatternCount)
	local GlobalNumber = 0
	if Global ~= nil then
		GlobalNumber = GlobalNumber + tonumber(Global)
	end
	if Global2 ~= nil then
		GlobalNumber = GlobalNumber + tonumber(Global2)
	end
	if Global3 ~= nil then
		GlobalNumber = GlobalNumber + tonumber(Global3)
	end
	if Global4 ~= nil then
		GlobalNumber = GlobalNumber + tonumber(Global4)
	end
	if Global5 ~= nil then
		GlobalNumber = GlobalNumber + tonumber(Global5)
	end
	if Global6 ~= nil then
		GlobalNumber = GlobalNumber + tonumber(Global6)
	end
	if Global7 ~= nil then
		GlobalNumber = GlobalNumber + tonumber(Global7)
	end
	return GlobalNumber
end

function angleDifference(target, current)
    local diff = target - current
    if diff > 180 then
        diff = diff - 360
    elseif diff < -180 then
        diff = diff + 360
    end
    return diff
end

-- Função para converter graus para radianos
local function deg2rad(deg)
    return deg * math.pi / 180.0
end

-- Função para converter radianos para graus
local function rad2deg(rad)
    return rad * 180.0 / math.pi
end

-- Função para limitar o ângulo no intervalo de -180 a 180 graus
local function wrap180(deg)
    while deg <= -180.0 do deg = deg + 360.0 end
    while deg > 180.0 do deg = deg - 360.0 end
    return deg
end

-- Função para converter rotação XYZ para ZYX
function convertRotationXYZtoZYX(rotX, rotY, rotZ)
    -- Converter para radianos
    local x = deg2rad(rotX)
    local y = deg2rad(rotY)
    local z = deg2rad(rotZ)

    -- Matriz de rotação para XYZ
    local cosX = math.cos(x)
    local sinX = math.sin(x)
    local cosY = math.cos(y)
    local sinY = math.sin(y)
    local cosZ = math.cos(z)
    local sinZ = math.sin(z)

    local Rxyz = {
        {cosY * cosZ, -cosY * sinZ, sinY},
        {sinX * sinY * cosZ + cosX * sinZ, -sinX * sinY * sinZ + cosX * cosZ, -sinX * cosY},
        {-cosX * sinY * cosZ + sinX * sinZ, cosX * sinY * sinZ + sinX * cosZ, cosX * cosY}
    }

    -- Extrair ângulos ZYX da matriz de rotação
    local rotZ2 = math.atan2(Rxyz[2][1], Rxyz[1][1])
    local rotY2 = math.asin(-Rxyz[3][1])
    local rotX2 = math.atan2(Rxyz[3][2], Rxyz[3][3])

    -- Converter de volta para graus
    rotX2 = rad2deg(rotX2)
    rotY2 = rad2deg(rotY2)
    rotZ2 = rad2deg(rotZ2)

    -- Ajustar ângulos para o intervalo de -180 a 180 graus
    rotX2 = wrap180(rotX2)
    rotY2 = wrap180(rotY2)
    rotZ2 = wrap180(rotZ2)

    return {x = rotX2, y = -rotY2, z = rotZ2}
end

-- Função para adicionar duas rotações e retornar a rotação normalizada
function addRotation(rot1, rot2)
    local result = rot1 + rot2
    return wrap180(result)
end

-- Função para subtrair duas rotações e retornar a rotação normalizada
function subtractRotation(rot1, rot2)
    local result = rot1 - rot2
    return wrap180(result)
end

function DistanceBetween(x1, y1, z1, x2, y2, z2)
	local dx = x1 - x2
	local dy = y1 - y2
	local dz = z1 - z2
	return math.sqrt ( dx * dx + dy * dy + dz * dz)
end

function CalculateOffsetZYX(basePos, rotation, forwardOffset, sideOffset, verticalOffset)
    -- Converte ângulos de graus para radianos
    local radZ = math.rad(rotation.z)
    local radY = math.rad(rotation.y)
    local radX = math.rad(rotation.x)

    -- Calcula os vetores de direção usando ZYX
    local cosZ, sinZ = math.cos(radZ), math.sin(radZ)
    local cosY, sinY = math.cos(radY), math.sin(radY)
    local cosX, sinX = math.cos(radX), math.sin(radX)

    -- Forward vector (Z depois Y depois X)
    local forward = {
        x = cosY * cosZ,
        y = cosY * sinZ,
        z = -sinY
    }

    -- Right vector
    local right = {
        x = cosZ * sinY * sinX - sinZ * cosX,
        y = sinZ * sinY * sinX + cosZ * cosX,
        z = cosY * sinX
    }

    -- Up vector
    local up = {
        x = cosZ * sinY * cosX + sinZ * sinX,
        y = sinZ * sinY * cosX - cosZ * sinX,
        z = cosY * cosX
    }

    -- Calcula a posição final com offset
    local finalPos = {
        x = basePos.x + forward.x * forwardOffset + right.x * sideOffset + up.x * verticalOffset,
        y = basePos.y + forward.y * forwardOffset + right.y * sideOffset + up.y * verticalOffset,
        z = basePos.z + forward.z * forwardOffset + right.z * sideOffset + up.z * verticalOffset
    }

    return finalPos
end

--local RailMode = false
--menu.toggle(GameModesMenu, "Rail Mode Race", {}, "", function(toggle)
--	RailMode = toggle
--	if RailMode then
--		local Paths = GetVectorsTable(PathDirSaveds.."ScriptedRails.txt")
--		local PlayersT = {}
--		local MaxOffsetX = 5.0
--		while RailMode do
--			local GameTimer = MISC.GET_GAME_TIMER()
--			for k = 0, 29 do
--				if NETWORK.NETWORK_IS_PLAYER_CONNECTED(k) then
--					if PlayersT[k] == nil then
--						PlayersT[k] = {}
--						PlayersT[k].OffsetX = 0.0
--						PlayersT[k].Speed = 0.0
--						PlayersT[k].Index = 1
--						PlayersT[k].LastTimer = nil
--						PlayersT[k].TickDuration = 1000 / FPS
--						PlayersT[k].LastTickTime = GameTimer
--					end
--					local PlayerPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(k)
--					if PlayerPed ~= 0 then
--						local Veh = PED.GET_VEHICLE_PED_IS_IN(PlayerPed, false)
--						if Veh ~= 0 and PED.IS_PED_IN_VEHICLE(PlayerPed, Veh, false) then
--							if RequestControlOfEntity(Veh) then
--								ENTITY.SET_ENTITY_AS_MISSION_ENTITY(Veh, false, true)
--								entities.set_can_migrate(Veh, false)
--							end
--							local BoneIndex = ENTITY.GET_ENTITY_BONE_INDEX_BY_NAME(Veh, "steeringwheel")
--							if BoneIndex ~= 0 then
--								local Rot = subtractRotation(ENTITY.GET_ENTITY_ROTATION(Veh, 2).z, players.get_cam_rot(k).z)
--								PlayersT[k].OffsetX = PlayersT[k].OffsetX + Rot * 0.005
--								if PlayersT[k].OffsetX > MaxOffsetX then
--									PlayersT[k].OffsetX = MaxOffsetX
--								end
--								if PlayersT[k].OffsetX < -MaxOffsetX then
--									PlayersT[k].OffsetX = -MaxOffsetX
--								end
--							end
--							if (GameTimer - PlayersT[k].LastTickTime) >= PlayersT[k].TickDuration then
--								if PlayersT[k].LastTimer ~= nil then
--									local TimeDiff = GameTimer - PlayersT[k].LastTimer
--									local LostTicks = math.floor(TimeDiff / PlayersT[k].TickDuration)
--									if LostTicks > 0 then
--										PlayersT[k].Index = PlayersT[k].Index + LostTicks + 1
--									else
--										PlayersT[k].Index = PlayersT[k].Index + 1
--									end
--								else
--									PlayersT[k].Index = PlayersT[k].Index + 1
--								end
--								PlayersT[k].LastTickTime = GameTimer
--							end
--							PlayersT[k].LastTimer = GameTimer
--							if PlayersT[k].Index <= #Paths then
--								local Rot = {x = Paths[PlayersT[k].Index].RotX, y = Paths[PlayersT[k].Index].RotY, z = Paths[PlayersT[k].Index].RotZ}
--								local TPos = {x = Paths[PlayersT[k].Index].x, y = Paths[PlayersT[k].Index].y, z = Paths[PlayersT[k].Index].z}
--								local NewPos = CalculateOffsetZYX(TPos, Rot, PlayersT[k].OffsetX, 0.0, 0.0)
--								local OPos = ENTITY.GET_ENTITY_COORDS(Veh)
--								local NewV3 = {
--									x = (NewPos.x - OPos.x) * 5.0,
--									y = (NewPos.y - OPos.y) * 5.0,
--									z = (NewPos.z - OPos.z) * 5.0
--								}
--								
--								
--								RotateEntityToTargetRotation(Veh, Rot, InterpolationFactor)
--								ENTITY.SET_ENTITY_VELOCITY(Veh, NewV3.x, NewV3.y, NewV3.z)
--								--ENTITY.SET_ENTITY_COORDS(Veh, TPos.x, TPos.y, TPos.z, false, true)
--							end
--						end
--					end
--				else
--					PlayersT[k] = nil
--				end
--			end
--			Wait()
--		end
--	end
--end)

function SetEntitySpeedToCoord(Entity, CoordTarget, Mul, IgnoreX, IgnoreY, IgnoreZ, AddX, AddY, AddZ, Normalise, Relative, OverridePos)
    local OPos = nil
    if OverridePos ~= nil then
        OPos = OverridePos
    else
        OPos = ENTITY.GET_ENTITY_COORDS(Entity)
    end
	local NewV3 = {
        x = (CoordTarget.x - OPos.x) * Mul,
        y = (CoordTarget.y - OPos.y) * Mul,
        z = (CoordTarget.z - OPos.z) * Mul
    }
    if IgnoreX then
        NewV3.x = 0.0
    end
    if IgnoreY then
        NewV3.y = 0.0
    end
    if IgnoreZ then
        NewV3.z = 0.0
    end
    if Normalise then
        NewV3 = v3.new(NewV3.x, NewV3.y, NewV3.z)
		if DistanceBetween(OPos.x, OPos.y, OPos.z, CoordTarget.x, CoordTarget.y, CoordTarget.z) * 0.5 > 1.0 then
			NewV3:normalise()
			NewV3:mul(Mul)
		end
    end
    local MoreX, MoreY, MoreZ = AddX, AddY, AddZ
    if Relative then
        local FVect, RVect, UpVect, Vect = v3.new(), v3.new(), v3.new(), v3.new()
		ENTITY.GET_ENTITY_MATRIX(Entity, FVect, RVect, UpVect, Vect)
        MoreX = (FVect.x * AddY) + (RVect.x * AddX) + (UpVect.x + AddZ)
        MoreY = (FVect.y * AddY) + (RVect.y * AddX) + (UpVect.y + AddZ)
        MoreZ = (FVect.z * AddY) + (RVect.z * AddX) + (UpVect.z + AddZ)
    end
    ENTITY.SET_ENTITY_VELOCITY(Entity, (NewV3.x) + MoreX, (NewV3.y) + MoreY, (NewV3.z) + MoreZ)
end

--local ScriptedToolsMenu = menu.list(menu.my_root(), "Scripted Tools", {}, "")
