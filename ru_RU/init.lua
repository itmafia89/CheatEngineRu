-- ============================================================
-- CHEAT ENGINE 7.7 | ДОПОЛНИТЕЛЬНАЯ РУСИФИКАЦИЯ
-- Файл: languages/ru_RU/init.lua
-- Назначение: перевод элементов интерфейса через Lua.
-- Исходные файлы Cheat Engine и расширений не изменяются.
-- ============================================================

-- ============================================================
-- 00. ОБЩИЕ ФУНКЦИИ И БЕЗОПАСНЫЙ ДОСТУП К СВОЙСТВАМ
-- ============================================================

local mf = getMainForm()
if not mf then return end

-- Некоторые компоненты Cheat Engine не поддерживают все свойства.
local function prop(object, name)
    if not object then return nil end
    local ok, value = pcall(function() return object[name] end)
    if ok then return value end
    return nil
end

local function setprop(object, name, value)
    if not object then return false end
    return pcall(function() object[name] = value end)
end

local function eachChild(root, callback, depth)
    if not root or (depth or 0) > 12 then return end
    callback(root)
    local count = prop(root, 'ControlCount')
    if type(count) ~= 'number' or count < 1 or count > 500 then return end
    for i = 0, count - 1 do
        local child
        local ok = pcall(function() child = root.Control[i] end)
        if ok and child and child ~= root then
            eachChild(child, callback, (depth or 0) + 1)
        end
    end
end

local function translateControls(root, dictionary, translateHints)
    eachChild(root, function(control)
        local caption = prop(control, 'Caption')
        local replacement = dictionary[caption]
        if replacement and replacement ~= caption then
            setprop(control, 'Caption', replacement)
        end
        -- Меняем только подсказку поля, не пользовательский ввод.
        if translateHints then
            local hint = prop(control, 'TextHint')
            local newHint = dictionary[hint]
            if newHint and newHint ~= hint then
                setprop(control, 'TextHint', newHint)
            end
        end
    end)
end

-- ============================================================
-- 01. КОНТЕКСТНОЕ МЕНЮ СПИСКА АДРЕСОВ
-- ============================================================
local function translateAddressMenu(items)
    local count = prop(items, 'Count')
    if type(count) ~= 'number' then return end
    for i = 0, count - 1 do
        local item = prop(items, i)
        if item then
            if prop(item, 'Caption') == 'Add to new group' then
                setprop(item, 'Caption', 'В новую группу')
            end
            translateAddressMenu(item)
        end
    end
end

local addressList = getAddressList()
local addressPopup = prop(addressList, 'PopupMenu')
if addressPopup then
    local oldPopup = prop(addressPopup, 'OnPopup')
    setprop(addressPopup, 'OnPopup', function(sender)
        if oldPopup then oldPopup(sender) end
        pcall(translateAddressMenu, prop(addressPopup, 'Items'))
    end)
    pcall(translateAddressMenu, prop(addressPopup, 'Items'))
end

-- ============================================================
-- 02. ШИРИНА СТОЛБЦОВ СПИСКА АДРЕСОВ
-- ============================================================
local header = prop(addressList, 'Header')
local sections = prop(header, 'Sections')
local widths = {60, 170, 120, 120, 170}
if sections then
    for i = 0, 4 do
        local section = prop(sections, i)
        if section then setprop(section, 'Width', widths[i + 1]) end
    end
end

-- ============================================================
-- 03. ЗАГОЛОВОК НАЧАЛЬНОГО ЗНАЧЕНИЯ В РЕЗУЛЬТАТАХ ПОИСКА
-- ============================================================
local function translateFirstColumn()
    local list = prop(mf, 'Foundlist3')
    local cols = prop(list, 'Columns')
    local count = prop(cols, 'Count')
    if type(count) ~= 'number' then return end
    for i = 2, math.min(count - 1, 5) do
        local col = prop(cols, i)
        local text = prop(col, 'Caption')
        if text == 'First' or text == 'FIRST' then
            setprop(col, 'Caption', 'Начальное')
        end
    end
