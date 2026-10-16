-- ===================================================================
--  LOUIS HUB UI LIBRARY (V3.0 NEXT-GEN COMPLETE ENGINE)
--  Brand: Louis Hub
--  Priority: Zero-Leaks > Backward Compatibility > Glassmorphism > Performance
--  [PART 1 OF 6] - Core Foundation, Diagnostics, Complete Themes & Motion
-- ===================================================================

-- 1. TASK LIBRARY POLYFILLS (Compatibility for legacy / sandboxed environments)
if type(task) ~= "table" then task = {} end
if type(task.wait) ~= "function" then task.wait = function(t) return (wait and wait(t)) or (t or 0) end end
if type(task.spawn) ~= "function" then
    task.spawn = function(f, ...)
        if type(spawn) == "function" then return spawn(function(...) f(...) end, ...) end
        local co = coroutine.create(f)
        local ok, err = coroutine.resume(co, ...)
        if not ok then warn("[LouisHub] task.spawn polyfill error:", err) end
        return co
    end
end
if type(task.delay) ~= "function" then
    task.delay = function(t, f, ...)
        local args = {...}
        if type(delay) == "function" then
            delay(t, function() f(table.unpack(args)) end)
        else
            coroutine.wrap(function() task.wait(t); f(table.unpack(args)) end)()
        end
    end
end
if type(task.defer) ~= "function" then task.defer = task.spawn end
if type(task.cancel) ~= "function" then
    task.cancel = function(h)
        if type(h) == "thread" then pcall(function() if coroutine.close then coroutine.close(h) end end) end
    end
end

-- 2. DEEP CLONING & TABLE EQUALITY UTILITIES
local function cloneTable(t)
    if type(t) ~= "table" then return t end
    local copy = {}
    for k, v in pairs(t) do
        if type(v) == "table" then
            copy[k] = cloneTable(v)
        else
            copy[k] = v
        end
    end
    return copy
end

local function copyDefault(v)
    if type(v) == "table" then return cloneTable(v) end
    return v
end

local function tablesEqual(t1, t2)
    if t1 == t2 then return true end
    if type(t1) ~= "table" or type(t2) ~= "table" then return false end
    for k, v in pairs(t1) do
        if type(v) == "table" then
            if not tablesEqual(v, t2[k]) then return false end
        else
            if t2[k] ~= v then return false end
        end
    end
    for k in pairs(t2) do
        if t1[k] == nil then return false end
    end
    return true
end

-- 3. METHOD CALL NORMALIZER (Fixed Dot '.' vs Colon ':' Calling Bug)
local function isLibraryElement(v)
    return type(v) == "table" and (rawget(v, "__isElement") == true or (rawget(v, "Set") ~= nil and rawget(v, "Get") ~= nil))
end

local function normalizeSetArg(...)
    local count = select('#', ...)
    if count == 0 then return nil end
    local first = select(1, ...)
    if isLibraryElement(first) then
        return (select(2, ...))
    end
    return first
end

-- 4. ROBLOX CORE SERVICES
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TextService      = game:GetService("TextService")
local Players          = game:GetService("Players")
local HttpService      = game:GetService("HttpService")
local Workspace        = game:GetService("Workspace")
local LocalPlayer      = Players.LocalPlayer

-- Central LouisHub Object
local LouisHub = {}
LouisHub._Internal = {}
LouisHub.Version   = "3.1.0-NextGenComplete"
LouisHub.DebugMode = false
LouisHub.MostrarErroresEnUI = true

LouisHub._Internal.cloneTable        = cloneTable
LouisHub._Internal.copyDefault       = copyDefault
LouisHub._Internal.tablesEqual       = tablesEqual
LouisHub._Internal.normalizeSetArg   = normalizeSetArg
LouisHub._Internal.isLibraryElement  = isLibraryElement

-- Central Elements Registry with Auto-Default Capture
local function createElementsTable()
    return setmetatable({}, {
        __newindex = function(t, flag, elem)
            rawset(t, flag, elem)
            if type(elem) == "table" and type(elem.Get) == "function" then
                local ok, val = pcall(elem.Get)
                if ok and val ~= nil then elem._defecto = copyDefault(val) end
            end
        end,
    })
end
LouisHub.Elementos = createElementsTable()

-- Internal State & Registries
local activeSaveWindow       = nil
local pendingUnsavedChanges  = false
local autoSaveLoopRunning    = false
local _isLoadingFromFile     = false
local _registeredThemeWindows= setmetatable({}, {__mode = "k"})
local _realFlags             = {}
local _nonPersistentFlags    = {}
local _uiFlags               = {}
local _registeredKeybinds    = {}

local function markPendingChange()
    if _isLoadingFromFile then return end
    pendingUnsavedChanges = true
end

local function startAutoSaveLoop()
    if autoSaveLoopRunning then return end
    autoSaveLoopRunning = true
    LouisHub:RegistrarHilo(task.spawn(function()
        while autoSaveLoopRunning do
            task.wait(10)
            if pendingUnsavedChanges and activeSaveWindow and activeSaveWindow.NombreConfig and LouisHub.SaveManager then
                pendingUnsavedChanges = false
                pcall(function()
                    LouisHub.SaveManager:GuardarSilencioso(activeSaveWindow.NombreConfig)
                end)
            end
        end
    end))
end

-- 5. SAFE UTF-8 STRING TRUNCATION (Prevents Broken Multi-byte Character Bytes)
local function safeSubUTF8(str, maxChars)
    if type(str) ~= "string" then return "" end
    local totalChars = utf8.len(str)
    if not totalChars or totalChars <= maxChars then return str end
    local byteEnd = utf8.offset(str, maxChars + 1)
    if byteEnd then
        return string.sub(str, 1, byteEnd - 1)
    end
    return string.sub(str, 1, maxChars)
end
LouisHub._Internal.safeSubUTF8 = safeSubUTF8

-- 6. KEYBIND UTILITIES & CONFLICT DETECTOR
local function decomposeKey(v)
    if typeof(v) == "table" then
        return v.KeyCode, v.Ctrl or false, v.Shift or false, v.Alt or false
    end
    return v, false, false, false
end

local function formatKeyText(keyCode, ctrl, shift, alt)
    if not keyCode or keyCode == Enum.KeyCode.Unknown then return "None" end
    local parts = {}
    if ctrl then table.insert(parts, "Ctrl") end
    if shift then table.insert(parts, "Shift") end
    if alt then table.insert(parts, "Alt") end
    table.insert(parts, keyCode.Name)
    return table.concat(parts, "+")
end

local function keysConflict(a, b)
    local kA, cA, sA, aA = decomposeKey(a)
    local kB, cB, sB, aB = decomposeKey(b)
    if not kA or not kB then return false end
    if kA == Enum.KeyCode.Unknown or kB == Enum.KeyCode.Unknown then return false end
    return kA == kB and cA == cB and sA == sB and aA == aB
end

local function checkKeybindConflict(ownEntry, newVal)
    local conflicts = {}
    for _, item in ipairs(_registeredKeybinds) do
        if item ~= ownEntry then
            local ok, otherVal = pcall(item.GetValor)
            if ok and keysConflict(newVal, otherVal) then
                table.insert(conflicts, item.texto or "Keybind")
            end
        end
    end
    if #conflicts > 0 then
        local k, c, s, a = decomposeKey(newVal)
        pcall(function()
            LouisHub:Notificar({
                Titulo = "⚠️ Key Conflict",
                Texto  = "'" .. formatKeyText(k, c, s, a) .. "' is also bound to: " .. table.concat(conflicts, ", "),
                Duracion = 4,
            })
        end)
    end
end

local function checkKeybindConflictsOnLoad()
    if #_registeredKeybinds < 2 then return end
    local bySignature = {}
    for _, entry in ipairs(_registeredKeybinds) do
        local ok, val = pcall(entry.GetValor)
        if ok then
            local k, c, s, a = decomposeKey(val)
            if k and k ~= Enum.KeyCode.Unknown then
                local sig = k.Name .. "|" .. tostring(c) .. "|" .. tostring(s) .. "|" .. tostring(a)
                bySignature[sig] = bySignature[sig] or { k = k, c = c, s = s, a = a, texts = {} }
                table.insert(bySignature[sig].texts, entry.texto or "Keybind")
            end
        end
    end
    for _, group in pairs(bySignature) do
        if #group.texts >= 2 then
            pcall(function()
                LouisHub:Notificar({
                    Titulo = "⚠️ Conflicting Keybinds",
                    Texto  = "'" .. formatKeyText(group.k, group.c, group.s, group.a) .. "' bound to: " .. table.concat(group.texts, ", "),
                    Duracion = 6,
                })
            end)
        end
    end
end

-- 7. CUSTOM GLOBAL SIGNALS SYSTEM (Safe Error Boundary)
local function createSignal()
    local conns = {}
    local sig = {}
    function sig:Connect(fn)
        if type(fn) ~= "function" then return {Disconnect = function() end} end
        local entry = {activo = true, callback = fn}
        table.insert(conns, entry)
        return {
            Disconnect = function() entry.activo = false end,
        }
    end
    function sig:Fire(...)
        local snapshot = table.move(conns, 1, #conns, 1, {})
        for _, e in ipairs(snapshot) do
            if e.activo then
                local ok, err = pcall(e.callback, ...)
                if not ok then LouisHub:_RegistrarError("Eventos", err) end
            end
        end
    end
    return sig
end

LouisHub.Eventos = {
    FlagCambiada      = createSignal(),
    TabCambiada       = createSignal(),
    SubTabCambiada    = createSignal(),
    TemaCambiado      = createSignal(),
    ControlRegistrado = createSignal(),
    TipoCambiado      = createSignal(),
    HistorialCambiado = createSignal(),
}

-- 8. REACTIVE FLAGS PROXY SYSTEM (Prevents Redundant Auto-Save Triggers)
LouisHub.Flags = setmetatable({}, {
    __index = _realFlags,
    __newindex = function(_, key, val)
        local prev = _realFlags[key]
        if type(val) == "table" and type(prev) == "table" then
            if tablesEqual(val, prev) then return end
        elseif prev == val then
            return
        end

        _realFlags[key] = val
        markPendingChange()
        if LouisHub.Eventos and LouisHub.Eventos.FlagCambiada then
            LouisHub.Eventos.FlagCambiada:Fire(key, val)
        end
    end,
})

-- 9. OBSERVABILITY & ERROR LOGGING
LouisHub._Logs = {}
function LouisHub:_RegistrarError(ctx, msg)
    table.insert(self._Logs, { Momento = os.time(), Contexto = tostring(ctx or "?"), Mensaje = tostring(msg or "") })
    if #self._Logs > 60 then table.remove(self._Logs, 1) end
    if LouisHub.DebugMode then
        warn("[LouisHub] Error in '" .. tostring(ctx or "?") .. "': " .. tostring(msg or ""))
    end
end

function LouisHub:ObtenerErrores()
    local c = {}
    for i, v in ipairs(self._Logs) do c[i] = cloneTable(v) end
    return c
end

local function intentarSilencioso(desc, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and LouisHub.DebugMode then
        warn("[LouisHub] (Debug) '" .. desc .. "' failed: " .. tostring(err))
    end
    return ok, err
end

local function executeCallback(cb, ctx, ...)
    if not cb then return end
    local args = {...}
    local ok, err = pcall(function() return cb(table.unpack(args)) end)
    if not ok then
        LouisHub:_RegistrarError(ctx, err)
        local rawErr = tostring(err)
        local dispErr = rawErr:sub(1, 120) .. (#rawErr > 120 and "…" or "")
        if LouisHub.MostrarErroresEnUI ~= false then
            pcall(function()
                LouisHub:Notificar({
                    Titulo   = "⚠️ Error in " .. (ctx or "Control"),
                    Texto    = dispErr,
                    Duracion = 6,
                })
            end)
        end
        warn("[LouisHub] Callback error (" .. (ctx or "?") .. "):", err)
    end
    return ok
end

-- 10. GLOBAL HELPER METHODS (V2 Features Restored)
function LouisHub:Try(flag, fallback)
    local elem = self.Elementos[flag]
    if not elem then return fallback end
    local ok, val = pcall(elem.Get)
    if not ok or val == nil then return fallback end
    return val
end

function LouisHub:ObtenerFlag(flag)
    return LouisHub.Flags[flag]
end

function LouisHub:MarcarComoUI(flagOrTable)
    if type(flagOrTable) == "table" then
        for _, f in ipairs(flagOrTable) do _uiFlags[f] = true end
    else
        _uiFlags[flagOrTable] = true
    end
end

function LouisHub:ObtenerElemento(flag)
    return LouisHub.Elementos[flag]
end

function LouisHub:ActualizarLabel(flag, text)
    local elem = self.Elementos[flag]
    if not elem then return false end
    return pcall(elem.Set, text)
end

-- 11. DYNAMIC TEXT SCALING & MEMORY PRUNING (V2 Complete)
local textScaleRegistry = {}
local deadTextScales = 0
local textScales = { tabs = 1, general = 1, titulo = 1 }

local function compactRegistry(reg)
    local j = 0
    for i = 1, #reg do
        local entry = reg[i]
        if not entry.muerta then
            j = j + 1
            reg[j] = entry
        end
    end
    for i = #reg, j + 1, -1 do reg[i] = nil end
end

local function pruneDeadConnections()
    local active = _G.LouisHub_InstanciaActiva
    if not active then return end
    local list = active.Conexiones
    local j = 0
    for i = 1, #list do
        local conn = list[i]
        if conn and conn.Connected ~= false then
            j = j + 1
            list[j] = conn
        end
    end
    for i = #list, j + 1, -1 do list[i] = nil end
end

local function hasHiddenAncestor(inst)
    local cur = inst
    while cur do
        if cur:IsA("GuiObject") and not cur.Visible then return true end
        cur = cur.Parent
    end
    return false
end

local function calculateAndApplyTextSize(entry)
    local inst = entry.instancia
    if not (inst and inst.Parent) then return end
    local factor = textScales[entry.categoria] or 1
    local floorVal = (LouisHub.Capacidades and not LouisHub.Capacidades.Teclado) and 9 or 7
    local target = math.max(floorVal, math.floor(entry.base * factor + 0.5))

    if not entry.truncable then
        pcall(function() inst.TextSize = target end)
        return
    end

    local availWidth = inst.AbsoluteSize.X
    if availWidth <= 0 then
        if hasHiddenAncestor(inst) then return end
        entry.reintentos = (entry.reintentos or 0) + 1
        if entry.reintentos > 8 then return end
        task.defer(calculateAndApplyTextSize, entry)
        return
    end
    entry.reintentos = 0

    local availHeight = inst.AbsoluteSize.Y > 0 and inst.AbsoluteSize.Y or 100
    local sizeVal = target
    while sizeVal > floorVal do
        local ok, width = pcall(function()
            return TextService:GetTextSize(inst.Text, sizeVal, inst.Font, Vector2.new(10000, availHeight)).X
        end)
        if not ok or width <= availWidth then break end
        sizeVal = sizeVal - 1
    end
    pcall(function() inst.TextSize = sizeVal end)
end

function LouisHub._Internal.registerTextScale(instance, baseSize, category, truncable)
    category = category or "general"
    local entry = {
        instancia = instance, base = baseSize, categoria = category,
        truncable = truncable or false, reintentos = 0
    }
    table.insert(textScaleRegistry, entry)
    instance.Destroying:Connect(function()
        entry.muerta = true
        deadTextScales = deadTextScales + 1
        if deadTextScales >= 48 and deadTextScales * 3 >= #textScaleRegistry then
            deadTextScales = 0
            compactRegistry(textScaleRegistry)
            pruneDeadConnections()
        end
    end)

    if truncable then
        instance:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            calculateAndApplyTextSize(entry)
        end)
        instance:GetPropertyChangedSignal("Text"):Connect(function()
            calculateAndApplyTextSize(entry)
        end)
        task.defer(calculateAndApplyTextSize, entry)
    elseif textScales[category] ~= 1 then
        calculateAndApplyTextSize(entry)
    end
end

local function applyTextScale(cat, factor)
    textScales[cat] = factor
    for _, entry in ipairs(textScaleRegistry) do
        if entry.categoria == cat and not entry.muerta then
            calculateAndApplyTextSize(entry)
        end
    end
end

-- 12. ENVIRONMENT, EXECUTOR & SANDBOX DETECTION
local function detectExecutor()
    if type(getexecutorname) == "function" then
        local ok, n = pcall(getexecutorname)
        if ok and n and n ~= "" then return n end
    end
    local list = {
        {function() return syn ~= nil end,                 "Synapse X"},
        {function() return krnl ~= nil end,                "Krnl"},
        {function() return fluxus ~= nil end,              "Fluxus"},
        {function() return identifyexecutor ~= nil end,    "Executor (" .. tostring(pcall(identifyexecutor) and identifyexecutor() or "Unknown") .. ")"},
    }
    for _, item in ipairs(list) do
        local ok2, isIt = pcall(item[1])
        if ok2 and isIt then return item[2] end
    end
    return "Standard Engine"
end

local function getGuiParent()
    local ok, hui = pcall(function() return gethui() end)
    if ok and hui then return hui end
    local okCore, core = pcall(function() return game:GetService("CoreGui") end)
    if okCore and core then return core end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function protectGuiObject(gui)
    pcall(function()
        if syn and syn.protect_gui then syn.protect_gui(gui)
        elseif protectgui then protectgui(gui) end
    end)
end

local function fsAvailable()
    return type(writefile) == "function" and type(readfile) == "function"
end

-- 13. FIXED DATA PACKING & SERIALIZATION (Fixes Enum.KeyCode Corruption)
local VERSION_FORMATO_GUARDADO = 3

local function packFlags(flags, onlyUI)
    local res = { __version = VERSION_FORMATO_GUARDADO }
    for k, v in pairs(flags) do
        local skip = _nonPersistentFlags[k] or (onlyUI and not _uiFlags[k]) or (not onlyUI and _uiFlags[k])
        if not skip then
            if typeof(v) == "Color3" then
                res[k] = { __color3 = true, R = math.floor(v.R * 255 + 0.5), G = math.floor(v.G * 255 + 0.5), B = math.floor(v.B * 255 + 0.5) }
            elseif typeof(v) == "EnumItem" then
                -- Solved: Strips "Enum." prefix completely so it stores "KeyCode"
                local cleanType = tostring(v.EnumType):gsub("^Enum%.", "")
                res[k] = { __enum = true, EnumType = cleanType, Name = v.Name }
            elseif type(v) == "table" and typeof(v.KeyCode) == "EnumItem" then
                res[k] = { __keybindMods = true, KeyCode = v.KeyCode.Name, Ctrl = v.Ctrl or false, Shift = v.Shift or false, Alt = v.Alt or false }
            elseif type(v) == "table" then
                res[k] = cloneTable(v)
            else
                res[k] = v
            end
        end
    end
    return res
end

local function unpackFlagValue(v)
    if type(v) == "table" and v.__color3 then
        return Color3.fromRGB(v.R or 0, v.G or 0, v.B or 0)
    end
    if type(v) == "table" and v.__enum then
        local cleanType = tostring(v.EnumType):gsub("^Enum%.", "")
        local ok, enumGroup = pcall(function() return Enum[cleanType] end)
        if ok and enumGroup and enumGroup[v.Name] then
            return enumGroup[v.Name]
        end
        return Enum.KeyCode.Unknown
    end
    if type(v) == "table" and v.__keybindMods then
        local ok, keyCode = pcall(function() return Enum.KeyCode[v.KeyCode] end)
        return { KeyCode = ok and keyCode or Enum.KeyCode.Unknown, Ctrl = v.Ctrl or false, Shift = v.Shift or false, Alt = v.Alt or false }
    end
    return v
end

local function migrateSavedData(data, fromVer)
    return data
end

local function prepareLoadedData(data)
    if type(data) ~= "table" then return {} end
    local fromVer = tonumber(data.__version) or 1
    data.__version = nil
    if fromVer > VERSION_FORMATO_GUARDADO then
        pcall(function()
            LouisHub:Notificar({
                Titulo   = "⚠️ Newer Config",
                Texto    = "File format (v" .. fromVer .. ") is newer. Attempting to parse anyway.",
                Duracion = 5,
            })
        end)
    end
    return migrateSavedData(data, fromVer)
end

-- 14. PLATFORM & CAPABILITIES ENGINE (With Support Diagnostics)
local VALID_ENV_TYPES = { PC = true, Movil = true, Tablet = true, Consola = true, Studio = true, Desconocido = true }

LouisHub.Capacidades = {
    Archivos     = fsAvailable(),
    Drawing      = type(Drawing) == "table" and type(Drawing.new) == "function",
    ProtectGUI   = (type(syn) == "table" and type(syn.protect_gui) == "function") or type(protectgui) == "function",
    GetHUI       = type(gethui) == "function",
    Teclado      = UserInputService.KeyboardEnabled,
    Gamepad      = UserInputService.GamepadEnabled,
    EsStudio     = RunService:IsStudio(),
    TieneTouch   = UserInputService.TouchEnabled,
    TieneMouse   = UserInputService.MouseEnabled,
    Plataforma   = (function()
        local ok, p = pcall(function() return UserInputService:GetPlatform() end)
        return ok and p or Enum.Platform.None
    end)(),
    ViewportSize = (Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize) or Vector2.new(1280, 720),
    Tipo         = "Desconocido",
    EsTactil     = false,
    EsEscritorio = false,
    EsTouchOnly  = false,
}

function LouisHub.Capacidades:NombrePlataforma()
    local p = self.Plataforma
    if not p then return "Unknown" end
    return p.Name or tostring(p)
end

function LouisHub:RecalcularDerivadosEntorno()
    local C = self.Capacidades
    local CONSOLE_PLATFORMS = { XboxOne = true, XboxSeriesX = true, XboxSeriesS = true, PS4 = true, PS5 = true, UWP = true }
    local platName = C.Plataforma and C.Plataforma.Name

    local tipo
    if _G.LouisHub_TipoForzado and VALID_ENV_TYPES[_G.LouisHub_TipoForzado] then
        tipo = _G.LouisHub_TipoForzado
    elseif C.EsStudio then
        tipo = "Studio"
    elseif platName and CONSOLE_PLATFORMS[platName] then
        tipo = "Consola"
    elseif C.TieneMouse and C.Teclado then
        tipo = "PC"
    elseif C.TieneTouch then
        if C.ViewportSize.Y < 520 or C.ViewportSize.X < 650 then
            tipo = "Movil"
        else
            tipo = "Tablet"
        end
    elseif C.Teclado then
        tipo = "PC"
    else
        tipo = "Desconocido"
    end

    C.Tipo         = tipo
    C.EsTactil     = (tipo == "Movil" or tipo == "Tablet")
    C.EsEscritorio = (tipo == "PC" or tipo == "Consola")
    C.EsTouchOnly  = C.TieneTouch and not C.TieneMouse and not C.Teclado

    if self.Eventos and self.Eventos.TipoCambiado then
        self.Eventos.TipoCambiado:Fire(tipo)
    end
    return tipo
end
LouisHub:RecalcularDerivadosEntorno()

if type(_G.LouisHub_ConexionesCapacidades) == "table" then
    for _, c in ipairs(_G.LouisHub_ConexionesCapacidades) do
        pcall(function() if c and c.Connected then c:Disconnect() end end)
    end
end
_G.LouisHub_ConexionesCapacidades = {}

local function hookViewportSignals(camera)
    if not camera then return end
    local conn = camera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        LouisHub.Capacidades.ViewportSize = camera.ViewportSize
        LouisHub:RecalcularDerivadosEntorno()
    end)
    table.insert(_G.LouisHub_ConexionesCapacidades, conn)
end

hookViewportSignals(Workspace.CurrentCamera)
table.insert(_G.LouisHub_ConexionesCapacidades, Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
    local c = Workspace.CurrentCamera
    if not c then return end
    LouisHub.Capacidades.ViewportSize = c.ViewportSize
    LouisHub:RecalcularDerivadosEntorno()
    hookViewportSignals(c)
end))

LouisHub.Features = {
    { nombre = "GUI",          test = function() return true end,                          nivel = "requerido" },
    { nombre = "Archivos",     claveCapacidad = "Archivos",   nivel = "recomendado", mensaje = "Configurations cannot be saved." },
    { nombre = "Drawing",      claveCapacidad = "Drawing",    nivel = "recomendado", mensaje = "Visual Drawing ESP will not work." },
    { nombre = "ProtectGUI",   claveCapacidad = "ProtectGUI", nivel = "recomendado", mensaje = "GUI protection not available." },
    { nombre = "GetHUI",       claveCapacidad = "GetHUI",     nivel = "recomendado", mensaje = "HUI fallback not available." },
    { nombre = "Teclado",      claveCapacidad = "Teclado",    nivel = "opcional",    mensaje = "Keybinds will default to touch mode." },
    { nombre = "Gamepad",      claveCapacidad = "Gamepad",    nivel = "opcional",    mensaje = "Gamepad input unavailable." },
}

function LouisHub:VerificarSoporte(name)
    for _, f in ipairs(self.Features) do
        if f.nombre == name then
            local ok = false
            if f.claveCapacidad then ok = self.Capacidades[f.claveCapacidad] == true
            elseif f.test then local o, r = pcall(f.test); ok = o and r == true end
            return { ok = ok, nivel = f.nivel, nombre = f.nombre, mensaje = ok and nil or f.mensaje }
        end
    end
    return { ok = false, nivel = "desconocido", nombre = name, mensaje = "Feature not recognized." }
end

function LouisHub:ForzarTipo(tipo)
    if tipo and not VALID_ENV_TYPES[tipo] then return false, "Invalid device type" end
    _G.LouisHub_TipoForzado = tipo
    self:RecalcularDerivadosEntorno()
    return true
end

function LouisHub:LiberarForzado()
    return self:ForzarTipo(nil)
end

function LouisHub:DiagnosticoCompleto()
    local C = self.Capacidades
    local okCount, total, warns = 0, #self.Features, {}
    for _, f in ipairs(self.Features) do
        local r = self:VerificarSoporte(f.nombre)
        if r.ok then okCount = okCount + 1
        elseif f.nivel ~= "requerido" then
            table.insert(warns, { nombre = f.nombre, nivel = f.nivel, mensaje = r.mensaje })
        end
    end
    return {
        Tipo = C.Tipo, Plataforma = C:NombrePlataforma(), EsStudio = C.EsStudio,
        Ejecutor = detectExecutor(), Viewport = C.ViewportSize, Forzado = _G.LouisHub_TipoForzado,
        FeaturesOk = okCount, FeaturesTotal = total, Advertencias = warns, Capacidades = C
    }
end

function LouisHub:Profiler()
    local data = { Flags = 0, Elementos = 0, Conexiones = 0, Hilos = 0, Dibujos = 0, Instancias = 0, ObjetosGui = 0, MemoriaMb = nil }
    for _ in pairs(_realFlags) do data.Flags = data.Flags + 1 end
    for _ in pairs(LouisHub.Elementos) do data.Elementos = data.Elementos + 1 end
    local inst = _G.LouisHub_InstanciaActiva
    if inst then
        data.Conexiones = #(inst.Conexiones or {})
        data.Hilos      = #(inst.Hilos or {})
        data.Dibujos    = #(inst.Dibujos or {})
        data.Instancias = #(inst.Instancias or {})
    end
    local okP, parent = pcall(getGuiParent)
    if okP and parent then
        local sg = parent:FindFirstChild("LouisHub_ScreenGui")
        if sg then
            local okD, desc = pcall(function() return sg:GetDescendants() end)
            if okD then data.ObjetosGui = #desc end
        end
    end
    local okS, st = pcall(function() return game:GetService("Stats") end)
    if okS and st then
        local okM, m = pcall(function() return st:GetTotalMemoryUsageMb() end)
        if okM and type(m) == "number" and m > 0 then data.MemoriaMb = math.floor(m + 0.5) end
    end
    print(("[LouisHub] Profiler -> Flags:%d Elementos:%d Conexiones:%d Hilos:%d Instancias:%d GuiObjects:%d Memoria:%s"):format(
        data.Flags, data.Elementos, data.Conexiones, data.Hilos, data.Instancias, data.ObjetosGui,
        data.MemoriaMb and ("~" .. data.MemoriaMb .. "MB") or "N/A"
    ))
    return data
end

-- 15. GLOBAL AUTO-CLEANUP LIFECYCLE (Zero Ghost Instances / Leaks)
local function cleanPreviousInstance()
    local prev = _G.LouisHub_InstanciaActiva
    if type(prev) ~= "table" then return end

    for _, c in ipairs(prev.Conexiones or {}) do
        pcall(function() if c and c.Connected then c:Disconnect() end end)
    end
    for _, h in ipairs(prev.Hilos or {}) do
        pcall(function() if h and coroutine.status(h) ~= "dead" then task.cancel(h) end end)
    end
    for _, d in ipairs(prev.Dibujos or {}) do
        pcall(function() if d then d:Remove() end end)
    end
    for _, inst in ipairs(prev.Instancias or {}) do
        pcall(function() if inst and inst.Parent then inst:Destroy() end end)
    end
    pcall(function()
        local parent = getGuiParent()
        for _, name in ipairs({"LouisHub_ScreenGui", "LouisHub_TooltipOverlay", "LouisHub_ExternalHUD", "LouisHub_FloatingActionButton", "LouisHub_HitOverlay"}) do
            local old = parent:FindFirstChild(name)
            if old then old:Destroy() end
        end
    end)
end

local function createInstanceRecord(title)
    return { Conexiones = {}, Hilos = {}, Dibujos = {}, Instancias = {}, Ventana = nil, Titulo = title }
end

function LouisHub:RegistrarConexion(c)
    if _G.LouisHub_InstanciaActiva and c then table.insert(_G.LouisHub_InstanciaActiva.Conexiones, c) end
    return c
end

function LouisHub:DesconectarYLimpiar(c)
    if not c then return end
    pcall(function() c:Disconnect() end)
    if _G.LouisHub_InstanciaActiva then
        local list = _G.LouisHub_InstanciaActiva.Conexiones
        local idx = table.find(list, c)
        if idx then table.remove(list, idx) end
    end
end

function LouisHub:RegistrarHilo(h)
    if _G.LouisHub_InstanciaActiva and h then table.insert(_G.LouisHub_InstanciaActiva.Hilos, h) end
    return h
end

function LouisHub:RegistrarDibujo(d)
    if _G.LouisHub_InstanciaActiva and d then table.insert(_G.LouisHub_InstanciaActiva.Dibujos, d) end
    return d
end

function LouisHub:RegistrarInstancia(i)
    if _G.LouisHub_InstanciaActiva and i then table.insert(_G.LouisHub_InstanciaActiva.Instancias, i) end
    return i
end

-- 16. CENTRAL EVENT MANAGER (Drag Anti-Overlap & Touch Routing)
local EventManager = { _activo = nil, _alFinalizar = nil }
function EventManager:Arrastrar(cb, onEnd)
    self._activo = cb
    self._alFinalizar = onEnd
end
function EventManager:DetenerArrastre()
    self._activo = nil
    if self._alFinalizar then
        local cb = self._alFinalizar
        self._alFinalizar = nil
        pcall(cb)
    end
end
function EventManager:HayArrastreActivo() return self._activo ~= nil end

if type(_G.LouisHub_ConexionesEventManager) == "table" then
    for _, c in ipairs(_G.LouisHub_ConexionesEventManager) do
        pcall(function() if c and c.Connected then c:Disconnect() end end)
    end
end
_G.LouisHub_ConexionesEventManager = {}

table.insert(_G.LouisHub_ConexionesEventManager, UserInputService.InputChanged:Connect(function(input)
    if EventManager._activo and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
        pcall(EventManager._activo, input)
    end
end))
table.insert(_G.LouisHub_ConexionesEventManager, UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        EventManager:DetenerArrastre()
    end
end))
LouisHub.EventManager = EventManager

