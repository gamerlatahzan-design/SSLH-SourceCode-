-- ===================================================================
--  LOUIS HUB UI LIBRARY (V3.0 CORE ENGINE)
--  Brand: Louis Hub
--  Priority: Compatibility > Performance > Simplicity > Visual Design
--  [PART 1 OF 5] - Foundation, State, Platform Engine & Event Core
-- ===================================================================

-- Task library polyfills for legacy or sandboxed executors
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

-- Defensive table cloning to isolate table references
local function cloneTable(t)
    if type(t) ~= "table" then return {} end
    if type(table.clone) == "function" then return table.clone(t) end
    local copy = {}
    for k, v in pairs(t) do copy[k] = v end
    return copy
end

local function copyDefault(v)
    if type(v) == "table" then return cloneTable(v) end
    return v
end

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

-- Roblox core services
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService       = game:GetService("RunService")
local TextService      = game:GetService("TextService")
local Players          = game:GetService("Players")
local HttpService      = game:GetService("HttpService")
local Workspace        = game:GetService("Workspace")
local LocalPlayer      = Players.LocalPlayer

local LouisHub = {}
LouisHub.Elementos = createElementsTable()
LouisHub.Version   = "3.0.0"
LouisHub.DebugMode = false
LouisHub.MostrarErroresEnUI = true

-- Internal auto-save coordinator
local activeSaveWindow = nil
local pendingUnsavedChanges = false
local autoSaveLoopRunning = false
local _isLoadingFromFile = false

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

local _registeredThemeWindows = setmetatable({}, {__mode = "k"})
local _realFlags = {}
local _nonPersistentFlags = {}
local _uiFlags = {}
local _registeredKeybinds = {}

-- Keybind utilities and conflict detection
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
                    Duracion = 7,
                })
            end)
        end
    end
end

-- Flags Proxy System (triggers auto-save & change signals on mutate)
LouisHub.Flags = setmetatable({}, {
    __index = _realFlags,
    __newindex = function(_, key, val)
        if type(val) ~= "table" and _realFlags[key] == val then return end
        _realFlags[key] = val
        markPendingChange()
        if LouisHub.Eventos and LouisHub.Eventos.FlagCambiada then
            LouisHub.Eventos.FlagCambiada:Fire(key, val)
        end
    end,
})

-- Dynamic Text Scaling Engine (adapts text smoothly to constraints)
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
        if conn.Connected ~= false then
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
    local floorVal = (LouisHub.Capacidades and not LouisHub.Capacidades.Teclado) and 9 or 6
    local target = math.max(floorVal, math.floor(entry.base * factor + 0.5))

    if not entry.truncable then
        pcall(function() inst.TextSize = target end)
        return
    end

    local availWidth = inst.AbsoluteSize.X
    if availWidth <= 0 then
        if hasHiddenAncestor(inst) then return end
        entry.reintentos = (entry.reintentos or 0) + 1
        if entry.reintentos > 10 then return end
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

local function registerTextScale(instance, baseSize, category, truncable)
    category = category or "general"
    local entry = {
        instancia = instance, base = baseSize, categoria = category,
        truncable = truncable or false, reintentos = 0
    }
    table.insert(textScaleRegistry, entry)
    instance.Destroying:Connect(function()
        entry.muerta = true
        deadTextScales = deadTextScales + 1
        if deadTextScales >= 64 and deadTextScales * 4 >= #textScaleRegistry then
            deadTextScales = 0
            compactRegistry(textScaleRegistry)
            pruneDeadConnections()
        end
    end)

    if truncable then
        LouisHub:RegistrarConexion(instance:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            calculateAndApplyTextSize(entry)
        end))
        LouisHub:RegistrarConexion(instance:GetPropertyChangedSignal("Text"):Connect(function()
            calculateAndApplyTextSize(entry)
        end))
        task.defer(calculateAndApplyTextSize, entry)
    elseif textScales[category] ~= 1 then
        calculateAndApplyTextSize(entry)
    end
end

local function applyTextScale(cat, factor)
    textScales[cat] = factor
    for _, entry in ipairs(textScaleRegistry) do
        if entry.categoria == cat then calculateAndApplyTextSize(entry) end
    end
end

-- Active UI instance counter (health monitor metric)
local _uiInstanceCounter = 0
local function countCreatedInstance(inst)
    _uiInstanceCounter = _uiInstanceCounter + 1
    inst.Destroying:Connect(function() _uiInstanceCounter = _uiInstanceCounter - 1 end)
    return inst
end

-- Central Logging & Observability
LouisHub._Logs = {}
function LouisHub:_RegistrarError(ctx, msg)
    table.insert(self._Logs, { Momento = os.time(), Contexto = tostring(ctx or "?"), Mensaje = tostring(msg or "") })
    if #self._Logs > 50 then table.remove(self._Logs, 1) end
    warn("[LouisHub] Error in '" .. tostring(ctx or "?") .. "': " .. tostring(msg or ""))
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

-- Custom Global Signals System
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
    TemaCambiado      = createSignal(),
    ControlRegistrado = createSignal(),
    TipoCambiado      = createSignal(),
    HistorialCambiado = createSignal(),
}

-- Safe callback executor
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

local function normalizeSetArg(...)
    if select('#', ...) >= 2 then return (select(2, ...)) end
    return (select(1, ...))
end

function LouisHub:Try(flag, fallback)
    local elem = self.Elementos[flag]
    if not elem then return fallback end
    local ok, val = pcall(elem.Get)
    if not ok or val == nil then return fallback end
    return val
end

-- Environment, Executor & Sandbox Detection
local function detectExecutor()
    if type(getexecutorname) == "function" then
        local ok, n = pcall(getexecutorname)
        if ok and n and n ~= "" then return n end
    end
    local list = {
        {function() return syn ~= nil end,                 "Synapse X"},
        {function() return krnl ~= nil end,                "Krnl"},
        {function() return fluxus ~= nil end,              "Fluxus"},
        {function() return identifyexecutor ~= nil end,    "Unknown (identifyexecutor)"},
    }
    for _, item in ipairs(list) do
        local ok2, isIt = pcall(item[1])
        if ok2 and isIt then return item[2] end
    end
    return "Unknown"
end

local function getGuiParent()
    local ok, hui = pcall(function() return gethui() end)
    if ok and hui then return hui end
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

-- Data packing & serialization helpers
local VERSION_FORMATO_GUARDADO = 2

local function packFlags(flags, onlyUI)
    local res = { __version = VERSION_FORMATO_GUARDADO }
    for k, v in pairs(flags) do
        local skip = _nonPersistentFlags[k] or (onlyUI and not _uiFlags[k]) or (not onlyUI and _uiFlags[k])
        if not skip then
            if typeof(v) == "Color3" then
                res[k] = { __color3 = true, R = math.floor(v.R * 255 + 0.5), G = math.floor(v.G * 255 + 0.5), B = math.floor(v.B * 255 + 0.5) }
            elseif typeof(v) == "EnumItem" then
                res[k] = { __enum = true, EnumType = tostring(v.EnumType), Name = v.Name }
            elseif type(v) == "table" and typeof(v.KeyCode) == "EnumItem" then
                res[k] = { __keybindMods = true, KeyCode = v.KeyCode.Name, Ctrl = v.Ctrl or false, Shift = v.Shift or false, Alt = v.Alt or false }
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
        local ok, enumItem = pcall(function() return Enum[v.EnumType][v.Name] end)
        return (ok and enumItem) or Enum.KeyCode.Unknown
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
                Duracion = 6,
            })
        end)
    end
    return migrateSavedData(data, fromVer)
end

-- Runtime Platform & Capabilities Detector
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
        return ok and p or nil
    end)(),
    ViewportSize = (Workspace.CurrentCamera and Workspace.CurrentCamera.ViewportSize) or Vector2.new(0, 0),
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
        if C.ViewportSize.Y < 500 or C.ViewportSize.X < 600 then
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

-- Global Auto-Cleanup Lifecycle (prevents ghost threads and leaks on re-execution)
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
        for _, name in ipairs({"LouisHub_ScreenGui", "LouisHub_TooltipOverlay"}) do
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

function LouisHub:ObtenerFlag(flag) return LouisHub.Flags[flag] end
function LouisHub:MarcarComoUI(flagOrTable)
    if type(flagOrTable) == "table" then
        for _, f in ipairs(flagOrTable) do _uiFlags[f] = true end
    else
        _uiFlags[flagOrTable] = true
    end
end
function LouisHub:ObtenerElemento(flag) return LouisHub.Elementos[flag] end
function LouisHub:ActualizarLabel(flag, text)
    local elem = self.Elementos[flag]
    if not elem then return false end
    return pcall(elem.Set, text)
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

-- Central EventManager for input drag throttling and anti-overlap
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

-- Motion Curve Profiles & Tween Engines
LouisHub.Motion = {
    Directo         = 0,
    Press           = 0.14,
    Hover           = 0.12,
    HoverIntensidad = 0.20,
    FlashIn         = 0.08,
    FlashOut        = 0.35,
    Expand          = 0.18,
    Modal           = 0.25,
    Page            = 0.22,
    Spin            = 0.6,
    EaseEntrar      = Enum.EasingStyle.Quart,
    EaseSalir       = Enum.EasingStyle.Quad,
    EasePop         = Enum.EasingStyle.Back,
    EaseSuave       = Enum.EasingStyle.Sine,
    EaseLineal      = Enum.EasingStyle.Linear,
}

local activeTweens = setmetatable({}, {__mode = "k"})
local function getPropKey(props)
    local names = {}
    for name in pairs(props) do table.insert(names, name) end
    table.sort(names)
    return table.concat(names, ",")
end

local Utils = {}

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

    local info = TweenInfo.new(duration or 0.22, style or LouisHub.Motion.EaseEntrar, direction or Enum.EasingDirection.Out)
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

-- [END OF PART 1 - PROCEED TO PART 2]

-- ===================================================================
--  LOUIS HUB UI LIBRARY (V3.0 CORE ENGINE)
--  Brand: Louis Hub
--  [PART 2 OF 5] - Visual Primitives, Themes, Tooltips, Modals & History
-- ===================================================================

function Utils.Corner(parent, radius)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radius or 6)
    c.Parent = parent
    return c
end

function Utils.Stroke(parent, color, thickness, transparency)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(48, 30, 72)
    s.Thickness = thickness or 1
    s.Transparency = transparency or 0
    s.Parent = parent
    return s
end

function Utils.ClickFeedback(visual)
    if not visual or not visual.Parent then return end
    local scale = visual:FindFirstChild("__LouisHub_ClickScale")
    if not scale then
        for _, child in ipairs(visual:GetChildren()) do
            if child:IsA("UIScale") and child.Name ~= "__LouisHub_EntradaScale" then
                scale = child
                break
            end
        end
    end
    if not scale then
        scale = Instance.new("UIScale")
        scale.Name = "__LouisHub_ClickScale"
        scale.Scale = 1
        scale.Parent = visual
    end
    scale.Scale = 0.97
    Utils.Tween(scale, {Scale = 1}, LouisHub.Motion.Press, LouisHub.Motion.EasePop, Enum.EasingDirection.Out)
end

function Utils.ClickConfiable(obj, callback, visual)
    local threshold = (LouisHub.Capacidades and LouisHub.Capacidades.EsTactil) and 18 or 10
    local downPos = nil
    LouisHub:RegistrarConexion(obj.MouseButton1Down:Connect(function(x, y)
        downPos = Vector2.new(x, y)
        Utils.ClickFeedback(visual or obj)
    end))
    LouisHub:RegistrarConexion(obj.MouseButton1Up:Connect(function(x, y)
        if not downPos then return end
        local dist = (Vector2.new(x, y) - downPos).Magnitude
        downPos = nil
        if dist > threshold then return end
        callback()
    end))
end

function Utils.HitboxAmpliado(btn, padding)
    padding = padding or 0
    if padding <= 0 or not btn then return btn end
    local hb = Utils.BotonBase({
        Padre = btn,
        Size = UDim2.new(1, padding * 2, 1, padding * 2),
        Posicion = UDim2.new(0, -padding, 0, -padding),
        Transparencia = 1, Radio = false,
    })
    hb.ZIndex = btn.ZIndex + 1
    return hb
end

function Utils.Hover(eventObj, colorObj, intensity, duration, getBaseColor)
    if not eventObj or not colorObj then return end
    colorObj = colorObj or eventObj
    intensity = intensity or LouisHub.Motion.HoverIntensidad
    duration = duration or LouisHub.Motion.Hover

    local isHovered = false
    local colorOriginal = nil
    local colorReposo = nil
    local reposoVigenteHasta = 0

    LouisHub:RegistrarConexion(eventObj.MouseEnter:Connect(function()
        if isHovered then return end
        isHovered = true
        pcall(function()
            local base = getBaseColor and getBaseColor()
            if not base then
                if colorReposo and os.clock() < reposoVigenteHasta then
                    base = colorReposo
                else
                    base = colorObj.BackgroundColor3
                end
            end
            colorReposo = base
            colorOriginal = base
            Utils.Tween(colorObj, {
                BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), intensity)
            }, duration, LouisHub.Motion.EaseSuave, Enum.EasingDirection.Out)
        end)
    end))

    LouisHub:RegistrarConexion(eventObj.MouseLeave:Connect(function()
        if not isHovered then return end
        isHovered = false
        pcall(function()
            local dest = getBaseColor and getBaseColor() or colorOriginal or colorReposo
            if not dest then return end
            colorReposo = dest
            reposoVigenteHasta = os.clock() + duration + 0.08
            Utils.Tween(colorObj, {BackgroundColor3 = dest}, duration, LouisHub.Motion.EaseSuave, Enum.EasingDirection.Out)
        end)
        colorOriginal = nil
    end))
end

local COLOR_FLASH_EXITO = Color3.fromRGB(46, 204, 113)
local COLOR_FLASH_ERROR = Color3.fromRGB(231, 76, 60)

function Utils.FlashFeedback(instance, success, normalColor)
    if not instance or not instance.Parent then return end
    local flashCol = success and COLOR_FLASH_EXITO or COLOR_FLASH_ERROR
    pcall(function()
        Utils.Tween(instance, {BackgroundColor3 = flashCol}, LouisHub.Motion.FlashIn)
        task.delay(LouisHub.Motion.FlashIn, function()
            pcall(function()
                Utils.Tween(instance, {BackgroundColor3 = normalColor}, LouisHub.Motion.FlashOut)
            end)
        end)
    end)
end

function Utils.Frame(cfg)
    cfg = cfg or {}
    local f = Instance.new("Frame")
    countCreatedInstance(f)
    f.Size = cfg.Size or UDim2.new(1, 0, 0, cfg.Alto or 26)
    f.Position = cfg.Posicion or UDim2.new(0, 0, 0, 0)
    if cfg.Ancla then f.AnchorPoint = cfg.Ancla end
    f.BackgroundColor3 = cfg.Color or Color3.fromRGB(18, 12, 28)
    f.BackgroundTransparency = cfg.Transparencia or 0
    f.BorderSizePixel = 0
    f.ClipsDescendants = cfg.Recortar or false
    f.LayoutOrder = cfg.Orden or 0
    if cfg.Visible ~= nil then f.Visible = cfg.Visible end
    f.Parent = cfg.Padre
    if cfg.Radio ~= false then Utils.Corner(f, cfg.Radio) end
    if cfg.Borde then
        local st = Utils.Stroke(f, cfg.ColorBorde, cfg.GrosorBorde, cfg.TransparenciaBorde)
        if cfg.ClaveTemaBorde then LouisHub:Registrar(st, "Color", cfg.ClaveTemaBorde) end
    end
    return f
end

function Utils.Fila(parent, height, order, color)
    return Utils.Frame({Padre = parent, Size = UDim2.new(1, 0, 0, height), Orden = order, Color = color, Radio = 8})
end

function Utils.Texto(cfg)
    cfg = cfg or {}
    local l = Instance.new("TextLabel")
    countCreatedInstance(l)
    l.BackgroundTransparency = 1
    l.Size = cfg.Size or UDim2.new(1, -8, 1, 0)
    l.Position = cfg.Posicion or UDim2.new(0, 8, 0, 0)
    l.Font = cfg.Fuente or Enum.Font.Ubuntu
    local baseSize = cfg.Tamano or 12
    l.TextSize = baseSize
    l.TextColor3 = cfg.Color or Color3.fromRGB(245, 245, 255)
    l.TextXAlignment = cfg.Alineacion or Enum.TextXAlignment.Left
    l.TextTruncate = cfg.Truncar and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None
    l.TextWrapped = cfg.Ajustar or false
    l.TextTransparency = cfg.TextoTransparencia or 0
    l.RichText = cfg.RichText or false
    l.Text = cfg.Texto or ""
    l.LayoutOrder = cfg.Orden or 0
    l.Parent = cfg.Padre
    if cfg.ColorTema then
        LouisHub:Registrar(l, "TextColor3", cfg.ColorTema)
    elseif not cfg.Color then
        LouisHub:Registrar(l, "TextColor3", "Text")
    end
    registerTextScale(l, baseSize, cfg.Categoria, cfg.Truncar)
    return l
end

function Utils.Diferir(fn)
    local pending = false
    return function()
        if pending then return end
        pending = true
        task.delay(0.03, function()
            pending = false
            fn()
        end)
    end
end

function Utils.FactorEscalaUI(inst)
    local f = 1
    local cur = inst
    while cur do
        local ok, sc = pcall(function() return cur:FindFirstChildOfClass("UIScale") end)
        if ok and sc then f = f * sc.Scale end
        cur = cur.Parent
    end
    return (f > 0) and f or 1
end

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

function Utils.BotonBase(cfg)
    cfg = cfg or {}
    local b = Instance.new("TextButton")
    countCreatedInstance(b)
    b.Size = cfg.Size or UDim2.new(1, 0, 0, cfg.Alto or 26)
    b.Position = cfg.Posicion or UDim2.new(0, 0, 0, 0)
    if cfg.Ancla then b.AnchorPoint = cfg.Ancla end
    b.BackgroundTransparency = cfg.Transparencia == nil and 1 or cfg.Transparencia
    b.BackgroundColor3 = cfg.Color or Color3.fromRGB(22, 14, 34)
    b.AutoButtonColor = false
    b.Text = ""
    b.BorderSizePixel = 0
    b.LayoutOrder = cfg.Orden or 0
    b.Parent = cfg.Padre
    if cfg.Radio then Utils.Corner(b, cfg.Radio) end
    return b
end

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
                    local delta = Vector2.new(inp.Position.X, inp.Position.Y) - startDrag
                    target.Position = UDim2.new(
                        startTarget.X.Scale, startTarget.X.Offset + delta.X,
                        startTarget.Y.Scale, startTarget.Y.Offset + delta.Y
                    )
                end)
            end
        end
    end)
end

-- ===================================================================
--  THEMES SYSTEM & REACTIVE THEME MANAGER
-- ===================================================================
local Themes = {}
Themes.Predeterminado = "NeonHalloween"
Themes.Lista = {
    NeonHalloween = {
        Background      = Color3.fromRGB(11, 7, 18),
        BackgroundDark  = Color3.fromRGB(7, 4, 12),
        BackgroundLight = Color3.fromRGB(24, 15, 38),
        Accent          = Color3.fromRGB(255, 130, 20),
        AccentLight     = Color3.fromRGB(255, 160, 40),
        Highlight       = Color3.fromRGB(255, 205, 75),
        Text            = Color3.fromRGB(245, 245, 255),
        TextDark        = Color3.fromRGB(160, 150, 180),
        Border          = Color3.fromRGB(48, 30, 72),
        Panel           = Color3.fromRGB(18, 12, 28),
        PanelClaro      = Color3.fromRGB(26, 16, 42),
        Fila            = Color3.fromRGB(22, 14, 34),
        Entrada         = Color3.fromRGB(14, 9, 22),
        Apagado         = Color3.fromRGB(44, 30, 60),
    },
    Negro = {
        Background      = Color3.fromRGB(45, 48, 53),
        BackgroundDark  = Color3.fromRGB(32, 34, 38),
        BackgroundLight = Color3.fromRGB(55, 58, 64),
        Accent          = Color3.fromRGB(90, 140, 210),
        AccentLight     = Color3.fromRGB(130, 175, 230),
        Highlight       = Color3.fromRGB(180, 200, 230),
        Text            = Color3.fromRGB(240, 240, 240),
        TextDark        = Color3.fromRGB(230, 230, 230),
        Border          = Color3.fromRGB(12, 13, 15),
        Panel           = Color3.fromRGB(18, 19, 22),
        PanelClaro      = Color3.fromRGB(26, 28, 32),
        Fila            = Color3.fromRGB(32, 34, 38),
        Entrada         = Color3.fromRGB(15, 16, 19),
        Apagado         = Color3.fromRGB(60, 60, 60),
    },
    Blanco = {
        Background      = Color3.fromRGB(218, 218, 224),
        BackgroundDark  = Color3.fromRGB(198, 198, 205),
        BackgroundLight = Color3.fromRGB(240, 240, 245),
        Accent          = Color3.fromRGB(60, 120, 210),
        AccentLight     = Color3.fromRGB(100, 155, 230),
        Highlight       = Color3.fromRGB(40, 70, 130),
        Text            = Color3.fromRGB(25, 25, 30),
        TextDark        = Color3.fromRGB(20, 20, 20),
        Border          = Color3.fromRGB(195, 195, 200),
        Panel           = Color3.fromRGB(252, 252, 254),
        PanelClaro      = Color3.fromRGB(240, 240, 244),
        Fila            = Color3.fromRGB(232, 232, 237),
        Entrada         = Color3.fromRGB(220, 220, 226),
        Apagado         = Color3.fromRGB(180, 180, 180),
    },
    Verde = {
        Background      = Color3.fromRGB(58, 122, 68),
        BackgroundDark  = Color3.fromRGB(42, 92, 50),
        BackgroundLight = Color3.fromRGB(72, 145, 82),
        Accent          = Color3.fromRGB(90, 190, 120),
        AccentLight     = Color3.fromRGB(130, 215, 155),
        Highlight       = Color3.fromRGB(170, 230, 185),
        Text            = Color3.fromRGB(240, 240, 240),
        TextDark        = Color3.fromRGB(230, 230, 230),
        Border          = Color3.fromRGB(15, 30, 18),
        Panel           = Color3.fromRGB(24, 40, 27),
        PanelClaro      = Color3.fromRGB(32, 52, 36),
        Fila            = Color3.fromRGB(28, 46, 31),
        Entrada         = Color3.fromRGB(20, 34, 22),
        Apagado         = Color3.fromRGB(60, 60, 60),
    },
    Morado = {
        Background      = Color3.fromRGB(78, 55, 120),
        BackgroundDark  = Color3.fromRGB(58, 40, 92),
        BackgroundLight = Color3.fromRGB(98, 72, 145),
        Accent          = Color3.fromRGB(175, 45, 255),
        AccentLight     = Color3.fromRGB(195, 85, 255),
        Highlight       = Color3.fromRGB(225, 185, 255),
        Text            = Color3.fromRGB(240, 240, 240),
        TextDark        = Color3.fromRGB(230, 230, 230),
        Border          = Color3.fromRGB(28, 16, 44),
        Panel           = Color3.fromRGB(26, 20, 36),
        PanelClaro      = Color3.fromRGB(34, 27, 46),
        Fila            = Color3.fromRGB(30, 24, 42),
        Entrada         = Color3.fromRGB(22, 17, 32),
        Apagado         = Color3.fromRGB(60, 60, 60),
    },
    Rojo = {
        Background      = Color3.fromRGB(214, 70, 60),
        BackgroundDark  = Color3.fromRGB(164, 45, 40),
        BackgroundLight = Color3.fromRGB(230, 110, 100),
        Accent          = Color3.fromRGB(163, 45, 60),
        AccentLight     = Color3.fromRGB(204, 94, 100),
        Highlight       = Color3.fromRGB(234, 160, 160),
        Text            = Color3.fromRGB(255, 255, 255),
        TextDark        = Color3.fromRGB(25, 20, 20),
        Border          = Color3.fromRGB(35, 8, 8),
        Panel           = Color3.fromRGB(34, 20, 20),
        PanelClaro      = Color3.fromRGB(44, 27, 27),
        Fila            = Color3.fromRGB(38, 24, 24),
        Entrada         = Color3.fromRGB(28, 17, 17),
        Apagado         = Color3.fromRGB(60, 60, 60),
    }
}

local Theme = {}
for k, v in pairs(Themes.Lista[Themes.Predeterminado]) do Theme[k] = v end
LouisHub.Theme = Theme

function Utils.GradienteAcento(inst, intensity)
    intensity = intensity or 0.12
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

local themeRegistry = {}
local deadThemeEntries = 0
function LouisHub:Registrar(instance, prop, key)
    local entry = {instancia = instance, propiedad = prop, claveTema = key}
    table.insert(themeRegistry, entry)
    if typeof(instance) == "Instance" then
        instance.Destroying:Connect(function()
            entry.muerta = true
            deadThemeEntries = deadThemeEntries + 1
            if deadThemeEntries >= 64 and deadThemeEntries * 4 >= #themeRegistry then
                deadThemeEntries = 0
                compactRegistry(themeRegistry)
            end
        end)
    end
end

