
local sqlLink = dbConnect ( "sqlite", "carshop.db" )
local players = {}
local sells = {}

addEvent( 'BuyCar', true )
addEvent( 'sellMyCar', true )
addEvent( 'updateList', true )
addEvent( 'spawnMyCar', true )
addEvent( 'destroyMyCar', true )

function initShops()
	dbExec( sqlLink, -- AUTOINCREMENT
		[[CREATE TABLE IF NOT EXISTS cars (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		owner TEXT,
		modelid INTEGER,
		heal INTEGER,
		vehvariant TEXT,
		doorstate TEXT,
		wheels TEXT,
		panels TEXT,
		plate TEXT,
		color TEXT,
		headlight TEXT,
		upgrades TEXT );]]
	)
	local sellCarRoot = createElement( 'sellCarRoot' )
	setElementParent( sellCarRoot, ( source == this and source ) or getResourceDynamicElementRoot( exports['mapmanager']:getRunningGamemodeMap() ) )
	for _, sellcar in ipairs( getElementsByType( 'sellCar' ) ) do
		setElementParent( sellcar, sellCarRoot )
		spawnCarForSale( sellcar )
	end
	addEventHandler( 'onColShapeHit', sellCarRoot, showCostTrigger )
end
addEventHandler( 'onResourceStart', resourceRoot, initShops )
addEventHandler( 'onGamemodeMapStart', root, initShops )

function spawnCarForSale( sellcar )
	local x, y, z = getElementPosition( sellcar )
	local car = createVehicle( getElementData( sellcar, 'model' ), x, y, z + 1, getElementData( sellcar, 'rotX' ), getElementData( sellcar, 'rotY' ), getElementData( sellcar, 'rotZ' ) )
	setElementData( car, 'cost', tonumber( getElementData( sellcar, 'cost' ) ) )
	setElementParent( car, sellcar )
	local col = createColSphere( x, y, z, 10 )
	setElementParent( col, car )
	setVehicleDamageProof( car, true )
	setElementFrozen( car, true )
end

function showCostTrigger( player )
	if getElementType( player ) ~= 'player' then return; end
	triggerClientEvent( player, 'showCarCost', getElementParent( source ) )
end

function isPlayerAvtoLimit( player )
	local max = tonumber( get( 'buyCarLimit' ) )
	if not max then
		return true
	end
	if not players[player] then
		return max > 0
	else
		local n = 0
		for _ in pairs( players[player] ) do
			n = n + 1
		end
		return n <= max
	end
end