-- 17. COMPLETE THEMES LIST (Includes All 6 Original Themes + Glass Variants)
local Themes = {}
Themes.Predeterminado = "NeonGlass"
Themes.Lista = {
    NeonGlass = {
        Background      = Color3.fromRGB(12, 10, 20),
        BackgroundTrans = 0.28,
        BackgroundDark  = Color3.fromRGB(7, 4, 12),
        BackgroundLight = Color3.fromRGB(24, 15, 38),
        Panel           = Color3.fromRGB(18, 14, 28),
        PanelTrans      = 0.32,
        PanelLight      = Color3.fromRGB(28, 20, 44),
        PanelLightTrans = 0.40,
        PanelClaro      = Color3.fromRGB(26, 16, 42),
        Row             = Color3.fromRGB(24, 18, 36),
        RowTrans        = 0.38,
        Fila            = Color3.fromRGB(22, 14, 34),
        Input           = Color3.fromRGB(14, 10, 22),
        InputTrans      = 0.25,
        Entrada         = Color3.fromRGB(14, 9, 22),
        Accent          = Color3.fromRGB(255, 128, 24),
        AccentLight     = Color3.fromRGB(255, 160, 60),
        AccentGlow      = Color3.fromRGB(255, 140, 40),
        Highlight       = Color3.fromRGB(255, 210, 90),
        Border          = Color3.fromRGB(80, 50, 115),
        BorderTrans     = 0.45,
        BorderGlow      = Color3.fromRGB(160, 95, 230),
        TextPrimary     = Color3.fromRGB(250, 250, 255),
        TextSecondary   = Color3.fromRGB(190, 180, 210),
        TextMuted       = Color3.fromRGB(130, 120, 150),
        TextAccent      = Color3.fromRGB(255, 160, 60),
        TextCode        = Color3.fromRGB(145, 225, 255),
        Text            = Color3.fromRGB(245, 245, 255),
        TextDark        = Color3.fromRGB(160, 150, 180),
        Success         = Color3.fromRGB(46, 204, 113),
        Warning         = Color3.fromRGB(241, 196, 15),
        Danger          = Color3.fromRGB(235, 75, 75),
        Off             = Color3.fromRGB(50, 40, 70),
        Apagado         = Color3.fromRGB(44, 30, 60),
    },
    MidnightFrosted = {
        Background      = Color3.fromRGB(10, 14, 22),
        BackgroundTrans = 0.25,
        BackgroundDark  = Color3.fromRGB(32, 34, 38),
        BackgroundLight = Color3.fromRGB(55, 58, 64),
        Panel           = Color3.fromRGB(16, 22, 34),
        PanelTrans      = 0.30,
        PanelLight      = Color3.fromRGB(24, 32, 50),
        PanelLightTrans = 0.38,
        PanelClaro      = Color3.fromRGB(26, 28, 32),
        Row             = Color3.fromRGB(20, 28, 44),
        RowTrans        = 0.35,
        Fila            = Color3.fromRGB(32, 34, 38),
        Input           = Color3.fromRGB(12, 16, 26),
        InputTrans      = 0.22,
        Entrada         = Color3.fromRGB(15, 16, 19),
        Accent          = Color3.fromRGB(0, 165, 255),
        AccentLight     = Color3.fromRGB(65, 195, 255),
        AccentGlow      = Color3.fromRGB(0, 180, 255),
        Highlight       = Color3.fromRGB(140, 220, 255),
        Border          = Color3.fromRGB(40, 65, 100),
        BorderTrans     = 0.40,
        BorderGlow      = Color3.fromRGB(55, 125, 210),
        TextPrimary     = Color3.fromRGB(245, 250, 255),
        TextSecondary   = Color3.fromRGB(175, 195, 220),
        TextMuted       = Color3.fromRGB(115, 135, 160),
        TextAccent      = Color3.fromRGB(65, 195, 255),
        TextCode        = Color3.fromRGB(160, 240, 220),
        Text            = Color3.fromRGB(240, 240, 240),
        TextDark        = Color3.fromRGB(230, 230, 230),
        Success         = Color3.fromRGB(46, 204, 113),
        Warning         = Color3.fromRGB(241, 196, 15),
        Danger          = Color3.fromRGB(235, 75, 75),
        Off             = Color3.fromRGB(45, 58, 80),
        Apagado         = Color3.fromRGB(60, 60, 60),
    },
    Blanco = {
        Background      = Color3.fromRGB(218, 218, 224),
        BackgroundTrans = 0.20,
        BackgroundDark  = Color3.fromRGB(198, 198, 205),
        BackgroundLight = Color3.fromRGB(240, 240, 245),
        Panel           = Color3.fromRGB(252, 252, 254),
        PanelTrans      = 0.25,
        PanelLight      = Color3.fromRGB(240, 240, 244),
        PanelLightTrans = 0.32,
        PanelClaro      = Color3.fromRGB(240, 240, 244),
        Row             = Color3.fromRGB(232, 232, 237),
        RowTrans        = 0.30,
        Fila            = Color3.fromRGB(232, 232, 237),
        Input           = Color3.fromRGB(220, 220, 226),
        InputTrans      = 0.20,
        Entrada         = Color3.fromRGB(220, 220, 226),
        Accent          = Color3.fromRGB(60, 120, 210),
        AccentLight     = Color3.fromRGB(100, 155, 230),
        AccentGlow      = Color3.fromRGB(80, 140, 225),
        Highlight       = Color3.fromRGB(40, 70, 130),
        Border          = Color3.fromRGB(180, 180, 190),
        BorderTrans     = 0.40,
        BorderGlow      = Color3.fromRGB(120, 160, 230),
        TextPrimary     = Color3.fromRGB(25, 25, 30),
        TextSecondary   = Color3.fromRGB(70, 70, 80),
        TextMuted       = Color3.fromRGB(120, 120, 130),
        TextAccent      = Color3.fromRGB(60, 120, 210),
        TextCode        = Color3.fromRGB(30, 80, 150),
        Text            = Color3.fromRGB(25, 25, 30),
        TextDark        = Color3.fromRGB(20, 20, 20),
        Success         = Color3.fromRGB(40, 180, 95),
        Warning         = Color3.fromRGB(220, 160, 10),
        Danger          = Color3.fromRGB(220, 60, 60),
        Off             = Color3.fromRGB(180, 180, 180),
        Apagado         = Color3.fromRGB(180, 180, 180),
    },
    CyberEmerald = {
        Background      = Color3.fromRGB(8, 18, 14),
        BackgroundTrans = 0.26,
        BackgroundDark  = Color3.fromRGB(42, 92, 50),
        BackgroundLight = Color3.fromRGB(72, 145, 82),
        Panel           = Color3.fromRGB(12, 26, 20),
        PanelTrans      = 0.32,
        PanelLight      = Color3.fromRGB(18, 38, 30),
        PanelLightTrans = 0.40,
        PanelClaro      = Color3.fromRGB(32, 52, 36),
        Row             = Color3.fromRGB(16, 32, 25),
        RowTrans        = 0.36,
        Fila            = Color3.fromRGB(28, 46, 31),
        Input           = Color3.fromRGB(9, 20, 15),
        InputTrans      = 0.22,
        Entrada         = Color3.fromRGB(20, 34, 22),
        Accent          = Color3.fromRGB(0, 230, 130),
        AccentLight     = Color3.fromRGB(60, 255, 170),
        AccentGlow      = Color3.fromRGB(20, 240, 145),
        Highlight       = Color3.fromRGB(170, 255, 215),
        Border          = Color3.fromRGB(30, 75, 55),
        BorderTrans     = 0.42,
        BorderGlow      = Color3.fromRGB(40, 145, 95),
        TextPrimary     = Color3.fromRGB(245, 255, 250),
        TextSecondary   = Color3.fromRGB(170, 215, 195),
        TextMuted       = Color3.fromRGB(110, 155, 135),
        TextAccent      = Color3.fromRGB(60, 255, 170),
        TextCode        = Color3.fromRGB(180, 255, 140),
        Text            = Color3.fromRGB(240, 240, 240),
        TextDark        = Color3.fromRGB(230, 230, 230),
        Success         = Color3.fromRGB(46, 204, 113),
        Warning         = Color3.fromRGB(241, 196, 15),
        Danger          = Color3.fromRGB(235, 75, 75),
        Off             = Color3.fromRGB(35, 65, 50),
        Apagado         = Color3.fromRGB(60, 60, 60),
    },
    Morado = {
        Background      = Color3.fromRGB(35, 20, 52),
        BackgroundTrans = 0.28,
        BackgroundDark  = Color3.fromRGB(58, 40, 92),
        BackgroundLight = Color3.fromRGB(98, 72, 145),
        Panel           = Color3.fromRGB(42, 25, 64),
        PanelTrans      = 0.32,
        PanelLight      = Color3.fromRGB(56, 34, 84),
        PanelLightTrans = 0.40,
        PanelClaro      = Color3.fromRGB(34, 27, 46),
        Row             = Color3.fromRGB(48, 30, 72),
        RowTrans        = 0.36,
        Fila            = Color3.fromRGB(30, 24, 42),
        Input           = Color3.fromRGB(26, 16, 40),
        InputTrans      = 0.22,
        Entrada         = Color3.fromRGB(22, 17, 32),
        Accent          = Color3.fromRGB(175, 45, 255),
        AccentLight     = Color3.fromRGB(195, 85, 255),
        AccentGlow      = Color3.fromRGB(185, 65, 255),
        Highlight       = Color3.fromRGB(225, 185, 255),
        Border          = Color3.fromRGB(75, 40, 110),
        BorderTrans     = 0.42,
        BorderGlow      = Color3.fromRGB(160, 80, 240),
        TextPrimary     = Color3.fromRGB(250, 245, 255),
        TextSecondary   = Color3.fromRGB(200, 185, 220),
        TextMuted       = Color3.fromRGB(145, 130, 165),
        TextAccent      = Color3.fromRGB(195, 85, 255),
        TextCode        = Color3.fromRGB(215, 175, 255),
        Text            = Color3.fromRGB(240, 240, 240),
        TextDark        = Color3.fromRGB(230, 230, 230),
        Success         = Color3.fromRGB(46, 204, 113),
        Warning         = Color3.fromRGB(241, 196, 15),
        Danger          = Color3.fromRGB(235, 75, 75),
        Off             = Color3.fromRGB(60, 45, 80),
        Apagado         = Color3.fromRGB(60, 60, 60),
    },
    Rojo = {
        Background      = Color3.fromRGB(45, 15, 15),
        BackgroundTrans = 0.28,
        BackgroundDark  = Color3.fromRGB(164, 45, 40),
        BackgroundLight = Color3.fromRGB(230, 110, 100),
        Panel           = Color3.fromRGB(56, 20, 20),
        PanelTrans      = 0.32,
        PanelLight      = Color3.fromRGB(72, 28, 28),
        PanelLightTrans = 0.40,
        PanelClaro      = Color3.fromRGB(44, 27, 27),
        Row             = Color3.fromRGB(60, 24, 24),
        RowTrans        = 0.36,
        Fila            = Color3.fromRGB(38, 24, 24),
        Input           = Color3.fromRGB(34, 14, 14),
        InputTrans      = 0.22,
        Entrada         = Color3.fromRGB(28, 17, 17),
        Accent          = Color3.fromRGB(235, 60, 60),
        AccentLight     = Color3.fromRGB(255, 95, 95),
        AccentGlow      = Color3.fromRGB(245, 75, 75),
        Highlight       = Color3.fromRGB(255, 180, 180),
        Border          = Color3.fromRGB(100, 35, 35),
        BorderTrans     = 0.42,
        BorderGlow      = Color3.fromRGB(210, 65, 65),
        TextPrimary     = Color3.fromRGB(255, 245, 245),
        TextSecondary   = Color3.fromRGB(220, 185, 185),
        TextMuted       = Color3.fromRGB(165, 130, 130),
        TextAccent      = Color3.fromRGB(255, 95, 95),
        TextCode        = Color3.fromRGB(255, 165, 165),
        Text            = Color3.fromRGB(255, 255, 255),
        TextDark        = Color3.fromRGB(230, 220, 220),
        Success         = Color3.fromRGB(46, 204, 113),
        Warning         = Color3.fromRGB(241, 196, 15),
        Danger          = Color3.fromRGB(235, 75, 75),
        Off             = Color3.fromRGB(75, 40, 40),
        Apagado         = Color3.fromRGB(60, 60, 60),
    }
}

-- Backward compatibility aliases
Themes.Lista.NeonHalloween = Themes.Lista.NeonGlass
Themes.Lista.Negro         = Themes.Lista.MidnightFrosted
Themes.Lista.Verde         = Themes.Lista.CyberEmerald

local Theme = {}
for k, v in pairs(Themes.Lista[Themes.Predeterminado]) do Theme[k] = v end
Theme.Text      = Theme.TextPrimary
Theme.TextDark  = Theme.TextMuted
Theme.Fila      = Theme.Row
Theme.Entrada   = Theme.Input
Theme.Apagado   = Theme.Off
LouisHub.Theme  = Theme

local themeRegistry = {}
function LouisHub:Registrar(instance, prop, key)
    local entry = {instancia = instance, propiedad = prop, claveTema = key}
    table.insert(themeRegistry, entry)
    if typeof(instance) == "Instance" then
        instance.Destroying:Connect(function()
            entry.muerta = true
        end)
    end
end

LouisHub.ThemeManager = { Temas = Themes.Lista }
function LouisHub.ThemeManager:AplicarTema(nameOrTable)
    local tbl = type(nameOrTable) == "string" and self.Temas[nameOrTable] or nameOrTable
    if not tbl then return end
    for k, v in pairs(tbl) do Theme[k] = v end
    Theme.Text     = Theme.TextPrimary
    Theme.TextDark = Theme.TextMuted
    Theme.Fila     = Theme.Row
    Theme.Entrada  = Theme.Input
    Theme.Apagado  = Theme.Off

    for _, entry in ipairs(themeRegistry) do
        if entry.instancia and entry.instancia.Parent and not entry.muerta then
            local val = type(entry.claveTema) == "function" and entry.claveTema() or Theme[entry.claveTema]
            if val ~= nil then
                pcall(function()
                    entry.instancia[entry.propiedad] = val
                end)
            end
        end
    end

    for win in pairs(_registeredThemeWindows) do
        if win._SincronizarSelectorTemas then
            pcall(win._SincronizarSelectorTemas, type(nameOrTable) == "string" and nameOrTable or nil)
        end
    end
    LouisHub.Eventos.TemaCambiado:Fire(type(nameOrTable) == "string" and nameOrTable or "Custom")
end

function LouisHub.ThemeManager:AgregarTema(name, tbl)
    if type(name) == "string" and type(tbl) == "table" then
        self.Temas[name] = tbl
    end
end

function LouisHub.ThemeManager:GuardarTemaActual()
    if not fsAvailable() then return false end
    if LouisHub.SaveManager then
        pcall(function()
            local folder = LouisHub.SaveManager.Carpeta
            local cur = ""
            for part in folder:gmatch("[^/]+") do
                cur = (cur == "") and part or (cur .. "/" .. part)
                if not isfolder(cur) then pcall(makefolder, cur) end
            end
            local data = {}
            for k, v in pairs(Theme) do
                if typeof(v) == "Color3" then data[k] = {v.R, v.G, v.B} end
            end
            writefile(folder .. "/tema.json", HttpService:JSONEncode(data))
        end)
        return true
    end
    return false
end

function LouisHub.ThemeManager:CargarTemaActual()
    if not fsAvailable() or not LouisHub.SaveManager then return false end
    local path = LouisHub.SaveManager.Carpeta .. "/tema.json"
    if not isfile(path) then return false end
    local ok, content = pcall(readfile, path)
    if not ok then return false end
    local okDecode, data = pcall(function() return HttpService:JSONDecode(content) end)
    if not okDecode or type(data) ~= "table" then return false end
    local custom = {}
    for k, v in pairs(data) do
        if type(v) == "table" and #v == 3 then custom[k] = Color3.new(v[1], v[2], v[3]) end
    end
    self:AplicarTema(custom)
    return true
end

-- 18. MOTION CURVES & PHYSICS TWEEN ENGINE
LouisHub.Motion = {
    Directo         = 0,
    Hover           = 0.16,
    Press           = 0.12,
    BouncePop       = 0.28,
    Modal           = 0.32,
    PageSlide       = 0.24,
    Expand          = 0.22,
    HitFloat        = 1.10,
    Spin            = 0.60,
    EaseBounce      = Enum.EasingStyle.Back,
    EaseElastic     = Enum.EasingStyle.Elastic,
    EaseSmooth      = Enum.EasingStyle.Quart,
    EaseOutQuad     = Enum.EasingStyle.Quad,
    EaseInOut       = Enum.EasingStyle.Sine,
    EaseLinear      = Enum.EasingStyle.Linear,
}

local activeTweens = setmetatable({}, {__mode = "k"})
local function getPropKey(props)
    local names = {}
    for name in pairs(props) do table.insert(names, name) end
    table.sort(names)
    return table.concat(names, ",")
end

local Utils = {}
LouisHub.Utils = Utils

function Utils.Tween(obj, props, duration, style, direction)
    if not obj or not obj.Parent then return nil end
    local key = getPropKey(props)
    local perObj = activeTweens[obj]
    local prev = perObj and perObj[key]
    if prev then pcall(function() prev:Cancel() end) end

    if duration == 0 then
        pcall(function()
            for prop, val in pairs(props) do obj[prop] = val end
        end)
        return nil
    end

    local info = TweenInfo.new(duration or LouisHub.Motion.Expand, style or Enum.EasingStyle.Quad, direction or Enum.EasingDirection.Out)
    local ok, tw = pcall(function()
        local t = TweenService:Create(obj, info, props)
        t:Play()
        return t
    end)
    if ok then
        activeTweens[obj] = activeTweens[obj] or {}
        activeTweens[obj][key] = tw
    end
    return ok and tw or nil
end

function Utils.ElasticBounce(visualInstance, scaleDownFactor)
    if not visualInstance or not visualInstance.Parent then return end
    local scale = visualInstance:FindFirstChild("__LouisHub_Scale")
    if not scale then
        scale = Instance.new("UIScale")
        scale.Name = "__LouisHub_Scale"
        scale.Scale = 1
        scale.Parent = visualInstance
    end
    scale.Scale = scaleDownFactor or 0.94
    Utils.Tween(scale, {Scale = 1.02}, LouisHub.Motion.Press, LouisHub.Motion.EaseBounce, Enum.EasingDirection.Out)
    task.delay(LouisHub.Motion.Press, function()
        if scale and scale.Parent then
            Utils.Tween(scale, {Scale = 1}, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
    end)
end

local activeNumberTweens = setmetatable({}, {__mode = "k"})
function Utils.TweenNumero(from, to, duration, callback, style, direction, key)
    if type(callback) ~= "function" then return end
    if from == to then callback(to); return end

    local k = key or callback
    local prev = activeNumberTweens[k]
    if prev then
        pcall(function() prev.tween:Cancel() end)
        pcall(function() prev.valor:Destroy() end)
    end

    local valObj = Instance.new("NumberValue")
    valObj.Value = from
    local conn = valObj:GetPropertyChangedSignal("Value"):Connect(function()
        pcall(callback, valObj.Value)
    end)

    local info = TweenInfo.new(duration or 0.22, style or LouisHub.Motion.EaseSmooth, direction or Enum.EasingDirection.Out)
    local ok, tw = pcall(function() return TweenService:Create(valObj, info, {Value = to}) end)
    if not ok then
        conn:Disconnect()
        valObj:Destroy()
        callback(to)
        return
    end

    local rec = {tween = tw, valor = valObj}
    activeNumberTweens[k] = rec
    tw:Play()
    tw.Completed:Connect(function()
        conn:Disconnect()
        valObj:Destroy()
        if activeNumberTweens[k] == rec then activeNumberTweens[k] = nil end
    end)
end

function Utils.GradienteAnimado(inst, colorSeq, rotationSpeed)
    local grad = Instance.new("UIGradient")
    grad.Color = colorSeq or ColorSequence.new(Theme.Accent, Theme.AccentLight)
    grad.Rotation = 0
    grad.Parent = inst

    local conn = RunService.RenderStepped:Connect(function(dt)
        if not (grad and grad.Parent) then return end
        grad.Rotation = (grad.Rotation + (rotationSpeed or 45) * dt) % 360
    end)

    inst.Destroying:Connect(function()
        conn:Disconnect()
    end)
    return grad
end

function Utils.GradienteAcento(inst, intensity)
    intensity = intensity or 0.14
    local function getSeq()
        local base = Theme.Accent
        local light = base:Lerp(Color3.new(1, 1, 1), intensity)
        return ColorSequence.new(base, light)
    end
    local grad = Instance.new("UIGradient")
    grad.Color = getSeq()
    grad.Parent = inst
    LouisHub:Registrar(grad, "Color", getSeq)
    return grad
end

function Utils.SheenEffect(inst)
    local grad = Instance.new("UIGradient")
    grad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
        ColorSequenceKeypoint.new(0.5, Color3.new(1, 1, 1)),
        ColorSequenceKeypoint.new(1, Color3.new(1, 1, 1)),
    })
    grad.Transparency = NumberSequence.new({
        NumberSequenceKeypoint.new(0, 1),
        NumberSequenceKeypoint.new(0.5, 0.4),
        NumberSequenceKeypoint.new(1, 1),
    })
    grad.Offset = Vector2.new(-1, 0)
    grad.Rotation = 30
    grad.Parent = inst

    local function runShine()
        grad.Offset = Vector2.new(-1, 0)
        Utils.Tween(grad, {Offset = Vector2.new(1, 0)}, 0.75, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
    end
    return runShine
end

-- 19. TYPOGRAPHY SYSTEM
LouisHub.Typography = {
    Title    = { Font = Enum.Font.FredokaOne, BaseSize = 15 },
    Subtitle = { Font = Enum.Font.GothamBold, BaseSize = 13 },
    Body     = { Font = Enum.Font.Ubuntu,     BaseSize = 12 },
    Code     = { Font = Enum.Font.RobotoMono, BaseSize = 11 },
    Badge    = { Font = Enum.Font.FredokaOne, BaseSize = 9 },
}

-- Export Shared Bridge References for Parts 2 to 6 (PRE-PATCHED)
LouisHub._Internal.Themes                       = Themes
LouisHub._Internal.detectExecutor               = detectExecutor
LouisHub._Internal.cleanPreviousInstance        = cleanPreviousInstance
LouisHub._Internal.createInstanceRecord         = createInstanceRecord
LouisHub._Internal.getGuiParent                 = getGuiParent
LouisHub._Internal.protectGuiObject             = protectGuiObject
LouisHub._Internal.fsAvailable                  = fsAvailable
LouisHub._Internal.packFlags                    = packFlags
LouisHub._Internal.unpackFlagValue              = unpackFlagValue
LouisHub._Internal.prepareLoadedData            = prepareLoadedData
LouisHub._Internal.decomposeKey                 = decomposeKey
LouisHub._Internal.formatKeyText                = formatKeyText
LouisHub._Internal.keysConflict                 = keysConflict
LouisHub._Internal.checkKeybindConflict         = checkKeybindConflict
LouisHub._Internal.checkKeybindConflictsOnLoad  = checkKeybindConflictsOnLoad
LouisHub._Internal.executeCallback              = executeCallback
LouisHub._Internal.registeredKeybinds           = _registeredKeybinds
LouisHub._Internal.registeredThemeWindows       = _registeredThemeWindows
LouisHub._Internal.realFlags                    = _realFlags
LouisHub._Internal.nonPersistentFlags           = _nonPersistentFlags
LouisHub._Internal.uiFlags                      = _uiFlags
LouisHub._Internal.activeSaveWindow             = activeSaveWindow
LouisHub._Internal.themeRegistry                = themeRegistry
LouisHub._Internal.applyTextScale               = applyTextScale
LouisHub._Internal.startAutoSaveLoop            = startAutoSaveLoop
LouisHub._Internal.stopAutoSaveLoop             = function() autoSaveLoopRunning = false end

-- ===================================================================
--  LOUIS HUB UI LIBRARY (V3.0 NEXT-GEN COMPLETE ENGINE)
--  Brand: Louis Hub
--  Priority: Zero-Leaks > Backward Compatibility > Glassmorphism > Performance
--  [PART 2 OF 6] - Visual Primitives, Scaled Drag, Fixed Tooltips, Lock & Modals
-- ===================================================================

local _Internal        = LouisHub._Internal
local Theme            = LouisHub.Theme
local Utils            = LouisHub.Utils
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TextService      = game:GetService("TextService")

-- 1. INSTANCE COUNTER & METRICS TRACKER
local _uiInstanceCounter = 0
local function countCreatedInstance(inst)
    _uiInstanceCounter = _uiInstanceCounter + 1
    inst.Destroying:Connect(function()
        _uiInstanceCounter = math.max(0, _uiInstanceCounter - 1)
    end)
    return inst
end
_Internal.countCreatedInstance = countCreatedInstance
_Internal.getUIInstanceCount   = function() return _uiInstanceCounter end

-- 2. CUMULATIVE UISCALE CALCULATION (Fixes Pointer Lag on Scaled Screens / Mobile)
function Utils.FactorEscalaUI(inst)
    local factor = 1
    local current = inst
    while current do
        if current:IsA("UIScale") then
            factor = factor * current.Scale
        end
        current = current.Parent
    end
    return (factor > 0) and factor or 1
end

-- ===================================================================
--  VISUAL PRIMITIVES (GLASSMORPHISM, BORDERS & SHADOW GLOWS)
-- ===================================================================

function Utils.Corner(parent, radius)
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, radius or 8)
    corner.Parent = parent
    return corner
end

function Utils.Stroke(parent, color, thickness, transparency)
    local stroke = Instance.new("UIStroke")
    stroke.Color = color or Theme.Border
    stroke.Thickness = thickness or 1
    stroke.Transparency = transparency or (Theme.BorderTrans or 0.45)
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end

function Utils.GlowStroke(parent, glowColor, thickness)
    local stroke = Instance.new("UIStroke")
    stroke.Color = glowColor or Theme.BorderGlow
    stroke.Thickness = thickness or 1.2
    stroke.Transparency = 0.55
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Parent = parent
    return stroke
end

-- Glassmorphic Non-Solid Frame Primitive (Anti-Overflow by Default)
function Utils.Frame(cfg)
    cfg = cfg or {}
    local frame = Instance.new("Frame")
    countCreatedInstance(frame)
    frame.Size = cfg.Size or UDim2.new(1, 0, 0, cfg.Alto or 28)
    frame.Position = cfg.Posicion or UDim2.new(0, 0, 0, 0)
    if cfg.Ancla then frame.AnchorPoint = cfg.Ancla end

    -- Non-Solid Translucent Glass Surface
    frame.BackgroundColor3 = cfg.Color or Theme.Panel
    frame.BackgroundTransparency = cfg.Transparencia or (Theme.PanelTrans or 0.32)
    frame.BorderSizePixel = 0
    frame.ClipsDescendants = cfg.Recortar ~= false -- Anti-Bocor Default (Strict Clipping)
    frame.LayoutOrder = cfg.Orden or 0
    if cfg.Visible ~= nil then frame.Visible = cfg.Visible end
    frame.Parent = cfg.Padre

    if cfg.Radio ~= false then
        Utils.Corner(frame, cfg.Radio or 8)
    end

    if cfg.Borde ~= false then
        local st = Utils.Stroke(frame, cfg.ColorBorde or Theme.Border, cfg.GrosorBorde or 1, cfg.TransparenciaBorde or Theme.BorderTrans)
        if cfg.ClaveTemaBorde then
            LouisHub:Registrar(st, "Color", cfg.ClaveTemaBorde)
        end
    end

    if cfg.ClaveTema then
        LouisHub:Registrar(frame, "BackgroundColor3", cfg.ClaveTema)
    end
    return frame
end

function Utils.Fila(parent, height, order, color)
    return Utils.Frame({
        Padre = parent,
        Size = UDim2.new(1, 0, 0, height or 32),
        Orden = order or 0,
        Color = color or Theme.Row,
        Transparencia = Theme.RowTrans or 0.38,
        Radio = 8,
        Recortar = true, -- Ensures elements within rows never bleed outside
    })
end

-- Typography Variants Label Builder (Title, Subtitle, Body, Code, Badge)
function Utils.Texto(cfg)
    cfg = cfg or {}
    local label = Instance.new("TextLabel")
    countCreatedInstance(label)
    label.BackgroundTransparency = 1
    label.Size = cfg.Size or UDim2.new(1, -12, 1, 0)
    label.Position = cfg.Posicion or UDim2.new(0, 8, 0, 0)

    local variantName = cfg.Variante or "Body"
    local variant = LouisHub.Typography[variantName] or LouisHub.Typography.Body
    label.Font = cfg.Fuente or variant.Font
    local baseSize = cfg.Tamano or variant.BaseSize
    label.TextSize = baseSize

    label.TextColor3 = cfg.Color or (variantName == "Title" and Theme.TextPrimary or (variantName == "Code" and Theme.TextCode or (variantName == "Badge" and Theme.TextAccent or Theme.TextSecondary)))
    label.TextXAlignment = cfg.Alineacion or Enum.TextXAlignment.Left
    label.TextTruncate = cfg.Truncar and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None
    label.TextWrapped = cfg.Ajustar or false
    label.TextTransparency = cfg.TextoTransparencia or 0
    label.RichText = cfg.RichText or false
    label.Text = cfg.Texto or ""
    label.LayoutOrder = cfg.Orden or 0
    label.Parent = cfg.Padre

    if cfg.ColorTema then
        LouisHub:Registrar(label, "TextColor3", cfg.ColorTema)
    elseif not cfg.Color then
        LouisHub:Registrar(label, "TextColor3", variantName == "Title" and "TextPrimary" or "TextSecondary")
    end

    _Internal.registerTextScale(label, baseSize, cfg.Categoria or "general", cfg.Truncar)
    return label
end

function Utils.BotonBase(cfg)
    cfg = cfg or {}
    local btn = Instance.new("TextButton")
    countCreatedInstance(btn)
    btn.Size = cfg.Size or UDim2.new(1, 0, 0, cfg.Alto or 28)
    btn.Position = cfg.Posicion or UDim2.new(0, 0, 0, 0)
    if cfg.Ancla then btn.AnchorPoint = cfg.Ancla end
    btn.BackgroundTransparency = cfg.Transparencia == nil and 0.38 or cfg.Transparencia
    btn.BackgroundColor3 = cfg.Color or Theme.Row
    btn.AutoButtonColor = false
    btn.Text = ""
    btn.BorderSizePixel = 0
    btn.ClipsDescendants = cfg.Recortar ~= false
    btn.LayoutOrder = cfg.Orden or 0
    btn.Parent = cfg.Padre
    if cfg.Radio ~= false then
        Utils.Corner(btn, cfg.Radio or 8)
    end
    return btn
end

function Utils.HitboxAmpliado(btn, padding)
    padding = padding or 0
    if padding <= 0 or not btn then return btn end
    local hb = Utils.BotonBase({
        Padre = btn,
        Size = UDim2.new(1, padding * 2, 1, padding * 2),
        Posicion = UDim2.new(0, -padding, 0, -padding),
        Transparencia = 1,
        Radio = false,
    })
    hb.ZIndex = btn.ZIndex + 1
    return hb
end

function Utils.Diferir(fn)
    local pending = false
    return function(...)
        if pending then return end
        pending = true
        local args = {...}
        task.delay(0.03, function()
            pending = false
            fn(table.unpack(args))
        end)
    end
end

-- Dynamic Row Height Calculation with Scale Factor Compensation
function Utils.HacerFilaDinamica(fila, lbl, minH, padY)
    padY = padY or 7
    lbl.TextWrapped   = true
    lbl.TextTruncate  = Enum.TextTruncate.None
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.AnchorPoint   = Vector2.new(0, 0.5)
    lbl.Position = UDim2.new(lbl.Position.X.Scale, lbl.Position.X.Offset, 0.5, 0)
    lbl.Size     = UDim2.new(lbl.Size.X.Scale, lbl.Size.X.Offset, 0, 0)

    local function recalc()
        if not (fila.Parent and lbl.Parent) then return end
        local h = lbl.AbsoluteSize.Y
        if h <= 0 then return end
        local targetH = math.max(minH, math.ceil(h / Utils.FactorEscalaUI(lbl)) + padY * 2)
        if fila.Size.Y.Offset ~= targetH then
            fila.Size = UDim2.new(fila.Size.X.Scale, fila.Size.X.Offset, 0, targetH)
        end
    end
    LouisHub:RegistrarConexion(lbl:GetPropertyChangedSignal("AbsoluteSize"):Connect(Utils.Diferir(recalc)))
    task.defer(recalc)
end

-- ===================================================================
--  SCALED DRAG & LEAK-FREE INTERACTION ENGINES
-- ===================================================================

-- Precise UIScale-Compensated Drag Engine
function Utils.Arrastrable(trigger, target, eventMgr)
    local dragging = false
    local startDrag, startTarget

    trigger.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            startDrag = Vector2.new(input.Position.X, input.Position.Y)
            startTarget = target.Position

            local conn
            conn = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                    if eventMgr then eventMgr:DetenerArrastre() end
                    if conn then conn:Disconnect(); conn = nil end
                end
            end)
            LouisHub:RegistrarConexion(conn)

            if eventMgr then
                eventMgr:Arrastrar(function(inp)
                    if not dragging then return end
                    local currentScale = Utils.FactorEscalaUI(target)
                    local delta = (Vector2.new(inp.Position.X, inp.Position.Y) - startDrag) / currentScale
                    target.Position = UDim2.new(
                        startTarget.X.Scale, startTarget.X.Offset + delta.X,
                        startTarget.Y.Scale, startTarget.Y.Offset + delta.Y
                    )
                end)
            end
        end
    end)
end

-- Leak-Free Hover Engine (Self-cleaning on Instance destruction)
function Utils.Hover(eventObj, colorObj, intensity, duration, getBaseColor)
    if not eventObj or not colorObj then return end
    colorObj = colorObj or eventObj
    intensity = intensity or 0.18
    duration = duration or LouisHub.Motion.Hover

    local isHovered = false
    local colorOriginal = nil

    local connEnter = eventObj.MouseEnter:Connect(function()
        if isHovered then return end
        isHovered = true
        pcall(function()
            local base = getBaseColor and getBaseColor() or colorObj.BackgroundColor3
            colorOriginal = base
            Utils.Tween(colorObj, {
                BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), intensity)
            }, duration, LouisHub.Motion.EaseInOut, Enum.EasingDirection.Out)
        end)
    end)

    local connLeave = eventObj.MouseLeave:Connect(function()
        if not isHovered then return end
        isHovered = false
        pcall(function()
            local dest = getBaseColor and getBaseColor() or colorOriginal
            if dest then
                Utils.Tween(colorObj, {BackgroundColor3 = dest}, duration, LouisHub.Motion.EaseInOut, Enum.EasingDirection.Out)
            end
        end)
        colorOriginal = nil
    end)

    eventObj.Destroying:Connect(function()
        connEnter:Disconnect()
        connLeave:Disconnect()
    end)
end

-- Reliable Click Engine with Distance Threshold (Prevents misclicks when scrolling)
function Utils.ClickConfiable(obj, callback, visual)
    local threshold = (LouisHub.Capacidades and LouisHub.Capacidades.EsTactil) and 16 or 8
    local downPos = nil

    local connDown = obj.MouseButton1Down:Connect(function(x, y)
        downPos = Vector2.new(x, y)
        Utils.ElasticBounce(visual or obj, 0.96)
    end)

    local connUp = obj.MouseButton1Up:Connect(function(x, y)
        if not downPos then return end
        local dist = (Vector2.new(x, y) - downPos).Magnitude
        downPos = nil
        if dist > threshold then return end
        callback()
    end)

    obj.Destroying:Connect(function()
        connDown:Disconnect()
        connUp:Disconnect()
    end)
end

function Utils.FlashFeedback(instance, success, normalColor)
    if not instance or not instance.Parent then return end
    local flashCol = success and Theme.Success or Theme.Danger
    pcall(function()
        Utils.Tween(instance, {BackgroundColor3 = flashCol}, 0.08)
        task.delay(0.08, function()
            pcall(function()
                Utils.Tween(instance, {BackgroundColor3 = normalColor}, 0.28)
            end)
        end)
    end)
end

