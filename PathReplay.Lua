util.require_natives(1676318796)

Print = util.toast
Wait = util.yield
joaat = util.joaat

local FileNameForSave = "StoredPath.txt"
local PathDirSaveds = filesystem.scripts_dir().."Paths\\"
local LoadedFileName = FileNameForSave

filesystem.mkdirs(filesystem.scripts_dir().."Paths")

local GlobalSpd = 20

local InterpolationFactor = 10.0

local FileListPTRs = {}

local FileListNoFolder = {}
local FileListOptions = {}
local FileList = {}

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

local FileSelectMenu = menu.list(menu.my_root(), "Load Replay File", {"loadreplayfilemenu"}, "Just click one time to load.", function() CreateMenuItemsForFileList() end
, function ()
	CreateMenuItemsForFileList()
end)

function CreateMenuItemsForFileList()
	FileList = SetFilesList(PathDirSaveds, "")
	FileListOptions = {}
	for k = 1, #FileListPTRs do
		menu.delete(FileListPTRs[#FileListPTRs].PTR)
		table.remove(FileListPTRs, #FileListPTRs)
	end
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
			FileListPTRs[#FileListPTRs+1] = {PTR = menu.action(PTR, FileListOptions[k].Contents[i].FileName, {}, "", function(toggle) LoadedFileName = FileListOptions[k].Contents[i].FilePath end)}
		end
	end
	for k = 1, #FileListNoFolder do
		FileListPTRs[#FileListPTRs+1] = {PTR = menu.action(FileSelectMenu, FileListNoFolder[k].FileName, {}, "", function(toggle) LoadedFileName = FileListNoFolder[k].FilePath end)}
	end
end

menu.text_input(menu.my_root(), "Set File Name", {"setfilename"}, "Set file name for saving.", function(OnChange) 
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
menu.toggle(menu.my_root(), "Start Recording", {}, "", function(toggle)
	StartRecord = toggle
	if StartRecord then
		while StartRecord do
			local PlayerPed = PLAYER.PLAYER_PED_ID()
			local Veh = PED.GET_VEHICLE_PED_IS_IN(PlayerPed, true)
			if Veh ~= 0 then
				local Pos = ENTITY.GET_ENTITY_COORDS(Veh)
				local Rot = ENTITY.GET_ENTITY_ROTATION(Veh, 5)
				RecordT[#RecordT+1] = ToTxt(Pos, Rot)
				if #RecordT >= 1000 then
					local BigText = ""
					for i = 1, #RecordT do
						BigText = BigText..RecordT[i]
					end
					for i = 1, #RecordT do
						table.remove(RecordT, #RecordT)
					end
					WriteFile(PathDirSaveds..FileNameForSave, BigText)
				end
			end
			Wait()
		end
	else
		local BigText = ""
		for i = 1, #RecordT do
			BigText = BigText..RecordT[i]
		end
		for i = 1, #RecordT do
			table.remove(RecordT, #RecordT)
		end
		WriteFile(PathDirSaveds..FileNameForSave, BigText)
	end
end)

local Model = "elegy"
menu.text_input(menu.my_root(), "Set Veh Model", {"setvehmodel"}, "Vehicle model will be created to perform the replay.", function(OnChange)
	if STREAMING.IS_MODEL_VALID(joaat(OnChange)) then
		Model = OnChange
	end
end)

local StartReplay = false
menu.toggle(menu.my_root(), "Start Selected Replay", {}, "", function(toggle)
	StartReplay = toggle
	if StartReplay then
		local Paths = GetVectorsTable(LoadedFileName)
		local Index = 0
		STREAMING.REQUEST_MODEL(joaat(Model))
		while not STREAMING.HAS_MODEL_LOADED(joaat(Model)) do
			Wait()
		end
		local PlayerPed = PLAYER.PLAYER_PED_ID()
		--local Pos = ENTITY.GET_ENTITY_COORDS(PlayerPed)
		local Veh = VEHICLE.CREATE_VEHICLE(joaat(Model), Paths[1].x, Paths[1].y, Paths[1].z, Paths[1].RotZ, true, true, false)
		--PED.SET_PED_INTO_VEHICLE(PlayerPed, Veh, -1)
		--ENTITY.SET_ENTITY_COORDS(PlayerPed, Paths[1].x, Paths[1].y, Paths[1].z + 2.0)
		ENTITY.SET_ENTITY_AS_MISSION_ENTITY(Veh, false, true)
		STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(joaat(Model))
		entities.set_can_migrate(Veh, false)
		ENTITY.SET_ENTITY_INVINCIBLE(Veh, true)
		NETWORK.NETWORK_SET_ENTITY_CAN_BLEND(Veh, true)
		local Mul = 0.3
		--VEHICLE.SET_DOOR_ALLOWED_TO_BE_BROKEN_OFF(Veh, 2, false)
		--VEHICLE.SET_VEHICLE_DOOR_OPEN(Veh, 2, false, true)
		--Wait()
		local NetworkTime = NETWORK.GET_NETWORK_TIME_ACCURATE()
		while StartReplay do
			--VEHICLE.SET_VEHICLE_DOOR_CONTROL(Veh, 2, 360, 360.0)
			if Index == 0 then
				Index = Index + 1
				ENTITY.SET_ENTITY_COORDS(Veh, Paths[1].x, Paths[1].y, Paths[1].z)
				ENTITY.SET_ENTITY_ROTATION(Veh, Paths[1].RotX, Paths[1].RotY, Paths[1].RotZ)
			end
			if Index <= #Paths then
				local TPos = {x = Paths[Index].x, y = Paths[Index].y, z = Paths[Index].z}
				local OPos = ENTITY.GET_ENTITY_COORDS(Veh)
				local NewV3 = {
					x = (TPos.x - OPos.x) * 1.0,
					y = (TPos.y - OPos.y) * 1.0,
					z = (TPos.z - OPos.z) * 1.0
				}
				local Rot = {x = Paths[Index].RotX, y = Paths[Index].RotY, z = Paths[Index].RotZ}
				
				RotateEntityToTargetRotation(Veh, Rot, InterpolationFactor)
				ENTITY.SET_ENTITY_VELOCITY(Veh, NewV3.x, NewV3.y, NewV3.z)
				
				local Calc = NETWORK.GET_TIME_DIFFERENCE(NETWORK.GET_NETWORK_TIME_ACCURATE(), NetworkTime) --Global_NetworkTime - IndexT.TimerMilis
        		Calc = math.max(math.floor(Calc / GlobalSpd), 1)
				Index = Calc
				if Index > #Paths then
					Index = 0
					NetworkTime = NETWORK.GET_NETWORK_TIME_ACCURATE()
				end
			else
				Index = 0
			end
			Wait()
		end
		entities.delete_by_handle(Veh)
	end
end)

local StartReplayCurVeh = false
menu.toggle(menu.my_root(), "Replay From Cur Veh", {}, "", function(toggle)
	StartReplayCurVeh = toggle
	if StartReplayCurVeh then
		local Paths = GetVectorsTable(LoadedFileName)
		local Index = 0
		local PlayerPed = PLAYER.PLAYER_PED_ID()
		local Veh = PED.GET_VEHICLE_PED_IS_IN(PlayerPed, true)
		local NetworkTime = NETWORK.GET_NETWORK_TIME_ACCURATE()
		while StartReplayCurVeh do
			if Veh ~= 0 then
				if ENTITY.DOES_ENTITY_EXIST(Veh) then
					if Index == 0 then
						Index = Index + 1
						ENTITY.SET_ENTITY_COORDS(Veh, Paths[1].x, Paths[1].y, Paths[1].z)
						ENTITY.SET_ENTITY_ROTATION(Veh, Paths[1].RotX, Paths[1].RotY, Paths[1].RotZ)
					end
					if Index <= #Paths then
						local TPos = {x = Paths[Index].x, y = Paths[Index].y, z = Paths[Index].z}
						local OPos = ENTITY.GET_ENTITY_COORDS(Veh)
						local NewV3 = {
							x = (TPos.x - OPos.x) * 10.0,
							y = (TPos.y - OPos.y) * 10.0,
							z = (TPos.z - OPos.z) * 10.0
						}
						local Rot = {x = Paths[Index].RotX, y = Paths[Index].RotY, z = Paths[Index].RotZ}
						
						RotateEntityToTargetRotation(Veh, Rot, InterpolationFactor)
						ENTITY.SET_ENTITY_VELOCITY(Veh, NewV3.x, NewV3.y, NewV3.z)
						
						local Calc = NETWORK.GET_TIME_DIFFERENCE(NETWORK.GET_NETWORK_TIME_ACCURATE(), NetworkTime) --Global_NetworkTime - IndexT.TimerMilis
						Calc = math.max(math.floor(Calc / GlobalSpd), 1)
						Index = Calc
						if Index > #Paths then
							break
						end
					else
						break
					end
				else
					break
				end
			else
				break
			end
			Wait()
		end
	end
end)

local ReplayFromOffset = false
menu.toggle(menu.my_root(), "Replay From Offset For Cur Veh", {}, "", function(toggle)
	ReplayFromOffset = toggle
	if ReplayFromOffset then
		local Paths = GetVectorsTable(LoadedFileName)
		local Index = 0
		local PlayerPed = PLAYER.PLAYER_PED_ID()
		local Offset = ENTITY.GET_ENTITY_COORDS(PlayerPed)
		local StartPath = {x = Paths[1].x, y = Paths[1].y, z = Paths[1].z}
		local NetworkTime = NETWORK.GET_NETWORK_TIME_ACCURATE()
		local Veh = PED.GET_VEHICLE_PED_IS_IN(PlayerPed, false)
		while ReplayFromOffset do
			if Veh ~= 0 then
				if ENTITY.DOES_ENTITY_EXIST(Veh) then
					if Index == 0 then
						Index = Index + 1
						ENTITY.SET_ENTITY_ROTATION(Veh, Paths[1].RotX, Paths[1].RotY, Paths[1].RotZ)
					end
					if Index <= #Paths then
						local TPos = {x = Paths[Index].x, y = Paths[Index].y, z = Paths[Index].z}
						local OPos = ENTITY.GET_ENTITY_COORDS(Veh)
						local NewV3 = {
							x = (((Offset.x + (TPos.x - StartPath.x))) - OPos.x) * 10.0,
							y = (((Offset.y + (TPos.y - StartPath.y))) - OPos.y) * 10.0,
							z = (((Offset.z + (TPos.z - StartPath.z))) - OPos.z) * 10.0
						}
						local Rot = {x = Paths[Index].RotX, y = Paths[Index].RotY, z = Paths[Index].RotZ}
						RotateEntityToTargetRotation(Veh, Rot, InterpolationFactor)
						ENTITY.SET_ENTITY_VELOCITY(Veh, NewV3.x, NewV3.y, NewV3.z)
						
						local Calc = NETWORK.GET_TIME_DIFFERENCE(NETWORK.GET_NETWORK_TIME_ACCURATE(), NetworkTime)
						Calc = math.max(math.floor(Calc / GlobalSpd), 1)
						Index = Calc
						if Index > #Paths then
							break
						end
					end
				else
					break
				end
			else
				break
			end
			Wait()
		end
	end
end)

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
		VectorTable[#VectorTable+1] = {x = Number[1], y = Number[2], z = Number[3], RotX = Number[4], RotY = Number[5], RotZ = Number[6]}
	end
	return VectorTable
end

function ToTxt(Pos, Rot)
	return string.format("%0.3f", Pos.x).." "..string.format("%0.3f", Pos.y).." "..string.format("%0.3f", Pos.z)..
	" "..string.format("%0.3f", Rot.x).." "..string.format("%0.3f", Rot.y).." "..string.format("%0.3f", Rot.z).."\n"
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
			for k = 1, #PlayersT do
				if NETWORK.NETWORK_IS_PLAYER_ACTIVE(PlayersT[k].PlayerID) then
					local PlayerPed = PLAYER.GET_PLAYER_PED_SCRIPT_INDEX(PlayersT[k].PlayerID)
					local Veh = PED.GET_VEHICLE_PED_IS_IN(PlayerPed, true)
					if Veh ~= 0 then
						local Pos = ENTITY.GET_ENTITY_COORDS(Veh)
						local Rot = ENTITY.GET_ENTITY_ROTATION(Veh, 5)
						PlayersT[k].Records[#PlayersT[k].Records+1] = ToTxt(Pos, Rot)
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

local MultiplayerModel = "elegy"
menu.text_input(MultiplayerRecording, "Set Veh Model", {"setmpvehmodel"}, "Vehicle model will be created to perform the replay.", function(OnChange)
	if STREAMING.IS_MODEL_VALID(joaat(OnChange)) then
		MultiplayerModel = OnChange
	end
end)

local StartMultiplayerReplay = false
menu.toggle(MultiplayerRecording, "Start Selected Multiplayer Replay", {}, "", function(toggle)
	StartMultiplayerReplay = toggle
	if StartMultiplayerReplay then
		local Paths = {}
		for k = 1, #LoadedFolderContents do
			local Paths_ = GetVectorsTable(LoadedFolderContents[k].FilePath)
			Paths[#Paths+1] = Paths_
		end
		local Vehs = {}
		RequestModel(joaat(MultiplayerModel))
		for k = 1, #Paths do
			local Veh = VEHICLE.CREATE_VEHICLE(joaat(MultiplayerModel), Paths[k][1].x, Paths[k][1].y, Paths[k][1].z, Paths[k][1].RotZ, true, true, false)
			ENTITY.SET_ENTITY_AS_MISSION_ENTITY(Veh, false, true)
			entities.set_can_migrate(Veh, false)
			ENTITY.SET_ENTITY_INVINCIBLE(Veh, true)
			NETWORK.NETWORK_SET_ENTITY_CAN_BLEND(Veh, true)
			Vehs[#Vehs+1] = {Handle = Veh, PathsTable = Paths[k]}
		end
		STREAMING.SET_MODEL_AS_NO_LONGER_NEEDED(joaat(MultiplayerModel))
		local NetworkTime = NETWORK.GET_NETWORK_TIME_ACCURATE()
		while StartMultiplayerReplay do
			for k = 1, #Vehs do
				if ENTITY.DOES_ENTITY_EXIST(Vehs[k].Handle) then
					local Calc = NETWORK.GET_TIME_DIFFERENCE(NETWORK.GET_NETWORK_TIME_ACCURATE(), NetworkTime)
					Calc = math.max(math.floor(Calc / GlobalSpd), 1)
					local Index = Calc
					if Index <= #Vehs[k].PathsTable then
						local TPos = {x = Vehs[k].PathsTable[Index].x, y = Vehs[k].PathsTable[Index].y, z = Vehs[k].PathsTable[Index].z}
						local OPos = ENTITY.GET_ENTITY_COORDS(Vehs[k].Handle)
						local NewV3 = {
							x = (TPos.x - OPos.x) * 10.0,
							y = (TPos.y - OPos.y) * 10.0,
							z = (TPos.z - OPos.z) * 10.0
						}
						local Rot = {x = Vehs[k].PathsTable[Index].RotX, y = Vehs[k].PathsTable[Index].RotY, z = Vehs[k].PathsTable[Index].RotZ}
						
						RotateEntityToTargetRotation(Vehs[k].Handle, Rot, InterpolationFactor)
						ENTITY.SET_ENTITY_VELOCITY(Vehs[k].Handle, NewV3.x, NewV3.y, NewV3.z)
					end
				end
			end
			Wait()
		end
		for k = 1, #Vehs do
			if ENTITY.DOES_ENTITY_EXIST(Vehs[k].Handle) then
				entities.delete_by_handle(Vehs[k].Handle)
			end
		end
	end
end)