function buyCar( car )
	local acc = getPlayerAccount( source )

	if isGuestAccount( acc ) then
		outputChatBox( 'У вас нет аккаунта на сервере. Операция отменена', source )
		return false
	end
	
	if not isPlayerAvtoLimit( source ) then
		outputChatBox( 'Изчерпан лимит авто', source )
		return false
	end
	
	local sellcar = getElementParent( car )

	setTimer( spawnCarForSale, 10000, 1, sellcar )
	
	for i, element in pairs( getElementChildren( car ) ) do
		destroyElement( element )
	end
	setElementParent( car, getResourceDynamicElementRoot( resource ) )

	setElementFrozen( car, false )
	setVehicleDamageProof( car, false )
	
	takePlayerMoney( source, getElementData( car, 'cost' ) )
	acc = getAccountName( acc )
	
	local doors = {}
	for i = 1, 6 do
		doors[i] = getVehicleDoorState( car, i - 1 )
	end
	
	local panels = {}
	for i = 1, 7 do
		panels[i] = getVehiclePanelState( car, i - 1 )
	end
	
	dbQuery( function( queryHandle, player, car )
		local tResul, num, errOrID = dbPoll( queryHandle, 0 )
		if tResul then
			outputDebugString( 'Reselect ' .. errOrID )
			local id = errOrID
			players[player] = players[player] or {}
			players[player][id] = players[player][id] or {}
			players[player][id]['element'] = car
			players[player][id]['modelid'] = getElementModel( car )
			players[player][id]['heal'] = getElementHealth( car )
			setElementData( car, 'owner', getAccountName( getPlayerAccount( player ) ) )
			setElementData( car, 'cardbid', id )
			addEventHandler( 'onElementDestroy', car, dbCarSave )
			addEventHandler( 'onVehicleExplode', car, dbCarDelete )
			addEventHandler( 'onPlayerQuit', player, updateCarState )
		elseif tResul == nil then
				dbFree(queryHandle)
		elseif tResul == false then
				outputDebugString('Ошибка в запросе, код '..num..': '..errOrID)
		end
	end,
	{ source, car },
	sqlLink,
			[[INSERT INTO cars ( owner, modelid, heal, vehvariant, doorstate, wheels, panels, plate, color, headlight, upgrades )
			VALUES ( ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ? );]], -- SELECT last_insert_rowid();
			acc, getElementModel( car ), getElementHealth( car ), toJSON( { getVehicleVariant( car ) } ),
			toJSON( doors ), toJSON( { getVehicleWheelStates( car ) } ), toJSON( panels ), getVehiclePlateText( car ), toJSON( { getVehicleColor( car, true ) } ),
			toJSON( { getVehicleHeadLightColor( car ) } ), toJSON( getVehicleUpgrades( car ) )
				)
	triggerEvent( 'updateList', source )
		
end
addEventHandler( 'BuyCar', root, buyCar )

function dbCarSave( car )
	local car = source -- must update
	local acc = getElementData( car, 'owner' )
	local id = getElementData( car, 'cardbid' )

	local doors = {}
	for i = 1, 6 do
		doors[i] = getVehicleDoorState( car, i - 1 )
	end
	
	local panels = {}
	for i = 1, 7 do
		panels[i] = getVehiclePanelState( car, i - 1 )
	end
	
	outputDebugString( 'Update car state ' .. tostring( id ) )
	dbExec( sqlLink,
			[[UPDATE cars SET heal = ?, vehvariant = ?, doorstate = ?, wheels = ?, panels = ?, plate = ?, color = ?, headlight = ?, upgrades = ? WHERE id = ? ;]],
			getElementHealth( car ), toJSON( { getVehicleVariant( car ) } ),
			toJSON( doors ), toJSON( { getVehicleWheelStates( car ) } ), toJSON( panels ), getVehiclePlateText( car ), toJSON( { getVehicleColor( car, true ) } ),
			toJSON( { getVehicleHeadLightColor( car ) } ), toJSON( getVehicleUpgrades( car ) ), id
				)
				
	local player = getAccountPlayer( getAccount( acc ) )
	if player then
		triggerEvent( 'updateList', player )
	end
end

function dbCarDelete()
	local player = getElementData( source, 'owner' )
	local id = getElementData( source, 'cardbid' )
	outputDebugString( 'delete ' .. tostring( id ) )
	dbExec( sqlLink,
			[[DELETE FROM cars WHERE id=?]],
			id
		)
	player = getAccountPlayer( getAccount( player ) )
	if player and players[player] and players[player][id] then
		players[player][id] = nil
		triggerEvent( 'updateList', player )
	end
end

function fastRand( to, count )
	local rand = {}
	for i = 1, count do
		rand[i] = math.random( 0, to )
	end
	return rand
end

