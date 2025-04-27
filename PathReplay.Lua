util.require_natives(1676318796)

Print = util.toast
Wait = util.yield
joaat = util.joaat

local FileNameForSave = "StoredPath"
local PathDirSaveds = filesystem.scripts_dir().."Paths\\"
local LoadedFileName = FileNameForSave

filesystem.mkdirs(filesystem.scripts_dir().."Paths")
filesystem.mkdirs(PathDirSaveds.."EditedRecords")
filesystem.mkdirs(PathDirSaveds.."ContinuedRecords")

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
local MultiplayerRecordingPTR = nil
local Advanced_StartRecordingPTR = nil

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

function ClearFile(FileName)
    local File = io.open(FileName, "w")  -- Abrir em modo de escrita ("w") para limpar
    if File then
        File:close()  -- Fechar o arquivo para garantir que foi zerado
    end
end

local AiHateRel = "rgFM_AiHate"
local AiLikeRel = "rgFM_AiLike"
local AiLikeHateAiHateRel = "rgFM_AiLike_HateAiHate"
local AiHateAiHateRel = "rgFM_HateAiHate"
local AiHateEveryone = "rgFM_HateEveryOne"

local EmptyRecord = false
local EmptyRecordPTR = menu.toggle(SoloRecordingMenu, "First Clear Recording File", {}, "", function(toggle)
	EmptyRecord = toggle
end, EmptyRecord)