end

-- ============================================================
-- 04. ОБЛАСТЬ СКАНИРОВАНИЯ: ALL -> ВСЁ
-- ============================================================
local regionDone = false
local regionAttempts = 0
local function translateScanRegion()
    local box = prop(mf, 'gbScanOptions')
    if not box then return false end
    local found = false
    eachChild(box, function(control)
        if found then return end
        local items = prop(control, 'Items')
        local count = prop(items, 'Count')
        if type(count) == 'number' and count > 0 then
            local first = prop(items, 0)
            if first == 'Всё' then
                found = true
            elseif first == 'All' then
                local index = prop(control, 'ItemIndex')
                if setprop(items, 0, 'Всё') then
                    if type(index) == 'number' then
                        setprop(control, 'ItemIndex', index)
                    end
                    found = true
                end
            end
        end
    end)
    return found
end

-- Первая попытка сразу при загрузке русского языкового пакета.
-- Если список еще не создан, основной таймер повторит проверку.
regionDone = translateScanRegion()

-- ============================================================
-- 05. ГЛАВНОЕ МЕНЮ: ASK AI
-- ============================================================
local askAIDone = false
local function translateAskAI()
    local help = prop(mf, 'miHelp')
    local count = prop(help, 'Count')
    if type(count) ~= 'number' then return false end
    for i = 0, count - 1 do
        local item = prop(help, i)
        local title = prop(item, 'Caption')
        if title == 'Спросить ИИ' then return true end
        if title == 'Ask AI' or title == '&Ask AI' then
            return setprop(item, 'Caption', 'Спросить ИИ')
        end
    end
    return false
end

-- ============================================================
-- 06. КОНТЕКСТНОЕ МЕНЮ ИИ В ПРОСМОТРЕ ПАМЯТИ
-- ============================================================
local aiMemoryTranslations = {
    ['Explain this function'] = 'Объяснить эту функцию',
    ['Generate pseudocode for this function'] = 'Создать псевдокод функции'
}

local hookedMemoryForms = setmetatable({}, {__mode = 'k'})
local function installMemoryMenu(form)
    if not form or hookedMemoryForms[form] then return end
    local popup = prop(form, 'debuggerpopup')
    if not popup then return end
    hookedMemoryForms[form] = true

    local function updateItems()
        local items = prop(popup, 'Items')
        local count = prop(items, 'Count')
        if type(count) ~= 'number' then return end
        for i = 0, count - 1 do
            local item = prop(items, i)
            local caption = prop(item, 'Caption')
            local translated = aiMemoryTranslations[caption]
            if translated then setprop(item, 'Caption', translated) end
        end
    end

    local oldPopup = prop(popup, 'OnPopup')
    setprop(popup, 'OnPopup', function(sender)
        if oldPopup then oldPopup(sender) end
        pcall(updateItems)
    end)
    pcall(updateItems)
end

-- ============================================================
-- 07. ДИАЛОГ ИИ: ПОДПИСИ И ПОДСКАЗКИ
-- ============================================================
local aiDialogStrings = {
    ['AI Dialog'] = 'Диалог ИИ',
    ['Your AI Access'] = 'Доступ к ИИ',
    ['Public CE API (Extremely Limited)'] = 'Публичный API CE (очень ограничен)',
    ['Public CE API (Limited)'] = 'Публичный API CE (ограничен)',
    ['Patreon CE API (Limited)'] = 'API Patreon CE (ограничен)',
    ['Personal Google AI Key (Best option)'] = 'Личный ключ Google AI (лучший вариант)',
    ['Current/Default Model'] = 'Текущая/стандартная модель',
    ['Refresh session'] = 'Обновить сеанс',
    ['Obtain Key'] = 'Получить ключ',
    ['Send'] = 'Отправить',
    ['Options'] = 'Параметры',
    ['<Enter CE Patreon session ID here>'] = '<Введите ID сеанса Patreon CE>',
    ['<Enter API key here>'] = '<Введите API-ключ>',
    ['Custom'] = 'Свой вариант'
}

