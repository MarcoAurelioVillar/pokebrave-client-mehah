local MainWindow, BuyPanel, SellPanel
local Current = {}
Market = {}
Market.opcode = 96
Market.time = {
  {value = 60 * 60 * 4, name = "4 horas"},
  {value = 60 * 60 * 8, name = "8 horas"},
  {value = 60 * 60 * 12, name = "12 horas"},
  {value = 60 * 60 * 24, name = "24 horas"},
}
Market.category = {
  all = 1,
  consumables = 2,
}
Market.order = {
  timedesc = 1,
  timeasc = 2,
  itemdesc = 3,
  itemasc = 4,
  namedesc = 3,
  nameasc = 4,
  sellerdesc = 5,
  sellerasc = 6,
  amountdesc = 7,
  amountasc = 8,
  pricedesc = 9,
  priceasc = 10,
}

local function onGameStart()
  if not MainWindow then return end
  MainWindow:hide()
end

local function onGameEnd()
  if not MainWindow then return end
  MainWindow:hide()
end

local function connecting(gameEvent)
  -- TODO: Just connect when you will be using
  if gameEvent then
  	connect(g_game, {
  	  onGameEnd = onGameEnd,
  	  onGameStart = onGameStart
  	})
	connect(LocalPlayer, {
		onPositionChange = onPositionChange
	})
  end

  -- register opcode
  return true
end

local function disconnecting(gameEvent)
  -- TODO: Just disconnect when you will be using
  if gameEvent then
  	connect(g_game, {
  	  onGameEnd = onGameEnd,
  	  onGameStart = onGameStart
  	})
	disconnect(LocalPlayer, {
		onPositionChange = onPositionChange
	})
  end
  -- unregister opcode

  return true
end

function init()
  connecting(true)
  MainWindow = g_ui.loadUI("market", modules.game_interface.getRootPanel())
  BuyPanel = MainWindow:getChildById("buyPanel")
  SellPanel = MainWindow:getChildById("sellPanel")

  BuyNowWindow = g_ui.createWidget('BuyNowWindow', modules.game_interface.getRootPanel())
  local options = {}

  for category, id in pairs(Market.category) do
    table.insert(options, {option = category, id = id})
  end

  table.sort(options, function(a,b) return a.id < b.id end)
  for _, tab in pairs(options) do
    BuyPanel:getChildById("comboBox"):addOption(tab.option:sub(1,1):upper()..tab.option:sub(2))
  end

  for _, _time in ipairs(Market.time) do
    SellPanel:getChildById("sell_timebox"):addOption(_time.name)
  end

  BuyPanel:getChildById("comboBox").onOptionChange = getBuyItems

  if g_game.isOnline() then onGameStart() end
  ProtocolGame.registerExtendedOpcode(Market.opcode, parseMarket)
end

function terminate()
  -- Removing the connectors
  disconnecting(true)
  ProtocolGame.unregisterExtendedOpcode(Market.opcode)

  BuyNowWindow:destroy()
  BuyNowWindow = nil
  MainWindow:destroy()
  MainWindow = nil
end

function show()
  BuyNowWindow:hide()
  MainWindow:show()
end

function hide()
  MainWindow:hide()
end

function togglePage(id)
  if id == "first" then
    Current.page = 1
  elseif id == "prev" then
    Current.page = math.max(1, Current.page - 1)
  elseif id == "next" then
    Current.page = math.min(Current.max_page, Current.page + 1)
  elseif id == "last" then
    Current.page = Current.max_page
  end
  getBuyItems()
end

function getBuyItems()
  local params = {
    protocol = "buy_items",
    category = Current.category or Market.category.all,
	page = Current.page or 1,
	order = Current.order or Market.order.timeasc,
	search_string = Current.search_string
  }
  g_game.getProtocolGame():sendExtendedOpcode(Market.opcode, json.encode(params))
end

function getSellItems()
  local params = {
    protocol = "sell_items",
  }
  g_game.getProtocolGame():sendExtendedOpcode(Market.opcode, json.encode(params))
end

function onTextChange()
  Current.search_string = BuyPanel:getChildById("searchEdit"):getText()
end

function onSellPriceChange()
  local value = math.max(1, SellPanel:getChildById("sell_amount"):getValue())
  local priceNumber = tonumber(SellPanel:getChildById("sell_priceedit"):getText())
  if priceNumber then
    SellPanel:getChildById("sell_value"):setText("Price: "..getFormattedMoney2((priceNumber*value)).."\nTaxa: "..getFormattedMoney2(getMarketFee(priceNumber*value)).."\nTotal: "..getFormattedMoney2((priceNumber*value)+getMarketFee(priceNumber*value)))
  end