local RecordT = {}
local GlobalReplayTime = 0  -- tempo virtual de reprodução, em ms
local ReplaySpeed = 1.0     -- 1.0 = velocidade normal, negativo seria rebobinar
local IsRewinding = false
local StartRecord = false
local StartRecordingPTR = menu.toggle(SoloRecordingMenu, "Start Recording", {}, "", function(toggle)
    StartRecord = toggle
    if StartRecord then
		--GlobalReplayTime = 0
        if EmptyRecord then
            ClearFile(PathDirSaveds..FileNameForSave..".txt")
        end
        local StartedTime = MISC.GET_GAME_TIMER()
        local LastTime = 0
        local PausedTimeStart = 0
        local IsPaused = false
        local LastValidTime = 0

        while StartRecord do
            local PlayerPed = PLAYER.PLAYER_PED_ID()
            local Veh = PED.GET_VEHICLE_PED_IS_IN(PlayerPed, true)
            local GameTimer = MISC.GET_GAME_TIMER()

            PAD.DISABLE_CONTROL_ACTION(0, 75)
			PAD.DISABLE_CONTROL_ACTION(0, 99)
            local ExitPressed = PAD.IS_DISABLED_CONTROL_PRESSED(0, 75) or PAD.IS_DISABLED_CONTROL_PRESSED(0, 99)

            if Veh ~= 0 then
                if ExitPressed then
                    if not IsPaused then
                        IsPaused = true
                        PausedTimeStart = GameTimer
                    end

                    -- Rebobinar: remover último frame
                    if #RecordT > 0 then
                        table.remove(RecordT, #RecordT)

                        -- Atualiza o LastValidTime
                        if #RecordT > 0 then
                            local LastFrame = GetVectorsFromIndex(RecordT[#RecordT])
                            LastValidTime = LastFrame.CurGameTime
                            ENTITY.SET_ENTITY_COORDS(Veh, LastFrame.x, LastFrame.y, LastFrame.z, false, false, true)
                            ENTITY.SET_ENTITY_ROTATION(Veh, LastFrame.RotX, LastFrame.RotY, LastFrame.RotZ, 5)
                            ENTITY.SET_ENTITY_VELOCITY(Veh, LastFrame.VelX, LastFrame.VelY, LastFrame.VelZ)
                            ENTITY.SET_ENTITY_ANGULAR_VELOCITY(Veh, LastFrame.AngVelX, LastFrame.AngVelY, LastFrame.AngVelZ)
							VEHICLE.SET_VEHICLE_FORWARD_SPEED(Veh, math.sqrt(LastFrame.VelX^2 + LastFrame.VelY^2 + LastFrame.VelZ^2))
                        else
                            LastValidTime = 0
                        end
                    end

                else
                    if IsPaused then
                        -- Terminou rebobinamento
                        local GameTimerNow = MISC.GET_GAME_TIMER()

                        -- ⚡ Aqui a correção real:
                        StartedTime = GameTimerNow - LastValidTime

                        IsPaused = false
                    end

                    -- Gravar normalmente
                    local Elapsed = GameTimer - StartedTime
                    LastTime = Elapsed
					--Global_StartedTime = StartedTime

                    local Pos = ENTITY.GET_ENTITY_COORDS(Veh)
                    local Rot = ENTITY.GET_ENTITY_ROTATION(Veh, 5)
                    local Vel = ENTITY.GET_ENTITY_VELOCITY(Veh)
                    local AngVel = ENTITY.GET_ENTITY_ROTATION_VELOCITY(Veh)
                    local VehModel = ENTITY.GET_ENTITY_MODEL(Veh)
                    local BoneID = ENTITY.GET_ENTITY_BONE_INDEX_BY_NAME(Veh, "steeringwheel")
                    local Steering = 0.0
                    if BoneID ~= 0 then
                        local SteeringRot = ENTITY.GET_ENTITY_BONE_OBJECT_ROTATION(Veh, BoneID)
                        SteeringRot:normalise()
                        Steering = -SteeringRot.y
                    end

                    RecordT[#RecordT+1] = ToTxt(Pos, Rot, Vel, AngVel, Elapsed, VehModel, Steering)
                end
            end
			IsRewinding = IsPaused
            -- Debug Visual
            --directx.draw_text(0.5, 0.55, "GameTimer "..GameTimer, ALIGN_CENTRE, 1.0, {r = 0.0, g = 1.0 , b = 1.0, a = 1.0}, false)
            --directx.draw_text(0.5, 0.6, "StartedTime "..StartedTime, ALIGN_CENTRE, 1.0, {r = 0.0, g = 1.0 , b = 1.0, a = 1.0}, false)
            --directx.draw_text(0.5, 0.65, "LastTime "..LastTime, ALIGN_CENTRE, 1.0, {r = 0.0, g = 1.0 , b = 1.0, a = 1.0}, false)

            Wait()
        end

        -- Salvar no final
        local BigText = table.concat(RecordT)
        WriteFile(PathDirSaveds..FileNameForSave..".txt", BigText)
        RecordT = {}
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

local FrameStartIndex = 1
menu.slider(SoloRecordingMenu, "Frame Start Index", {"setstartingframe"}, "Useful to jump to a specific part of the replay.", 1, 50000000, 1, 1000, function(OnChange)
	FrameStartIndex = OnChange
end)

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

local CreatePedToReplay = true
menu.toggle(SoloRecordingMenu, "Create Ped To Replay Vehicles", {}, "", function(toggle)
	CreatePedToReplay = toggle
end, CreatePedToReplay)

local ReplayTeleportMode = false
menu.toggle(SoloRecordingMenu, "Replay Teleport Mode", {}, "Use teleportation instead of velocity physics.", function(toggle)
	ReplayTeleportMode = toggle
end, ReplayTeleportMode)

local WaitBeforeStartReplay = false
local UseMilisAdjustLoop = true
local Multiplayer_StartedFromScript = false
local StartedFromScript = false
local Advanced_StartedFromScript = false
local ReplayVehsT = {}
local StartReplay = false
local StartSelectedReplaysPTR = menu.toggle(SoloRecordingMenu, "Start Selected Replay", {}, "", function(toggle)
	StartReplay = toggle
	if StartReplay then
		for k, value in pairs(ReplaysToLoad) do
			ReplayVehsT[#ReplayVehsT+1] = {
				VehHandle = 0,
				ModelHash = 0,
				Paths = GetVectorsTable(k, true, false),
				Index = 0,
				Blip = 0,
				StartTimer = 0,
				PedHandle = 0,
				PedBlip = 0,
				HasSetStartTimer = false,
				SteerMilis = 0,
				IsCargoPlane = false
			}
		end
		for k = 1, #ReplayVehsT do
			if ReplayVehsT[k].Paths ~= nil and ReplayVehsT[k].Paths[1] ~= nil then
				if not UseStoredVehicleModel then
					ReplayVehsT[k].Paths[1].ModelHash = joaat(Model)
				end
				ReplayVehsT[k].ModelHash = ReplayVehsT[k].Paths[1].ModelHash or joaat(Model)
				if ReplayVehsT[k].VehHandle == 0 then
					if not STREAMING.IS_MODEL_VALID(ReplayVehsT[k].ModelHash) then
						ReplayVehsT[k].ModelHash = joaat(Model)
					end
					ReplayVehsT[k].IsCargoPlane = ReplayVehsT[k].ModelHash == joaat("cargoplane") or ReplayVehsT[k].ModelHash == joaat("cargoplane2")
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
						UpgradeVehicle(ReplayVehsT[k].VehHandle, true, true, true)
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
									PED.SET_PED_CAN_BE_KNOCKED_OFF_VEHICLE(ReplayVehsT[k].PedHandle, 1)
								else
									STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(joaat(PedModel))
								end
							end
						end
						ENTITY.FREEZE_ENTITY_POSITION(ReplayVehsT[k].VehHandle, true)
						ENTITY.SET_ENTITY_COORDS(ReplayVehsT[k].VehHandle, ReplayVehsT[k].Paths[1].x, ReplayVehsT[k].Paths[1].y, ReplayVehsT[k].Paths[1].z)
						ENTITY.SET_ENTITY_ROTATION(ReplayVehsT[k].VehHandle, ReplayVehsT[k].Paths[1].RotX, ReplayVehsT[k].Paths[1].RotY, ReplayVehsT[k].Paths[1].RotZ, 5)
					else
						STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(ReplayVehsT[k].ModelHash)
					end
				end
			end
		end
		local LastEnt = 0
		local WaitWasEnabled = false
		while WaitBeforeStartReplay do
			WaitWasEnabled = true
			--if LastEnt == 0 then
				local PVeh = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), true)
				if PVeh ~= 0 then
					local NewLastEnt = ENTITY._GET_LAST_ENTITY_HIT_BY_ENTITY(PVeh)
					if NewLastEnt ~= 0 then
						LastEnt = NewLastEnt
					end
				end
			--end
			Wait()
		end
		GlobalReplayTime = 0
		local StartTimer = MISC.GET_GAME_TIMER()
		while StartReplay do
			--VEHICLE.SET_VEHICLE_DOOR_CONTROL(Veh, 2, 360, 360.0)
			local GameTimer = MISC.GET_GAME_TIMER()
			if StartedFromScript then
				StartedFromScript = false
				menu.set_value(StartRecordingPTR, true)
			end
			if Multiplayer_StartedFromScript then
				Multiplayer_StartedFromScript = false
				menu.set_value(MultiplayerRecordingPTR, true)
			end
			if Advanced_StartedFromScript then
				Advanced_StartedFromScript = false
				menu.set_value(Advanced_StartRecordingPTR, true)
			end
			local DeltaTime = MISC.GET_FRAME_TIME() * 1000.0  -- DeltaTime em milissegundos

            if not IsRewinding then
                -- Avançar normalmente
                GlobalReplayTime = GlobalReplayTime + (DeltaTime * ReplaySpeed)
            else
                -- Rebobinar
                GlobalReplayTime = GlobalReplayTime - (DeltaTime * ReplaySpeed)
                if GlobalReplayTime < 0 then
                    GlobalReplayTime = 0  -- não pode ir antes do início
                end
            end
			for k = 1, #ReplayVehsT do
				local Veh = ReplayVehsT[k].VehHandle
				if Veh ~= 0 and ENTITY.DOES_ENTITY_EXIST(Veh) then
					ENTITY.FREEZE_ENTITY_POSITION(ReplayVehsT[k].VehHandle, false)
					if ReplayVehsT[k].Index == 0 then
						ReplayVehsT[k].Index = FrameStartIndex
						local PathsData = ReplayVehsT[k].Paths[FrameStartIndex] or ReplayVehsT[k].Paths[1]
						ENTITY.SET_ENTITY_COORDS(Veh, PathsData.x, PathsData.y, PathsData.z)
						ENTITY.SET_ENTITY_ROTATION(Veh, PathsData.RotX, PathsData.RotY, PathsData.RotZ, 5)
						if not ReplayVehsT[k].HasSetStartTimer then
							ReplayVehsT[k].HasSetStartTimer = true
							ReplayVehsT[k].StartTimer = StartTimer
						else
							ReplayVehsT[k].StartTimer = GameTimer
						end
						if FrameStartIndex > 1 then
							if ReplayVehsT[k].Index > 0 and ReplayVehsT[k].Index < #ReplayVehsT[k].Paths then
								local Frame1, Frame2 = ReplayVehsT[k].Paths[ReplayVehsT[k].Index], ReplayVehsT[k].Paths[ReplayVehsT[k].Index + 1]
								ReplayVehsT[k].StartTimer = StartTimer - (Frame2.CurGameTime - ReplayVehsT[k].Paths[1].CurGameTime)
								--Print("ReplayVehsT[k].StartTimer "..ReplayVehsT[k].StartTimer.." StartTimer "..StartTimer)
							end
						end
					end
					if ReplayVehsT[k].Index > 0 and ReplayVehsT[k].Index < #ReplayVehsT[k].Paths then
						
						UpdateReplayIndexByTime(ReplayVehsT[k])
						
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
						if ReplayVehsT[k].IsCargoPlane then
							VEHICLE.SET_DOOR_ALLOWED_TO_BE_BROKEN_OFF(Veh, 2, false)
							VEHICLE.SET_VEHICLE_DOOR_CONTROL(Veh, 2, 180.0, 180.0)
							if not VEHICLE.IS_VEHICLE_DOOR_DAMAGED(Veh, 4) then
								VEHICLE.SET_VEHICLE_DOOR_BROKEN(Veh, 4, false)
							end
						end
						--VEHICLE.SET_VEHICLE_IS_RACING(Veh, true)
						local Steering = ReplayVehsT[k].Paths[ReplayVehsT[k].Index].Steering
						--VEHICLE.SET_VEHICLE_STEER_BIAS(Veh, Steering)
						if ReplayVehsT[k].PedHandle ~= 0 and ENTITY.DOES_ENTITY_EXIST(ReplayVehsT[k].PedHandle) then
							PED.SET_DRIVER_RACING_MODIFIER(ReplayVehsT[k].PedHandle, 1.0)
							if GameTimer > ReplayVehsT[k].SteerMilis+1000 then
								ReplayVehsT[k].SteerMilis = GameTimer
								local Offset = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(Veh, -Steering * 3.0, 0.0, 0.0)
								TASK.TASK_VEHICLE_DRIVE_TO_COORD(ReplayVehsT[k].PedHandle, Veh, Offset.x, Offset.y, Offset.z, 180.0, 1, ENTITY.GET_ENTITY_MODEL(Veh), 1, 0.01, 40000.0)
							else
								ReplayVehsT[k].SteerMilis = 0
							end
						end
						if not IsRewinding then
							if not ReplayTeleportMode then
								SetEntitySpeedToCoord(Veh, Coord, 1.0,
								false, false, false, Vel.x, Vel.y, Vel.z, false, false, nil)
								RotateEntityToTargetRotation(Veh, Rot, 10.0)
							else
								ENTITY.SET_ENTITY_COORDS_NO_OFFSET(Veh, Coord.x, Coord.y, Coord.z)
								ENTITY.SET_ENTITY_ROTATION(Veh, Rot.x, Rot.y, Rot.z, 5)
								ENTITY.SET_ENTITY_VELOCITY(Veh, Vel.x, Vel.y, Vel.z)
								ENTITY.SET_ENTITY_ANGULAR_VELOCITY(Veh, AngVel.x, AngVel.y, AngVel.z)
							end
						else
							ENTITY.SET_ENTITY_COORDS_NO_OFFSET(Veh, Coord.x, Coord.y, Coord.z)
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
			if WaitWasEnabled then
				local PVeh = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), true)
				if PVeh ~= 0 then
					if LastEnt == 0 then
						LastEnt = ENTITY._GET_LAST_ENTITY_HIT_BY_ENTITY(PVeh)
					end
					if LastEnt ~= 0 then
						local CurVel = ENTITY.GET_ENTITY_VELOCITY(LastEnt)
						ENTITY.SET_ENTITY_VELOCITY(PVeh, CurVel.x, CurVel.y, CurVel.z)
						WaitWasEnabled = false
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

local RecordAndReplays = false
local StartRecordingAndReplays = menu.toggle(SoloRecordingMenu, "Start Recording + Replays", {}, "", function(toggle)
	RecordAndReplays = toggle
	if RecordAndReplays then
		for k, value in pairs(ReplaysToLoad) do
			ReplayVehsT[#ReplayVehsT+1] = {
				VehHandle = 0,
				ModelHash = 0,
				Paths = GetVectorsTable(k, true, false),
				Index = 0,
				Blip = 0,
				StartTimer = 0,
				PedHandle = 0,
				PedBlip = 0,
				HasSetStartTimer = false,
				SteerMilis = 0,
				IsCargoPlane = false
			}
		end
		for k = 1, #ReplayVehsT do
			if ReplayVehsT[k].Paths ~= nil and ReplayVehsT[k].Paths[1] ~= nil then
				if not UseStoredVehicleModel then
					ReplayVehsT[k].Paths[1].ModelHash = joaat(Model)
				end
				ReplayVehsT[k].ModelHash = ReplayVehsT[k].Paths[1].ModelHash or joaat(Model)
				if ReplayVehsT[k].VehHandle == 0 then
					if not STREAMING.IS_MODEL_VALID(ReplayVehsT[k].ModelHash) then
						ReplayVehsT[k].ModelHash = joaat(Model)
					end
					ReplayVehsT[k].IsCargoPlane = ReplayVehsT[k].ModelHash == joaat("cargoplane") or ReplayVehsT[k].ModelHash == joaat("cargoplane2")
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
						UpgradeVehicle(ReplayVehsT[k].VehHandle, true, true, true)
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
									PED.SET_PED_CAN_BE_KNOCKED_OFF_VEHICLE(ReplayVehsT[k].PedHandle, 1)
								else
									STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(joaat(PedModel))
								end
							end
						end
						ENTITY.FREEZE_ENTITY_POSITION(ReplayVehsT[k].VehHandle, true)
						ENTITY.SET_ENTITY_COORDS(ReplayVehsT[k].VehHandle, ReplayVehsT[k].Paths[1].x, ReplayVehsT[k].Paths[1].y, ReplayVehsT[k].Paths[1].z)
						ENTITY.SET_ENTITY_ROTATION(ReplayVehsT[k].VehHandle, ReplayVehsT[k].Paths[1].RotX, ReplayVehsT[k].Paths[1].RotY, ReplayVehsT[k].Paths[1].RotZ, 5)
					else
						STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(ReplayVehsT[k].ModelHash)
					end
				end
			end
		end
		local LastEnt = 0
		local WaitWasEnabled = false
		while WaitBeforeStartReplay do
			WaitWasEnabled = true
			--if LastEnt == 0 then
				local PVeh = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), true)
				if PVeh ~= 0 then
					local NewLastEnt = ENTITY._GET_LAST_ENTITY_HIT_BY_ENTITY(PVeh)
					if NewLastEnt ~= 0 then
						LastEnt = NewLastEnt
					end
				end
			--end
			Wait()
		end
		GlobalReplayTime = 0
		
        if EmptyRecord then
            ClearFile(PathDirSaveds..FileNameForSave..".txt")
        end
        local StartedTime = MISC.GET_GAME_TIMER()
        local LastTime = 0
        local PausedTimeStart = 0
        local IsPaused = false
        local LastValidTime = 0

		local StartTimer = StartedTime
		while RecordAndReplays do
			local PlayerPed = PLAYER.PLAYER_PED_ID()
            local Veh = PED.GET_VEHICLE_PED_IS_IN(PlayerPed, true)
            local GameTimer = MISC.GET_GAME_TIMER()

            PAD.DISABLE_CONTROL_ACTION(0, 75)
			PAD.DISABLE_CONTROL_ACTION(0, 99)
            local ExitPressed = PAD.IS_DISABLED_CONTROL_PRESSED(0, 75) or PAD.IS_DISABLED_CONTROL_PRESSED(0, 99)

            if Veh ~= 0 then
                if ExitPressed then
                    if not IsPaused then
                        IsPaused = true
                        PausedTimeStart = GameTimer
                    end

                    -- Rebobinar: remover último frame
                    if #RecordT > 0 then
                        table.remove(RecordT, #RecordT)

                        -- Atualiza o LastValidTime
                        if #RecordT > 0 then
                            local LastFrame = GetVectorsFromIndex(RecordT[#RecordT])
                            LastValidTime = LastFrame.CurGameTime
                            ENTITY.SET_ENTITY_COORDS(Veh, LastFrame.x, LastFrame.y, LastFrame.z, false, false, true)
                            ENTITY.SET_ENTITY_ROTATION(Veh, LastFrame.RotX, LastFrame.RotY, LastFrame.RotZ, 5)
                            ENTITY.SET_ENTITY_VELOCITY(Veh, LastFrame.VelX, LastFrame.VelY, LastFrame.VelZ)
                            ENTITY.SET_ENTITY_ANGULAR_VELOCITY(Veh, LastFrame.AngVelX, LastFrame.AngVelY, LastFrame.AngVelZ)
							VEHICLE.SET_VEHICLE_FORWARD_SPEED(Veh, math.sqrt(LastFrame.VelX^2 + LastFrame.VelY^2 + LastFrame.VelZ^2))
                        else
                            LastValidTime = 0
                        end
                    end

                else
                    if IsPaused then
                        -- Terminou rebobinamento
                        local GameTimerNow = MISC.GET_GAME_TIMER()

                        -- ⚡ Aqui a correção real:
                        StartedTime = GameTimerNow - LastValidTime

                        IsPaused = false
                    end

                    -- Gravar normalmente
                    local Elapsed
					if IsRewinding then
						Elapsed = GlobalReplayTime
					else
						Elapsed = GlobalReplayTime
					end

                    LastTime = Elapsed
					--Global_StartedTime = StartedTime

                    local Pos = ENTITY.GET_ENTITY_COORDS(Veh)
                    local Rot = ENTITY.GET_ENTITY_ROTATION(Veh, 5)
                    local Vel = ENTITY.GET_ENTITY_VELOCITY(Veh)
                    local AngVel = ENTITY.GET_ENTITY_ROTATION_VELOCITY(Veh)
                    local VehModel = ENTITY.GET_ENTITY_MODEL(Veh)
                    local BoneID = ENTITY.GET_ENTITY_BONE_INDEX_BY_NAME(Veh, "steeringwheel")
                    local Steering = 0.0
                    if BoneID ~= 0 then
                        local SteeringRot = ENTITY.GET_ENTITY_BONE_OBJECT_ROTATION(Veh, BoneID)
                        SteeringRot:normalise()
                        Steering = -SteeringRot.y
                    end

                    RecordT[#RecordT+1] = ToTxt(Pos, Rot, Vel, AngVel, Elapsed, VehModel, Steering)
                end
            end
			IsRewinding = IsPaused
            -- Debug Visual
            --directx.draw_text(0.5, 0.55, "GameTimer "..GameTimer, ALIGN_CENTRE, 1.0, {r = 0.0, g = 1.0 , b = 1.0, a = 1.0}, false)
            --directx.draw_text(0.5, 0.6, "StartedTime "..StartedTime, ALIGN_CENTRE, 1.0, {r = 0.0, g = 1.0 , b = 1.0, a = 1.0}, false)
            --directx.draw_text(0.5, 0.65, "LastTime "..LastTime, ALIGN_CENTRE, 1.0, {r = 0.0, g = 1.0 , b = 1.0, a = 1.0}, false)
			--VEHICLE.SET_VEHICLE_DOOR_CONTROL(Veh, 2, 360, 360.0)
			if StartedFromScript then
				StartedFromScript = false
				menu.set_value(StartRecordingPTR, true)
			end
			if Multiplayer_StartedFromScript then
				Multiplayer_StartedFromScript = false
				menu.set_value(MultiplayerRecordingPTR, true)
			end
			if Advanced_StartedFromScript then
				Advanced_StartedFromScript = false
				menu.set_value(Advanced_StartRecordingPTR, true)
			end
			local DeltaTime = MISC.GET_FRAME_TIME() * 1000.0  -- DeltaTime em milissegundos

            if not IsRewinding then
                -- Avançar normalmente
                GlobalReplayTime = GlobalReplayTime + (DeltaTime * ReplaySpeed)
            else
                -- Rebobinar
                GlobalReplayTime = GlobalReplayTime - (DeltaTime * ReplaySpeed)
                if GlobalReplayTime < 0 then
                    GlobalReplayTime = 0  -- não pode ir antes do início
                end
            end
			for k = 1, #ReplayVehsT do
				local Veh = ReplayVehsT[k].VehHandle
				if Veh ~= 0 and ENTITY.DOES_ENTITY_EXIST(Veh) then
					ENTITY.FREEZE_ENTITY_POSITION(ReplayVehsT[k].VehHandle, false)
					if ReplayVehsT[k].Index == 0 then
						ReplayVehsT[k].Index = FrameStartIndex
						local PathsData = ReplayVehsT[k].Paths[FrameStartIndex] or ReplayVehsT[k].Paths[1]
						ENTITY.SET_ENTITY_COORDS(Veh, PathsData.x, PathsData.y, PathsData.z)
						ENTITY.SET_ENTITY_ROTATION(Veh, PathsData.RotX, PathsData.RotY, PathsData.RotZ, 5)
						if not ReplayVehsT[k].HasSetStartTimer then
							ReplayVehsT[k].HasSetStartTimer = true
							ReplayVehsT[k].StartTimer = StartTimer
						else
							ReplayVehsT[k].StartTimer = GameTimer
						end
						if FrameStartIndex > 1 then
							if ReplayVehsT[k].Index > 0 and ReplayVehsT[k].Index < #ReplayVehsT[k].Paths then
								local Frame1, Frame2 = ReplayVehsT[k].Paths[ReplayVehsT[k].Index], ReplayVehsT[k].Paths[ReplayVehsT[k].Index + 1]
								ReplayVehsT[k].StartTimer = StartTimer - (Frame2.CurGameTime - ReplayVehsT[k].Paths[1].CurGameTime)
								--Print("ReplayVehsT[k].StartTimer "..ReplayVehsT[k].StartTimer.." StartTimer "..StartTimer)
							end
						end
					end
					if ReplayVehsT[k].Index > 0 and ReplayVehsT[k].Index < #ReplayVehsT[k].Paths then
						
						UpdateReplayIndexByTime(ReplayVehsT[k])
						
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
						if ReplayVehsT[k].IsCargoPlane then
							VEHICLE.SET_DOOR_ALLOWED_TO_BE_BROKEN_OFF(Veh, 2, false)
							VEHICLE.SET_VEHICLE_DOOR_CONTROL(Veh, 2, 180.0, 180.0)
							if not VEHICLE.IS_VEHICLE_DOOR_DAMAGED(Veh, 4) then
								VEHICLE.SET_VEHICLE_DOOR_BROKEN(Veh, 4, false)
							end
						end
						--VEHICLE.SET_VEHICLE_IS_RACING(Veh, true)
						local Steering = ReplayVehsT[k].Paths[ReplayVehsT[k].Index].Steering
						--VEHICLE.SET_VEHICLE_STEER_BIAS(Veh, Steering)
						if ReplayVehsT[k].PedHandle ~= 0 and ENTITY.DOES_ENTITY_EXIST(ReplayVehsT[k].PedHandle) then
							PED.SET_DRIVER_RACING_MODIFIER(ReplayVehsT[k].PedHandle, 1.0)
							if GameTimer > ReplayVehsT[k].SteerMilis+1000 then
								ReplayVehsT[k].SteerMilis = GameTimer
								local Offset = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(Veh, -Steering * 3.0, 0.0, 0.0)
								TASK.TASK_VEHICLE_DRIVE_TO_COORD(ReplayVehsT[k].PedHandle, Veh, Offset.x, Offset.y, Offset.z, 180.0, 1, ENTITY.GET_ENTITY_MODEL(Veh), 1, 0.01, 40000.0)
							else
								ReplayVehsT[k].SteerMilis = 0
							end
						end
						if not IsRewinding then
							if not ReplayTeleportMode then
								SetEntitySpeedToCoord(Veh, Coord, 1.0,
								false, false, false, Vel.x, Vel.y, Vel.z, false, false, nil)
								RotateEntityToTargetRotation(Veh, Rot, 10.0)
							else
								ENTITY.SET_ENTITY_COORDS_NO_OFFSET(Veh, Coord.x, Coord.y, Coord.z)
								ENTITY.SET_ENTITY_ROTATION(Veh, Rot.x, Rot.y, Rot.z, 5)
								ENTITY.SET_ENTITY_VELOCITY(Veh, Vel.x, Vel.y, Vel.z)
								ENTITY.SET_ENTITY_ANGULAR_VELOCITY(Veh, AngVel.x, AngVel.y, AngVel.z)
							end
						else
							ENTITY.SET_ENTITY_COORDS_NO_OFFSET(Veh, Coord.x, Coord.y, Coord.z)
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
			if WaitWasEnabled then
				local PVeh = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), true)
				if PVeh ~= 0 then
					if LastEnt == 0 then
						LastEnt = ENTITY._GET_LAST_ENTITY_HIT_BY_ENTITY(PVeh)
					end
					if LastEnt ~= 0 then
						local CurVel = ENTITY.GET_ENTITY_VELOCITY(LastEnt)
						ENTITY.SET_ENTITY_VELOCITY(PVeh, CurVel.x, CurVel.y, CurVel.z)
						WaitWasEnabled = false
					end
				end
			end
			Wait()
        end

        -- Salvar no final
        local BigText = table.concat(RecordT)
        WriteFile(PathDirSaveds..FileNameForSave..".txt", BigText)
        RecordT = {}
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

function UpdateReplayIndexByTime(vehicleReplay)
    local Paths = vehicleReplay.Paths
    local StartFrameTime = Paths[1].CurGameTime

    -- Atualiza o índice com base no GlobalReplayTime
    while vehicleReplay.Index < (#Paths - 1) and 
          GlobalReplayTime > (Paths[vehicleReplay.Index + 1].CurGameTime - StartFrameTime) do
        vehicleReplay.Index = vehicleReplay.Index + 1
    end

    while vehicleReplay.Index > 1 and 
          GlobalReplayTime < (Paths[vehicleReplay.Index].CurGameTime - StartFrameTime) do
        vehicleReplay.Index = vehicleReplay.Index - 1
    end
end


menu.toggle(SoloRecordingMenu, "Wait Before Start Replay", {}, "", function(toggle)
	WaitBeforeStartReplay = toggle
end, WaitBeforeStartReplay)

menu.action(SoloRecordingMenu, "Load Replays And Start Recording", {}, "If you want to combine replays, this is useful.", function(toggle)
	StartedFromScript = true
	menu.set_value(StartSelectedReplaysPTR, true)
end)

menu.action(SoloRecordingMenu, "Stop Replay And Recording", {}, "", function(toggle)
	menu.set_value(StartRecordingPTR, false)
	menu.set_value(StartSelectedReplaysPTR, false)
end)

local AdvancedRecordingMenu = menu.list(SoloRecordingMenu, "Advanced Tools", {}, "")

local Advanced_FileNameForSave = "AdvancedStored"
menu.text_input(AdvancedRecordingMenu, "Set File Name", {"advancedsetfilename"}, "Set file name for saving.", function(OnChange)
	Advanced_FileNameForSave = OnChange
end, Advanced_FileNameForSave)

local RegisteredVehiclesT = {}
menu.action(AdvancedRecordingMenu, "Register Vehicle For Recording", {}, "Add the current vehicle to record separadately.", function(toggle)
	local Veh = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), true)
	if Veh ~= 0 then
		local Pos = ENTITY.GET_ENTITY_COORDS(Veh)
		local Rot = ENTITY.GET_ENTITY_ROTATION(Veh, 5)
		local Vel = ENTITY.GET_ENTITY_VELOCITY(Veh)
		local AngVel = ENTITY.GET_ENTITY_ROTATION_VELOCITY(Veh)
		RegisteredVehiclesT[Veh] = {Pos = Pos, Rot = Rot, Vel = Vel, AngVel = AngVel}
		while not RequestControlOfEntity(Veh) do
			Wait()
		end
		if not ENTITY.IS_ENTITY_A_MISSION_ENTITY(Veh) then
			ENTITY.SET_ENTITY_AS_MISSION_ENTITY(Veh, false, true)
		end
		entities.set_can_migrate(Veh, false)
		ENTITY.SET_ENTITY_INVINCIBLE(Veh, true)
		ENTITY.FREEZE_ENTITY_POSITION(Veh, true)
	end
end)

menu.action(AdvancedRecordingMenu, "Clear Registered Vehicles", {}, "", function(toggle)
	for k, Value in pairs(RegisteredVehiclesT) do
		if ENTITY.DOES_ENTITY_EXIST(k) then
			ENTITY.FREEZE_ENTITY_POSITION(k, false)
		end
	end
	RegisteredVehiclesT = {}
end)

local FixSwitchSpeedForPlanes = true
menu.toggle(AdvancedRecordingMenu, "Fix Switch Speed For Planes", {}, "", function(toggle)
	FixSwitchSpeedForPlanes = toggle
end, FixSwitchSpeedForPlanes)

local FixSwitchSpeedForHelis = true
menu.toggle(AdvancedRecordingMenu, "Fix Switch Speed For Helis", {}, "", function(toggle)
	FixSwitchSpeedForHelis = toggle
end, FixSwitchSpeedForHelis)

local FixSwitchSpeedForGroundVehs = true
menu.toggle(AdvancedRecordingMenu, "Fix Switch Speed For Ground Vehs", {}, "", function(toggle)
	FixSwitchSpeedForGroundVehs = toggle
end, FixSwitchSpeedForGroundVehs)

local FollowAimedVehicle = false
menu.toggle(AdvancedRecordingMenu, "Follow Aimed Vehicle", {}, "Press aim button to choose a vehicle to follow, press shoot button to confirm vehicle selection, press shoot button without aiming to reset.", function(toggle)
	FollowAimedVehicle = toggle
end, FollowAimedVehicle)

local FollowAimedVehicleLockOffset = false
menu.toggle(AdvancedRecordingMenu, "Follow Aimed Vehicle Lock Offset", {}, "", function(toggle)
	FollowAimedVehicleLockOffset = toggle
end, FollowAimedVehicleLockOffset)

local FollowOnlyWhenHandbrake = false
menu.toggle(AdvancedRecordingMenu, "Follow Only When Handbrake Pressed", {}, "", function(toggle)
	FollowOnlyWhenHandbrake = toggle
end, FollowOnlyWhenHandbrake)

local FollowAimedVehicleNoShootPressNeeded = false
menu.toggle(AdvancedRecordingMenu, "Follow Aimed Vehicle | No Shoot Press", {}, "No Shoot Press Needed", function(toggle)
	FollowAimedVehicleNoShootPressNeeded = toggle
end, FollowAimedVehicleNoShootPressNeeded)

local Advanced_EmptyRecord = false
local Advanced_EmptyRecordPTR = menu.toggle(AdvancedRecordingMenu, "First Clear Recording File", {}, "", function(toggle)
	Advanced_EmptyRecord = toggle
end, Advanced_EmptyRecord)


local Advanced_StartRecord = false
Advanced_StartRecordingPTR = menu.toggle(AdvancedRecordingMenu, "Start Recording", {}, "", function(toggle)
	Advanced_StartRecord = toggle
	if Advanced_StartRecord then
		local RegisteredVehsReplayT = {}
		local PlayerPed = PLAYER.PLAYER_PED_ID()
		local Veh = PED.GET_VEHICLE_PED_IS_IN(PlayerPed, true)
		local CurIndex = 1
		local MainVehicleIndex = 1
		local FoundVehicle = false
		local StartTime = MISC.GET_GAME_TIMER()
		for k, Value in pairs(RegisteredVehiclesT) do
			if ENTITY.DOES_ENTITY_EXIST(k) then
				local ModelHash = ENTITY.GET_ENTITY_MODEL(k)
				RegisteredVehsReplayT[#RegisteredVehsReplayT+1] = {
					Veh = k, RecordT = {}, MainVehicle = false, Ped = 0, PedBlip = 0,
					Pos = Value.Pos, Rot = Value.Rot, Vel = Value.Vel,
					AngVel = Value.AngVel, Bits = 0, FileName = Advanced_FileNameForSave.."_"..#RegisteredVehsReplayT+1,
					ReplayT = {}, Index = 0, RelSpeed = ENTITY.GET_ENTITY_SPEED_VECTOR(k, true), LastSpeed = ENTITY.GET_ENTITY_SPEED(k),
					IsNotAPlane = VEHICLE.IS_THIS_MODEL_A_BOAT(ModelHash) or VEHICLE.IS_THIS_MODEL_A_JETSKI(ModelHash) or VEHICLE.IS_THIS_MODEL_A_CAR(ModelHash) or
					VEHICLE.IS_THIS_MODEL_A_BIKE(ModelHash) or VEHICLE.IS_THIS_MODEL_A_BICYCLE(ModelHash) or VEHICLE.IS_THIS_MODEL_A_QUADBIKE(ModelHash) or
					VEHICLE.IS_THIS_MODEL_AN_AMPHIBIOUS_CAR(ModelHash) or VEHICLE.IS_THIS_MODEL_AN_AMPHIBIOUS_QUADBIKE(ModelHash),
					IsAHeli = VEHICLE.IS_THIS_MODEL_A_HELI(ModelHash), IsAPlane = VEHICLE.IS_THIS_MODEL_A_PLANE(ModelHash),
					SteerMilis = 0, CanFixSpeed = false, StayInVeh = 0, LastValidOffset = v3.new(), LastVel = v3.new()
				}
				if Advanced_EmptyRecord then
					ClearFile(PathDirSaveds..RegisteredVehsReplayT[#RegisteredVehsReplayT].FileName..".txt")
					--menu.set_value(EmptyRecordPTR, false)
				end
				if Veh == k then
					CurIndex = #RegisteredVehsReplayT
					RegisteredVehsReplayT[CurIndex].Bits = 1
					RegisteredVehsReplayT[CurIndex].StartTime = StartTime
					RegisteredVehsReplayT[CurIndex].LastMilis = StartTime
					RegisteredVehsReplayT[CurIndex].MainVehicle = true
					RegisteredVehsReplayT[CurIndex].CanFixSpeed = true
					MainVehicleIndex = CurIndex
					FoundVehicle = true
				end
			end
		end
		if not FoundVehicle then
			if RegisteredVehsReplayT[CurIndex] ~= nil then
				PED.SET_PED_INTO_VEHICLE(PlayerPed, RegisteredVehsReplayT[CurIndex].Veh, -1)
				RegisteredVehsReplayT[CurIndex].Bits = 1
				RegisteredVehsReplayT[CurIndex].StartTime = StartTime
				RegisteredVehsReplayT[CurIndex].LastMilis = StartTime
				RegisteredVehsReplayT[CurIndex].MainVehicle = true
				RegisteredVehsReplayT[CurIndex].CanFixSpeed = true
				MainVehicleIndex = CurIndex
			end
		end
		local GlobalStartTime = StartTime
		local TimeContinue = 0
		local LastRecordedTime = 0
		local LastTime = 0
		local CreatePeds = true
		local SwitchTriggered = false
		local SwitchTick = 0
		local MaxTick = 10
		local CorrectSpeedTick = 0
		local CorrectSpeedMaxTick = 50
		local LastSpeedVect = v3.new()
		while Advanced_StartRecord do
			PlayerPed = PLAYER.PLAYER_PED_ID()
			local CurVeh = RegisteredVehsReplayT[CurIndex]
			local GameTimer = MISC.GET_GAME_TIMER()
			local Timestep = SYSTEM.TIMESTEP()
			PAD.DISABLE_CONTROL_ACTION(0, 75, true)
			local SwitchPressed = PAD.IS_DISABLED_CONTROL_JUST_PRESSED(0, 75)
			local BoostPressed = PAD.IS_CONTROL_PRESSED(0, 71)
			local AimPressed = PAD.IS_CONTROL_PRESSED(0, 25)
			local ShootPressed = PAD.IS_CONTROL_JUST_PRESSED(0, 24)
			local HandBrakePressed = PAD.IS_CONTROL_PRESSED(0, 76)
			--if not PAD.IS_USING_KEYBOARD_AND_MOUSE(2) then
			--	AimPressed = true
			--	ShootPressed = PAD.IS_CONTROL_JUST_PRESSED(0, 69)
			--end
			if CurVeh ~= nil then
				Veh = CurVeh.Veh
				if ENTITY.DOES_ENTITY_EXIST(Veh) then
					if is_bit_set(CurVeh.Bits, 1) then
						CurVeh.Bits = clear_bit(CurVeh.Bits, 1)
						ENTITY.FREEZE_ENTITY_POSITION(Veh, false)
						local Pos = CurVeh.Pos
						local Rot = CurVeh.Rot
						local Vel = CurVeh.Vel
						local AngVel = CurVeh.AngVel
						local RelSpeed = CurVeh.RelSpeed
						ENTITY.SET_ENTITY_COORDS_NO_OFFSET(Veh, Pos.x, Pos.y, Pos.z, false, false, true)
						--VEHICLE.SET_VEHICLE_FORWARD_SPEED(Veh, 300.0)
						ENTITY.SET_ENTITY_ROTATION(Veh, Rot.x, Rot.y, Rot.z, 5)
						ENTITY.SET_ENTITY_VELOCITY(Veh, Vel.x, Vel.y, Vel.z)
						--ENTITY.SET_ENTITY_VELOCITY(Veh, 0.0, 0.0, 0.0)
						ENTITY.SET_ENTITY_ANGULAR_VELOCITY(Veh, AngVel.x, AngVel.y, AngVel.z)
						--VEHICLE.SET_VEHICLE_FORWARD_SPEED(Veh, RelSpeed.y)
						--VEHICLE.SET_VEHICLE_FORWARD_SPEED_XY(Veh, RelSpeed.x)
						--ENTITY.APPLY_FORCE_TO_ENTITY_CENTER_OF_MASS(Veh, 1, Vel.x, Vel.y, Vel.z, 0, false, true, true)
					end
					if BoostPressed and SwitchTick < MaxTick and SwitchTriggered and CurVeh.CanFixSpeed then
						--local RelSpeed = CurVeh.RelSpeed
						local CurSpeed = ENTITY.GET_ENTITY_SPEED(Veh)
						local CurSpeedVec = ENTITY.GET_ENTITY_SPEED_VECTOR(Veh, true)
						if CurSpeedVec.y <= LastSpeedVect.y or CurSpeedVec.y <= CurVeh.RelSpeed.y then
							local CanGiveSpeed = true
							if CurVeh.IsNotAPlane then
								if ENTITY.IS_ENTITY_IN_AIR(Veh) or not FixSwitchSpeedForGroundVehs then
									CanGiveSpeed = false
								end
							end
							if CurVeh.IsAHeli then
								if not FixSwitchSpeedForHelis then
									CanGiveSpeed = false
								end
							end
							if CurVeh.IsAPlane then
								if not FixSwitchSpeedForPlanes then
									CanGiveSpeed = false
								end
							end
							if CanGiveSpeed then
								VEHICLE.SET_VEHICLE_FORWARD_SPEED(Veh, CurSpeed + 1.0)
								SwitchTick = SwitchTick + 1
							end
						else
							CorrectSpeedTick = CorrectSpeedTick + 1
							if CorrectSpeedTick > CorrectSpeedMaxTick then
								CorrectSpeedTick = 0
								SwitchTriggered = false
								SwitchTick = 0
							end
						end
					else
						--SwitchTriggered = false
					end
					if SwitchTick < MaxTick then
						--SwitchTick = SwitchTick + 1
					end
					local Pos = ENTITY.GET_ENTITY_COORDS(Veh)
					local Vel = ENTITY.GET_ENTITY_VELOCITY(Veh)
					if FollowAimedVehicle then
						if AimPressed then
							local HitCoords, DidHit, EntHit = RaycastFromCamera(PlayerPed, 1000.0, -1)
							GRAPHICS.DRAW_LINE(Pos.x, Pos.y, Pos.z, HitCoords.x, HitCoords.y, HitCoords.z, 255, 255, 0, 255)
							if DidHit and EntHit ~= 0 and EntHit ~= Veh and ENTITY.IS_ENTITY_A_VEHICLE(EntHit) then
								if ShootPressed or FollowAimedVehicleNoShootPressNeeded then
									CurVeh.StayInVeh = EntHit
									local EntVel = ENTITY.GET_ENTITY_VELOCITY(CurVeh.StayInVeh)
									CurVeh.LastValidOffset = ENTITY.GET_OFFSET_FROM_ENTITY_GIVEN_WORLD_COORDS(CurVeh.StayInVeh,
									HitCoords.x, HitCoords.y, HitCoords.z )
								end
							end
						else
							if ShootPressed then
								CurVeh.StayInVeh = 0
							end
						end
						if CurVeh.StayInVeh ~= 0 and ENTITY.DOES_ENTITY_EXIST(CurVeh.StayInVeh) then
							local IsTouching = ENTITY.IS_ENTITY_TOUCHING_ENTITY(Veh, CurVeh.StayInVeh)
							local EntVel = ENTITY.GET_ENTITY_VELOCITY(CurVeh.StayInVeh)
							--EntVel:mul(0.0)
							local EntAngVel = ENTITY.GET_ENTITY_ROTATION_VELOCITY(CurVeh.StayInVeh)
							local PredictPos = nil
							if not IsTouching then
								PredictPos = PredictEntityOffsetCoords(CurVeh.StayInVeh, CurVeh.LastValidOffset, Timestep, EntAngVel)
								if is_bit_set(CurVeh.Bits, 4) then
									if not is_bit_set(CurVeh.Bits, 3) then
										CurVeh.Bits = set_bit(CurVeh.Bits, 3)
									end
								end
							else
								local EntOffset = ENTITY.GET_OFFSET_FROM_ENTITY_GIVEN_WORLD_COORDS(CurVeh.StayInVeh,
								Pos.x, Pos.y, Pos.z)
								PredictPos = PredictEntityOffsetCoords(CurVeh.StayInVeh, EntOffset, Timestep, EntAngVel)
								if not is_bit_set(CurVeh.Bits, 4) then
									CurVeh.Bits = set_bit(CurVeh.Bits, 4)
								end
								if is_bit_set(CurVeh.Bits, 3) then
									CurVeh.Bits = clear_bit(CurVeh.Bits, 3)
									--ENTITY.SET_ENTITY_VELOCITY(Veh, CurVeh.LastVel.x, CurVeh.LastVel.y, CurVeh.LastVel.z)
								else
									local CurVehVel = ENTITY.GET_ENTITY_VELOCITY(Veh)
									CurVeh.LastVel = CurVehVel
								end
							end
							if not FollowAimedVehicleLockOffset then
								if IsTouching then
									local HitCoords, DidHit, EntHit = RaycastCoordToCoord(Veh, PredictPos,
									{x = PredictPos.x, y = PredictPos.y, z = PredictPos.z - 1.0}, -1)
									if DidHit and EntHit ~= 0 and EntHit == CurVeh.StayInVeh then
										CurVeh.LastValidOffset = ENTITY.GET_OFFSET_FROM_ENTITY_GIVEN_WORLD_COORDS(CurVeh.StayInVeh,
										PredictPos.x, PredictPos.y, PredictPos.z)
									end
								end
							end
							GRAPHICS.DRAW_LINE(Pos.x, Pos.y, Pos.z, PredictPos.x, PredictPos.y, PredictPos.z, 255, 255, 0, 255)
							if not FollowOnlyWhenHandbrake then
								if not IsTouching or HandBrakePressed then
									local IgnoreZ, VelZ = false, 0.0
									if Pos.z >= PredictPos.z then
										IgnoreZ = true
										VelZ = Vel.z
									else
										VelZ = EntVel.z
									end
									SetEntitySpeedToCoord(Veh, PredictPos, 1.0, false, false, IgnoreZ, EntVel.x, EntVel.y, VelZ, false, false)
									local CurVehVel = ENTITY.GET_ENTITY_VELOCITY(Veh)
									CurVeh.LastVel = CurVehVel
								end
							else
								if HandBrakePressed then
									local IgnoreZ, VelZ = false, 0.0
									if Pos.z >= PredictPos.z then
										IgnoreZ = true
										VelZ = Vel.z
									else
										VelZ = EntVel.z
									end
									SetEntitySpeedToCoord(Veh, PredictPos, 1.0, false, false, IgnoreZ, EntVel.x, EntVel.y, VelZ, false, false)
									local CurVehVel = ENTITY.GET_ENTITY_VELOCITY(Veh)
									CurVeh.LastVel = CurVehVel
								end
							end
						end
					end
					TASK.CLEAR_VEHICLE_CRASH_TASK(Veh)
					VEHICLE.SET_DISABLE_AUTOMATIC_CRASH_TASK(Veh, false)
					VEHICLE.SET_DIP_STRAIGHT_DOWN_WHEN_CRASHING_PLANE(Veh, false)
					VEHICLE.SET_VEHICLE_ENGINE_ON(Veh, true, true, false)
					VEHICLE.SET_VEHICLE_KEEP_ENGINE_ON_WHEN_ABANDONED(Veh, true)
					--VEHICLE.SET_ROCKET_BOOST_ACTIVE(Veh, true)
					Pos = ENTITY.GET_ENTITY_COORDS(Veh)
					local Rot = ENTITY.GET_ENTITY_ROTATION(Veh, 5)
					Vel = ENTITY.GET_ENTITY_VELOCITY(Veh)
					local AngVel = ENTITY.GET_ENTITY_ROTATION_VELOCITY(Veh)
					local VehModel = ENTITY.GET_ENTITY_MODEL(Veh)
					local BoneID = ENTITY.GET_ENTITY_BONE_INDEX_BY_NAME(Veh, "steeringwheel")
					local Steering = 0.0
					if BoneID ~= 0 then
						local SteeringRot = ENTITY.GET_ENTITY_BONE_OBJECT_ROTATION(Veh, BoneID)
						SteeringRot:normalise()
						Steering = -SteeringRot.y
					end
					local AdjustedGameTimer = (GameTimer - StartTime) + TimeContinue
					RegisteredVehsReplayT[CurIndex].RecordT[#RegisteredVehsReplayT[CurIndex].RecordT+1] = ToTxt(Pos, Rot, Vel, AngVel, AdjustedGameTimer, VehModel, Steering)
					if #RegisteredVehsReplayT[CurIndex].RecordT >= 1000 then
						local BigText = table.concat(RegisteredVehsReplayT[CurIndex].RecordT)
						WriteFile(PathDirSaveds..RegisteredVehsReplayT[CurIndex].FileName..".txt", BigText)
						RegisteredVehsReplayT[CurIndex].RecordT = {}
					end
					CurVeh.ReplayT[#CurVeh.ReplayT+1] = {
						Pos = Pos,
						Rot = Rot,
						Vel = Vel,
						AngVel = AngVel,
						CurGameTime = GameTimer,
						Steering = Steering
					}
					if SwitchPressed and CurVeh.MainVehicle or GameTimer >= LastTime+LastRecordedTime and not CurVeh.MainVehicle then
						if not is_bit_set(CurVeh.Bits, 2) then
							CurVeh.Bits = set_bit(CurVeh.Bits, 2)
						end
					end
					directx.draw_text(0.5, 0.275, "AdjustedGameTimer "..AdjustedGameTimer, ALIGN_CENTRE, 1.0, {r = 0.0, g = 1.0 , b = 1.0, a = 1.0}, false)
					if is_bit_set(CurVeh.Bits, 2) then
						if #RegisteredVehsReplayT > 1 then
							CurVeh.CanFixSpeed = true
							CurVeh.RelSpeed = ENTITY.GET_ENTITY_SPEED_VECTOR(Veh, true)
							if CurVeh.MainVehicle then
								LastRecordedTime = GameTimer - StartTime
								LastSpeedVect = CurVeh.RelSpeed
							end
							LastTime = GameTimer
							CurVeh.Pos = Pos
							CurVeh.Rot = Rot
							CurVeh.Vel = Vel
							CurVeh.AngVel = AngVel
							CurVeh.LastSpeed = ENTITY.GET_ENTITY_SPEED(Veh)
							CurIndex = CurIndex + 1
							if CurIndex > #RegisteredVehsReplayT then
								CurIndex = 1
							end
							local NextVeh = RegisteredVehsReplayT[CurIndex]
							if not is_bit_set(NextVeh.Bits, 1) then
								NextVeh.Bits = set_bit(NextVeh.Bits, 1)
							end
							if NextVeh.MainVehicle then
								TimeContinue = TimeContinue + LastRecordedTime
							end
							CurVeh.Bits = clear_bit(CurVeh.Bits, 2)
							if NextVeh.Ped ~= 0 and ENTITY.DOES_ENTITY_EXIST(NextVeh.Ped) then
								local Coords1 = ENTITY.GET_ENTITY_COORDS(CurVeh.Veh)
								local Coords2 = ENTITY.GET_ENTITY_COORDS(NextVeh.Veh)
								ENTITY.SET_ENTITY_COORDS(PlayerPed, Coords2.x, Coords2.y, Coords2.z)
								ENTITY.SET_ENTITY_COORDS(NextVeh.Ped, Coords1.x, Coords1.y, Coords1.z)
								PED.SET_PED_INTO_VEHICLE(NextVeh.Ped, CurVeh.Veh, -1)
								--TASK.TASK_VEHICLE_DRIVE_TO_COORD(NextVeh.Ped, Veh, 0.0, 0.0, 500.0, 360.0, 1, ENTITY.GET_ENTITY_MODEL(Veh), 1, 0.1, 40000.0)
								local OldPed = CurVeh.Ped
								CurVeh.Ped = NextVeh.Ped
								NextVeh.Ped = OldPed
							end
							PED.SET_PED_INTO_VEHICLE(PlayerPed, NextVeh.Veh, -1)
							NextVeh.ReplayT = {}
							GlobalStartTime = GameTimer
							for k = 1, #RegisteredVehsReplayT do
								RegisteredVehsReplayT[k].Index = 0
							end
							StartTime = MISC.GET_GAME_TIMER()
							SwitchTriggered = true
							SwitchTick = 0
							CorrectSpeedTick = 0
						end
					end
				else
					local BigText = table.concat(RegisteredVehsReplayT[CurIndex].RecordT)
					WriteFile(PathDirSaveds..RegisteredVehsReplayT[CurIndex].FileName..".txt", BigText)
					RegisteredVehsReplayT[CurIndex].RecordT = {}
					table.remove(RegisteredVehsReplayT, CurIndex)
					CurIndex = CurIndex - 1
				end
			end
			for k = 1, #RegisteredVehsReplayT do
				if k ~= CurIndex then
					local Vehicle = RegisteredVehsReplayT[k].Veh
					if ENTITY.DOES_ENTITY_EXIST(Vehicle) then
						TASK.CLEAR_VEHICLE_CRASH_TASK(Vehicle)
						VEHICLE.SET_DISABLE_AUTOMATIC_CRASH_TASK(Vehicle, false)
						VEHICLE.SET_DIP_STRAIGHT_DOWN_WHEN_CRASHING_PLANE(Vehicle, false)
						VEHICLE.SET_VEHICLE_ENGINE_ON(Vehicle, true, true, false)
						VEHICLE.SET_VEHICLE_KEEP_ENGINE_ON_WHEN_ABANDONED(Vehicle, true)
						if CreatePeds then
							if not RegisteredVehsReplayT[k].MainVehicle then
								if RegisteredVehsReplayT[k].Ped == 0 then
									if RequestModelFunc(joaat(PedModel)) then
										RegisteredVehsReplayT[k].Ped = PED.CREATE_PED_INSIDE_VEHICLE(Vehicle, 28, joaat(PedModel), -1, true, true)
										if RegisteredVehsReplayT[k].Ped ~= 0 then
											STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(joaat(PedModel))
											ENTITY.SET_ENTITY_AS_MISSION_ENTITY(RegisteredVehsReplayT[k].Ped, false, true)
											entities.set_can_migrate(RegisteredVehsReplayT[k].Ped, false)
											ENTITY.SET_ENTITY_INVINCIBLE(RegisteredVehsReplayT[k].Ped, true)
											NETWORK.NETWORK_SET_ENTITY_CAN_BLEND(RegisteredVehsReplayT[k].Ped, true)
											RegisteredVehsReplayT[k].PedBlip = HUD.ADD_BLIP_FOR_ENTITY(RegisteredVehsReplayT[k].Ped)
											HUD.SET_BLIP_COLOUR(RegisteredVehsReplayT[k].PedBlip, 1)
											HUD.SHOW_HEADING_INDICATOR_ON_BLIP(RegisteredVehsReplayT[k].PedBlip, true)
											PED.SET_PED_COMBAT_ATTRIBUTES(RegisteredVehsReplayT[k].Ped, 3, false)
										else
											STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(joaat(PedModel))
										end
									end
								end
							end
						end
						if #RegisteredVehsReplayT[k].ReplayT > 0 then
							if RegisteredVehsReplayT[k].Index == 0 then
								RegisteredVehsReplayT[k].Index = 1
								local PathsData = RegisteredVehsReplayT[k].ReplayT[RegisteredVehsReplayT[k].LastReplaySize] or RegisteredVehsReplayT[k].ReplayT[1]
								ENTITY.SET_ENTITY_COORDS_NO_OFFSET(Vehicle, PathsData.Pos.x, PathsData.Pos.y, PathsData.Pos.z)
								ENTITY.SET_ENTITY_ROTATION(Vehicle, PathsData.Rot.x, PathsData.Rot.y, PathsData.Rot.z, 5)
							end
							if RegisteredVehsReplayT[k].Index > 0 and RegisteredVehsReplayT[k].Index < #RegisteredVehsReplayT[k].ReplayT then
								local CurrentTime = GameTimer - GlobalStartTime
								local Frame1, Frame2 = RegisteredVehsReplayT[k].ReplayT[RegisteredVehsReplayT[k].Index], RegisteredVehsReplayT[k].ReplayT[RegisteredVehsReplayT[k].Index + 1]
								if UseMilisAdjustLoop then
									local It = 0
									local Debug = false
									while CurrentTime > (Frame2.CurGameTime - RegisteredVehsReplayT[k].ReplayT[1].CurGameTime) do
										if Debug then
											It = It + 1
											if It > 10 then
												Print("It "..It.." Index "..RegisteredVehsReplayT[k].Index)
											end
										end
										RegisteredVehsReplayT[k].Index = RegisteredVehsReplayT[k].Index + 1
										if RegisteredVehsReplayT[k].Index >= #RegisteredVehsReplayT[k].ReplayT then
											RegisteredVehsReplayT[k].Index = #RegisteredVehsReplayT[k].ReplayT
											break
										else
											Frame1, Frame2 = RegisteredVehsReplayT[k].ReplayT[RegisteredVehsReplayT[k].Index], RegisteredVehsReplayT[k].ReplayT[RegisteredVehsReplayT[k].Index + 1]
										end
										CurrentTime = MISC.GET_GAME_TIMER() - GlobalStartTime
									end
								else
									if CurrentTime > (Frame2.CurGameTime - RegisteredVehsReplayT[k].ReplayT[1].CurGameTime) then
										RegisteredVehsReplayT[k].Index = RegisteredVehsReplayT[k].Index + 1
										if RegisteredVehsReplayT[k].Index >= #RegisteredVehsReplayT[k].ReplayT then
											RegisteredVehsReplayT[k].Index = #RegisteredVehsReplayT[k].ReplayT
										else
											Frame1, Frame2 = RegisteredVehsReplayT[k].ReplayT[RegisteredVehsReplayT[k].Index], RegisteredVehsReplayT[k].ReplayT[RegisteredVehsReplayT[k].Index + 1]
										end
									end
								end
								local Coord = {
									x = RegisteredVehsReplayT[k].ReplayT[RegisteredVehsReplayT[k].Index].Pos.x,
									y = RegisteredVehsReplayT[k].ReplayT[RegisteredVehsReplayT[k].Index].Pos.y,
									z = RegisteredVehsReplayT[k].ReplayT[RegisteredVehsReplayT[k].Index].Pos.z
								}
								local Rot = {
									x = RegisteredVehsReplayT[k].ReplayT[RegisteredVehsReplayT[k].Index].Rot.x,
									y = RegisteredVehsReplayT[k].ReplayT[RegisteredVehsReplayT[k].Index].Rot.y,
									z = RegisteredVehsReplayT[k].ReplayT[RegisteredVehsReplayT[k].Index].Rot.z
								}
								local Vel = {
									x = RegisteredVehsReplayT[k].ReplayT[RegisteredVehsReplayT[k].Index].Vel.x,
									y = RegisteredVehsReplayT[k].ReplayT[RegisteredVehsReplayT[k].Index].Vel.y,
									z = RegisteredVehsReplayT[k].ReplayT[RegisteredVehsReplayT[k].Index].Vel.z
								}
								local AngVel = {
									x = RegisteredVehsReplayT[k].ReplayT[RegisteredVehsReplayT[k].Index].AngVel.x,
									y = RegisteredVehsReplayT[k].ReplayT[RegisteredVehsReplayT[k].Index].AngVel.y,
									z = RegisteredVehsReplayT[k].ReplayT[RegisteredVehsReplayT[k].Index].AngVel.z
								}
								local Steering = RegisteredVehsReplayT[k].ReplayT[RegisteredVehsReplayT[k].Index].Steering
								--VEHICLE.SET_VEHICLE_STEER_BIAS(Veh, Steering)
								if RegisteredVehsReplayT[k].Ped ~= 0 and ENTITY.DOES_ENTITY_EXIST(RegisteredVehsReplayT[k].Ped) then
									PED.SET_DRIVER_RACING_MODIFIER(RegisteredVehsReplayT[k].Ped, 1.0)
									if GameTimer > RegisteredVehsReplayT[k].SteerMilis+1000 then
										RegisteredVehsReplayT[k].SteerMilis = GameTimer
										local Offset = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(Vehicle, -Steering * 3.0, 0.0, 0.0)
										TASK.TASK_VEHICLE_DRIVE_TO_COORD(RegisteredVehsReplayT[k].Ped, Vehicle, Offset.x, Offset.y, Offset.z, 180.0, 1, ENTITY.GET_ENTITY_MODEL(Vehicle), 1, 0.01, 40000.0)
									else
										RegisteredVehsReplayT[k].SteerMilis = 0
									end
								end
								SetEntitySpeedToCoord(Vehicle, Coord, 1.0,
								false, false, false, Vel.x, Vel.y, Vel.z, false, false, nil)
								RotateEntityToTargetRotation(Vehicle, Rot, 10.0)
							else
								ENTITY.FREEZE_ENTITY_POSITION(Vehicle, true)
							end
						else
							ENTITY.FREEZE_ENTITY_POSITION(Vehicle, true)
						end
					end
				end
			end
			Wait()
		end
		for k = 1, #RegisteredVehsReplayT do
			local BigText = table.concat(RegisteredVehsReplayT[k].RecordT)
			WriteFile(PathDirSaveds..RegisteredVehsReplayT[k].FileName..".txt", BigText)
			RegisteredVehsReplayT[k].RecordT = {}
			if ENTITY.DOES_ENTITY_EXIST(RegisteredVehsReplayT[k].Veh) then
				ENTITY.FREEZE_ENTITY_POSITION(RegisteredVehsReplayT[k].Veh, false)
			end
			if RegisteredVehsReplayT[k].Ped ~= 0 and ENTITY.DOES_ENTITY_EXIST(RegisteredVehsReplayT[k].Ped) then
				util.remove_blip(RegisteredVehsReplayT[k].PedBlip)
				entities.delete_by_handle(RegisteredVehsReplayT[k].Ped)
			end
		end
	end
end)

menu.toggle(AdvancedRecordingMenu, "Wait Before Start Replay", {}, "", function(toggle)
	WaitBeforeStartReplay = toggle
end, WaitBeforeStartReplay)

menu.action(AdvancedRecordingMenu, "Load Replays And Start Recording", {}, "If you want to combine replays, this is useful.", function(toggle)
	Advanced_StartedFromScript = true
	menu.set_value(StartSelectedReplaysPTR, true)
end)

menu.action(AdvancedRecordingMenu, "Stop Replay And Recording", {}, "", function(toggle)
	menu.set_value(Advanced_StartRecordingPTR, false)
	menu.set_value(StartSelectedReplaysPTR, false)
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

function GetVectorsTable(FileName, DelayLoad, GetOnlyFirstData)
	local MaxIt = 10000
	local VectorTable = {}
	local Vectors = file_lines(FileName)
	local It = 0
	for i = 1, #Vectors do
		local Number = split_number(Vectors[i])
		VectorTable[#VectorTable+1] = {
			x = Number[1], y = Number[2], z = Number[3],
			RotX = Number[4], RotY = Number[5], RotZ = Number[6],
			VelX = Number[7], VelY = Number[8], VelZ = Number[9],
			AngVelX = Number[10], AngVelY = Number[11], AngVelZ = Number[12],
			CurGameTime = Number[13], ModelHash = Number[14]
		}
		if DelayLoad then
			It = It + 1
			if It > MaxIt then
				It = 0
				Wait()
			end
		end
		if GetOnlyFirstData then
			break
		end
	end
	return VectorTable
end

function ToTxt(Pos, Rot, Vel, AngVel, CurGameTimer, VehModel, Steering)
    return string.format("%0.3f", Pos.x).." "..string.format("%0.3f", Pos.y).." "..string.format("%0.3f", Pos.z)..
    " "..string.format("%0.3f", Rot.x).." "..string.format("%0.3f", Rot.y).." "..string.format("%0.3f", Rot.z)..
    " "..string.format("%0.3f", Vel.x).." "..string.format("%0.3f", Vel.y).." "..string.format("%0.3f", Vel.z)..
    " "..string.format("%0.3f", AngVel.x).." "..string.format("%0.3f", AngVel.y).." "..string.format("%0.3f", AngVel.z)..
    " "..CurGameTimer.." "..VehModel.." "..Steering.."\n"
end

function TimerCount(TimerT)
	local TimeMillis = util.current_time_millis()
	if TimeMillis > TimerT.Timer+10 then
		TimerT.TimerCount = TimerT.TimerCount + 1
		TimerT.Timer = TimeMillis
	end
end

function RequestModel(ModelHash)
	if not STREAMING.HAS_MODEL_LOADED(ModelHash) then
		STREAMING.REQUEST_MODEL(ModelHash)
		while not STREAMING.HAS_MODEL_LOADED(ModelHash) do
			Wait()
		end
	end
end

function RequestModelFunc(ModelHash)
	STREAMING.REQUEST_MODEL(ModelHash)
	return STREAMING.HAS_MODEL_LOADED(ModelHash)
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


--local FolderSelectMenu = menu.list(MultiplayerRecording, "Load Multiplayer Replay", {"loadmultiplayerreplaymenu"}, "", function() CreateMenuItemsFolder() end
--, function ()
--	CreateMenuItemsFolder()
--end)

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
MultiplayerRecordingPTR = menu.toggle(MultiplayerRecording, "Start Multiplayer Recording", {}, "", function(toggle)
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
						local BoneID = ENTITY.GET_ENTITY_BONE_INDEX_BY_NAME(Veh, "steeringwheel")
						local Steering = 0.0
						if BoneID ~= 0 then
							local SteeringRot = ENTITY.GET_ENTITY_BONE_OBJECT_ROTATION(Veh, BoneID)
							SteeringRot:normalise()
							Steering = -SteeringRot.y
						end
						PlayersT[k].Records[#PlayersT[k].Records+1] = ToTxt(Pos, Rot, Vel, AngVel, GameTimer, VehModel, Steering)
						if #PlayersT[k].Records >= 1000 then
							local BigText = table.concat(PlayersT[k].Records)
							WriteFile(Dir..k..".txt", BigText)
							PlayersT[k].Records = {}
						end
					end
				end
			end
			Wait()
		end
		for k = 1, #PlayersT do
			local BigText = table.concat(PlayersT[k].Records)
			WriteFile(Dir..k..".txt", BigText)
			PlayersT[k].Records = {}
		end
	end
end)

menu.action(MultiplayerRecording, "Load Replays And Start Recording", {}, "If you want to combine replays, this is useful.", function(toggle)
	Multiplayer_StartedFromScript = true
	menu.set_value(StartSelectedReplaysPTR, true)
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

function UpgradeVehicle(Vehicle, RandomUpgrade, SetRandomColors, SetRandomCustomColors)
    VEHICLE.SET_VEHICLE_MOD_KIT(Vehicle, 0)
    if RandomUpgrade then
        for k = 0, 48 do
            local Max = VEHICLE.GET_NUM_VEHICLE_MODS(Vehicle, k)
            VEHICLE.SET_VEHICLE_MOD(Vehicle, k, math.random(0, math.max(0, Max-1)), false)
        end
    else
        for k = 0, 48 do
            local Max = VEHICLE.GET_NUM_VEHICLE_MODS(Vehicle, k)
            VEHICLE.SET_VEHICLE_MOD(Vehicle, k, Max-1, false)
        end
    end
    if SetRandomColors then
        VEHICLE.SET_VEHICLE_COLOURS(Vehicle, math.random(0, 222), math.random(0, 222))
    end
    if SetRandomCustomColors then
        VEHICLE.SET_VEHICLE_CUSTOM_PRIMARY_COLOUR(Vehicle, math.random(0, 255), math.random(0, 255), math.random(0, 255))
        VEHICLE.SET_VEHICLE_CUSTOM_SECONDARY_COLOUR(Vehicle, math.random(0, 255), math.random(0, 255), math.random(0, 255))
    end
end

--local ScriptedToolsMenu = menu.list(menu.my_root(), "Scripted Tools", {}, "")

local GameModesMenu = menu.list(menu.my_root(), "Game Modes", {}, "")

local CargobobChaseWars = false
menu.toggle(GameModesMenu, "Cargobob VS Speedo Chase", {}, "", function(toggle)
	CargobobChaseWars = toggle
	if CargobobChaseWars then
		local Paths1 = GetVectorsTable(PathDirSaveds.."ChaseBob1.txt", true, false)
		local Paths2 = GetVectorsTable(PathDirSaveds.."ChaseBob2.txt", true, false)
		local Paths = {Paths1, Paths2}
		local Vehs = {}
		local Objs = {}
		local VehsLocal = SplitGlobals("Local_22995.f_834.f_81")
		local ObjsLocal = SplitGlobals("Local_22995.f_834.f_147")
		local Spd = {13, 10}
		local StartTimer = 0
		local Started = false
		local SwitchIDsMilis = 0
		local PlayerID = PLAYER.PLAYER_ID()
		while CargobobChaseWars do
			if SCRIPT.GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH(joaat("fm_mission_controller")) > 0 then
				if PLAYER.IS_PLAYER_CONTROL_ON(PLAYER.PLAYER_ID()) then
					if not Started then
						StartTimer = MISC.GET_GAME_TIMER()
					end
				 	Started = true
				end
				if Started then
					local TimeStep = SYSTEM.TIMESTEP()
					local GameTimer = MISC.GET_GAME_TIMER()
					for k = 1, 4 do
						if k <= 2 then
							if Vehs[k] == nil then
								local NetID = memory.read_int(memory.script_local("fm_mission_controller", VehsLocal+k))
								if NetID ~= 0 then
									local Handle = 0
									util.spoof_script("fm_mission_controller", function()
										Handle = NETWORK.NET_TO_VEH(NetID)
									end)
									if Handle ~= 0 then
										Vehs[k] = {Handle = Handle, NetID = NetID, PathsTable = Paths[k], Index = 1}
									end
								end
							end
						end
						if k >= 3 then
							if Vehs[k] == nil then
								local NetID = memory.read_int(memory.script_local("fm_mission_controller", VehsLocal+k))
								if NetID ~= 0 then
									local Handle = 0
									util.spoof_script("fm_mission_controller", function()
										Handle = NETWORK.NET_TO_VEH(NetID)
									end)
									if Handle ~= 0 then
										Vehs[k] = {Handle = Handle, NetID = NetID}
									end
								end
							end
						end
					end
					for k = 1, 4 do
						if Vehs[k] ~= nil then
							if ENTITY.DOES_ENTITY_EXIST(Vehs[k].Handle) then
								if RequestControlOfEntity(Vehs[k].Handle) then
									NETWORK.NETWORK_SET_ENTITY_CAN_BLEND(Vehs[k].Handle, true)
									entities.set_can_migrate(Vehs[k].Handle, false)
									ENTITY.SET_ENTITY_HAS_GRAVITY(Vehs[k].Handle, false)
									if k >= 3 then
										ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(Vehs[k].Handle, Vehs[2].Handle, false)
										if not DECORATOR.DECOR_EXIST_ON(Vehs[k].Handle, "RespawnVeh") then
											local bVar0 = math.random(0, 65535)
											DECORATOR.DECOR_SET_INT(Vehs[k].Handle, "RespawnVeh", bVar0);
										end
										local Speed = ENTITY.GET_ENTITY_VELOCITY(Vehs[2].Handle)
										local Pos = nil
										if k == 3 then
											Pos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(Vehs[2].Handle, -5.25, 1.5, 0.0)
										end
										if k == 4 then
											Pos = ENTITY.GET_OFFSET_FROM_ENTITY_IN_WORLD_COORDS(Vehs[2].Handle, 5.25, 1.5, 0.0)
										end
										local FinalPos = {
											x = Pos.x + Speed.x * 1.0,
											y = Pos.y + Speed.y * 1.0,
											z = Pos.z + Speed.z * 1.0,
										}
										Speed:mul(0.0)
										SetEntitySpeedToCoord(Vehs[k].Handle, FinalPos, 1.0, false, false, false, Speed.x, Speed.y, Speed.z, false, false, nil)
										--local Rot = ENTITY.GET_ENTITY_ROTATION(Vehs[2].Handle, 5)
										local CamRot = players.get_cam_rot(PlayerID)
										local NewRot = convertRotationXYZtoZYX(CamRot.x, CamRot.y, CamRot.z)
										RotateEntityToTargetRotation(Vehs[k].Handle, NewRot, 10.0)
									end
									--ENTITY.SET_ENTITY_INVINCIBLE(Vehs[k].Handle, true)
								end
								if k <= 2 then
									--ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(Vehs[1].Handle, Vehs[2].Handle, false)
									--ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(Vehs[2].Handle, Vehs[1].Handle, false)
									if k == 2 then
										VEHICLE.SET_VEHICLE_DOOR_CONTROL(Vehs[k].Handle, 2, 180, 180.0)
										VEHICLE.SET_DOOR_ALLOWED_TO_BE_BROKEN_OFF(Vehs[k].Handle, 2, false)
										VEHICLE.SET_HELI_TAIL_ROTOR_HEALTH(Vehs[k].Handle, 100000.0)
										VEHICLE.SET_HELI_MAIN_ROTOR_HEALTH(Vehs[k].Handle, 100000.0)
										VEHICLE.SET_HELI_TAIL_BOOM_CAN_BREAK_OFF(Vehs[k].Handle, false)
									end
									if Vehs[k].Index > 0 and Vehs[k].Index < #Vehs[k].PathsTable then
										local CurrentTime = GameTimer - StartTimer
										local Frame1, Frame2 = Vehs[k].PathsTable[Vehs[k].Index], Vehs[k].PathsTable[Vehs[k].Index + 1]
										if UseMilisAdjustLoop then
											while CurrentTime > (Frame2.CurGameTime - Vehs[k].PathsTable[1].CurGameTime) do
												Vehs[k].Index = Vehs[k].Index + 1
												if Vehs[k].Index >= #Vehs[k].PathsTable then
													Vehs[k].Index = #Vehs[k].PathsTable
													break
												else
													Frame1, Frame2 = Vehs[k].PathsTable[Vehs[k].Index], Vehs[k].PathsTable[Vehs[k].Index + 1]
												end
												CurrentTime = MISC.GET_GAME_TIMER() - StartTimer
											end
										else
											if CurrentTime > (Frame2.CurGameTime - Vehs[k].PathsTable[1].CurGameTime) then
												Vehs[k].Index = Vehs[k].Index + 1
												if Vehs[k].Index >= #Vehs[k].PathsTable then
													Vehs[k].Index = #Vehs[k].PathsTable
												else
													Frame1, Frame2 = Vehs[k].PathsTable[Vehs[k].Index], Vehs[k].PathsTable[Vehs[k].Index + 1]
												end
											end
										end
										local Veh = Vehs[k].Handle
										--directx.draw_text(0.5, 0.5, "CurrentTime "..CurrentTime, ALIGN_CENTRE, 1.0, {r = 0.0, g = 1.0 , b = 1.0, a = 1.0}, false)
										--directx.draw_text(0.5, 0.6, "Frame2.CurGameTime - ReplayVehsT[k].Paths[1].CurGameTime "..Frame2.CurGameTime - ReplayVehsT[k].Paths[1].CurGameTime, ALIGN_CENTRE, 1.0, {r = 0.0, g = 1.0 , b = 1.0, a = 1.0}, false)
										local Coord = {
											x = Vehs[k].PathsTable[Vehs[k].Index].x,
											y = Vehs[k].PathsTable[Vehs[k].Index].y,
											z = Vehs[k].PathsTable[Vehs[k].Index].z
										}
										local Rot = {
											x = Vehs[k].PathsTable[Vehs[k].Index].RotX,
											y = Vehs[k].PathsTable[Vehs[k].Index].RotY,
											z = Vehs[k].PathsTable[Vehs[k].Index].RotZ
										}
										local Vel = {
											x = Vehs[k].PathsTable[Vehs[k].Index].VelX,
											y = Vehs[k].PathsTable[Vehs[k].Index].VelY,
											z = Vehs[k].PathsTable[Vehs[k].Index].VelZ
										}
										local AngVel = {
											x = Vehs[k].PathsTable[Vehs[k].Index].AngVelX,
											y = Vehs[k].PathsTable[Vehs[k].Index].AngVelY,
											z = Vehs[k].PathsTable[Vehs[k].Index].AngVelZ
										}
										--if not ReplayTeleportMode then
											SetEntitySpeedToCoord(Veh, Coord, 1.0,
											false, false, false, Vel.x, Vel.y, Vel.z, false, false, nil)
											RotateEntityToTargetRotation(Veh, Rot, 10.0)
										--end
									end
								end
							end
						end
					end
					if Vehs[2] ~= nil then
						for k = 1, 1 do
							if Objs[k] == nil then
								local NetID = memory.read_int(memory.script_local("fm_mission_controller", ObjsLocal+k))
								if NetID ~= 0 then
									local Handle = 0
									util.spoof_script("fm_mission_controller", function()
										Handle = NETWORK.NET_TO_OBJ(NetID)
									end)
									if Handle ~= 0 then
										Objs[k] = {Handle = Handle, Offset = nil}
									end
								end
							end
							if Objs[k] ~= nil then
								if ENTITY.DOES_ENTITY_EXIST(Objs[k].Handle) then
									if RequestControlOfEntity(Objs[k].Handle) then
										entities.set_can_migrate(Objs[k].Handle, false)
										--ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION(Objs[k].Handle, false, true)
									end
									if Vehs[3] ~= nil then
										if not ENTITY.IS_ENTITY_ATTACHED(Vehs[3].Handle) then
											--ENTITY.ATTACH_ENTITY_TO_ENTITY(Vehs[3].Handle, Objs[k].Handle, 0, -3.25, 1.5, 0.0, 0.0, 0.0, 0.0, true, false, false, false, 2, true, false)
											--ENTITY.ATTACH_ENTITY_TO_ENTITY_PHYSICALLY(Vehs[3].Handle, Objs[k].Handle, 0, 0, -3.25, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, -1.0, true, true, false, true, 2)
											--ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION(Vehs[3].Handle, false, true)
										end
									end
									if Vehs[4] ~= nil then
										if not ENTITY.IS_ENTITY_ATTACHED(Vehs[4].Handle) then
											--ENTITY.ATTACH_ENTITY_TO_ENTITY(Vehs[4].Handle, Objs[k].Handle, 0, 3.25, 1.5, 0.0, 0.0, 0.0, 0.0, true, false, false, false, 2, true, false)
											--ENTITY.ATTACH_ENTITY_TO_ENTITY_PHYSICALLY(Vehs[4].Handle, Objs[k].Handle, 0, 0, 3.25, 1.5, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, -1.0, true, true, false, true, 2)
											--ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION(Vehs[4].Handle, false, true)
										end
									end
									if Objs[k].Offset == nil then
										Objs[k].Offset = {x = 0.0, y = 0.0, z = 0.0}
									end
									ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION(Objs[k].Handle, false, true)
									ENTITY.SET_ENTITY_HAS_GRAVITY(Objs[k].Handle, false)
									local Speed = ENTITY.GET_ENTITY_VELOCITY(Vehs[2].Handle)
									local Pos = ENTITY.GET_ENTITY_COORDS(Vehs[2].Handle)
									local FinalPos = {
										x = Pos.x + Speed.x * 1.0,
										y = Pos.y + Speed.y * 1.0,
										z = Pos.z + Speed.z * 1.0,
									}
									Speed:mul(0.0)
									SetEntitySpeedToCoord(Objs[k].Handle, FinalPos, 1.0, false, false, false, Speed.x, Speed.y, Speed.z, false, false, nil)
									local Rot = ENTITY.GET_ENTITY_ROTATION(Vehs[2].Handle, 5)
									RotateEntityToTargetRotation(Objs[k].Handle, Rot, 10.0)
								end
							end
						end
					end
					if Vehs[3] ~= nil and Vehs[4] ~= nil then
						if GameTimer > SwitchIDsMilis+5000 then
							local IsHostOfScript = false
							util.spoof_script("fm_mission_controller", function()
								IsHostOfScript = NETWORK.NETWORK_IS_HOST_OF_THIS_SCRIPT()
							end)
							if IsHostOfScript then
								SwitchIDsMilis = GameTimer
								local NetID1 = Vehs[3].NetID
								local NetID2 = Vehs[4].NetID
								local Addr1 = memory.script_local("fm_mission_controller", VehsLocal+3)
								local Addr2 = memory.script_local("fm_mission_controller", VehsLocal+4)
								memory.write_int(Addr1, NetID2)
								memory.write_int(Addr2, NetID1)
								Vehs[3].NetID = NetID2
								Vehs[4].NetID = NetID1
							end
						end
					end
				end
			else
				Started = false
				for k = 1, 4 do
					Vehs[k] = nil
				end
				for k = 1, 12 do
					Objs[k] = nil
				end
			end
			Wait()
		end
	end
end)

local ComboyWars = false
menu.toggle(GameModesMenu, "Comboy Wars", {}, "", function(toggle)
	ComboyWars = toggle
	if ComboyWars then
		local Paths1 = GetVectorsTable(PathDirSaveds.."ChaseBob1.txt", true, false)
		local Paths2 = GetVectorsTable(PathDirSaveds.."ChaseBob2.txt", true, false)
		local Paths = {Paths1, Paths2}
		local Vehs = {}
		local Objs = {}
		local VehsLocal = SplitGlobals("Local_22995.f_834.f_81")
		local ObjsLocal = SplitGlobals("Local_22995.f_834.f_147")
		local Spd = {13, 10}
		local StartTimer = 0
		local Started = false
		local SwitchIDsMilisTeam1 = 0
		local SwitchIDsMilisTeam2 = 0
		local CurSwitchIndexTeam1 = 2
		local CurSwitchIndexTeam2 = 7
		while ComboyWars do
			if SCRIPT.GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH(joaat("fm_mission_controller")) > 0 then
				if PLAYER.IS_PLAYER_CONTROL_ON(PLAYER.PLAYER_ID()) then
					if not Started then
						StartTimer = MISC.GET_GAME_TIMER()
					end
				 	Started = true
				end
				if Started then
					local GameTimer = MISC.GET_GAME_TIMER()
					for k = 1, 10 do
						if Vehs[k] == nil then
							local Address = memory.script_local("fm_mission_controller", VehsLocal+k)
							local NetID = memory.read_int(Address)
							if NetID ~= 0 then
								local Handle = 0
								util.spoof_script("fm_mission_controller", function()
									Handle = NETWORK.NET_TO_VEH(NetID)
								end)
								if Handle ~= 0 then
									local PathsToSet = Paths[2]
									local Delay = 1000 * (k-1)
									if k >= 6 then
										PathsToSet = Paths[1]
										Delay = 1000 * (k-6)
									end
									Vehs[k] = {Handle = Handle, NetID = NetID, PathsTable = PathsToSet, Index = 1, StartMilis = GameTimer, Delay = Delay, HasPassedDelay = false,
									InvincibleMilis = 0, Address = Address, IsDead = false}
								end
							end
						end
					end
					for k = 1, 10 do
						if Vehs[k] ~= nil then
							if ENTITY.DOES_ENTITY_EXIST(Vehs[k].Handle) and not ENTITY.IS_ENTITY_DEAD(Vehs[k].Handle) then
								if RequestControlOfEntity(Vehs[k].Handle) then
									NETWORK.NETWORK_SET_ENTITY_CAN_BLEND(Vehs[k].Handle, true)
									entities.set_can_migrate(Vehs[k].Handle, false)
									if not Vehs[k].HasPassedDelay then
										ENTITY.SET_ENTITY_INVINCIBLE(Vehs[k].Handle, true)
										ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION(Vehs[k].Handle, false, false)
									end
									if not DECORATOR.DECOR_EXIST_ON(Vehs[k].Handle, "RespawnVeh") then
										local bVar0 = math.random(0, 65535)
										DECORATOR.DECOR_SET_INT(Vehs[k].Handle, "RespawnVeh", bVar0);
									end
									if k > 1 and k <= 5 then
										if Vehs[k-1] ~= nil and not Vehs[k-1].IsDead then
											ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(Vehs[k].Handle, Vehs[k-1].Handle, false)
										end
									end
								end
								if Vehs[k].Index > 0 and Vehs[k].Index < #Vehs[k].PathsTable and GameTimer >= Vehs[k].StartMilis+Vehs[k].Delay then
									if not Vehs[k].HasPassedDelay then
										Vehs[k].HasPassedDelay = true
										Vehs[k].Delay = 0
										Vehs[k].StartMilis = GameTimer
										Vehs[k].InvincibleMilis = GameTimer
									end
									if GameTimer > Vehs[k].InvincibleMilis+5000 then
										ENTITY.SET_ENTITY_INVINCIBLE(Vehs[k].Handle, false)
										ENTITY.SET_ENTITY_COLLISION(Vehs[k].Handle, true, false)
									end
									local CurrentTime = (GameTimer - Vehs[k].StartMilis)
									local Frame1, Frame2 = Vehs[k].PathsTable[Vehs[k].Index], Vehs[k].PathsTable[Vehs[k].Index + 1]
									if UseMilisAdjustLoop then
										while CurrentTime > (Frame2.CurGameTime - Vehs[k].PathsTable[1].CurGameTime) do
											Vehs[k].Index = Vehs[k].Index + 1
											if Vehs[k].Index >= #Vehs[k].PathsTable then
												Vehs[k].Index = #Vehs[k].PathsTable
												break
											else
												Frame1, Frame2 = Vehs[k].PathsTable[Vehs[k].Index], Vehs[k].PathsTable[Vehs[k].Index + 1]
											end
											CurrentTime = (MISC.GET_GAME_TIMER() - Vehs[k].StartMilis)
										end
									else
										if CurrentTime > (Frame2.CurGameTime - Vehs[k].PathsTable[1].CurGameTime) then
											Vehs[k].Index = Vehs[k].Index + 1
											if Vehs[k].Index >= #Vehs[k].PathsTable then
												Vehs[k].Index = #Vehs[k].PathsTable
											else
												Frame1, Frame2 = Vehs[k].PathsTable[Vehs[k].Index], Vehs[k].PathsTable[Vehs[k].Index + 1]
											end
										end
									end
									local Veh = Vehs[k].Handle
									local Coord = {
										x = Vehs[k].PathsTable[Vehs[k].Index].x,
										y = Vehs[k].PathsTable[Vehs[k].Index].y,
										z = Vehs[k].PathsTable[Vehs[k].Index].z
									}
									local Rot = {
										x = Vehs[k].PathsTable[Vehs[k].Index].RotX,
										y = Vehs[k].PathsTable[Vehs[k].Index].RotY,
										z = Vehs[k].PathsTable[Vehs[k].Index].RotZ
									}
									local Vel = {
										x = Vehs[k].PathsTable[Vehs[k].Index].VelX,
										y = Vehs[k].PathsTable[Vehs[k].Index].VelY,
										z = Vehs[k].PathsTable[Vehs[k].Index].VelZ
									}
									local AngVel = {
										x = Vehs[k].PathsTable[Vehs[k].Index].AngVelX,
										y = Vehs[k].PathsTable[Vehs[k].Index].AngVelY,
										z = Vehs[k].PathsTable[Vehs[k].Index].AngVelZ
									}
									--if not ReplayTeleportMode then
										SetEntitySpeedToCoord(Veh, Coord, 1.0,
										false, false, false, Vel.x, Vel.y, Vel.z, false, false, nil)
										RotateEntityToTargetRotation(Veh, Rot, 10.0)
									--end
								end
							else
								Vehs[k].IsDead = true
							end
						end
					end
					if GameTimer >= SwitchIDsMilisTeam1+5000 then
						if CurSwitchIndexTeam1 <= 5 then
							local Veh1 = Vehs[1]
							local Veh2 = Vehs[CurSwitchIndexTeam1]
							if Veh2 ~= nil and Veh1 ~= nil and not Veh2.IsDead then
								SwitchIDsMilisTeam1 = GameTimer
								local NetID1 = Veh1.NetID
								local NetID2 = Veh2.NetID
								local Addr1 = Veh1.Address
								local Addr2 = Veh2.Address
								memory.write_int(Addr1, NetID2)
								memory.write_int(Addr2, NetID1)
								Veh1.NetID = NetID2
								Veh2.NetID = NetID1
								CurSwitchIndexTeam1 = CurSwitchIndexTeam1 + 1
							else
								CurSwitchIndexTeam1 = CurSwitchIndexTeam1 + 1
							end
						else
							CurSwitchIndexTeam1 = 2
						end
					end
					if GameTimer >= SwitchIDsMilisTeam2+5000 then
						if CurSwitchIndexTeam2 <= 10 then
							local Veh1 = Vehs[6]
							local Veh2 = Vehs[CurSwitchIndexTeam2]
							if Veh2 ~= nil and Veh1 ~= nil and not Veh2.IsDead then
								SwitchIDsMilisTeam2 = GameTimer
								local NetID1 = Veh1.NetID
								local NetID2 = Veh2.NetID
								local Addr1 = Veh1.Address
								local Addr2 = Veh2.Address
								memory.write_int(Addr1, NetID2)
								memory.write_int(Addr2, NetID1)
								Veh1.NetID = NetID2
								Veh2.NetID = NetID1
								CurSwitchIndexTeam2 = CurSwitchIndexTeam2 + 1
							else
								CurSwitchIndexTeam2 = CurSwitchIndexTeam2 + 1
							end
						else
							CurSwitchIndexTeam2 = 7
						end
					end
				end
			else
				Started = false
				Vehs = {}
			end
			Wait()
		end
	end
end)

--local YOffset = 6.0
--menu.slider_float(GameModesMenu, "Y Offset", {"yoffset"}, "", -500000, 500000, math.floor(YOffset * 100), 100, function(OnChange)
--	YOffset = OnChange / 100
--end)

local CargobobRideWars = false
menu.toggle(GameModesMenu, "Cargobob Ride Wars", {}, "", function(toggle)
	CargobobRideWars = toggle
	if CargobobRideWars then
		local Paths1 = GetVectorsTable(PathDirSaveds.."ChaseBob2_1.txt", true, false)
		local Paths2 = GetVectorsTable(PathDirSaveds.."ChaseBob2_2.txt", true, false)
		local Paths3 = GetVectorsTable(PathDirSaveds.."ChaseBob2_3.txt", true, false)
		local Paths4 = GetVectorsTable(PathDirSaveds.."ChaseBob2_4.txt", true, false)
		local Paths = {Paths1, Paths2, Paths3, Paths4}
		local Vehs = {}
		local Objs = {}
		local VehsLocal = SplitGlobals("Local_22995.f_834.f_81")
		local ObjsLocal = SplitGlobals("Local_22995.f_834.f_147")
		local StartTimer = 0
		local Started = false
		local SwitchIDsMilis = 0
		local PlayerID = PLAYER.PLAYER_ID()
		local IDsToAttach = {
			[1] = {5, 6},
			[2] = {7, 8},
			[3] = {9, 10},
			[4] = {11, 12}
		}
		local Offsets = {
			[1] = {Pos = {x = -3.25, y = 1.5, z = 0.0}, Rot = {x = 0.0, y = 0.0, z = 0.0}},
			[2] = {Pos = {x = 3.25, y = 1.5, z = 0.0}, Rot = {x = 0.0, y = 0.0, z = 0.0}}
		}
		local SwitchIDsMilisTeam1 = 0
		local SwitchIDsMilisTeam2 = 0
		local CurSwitchIndexTeam1 = 6
		local CurSwitchIndexTeam2 = 10
		local WriteGlobals = false
		local Patched = true
		if WriteGlobals then
			local VehPosGlobalNum = SplitGlobals("Global_4980736.f_99616[bVar0 /*615*/]")
			for k = 1, 4 do
				local GlobalAddr = memory.script_global(VehPosGlobalNum + 615 * (k-1))
				memory.write_float(GlobalAddr, Paths[k][1].x)
				memory.write_float(GlobalAddr + 8, Paths[k][1].y)
				memory.write_float(GlobalAddr + 16, Paths[k][1].z)
				memory.write_float(GlobalAddr + 24, Rotation180To360(Paths[k][1].RotZ))
			end
		end
		while CargobobRideWars do
			if SCRIPT.GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH(joaat("fm_mission_controller")) > 0 then
				if not Patched then
					Patched = true
					local Addr = memory.scan_script("fm_mission_controller", "2C ? ? ? 38 01 61 ? ? ? 64 ? ? ? 3F 49 ? ? 41 ? 25 ? 82 56 ? ? 38 00 71 2C ? ? ? 38 01 61 ? ? ? 64 ? ? ? 3F 49 ? ? 41 ? 25 ? 82 56 ? ? 38 00 72 ")
					if Addr ~= 0 then
						local HexT = { 0x00, 0x00, 0x00, 0x00 }
						for i = 1, #HexT do
							memory.write_byte(Addr + (i - 1), HexT[i])
						end
						Print("Patched")
					end
					Addr = memory.scan_script("fm_mission_controller", "2C ? ? ? 55 ? ? 38 00 72 71 2C ? ? ? 38 01 61 ? ? ? 64 ? ? ? 3F 49 ? ? 41 ? 25 ? ")
					if Addr ~= 0 then
						local HexT = { 0x00, 0x00, 0x00, 0x00 }
						for i = 1, #HexT do
							memory.write_byte(Addr + (i - 1), HexT[i])
						end
						Print("Patched")
					end
				end
				if PLAYER.IS_PLAYER_CONTROL_ON(PLAYER.PLAYER_ID()) then
					if not Started then
						StartTimer = MISC.GET_GAME_TIMER()
					end
				 	Started = true
				end
				if Started then
					local TimeStep = SYSTEM.TIMESTEP()
					local GameTimer = MISC.GET_GAME_TIMER()
					for k = 1, 12 do
						if k <= 4 then
							if Vehs[k] == nil then
								local Address = memory.script_local("fm_mission_controller", VehsLocal+k)
								local NetID = memory.read_int(Address)
								if NetID ~= 0 then
									local Handle = 0
									util.spoof_script("fm_mission_controller", function()
										Handle = NETWORK.NET_TO_VEH(NetID)
									end)
									if Handle ~= 0 then
										Vehs[k] = {Handle = Handle, NetID = NetID, PathsTable = Paths[k], Index = 1, Address = Address, IsDead = false, SetInvisible = false}
									end
								end
							end
						end
						if k >= 5 then
							if Vehs[k] == nil then
								local Address = memory.script_local("fm_mission_controller", VehsLocal+k)
								local NetID = memory.read_int(Address)
								if NetID ~= 0 then
									local Handle = 0
									util.spoof_script("fm_mission_controller", function()
										Handle = NETWORK.NET_TO_VEH(NetID)
									end)
									if Handle ~= 0 then
										Vehs[k] = {Handle = Handle, NetID = NetID, Address = Address, IsDead = false, SetInvisible = false}
									end
								end
							end
						end
					end
					for k = 1, 12 do
						if Vehs[k] ~= nil then
							if ENTITY.DOES_ENTITY_EXIST(Vehs[k].Handle) then
								if RequestControlOfEntity(Vehs[k].Handle) then
									NETWORK.NETWORK_SET_ENTITY_CAN_BLEND(Vehs[k].Handle, true)
									entities.set_can_migrate(Vehs[k].Handle, false)
									ENTITY.SET_ENTITY_HAS_GRAVITY(Vehs[k].Handle, false)
									if k >= 5 then
										--ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(Vehs[k].Handle, Vehs[2].Handle, false)
										if not DECORATOR.DECOR_EXIST_ON(Vehs[k].Handle, "RespawnVeh") then
											local bVar0 = math.random(0, 65535)
											DECORATOR.DECOR_SET_INT(Vehs[k].Handle, "RespawnVeh", bVar0);
										end
										--if not Vehs[k].SetInvisible then
											--Vehs[k].SetInvisible= true
										--if ENTITY.IS_ENTITY_VISIBLE(Vehs[k].Handle) then
											--ENTITY.SET_ENTITY_VISIBLE(Vehs[k].Handle, false, false)
											--ENTITY.SET_ENTITY_ALPHA(Vehs[k].Handle, 0, false)
										--end
										--ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION(Vehs[k].Handle, false, true)
									end
									--ENTITY.SET_ENTITY_INVINCIBLE(Vehs[k].Handle, true)
								end
								if k <= 4 then
									--ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(Vehs[1].Handle, Vehs[2].Handle, false)
									--ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(Vehs[2].Handle, Vehs[1].Handle, false)
									--if k == 2 then
										VEHICLE.SET_VEHICLE_DOOR_CONTROL(Vehs[k].Handle, 2, 180, 180.0)
										VEHICLE.SET_DOOR_ALLOWED_TO_BE_BROKEN_OFF(Vehs[k].Handle, 2, false)
										VEHICLE.SET_HELI_TAIL_ROTOR_HEALTH(Vehs[k].Handle, 100000.0)
										VEHICLE.SET_HELI_MAIN_ROTOR_HEALTH(Vehs[k].Handle, 100000.0)
										VEHICLE.SET_HELI_TAIL_BOOM_CAN_BREAK_OFF(Vehs[k].Handle, false)
										--ENTITY.SET_ENTITY_COLLISION(Vehs[k].Handle, false, false)
										--ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION(Vehs[k].Handle, false, false)
									--end
									--for i = 1, #IDsToAttach[k] do
									--	if Vehs[IDsToAttach[k][i]] ~= nil then
									--		--ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(Vehs[IDsToAttach[k][i]].Handle, Vehs[k].Handle, false)
									--		ENTITY.SET_ENTITY_NO_COLLISION_ENTITY(Vehs[k].Handle, PlayerPed, false)
									--	end
									--end
									--VEHICLE.SET_DISABLE_MAP_COLLISION(Vehs[k].Handle)
									if Vehs[k].Index > 0 and Vehs[k].Index < #Vehs[k].PathsTable then
										local CurrentTime = GameTimer - StartTimer
										local Frame1, Frame2 = Vehs[k].PathsTable[Vehs[k].Index], Vehs[k].PathsTable[Vehs[k].Index + 1]
										if UseMilisAdjustLoop then
											while CurrentTime > (Frame2.CurGameTime - Vehs[k].PathsTable[1].CurGameTime) do
												Vehs[k].Index = Vehs[k].Index + 1
												if Vehs[k].Index >= #Vehs[k].PathsTable then
													Vehs[k].Index = #Vehs[k].PathsTable
													break
												else
													Frame1, Frame2 = Vehs[k].PathsTable[Vehs[k].Index], Vehs[k].PathsTable[Vehs[k].Index + 1]
												end
												CurrentTime = MISC.GET_GAME_TIMER() - StartTimer
											end
										else
											if CurrentTime > (Frame2.CurGameTime - Vehs[k].PathsTable[1].CurGameTime) then
												Vehs[k].Index = Vehs[k].Index + 1
												if Vehs[k].Index >= #Vehs[k].PathsTable then
													Vehs[k].Index = #Vehs[k].PathsTable
												else
													Frame1, Frame2 = Vehs[k].PathsTable[Vehs[k].Index], Vehs[k].PathsTable[Vehs[k].Index + 1]
												end
											end
										end
										local Veh = Vehs[k].Handle
										--directx.draw_text(0.5, 0.5, "CurrentTime "..CurrentTime, ALIGN_CENTRE, 1.0, {r = 0.0, g = 1.0 , b = 1.0, a = 1.0}, false)
										--directx.draw_text(0.5, 0.6, "Frame2.CurGameTime - ReplayVehsT[k].Paths[1].CurGameTime "..Frame2.CurGameTime - ReplayVehsT[k].Paths[1].CurGameTime, ALIGN_CENTRE, 1.0, {r = 0.0, g = 1.0 , b = 1.0, a = 1.0}, false)
										local Coord = {
											x = Vehs[k].PathsTable[Vehs[k].Index].x,
											y = Vehs[k].PathsTable[Vehs[k].Index].y,
											z = Vehs[k].PathsTable[Vehs[k].Index].z
										}
										local Rot = {
											x = Vehs[k].PathsTable[Vehs[k].Index].RotX,
											y = Vehs[k].PathsTable[Vehs[k].Index].RotY,
											z = Vehs[k].PathsTable[Vehs[k].Index].RotZ
										}
										local Vel = {
											x = Vehs[k].PathsTable[Vehs[k].Index].VelX,
											y = Vehs[k].PathsTable[Vehs[k].Index].VelY,
											z = Vehs[k].PathsTable[Vehs[k].Index].VelZ
										}
										local AngVel = {
											x = Vehs[k].PathsTable[Vehs[k].Index].AngVelX,
											y = Vehs[k].PathsTable[Vehs[k].Index].AngVelY,
											z = Vehs[k].PathsTable[Vehs[k].Index].AngVelZ
										}
										--if not ReplayTeleportMode then
											SetEntitySpeedToCoord(Veh, Coord, 1.0,
											false, false, false, Vel.x, Vel.y, Vel.z, false, false, nil)
											RotateEntityToTargetRotation(Veh, Rot, 10.0)
										--end
									end
								end
							else
								Vehs[k] = nil
							end
						end
					end
					for k = 1, 4 do
						if Objs[k] == nil then
							local NetID = memory.read_int(memory.script_local("fm_mission_controller", ObjsLocal+k))
							if NetID ~= 0 then
								local Handle = 0
								util.spoof_script("fm_mission_controller", function()
									Handle = NETWORK.NET_TO_OBJ(NetID)
								end)
								if Handle ~= 0 then
									Objs[k] = {Handle = Handle, Offset = nil}
								end
							end
						end
						if Objs[k] ~= nil then
							if ENTITY.DOES_ENTITY_EXIST(Objs[k].Handle) then
								if RequestControlOfEntity(Objs[k].Handle) then
									entities.set_can_migrate(Objs[k].Handle, false)
									--ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION(Objs[k].Handle, false, true)
								end
								if IDsToAttach[k] ~= nil then
									for i = 1, #IDsToAttach[k] do
										if Vehs[IDsToAttach[k][i]] ~= nil then
											if not ENTITY.IS_ENTITY_ATTACHED(Vehs[IDsToAttach[k][i]].Handle) then
												ENTITY.ATTACH_ENTITY_TO_ENTITY(Vehs[IDsToAttach[k][i]].Handle, Objs[k].Handle, 0,
												Offsets[i].Pos.x, Offsets[i].Pos.y, Offsets[i].Pos.z,
												Offsets[i].Rot.x, Offsets[i].Rot.y, Offsets[i].Rot.z, true, false, false, false, 2, true, false)
											end
										end
									end
								end
								if Objs[k].Offset == nil then
									Objs[k].Offset = {x = 0.0, y = 0.0, z = 0.0}
								end
								--ENTITY.SET_ENTITY_VISIBLE(Objs[k].Handle, false, false)
								NETWORK.SET_ENTITY_LOCALLY_INVISIBLE(Objs[k].Handle)
								ENTITY.SET_ENTITY_COMPLETELY_DISABLE_COLLISION(Objs[k].Handle, false, true)
								ENTITY.SET_ENTITY_HAS_GRAVITY(Objs[k].Handle, false)
								if Vehs[k] ~= nil then
									local Speed = ENTITY.GET_ENTITY_VELOCITY(Vehs[k].Handle)
									local Pos = ENTITY.GET_ENTITY_COORDS(Vehs[k].Handle)
									local FinalPos = {
										x = Pos.x + Speed.x * 1.0,
										y = Pos.y + Speed.y * 1.0,
										z = Pos.z + Speed.z * 1.0,
									}
									Speed:mul(0.0)
									SetEntitySpeedToCoord(Objs[k].Handle, FinalPos, 1.0, false, false, false, Speed.x, Speed.y, Speed.z, false, false, nil)
									local Rot = ENTITY.GET_ENTITY_ROTATION(Vehs[k].Handle, 5)
									RotateEntityToTargetRotation(Objs[k].Handle, Rot, 10.0)
								end
							end
						end
					end
					if GameTimer >= SwitchIDsMilisTeam1+5000 then
						if CurSwitchIndexTeam1 <= 8 then
							local Veh1 = Vehs[5]
							local Veh2 = Vehs[CurSwitchIndexTeam1]
							if Veh2 ~= nil and Veh1 ~= nil and not Veh2.IsDead then
								SwitchIDsMilisTeam1 = GameTimer
								local NetID1 = Veh1.NetID
								local NetID2 = Veh2.NetID
								local Addr1 = Veh1.Address
								local Addr2 = Veh2.Address
								memory.write_int(Addr1, NetID2)
								memory.write_int(Addr2, NetID1)
								Veh1.NetID = NetID2
								Veh2.NetID = NetID1
								CurSwitchIndexTeam1 = CurSwitchIndexTeam1 + 1
							else
								CurSwitchIndexTeam1 = CurSwitchIndexTeam1 + 1
							end
						else
							CurSwitchIndexTeam1 = 6
						end
					end
					if GameTimer >= SwitchIDsMilisTeam2+5000 then
						if CurSwitchIndexTeam2 <= 12 then
							local Veh1 = Vehs[9]
							local Veh2 = Vehs[CurSwitchIndexTeam2]
							if Veh2 ~= nil and Veh1 ~= nil and not Veh2.IsDead then
								SwitchIDsMilisTeam2 = GameTimer
								local NetID1 = Veh1.NetID
								local NetID2 = Veh2.NetID
								local Addr1 = Veh1.Address
								local Addr2 = Veh2.Address
								memory.write_int(Addr1, NetID2)
								memory.write_int(Addr2, NetID1)
								Veh1.NetID = NetID2
								Veh2.NetID = NetID1
								CurSwitchIndexTeam2 = CurSwitchIndexTeam2 + 1
							else
								CurSwitchIndexTeam2 = CurSwitchIndexTeam2 + 1
							end
						else
							CurSwitchIndexTeam2 = 10
						end
					end
					local CoordsT = {}
					for k = 1, 4 do
						if Vehs[k] ~= nil then
							CoordsT[#CoordsT+1] = ENTITY.GET_ENTITY_COORDS(Vehs[k].Handle)
						end
					end
					local Center = GetCoordsCenter(CoordsT)
					--local Radius = GetTheBiggerDistance(CoordsT, Center)
					local VectorDistance = GetVector3_Distances(CoordsT, Center, 5.0)
					--GRAPHICS.DRAW_MARKER(28, Center.x, Center.y, Center.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, VectorDistance.x, VectorDistance.y, VectorDistance.z, 255, 255, 0, 100, false, false, 2, false, 0, 0, false)
					--Radius = Radius * 0.5
					--GRAPHICS.SET_BACKFACECULLING(false)
					--GRAPHICS.DRAW_BOX(Center.x - VectorDistance.x, Center.y - VectorDistance.y, Center.z - VectorDistance.z,
					--Center.x + VectorDistance.x, Center.y + VectorDistance.y, Center.z + VectorDistance.z, 255, 255, 0, 100)
					--GRAPHICS.SET_BACKFACECULLING(true)
					--Print(VectorDistance.x)
					for k = 0, 29 do
						local PlayerPedID = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(k)
						if PlayerPedID ~= 0 then
							if not ENTITY.IS_ENTITY_DEAD(PlayerPedID) then
								local Pos = ENTITY.GET_ENTITY_COORDS(PlayerPedID)
								if not ENTITY.IS_ENTITY_AT_COORD(PlayerPedID, Center.x, Center.y, Center.z, VectorDistance.x, VectorDistance.y, VectorDistance.z, false, true, 0) then
									local CurVel = ENTITY.GET_ENTITY_VELOCITY(PlayerPedID)
									CurVel:mul(TimeStep)
									Pos:add(CurVel)
									FIRE.ADD_EXPLOSION(Pos.x, Pos.y, Pos.z, 82, 1000.0, true, false, 0.0, false)
								end
							end
						end
					end
				end
			else
				Started = false
				Vehs = {}
				Objs = {}
			end
			Wait()
		end
	end
end)

local CargoPlaneStunts = false
menu.toggle(GameModesMenu, "Cargo Plane Stunts", {}, "", function(toggle)
	CargoPlaneStunts = toggle
	if CargoPlaneStunts then
		local PathsToLoad = {
			PathDirSaveds.."PlaneStunts1_1.txt",
			PathDirSaveds.."PlaneStunts1_2.txt",
			PathDirSaveds.."PlaneStunts2_1.txt",
			PathDirSaveds.."PlaneStunts2_2.txt",
			PathDirSaveds.."PlaneStunts3_1.txt",
			PathDirSaveds.."PlaneStunts3_2.txt",
			PathDirSaveds.."PlaneStunts4_1.txt",
			PathDirSaveds.."ToPlaneStunts1.txt",
			PathDirSaveds.."ToPlaneStunts2.txt",
			PathDirSaveds.."ToPlaneStunts3.txt",
			PathDirSaveds.."ToPlaneStunts4.txt"
		}
		local CurPriorityLocal = SplitGlobals("Local_28400[iVar0]")
		local Paths = {}
		for k = 1, #PathsToLoad do
			local LoadedPath = GetVectorsTable(PathsToLoad[k], true, false)
			if LoadedPath then
				Paths[k] = LoadedPath
			end
		end
		local Vehs = {}
		local Objs = {}
		local VehsLocal = SplitGlobals("Local_22995.f_834.f_81")
		local CaptureObjectsLocal = SplitGlobals("Local_22995.f_834.f_114")
		local StartTimer = 0
		local Started = false
		local PlayerID = PLAYER.PLAYER_ID()
		local LastPriority = 0
		local Objectives = {
			[0] = {
				Paths = {
					[1] = Paths[1],
					[2] = Paths[2],
					[4] = Paths[8],
				},
				Duration = 101151,
				ReferenceID = 4
			},
			[1] = {
				Paths = {
					[1] = Paths[3],
					[2] = Paths[4],
					[5] = Paths[9],
				},
				Duration = 59914+16000,
				ReferenceID = 5
			},
			[2] = {
				Paths = {
					[3] = Paths[5],
					[1] = Paths[6],
					[6] = Paths[10],
				},
				Duration = 144164,
				ReferenceID = 6
			},
			[3] = {
				Paths = {
					[1] = Paths[7],
					[0] = Paths[1],
					[7] = Paths[11],
				},
				Duration = 41618,
				ReferenceID = 7
			}
		}
		local Bits = 3
		local BringPlayersT = {}
		local FocusedPlayerID = -1
		local FocusedPlayer = 0
		local BringedMilis = 0
		while CargoPlaneStunts do
			if SCRIPT.GET_NUMBER_OF_THREADS_RUNNING_THE_SCRIPT_WITH_THIS_HASH(joaat("fm_mission_controller")) > 0 then
				local PlayerPed = PLAYER.PLAYER_PED_ID()
				local PlayerID = PLAYER.PLAYER_ID()
				if PLAYER.IS_PLAYER_CONTROL_ON(PlayerID) then
					if not Started then
						StartTimer = MISC.GET_GAME_TIMER()
					end
				 	Started = true
				end
				if Started then
					local CurPriority = GET_INT_LOCAL("fm_mission_controller", CurPriorityLocal)
					if CurPriority ~= LastPriority then
						LastPriority = CurPriority
						StartTimer = MISC.GET_GAME_TIMER()
						if not is_bit_set(Bits, 1) then
							Bits = set_bit(Bits, 1)
						end
						if not is_bit_set(Bits, 2) then
							Bits = set_bit(Bits, 2)
						end
						BringPlayersT = {}
					end
					local TimeStep = SYSTEM.TIMESTEP()
					local GameTimer = MISC.GET_GAME_TIMER()
					for k = 1, 4 do
						if Objs[k] == nil then
							local Address = memory.script_local("fm_mission_controller", CaptureObjectsLocal+k)
							local NetID = memory.read_int(Address)
							if NetID ~= 0 then
								local Handle = 0
								util.spoof_script("fm_mission_controller", function()
									Handle = NETWORK.NET_TO_OBJ(NetID)
								end)
								if Handle ~= 0 then
									Objs[k] = {Handle = Handle, NetID = NetID, Address = Address}
								end
							end
						end
					end
					for k = 1, 7 do
						if Vehs[k] == nil then
							local Address = memory.script_local("fm_mission_controller", VehsLocal+k)
							local NetID = memory.read_int(Address)
							if NetID ~= 0 then
								local Handle = 0
								util.spoof_script("fm_mission_controller", function()
									Handle = NETWORK.NET_TO_VEH(NetID)
								end)
								if Handle ~= 0 then
									Vehs[k] = {Handle = Handle, NetID = NetID, PathsTable = nil, Index = 1, Address = Address, IsDead = false, SetInvisible = false,
									IsCargoPlane = ENTITY.GET_ENTITY_MODEL(Handle) == joaat("cargoplane")}
								end
							end
						end
					end
					for k = 1, 7 do
						if Vehs[k] ~= nil then
							if ENTITY.DOES_ENTITY_EXIST(Vehs[k].Handle) then
								if RequestControlOfEntity(Vehs[k].Handle) then
									NETWORK.NETWORK_SET_ENTITY_CAN_BLEND(Vehs[k].Handle, true)
									entities.set_can_migrate(Vehs[k].Handle, false)
									ENTITY.SET_ENTITY_HAS_GRAVITY(Vehs[k].Handle, false)
								end
								if Vehs[k].IsCargoPlane then
									--VEHICLE.SET_DOOR_ALLOWED_TO_BE_BROKEN_OFF(Vehs[k].Handle, 2, false)
									--VEHICLE.SET_VEHICLE_DOOR_CONTROL(Vehs[k].Handle, 2, 180, 180.0)
								end
								VEHICLE.SET_HELI_TAIL_ROTOR_HEALTH(Vehs[k].Handle, 100000.0)
								VEHICLE.SET_HELI_MAIN_ROTOR_HEALTH(Vehs[k].Handle, 100000.0)
								VEHICLE.SET_HELI_TAIL_BOOM_CAN_BREAK_OFF(Vehs[k].Handle, false)
								if is_bit_set(Bits, 1) then
									Vehs[k].Index = 1
								end
								if Objectives[CurPriority] and Objectives[CurPriority].Paths[k] then
									Vehs[k].PathsTable = Objectives[CurPriority].Paths[k]
								end
								if Vehs[k].PathsTable ~= nil then
									if Vehs[k].Index > 0 and Vehs[k].Index < #Vehs[k].PathsTable then
										local CurrentTime = GameTimer - StartTimer
										local Frame1, Frame2 = Vehs[k].PathsTable[Vehs[k].Index], Vehs[k].PathsTable[Vehs[k].Index + 1]
										if UseMilisAdjustLoop then
											while CurrentTime > (Frame2.CurGameTime - Vehs[k].PathsTable[1].CurGameTime) do
												Vehs[k].Index = Vehs[k].Index + 1
												if Vehs[k].Index >= #Vehs[k].PathsTable then
													Vehs[k].Index = #Vehs[k].PathsTable
													break
												else
													Frame1, Frame2 = Vehs[k].PathsTable[Vehs[k].Index], Vehs[k].PathsTable[Vehs[k].Index + 1]
												end
												CurrentTime = MISC.GET_GAME_TIMER() - StartTimer
											end
										else
											if CurrentTime > (Frame2.CurGameTime - Vehs[k].PathsTable[1].CurGameTime) then
												Vehs[k].Index = Vehs[k].Index + 1
												if Vehs[k].Index >= #Vehs[k].PathsTable then
													Vehs[k].Index = #Vehs[k].PathsTable
												else
													Frame1, Frame2 = Vehs[k].PathsTable[Vehs[k].Index], Vehs[k].PathsTable[Vehs[k].Index + 1]
												end
											end
										end
										local Veh = Vehs[k].Handle
										--directx.draw_text(0.5, 0.5, "CurrentTime "..CurrentTime, ALIGN_CENTRE, 1.0, {r = 0.0, g = 1.0 , b = 1.0, a = 1.0}, false)
										--directx.draw_text(0.5, 0.6, "Frame2.CurGameTime - ReplayVehsT[k].Paths[1].CurGameTime "..Frame2.CurGameTime - ReplayVehsT[k].Paths[1].CurGameTime, ALIGN_CENTRE, 1.0, {r = 0.0, g = 1.0 , b = 1.0, a = 1.0}, false)
										local Coord = {
											x = Vehs[k].PathsTable[Vehs[k].Index].x,
											y = Vehs[k].PathsTable[Vehs[k].Index].y,
											z = Vehs[k].PathsTable[Vehs[k].Index].z
										}
										local Rot = {
											x = Vehs[k].PathsTable[Vehs[k].Index].RotX,
											y = Vehs[k].PathsTable[Vehs[k].Index].RotY,
											z = Vehs[k].PathsTable[Vehs[k].Index].RotZ
										}
										local Vel = {
											x = Vehs[k].PathsTable[Vehs[k].Index].VelX,
											y = Vehs[k].PathsTable[Vehs[k].Index].VelY,
											z = Vehs[k].PathsTable[Vehs[k].Index].VelZ
										}
										local AngVel = {
											x = Vehs[k].PathsTable[Vehs[k].Index].AngVelX,
											y = Vehs[k].PathsTable[Vehs[k].Index].AngVelY,
											z = Vehs[k].PathsTable[Vehs[k].Index].AngVelZ
										}
										if is_bit_set(Bits, 1) then
											ENTITY.SET_ENTITY_COORDS(Veh, Coord.x, Coord.y, Coord.z)
											ENTITY.SET_ENTITY_ROTATION(Veh, Rot.x, Rot.y, Rot.z, 5)
											if not is_bit_set(Bits, 3) then
												Bits = set_bit(Bits, 3)
											end
										else
											SetEntitySpeedToCoord(Veh, Coord, 1.0,
											false, false, false, Vel.x, Vel.y, Vel.z, false, false, nil)
											RotateEntityToTargetRotation(Veh, Rot, 10.0)
										end
									end
								end
							else
								Vehs[k] = nil
							end
						end
					end
					if is_bit_set(Bits, 3) then
						if is_bit_set(Bits, 1) then
							Bits = clear_bit(Bits, 1)
							Bits = clear_bit(Bits, 3)
						end
					end
					local Duration = Objectives[CurPriority] and Objectives[CurPriority].Duration or 10000
					if GameTimer > StartTimer+Duration then
						if Objs[CurPriority+1] ~= nil and ENTITY.DOES_ENTITY_EXIST(Objs[CurPriority+1].Handle) then
							if RequestControlOfEntity(Objs[CurPriority+1].Handle) then
								OBJECT.ATTACH_PORTABLE_PICKUP_TO_PED(Objs[CurPriority+1].Handle, PlayerPed)
							end
						end
					end
					if is_bit_set(Bits, 2) then
						if Objectives[CurPriority] and Vehs[Objectives[CurPriority].ReferenceID] ~= nil then
							local BringedSet = 0
							local ReferencePos = ENTITY.GET_ENTITY_COORDS(Vehs[Objectives[CurPriority].ReferenceID].Handle)
							local ReferenceRot = ENTITY.GET_ENTITY_ROTATION(Vehs[Objectives[CurPriority].ReferenceID].Handle, 5)
							local ReferenceVel = ENTITY.GET_ENTITY_VELOCITY(Vehs[Objectives[CurPriority].ReferenceID].Handle)
							local ReferenceAngVel = ENTITY.GET_ENTITY_ROTATION_VELOCITY(Vehs[Objectives[CurPriority].ReferenceID].Handle)
							if FocusedPlayerID == -1 then
								for k = 0, 29 do
									local PlayerPedID = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(k)
									if PlayerPedID ~= 0 then
										if not ENTITY.IS_ENTITY_DEAD(PlayerPedID) then
											if not ENTITY.IS_ENTITY_AT_COORD(PlayerPedID, ReferencePos.x,
											ReferencePos.y, ReferencePos.z,
											300.0, 300.0, 300.0, false, true, 0) then
												FocusedPlayerID = k
												FocusedPlayer = PlayerPedID
												BringedMilis = GameTimer
												break
											end
										end
									end
								end
							end
							if FocusedPlayerID ~= -1 then
								local PlayerPedID = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(FocusedPlayerID)
								local PlayerVeh = PED.GET_VEHICLE_PED_IS_IN(PlayerPedID, false)
								FocusedPlayer = PlayerPedID
								if FocusedPlayerID ~= PlayerID then
									NETWORK.NETWORK_SET_IN_SPECTATOR_MODE(true, PlayerPedID)
								end
								if PlayerVeh ~= 0 then
									if PED.IS_PED_IN_VEHICLE(PlayerPedID, PlayerVeh, false) then
										if not ENTITY.IS_ENTITY_AT_COORD(PlayerPedID, ReferencePos.x,
										ReferencePos.y, ReferencePos.z,
										300.0, 300.0, 300.0, false, true, 0) then
											if NETWORK.NETWORK_REQUEST_CONTROL_OF_ENTITY(PlayerVeh) and GameTimer+1000 then
												--BringedSet = BringedSet + 1
												ENTITY.SET_ENTITY_COORDS(PlayerVeh, ReferencePos.x, ReferencePos.y, ReferencePos.z)
												ENTITY.SET_ENTITY_ROTATION(PlayerVeh, ReferenceRot.x, ReferenceRot.y, ReferenceRot.z, 5)
												ENTITY.SET_ENTITY_VELOCITY(PlayerVeh, ReferenceVel.x, ReferenceVel.y, ReferenceVel.z)
												ENTITY.SET_ENTITY_ANGULAR_VELOCITY(PlayerVeh, ReferenceAngVel.x, ReferenceAngVel.y, ReferenceAngVel.z)
												ENTITY.SET_ENTITY_COLLISION(PlayerVeh, true, true)
											else
												if NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(PlayerVeh) then
													--entities.give_control(PlayerVeh, k)
												end
											end
										end
									else
										NETWORK.NETWORK_SET_IN_SPECTATOR_MODE(false, PlayerPed)
										if PlayerVeh ~= 0 then
											if NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(PlayerVeh) then
												entities.give_control(PlayerVeh, FocusedPlayerID)
											end
										end
										FocusedPlayer = 0
										FocusedPlayerID = -1
									end
								end
								if FocusedPlayerID ~= -1 then
									if ENTITY.IS_ENTITY_AT_COORD(PlayerPedID, ReferencePos.x,
									ReferencePos.y, ReferencePos.z,
									300.0, 300.0, 300.0, false, true, 0) then
										if GameTimer > BringedMilis+2000 then
											NETWORK.NETWORK_SET_IN_SPECTATOR_MODE(false, PlayerPed)
											if PlayerVeh ~= 0 then
												if NETWORK.NETWORK_HAS_CONTROL_OF_ENTITY(PlayerVeh) then
													entities.give_control(PlayerVeh, FocusedPlayerID)
												end
											end
											FocusedPlayer = 0
											FocusedPlayerID = -1
										else
											if PlayerVeh ~= 0 then
												ENTITY.SET_ENTITY_COORDS(PlayerVeh, ReferencePos.x, ReferencePos.y, ReferencePos.z)
												ENTITY.SET_ENTITY_ROTATION(PlayerVeh, ReferenceRot.x, ReferenceRot.y, ReferenceRot.z, 5)
												ENTITY.SET_ENTITY_VELOCITY(PlayerVeh, ReferenceVel.x, ReferenceVel.y, ReferenceVel.z)
												ENTITY.SET_ENTITY_ANGULAR_VELOCITY(PlayerVeh, ReferenceAngVel.x, ReferenceAngVel.y, ReferenceAngVel.z)
												ENTITY.SET_ENTITY_COLLISION(PlayerVeh, true, true)
											end
										end
									end
								end
							end
							if FocusedPlayerID == -1 then
								NETWORK.NETWORK_SET_IN_SPECTATOR_MODE(false, PlayerPed)
							end
							--if FocusedPlayer ~= 0 and ENTITY.DOES_ENTITY_EXIST(FocusedPlayer) and GameTimer < BringedMilis+1000 then
							--	NETWORK.NETWORK_SET_IN_SPECTATOR_MODE(true, FocusedPlayer)
							--else
							--	FocusedPlayer = 0
							--end
							--if BringedSet == 0 and GameTimer > BringedMilis+1000 and FocusedPlayer == 0 then
							--	NETWORK.NETWORK_SET_IN_SPECTATOR_MODE(false, PlayerPed)
							--end
						end
					end
				end
			else
				Started = false
				Vehs = {}
				Objs = {}
				LastPriority = 0
				BringPlayersT = {}
				Bits = 3
			end
			Wait()
		end
	end
end)

function GetRotationDifference(CurRot, TargetRot)
	local RotDifference = {
        x = TargetRot.x - CurRot.x,
        y = TargetRot.y - CurRot.y,
        z = TargetRot.z - CurRot.z,
    }
    
    RotDifference.x = (RotDifference.x + 180) % 360 - 180
    RotDifference.y = (RotDifference.y + 180) % 360 - 180
    RotDifference.z = (RotDifference.z + 180) % 360 - 180
	return RotDifference
end

function QuatInverse(q)
    return {x = -q.x, y = -q.y, z = -q.z, w = q.w}
end

function QuatMultiply(q1, q2)
    return {
        x = q1.w * q2.x + q1.x * q2.w + q1.y * q2.z - q1.z * q2.y,
        y = q1.w * q2.y - q1.x * q2.z + q1.y * q2.w + q1.z * q2.x,
        z = q1.w * q2.z + q1.x * q2.y - q1.y * q2.x + q1.z * q2.w,
        w = q1.w * q2.w - q1.x * q2.x - q1.y * q2.y - q1.z * q2.z
    }
end

function QuatToEuler(q)
    local ysqr = q.y * q.y

    -- Roll (X)
    local t0 = 2.0 * (q.w * q.x + q.y * q.z)
    local t1 = 1.0 - 2.0 * (q.x * q.x + ysqr)
    local roll = math.atan(t0, t1)

    -- Pitch (Y)
    local t2 = 2.0 * (q.w * q.y - q.z * q.x)
    t2 = math.max(-1.0, math.min(1.0, t2))
    local pitch = math.asin(t2)

    -- Yaw (Z)
    local t3 = 2.0 * (q.w * q.z + q.x * q.y)
    local t4 = 1.0 - 2.0 * (ysqr + q.z * q.z)
    local yaw = math.atan(t3, t4)

    return {x = math.deg(roll), y = math.deg(pitch), z = math.deg(yaw)}
end

function GetEntityQuaternion(ent)
	local q_pointer = memory.alloc(8 * 4)
    ENTITY.GET_ENTITY_QUATERNION(ent, q_pointer, q_pointer + 8, q_pointer + 16, q_pointer + 24)
    return {
		x = memory.read_float(q_pointer),
        y = memory.read_float(q_pointer + 8),
        z = memory.read_float(q_pointer + 16),
        w = memory.read_float(q_pointer + 24)}
end

-------------------------------------------------------------------------------
-- Produto vetorial: cross(u, v) = (u.y*v.z - u.z*v.y, u.z*v.x - u.x*v.z, u.x*v.y - u.y*v.x)
-------------------------------------------------------------------------------
function CrossProduct(a, b)
    return {
        x = a.y * b.z - a.z * b.y,
        y = a.z * b.x - a.x * b.z,
        z = a.x * b.y - a.y * b.x
    }
end

-------------------------------------------------------------------------------
-- Soma vetorial simples: a + b
-------------------------------------------------------------------------------
function VecAdd(a, b)
    return {
        x = a.x + b.x,
        y = a.y + b.y,
        z = a.z + b.z
    }
end

-------------------------------------------------------------------------------
-- Escala um vetor: a * escalar
-------------------------------------------------------------------------------
function VecScale(a, s)
    return {
        x = a.x * s,
        y = a.y * s,
        z = a.z * s
    }
end

-------------------------------------------------------------------------------
-- Magnitude de um vetor
-------------------------------------------------------------------------------
function VecMag(a)
    return math.sqrt(a.x*a.x + a.y*a.y + a.z*a.z)
end

-------------------------------------------------------------------------------
-- Normaliza um vetor
-------------------------------------------------------------------------------
function VecNormalize(a)
    local mag = VecMag(a)
    if mag > 0.000001 then
        return { x = a.x / mag, y = a.y / mag, z = a.z / mag }
    else
        return { x = 0, y = 0, z = 0 }
    end
end

function PredictEntityOffsetCoords(entity, offset, dt, angularVelocity)
    -- 1) Lê a matriz atual: fwd, right, up, pos
    local ForwardVector, RightVector, UpVector, PositionVector = v3.new(), v3.new(), v3.new(), v3.new()
	ENTITY.GET_ENTITY_MATRIX(entity, ForwardVector, RightVector, UpVector, PositionVector)
    local fwdx, fwdy, fwdz,
          rightx, righty, rightz,
          upx, upy, upz,
          px, py, pz = ForwardVector.x, ForwardVector.y, ForwardVector.z,
          RightVector.x, RightVector.y, RightVector.z,
          UpVector.x, UpVector.y, UpVector.z,
          PositionVector.x, PositionVector.y, PositionVector.z

    local fwd   = { x=fwdx,  y=fwdy,  z=fwdz }
    local right = { x=rightx,y=righty,z=rightz }
    local up    = { x=upx,   y=upy,   z=upz  }
    local pos   = { x=px,    y=py,    z=pz   }
    
    -- 2) Velocidade linear da entidade
    local linVel = ENTITY.GET_ENTITY_VELOCITY(entity)  -- {x,y,z}
    
    -- 3) Prediz a posição do pivô no t+dt
    local predictedPos = {
        x = pos.x + linVel.x * dt,
        y = pos.y + linVel.y * dt,
        z = pos.z + linVel.z * dt
    }
    
    -- 4) Atualiza fwd, right, up baseado na velocidade angular (pequena rotação)
    --    newVector = oldVector + (omega x oldVector) * dt
    local w = angularVelocity  -- atalho
    local function UpdateVec(vec)
        local crossTerm = CrossProduct(w, vec) -- w x vec
        local newVec = VecAdd(vec, VecScale(crossTerm, dt))
        return VecNormalize(newVec)  -- normaliza para evitar distorção
    end
    
    local fwdNext   = UpdateVec(fwd)
    local rightNext = UpdateVec(right)
    local upNext    = UpdateVec(up)
    
    local offsetPos = {
        x = predictedPos.x
            + rightNext.x * offset.x
            + fwdNext.x   * offset.y
            + upNext.x    * offset.z,
        y = predictedPos.y
            + rightNext.y * offset.x
            + fwdNext.y   * offset.y
            + upNext.y    * offset.z,
        z = predictedPos.z
            + rightNext.z * offset.x
            + fwdNext.z   * offset.y
            + upNext.z    * offset.z
    }
    
    return offsetPos
end

--menu.action(menu.my_root(), "Test", {}, "", function(toggle)
--	local Veh = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), true)
--	if Veh ~= 0 then
--		--NETWORK.SET_NETWORK_VEHICLE_AS_GHOST(Veh, true)
--		--ENTITY.SET_ENTITY_COLLISION(Veh, false, true)
--		--ENTITY.SET_ENTITY_VISIBLE(Veh, false, false)
--		TASK.TASK_LEAVE_VEHICLE(PLAYER.PLAYER_PED_ID(), Veh, 4096)
--	end
--end)

--local CurrentIndex = 1
--local StartTime = MISC.GET_GAME_TIMER()
--local TimeLimit = 3000  -- 3 segundos por índice
--local TimeTable = {0, 0, 0}  -- Armazena o tempo de cada índice
--local TotalElapsedTime = 0  -- Tempo total acumulado
--local ContinuacaoTempo = 0  -- Tempo de continuação apenas para o índice 1
--
--menu.toggle_loop(menu.my_root(), "Time Test", {}, "", function(toggle)
--	local CurrentTime = MISC.GET_GAME_TIMER()
--	local ElapsedTime = CurrentTime - StartTime
--
--	-- Atualiza o tempo no índice atual
--	TimeTable[CurrentIndex] = ElapsedTime
--
--	-- Se estamos no índice 1, aplicamos a continuação do tempo
--	local DisplayTime = ElapsedTime
--	if CurrentIndex == 1 then
--		DisplayTime = ContinuacaoTempo + ElapsedTime
--	end
--
--	-- Imprime os tempos para depuração
--	print(string.format("Índice: %d | Tempo no Índice: %d ms | Tempo Total: %d ms | Continuação: %d ms",
--		CurrentIndex, TimeTable[CurrentIndex], TotalElapsedTime + ElapsedTime, ContinuacaoTempo))
--
--	-- Se passar de 3 segundos, muda para o próximo índice
--	if ElapsedTime >= TimeLimit then
--		-- Se estamos voltando para o índice 1, acumular o tempo total
--		if CurrentIndex == 3 then
--			ContinuacaoTempo = ContinuacaoTempo + TimeLimit
--		end
--
--		-- Muda para o próximo índice (1 → 2 → 3 → 1 ...)
--		CurrentIndex = CurrentIndex + 1
--		if CurrentIndex > 3 then
--			CurrentIndex = 1  -- Voltar para o primeiro índice
--		end
--
--		-- Reiniciar o tempo para o novo índice
--		StartTime = MISC.GET_GAME_TIMER()
--		TimeTable[CurrentIndex] = 0  -- Reseta o tempo local do índice
--	end
--end)]

function Rotation180To360(Angle)
    if Angle < 0.0 then
        return 360.0 + Angle
    else
        return Angle
    end
end

function GetCoordsCenter(CoordsT)
    local cx, cy, cz = 0, 0, 0
    local NumCoords = #CoordsT

    for i = 1, NumCoords do
        cx = cx + CoordsT[i].x
        cy = cy + CoordsT[i].y
        cz = cz + CoordsT[i].z
    end
    cx = cx / NumCoords
    cy = cy / NumCoords
    cz = cz / NumCoords

    return {x = cx, y = cy, z = cz}
end

function GetTheBiggerDistance(CoordsT, Center)
	local Distance = 0.0
    for i = 1, #CoordsT do
        local Dist = DistanceBetween(CoordsT[i].x, CoordsT[i].y, CoordsT[i].z, Center.x, Center.y, Center.z)-- * 0.5
        if Dist > Distance then
            Distance = Dist
        end
    end
	return Distance
end

function GetVector3_Distances(CoordsT, Center, Adjust)
    local d_x, d_y, d_z = 0, 0, 0
    for _, heli in ipairs(CoordsT) do
        d_x = math.max(d_x, math.abs(heli.x - Center.x))
        d_y = math.max(d_y, math.abs(heli.y - Center.y))
        d_z = math.max(d_z, math.abs(heli.z - Center.z))
    end
    local L_x = d_x + Adjust
    local L_y = d_y + Adjust
    local L_z = d_z + Adjust

    return {x = L_x, y = L_y, z = L_z}
end

function file_read(file)
    local f = io.open(file, "rb")
    if not f then return nil end
    local content = f:read("*a") -- Lê tudo de uma vez (muito mais rápido)
    f:close()
    return content
end

function GetVectorsTable(fileName, delayLoad, getOnlyFirstData)
    local content = file_read(fileName)
    if not content then return {} end
    
    local vectorTable = {}
    local maxIt = 1000
    local it = 0

    for line in content:gmatch("[^\r\n]+") do -- Divide manualmente por linhas
        local numbers = {}
        for n in line:gmatch("%S+") do -- Divide por espaços
            numbers[#numbers + 1] = tonumber(n)
        end

        vectorTable[#vectorTable + 1] = {
            x = numbers[1], y = numbers[2], z = numbers[3],
            RotX = numbers[4], RotY = numbers[5], RotZ = numbers[6],
            VelX = numbers[7], VelY = numbers[8], VelZ = numbers[9],
            AngVelX = numbers[10], AngVelY = numbers[11], AngVelZ = numbers[12],
            CurGameTime = numbers[13], ModelHash = numbers[14], Steering = numbers[15] or 0.0
        }

        if delayLoad then
            it = it + 1
            if it >= maxIt then
                it = 0
                Wait() -- Dá um respiro no loop
            end
        end

        if getOnlyFirstData then
            break
        end
    end

    return vectorTable
end

function GetVectorsFromIndex(Txts)
	local Vectors = nil
	for line in Txts:gmatch("[^\r\n]+") do -- Divide manualmente por linhas
        local numbers = {}
        for n in line:gmatch("%S+") do -- Divide por espaços
            numbers[#numbers + 1] = tonumber(n)
        end
        Vectors = {
            x = numbers[1], y = numbers[2], z = numbers[3],
            RotX = numbers[4], RotY = numbers[5], RotZ = numbers[6],
            VelX = numbers[7], VelY = numbers[8], VelZ = numbers[9],
            AngVelX = numbers[10], AngVelY = numbers[11], AngVelZ = numbers[12],
            CurGameTime = numbers[13], ModelHash = numbers[14], Steering = numbers[15] or 0.0
        }
	end
	return Vectors
end

function QuaternionToEulerOrder(x, y, z, w, order)
    local ysqr = y * y

    local t0, t1, t2, t3, t4
    local pitch, yaw, roll

    if order == "XYZ" then
        t0 = 2 * (w * x + y * z)
        t1 = 1 - 2 * (x * x + ysqr)
        pitch = math.atan2(t0, t1)

        t2 = 2 * (w * y - z * x)
        t2 = math.max(-1, math.min(1, t2))
        yaw = math.asin(t2)

        t3 = 2 * (w * z + x * y)
        t4 = 1 - 2 * (ysqr + z * z)
        roll = math.atan2(t3, t4)

    elseif order == "XZY" then
        t0 = 2 * (w * x + z * y)
        t1 = 1 - 2 * (x * x + z * z)
        pitch = math.atan2(t0, t1)

        t2 = 2 * (w * z - x * y)
        t2 = math.max(-1, math.min(1, t2))
        roll = math.asin(t2)

        t3 = 2 * (w * y + x * z)
        t4 = 1 - 2 * (ysqr + z * z)
        yaw = math.atan2(t3, t4)

    elseif order == "YXZ" then
        t0 = 2 * (w * y - x * z)
        t1 = 1 - 2 * (y * y + z * z)
        yaw = math.atan2(t0, t1)

        t2 = 2 * (w * x + y * z)
        t2 = math.max(-1, math.min(1, t2))
        pitch = math.asin(t2)

        t3 = 2 * (w * z - x * y)
        t4 = 1 - 2 * (ysqr + x * x)
        roll = math.atan2(t3, t4)

    elseif order == "YZX" then
        t0 = 2 * (w * y + x * z)
        t1 = 1 - 2 * (y * y + x * x)
        yaw = math.atan2(t0, t1)

        t2 = 2 * (w * x - y * z)
        t2 = math.max(-1, math.min(1, t2))
        roll = math.asin(t2)

        t3 = 2 * (w * z + y * x)
        t4 = 1 - 2 * (ysqr + x * x)
        pitch = math.atan2(t3, t4)

    elseif order == "ZXY" then
        t0 = 2 * (w * z - x * y)
        t1 = 1 - 2 * (z * z + y * y)
        roll = math.atan2(t0, t1)

        t2 = 2 * (w * y + x * z)
        t2 = math.max(-1, math.min(1, t2))
        pitch = math.asin(t2)

        t3 = 2 * (w * x - y * z)
        t4 = 1 - 2 * (ysqr + z * z)
        yaw = math.atan2(t3, t4)

    elseif order == "ZYX" then
        t0 = 2 * (w * z + x * y)
        t1 = 1 - 2 * (z * z + y * y)
        yaw = math.atan2(t0, t1)

        t2 = 2 * (w * y - x * z)
        t2 = math.max(-1, math.min(1, t2))
        pitch = math.asin(t2)

        t3 = 2 * (w * x + y * z)
        t4 = 1 - 2 * (ysqr + x * x)
        roll = math.atan2(t3, t4)
    else
        error("Ordem de rotação inválida. Escolha entre XYZ, XZY, YXZ, YZX, ZXY ou ZYX.")
    end

    return {x = rad2deg(pitch), y = rad2deg(yaw), z = rad2deg(roll)}
end

function GetValidEulerOrders(entity)
    local validOrders = {}
	local T1 = GetEntityQuaternion(entity)
    -- Obtém o quaternion da entidade
    local qX, qY, qZ, qW = T1.x, T1.y, T1.z, T1.w

    -- Todas as 6 ordens possíveis de rotação Euler
    local orders = {"XYZ", "XZY", "YXZ", "YZX", "ZXY", "ZYX"}

    -- Testa cada ordem de rotação
    for _, order in ipairs(orders) do
		local T2 = QuaternionToEulerOrder(qX, qY, qZ, qW, order)
        -- Converte o quaternion para Euler na ordem atual
        local pitch, yaw, roll = T2.x, T2.y, T2.z
		for k = 0, 5 do
			-- Obtém a rotação Euler diretamente da native com a mesma ordem
			local entityRot = ENTITY.GET_ENTITY_ROTATION(entity, k) -- O FiveM usa números (0 a 5)
			
			--local Txt = "entityRot order "..order..": x: "..string.format("%0.3f", entityRot.x).." y: "..string.format("%0.3f", entityRot.y).." z: "..string.format("%0.3f", entityRot.z)
			--directx.draw_text(0.2 + 0.2 * k, 0.275 + 0.025 * (_), Txt, ALIGN_CENTRE, 1.0, {r = 0.0, g = 1.0 , b = 1.0, a = 1.0}, false)
			-- Tolerância para comparar flutuações numéricas
			local tolerance = 0.01
			-- Verifica se os valores batem dentro da tolerância
			if math.abs(entityRot.x - pitch) < tolerance and
			math.abs(entityRot.y - yaw) < tolerance and
			math.abs(entityRot.z - roll) < tolerance then
				table.insert(validOrders, order)
			end
		end
    end

    return validOrders
end


--menu.toggle_loop(menu.my_root(), "Rot Quat Test", {}, "", function(toggle)
--	local Veh = PED.GET_VEHICLE_PED_IS_IN(PLAYER.PLAYER_PED_ID(), true)
--	if Veh ~= 0 then
--		--local Quat = GetEntityQuaternion(Veh)
--		--local GameRot = ENTITY.GET_ENTITY_ROTATION(Veh, 5)
--		--local FuncRot = QuaternionToEulerOrder(Quat.x, Quat.y, Quat.z, Quat.w, "ZYX")
--		--FuncRot.x = rad2deg(FuncRot.x)
--		--FuncRot.y = rad2deg(FuncRot.y)
--		--FuncRot.z = rad2deg(FuncRot.z)
--		--local Txt = "GameRot: x: "..string.format("%0.3f", GameRot.x).." y: "..string.format("%0.3f", GameRot.y).." z: "..string.format("%0.3f", GameRot.z)
--		--directx.draw_text(0.7, 0.5, Txt, ALIGN_CENTRE, 1.0, {r = 0.0, g = 1.0 , b = 1.0, a = 1.0}, false)
--		--local Txt2 = "FuncRot: x: "..string.format("%0.3f", FuncRot.x).." y: "..string.format("%0.3f", FuncRot.y).." z: "..string.format("%0.3f", FuncRot.z)
--		--directx.draw_text(0.7, 0.525, Txt2, ALIGN_CENTRE, 1.0, {r = 0.0, g = 1.0 , b = 1.0, a = 1.0}, false)
--		local ValidOrders = GetValidEulerOrders(Veh)
--		for k = 1, #ValidOrders do
--			directx.draw_text(0.3, 0.475 + 0.025 * k, ValidOrders[k], ALIGN_CENTRE, 1.0, {r = 0.0, g = 1.0 , b = 1.0, a = 1.0}, false)
--		end
--	end
--end)
function GET_INT_LOCAL(script, script_local)
	if memory.script_local(script, script_local) ~= 0 then
		local ReadLocal = memory.read_int(memory.script_local(script, script_local))
		if ReadLocal ~= nil then
			return ReadLocal
		end
	end
end

--menu.action(menu.my_root(), "Event Test", {}, "", function(toggle)
	--local ArgsAddr = memory.alloc(8*5)
	--memory.write_int(ArgsAddr + 8 * 0, -793987806)
	--memory.write_int(ArgsAddr + 8 * 1, PLAYER.PLAYER_ID())
	--memory.write_int(ArgsAddr + 8 * 2, 0) -- Player to swap team
	--memory.write_int(ArgsAddr + 8 * 3, 0) -- Team
	--memory.write_int(ArgsAddr + 8 * 4, 3) -- Spawn Point Index
	--memory.write_int(ArgsAddr + 8 * 5, 1) -- Set
	--SCRIPT._SEND_TU_SCRIPT_EVENT_NEW(1, ArgsAddr, 8, 1 << PLAYER.PLAYER_ID(), -793987806)

	
	--local ArgsAddr = memory.alloc(8*10)
	--memory.write_int(ArgsAddr + 8 * 0, -1514442960)
	--memory.write_int(ArgsAddr + 8 * 1, PLAYER.PLAYER_ID())
	--memory.write_int(ArgsAddr + 8 * 2, 0) -- Player to swap team
	--memory.write_int(ArgsAddr + 8 * 3, 0) -- Team
	--memory.write_int(ArgsAddr + 8 * 4, 0) -- Spawn Point Index
	--memory.write_int(ArgsAddr + 8 * 5, 0) -- Set
	--memory.write_int(ArgsAddr + 8 * 6, 0) -- Set
	--memory.write_int(ArgsAddr + 8 * 7, 0) -- Set
	--memory.write_int(ArgsAddr + 8 * 8, 0) -- Set
	--memory.write_int(ArgsAddr + 8 * 9, 0) -- Set
	--SCRIPT._SEND_TU_SCRIPT_EVENT_NEW(1, ArgsAddr, 10, 1 << PLAYER.PLAYER_ID(), -1514442960)
--end)

--for k = 0, 29 do
--	local PlayerPedID = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(k)
--	if PlayerPedID ~= 0 then
--		NETWORK.NETWORK_SET_IN_SPECTATOR_MODE(false, PlayerPedID)
--	end
--end

function RaycastFromCamera(PlayerPed, Distance, Flags)
	local FlagBits = -1
	if Flags ~= nil then
		FlagBits = Flags
	end
	local HitCoords = v3.new()
	local CamRot = CAM.GET_GAMEPLAY_CAM_ROT(2)
	local FVect = CamRot:toDir()
	local PPos = CAM.GET_GAMEPLAY_CAM_COORD()
	local AdjustedX = PPos.x + FVect.x * Distance
	local AdjustedY = PPos.y + FVect.y * Distance
	local AdjustedZ = PPos.z + FVect.z * Distance
	local DidHit = memory.alloc(1)
	local EndCoords = v3.new()
	local Normal = v3.new()
	local HitEntity = memory.alloc_int()
	
	local Handle = SHAPETEST.START_EXPENSIVE_SYNCHRONOUS_SHAPE_TEST_LOS_PROBE(
		PPos.x, PPos.y, PPos.z,
		AdjustedX, AdjustedY, AdjustedZ,
		FlagBits,
		PlayerPed, 7
	)
	SHAPETEST.GET_SHAPE_TEST_RESULT(Handle, DidHit, EndCoords, Normal, HitEntity)
	if memory.read_byte(DidHit) ~= 0 then
		HitCoords.x = EndCoords.x
		HitCoords.y = EndCoords.y
		HitCoords.z = EndCoords.z
	else
		HitCoords.x = AdjustedX
		HitCoords.y = AdjustedY
		HitCoords.z = AdjustedZ
	end
	return HitCoords, memory.read_byte(DidHit) ~= 0, memory.read_int(HitEntity)
end

function RaycastCoordToCoord(Entity, PPos, AdjustedVect, Flags)
	local FlagBits = -1
	if Flags ~= nil then
		FlagBits = Flags
	end
	local HitCoords = v3.new()
	local DidHit = memory.alloc(1)
	local EndCoords = v3.new()
	local Normal = v3.new()
	local HitEntity = memory.alloc_int()
	
	local Handle = SHAPETEST.START_EXPENSIVE_SYNCHRONOUS_SHAPE_TEST_LOS_PROBE(
		PPos.x, PPos.y, PPos.z,
		AdjustedVect.x, AdjustedVect.y, AdjustedVect.z,
		FlagBits,
		Entity, 7
	)
	SHAPETEST.GET_SHAPE_TEST_RESULT(Handle, DidHit, EndCoords, Normal, HitEntity)
	if memory.read_byte(DidHit) ~= 0 then
		HitCoords.x = EndCoords.x
		HitCoords.y = EndCoords.y
		HitCoords.z = EndCoords.z
	else
		HitCoords.x = AdjustedVect.x
		HitCoords.y = AdjustedVect.y
		HitCoords.z = AdjustedVect.z
	end
	return HitCoords, memory.read_byte(DidHit) ~= 0, memory.read_int(HitEntity), Normal
end