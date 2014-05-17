local customCarNames = {
	[400] = 'Трататат';
	[442] = 'корыто';
	}

local sellCarRoot = getElementsByType( 'sellCarRoot' )[1]

local myCars = {}
local carsCost = {}
local renderState = false

addEvent( 'updateClientList', true )
addEvent( 'showCarCost', true )

function intiCarShops()
  triggerServerEvent( 'updateList', localPlayer )
end
addEventHandler( 'onClientResourceStart', resourceRoot, intiCarShops )

addEventHandler( 'showCarCost', root, function()
  carsCost[source] = getElementData( source, 'cost' )
  if not renderState then
    renderState = true
    addEventHandler( 'onClientRender', root, renderCarCost )
  end
end )

addEventHandler( 'onClientVehicleEnter', sellCarRoot, function( player )
  if player ~= localPlayer then return; end
  outputChatBox( 'Вы можете купить это авто за '.. getElementData( source, 'cost' ) .. '$. Нажмите "b" для этого' )
  bindKey( 'b', 'down', buyCar, source )
end )

addEventHandler( 'onClientVehicleExit', sellCarRoot, function( player )
  if player ~= localPlayer then return; end
  unbindKey( 'b', 'down', buyCar )
end )

function renderCarCost()
  local x, y, z = getElementPosition( localPlayer )
  renderState = false
  for car, cost in pairs( carsCost ) do
    local vX, vY, vZ = getElementPosition( car )
    local sX, sY = getScreenFromWorldPosition( vX, vY, vZ + 1, 0, false )
    local dis = getDistanceBetweenPoints3D( x, y, z, vX, vY, vZ )
    if sX and dis < 11 then
      dxDrawText( tostring( cost ), sX, sY, 30, 10, nil, 3, 'arial' )
    elseif dis > 11 then
      carsCost[car] = nil
    end
    renderState = true
  end
  if not renderState then
    removeEventHandler( 'onClientRender', root, renderCarCost )
  end
end

function buyCar( _, _, car )
  local money = tonumber( getElementData( car, 'cost' ) )
  if not money then return false end
  if money <= getPlayerMoney( localPlayer ) then
    triggerServerEvent( 'BuyCar', localPlayer, car )
    carsCost[car] = nil
    unbindKey( 'b', 'down', buyCar )
  else
    outputChatBox( 'У Вас нет денег на покупку.' )
  end
end

function outputCarList()
  if w_mycars then
    destroyElement( w_mycars )
    showCursor( false )
    w_mycars = nil
    
    if sellWindow then
      destroyElement( sellWindow )
      sellWindow = nil
    end
    
  else
    w_mycars = guiCreateWindow(500,200,290,440,"Cars",false)
    myCarGridList = guiCreateGridList(0.05, 0.2, 0.875, 0.65,true,w_mycars)
    guiGridListAddColumn(myCarGridList,"Car",0.7)
    guiGridListAddColumn(myCarGridList,"HP",0.2)
    updateMyCarList()
    showCursor( true )
    local spawnButton   = guiCreateButton( 0.05, 0.075, 0.9, 0.1,"Спавн!",true,w_mycars )
    local sellButton    = guiCreateButton( 0.05, 0.85, 0.45, 0.1, "Продать", true, w_mycars )
    local destroyButton = guiCreateButton( 0.5, 0.85,0.31,0.1,"В гараж",true,w_mycars )
    local closeButton   = guiCreateButton( 0.85,0.85,0.09,0.1,"x",true,w_mycars )
    
    addEventHandler( 'onClientGUIClick', spawnButton,   spawnCar,      false )
    addEventHandler( 'onClientGUIClick', sellButton,    sellGUI,       false )
    addEventHandler( 'onClientGUIClick', destroyButton, destroyMyCar,  false )
    addEventHandler( 'onClientGUIClick', closeButton,   outputCarList, false )
  end 
end
bindKey( 'f3', 'down', outputCarList )