end

function cancelSellItem(widget)
  local params = {
    protocol = "cancelsell_item",
    item_code = widget.market_item.item_code,
  }
  g_game.getProtocolGame():sendExtendedOpcode(Market.opcode, json.encode(params))
end

function buyItem()
  if not Current.buyWidget then return end
  local rowItem = BuyNowWindow:getChildById('item')
  rowItem:setItemId(Current.buyWidget.market_item.clientId)
  rowItem:setItemCount(Current.buyWidget.market_item.count)
  local rowScrollbar = BuyNowWindow:getChildById('countScrollBar')
  rowScrollbar:setMinimum(1)
  rowScrollbar:setMaximum(Current.buyWidget.market_item.count)
  rowScrollbar:setText(Current.buyWidget.market_item.count)
  rowScrollbar:setValue(Current.buyWidget.market_item.count)

  local rowPrice = BuyNowWindow:getChildById('price')
  rowPrice:setText(getFormattedMoney2(Current.buyWidget.market_item.price * Current.buyWidget.market_item.count))

  local rowSpinBox = BuyNowWindow:getChildById('spinBox')
  rowSpinBox:setMinimum(0)
  rowSpinBox:setMaximum(Current.buyWidget.market_item.count)
  rowSpinBox:setValue(0)
  rowSpinBox:hideButtons()
  rowSpinBox:focus()
  rowSpinBox.firstEdit = true
  local onSpinBoxValueChange = function(self, value)
    rowSpinBox.firstEdit = false
	rowScrollbar:setValue(value)
  end
  rowSpinBox.onValueChange = onSpinBoxValueChange

  local refresh = function()
    if rowSpinBox.firstEdit then
      rowSpinBox:setValue(rowSpinBox:getMaximum())
      rowSpinBox.firstEdit = false
    end
  end

  g_keyboard.bindKeyPress("Up", function() refresh() rowSpinBox:up() end, rowSpinBox)
  g_keyboard.bindKeyPress("Down", function() refresh() rowSpinBox:down() end, rowSpinBox)
  g_keyboard.bindKeyPress("Right", function() refresh() rowSpinBox:up() end, rowSpinBox)
  g_keyboard.bindKeyPress("Left", function() refresh() rowSpinBox:down() end, rowSpinBox)
  g_keyboard.bindKeyPress("PageUp", function() refresh() rowSpinBox:setValue(rowSpinBox:getValue()+1) end, rowSpinBox)
  g_keyboard.bindKeyPress("PageDown", function() refresh() rowSpinBox:setValue(rowSpinBox:getValue()-1) end, rowSpinBox)

  rowScrollbar.onValueChange = function(self, value)
    rowItem:setItemCount(value)
	rowScrollbar:setText(value)
	rowPrice:setText(getFormattedMoney2(value * Current.buyWidget.market_item.price))
    rowSpinBox.onValueChange = nil
    rowSpinBox:setValue(value)
    rowSpinBox.onValueChange = onSpinBoxValueChange
  end

  local okButton = BuyNowWindow:getChildById('buttonOk')
  local buyFunc = function()
    buyItem(rowItem:getItemCount())
    local params = {
      protocol = "buy_item",
      item_code = Current.buyWidget.market_item.item_code,
	  itemid = Current.buyWidget.market_item.itemid,
	  buy_count = rowItem:getItemCount()
    }
    g_game.getProtocolGame():sendExtendedOpcode(Market.opcode, json.encode(params))
    show()
  end
  local cancelButton = BuyNowWindow:getChildById('buttonCancel')
  local cancelFunc = function()
    show()
  end

  BuyNowWindow.onEnter = buyFunc
  BuyNowWindow.onEscape = cancelFunc

  okButton.onClick = buyFunc
  cancelButton.onClick = cancelFunc
  MainWindow:hide()
  BuyNowWindow:show()
end