function updatelist()
		dbQuery (
		function ( queryHandle, tPlayer )
				
				local resultTable, num, err = dbPoll( queryHandle, 0 )
				if resultTable then
					players[tPlayer] = players[tPlayer] or {}
					for i = 1, #resultTable do
						local id = resultTable[i]['id']
						outputDebugString( 'In update ' .. id )
						resultTable[i]['id'] = nil -- лишнее убрали
--						if not players[tPlayer][id] then
							-- ставим новые данные для несуществующих авто
							local element = players[tPlayer][id] and players[tPlayer][id]['element'] or nil
							players[tPlayer][id] = resultTable[i]
							players[tPlayer][id]['element'] = element
--						end
					end
					if tPlayer then
						triggerClientEvent( tPlayer, 'updateClientList', root, players[tPlayer] )
					end
				elseif resultTable == nil then
						dbFree(queryHandle)
				elseif resultTable == false then
						outputDebugString('Ошибка в запросе, код '..num..': '..err)
				end
		end,
	{ source },
		sqlLink, 
 
		"SELECT * FROM cars WHERE owner = ? ;",
	getAccountName( getPlayerAccount( source ) )
	)
end
addEventHandler( 'updateList', root, updatelist )

function spawnCar( id )

	if not players[source][id] then
		outputChatBox( 'Эпическая ошибка', source )
		return;
	end

	if isElement( players[source][id]['element'] ) then
		outputChatBox( 'Чувак, я не знаю, где твоя машина', source )
		return;
	end
	
	local x, y, z = getElementPosition( source )
	local car = createVehicle ( players[source][id]['modelid'], x + 2, y + 1, z +1, 0, 0, 0, players[source][id]['plate'], false, unpack( fromJSON( players[source][id]['vehvariant'] ) or {} ) )
	setElementHealth( car, players[source][id]['heal'] )
	-- Костыль: состояние дверей, панелей не применяются корректно сразу после спавна
	setTimer( function( source, id )
		local doors = fromJSON( players[source][id]['doorstate'] )
	
		for i=1, 6 do
			setVehicleDoorState( players[source][id]['element'], i - 1, doors[i] )
		end

		local panels = fromJSON( players[source][id]['panels'] )
	
		for i=1, 7 do
			setVehiclePanelState( players[source][id]['element'], i - 1, panels[i] )
		end
	end, 500, 1, source, id )
	
	setVehicleWheelStates( car, unpack( fromJSON( players[source][id]['wheels'] ) ) )
	setVehicleColor( car, unpack( fromJSON( players[source][id]['color'] ) ) )
	
	local upgrades = fromJSON( players[source][id]['upgrades'] )
	
	for i, upgrade in ipairs ( upgrades ) do
		addVehicleUpgrade( car, upgrade )
	end
	
	players[source][id]['element'] = car
	setElementData( car, 'owner', getAccountName( getPlayerAccount( source ) ) )
	setElementData( car, 'cardbid', id )
	
	addEventHandler( 'onElementDestroy', car, dbCarSave )
	addEventHandler( 'onVehicleExplode', car, dbCarDelete )
	addEventHandler( 'onPlayerQuit', source, updateCarState )
end
addEventHandler( 'spawnMyCar', root, spawnCar )

function updateCarState()
	if not players[source] then return; end
	for id, data in pairs(	players[source] ) do
		if isElement( players[source][id]['element'] ) and not isElementInWater( players[source][id]['element'] ) then
			destroyElement( players[source][id]['element'] )
		end
	end
	players[source] = nil
end

function updateWhenPlayerLogin()
	triggerEvent( 'updateList', source )
end
addEventHandler( 'onPlayerLogin', root, updateWhenPlayerLogin )

function destroyMyCar( id )
	local car = players[source][id]['element']
	if not isElement( car ) then
		outputChatBox( 'Авто нет, операция отменена.', source )
		return;
	end
	
	outputChatBox( 'Операция будет выполнена через 10 сек. ', source )
	setElementAlpha( car, 125 )
	
	setTimer( function( source, id, car )
		if isElement( car ) then
			destroyElement( car )
			players[source][id]['element'] = nil
		end
	end, 10000, 1, source, id, car )

end
addEventHandler( 'destroyMyCar', root, destroyMyCar )