local function translateAIDialog(form)
    local caption = prop(form, 'Caption')
    if caption == 'AI Dialog' or caption == 'Диалог ИИ' then
        translateControls(form, aiDialogStrings, true)
    end
end

local function prepareForm(form)
    if not form then return end
    if prop(form, 'ClassName') == 'TMemoryBrowser' then
        installMemoryMenu(form)
    end
    translateAIDialog(form)
end

-- Обрабатываем уже созданные окна один раз.
local count = getFormCount()
for i = 0, count - 1 do
    pcall(prepareForm, getForm(i))
end

-- Для новых окон перевод выполняется при первом показе.
ruLocalizationFormHook = registerFormAddNotification(function(form)
    local ok = pcall(function()
        form.registerFirstShowCallback(function(shownForm)
            pcall(prepareForm, shownForm)
        end)
    end)
    if not ok then pcall(prepareForm, form) end
end)

-- ============================================================
-- 08. НАСТРОЙКИ: НАЗВАНИЯ РАЗДЕЛОВ И ПОДПИСИ
-- ============================================================
local settingsCategories = {
    ['AI Tools'] = 'Инструменты ИИ',
    ['Auto Save'] = 'Автосохранение',
    ['MonoExtension'] = 'Расширение Mono',
    ['CE Share'] = 'Обмен таблицами',
    ['CEShare'] = 'Обмен таблицами',
    ['Extra Custom Types'] = 'Доп. типы данных'
}

local settingsCaptions = {
    ['Enable use of AI functions (Requires restart of CE to apply)'] = 'Включить функции ИИ (требуется перезапуск CE)',
    ['Auto Save Interval (In seconds. 0 is disabled)'] = 'Интервал автосохранения (сек., 0 — отключено)',
    ['Enable "Uses Mono" option on successful mono attach'] = 'Включать «Uses Mono» при подключении Mono',
    ['Ignore the "Uses Mono" option inside a table'] = 'Игнорировать «Uses Mono» в таблице',
    ['CEShare community URL (For writes only)'] = 'URL сообщества CE Share (только для записи)',
    ['CEShare community URL'] = 'URL сообщества CE Share',
    ['2 Byte Big Endian'] = '2 байта (старший байт первым)',
    ['4 Byte Big Endian'] = '4 байта (старший байт первым)',
    ['Float Big Endian'] = 'Float (старший байт первым)'
}

-- ============================================================
-- 08.1. ТИПЫ BIG ENDIAN: ПЕРЕВОД БЕЗ ИЗМЕНЕНИЯ ИДЕНТИФИКАТОРОВ
-- ============================================================
-- В autorun/bigendian.lua названия типов хранятся в Items[].
-- Эти строки также используются как внутренние идентификаторы.
-- Перед обработкой закрытия возвращаем исходные английские названия.
local bigEndianNames = {
    ['2 Byte Big Endian'] = '2 байта (старший байт первым)',
    ['4 Byte Big Endian'] = '4 байта (старший байт первым)',
    ['Float Big Endian'] = 'Float (старший байт первым)'
}
local bigEndianOriginalNames = {}
for english, russian in pairs(bigEndianNames) do
    bigEndianOriginalNames[russian] = english
end

local bigEndianHookedForms = setmetatable({}, {__mode = 'k'})
local bigEndianTranslated = false

local function bigEndianList(sf)
    local pc = prop(sf, 'SettingsPageControl')
    local count = prop(pc, 'PageCount')
    if type(count) ~= 'number' or count < 1 or count > 100 then
        return nil
    end
    for i = 0, count - 1 do
        local page
        local ok = pcall(function() page = pc.Page[i] end)
        if ok and page and prop(page, 'Name') == 'CustomTypes' then
            return prop(page, 'List')
        end
    end
    return nil
end

