util.require_natives(1676318796)

Print = util.toast
Wait = util.yield
joaat = util.joaat

local FileNameForSave = "StoredPath.txt"
local PathDirSaveds = filesystem.scripts_dir().."Paths\\"
local LoadedFileName = FileNameForSave

local FileListPTR = nil

local FileListOptions = {}
local FileList = {}
function SetFilesList()
	--Copied from Constructor
	for i = 1, #FileList do
		table.remove(FileList, #FileList)
	end
	for i = 1, #FileListOptions do
		table.remove(FileListOptions, #FileListOptions)
	end
	for _, filepath in ipairs(filesystem.list_files(PathDirSaveds)) do
        if not filesystem.is_dir(filepath) then
            local _, filename, ext = string.match(filepath, "(.-)([^\\/]-%.?)[.]([^%.\\/]*)$")
			if ext == "txt" then
				local PathsFile = {
					FilePath=filepath,
					FileName=filename,
					Name=filename..ext
				}
				table.insert(FileListOptions, filename.."."..ext)
				table.insert(FileList, PathsFile)
			end
		end
	end
end
SetFilesList()

FileListPTR = menu.list_select(menu.my_root(), "Load Recorded Path File", {"loadrecordedpath"}, "To start the replay.", FileListOptions, 1, function(OnChange) 
	LoadedFileName = FileListOptions[OnChange]
	SetFilesList()
	menu.set_list_action_options(FileListPTR, FileListOptions)
end)
LoadedFileName = FileListOptions[1]

menu.text_input(menu.my_root(), "Set File Name", {"setfilename"}, "Set file name for saving.", function(OnChange) 
	FileNameForSave = OnChange
	SetFilesList()
	menu.set_list_action_options(FileListPTR, FileListOptions)
end, FileNameForSave)

local AiHateRel = "rgFM_AiHate"
local AiLikeRel = "rgFM_AiLike"
local AiLikeHateAiHateRel = "rgFM_AiLike_HateAiHate"
local AiHateAiHateRel = "rgFM_HateAiHate"
local AiHateEveryone = "rgFM_HateEveryOne"

local RecordT = {}

local StartRecord = false
menu.toggle(menu.my_root(), "Start Recording", {}, "", function(toggle)
	StartRecord = toggle
	SetFilesList()
	menu.set_list_action_options(FileListPTR, FileListOptions)
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

local Model = "sanchez"
menu.text_input(menu.my_root(), "Set Veh Model", {"setvehmodel"}, "Vehicle model will be created to perform the replay.", function(OnChange)
	if STREAMING.IS_MODEL_VALID(joaat(OnChange)) then
		Model = OnChange
	end
	SetFilesList()
	menu.set_list_action_options(FileListPTR, FileListOptions)
end)

local StartReplay = false
menu.toggle(menu.my_root(), "Start Selected Replay", {}, "", function(toggle)
	StartReplay = toggle
	SetFilesList()
	menu.set_list_action_options(FileListPTR, FileListOptions)
	if StartReplay then
		local Paths = GetVectorsTable(PathDirSaveds..LoadedFileName)
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
					x = (TPos.x - OPos.x) * 10.0,
					y = (TPos.y - OPos.y) * 10.0,
					z = (TPos.z - OPos.z) * 10.0
				}
				local Rot = {x = Paths[Index].RotX, y = Paths[Index].RotY, z = Paths[Index].RotZ}
				
				RotateEntityToTargetRotation(Veh, Rot, 20.0)
				ENTITY.SET_ENTITY_VELOCITY(Veh, NewV3.x, NewV3.y, NewV3.z)
				
				local Calc = NETWORK.GET_TIME_DIFFERENCE(NETWORK.GET_NETWORK_TIME_ACCURATE(), NetworkTime) --Global_NetworkTime - IndexT.TimerMilis
        		Calc = math.max(math.floor(Calc / 10), 1)
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
	SetFilesList()
	menu.set_list_action_options(FileListPTR, FileListOptions)
	if StartReplayCurVeh then
		local Paths = GetVectorsTable(PathDirSaveds..LoadedFileName)
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
						
						RotateEntityToTargetRotation(Veh, Rot, 20.0)
						ENTITY.SET_ENTITY_VELOCITY(Veh, NewV3.x, NewV3.y, NewV3.z)
						
						local Calc = NETWORK.GET_TIME_DIFFERENCE(NETWORK.GET_NETWORK_TIME_ACCURATE(), NetworkTime) --Global_NetworkTime - IndexT.TimerMilis
						Calc = math.max(math.floor(Calc / 10), 1)
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
	SetFilesList()
	menu.set_list_action_options(FileListPTR, FileListOptions)
	if ReplayFromOffset then
		local Paths = GetVectorsTable(PathDirSaveds..LoadedFileName)
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
						RotateEntityToTargetRotation(Veh, Rot, 20.0)
						ENTITY.SET_ENTITY_VELOCITY(Veh, NewV3.x, NewV3.y, NewV3.z)
						
						local Calc = NETWORK.GET_TIME_DIFFERENCE(NETWORK.GET_NETWORK_TIME_ACCURATE(), NetworkTime)
						Calc = math.max(math.floor(Calc / 10), 1)
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