LouisHub.ThemeManager = { Temas = Themes.Lista }
function LouisHub.ThemeManager:AplicarTema(nameOrTable)
    local tbl = type(nameOrTable) == "string" and self.Temas[nameOrTable] or nameOrTable
    if not tbl then return end
    for k, v in pairs(tbl) do Theme[k] = v end

    local animar = LouisHub._ventanaRevelada == true
    local paginasOcultas = {}
    if animar then
        local activa = _G.LouisHub_InstanciaActiva
        local win = activa and activa.Ventana
        if win and win.Tabs then
            for _, t in ipairs(win.Tabs) do
                if t.Pagina and not t.Pagina.Visible then table.insert(paginasOcultas, t.Pagina) end
            end
        end
    end

    local function estaEnPaginaOculta(inst)
        for _, p in ipairs(paginasOcultas) do
            if inst:IsDescendantOf(p) then return true end
        end
        return false
    end

    for _, entry in ipairs(themeRegistry) do
        if entry.instancia and entry.instancia.Parent then
            local val = type(entry.claveTema) == "function" and entry.claveTema() or Theme[entry.claveTema]
            if val ~= nil then
                intentarSilencioso("ThemeManager", function()
                    local inst, prop = entry.instancia, entry.propiedad
                    if animar and typeof(val) == "Color3" and typeof(inst[prop]) == "Color3" and not estaEnPaginaOculta(inst) then
                        Utils.Tween(inst, {[prop] = val}, LouisHub.Motion.Page, LouisHub.Motion.EaseSuave, Enum.EasingDirection.InOut)
                    else
                        inst[prop] = val
                    end
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
    if type(name) == "string" and type(tbl) == "table" then self.Temas[name] = tbl end
end

function LouisHub.ThemeManager:GuardarTemaActual()
    if not fsAvailable() then return false end
    ensureFolder(LouisHub.SaveManager.Carpeta)
    local ok, json = pcall(function()
        local data = {}
        for k, v in pairs(Theme) do data[k] = {v.R, v.G, v.B} end
        return HttpService:JSONEncode(data)
    end)
    if not ok then return false end
    return pcall(writefile, LouisHub.SaveManager.Carpeta .. "/tema.json", json)
end

-- ===================================================================
--  TOOLTIP SYSTEM
-- ===================================================================
local overlayGui, panelAyuda, lblAyuda, conexionCierreGlobal

local function obtenerOverlayTooltip()
    if overlayGui and overlayGui.Parent then return overlayGui end
    overlayGui = Instance.new("ScreenGui")
    overlayGui.Name = "LouisHub_TooltipOverlay"
    overlayGui.ResetOnSpawn = false
    overlayGui.IgnoreGuiInset = true
    overlayGui.DisplayOrder = 999
    pcall(function() overlayGui.Parent = getGuiParent() end)
    protectGuiObject(overlayGui)

    panelAyuda = Instance.new("Frame")
    panelAyuda.Name = "PanelAyuda"
    panelAyuda.BackgroundColor3 = Theme.Panel
    panelAyuda.BorderSizePixel = 0
    panelAyuda.Visible = false
    panelAyuda.ZIndex = 1000
    panelAyuda.Size = UDim2.new(0, 200, 0, 0)
    panelAyuda.AutomaticSize = Enum.AutomaticSize.Y
    panelAyuda.Parent = overlayGui
    LouisHub:Registrar(panelAyuda, "BackgroundColor3", "Panel")
    Utils.Corner(panelAyuda, 6)
    local strokeTooltip = Utils.Stroke(panelAyuda, Theme.Accent, 1, 0.3)
    LouisHub:Registrar(strokeTooltip, "Color", "Accent")

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
    pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
    pad.Parent = panelAyuda

    lblAyuda = Utils.Texto({
        Padre = panelAyuda, Texto = "",
        Size = UDim2.new(1, 0, 0, 0), Tamano = 11, Ajustar = true,
    })
    lblAyuda.AutomaticSize = Enum.AutomaticSize.Y
    lblAyuda.ZIndex = 1001
    LouisHub:Registrar(lblAyuda, "TextColor3", "Text")
    return overlayGui
end

local function cerrarTooltipGlobal()
    if panelAyuda then panelAyuda.Visible = false end
    if conexionCierreGlobal then
        LouisHub:DesconectarYLimpiar(conexionCierreGlobal)
        conexionCierreGlobal = nil
    end
end

local function mostrarTooltipEn(elemRef, textHelp)
    obtenerOverlayTooltip()
    if panelAyuda.Visible and lblAyuda.Text == textHelp then
        cerrarTooltipGlobal()
        return
    end
    cerrarTooltipGlobal()

    lblAyuda.Text = textHelp
    panelAyuda.Size = UDim2.new(0, 200, 0, 0)

    local pos = elemRef.AbsolutePosition
    local tam = elemRef.AbsoluteSize
    local x = pos.X
    local y = pos.Y + tam.Y + 4
    local scrW = overlayGui.AbsoluteSize.X
    if scrW > 0 then x = math.min(x, scrW - 208) end
    panelAyuda.Position = UDim2.new(0, math.max(4, x), 0, y)
    panelAyuda.Visible = true

    local escalaTip = panelAyuda:FindFirstChild("__LouisHub_TooltipScale") or Instance.new("UIScale", panelAyuda)
    escalaTip.Name = "__LouisHub_TooltipScale"
    escalaTip.Scale = 0.9
    Utils.Tween(escalaTip, {Scale = 1}, LouisHub.Motion.Expand, LouisHub.Motion.EasePop, Enum.EasingDirection.Out)

    conexionCierreGlobal = LouisHub:RegistrarConexion(UserInputService.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            cerrarTooltipGlobal()
        end
    end))
end

local function agregarTooltip(row, pos, textHelp)
    if not textHelp then return end
    local btnInfo = Utils.BotonBase({
        Padre = row, Size = UDim2.new(0, 20, 0, 20), Posicion = pos,
        Color = Theme.AccentLight, Transparencia = 0, Radio = 10,
    })
    btnInfo.ZIndex = 5
    LouisHub:Registrar(btnInfo, "BackgroundColor3", "AccentLight")

    local lblSigno = Utils.Texto({
        Padre = btnInfo, Texto = "?", Alineacion = Enum.TextXAlignment.Center,
        Fuente = Enum.Font.FredokaOne, Tamano = 12, Color = Theme.TextDark,
    })
    LouisHub:Registrar(lblSigno, "TextColor3", "TextDark")
    btnInfo.MouseButton1Click:Connect(function() mostrarTooltipEn(btnInfo, textHelp) end)
    return btnInfo
end

local function agregarTooltipTexto(row, textLabel, textHelp, lblInst, offsetRight)
    if not textHelp then return end
    if not (lblInst and lblInst.Size) then
        agregarTooltip(row, UDim2.new(0, 160, 0, 8), textHelp)
        return
    end

    local TAM_INFO = 20
    local RESERVA  = TAM_INFO + 12
    local sx = lblInst.Size.X.Scale
    local ox = offsetRight or lblInst.Size.X.Offset
    local px = lblInst.Position.X.Offset
    lblInst.Size = UDim2.new(sx, ox - RESERVA - px, lblInst.Size.Y.Scale, lblInst.Size.Y.Offset)

    local xInfo = ox - TAM_INFO - 6
    local btnInfo = agregarTooltip(row, UDim2.new(sx, xInfo, 0.5, 0), textHelp)
    btnInfo.AnchorPoint = Vector2.new(0, 0.5)

    local function centrarY()
        if not (btnInfo.Parent and lblInst.Parent and row.Parent) then return end
        if lblInst.AbsoluteSize.Y <= 0 then return end
        local e = Utils.FactorEscalaUI(row)
        local cy = (lblInst.AbsolutePosition.Y - row.AbsolutePosition.Y + lblInst.AbsoluteSize.Y / 2) / e
        btnInfo.Position = UDim2.new(sx, xInfo, 0, math.floor(cy + 0.5))
    end
    LouisHub:RegistrarConexion(lblInst:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() centrarY(); task.defer(centrarY) end))
    LouisHub:RegistrarConexion(row:GetPropertyChangedSignal("AbsoluteSize"):Connect(function() centrarY(); task.defer(centrarY) end))
    task.defer(centrarY)

    row.Active = true
    local threshold = (LouisHub.Capacidades and LouisHub.Capacidades.EsTactil) and 18 or 10
    local touchStart = nil

    local function openTip()
        if panelAyuda and panelAyuda.Visible and lblAyuda and lblAyuda.Text == textHelp then return end
        pcall(mostrarTooltipEn, row, textHelp)
    end

    row.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1 and input.UserInputType ~= Enum.UserInputType.Touch then return end
        touchStart = input
        local startPos = Vector2.new(input.Position.X, input.Position.Y)
        local startTime = os.clock()
        task.spawn(function()
            while touchStart == input do
                if not (row and row.Parent) or input.UserInputState == Enum.UserInputState.End then return end
                if (Vector2.new(input.Position.X, input.Position.Y) - startPos).Magnitude > threshold then return end
                if os.clock() - startTime >= 0.45 then
                    touchStart = nil
                    openTip()
                    return
                end
                task.wait(0.05)
            end
        end)
    end)
    row.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then touchStart = nil end
    end)
    pcall(function()
        row.TouchLongPress:Connect(function(_, state)
            if state == Enum.UserInputState.Begin then openTip() end
        end)
    end)
    return btnInfo
end

-- ===================================================================
--  AUTO-UPDATE LABELS & CONDITIONAL VISIBILITY
-- ===================================================================
local _labelsAutoActualizables = setmetatable({}, {__mode = "k"})

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
                LouisHub:_RegistrarError("Label auto-update ('" .. tostring(cfg.flag) .. "')", val)
            end
        end
    end
end))

local registroVisibilidad = setmetatable({}, {__mode = "k"})
local function cumpleVisibilidadCondicional(row)
    local cond = registroVisibilidad[row]
    if not cond then return true end
    local ok, res = pcall(cond)
    if not ok then LouisHub:_RegistrarError("VisibleSi", res); return true end
    return res and true or false
end

local function reevaluarVisibilidadCondicional()
    for row, _ in pairs(registroVisibilidad) do
        if row and row.Parent then row.Visible = cumpleVisibilidadCondicional(row) end
    end
end
table.insert(_G.LouisHub_ConexionesModulo, LouisHub.Eventos.FlagCambiada:Connect(reevaluarVisibilidadCondicional))

-- ===================================================================
--  NOTIFICATIONS ENGINE
-- ===================================================================
local contenedorNotif
local MAX_NOTIF_SIMULTANEAS = 4
local colaNotif   = {}
local notifActivas = 0

local function crearContenedorNotif(padreGui)
    if contenedorNotif and contenedorNotif.Parent then return end
    contenedorNotif = Utils.Frame({
        Padre = padreGui, Transparencia = 1,
        Size = UDim2.new(0, 260, 0, 0),
        Posicion = UDim2.new(1, -270, 0, 10),
        Radio = false,
    })
    contenedorNotif.Name = "LouisHub_Notificaciones"
    contenedorNotif.AutomaticSize = Enum.AutomaticSize.Y
    contenedorNotif.ZIndex = 500
    contenedorNotif.Active = false

    local layout = Instance.new("UIListLayout", contenedorNotif)
    layout.Padding = UDim.new(0, 6)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
end

local COLORES_TIPO_NOTIF = {
    Success = Color3.fromRGB(46, 204, 113),
    Warning = Color3.fromRGB(241, 196, 15),
    Error   = Color3.fromRGB(231, 76, 60),
}

local function mostrarTarjetaNotif(cfg)
    notifActivas = notifActivas + 1
    local colorAcento = COLORES_TIPO_NOTIF[cfg.Tipo] or Theme.Accent
    local esTipoFijo  = COLORES_TIPO_NOTIF[cfg.Tipo] ~= nil

    local tarjeta = Utils.Frame({
        Padre = contenedorNotif, Color = Theme.Panel,
        Size = UDim2.new(1, 0, 0, 0), Radio = 8,
        Borde = true, ColorBorde = colorAcento, TransparenciaBorde = 0.3,
        ClaveTemaBorde = (not esTipoFijo) and "Accent" or nil,
    })
    tarjeta.AutomaticSize = Enum.AutomaticSize.Y
    tarjeta.ClipsDescendants = true
    tarjeta.Active = false
    LouisHub:Registrar(tarjeta, "BackgroundColor3", "Panel")

    local grad = Instance.new("UIGradient", tarjeta)
    grad.Rotation = 135
    grad.Color = ColorSequence.new(Theme.Panel:Lerp(colorAcento, 0.08), Theme.Panel)

    local escalaTarjeta = Instance.new("UIScale", tarjeta)
    escalaTarjeta.Scale = 0.85

    Utils.Frame({Padre = tarjeta, Size = UDim2.new(0, 3, 1, 0), Color = colorAcento, Radio = false})

    local pad = Instance.new("UIPadding", tarjeta)
    pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 12), UDim.new(0, 10)
    pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)

    Utils.Texto({
        Padre = tarjeta, Texto = cfg.Titulo or "Notification",
        Size = UDim2.new(1, 0, 0, 16), Fuente = Enum.Font.FredokaOne,
        Tamano = 12, Color = Theme.Highlight,
    })

    local lblTexto = Utils.Texto({
        Padre = tarjeta, Texto = cfg.Texto or "",
        Size = UDim2.new(1, 0, 0, 0), Posicion = UDim2.new(0, 0, 0, 16),
        Tamano = 11, Ajustar = true, Color = Theme.Text,
    })
    lblTexto.AutomaticSize = Enum.AutomaticSize.Y

    tarjeta.Position = UDim2.new(1.2, 0, 0, 0)
    Utils.Tween(tarjeta, {Position = UDim2.new(0, 0, 0, 0)}, LouisHub.Motion.Modal, LouisHub.Motion.EasePop, Enum.EasingDirection.Out)
    Utils.Tween(escalaTarjeta, {Scale = 1}, LouisHub.Motion.Modal, LouisHub.Motion.EasePop, Enum.EasingDirection.Out)

    local function cerrarTarjeta()
        if not (tarjeta and tarjeta.Parent) then return end
        local t = Utils.Tween(tarjeta, {Position = UDim2.new(1.2, 0, 0, 0)}, LouisHub.Motion.Page, LouisHub.Motion.EaseSalir, Enum.EasingDirection.In)
        Utils.Tween(escalaTarjeta, {Scale = 0.85}, LouisHub.Motion.Page, LouisHub.Motion.EaseSalir, Enum.EasingDirection.In)
        t.Completed:Connect(function()
            pcall(function() tarjeta:Destroy() end)
            notifActivas = math.max(0, notifActivas - 1)
            local siguiente = table.remove(colaNotif, 1)
            if siguiente then pcall(mostrarTarjetaNotif, siguiente) end
        end)
    end

    if cfg.Persistente then
        local btnCerrar = Instance.new("TextButton", tarjeta)
        btnCerrar.BackgroundTransparency = 1
        btnCerrar.Text = ""
        btnCerrar.Size = UDim2.new(1, 0, 1, 0)
        btnCerrar.ZIndex = tarjeta.ZIndex + 1
        btnCerrar.MouseButton1Click:Connect(cerrarTarjeta)
    else
        task.delay(cfg.Duracion or 4, cerrarTarjeta)
    end
end

function LouisHub:Notificar(cfg)
    cfg = cfg or {}
    if not contenedorNotif then return end
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

-- ===================================================================
--  LOCK OVERLAY & MODAL HELPERS
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
    return proxy
end

function Utils.AnexarBloqueo(elem, row)
    local overlay, lblMotivo, insignia
    local bloqueado, motivo = false, nil
    local POS_INSIGNIA = UDim2.new(1, -8, 0.5, 0)
    local tokenSacudida = 0
    rawset(elem, "Fila", row)
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
        overlay.BackgroundColor3 = Theme.BackgroundDark
        overlay.BackgroundTransparency = 0.35
        overlay.BorderSizePixel = 0
        overlay.AutoButtonColor = false
        overlay.Text = ""
        overlay.ZIndex = 100
        overlay.Visible = false
        overlay.Parent = row

        local corner = row:FindFirstChildOfClass("UICorner")
        if corner then Utils.Corner(overlay, corner.CornerRadius.Offset) end
        LouisHub:Registrar(overlay, "BackgroundColor3", "BackgroundDark")

        insignia = Utils.Frame({
            Padre = overlay, Size = UDim2.new(0.55, -8, 0, 26),
            Posicion = POS_INSIGNIA, Ancla = Vector2.new(1, 0.5),
            Color = Theme.Panel, Radio = 6,
        })
        insignia.ZIndex = 101
        LouisHub:Registrar(insignia, "BackgroundColor3", "Panel")

        lblMotivo = Utils.Texto({
            Padre = insignia, Texto = "",
            Size = UDim2.new(1, -12, 1, 0), Posicion = UDim2.new(0, 6, 0, 0),
            Alineacion = Enum.TextXAlignment.Center, Tamano = 12, Truncar = true,
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
                    }, 0.05, LouisHub.Motion.EaseSuave, Enum.EasingDirection.InOut)
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
            Utils.Tween(insignia, {BackgroundTransparency = 0, Position = POS_INSIGNIA}, LouisHub.Motion.Expand, LouisHub.Motion.EasePop)
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
    for _, o in ipairs(targets) do Utils.Tween(o[1], {[o[2]] = o[3]}, duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out) end
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
    Utils.Tween(frame, {Size = finalSize}, LouisHub.Motion.Expand, LouisHub.Motion.EaseEntrar, Enum.EasingDirection.Out)
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
    Utils.Tween(backdrop, {BackgroundTransparency = origTrans}, LouisHub.Motion.Expand, LouisHub.Motion.EaseEntrar, Enum.EasingDirection.Out)
    Utils.Tween(sc, {Scale = 1}, LouisHub.Motion.Modal, LouisHub.Motion.EaseEntrar, Enum.EasingDirection.Out)
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

function Utils.AnexarDescripcion(row, parent, order, text, zoneWidth)
    local panel = Utils.Frame({
        Padre = parent, Size = UDim2.new(1, 0, 0, 0), Color = Theme.Fila, Orden = order, Radio = 8,
    })
    panel.AutomaticSize = Enum.AutomaticSize.Y
    panel.Visible = false
    LouisHub:Registrar(panel, "BackgroundColor3", "Fila")
    local pad = Instance.new("UIPadding", panel)
    pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
    pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 28), UDim.new(0, 12)

    local lblDesc = Utils.Texto({
        Padre = panel, Texto = tostring(text), Size = UDim2.new(1, 0, 0, 0),
        Ajustar = true, Tamano = 11, Color = Theme.TextDark, ColorTema = "TextDark",
    })
    lblDesc.AutomaticSize = Enum.AutomaticSize.Y

    local zone = Utils.BotonBase({
        Padre = row, Size = zoneWidth or UDim2.new(1, 0, 1, 0), Color = Theme.Fila, Transparencia = 1, Radio = 8,
    })
    local arrow = Instance.new("ImageLabel", row)
    arrow.BackgroundTransparency = 1
    arrow.Image = "rbxassetid://83472139709682"
    arrow.ScaleType = Enum.ScaleType.Fit
    arrow.Size = UDim2.new(0, 10, 0, 10)
    arrow.AnchorPoint = Vector2.new(0.5, 0.5)
    arrow.Position = UDim2.new(0, 14, 0.5, 0)
    arrow.Rotation = -90
    LouisHub:Registrar(arrow, "ImageColor3", "Text")

    Utils.ClickConfiable(zone, function()
        panel.Visible = not panel.Visible
        Utils.Tween(arrow, {Rotation = panel.Visible and 0 or -90}, LouisHub.Motion.Expand)
    end)
    return panel
end

-- ===================================================================
--  UNDO / REDO HISTORY ENGINE
-- ===================================================================
LouisHub._historial = { deshacer = {}, rehacer = {}, ultimos = {}, pausa = 0 }
local MAX_HISTORIAL = 50

local function notifyHistoryChanged()
    local h = LouisHub._historial
    LouisHub.Eventos.HistorialCambiado:Fire(#h.deshacer, #h.rehacer)
end

table.insert(_G.LouisHub_ConexionesModulo, LouisHub.Eventos.FlagCambiada:Connect(function(flag, val)
    local h = LouisHub._historial
    local prev = h.ultimos[flag]
    h.ultimos[flag] = copyDefault(val)
    if h.pausa > 0 or _uiFlags[flag] or _nonPersistentFlags[flag] then return end
    local elem = LouisHub.Elementos[flag]
    if prev == nil and elem then prev = elem._defecto end
    if prev == nil or (type(val) ~= "table" and prev == val) then return end

    local now = os.clock()
    local last = h.deshacer[#h.deshacer]
    if last and #last.cambios == 1 and last.cambios[1].flag == flag and now - last.t < 0.6 then
        last.cambios[1].despues = copyDefault(val)
        last.t = now
    else
        table.insert(h.deshacer, {
            t = now, cambios = { { flag = flag, antes = copyDefault(prev), despues = copyDefault(val) } }
        })
        if #h.deshacer > MAX_HISTORIAL then table.remove(h.deshacer, 1) end
    end
    h.rehacer = {}
    notifyHistoryChanged()
end))

local function applyHistoryChanges(changes, useBefore, inReverse)
    local h = LouisHub._historial
    h.pausa = h.pausa + 1
    local total = #changes
    for i = 1, total do
        local c = changes[inReverse and (total - i + 1) or i]
        local elem = LouisHub.Elementos[c.flag]
        if elem and type(elem.Set) == "function" then
            local val = copyDefault(useBefore and c.antes or c.despues)
            pcall(elem.Set, val, true)
            h.ultimos[c.flag] = copyDefault(val)
        end
    end
    h.pausa = h.pausa - 1
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
            if ok and val ~= nil then h.ultimos[flag] = copyDefault(val) end
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
--  CONFIRMATION MODAL ENGINE
-- ===================================================================
function LouisHub:Confirmar(cfg)
    cfg = cfg or {}
    local gui = self._guiConfirmar
    if not (gui and gui.Parent) then
        self:_RegistrarError("Confirmar", "No active ScreenGui context for modal dialog.")
        return nil
    end

    local buttons = {}
    if type(cfg.Botones) == "table" and #cfg.Botones > 0 then
        for _, b in ipairs(cfg.Botones) do table.insert(buttons, cloneTable(b)) end
    else
        if cfg.BotonCancelar then
            local b = cloneTable(cfg.BotonCancelar)
            b.Texto = b.Texto or "Cancel"
            b.Variante = b.Variante or "neutral"
            table.insert(buttons, b)
        end
        local okBtn = cloneTable(cfg.BotonAceptar or {})
        okBtn.Texto = okBtn.Texto or "Accept"
        okBtn.Variante = okBtn.Variante or "primary"
        table.insert(buttons, okBtn)
    end

    self._modalesAbiertos = (self._modalesAbiertos or 0) + 1
    local zBase = 500 + (self._modalesAbiertos - 1) * 10

    local backdrop = Utils.Frame({
        Padre = gui, Size = UDim2.new(1, 0, 1, 0),
        Color = Color3.new(0, 0, 0), Transparencia = 0.5, Radio = false,
    })
    backdrop.ZIndex = zBase
    backdrop.Active = true

    local card = Utils.Frame({
        Padre = backdrop, Size = UDim2.new(0, 300, 0, 0),
        Posicion = UDim2.new(0.5, 0, 0.5, 0), Ancla = Vector2.new(0.5, 0.5),
        Color = Theme.Panel, Radio = 10, Borde = true, ColorBorde = Theme.Border, ClaveTemaBorde = "Border",
    })
    card.ZIndex = zBase + 1
    card.AutomaticSize = Enum.AutomaticSize.Y
    LouisHub:Registrar(card, "BackgroundColor3", "Panel")

    local layout = Instance.new("UIListLayout", card)
    layout.Padding = UDim.new(0, 12)
    layout.SortOrder = Enum.SortOrder.LayoutOrder

    local pad = Instance.new("UIPadding", card)
    pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 16), UDim.new(0, 16)
    pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 16), UDim.new(0, 16)

    local order = 0
    if cfg.Icono then
        order = order + 1
        local lIco = Utils.Texto({
            Padre = card, Texto = tostring(cfg.Icono), Size = UDim2.new(1, 0, 0, 28),
            Orden = order, Alineacion = Enum.TextXAlignment.Center, Tamano = 24,
        })
        lIco.ZIndex = zBase + 2
    end
    if cfg.Titulo then
        order = order + 1
        local lTit = Utils.Texto({
            Padre = card, Texto = tostring(cfg.Titulo), Size = UDim2.new(1, 0, 0, 0),
            Orden = order, Fuente = Enum.Font.FredokaOne, Tamano = 15, Ajustar = true,
            Alineacion = cfg.Icono and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
        })
        lTit.AutomaticSize = Enum.AutomaticSize.Y
        lTit.ZIndex = zBase + 2
    end
    if cfg.Contenido then
        order = order + 1
        local lBody = Utils.Texto({
            Padre = card, Texto = tostring(cfg.Contenido), Size = UDim2.new(1, 0, 0, 0),
            Orden = order, Ajustar = true, Tamano = 12, TextoTransparencia = 0.15,
            Alineacion = cfg.Icono and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
        })
        lBody.AutomaticSize = Enum.AutomaticSize.Y
        lBody.ZIndex = zBase + 2
    end

    order = order + 1
    local totalB = #buttons
    local vertical = totalB > 3
    local rowBtns = Utils.Frame({
        Padre = card, Size = UDim2.new(1, 0, 0, vertical and 0 or 34),
        Transparencia = 1, Orden = order,
    })
    rowBtns.ZIndex = zBase + 2
    if vertical then rowBtns.AutomaticSize = Enum.AutomaticSize.Y end

    local btnLayout = Instance.new("UIListLayout", rowBtns)
    btnLayout.FillDirection = vertical and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
    btnLayout.Padding = UDim.new(0, 8)
    btnLayout.SortOrder = Enum.SortOrder.LayoutOrder

    local function close() if backdrop.Parent then backdrop:Destroy() end end
    local function press(idx)
        local b = buttons[idx]
        if not b then return end
        close()
        if type(b.Callback) == "function" then executeCallback(b.Callback, b.Texto or "Modal") end
    end

    for i, b in ipairs(buttons) do
        local var = b.Variante or "neutral"
        local bWidth = vertical and UDim2.new(1, 0, 0, 34) or UDim2.new(1 / totalB, -math.ceil(8 * (totalB - 1) / totalB), 1, 0)
        local col, themeKey, txtCol, conBorde = Theme.Fila, "Fila", nil, false
        if var == "primary" then col, themeKey, txtCol = Theme.Accent, "Accent", Color3.fromRGB(255, 255, 255)
        elseif var == "danger" then col, themeKey, txtCol = Color3.fromRGB(190, 60, 60), nil, Color3.fromRGB(255, 255, 255)
        elseif var == "tertiary" then col, themeKey, conBorde = Theme.Panel, nil, true end

        local btn = Utils.BotonBase({
            Padre = rowBtns, Size = bWidth, Color = col, Transparencia = var == "tertiary" and 1 or 0, Radio = 6,
        })
        btn.LayoutOrder = i
        btn.ZIndex = zBase + 3
        if themeKey then LouisHub:Registrar(btn, "BackgroundColor3", themeKey) end
        if conBorde then
            local st = Utils.Stroke(btn, Theme.Border, 1)
            LouisHub:Registrar(st, "Color", "Border")
        else
            Utils.Hover(btn, btn)
        end

        local lbl = Utils.Texto({
            Padre = btn, Texto = tostring(b.Texto or "OK"), Alineacion = Enum.TextXAlignment.Center,
            Tamano = 12, Fuente = Enum.Font.FredokaOne, Color = txtCol, Truncar = true,
        })
        lbl.ZIndex = zBase + 4
        btn.MouseButton1Click:Connect(function() press(i) end)
    end

    Utils.EntradaModal(backdrop, card)
    return { Cerrar = close, Presionar = press, Fondo = backdrop }
end

-- [END OF PART 2 - PROCEED TO PART 3]

-- ===================================================================
--  LOUIS HUB UI LIBRARY (V3.0 CORE ENGINE)
--  Brand: Louis Hub
--  [PART 3 OF 5] - Full SaveManager, External HUD & Mobile Action Button
-- ===================================================================