function onConfirmSellItem()
  local buffer = {
    protocol = "sell_item",
	itemid = SellPanel:getChildById("sell_item").item.itemid,
	item_code = SellPanel:getChildById("sell_item").item.item_code,
	count = SellPanel:getChildById("sell_amount"):getValue(),
	maxtime = SellPanel:getChildById("sell_timebox"):getText(),
	price = tonumber(SellPanel:getChildById("sell_priceedit"):getText()) or 0,
  }
  for id, _time in ipairs(Market.time) do
    if _time.name == SellPanel:getChildById("sell_timebox"):getText() then
	  buffer.maxtime = id
	  break
	end
  end
  g_game.getProtocolGame():sendExtendedOpcode(Market.opcode, json.encode(buffer))
end

function selectItemToSell()
  local gameInterface = modules.game_interface
  local mouseGrabberWidget = gameInterface.getMouseGrabberWidget()
  mouseGrabberWidget:grabMouse()
  g_mouse.pushCursor('target')
  mouseGrabberWidget.onMouseRelease = function(self, mousePosition, mouseButton)
    if mouseButton == MouseLeftButton then
	  local clickedWidget = gameInterface.getRootPanel():recursiveGetChildByPos(mousePosition, false)
	  if clickedWidget and clickedWidget:getClassName() == 'UIItem' then
		g_game.getProtocolGame():sendExtendedOpcode(Market.opcode, json.encode({protocol = "selectItemToSell", pos = clickedWidget:getItem():getPosition()}))
	  end
	end
	while(g_mouse.isCursorChanged()) do
	  g_mouse.popCursor('target')
	end
	self:ungrabMouse()
	mouseGrabberWidget.onMouseRelease = nil
	mouseGrabberWidget.onMouseRelease = gameInterface.onMouseGrabberRelease
  end
end

function showBuyPanel()
  SellPanel:hide()
  getBuyItems()
  BuyPanel:show()
end

function showSellPanel()
  BuyPanel:hide()
  getSellItems()
  SellPanel:show()
end

function parseMarket(protocol, opcode, buffer)
  local receive = json.decode(buffer)
  print(buffer)
  if receive.protocol == "close" then
    MainWindow:hide()
  elseif receive.protocol == "buy_items" then
    if receive.first then
	  Current.page = receive.page
	  Current.category = receive.category
	  Current.max_page = receive.max_page
	  Current.search_string = receive.search_string
	  updatePageWidget()
	  BuyPanel:getChildById("items"):destroyChildren()
	  BuyPanel:getChildById("buyButton"):setEnabled(false)
	end
	local child_count = #BuyPanel:getChildById("items"):getChildren()
    local function onFocus(widget, market_item, focused)
      if focused then
        widget:setBorderColor("red")
        BuyPanel:getChildById("buyButton"):setEnabled(true)
        Current.buyWidget = widget
      else
        widget:setBorderColor("alpha")
      end
    end
	for n, market_item in ipairs(receive.market_items) do
	  local widget = g_ui.createWidget("MarketItem", BuyPanel:getChildById("items"))
	  widget.market_item = market_item
	  widget:getChildById("time"):setText("#"..child_count)
	  child_count = child_count + 1
	  local _t = market_item.timeleft
	  -- widget:getChildById("timer"):setText(_t < 0 and "Expired" or string.format("%02d:%02d:%02d", math.floor(_t/(60*60)), math.floor((_t/60)%60), math.floor(_t%60)))
      widget.market_item.timeleft = widget.market_item.timeleft - 1
	  widget:getChildById("item"):setItemId(market_item.clientId)
	  widget:getChildById("item"):setItemCount(market_item.count)
	  widget:getChildById("name"):setText(market_item.item_name)
	  widget:getChildById("seller"):setText(market_item.seller_name)
	  widget:getChildById("amount"):setText(market_item.count)
	  widget:getChildById("price"):setText(getFormattedMoney2(market_item.price))
	  widget.onFocusChange = function(reasonLabel, focused)
	    onFocus(widget, market_item, focused)
	  end
	  if n == #receive.market_items then onFocus(widget, market_item, true) end
	  widget:setBackgroundColor(child_count % 2 == 0 and "#191B22" or "#262933")
	end
	SellPanel:hide()
    BuyPanel:show()
	MainWindow:show()
  elseif receive.protocol == "sell_items" then
    if receive.first then
	  SellPanel:getChildById("items"):destroyChildren()
      SellPanel:getChildById("sell_item"):setItemId(0)
	  SellPanel:getChildById("sell_amount"):setEnabled(true)
	  SellPanel:getChildById("sell_amount").onValueChange = nil
	  SellPanel:getChildById("sell_confirm"):setEnabled(false)
	  SellPanel:getChildById("sell_priceedit"):setEnabled(false)
	end
	local child_count = #SellPanel:getChildById("items"):getChildren()
    local function onFocus(widget, market_item, focused)
      if focused then
        widget:setBorderColor("white")
      else
        widget:setBorderColor("alpha")
      end
    end
	for n, market_item in ipairs(receive.market_items) do
	  local widget = g_ui.createWidget("MarketSellItem", SellPanel:getChildById("items"))
	  widget.market_item = market_item
	  widget:getChildById("time"):setText("#"..child_count)
	  child_count = child_count + 1
	  local _t = market_item.timeleft
	  widget:getChildById("timer"):setText(_t < 0 and "Expired" or string.format("%02d:%02d:%02d", math.floor(_t/(60*60)), math.floor((_t/60)%60), math.floor(_t%60)))
      widget.market_item.timeleft = widget.market_item.timeleft - 1
	  widget:getChildById("item"):setItemId(market_item.clientId)
	  widget:getChildById("item"):setItemCount(market_item.count)
	  widget:getChildById("name"):setText(market_item.item_name)
	  widget:getChildById("amount"):setText(market_item.count)
	  widget:getChildById("price"):setText(market_item.price)
	  widget.onFocusChange = function(reasonLabel, focused)
	    onFocus(widget, market_item, focused)
	  end
	  if n == #receive.market_items then onFocus(widget, market_item, true) end
	end
  elseif receive.protocol == "item_to_sell" then
    SellPanel:getChildById("sell_item").item = receive
    SellPanel:getChildById("sell_item"):setItemId(receive.clientId)
    SellPanel:getChildById("sell_item"):setItemCount(1)
	SellPanel:getChildById("sell_amount"):setEnabled(true)
	SellPanel:getChildById("sell_amount"):setValue(1)
	SellPanel:getChildById("sell_amount"):setText(1)
	SellPanel:getChildById("sell_amount"):setMinimum(1)
	SellPanel:getChildById("sell_amount"):setMaximum(receive.count)
	SellPanel:getChildById("sell_amount").onValueChange = function(self)
      local value = math.max(1, SellPanel:getChildById("sell_amount"):getValue())
	  SellPanel:getChildById("sell_item"):setItemCount(value)
	  SellPanel:getChildById("sell_amount"):setText(value)
	  onSellPriceChange()
	end
	SellPanel:getChildById("sell_priceedit"):setEnabled(true)
	SellPanel:getChildById("sell_confirm"):setEnabled(true)
  end