-- Visual Transitions from V2
function Utils.FundirEntrada(root, duration, includeRoot)
    local targets = {}
    local function reg(inst)
        if inst:IsA("GuiObject") then
            if inst.BackgroundTransparency < 0.99 then table.insert(targets, {inst, "BackgroundTransparency", inst.BackgroundTransparency}) end
            if (inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox")) and inst.TextTransparency < 0.99 then
                table.insert(targets, {inst, "TextTransparency", inst.TextTransparency})
            end
            if (inst:IsA("ImageLabel") or inst:IsA("ImageButton")) and inst.ImageTransparency < 0.99 then
                table.insert(targets, {inst, "ImageTransparency", inst.ImageTransparency})
            end
        elseif inst:IsA("UIStroke") and inst.Transparency < 0.99 then
            table.insert(targets, {inst, "Transparency", inst.Transparency})
        end
    end
    if includeRoot then reg(root) end
    for _, d in ipairs(root:GetDescendants()) do reg(d) end
    for _, o in ipairs(targets) do o[1][o[2]] = 1 end
    for _, o in ipairs(targets) do Utils.Tween(o[1], {[o[2]] = o[3]}, duration or LouisHub.Motion.Expand, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
end

function Utils.AnimarInsercion(frame, axis)
    if not (frame and frame.Parent) then return end
    local finalSize = frame.Size
    local origClip = frame.ClipsDescendants
    frame.ClipsDescendants = true
    if axis == "x" then
        frame.Size = UDim2.new(finalSize.X.Scale, 0, finalSize.Y.Scale, finalSize.Y.Offset)
    else
        frame.Size = UDim2.new(finalSize.X.Scale, finalSize.X.Offset, finalSize.Y.Scale, 0)
    end
    Utils.FundirEntrada(frame, LouisHub.Motion.Expand, false)
    Utils.Tween(frame, {Size = finalSize}, LouisHub.Motion.Expand, LouisHub.Motion.EaseSmooth, Enum.EasingDirection.Out)
    task.delay(LouisHub.Motion.Expand + 0.05, function()
        if frame.Parent then frame.Size = finalSize; frame.ClipsDescendants = origClip end
    end)
end

function Utils.EntradaModal(backdrop, card)
    local origTrans = backdrop.BackgroundTransparency
    backdrop.BackgroundTransparency = 1
    local sc = Instance.new("UIScale", card)
    sc.Scale = 0.95
    Utils.FundirEntrada(card, LouisHub.Motion.Modal, true)
    Utils.Tween(backdrop, {BackgroundTransparency = origTrans}, LouisHub.Motion.Expand, LouisHub.Motion.EaseSmooth, Enum.EasingDirection.Out)
    Utils.Tween(sc, {Scale = 1}, LouisHub.Motion.Modal, LouisHub.Motion.EaseBounce, Enum.EasingDirection.Out)
end

function Utils.IconoImagen(padre, asset, color, tamano, posicion)
    local img = Instance.new("ImageLabel")
    img.BackgroundTransparency = 1
    img.BorderSizePixel = 0
    img.Image = asset
    img.ImageColor3 = color or Color3.new(1, 1, 1)
    img.ScaleType = Enum.ScaleType.Fit
    img.Size = UDim2.new(0, tamano, 0, tamano)
    img.AnchorPoint = Vector2.new(0.5, 0.5)
    img.Position = posicion
    img.Parent = padre
    return img
end

-- ===================================================================
--  LOCK OVERLAY & ROW BLOCK SYSTEM (WITH SHAKE ANIMATION)
-- ===================================================================
function Utils.EnvolverInstancia(inst)
    local proxy = setmetatable({}, {
        __index = function(_, k)
            local ok, val = pcall(function() return inst[k] end)
            if not ok then return nil end
            if type(val) == "function" then return function(_, ...) return val(inst, ...) end end
            return val
        end,
        __newindex = function(_, k, v) inst[k] = v end,
    })
    rawset(proxy, "Instancia", inst)
    rawset(proxy, "__isElement", true)
    return proxy
end

function Utils.AnexarBloqueo(elem, row)
    local overlay, lblMotivo, insignia
    local bloqueado, motivo = false, nil
    local POS_INSIGNIA = UDim2.new(1, -8, 0.5, 0)
    local tokenSacudida = 0
    rawset(elem, "Fila", row)
    rawset(elem, "__isElement", true)
    local trazo, tokenResaltado = nil, 0

    local function sinSelf(a, b) return (a == elem) and b or a end
    local function refrescarTexto()
        if lblMotivo then lblMotivo.Text = "🔒 " .. (motivo and motivo ~= "" and motivo or "Locked") end
    end

    local function asegurarOverlay()
        if overlay and overlay.Parent then return end
        overlay = Instance.new("TextButton")
        overlay.Name = "LouisHub_Locked"
        overlay.Size = UDim2.new(1, 0, 1, 0)
        overlay.BackgroundColor3 = Theme.Background
        overlay.BackgroundTransparency = 0.35
        overlay.BorderSizePixel = 0
        overlay.AutoButtonColor = false
        overlay.Text = ""
        overlay.ZIndex = 100
        overlay.Visible = false
        overlay.Parent = row

        local corner = row:FindFirstChildOfClass("UICorner")
        if corner then Utils.Corner(overlay, corner.CornerRadius.Offset) end
        LouisHub:Registrar(overlay, "BackgroundColor3", "Background")

        insignia = Utils.Frame({
            Padre = overlay,
            Size = UDim2.new(0.55, -8, 0, 24),
            Posicion = POS_INSIGNIA,
            Ancla = Vector2.new(1, 0.5),
            Color = Theme.Panel,
            Transparencia = 0.2,
            Radio = 6,
        })
        insignia.ZIndex = 101
        LouisHub:Registrar(insignia, "BackgroundColor3", "Panel")

        lblMotivo = Utils.Texto({
            Padre = insignia,
            Texto = "",
            Size = UDim2.new(1, -12, 1, 0),
            Posicion = UDim2.new(0, 6, 0, 0),
            Alineacion = Enum.TextXAlignment.Center,
            Variante = "Body",
            Tamano = 11,
            Truncar = true,
        })
        lblMotivo.ZIndex = 102

        Utils.ClickConfiable(overlay, function()
            if not (insignia and insignia.Parent) then return end
            tokenSacudida = tokenSacudida + 1
            local myToken = tokenSacudida
            Utils.FlashFeedback(insignia, false, Theme.Panel)
            task.spawn(function()
                for _, dx in ipairs({-3, 3, -3, 3, 0}) do
                    if tokenSacudida ~= myToken or not (insignia and insignia.Parent) then return end
                    Utils.Tween(insignia, {
                        Position = UDim2.new(POS_INSIGNIA.X.Scale, POS_INSIGNIA.X.Offset + dx, POS_INSIGNIA.Y.Scale, POS_INSIGNIA.Y.Offset),
                    }, 0.05, LouisHub.Motion.EaseInOut, Enum.EasingDirection.InOut)
                    task.wait(0.05)
                end
            end)
        end, insignia)
    end

    local function bloquear(nuevoMotivo, animar)
        local yaBloqueado = bloqueado
        motivo = nuevoMotivo
        asegurarOverlay()
        refrescarTexto()
        overlay.Visible = true
        bloqueado = true
        if animar and not yaBloqueado and row.AbsoluteSize.X > 0 then
            overlay.BackgroundTransparency = 1
            insignia.BackgroundTransparency = 1
            lblMotivo.TextTransparency = 1
            insignia.Position = UDim2.new(POS_INSIGNIA.X.Scale, POS_INSIGNIA.X.Offset + 24, POS_INSIGNIA.Y.Scale, POS_INSIGNIA.Y.Offset)
            Utils.Tween(overlay, {BackgroundTransparency = 0.35}, LouisHub.Motion.Expand)
            Utils.Tween(insignia, {BackgroundTransparency = 0.2, Position = POS_INSIGNIA}, LouisHub.Motion.Expand, LouisHub.Motion.EaseBounce)
            Utils.Tween(lblMotivo, {TextTransparency = 0}, LouisHub.Motion.Expand)
        end
    end

    rawset(elem, "Lock", function(a, b) bloquear(sinSelf(a, b), true) end)
    rawset(elem, "Unlock", function()
        bloqueado = false
        if overlay then overlay.Visible = false end
    end)
    rawset(elem, "IsLocked", function() return bloqueado end)
    rawset(elem, "SetLockedTitle", function(a, b) motivo = sinSelf(a, b); refrescarTexto() end)
    rawset(elem, "Highlight", function(a, b)
        local opts = sinSelf(a, b)
        local dur = (type(opts) == "number" and opts) or (type(opts) == "table" and opts.Duracion) or 2
        dur = math.clamp(dur, 0.5, 10)
        tokenResaltado = tokenResaltado + 1
        local myToken = tokenResaltado
        if trazo then trazo:Destroy() end
        trazo = Instance.new("UIStroke")
        trazo.Thickness = 2
        trazo.Color = Theme.AccentLight
        trazo.Transparency = 1
        trazo.Parent = row

        local tw = TweenService:Create(trazo, TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, math.floor(dur / 0.8), true), {Transparency = 0})
        tw:Play()
        task.delay(dur + 0.2, function()
            if trazo and trazo.Parent then trazo:Destroy() end
            if tokenResaltado == myToken then trazo = nil end
        end)
    end)
    return function(initMotivo) bloquear(initMotivo, false) end
end

function Utils.EnvolverControlBloqueable(Seccion, container, name)
    local orig = Seccion[name]
    if type(orig) ~= "function" then return end
    Seccion[name] = function(self, cfg)
        local prev = {}
        for _, c in ipairs(container:GetChildren()) do prev[c] = true end
        local res = orig(self, cfg)
        local row
        for _, c in ipairs(container:GetChildren()) do
            if not prev[c] and c:IsA("GuiObject") and (not row or c.LayoutOrder > row.LayoutOrder) then row = c end
        end
        if not row then return res end
        local elem = (typeof(res) == "Instance") and Utils.EnvolverInstancia(res) or res
        if type(elem) ~= "table" then return res end
        local lockFn = Utils.AnexarBloqueo(elem, row)
        if type(cfg) == "table" and cfg.Locked then lockFn(cfg.LockedTitle) end
        return elem
    end
end

-- Row Description Accordion Expander
function Utils.AnexarDescripcion(row, parent, order, text, zoneWidth)
    local panel = Utils.Frame({
        Padre = parent,
        Size = UDim2.new(1, 0, 0, 0),
        Color = Theme.Row,
        Transparencia = Theme.RowTrans or 0.38,
        Orden = order,
        Radio = 8,
    })
    panel.AutomaticSize = Enum.AutomaticSize.Y
    panel.Visible = false
    LouisHub:Registrar(panel, "BackgroundColor3", "Row")

    local pad = Instance.new("UIPadding", panel)
    pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
    pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 26), UDim.new(0, 12)

    local lblDesc = Utils.Texto({
        Padre = panel,
        Texto = tostring(text),
        Size = UDim2.new(1, 0, 0, 0),
        Ajustar = true,
        Variante = "Body",
        ColorTema = "TextMuted",
    })
    lblDesc.AutomaticSize = Enum.AutomaticSize.Y

    local zone = Utils.BotonBase({
        Padre = row,
        Size = zoneWidth or UDim2.new(1, 0, 1, 0),
        Color = Theme.Row,
        Transparencia = 1,
        Radio = 8,
    })
    local arrow = Instance.new("ImageLabel", row)
    arrow.BackgroundTransparency = 1
    arrow.Image = "rbxassetid://83472139709682"
    arrow.ScaleType = Enum.ScaleType.Fit
    arrow.Size = UDim2.new(0, 10, 0, 10)
    arrow.AnchorPoint = Vector2.new(0.5, 0.5)
    arrow.Position = UDim2.new(0, 14, 0.5, 0)
    arrow.Rotation = -90
    LouisHub:Registrar(arrow, "ImageColor3", "TextSecondary")

    Utils.ClickConfiable(zone, function()
        panel.Visible = not panel.Visible
        Utils.Tween(arrow, {Rotation = panel.Visible and 0 or -90}, LouisHub.Motion.Expand)
    end)
    return panel
end

-- ===================================================================
--  REDESIGNED MINIMALIST TOOLTIP SYSTEM (ANTI-OBSCURING BADGE)
-- ===================================================================
local overlayGui, panelAyuda, lblAyuda, conexionCierreGlobal
local _tooltipBlockedByGesture = false

local function obtenerOverlayTooltip()
    if overlayGui and overlayGui.Parent then return overlayGui end
    overlayGui = Instance.new("ScreenGui")
    overlayGui.Name = "LouisHub_TooltipOverlay"
    overlayGui.ResetOnSpawn = false
    overlayGui.IgnoreGuiInset = true
    overlayGui.DisplayOrder = 999
    pcall(function() overlayGui.Parent = _Internal.getGuiParent() end)
    _Internal.protectGuiObject(overlayGui)

    panelAyuda = Instance.new("Frame")
    panelAyuda.Name = "PanelAyuda"
    panelAyuda.BackgroundColor3 = Theme.Panel
    panelAyuda.BackgroundTransparency = 0.15
    panelAyuda.BorderSizePixel = 0
    panelAyuda.Visible = false
    panelAyuda.ZIndex = 1000
    panelAyuda.Size = UDim2.new(0, 210, 0, 0)
    panelAyuda.AutomaticSize = Enum.AutomaticSize.Y
    panelAyuda.ClipsDescendants = true
    panelAyuda.Parent = overlayGui
    LouisHub:Registrar(panelAyuda, "BackgroundColor3", "Panel")
    Utils.Corner(panelAyuda, 8)

    local strokeTooltip = Utils.Stroke(panelAyuda, Theme.BorderGlow, 1.2, 0.3)
    LouisHub:Registrar(strokeTooltip, "Color", "BorderGlow")

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, 10)
    pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
    pad.Parent = panelAyuda

    lblAyuda = Utils.Texto({
        Padre = panelAyuda,
        Texto = "",
        Variante = "Body",
        Size = UDim2.new(1, 0, 0, 0),
        Ajustar = true,
    })
    lblAyuda.AutomaticSize = Enum.AutomaticSize.Y
    lblAyuda.ZIndex = 1001
    return overlayGui
end

local function cerrarTooltipGlobal()
    if panelAyuda then panelAyuda.Visible = false end
    if conexionCierreGlobal then
        conexionCierreGlobal:Disconnect()
        conexionCierreGlobal = nil
    end
end

local function mostrarTooltipEn(elemRef, textHelp)
    if _tooltipBlockedByGesture then return end
    obtenerOverlayTooltip()
    if panelAyuda.Visible and lblAyuda.Text == textHelp then
        cerrarTooltipGlobal()
        return
    end
    cerrarTooltipGlobal()

    lblAyuda.Text = textHelp
    panelAyuda.Size = UDim2.new(0, 210, 0, 0)

    local pos = elemRef.AbsolutePosition
    local tam = elemRef.AbsoluteSize
    local x = pos.X
    local y = pos.Y + tam.Y + 6
    local scrW = overlayGui.AbsoluteSize.X
    if scrW > 0 then x = math.min(x, scrW - 220) end
    panelAyuda.Position = UDim2.new(0, math.max(6, x), 0, y)
    panelAyuda.Visible = true

    local escalaTip = panelAyuda:FindFirstChild("__LouisHub_TooltipScale") or Instance.new("UIScale", panelAyuda)
    escalaTip.Name = "__LouisHub_TooltipScale"
    escalaTip.Scale = 0.92
    Utils.Tween(escalaTip, {Scale = 1}, LouisHub.Motion.BouncePop, LouisHub.Motion.EaseBounce, Enum.EasingDirection.Out)

    conexionCierreGlobal = UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            cerrarTooltipGlobal()
        end
    end)
end

-- Requirement 4 Solved: High-contrast, clean ring badge where '?' is never obscured
local function agregarTooltip(row, pos, textHelp)
    if not textHelp then return end
    local btnInfo = Utils.BotonBase({
        Padre = row,
        Size = UDim2.new(0, 18, 0, 18),
        Posicion = pos,
        Color = Theme.PanelLight,
        Transparencia = 0.45, -- Subtle translucent ring surface
        Radio = 9,
    })
    btnInfo.ZIndex = 5
    LouisHub:Registrar(btnInfo, "BackgroundColor3", "PanelLight")

    local strokeBadge = Utils.Stroke(btnInfo, Theme.BorderGlow, 1, 0.45)
    LouisHub:Registrar(strokeBadge, "Color", "BorderGlow")

    local lblSigno = Instance.new("TextLabel")
    lblSigno.BackgroundTransparency = 1
    lblSigno.Size = UDim2.new(1, 0, 1, 0)
    lblSigno.AnchorPoint = Vector2.new(0.5, 0.5)
    lblSigno.Position = UDim2.new(0.5, 0, 0.5, 0)
    lblSigno.Font = Enum.Font.FredokaOne
    lblSigno.TextSize = 11
    lblSigno.TextColor3 = Theme.TextAccent
    lblSigno.Text = "?"
    lblSigno.TextXAlignment = Enum.TextXAlignment.Center
    lblSigno.TextYAlignment = Enum.TextYAlignment.Center
    lblSigno.Parent = btnInfo
    LouisHub:Registrar(lblSigno, "TextColor3", "TextAccent")

    Utils.Hover(btnInfo, btnInfo, 0.25)
    btnInfo.MouseButton1Click:Connect(function()
        mostrarTooltipEn(btnInfo, textHelp)
    end)
    return btnInfo
end

local function agregarTooltipTexto(row, textLabel, textHelp, lblInst, offsetRight)
    if not textHelp then return end
    if not (lblInst and lblInst.Size) then
        return agregarTooltip(row, UDim2.new(0, 160, 0, 8), textHelp)
    end

    local TAM_INFO = 18
    local RESERVA  = TAM_INFO + 10
    local sx = lblInst.Size.X.Scale
    local ox = offsetRight or lblInst.Size.X.Offset
    local px = lblInst.Position.X.Offset
    lblInst.Size = UDim2.new(sx, ox - RESERVA - px, lblInst.Size.Y.Scale, lblInst.Size.Y.Offset)

    local xInfo = ox - TAM_INFO - 4
    local btnInfo = agregarTooltip(row, UDim2.new(sx, xInfo, 0.5, -9), textHelp)
    return btnInfo
end

_Internal.agregarTooltip = agregarTooltip
_Internal.agregarTooltipTexto = agregarTooltipTexto
_Internal.setTooltipGestureBlock = function(state)
    _tooltipBlockedByGesture = state
end

-- ===================================================================
--  AUTO-UPDATE LABELS & CONDITIONAL VISIBILITY ENGINE
-- ===================================================================
local _labelsAutoActualizables = setmetatable({}, {__mode = "k"})
local registroVisibilidad       = setmetatable({}, {__mode = "k"})

if type(_G.LouisHub_ConexionesModulo) == "table" then
    for _, c in ipairs(_G.LouisHub_ConexionesModulo) do pcall(function() c:Disconnect() end) end
end
_G.LouisHub_ConexionesModulo = {}

table.insert(_G.LouisHub_ConexionesModulo, RunService.Heartbeat:Connect(function()
    local now = os.clock()
    for entry, cfg in pairs(_labelsAutoActualizables) do
        if entry and entry.Parent and now >= cfg.proxima then
            cfg.proxima = now + cfg.cada
            local ok, val = pcall(cfg.fn)
            if ok and val ~= nil then
                pcall(cfg.aplicar, val)
            elseif not ok then
                LouisHub:_RegistrarError("Label AutoUpdate ('" .. tostring(cfg.flag) .. "')", val)
            end
        end
    end
end))

local function cumpleVisibilidadCondicional(row)
    local cond = registroVisibilidad[row]
    if not cond then return true end
    local ok, res = pcall(cond)
    if not ok then
        LouisHub:_RegistrarError("VisibleSi", res)
        return true
    end
    return res and true or false
end

local function reevaluarVisibilidadCondicional()
    for row, _ in pairs(registroVisibilidad) do
        if row and row.Parent then
            row.Visible = cumpleVisibilidadCondicional(row)
        end
    end
end
table.insert(_G.LouisHub_ConexionesModulo, LouisHub.Eventos.FlagCambiada:Connect(reevaluarVisibilidadCondicional))

_Internal.labelsAutoActualizables         = _labelsAutoActualizables
_Internal.registroVisibilidad             = registroVisibilidad
_Internal.cumpleVisibilidadCondicional    = cumpleVisibilidadCondicional
_Internal.reevaluarVisibilidadCondicional = reevaluarVisibilidadCondicional

-- ===================================================================
--  DEADLOCK-PROOF UNDO / REDO HISTORY ENGINE
-- ===================================================================
LouisHub._historial = { deshacer = {}, rehacer = {}, ultimos = {}, pausa = 0 }
local MAX_HISTORIAL = 50