function sellCar( newOwnerPlayer )
	if not sells[newOwnerPlayer] then return false end
	local source, id = sells[newOwnerPlayer].source, sells[newOwnerPlayer].id
	local ownerAccName = getAccountName( getPlayerAccount( source ) )
	local newOwnerAcc = getPlayerAccount( newOwnerPlayer )
	
	killTimer( sells[newOwnerPlayer].timer )
	
	if not players[source][id] then
		outputChatBox( 'Пока Вы думали, авто просрали. :(', newOwnerPlayer )
		return false
	end
		
	players[newOwnerPlayer][id] = players[source][id]
	players[source][id] = nil
	
	local newOwnerAccName = getAccountName( newOwnerAcc )
	newOwnerAcc = nil
	
	dbExec( sqlLink,
			[[UPDATE cars SET owner = ? WHERE id=?]],
			newOwnerAccName, id
				)
				
	triggerEvent( 'updateList', source )
	triggerEvent( 'updateList', newOwnerPlayer )
	
	takePlayerMoney( newOwnerPlayer, sells[newOwnerPlayer].money )
	givePlayerMoney( sells[newOwnerPlayer].source, sells[newOwnerPlayer].money )
	
	outputChatBox( 'Вы успешно купили ' .. sells[newOwnerPlayer].name .. '.', newOwnerPlayer )
	outputChatBox( getPlayerName( newOwnerPlayer ) ..	' подтвердил сделку.', source )
	
	sells[newOwnerPlayer] = nil
end

function cancelSell( newOwnerPlayer )
	killTimer( sells[newOwnerPlayer].timer )
	outputChatBox( getPlayerName( newOwnerPlayer ) ..	' отменил сделку.', sells[newOwnerPlayer].source )
	sells[newOwnerPlayer] = nil
	unbindKey( newOwnerPlayer, 'y', 'down', sellCar )
	unbindKey( newOwnerPlayer, 'n', 'down', cancelSell )
end

function sell( id, name, money, newOwnerPlayer )
	
	local newOwnerAcc = getPlayerAccount( newOwnerPlayer )
	
	if isGuestAccount( newOwnerAcc ) then
		outputChatBox( 'Игрок, которому вы хотить продать авто, не зарегистрирован на сервере. Операция отменена.', source )
		return false
	end
	
	 if not isPlayerAvtoLimit( source ) then
		outputChatBox( 'У целевого игрока изчерпан лимит авто', source )
		return false
	end
	
	if getPlayerMoney( newOwnerPlayer ) < money then
		outputChatBox( 'У игрока нет средств на покупку.', source )
		return false
	end
	
	if sells[newOwnerPlayer] and sells[newOwnerPlayer].id then
		outputChatBox( 'Подождите, пока получатель подтвердит сделку.', source )
		return false
	end
	
	sells[newOwnerPlayer] = { id = id, name = name, money =	money, source = source }
	
	outputChatBox( getPlayerName( source ) .. ' предлагает вам купить авто ' .. name .. ' за ' .. money .. '$.' , newOwnerPlayer )
	outputChatBox( 'Нажмите \"y\" для принятия сделки или \"n\" для отмены.', newOwnerPlayer )
	
	bindKey( newOwnerPlayer, 'y', 'down', sellCar )
	bindKey( newOwnerPlayer, 'n', 'down', cancelSell )
		
	sells[newOwnerPlayer].timer = setTimer( function( newOwnerPlayer )
		if not sells[newOwnerPlayer] then
			return
		end
		outputChatBox( getPlayerName( newOwnerPlayer ) ..	': истекло время ожидания, операция отменена.', sells[newOwnerPlayer].source )
		unbindKey( newOwnerPlayer, 'y', 'down', sellCar )
		unbindKey( newOwnerPlayer, 'n', 'down', cancelSell )
		sells[newOwnerPlayer] = nil;
		end, 30000, 1, newOwnerPlayer )
	end
addEventHandler( 'sellMyCar', root, sell )