local function replaceBigEndianListItems(sf, translations)
    local list = bigEndianList(sf)
    local items = prop(list, 'Items')
    local count = prop(items, 'Count')
    if type(count) ~= 'number' or count < 1 or count > 100 then
        return false
    end
    for i = 0, count - 1 do
        local original = prop(items, i)
        local replacement = translations[original]
        if replacement then
            -- Меняем только надпись; положение и состояние флажка сохраняем.
            setprop(items, i, replacement)
        end
    end
    return true
end

local function translateBigEndianSettings(sf)
    if not bigEndianList(sf) then return false end

    -- Подменяем OnClose после инициализации страницы расширением,
    -- предварительно сохраняя оригинальный обработчик.
    if not bigEndianHookedForms[sf] then
        local oldOnClose = prop(sf, 'OnClose')
        local hooked = setprop(sf, 'OnClose', function(sender, closeAction)
            -- ВАЖНО: вернуть английские идентификаторы до того,
            -- как bigendian.lua прочитает Items[i] при нажатии «ОК».
            pcall(replaceBigEndianListItems, sf, bigEndianOriginalNames)
            bigEndianTranslated = false
            if oldOnClose then
                return oldOnClose(sender, closeAction)
            end
            return closeAction
        end)
        if not hooked then return false end
        bigEndianHookedForms[sf] = true
    end

    return replaceBigEndianListItems(sf, bigEndianNames)
end

-- ------------------------------------------------------------
-- 08.2. ОБНОВЛЕНИЕ АКТИВНОЙ СТРАНИЦЫ НАСТРОЕК
-- ------------------------------------------------------------
local ceShareCaption = {['Enabled'] = 'Включить CE Share'}
local lastSettingsVisible = false
local lastSettingsPage = nil
local lastSettingsNode = nil
local lastSettingsCount = -1
local pagePasses = 0

local function translateCategoryTree(tree)
    local items = prop(tree, 'Items')
    local count = prop(items, 'Count')
    if type(count) ~= 'number' then return end
    for i = 0, count - 1 do
        local node = prop(items, i)
        local label = prop(node, 'Text')
        local replacement = settingsCategories[label]
        if replacement then setprop(node, 'Text', replacement) end
    end
end

local function updateSettings()
    local sf = getSettingsForm()
    if not sf or not prop(sf, 'Visible') then
        lastSettingsVisible = false
        lastSettingsPage = nil
        lastSettingsNode = nil
        bigEndianTranslated = false
        pagePasses = 0
        return
    end

    local tree = prop(sf, 'SettingsTreeView')
    local pageControl = prop(sf, 'SettingsPageControl')
    local page = prop(pageControl, 'ActivePage')
    local selectedNode = prop(tree, 'Selected')
    local items = prop(tree, 'Items')
    local nodeCount = prop(items, 'Count') or 0

    -- Переводим названия разделов при открытии или добавлении узлов.
    if not lastSettingsVisible or nodeCount ~= lastSettingsCount then
        translateCategoryTree(tree)
        lastSettingsCount = nodeCount
    end

    local pageIndex = prop(pageControl, 'TabIndex')
    local nodeName = prop(selectedNode, 'Text')
    if pageIndex ~= lastSettingsPage or nodeName ~= lastSettingsNode or
       not lastSettingsVisible then
        pagePasses = 4
        lastSettingsPage = pageIndex
        lastSettingsNode = nodeName
    end
    lastSettingsVisible = true

    -- Флажки Big Endian находятся в Items[], а не в Caption.
    -- Переводим их один раз за открытие окна.
    if not bigEndianTranslated and nodeName == 'Доп. типы данных' then
        local ok, result = pcall(translateBigEndianSettings, sf)
        if ok and result then bigEndianTranslated = true end
    end

    -- Переводим активную страницу несколькими проходами после переключения.
    if page and pagePasses > 0 then
        pagePasses = pagePasses - 1
        translateControls(page, settingsCaptions, false)
        if prop(selectedNode, 'Text') == 'Обмен таблицами' then
            translateControls(page, ceShareCaption, false)
        end
    end

    -- Увеличиваем ширину списка приоритета потока.
    local priority = prop(sf, 'ComboThreadPriority')
    if priority and prop(priority, 'Width') ~= 220 then
        setprop(priority, 'Width', 220)
    end