-- ===================================================================
--  COMPLETE SAVE & CONFIG MANAGER
-- ===================================================================
LouisHub.SaveManager = {
    Carpeta   = "LouisHub/Config",
    CarpetaUI = "LouisHub/Config/_ui"
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

function SM:GuardarSilencioso(name)
    name = name or "default"
    if not LouisHub.Capacidades.Archivos then return false end
    asegurarCarpeta()
    local ok, err = pcall(function()
        local data = packFlags(_realFlags)
        writefile(SM.Carpeta .. "/" .. name .. ".json", HttpService:JSONEncode(data))
    end)
    if not ok then LouisHub:_RegistrarError("SaveManager:GuardarSilencioso", err) end
    return ok
end

function SM:Guardar(name)
    name = name or "default"
    if not fsAvailable() then
        LouisHub:Notificar({ Titulo = "SaveManager", Texto = "Executor lacks filesystem support.", Duracion = 4 })
        return false
    end
    asegurarCarpeta()
    local path = SM.Carpeta .. "/" .. name .. ".json"
    local hasChanges = true

    local ok, err = pcall(function()
        local data = packFlags(_realFlags)
        local json = HttpService:JSONEncode(data)

        if type(isfile) == "function" and isfile(path) then
            local okRead, existing = pcall(readfile, path)
            if okRead and existing == json then
                hasChanges = false
            end
        end

        if hasChanges then
            writefile(path, json)
        end
    end)

    if ok then
        if hasChanges then
            LouisHub:Notificar({ Titulo = "Config Saved", Texto = name .. ".json", Tipo = "Success", Duracion = 3 })
        else
            LouisHub:Notificar({ Titulo = "✅ Up to Date", Texto = name .. ".json has no pending changes.", Duracion = 3 })
        end
    else
        LouisHub:_RegistrarError("SaveManager:Guardar", err)
        LouisHub:Notificar({ Titulo = "❌ Save Failed", Texto = tostring(err):sub(1, 100), Tipo = "Error", Duracion = 5 })
    end
    return ok
end

function SM:CargarSilencioso(name)
    name = name or "default"
    local path = SM.Carpeta .. "/" .. name .. ".json"
    if not (fsAvailable() and type(isfile) == "function" and isfile(path)) then return false end

    local okRead, content = pcall(readfile, path)
    if not okRead then
        LouisHub:_RegistrarError("SaveManager:CargarSilencioso (read)", content)
        return false
    end
    local okDecode, data = pcall(function() return HttpService:JSONDecode(content) end)
    if not okDecode then
        LouisHub:_RegistrarError("SaveManager:CargarSilencioso (json)", data)
        return false
    end
    data = prepareLoadedData(data)

    _isLoadingFromFile = true
    local okLoop, errLoop = pcall(function()
        for flag, rawVal in pairs(data) do
            local val = unpackFlagValue(rawVal)
            LouisHub.Flags[flag] = val
            if LouisHub.Elementos[flag] then
                pcall(LouisHub.Elementos[flag].Set, val, true)
            end
        end
    end)
    _isLoadingFromFile = false

    if not okLoop then LouisHub:_RegistrarError("SaveManager:CargarSilencioso (restore)", errLoop) end
    checkKeybindConflictsOnLoad()
    LouisHub:Notificar({ Titulo = "Config Loaded", Texto = name .. ".json", Tipo = "Success", Duracion = 3 })
    return true
end

function SM:Cargar(name)
    return self:CargarSilencioso(name)
end

function SM:CambiarPerfil(ventana, name)
    if type(ventana) ~= "table" or type(name) ~= "string" or name == "" then
        LouisHub:_RegistrarError("SaveManager:CambiarPerfil", "Invalid window or profile name.")
        return false
    end

    if ventana.NombreConfig then
        SM:GuardarSilencioso(ventana.NombreConfig)
    end

    ventana.NombreConfig = name
    local exists = SM:Cargar(name)
    if not exists then
        LouisHub:Notificar({ Titulo = "New Profile", Texto = "'" .. name .. "' created (no prior file)", Duracion = 3 })
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
    if type(name) ~= "string" or name == "" then return false end
    if not (fsAvailable() and type(isfile) == "function" and type(delfile) == "function") then return false end
    local path = SM.Carpeta .. "/" .. name .. ".json"
    if not isfile(path) then return false end
    local ok, err = pcall(delfile, path)
    if not ok then LouisHub:_RegistrarError("SaveManager:Eliminar", err) end
    return ok
end

local function nombrePerfilValido(name)
    if type(name) ~= "string" then return false end
    local clean = name:match("^%s*(.-)%s*$")
    if clean == "" or #clean > 60 or clean:find('[/\\:*?"<>|%c]') then return false end
    return true, clean
end

function SM:Duplicar(orig, dest)
    local okO, nameO = nombrePerfilValido(orig)
    local okD, nameD = nombrePerfilValido(dest)
    if not (okO and okD) then return false, "Invalid profile name" end
    if not (fsAvailable() and type(isfile) == "function") then return false, "No FS" end
    asegurarCarpeta()
    local pO = SM.Carpeta .. "/" .. nameO .. ".json"
    local pD = SM.Carpeta .. "/" .. nameD .. ".json"
    if not isfile(pO) then return false, "Source profile not found" end
    if isfile(pD) then return false, "Target profile already exists" end
    local ok, err = pcall(function() writefile(pD, readfile(pO)) end)
    if not ok then
        LouisHub:_RegistrarError("SaveManager:Duplicar", err)
        return false, "Failed to copy profile"
    end
    return true
end

function SM:Renombrar(orig, dest)
    local ok, err = SM:Duplicar(orig, dest)
    if not ok then return false, err end
    local _, nameO = nombrePerfilValido(orig)
    if not SM:Eliminar(nameO) then return true, "Copied, but original was not removed" end
    return true
end

function SM:Exportar(name)
    local okN, cleanName = nombrePerfilValido(name)
    if not okN then return nil, "Invalid profile name" end
    if not (fsAvailable() and type(isfile) == "function") then return nil, "No FS" end
    local path = SM.Carpeta .. "/" .. cleanName .. ".json"
    if not isfile(path) then return nil, "Profile not found" end
    local okR, text = pcall(readfile, path)
    if not okR then return nil, "Read failure" end
    local copied = false
    if type(setclipboard) == "function" then copied = pcall(setclipboard, text) end
    return text, copied
end

function SM:Importar(name, text, overwrite)
    local okN, cleanName = nombrePerfilValido(name)
    if not okN then return false, "Invalid profile name" end
    if type(text) ~= "string" or text:match("^%s*$") then return false, "No text provided" end
    if #text > 200000 then return false, "Payload too large" end
    if not (fsAvailable() and type(isfile) == "function") then return false, "No FS" end
    local okJ, data = pcall(function() return HttpService:JSONDecode(text) end)
    if not okJ or type(data) ~= "table" then return false, "Invalid JSON data" end
    asegurarCarpeta()
    local path = SM.Carpeta .. "/" .. cleanName .. ".json"
    if isfile(path) and not overwrite then return false, "Profile already exists" end
    local ok, err = pcall(writefile, path, text)
    if not ok then LouisHub:_RegistrarError("SaveManager:Importar", err) end
    return ok
end

function SM:GuardarUI(name)
    name = name or "default"
    if not fsAvailable() then return false end
    asegurarCarpetaUI()
    local path = SM.CarpetaUI .. "/" .. name .. ".json"
    local hasChanges = true

    local ok, err = pcall(function()
        local data = packFlags(_realFlags, true)
        local json = HttpService:JSONEncode(data)

        if type(isfile) == "function" and isfile(path) then
            local okR, ex = pcall(readfile, path)
            if okR and ex == json then hasChanges = false end
        end

        if hasChanges then writefile(path, json) end
    end)

    if ok then
        if hasChanges then
            LouisHub:Notificar({ Titulo = "UI Settings Saved", Texto = name .. ".json", Tipo = "Success", Duracion = 3 })
        else
            LouisHub:Notificar({ Titulo = "✅ Up to Date", Texto = "UI settings already saved.", Duracion = 3 })
        end
    else
        LouisHub:_RegistrarError("SaveManager:GuardarUI", err)
        LouisHub:Notificar({ Titulo = "❌ Save Failed", Texto = tostring(err):sub(1, 100), Tipo = "Error", Duracion = 5 })
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
    data = prepareLoadedData(data)

    _isLoadingFromFile = true
    pcall(function()
        for flag, rawVal in pairs(data) do
            if _uiFlags[flag] then
                local val = unpackFlagValue(rawVal)
                LouisHub.Flags[flag] = val
                if LouisHub.Elementos[flag] then
                    pcall(LouisHub.Elementos[flag].Set, val, true)
                end
            end
        end
    end)
    _isLoadingFromFile = false
    checkKeybindConflictsOnLoad()
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
    if type(name) ~= "string" or name == "" then return false end
    if not (fsAvailable() and type(isfile) == "function" and type(delfile) == "function") then return false end
    local path = SM.CarpetaUI .. "/" .. name .. ".json"
    if not isfile(path) then return false end
    local ok, err = pcall(delfile, path)
    if not ok then LouisHub:_RegistrarError("SaveManager:EliminarUI", err) end
    return ok
end

for _, fnName in ipairs({ "CargarSilencioso", "CargarUI" }) do
    local orig = SM[fnName]
    if type(orig) == "function" then
        SM[fnName] = function(...)
            local res = table.pack(orig(...))
            LouisHub:LimpiarHistorial()
            return table.unpack(res, 1, res.n)
        end
    end
end

-- ===================================================================
--  NEW COMPONENT 1: FLOATING EXTERNAL STATS HUD
-- ===================================================================
function LouisHub:CrearHUD(cfg)
    cfg = cfg or {}
    local parentGui = getGuiParent():FindFirstChild("LouisHub_ScreenGui") or getGuiParent()
    local titulo = cfg.Titulo or "Stats HUD"
    local visible = cfg.Visible or false

    local hudFrame = Utils.Frame({
        Padre = parentGui,
        Size = UDim2.new(0, cfg.Ancho or 190, 0, 0),
        Posicion = cfg.Posicion or UDim2.new(1, -210, 0.5, -60),
        Color = Theme.Panel,
        Radio = 8,
        Borde = true,
        ColorBorde = Theme.Accent,
        Visible = visible
    })
    hudFrame.Name = "LouisHub_ExternalHUD"
    hudFrame.AutomaticSize = Enum.AutomaticSize.Y
    hudFrame.ZIndex = 400
    hudFrame.ClipsDescendants = true
    LouisHub:Registrar(hudFrame, "BackgroundColor3", "Panel")
    LouisHub:Registrar(hudFrame.UIStroke, "Color", "Accent")

    local header = Utils.Frame({
        Padre = hudFrame, Size = UDim2.new(1, 0, 0, 24),
        Color = Theme.BackgroundDark, Radio = 8,
    })
    LouisHub:Registrar(header, "BackgroundColor3", "BackgroundDark")
    Utils.Arrastrable(header, hudFrame, LouisHub.EventManager)

    local lblTitle = Utils.Texto({
        Padre = header, Texto = titulo,
        Size = UDim2.new(1, -12, 1, 0), Posicion = UDim2.new(0, 6, 0, 0),
        Fuente = Enum.Font.FredokaOne, Tamano = 11, Color = Theme.Highlight
    })
    LouisHub:Registrar(lblTitle, "TextColor3", "Highlight")

    local content = Utils.Frame({
        Padre = hudFrame, Size = UDim2.new(1, 0, 0, 0),
        Posicion = UDim2.new(0, 0, 0, 26), Transparencia = 1
    })
    content.AutomaticSize = Enum.AutomaticSize.Y
    local layout = Instance.new("UIListLayout", content)
    layout.Padding = UDim.new(0, 4)
    local pad = Instance.new("UIPadding", content)
    pad.PaddingLeft, pad.PaddingRight, pad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6), UDim.new(0, 6)

    local rows = {}

    local HUD = { Frame = hudFrame }
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
            Padre = content, Size = UDim2.new(1, 0, 0, 18),
            Color = Theme.Fila, Radio = 4
        })
        LouisHub:Registrar(rowFrame, "BackgroundColor3", "Fila")

        local lbl = Utils.Texto({
            Padre = rowFrame, Texto = labelText,
            Size = UDim2.new(0.55, -4, 1, 0), Posicion = UDim2.new(0, 4, 0, 0),
            Tamano = 10, Color = Theme.TextDark, Truncar = true
        })
        local valLbl = Utils.Texto({
            Padre = rowFrame, Texto = tostring(defaultVal or "-"),
            Size = UDim2.new(0.45, -4, 1, 0), Posicion = UDim2.new(0.55, 0, 0, 0),
            Alineacion = Enum.TextXAlignment.Right, Tamano = 10,
            Color = Theme.Highlight, Truncar = true
        })
        LouisHub:Registrar(valLbl, "TextColor3", "Highlight")

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
--  NEW COMPONENT 2: FLOATING ACTION BUTTON (MOBILE-OPTIMIZED)
-- ===================================================================
function LouisHub:CrearBotonFlotante(cfg)
    cfg = cfg or {}
    local parentGui = getGuiParent():FindFirstChild("LouisHub_ScreenGui") or getGuiParent()
    local text = cfg.Texto or "Action"
    local mode = cfg.Modo or "Click"
    local state = cfg.Defecto or false
    local keybind = cfg.Keybind
    local visible = cfg.Visible or false

    local sizeW = cfg.Ancho or 90
    local sizeH = cfg.Alto or 34

    local btnFrame = Utils.BotonBase({
        Padre = parentGui,
        Size = UDim2.new(0, sizeW, 0, sizeH),
        Posicion = cfg.Posicion or UDim2.new(0.85, 0, 0.75, 0),
        Color = (mode == "Toggle" and state) and Theme.Accent or Theme.Panel,
        Transparencia = 0,
        Radio = 10,
    })
    btnFrame.Name = "LouisHub_FloatingActionButton"
    btnFrame.Visible = visible
    btnFrame.ZIndex = 450
    Instance.new("UIStroke", btnFrame).Color = Theme.Accent
    btnFrame.UIStroke.Thickness = 1.4

    local lbl = Instance.new("TextLabel", btnFrame)
    lbl.Size = UDim2.new(1, -8, 1, -4)
    lbl.Position = UDim2.new(0, 4, 0, 2)
    lbl.BackgroundTransparency = 1
    lbl.Text = text
    lbl.TextColor3 = Theme.Text
    lbl.Font = Enum.Font.FredokaOne
    lbl.TextScaled = true
    local constraint = Instance.new("UITextSizeConstraint", lbl)
    constraint.MaxTextSize = 14
    constraint.MinTextSize = 8

    Utils.Arrastrable(btnFrame, btnFrame, LouisHub.EventManager)

    local function triggerAction()
        if mode == "Toggle" then
            state = not state
            Utils.Tween(btnFrame, { BackgroundColor3 = state and Theme.Accent or Theme.Panel }, LouisHub.Motion.Hover)
            executeCallback(cfg.Callback, "FloatingButton", state)
        else
            Utils.ClickFeedback(btnFrame)
            executeCallback(cfg.Callback, "FloatingButton")
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

    local FloatingBtn = { Frame = btnFrame }
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
            executeCallback(cfg.Callback, "FloatingButton", state)
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
--  INTERACTION & EXPANDABLE MATH CONTROLLERS
-- ===================================================================