end

function updatePageWidget()
  local pageWidget = BuyPanel:getChildById("pageWidget")
  pageWidget:getChildById("text"):setText(tr("Page")..": "..Current.page.."/"..Current.max_page)
  pageWidget:getChildById("first"):setEnabled(Current.page > 1 and true or false)
  pageWidget:getChildById("prev"):setEnabled(Current.page > 1 and true or false)
  pageWidget:getChildById("next"):setEnabled(Current.page < Current.max_page and true or false)
  pageWidget:getChildById("last"):setEnabled(Current.page < Current.max_page and true or false)
end

function onPositionChange(player, newPos, oldPos)
  if player:isLocalPlayer() then

  end
end

function getFormattedMoney2(value)
  local valueText = ""
  if value < 1000 then
    valueText = valueText..value
  else
    if value < 10000 then
	  valueText = valueText..string.sub(value, 0, 1).."."..valueText..string.sub(value, 2, 4)
	elseif value < 100000 then
	  valueText = valueText..string.sub(value, 0, 2).."."..valueText..string.sub(value, 3, 5)
	elseif value < 1000000 then
	  valueText = valueText..string.sub(value, 0, 3).."."..valueText..string.sub(value, 4, 6)
	elseif value < 10000000 then
	  valueText = valueText..string.sub(value, 0, 1).."."..valueText..string.sub(value, 2, 4).."."..valueText..string.sub(value, 5, 8)
	elseif value <= 100000000 then
	  valueText = valueText..string.sub(value, 0, 2).."."..valueText..string.sub(value, 3, 5).."."..valueText..string.sub(value, 6, 9)
	else
	  valueText = " invalido."
	end
  end
  return "$"..valueText
end

function getMarketFee(price)
  local fee = math.max(1, price / 100)
  if (fee < 20) then
  	fee = 20
  elseif (fee > 1000) then
  	fee = 1000
  end
  return fee
end