function updateMyCarList( newCarList )
  myCars = newCarList or myCars
  if not isElement( myCarGridList ) then return; end
  guiGridListClear( myCarGridList )
  for id, data in pairs ( myCars ) do
    local carname = customCarNames[ data['modelid'] ] or getVehicleNameFromModel ( data['modelid'] )
--[[    
    for i, carshopdata in ipairs ( cars ) do
      if carshopdata[1] == data['modelid'] then
        if carshopdata[3] then
          carname = carshopdata[3]
        end
      break
     end
   end
 --]]  
   local row = guiGridListAddRow (myCarGridList)
   guiGridListSetItemText ( myCarGridList, row, 1, carname, false, true)
   guiGridListSetItemText ( myCarGridList, row, 2, data['heal'], false, true)
   guiGridListSetItemData ( myCarGridList, row, 1, id )
  end
end
addEventHandler( 'updateClientList', localPlayer, updateMyCarList )

function spawnCar()
  local carId = guiGridListGetItemData( myCarGridList, guiGridListGetSelectedItem (myCarGridList), 1 )
  if carId then
    triggerServerEvent( 'spawnMyCar', localPlayer, carId )
  else
    outputChatBox( 'Вы не выбрали авто.' )
  end
end

function sellGUI()
  local vehicleName = guiGridListGetItemText( myCarGridList, guiGridListGetSelectedItem (myCarGridList), 1 )

  if vehicleName == ''  then
    outputChatBox( 'Вы не выбрали авто для продажи.' )
    return false
  end
  
  sellWindow = guiCreateWindow( 500, 400, 290, 150, 'Продажа авто \"' .. vehicleName .. '\" ', false )
  
  selectPlayerBox = guiCreateComboBox( 0.05, 0.15, 0.9, 1, 'Игроки', true, sellWindow )
  for i, player in ipairs( getElementsByType( 'player' ) ) do
    guiComboBoxAddItem( selectPlayerBox, getPlayerName( player ) )
  end
  
  moneyEdit = guiCreateEdit( 0.05, 0.35, 0.7, 0.2, 5000, true, sellWindow )
  
  addEventHandler("onClientGUIChanged", moneyEdit, function( ) 
   guiSetText( moneyEdit, string.gsub( guiGetText( moneyEdit ), '%D', '' ) )
  end )
  
  local acceptButton = guiCreateButton( 0.05, 0.65, 0.6, 0.3, 'Предложить', true, sellWindow )
  local closeButton  = guiCreateButton( 0.7, 0.65, 0.25, 0.3, 'Отмена', true, sellWindow )
  
  addEventHandler( 'onClientGUIClick', acceptButton, sellMyCar,      false )
  addEventHandler( 'onClientGUIClick', closeButton,  killSellGUI,    false )
  
end

function killSellGUI()
  destroyElement( sellWindow )
  sellWindow = nil
end

function sellMyCar()
  local player      = getPlayerFromName( guiComboBoxGetItemText( selectPlayerBox, guiComboBoxGetSelected( selectPlayerBox ) ) )
  local money       = tonumber( guiGetText( moneyEdit ) )
  local id          = guiGridListGetItemData( myCarGridList, guiGridListGetSelectedItem (myCarGridList), 1 )
  local vehicleName = guiGridListGetItemText( myCarGridList, guiGridListGetSelectedItem (myCarGridList), 1 )
  
  if id and isElement( player ) and money and vehicleName then
    triggerServerEvent( 'sellMyCar', localPlayer, id, vehicleName, money, player )
  else
    outputChatBox( 'Ошибка... :(' )
  end
  
  killSellGUI()
end

function destroyMyCar()
  local carId = guiGridListGetItemData( myCarGridList, guiGridListGetSelectedItem (myCarGridList), 1 )
  if carId then
    triggerServerEvent( 'destroyMyCar', localPlayer, carId )
  else
    outputChatBox( 'Вы не выбрали авто' )
  end  
end