local function notifyHistoryChanged()
    local h = LouisHub._historial
    LouisHub.Eventos.HistorialCambiado:Fire(#h.deshacer, #h.rehacer)
end

LouisHub.Eventos.FlagCambiada:Connect(function(flag, val)
    local h = LouisHub._historial
    local prev = h.ultimos[flag]
    h.ultimos[flag] = _Internal.copyDefault(val)
    if h.pausa > 0 or _Internal.uiFlags[flag] or _Internal.nonPersistentFlags[flag] then return end

    local elem = LouisHub.Elementos[flag]
    if prev == nil and elem then prev = elem._defecto end
    if prev == nil or (type(val) ~= "table" and prev == val) then return end

    local now = os.clock()
    local last = h.deshacer[#h.deshacer]
    if last and #last.cambios == 1 and last.cambios[1].flag == flag and now - last.t < 0.6 then
        last.cambios[1].despues = _Internal.copyDefault(val)
        last.t = now
    else
        table.insert(h.deshacer, {
            t = now, cambios = { { flag = flag, antes = _Internal.copyDefault(prev), despues = _Internal.copyDefault(val) } }
        })
        if #h.deshacer > MAX_HISTORIAL then table.remove(h.deshacer, 1) end
    end
    h.rehacer = {}
    notifyHistoryChanged()
end)

-- Safe Exception Boundary (Guarantees h.pausa is always restored)
local function applyHistoryChanges(changes, useBefore, inReverse)
    local h = LouisHub._historial
    h.pausa = h.pausa + 1
    local ok, err = pcall(function()
        local total = #changes
        for i = 1, total do
            local c = changes[inReverse and (total - i + 1) or i]
            local elem = LouisHub.Elementos[c.flag]
            if elem and type(elem.Set) == "function" then
                local val = _Internal.copyDefault(useBefore and c.antes or c.despues)
                pcall(elem.Set, val, true)
                h.ultimos[c.flag] = _Internal.copyDefault(val)
            end
        end
    end)
    h.pausa = math.max(0, h.pausa - 1)
    if not ok then
        LouisHub:_RegistrarError("History Engine", err)
    end
end

function LouisHub:Deshacer()
    local h = self._historial
    local entry = table.remove(h.deshacer)
    if not entry then return false end
    applyHistoryChanges(entry.cambios, true, true)
    table.insert(h.rehacer, entry)
    notifyHistoryChanged()
    return true, entry
end

function LouisHub:Rehacer()
    local h = self._historial
    local entry = table.remove(h.rehacer)
    if not entry then return false end
    applyHistoryChanges(entry.cambios, false, false)
    table.insert(h.deshacer, entry)
    notifyHistoryChanged()
    return true, entry
end

function LouisHub:PuedeDeshacer() return #self._historial.deshacer > 0 end
function LouisHub:PuedeRehacer() return #self._historial.rehacer > 0 end
function LouisHub:ObtenerHistorial() return { Deshacer = #self._historial.deshacer, Rehacer = #self._historial.rehacer } end
function LouisHub:LimpiarHistorial()
    local h = self._historial
    h.deshacer, h.rehacer, h.ultimos = {}, {}, {}
    for flag, elem in pairs(self.Elementos) do
        if type(elem) == "table" and type(elem.Get) == "function" then
            local ok, val = pcall(elem.Get)
            if ok and val ~= nil then h.ultimos[flag] = _Internal.copyDefault(val) end
        end
    end
    notifyHistoryChanged()
end

function LouisHub:DescribirCambio(entry)
    if type(entry) ~= "table" or not entry.cambios or #entry.cambios == 0 then return "" end
    local first = entry.cambios[1]
    local function str(v) return (type(v) == "table") and "[table]" or tostring(v) end
    local desc = tostring(first.flag) .. ": " .. str(first.antes) .. " -> " .. str(first.despues)
    if #entry.cambios > 1 then desc = desc .. " (+" .. (#entry.cambios - 1) .. ")" end
    return desc
end

-- ===================================================================
--  GLASSMORPHISM CONFIRMATION MODAL ENGINE
-- ===================================================================
function LouisHub:Confirmar(cfg)
    cfg = cfg or {}
    local gui = self._guiConfirmar or _Internal.getGuiParent():FindFirstChild("LouisHub_ScreenGui")
    if not (gui and gui.Parent) then
        self:_RegistrarError("Confirmar", "No active ScreenGui context for modal dialog.")
        return nil
    end

    local buttons = {}
    if type(cfg.Botones) == "table" and #cfg.Botones > 0 then
        for _, b in ipairs(cfg.Botones) do table.insert(buttons, _Internal.cloneTable(b)) end
    else
        if cfg.BotonCancelar then
            local b = _Internal.cloneTable(cfg.BotonCancelar)
            b.Texto = b.Texto or "Cancel"
            b.Variante = b.Variante or "neutral"
            table.insert(buttons, b)
        end
        local okBtn = _Internal.cloneTable(cfg.BotonAceptar or {})
        okBtn.Texto = okBtn.Texto or "Accept"
        okBtn.Variante = okBtn.Variante or "primary"
        table.insert(buttons, okBtn)
    end

    self._modalesAbiertos = (self._modalesAbiertos or 0) + 1
    local zBase = 800 + (self._modalesAbiertos - 1) * 10

    local backdrop = Utils.Frame({
        Padre = gui,
        Size = UDim2.new(1, 0, 1, 0),
        Color = Color3.new(0, 0, 0),
        Transparencia = 0.5,
        Radio = false,
        Recortar = true,
    })
    backdrop.ZIndex = zBase
    backdrop.Active = true

    local card = Utils.Frame({
        Padre = backdrop,
        Size = UDim2.new(0, 310, 0, 0),
        Posicion = UDim2.new(0.5, 0, 0.5, 0),
        Ancla = Vector2.new(0.5, 0.5),
        Color = Theme.Panel,
        Transparencia = 0.14,
        Radio = 12,
        Borde = true,
        ColorBorde = Theme.BorderGlow,
        Recortar = true,
    })
    card.ZIndex = zBase + 1
    card.AutomaticSize = Enum.AutomaticSize.Y
    LouisHub:Registrar(card, "BackgroundColor3", "Panel")

    local layout = Instance.new("UIListLayout", card)
    layout.Padding = UDim.new(0, 12)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local pad = Instance.new("UIPadding", card)
    pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 18), UDim.new(0, 18)
    pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 16), UDim.new(0, 16)

    local order = 0
    if cfg.Icono then
        order = order + 1
        local lIco = Utils.Texto({
            Padre = card, Texto = tostring(cfg.Icono), Size = UDim2.new(1, 0, 0, 26),
            Orden = order, Alineacion = Enum.TextXAlignment.Center, Variante = "Title", Tamano = 22,
        })
        lIco.ZIndex = zBase + 2
    end
    if cfg.Titulo then
        order = order + 1
        local lTit = Utils.Texto({
            Padre = card, Texto = tostring(cfg.Titulo), Size = UDim2.new(1, 0, 0, 0),
            Orden = order, Variante = "Title", Tamano = 14, Ajustar = true,
            Alineacion = cfg.Icono and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
        })
        lTit.AutomaticSize = Enum.AutomaticSize.Y
        lTit.ZIndex = zBase + 2
    end
    if cfg.Contenido then
        order = order + 1
        local lBody = Utils.Texto({
            Padre = card, Texto = tostring(cfg.Contenido), Size = UDim2.new(1, 0, 0, 0),
            Orden = order, Ajustar = true, Variante = "Body",
            Alineacion = cfg.Icono and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
        })
        lBody.AutomaticSize = Enum.AutomaticSize.Y
        lBody.ZIndex = zBase + 2
    end

    order = order + 1
    local totalB = #buttons
    local vertical = totalB > 2
    local rowBtns = Utils.Frame({
        Padre = card,
        Size = UDim2.new(1, 0, 0, vertical and 0 or 32),
        Transparencia = 1,
        Orden = order,
        Borde = false,
    })
    rowBtns.ZIndex = zBase + 2
    if vertical then rowBtns.AutomaticSize = Enum.AutomaticSize.Y end

    local btnLayout = Instance.new("UIListLayout", rowBtns)
    btnLayout.FillDirection = vertical and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
    btnLayout.Padding = UDim.new(0, 8)
    btnLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local function close()
        if backdrop.Parent then
            self._modalesAbiertos = math.max(0, (self._modalesAbiertos or 1) - 1)
            backdrop:Destroy()
        end
    end

    local function press(idx)
        local b = buttons[idx]
        if not b then return end
        close()
        if type(b.Callback) == "function" then
            pcall(b.Callback, b.Texto or "Modal")
        end
    end

    for i, b in ipairs(buttons) do
        local var = b.Variante or "neutral"
        local bWidth = vertical and UDim2.new(1, 0, 0, 32) or UDim2.new(1 / totalB, -math.ceil(8 * (totalB - 1) / totalB), 1, 0)
        local col = Theme.Row
        if var == "primary" then col = Theme.Accent
        elseif var == "danger" then col = Theme.Danger end

        local btn = Utils.BotonBase({
            Padre = rowBtns,
            Size = bWidth,
            Color = col,
            Transparencia = var == "tertiary" and 1 or 0.25,
            Radio = 6,
        })
        btn.LayoutOrder = i
        btn.ZIndex = zBase + 3
        Utils.Hover(btn, btn, 0.2)

        local lbl = Utils.Texto({
            Padre = btn,
            Texto = tostring(b.Texto or "OK"),
            Alineacion = Enum.TextXAlignment.Center,
            Variante = "Title",
            Tamano = 11,
            Color = (var == "primary" or var == "danger") and Color3.new(1, 1, 1) or Theme.TextPrimary,
            Truncar = true,
        })
        lbl.ZIndex = zBase + 4
        btn.MouseButton1Click:Connect(function() press(i) end)
    end

    local sc = Instance.new("UIScale", card)
    sc.Scale = 0.88
    Utils.Tween(sc, {Scale = 1}, LouisHub.Motion.Modal, LouisHub.Motion.EaseBounce, Enum.EasingDirection.Out)
    return { Cerrar = close, Presionar = press, Fondo = backdrop }
end

-- ===================================================================
--  LOUIS HUB UI LIBRARY (V3.0 NEXT-GEN COMPLETE ENGINE)
--  Brand: Louis Hub
--  Priority: Zero-Leaks > Backward Compatibility > Glassmorphism > Performance
--  [PART 3 OF 6] - Hit Popups, Notifications, HUD, Action Button & Math Controllers
-- ===================================================================

local _Internal        = LouisHub._Internal
local Theme            = LouisHub.Theme
local Utils            = LouisHub.Utils
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TextService      = game:GetService("TextService")

-- ===================================================================
--  1. FIXED NOTIFICATION SYSTEM (Bebas Glitch UIListLayout Position)
-- ===================================================================
local contenedorNotif
local MAX_NOTIF_SIMULTANEAS = 4
local colaNotif   = {}
local notifActivas = 0

local function crearContenedorNotif(padreGui)
    if contenedorNotif and contenedorNotif.Parent then return end
    contenedorNotif = Utils.Frame({
        Padre = padreGui,
        Transparencia = 1,
        Size = UDim2.new(0, 280, 0, 0),
        Posicion = UDim2.new(1, -290, 0, 16),
        Radio = false,
        Recortar = false,
        Borde = false,
    })
    contenedorNotif.Name = "LouisHub_Notificaciones"
    contenedorNotif.AutomaticSize = Enum.AutomaticSize.Y
    contenedorNotif.ZIndex = 900
    contenedorNotif.Active = false

    local layout = Instance.new("UIListLayout", contenedorNotif)
    layout.Padding = UDim.new(0, 8)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
end

-- Fixed Notification Animation using NotifSlot container
local function mostrarTarjetaNotif(cfg)
    notifActivas = notifActivas + 1
    local colorAcento = (cfg.Tipo == "Success" and Theme.Success)
        or (cfg.Tipo == "Warning" and Theme.Warning)
        or (cfg.Tipo == "Danger" and Theme.Danger)
        or (cfg.Tipo == "Error" and Theme.Danger)
        or Theme.Accent

    local slot = Instance.new("Frame")
    slot.Name = "NotifSlot"
    slot.BackgroundTransparency = 1
    slot.BorderSizePixel = 0
    slot.Size = UDim2.new(1, 0, 0, 0)
    slot.AutomaticSize = Enum.AutomaticSize.Y
    slot.ClipsDescendants = true
    slot.Parent = contenedorNotif

    local tarjeta = Utils.Frame({
        Padre = slot,
        Color = Theme.Panel,
        Transparencia = 0.16,
        Size = UDim2.new(1, 0, 0, 0),
        Posicion = UDim2.new(1.15, 0, 0, 0),
        Radio = 10,
        Borde = true,
        ColorBorde = colorAcento,
        GrosorBorde = 1.2,
        Recortar = true,
    })
    tarjeta.AutomaticSize = Enum.AutomaticSize.Y
    LouisHub:Registrar(tarjeta, "BackgroundColor3", "Panel")

    local pillAcento = Utils.Frame({
        Padre = tarjeta,
        Size = UDim2.new(0, 4, 1, 0),
        Color = colorAcento,
        Radio = false,
        Borde = false,
    })

    local pad = Instance.new("UIPadding", tarjeta)
    pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 10)
    pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)

    Utils.Texto({
        Padre = tarjeta,
        Texto = cfg.Titulo or "Notification",
        Size = UDim2.new(1, 0, 0, 16),
        Variante = "Title",
        Tamano = 12,
        Color = Theme.Highlight,
    })

    local lblTexto = Utils.Texto({
        Padre = tarjeta,
        Texto = cfg.Texto or "",
        Size = UDim2.new(1, 0, 0, 0),
        Posicion = UDim2.new(0, 0, 0, 18),
        Variante = "Body",
        Ajustar = true,
        Color = Theme.TextPrimary,
    })
    lblTexto.AutomaticSize = Enum.AutomaticSize.Y

    local sc = Instance.new("UIScale", tarjeta)
    sc.Scale = 0.9

    Utils.Tween(tarjeta, {Position = UDim2.new(0, 0, 0, 0)}, LouisHub.Motion.Modal, LouisHub.Motion.EaseBounce, Enum.EasingDirection.Out)
    Utils.Tween(sc, {Scale = 1}, LouisHub.Motion.Modal, LouisHub.Motion.EaseBounce, Enum.EasingDirection.Out)

    local function cerrarTarjeta()
        if not (slot and slot.Parent) then return end
        local tw = Utils.Tween(tarjeta, {Position = UDim2.new(1.2, 0, 0, 0)}, LouisHub.Motion.PageSlide, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        Utils.Tween(sc, {Scale = 0.85}, LouisHub.Motion.PageSlide, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        
        tw.Completed:Connect(function()
            pcall(function() slot:Destroy() end)
            notifActivas = math.max(0, notifActivas - 1)
            local siguiente = table.remove(colaNotif, 1)
            if siguiente then
                pcall(mostrarTarjetaNotif, siguiente)
            end
        end)
    end

    if cfg.Persistente then
        local btnCerrar = Instance.new("TextButton", tarjeta)
        btnCerrar.BackgroundTransparency = 1
        btnCerrar.Text = ""
        btnCerrar.Size = UDim2.new(1, 0, 1, 0)
        btnCerrar.ZIndex = tarjeta.ZIndex + 2
        btnCerrar.MouseButton1Click:Connect(cerrarTarjeta)
    else
        task.delay(cfg.Duracion or 4, cerrarTarjeta)
    end
end

function LouisHub:Notificar(cfg)
    cfg = cfg or {}
    if not contenedorNotif then
        local parentGui = self._guiConfirmar or _Internal.getGuiParent():FindFirstChild("LouisHub_ScreenGui") or _Internal.getGuiParent()
        crearContenedorNotif(parentGui)
    end
    if notifActivas >= MAX_NOTIF_SIMULTANEAS then
        local prio = cfg.Prioridad or 0
        local pos = #colaNotif + 1
        for i, queued in ipairs(colaNotif) do
            if (queued.Prioridad or 0) < prio then pos = i; break end
        end
        table.insert(colaNotif, pos, cfg)
        return
    end
    mostrarTarjetaNotif(cfg)
end

_Internal.crearContenedorNotif = crearContenedorNotif

-- ===================================================================
--  2. HIT / DAMAGE POP-UP FLOAT ENGINE (REQUIREMENT 6)
-- ===================================================================
local hitOverlayGui = nil

local function obtenerHitOverlay()
    if hitOverlayGui and hitOverlayGui.Parent then return hitOverlayGui end
    hitOverlayGui = Instance.new("ScreenGui")
    hitOverlayGui.Name = "LouisHub_HitOverlay"
    hitOverlayGui.ResetOnSpawn = false
    hitOverlayGui.IgnoreGuiInset = true
    hitOverlayGui.DisplayOrder = 950
    pcall(function() hitOverlayGui.Parent = _Internal.getGuiParent() end)
    _Internal.protectGuiObject(hitOverlayGui)
    return hitOverlayGui
end

local COLORES_HIT = {
    Crit   = Color3.fromRGB(255, 65, 65),
    Damage = Color3.fromRGB(255, 175, 45),
    Heal   = Color3.fromRGB(50, 235, 120),
    Info   = Color3.fromRGB(80, 190, 255),
}

function LouisHub:SpawnHit(cfg)
    cfg = cfg or {}
    local overlay = obtenerHitOverlay()
    local text = tostring(cfg.Texto or cfg.Text or "100")
    local tipe = cfg.Tipe or cfg.Type or "Damage"
    local color = cfg.Color or COLORES_HIT[tipe] or Theme.Highlight
    local dur = math.clamp(tonumber(cfg.Durasi or cfg.Duration) or LouisHub.Motion.HitFloat, 0.5, 3.5)

    local spreadX = math.random(-30, 30)
    local startPos = cfg.Posisi or cfg.Position or UDim2.new(0.5, spreadX, 0.5, math.random(-20, 20))

    local hitHolder = Instance.new("Frame")
    hitHolder.Name = "HitHolder"
    hitHolder.BackgroundTransparency = 1
    hitHolder.Size = UDim2.new(0, 160, 0, 36)
    hitHolder.AnchorPoint = Vector2.new(0.5, 0.5)
    hitHolder.Position = startPos
    hitHolder.Parent = overlay

    local sc = Instance.new("UIScale", hitHolder)
    sc.Scale = 0.55

    local lblStroke = Instance.new("UIStroke", hitHolder)
    lblStroke.Thickness = (tipe == "Crit") and 2.5 or 1.5
    lblStroke.Color = Color3.fromRGB(15, 10, 22)
    lblStroke.Transparency = 0.1

    local lbl = Instance.new("TextLabel")
    lbl.BackgroundTransparency = 1
    lbl.Size = UDim2.new(1, 0, 1, 0)
    lbl.Font = (tipe == "Crit") and Enum.Font.FredokaOne or Enum.Font.GothamBold
    lbl.TextSize = (tipe == "Crit") and 24 or 18
    lbl.TextColor3 = color
    lbl.Text = text
    lbl.TextXAlignment = Enum.TextXAlignment.Center
    lbl.TextYAlignment = Enum.TextYAlignment.Center
    lbl.Parent = hitHolder

    Utils.Tween(sc, {Scale = (tipe == "Crit") and 1.35 or 1.1}, 0.14, LouisHub.Motion.EaseBounce, Enum.EasingDirection.Out)
    task.delay(0.14, function()
        if sc and sc.Parent then
            Utils.Tween(sc, {Scale = 1.0}, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
        end
    end)

    local floatYOffset = (tipe == "Crit") and -85 or -65
    Utils.Tween(hitHolder, {
        Position = UDim2.new(startPos.X.Scale, startPos.X.Offset, startPos.Y.Scale, startPos.Y.Offset + floatYOffset)
    }, dur, LouisHub.Motion.EaseSmooth, Enum.EasingDirection.Out)

    task.delay(dur * 0.65, function()
        if hitHolder and hitHolder.Parent then
            local fadeDur = dur * 0.35
            Utils.Tween(lbl, {TextTransparency = 1}, fadeDur, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            Utils.Tween(lblStroke, {Transparency = 1}, fadeDur, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
        end
    end)

    task.delay(dur + 0.05, function()
        pcall(function() hitHolder:Destroy() end)
    end)

    return hitHolder
end

-- ===================================================================
--  3. FLOATING EXTERNAL STATS HUD (REQUIREMENT 7 - STABLE LIFECYCLE)
-- ===================================================================
function LouisHub:CrearHUD(cfg)
    cfg = cfg or {}
    local parentGui = self._guiConfirmar or _Internal.getGuiParent():FindFirstChild("LouisHub_ScreenGui") or _Internal.getGuiParent()
    local titulo = cfg.Titulo or "Stats HUD"
    local visible = cfg.Visible ~= false

    local hudFrame = Utils.Frame({
        Padre = parentGui,
        Size = UDim2.new(0, cfg.Ancho or 190, 0, 0),
        Posicion = cfg.Posicion or UDim2.new(1, -210, 0.45, -60),
        Color = Theme.Panel,
        Transparencia = 0.18,
        Radio = 10,
        Borde = true,
        ColorBorde = Theme.BorderGlow,
        Visible = visible,
        Recortar = true,
    })
    hudFrame.Name = "LouisHub_ExternalHUD"
    hudFrame.AutomaticSize = Enum.AutomaticSize.Y
    hudFrame.ZIndex = 400
    LouisHub:Registrar(hudFrame, "BackgroundColor3", "Panel")

    local header = Utils.Frame({
        Padre = hudFrame,
        Size = UDim2.new(1, 0, 0, 26),
        Color = Theme.Background,
        Transparencia = 0.25,
        Radio = 10,
        Borde = false,
    })
    Utils.Arrastrable(header, hudFrame, LouisHub.EventManager)

    local lblTitle = Utils.Texto({
        Padre = header,
        Texto = titulo,
        Size = UDim2.new(1, -12, 1, 0),
        Posicion = UDim2.new(0, 8, 0, 0),
        Variante = "Title",
        Tamano = 11,
        Color = Theme.Highlight,
    })

    local content = Utils.Frame({
        Padre = hudFrame,
        Size = UDim2.new(1, 0, 0, 0),
        Posicion = UDim2.new(0, 0, 0, 28),
        Transparencia = 1,
        Borde = false,
    })
    content.AutomaticSize = Enum.AutomaticSize.Y

    local layout = Instance.new("UIListLayout", content)
    layout.Padding = UDim.new(0, 4)
    local pad = Instance.new("UIPadding", content)
    pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
    pad.PaddingBottom = UDim.new(0, 8)

    local rows = {}

    local HUD = { Frame = hudFrame, __isElement = true }
    function HUD:SetVisible(state)
        visible = state
        hudFrame.Visible = state
    end
    function HUD:ToggleVisible()
        self:SetVisible(not visible)
        return visible
    end
    function HUD:AgregarFila(id, labelText, defaultVal)
        local rowFrame = Utils.Frame({
            Padre = content,
            Size = UDim2.new(1, 0, 0, 20),
            Color = Theme.Row,
            Transparencia = 0.35,
            Radio = 4,
            Borde = false,
        })
        local lbl = Utils.Texto({
            Padre = rowFrame,
            Texto = labelText,
            Size = UDim2.new(0.55, -4, 1, 0),
            Posicion = UDim2.new(0, 6, 0, 0),
            Variante = "Body",
            Tamano = 10,
            ColorTema = "TextMuted",
            Truncar = true,
        })
        local valLbl = Utils.Texto({
            Padre = rowFrame,
            Texto = tostring(defaultVal or "-"),
            Size = UDim2.new(0.45, -6, 1, 0),
            Posicion = UDim2.new(0.55, 0, 0, 0),
            Alineacion = Enum.TextXAlignment.Right,
            Variante = "Code",
            Tamano = 10,
            Color = Theme.Highlight,
            Truncar = true,
        })
        rows[id] = { Frame = rowFrame, Label = lbl, ValLabel = valLbl }
        return rows[id]
    end
    function HUD:ActualizarFila(id, newVal)
        if rows[id] and rows[id].ValLabel then
            rows[id].ValLabel.Text = tostring(newVal)
        end
    end
    function HUD:Destruir()
        if hudFrame.Parent then hudFrame:Destroy() end
    end

    LouisHub:RegistrarInstancia(hudFrame)
    return HUD
end

-- ===================================================================
--  4. MOBILE FLOATING ACTION BUTTON (REQUIREMENT 7 - STABLE LIFECYCLE)
-- ===================================================================
function LouisHub:CrearBotonFlotante(cfg)
    cfg = cfg or {}
    local parentGui = self._guiConfirmar or _Internal.getGuiParent():FindFirstChild("LouisHub_ScreenGui") or _Internal.getGuiParent()
    local text = cfg.Texto or "Action"
    local mode = cfg.Modo or "Click"
    local state = cfg.Defecto or false
    local keybind = cfg.Keybind
    local visible = cfg.Visible ~= false

    local sizeW = cfg.Ancho or 95
    local sizeH = cfg.Alto or 36

    local btnFrame = Utils.BotonBase({
        Padre = parentGui,
        Size = UDim2.new(0, sizeW, 0, sizeH),
        Posicion = cfg.Posicion or UDim2.new(0.85, 0, 0.72, 0),
        Color = (mode == "Toggle" and state) and Theme.Accent or Theme.Panel,
        Transparencia = 0.22,
        Radio = 10,
    })
    btnFrame.Name = "LouisHub_FloatingActionButton"
    btnFrame.Visible = visible
    btnFrame.ZIndex = 450
    Utils.GlowStroke(btnFrame, Theme.AccentGlow, 1.4)

    local lbl = Instance.new("TextLabel", btnFrame)
    lbl.Size = UDim2.new(1, -8, 1, -4)
    lbl.Position = UDim2.new(0, 4, 0, 2)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Theme.TextPrimary
    lbl.Font = Enum.Font.FredokaOne
    lbl.TextScaled = true
    local constraint = Instance.new("UITextSizeConstraint", lbl)
    constraint.MaxTextSize = 13
    constraint.MinTextSize = 8

    Utils.Arrastrable(btnFrame, btnFrame, LouisHub.EventManager)

    local function triggerAction()
        if mode == "Toggle" then
            state = not state
            Utils.Tween(btnFrame, { BackgroundColor3 = state and Theme.Accent or Theme.Panel }, LouisHub.Motion.Hover)
            _Internal.executeCallback(cfg.Callback, "FloatingButton", state)
        else
            Utils.ElasticBounce(btnFrame, 0.94)
            _Internal.executeCallback(cfg.Callback, "FloatingButton")
        end
    end

    Utils.ClickConfiable(btnFrame, triggerAction, btnFrame)

    if keybind then
        LouisHub:RegistrarConexion(UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe then return end
            if input.KeyCode == keybind and btnFrame.Visible then
                triggerAction()
            end
        end))
    end

    local FloatingBtn = { Frame = btnFrame, __isElement = true }
    function FloatingBtn:SetVisible(s)
        visible = s
        btnFrame.Visible = s
    end
    function FloatingBtn:ToggleVisible()
        self:SetVisible(not visible)
        return visible
    end
    function FloatingBtn:SetTexto(t)
        text = t
        lbl.Text = t
    end
    function FloatingBtn:Set(val)
        if mode == "Toggle" then
            state = val
            btnFrame.BackgroundColor3 = state and Theme.Accent or Theme.Panel
            _Internal.executeCallback(cfg.Callback, "FloatingButton", state)
        end
    end
    function FloatingBtn:Get() return state end
    function FloatingBtn:Destruir()
        if btnFrame.Parent then btnFrame:Destroy() end
    end

    LouisHub:RegistrarInstancia(btnFrame)
    return FloatingBtn
end

-- ===================================================================
--  5. INTERACTIVE MATH & EXPANDABLE CONTROLLERS (ZERO-DIVISION SAFE)
-- ===================================================================

local function crearBarraArrastrable(cfg)
    local diff = math.max(1e-5, cfg.Max - cfg.Min)

    local fondo = Utils.Frame({
        Padre = cfg.Padre, Size = cfg.Size, Posicion = cfg.Posicion,
        Color = Theme.Input, Transparencia = Theme.InputTrans or 0.25, Radio = 4,
    })
    LouisHub:Registrar(fondo, "BackgroundColor3", "Input")

    local aroArrastre = Utils.Stroke(fondo, Theme.AccentLight, 1.8, 1)
    LouisHub:Registrar(aroArrastre, "Color", "AccentLight")

    local function marcarArrastre(activo)
        Utils.Tween(aroArrastre, { Transparency = activo and 0 or 1 }, LouisHub.Motion.Hover)
    end

    local relleno = Utils.Frame({
        Padre = fondo,
        Size = UDim2.new((cfg.Valor - cfg.Min) / diff, 0, 1, 0),
        Color = Theme.Accent, Transparencia = 0, Radio = 4,
    })
    LouisHub:Registrar(relleno, "BackgroundColor3", "Accent")
    Utils.GradienteAcento(relleno, 0.35)

    if cfg.Pasos and cfg.Incremento and cfg.Incremento > 0 then
        local totalPasos = math.floor(diff / cfg.Incremento + 0.5)
        if totalPasos >= 2 and totalPasos <= 40 then
            for i = 1, totalPasos - 1 do
                local rel = i / totalPasos
                local marca = Utils.Frame({
                    Padre = fondo, Size = UDim2.new(0, 2, 1, 0),
                    Posicion = UDim2.new(rel, -1, 0, 0),
                    Color = Theme.Border, Transparencia = 0.35, Radio = false,
                })
                marca.ZIndex = 2
            end
        end
    end

    local function fijarVisual(valor)
        local rel = math.clamp((valor - cfg.Min) / diff, 0, 1)
        local dur = LouisHub.EventManager:HayArrastreActivo() and LouisHub.Motion.Directo or LouisHub.Motion.PageSlide
        Utils.Tween(relleno, { Size = UDim2.new(rel, 0, 1, 0) }, dur, LouisHub.Motion.EaseSmooth, Enum.EasingDirection.Out)
    end

    local function calcularYAplicar(input)
        local rel = math.clamp((input.Position.X - fondo.AbsolutePosition.X) / fondo.AbsoluteSize.X, 0, 1)
        local v = cfg.Min + rel * diff
        Utils.Tween(relleno, { Size = UDim2.new(rel, 0, 1, 0) }, LouisHub.Motion.Directo)
        cfg.OnCambio(v)
    end

    local objetoInput = fondo
    if cfg.AltoHitbox and cfg.AltoHitbox > 0 then
        local offsetY = cfg.OffsetHitboxY or 0
        local hitbox = Utils.Frame({
            Padre = cfg.Padre,
            Size = UDim2.new(cfg.Size.X.Scale, cfg.Size.X.Offset, 0, cfg.AltoHitbox),
            Posicion = UDim2.new(
                cfg.Posicion.X.Scale, cfg.Posicion.X.Offset,
                cfg.Posicion.Y.Scale, cfg.Posicion.Y.Offset - (cfg.AltoHitbox - cfg.Size.Y.Offset) / 2 + offsetY
            ),
            Transparencia = 1, Radio = false,
        })
        hitbox.ZIndex = fondo.ZIndex + 1
        objetoInput = hitbox
    end

    objetoInput.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if LouisHub.EventManager:HayArrastreActivo() then return end
            local UMBRAL_GESTO = 10
            local inicio = Vector2.new(input.Position.X, input.Position.Y)
            local decidido, esArrastre = false, false
            local scrollAncestro = fondo:FindFirstAncestorWhichIsA("ScrollingFrame")
            local scrollEstabaActivo = scrollAncestro and scrollAncestro.ScrollingEnabled

            local function candidato(inputMovido)
                if not decidido then
                    local delta = Vector2.new(inputMovido.Position.X, inputMovido.Position.Y) - inicio
                    if delta.Magnitude < UMBRAL_GESTO then return end
                    decidido = true
                    if math.abs(delta.X) > math.abs(delta.Y) then
                        esArrastre = true
                        if scrollAncestro then scrollAncestro.ScrollingEnabled = false end
                        marcarArrastre(true)
                    else
                        LouisHub.EventManager:DetenerArrastre()
                        return
                    end
                end
                if esArrastre then calcularYAplicar(inputMovido) end
            end

            LouisHub.EventManager:Arrastrar(candidato, function()
                if esArrastre then marcarArrastre(false) end
                if scrollAncestro then scrollAncestro.ScrollingEnabled = scrollEstabaActivo end
            end)
        end
    end)

    return fondo, relleno, fijarVisual, (objetoInput ~= fondo) and objetoInput or nil
end

local function crearBarraArrastrableRango(cfg)
    local diff = math.max(1e-5, cfg.Max - cfg.Min)

    local fondo = Utils.Frame({
        Padre = cfg.Padre, Size = cfg.Size, Posicion = cfg.Posicion,
        Color = Theme.Input, Transparencia = Theme.InputTrans or 0.25, Radio = 4,
    })
    LouisHub:Registrar(fondo, "BackgroundColor3", "Input")

    local function relX(v)
        return math.clamp((v - cfg.Min) / diff, 0, 1)
    end

    local relleno = Utils.Frame({
        Padre = fondo,
        Posicion = UDim2.new(relX(cfg.ValorMin), 0, 0, 0),
        Size = UDim2.new(relX(cfg.ValorMax) - relX(cfg.ValorMin), 0, 1, 0),
        Color = Theme.Accent, Transparencia = 0, Radio = 4,
    })
    LouisHub:Registrar(relleno, "BackgroundColor3", "Accent")
    Utils.GradienteAcento(relleno, 0.35)

    local DIAMETRO_MANIJA = cfg.DiametroManija or 16
    local function crearManija()
        local m = Utils.Frame({
            Padre = fondo,
            Size = UDim2.new(0, DIAMETRO_MANIJA, 0, DIAMETRO_MANIJA),
            Ancla = Vector2.new(0.5, 0.5),
            Color = Theme.Highlight, Transparencia = 0, Radio = 999,
        })
        m.ZIndex = 3
        LouisHub:Registrar(m, "BackgroundColor3", "Highlight")
        local aro = Utils.Stroke(m, Theme.AccentLight, 2, 1)
        LouisHub:Registrar(aro, "Color", "AccentLight")
        return m, aro
    end

    local manijaMin, aroMin = crearManija()
    local manijaMax, aroMax = crearManija()

    local function posicionarManija(manija, v)
        manija.Position = UDim2.new(relX(v), 0, 0.5, 0)
    end
    posicionarManija(manijaMin, cfg.ValorMin)
    posicionarManija(manijaMax, cfg.ValorMax)

    local function marcarArrastre(aro, activo)
        Utils.Tween(aro, { Transparency = activo and 0 or 1 }, LouisHub.Motion.Hover)
    end

    local function fijarVisual(vMin, vMax)
        posicionarManija(manijaMin, vMin)
        posicionarManija(manijaMax, vMax)
        relleno.Position = UDim2.new(relX(vMin), 0, 0, 0)
        relleno.Size = UDim2.new(relX(vMax) - relX(vMin), 0, 1, 0)
    end

    local function calcularValor(input)
        local rel = math.clamp((input.Position.X - fondo.AbsolutePosition.X) / fondo.AbsoluteSize.X, 0, 1)
        return cfg.Min + rel * diff
    end

    fondo.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if LouisHub.EventManager:HayArrastreActivo() then return end

            local UMBRAL_GESTO = 10
            local inicio = Vector2.new(input.Position.X, input.Position.Y)
            local decidido, esArrastre, moviendoMin = false, false, nil
            local scrollAncestro = fondo:FindFirstAncestorWhichIsA("ScrollingFrame")
            local scrollEstabaActivo = scrollAncestro and scrollAncestro.ScrollingEnabled

            local function elegirManija(inputInicial)
                local vToque = calcularValor(inputInicial)
                local vMin, vMax = cfg.ObtenerMin(), cfg.ObtenerMax()
                local distMin, distMax = math.abs(vToque - vMin), math.abs(vToque - vMax)
                if distMin < distMax then
                    moviendoMin = true
                elseif distMax < distMin then
                    moviendoMin = false
                else
                    moviendoMin = vToque <= vMin
                end
            end

            local function candidato(inputMovido)
                if not decidido then
                    local delta = Vector2.new(inputMovido.Position.X, inputMovido.Position.Y) - inicio
                    if delta.Magnitude < UMBRAL_GESTO then return end
                    decidido = true
                    if math.abs(delta.X) > math.abs(delta.Y) then
                        esArrastre = true
                        elegirManija(input)
                        if scrollAncestro then scrollAncestro.ScrollingEnabled = false end
                        marcarArrastre(moviendoMin and aroMin or aroMax, true)
                    else
                        LouisHub.EventManager:DetenerArrastre()
                        return
                    end
                end
                if not esArrastre then return end

                local v = calcularValor(inputMovido)
                local vMin, vMax = cfg.ObtenerMin(), cfg.ObtenerMax()
                if moviendoMin then
                    v = math.min(v, vMax)
                    posicionarManija(manijaMin, v)
                    cfg.OnCambio(v, vMax)
                else
                    v = math.max(v, vMin)
                    posicionarManija(manijaMax, v)
                    cfg.OnCambio(vMin, v)
                end
                local vMinReal, vMaxReal = cfg.ObtenerMin(), cfg.ObtenerMax()
                relleno.Position = UDim2.new(relX(vMinReal), 0, 0, 0)
                relleno.Size = UDim2.new(relX(vMaxReal) - relX(vMinReal), 0, 1, 0)
            end

            LouisHub.EventManager:Arrastrar(candidato, function()
                if esArrastre then marcarArrastre(moviendoMin and aroMin or aroMax, false) end
                if scrollAncestro then scrollAncestro.ScrollingEnabled = scrollEstabaActivo end
            end)
        end
    end)

    return fondo, fijarVisual
end

local function hacerExpandible(marco, altoCerrado, obtenerAltoAbierto)
    local abierto = false
    local conexionesCierre = {}

    local function estaFuera(input)
        local pos = marco.AbsolutePosition
        local tam = marco.AbsoluteSize
        local x, y = input.Position.X, input.Position.Y
        return x < pos.X or x > pos.X + tam.X or y < pos.Y or y > pos.Y + tam.Y
    end

    local function limpiarConexionesCierre()
        for _, conn in ipairs(conexionesCierre) do
            LouisHub:DesconectarYLimpiar(conn)
        end
        conexionesCierre = {}
    end

    local function alternar()
        abierto = not abierto
        local alto = abierto and obtenerAltoAbierto() or altoCerrado
        Utils.Tween(marco, { Size = UDim2.new(1, 0, 0, alto) }, LouisHub.Motion.Expand)
        limpiarConexionesCierre()

        if abierto then
            local UMBRAL_MOVIMIENTO = (LouisHub.Capacidades and LouisHub.Capacidades.EsTactil) and 18 or 10
            local inicio = nil
            table.insert(conexionesCierre, LouisHub:RegistrarConexion(
                UserInputService.InputBegan:Connect(function(input)
                    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
                    if marco.Parent and estaFuera(input) then
                        inicio = { tipo = input.UserInputType, pos = Vector2.new(input.Position.X, input.Position.Y) }
                    else
                        inicio = nil
                    end
                end)
            ))
            table.insert(conexionesCierre, LouisHub:RegistrarConexion(
                UserInputService.InputEnded:Connect(function(input)
                    if not inicio or input.UserInputType ~= inicio.tipo then return end
                    local movio = (Vector2.new(input.Position.X, input.Position.Y) - inicio.pos).Magnitude > UMBRAL_MOVIMIENTO
                    inicio = nil
                    if movio then return end
                    if marco.Parent and abierto then alternar() end
                end)
            ))
        end
        return abierto
    end
    return alternar
end

_Internal.crearBarraArrastrable      = crearBarraArrastrable
_Internal.crearBarraArrastrableRango = crearBarraArrastrableRango
_Internal.hacerExpandible            = hacerExpandible

-- ===================================================================
--  LOUIS HUB UI LIBRARY (V3.0 NEXT-GEN COMPLETE ENGINE)
--  Brand: Louis Hub
--  Priority: Zero-Leaks > Backward Compatibility > Glassmorphism > Performance
--  [PART 4 OF 6] - Window Core, Splash Screen, 3-Tier Hierarchy & 2-Column Grid
-- ===================================================================

local _Internal        = LouisHub._Internal
local Theme            = LouisHub.Theme
local Utils            = LouisHub.Utils
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TextService      = game:GetService("TextService")
local Workspace        = game:GetService("Workspace")

local indiceBusqueda       = {}
local seccionesRegistradas = {}

local function registrarBuscable(fila, texto, visibleSi)
    table.insert(indiceBusqueda, { fila = fila, texto = (texto or ""):lower() })
    if type(visibleSi) == "function" and fila then
        _Internal.registroVisibilidad[fila] = visibleSi
        fila.Visible = _Internal.cumpleVisibilidadCondicional(fila)
    end
end

local function anchoTexto(texto, tamano, fuente)
    return TextService:GetTextSize(texto or "", tamano or 11, fuente or Enum.Font.Ubuntu, Vector2.new(1000, 40)).X
end

_Internal.registrarBuscable    = registrarBuscable
_Internal.indiceBusqueda       = indiceBusqueda
_Internal.seccionesRegistradas = seccionesRegistradas
_Internal.anchoTexto           = anchoTexto
_Internal.pendingSections      = _Internal.pendingSections or {}

-- ===================================================================
--  MAIN WINDOW BUILDER (CREAR VENTANA)
-- ===================================================================
function LouisHub:CrearVentana(config)
    config = config or {}
    local titulo    = config.Titulo or "Louis Hub"
    local subtitulo = (config.Subtitulo or "Next-Gen Complete Edition") .. "  •  v" .. LouisHub.Version
    local anchoX    = config.TamanoX or 620
    local anchoY    = config.TamanoY or 380
    local teclaUI   = config.TeclaToggle or Enum.KeyCode.RightControl

    pcall(_Internal.cleanPreviousInstance)
    _G.LouisHub_InstanciaActiva = _Internal.createInstanceRecord(titulo)

    local padreGui = _Internal.getGuiParent()
    local viejo = padreGui:FindFirstChild("LouisHub_ScreenGui")
    if viejo then viejo:Destroy() end

    _Internal.themeRegistry          = {}
    indiceBusqueda                   = {}
    seccionesRegistradas             = {}
    _Internal.indiceBusqueda         = indiceBusqueda
    _Internal.seccionesRegistradas   = seccionesRegistradas
    LouisHub.Elementos               = setmetatable({}, getmetatable(LouisHub.Elementos))
    _Internal.registeredKeybinds     = {}
    
    for k in pairs(_Internal.realFlags) do _Internal.realFlags[k] = nil end
    _Internal.nonPersistentFlags     = {}
    _Internal.uiFlags                = {}
    LouisHub:LimpiarHistorial()
    _Internal.activeSaveWindow       = nil

    local sg = Instance.new("ScreenGui")
    sg.Name           = "LouisHub_ScreenGui"
    sg.ResetOnSpawn   = false
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = padreGui
    _Internal.protectGuiObject(sg)

    _Internal.crearContenedorNotif(sg)
    LouisHub._guiConfirmar = sg
    LouisHub._modalesAbiertos = 0

    -- Screen Ambient Dimmer Frame
    local sombraPantalla = Utils.Frame({
        Padre = sg, Size = UDim2.new(1, 0, 1, 0), Posicion = UDim2.new(0, 0, 0, 0),
        Color = Color3.new(0, 0, 0), Transparencia = 1, Radio = false, Borde = false, Recortar = true,
    })
    sombraPantalla.ZIndex = -10

    -- Glassmorphic Main Window Frame (Strict Anti-Bocor)
    local main = Utils.Frame({
        Padre = sg, Size = UDim2.new(0, 0, 0, 0),
        Posicion = UDim2.new(0.5, 0, 0.5, 0), Ancla = Vector2.new(0.5, 0.5),
        Color = Theme.Panel, Transparencia = Theme.PanelTrans or 0.28,
        Radio = 14, Recortar = true, Borde = true,
        ColorBorde = Theme.BorderGlow, GrosorBorde = 1.4,
    })
    main.Active = true
    LouisHub:Registrar(main, "BackgroundColor3", "Panel")

    local POSICION_ORIGINAL_VENTANA = UDim2.new(0.5, 0, 0.5, 0)
    Utils.Tween(main, {
        Size = UDim2.new(0, anchoX, 0, anchoY),
        Position = POSICION_ORIGINAL_VENTANA,
    }, LouisHub.Motion.Modal, LouisHub.Motion.EaseBounce, Enum.EasingDirection.Out)
    Utils.Tween(sombraPantalla, {BackgroundTransparency = 0.88}, LouisHub.Motion.Modal)

    LouisHub:RegistrarConexion(main:GetPropertyChangedSignal("Visible"):Connect(function()
        sombraPantalla.Visible = main.Visible
    end))

    -- ===============================================================
    --  ATMOSPHERIC LOADING SPLASH SCREEN (RESTORED FROM V2)
    -- ===============================================================
    local ventanaRevelada = false
    LouisHub._ventanaRevelada = false

    local splash = Utils.Frame({
        Padre = sg, Color = Theme.Panel, Transparencia = 0.05, Radio = 12,
        Size = UDim2.new(2, 0, 2, 0), Posicion = UDim2.new(0.5, 0, 0.5, 0), Ancla = Vector2.new(0.5, 0.5),
        Recortar = true, Borde = false,
    })
    splash.ZIndex = 2000
    splash.Active = true
    LouisHub:Registrar(splash, "BackgroundColor3", "Panel")

    local logoImagen = Instance.new("ImageLabel")
    logoImagen.BackgroundTransparency = 1
    logoImagen.Image = "rbxthumb://type=Asset&id=104436283956004&w=420&h=420"
    logoImagen.ScaleType = Enum.ScaleType.Fit
    logoImagen.Size = UDim2.new(0, 64, 0, 64)
    logoImagen.Position = UDim2.new(0.5, -32, 0.5, -90)
    logoImagen.Parent = splash

    Utils.Texto({
        Padre = splash, Texto = "Louis Hub",
        Size = UDim2.new(1, 0, 0, 28), Posicion = UDim2.new(0, 0, 0.5, -20),
        Alineacion = Enum.TextXAlignment.Center, Variante = "Title",
        Tamano = 22, Color = Theme.AccentLight,
    })
    local lblCreditoSplash = Utils.Texto({
        Padre = splash, Texto = subtitulo,
        Size = UDim2.new(1, 0, 0, 16), Posicion = UDim2.new(0, 0, 0.5, 8),
        Alineacion = Enum.TextXAlignment.Center, Variante = "Body", Tamano = 11,
        Color = Theme.TextMuted, TextoTransparencia = 0.2,
    })

    local barraSplashFondo = Utils.Frame({
        Padre = splash, Color = Theme.Input, Transparencia = 0.25, Radio = 4,
        Size = UDim2.new(0, 180, 0, 6), Posicion = UDim2.new(0.5, -90, 0.5, 36),
        Borde = false, Recortar = true,
    })
    local barraSplashRelleno = Utils.Frame({
        Padre = barraSplashFondo, Color = Theme.Accent, Transparencia = 0, Radio = 4,
        Size = UDim2.new(0, 0, 1, 0), Borde = false, Recortar = true,
    })
    Utils.GradienteAcento(barraSplashRelleno, 0.3)
    Utils.FundirEntrada(splash, LouisHub.Motion.Modal, true)

    LouisHub:RegistrarHilo(task.spawn(function()
        local okS, _ = pcall(function()
            for _ = 1, 3 do
                if not (splash and splash.Parent) then return end
                RunService.Heartbeat:Wait()
            end
            local dur = 0.45
            Utils.Tween(barraSplashRelleno, {Size = UDim2.new(1, 0, 1, 0)}, dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
            task.wait(dur)
            if not (splash and splash.Parent) then return end
            ventanaRevelada = true
            LouisHub._ventanaRevelada = true
            local tSplash = Utils.Tween(splash, {Position = UDim2.new(0.5, 0, -1.5, 0)}, LouisHub.Motion.Modal, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            tSplash.Completed:Connect(function()
                pcall(function() if splash and splash.Parent then splash:Destroy() end end)
            end)
        end)
        if not okS then
            ventanaRevelada = true
            LouisHub._ventanaRevelada = true
            pcall(function() if splash and splash.Parent then splash:Destroy() end end)
        end
    end))

    -- Responsive Scaling Engine
    local escalaUI = Instance.new("UIScale", main)
    escalaUI.Scale = 1
    local escalaManual = 1
    local anchoXBase, anchoYBase = anchoX, anchoY
    local factorAncho, factorAlto = 1, 1

    local function actualizarTamanoVentana()
        local dur = LouisHub.EventManager:HayArrastreActivo() and LouisHub.Motion.Directo or LouisHub.Motion.PageSlide
        Utils.Tween(main, {
            Size = UDim2.new(0, anchoXBase * factorAncho, 0, anchoYBase * factorAlto),
            Position = UDim2.new(0.5, 0, 0.5, 0),
        }, dur, LouisHub.Motion.EaseSmooth, Enum.EasingDirection.Out)
    end

    local function recalcularEscala()
        local cam = Workspace.CurrentCamera
        if not cam then return end
        local tam = cam.ViewportSize
        if tam.X <= 0 or tam.Y <= 0 then return end
        local esMovil = tam.X < 720 or tam.Y < 520
        local pctAncho = esMovil and 0.94 or 0.82
        local pctAlto  = esMovil and 0.88 or 0.82
        local escalaAuto = math.clamp(math.min((tam.X * pctAncho) / (anchoXBase * factorAncho), (tam.Y * pctAlto) / (anchoYBase * factorAlto)), 0.45, 1.15)
        local lim = math.min((tam.X * 0.98) / (anchoXBase * factorAncho), (tam.Y * 0.92) / (anchoYBase * factorAlto))
        local fin = math.max(0.35, math.min(escalaAuto * escalaManual, lim))
        local dur = LouisHub.EventManager:HayArrastreActivo() and LouisHub.Motion.Directo or LouisHub.Motion.PageSlide
        Utils.Tween(escalaUI, {Scale = fin}, dur, LouisHub.Motion.EaseSmooth, Enum.EasingDirection.Out)
    end
    recalcularEscala()

    local connCam
    local function attachCamera()
        if connCam then connCam:Disconnect(); connCam = nil end
        local cur = Workspace.CurrentCamera
        if cur then
            connCam = LouisHub:RegistrarConexion(cur:GetPropertyChangedSignal("ViewportSize"):Connect(recalcularEscala))
        end
    end
    attachCamera()
    LouisHub:RegistrarConexion(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        attachCamera(); recalcularEscala()
    end))

    -- Floating Pill Minimizer
    local textoPill = "✨ " .. titulo
    local anchoPill = math.clamp(anchoTexto(textoPill, 12, Enum.Font.FredokaOne) + 36, 130, 260)

    local pillRestaurar = Utils.BotonBase({
        Padre = sg, Size = UDim2.new(0, anchoPill, 0, 32),
        Posicion = UDim2.new(0.5, 0, 0, 30), Ancla = Vector2.new(0.5, 0.5),
        Color = Theme.Panel, Transparencia = 0.18, Radio = 16,
    })
    pillRestaurar.Visible = false
    pillRestaurar.ZIndex  = 100
    Utils.GlowStroke(pillRestaurar, Theme.BorderGlow, 1.2)

    Utils.Texto({
        Padre = pillRestaurar, Texto = textoPill,
        Size = UDim2.new(1, -12, 1, 0), Posicion = UDim2.new(0, 6, 0, 0),
        Alineacion = Enum.TextXAlignment.Center, Variante = "Title", Tamano = 12,
    })

    local ventanaAbierta = true
    local function alternarVentana(abrir)
        if abrir == ventanaAbierta then return end
        ventanaAbierta = abrir
        if abrir then
            pillRestaurar.Visible = false
            main.Visible = true
            main.Size = UDim2.new(0, 0, 0, 0)
            Utils.Tween(main, {
                Size = UDim2.new(0, anchoXBase * factorAncho, 0, anchoYBase * factorAlto),
                Position = POSICION_ORIGINAL_VENTANA
            }, LouisHub.Motion.Modal, LouisHub.Motion.EaseBounce, Enum.EasingDirection.Out)
        else
            Utils.Tween(main, {Size = UDim2.new(0, 0, 0, 0)}, LouisHub.Motion.PageSlide, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
            task.delay(LouisHub.Motion.PageSlide, function()
                main.Visible = false
                pillRestaurar.Visible = true
                Utils.ElasticBounce(pillRestaurar, 0.85)
            end)
        end
    end
    pillRestaurar.MouseButton1Click:Connect(function() alternarVentana(true) end)

    -- Window Header & Title Bar
    local barraTitulo = Utils.Frame({
        Padre = main, Size = UDim2.new(1, 0, 0, 38), Color = Theme.Background,
        Transparencia = Theme.BackgroundTrans or 0.22, Radio = 14, Borde = false, Recortar = true,
    })
    barraTitulo.Active = true
    Utils.Arrastrable(barraTitulo, main, LouisHub.EventManager)

    local lineaTitulo = Utils.Frame({
        Padre = barraTitulo, Size = UDim2.new(1, 0, 0, 1), Posicion = UDim2.new(0, 0, 1, -1),
        Color = Theme.Border, Transparencia = 0.5, Radio = false, Borde = false,
    })

    local lblTit = Utils.Texto({
        Padre = barraTitulo, Texto = titulo, Posicion = UDim2.new(0, 14, 0, 3),
        Size = UDim2.new(0.4, 0, 0, 18), Variante = "Title", Tamano = 14, Truncar = true,
    })
    local lblSub = Utils.Texto({
        Padre = barraTitulo, Texto = subtitulo, Posicion = UDim2.new(0, 14, 0, 20),
        Size = UDim2.new(0.4, 0, 0, 14), Variante = "Body", Tamano = 10, ColorTema = "TextMuted", Truncar = true,
    })

    -- Header Window Control Buttons (Minimize / Close)
    local btnCerrar = Utils.BotonBase({
        Padre = barraTitulo, Size = UDim2.new(0, 28, 0, 24),
        Posicion = UDim2.new(1, -20, 0.5, 0), Ancla = Vector2.new(0.5, 0.5),
        Color = Theme.Danger, Transparencia = 0.65, Radio = 6,
    })
    local lblX = Utils.Texto({
        Padre = btnCerrar, Texto = "✕", Size = UDim2.new(1, 0, 1, 0), Posicion = UDim2.new(0, 0, 0, 0),
        Alineacion = Enum.TextXAlignment.Center, Variante = "Title", Tamano = 12, Color = Theme.TextPrimary,
    })
    lblX.TextYAlignment = Enum.TextYAlignment.Center

    Utils.ClickConfiable(btnCerrar, function()
        LouisHub:Confirmar({
            Titulo    = "⚠️ Close Interface?",
            Contenido = "Do you want to completely unload this interface and clear all running threads?",
            Icono     = "⚠️",
            Botones   = {
                { Texto = "Cancel", Variante = "neutral" },
                {
                    Texto = "Close", Variante = "danger",
                    Callback = function()
                        if sg and sg.Parent then sg:Destroy() end
                    end
                }
            }
        })
    end)

    local btnMin = Utils.BotonBase({
        Padre = barraTitulo, Size = UDim2.new(0, 28, 0, 24),
        Posicion = UDim2.new(1, -54, 0.5, 0), Ancla = Vector2.new(0.5, 0.5),
        Color = Theme.Row, Transparencia = 0.5, Radio = 6,
    })
    local lblDash = Utils.Texto({
        Padre = btnMin, Texto = "—", Size = UDim2.new(1, 0, 1, 0), Posicion = UDim2.new(0, 0, 0, 0),
        Alineacion = Enum.TextXAlignment.Center, Variante = "Title", Tamano = 13, Color = Theme.TextSecondary,
    })
    lblDash.TextYAlignment = Enum.TextYAlignment.Center
    Utils.ClickConfiable(btnMin, function() alternarVentana(false) end)

    -- Keyboard Shortcut to Toggle
    LouisHub:RegistrarConexion(UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == teclaUI then
            alternarVentana(not ventanaAbierta)
        end
    end))

    -- ===============================================================
    --  SIDEBAR NAVIGATION ENGINE (REQUIREMENT 3: ANTI-HIDDEN SCROLL)
    -- ===============================================================
    local barraLat = Instance.new("ScrollingFrame")
    barraLat.Name                = "SidebarNav"
    barraLat.Size                = UDim2.new(0, 165, 1, -38)
    barraLat.Position            = UDim2.new(0, 0, 0, 38)
    barraLat.BackgroundColor3    = Theme.PanelLight
    barraLat.BackgroundTransparency = Theme.PanelLightTrans or 0.40
    barraLat.BorderSizePixel     = 0
    barraLat.ScrollingDirection  = Enum.ScrollingDirection.Y
    barraLat.CanvasSize          = UDim2.new(0, 0, 0, 0)
    barraLat.AutomaticCanvasSize = Enum.AutomaticSize.Y
    barraLat.ScrollBarThickness  = 3
    barraLat.ScrollBarImageColor3= Theme.Accent
    barraLat.ClipsDescendants    = true
    barraLat.Parent              = main
    LouisHub:Registrar(barraLat, "BackgroundColor3", "PanelLight")

    local layoutSidebar = Instance.new("UIListLayout", barraLat)
    layoutSidebar.Padding = UDim.new(0, 4)
    layoutSidebar.SortOrder = Enum.SortOrder.LayoutOrder

    local padSidebar = Instance.new("UIPadding", barraLat)
    padSidebar.PaddingTop = UDim.new(0, 8); padSidebar.PaddingBottom = UDim.new(0, 10)
    padSidebar.PaddingLeft = UDim.new(0, 8); padSidebar.PaddingRight = UDim.new(0, 8)

    -- Content Area Container (Strict Anti-Bocor)
    local contenedorPaginas = Utils.Frame({
        Padre = main, Size = UDim2.new(1, -165, 1, -38),
        Posicion = UDim2.new(0, 165, 0, 38), Transparencia = 1,
        Radio = false, Borde = false, Recortar = true,
    })

    -- Search Box (Debounced Engine)
    local searchBox = Instance.new("TextBox", barraLat)
    searchBox.Size             = UDim2.new(1, 0, 0, 24)
    searchBox.BackgroundColor3 = Theme.Input
    searchBox.BackgroundTransparency = Theme.InputTrans or 0.25
    searchBox.PlaceholderText  = "🔍 Search features..."
    searchBox.Text             = ""
    searchBox.TextColor3       = Theme.TextPrimary
    searchBox.Font             = Enum.Font.Ubuntu
    searchBox.TextSize         = 11
    searchBox.BorderSizePixel  = 0
    searchBox.ClearTextOnFocus = false
    searchBox.LayoutOrder      = 0
    Utils.Corner(searchBox, 6)

    local searchId = 0
    searchBox:GetPropertyChangedSignal("Text"):Connect(function()
        searchId = searchId + 1
        local curId = searchId
        local q = searchBox.Text:lower()
        task.delay(0.12, function()
            if curId ~= searchId then return end
            for _, item in ipairs(indiceBusqueda) do
                local match = (q == "") or (item.texto:find(q, 1, true) ~= nil)
                item.fila.Visible = match and _Internal.cumpleVisibilidadCondicional(item.fila)
            end
            for _, sec in ipairs(seccionesRegistradas) do
                if q ~= "" and sec.colapsada and sec.AplicarColapsada then
                    sec.AplicarColapsada(false)
                end
            end
        end)
    end)

    local Ventana = {
        Tabs = {}, Categorias = {}, NombreConfig = config.NombreConfig or "default",
        _main = main, __isElement = true,
    }
    _Internal.activeSaveWindow = Ventana

    -- ===============================================================
    --  WINDOW LEVEL EXTENSIONS: TAGS, DIVIDERS & THEME SELECTOR (V2)
    -- ===============================================================
    local contenedorTags
    local COLORES_TAG = {
        info    = Color3.fromRGB(70, 130, 210),
        warning = Color3.fromRGB(215, 160, 50),
        success = Color3.fromRGB(70, 170, 100),
        danger  = Color3.fromRGB(190, 60, 60),
        neutral = Color3.fromRGB(95, 100, 110),
    }

    function Ventana:AgregarTag(cfg)
        if type(cfg) == "string" then cfg = { Texto = cfg } end
        cfg = cfg or {}
        if not contenedorTags then
            contenedorTags = Utils.Frame({
                Padre = barraTitulo, Size = UDim2.new(0.5, 0, 0, 18),
                Posicion = UDim2.new(1, -86, 0.5, 0), Ancla = Vector2.new(1, 0.5),
                Transparencia = 1, Radio = false, Borde = false, Recortar = true,
            })
            lblTit.Size = UDim2.new(0.35, 0, 0, 18)
            lblSub.Size = UDim2.new(0.35, 0, 0, 14)
            local lTags = Instance.new("UIListLayout", contenedorTags)
            lTags.FillDirection = Enum.FillDirection.Horizontal
            lTags.HorizontalAlignment = Enum.HorizontalAlignment.Right
            lTags.VerticalAlignment = Enum.VerticalAlignment.Center
            lTags.Padding = UDim.new(0, 4)
        end

        local pastilla = Utils.Frame({
            Padre = contenedorTags, Size = UDim2.new(0, 0, 0, 16),
            Color = COLORES_TAG.info, Radio = 8, Borde = false, Recortar = true,
        })
        pastilla.AutomaticSize = Enum.AutomaticSize.X
        local relPad = Instance.new("UIPadding", pastilla)
        relPad.PaddingLeft, relPad.PaddingRight = UDim.new(0, 7), UDim.new(0, 7)

        local lblTag = Utils.Texto({
            Padre = pastilla, Texto = tostring(cfg.Texto or "TAG"),
            Size = UDim2.new(0, 0, 1, 0), Variante = "Badge",
            Color = Color3.fromRGB(255, 255, 255),
        })
        lblTag.AutomaticSize = Enum.AutomaticSize.X

        local function applyTagColor(col)
            if col == "rainbow" then
                pastilla.BackgroundColor3 = Color3.new(1, 1, 1)
                local g = Instance.new("UIGradient", pastilla)
                g.Color = ColorSequence.new({
                    ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
                    ColorSequenceKeypoint.new(0.5, Color3.fromRGB(80, 255, 120)),
                    ColorSequenceKeypoint.new(1, Color3.fromRGB(80, 120, 255)),
                })
                TweenService:Create(g, TweenInfo.new(3, Enum.EasingStyle.Linear, Enum.EasingDirection.In, -1), {Rotation = 360}):Play()
                return
            end
            pastilla.BackgroundColor3 = (type(col) == "string" and COLORES_TAG[col]) or (typeof(col) == "Color3" and col) or COLORES_TAG.info
        end
        applyTagColor(cfg.Color)

        return {
            SetTexto = function(_, t) lblTag.Text = tostring(t) end,
            SetColor = function(_, c) applyTagColor(c) end,
            Remover  = function() pastilla:Destroy() end
        }
    end

    function Ventana:AgregarSelectorTemas()
        if self._btnSelectorTemas then return self._btnSelectorTemas end
        local nombres = {}
        for n in pairs(LouisHub.ThemeManager.Temas) do table.insert(nombres, n) end
        table.sort(nombres)
        if #nombres == 0 then return end

        local idx = 1
        local btn = Utils.BotonBase({
            Padre = barraLat, Size = UDim2.new(1, 0, 0, 26),
            Color = Theme.Row, Transparencia = 0.35, Orden = 9999, Radio = 8,
        })
        Utils.Hover(btn, btn)
        local lbl = Utils.Texto({
            Padre = btn, Texto = "🎨 " .. nombres[idx], Tamano = 11,
            Alineacion = Enum.TextXAlignment.Center, Variante = "Title",
        })
        btn.MouseButton1Click:Connect(function()
            idx = (idx % #nombres) + 1
            lbl.Text = "🎨 " .. nombres[idx]
            LouisHub.ThemeManager:AplicarTema(nombres[idx])
        end)
        self._btnSelectorTemas = btn
        self._SincronizarSelectorTemas = function(name)
            lbl.Text = "🎨 " .. (name or "Custom")
            if name then
                for i, v in ipairs(nombres) do if v == name then idx = i break end end
            end
        end
        _Internal.registeredThemeWindows[self] = true
        return btn
    end

    local ordenDivSidebar = 1000
    function Ventana:AgregarDivisorSidebar(cfg)
        cfg = cfg or {}
        ordenDivSidebar = ordenDivSidebar + 1
        local marcoLat = Utils.Frame({
            Padre = barraLat, Size = UDim2.new(1, 0, 0, cfg.Texto and 22 or 9),
            Transparencia = 1, Orden = ordenDivSidebar, Radio = false, Borde = false,
        })
        if cfg.Texto then
            Utils.Texto({
                Padre = marcoLat, Texto = tostring(cfg.Texto), Size = UDim2.new(1, -8, 1, -4),
                Posicion = UDim2.new(0, 4, 0, 0), Variante = "Badge", Tamano = 9, ColorTema = "TextMuted", Truncar = true,
            })
        end
        local line = Utils.Frame({
            Padre = marcoLat, Size = UDim2.new(1, -8, 0, 1), Posicion = UDim2.new(0, 4, 1, -2),
            Color = Theme.Border, Transparencia = 0.4, Radio = false, Borde = false,
        })
        return { InstanciaLat = marcoLat, __isElement = true }
    end

    -- ===============================================================
    --  3-TIER HIERARCHY: LEVEL 1 (CATEGORY) & LEVEL 2 (TAB)
    -- ===============================================================
    local ordenCategoria = 1
    local defaultCategoria = nil
    local primeraTabGlobal = true

    function Ventana:CrearCategoria(nombreCat)
        nombreCat = nombreCat or "General"
        if self.Categorias[nombreCat] then return self.Categorias[nombreCat] end
        ordenCategoria = ordenCategoria + 1

        local labelCat = Utils.Texto({
            Padre = barraLat, Texto = string.upper(nombreCat),
            Size = UDim2.new(1, -4, 0, 20), Posicion = UDim2.new(0, 4, 0, 0),
            Variante = "Badge", Tamano = 9, ColorTema = "TextMuted",
            Orden = ordenCategoria * 100, Truncar = true,
        })

        local Categoria = { Nombre = nombreCat, Header = labelCat, Tabs = {}, __isElement = true }

        function Categoria:CrearTab(nombreTab, iconoTab)
            return Ventana:CrearTab(nombreTab, iconoTab, self)
        end

        self.Categorias[nombreCat] = Categoria
        return Categoria
    end

    function Ventana:CrearTab(nombre, icono, categoriaObj)
        nombre = nombre or "Tab"
        icono  = icono or "▪"

        if not categoriaObj then
            if not defaultCategoria then
                defaultCategoria = self:CrearCategoria("Main Navigation")
            end
            categoriaObj = defaultCategoria
        end

        local ordenTabItem = #categoriaObj.Tabs + 1
        local botonTab = Utils.BotonBase({
            Padre = barraLat, Size = UDim2.new(1, 0, 0, 30),
            Color = Theme.Row, Transparencia = Theme.RowTrans or 0.38,
            Orden = (categoriaObj.Header.LayoutOrder) + ordenTabItem, Radio = 8,
        })
        Utils.Hover(botonTab, botonTab)

        local indTab = Utils.Frame({
            Padre = botonTab, Size = UDim2.new(0, 3, 1, -8), Posicion = UDim2.new(0, 2, 0, 4),
            Color = Theme.Accent, Radio = 2, Borde = false,
        })
        indTab.BackgroundTransparency = 1
        LouisHub:Registrar(indTab, "BackgroundColor3", "Accent")

        local lblIcon = Utils.Texto({
            Padre = botonTab, Texto = icono, Size = UDim2.new(0, 22, 1, 0),
            Posicion = UDim2.new(0, 6, 0, 0), Variante = "Title", Tamano = 13,
            Alineacion = Enum.TextXAlignment.Center,
        })
        local lblTab = Utils.Texto({
            Padre = botonTab, Texto = nombre, Size = UDim2.new(1, -34, 1, 0),
            Posicion = UDim2.new(0, 32, 0, 0), Variante = "Body", Tamano = 11,
            Truncar = true,
        })

        -- Tab Base Container
        local paginaTab = Utils.Frame({
            Padre = contenedorPaginas, Size = UDim2.new(1, 0, 1, 0),
            Transparencia = 1, Borde = false, Recortar = true,
            Visible = primeraTabGlobal,
        })

        -- Sub-Tab Horizontal Segmented Switcher Bar (Requirement 8)
        local barSubTabs = Utils.Frame({
            Padre = paginaTab, Size = UDim2.new(1, -20, 0, 30),
            Posicion = UDim2.new(0, 10, 0, 8), Color = Theme.Input,
            Transparencia = Theme.InputTrans or 0.25, Radio = 8,
            Borde = true, ColorBorde = Theme.Border, Recortar = true,
            Visible = false,
        })
        local layoutSubTabs = Instance.new("UIListLayout", barSubTabs)
        layoutSubTabs.FillDirection = Enum.FillDirection.Horizontal
        layoutSubTabs.Padding = UDim.new(0, 4)
        layoutSubTabs.SortOrder = Enum.SortOrder.LayoutOrder

        local padSubTabs = Instance.new("UIPadding", barSubTabs)
        padSubTabs.PaddingLeft = UDim.new(0, 4); padSubTabs.PaddingRight = UDim.new(0, 4)
        padSubTabs.PaddingTop = UDim.new(0, 3); padSubTabs.PaddingBottom = UDim.new(0, 3)

        local contenedorSubPages = Utils.Frame({
            Padre = paginaTab, Size = UDim2.new(1, 0, 1, 0),
            Posicion = UDim2.new(0, 0, 0, 0), Transparencia = 1,
            Radio = false, Borde = false, Recortar = true,
        })

        local Tab = {
            Nombre = nombre, Boton = botonTab, Indicador = indTab,
            Pagina = paginaTab, SubTabs = {}, SubTabActiva = nil,
            __isElement = true,
        }

        local function seleccionarTab()
            for _, t in ipairs(Ventana.Tabs) do
                t.Pagina.Visible = false
                Utils.Tween(t.Indicador, {BackgroundTransparency = 1}, LouisHub.Motion.Hover)
            end
            paginaTab.Visible = true
            Utils.Tween(indTab, {BackgroundTransparency = 0}, LouisHub.Motion.Hover)
            LouisHub.Eventos.TabCambiada:Fire(nombre)
        end
        Utils.ClickConfiable(botonTab, seleccionarTab, botonTab)

        if primeraTabGlobal then
            indTab.BackgroundTransparency = 0
            primeraTabGlobal = false
        end

        local ordenDivTab = 0
        function Tab:CrearDivisor(cfg)
            cfg = cfg or {}
            ordenDivTab = ordenDivTab + 1
            local marcoDiv = Utils.Frame({
                Padre = paginaTab, Size = UDim2.new(1, 0, 0, cfg.Texto and 26 or 10),
                Transparencia = 1, Orden = ordenDivTab, Radio = false, Borde = false,
            })
            if cfg.Texto then
                Utils.Texto({
                    Padre = marcoDiv, Texto = tostring(cfg.Texto), Size = UDim2.new(1, -24, 1, -4),
                    Posicion = UDim2.new(0, 12, 0, 0), Variante = "Title", Tamano = 11, ColorTema = "TextMuted",
                })
            end
            local line = Utils.Frame({
                Padre = marcoDiv, Size = UDim2.new(1, -24, 0, 1), Posicion = UDim2.new(0, 12, 1, -2),
                Color = Theme.Border, Transparencia = 0.4, Radio = false, Borde = false,
            })
            return { Instancia = marcoDiv, __isElement = true }
        end

        -- ===============================================================
        --  LEVEL 3: SUB-TAB & PRE-PATCHED 2-COLUMN ANTI-OVERLAP GRID
        -- ===============================================================
        function Tab:CrearSubTab(nombreSub, iconoSub)
            nombreSub = nombreSub or "SubTab"
            iconoSub  = iconoSub and (iconoSub .. " ") or ""

            if #self.SubTabs >= 1 then
                barSubTabs.Visible = true
                contenedorSubPages.Position = UDim2.new(0, 0, 0, 42)
                contenedorSubPages.Size     = UDim2.new(1, 0, 1, -42)
            end

            local ordenSub = #self.SubTabs + 1
            local btnSub = Utils.BotonBase({
                Padre = barSubTabs, Size = UDim2.new(0, 0, 1, 0),
                Color = Theme.Row, Transparencia = (ordenSub == 1) and 0.2 or 0.6,
                Radio = 6, Orden = ordenSub,
            })
            btnSub.AutomaticSize = Enum.AutomaticSize.X

            local padBtnSub = Instance.new("UIPadding", btnSub)
            padBtnSub.PaddingLeft = UDim.new(0, 12); padBtnSub.PaddingRight = UDim.new(0, 12)

            local lblSubBtn = Utils.Texto({
                Padre = btnSub, Texto = iconoSub .. nombreSub,
                Size = UDim2.new(1, 0, 1, 0), Variante = "Title", Tamano = 11,
                Alineacion = Enum.TextXAlignment.Center,
                Color = (ordenSub == 1) and Theme.Highlight or Theme.TextMuted,
            })
            lblSubBtn.AutomaticSize = Enum.AutomaticSize.X

            -- SubTab Content Scrolling Frame (Strict Anti-Bocor)
            local subScroll = Instance.new("ScrollingFrame")
            subScroll.Name                = "SubScroll_" .. nombreSub
            subScroll.Size                = UDim2.new(1, 0, 1, 0)
            subScroll.BackgroundTransparency = 1
            subScroll.BorderSizePixel     = 0
            subScroll.ScrollBarThickness  = 4
            subScroll.ScrollBarImageColor3= Theme.Accent
            subScroll.CanvasSize          = UDim2.new(0, 0, 0, 0)
            subScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
            subScroll.ClipsDescendants    = true
            subScroll.Visible             = (ordenSub == 1)
            subScroll.Parent              = contenedorSubPages

            local padSubScroll = Instance.new("UIPadding", subScroll)
            padSubScroll.PaddingLeft = UDim.new(0, 10); padSubScroll.PaddingRight = UDim.new(0, 10)
            padSubScroll.PaddingTop = UDim.new(0, 8); padSubScroll.PaddingBottom = UDim.new(0, 12)

            -- PRE-PATCHED: UIListLayout for subScroll to stack 2-Column row and Full-Width row without overlap
            local laySubScroll = Instance.new("UIListLayout", subScroll)
            laySubScroll.Padding = UDim.new(0, 10)
            laySubScroll.SortOrder = Enum.SortOrder.LayoutOrder

            -- Container for 2 Columns (Left & Right)
            local gridTwoCol = Utils.Frame({
                Padre = subScroll, Size = UDim2.new(1, 0, 0, 0),
                Transparencia = 1, Radio = false, Borde = false, Recortar = true,
                Orden = 1,
            })
            gridTwoCol.AutomaticSize = Enum.AutomaticSize.Y

            -- Left Column (Column 1)
            local colIzq = Utils.Frame({
                Padre = gridTwoCol,
                Size = UDim2.new(0.5, -5, 0, 0),
                Posicion = UDim2.new(0, 0, 0, 0),
                Transparencia = 1, Radio = false, Borde = false, Recortar = true,
            })
            colIzq.AutomaticSize = Enum.AutomaticSize.Y
            local layIzq = Instance.new("UIListLayout", colIzq)
            layIzq.Padding = UDim.new(0, 8)
            layIzq.SortOrder = Enum.SortOrder.LayoutOrder

            -- Right Column (Column 2)
            local colDer = Utils.Frame({
                Padre = gridTwoCol,
                Size = UDim2.new(0.5, -5, 0, 0),
                Posicion = UDim2.new(0.5, 5, 0, 0),
                Transparencia = 1, Radio = false, Borde = false, Recortar = true,
            })
            colDer.AutomaticSize = Enum.AutomaticSize.Y
            local layDer = Instance.new("UIListLayout", colDer)
            layDer.Padding = UDim.new(0, 8)
            layDer.SortOrder = Enum.SortOrder.LayoutOrder

            -- Full Width Container (Pre-patched: stacks safely below gridTwoCol without overlapping)
            local colFull = Utils.Frame({
                Padre = subScroll,
                Size = UDim2.new(1, 0, 0, 0),
                Transparencia = 1, Radio = false, Borde = false, Recortar = true,
                Orden = 2,
            })
            colFull.AutomaticSize = Enum.AutomaticSize.Y
            local layFull = Instance.new("UIListLayout", colFull)
            layFull.Padding = UDim.new(0, 8)
            layFull.SortOrder = Enum.SortOrder.LayoutOrder

            local SubTab = {
                Nombre = nombreSub, Boton = btnSub, Scroll = subScroll,
                ColIzq = colIzq, ColDer = colDer, ColFull = colFull,
                TotalIzq = 0, TotalDer = 0, Secciones = {},
                __isElement = true,
            }

            local function seleccionarSubTab()
                for _, st in ipairs(Tab.SubTabs) do
                    st.Scroll.Visible = false
                    Utils.Tween(st.Boton, {BackgroundTransparency = 0.6}, LouisHub.Motion.Hover)
                    local l = st.Boton:FindFirstChildOfClass("TextLabel")
                    if l then l.TextColor3 = Theme.TextMuted end
                end
                subScroll.Visible = true
                Tab.SubTabActiva = SubTab
                Utils.Tween(btnSub, {BackgroundTransparency = 0.2}, LouisHub.Motion.Hover)
                lblSubBtn.TextColor3 = Theme.Highlight
                LouisHub.Eventos.SubTabCambiada:Fire(Tab.Nombre, nombreSub)
            end
            Utils.ClickConfiable(btnSub, seleccionarSubTab, btnSub)

            if ordenSub == 1 then
                Tab.SubTabActiva = SubTab
            end

            -- SECTION BUILDER (COLLAPSIBLE CARD + 2-COLUMN AUTO BALANCING)
            function SubTab:CrearSeccion(nombreSec, cfgSec)
                cfgSec = cfgSec or {}
                local colapsable = cfgSec.Colapsable ~= false
                local colapsadaPorDefecto = colapsable and (cfgSec.ColapsadaPorDefecto == true)

                -- 2-Column Placement Decision
                local targetCol
                if cfgSec.Columna == 1 then
                    targetCol = colIzq
                    self.TotalIzq = self.TotalIzq + 1
                elseif cfgSec.Columna == 2 then
                    targetCol = colDer
                    self.TotalDer = self.TotalDer + 1
                elseif cfgSec.Columna == "Full" or cfgSec.FullWidth then
                    targetCol = colFull
                else
                    if self.TotalIzq <= self.TotalDer then
                        targetCol = colIzq
                        self.TotalIzq = self.TotalIzq + 1
                    else
                        targetCol = colDer
                        self.TotalDer = self.TotalDer + 1
                    end
                end

                local marcoSec = Utils.Frame({
                    Padre = targetCol, Size = UDim2.new(1, 0, 0, 0),
                    Color = Theme.Panel, Transparencia = Theme.PanelTrans or 0.28,
                    Radio = 8, Borde = true, ColorBorde = Theme.Border,
                    Recortar = true,
                })
                marcoSec.AutomaticSize = Enum.AutomaticSize.Y
                LouisHub:Registrar(marcoSec, "BackgroundColor3", "Panel")

                local flecha, btnHeader
                if colapsable then
                    btnHeader = Utils.BotonBase({
                        Padre = marcoSec, Size = UDim2.new(1, 0, 0, 26),
                        Transparencia = 1, Radio = false, Borde = false,
                    })
                    Utils.Hover(btnHeader, marcoSec)

                    flecha = Instance.new("ImageLabel", btnHeader)
                    flecha.BackgroundTransparency = 1
                    flecha.Image = "rbxassetid://83472139709682"
                    flecha.ScaleType = Enum.ScaleType.Fit
                    flecha.Size = UDim2.new(0, 12, 0, 12)
                    flecha.AnchorPoint = Vector2.new(0.5, 0.5)
                    flecha.Position = UDim2.new(0, 12, 0.5, 0)
                    flecha.Rotation = colapsadaPorDefecto and -90 or 0
                    LouisHub:Registrar(flecha, "ImageColor3", "AccentLight")

                    Utils.Texto({
                        Padre = btnHeader, Texto = nombreSec or "Section",
                        Size = UDim2.new(1, -26, 1, 0), Posicion = UDim2.new(0, 24, 0, 0),
                        Variante = "Title", Tamano = 11, Color = Theme.AccentLight,
                    })
                else
                    Utils.Texto({
                        Padre = marcoSec, Texto = nombreSec or "Section",
                        Size = UDim2.new(1, -12, 0, 22), Posicion = UDim2.new(0, 10, 0, 3),
                        Variante = "Title", Tamano = 11, Color = Theme.AccentLight,
                    })
                end

                local contenedorControles = Utils.Frame({
                    Padre = marcoSec, Size = UDim2.new(1, 0, 0, 0),
                    Posicion = UDim2.new(0, 0, 0, 26), Transparencia = 1,
                    Radio = false, Borde = false, Recortar = true,
                    Visible = not colapsadaPorDefecto,
                })
                contenedorControles.AutomaticSize = Enum.AutomaticSize.Y

                local layControles = Instance.new("UIListLayout", contenedorControles)
                layControles.Padding = UDim.new(0, 6)
                layControles.SortOrder = Enum.SortOrder.LayoutOrder

                local padControles = Instance.new("UIPadding", contenedorControles)
                padControles.PaddingLeft = UDim.new(0, 8); padControles.PaddingRight = UDim.new(0, 8)
                padControles.PaddingTop = UDim.new(0, 6); padControles.PaddingBottom = UDim.new(0, 8)

                local entradaSec = {
                    marco = marcoSec, contenedor = contenedorControles,
                    flecha = flecha, colapsable = colapsable, colapsada = colapsadaPorDefecto,
                }

                local function aplicarColapsada(v)
                    entradaSec.colapsada = v
                    if flecha then
                        Utils.Tween(flecha, {Rotation = v and -90 or 0}, LouisHub.Motion.Expand)
                    end
                    contenedorControles.Visible = not v
                end
                entradaSec.AplicarColapsada = aplicarColapsada

                if colapsable and btnHeader then
                    Utils.ClickConfiable(btnHeader, function()
                        aplicarColapsada(not entradaSec.colapsada)
                    end)
                end

                table.insert(seccionesRegistradas, entradaSec)
                table.insert(self.Secciones, entradaSec)

                local Seccion = {
                    Marco = marcoSec, Contenedor = contenedorControles,
                    SubTab = self, Tab = Tab, __isElement = true,
                }

                if _Internal.vincularMetodosControles then
                    _Internal.vincularMetodosControles(Seccion, contenedorControles)
                else
                    table.insert(_Internal.pendingSections, { Seccion = Seccion, Contenedor = contenedorControles })
                end
                return Seccion
            end

            table.insert(Tab.SubTabs, SubTab)
            return SubTab
        end

        function Tab:CrearSeccion(nombreSec, cfgSec)
            if #self.SubTabs == 0 then
                self:CrearSubTab("General")
            end
            return self.SubTabs[1]:CrearSeccion(nombreSec, cfgSec)
        end

        table.insert(categoriaObj.Tabs, Tab)
        table.insert(Ventana.Tabs, Tab)
        return Tab
    end

    function Ventana:Destruir()
        if sg and sg.Parent then sg:Destroy() end
    end
    function Ventana:Minimizar() alternarVentana(false) end
    function Ventana:Mostrar() alternarVentana(true) end
    function Ventana:EstaVisible() return ventanaAbierta end

    -- PRE-PATCHED: Camera Scale & Window Resize Bridge Methods
    Ventana._setFactorAncho = function(v)
        factorAncho = v
        actualizarTamanoVentana()
        recalcularEscala()
    end

    Ventana._setFactorAlto = function(v)
        factorAlto = v
        actualizarTamanoVentana()
        recalcularEscala()
    end

    Ventana._setEscalaManual = function(v)
        escalaManual = v
        recalcularEscala()
    end

    return Ventana
end

-- ===================================================================
--  LOUIS HUB UI LIBRARY (V3.0 NEXT-GEN COMPLETE ENGINE)
--  Brand: Louis Hub
--  Priority: Zero-Leaks > Backward Compatibility > Glassmorphism > Performance
--  [PART 5 OF 6] - Complete 18 Input Controls & Schema Builder Engine
-- ===================================================================

local _Internal        = LouisHub._Internal
local Theme            = LouisHub.Theme
local Utils            = LouisHub.Utils
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TextService      = game:GetService("TextService")

local normalizeSetArg  = _Internal.normalizeSetArg
local safeSubUTF8      = _Internal.safeSubUTF8
local cloneTable       = _Internal.cloneTable
local executeCallback  = _Internal.executeCallback

function _Internal.vincularMetodosControles(Seccion, contenedor)
    local ordenElem = 0
    local function nextOrder()
        ordenElem = ordenElem + 1
        return ordenElem
    end

    local function crearCabecera(alto, txt, anchoLabel, offsetX, modo)
        local fila = Utils.Fila(contenedor, alto, nextOrder(), Theme.Row)
        Utils.Hover(fila, fila)
        if modo ~= "fijo" then
            local lblD = Utils.Texto({
                Padre = fila, Texto = txt, Size = UDim2.new(anchoLabel or 1, offsetX or -50, 1, 0),
                Variante = "Body", Tamano = 12, Ajustar = true,
            })
            if modo ~= "manual" then Utils.HacerFilaDinamica(fila, lblD, alto, 7) end
            return fila, lblD
        end
        local lbl = Utils.Texto({
            Padre = fila, Texto = txt, Size = UDim2.new(anchoLabel or 1, offsetX or -50, 1, 0),
            Variante = "Body", Tamano = 12, Truncar = true,
        })
        return fila, lbl
    end

    -- 1. BOTON
    function Seccion:Boton(cfg)
        cfg = cfg or {}
        local fila = Utils.BotonBase({
            Padre = contenedor, Size = UDim2.new(1, 0, 0, 32),
            Color = Theme.Row, Transparencia = Theme.RowTrans or 0.38,
            Orden = nextOrder(), Radio = 8,
        })
        Utils.Hover(fila, fila)

        local fullText = (cfg.Icono and (cfg.Icono .. " ") or "") .. (cfg.Texto or "Button")
        local lblBoton = Utils.Texto({ Padre = fila, Texto = fullText, Variante = "Title", Tamano = 12, RichText = cfg.RichText })
        local lblInteract
        if cfg.Interact ~= nil then
            lblBoton.Size = UDim2.new(0.6, -10, 1, 0)
            lblInteract = Utils.Texto({
                Padre = fila, Texto = tostring(cfg.Interact), Size = UDim2.new(0.4, -10, 1, 0),
                Posicion = UDim2.new(0.6, 0, 0, 0), Alineacion = Enum.TextXAlignment.Right,
                Variante = "Code", Tamano = 11, ColorTema = "TextAccent", Truncar = true,
            })
        end
        _Internal.agregarTooltipTexto(fila, cfg.Texto or "Button", cfg.Tooltip, lblBoton)
        _Internal.registrarBuscable(fila, cfg.Texto or "Button", cfg.VisibleSi)

        local spinner
        local function setSpinner(act)
            if act and not spinner then
                spinner = Utils.Texto({
                    Padre = fila, Texto = "◐", Size = UDim2.new(0, 20, 1, 0),
                    Posicion = UDim2.new(1, -26, 0, 0), Alineacion = Enum.TextXAlignment.Center,
                    Variante = "Title", Tamano = 14, ColorTema = "AccentLight",
                })
            end
            if spinner then
                spinner.Visible = act
                if act then
                    LouisHub:RegistrarHilo(task.spawn(function()
                        while spinner and spinner.Visible do
                            Utils.Tween(spinner, {Rotation = spinner.Rotation + 360}, LouisHub.Motion.Hover, LouisHub.Motion.EaseLinear)
                            task.wait(LouisHub.Motion.Hover)
                        end
                    end))
                end
            end
        end

        local enCurso = false
        Utils.ClickConfiable(fila, function()
            if cfg.Async and enCurso then return end
            Utils.FlashFeedback(fila, true, Theme.Row)
            if cfg.Callback then
                if cfg.Async then
                    enCurso = true; setSpinner(true)
                    task.spawn(function()
                        executeCallback(cfg.Callback, cfg.Texto or "Button")
                        enCurso = false
                        if fila and fila.Parent then setSpinner(false) end
                    end)
                else
                    executeCallback(cfg.Callback, cfg.Texto or "Button")
                end
            end
        end, fila)

        local proxy = Utils.EnvolverInstancia(fila)
        rawset(proxy, "SetInteract", function(_, t) if lblInteract then lblInteract.Text = tostring(t) end end)
        rawset(proxy, "GetInteract", function() return lblInteract and lblInteract.Text or "" end)
        return proxy
    end

    -- 2. TOGGLE
    function Seccion:Toggle(cfg)
        cfg = cfg or {}
        local flag = cfg.Flag or cfg.Texto or ("Toggle_" .. math.random(1e5, 1e6))
        local val  = cfg.Defecto or false
        LouisHub.Flags[flag] = val

        local fila, lbl = crearCabecera(32, cfg.Texto or "Toggle")
        _Internal.agregarTooltipTexto(fila, cfg.Texto or "Toggle", cfg.Tooltip, lbl)
        _Internal.registrarBuscable(fila, cfg.Texto or "Toggle", cfg.VisibleSi)

        local perilla = Utils.BotonBase({
            Padre = fila, Size = UDim2.new(0, 42, 0, 22), Posicion = UDim2.new(1, -48, 0.5, -11),
            Color = val and Theme.Accent or Theme.Off, Transparencia = 0.2, Radio = 11,
        })
        LouisHub:Registrar(perilla, "BackgroundColor3", function() return val and Theme.Accent or Theme.Off end)

        local circulo = Utils.Frame({
            Padre = perilla, Size = UDim2.new(0, 16, 0, 16),
            Posicion = val and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8),
            Color = Theme.TextPrimary, Transparencia = 0, Radio = 8, Borde = false,
        })
        LouisHub:Registrar(circulo, "BackgroundColor3", "TextPrimary")

        local function actualizar(v, disparar)
            if type(v) ~= "boolean" then return end
            val = v; LouisHub.Flags[flag] = v
            Utils.Tween(perilla, {BackgroundColor3 = v and Theme.Accent or Theme.Off}, LouisHub.Motion.Hover)
            Utils.Tween(circulo, {Position = v and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)}, LouisHub.Motion.PageSlide)
            if v == true and cfg.Desactivar then
                for _, otherFlag in ipairs(cfg.Desactivar) do
                    local target = LouisHub.Elementos[otherFlag]
                    if target and target.Get() == true then target.Set(false, true) end
                end
            end
            if disparar and cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, v) end
        end

        local hbToggle = Utils.HitboxAmpliado(perilla, 8)
        Utils.ClickConfiable(hbToggle, function() actualizar(not val, true) end, perilla)

        if cfg.Tecla then
            LouisHub:RegistrarConexion(UserInputService.InputBegan:Connect(function(inp, gpe)
                if not gpe and inp.KeyCode == cfg.Tecla then actualizar(not val, true) end
            end))
        end

        local elemObj = {
            Set = function(...) actualizar(normalizeSetArg(...), true) end,
            Get = function() return val end,
            __isElement = true, _flag = flag,
        }
        LouisHub.Elementos[flag] = { Set = function(v, d) actualizar(v, d or false) end, Get = function() return val end }
        return elemObj
    end

    -- 3. CASILLA (CHECKBOX)
    function Seccion:Casilla(cfg)
        cfg = cfg or {}
        local flag = cfg.Flag or cfg.Texto or ("Casilla_" .. math.random(1e5, 1e6))
        local val  = cfg.Defecto or false
        LouisHub.Flags[flag] = val

        local fila, lbl = crearCabecera(32, cfg.Texto or "Casilla")
        _Internal.agregarTooltipTexto(fila, cfg.Texto or "Casilla", cfg.Tooltip, lbl)
        _Internal.registrarBuscable(fila, cfg.Texto or "Casilla", cfg.VisibleSi)

        local caja = Utils.BotonBase({
            Padre = fila, Size = UDim2.new(0, 20, 0, 20), Posicion = UDim2.new(1, -28, 0.5, -10),
            Color = val and Theme.Accent or Theme.Input, Transparencia = 0.2, Radio = 5,
        })
        LouisHub:Registrar(caja, "BackgroundColor3", function() return val and Theme.Accent or Theme.Input end)
        Utils.Stroke(caja, Theme.Border, 1)

        local check = Utils.Frame({ Padre = caja, Size = UDim2.new(1, 0, 1, 0), Transparencia = 1, Borde = false })
        local tCorto = Utils.Frame({
            Padre = check, Size = UDim2.new(0, 6, 0, 2), Posicion = UDim2.new(0.5, -6, 0.5, 1),
            Color = Theme.TextPrimary, Transparencia = val and 0 or 1, Radio = 1, Borde = false,
        })
        tCorto.Rotation = 45
        local tLargo = Utils.Frame({
            Padre = check, Size = UDim2.new(0, 11, 0, 2), Posicion = UDim2.new(0.5, -3, 0.5, -3),
            Color = Theme.TextPrimary, Transparencia = val and 0 or 1, Radio = 1, Borde = false,
        })
        tLargo.Rotation = -45

        local function actualizar(v, disparar)
            if type(v) ~= "boolean" then return end
            val = v; LouisHub.Flags[flag] = v
            Utils.Tween(caja, {BackgroundColor3 = v and Theme.Accent or Theme.Input}, LouisHub.Motion.Hover)
            Utils.Tween(tCorto, {BackgroundTransparency = v and 0 or 1}, LouisHub.Motion.Hover)
            Utils.Tween(tLargo, {BackgroundTransparency = v and 0 or 1}, LouisHub.Motion.Hover)
            if disparar and cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, v) end
        end

        local hb = Utils.HitboxAmpliado(caja, 8)
        Utils.ClickConfiable(hb, function() actualizar(not val, true) end, caja)

        local elemObj = {
            Set = function(...) actualizar(normalizeSetArg(...), true) end,
            Get = function() return val end,
            __isElement = true, _flag = flag,
        }
        LouisHub.Elementos[flag] = { Set = function(v, d) actualizar(v, d or false) end, Get = function() return val end }
        return elemObj
    end

    -- 4. SLIDER
    function Seccion:Slider(cfg)
        cfg = cfg or {}
        local flag   = cfg.Flag or cfg.Texto or ("Slider_" .. math.random(1e5, 1e6))
        local minimo = cfg.Min or 0
        local maximo = cfg.Max or 100
        if minimo >= maximo then maximo = minimo + 1 end
        local inc    = (cfg.Incremento and cfg.Incremento > 0) and cfg.Incremento or 1
        local sufijo = cfg.Sufijo or ""
        local val    = math.clamp(cfg.Defecto or minimo, minimo, maximo)
        LouisHub.Flags[flag] = val

        local fila = Utils.Fila(contenedor, 56, nextOrder(), Theme.Row)
        Utils.Hover(fila, fila)
        _Internal.registrarBuscable(fila, cfg.Texto or "Slider", cfg.VisibleSi)

        local lblSlider = Utils.Texto({
            Padre = fila, Texto = cfg.Texto or "Slider", Size = UDim2.new(1, -95, 0, 18),
            Posicion = UDim2.new(0, 8, 0, 6), Variante = "Body", Truncar = true,
        })
        _Internal.agregarTooltipTexto(fila, cfg.Texto or "Slider", cfg.Tooltip, lblSlider, -95)

        local inputValor = Instance.new("TextBox", fila)
        inputValor.Size = UDim2.new(0, 85, 0, 22)
        inputValor.Position = UDim2.new(1, -90, 0, 6)
        inputValor.BackgroundColor3 = Theme.Input
        inputValor.BackgroundTransparency = Theme.InputTrans or 0.25
        inputValor.Text = tostring(val) .. sufijo
        inputValor.TextColor3 = Theme.Highlight
        inputValor.Font = Enum.Font.FredokaOne
        inputValor.TextSize = 13
        inputValor.TextXAlignment = Enum.TextXAlignment.Center
        inputValor.BorderSizePixel = 0
        inputValor.ClearTextOnFocus = false
        Utils.Corner(inputValor, 5)

        local function redondear(v)
            local factor = 1 / inc
            return math.clamp(math.floor((v - minimo) * factor + 0.5) / factor + minimo, minimo, maximo)
        end

        local decCount = 0
        local decStr = tostring(inc):match("%.(%d+)$")
        if decStr then decCount = #decStr end
        local function formatNum(n)
            return (decCount > 0) and string.format("%." .. decCount .. "f", n) or tostring(math.floor(n + 0.5))
        end

        local ultimoProcesado = val
        local function procesarNuevo(vRaw)
            local v = redondear(vRaw)
            if v == ultimoProcesado then return end
            ultimoProcesado = v; val = v
            LouisHub.Flags[flag] = v
            inputValor.Text = formatNum(v) .. sufijo
            if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, v) end
        end

        local barra, _, fijarVis = _Internal.crearBarraArrastrable({
            Padre = fila, Size = UDim2.new(1, -16, 0, 8), Posicion = UDim2.new(0, 8, 0, 36),
            Min = minimo, Max = maximo, Valor = val, Incremento = inc, Pasos = cfg.Pasos,
            AltoHitbox = 18, OnCambio = procesarNuevo,
        })

        inputValor.FocusLost:Connect(function(enter)
            if not enter then return end
            local raw = inputValor.Text:gsub("%s+", "")
            if sufijo ~= "" and raw:sub(-#sufijo) == sufijo then raw = raw:sub(1, -#sufijo - 1) end
            local n = tonumber(raw)
            if n then
                n = redondear(n); ultimoProcesado = n; val = n
                LouisHub.Flags[flag] = n; inputValor.Text = formatNum(n) .. sufijo; fijarVis(n)
                Utils.FlashFeedback(inputValor, true, Theme.Input)
                if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, n) end
            else
                inputValor.Text = formatNum(val) .. sufijo
                Utils.FlashFeedback(inputValor, false, Theme.Input)
            end
        end)

        local elemObj = {
            Set = function(...)
                local v = normalizeSetArg(...)
                if type(v) ~= "number" then return end
                v = redondear(v); ultimoProcesado = v; val = v
                LouisHub.Flags[flag] = v; inputValor.Text = formatNum(v) .. sufijo; fijarVis(v)
                if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, v) end
            end,
            Get = function() return val end,
            __isElement = true, _flag = flag,
        }
        LouisHub.Elementos[flag] = {
            Set = function(v, d)
                if type(v) ~= "number" then return end
                v = redondear(v); ultimoProcesado = v; val = v
                LouisHub.Flags[flag] = v; inputValor.Text = formatNum(v) .. sufijo; fijarVis(v)
                if d and cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, v) end
            end,
            Get = function() return val end,
        }
        return elemObj
    end

    -- 5. RANGE SLIDER (DUAL THUMBS)
    function Seccion:RangeSlider(cfg)
        cfg = cfg or {}
        local flag   = cfg.Flag or cfg.Texto or ("RangeSlider_" .. math.random(1e5, 1e6))
        local minimo = cfg.Min or 0
        local maximo = cfg.Max or 100
        if minimo >= maximo then maximo = minimo + 1 end
        local inc    = (cfg.Incremento and cfg.Incremento > 0) and cfg.Incremento or 1
        local sufijo = cfg.Sufijo or ""

        local def = cfg.Defecto or {}
        local vMin = math.clamp(def.min or (def[1] or minimo), minimo, maximo)
        local vMax = math.clamp(def.max or (def[2] or maximo), minimo, maximo)
        if vMin > vMax then vMin, vMax = vMax, vMin end

        local function getVal() return { min = vMin, max = vMax } end
        LouisHub.Flags[flag] = getVal()

        local fila = Utils.Fila(contenedor, 56, nextOrder(), Theme.Row)
        Utils.Hover(fila, fila)
        _Internal.registrarBuscable(fila, cfg.Texto or "RangeSlider", cfg.VisibleSi)

        local lblS = Utils.Texto({
            Padre = fila, Texto = cfg.Texto or "RangeSlider", Size = UDim2.new(1, -125, 0, 18),
            Posicion = UDim2.new(0, 8, 0, 6), Variante = "Body", Truncar = true,
        })
        _Internal.agregarTooltipTexto(fila, cfg.Texto or "RangeSlider", cfg.Tooltip, lblS, -125)

        local lblVal = Utils.Texto({
            Padre = fila, Size = UDim2.new(0, 115, 0, 18), Posicion = UDim2.new(1, -120, 0, 6),
            Alineacion = Enum.TextXAlignment.Right, Variante = "Code", Tamano = 11, Color = Theme.Highlight,
        })

        local function refreshText()
            lblVal.Text = tostring(vMin) .. sufijo .. " – " .. tostring(vMax) .. sufijo
        end
        refreshText()

        local function redondear(v)
            local factor = 1 / inc
            return math.clamp(math.floor((v - minimo) * factor + 0.5) / factor + minimo, minimo, maximo)
        end

        local ultimoMin, ultimoMax = vMin, vMax
        local function onRngChange(mi, ma)
            mi, ma = redondear(mi), redondear(ma)
            if mi > ma then mi, ma = ma, mi end
            if mi == ultimoMin and ma == ultimoMax then return end
            ultimoMin, ultimoMax = mi, ma; vMin, vMax = mi, ma
            LouisHub.Flags[flag] = getVal(); refreshText()
            if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, getVal()) end
        end

        local _, fijarVisR = _Internal.crearBarraArrastrableRango({
            Padre = fila, Size = UDim2.new(1, -16, 0, 8), Posicion = UDim2.new(0, 8, 0, 36),
            Min = minimo, Max = maximo, ValorMin = vMin, ValorMax = vMax,
            ObtenerMin = function() return ultimoMin end,
            ObtenerMax = function() return ultimoMax end,
            OnCambio = onRngChange,
        })

        local elemObj = {
            Set = function(...)
                local v = normalizeSetArg(...)
                if type(v) ~= "table" then return end
                vMin = redondear(v.min or (v[1] or vMin))
                vMax = redondear(v.max or (v[2] or vMax))
                if vMin > vMax then vMin, vMax = vMax, vMin end
                ultimoMin, ultimoMax = vMin, vMax; LouisHub.Flags[flag] = getVal()
                refreshText(); fijarVisR(vMin, vMax)
                if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, getVal()) end
            end,
            Get = getVal,
            __isElement = true, _flag = flag,
        }
        LouisHub.Elementos[flag] = { Set = elemObj.Set, Get = getVal }
        return elemObj
    end

    -- 6. NUMBER STEPPER
    function Seccion:NumberStepper(cfg)
        cfg = cfg or {}
        local flag   = cfg.Flag or cfg.Texto or ("Stepper_" .. math.random(1e5, 1e6))
        local minimo = cfg.Min or 0
        local maximo = cfg.Max or 100
        if minimo >= maximo then maximo = minimo + 1 end
        local inc    = (cfg.Incremento and cfg.Incremento > 0) and cfg.Incremento or 1
        local pref   = cfg.Prefijo or ""
        local suf    = cfg.Sufijo or ""

        local function redondear(v)
            local factor = 1 / inc
            return math.clamp(math.floor((v - minimo) * factor + 0.5) / factor + minimo, minimo, maximo)
        end
        local val = redondear(cfg.Defecto or minimo)
        LouisHub.Flags[flag] = val

        local fila, lbl = crearCabecera(32, cfg.Texto or "Stepper", 1, -150)
        _Internal.agregarTooltipTexto(fila, cfg.Texto or "Stepper", cfg.Tooltip, lbl)
        _Internal.registrarBuscable(fila, cfg.Texto or "Stepper", cfg.VisibleSi)

        local btnMenos = Utils.BotonBase({
            Padre = fila, Color = Theme.Input, Transparencia = 0.25, Radio = 5,
            Size = UDim2.new(0, 26, 0, 22), Posicion = UDim2.new(1, -145, 0.5, -11),
        })
        Utils.Texto({ Padre = btnMenos, Texto = "−", Size = UDim2.new(1, 0, 1, 0), Alineacion = Enum.TextXAlignment.Center, Variante = "Title", Tamano = 13 })

        local caja = Instance.new("TextBox", fila)
        caja.Size = UDim2.new(0, 80, 0, 22)
        caja.Position = UDim2.new(1, -115, 0.5, -11)
        caja.BackgroundColor3 = Theme.Input
        caja.BackgroundTransparency = Theme.InputTrans or 0.25
        caja.Text = pref .. tostring(val) .. suf
        caja.TextColor3 = Theme.Highlight
        caja.Font = Enum.Font.FredokaOne
        caja.TextSize = 12
        caja.TextXAlignment = Enum.TextXAlignment.Center
        caja.ClearTextOnFocus = false
        caja.BorderSizePixel = 0
        Utils.Corner(caja, 5)

        local btnMas = Utils.BotonBase({
            Padre = fila, Color = Theme.Input, Transparencia = 0.25, Radio = 5,
            Size = UDim2.new(0, 26, 0, 22), Posicion = UDim2.new(1, -31, 0.5, -11),
        })
        Utils.Texto({ Padre = btnMas, Texto = "+", Size = UDim2.new(1, 0, 1, 0), Alineacion = Enum.TextXAlignment.Center, Variante = "Title", Tamano = 13 })

        local function step(sign)
            local n = redondear(val + sign * inc)
            if n == val then return end
            val = n; LouisHub.Flags[flag] = val
            caja.Text = pref .. tostring(val) .. suf
            if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, val) end
        end

        local pressId = 0
        local function bindHold(btn, sgn)
            btn.MouseButton1Down:Connect(function()
                pressId = pressId + 1; local myP = pressId; step(sgn)
                task.spawn(function()
                    task.wait(0.35)
                    while pressId == myP and btn.Parent do step(sgn); task.wait(0.08) end
                end)
            end)
            local stop = function() pressId = pressId + 1 end
            btn.MouseButton1Up:Connect(stop); btn.MouseLeave:Connect(stop)
        end
        bindHold(btnMenos, -1); bindHold(btnMas, 1)

        caja.FocusLost:Connect(function(enter)
            if not enter then return end
            local t = caja.Text
            if pref ~= "" and t:sub(1, #pref) == pref then t = t:sub(#pref + 1) end
            if suf ~= "" and t:sub(-#suf) == suf then t = t:sub(1, -#suf - 1) end
            local n = tonumber(t)
            if n then
                val = redondear(n); LouisHub.Flags[flag] = val; caja.Text = pref .. tostring(val) .. suf
                Utils.FlashFeedback(caja, true, Theme.Input)
                if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, val) end
            else
                caja.Text = pref .. tostring(val) .. suf
                Utils.FlashFeedback(caja, false, Theme.Input)
            end
        end)

        local elemObj = {
            Set = function(...)
                local v = normalizeSetArg(...)
                if type(v) ~= "number" then return end
                val = redondear(v); LouisHub.Flags[flag] = val; caja.Text = pref .. tostring(val) .. suf
                if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, val) end
            end,
            Get = function() return val end,
            __isElement = true, _flag = flag,
        }
        LouisHub.Elementos[flag] = { Set = elemObj.Set, Get = function() return val end }
        return elemObj
    end

    -- 7. INPUT (NUMBER & PATTERN VALIDATION RESTORED FROM V2)
    function Seccion:Input(cfg)
        cfg = cfg or {}
        local flag   = cfg.Flag or cfg.Texto or ("Input_" .. math.random(1e5, 1e6))
        local val    = tostring(cfg.Defecto or "")
        local esArea = cfg.Tipo == "textarea"
        local altoA  = math.clamp(cfg.Alto or 85, 45, 300)
        local maxCh  = cfg.MaxCaracteres or (esArea and 2000 or 150)
        LouisHub.Flags[flag] = val

        local fila, lbl = crearCabecera(esArea and (altoA + 36) or 32, cfg.Texto or "Input", esArea and 1 or 0.45, nil, esArea and "manual" or "fijo")
        _Internal.agregarTooltipTexto(fila, cfg.Texto or "Input", cfg.Tooltip, lbl)
        _Internal.registrarBuscable(fila, cfg.Texto or "Input", cfg.VisibleSi)

        local caja = Instance.new("TextBox", fila)
        caja.Size             = esArea and UDim2.new(1, -16, 0, altoA) or UDim2.new(0.5, -8, 0, 24)
        caja.Position         = esArea and UDim2.new(0, 8, 0, 28) or UDim2.new(0.5, 0, 0.5, -12)
        caja.BackgroundColor3 = Theme.Input
        caja.BackgroundTransparency = Theme.InputTrans or 0.25
        caja.Text             = val
        caja.PlaceholderText  = cfg.Placeholder or ""
        caja.TextColor3       = Theme.Highlight
        caja.Font             = Enum.Font.Ubuntu
        caja.TextSize         = 12
        caja.ClearTextOnFocus = false
        caja.BorderSizePixel  = 0
        if esArea then
            caja.MultiLine      = true
            caja.TextWrapped    = true
            caja.TextXAlignment = Enum.TextXAlignment.Left
            caja.TextYAlignment = Enum.TextYAlignment.Top
            local p = Instance.new("UIPadding", caja)
            p.PaddingLeft = UDim.new(0, 6); p.PaddingRight = UDim.new(0, 6)
            p.PaddingTop  = UDim.new(0, 6); p.PaddingBottom = UDim.new(0, 6)
        end
        Utils.Corner(caja, 5)

        caja:GetPropertyChangedSignal("Text"):Connect(function()
            local raw = caja.Text
            if utf8.len(raw) and utf8.len(raw) > maxCh then
                caja.Text = safeSubUTF8(raw, maxCh)
                Utils.FlashFeedback(caja, false, Theme.Input)
            end
        end)

        caja.FocusLost:Connect(function(enter)
            local clean = caja.Text:gsub("^%s+", ""):gsub("%s+$", "")
            local finalVal = clean

            -- V2 Validation Logic Restored
            if cfg.Tipo == "number" then
                local n = tonumber(clean)
                if not n then
                    caja.Text = tostring(val)
                    Utils.FlashFeedback(caja, false, Theme.Input)
                    return
                end
                if cfg.Min and n < cfg.Min then n = cfg.Min end
                if cfg.Max and n > cfg.Max then n = cfg.Max end
                finalVal = n
            elseif cfg.Tipo == "pattern" and cfg.Regex then
                local pat = cfg.Regex:gsub("^%^", ""):gsub("%$$", "")
                local okM, resM = pcall(function() return clean:match("^" .. pat .. "$") end)
                if not okM or not resM then
                    caja.Text = tostring(val)
                    Utils.FlashFeedback(caja, false, Theme.Input)
                    return
                end
            end

            val = finalVal; caja.Text = tostring(finalVal); LouisHub.Flags[flag] = val
            if cfg.Tipo == "number" or cfg.Tipo == "pattern" then
                Utils.FlashFeedback(caja, true, Theme.Input)
            end
            if (enter or esArea) and cfg.Callback then
                executeCallback(cfg.Callback, cfg.Texto, val)
            end
        end)

        local elemObj = {
            Set = function(...)
                local v = normalizeSetArg(...)
                val = v; caja.Text = tostring(v or ""); LouisHub.Flags[flag] = v
                if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, v) end
            end,
            Get = function() return val end,
            __isElement = true, _flag = flag,
        }
        LouisHub.Elementos[flag] = { Set = elemObj.Set, Get = function() return val end }
        return elemObj
    end

    -- 8. RADIO GROUP (WRAPPED GRID FLOW - ANTI SQUISH)
    function Seccion:RadioGroup(cfg)
        cfg = cfg or {}
        local flag = cfg.Flag or cfg.Texto or ("RadioGroup_" .. math.random(1e5, 1e6))
        local opts = cfg.Opciones or {}
        local val  = cfg.Defecto or opts[1]
        LouisHub.Flags[flag] = val

        local fila = Utils.Fila(contenedor, 60, nextOrder(), Theme.Row)
        fila.AutomaticSize = Enum.AutomaticSize.Y
        Utils.Hover(fila, fila)
        _Internal.registrarBuscable(fila, cfg.Texto or "RadioGroup", cfg.VisibleSi)

        local lbl = Utils.Texto({
            Padre = fila, Texto = cfg.Texto or "RadioGroup", Size = UDim2.new(1, -16, 0, 18),
            Posicion = UDim2.new(0, 8, 0, 6), Variante = "Body", Truncar = true,
        })
        _Internal.agregarTooltipTexto(fila, cfg.Texto or "RadioGroup", cfg.Tooltip, lbl)

        local contBtns = Utils.Frame({
            Padre = fila, Size = UDim2.new(1, -16, 0, 0), Posicion = UDim2.new(0, 8, 0, 28),
            Transparencia = 1, Radio = false, Borde = false, Recortar = true,
        })
        contBtns.AutomaticSize = Enum.AutomaticSize.Y
        local lay = Instance.new("UIGridLayout", contBtns)
        lay.CellSize = UDim2.new(0.5, -4, 0, 24)
        lay.CellPadding = UDim2.new(0, 6, 0, 6)
        lay.SortOrder = Enum.SortOrder.LayoutOrder

        local pad = Instance.new("UIPadding", fila)
        pad.PaddingBottom = UDim.new(0, 8)

        local btns = {}
        local function refresh()
            for op, b in pairs(btns) do
                local act = (op == val)
                Utils.Tween(b, { BackgroundColor3 = act and Theme.Accent or Theme.Input }, LouisHub.Motion.Hover)
                local l = b:FindFirstChildOfClass("TextLabel")
                if l then l.TextColor3 = act and Theme.TextPrimary or Theme.TextMuted end
            end
        end

        local function choose(op)
            if op == val then return end
            val = op; LouisHub.Flags[flag] = val; refresh()
            if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, val) end
        end

        for i, op in ipairs(opts) do
            local act = (op == val)
            local b = Utils.BotonBase({
                Padre = contBtns, Size = UDim2.new(1, 0, 1, 0),
                Color = act and Theme.Accent or Theme.Input, Transparencia = 0.25, Radio = 5, Orden = i,
            })
            Utils.Texto({
                Padre = b, Texto = tostring(op), Size = UDim2.new(1, 0, 1, 0), Posicion = UDim2.new(0, 0, 0, 0),
                Alineacion = Enum.TextXAlignment.Center, Variante = "Body", Tamano = 11, Truncar = true,
                Color = act and Theme.TextPrimary or Theme.TextMuted,
            })
            Utils.ClickConfiable(b, function() choose(op) end, b)
            btns[op] = b
        end

        local elemObj = {
            Set = function(...) choose(normalizeSetArg(...)) end,
            Get = function() return val end,
            __isElement = true, _flag = flag,
        }
        LouisHub.Elementos[flag] = { Set = elemObj.Set, Get = function() return val end }
        return elemObj
    end

    -- 9. DROPDOWN (DYNAMIC OPTIONS, DIVIDERS & LOCK RESTORED FROM V2)
    function Seccion:Dropdown(cfg)
        cfg = cfg or {}
        local flag  = cfg.Flag or cfg.Texto or ("Dropdown_" .. math.random(1e5, 1e6))
        local multi = cfg.Multi or false
        local rawEntries = cloneTable(cfg.Opciones or {})

        local opts, meta = {}, {}
        local function parseEntries(list)
            opts, meta = {}, {}
            local seen = {}
            for _, e in ipairs(list or {}) do
                if type(e) == "string" and not seen[e] then
                    seen[e] = true; table.insert(opts, e)
                elseif type(e) == "table" and e.Titulo and not seen[e.Titulo] then
                    seen[e.Titulo] = true; table.insert(opts, e.Titulo)
                    meta[e.Titulo] = e
                end
            end
        end
        parseEntries(rawEntries)

        local sel = {}
        if multi then
            if type(cfg.Defecto) == "table" then
                for k, v in pairs(cfg.Defecto) do
                    if type(k) == "number" and type(v) == "string" then sel[v] = true
                    elseif v == true then sel[k] = true end
                end
            end
        elseif cfg.Defecto then
            sel[cfg.Defecto] = true
        end
        LouisHub.Flags[flag] = multi and cloneTable(sel) or cfg.Defecto

        local ALTO_FILA = 32
        local marco = Utils.Frame({
            Padre = contenedor, Size = UDim2.new(1, 0, 0, ALTO_FILA),
            Color = Theme.Row, Transparencia = Theme.RowTrans or 0.38,
            Orden = nextOrder(), Recortar = true,
        })
        _Internal.registrarBuscable(marco, cfg.Texto or "Dropdown", cfg.VisibleSi)

        local cabecera = Utils.BotonBase({ Padre = marco, Size = UDim2.new(1, 0, 0, ALTO_FILA), Transparencia = 1 })
        Utils.Hover(cabecera, marco)
        local lbl = Utils.Texto({ Padre = marco, Size = UDim2.new(1, -30, 0, ALTO_FILA), Variante = "Body", Truncar = true })

        local arrow = Instance.new("ImageLabel", marco)
        arrow.BackgroundTransparency = 1
        arrow.Image = "rbxassetid://83472139709682"
        arrow.ScaleType = Enum.ScaleType.Fit
        arrow.Size = UDim2.new(0, 10, 0, 10)
        arrow.AnchorPoint = Vector2.new(0.5, 0.5)
        arrow.Position = UDim2.new(1, -14, 0.5, 0)
        LouisHub:Registrar(arrow, "ImageColor3", "TextSecondary")

        local function getDisplay()
            if multi then
                local t = {}
                for _, o in ipairs(opts) do if sel[o] then table.insert(t, o) end end
                return #t > 0 and table.concat(t, ", ") or "None"
            end
            for k, v in pairs(sel) do if v then return k end end
            return "None"
        end
        local function updateLbl() lbl.Text = (cfg.Texto or "Dropdown") .. ": " .. getDisplay() end
        updateLbl()

        local listaOp = Utils.Frame({
            Padre = marco, Size = UDim2.new(1, 0, 0, #opts * 24),
            Posicion = UDim2.new(0, 0, 0, ALTO_FILA), Transparencia = 1, Borde = false,
        })
        local layOp = Instance.new("UIListLayout", listaOp)
        layOp.Padding = UDim.new(0, 2)
        layOp.SortOrder = Enum.SortOrder.LayoutOrder

        local btnsOp = {}
        local alternar

        local function choose(op)
            local itemMeta = meta[op]
            if itemMeta and itemMeta.Locked then return end
            if multi then sel[op] = not sel[op] or nil
            else sel = { [op] = true } end
            LouisHub.Flags[flag] = multi and cloneTable(sel) or op
            for o, b in pairs(btnsOp) do b.BackgroundColor3 = sel[o] and Theme.Accent or Theme.Input end
            updateLbl()
            if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, multi and cloneTable(sel) or op) end
            if not multi and alternar then alternar() end
        end

        local function renderOptions()
            for _, c in ipairs(listaOp:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
            btnsOp = {}
            for i, op in ipairs(opts) do
                local itemMeta = meta[op]
                local isLock = itemMeta and itemMeta.Locked
                local b = Utils.BotonBase({
                    Padre = listaOp, Size = UDim2.new(1, -8, 0, 22), Posicion = UDim2.new(0, 4, 0, 0),
                    Color = sel[op] and Theme.Accent or Theme.Input, Transparencia = isLock and 0.5 or 0.25, Radio = 4, Orden = i,
                })
                local txt = (isLock and "🔒 " or "") .. op .. (itemMeta and itemMeta.Descripcion and (" - " .. itemMeta.Descripcion) or "")
                Utils.Texto({ Padre = b, Texto = txt, Size = UDim2.new(1, -8, 1, 0), Variante = "Body", Tamano = 11 })
                Utils.ClickConfiable(b, function() choose(op) end, b)
                btnsOp[op] = b
            end
            listaOp.Size = UDim2.new(1, 0, 0, #opts * 24 + 4)
        end
        renderOptions()

        alternar = _Internal.hacerExpandible(marco, ALTO_FILA, function()
            return ALTO_FILA + #opts * 24 + 6
        end)
        Utils.ClickConfiable(cabecera, alternar, cabecera)

        local elemObj = {
            Set = function(...)
                local v = normalizeSetArg(...)
                if multi then
                    sel = {}
                    if type(v) == "table" then
                        for k, val in pairs(v) do
                            if type(k) == "number" and type(val) == "string" then sel[val] = true
                            elseif val == true then sel[k] = true end
                        end
                    end
                else
                    sel = { [tostring(v)] = true }
                end
                LouisHub.Flags[flag] = multi and cloneTable(sel) or v
                for o, b in pairs(btnsOp) do b.BackgroundColor3 = sel[o] and Theme.Accent or Theme.Input end
                updateLbl()
                if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, multi and cloneTable(sel) or v) end
            end,
            Get = function() return multi and cloneTable(sel) or getDisplay() end,
            ActualizarOpciones = function(newOpts)
                rawEntries = cloneTable(newOpts or {})
                parseEntries(rawEntries); renderOptions(); updateLbl()
            end,
            AgregarOpcion = function(...)
                local n = normalizeSetArg(...)
                if type(n) == "string" and n ~= "" and not table.find(opts, n) then
                    table.insert(rawEntries, n); parseEntries(rawEntries); renderOptions(); updateLbl()
                    return true
                end
                return false
            end,
            EliminarOpcion = function(...)
                local n = normalizeSetArg(...)
                local idx = table.find(opts, n)
                if idx then
                    table.remove(rawEntries, idx); parseEntries(rawEntries); renderOptions(); updateLbl()
                    return true
                end
                return false
            end,
            LimpiarOpciones = function()
                rawEntries = {}; parseEntries(rawEntries); renderOptions(); updateLbl()
            end,
            __isElement = true, _flag = flag,
        }
        LouisHub.Elementos[flag] = { Set = elemObj.Set, Get = elemObj.Get }
        return elemObj
    end

    -- 10. COLOR PICKER (8 QUICK SWATCHES & HEX BOX RESTORED FROM V2)
    function Seccion:ColorPicker(cfg)
        cfg = cfg or {}
        local flag     = cfg.Flag or cfg.Texto or ("Color_" .. math.random(1e5, 1e6))
        local curColor = cfg.Defecto or Color3.fromRGB(255, 255, 255)
        LouisHub.Flags[flag] = curColor

        local ALTO_FILA = 32
        local marco = Utils.Frame({
            Padre = contenedor, Size = UDim2.new(1, 0, 0, ALTO_FILA),
            Color = Theme.Row, Transparencia = Theme.RowTrans or 0.38,
            Orden = nextOrder(), Recortar = true,
        })
        _Internal.registrarBuscable(marco, cfg.Texto or "Color", cfg.VisibleSi)

        local cabecera = Utils.BotonBase({ Padre = marco, Size = UDim2.new(1, 0, 0, ALTO_FILA), Transparencia = 1 })
        Utils.Hover(cabecera, marco)
        Utils.Texto({ Padre = marco, Texto = cfg.Texto or "Color", Size = UDim2.new(1, -50, 0, ALTO_FILA), Variante = "Body", Truncar = true })

        local swatch = Utils.Frame({
            Padre = marco, Size = UDim2.new(0, 28, 0, 16), Posicion = UDim2.new(1, -36, 0.5, -8),
            Color = curColor, Transparencia = 0, Radio = 4, Borde = true,
        })

        local panel = Utils.Frame({
            Padre = marco, Size = UDim2.new(1, -16, 0, 145), Posicion = UDim2.new(0, 8, 0, ALTO_FILA + 2),
            Transparencia = 1, Borde = false,
        })
        local layP = Instance.new("UIListLayout", panel)
        layP.Padding = UDim.new(0, 4)

        local r, g, b = curColor.R * 255, curColor.G * 255, curColor.B * 255
        local hexBox, fvR, fvG, fvB

        local function toHex(c)
            return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
        end

        local function sync(fire)
            curColor = Color3.fromRGB(math.clamp(math.floor(r + 0.5), 0, 255), math.clamp(math.floor(g + 0.5), 0, 255), math.clamp(math.floor(b + 0.5), 0, 255))
            swatch.BackgroundColor3 = curColor
            if hexBox then hexBox.Text = toHex(curColor) end
            LouisHub.Flags[flag] = curColor
            if fire and cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, curColor) end
        end

        -- V2 Quick Swatches Palette (8 Common Colors)
        local COLORES_COMUNES = {
            Color3.fromRGB(255, 0, 0),     Color3.fromRGB(0, 255, 0),
            Color3.fromRGB(0, 120, 255),   Color3.fromRGB(255, 255, 0),
            Color3.fromRGB(255, 0, 255),   Color3.fromRGB(0, 255, 255),
            Color3.fromRGB(255, 255, 255), Color3.fromRGB(20, 20, 20),
        }
        local filaSwatches = Utils.Frame({ Padre = panel, Size = UDim2.new(1, 0, 0, 20), Orden = 0, Transparencia = 1, Borde = false })
        local laySw = Instance.new("UIListLayout", filaSwatches)
        laySw.FillDirection = Enum.FillDirection.Horizontal
        laySw.Padding = UDim.new(0, 4)

        for i, swCol in ipairs(COLORES_COMUNES) do
            local sw = Utils.BotonBase({ Padre = filaSwatches, Size = UDim2.new(0, 18, 0, 18), Color = swCol, Transparencia = 0, Radio = 4, Orden = i })
            Utils.Stroke(sw, Theme.Border, 1)
            Utils.ClickConfiable(sw, function()
                r, g, b = swCol.R * 255, swCol.G * 255, swCol.B * 255
                fvR(r); fvG(g); fvB(b); sync(true)
            end, sw)
        end

        local function canalRGB(chName, order, getV, setV)
            local rowM = Utils.Frame({ Padre = panel, Size = UDim2.new(1, 0, 0, 20), Orden = order, Transparencia = 1, Borde = false })
            Utils.Texto({ Padre = rowM, Texto = chName, Size = UDim2.new(0, 14, 1, 0), Variante = "Title", Tamano = 10 })
            local _, _, fv = _Internal.crearBarraArrastrable({
                Padre = rowM, Size = UDim2.new(1, -18, 0, 6), Posicion = UDim2.new(0, 18, 0.5, -3),
                Min = 0, Max = 255, Valor = getV(),
                OnCambio = function(v) setV(v); sync(true) end,
            })
            return fv
        end

        fvR = canalRGB("R", 1, function() return r end, function(v) r = v end)
        fvG = canalRGB("G", 2, function() return g end, function(v) g = v end)
        fvB = canalRGB("B", 3, function() return b end, function(v) b = v end)

        -- V2 Hex Box Input
        local rowHex = Utils.Frame({ Padre = panel, Size = UDim2.new(1, 0, 0, 22), Orden = 4, Transparencia = 1, Borde = false })
        Utils.Texto({ Padre = rowHex, Texto = "Hex", Size = UDim2.new(0, 28, 1, 0), Variante = "Title", Tamano = 10 })
        hexBox = Instance.new("TextBox", rowHex)
        hexBox.Size             = UDim2.new(1, -32, 1, 0)
        hexBox.Position         = UDim2.new(0, 32, 0, 0)
        hexBox.BackgroundColor3 = Theme.Input
        hexBox.Font             = Enum.Font.RobotoMono
        hexBox.TextSize         = 11
        hexBox.TextColor3       = Theme.Highlight
        hexBox.PlaceholderText  = "#RRGGBB"
        hexBox.ClearTextOnFocus = false
        hexBox.Text             = toHex(curColor)
        hexBox.BorderSizePixel  = 0
        Utils.Corner(hexBox, 4)

        hexBox.FocusLost:Connect(function()
            local clean = hexBox.Text:gsub("^#", ""):gsub("%s", "")
            if #clean == 3 then clean = clean:sub(1,1):rep(2) .. clean:sub(2,2):rep(2) .. clean:sub(3,3):rep(2) end
            if #clean == 6 and not clean:match("%X") then
                r = tonumber(clean:sub(1, 2), 16)
                g = tonumber(clean:sub(3, 4), 16)
                b = tonumber(clean:sub(5, 6), 16)
                fvR(r); fvG(g); fvB(b); sync(true)
                Utils.FlashFeedback(hexBox, true, Theme.Input)
            else
                hexBox.Text = toHex(curColor)
                Utils.FlashFeedback(hexBox, false, Theme.Input)
            end
        end)

        local alternar = _Internal.hacerExpandible(marco, ALTO_FILA, function() return ALTO_FILA + 150 end)
        Utils.ClickConfiable(cabecera, alternar, cabecera)

        local elemObj = {
            Set = function(...)
                local v = normalizeSetArg(...)
                if typeof(v) ~= "Color3" then return end
                r, g, b = v.R * 255, v.G * 255, v.B * 255
                fvR(r); fvG(g); fvB(b); sync(true)
            end,
            Get = function() return curColor end,
            __isElement = true, _flag = flag,
        }
        LouisHub.Elementos[flag] = { Set = elemObj.Set, Get = elemObj.Get }
        return elemObj
    end

    -- 11. KEYBIND (WITH MOBILE TOUCH-LONGPRESS CYCLE RESTORED FROM V2)
    function Seccion:Keybind(cfg)
        cfg = cfg or {}
        local flag    = cfg.Flag or cfg.Texto or ("Keybind_" .. math.random(1e5, 1e6))
        local conMods = cfg.ConModificadores or false
        local val     = cfg.Defecto or Enum.KeyCode.Unknown
        if conMods and typeof(val) ~= "table" then val = { KeyCode = val, Ctrl = false, Shift = false, Alt = false } end
        LouisHub.Flags[flag] = val

        local entry = { flag = flag, texto = cfg.Texto or "Keybind", GetValor = function() return val end }
        table.insert(_Internal.registeredKeybinds, entry)

        local fila, lbl = crearCabecera(32, cfg.Texto or "Keybind", 1, -75)
        _Internal.agregarTooltipTexto(fila, cfg.Texto or "Keybind", cfg.Tooltip, lbl)
        _Internal.registrarBuscable(fila, cfg.Texto or "Keybind", cfg.VisibleSi)

        local btnTecla = Utils.BotonBase({
            Padre = fila, Size = UDim2.new(0, 68, 0, 20), Posicion = UDim2.new(1, -72, 0.5, -10),
            Color = Theme.Input, Transparencia = 0.25, Radio = 5,
        })
        local k, c, s, a = _Internal.decomposeKey(val)
        local lblTecla = Utils.Texto({
            Padre = btnTecla, Texto = _Internal.formatKeyText(k, c, s, a), Size = UDim2.new(1, 0, 1, 0),
            Posicion = UDim2.new(0, 0, 0, 0), Alineacion = Enum.TextXAlignment.Center,
            Variante = "Code", Tamano = 10, Color = Theme.Highlight,
        })

        local escuchando = false
        local function bindKey()
            if escuchando then return end
            escuchando = true; lblTecla.Text = "..."; btnTecla.BackgroundColor3 = Theme.Accent
            local conn
            conn = UserInputService.InputBegan:Connect(function(input, gpe)
                if gpe then return end
                if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
                    escuchando = false; btnTecla.BackgroundColor3 = Theme.Input
                    conn:Disconnect()
                    local newVal = conMods and {
                        KeyCode = input.KeyCode,
                        Ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl),
                        Shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift),
                        Alt = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt),
                    } or input.KeyCode
                    val = newVal; LouisHub.Flags[flag] = newVal
                    local k2, c2, s2, a2 = _Internal.decomposeKey(val)
                    lblTecla.Text = _Internal.formatKeyText(k2, c2, s2, a2)
                    _Internal.checkKeybindConflict(entry, newVal)
                end
            end)
        end
        Utils.ClickConfiable(btnTecla, bindKey, btnTecla)

        -- V2 Mobile Gesture Support (TouchLongPress Key Switcher)
        local touchKeys = { Enum.KeyCode.E, Enum.KeyCode.F, Enum.KeyCode.Q, Enum.KeyCode.R, Enum.KeyCode.T, Enum.KeyCode.G }
        pcall(function()
            LouisHub:RegistrarConexion(UserInputService.TouchLongPress:Connect(function(positions, state)
                if state ~= Enum.UserInputState.Begin then return end
                local pos = positions[1]
                if not pos then return end
                local ap, as = btnTecla.AbsolutePosition, btnTecla.AbsoluteSize
                if pos.X >= ap.X and pos.X <= ap.X + as.X and pos.Y >= ap.Y and pos.Y <= ap.Y + as.Y then
                    _Internal.setTooltipGestureBlock(true)
                    local curK = _Internal.decomposeKey(val)
                    local idx = table.find(touchKeys, curK) or 0
                    local nextK = touchKeys[(idx % #touchKeys) + 1]
                    val = conMods and { KeyCode = nextK, Ctrl = false, Shift = false, Alt = false } or nextK
                    LouisHub.Flags[flag] = val
                    local k2, c2, s2, a2 = _Internal.decomposeKey(val)
                    lblTecla.Text = _Internal.formatKeyText(k2, c2, s2, a2)
                    LouisHub:Notificar({ Titulo = "⌨️ Key Switched", Texto = nextK.Name, Duracion = 1.5 })
                    task.delay(0.5, function() _Internal.setTooltipGestureBlock(false) end)
                end
            end))
        end)

        LouisHub:RegistrarConexion(UserInputService.InputBegan:Connect(function(input, gpe)
            if gpe or escuchando then return end
            local curK = _Internal.decomposeKey(val)
            if input.KeyCode == curK and curK ~= Enum.KeyCode.Unknown then
                if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, val) end
            end
        end))

        local elemObj = {
            Set = function(...)
                val = normalizeSetArg(...)
                LouisHub.Flags[flag] = val
                local k2, c2, s2, a2 = _Internal.decomposeKey(val)
                lblTecla.Text = _Internal.formatKeyText(k2, c2, s2, a2)
            end,
            Get = function() return val end,
            __isElement = true, _flag = flag,
        }
        LouisHub.Elementos[flag] = { Set = elemObj.Set, Get = elemObj.Get }
        return elemObj
    end

    -- 12. LABEL (WITH SETCOLOR RESTORED FROM V2)
    function Seccion:Label(cfg)
        cfg = cfg or {}
        local flag = cfg.Flag or ("Label_" .. math.random(1e5, 1e6))
        local val  = tostring(cfg.Valor or "")
        _Internal.nonPersistentFlags[flag] = true

        local fila, lbl = crearCabecera(32, cfg.Texto or "Label", 1, -120)
        _Internal.agregarTooltipTexto(fila, cfg.Texto or "Label", cfg.Tooltip, lbl)
        _Internal.registrarBuscable(fila, cfg.Texto or "Label", cfg.VisibleSi)

        local lblVal = Utils.Texto({
            Padre = fila, Texto = val, Size = UDim2.new(0, 115, 1, 0), Posicion = UDim2.new(1, -120, 0, 0),
            Alineacion = Enum.TextXAlignment.Right, Variante = "Body", Tamano = 11, ColorTema = "TextAccent", Truncar = true,
        })

        local function fijar(v)
            val = tostring(v); lblVal.Text = val
        end

        if cfg.Cada and cfg.Actualizar and type(cfg.Actualizar) == "function" then
            local c = tonumber(cfg.Cada) or 1
            _Internal.labelsAutoActualizables[lblVal] = { cada = c, fn = cfg.Actualizar, aplicar = fijar, flag = flag, proxima = os.clock() + c }
        end

        local elemObj = {
            Set = function(...) fijar(normalizeSetArg(...)) end,
            SetColor = function(_, c) lblVal.TextColor3 = c end,
            Get = function() return val end,
            __isElement = true, _flag = flag,
        }
        LouisHub.Elementos[flag] = elemObj
        return elemObj
    end

    -- 13. PARRAFO (IMAGE BANNER, THUMBNAIL & BUTTONS RESTORED FROM V2)
    function Seccion:Parrafo(cfg)
        cfg = cfg or {}
        local marcoP = Utils.Frame({
            Padre = contenedor, Size = UDim2.new(1, 0, 0, 0),
            Color = Theme.Row, Transparencia = Theme.RowTrans or 0.38,
            Orden = nextOrder(), Radio = 8, Recortar = true,
        })
        marcoP.AutomaticSize = Enum.AutomaticSize.Y

        local pad = Instance.new("UIPadding", marcoP)
        pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, cfg.MiniaturaUrl and 68 or 10)
        pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)

        local lay = Instance.new("UIListLayout", marcoP)
        lay.Padding = UDim.new(0, 4)
        lay.SortOrder = Enum.SortOrder.LayoutOrder

        if type(cfg.ImagenUrl) == "string" and cfg.ImagenUrl ~= "" then
            local imgBanner = Instance.new("ImageLabel", marcoP)
            imgBanner.BackgroundColor3 = Theme.Input
            imgBanner.BackgroundTransparency = 0.3
            imgBanner.BorderSizePixel  = 0
            imgBanner.Image            = cfg.ImagenUrl
            imgBanner.ScaleType        = Enum.ScaleType.Crop
            imgBanner.Size             = UDim2.new(1, 0, 0, math.clamp(cfg.ImagenAlto or 90, 40, 200))
            imgBanner.LayoutOrder      = 0
            Utils.Corner(imgBanner, 6)
        end

        if type(cfg.MiniaturaUrl) == "string" and cfg.MiniaturaUrl ~= "" then
            local thumb = Instance.new("ImageLabel", marcoP)
            thumb.BackgroundColor3 = Theme.Input
            thumb.BackgroundTransparency = 0.3
            thumb.BorderSizePixel  = 0
            thumb.Image            = cfg.MiniaturaUrl
            thumb.ScaleType        = Enum.ScaleType.Crop
            thumb.Size             = UDim2.new(0, 48, 0, 48)
            thumb.AnchorPoint      = Vector2.new(1, 0)
            thumb.Position         = UDim2.new(1, -10, 0, 8)
            Utils.Corner(thumb, 6)
        end

        if cfg.Titulo then
            Utils.Texto({
                Padre = marcoP, Texto = cfg.Titulo, Size = UDim2.new(1, 0, 0, 0),
                Variante = "Title", Tamano = 12, Color = Theme.Highlight, Ajustar = true,
            }).AutomaticSize = Enum.AutomaticSize.Y
        end

        local lBody = Utils.Texto({
            Padre = marcoP, Texto = cfg.Contenido or "", Size = UDim2.new(1, 0, 0, 0),
            Variante = "Body", Tamano = 11, Color = Theme.TextPrimary, Ajustar = true,
        })
        lBody.AutomaticSize = Enum.AutomaticSize.Y

        if cfg.Descripcion then
            local bMore = Utils.BotonBase({ Padre = marcoP, Size = UDim2.new(1, 0, 0, 18), Transparencia = 1 })
            local lMore = Utils.Texto({ Padre = bMore, Texto = "+ More info", Size = UDim2.new(1, 0, 1, 0), Variante = "Badge", ColorTema = "AccentLight" })
            local lExtra = Utils.Texto({
                Padre = marcoP, Texto = tostring(cfg.Descripcion), Size = UDim2.new(1, 0, 0, 0),
                Variante = "Body", Tamano = 10, Ajustar = true, ColorTema = "TextMuted",
            })
            lExtra.AutomaticSize = Enum.AutomaticSize.Y
            lExtra.Visible = false
            Utils.ClickConfiable(bMore, function()
                lExtra.Visible = not lExtra.Visible
                lMore.Text = lExtra.Visible and "- Less info" or "+ More info"
            end)
        end

        if type(cfg.Botones) == "table" and #cfg.Botones > 0 then
            local rowB = Utils.Frame({ Padre = marcoP, Size = UDim2.new(1, 0, 0, 26), Transparencia = 1, Borde = false })
            local layB = Instance.new("UIListLayout", rowB)
            layB.FillDirection = Enum.FillDirection.Horizontal
            layB.Padding = UDim.new(0, 6)
            for i, defB in ipairs(cfg.Botones) do
                local bp = Utils.BotonBase({
                    Padre = rowB, Size = UDim2.new(1 / #cfg.Botones, -math.floor(6 * (#cfg.Botones - 1) / #cfg.Botones), 1, 0),
                    Color = defB.Variante == "danger" and Theme.Danger or (defB.Variante == "primary" and Theme.Accent or Theme.Input),
                    Transparencia = 0.25, Radio = 5,
                })
                Utils.Texto({
                    Padre = bp, Texto = tostring(defB.Texto or "OK"), Alineacion = Enum.TextXAlignment.Center,
                    Variante = "Title", Tamano = 11, Color = Color3.fromRGB(255, 255, 255),
                })
                Utils.ClickConfiable(bp, function()
                    if type(defB.Callback) == "function" then executeCallback(defB.Callback, defB.Texto or "Parrafo") end
                end, bp)
            end
        end

        return {
            Set = function(...) lBody.Text = tostring(normalizeSetArg(...)) end,
            Instancia = marcoP, __isElement = true,
        }
    end

    -- 14. PROGRESO (SMOOTH NUMBER TWEENING RESTORED FROM V2)
    function Seccion:Progreso(cfg)
        cfg = cfg or {}
        local flag = cfg.Flag or ("Progreso_" .. math.random(1e5, 1e6))
        local val  = math.clamp(cfg.Defecto or 0, 0, 100)
        _Internal.nonPersistentFlags[flag] = true

        local fila, lbl = crearCabecera(42, cfg.Texto or "Progress", 1, -60, "fijo")
        _Internal.registrarBuscable(fila, cfg.Texto or "Progress", cfg.VisibleSi)

        local lblVal = Utils.Texto({
            Padre = fila, Texto = math.floor(val) .. "%", Size = UDim2.new(0, 50, 0, 18),
            Posicion = UDim2.new(1, -55, 0, 4), Alineacion = Enum.TextXAlignment.Right,
            Variante = "Code", Tamano = 10, Color = Theme.Highlight,
        })

        local fondo = Utils.Frame({
            Padre = fila, Size = UDim2.new(1, -16, 0, 6), Posicion = UDim2.new(0, 8, 0, 28),
            Color = Theme.Input, Transparencia = 0.2, Radio = 3, Borde = false,
        })
        local relleno = Utils.Frame({
            Padre = fondo, Size = UDim2.new(val / 100, 0, 1, 0),
            Color = Theme.Accent, Transparencia = 0, Radio = 3, Borde = false,
        })
        Utils.GradienteAcento(relleno)

        local lastNum = val
        local function fijar(v)
            if type(v) ~= "number" then return end
            val = math.clamp(v, 0, 100)
            Utils.Tween(relleno, {Size = UDim2.new(val / 100, 0, 1, 0)}, LouisHub.Motion.Expand)
            local from = lastNum; lastNum = val
            Utils.TweenNumero(from, val, LouisHub.Motion.PageSlide, function(n)
                if lblVal and lblVal.Parent then lblVal.Text = math.floor(n + 0.5) .. "%" end
            end, LouisHub.Motion.EaseSmooth)
        end

        local elemObj = { Set = function(...) fijar(normalizeSetArg(...)) end, Get = function() return val end, __isElement = true }
        LouisHub.Elementos[flag] = elemObj
        return elemObj
    end

    -- 15. DIVIDER
    function Seccion:Divider(cfg)
        cfg = cfg or {}
        local fila = Utils.Frame({
            Padre = contenedor, Size = UDim2.new(1, 0, 0, cfg.Texto and 26 or 12),
            Transparencia = 1, Orden = nextOrder(), Radio = false, Borde = false,
        })
        if cfg.Texto then
            Utils.Texto({
                Padre = fila, Texto = tostring(cfg.Texto), Size = UDim2.new(1, 0, 0, 16),
                Variante = "Badge", ColorTema = "TextMuted",
            })
        end
        local line = Utils.Frame({
            Padre = fila, Size = UDim2.new(1, 0, 0, 1), Posicion = UDim2.new(0, 0, 1, -2),
            Color = Theme.Border, Transparencia = 0.4, Radio = false, Borde = false,
        })
        return { Instancia = fila, __isElement = true }
    end

    -- 16. IMAGEN (ASPECT RATIO RESTORED FROM V2)
    function Seccion:Imagen(cfg)
        cfg = cfg or {}
        local aspectVal
        if type(cfg.Aspecto) == "string" then
            local w, h = cfg.Aspecto:match("^(%d+):(%d+)$")
            if w and h and tonumber(h) > 0 then aspectVal = tonumber(w) / tonumber(h) end
        elseif type(cfg.Aspecto) == "number" and cfg.Aspecto > 0 then
            aspectVal = cfg.Aspecto
        end

        local alto = math.clamp(cfg.Alto or 110, 40, 300)
        local fila = Utils.Frame({
            Padre = contenedor, Size = UDim2.new(1, 0, 0, aspectVal and 0 or alto),
            Transparencia = 1, Orden = nextOrder(), Radio = false, Borde = false,
        })
        if aspectVal then
            local ac = Instance.new("UIAspectRatioConstraint", fila)
            ac.AspectRatio = aspectVal
        end

        local img = Instance.new("ImageLabel", fila)
        img.BackgroundColor3 = Theme.Input
        img.BackgroundTransparency = 0.3
        img.BorderSizePixel  = 0
        img.Image            = cfg.Url or ""
        img.ScaleType        = aspectVal and Enum.ScaleType.Crop or (cfg.Escala == "Crop" and Enum.ScaleType.Crop or Enum.ScaleType.Fit)
        img.Size             = UDim2.new(1, 0, 1, 0)
        Utils.Corner(img, 8)
        return {
            Set = function(...) img.Image = tostring(normalizeSetArg(...) or "") end,
            Instancia = img, __isElement = true,
        }
    end

    -- 17. GRUPO
    function Seccion:Grupo(cfg)
        cfg = cfg or {}
        local filaG = Utils.Frame({
            Padre = contenedor, Size = UDim2.new(1, 0, 0, cfg.Alto or 30),
            Transparencia = 1, Orden = nextOrder(), Radio = false, Borde = false,
        })
        local lay = Instance.new("UIListLayout", filaG)
        lay.FillDirection = Enum.FillDirection.Horizontal
        lay.Padding = UDim.new(0, 6)
        lay.SortOrder = Enum.SortOrder.LayoutOrder

        local btns = {}
        local function recalc()
            for _, b in ipairs(btns) do
                b.Size = UDim2.new(1 / #btns, -math.floor(6 * (#btns - 1) / #btns), 1, 0)
            end
        end

        local grp = { Instancia = filaG, __isElement = true }
        function grp:Boton(cfgB)
            local b = Seccion:Boton(cfgB)
            local f = b.Instancia or b.Fila or b
            f.Parent = filaG
            table.insert(btns, f)
            recalc()
            return b
        end
        return grp
    end

    -- 18. TAG INPUT (FIXED BACKSPACE DELETION & CHIPS)
    function Seccion:TagInput(cfg)
        cfg = cfg or {}
        local flag = cfg.Flag or cfg.Texto or ("TagInput_" .. math.random(1e5, 1e6))
        local tags = cloneTable(cfg.Defecto or {})
        LouisHub.Flags[flag] = tags

        local fila = Utils.Fila(contenedor, 68, nextOrder(), Theme.Row)
        fila.AutomaticSize = Enum.AutomaticSize.Y
        Utils.Hover(fila, fila)
        _Internal.registrarBuscable(fila, cfg.Texto or "TagInput", cfg.VisibleSi)

        local lbl = Utils.Texto({
            Padre = fila, Texto = cfg.Texto or "TagInput", Size = UDim2.new(1, -16, 0, 18),
            Posicion = UDim2.new(0, 8, 0, 6), Variante = "Body", Truncar = true,
        })
        _Internal.agregarTooltipTexto(fila, cfg.Texto or "TagInput", cfg.Tooltip, lbl)

        local contChips = Utils.Frame({
            Padre = fila, Size = UDim2.new(1, -16, 0, 0), Posicion = UDim2.new(0, 8, 0, 26),
            Transparencia = 1, Radio = false, Borde = false,
        })
        contChips.AutomaticSize = Enum.AutomaticSize.Y
        local layChips = Instance.new("UIListLayout", contChips)
        layChips.FillDirection = Enum.FillDirection.Horizontal
        layChips.Wraps = true
        layChips.Padding = UDim.new(0, 4)

        local caja = Instance.new("TextBox", fila)
        caja.Size = UDim2.new(1, -16, 0, 24)
        caja.Position = UDim2.new(0, 8, 0, 32)
        caja.BackgroundColor3 = Theme.Input
        caja.BackgroundTransparency = Theme.InputTrans or 0.25
        caja.PlaceholderText = cfg.Placeholder or "Type & hit Enter..."
        caja.Text = ""
        caja.TextColor3 = Theme.Highlight
        caja.Font = Enum.Font.Ubuntu
        caja.TextSize = 11
        caja.BorderSizePixel = 0
        caja.ClearTextOnFocus = false
        Utils.Corner(caja, 5)

        local renderChips
        local function addTag(t)
            local clean = t:gsub("^%s+", ""):gsub("%s+$", "")
            if clean ~= "" and not table.find(tags, clean) then
                table.insert(tags, clean); return true
            end
            return false
        end

        local function commit()
            if addTag(caja.Text) then
                caja.Text = ""; LouisHub.Flags[flag] = cloneTable(tags); renderChips()
                if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, cloneTable(tags)) end
            end
        end
        caja.FocusLost:Connect(commit)

        -- Direct TextBox InputBegan catches backspace without GPE blocking!
        caja.InputBegan:Connect(function(inp)
            if inp.KeyCode == Enum.KeyCode.Backspace and caja.Text == "" and #tags > 0 then
                table.remove(tags)
                LouisHub.Flags[flag] = cloneTable(tags); renderChips()
                if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, cloneTable(tags)) end
            end
        end)

        renderChips = function()
            for _, c in ipairs(contChips:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
            for i, t in ipairs(tags) do
                local tw = _Internal.anchoTexto(t, 11, Enum.Font.FredokaOne)
                local ch = Utils.Frame({
                    Padre = contChips, Size = UDim2.new(0, tw + 28, 0, 20),
                    Color = Theme.Accent, Transparencia = 0.2, Radio = 10, Borde = false,
                })
                Utils.Texto({
                    Padre = ch, Texto = t, Size = UDim2.new(0, tw + 2, 1, 0), Posicion = UDim2.new(0, 8, 0, 0),
                    Variante = "Title", Tamano = 10, Color = Theme.TextPrimary,
                })
                local bx = Instance.new("TextButton", ch)
                bx.BackgroundTransparency = 1; bx.Text = "×"; bx.TextColor3 = Theme.TextPrimary
                bx.Font = Enum.Font.FredokaOne; bx.TextSize = 13
                bx.Size = UDim2.new(0, 16, 1, 0); bx.Position = UDim2.new(1, -18, 0, 0)
                bx.MouseButton1Click:Connect(function()
                    table.remove(tags, i)
                    LouisHub.Flags[flag] = cloneTable(tags); renderChips()
                    if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, cloneTable(tags)) end
                end)
            end
            task.defer(function()
                local hC = (#tags > 0) and math.ceil(layChips.AbsoluteContentSize.Y) or 0
                caja.Position = UDim2.new(0, 8, 0, 28 + hC + (hC > 0 and 6 or 2))
                fila.Size = UDim2.new(1, 0, 0, 28 + hC + 34)
            end)
        end
        renderChips()

        local elemObj = {
            Set = function(...)
                tags = cloneTable(normalizeSetArg(...) or {})
                LouisHub.Flags[flag] = tags; renderChips()
            end,
            Get = function() return cloneTable(tags) end,
            __isElement = true, _flag = flag,
        }
        LouisHub.Elementos[flag] = elemObj
        return elemObj
    end

    -- Dynamic Toggle Helpers for External Components (V2)
    function Seccion:HUDToggle(hudInst, cfgToggle)
        cfgToggle = cfgToggle or {}
        cfgToggle.Texto = cfgToggle.Texto or "Display HUD"
        cfgToggle.Defecto = hudInst.Frame.Visible
        cfgToggle.Callback = function(v) hudInst:SetVisible(v) end
        return Seccion:Toggle(cfgToggle)
    end

    function Seccion:BotonFlotanteToggle(btnInst, cfgToggle)
        cfgToggle = cfgToggle or {}
        cfgToggle.Texto = cfgToggle.Texto or "Display Action Button"
        cfgToggle.Defecto = btnInst.Frame.Visible
        cfgToggle.Callback = function(v) btnInst:SetVisible(v) end
        return Seccion:Toggle(cfgToggle)
    end

    -- Wrap Lockable Controls
    for _, name in ipairs({ "Boton", "Toggle", "Casilla", "Slider", "RangeSlider", "NumberStepper", "Input", "RadioGroup", "Dropdown", "ColorPicker", "Keybind", "TagInput" }) do
        Utils.EnvolverControlBloqueable(Seccion, contenedor, name)
    end

    -- Declarative Schema Builder
    function Seccion:Construir(lista)
        local res = {}
        if type(lista) ~= "table" then return res end
        local dispatch = {
            Boton = Seccion.Boton, Toggle = Seccion.Toggle, Casilla = Seccion.Casilla,
            Slider = Seccion.Slider, RangeSlider = Seccion.RangeSlider, NumberStepper = Seccion.NumberStepper,
            Input = Seccion.Input, RadioGroup = Seccion.RadioGroup, Dropdown = Seccion.Dropdown,
            ColorPicker = Seccion.ColorPicker, Keybind = Seccion.Keybind, Label = Seccion.Label,
            Parrafo = Seccion.Parrafo, Progreso = Seccion.Progreso, Divider = Seccion.Divider,
            Imagen = Seccion.Imagen, Grupo = Seccion.Grupo, TagInput = Seccion.TagInput,
        }
        for i, def in ipairs(lista) do
            if type(def) == "table" then
                local fn = dispatch[def.Control or def.Tipo]
                if fn then
                    local cDef = cloneTable(def)
                    cDef.Control = nil; cDef.Tipo = nil
                    local el = fn(Seccion, cDef)
                    res[i] = el
                    if def.Flag then res[def.Flag] = el end
                end
            end
        end
        return res
    end
end

-- Process any pending sections created in Part 4 before Part 5 was loaded
if type(_Internal.pendingSections) == "table" then
    for _, p in ipairs(_Internal.pendingSections) do
        _Internal.vincularMetodosControles(p.Seccion, p.Contenedor)
    end
    _Internal.pendingSections = {}
end

-- ===================================================================
--  LOUIS HUB UI LIBRARY (V3.0 NEXT-GEN COMPLETE ENGINE)
--  Brand: Louis Hub
--  Priority: Zero-Leaks > Backward Compatibility > Glassmorphism > Performance
--  [PART 6 OF 6] - Complete SaveManager, System Suite Tab & Final Export
-- ===================================================================

local _Internal        = LouisHub._Internal
local Theme            = LouisHub.Theme
local Utils            = LouisHub.Utils
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TextService      = game:GetService("TextService")
local HttpService      = game:GetService("HttpService")

local cloneTable       = _Internal.cloneTable
local executeCallback  = _Internal.executeCallback
local fsAvailable      = _Internal.fsAvailable

-- ===================================================================
--  1. COMPLETE & FIXED SAVE & CONFIG MANAGER (V2 FULL RESTORE)
-- ===================================================================
LouisHub.SaveManager = {
    Carpeta   = "LouisHub/Config",
    CarpetaUI = "LouisHub/Config/_ui",
}
local SM = LouisHub.SaveManager

function SM:Configurar(folder)
    self.Carpeta = folder or self.Carpeta
end

local function asegurarCarpeta()
    if not (fsAvailable() and type(isfolder) == "function" and type(makefolder) == "function") then return end
    local cur = ""
    for part in SM.Carpeta:gmatch("[^/]+") do
        cur = (cur == "") and part or (cur .. "/" .. part)
        if not isfolder(cur) then pcall(makefolder, cur) end
    end
end

local function asegurarCarpetaUI()
    if not (fsAvailable() and type(isfolder) == "function" and type(makefolder) == "function") then return end
    local cur = ""
    for part in SM.CarpetaUI:gmatch("[^/]+") do
        cur = (cur == "") and part or (cur .. "/" .. part)
        if not isfolder(cur) then pcall(makefolder, cur) end
    end
end

local function nombrePerfilValido(name)
    if type(name) ~= "string" then return false end
    local clean = name:match("^%s*(.-)%s*$")
    if clean == "" or #clean > 60 or clean:find('[/\\:*?"<>|%c]') then return false end
    return true, clean
end

function SM:GuardarSilencioso(name)
    name = name or "default"
    if not LouisHub.Capacidades.Archivos then return false end
    asegurarCarpeta()
    local ok, err = pcall(function()
        local data = _Internal.packFlags(_Internal.realFlags)
        writefile(SM.Carpeta .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    end)
    if not ok then LouisHub:_RegistrarError("SaveManager:GuardarSilencioso", err) end
    return ok
end

function SM:Guardar(name)
    name = name or "default"
    if not fsAvailable() then
        LouisHub:Notificar({ Titulo = "SaveManager", Texto = "Filesystem not supported.", Duracion = 4 })
        return false
    end
    local ok = SM:GuardarSilencioso(name)
    if ok then
        LouisHub:Notificar({ Titulo = "Config Saved", Texto = name .. ".json", Tipo = "Success", Duracion = 3 })
    else
        LouisHub:Notificar({ Titulo = "❌ Save Failed", Texto = "Error writing file.", Tipo = "Error", Duracion = 4 })
    end
    return ok
end

function SM:CargarSilencioso(name)
    name = name or "default"
    local path = SM.Carpeta .. "/" .. name .. ".json"
    if not (fsAvailable() and type(isfile) == "function" and isfile(path)) then return false end

    local okRead, content = pcall(readfile, path)
    if not okRead then return false end
    local okDecode, data = pcall(function() return HttpService:JSONDecode(content) end)
    if not okDecode or type(data) ~= "table" then return false end
    data = _Internal.prepareLoadedData(data)

    for flag, rawVal in pairs(data) do
        if flag ~= "__version" then
            local val = _Internal.unpackFlagValue(rawVal)
            LouisHub.Flags[flag] = val
            if LouisHub.Elementos[flag] and type(LouisHub.Elementos[flag].Set) == "function" then
                pcall(LouisHub.Elementos[flag].Set, val, true)
            end
        end
    end
    _Internal.checkKeybindConflictsOnLoad()
    LouisHub:LimpiarHistorial()
    return true
end

function SM:Cargar(name)
    local ok = self:CargarSilencioso(name)
    if ok then
        LouisHub:Notificar({ Titulo = "Config Loaded", Texto = name .. ".json", Tipo = "Success", Duracion = 3 })
    end
    return ok
end

function SM:CambiarPerfil(ventana, name)
    if type(name) ~= "string" or name == "" then return false end
    if ventana and ventana.NombreConfig then
        SM:GuardarSilencioso(ventana.NombreConfig)
    end
    if ventana then ventana.NombreConfig = name end
    if _Internal.activeSaveWindow then _Internal.activeSaveWindow.NombreConfig = name end
    local exists = SM:Cargar(name)
    if not exists then
        LouisHub:Notificar({ Titulo = "New Profile", Texto = "'" .. name .. "' created (active)", Duracion = 3 })
    end
    return true
end

function SM:Listar()
    if not (fsAvailable() and type(listfiles) == "function") then return {} end
    asegurarCarpeta()
    local res = {}
    local ok, files = pcall(listfiles, SM.Carpeta)
    if ok then
        for _, path in ipairs(files) do
            local name = path:match("([^/\\]+)%.json$")
            if name then table.insert(res, name) end
        end
    end
    return res
end

function SM:Eliminar(name)
    if not (fsAvailable() and type(isfile) == "function" and type(delfile) == "function") then return false end
    local path = SM.Carpeta .. "/" .. name .. ".json"
    if not isfile(path) then return false end
    local ok = pcall(delfile, path)
    if ok and _Internal.activeSaveWindow and _Internal.activeSaveWindow.NombreConfig == name then
        _Internal.activeSaveWindow.NombreConfig = "default"
    end
    return ok
end

function SM:Renombrar(orig, dest)
    local okO, nameO = nombrePerfilValido(orig)
    local okD, nameD = nombrePerfilValido(dest)
    if not (okO and okD) then return false, "Invalid profile name" end
    if not (fsAvailable() and type(isfile) == "function") then return false end

    local pO = SM.Carpeta .. "/" .. nameO .. ".json"
    local pD = SM.Carpeta .. "/" .. nameD .. ".json"
    if not isfile(pO) then return false, "Source profile not found" end
    if isfile(pD) then return false, "Target profile already exists" end

    local ok, content = pcall(readfile, pO)
    if not ok then return false end
    pcall(writefile, pD, content)
    pcall(delfile, pO)

    if _Internal.activeSaveWindow and _Internal.activeSaveWindow.NombreConfig == nameO then
        _Internal.activeSaveWindow.NombreConfig = nameD
    end
    return true
end

function SM:Duplicar(orig, dest)
    local okO, nameO = nombrePerfilValido(orig)
    local okD, nameD = nombrePerfilValido(dest)
    if not (okO and okD) then return false, "Invalid profile name" end
    if not (fsAvailable() and type(isfile) == "function") then return false end

    local pO = SM.Carpeta .. "/" .. nameO .. ".json"
    local pD = SM.Carpeta .. "/" .. nameD .. ".json"
    if not isfile(pO) then return false, "Source profile not found" end
    if isfile(pD) then return false, "Target profile already exists" end

    local ok, content = pcall(readfile, pO)
    if not ok then return false end
    return pcall(writefile, pD, content)
end

function SM:Exportar(name)
    local okN, cleanName = nombrePerfilValido(name)
    if not okN or not fsAvailable() then return nil, "Invalid profile name" end
    local p = SM.Carpeta .. "/" .. cleanName .. ".json"
    if not isfile(p) then return nil, "Profile not found" end
    local ok, txt = pcall(readfile, p)
    if not ok then return nil, "Read failure" end
    local copied = false
    if type(setclipboard) == "function" then copied = pcall(setclipboard, txt) end
    return txt, copied
end

function SM:Importar(name, text, overwrite)
    local okN, cleanName = nombrePerfilValido(name)
    if not okN or not fsAvailable() or type(text) ~= "string" or text == "" then return false, "Invalid input" end
    local okJ, _ = pcall(function() return HttpService:JSONDecode(text) end)
    if not okJ then return false, "Invalid JSON data" end

    asegurarCarpeta()
    local p = SM.Carpeta .. "/" .. cleanName .. ".json"
    if isfile(p) and not overwrite then return false, "Profile already exists" end
    local ok = pcall(writefile, p, text)
    return ok
end

-- UI Settings Persistence (V2 Restored)
function SM:GuardarUI(name)
    name = name or "default"
    if not fsAvailable() then return false end
    asegurarCarpetaUI()
    local path = SM.CarpetaUI .. "/" .. name .. ".json"
    local ok = pcall(function()
        local data = _Internal.packFlags(_Internal.realFlags, true)
        writefile(path, HttpService:JSONEncode(data))
    end)
    if ok then
        LouisHub:Notificar({ Titulo = "UI Settings Saved", Texto = name .. ".json", Tipo = "Success", Duracion = 3 })
    end
    return ok
end

function SM:CargarUI(name)
    name = name or "default"
    local path = SM.CarpetaUI .. "/" .. name .. ".json"
    if not (fsAvailable() and type(isfile) == "function" and isfile(path)) then return false end

    local okR, content = pcall(readfile, path)
    if not okR then return false end
    local okJ, data = pcall(function() return HttpService:JSONDecode(content) end)
    if not okJ or type(data) ~= "table" then return false end
    data = _Internal.prepareLoadedData(data)

    pcall(function()
        for flag, rawVal in pairs(data) do
            if _Internal.uiFlags[flag] then
                local val = _Internal.unpackFlagValue(rawVal)
                LouisHub.Flags[flag] = val
                if LouisHub.Elementos[flag] and type(LouisHub.Elementos[flag].Set) == "function" then
                    pcall(LouisHub.Elementos[flag].Set, val, true)
                end
            end
        end
    end)
    _Internal.checkKeybindConflictsOnLoad()
    LouisHub:LimpiarHistorial()
    LouisHub:Notificar({ Titulo = "UI Settings Loaded", Texto = name .. ".json", Tipo = "Success", Duracion = 3 })
    return true
end

function SM:ListarUI()
    if not (fsAvailable() and type(listfiles) == "function") then return {} end
    asegurarCarpetaUI()
    local res = {}
    local ok, files = pcall(listfiles, SM.CarpetaUI)
    if ok then
        for _, path in ipairs(files) do
            local name = path:match("([^/\\]+)%.json$")
            if name then table.insert(res, name) end
        end
    end
    return res
end

function SM:EliminarUI(name)
    if not (fsAvailable() and type(isfile) == "function" and type(delfile) == "function") then return false end
    local path = SM.CarpetaUI .. "/" .. name .. ".json"
    if not isfile(path) then return false end
    return pcall(delfile, path)
end

-- ===================================================================
--  2. PREINSTALLED SYSTEM SUITE TAB (V2 COMPLETE MONITORING & SUITE)
-- ===================================================================
local function agregarPestanaPreinstaladaA(self, cfg)
    cfg = cfg or {}
    local sysTab = self:CrearTab(cfg.Nombre or "🔧 Suite", "🛠️")

    -- SECTION: REALTIME PERFORMANCE METRICS (FPS, FRAMETIME, HEALTH, MEMORY)
    local secInfo = sysTab:CrearSeccion("System Metrics", { Columna = 1 })
    secInfo:Label({
        Texto = "Executor", Flag = "sys_exec",
        Valor = (_Internal.detectExecutor and _Internal.detectExecutor() or "Standard Engine")
    })
    secInfo:Label({ Texto = "Engine Version", Flag = "sys_version", Valor = LouisHub.Version })
    local lblFps = secInfo:Label({ Texto = "FPS", Flag = "sys_fps", Valor = "–" })
    local lblFt  = secInfo:Label({ Texto = "Frame Time", Flag = "sys_frametime", Valor = "–" })
    local lblEst = secInfo:Label({ Texto = "Performance", Flag = "sys_estado", Valor = "–" })
    local lblSal = secInfo:Label({
        Texto = "💚 Health Score", Flag = "sys_health", Valor = "🟢 Calculating...",
        Tooltip = "Evaluates UI node count, registered connections and FPS growth.",
    })

    local statsOk, statsService = pcall(function() return game:GetService("Stats") end)
    local lblMemoria
    if statsOk and statsService then
        local okM, mInit = pcall(function() return statsService:GetTotalMemoryUsageMb() end)
        if okM and type(mInit) == "number" and mInit > 0 then
            lblMemoria = secInfo:Label({
                Texto = "Memory (approx.)", Flag = "sys_memoria", Valor = "–",
                Tooltip = "Total Roblox client memory usage estimate.",
            })
        end
    end

    local frames, lastTime = 0, os.clock()
    local initHealth = os.clock()
    local baseline = nil

    LouisHub:RegistrarConexion(RunService.Heartbeat:Connect(function()
        frames = frames + 1
        local now = os.clock()
        if now - lastTime >= 1 then
            local dt = now - lastTime
            local fps = math.round(frames / dt)
            local ft = math.round((dt / frames) * 1000 * 10) / 10
            frames, lastTime = 0, now

            local eFps = LouisHub.Elementos["sys_fps"]
            if eFps then eFps.Set(fps .. " FPS") end
            local eFt = LouisHub.Elementos["sys_frametime"]
            if eFt then eFt.Set(ft .. " ms") end
            local eEst = LouisHub.Elementos["sys_estado"]
            if eEst then eEst.Set(fps >= 50 and "🟢 Optimal" or (fps >= 30 and "🟡 Normal" or "🔴 Degraded")) end

            if lblMemoria then
                local okM, mMb = pcall(function() return statsService:GetTotalMemoryUsageMb() end)
                local eMem = LouisHub.Elementos["sys_memoria"]
                if okM and eMem then eMem.Set("~" .. math.round(mMb) .. " MB") end
            end

            local eSal = LouisHub.Elementos["sys_health"]
            if eSal then
                local objCount = _Internal.getUIInstanceCount()
                local conns = (_G.LouisHub_InstanciaActiva and _G.LouisHub_InstanciaActiva.Conexiones and #_G.LouisHub_InstanciaActiva.Conexiones) or 0
                if not baseline and (now - initHealth) >= 5 then
                    baseline = { objetos = objCount, conexiones = conns }
                end
                if not baseline then
                    eSal.Set("⚪ Calculating...")
                else
                    local dObj = objCount - baseline.objetos
                    local dCon = conns - baseline.conexiones
                    local status = "🟢 Healthy"
                    if dObj > 1200 or dCon > 80 or fps < 20 then status = "🔴 Critical"
                    elseif dObj > 500 or dCon > 40 or fps < 30 then status = "🟡 Attention" end
                    eSal.Set(status)
                end
            end
        end
    end))

    -- SECTION: ENVIRONMENT DIAGNOSTICS & FEATURE AUDIT
    local secDiag = sysTab:CrearSeccion("🖥️ Environment Diagnostics", { Columna = 2 })
    local C = LouisHub.Capacidades

    local function descEnv()
        local parts = { C.Tipo }
        if C.Plataforma then table.insert(parts, C:NombrePlataforma()) end
        local inp = C.EsTouchOnly and "Touch Only" or (C.TieneMouse and C.Teclado and "Mouse + Keyboard" or (C.TieneTouch and "Touch + Hybrid" or "Gamepad"))
        table.insert(parts, inp)
        return table.concat(parts, " · ")
    end

    secDiag:Label({ Texto = "Environment", Flag = "diag_entorno", Valor = descEnv() })
    secDiag:Label({ Texto = "Viewport", Flag = "diag_viewport", Valor = math.floor(C.ViewportSize.X) .. " x " .. math.floor(C.ViewportSize.Y) })

    local totalF, okF, warnsF = 0, 0, {}
    for _, f in ipairs(LouisHub.Features) do
        totalF = totalF + 1
        local r = LouisHub:VerificarSoporte(f.nombre)
        if r.ok then okF = okF + 1
        elseif f.nivel ~= "requerido" then table.insert(warnsF, { nombre = f.nombre, nivel = f.nivel, msg = r.mensaje }) end
    end
    secDiag:Label({ Texto = "Features Supported", Flag = "diag_features", Valor = okF .. "/" .. totalF .. " " .. (okF == totalF and "🟢" or "🟡") })

    secDiag:Boton({
        Texto = "🩺 Dump Full Diagnostics to Console (F9)",
        Callback = function()
            LouisHub:Profiler()
            local d = LouisHub:DiagnosticoCompleto()
            print(("[LouisHub] Diagnostics: %s · %s | %dx%d | %s | %d/%d Features"):format(d.Tipo, d.Plataforma, d.Viewport.X, d.Viewport.Y, d.Ejecutor, d.FeaturesOk, d.FeaturesTotal))
        end,
    })

    local forzables = { "Auto", "PC", "Movil", "Tablet", "Consola" }
    secDiag:Dropdown({
        Texto = "🖥️ Force Device Classification", Flag = "diag_forzar_tipo", Opciones = forzables,
        Defecto = _G.LouisHub_TipoForzado or "Auto",
        Callback = function(v) if v == "Auto" then LouisHub:LiberarForzado() else LouisHub:ForzarTipo(v) end end,
    })
    LouisHub:MarcarComoUI("diag_forzar_tipo")

    -- SECTION: APPEARANCE SETTINGS (PRE-PATCHED CAMERA SCALE SYNC)
    local secAp = sysTab:CrearSeccion("Interface Appearance", { Columna = 1 })
    local tNombres = {}
    for n in pairs(LouisHub.ThemeManager.Temas) do table.insert(tNombres, n) end
    table.sort(tNombres)

    secAp:Dropdown({
        Texto = "🎨 Theme Style", Flag = "sys_tema", Opciones = tNombres,
        Defecto = (_Internal.Themes and _Internal.Themes.Predeterminado or "NeonGlass"),
        Callback = function(v) LouisHub.ThemeManager:AplicarTema(v) end,
    })
    secAp:Slider({
        Texto = "📏 Interface Scale", Flag = "sys_escala", Min = 70, Max = 130, Incremento = 5, Sufijo = "%", Defecto = 100,
        Callback = function(v)
            if self._setEscalaManual then self._setEscalaManual(v / 100) end
        end,
    })
    secAp:Slider({
        Texto = "↔️ Window Width Ratio", Flag = "sys_ancho", Min = 70, Max = 130, Incremento = 5, Sufijo = "%", Defecto = 100,
        Callback = function(v)
            if self._setFactorAncho then self._setFactorAncho(v / 100) end
        end,
    })
    secAp:Slider({
        Texto = "↕️ Window Height Ratio", Flag = "sys_alto", Min = 70, Max = 130, Incremento = 5, Sufijo = "%", Defecto = 100,
        Callback = function(v)
            if self._setFactorAlto then self._setFactorAlto(v / 100) end
        end,
    })
    secAp:Slider({
        Texto = "🔡 Global Text Scale", Flag = "sys_escala_texto", Min = 80, Max = 150, Incremento = 5, Sufijo = "%", Defecto = 100,
        Callback = function(v) _Internal.applyTextScale("tabs", v / 100); _Internal.applyTextScale("general", v / 100) end,
    })
    LouisHub:MarcarComoUI({ "sys_tema", "sys_escala", "sys_ancho", "sys_alto", "sys_escala_texto" })

    -- SECTION: UI PERSISTENCE SETTINGS
    local secCfg = sysTab:CrearSeccion("UI Settings Persistence", { Columna = 2 })
    secCfg:Boton({
        Texto = "💾 Save UI Settings", Async = true,
        Callback = function() LouisHub.SaveManager:GuardarUI("preinstalada") end,
    })
    secCfg:Boton({
        Texto = "📂 Load UI Settings", Async = true,
        Callback = function() LouisHub.SaveManager:CargarUI("preinstalada") end,
    })
    secCfg:Boton({
        Texto = "🗑️ Delete UI Settings", Async = true,
        Callback = function()
            local okD = LouisHub.SaveManager:EliminarUI("preinstalada")
            LouisHub:Notificar({ Titulo = "UI Settings", Texto = okD and "Saved settings removed" or "No file found", Duracion = 3 })
        end,
    })

    -- SECTION: SCRIPT PROFILE MANAGER GUI (PRE-PATCHED FULL-WIDTH SAFE STACKING)
    local secPerfiles = sysTab:CrearSeccion("Script Profile Manager", { Columna = "Full" })
    local selProfile = nil

    local dropProf = secPerfiles:Dropdown({
        Texto = "Active Profile", Flag = "sys_perfil_elegido", Opciones = LouisHub.SaveManager:Listar(),
        Callback = function(v) selProfile = v end,
    })
    LouisHub:MarcarComoUI("sys_perfil_elegido")

    local function refreshProfiles() dropProf.ActualizarOpciones(LouisHub.SaveManager:Listar()) end

    local grpProfA = secPerfiles:Grupo()
    grpProfA:Boton({
        Texto = "🔄 Refresh List",
        Callback = function() refreshProfiles() end,
    })
    grpProfA:Boton({
        Texto = "📂 Load Selected Profile", Async = true,
        Callback = function()
            if not selProfile then LouisHub:Notificar({ Titulo = "Profiles", Texto = "Select a profile first", Duracion = 3 }); return end
            LouisHub.SaveManager:CambiarPerfil(self, selProfile)
        end,
    })

    secPerfiles:Input({
        Texto = "New Profile Name", Flag = "sys_nombre_nuevo_perfil", Placeholder = "e.g. Farm, PvP, Raid...",
    })
    LouisHub:MarcarComoUI("sys_nombre_nuevo_perfil")

    local grpProfB = secPerfiles:Grupo()
    grpProfB:Boton({
        Texto = "💾 Save as New Profile", Async = true,
        Callback = function()
            local name = LouisHub:ObtenerFlag("sys_nombre_nuevo_perfil")
            if not name or name == "" then LouisHub:Notificar({ Titulo = "Profiles", Texto = "Enter a name first", Duracion = 3 }); return end
            LouisHub.SaveManager:CambiarPerfil(self, name)
            refreshProfiles()
        end,
    })
    grpProfB:Boton({
        Texto = "🗑️ Delete Selected Profile", Async = true,
        Callback = function()
            if not selProfile then LouisHub:Notificar({ Titulo = "Profiles", Texto = "Select a profile first", Duracion = 3 }); return end
            local okDel = LouisHub.SaveManager:Eliminar(selProfile)
            LouisHub:Notificar({ Titulo = "Profiles", Texto = okDel and ("'" .. selProfile .. "' removed") or "Cannot delete", Duracion = 3 })
            if okDel then selProfile = nil; refreshProfiles() end
        end,
    })

    secPerfiles:Input({
        Texto = "Profile JSON Text (Export / Import)", Flag = "sys_perfil_texto", Tipo = "textarea",
        Alto = 80, MaxCaracteres = 60000, Placeholder = "JSON text will appear here. Paste here to import...",
    })
    LouisHub:MarcarComoUI("sys_perfil_texto")

    local grpProfC = secPerfiles:Grupo()
    grpProfC:Boton({
        Texto = "📑 Duplicate",
        Callback = function()
            local nName = LouisHub:ObtenerFlag("sys_nombre_nuevo_perfil")
            if not selProfile or not nName or nName == "" then LouisHub:Notificar({ Titulo = "Profiles", Texto = "Select profile and enter new name", Duracion = 3 }); return end
            local okDup, errDup = LouisHub.SaveManager:Duplicar(selProfile, nName)
            LouisHub:Notificar({ Titulo = okDup and "📑 Duplicated" or "Error", Texto = okDup and nName or tostring(errDup), Duracion = 3 })
            if okDup then refreshProfiles() end
        end,
    })
    grpProfC:Boton({
        Texto = "✏️ Rename",
        Callback = function()
            local nName = LouisHub:ObtenerFlag("sys_nombre_nuevo_perfil")
            if not selProfile or not nName or nName == "" then LouisHub:Notificar({ Titulo = "Profiles", Texto = "Select profile and enter new name", Duracion = 3 }); return end
            local okRen, errRen = LouisHub.SaveManager:Renombrar(selProfile, nName)
            LouisHub:Notificar({ Titulo = okRen and "✏️ Renamed" or "Error", Texto = okRen and nName or tostring(errRen), Duracion = 3 })
            if okRen then selProfile = nil; refreshProfiles() end
        end,
    })
    grpProfC:Boton({
        Texto = "📤 Export to Clipboard",
        Callback = function()
            if not selProfile then LouisHub:Notificar({ Titulo = "Profiles", Texto = "Select a profile first", Duracion = 3 }); return end
            local txt, cop = LouisHub.SaveManager:Exportar(selProfile)
            if not txt then LouisHub:Notificar({ Titulo = "Export", Texto = tostring(cop), Duracion = 3 }); return end
            local e = LouisHub.Elementos["sys_perfil_texto"]
            if e then e.Set(txt) end
            LouisHub:Notificar({ Titulo = "📤 Exported", Texto = cop and "Copied to clipboard" or "Written to textarea", Duracion = 3 })
        end,
    })
    grpProfC:Boton({
        Texto = "📥 Import from Text",
        Callback = function()
            local nName = LouisHub:ObtenerFlag("sys_nombre_nuevo_perfil")
            if not nName or nName == "" then LouisHub:Notificar({ Titulo = "Profiles", Texto = "Enter new profile name", Duracion = 3 }); return end
            local okImp, errImp = LouisHub.SaveManager:Importar(nName, LouisHub:ObtenerFlag("sys_perfil_texto"))
            LouisHub:Notificar({ Titulo = okImp and "📥 Imported" or "Error", Texto = okImp and nName or tostring(errImp), Duracion = 3 })
            if okImp then refreshProfiles() end
        end,
    })

    -- SECTION: ACTION HISTORY LOG
    local secHist = sysTab:CrearSeccion("Action History", { Columna = 1 })
    local lblHist = secHist:Label({ Texto = "History Log", Flag = "sys_hist_lbl", Valor = "Ready" })
    local grpHist = secHist:Grupo()
    grpHist:Boton({
        Texto = "↩️ Undo",
        Callback = function()
            local okU, eU = LouisHub:Deshacer()
            LouisHub:Notificar({ Titulo = okU and "↩️ Undone" or "History", Texto = okU and LouisHub:DescribirCambio(eU) or "Nothing to undo", Duracion = 2 })
        end,
    })
    grpHist:Boton({
        Texto = "↪️ Redo",
        Callback = function()
            local okR, eR = LouisHub:Rehacer()
            LouisHub:Notificar({ Titulo = okR and "↪️ Redone" or "History", Texto = okR and LouisHub:DescribirCambio(eR) or "Nothing to redo", Duracion = 2 })
        end,
    })
    LouisHub:RegistrarConexion(LouisHub.Eventos.HistorialCambiado:Connect(function(u, r)
        local txt = (u == 0 and r == 0) and "Ready" or (u .. " to undo · " .. r .. " to redo")
        lblHist.Set(txt)
    end))

    -- SECTION: KEYBOARD SHORTCUTS
    local secAtajos = sysTab:CrearSeccion("Keyboard Shortcuts", { Columna = 2 })
    secAtajos:Parrafo({
        Titulo    = "⌨️ Default Bindings",
        Contenido = "RightCtrl — Toggle GUI Visibility\n"
                 .. "Minimize (—) — Collapse to Floating Pill\n"
                 .. "Close (✕) — Destroy interface safely",
    })

    self._pestanaSistema = sysTab
    return sysTab
end

-- ===================================================================
--  3. ENHANCE CREARVENTANA (AUTOSAVE, SUITE & WINDOW METHODS HOOK)
-- ===================================================================
local origCrearVentana = LouisHub.CrearVentana
function LouisHub:CrearVentana(config)
    config = config or {}
    local Ventana = origCrearVentana(self, config)

    -- Attach Window Level Methods from V2
    function Ventana:AgregarPestanaPreinstalada(cfg)
        return agregarPestanaPreinstaladaA(self, cfg)
    end

    function Ventana:Resetear()
        for flag, elem in pairs(LouisHub.Elementos) do
            if elem._defecto ~= nil and not _Internal.uiFlags[flag] and not _Internal.nonPersistentFlags[flag] and type(elem.Set) == "function" then
                pcall(elem.Set, _Internal.copyDefault(elem._defecto), true)
            end
        end
    end

    function Ventana:CambiarTema(name)
        LouisHub.ThemeManager:AplicarTema(name)
        LouisHub:Notificar({ Titulo = "🎨 Theme", Texto = "'" .. name .. "' applied", Duracion = 2 })
    end

    function Ventana:GuardarConfiguracion()
        return LouisHub.SaveManager:Guardar(self.NombreConfig)
    end

    function Ventana:CargarConfiguracion()
        return LouisHub.SaveManager:Cargar(self.NombreConfig)
    end

    function Ventana:CrearHUD(cfg)
        return LouisHub:CrearHUD(cfg)
    end

    function Ventana:CrearBotonFlotante(cfg)
        return LouisHub:CrearBotonFlotante(cfg)
    end

    function Ventana:ConstruirDesdeSchema(schema)
        local res = {}
        if type(schema) ~= "table" or type(schema.Tabs) ~= "table" then return res end
        for _, dTab in ipairs(schema.Tabs) do
            local tab = self:CrearTab(dTab.Nombre or "Tab", dTab.Icono)
            for _, dSec in ipairs(dTab.Secciones or {}) do
                local seccion = tab:CrearSeccion(dSec.Nombre or "Section", { Colapsable = dSec.Colapsable, ColapsadaPorDefecto = dSec.ColapsadaPorDefecto, Columna = dSec.Columna })
                for flag, el in pairs(seccion:Construir(dSec.Controles or {})) do
                    if type(flag) == "string" then res[flag] = el end
                end
            end
        end
        return res
    end

    -- Preinstalled System Suite Auto-Mount
    if config.PestanaPreinstalada ~= false then
        Ventana:AgregarPestanaPreinstalada(type(config.PestanaPreinstalada) == "table" and config.PestanaPreinstalada or {})
    end

    -- AutoSave Background Loop Hook
    if config.AutoGuardar ~= false and fsAvailable() then
        _Internal.activeSaveWindow = Ventana
        task.defer(function()
            LouisHub.SaveManager:CargarSilencioso(Ventana.NombreConfig)
            LouisHub.SaveManager:CargarUI("preinstalada")
        end)
        _Internal.startAutoSaveLoop()
    end

    return Ventana
end

-- ===================================================================
--  4. SAFE WINDOW INITIALIZER (V2 REPLACEMENT CONFIRMATION RESTORED)
-- ===================================================================
function LouisHub:CrearVentanaConSeguridad(config)
    config = config or {}
    local nombreConfig = config.NombreConfig or "autosave"
    local flagRecordar = "AutoReemplazar_" .. (config.Titulo or "default")
    pcall(function() LouisHub.SaveManager:CargarSilencioso(nombreConfig) end)

    if LouisHub.Flags[flagRecordar] == true then
        local activa = _G.LouisHub_InstanciaActiva
        if activa and activa.Ventana and activa.Ventana.Destruir then
            pcall(function() activa.Ventana:Destruir() end)
        end
        return LouisHub:CrearVentana(config)
    end

    local instanciaActiva = _G.LouisHub_InstanciaActiva
    local ventanaActual   = instanciaActiva and instanciaActiva.Ventana
    if not (ventanaActual and ventanaActual._main and ventanaActual._main.Parent) then
        return LouisHub:CrearVentana(config)
    end

    local eventPause = Instance.new("BindableEvent")
    local accepted = false

    LouisHub:Confirmar({
        Titulo    = "⚠️ Existing Script Running",
        Contenido = string.format("Detected active GUI \"%s\". Do you want to replace it with \"%s\"?", instanciaActiva.Titulo or "Current GUI", config.Titulo or "New Script"),
        Icono     = "⚠️",
        BotonCancelar = { Texto = "Cancel", Variante = "neutral" },
        BotonAceptar  = {
            Texto = "Replace", Variante = "danger",
            Callback = function() accepted = true end,
        }
    })

    task.spawn(function()
        while LouisHub._modalesAbiertos and LouisHub._modalesAbiertos > 0 do task.wait(0.1) end
        eventPause:Fire()
    end)
    eventPause.Event:Wait()
    eventPause:Destroy()

    if not accepted then return nil end
    pcall(function() ventanaActual:Destruir() end)
    return LouisHub:CrearVentana(config)
end

return LouisHub