local function crearBarraArrastrable(cfg)
    local fondo = Utils.Frame({
        Padre = cfg.Padre, Size = cfg.Size, Posicion = cfg.Posicion,
        Color = Theme.Entrada, Radio = 4,
    })
    LouisHub:Registrar(fondo, "BackgroundColor3", "Entrada")

    local aroArrastre = Utils.Stroke(fondo, Theme.AccentLight, 2, 1)
    LouisHub:Registrar(aroArrastre, "Color", "AccentLight")

    local function marcarArrastre(activo)
        Utils.Tween(aroArrastre, { Transparency = activo and 0 or 1 }, LouisHub.Motion.Hover)
    end

    local relleno = Utils.Frame({
        Padre = fondo,
        Size = UDim2.new((cfg.Valor - cfg.Min) / (cfg.Max - cfg.Min), 0, 1, 0),
        Color = Theme.Accent, Radio = 4,
    })
    LouisHub:Registrar(relleno, "BackgroundColor3", "Accent")
    Utils.GradienteAcento(relleno, 0.35)

    if cfg.Pasos and cfg.Incremento and cfg.Incremento > 0 then
        local totalPasos = math.floor((cfg.Max - cfg.Min) / cfg.Incremento + 0.5)
        if totalPasos >= 2 and totalPasos <= 40 then
            for i = 1, totalPasos - 1 do
                local rel = i / totalPasos
                local marca = Utils.Frame({
                    Padre = fondo, Size = UDim2.new(0, 2, 1, 0),
                    Posicion = UDim2.new(rel, -1, 0, 0),
                    Color = Theme.Border, Transparencia = 0.35, Radio = false,
                })
                marca.ZIndex = 2
                LouisHub:Registrar(marca, "BackgroundColor3", "Border")
            end
        end
    end

    local function fijarVisual(valor)
        local rel = math.clamp((valor - cfg.Min) / (cfg.Max - cfg.Min), 0, 1)
        local dur = LouisHub.EventManager:HayArrastreActivo() and LouisHub.Motion.Directo or LouisHub.Motion.Page
        Utils.Tween(relleno, { Size = UDim2.new(rel, 0, 1, 0) }, dur, LouisHub.Motion.EaseEntrar, Enum.EasingDirection.Out)
    end

    local function calcularYAplicar(input)
        local rel = math.clamp((input.Position.X - fondo.AbsolutePosition.X) / fondo.AbsoluteSize.X, 0, 1)
        local v = cfg.Min + rel * (cfg.Max - cfg.Min)
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
            local decidido = false
            local esArrastre = false
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
    local fondo = Utils.Frame({
        Padre = cfg.Padre, Size = cfg.Size, Posicion = cfg.Posicion,
        Color = Theme.Entrada, Radio = 4,
    })
    LouisHub:Registrar(fondo, "BackgroundColor3", "Entrada")

    local function relX(v)
        return math.clamp((v - cfg.Min) / (cfg.Max - cfg.Min), 0, 1)
    end

    local relleno = Utils.Frame({
        Padre = fondo,
        Posicion = UDim2.new(relX(cfg.ValorMin), 0, 0, 0),
        Size = UDim2.new(relX(cfg.ValorMax) - relX(cfg.ValorMin), 0, 1, 0),
        Color = Theme.Accent, Radio = 4,
    })
    LouisHub:Registrar(relleno, "BackgroundColor3", "Accent")
    Utils.GradienteAcento(relleno, 0.35)

    local DIAMETRO_MANIJA = cfg.DiametroManija or 16
    local function crearManija()
        local m = Utils.Frame({
            Padre = fondo,
            Size = UDim2.new(0, DIAMETRO_MANIJA, 0, DIAMETRO_MANIJA),
            Ancla = Vector2.new(0.5, 0.5),
            Color = Theme.Highlight, Radio = 999,
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
        return cfg.Min + rel * (cfg.Max - cfg.Min)
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

-- [END OF PART 3 - PROCEED TO PART 4]

-- ===================================================================
--  LOUIS HUB UI LIBRARY (V3.0 CORE ENGINE)
--  Brand: Louis Hub
--  [PART 4 OF 5] - Window Core, Responsive Engine, Tabs & Controls (A)
-- ===================================================================

local indiceBusqueda = {}
local seccionesRegistradas = {}

local function registrarBuscable(fila, texto, visibleSi)
    table.insert(indiceBusqueda, { fila = fila, texto = (texto or ""):lower() })
    if type(visibleSi) == "function" and fila then
        registroVisibilidad[fila] = visibleSi
        fila.Visible = cumpleVisibilidadCondicional(fila)
    end
end

local function advertirDev(tipo, nombre, mensaje)
    warn(("[LouisHub] %s \"%s\": %s"):format(tipo, tostring(nombre or "?"), mensaje))
end

local function validarCallback(tipo, cfg)
    if cfg.Callback ~= nil and type(cfg.Callback) ~= "function" then
        advertirDev(tipo, cfg.Texto, "'Callback' must be a function. Value was ignored.")
        cfg.Callback = nil
    end
end

local function aplicarDesactivarSiCorresponde(cfg, v)
    if v == true and cfg.Desactivar then
        for _, otherFlag in ipairs(cfg.Desactivar) do
            local target = LouisHub.Elementos[otherFlag]
            if target and target.Get() == true then
                target.Set(false, true)
            end
        end
    end
end

local function anchoTexto(texto, tamano)
    return TextService:GetTextSize(texto or "", tamano or 11, Enum.Font.Ubuntu, Vector2.new(1000, 20)).X
end

-- ===================================================================
--  MAIN WINDOW GENERATOR (CREAR VENTANA)
-- ===================================================================
function LouisHub:CrearVentana(config)
    local ok, resultado = pcall(function()
        config = config or {}
        local titulo    = config.Titulo or "Louis Hub"
        local subtitulo = (config.Subtitulo or "by Louis Hub") .. "  •  Louis Hub v" .. LouisHub.Version
        local anchoX    = config.TamanoX or 560
        local anchoY    = config.TamanoY or 340
        local teclaUI   = config.TeclaToggle or Enum.KeyCode.RightControl

        pcall(cleanPreviousInstance)
        _G.LouisHub_InstanciaActiva = createInstanceRecord(titulo)

        local padreGui = getGuiParent()
        local viejo = padreGui:FindFirstChild("LouisHub_ScreenGui")
        if viejo then viejo:Destroy() end

        themeRegistry          = {}
        indiceBusqueda         = {}
        textScaleRegistry      = {}
        LouisHub.Elementos     = createElementsTable()
        _registeredKeybinds    = {}
        seccionesRegistradas   = {}
        for k in pairs(_realFlags) do _realFlags[k] = nil end
        _nonPersistentFlags    = {}
        _uiFlags               = {}
        pendingUnsavedChanges  = false
        LouisHub:LimpiarHistorial()
        activeSaveWindow       = nil
        autoSaveLoopRunning    = false
        contenedorNotif        = nil
        colaNotif              = {}
        notifActivas           = 0

        local sg = Instance.new("ScreenGui")
        sg.Name           = "LouisHub_ScreenGui"
        sg.ResetOnSpawn   = false
        sg.IgnoreGuiInset = true
        sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
        sg.Parent         = padreGui
        protectGuiObject(sg)

        crearContenedorNotif(sg)
        LouisHub._guiConfirmar = sg
        LouisHub._modalesAbiertos = 0

        local main = Utils.Frame({
            Padre = sg, Size = UDim2.new(0, 0, 0, 0),
            Posicion = UDim2.new(0.5, 0, 0.5, 0), Ancla = Vector2.new(0.5, 0.5),
            Color = Theme.Panel, Radio = 14, Recortar = true,
            Borde = true, ColorBorde = Theme.Border, GrosorBorde = 2, ClaveTemaBorde = "Border",
        })
        main.Active = true
        LouisHub:Registrar(main, "BackgroundColor3", "Panel")

        local sombraPantalla = Utils.Frame({
            Padre = sg, Size = UDim2.new(1, 0, 1, 0), Posicion = UDim2.new(0, 0, 0, 0),
            Color = Color3.new(0, 0, 0), Transparencia = 1, Radio = false,
        })
        sombraPantalla.ZIndex = -10
        Utils.Tween(sombraPantalla, {BackgroundTransparency = 0.95}, LouisHub.Motion.Modal, LouisHub.Motion.EaseEntrar, Enum.EasingDirection.Out)
        LouisHub:RegistrarConexion(main:GetPropertyChangedSignal("Visible"):Connect(function()
            sombraPantalla.Visible = main.Visible
        end))

        local POSICION_ORIGINAL_VENTANA = UDim2.new(0.5, 0, 0.5, 0)
        local duracionApertura = LouisHub.Motion.Modal
        local tweenApertura = Utils.Tween(main, {
            Size     = UDim2.new(0, anchoX, 0, anchoY),
            Position = POSICION_ORIGINAL_VENTANA,
        }, duracionApertura, LouisHub.Motion.EasePop, Enum.EasingDirection.Out)

        sg.Destroying:Connect(function()
            if tweenApertura then pcall(function() tweenApertura:Cancel() end) end
            pcall(cerrarTooltipGlobal)
        end)

        -- Atmospheric Loading Splash Screen
        local ventanaRevelada = false
        LouisHub._ventanaRevelada = false

        local splash = Utils.Frame({
            Padre = sg, Color = Theme.Panel, Radio = 10,
            Size = UDim2.new(2, 0, 2, 0), Posicion = UDim2.new(0.5, 0, 0.5, 0), Ancla = Vector2.new(0.5, 0.5),
        })
        splash.ZIndex = 2000
        splash.Active = true
        LouisHub:Registrar(splash, "BackgroundColor3", "Panel")

        local logoImagen = Instance.new("ImageLabel")
        logoImagen.BackgroundTransparency = 1
        logoImagen.Image = "rbxassetid://123994745552712"
        logoImagen.ScaleType = Enum.ScaleType.Fit
        logoImagen.Size = UDim2.new(0, 64, 0, 64)
        logoImagen.Position = UDim2.new(0.5, -32, 0.5, -100)
        logoImagen.Parent = splash

        Utils.Texto({
            Padre = splash, Texto = "Louis Hub",
            Size = UDim2.new(1, 0, 0, 28), Posicion = UDim2.new(0, 0, 0.5, -28),
            Alineacion = Enum.TextXAlignment.Center, Fuente = Enum.Font.FredokaOne,
            Tamano = 22, Color = Theme.AccentLight,
        })
        local lblCreditoSplash = Utils.Texto({
            Padre = splash, Texto = subtitulo,
            Size = UDim2.new(1, 0, 0, 16), Posicion = UDim2.new(0, 0, 0.5, 2),
            Alineacion = Enum.TextXAlignment.Center, Tamano = 12,
            Color = Theme.TextDark, TextoTransparencia = 0.3,
        })
        LouisHub:Registrar(lblCreditoSplash, "TextColor3", "TextDark")

        local barraSplashFondo = Utils.Frame({
            Padre = splash, Color = Theme.Entrada, Radio = 4,
            Size = UDim2.new(0, 180, 0, 6), Posicion = UDim2.new(0.5, -90, 0.5, 34),
        })
        LouisHub:Registrar(barraSplashFondo, "BackgroundColor3", "Entrada")
        local barraSplashRelleno = Utils.Frame({
            Padre = barraSplashFondo, Color = Theme.Accent, Radio = 4, Size = UDim2.new(0, 0, 1, 0),
        })
        LouisHub:Registrar(barraSplashRelleno, "BackgroundColor3", "Accent")
        Utils.GradienteAcento(barraSplashRelleno)
        Utils.FundirEntrada(splash, LouisHub.Motion.Modal, true)

        LouisHub:RegistrarHilo(task.spawn(function()
            local okS, errS = pcall(function()
                for _ = 1, 3 do
                    if not (splash and splash.Parent) then return end
                    RunService.Heartbeat:Wait()
                end
                local totalControles = #indiceBusqueda
                local dur = math.clamp(0.35 + totalControles * 0.008, 0.35, 1.0)
                Utils.Tween(barraSplashRelleno, {Size = UDim2.new(1, 0, 1, 0)}, dur, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
                task.wait(dur)
                if not (splash and splash.Parent) then return end
                ventanaRevelada = true
                LouisHub._ventanaRevelada = true
                local tSplash = Utils.Tween(splash, {Position = UDim2.new(0.5, 0, -1.5, 0)}, LouisHub.Motion.Modal, LouisHub.Motion.EaseSalir, Enum.EasingDirection.In)
                tSplash.Completed:Connect(function()
                    pcall(function() if splash and splash.Parent then splash:Destroy() end end)
                end)
            end)
            if not okS then
                ventanaRevelada = true
                LouisHub._ventanaRevelada = true
                LouisHub:_RegistrarError("Splash", errS)
                pcall(function() if splash and splash.Parent then splash:Destroy() end end)
            end
        end))

        -- Responsive Dynamic Scaling Engine
        local escalaUI = Instance.new("UIScale", main)
        escalaUI.Scale = 1
        local escalaManual = 1
        local anchoXBase, anchoYBase = anchoX, anchoY
        local factorAncho, factorAlto = 1, 1

        local function actualizarTamanoVentana()
            local dur = LouisHub.EventManager:HayArrastreActivo() and LouisHub.Motion.Directo or LouisHub.Motion.Page
            Utils.Tween(main, {
                Size = UDim2.new(0, anchoXBase * factorAncho, 0, anchoYBase * factorAlto),
                Position = UDim2.new(0.5, 0, 0.5, 0),
            }, dur, LouisHub.Motion.EaseEntrar, Enum.EasingDirection.Out)
        end

        local function recalcularEscala()
            local cam = Workspace.CurrentCamera
            if not cam then return end
            local tam = cam.ViewportSize
            if tam.X <= 0 or tam.Y <= 0 then return end
            local esMovil = tam.X < 700 or tam.Y < 500
            local pctAncho = esMovil and 0.94 or 0.75
            local pctAlto  = esMovil and 0.82 or 0.75
            local escalaAuto = math.clamp(math.min((tam.X * pctAncho) / (anchoXBase * factorAncho), (tam.Y * pctAlto) / (anchoYBase * factorAlto)), 0.45, 1.15)
            local lim = math.min((tam.X * 0.98) / (anchoXBase * factorAncho), (tam.Y * 0.88) / (anchoYBase * factorAlto))
            local fin = math.max(0.3, math.min(escalaAuto * escalaManual, lim))
            local dur = LouisHub.EventManager:HayArrastreActivo() and LouisHub.Motion.Directo or LouisHub.Motion.Page
            Utils.Tween(escalaUI, {Scale = fin}, dur, LouisHub.Motion.EaseEntrar, Enum.EasingDirection.Out)
        end
        recalcularEscala()

        local connCam
        local function attachCamera()
            if connCam then LouisHub:DesconectarYLimpiar(connCam); connCam = nil end
            local cur = Workspace.CurrentCamera
            if cur then
                connCam = LouisHub:RegistrarConexion(cur:GetPropertyChangedSignal("ViewportSize"):Connect(recalcularEscala))
            end
        end
        attachCamera()
        LouisHub:RegistrarConexion(Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            attachCamera(); recalcularEscala()
        end))

        -- Rayfield-style Floating Pill Minimizer
        local textoPill = "🔧 " .. titulo
        local anchoPill = math.clamp(anchoTexto(textoPill, 12) + 42, 120, 280)

        local pillRestaurar = Utils.BotonBase({
            Padre = sg, Size = UDim2.new(0, anchoPill, 0, 30),
            Posicion = UDim2.new(0.5, 0, 0, 29), Ancla = Vector2.new(0.5, 0.5),
            Color = Theme.Panel, Transparencia = 0, Radio = 15,
        })
        pillRestaurar.Visible = false
        pillRestaurar.ZIndex  = 50
        pillRestaurar.Active  = true
        LouisHub:Registrar(pillRestaurar, "BackgroundColor3", "Panel")
        local strokePill = Utils.Stroke(pillRestaurar, Theme.Accent, 1, 0.3)
        LouisHub:Registrar(strokePill, "Color", "Accent")

        Utils.Texto({
            Padre = pillRestaurar, Texto = textoPill,
            Size = UDim2.new(1, -12, 1, 0), Posicion = UDim2.new(0, 6, 0, 0),
            Alineacion = Enum.TextXAlignment.Center, Truncar = true,
            Fuente = Enum.Font.FredokaOne, Tamano = 12,
        })

        local ventanaAbierta = true
        local animandoVentana = false
        local idOperacionVentana = 0

        local function alternarVentana(abrir)
            if animandoVentana or abrir == ventanaAbierta then return end
            animandoVentana = true
            ventanaAbierta = abrir
            idOperacionVentana = idOperacionVentana + 1
            local curOp = idOperacionVentana

            if abrir then
                local tSize = UDim2.new(0, anchoXBase * factorAncho, 0, anchoYBase * factorAlto)
                Utils.Tween(pillRestaurar, {Size = UDim2.new(0, 0, 0, 0)}, LouisHub.Motion.Expand, LouisHub.Motion.EaseSalir, Enum.EasingDirection.In)
                main.Visible = true
                main.Size = UDim2.new(0, 0, 0, 0)
                main.Position = POSICION_ORIGINAL_VENTANA
                Utils.Tween(main, {Size = tSize}, LouisHub.Motion.Modal, LouisHub.Motion.EasePop, Enum.EasingDirection.Out)
                task.spawn(function()
                    task.wait(LouisHub.Motion.Expand)
                    if idOperacionVentana == curOp then
                        pillRestaurar.Visible = false
                        pillRestaurar.Size = UDim2.new(0, anchoPill, 0, 30)
                    end
                    task.wait(math.max(0, LouisHub.Motion.Modal - LouisHub.Motion.Expand))
                    if idOperacionVentana == curOp then
                        main.Size = tSize
                        animandoVentana = false
                    end
                end)
            else
                Utils.Tween(main, {Size = UDim2.new(0, 0, 0, 0)}, LouisHub.Motion.Expand, LouisHub.Motion.EaseSalir, Enum.EasingDirection.In)
                task.spawn(function()
                    task.wait(LouisHub.Motion.Expand + 0.04)
                    if idOperacionVentana ~= curOp then return end
                    main.Visible = false
                    pillRestaurar.Size = UDim2.new(0, 0, 0, 0)
                    pillRestaurar.Visible = true
                    Utils.Tween(pillRestaurar, {Size = UDim2.new(0, anchoPill, 0, 30)}, LouisHub.Motion.Modal, LouisHub.Motion.EasePop, Enum.EasingDirection.Out)
                    task.wait(LouisHub.Motion.Modal + 0.01)
                    if idOperacionVentana == curOp then
                        pillRestaurar.Size = UDim2.new(0, anchoPill, 0, 30)
                        animandoVentana = false
                    end
                end)
            end
        end

        pillRestaurar.MouseButton1Click:Connect(function() alternarVentana(true) end)

        -- Window Header & Controls
        local barraTitulo = Utils.Frame({
            Padre = main, Size = UDim2.new(1, 0, 0, 34), Color = Theme.Background, Radio = 10,
        })
        barraTitulo.Active = true
        LouisHub:Registrar(barraTitulo, "BackgroundColor3", "Background")

        local tapa = Utils.Frame({
            Padre = barraTitulo, Size = UDim2.new(1, 0, 0, 10), Posicion = UDim2.new(0, 0, 1, -10),
            Color = Theme.Background, Radio = false,
        })
        LouisHub:Registrar(tapa, "BackgroundColor3", "Background")

        local lineaAcento = Utils.Frame({
            Padre = main, Size = UDim2.new(1, -24, 0, 2), Posicion = UDim2.new(0, 12, 0, 33),
            Color = Theme.Accent, Radio = false,
        })
        lineaAcento.ZIndex = barraTitulo.ZIndex + 2
        LouisHub:Registrar(lineaAcento, "BackgroundColor3", "Accent")

        Utils.Arrastrable(barraTitulo, main, LouisHub.EventManager)

        local lblTitulo = Utils.Texto({
            Padre = barraTitulo, Texto = titulo, Posicion = UDim2.new(0, 12, 0, 2),
            Size = UDim2.new(0.6, 0, 0, 18), Fuente = Enum.Font.FredokaOne, Tamano = 15,
            Color = Theme.TextDark, Categoria = "titulo", Truncar = true,
        })
        LouisHub:Registrar(lblTitulo, "TextColor3", "TextDark")

        local lblSub = Utils.Texto({
            Padre = barraTitulo, Texto = subtitulo, Posicion = UDim2.new(0, 12, 0, 19),
            Size = UDim2.new(0.6, 0, 0, 13), Tamano = 11, Color = Theme.TextDark,
            TextoTransparencia = 0.22, Categoria = "titulo", Truncar = true,
        })
        LouisHub:Registrar(lblSub, "TextColor3", "TextDark")

        local function mostrarConfirmacionDestruir()
            LouisHub:Confirmar({
                Titulo = "⚠️ Destroy Interface?",
                Contenido = "This will completely close the GUI and clear active bindings.",
                Icono = "⚠️",
                Botones = {
                    { Texto = "Cancel", Variante = "neutral" },
                    {
                        Texto = "Destroy", Variante = "danger",
                        Callback = function()
                            themeRegistry = {}; indiceBusqueda = {}; textScaleRegistry = {};
                            LouisHub.Elementos = createElementsTable(); _registeredKeybinds = {}; seccionesRegistradas = {};
                            sg:Destroy()
                        end
                    }
                }
            })
        end

        local btnCerrar = Utils.BotonBase({
            Padre = barraTitulo, Size = UDim2.new(0, 32, 0, 26),
            Posicion = UDim2.new(1, -20, 0, 17), Ancla = Vector2.new(0.5, 0.5),
            Color = Color3.fromRGB(200, 60, 60), Transparencia = 1, Radio = 6,
        })
        local icoCerrar = Utils.Texto({
            Padre = btnCerrar, Texto = "❌", Size = UDim2.new(1, 0, 1, 0),
            Alineacion = Enum.TextXAlignment.Center, Categoria = "titulo", Tamano = 15,
        })
        icoCerrar.TextYAlignment = Enum.TextYAlignment.Center
        Utils.ClickConfiable(btnCerrar, mostrarConfirmacionDestruir)

        local btnMin = Utils.BotonBase({
            Padre = barraTitulo, Size = UDim2.new(0, 32, 0, 26),
            Posicion = UDim2.new(1, -62, 0, 17), Ancla = Vector2.new(0.5, 0.5),
            Color = Theme.BackgroundDark, Transparencia = 1, Radio = 6,
        })
        Utils.Texto({
            Padre = btnMin, Texto = "—", Size = UDim2.new(1, 0, 1, 0),
            Alineacion = Enum.TextXAlignment.Center, Fuente = Enum.Font.FredokaOne,
            Tamano = 16, Color = Theme.TextDark, Categoria = "titulo",
        })
        Utils.ClickConfiable(btnMin, function() alternarVentana(false) end)

        local modoHorizontal = config.Orientacion == "horizontal"
        local barraLat = Instance.new("ScrollingFrame")
        barraLat.Size                = UDim2.new(0, 150, 1, -34)
        barraLat.Position            = UDim2.new(0, 0, 0, 34)
        barraLat.BackgroundColor3    = Theme.PanelClaro
        barraLat.BorderSizePixel     = 0
        barraLat.Visible             = not modoHorizontal
        barraLat.ScrollingDirection  = Enum.ScrollingDirection.Y
        barraLat.CanvasSize          = UDim2.new(0, 0, 0, 0)
        barraLat.AutomaticCanvasSize = Enum.AutomaticSize.Y
        barraLat.ScrollBarThickness  = 3
        barraLat.ScrollBarImageColor3= Theme.Accent
        barraLat.Parent              = main
        LouisHub:Registrar(barraLat, "BackgroundColor3", "PanelClaro")

        local layoutTabs = Instance.new("UIListLayout", barraLat)
        layoutTabs.Padding = UDim.new(0, 4)
        layoutTabs.SortOrder = Enum.SortOrder.LayoutOrder

        local padTabs = Instance.new("UIPadding", barraLat)
        padTabs.PaddingTop = UDim.new(0, 8); padTabs.PaddingLeft = UDim.new(0, 6); padTabs.PaddingRight = UDim.new(0, 6)

        local barraHoriz = Instance.new("ScrollingFrame")
        barraHoriz.Size                = UDim2.new(1, 0, 0, 36)
        barraHoriz.Position            = UDim2.new(0, 0, 0, 34)
        barraHoriz.BackgroundColor3    = Theme.PanelClaro
        barraHoriz.BorderSizePixel     = 0
        barraHoriz.Visible             = modoHorizontal
        barraHoriz.ScrollingDirection  = Enum.ScrollingDirection.X
        barraHoriz.CanvasSize          = UDim2.new(0, 0, 0, 0)
        barraHoriz.AutomaticCanvasSize = Enum.AutomaticSize.X
        barraHoriz.ScrollBarThickness  = 3
        barraHoriz.ScrollBarImageColor3= Theme.Accent
        barraHoriz.Parent              = main
        LouisHub:Registrar(barraHoriz, "BackgroundColor3", "PanelClaro")

        local layoutHoriz = Instance.new("UIListLayout", barraHoriz)
        layoutHoriz.FillDirection = Enum.FillDirection.Horizontal
        layoutHoriz.Padding = UDim.new(0, 4)
        layoutHoriz.SortOrder = Enum.SortOrder.LayoutOrder
        layoutHoriz.VerticalAlignment = Enum.VerticalAlignment.Center

        local padHoriz = Instance.new("UIPadding", barraHoriz)
        padHoriz.PaddingLeft = UDim.new(0, 8); padHoriz.PaddingRight = UDim.new(0, 8)
        padHoriz.PaddingTop = UDim.new(0, 4); padHoriz.PaddingBottom = UDim.new(0, 4)

        local function getPosContainer()
            if modoHorizontal then
                return UDim2.new(0, 0, 0, 70), UDim2.new(1, 0, 1, -70)
            else
                return UDim2.new(0, 150, 0, 34), UDim2.new(1, -150, 1, -34)
            end
        end

        local posP, sizeP = getPosContainer()
        local contenedorPaginas = Utils.Frame({
            Padre = main, Size = sizeP, Posicion = posP, Transparencia = 1, Radio = false,
        })

        LouisHub:RegistrarConexion(UserInputService.InputBegan:Connect(function(input, gpe)
            if not gpe and input.KeyCode == teclaUI then alternarVentana(not ventanaAbierta) end
        end))

        local Ventana = { Tabs = {}, NombreConfig = config.NombreConfig or "default", _main = main }
        activeSaveWindow = Ventana
        local ordenTab, primeraTab = 0, true

        -- Global Debounced Search Engine
        local function filtrarBusqueda(texto)
            texto = (texto or ""):lower()
            local buscandoActivo = texto ~= ""

            for _, entrada in ipairs(seccionesRegistradas) do
                if entrada.colapsable then
                    if buscandoActivo then
                        if entrada.colapsadaAntesDeBuscar == nil then
                            entrada.colapsadaAntesDeBuscar = entrada.colapsada
                        end
                        if entrada.colapsada then entrada.AplicarColapsada(false) end
                    else
                        if entrada.colapsadaAntesDeBuscar ~= nil then
                            entrada.AplicarColapsada(entrada.colapsadaAntesDeBuscar)
                            entrada.colapsadaAntesDeBuscar = nil
                        end
                    end
                end
            end

            for _, entrada in ipairs(indiceBusqueda) do
                local coincide = (texto == "") or (entrada.texto:find(texto, 1, true) ~= nil)
                entrada.fila.Visible = coincide and cumpleVisibilidadCondicional(entrada.fila)
            end

            local primerTabMatch = nil
            for _, t in ipairs(Ventana.Tabs) do
                local tabMatch = false
                for _, s in ipairs(t.Secciones) do
                    local secMatch = false
                    for _, child in ipairs(s.contenedor:GetChildren()) do
                        if child:IsA("GuiObject") and child.Visible then secMatch = true; break end
                    end
                    s.marco.Visible = (texto == "") or secMatch
                    if secMatch then tabMatch = true end
                end
                if texto ~= "" and tabMatch and not primerTabMatch then primerTabMatch = t end
            end

            if texto ~= "" and primerTabMatch and not primerTabMatch.Pagina.Visible then
                primerTabMatch.Seleccionar()
            end
        end

        function Ventana:Buscar(txt) return filtrarBusqueda(txt) end

        if config.Buscador ~= false then
            local busquedaId = 0
            local function connectSearch(caja)
                caja:GetPropertyChangedSignal("Text"):Connect(function()
                    busquedaId = busquedaId + 1
                    local curId = busquedaId
                    local text = caja.Text
                    task.delay(LouisHub.Motion.Hover, function()
                        if curId == busquedaId then filtrarBusqueda(text) end
                    end)
                end)
            end

            local function makeSearchBox()
                local b = Instance.new("TextBox")
                b.BackgroundColor3 = Theme.Entrada
                b.PlaceholderText  = "🔍 Search..."
                b.Text             = ""
                b.TextColor3       = Theme.Text
                b.Font             = Enum.Font.Ubuntu
                b.TextSize         = 11
                b.ClearTextOnFocus = false
                b.BorderSizePixel  = 0
                Utils.Corner(b, 5)
                LouisHub:Registrar(b, "BackgroundColor3", "Entrada")
                LouisHub:Registrar(b, "TextColor3", "Text")
                connectSearch(b)
                return b
            end

            local bBoxV = makeSearchBox()
            bBoxV.Size = UDim2.new(1, 0, 0, 22)
            bBoxV.LayoutOrder = 0
            bBoxV.Parent = barraLat

            local bBoxH = makeSearchBox()
            bBoxH.Size = UDim2.new(0, 150, 0, 26)
            bBoxH.Position = UDim2.new(1, -158, 0, 39)
            bBoxH.ZIndex = 10
            bBoxH.Visible = modoHorizontal
            bBoxH.Parent = main
            Ventana._buscadorBoxHoriz = bBoxH
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
                Color = Theme.Fila, Transparencia = 0, Orden = 9999, Radio = 8,
            })
            LouisHub:Registrar(btn, "BackgroundColor3", "Fila")
            Utils.Hover(btn, btn)
            local lbl = Utils.Texto({
                Padre = btn, Texto = "🎨 " .. nombres[idx], Tamano = 11, Alineacion = Enum.TextXAlignment.Center,
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
            _registeredThemeWindows[self] = true
            return btn
        end

        local contenedorTags
        local tagsLista = {}
        local anchosTags = {}
        local COLORES_TAG = {
            info = Color3.fromRGB(70, 130, 210), warning = Color3.fromRGB(215, 160, 50),
            success = Color3.fromRGB(70, 170, 100), danger = Color3.fromRGB(190, 60, 60),
            neutral = Color3.fromRGB(95, 100, 110),
        }

        function Ventana:AgregarTag(cfg)
            if type(cfg) == "string" then cfg = { Texto = cfg } end
            cfg = cfg or {}
            if not contenedorTags then
                contenedorTags = Utils.Frame({
                    Padre = barraTitulo, Size = UDim2.new(0.5, 0, 0, 18),
                    Posicion = UDim2.new(1, -86, 0, 17), Ancla = Vector2.new(1, 0.5),
                    Transparencia = 1, Radio = false,
                })
                contenedorTags.ClipsDescendants = true
                lblTitulo.Size = UDim2.new(0.42, 0, 0, 18)
                lblSub.Size = UDim2.new(0.42, 0, 0, 13)
                local lTags = Instance.new("UIListLayout", contenedorTags)
                lTags.FillDirection = Enum.FillDirection.Horizontal
                lTags.HorizontalAlignment = Enum.HorizontalAlignment.Right
                lTags.VerticalAlignment = Enum.VerticalAlignment.Center
                lTags.Padding = UDim.new(0, 4)
            end

            local pastilla = Utils.Frame({
                Padre = contenedorTags, Size = UDim2.new(0, 0, 0, 16),
                Color = COLORES_TAG.info, Orden = #contenedorTags:GetChildren(), Radio = 8,
            })
            pastilla.AutomaticSize = Enum.AutomaticSize.X
            local relPad = Instance.new("UIPadding", pastilla)
            relPad.PaddingLeft, relPad.PaddingRight = UDim.new(0, 7), UDim.new(0, 7)
            table.insert(tagsLista, pastilla)

            local lblTag = Utils.Texto({
                Padre = pastilla, Texto = tostring(cfg.Texto or "TAG"),
                Size = UDim2.new(0, 0, 1, 0), Fuente = Enum.Font.FredokaOne,
                Tamano = 10, Color = Color3.fromRGB(255, 255, 255), Categoria = "titulo",
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
                Remover = function() pastilla:Destroy() end
            }
        end

        function Ventana:AgregarDivisorSidebar(cfg)
            cfg = cfg or {}
            ordenTab = ordenTab + 1
            local marcoLat = Utils.Frame({
                Padre = barraLat, Size = UDim2.new(1, 0, 0, cfg.Texto and 22 or 9),
                Transparencia = 1, Orden = ordenTab, Radio = false,
            })
            if cfg.Texto then
                Utils.Texto({
                    Padre = marcoLat, Texto = tostring(cfg.Texto), Size = UDim2.new(1, -8, 1, -4),
                    Posicion = UDim2.new(0, 4, 0, 0), Fuente = Enum.Font.FredokaOne, Tamano = 10,
                    ColorTema = "TextDark", Categoria = "tabs", Truncar = true,
                })
            end
            local line = Utils.Frame({
                Padre = marcoLat, Size = UDim2.new(1, -8, 0, 1), Posicion = UDim2.new(0, 4, 1, -2),
                Color = Theme.Border, Transparencia = 0.4, Radio = false,
            })
            LouisHub:Registrar(line, "BackgroundColor3", "Border")
            return { InstanciaLat = marcoLat }
        end

        -- Tab Builder (CrearTab)
        function Ventana:CrearTab(nombre, icono)
            nombre = nombre or "Tab"
            icono = icono or "▪"
            ordenTab = ordenTab + 1

            local botonLat = Utils.BotonBase({
                Padre = barraLat, Size = UDim2.new(1, 0, 0, 30),
                Color = Theme.Fila, Transparencia = 0, Orden = ordenTab, Radio = 8,
            })
            local hbLat = Utils.HitboxAmpliado(botonLat, 7)
            Utils.Hover(hbLat, botonLat)
            LouisHub:Registrar(botonLat, "BackgroundColor3", "Fila")

            local indLat = Utils.Frame({
                Padre = botonLat, Size = UDim2.new(0, 3, 1, -8), Posicion = UDim2.new(0, 0, 0, 4),
                Color = Theme.Accent, Radio = 2,
            })
            indLat.BackgroundTransparency = 1
            LouisHub:Registrar(indLat, "BackgroundColor3", "Accent")

            Utils.Texto({
                Padre = botonLat, Texto = icono, Size = UDim2.new(0, 26, 1, 0),
                Posicion = UDim2.new(0, 4, 0, 0), Tamano = 13, Alineacion = Enum.TextXAlignment.Center,
                Categoria = "tabs", Truncar = true,
            })
            Utils.Texto({
                Padre = botonLat, Texto = nombre, Size = UDim2.new(1, -36, 1, 0),
                Posicion = UDim2.new(0, 34, 0, 0), Fuente = Enum.Font.Ubuntu, Tamano = 12,
                Categoria = "tabs", Truncar = true,
            })

            local botonHoriz = Utils.BotonBase({
                Padre = barraHoriz, Size = UDim2.new(0, 100, 0, 28),
                Color = Theme.Fila, Transparencia = 0, Orden = ordenTab, Radio = 8,
            })
            botonHoriz.AutomaticSize = Enum.AutomaticSize.X
            local hbHoriz = Utils.HitboxAmpliado(botonHoriz, 7)
            Utils.Hover(hbHoriz, botonHoriz)
            LouisHub:Registrar(botonHoriz, "BackgroundColor3", "Fila")

            local indHoriz = Utils.Frame({
                Padre = botonHoriz, Size = UDim2.new(1, -8, 0, 2), Posicion = UDim2.new(0, 4, 1, -3),
                Color = Theme.Accent, Radio = 1,
            })
            indHoriz.BackgroundTransparency = 1
            LouisHub:Registrar(indHoriz, "BackgroundColor3", "Accent")

            Utils.Texto({
                Padre = botonHoriz, Texto = icono .. "  " .. nombre, Size = UDim2.new(1, -16, 1, 0),
                Posicion = UDim2.new(0, 8, 0, 0), Tamano = 11, Fuente = Enum.Font.Ubuntu,
                Categoria = "tabs",
            })

            local pagina = Instance.new("ScrollingFrame")
            pagina.Size                = UDim2.new(1, 0, 1, 0)
            pagina.BackgroundTransparency = 1
            pagina.BorderSizePixel     = 0
            pagina.ScrollBarThickness  = 4
            pagina.ScrollBarImageColor3= Theme.Accent
            pagina.CanvasSize          = UDim2.new(0, 0, 0, 0)
            pagina.AutomaticCanvasSize = Enum.AutomaticSize.Y
            pagina.Visible             = primeraTab
            pagina.Parent              = contenedorPaginas

            local layoutPag = Instance.new("UIListLayout", pagina)
            layoutPag.Padding = UDim.new(0, 14)
            layoutPag.SortOrder = Enum.SortOrder.LayoutOrder

            local padPag = Instance.new("UIPadding", pagina)
            padPag.PaddingTop = UDim.new(0, 12); padPag.PaddingBottom = UDim.new(0, 12)
            padPag.PaddingLeft = UDim.new(0, 12); padPag.PaddingRight = UDim.new(0, 12)

            if primeraTab then
                indLat.BackgroundTransparency   = 0
                indHoriz.BackgroundTransparency = 0
            end
            primeraTab = false

            local function seleccionar()
                for _, t in ipairs(Ventana.Tabs) do
                    t.Pagina.Visible = false
                    Utils.Tween(t.IndicadorLat, {BackgroundTransparency = 1}, LouisHub.Motion.Hover)
                    Utils.Tween(t.IndicadorHoriz, {BackgroundTransparency = 1}, LouisHub.Motion.Hover)
                end
                pagina.Position = UDim2.new(0, 0, 0, 14)
                pagina.Visible = true
                Utils.Tween(pagina, {Position = UDim2.new(0, 0, 0, 0)}, LouisHub.Motion.Page)
                Utils.Tween(indLat, {BackgroundTransparency = 0}, LouisHub.Motion.Hover)
                Utils.Tween(indHoriz, {BackgroundTransparency = 0}, LouisHub.Motion.Hover)
                LouisHub.Eventos.TabCambiada:Fire(nombre)
            end

            Utils.ClickConfiable(hbLat, seleccionar, botonLat)
            Utils.ClickConfiable(hbHoriz, seleccionar, botonHoriz)

            local Tab = {
                Nombre = nombre, Boton = botonLat, BotonLat = botonLat, BotonHoriz = botonHoriz,
                IndicadorLat = indLat, IndicadorHoriz = indHoriz, Pagina = pagina,
                Seleccionar = seleccionar, Secciones = {}
            }
            table.insert(Ventana.Tabs, Tab)

            local ordenSeccion = 0

            function Tab:CrearDivisor(cfg)
                cfg = cfg or {}
                ordenSeccion = ordenSeccion + 1
                local marcoDiv = Utils.Frame({
                    Padre = pagina, Size = UDim2.new(1, 0, 0, cfg.Texto and 28 or 10),
                    Transparencia = 1, Orden = ordenSeccion, Radio = false,
                })
                if cfg.Texto then
                    Utils.Texto({
                        Padre = marcoDiv, Texto = tostring(cfg.Texto), Size = UDim2.new(1, -24, 1, -6),
                        Posicion = UDim2.new(0, 12, 0, 0), Fuente = Enum.Font.FredokaOne, Tamano = 12,
                        ColorTema = "TextDark",
                    })
                end
                local line = Utils.Frame({
                    Padre = marcoDiv, Size = UDim2.new(1, -24, 0, 1), Posicion = UDim2.new(0, 12, 1, -2),
                    Color = Theme.Border, Transparencia = 0.4, Radio = false,
                })
                LouisHub:Registrar(line, "BackgroundColor3", "Border")
                return { Instancia = marcoDiv }
            end

            function Tab:CrearSeccion(nombreSec, cfgSec)
                cfgSec = cfgSec or {}
                ordenSeccion = ordenSeccion + 1
                local colapsable = cfgSec.Colapsable ~= false
                local colapsadaPorDefecto = colapsable and (cfgSec.ColapsadaPorDefecto == true)
                local ALTO_HEADER = 26

                local marco = Utils.Frame({
                    Padre = pagina, Size = UDim2.new(1, 0, 0, 0), Color = Theme.Panel,
                    Orden = ordenSeccion, Radio = 8, Borde = true, ColorBorde = Theme.Border,
                    TransparenciaBorde = 0.5, ClaveTemaBorde = "Border",
                })
                marco.AutomaticSize = Enum.AutomaticSize.Y
                LouisHub:Registrar(marco, "BackgroundColor3", "Panel")

                local flecha, btnHeader
                if colapsable then
                    btnHeader = Utils.BotonBase({
                        Padre = marco, Size = UDim2.new(1, 0, 0, ALTO_HEADER), Transparencia = 1, Radio = false,
                    })
                    Utils.Hover(btnHeader, marco, nil, nil, function() return Theme.Panel end)

                    flecha = Instance.new("ImageLabel", btnHeader)
                    flecha.BackgroundTransparency = 1
                    flecha.Image = "rbxassetid://83472139709682"
                    flecha.ImageColor3 = Theme.AccentLight
                    flecha.ScaleType = Enum.ScaleType.Fit
                    flecha.Size = UDim2.new(0, 14, 0, 14)
                    flecha.AnchorPoint = Vector2.new(0.5, 0.5)
                    flecha.Position = UDim2.new(0, 13, 0.5, 0)
                    flecha.Rotation = colapsadaPorDefecto and -90 or 0
                    LouisHub:Registrar(flecha, "ImageColor3", "AccentLight")

                    local lSec = Utils.Texto({
                        Padre = btnHeader, Texto = nombreSec or "Section", Size = UDim2.new(1, -28, 0, ALTO_HEADER),
                        Posicion = UDim2.new(0, 24, 0, 0), Fuente = Enum.Font.FredokaOne, Tamano = 12, Color = Theme.AccentLight,
                    })
                    LouisHub:Registrar(lSec, "TextColor3", "AccentLight")
                else
                    local lSec = Utils.Texto({
                        Padre = marco, Texto = nombreSec or "Section", Size = UDim2.new(1, -14, 0, 22),
                        Posicion = UDim2.new(0, 10, 0, 4), Fuente = Enum.Font.FredokaOne, Tamano = 12, Color = Theme.AccentLight,
                    })
                    LouisHub:Registrar(lSec, "TextColor3", "AccentLight")
                end

                local contenedor = Utils.Frame({
                    Padre = marco, Size = UDim2.new(1, 0, 0, 0), Posicion = UDim2.new(0, 0, 0, ALTO_HEADER),
                    Transparencia = 1, Radio = false,
                })
                contenedor.AutomaticSize = Enum.AutomaticSize.Y
                contenedor.Visible = not colapsadaPorDefecto

                local escalaCont = Instance.new("UIScale", contenedor)
                escalaCont.Scale = 1

                local layoutC = Instance.new("UIListLayout", contenedor)
                layoutC.Padding = UDim.new(0, 8)
                layoutC.SortOrder = Enum.SortOrder.LayoutOrder

                local padC = Instance.new("UIPadding", contenedor)
                padC.PaddingLeft = UDim.new(0, 10); padC.PaddingRight = UDim.new(0, 10)
                padC.PaddingTop = UDim.new(0, 8); padC.PaddingBottom = UDim.new(0, 10)

                local entradaSec = {
                    marco = marco, contenedor = contenedor, flecha = flecha,
                    colapsable = colapsable, colapsada = colapsadaPorDefecto, nombre = nombreSec
                }

                local function aplicarColapsada(v, animar)
                    entradaSec.colapsada = v
                    if entradaSec.flecha then
                        local targetRot = v and -90 or 0
                        if animar then Utils.Tween(entradaSec.flecha, {Rotation = targetRot}, LouisHub.Motion.Expand)
                        else entradaSec.flecha.Rotation = targetRot end
                    end
                    if not animar then
                        contenedor.Visible = not v
                        return
                    end
                    if v then
                        local curH = contenedor.AbsoluteSize.Y
                        contenedor.ClipsDescendants = true
                        contenedor.AutomaticSize = Enum.AutomaticSize.None
                        contenedor.Size = UDim2.new(1, 0, 0, curH)
                        Utils.Tween(contenedor, {Size = UDim2.new(1, 0, 0, 0)}, LouisHub.Motion.Expand, LouisHub.Motion.EaseSalir, Enum.EasingDirection.In)
                        task.delay(LouisHub.Motion.Expand, function()
                            if entradaSec.colapsada then contenedor.Visible = false end
                        end)
                    else
                        contenedor.AutomaticSize = Enum.AutomaticSize.Y
                        task.defer(function()
                            if entradaSec.colapsada then return end
                            local targetH = contenedor.AbsoluteSize.Y
                            contenedor.AutomaticSize = Enum.AutomaticSize.None
                            contenedor.Size = UDim2.new(1, 0, 0, 0)
                            contenedor.ClipsDescendants = true
                            contenedor.Visible = true
                            escalaCont.Scale = 0.92
                            Utils.Tween(escalaCont, {Scale = 1}, LouisHub.Motion.Expand, LouisHub.Motion.EaseEntrar, Enum.EasingDirection.Out)
                            Utils.Tween(contenedor, {Size = UDim2.new(1, 0, 0, targetH)}, LouisHub.Motion.Expand, LouisHub.Motion.EaseEntrar, Enum.EasingDirection.Out)
                            task.delay(LouisHub.Motion.Expand, function()
                                if not entradaSec.colapsada then
                                    contenedor.AutomaticSize = Enum.AutomaticSize.Y
                                    contenedor.ClipsDescendants = false
                                end
                            end)
                        end)
                    end
                end
                entradaSec.AplicarColapsada = aplicarColapsada

                if colapsable and btnHeader then
                    Utils.ClickConfiable(btnHeader, function()
                        aplicarColapsada(not entradaSec.colapsada, true)
                    end)
                end

                table.insert(Tab.Secciones, { marco = marco, contenedor = contenedor })
                table.insert(seccionesRegistradas, entradaSec)

                local Seccion = {}
                local ordenElem = 0
                local function nextOrder() ordenElem = ordenElem + 1; return ordenElem end

                local function crearCabecera(alto, txt, anchoLabel, offsetX, modo)
                    local fila = Utils.Fila(contenedor, alto, nextOrder(), Theme.Fila)
                    LouisHub:Registrar(fila, "BackgroundColor3", "Fila")
                    Utils.Hover(fila, fila)
                    if modo ~= "fijo" then
                        local lblD = Utils.Texto({ Padre = fila, Texto = txt, Size = UDim2.new(anchoLabel or 1, offsetX or -50, 1, 0), Tamano = 12, Ajustar = true })
                        if modo ~= "manual" then Utils.HacerFilaDinamica(fila, lblD, alto, 7) end
                        return fila, lblD
                    end
                    local lbl = Utils.Texto({ Padre = fila, Texto = txt, Size = UDim2.new(anchoLabel or 1, offsetX or -50, 1, 0), Tamano = 12, Truncar = true })
                    return fila, lbl
                end

                -- 1. BOTON
                function Seccion:Boton(cfg)
                    cfg = cfg or {}
                    validarCallback("Boton", cfg)
                    local fila = Utils.BotonBase({
                        Padre = contenedor, Size = UDim2.new(1, 0, 0, 32),
                        Color = Theme.Fila, Transparencia = 0, Orden = nextOrder(), Radio = 8,
                    })
                    LouisHub:Registrar(fila, "BackgroundColor3", "Fila")
                    Utils.Hover(fila, fila)

                    local fullText = (cfg.Icono and (cfg.Icono .. " ") or "") .. (cfg.Texto or "Button")
                    local lblBoton = Utils.Texto({ Padre = fila, Texto = fullText, RichText = cfg.RichText })
                    local lblInteract
                    if cfg.Interact ~= nil then
                        lblBoton.Size = UDim2.new(0.6, -12, 1, 0)
                        lblInteract = Utils.Texto({
                            Padre = fila, Texto = tostring(cfg.Interact), Size = UDim2.new(0.4, -10, 1, 0),
                            Posicion = UDim2.new(0.6, 0, 0, 0), Alineacion = Enum.TextXAlignment.Right,
                            Tamano = 12, Color = Theme.AccentLight, ColorTema = "AccentLight", Truncar = true,
                        })
                    end
                    agregarTooltipTexto(fila, cfg.Texto or "Button", cfg.Tooltip, lblBoton)
                    registrarBuscable(fila, cfg.Texto or "Button", cfg.VisibleSi)

                    local spinner
                    local function activarSpinner(act)
                        if act and not spinner then
                            spinner = Utils.Texto({
                                Padre = fila, Texto = "◐", Size = UDim2.new(0, 20, 1, 0),
                                Posicion = UDim2.new(1, -28, 0, 0), Alineacion = Enum.TextXAlignment.Center,
                                Tamano = 14, Color = Theme.AccentLight,
                            })
                            LouisHub:Registrar(spinner, "TextColor3", "AccentLight")
                        end
                        if spinner then
                            spinner.Visible = act
                            if act then
                                LouisHub:RegistrarHilo(task.spawn(function()
                                    while spinner and spinner.Visible do
                                        Utils.Tween(spinner, {Rotation = spinner.Rotation + 360}, LouisHub.Motion.Spin, LouisHub.Motion.EaseLineal)
                                        task.wait(LouisHub.Motion.Spin)
                                    end
                                end))
                            end
                        end
                    end

                    local enCurso = false
                    Utils.ClickConfiable(fila, function()
                        if cfg.Async and enCurso then return end
                        Utils.Tween(fila, {BackgroundColor3 = Theme.Accent}, LouisHub.Motion.FlashIn)
                        task.delay(0.1, function()
                            if fila and fila.Parent then Utils.Tween(fila, {BackgroundColor3 = Theme.Fila}, LouisHub.Motion.Expand) end
                        end)
                        if cfg.Callback then
                            if cfg.Async then
                                enCurso = true
                                activarSpinner(true)
                                task.spawn(function()
                                    executeCallback(cfg.Callback, cfg.Texto or "Button")
                                    enCurso = false
                                    if fila and fila.Parent then activarSpinner(false) end
                                end)
                            else
                                executeCallback(cfg.Callback, cfg.Texto or "Button")
                            end
                        end
                    end)

                    if lblInteract then
                        local proxy = Utils.EnvolverInstancia(fila)
                        rawset(proxy, "SetInteract", function(_, t) lblInteract.Text = tostring(t) end)
                        rawset(proxy, "GetInteract", function() return lblInteract.Text end)
                        return proxy
                    end
                    return fila
                end

                -- 2. TOGGLE
                function Seccion:Toggle(cfg)
                    cfg = cfg or {}
                    validarCallback("Toggle", cfg)
                    local flag = cfg.Flag or cfg.Texto or ("Toggle_" .. math.random(1e5, 1e6))
                    local val  = cfg.Defecto or false
                    LouisHub.Flags[flag] = val

                    local fila, lbl = crearCabecera(32, cfg.Texto or "Toggle")
                    agregarTooltipTexto(fila, cfg.Texto or "Toggle", cfg.Tooltip, lbl)
                    registrarBuscable(fila, cfg.Texto or "Toggle", cfg.VisibleSi)

                    local perilla = Utils.BotonBase({
                        Padre = fila, Size = UDim2.new(0, 44, 0, 22), Posicion = UDim2.new(1, -50, 0.5, -11),
                        Color = val and Theme.Accent or Theme.Apagado, Transparencia = 0, Radio = 11,
                    })
                    LouisHub:Registrar(perilla, "BackgroundColor3", function() return val and Theme.Accent or Theme.Apagado end)

                    local circulo = Utils.Frame({
                        Padre = perilla, Size = UDim2.new(0, 18, 0, 18),
                        Posicion = val and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9),
                        Color = Theme.Text, Radio = 9,
                    })
                    LouisHub:Registrar(circulo, "BackgroundColor3", "Text")

                    local function actualizar(v, disparar)
                        if type(v) ~= "boolean" then return end
                        val = v
                        LouisHub.Flags[flag] = v
                        Utils.Tween(perilla, {BackgroundColor3 = v and Theme.Accent or Theme.Apagado}, LouisHub.Motion.Expand)
                        Utils.Tween(circulo, {Position = v and UDim2.new(1, -20, 0.5, -9) or UDim2.new(0, 2, 0.5, -9)}, LouisHub.Motion.Page)
                        aplicarDesactivarSiCorresponde(cfg, v)
                        if disparar and cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, v) end
                    end

                    local hbToggle = Utils.HitboxAmpliado(perilla, 10)
                    Utils.ClickConfiable(hbToggle, function() actualizar(not val, true) end, perilla)

                    if cfg.Tecla then
                        LouisHub:RegistrarConexion(UserInputService.InputBegan:Connect(function(inp, gpe)
                            if not gpe and inp.KeyCode == cfg.Tecla then actualizar(not val, true) end
                        end))
                    end

                    LouisHub.Elementos[flag] = {
                        Set = function(v, d) actualizar(v, d or false) end,
                        Get = function() return val end,
                    }
                    if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, val) end
                    return {
                        Set = function(...) actualizar(normalizeSetArg(...), true) end,
                        Get = function() return val end,
                    }
                end

                -- 3. CASILLA (CHECKBOX)
                function Seccion:Casilla(cfg)
                    cfg = cfg or {}
                    validarCallback("Casilla", cfg)
                    local flag = cfg.Flag or cfg.Texto or ("Casilla_" .. math.random(1e5, 1e6))
                    local val  = cfg.Defecto or false
                    LouisHub.Flags[flag] = val

                    local fila, lbl = crearCabecera(32, cfg.Texto or "Casilla")
                    agregarTooltipTexto(fila, cfg.Texto or "Casilla", cfg.Tooltip, lbl)
                    registrarBuscable(fila, cfg.Texto or "Casilla", cfg.VisibleSi)

                    local caja = Utils.BotonBase({
                        Padre = fila, Size = UDim2.new(0, 22, 0, 22), Posicion = UDim2.new(1, -30, 0.5, -11),
                        Color = val and Theme.Accent or Theme.Entrada, Transparencia = 0, Radio = 5,
                    })
                    LouisHub:Registrar(caja, "BackgroundColor3", function() return val and Theme.Accent or Theme.Entrada end)
                    local strokeC = Utils.Stroke(caja, Theme.Border, 1, 0.3)
                    LouisHub:Registrar(strokeC, "Color", "Border")

                    local check = Utils.Frame({ Padre = caja, Size = UDim2.new(1, 0, 1, 0), Transparencia = 1 })
                    local tCorto = Utils.Frame({
                        Padre = check, Size = UDim2.new(0, 7, 0, 2), Posicion = UDim2.new(0.5, -7, 0.5, 1),
                        Color = Theme.Text, Transparencia = val and 0 or 1, Radio = 1,
                    })
                    tCorto.Rotation = 45
                    local tLargo = Utils.Frame({
                        Padre = check, Size = UDim2.new(0, 12, 0, 2), Posicion = UDim2.new(0.5, -3, 0.5, -4),
                        Color = Theme.Text, Transparencia = val and 0 or 1, Radio = 1,
                    })
                    tLargo.Rotation = -45
                    LouisHub:Registrar(tCorto, "BackgroundColor3", "Text")
                    LouisHub:Registrar(tLargo, "BackgroundColor3", "Text")

                    local function actualizar(v, disparar)
                        if type(v) ~= "boolean" then return end
                        val = v
                        LouisHub.Flags[flag] = v
                        Utils.Tween(caja, {BackgroundColor3 = v and Theme.Accent or Theme.Entrada}, LouisHub.Motion.Hover)
                        Utils.Tween(tCorto, {BackgroundTransparency = v and 0 or 1}, LouisHub.Motion.Hover)
                        Utils.Tween(tLargo, {BackgroundTransparency = v and 0 or 1}, LouisHub.Motion.Hover)
                        aplicarDesactivarSiCorresponde(cfg, v)
                        if disparar and cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, v) end
                    end

                    local hbC = Utils.HitboxAmpliado(caja, 10)
                    Utils.ClickConfiable(hbC, function() actualizar(not val, true) end, caja)

                    LouisHub.Elementos[flag] = {
                        Set = function(v, d) actualizar(v, d or false) end,
                        Get = function() return val end,
                    }
                    return {
                        Set = function(...) actualizar(normalizeSetArg(...), true) end,
                        Get = function() return val end,
                    }
                end

                -- 4. SLIDER
                function Seccion:Slider(cfg)
                    cfg = cfg or {}
                    validarCallback("Slider", cfg)
                    local flag = cfg.Flag or cfg.Texto or ("Slider_" .. math.random(1e5, 1e6))
                    local minimo = cfg.Min or 0
                    local maximo = cfg.Max or 100
                    if minimo >= maximo then maximo = minimo + 1 end
                    local inc = (cfg.Incremento and cfg.Incremento > 0) and cfg.Incremento or 1
                    local sufijo = cfg.Sufijo or ""
                    local val = math.clamp(cfg.Defecto or minimo, minimo, maximo)
                    LouisHub.Flags[flag] = val

                    local fila = Utils.Fila(contenedor, 54, nextOrder(), Theme.Fila)
                    LouisHub:Registrar(fila, "BackgroundColor3", "Fila")
                    Utils.Hover(fila, fila)
                    registrarBuscable(fila, cfg.Texto or "Slider", cfg.VisibleSi)

                    local lblSlider = Utils.Texto({
                        Padre = fila, Texto = cfg.Texto or "Slider", Size = UDim2.new(1, -120, 0, 0),
                        Posicion = UDim2.new(0, 8, 0, 7), Ajustar = true,
                    })
                    lblSlider.AutomaticSize = Enum.AutomaticSize.Y
                    agregarTooltipTexto(fila, cfg.Texto or "Slider", cfg.Tooltip, lblSlider, -118)

                    local inputValor = Instance.new("TextBox", fila)
                    inputValor.Size = UDim2.new(0, 110, 0, 34)
                    inputValor.Position = UDim2.new(1, -116, 0, 7)
                    inputValor.BackgroundColor3 = Theme.Entrada
                    inputValor.Text = tostring(val) .. sufijo
                    inputValor.TextColor3 = Theme.Highlight
                    inputValor.Font = Enum.Font.FredokaOne
                    inputValor.TextSize = 16
                    inputValor.TextXAlignment = Enum.TextXAlignment.Center
                    inputValor.BorderSizePixel = 0
                    inputValor.ClearTextOnFocus = false
                    Utils.Corner(inputValor, 6)
                    LouisHub:Registrar(inputValor, "BackgroundColor3", "Entrada")
                    LouisHub:Registrar(inputValor, "TextColor3", "Highlight")

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

                    local barra, _, fijarVis, hbSlider = crearBarraArrastrable({
                        Padre = fila, Size = UDim2.new(1, -160, 0, 10), Posicion = UDim2.new(0, 8, 0, 38),
                        Min = minimo, Max = maximo, Valor = val, Incremento = inc, Pasos = cfg.Pasos,
                        AltoHitbox = 18, OffsetHitboxY = 2, OnCambio = procesarNuevo,
                    })

                    local function reLayoutSlider()
                        if not (fila and fila.Parent) then return end
                        local e = Utils.FactorEscalaUI(fila)
                        local hLbl = math.max(16, math.ceil(lblSlider.AbsoluteSize.Y / e))
                        local hTop = math.max(hLbl, 34)
                        local yBarra = 7 + hTop + 10
                        barra.Position = UDim2.new(0, 8, 0, yBarra)
                        if hbSlider then hbSlider.Position = UDim2.new(0, 8, 0, yBarra - 2) end
                        fila.Size = UDim2.new(1, 0, 0, yBarra + 24)
                    end
                    LouisHub:RegistrarConexion(lblSlider:GetPropertyChangedSignal("AbsoluteSize"):Connect(Utils.Diferir(reLayoutSlider)))
                    task.defer(reLayoutSlider)

                    inputValor.FocusLost:Connect(function(enter)
                        if not enter then return end
                        local raw = inputValor.Text:gsub("%s+", "")
                        if sufijo ~= "" and raw:sub(-#sufijo) == sufijo then raw = raw:sub(1, -#sufijo - 1) end
                        local n = tonumber(raw)
                        if n then
                            n = redondear(n)
                            ultimoProcesado = n; val = n
                            LouisHub.Flags[flag] = n
                            inputValor.Text = formatNum(n) .. sufijo
                            fijarVis(n)
                            Utils.FlashFeedback(inputValor, true, Theme.Entrada)
                            if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, n) end
                        else
                            inputValor.Text = formatNum(val) .. sufijo
                            Utils.FlashFeedback(inputValor, false, Theme.Entrada)
                        end
                    end)

                    LouisHub.Elementos[flag] = {
                        Set = function(v, d)
                            if type(v) ~= "number" then return end
                            v = redondear(v)
                            ultimoProcesado = v; val = v
                            LouisHub.Flags[flag] = v
                            inputValor.Text = formatNum(v) .. sufijo
                            fijarVis(v)
                            if d and cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, v) end
                        end,
                        Get = function() return val end,
                    }
                    return {
                        Set = function(...) LouisHub.Elementos[flag].Set(normalizeSetArg(...), true) end,
                        Get = function() return val end,
                    }
                end

                -- 5. RANGE SLIDER (DUAL THUMBS)
                function Seccion:RangeSlider(cfg)
                    cfg = cfg or {}
                    validarCallback("RangeSlider", cfg)
                    local flag = cfg.Flag or cfg.Texto or ("RangeSlider_" .. math.random(1e5, 1e6))
                    local minimo = cfg.Min or 0
                    local maximo = cfg.Max or 100
                    if minimo >= maximo then maximo = minimo + 1 end
                    local inc = (cfg.Incremento and cfg.Incremento > 0) and cfg.Incremento or 1
                    local sufijo = cfg.Sufijo or ""
                    local def = cfg.Defecto or {}
                    local vMin = math.clamp(def.min or minimo, minimo, maximo)
                    local vMax = math.clamp(def.max or maximo, minimo, maximo)
                    if vMin > vMax then vMin, vMax = vMax, vMin end

                    local function getVal() return { min = vMin, max = vMax } end
                    LouisHub.Flags[flag] = getVal()

                    local fila = Utils.Fila(contenedor, 54, nextOrder(), Theme.Fila)
                    LouisHub:Registrar(fila, "BackgroundColor3", "Fila")
                    Utils.Hover(fila, fila)
                    registrarBuscable(fila, cfg.Texto or "RangeSlider", cfg.VisibleSi)

                    local lblS = Utils.Texto({
                        Padre = fila, Texto = cfg.Texto or "RangeSlider", Size = UDim2.new(1, -170, 0, 18),
                        Posicion = UDim2.new(0, 8, 0, 6), Truncar = true,
                    })
                    agregarTooltipTexto(fila, cfg.Texto or "RangeSlider", cfg.Tooltip, lblS, -118)

                    local lblVal = Utils.Texto({
                        Padre = fila, Size = UDim2.new(0, 110, 0, 18), Posicion = UDim2.new(1, -116, 0, 6),
                        Alineacion = Enum.TextXAlignment.Right, Fuente = Enum.Font.FredokaOne,
                        Tamano = 13, Color = Theme.Highlight,
                    })
                    LouisHub:Registrar(lblVal, "TextColor3", "Highlight")

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
                        ultimoMin, ultimoMax = mi, ma
                        vMin, vMax = mi, ma
                        LouisHub.Flags[flag] = getVal()
                        refreshText()
                        if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, getVal()) end
                    end

                    local _, fijarVisR = crearBarraArrastrableRango({
                        Padre = fila, Size = UDim2.new(1, -170, 0, 10), Posicion = UDim2.new(0, 8, 0, 38),
                        Min = minimo, Max = maximo, ValorMin = vMin, ValorMax = vMax,
                        ObtenerMin = function() return ultimoMin end,
                        ObtenerMax = function() return ultimoMax end,
                        OnCambio = onRngChange,
                    })

                    LouisHub.Elementos[flag] = {
                        Set = function(v, d)
                            if type(v) ~= "table" or not v.min or not v.max then return end
                            vMin, vMax = redondear(v.min), redondear(v.max)
                            if vMin > vMax then vMin, vMax = vMax, vMin end
                            ultimoMin, ultimoMax = vMin, vMax
                            LouisHub.Flags[flag] = getVal()
                            refreshText(); fijarVisR(vMin, vMax)
                            if d and cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, getVal()) end
                        end,
                        Get = getVal,
                    }
                    return {
                        Set = function(...) LouisHub.Elementos[flag].Set(normalizeSetArg(...), true) end,
                        Get = getVal,
                    }
                end

                -- 6. NUMBER STEPPER
                function Seccion:NumberStepper(cfg)
                    cfg = cfg or {}
                    validarCallback("NumberStepper", cfg)
                    local flag = cfg.Flag or cfg.Texto or ("NumberStepper_" .. math.random(1e5, 1e6))
                    local minimo = cfg.Min or 0
                    local maximo = cfg.Max or 100
                    if minimo >= maximo then maximo = minimo + 1 end
                    local inc = (cfg.Incremento and cfg.Incremento > 0) and cfg.Incremento or 1
                    local decCount = 0
                    local decStr = tostring(inc):match("%.(%d+)$")
                    if decStr then decCount = #decStr end
                    local prefijo = cfg.Prefijo or ""
                    local sufijo  = cfg.Sufijo or ""

                    local function redondear(v)
                        local factor = 1 / inc
                        return math.clamp(math.floor((v - minimo) * factor + 0.5) / factor + minimo, minimo, maximo)
                    end
                    local val = redondear(cfg.Defecto or minimo)
                    LouisHub.Flags[flag] = val

                    local function formatStep(v)
                        local s = (decCount > 0) and string.format("%." .. decCount .. "f", v) or tostring(math.floor(v + 0.5))
                        return prefijo .. s .. sufijo
                    end

                    local fila, lbl = crearCabecera(32, cfg.Texto or "NumberStepper", 1, -160)
                    agregarTooltipTexto(fila, cfg.Texto or "NumberStepper", cfg.Tooltip, lbl)
                    registrarBuscable(fila, cfg.Texto or "NumberStepper", cfg.VisibleSi)

                    local btnMenos = Utils.BotonBase({
                        Padre = fila, Color = Theme.Entrada, Transparencia = 0, Radio = 5,
                        Size = UDim2.new(0, 28, 0, 22), Posicion = UDim2.new(1, -152, 0.5, -11),
                    })
                    LouisHub:Registrar(btnMenos, "BackgroundColor3", "Entrada")
                    Utils.Texto({ Padre = btnMenos, Texto = "−", Size = UDim2.new(1, 0, 1, 0), Alineacion = Enum.TextXAlignment.Center, Fuente = Enum.Font.FredokaOne, Tamano = 14 })

                    local caja = Instance.new("TextBox", fila)
                    caja.Size = UDim2.new(0, 80, 0, 22)
                    caja.Position = UDim2.new(1, -120, 0.5, -11)
                    caja.BackgroundColor3 = Theme.Entrada
                    caja.Text = formatStep(val)
                    caja.TextColor3 = Theme.Highlight
                    caja.Font = Enum.Font.FredokaOne
                    caja.TextSize = 12
                    caja.TextXAlignment = Enum.TextXAlignment.Center
                    caja.ClearTextOnFocus = false
                    caja.BorderSizePixel = 0
                    Utils.Corner(caja, 5)
                    LouisHub:Registrar(caja, "BackgroundColor3", "Entrada")
                    LouisHub:Registrar(caja, "TextColor3", "Highlight")

                    local btnMas = Utils.BotonBase({
                        Padre = fila, Color = Theme.Entrada, Transparencia = 0, Radio = 5,
                        Size = UDim2.new(0, 28, 0, 22), Posicion = UDim2.new(1, -36, 0.5, -11),
                    })
                    LouisHub:Registrar(btnMas, "BackgroundColor3", "Entrada")
                    Utils.Texto({ Padre = btnMas, Texto = "+", Size = UDim2.new(1, 0, 1, 0), Alineacion = Enum.TextXAlignment.Center, Fuente = Enum.Font.FredokaOne, Tamano = 14 })

                    local function step(sign)
                        local n = redondear(val + sign * inc)
                        if n == val then return end
                        val = n
                        LouisHub.Flags[flag] = val
                        caja.Text = formatStep(val)
                        if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, val) end
                    end

                    local pressId = 0
                    local function bindRepeat(btn, sgn)
                        btn.MouseButton1Down:Connect(function()
                            pressId = pressId + 1
                            local myP = pressId
                            step(sgn)
                            task.spawn(function()
                                task.wait(0.4)
                                while pressId == myP and btn.Parent do
                                    step(sgn); task.wait(0.1)
                                end
                            end)
                        end)
                        local stop = function() pressId = pressId + 1 end
                        btn.MouseButton1Up:Connect(stop)
                        btn.MouseLeave:Connect(stop)
                    end
                    bindRepeat(btnMenos, -1)
                    bindRepeat(btnMas, 1)

                    caja.FocusLost:Connect(function(enter)
                        if not enter then return end
                        local t = caja.Text
                        if prefijo ~= "" and t:sub(1, #prefijo) == prefijo then t = t:sub(#prefijo + 1) end
                        if sufijo ~= "" and t:sub(-#sufijo) == sufijo then t = t:sub(1, -#sufijo - 1) end
                        local n = tonumber(t)
                        if n then
                            val = redondear(n)
                            LouisHub.Flags[flag] = val
                            caja.Text = formatStep(val)
                            Utils.FlashFeedback(caja, true, Theme.Entrada)
                            if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, val) end
                        else
                            caja.Text = formatStep(val)
                            Utils.FlashFeedback(caja, false, Theme.Entrada)
                        end
                    end)

                    LouisHub.Elementos[flag] = {
                        Set = function(v, d)
                            if type(v) ~= "number" then return end
                            val = redondear(v)
                            LouisHub.Flags[flag] = val
                            caja.Text = formatStep(val)
                            if d and cfg.Callback then executeCallback(cfg.Callback, cfg.Texto, val) end
                        end,
                        Get = function() return val end,
                    }
                    return {
                        Set = function(...) LouisHub.Elementos[flag].Set(normalizeSetArg(...), true) end,
                        Get = function() return val end,
                    }
                end

-- [END OF PART 4 - PROCEED TO PART 5]

-- ===================================================================
--  LOUIS HUB UI LIBRARY (V3.0 CORE ENGINE)
--  Brand: Louis Hub
--  [PART 5 OF 5] - Controls (B), Schema Builder, Full Suite & Export
-- ===================================================================

                -- 7. INPUT (SINGLE LINE & TEXTAREA)
                function Seccion:Input(cfg)
                    cfg = cfg or {}
                    validarCallback("Input", cfg)
                    local flag = cfg.Flag or cfg.Texto or ("Input_" .. math.random(1e5, 1e6))
                    local val  = cfg.Defecto or ""
                    LouisHub.Flags[flag] = val

                    local esArea = cfg.Tipo == "textarea"
                    local altoArea = math.clamp(cfg.Alto or 100, 50, 400)
                    local PAD_A, GAP_A = 9, 8
                    local fila, lblInput
                    if esArea then
                        fila, lblInput = crearCabecera(32, cfg.Texto or "Input", nil, nil, "manual")
                        lblInput.AutomaticSize = Enum.AutomaticSize.Y
                        lblInput.Size = UDim2.new(1, -20, 0, 0)
                        lblInput.Position = UDim2.new(0, 10, 0, PAD_A)
                    else
                        fila, lblInput = crearCabecera(32, cfg.Texto or "Input", 0.45)
                    end
                    agregarTooltipTexto(fila, cfg.Texto or "Input", cfg.Tooltip, lblInput)
                    registrarBuscable(fila, cfg.Texto or "Input", cfg.VisibleSi)

                    local caja = Instance.new("TextBox", fila)
                    caja.Size             = esArea and UDim2.new(1, -20, 0, altoArea) or UDim2.new(0.5, -12, 0, 26)
                    caja.Position         = esArea and UDim2.new(0, 10, 0, PAD_A + 24 + GAP_A) or UDim2.new(0.5, 0, 0.5, -13)
                    caja.BackgroundColor3 = Theme.Entrada
                    caja.Text             = tostring(val)
                    caja.PlaceholderText  = cfg.Placeholder or ""
                    caja.TextColor3       = Theme.Highlight
                    caja.Font             = Enum.Font.Ubuntu
                    caja.TextSize         = 13
                    caja.ClearTextOnFocus = false
                    caja.BorderSizePixel  = 0
                    if esArea then
                        caja.MultiLine        = true
                        caja.TextWrapped      = true
                        caja.TextXAlignment   = Enum.TextXAlignment.Left
                        caja.TextYAlignment   = Enum.TextYAlignment.Top
                        caja.ClipsDescendants = true
                        local rel = Instance.new("UIPadding", caja)
                        rel.PaddingLeft, rel.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
                        rel.PaddingTop, rel.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
                    end
                    Utils.Corner(caja, 4)
                    LouisHub:Registrar(caja, "BackgroundColor3", "Entrada")
                    LouisHub:Registrar(caja, "TextColor3", "Highlight")

                    local maxChars = cfg.MaxCaracteres or (esArea and 2000 or 200)
                    local umbral = math.floor(maxChars * 0.8)
                    local lblContador, pildoraContador, padCaja
                    local COL_WARN = Color3.fromRGB(215, 160, 50)
                    local COL_LIM  = Color3.fromRGB(190, 60, 60)

                    if not cfg.OcultarContador then
                        pildoraContador = Utils.Frame({
                            Padre = caja, Size = UDim2.new(0, 0, 0, 16),
                            Posicion = esArea and UDim2.new(1, -6, 1, -6) or UDim2.new(1, -6, 0.5, 0),
                            Ancla = esArea and Vector2.new(1, 1) or Vector2.new(1, 0.5),
                            Color = COL_WARN, Radio = 8,
                        })
                        pildoraContador.AutomaticSize = Enum.AutomaticSize.X
                        pildoraContador.Visible = false
                        pildoraContador.ZIndex = caja.ZIndex + 2
                        local relP = Instance.new("UIPadding", pildoraContador)
                        relP.PaddingLeft, relP.PaddingRight = UDim.new(0, 7), UDim.new(0, 7)
                        lblContador = Utils.Texto({
                            Padre = pildoraContador, Texto = "", Size = UDim2.new(0, 0, 1, 0),
                            Alineacion = Enum.TextXAlignment.Center, Fuente = Enum.Font.FredokaOne,
                            Tamano = 10, Color = Color3.fromRGB(255, 255, 255), Categoria = "titulo",
                        })
                        lblContador.AutomaticSize = Enum.AutomaticSize.X
                        lblContador.ZIndex = pildoraContador.ZIndex + 1
                        if not esArea then
                            padCaja = Instance.new("UIPadding", caja)
                        end
                    end

                    local function syncContador()
                        if not lblContador then return end
                        local n = #caja.Text
                        local vis = n >= umbral
                        pildoraContador.Visible = vis
                        if vis then
                            lblContador.Text = n .. "/" .. maxChars
                            pildoraContador.BackgroundColor3 = (n >= maxChars) and COL_LIM or COL_WARN
                        end
                        if padCaja then padCaja.PaddingRight = UDim.new(0, vis and 58 or 0) end
                    end
                    syncContador()

                    caja:GetPropertyChangedSignal("Text"):Connect(function()
                        if #caja.Text > maxChars then
                            caja.Text = caja.Text:sub(1, maxChars)
                            Utils.FlashFeedback(caja, false, Theme.Entrada)
                        end
                        syncContador()
                    end)

                    caja.FocusLost:Connect(function(enter)
                        local clean = caja.Text:gsub("^%s+", ""):gsub("%s+$", "")
                        local finalVal = clean
                        if cfg.Tipo == "number" then
                            local n = tonumber(clean)
                            if not n then
                                caja.Text = tostring(val)
                                Utils.FlashFeedback(caja, false, Theme.Entrada)
                                return
                            end
                            if cfg.Min and n < cfg.Min then n = cfg.Min end
                            if cfg.Max and n > cfg.Max then n = cfg.Max end
                            finalVal = n
                        elseif cfg.Tipo == "pattern" and cfg.Regex then
                            local pat = cfg.Regex:gsub("^%^", ""):gsub("%$$", "")
                            if not clean:match("^" .. pat .. "$") then
                                caja.Text = tostring(val)
                                Utils.FlashFeedback(caja, false, Theme.Entrada)
                                return
                            end
                        end
                        val = finalVal
                        caja.Text = tostring(finalVal)
                        LouisHub.Flags[flag] = val
                        if cfg.Tipo == "number" or cfg.Tipo == "pattern" then
                            Utils.FlashFeedback(caja, true, Theme.Entrada)
                        end
                        if (enter or esArea) and cfg.Callback then
                            executeCallback(cfg.Callback, cfg.Texto or "Input", val)
                        end
                    end)

                    if esArea then
                        local function reLayoutArea()
                            if not (fila and fila.Parent) then return end
                            local e = Utils.FactorEscalaUI(fila)
                            local hLbl = math.max(16, math.ceil(lblInput.AbsoluteSize.Y / e))
                            local yCaja = PAD_A + hLbl + GAP_A
                            caja.Position = UDim2.new(0, 10, 0, yCaja)
                            fila.Size = UDim2.new(1, 0, 0, yCaja + altoArea + PAD_A)
                        end
                        LouisHub:RegistrarConexion(lblInput:GetPropertyChangedSignal("AbsoluteSize"):Connect(Utils.Diferir(reLayoutArea)))
                        task.defer(reLayoutArea)
                    end

                    LouisHub.Elementos[flag] = {
                        Set = function(v, d)
                            val = v
                            caja.Text = tostring(v)
                            LouisHub.Flags[flag] = v
                            if d and cfg.Callback then executeCallback(cfg.Callback, cfg.Texto or "Input", v) end
                        end,
                        Get = function() return val end,
                    }
                    return {
                        Set = function(...) LouisHub.Elementos[flag].Set(normalizeSetArg(...), true) end,
                        Get = function() return val end,
                    }
                end

                -- 8. RADIO GROUP
                function Seccion:RadioGroup(cfg)
                    cfg = cfg or {}
                    validarCallback("RadioGroup", cfg)
                    local flag = cfg.Flag or cfg.Texto or ("RadioGroup_" .. math.random(1e5, 1e6))
                    local opts = cfg.Opciones or {}
                    local seen, cleanOpts = {}, {}
                    for _, op in ipairs(opts) do
                        if not seen[op] then
                            seen[op] = true
                            table.insert(cleanOpts, op)
                        end
                    end
                    opts = cleanOpts
                    local val = cfg.Defecto or opts[1]
                    LouisHub.Flags[flag] = val

                    local PAD_V, GAP_T = 9, 8
                    local fila, lbl = crearCabecera(60, cfg.Texto or "RadioGroup", nil, nil, "manual")
                    lbl.AutomaticSize = Enum.AutomaticSize.Y
                    lbl.Size = UDim2.new(1, -20, 0, 0)
                    lbl.Position = UDim2.new(0, 10, 0, PAD_V)
                    agregarTooltipTexto(fila, cfg.Texto or "RadioGroup", cfg.Tooltip, lbl)
                    registrarBuscable(fila, cfg.Texto or "RadioGroup", cfg.VisibleSi)

                    local filaBtns = Utils.Frame({
                        Padre = fila, Size = UDim2.new(1, -20, 0, 32), Posicion = UDim2.new(0, 10, 0, PAD_V + 20 + GAP_T), Transparencia = 1,
                    })
                    local layBtns = Instance.new("UIListLayout", filaBtns)
                    layBtns.FillDirection = Enum.FillDirection.Horizontal
                    layBtns.Padding = UDim.new(0, 8)
                    layBtns.SortOrder = Enum.SortOrder.LayoutOrder

                    local btns = {}
                    local function refresh()
                        for op, b in pairs(btns) do
                            local act = (op == val)
                            Utils.Tween(b, { BackgroundColor3 = act and Theme.Accent or Theme.Entrada }, LouisHub.Motion.Hover)
                            local lb = b:FindFirstChildOfClass("TextLabel")
                            if lb then lb.TextColor3 = act and Theme.Text or Theme.TextDark end
                        end
                    end

                    local function choose(op)
                        if op == val then return end
                        val = op
                        LouisHub.Flags[flag] = val
                        refresh()
                        if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto or "RadioGroup", val) end
                    end

                    for i, op in ipairs(opts) do
                        local act = (op == val)
                        local b = Utils.BotonBase({
                            Padre = filaBtns,
                            Size = UDim2.new(1 / math.max(#opts, 1), -math.floor(8 * (math.max(#opts, 1) - 1) / math.max(#opts, 1)), 1, 0),
                            Color = act and Theme.Accent or Theme.Entrada,
                            Transparencia = 0, Radio = 6, Orden = i,
                        })
                        LouisHub:Registrar(b, "BackgroundColor3", function() return (op == val) and Theme.Accent or Theme.Entrada end)
                        local lblB = Utils.Texto({
                            Padre = b, Texto = tostring(op), Size = UDim2.new(1, 0, 1, 0),
                            Alineacion = Enum.TextXAlignment.Center, Tamano = 13, Truncar = true,
                            Color = act and Theme.Text or Theme.TextDark,
                        })
                        LouisHub:Registrar(lblB, "TextColor3", function() return (op == val) and Theme.Text or Theme.TextDark end)
                        local hb = Utils.HitboxAmpliado(b, 7)
                        Utils.ClickConfiable(hb, function() choose(op) end, b)
                        btns[op] = b
                    end

                    local function reLayoutRadio()
                        if not (fila and fila.Parent) then return end
                        local e = Utils.FactorEscalaUI(fila)
                        local hLbl = math.max(16, math.ceil(lbl.AbsoluteSize.Y / e))
                        filaBtns.Position = UDim2.new(0, 10, 0, PAD_V + hLbl + GAP_T)
                        fila.Size = UDim2.new(1, 0, 0, PAD_V + hLbl + GAP_T + 32 + PAD_V)
                    end
                    LouisHub:RegistrarConexion(lbl:GetPropertyChangedSignal("AbsoluteSize"):Connect(Utils.Diferir(reLayoutRadio)))
                    task.defer(reLayoutRadio)

                    LouisHub.Elementos[flag] = {
                        Set = function(v, d)
                            val = v
                            LouisHub.Flags[flag] = v
                            refresh()
                            if d and cfg.Callback then executeCallback(cfg.Callback, cfg.Texto or "RadioGroup", v) end
                        end,
                        Get = function() return val end,
                    }
                    return {
                        Set = function(...) choose(normalizeSetArg(...)) end,
                        Get = function() return val end,
                    }
                end

                -- 9. DROPDOWN (SEARCHABLE / MULTI / DIVIDERS / LOCKED ITEMS)
                function Seccion:Dropdown(cfg)
                    cfg = cfg or {}
                    validarCallback("Dropdown", cfg)
                    local flag = cfg.Flag or cfg.Texto or ("Dropdown_" .. math.random(1e5, 1e6))

                    local function normalizarEntradas(lista)
                        local nOpts, nMeta, pSep = {}, {}, false
                        local seen = {}
                        for _, e in ipairs(lista or {}) do
                            if type(e) == "string" then
                                if not seen[e] then
                                    seen[e] = true
                                    table.insert(nOpts, e)
                                    if pSep and #nOpts > 1 then nMeta[e] = { sep = true } end
                                    pSep = false
                                end
                            elseif type(e) == "table" then
                                if e.Tipo == "Divider" then
                                    pSep = true
                                elseif type(e.Titulo) == "string" and e.Titulo ~= "" and not seen[e.Titulo] then
                                    seen[e.Titulo] = true
                                    table.insert(nOpts, e.Titulo)
                                    nMeta[e.Titulo] = {
                                        Descripcion = e.Descripcion, Icono = e.Icono,
                                        Locked = e.Locked == true, LockedTitle = e.LockedTitle,
                                        sep = pSep and #nOpts > 1,
                                    }
                                    pSep = false
                                end
                            end
                        end
                        return nOpts, nMeta
                    end

                    local rawEntries = cloneTable(cfg.Opciones or {})
                    local opts, meta = normalizarEntradas(rawEntries)
                    local multi      = cfg.Multi or false
                    local sel        = {}
                    if multi then
                        for _, v in ipairs(cfg.Defecto or {}) do sel[v] = true end
                    elseif cfg.Defecto then
                        sel[cfg.Defecto] = true
                    end
                    LouisHub.Flags[flag] = multi and cloneTable(sel) or cfg.Defecto

                    local ALTO_FILA   = 32
                    local conBusqueda = #opts > 8
                    local ALTO_BUSQ   = conBusqueda and 24 or 0

                    local marco = Utils.Frame({
                        Padre = contenedor, Size = UDim2.new(1, 0, 0, ALTO_FILA),
                        Color = Theme.Fila, Orden = nextOrder(), Recortar = true,
                    })
                    LouisHub:Registrar(marco, "BackgroundColor3", "Fila")
                    registrarBuscable(marco, cfg.Texto or "Dropdown", cfg.VisibleSi)

                    local cabecera = Utils.BotonBase({ Padre = marco, Size = UDim2.new(1, 0, 0, ALTO_FILA) })
                    Utils.Hover(cabecera, marco)
                    local lbl = Utils.Texto({ Padre = marco, Size = UDim2.new(1, cfg.Tooltip and -52 or -30, 0, ALTO_FILA), Truncar = true })

                    local arrow = Instance.new("ImageLabel", marco)
                    arrow.BackgroundTransparency = 1
                    arrow.Image = "rbxassetid://83472139709682"
                    arrow.ScaleType = Enum.ScaleType.Fit
                    arrow.Size = UDim2.new(0, 10, 0, 10)
                    arrow.AnchorPoint = Vector2.new(0.5, 0.5)
                    arrow.Position = UDim2.new(1, -12, 0.5, 0)
                    LouisHub:Registrar(arrow, "ImageColor3", "Text")
                    if cfg.Tooltip then agregarTooltip(marco, UDim2.new(1, -46, 0, 6), cfg.Tooltip) end

                    local searchBox
                    local function makeSearch()
                        searchBox = Instance.new("TextBox", marco)
                        searchBox.Size             = UDim2.new(1, -8, 0, ALTO_BUSQ - 4)
                        searchBox.Position         = UDim2.new(0, 4, 0, ALTO_FILA + 2)
                        searchBox.BackgroundColor3 = Theme.Entrada
                        searchBox.PlaceholderText  = "🔍 Search..."
                        searchBox.Text             = ""
                        searchBox.TextColor3       = Theme.Text
                        searchBox.Font             = Enum.Font.Ubuntu
                        searchBox.TextSize         = 10
                        searchBox.BorderSizePixel  = 0
                        searchBox.ClearTextOnFocus = false
                        Utils.Corner(searchBox, 4)
                        LouisHub:Registrar(searchBox, "BackgroundColor3", "Entrada")
                        LouisHub:Registrar(searchBox, "TextColor3", "Text")
                    end
                    if conBusqueda then makeSearch() end

                    local listaOp = Utils.Frame({
                        Padre = marco, Size = UDim2.new(1, 0, 0, #opts * 24),
                        Posicion = UDim2.new(0, 0, 0, ALTO_FILA + ALTO_BUSQ), Transparencia = 1,
                    })
                    local layOp = Instance.new("UIListLayout", listaOp)
                    layOp.Padding = UDim.new(0, 2)
                    layOp.SortOrder = Enum.SortOrder.LayoutOrder

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

                    local btnsOp, strokesOp = {}, {}
                    local alternar
                    local primeMatch = nil

                    local function choose(op, noToggle)
                        if multi then sel[op] = not sel[op] or nil
                        else sel = { [op] = true } end
                        LouisHub.Flags[flag] = multi and cloneTable(sel) or op
                        for o, b in pairs(btnsOp) do b.BackgroundColor3 = sel[o] and Theme.Accent or Theme.Entrada end
                        updateLbl()
                        if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto or "Dropdown", multi and cloneTable(sel) or op) end
                        if not multi and not noToggle and alternar then alternar() end
                    end

                    local function createOptionBtn(op, idx)
                        local info = meta[op]
                        local isLocked = info and info.Locked == true
                        local b = Utils.BotonBase({
                            Padre = listaOp, Size = UDim2.new(1, 0, 0, 22),
                            Color = sel[op] and Theme.Accent or Theme.Entrada,
                            Transparencia = isLocked and 0.45 or 0, Orden = idx, Radio = 4,
                        })
                        LouisHub:Registrar(b, "BackgroundColor3", function() return sel[op] and Theme.Accent or Theme.Entrada end)

                        local tTitle = ((info and info.Icono) and (tostring(info.Icono) .. " ") or "") .. op
                        local tRight = info and (isLocked and ("🔒 " .. tostring(info.LockedTitle or "Locked")) or info.Descripcion)
                        if tRight then
                            Utils.Texto({ Padre = b, Texto = tTitle, Tamano = 11, Size = UDim2.new(0.55, -8, 1, 0), Truncar = true, TextoTransparencia = isLocked and 0.45 or 0 })
                            Utils.Texto({ Padre = b, Texto = tostring(tRight), Tamano = 10, Size = UDim2.new(0.45, -10, 1, 0), Posicion = UDim2.new(0.55, 0, 0, 0), Alineacion = Enum.TextXAlignment.Right, Truncar = true, ColorTema = "TextDark", TextoTransparencia = 0.1 })
                        else
                            Utils.Texto({ Padre = b, Texto = tTitle, Tamano = 11 })
                        end

                        if info and info.sep then
                            local sep = Utils.Frame({ Padre = b, Size = UDim2.new(1, -8, 0, 1), Posicion = UDim2.new(0, 4, 0, -2), Color = Theme.Border, Transparencia = 0.3, Radio = false })
                            LouisHub:Registrar(sep, "BackgroundColor3", "Border")
                        end

                        local hb = Utils.HitboxAmpliado(b, 6)
                        Utils.ClickConfiable(hb, function()
                            if isLocked then return end
                            choose(op)
                        end, b)

                        btnsOp[op] = b
                        strokesOp[op] = Utils.Stroke(b, Theme.Highlight, 1.5, 1)
                        LouisHub:Registrar(strokesOp[op], "Color", "Highlight")
                    end

                    local function renderAllOptions()
                        for _, c in ipairs(listaOp:GetChildren()) do if c:IsA("TextButton") then c:Destroy() end end
                        btnsOp, strokesOp = {}, {}
                        for i, op in ipairs(opts) do createOptionBtn(op, i) end
                        listaOp.Size = UDim2.new(1, 0, 0, math.max(#opts, 1) * 24)
                    end
                    renderAllOptions()

                    local function filterOptions(t)
                        t = t:lower()
                        local count = 0
                        local prevMatch = primeMatch
                        primeMatch = nil
                        for _, op in ipairs(opts) do
                            local b = btnsOp[op]
                            if b then
                                local m = (t == "") or (op:lower():find(t, 1, true) ~= nil)
                                b.Visible = m
                                if m then
                                    count = count + 1
                                    if not primeMatch and t ~= "" then primeMatch = op end
                                end
                            end
                        end
                        listaOp.Size = UDim2.new(1, 0, 0, math.max(count, 1) * 24)
                        if prevMatch and strokesOp[prevMatch] then strokesOp[prevMatch].Transparency = 1 end
                        if primeMatch and strokesOp[primeMatch] then strokesOp[primeMatch].Transparency = 0 end
                    end

                    alternar = hacerExpandible(marco, ALTO_FILA, function()
                        local count = 0
                        for _, b in pairs(btnsOp) do if b.Visible then count = count + 1 end end
                        return ALTO_FILA + ALTO_BUSQ + math.max(count, 1) * 24 + 4
                    end)

                    Utils.ClickConfiable(cabecera, function()
                        local opened = alternar()
                        if searchBox then
                            searchBox.Visible = opened
                            if opened then
                                searchBox.Text = ""
                                filterOptions("")
                                if not LouisHub.Capacidades.EsTactil then searchBox:CaptureFocus() end
                            else
                                searchBox:ReleaseFocus()
                            end
                        end
                    end)

                    local function hookSearch()
                        searchBox:GetPropertyChangedSignal("Text"):Connect(function()
                            filterOptions(searchBox.Text)
                            local count = 0
                            for _, b in pairs(btnsOp) do if b.Visible then count = count + 1 end end
                            Utils.Tween(marco, { Size = UDim2.new(1, 0, 0, ALTO_FILA + ALTO_BUSQ + math.max(count, 1) * 24 + 4) }, 0.1)
                        end)
                        searchBox.FocusLost:Connect(function(enter)
                            if enter and primeMatch then choose(primeMatch) end
                        end)
                    end
                    if searchBox then hookSearch() end

                    local function getVal()
                        if multi then return cloneTable(sel) end
                        for k, v in pairs(sel) do if v then return k end end
                        return nil
                    end

                    local function updateOptions(newEntries)
                        rawEntries = cloneTable(newEntries or {})
                        opts, meta = normalizarEntradas(rawEntries)
                        renderAllOptions()
                        conBusqueda = #opts > 8
                        ALTO_BUSQ   = conBusqueda and 24 or 0
                        if conBusqueda and not searchBox then
                            makeSearch(); hookSearch()
                        end
                        if searchBox then searchBox.Visible = false end
                        listaOp.Position = UDim2.new(0, 0, 0, ALTO_FILA + ALTO_BUSQ)
                        updateLbl()
                    end

                    LouisHub.Elementos[flag] = {
                        Set = function(v, d)
                            if multi then sel = cloneTable(v or {}) else sel = { [v] = true } end
                            LouisHub.Flags[flag] = multi and cloneTable(sel) or v
                            for o, b in pairs(btnsOp) do b.BackgroundColor3 = sel[o] and Theme.Accent or Theme.Entrada end
                            updateLbl()
                            if d and cfg.Callback then executeCallback(cfg.Callback, cfg.Texto or "Dropdown", getVal()) end
                        end,
                        Get = getVal,
                        ActualizarOpciones = updateOptions,
                        AgregarOpcion = function(...)
                            local n = normalizeSetArg(...)
                            if type(n) == "string" and n ~= "" and not table.find(opts, n) then
                                local c = cloneTable(rawEntries); table.insert(c, n); updateOptions(c)
                                return true
                            end
                            return false
                        end,
                        EliminarOpcion = function(...)
                            local n = normalizeSetArg(...)
                            local c, found = {}, false
                            for _, e in ipairs(rawEntries) do
                                local tit = (type(e) == "string" and e) or (type(e) == "table" and e.Titulo)
                                if tit == n then found = true else table.insert(c, e) end
                            end
                            if found then updateOptions(c); return true end
                            return false
                        end,
                        LimpiarOpciones = function() updateOptions({}) end,
                    }

                    return {
                        Set = function(...)
                            local v = normalizeSetArg(...)
                            if multi then
                                sel = cloneTable(v or {})
                                LouisHub.Flags[flag] = cloneTable(sel)
                                for o, b in pairs(btnsOp) do b.BackgroundColor3 = sel[o] and Theme.Accent or Theme.Entrada end
                                updateLbl()
                                if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto or "Dropdown", cloneTable(sel)) end
                            else
                                choose(v, true)
                            end
                        end,
                        Get = getVal,
                        ActualizarOpciones = updateOptions,
                        AgregarOpcion = LouisHub.Elementos[flag].AgregarOpcion,
                        EliminarOpcion = LouisHub.Elementos[flag].EliminarOpcion,
                        LimpiarOpciones = LouisHub.Elementos[flag].LimpiarOpciones,
                    }
                end

                -- 10. COLOR PICKER (RGB SLIDERS + HEX + 8 SWATCHES PALETTE)
                function Seccion:ColorPicker(cfg)
                    cfg = cfg or {}
                    validarCallback("ColorPicker", cfg)
                    local flag = cfg.Flag or cfg.Texto or ("Color_" .. math.random(1e5, 1e6))
                    local curColor = cfg.Defecto or Color3.fromRGB(255, 255, 255)
                    LouisHub.Flags[flag] = curColor

                    local ALTO_FILA = 32
                    local marco = Utils.Frame({
                        Padre = contenedor, Size = UDim2.new(1, 0, 0, ALTO_FILA),
                        Color = Theme.Fila, Orden = nextOrder(), Recortar = true,
                    })
                    LouisHub:Registrar(marco, "BackgroundColor3", "Fila")
                    registrarBuscable(marco, cfg.Texto or "Color", cfg.VisibleSi)

                    local cabecera = Utils.BotonBase({ Padre = marco, Size = UDim2.new(1, 0, 0, ALTO_FILA) })
                    Utils.Hover(cabecera, marco)
                    Utils.Texto({ Padre = marco, Texto = cfg.Texto or "Color", Size = UDim2.new(1, cfg.Tooltip and -68 or -46, 0, ALTO_FILA), Truncar = true })

                    local swatch = Utils.Frame({
                        Padre = marco, Size = UDim2.new(0, 30, 0, 16), Posicion = UDim2.new(1, -36, 0, 8),
                        Color = curColor, Radio = 4, Borde = true, ColorBorde = Theme.Border,
                    })
                    if cfg.Tooltip then agregarTooltip(marco, UDim2.new(1, -68, 0, 6), cfg.Tooltip) end

                    local panel = Utils.Frame({
                        Padre = marco, Size = UDim2.new(1, -16, 0, 126), Posicion = UDim2.new(0, 8, 0, ALTO_FILA + 2), Transparencia = 1,
                    })
                    local layP = Instance.new("UIListLayout", panel)
                    layP.Padding = UDim.new(0, 4)

                    local r, g, b = curColor.R * 255, curColor.G * 255, curColor.B * 255
                    local hexBox
                    local fvR, fvG, fvB

                    local function toHex(c)
                        return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
                    end

                    local function sync(fire)
                        curColor = Color3.fromRGB(math.clamp(math.floor(r + 0.5), 0, 255), math.clamp(math.floor(g + 0.5), 0, 255), math.clamp(math.floor(b + 0.5), 0, 255))
                        swatch.BackgroundColor3 = curColor
                        if hexBox then hexBox.Text = toHex(curColor) end
                        LouisHub.Flags[flag] = curColor
                        if fire and cfg.Callback then executeCallback(cfg.Callback, cfg.Texto or "ColorPicker", curColor) end
                    end

                    local COLORES_COMUNES = {
                        Color3.fromRGB(255, 0, 0),     Color3.fromRGB(0, 255, 0),
                        Color3.fromRGB(0, 120, 255),   Color3.fromRGB(255, 255, 0),
                        Color3.fromRGB(255, 0, 255),   Color3.fromRGB(0, 255, 255),
                        Color3.fromRGB(255, 255, 255), Color3.fromRGB(20, 20, 20),
                    }
                    local filaSwatches = Utils.Frame({ Padre = panel, Size = UDim2.new(1, 0, 0, 22), Orden = 0, Transparencia = 1 })
                    local laySwatches = Instance.new("UIListLayout", filaSwatches)
                    laySwatches.FillDirection = Enum.FillDirection.Horizontal
                    laySwatches.Padding = UDim.new(0, 4)

                    for i, swCol in ipairs(COLORES_COMUNES) do
                        local sw = Utils.BotonBase({ Padre = filaSwatches, Size = UDim2.new(0, 20, 0, 20), Color = swCol, Transparencia = 0, Radio = 4, Orden = i })
                        local stSw = Utils.Stroke(sw, Theme.Border, 1, 0.4)
                        LouisHub:Registrar(stSw, "Color", "Border")
                        local hbSw = Utils.HitboxAmpliado(sw, 7)
                        Utils.ClickConfiable(hbSw, function()
                            r, g, b = swCol.R * 255, swCol.G * 255, swCol.B * 255
                            fvR(r); fvG(g); fvB(b)
                            sync(true)
                        end, sw)
                    end

                    local function canalRGB(chName, order, getV, setV)
                        local rowMini = Utils.Frame({ Padre = panel, Size = UDim2.new(1, 0, 0, 22), Orden = order, Transparencia = 1 })
                        Utils.Texto({ Padre = rowMini, Texto = chName, Size = UDim2.new(0, 14, 1, 0), Fuente = Enum.Font.FredokaOne, Tamano = 10 })
                        local _, _, fv = crearBarraArrastrable({
                            Padre = rowMini, Size = UDim2.new(1, -18, 0, 6), Posicion = UDim2.new(0, 18, 0.5, -3),
                            Min = 0, Max = 255, Valor = getV(),
                            OnCambio = function(v) setV(v); sync(true) end,
                        })
                        return fv
                    end

                    fvR = canalRGB("R", 1, function() return r end, function(v) r = v end)
                    fvG = canalRGB("G", 2, function() return g end, function(v) g = v end)
                    fvB = canalRGB("B", 3, function() return b end, function(v) b = v end)

                    local rowHex = Utils.Frame({ Padre = panel, Size = UDim2.new(1, 0, 0, 22), Orden = 4, Transparencia = 1 })
                    Utils.Texto({ Padre = rowHex, Texto = "Hex", Size = UDim2.new(0, 28, 1, 0), Fuente = Enum.Font.FredokaOne, Tamano = 10 })
                    hexBox = Instance.new("TextBox", rowHex)
                    hexBox.Size             = UDim2.new(1, -32, 1, 0)
                    hexBox.Position         = UDim2.new(0, 32, 0, 0)
                    hexBox.BackgroundColor3 = Theme.Entrada
                    hexBox.Font             = Enum.Font.Code
                    hexBox.TextSize         = 12
                    hexBox.TextColor3       = Theme.Text
                    hexBox.PlaceholderText  = "#RRGGBB"
                    hexBox.ClearTextOnFocus = false
                    hexBox.Text             = toHex(curColor)
                    Utils.Corner(hexBox, 4)
                    LouisHub:Registrar(hexBox, "BackgroundColor3", "Entrada")
                    LouisHub:Registrar(hexBox, "TextColor3", "Text")

                    hexBox.FocusLost:Connect(function()
                        local clean = hexBox.Text:gsub("^#", ""):gsub("%s", "")
                        if #clean == 3 then
                            clean = clean:sub(1,1):rep(2) .. clean:sub(2,2):rep(2) .. clean:sub(3,3):rep(2)
                        end
                        if #clean == 6 and not clean:match("%X") then
                            r = tonumber(clean:sub(1, 2), 16)
                            g = tonumber(clean:sub(3, 4), 16)
                            b = tonumber(clean:sub(5, 6), 16)
                            fvR(r); fvG(g); fvB(b)
                            sync(true)
                            Utils.FlashFeedback(hexBox, true, Theme.Entrada)
                        else
                            hexBox.Text = toHex(curColor)
                            Utils.FlashFeedback(hexBox, false, Theme.Entrada)
                        end
                    end)

                    local alternar = hacerExpandible(marco, ALTO_FILA, function() return ALTO_FILA + 130 end)
                    Utils.ClickConfiable(cabecera, function() alternar() end)

                    LouisHub.Elementos[flag] = {
                        Set = function(v, d)
                            if typeof(v) ~= "Color3" then return end
                            r, g, b = v.R * 255, v.G * 255, v.B * 255
                            fvR(r); fvG(g); fvB(b)
                            sync(d or false)
                        end,
                        Get = function() return curColor end,
                    }
                    return {
                        Set = function(...) LouisHub.Elementos[flag].Set(normalizeSetArg(...), true) end,
                        Get = function() return curColor end,
                    }
                end

                -- 11. KEYBIND (WITH GAMEPAD & MOBILE ROTATION)
                function Seccion:Keybind(cfg)
                    cfg = cfg or {}
                    validarCallback("Keybind", cfg)
                    local flag    = cfg.Flag or cfg.Texto or ("Keybind_" .. math.random(1e5, 1e6))
                    local conMods = cfg.ConModificadores or false
                    local val     = cfg.Defecto or (conMods and { KeyCode = Enum.KeyCode.Unknown } or Enum.KeyCode.Unknown)
                    if conMods and typeof(val) ~= "table" then
                        val = { KeyCode = val, Ctrl = false, Shift = false, Alt = false }
                    end
                    LouisHub.Flags[flag] = val

                    local entryConflict = { flag = flag, texto = cfg.Texto or "Keybind", GetValor = function() return val end }
                    table.insert(_registeredKeybinds, entryConflict)

                    local fila, lbl = crearCabecera(32, cfg.Texto or "Keybind", 1, -72)
                    agregarTooltipTexto(fila, cfg.Texto or "Keybind", cfg.Tooltip, lbl)
                    registrarBuscable(fila, cfg.Texto or "Keybind", cfg.VisibleSi)

                    local sinTeclado = not LouisHub.Capacidades.Teclado
                    local conGamepad = sinTeclado and LouisHub.Capacidades.Gamepad
                    local soloDirect = sinTeclado and not conGamepad

                    local btnTecla = Utils.BotonBase({
                        Padre = fila, Size = UDim2.new(0, 60, 0, 18), Posicion = UDim2.new(1, -66, 0.5, -9),
                        Color = Theme.Entrada, Transparencia = 0, Radio = 4,
                    })
                    LouisHub:Registrar(btnTecla, "BackgroundColor3", "Entrada")
                    local k, c, s, a = decomposeKey(val)
                    local lblTecla = Utils.Texto({
                        Padre = btnTecla, Texto = soloDirect and "▶ Run" or formatKeyText(k, c, s, a),
                        Alineacion = Enum.TextXAlignment.Center, Color = Theme.Highlight, Tamano = 10,
                    })
                    LouisHub:Registrar(lblTecla, "TextColor3", "Highlight")

                    local esperando = false
                    local connCapture

                    local function applyKey(newVal, fire)
                        val = newVal
                        LouisHub.Flags[flag] = newVal
                        if not soloDirect then
                            local keyK, keyC, keyS, keyA = decomposeKey(val)
                            lblTecla.Text = formatKeyText(keyK, keyC, keyS, keyA)
                        end
                        if fire and cfg.Callback then executeCallback(cfg.Callback, cfg.Texto or "Keybind", val) end
                    end

                    if soloDirect then
                        Utils.ClickConfiable(btnTecla, function()
                            Utils.Tween(btnTecla, { BackgroundColor3 = Theme.Accent }, LouisHub.Motion.FlashIn)
                            task.delay(0.12, function()
                                if btnTecla and btnTecla.Parent then Utils.Tween(btnTecla, { BackgroundColor3 = Theme.Entrada }, LouisHub.Motion.Expand) end
                            end)
                            applyKey(val, true)
                        end)

                        local touchKeys = { Enum.KeyCode.E, Enum.KeyCode.F, Enum.KeyCode.Q, Enum.KeyCode.R, Enum.KeyCode.T, Enum.KeyCode.G }
                        pcall(function()
                            LouisHub:RegistrarConexion(UserInputService.TouchLongPress:Connect(function(positions, state)
                                if state ~= Enum.UserInputState.Begin then return end
                                local pos = positions[1]
                                if not pos then return end
                                local ap, as = btnTecla.AbsolutePosition, btnTecla.AbsoluteSize
                                if pos.X >= ap.X and pos.X <= ap.X + as.X and pos.Y >= ap.Y and pos.Y <= ap.Y + as.Y then
                                    local curK = decomposeKey(val)
                                    local idx = table.find(touchKeys, curK) or 0
                                    local nextK = touchKeys[(idx % #touchKeys) + 1]
                                    local nVal = conMods and { KeyCode = nextK, Ctrl = false, Shift = false, Alt = false } or nextK
                                    checkKeybindConflict(entryConflict, nVal)
                                    applyKey(nVal, false)
                                    LouisHub:Notificar({ Titulo = "⌨️ Key Switched", Texto = nextK.Name, Duracion = 1.5 })
                                end
                            end))
                        end)
                    else
                        Utils.ClickConfiable(btnTecla, function()
                            if esperando then return end
                            esperando = true
                            lblTecla.Text = "..."
                            btnTecla.BackgroundColor3 = Theme.Accent

                            connCapture = UserInputService.InputBegan:Connect(function(input, gpe)
                                if gpe or not esperando then return end
                                local isKb = input.UserInputType == Enum.UserInputType.Keyboard
                                local isGp = input.UserInputType.Name:sub(1, 7) == "Gamepad"
                                if (isKb or isGp) and input.KeyCode ~= Enum.KeyCode.Unknown then
                                    local isMod = conMods and isKb and (
                                        input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl or
                                        input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift or
                                        input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt
                                    )
                                    if isMod then return end

                                    esperando = false
                                    btnTecla.BackgroundColor3 = Theme.Entrada
                                    if connCapture then connCapture:Disconnect(); connCapture = nil end

                                    local newVal
                                    if conMods then
                                        newVal = {
                                            KeyCode = input.KeyCode,
                                            Ctrl  = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl),
                                            Shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift),
                                            Alt   = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt),
                                        }
                                    else
                                        newVal = input.KeyCode
                                    end
                                    checkKeybindConflict(entryConflict, newVal)
                                    applyKey(newVal, false)
                                end
                            end)
                            LouisHub:RegistrarConexion(connCapture)

                            task.delay(5, function()
                                if esperando then
                                    esperando = false
                                    btnTecla.BackgroundColor3 = Theme.Entrada
                                    local keyK, keyC, keyS, keyA = decomposeKey(val)
                                    lblTecla.Text = formatKeyText(keyK, keyC, keyS, keyA)
                                    if connCapture then connCapture:Disconnect(); connCapture = nil end
                                end
                            end)
                        end)

                        LouisHub:RegistrarConexion(UserInputService.InputBegan:Connect(function(input, gpe)
                            if gpe or esperando then return end
                            local targetK, reqC, reqS, reqA = decomposeKey(val)
                            if targetK == Enum.KeyCode.Unknown or input.KeyCode ~= targetK then return end
                            if conMods then
                                local ctrl  = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
                                local shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
                                local alt   = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
                                if ctrl ~= reqC or shift ~= reqS or alt ~= reqA then return end
                            end
                            if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto or "Keybind", val) end
                        end))
                    end

                    LouisHub.Elementos[flag] = {
                        Set = function(newKey, d) applyKey(newKey, d or false) end,
                        Get = function() return val end,
                    }
                    return {
                        Set = function(...) applyKey(normalizeSetArg(...), true) end,
                        Get = function() return val end,
                    }
                end

                -- 12. LABEL (DYNAMIC OBSERVABLE TEXT)
                function Seccion:Label(cfg)
                    cfg = cfg or {}
                    local flag = cfg.Flag or ("Label_" .. math.random(1e5, 1e6))
                    local val  = tostring(cfg.Valor or "")
                    _nonPersistentFlags[flag] = true

                    local fila, lbl = crearCabecera(32, cfg.Texto or "Label", 1, -126)
                    agregarTooltipTexto(fila, cfg.Texto or "Label", cfg.Tooltip, lbl)
                    registrarBuscable(fila, cfg.Texto or "Label", cfg.VisibleSi)

                    local lblValor = Utils.Texto({
                        Padre = fila, Texto = val, Size = UDim2.new(0, 120, 1, 0),
                        Posicion = UDim2.new(1, -126, 0, 0), Alineacion = Enum.TextXAlignment.Right,
                        Color = Theme.AccentLight, Tamano = 12, Truncar = true, RichText = cfg.RichText,
                    })

                    local colorCustom = nil
                    LouisHub:Registrar(lblValor, "TextColor3", function() return colorCustom or Theme.AccentLight end)

                    local function fijar(v)
                        val = tostring(v)
                        lblValor.Text = val
                        _realFlags[flag] = v
                    end
                    _realFlags[flag] = cfg.Valor

                    if cfg.Cada and cfg.Actualizar and type(cfg.Actualizar) == "function" then
                        local c = tonumber(cfg.Cada) or 1
                        _labelsAutoActualizables[lblValor] = { cada = c, fn = cfg.Actualizar, aplicar = fijar, flag = flag, proxima = os.clock() + c }
                    end

                    LouisHub.Elementos[flag] = {
                        Set = fijar, Get = function() return val end,
                    }
                    return {
                        Set = function(...) fijar(normalizeSetArg(...)) end,
                        SetColor = function(_, c) colorCustom = c; lblValor.TextColor3 = c end,
                        Get = function() return val end,
                    }
                end

                -- 13. PARRAFO (RICH TEXT, MEDIA & EXPANDER)
                function Seccion:Parrafo(cfg)
                    cfg = cfg or {}
                    local marcoP = Utils.Frame({
                        Padre = contenedor, Size = UDim2.new(1, 0, 0, 0),
                        Color = Theme.Fila, Orden = nextOrder(), Radio = 8,
                    })
                    marcoP.AutomaticSize = Enum.AutomaticSize.Y
                    LouisHub:Registrar(marcoP, "BackgroundColor3", "Fila")

                    local int = Utils.Frame({ Padre = marcoP, Size = UDim2.new(1, 0, 0, 0), Transparencia = 1 })
                    int.AutomaticSize = Enum.AutomaticSize.Y
                    local lay = Instance.new("UIListLayout", int)
                    lay.Padding = UDim.new(0, 2)
                    lay.SortOrder = Enum.SortOrder.LayoutOrder

                    local pad = Instance.new("UIPadding", int)
                    pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 8), UDim.new(0, 8)
                    pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 10), UDim.new(0, cfg.MiniaturaUrl and 72 or 10)

                    if type(cfg.ImagenUrl) == "string" and cfg.ImagenUrl ~= "" then
                        local imgBanner = Instance.new("ImageLabel", int)
                        imgBanner.BackgroundColor3 = Theme.Entrada
                        imgBanner.BorderSizePixel  = 0
                        imgBanner.Image            = cfg.ImagenUrl
                        imgBanner.ScaleType        = cfg.ImagenEscala == "Fit" and Enum.ScaleType.Fit or Enum.ScaleType.Crop
                        imgBanner.Size             = UDim2.new(1, 0, 0, math.clamp(cfg.ImagenAlto or 110, 40, 300))
                        imgBanner.LayoutOrder      = 0
                        Utils.Corner(imgBanner, 6)
                        LouisHub:Registrar(imgBanner, "BackgroundColor3", "Entrada")
                    end

                    if type(cfg.MiniaturaUrl) == "string" and cfg.MiniaturaUrl ~= "" then
                        local thumb = Instance.new("ImageLabel", marcoP)
                        thumb.BackgroundColor3 = Theme.Entrada
                        thumb.BorderSizePixel  = 0
                        thumb.Image            = cfg.MiniaturaUrl
                        thumb.ScaleType        = Enum.ScaleType.Crop
                        thumb.Size             = UDim2.new(0, 52, 0, 52)
                        thumb.AnchorPoint      = Vector2.new(1, 0)
                        thumb.Position         = UDim2.new(1, -10, 0, 8)
                        Utils.Corner(thumb, 8)
                        LouisHub:Registrar(thumb, "BackgroundColor3", "Entrada")
                        local sc = Instance.new("UISizeConstraint", marcoP)
                        sc.MinSize = Vector2.new(0, 68)
                    end

                    if cfg.Titulo then
                        local lTit = Utils.Texto({
                            Padre = int, Texto = cfg.Titulo, Size = UDim2.new(1, 0, 0, 0),
                            Fuente = Enum.Font.FredokaOne, Tamano = 13, Color = Theme.Highlight,
                            Ajustar = true, Orden = 1, RichText = cfg.RichText,
                        })
                        lTit.AutomaticSize = Enum.AutomaticSize.Y
                        LouisHub:Registrar(lTit, "TextColor3", "Highlight")
                    end

                    local lContent = Utils.Texto({
                        Padre = int, Texto = cfg.Contenido or "", Size = UDim2.new(1, 0, 0, 0),
                        Tamano = 12, Color = Theme.Text, Ajustar = true, Orden = 2, RichText = cfg.RichText,
                    })
                    lContent.AutomaticSize = Enum.AutomaticSize.Y
                    LouisHub:Registrar(lContent, "TextColor3", "Text")

                    if cfg.Descripcion then
                        local bMore = Utils.BotonBase({ Padre = int, Size = UDim2.new(1, 0, 0, 22), Transparencia = 1, Orden = 3, Radio = 4 })
                        local lMore = Utils.Texto({ Padre = bMore, Texto = "+ More info", Size = UDim2.new(1, 0, 1, 0), Tamano = 11, Color = Theme.AccentLight, ColorTema = "AccentLight" })
                        local lExtra = Utils.Texto({
                            Padre = int, Texto = tostring(cfg.Descripcion), Size = UDim2.new(1, 0, 0, 0),
                            Tamano = 11, Ajustar = true, ColorTema = "TextDark", Orden = 4, RichText = cfg.RichText,
                        })
                        lExtra.AutomaticSize = Enum.AutomaticSize.Y
                        lExtra.Visible = false
                        Utils.ClickConfiable(bMore, function()
                            lExtra.Visible = not lExtra.Visible
                            lMore.Text = lExtra.Visible and "- Less info" or "+ More info"
                        end)
                    end

                    local parBtns = {}
                    if type(cfg.Botones) == "table" and #cfg.Botones > 0 then
                        local totalB = #cfg.Botones
                        local rowB = Utils.Frame({ Padre = int, Size = UDim2.new(1, 0, 0, 30), Transparencia = 1, Orden = 5, Radio = false })
                        local layB = Instance.new("UIListLayout", rowB)
                        layB.FillDirection = Enum.FillDirection.Horizontal
                        layB.Padding = UDim.new(0, 8)
                        for i, defB in ipairs(cfg.Botones) do
                            local isPri = defB.Variante == "primary"
                            local isDan = defB.Variante == "danger"
                            local bp = Utils.BotonBase({
                                Padre = rowB, Size = UDim2.new(1 / totalB, -math.ceil(8 * (totalB - 1) / totalB), 1, 0),
                                Color = isDan and Color3.fromRGB(190, 60, 60) or (isPri and Theme.Accent or Theme.Entrada),
                                Transparencia = 0, Radio = 6,
                            })
                            bp.LayoutOrder = i
                            if isPri then LouisHub:Registrar(bp, "BackgroundColor3", "Accent")
                            elseif not isDan then LouisHub:Registrar(bp, "BackgroundColor3", "Entrada") end
                            Utils.Texto({
                                Padre = bp, Texto = tostring(defB.Texto or "OK"), Alineacion = Enum.TextXAlignment.Center,
                                Tamano = 12, Truncar = true, Fuente = Enum.Font.FredokaOne,
                                Color = (isPri or isDan) and Color3.fromRGB(255, 255, 255) or nil,
                            })
                            Utils.ClickConfiable(bp, function()
                                if type(defB.Callback) == "function" then executeCallback(defB.Callback, defB.Texto or "Parrafo") end
                            end, bp)
                            table.insert(parBtns, bp)
                        end
                    end

                    return {
                        Instancia = marcoP,
                        Botones   = parBtns,
                        Set = function(...) lContent.Text = tostring(normalizeSetArg(...)) end,
                    }
                end

                -- 14. PROGRESO (READ-ONLY ANIMATED BAR)
                function Seccion:Progreso(cfg)
                    cfg = cfg or {}
                    local flag = cfg.Flag or cfg.Texto or ("Progreso_" .. math.random(1e5, 1e6))
                    local val  = math.clamp(cfg.Defecto or 0, 0, 100)
                    _nonPersistentFlags[flag] = true
                    _realFlags[flag] = val

                    local fila, lbl = crearCabecera(44, cfg.Texto or "Progreso", nil, nil, "fijo")
                    lbl.Size = UDim2.new(1, -70, 0, 18)
                    lbl.Position = UDim2.new(0, 10, 0, 4)
                    registrarBuscable(fila, cfg.Texto or "Progreso", cfg.VisibleSi)

                    local lblVal = Utils.Texto({
                        Padre = fila, Texto = math.floor(val) .. "%", Size = UDim2.new(0, 50, 0, 18),
                        Posicion = UDim2.new(1, -60, 0, 4), Alineacion = Enum.TextXAlignment.Right,
                        Color = Theme.AccentLight, Tamano = 11,
                    })
                    LouisHub:Registrar(lblVal, "TextColor3", "AccentLight")

                    local fondo = Utils.Frame({
                        Padre = fila, Size = UDim2.new(1, -20, 0, 6), Posicion = UDim2.new(0, 10, 0, 28),
                        Color = Theme.Entrada, Radio = 3,
                    })
                    LouisHub:Registrar(fondo, "BackgroundColor3", "Entrada")

                    local relleno = Utils.Frame({
                        Padre = fondo, Size = UDim2.new(val / 100, 0, 1, 0), Color = Theme.Accent, Radio = 3,
                    })
                    LouisHub:Registrar(relleno, "BackgroundColor3", "Accent")
                    Utils.GradienteAcento(relleno)

                    local lastNum = val
                    local function fijar(v)
                        if type(v) ~= "number" then return end
                        val = math.clamp(v, 0, 100)
                        Utils.Tween(relleno, { Size = UDim2.new(val / 100, 0, 1, 0) }, LouisHub.Motion.Expand)
                        local from = lastNum
                        lastNum = val
                        Utils.TweenNumero(from, val, LouisHub.Motion.Page, function(n)
                            if lblVal and lblVal.Parent then lblVal.Text = math.floor(n + 0.5) .. "%" end
                        end, LouisHub.Motion.EaseEntrar)
                        _realFlags[flag] = val
                    end

                    LouisHub.Elementos[flag] = { Set = fijar, Get = function() return val end }
                    return { Set = function(...) fijar(normalizeSetArg(...)) end, Get = function() return val end }
                end

                -- 15. DIVIDER
                function Seccion:Divider(cfg)
                    cfg = cfg or {}
                    local conTxt = cfg.Texto ~= nil
                    local fila = Utils.Frame({
                        Padre = contenedor, Size = UDim2.new(1, 0, 0, conTxt and 38 or 18),
                        Orden = nextOrder(), Transparencia = 1, Radio = false,
                    })
                    if conTxt then
                        local bAcento = Utils.Frame({
                            Padre = fila, Size = UDim2.new(0, 3, 0, 16), Posicion = UDim2.new(0, 2, 0, 13),
                            Color = Theme.Accent, Radio = 2,
                        })
                        LouisHub:Registrar(bAcento, "BackgroundColor3", "Accent")
                        Utils.Texto({
                            Padre = fila, Texto = tostring(cfg.Texto), Size = UDim2.new(1, -16, 0, 22),
                            Posicion = UDim2.new(0, 14, 0, 10), Fuente = Enum.Font.FredokaOne, Tamano = 12,
                            ColorTema = "AccentLight", Truncar = true,
                        })
                    end
                    local line = Utils.Frame({
                        Padre = fila, Size = UDim2.new(1, 0, 0, 2), Posicion = UDim2.new(0, 0, 1, -4),
                        Color = Theme.Accent, Radio = false,
                    })
                    LouisHub:Registrar(line, "BackgroundColor3", "Accent")
                    return { Instancia = fila }
                end

                -- 16. IMAGEN
                function Seccion:Imagen(cfg)
                    cfg = cfg or {}
                    local aspectVal
                    if type(cfg.Aspecto) == "string" then
                        local w, h = cfg.Aspecto:match("^(%d+):(%d+)$")
                        if w and h and tonumber(h) > 0 then aspectVal = tonumber(w) / tonumber(h) end
                    elseif type(cfg.Aspecto) == "number" and cfg.Aspecto > 0 then
                        aspectVal = cfg.Aspecto
                    end
                    local altoFijo = math.clamp(cfg.Alto or 120, 40, 400)

                    local fila = Utils.Frame({
                        Padre = contenedor, Size = UDim2.new(1, 0, 0, aspectVal and 0 or altoFijo),
                        Transparencia = 1, Orden = nextOrder(), Radio = false,
                    })
                    if aspectVal then
                        local ac = Instance.new("UIAspectRatioConstraint", fila)
                        ac.AspectRatio = aspectVal
                        ac.DominantAxis = Enum.DominantAxis.Width
                    end
                    local img = Instance.new("ImageLabel", fila)
                    img.BackgroundColor3 = Theme.Fila
                    img.BorderSizePixel  = 0
                    img.Image            = type(cfg.Url) == "string" and cfg.Url or ""
                    img.ScaleType        = aspectVal and Enum.ScaleType.Crop or (cfg.Escala == "Crop" and Enum.ScaleType.Crop or Enum.ScaleType.Fit)
                    img.Size             = UDim2.new(1, 0, 1, 0)
                    Utils.Corner(img, cfg.Radio or 8)
                    LouisHub:Registrar(img, "BackgroundColor3", "Fila")

                    return {
                        Set = function(...)
                            local u = normalizeSetArg(...)
                            if type(u) == "string" then img.Image = u end
                        end,
                        Get = function() return img.Image end,
                        Instancia = img,
                    }
                end

                -- 17. GRUPO
                function Seccion:Grupo(cfg)
                    cfg = cfg or {}
                    local h = math.clamp(cfg.Alto or 32, 26, 60)
                    local filaG = Utils.Frame({
                        Padre = contenedor, Size = UDim2.new(1, 0, 0, h), Transparencia = 1, Orden = nextOrder(), Radio = false,
                    })
                    local lay = Instance.new("UIListLayout", filaG)
                    lay.FillDirection = Enum.FillDirection.Horizontal
                    lay.Padding       = UDim.new(0, 8)
                    lay.SortOrder     = Enum.SortOrder.LayoutOrder

                    local btns = {}
                    local function recalc()
                        local total = #btns
                        if total == 0 then return end
                        for i, b in ipairs(btns) do
                            b.Size = UDim2.new(1 / total, -math.ceil(8 * (total - 1) / total), 1, 0)
                        end
                    end

                    local grp = { Instancia = filaG }
                    function grp:Boton(cfgB)
                        local b = Seccion:Boton(cfgB or {})
                        local f = b.Fila or b.Instancia or b
                        f.Parent = filaG
                        table.insert(btns, f)
                        recalc()
                        return b
                    end
                    return grp
                end

                -- 18. TAG INPUT (CHIPS)
                function Seccion:TagInput(cfg)
                    cfg = cfg or {}
                    validarCallback("TagInput", cfg)
                    local flag      = cfg.Flag or cfg.Texto or ("TagInput_" .. math.random(1e5, 1e6))
                    local maxChars  = cfg.MaxCaracteres or 200
                    local maxTags   = cfg.MaxTags

                    local tags, tagsLower = {}, {}
                    for _, t in ipairs(cfg.Defecto or {}) do
                        if type(t) == "string" then
                            local cl = t:gsub("^%s+", ""):gsub("%s+$", "")
                            if cl ~= "" and not tagsLower[cl:lower()] then
                                table.insert(tags, cl)
                                tagsLower[cl:lower()] = true
                            end
                        end
                    end
                    local function getArr() return cloneTable(tags) end
                    LouisHub.Flags[flag] = getArr()

                    local fila = Utils.Fila(contenedor, 66, nextOrder(), Theme.Fila)
                    LouisHub:Registrar(fila, "BackgroundColor3", "Fila")
                    Utils.Hover(fila, fila)
                    registrarBuscable(fila, cfg.Texto or "TagInput", cfg.VisibleSi)

                    local lblT = Utils.Texto({ Padre = fila, Texto = cfg.Texto or "TagInput", Size = UDim2.new(1, -16, 0, 18), Posicion = UDim2.new(0, 8, 0, 6) })
                    agregarTooltipTexto(fila, cfg.Texto or "TagInput", cfg.Tooltip, lblT)

                    local contChips = Utils.Frame({
                        Padre = fila, Size = UDim2.new(1, -16, 0, 0), Posicion = UDim2.new(0, 8, 0, 28), Transparencia = 1, Radio = false,
                    })
                    local layChips = Instance.new("UIListLayout", contChips)
                    layChips.FillDirection = Enum.FillDirection.Horizontal
                    layChips.Wraps = true
                    layChips.Padding = UDim.new(0, 4)

                    local caja = Instance.new("TextBox", fila)
                    caja.Size             = UDim2.new(1, -16, 0, 26)
                    caja.Position         = UDim2.new(0, 8, 0, 32)
                    caja.BackgroundColor3 = Theme.Entrada
                    caja.PlaceholderText  = cfg.Placeholder or "Type & press Enter or comma..."
                    caja.Text             = ""
                    caja.TextColor3       = Theme.Highlight
                    caja.Font             = Enum.Font.Ubuntu
                    caja.TextSize         = 12
                    caja.BorderSizePixel  = 0
                    caja.ClearTextOnFocus = false
                    Utils.Corner(caja, 4)
                    LouisHub:Registrar(caja, "BackgroundColor3", "Entrada")
                    LouisHub:Registrar(caja, "TextColor3", "Highlight")

                    caja:GetPropertyChangedSignal("Text"):Connect(function()
                        if #caja.Text > maxChars then
                            caja.Text = caja.Text:sub(1, maxChars)
                            Utils.FlashFeedback(caja, false, Theme.Entrada)
                        end
                    end)

                    local renderChips

                    local function addTag(raw)
                        local cl = raw:gsub("^%s+", ""):gsub("%s+$", "")
                        if cl == "" or tagsLower[cl:lower()] then return false end
                        if maxTags and #tags >= maxTags then
                            Utils.FlashFeedback(caja, false, Theme.Entrada)
                            return false
                        end
                        table.insert(tags, cl)
                        tagsLower[cl:lower()] = true
                        return true
                    end

                    local function commit()
                        local changed = false
                        for frag in (caja.Text .. ","):gmatch("([^,]*),") do
                            if addTag(frag) then changed = true end
                        end
                        caja.Text = ""
                        if changed then
                            LouisHub.Flags[flag] = getArr()
                            renderChips(#tags)
                            if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto or "TagInput", getArr()) end
                        end
                    end
                    caja.FocusLost:Connect(commit)

                    LouisHub:RegistrarConexion(UserInputService.InputBegan:Connect(function(input, gpe)
                        if gpe then return end
                        if input.KeyCode == Enum.KeyCode.Backspace and caja:IsFocused() and caja.Text == "" and #tags > 0 then
                            local rm = table.remove(tags)
                            tagsLower[rm:lower()] = nil
                            LouisHub.Flags[flag] = getArr()
                            renderChips()
                            if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto or "TagInput", getArr()) end
                        end
                    end))

                    local function reLayoutChips()
                        if not (fila and fila.Parent) then return end
                        local e = Utils.FactorEscalaUI(fila)
                        local hC = (#tags > 0) and math.ceil(layChips.AbsoluteContentSize.Y / e) or 0
                        contChips.Size = UDim2.new(1, -16, 0, hC)
                        local yBox = 28 + hC + (hC > 0 and 6 or 4)
                        caja.Position = UDim2.new(0, 8, 0, yBox)
                        fila.Size = UDim2.new(1, 0, 0, yBox + 26 + 8)
                    end
                    LouisHub:RegistrarConexion(layChips:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(Utils.Diferir(reLayoutChips)))
                    LouisHub:RegistrarConexion(fila:GetPropertyChangedSignal("AbsoluteSize"):Connect(Utils.Diferir(reLayoutChips)))

                    renderChips = function(popIdx)
                        for _, c in ipairs(contChips:GetChildren()) do if not c:IsA("UIListLayout") then c:Destroy() end end
                        for i, t in ipairs(tags) do
                            local tw = anchoTexto(t, 12)
                            local ch = Utils.Frame({
                                Padre = contChips, Size = UDim2.new(0, tw + 34, 0, 24), Color = Theme.Accent, Radio = 12, Orden = i,
                            })
                            LouisHub:Registrar(ch, "BackgroundColor3", "Accent")
                            if popIdx and i == popIdx then
                                local sc = Instance.new("UIScale", ch)
                                sc.Scale = 0.6
                                Utils.Tween(sc, { Scale = 1 }, LouisHub.Motion.Expand, LouisHub.Motion.EasePop, Enum.EasingDirection.Out)
                            end
                            Utils.Texto({
                                Padre = ch, Texto = t, Size = UDim2.new(0, tw + 2, 1, 0), Posicion = UDim2.new(0, 10, 0, 0),
                                Tamano = 12, Fuente = Enum.Font.FredokaOne, Color = Color3.fromRGB(255, 255, 255), Categoria = "titulo",
                            })
                            local bx = Instance.new("TextButton", ch)
                            bx.BackgroundTransparency = 1
                            bx.Text = "×"
                            bx.Font = Enum.Font.FredokaOne
                            bx.TextSize = 16
                            bx.TextColor3 = Color3.fromRGB(255, 255, 255)
                            bx.Size = UDim2.new(0, 22, 1, 0)
                            bx.Position = UDim2.new(1, -24, 0, 0)
                            bx.MouseButton1Click:Connect(function()
                                local rm = table.remove(tags, i)
                                if rm then tagsLower[rm:lower()] = nil end
                                LouisHub.Flags[flag] = getArr()
                                renderChips()
                                if cfg.Callback then executeCallback(cfg.Callback, cfg.Texto or "TagInput", getArr()) end
                            end)
                        end
                        task.defer(reLayoutChips)
                    end
                    renderChips()

                    LouisHub.Elementos[flag] = {
                        Set = function(v, d)
                            tags, tagsLower = {}, {}
                            for _, t in ipairs(v or {}) do
                                if type(t) == "string" then
                                    local cl = t:gsub("^%s+", ""):gsub("%s+$", "")
                                    if cl ~= "" and not tagsLower[cl:lower()] then
                                        table.insert(tags, cl); tagsLower[cl:lower()] = true
                                    end
                                end
                            end
                            LouisHub.Flags[flag] = getArr()
                            renderChips()
                            if d and cfg.Callback then executeCallback(cfg.Callback, cfg.Texto or "TagInput", getArr()) end
                        end,
                        Get = getArr,
                    }
                    return {
                        Set = function(...) LouisHub.Elementos[flag].Set(normalizeSetArg(...), true) end,
                        Get = getArr,
                    }
                end

                -- Dynamic Novel Helpers for Section
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

                -- Schema Builder Dispatcher
                local SCHEMA_DISPATCH = {
                    Boton = Seccion.Boton, Toggle = Seccion.Toggle, Casilla = Seccion.Casilla,
                    Slider = Seccion.Slider, RangeSlider = Seccion.RangeSlider, NumberStepper = Seccion.NumberStepper,
                    Input = Seccion.Input, RadioGroup = Seccion.RadioGroup, Dropdown = Seccion.Dropdown,
                    ColorPicker = Seccion.ColorPicker, Keybind = Seccion.Keybind, Label = Seccion.Label,
                    Parrafo = Seccion.Parrafo, Progreso = Seccion.Progreso, Divider = Seccion.Divider,
                    Imagen = Seccion.Imagen, Grupo = Seccion.Grupo, TagInput = Seccion.TagInput,
                }

                function Seccion:Construir(lista)
                    local res = {}
                    if type(lista) ~= "table" then return res end
                    for i, def in ipairs(lista) do
                        if type(def) == "table" then
                            local fn = SCHEMA_DISPATCH[def.Control or def.Tipo]
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

                for _, name in ipairs({
                    "Boton", "Toggle", "Casilla", "Slider", "RangeSlider", "NumberStepper",
                    "Input", "TagInput", "Dropdown", "RadioGroup", "ColorPicker", "Keybind",
                }) do
                    Utils.EnvolverControlBloqueable(Seccion, contenedor, name)
                end

                return Seccion
            end

            if ventanaRevelada then
                Utils.FundirEntrada(botonLat, LouisHub.Motion.Expand, true)
                Utils.FundirEntrada(botonHoriz, LouisHub.Motion.Expand, true)
            end
            return Tab
        end

        function Ventana:ConstruirDesdeSchema(schema)
            local res = {}
            if type(schema) ~= "table" or type(schema.Tabs) ~= "table" then return res end
            for _, dTab in ipairs(schema.Tabs) do
                local tab = Ventana:CrearTab(dTab.Nombre or "Tab", dTab.Icono)
                for _, dSec in ipairs(dTab.Secciones or {}) do
                    local seccion = tab:CrearSeccion(dSec.Nombre or "Section", { Colapsable = dSec.Colapsable, ColapsadaPorDefecto = dSec.ColapsadaPorDefecto })
                    for flag, el in pairs(seccion:Construir(dSec.Controles or {})) do
                        if type(flag) == "string" then res[flag] = el end
                    end
                end
            end
            return res
        end

        function Ventana:CambiarOrientacion(mode)
            local nuevoH = (mode == "horizontal")
            if nuevoH == modoHorizontal then return end
            modoHorizontal = nuevoH
            barraLat.Visible = not modoHorizontal
            barraHoriz.Visible = modoHorizontal
            if self._buscadorBoxHoriz then self._buscadorBoxHoriz.Visible = modoHorizontal end
            local pos, sz = getPosContainer()
            Utils.Tween(contenedorPaginas, { Position = pos, Size = sz }, LouisHub.Motion.Page)
            for _, t in ipairs(self.Tabs) do
                local act = t.Pagina.Visible
                t.BotonLat.BackgroundColor3   = act and Theme.Accent or Theme.Fila
                t.BotonHoriz.BackgroundColor3 = act and Theme.Accent or Theme.Fila
            end
        end

        function Ventana:Destruir()
            if sg and sg.Parent then sg:Destroy() end
            themeRegistry = {}; indiceBusqueda = {}; textScaleRegistry = {};
            LouisHub.Elementos = createElementsTable(); _registeredKeybinds = {}; seccionesRegistradas = {};
        end
        function Ventana:Minimizar() alternarVentana(false) end
        function Ventana:Mostrar() alternarVentana(true) end
        function Ventana:EstaVisible() return ventanaAbierta end
        function Ventana:Resetear()
            for flag, elem in pairs(LouisHub.Elementos) do
                if elem._defecto ~= nil and not _uiFlags[flag] and not _nonPersistentFlags[flag] and type(elem.Set) == "function" then
                    pcall(elem.Set, copyDefault(elem._defecto), true)
                end
            end
        end
        function Ventana:CambiarTema(name)
            LouisHub.ThemeManager:AplicarTema(name)
            LouisHub:Notificar({ Titulo = "🎨 Theme", Texto = "'" .. name .. "' applied", Duracion = 2 })
        end

        function Ventana:CrearHUD(cfg) return LouisHub:CrearHUD(cfg) end
        function Ventana:CrearBotonFlotante(cfg) return LouisHub:CrearBotonFlotante(cfg) end

        -- Complete Preinstalled System Suite Tab
        function Ventana:AgregarPestanaPreinstalada(cfg)
            cfg = cfg or {}
            local sysTab = self:CrearTab(cfg.Nombre or "🔧 Suite", "🛠️")

            -- Section: System Information
            local secInfo = sysTab:CrearSeccion("System Metrics")
            secInfo:Label({ Texto = "Executor", Flag = "sys_exec", Valor = detectExecutor() })
            secInfo:Label({ Texto = "Engine Version", Flag = "sys_version", Valor = LouisHub.Version })
            secInfo:Label({ Texto = "Created By", Flag = "sys_creditos", Valor = "@LouisHub" })
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
                        local objCount = _uiInstanceCounter
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

            -- Section: Environment Diagnostics
            local secDiag = sysTab:CrearSeccion("🖥️ Environment Diagnostics")
            local C = LouisHub.Capacidades

            local function descEnv()
                local parts = { C.Tipo }
                if C.Plataforma then table.insert(parts, C:NombrePlataforma()) end
                local inp = C.EsTouchOnly and "Touch Only" or (C.TieneMouse and C.Teclado and "Mouse + Keyboard" or (C.TieneTouch and "Touch + Hybrid" or "Gamepad"))
                table.insert(parts, inp)
                return table.concat(parts, " · ")
            end

            secDiag:Label({ Texto = "Environment", Flag = "diag_entorno", Valor = descEnv() })
            secDiag:Label({ Texto = "Executor", Flag = "diag_ejecutor", Valor = detectExecutor() })
            secDiag:Label({ Texto = "Viewport", Flag = "diag_viewport", Valor = math.floor(C.ViewportSize.X) .. " x " .. math.floor(C.ViewportSize.Y) })

            local totalF, okF, warnsF = 0, 0, {}
            for _, f in ipairs(LouisHub.Features) do
                totalF = totalF + 1
                local r = LouisHub:VerificarSoporte(f.nombre)
                if r.ok then okF = okF + 1
                elseif f.nivel ~= "requerido" then table.insert(warnsF, { nombre = f.nombre, nivel = f.nivel, msg = r.mensaje }) end
            end

            secDiag:Label({ Texto = "Supported Features", Flag = "diag_features", Valor = okF .. "/" .. totalF .. " " .. (okF == totalF and "🟢" or "🟡") })

            if #warnsF > 0 then
                secDiag:Divider({ Texto = "⚠️ System Warnings" })
                for _, w in ipairs(warnsF) do
                    secDiag:Parrafo({ Titulo = ((w.nivel == "recomendado" and "🔴 " or "🟡 ") .. w.nombre), Contenido = w.msg })
                end
            end

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

            -- Section: Appearance Settings
            local secAp = sysTab:CrearSeccion("Interface Appearance")
            local tNombres = {}
            for n in pairs(LouisHub.ThemeManager.Temas) do table.insert(tNombres, n) end
            table.sort(tNombres)

            secAp:Dropdown({
                Texto = "🎨 Theme Style", Flag = "sys_tema", Opciones = tNombres,
                Defecto = Themes.Predeterminado,
                Callback = function(v) LouisHub.ThemeManager:AplicarTema(v) end,
            })
            secAp:Dropdown({
                Texto = "📐 Tab Layout", Flag = "sys_orientacion", Opciones = { "vertical", "horizontal" },
                Defecto = modoHorizontal and "horizontal" or "vertical",
                Callback = function(v) self:CambiarOrientacion(v) end,
            })
            secAp:Slider({
                Texto = "📏 Interface Scale", Flag = "sys_escala", Min = 70, Max = 130, Incremento = 5, Sufijo = "%", Defecto = 100,
                Callback = function(v) escalaManual = v / 100; recalcularEscala() end,
            })
            secAp:Slider({
                Texto = "↔️ Window Width Ratio", Flag = "sys_ancho", Min = 70, Max = 130, Incremento = 5, Sufijo = "%", Defecto = 100,
                Callback = function(v) factorAncho = v / 100; actualizarTamanoVentana(); recalcularEscala() end,
            })
            secAp:Slider({
                Texto = "↕️ Window Height Ratio", Flag = "sys_alto", Min = 70, Max = 130, Incremento = 5, Sufijo = "%", Defecto = 100,
                Callback = function(v) factorAlto = v / 100; actualizarTamanoVentana(); recalcularEscala() end,
            })
            secAp:Slider({
                Texto = "🔡 Global Text Scale", Flag = "sys_escala_texto", Min = 80, Max = 150, Incremento = 5, Sufijo = "%", Defecto = 100,
                Callback = function(v) applyTextScale("tabs", v / 100); applyTextScale("general", v / 100) end,
            })
            LouisHub:MarcarComoUI({ "sys_tema", "sys_orientacion", "sys_escala", "sys_ancho", "sys_alto", "sys_escala_texto" })

            -- Section: UI Profile Config
            local secCfg = sysTab:CrearSeccion("UI Settings Persistence")
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

            -- Section: Script Profiles Manager
            local secPerfiles = sysTab:CrearSeccion("Script Profile Manager")
            local selProfile = nil

            local dropProf = secPerfiles:Dropdown({
                Texto = "Active Profile", Flag = "sys_perfil_elegido", Opciones = LouisHub.SaveManager:Listar(),
                Callback = function(v) selProfile = v end,
            })
            LouisHub:MarcarComoUI("sys_perfil_elegido")

            secPerfiles:Boton({
                Texto = "🔄 Refresh List",
                Callback = function() dropProf.ActualizarOpciones(LouisHub.SaveManager:Listar()) end,
            })
            secPerfiles:Boton({
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

            secPerfiles:Boton({
                Texto = "💾 Save as New Profile", Async = true,
                Callback = function()
                    local name = LouisHub:ObtenerFlag("sys_nombre_nuevo_perfil")
                    if not name or name == "" then LouisHub:Notificar({ Titulo = "Profiles", Texto = "Enter a name first", Duracion = 3 }); return end
                    LouisHub.SaveManager:CambiarPerfil(self, name)
                    dropProf.ActualizarOpciones(LouisHub.SaveManager:Listar())
                end,
            })

            secPerfiles:Boton({
                Texto = "🗑️ Delete Selected Profile", Async = true,
                Callback = function()
                    if not selProfile then LouisHub:Notificar({ Titulo = "Profiles", Texto = "Select a profile first", Duracion = 3 }); return end
                    local okDel = LouisHub.SaveManager:Eliminar(selProfile)
                    LouisHub:Notificar({ Titulo = "Profiles", Texto = okDel and ("'" .. selProfile .. "' removed") or "Cannot delete", Duracion = 3 })
                    if okDel then
                        selProfile = nil
                        dropProf.ActualizarOpciones(LouisHub.SaveManager:Listar())
                    end
                end,
            })

            local function refreshProfiles() dropProf.ActualizarOpciones(LouisHub.SaveManager:Listar()) end

            secPerfiles:Input({
                Texto = "Profile JSON Text (Export / Import)", Flag = "sys_perfil_texto", Tipo = "textarea",
                Alto = 90, MaxCaracteres = 60000, Placeholder = "JSON text will appear here. Paste here to import...",
            })
            LouisHub:MarcarComoUI("sys_perfil_texto")

            local grpProfA = secPerfiles:Grupo()
            grpProfA:Boton({
                Texto = "📑 Duplicate",
                Callback = function()
                    local nName = LouisHub:ObtenerFlag("sys_nombre_nuevo_perfil")
                    if not selProfile or not nName or nName == "" then LouisHub:Notificar({ Titulo = "Profiles", Texto = "Select profile and enter new name", Duracion = 3 }); return end
                    local okDup, errDup = LouisHub.SaveManager:Duplicar(selProfile, nName)
                    LouisHub:Notificar({ Titulo = okDup and "📑 Duplicated" or "Error", Texto = okDup and nName or tostring(errDup), Duracion = 3 })
                    if okDup then refreshProfiles() end
                end,
            })
            grpProfA:Boton({
                Texto = "✏️ Rename",
                Callback = function()
                    local nName = LouisHub:ObtenerFlag("sys_nombre_nuevo_perfil")
                    if not selProfile or not nName or nName == "" then LouisHub:Notificar({ Titulo = "Profiles", Texto = "Select profile and enter new name", Duracion = 3 }); return end
                    local okRen, errRen = LouisHub.SaveManager:Renombrar(selProfile, nName)
                    LouisHub:Notificar({ Titulo = okRen and "✏️ Renamed" or "Error", Texto = okRen and nName or tostring(errRen), Duracion = 3 })
                    if okRen then selProfile = nil; refreshProfiles() end
                end,
            })

            local grpProfB = secPerfiles:Grupo()
            grpProfB:Boton({
                Texto = "📤 Export to Clipboard",
                Callback = function()
                    if not selProfile then LouisHub:Notificar({ Titulo = "Profiles", Texto = "Select a profile first", Duracion = 3 }); return end
                    local txt, cop = LouisHub.SaveManager:Exportar(selProfile)
                    if not txt then LouisHub:Notificar({ Titulo = "Export", Texto = tostring(cop), Duracion = 3 }); return end
                    LouisHub.Elementos["sys_perfil_texto"].Set(txt, false)
                    LouisHub:Notificar({ Titulo = "📤 Exported", Texto = cop and "Copied to clipboard" or "Written to textarea", Duracion = 3 })
                end,
            })
            grpProfB:Boton({
                Texto = "📥 Import from Text",
                Callback = function()
                    local nName = LouisHub:ObtenerFlag("sys_nombre_nuevo_perfil")
                    if not nName or nName == "" then LouisHub:Notificar({ Titulo = "Profiles", Texto = "Enter new profile name", Duracion = 3 }); return end
                    local okImp, errImp = LouisHub.SaveManager:Importar(nName, LouisHub:ObtenerFlag("sys_perfil_texto"))
                    LouisHub:Notificar({ Titulo = okImp and "📥 Imported" or "Error", Texto = okImp and nName or tostring(errImp), Duracion = 3 })
                    if okImp then refreshProfiles() end
                end,
            })

            -- Section: History
            local secHist = sysTab:CrearSeccion("Action History")
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
                pcall(function() lblHist.Set(txt) end)
            end))

            -- Section: Shortcuts Info
            local secAtajos = sysTab:CrearSeccion("Keyboard Shortcuts")
            secAtajos:Parrafo({
                Titulo    = "⌨️ Default Bindings",
                Contenido = "RightCtrl — Toggle GUI Visibility\n"
                         .. "Minimize (—) — Collapse to Floating Pill\n"
                         .. "Close (✕) — Destroy interface safely",
            })

            self._pestanaSistema = sysTab
            return sysTab
        end

        function Ventana:GuardarConfiguracion() return LouisHub.SaveManager:Guardar(Ventana.NombreConfig) end
        function Ventana:CargarConfiguracion() return LouisHub.SaveManager:Cargar(Ventana.NombreConfig) end

        if config.PestanaPreinstalada ~= false then
            Ventana:AgregarPestanaPreinstalada(type(config.PestanaPreinstalada) == "table" and config.PestanaPreinstalada or {})
        end

        if config.AutoGuardar ~= false and fsAvailable() then
            activeSaveWindow = Ventana
            task.defer(function()
                LouisHub.SaveManager:CargarSilencioso(Ventana.NombreConfig)
                LouisHub.SaveManager:CargarUI("preinstalada")
            end)
            sg.Destroying:Connect(function()
                autoSaveLoopRunning = false
                pcall(function() LouisHub.SaveManager:GuardarSilencioso(Ventana.NombreConfig) end)
            end)
            startAutoSaveLoop()
        end

        if _G.LouisHub_InstanciaActiva then _G.LouisHub_InstanciaActiva.Ventana = Ventana end
        return Ventana
    end)

    if not ok then
        warn("[LouisHub] Fatal window creation error:", resultado)
        local ghost = {}
        setmetatable(ghost, { __index = function() return function() return ghost end end })
        return ghost
    end
    return resultado
end

-- ===================================================================
--  SAFE WINDOW INITIALIZATION (ANTI-COLLISION / REMEMBER PREFERENCE)
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

    -- Wait for modal completion
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