end

-- ============================================================
-- 09. ПРОСМОТР ПАМЯТИ: ТОЛЬКО ЗАГОЛОВОК ОКНА
-- ============================================================
local function updateMemoryViewer()
    local mv = getMemoryViewForm()
    if not mv or not prop(mv, 'Visible') then return end

    if prop(mv, 'Caption') == 'Memory Viewer' then
        setprop(mv, 'Caption', 'Просмотр памяти')
    end
end

-- ============================================================
-- 10. ПРОВЕРКА ОТКРЫТЫХ ДИАЛОГОВ ИИ
-- ============================================================
local function updateVisibleAIDialogs()
    local n = getFormCount()
    for i = 0, n - 1 do
        local form = getForm(i)
        if form and prop(form, 'Visible') then
            translateAIDialog(form)
        end
    end
end

-- ============================================================
-- 11. ОСНОВНОЙ ТАЙМЕР: БЫСТРЫЕ ПРОВЕРКИ БЕЗ ПОЛНОГО ОБХОДА
-- ============================================================
local ticks = 0
local uiTimer = createTimer(mf, false)
uiTimer.Interval = 20
uiTimer.OnTimer = function()
    ticks = ticks + 1

    pcall(translateFirstColumn)  -- только несколько заголовков
    pcall(updateSettings)        -- без полного обхода при неизменной странице

    if ticks % 5 == 0 then       -- примерно каждые 100 мс
        if not askAIDone then
            local ok, result = pcall(translateAskAI)
            if ok and result then askAIDone = true end
        end
    end

    -- Пока All еще не найден: проверка каждые 20 мс, максимум 5 секунд.
    -- После успешного перевода проверка больше не выполняется.
    if not regionDone and regionAttempts < 250 then
        regionAttempts = regionAttempts + 1
        local ok, result = pcall(translateScanRegion)
        if ok and result then regionDone = true end
    end

	-- Просмотр памяти: каждые 20 мс
	pcall(updateMemoryViewer)
	
	-- Диалоги ИИ: каждые 60 мс
	if ticks % 3 == 0 then
		pcall(updateVisibleAIDialogs)
	end
	
end
uiTimer.Enabled = true


-- ============================================================
-- 12. ДИАГРАММА: ПУНКТ МЕНЮ «ИЗМЕНИТЬ ЦВЕТ ФОНА»
-- ============================================================

local function translateDiagramMenu(form)
    if not form then return false end

    local title = form.Caption

    if title ~= 'Диаграмма' and title ~= 'Diagram' then
        return false
    end

    local menu = form.Menu
    if not menu or not menu.Items then
        return false
    end

    local function checkMenu(parent)
        if not parent then return false end

        local found = false

        if parent.Caption == 'Change background color' or
           parent.Caption == '&Change background color' then

            parent.Caption = 'Изменить цвет фона'
            found = true
        end

        local count = parent.Count

        if type(count) == 'number' then
            for i = 0, count - 1 do
                local item = parent[i]

                if item and checkMenu(item) then
                    found = true
                end
            end
        end

        return found
    end

    return checkMenu(menu.Items)
end

-- Кратковременная проверка для каждого нового окна диаграммы.
local function watchDiagramMenu(form)
    if not form then return end

    local attempts = 0
    local timer = createTimer(form, false)

    timer.Interval = 20

    timer.OnTimer = function()
        attempts = attempts + 1

        local ok, result = pcall(
            translateDiagramMenu, form
        )

        if (ok and result) or attempts >= 100 then
            timer.Enabled = false
        end
    end

    timer.Enabled = true
end

-- Обрабатываем окна, созданные до загрузки этого скрипта.
for i = 0, getFormCount() - 1 do
    watchDiagramMenu(getForm(i))
end

-- Обрабатываем новые окна при их создании.
ruDiagramMenuHook = registerFormAddNotification(
    function(form)
        watchDiagramMenu(form)
    end
)
