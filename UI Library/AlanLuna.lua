--[[
╔══════════════════════════════════════════════════════════════════════╗
                              AlanLuna
              Merged Suite: AlanUI v2.12.5 × Luna UI Beta 6.1
                      by AlanbeikersFF & Nebula Softworks
╚══════════════════════════════════════════════════════════════════════╝
]]

-- ══════════════════════════════════════════════════════════════
--  SECCION 1: POLYFILLS & LOW-LEVEL RUNTIME COMPATIBILITY
-- ══════════════════════════════════════════════════════════════
if type(task) ~= "table" then task = {} end
if type(task.wait) ~= "function" then
    task.wait = function(t)
        if type(wait) == "function" then return wait(t) end
        return t or 0
    end
end
if type(task.spawn) ~= "function" then
    task.spawn = function(f, ...)
        if type(spawn) == "function" then
            return spawn(function(...) f(...) end, ...)
        end
        local co = coroutine.create(f)
        local ok, err = coroutine.resume(co, ...)
        if not ok then warn("[AlanLuna] Polyfill task.spawn error:", err) end
        return co
    end
end
if type(task.delay) ~= "function" then
    task.delay = function(t, f, ...)
        local args = {...}
        if type(delay) == "function" then
            delay(t, function() f(table.unpack(args)) end)
        else
            coroutine.wrap(function()
                if type(wait) == "function" then wait(t) end
                f(table.unpack(args))
            end)()
        end
    end
end
if type(task.defer) ~= "function" then task.defer = task.spawn end
if type(task.cancel) ~= "function" then
    task.cancel = function(hilo)
        if type(hilo) == "thread" then
            pcall(function()
                if coroutine.status(hilo) ~= "dead" and coroutine.close then
                    coroutine.close(hilo)
                end
            end)
        end
    end
end

local function clonarTabla(t)
    if type(t) ~= "table" then return {} end
    if type(table.clone) == "function" then return table.clone(t) end
    local copia = {}
    for clave, valor in pairs(t) do copia[clave] = valor end
    return copia
end

local function copiarDefecto(v)
    if type(v) == "table" then return clonarTabla(v) end
    return v
end

local function normalizarArgSet(...)
    if select('#', ...) >= 2 then
        return (select(2, ...))
    end
    return (select(1, ...))
end

local function Kwargify(defaults, passed)
    passed = passed or {}
    for i, v in pairs(defaults) do
        if passed[i] == nil then
            passed[i] = v
        end
    end
    return passed
end

local function PackColor(Color)
    return {R = Color.R * 255, G = Color.G * 255, B = Color.B * 255}
end

local function UnpackColor(Color)
    return Color3.fromRGB(Color.R, Color.G, Color.B)
end

-- ══════════════════════════════════════════════════════════════
--  SECCION 2: SERVICES & ENVIRONMENT INITIALIZATION
-- ══════════════════════════════════════════════════════════════
local UserInputService = game:GetService("UserInputService")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")
local RunService       = game:GetService("RunService")
local Localization     = game:GetService("LocalizationService")
local Players          = game:GetService("Players")
local Workspace        = game:GetService("Workspace")
local Lighting         = game:GetService("Lighting")
local CoreGui          = game:GetService("CoreGui")
local TextService      = game:GetService("TextService")
local LocalPlayer      = Players.LocalPlayer

local isStudio = RunService:IsStudio()
local request = (syn and syn.request) or (http and http.request) or http_request or nil

local function fsDisponible()
    return type(writefile) == "function" and type(readfile) == "function"
end

local function obtenerPadreGui()
    local ok, hui = pcall(function() return gethui() end)
    if ok and hui then return hui end
    return LocalPlayer:WaitForChild("PlayerGui")
end

local function protegerGui(gui)
    pcall(function()
        if syn and syn.protect_gui then
            syn.protect_gui(gui)
        elseif protectgui then
            protectgui(gui)
        end
    end)
end

-- ══════════════════════════════════════════════════════════════
--  SECCION 3: ALANLUNA NAMESPACE & REGISTRO DE AUTO-LIMPIEZA
-- ══════════════════════════════════════════════════════════════
local AlanLuna = {}
AlanLuna.Version = "3.0.0"
AlanLuna.DebugMode = false
AlanLuna.MostrarErroresEnUI = true
AlanLuna.Folder = "AlanUI/Config"

-- FIX UTAMA: Deklarasikan alias AlanUI dan Luna sedini mungkin agar tidak nil!
local AlanUI = AlanLuna
local Luna = AlanLuna

_G.AlanLuna = AlanLuna
_G.AlanUI = AlanLuna
_G.Luna = AlanLuna

local function limpiarInstanciaPrevia()
    local previa = _G.AlanLuna_Instancia
    if type(previa) ~= "table" then return end

    for _, conexion in ipairs(previa.Conexiones or {}) do
        pcall(function()
            if conexion and conexion.Connected then conexion:Disconnect() end
        end)
    end

    for _, hilo in ipairs(previa.Hilos or {}) do
        pcall(function()
            if hilo and coroutine.status(hilo) ~= "dead" then task.cancel(hilo) end
        end)
    end

    for _, objeto in ipairs(previa.Dibujos or {}) do
        pcall(function() if objeto then objeto:Remove() end end)
    end

    for _, inst in ipairs(previa.Instancias or {}) do
        pcall(function() if inst and inst.Parent then inst:Destroy() end end)
    end

    pcall(function()
        local padre = obtenerPadreGui()
        for _, nombreGui in ipairs({"AlanLuna_ScreenGui", "AlanLuna_NotifGui", "AlanLuna_TooltipOverlay", "AlanLuna_PopupGui"}) do
            local viejo = padre:FindFirstChild(nombreGui)
            if viejo then viejo:Destroy() end
        end
    end)
end

limpiarInstanciaPrevia()

_G.AlanLuna_Instancia = {
    Conexiones = {},
    Hilos = {},
    Dibujos = {},
    Instancias = {},
    Ventana = nil,
    Titulo = "AlanLuna",
}

function AlanLuna:RegistrarConexion(conexion)
    if _G.AlanLuna_Instancia and conexion then
        table.insert(_G.AlanLuna_Instancia.Conexiones, conexion)
    end
    return conexion
end

function AlanLuna:DesconectarYLimpiar(conexion)
    if not conexion then return end
    pcall(function() conexion:Disconnect() end)
    if _G.AlanLuna_Instancia then
        local lista = _G.AlanLuna_Instancia.Conexiones
        local idx = table.find(lista, conexion)
        if idx then table.remove(lista, idx) end
    end
end

function AlanLuna:RegistrarHilo(hilo)
    if _G.AlanLuna_Instancia and hilo then
        table.insert(_G.AlanLuna_Instancia.Hilos, hilo)
    end
    return hilo
end

function AlanLuna:RegistrarDibujo(objetoDrawing)
    if _G.AlanLuna_Instancia and objetoDrawing then
        table.insert(_G.AlanLuna_Instancia.Dibujos, objetoDrawing)
    end
    return objetoDrawing
end

function AlanLuna:RegistrarInstancia(instancia)
    if _G.AlanLuna_Instancia and instancia then
        table.insert(_G.AlanLuna_Instancia.Instancias, instancia)
    end
    return instancia
end

-- ══════════════════════════════════════════════════════════════
--  SECCION 4: ICON MODULE (COMPLETO DE LUNA UI)
-- ══════════════════════════════════════════════════════════════
local IconModule = {
    Lucide = nil,
    Material = {
        ["perm_media"] = "http://www.roblox.com/asset/?id=6031215982",
        ["sticky_note_2"] = "http://www.roblox.com/asset/?id=6031265972",
        ["gavel"] = "http://www.roblox.com/asset/?id=6023565902",
        ["table_view"] = "http://www.roblox.com/asset/?id=6031233835",
        ["home"] = "http://www.roblox.com/asset/?id=6026568195",
        ["list"] = "http://www.roblox.com/asset/?id=6026568229",
        ["alarm_add"] = "http://www.roblox.com/asset/?id=6023426898",
        ["speaker_notes"] = "http://www.roblox.com/asset/?id=6031266001",
        ["check_circle_outline"] = "http://www.roblox.com/asset/?id=6023426909",
        ["extension"] = "http://www.roblox.com/asset/?id=6023565892",
        ["pending"] = "http://www.roblox.com/asset/?id=6031084745",
        ["pageview"] = "http://www.roblox.com/asset/?id=6031216007",
        ["group_work"] = "http://www.roblox.com/asset/?id=6023565910",
        ["zoom_in"] = "http://www.roblox.com/asset/?id=6031075573",
        ["aspect_ratio"] = "http://www.roblox.com/asset/?id=6022668895",
        ["code"] = "http://www.roblox.com/asset/?id=6022668955",
        ["3d_rotation"] = "http://www.roblox.com/asset/?id=6022668893",
        ["translate"] = "http://www.roblox.com/asset/?id=6031225812",
        ["star_rate"] = "http://www.roblox.com/asset/?id=6031265978",
        ["system_update_alt"] = "http://www.roblox.com/asset/?id=6031251515",
        ["open_with"] = "http://www.roblox.com/asset/?id=6026568265",
        ["build_circle"] = "http://www.roblox.com/asset/?id=6023426952",
        ["toc"] = "http://www.roblox.com/asset/?id=6031229341",
        ["settings_phone"] = "http://www.roblox.com/asset/?id=6031289445",
        ["open_in_full"] = "http://www.roblox.com/asset/?id=6026568245",
        ["history"] = "http://www.roblox.com/asset/?id=6026568197",
        ["accessibility_new"] = "http://www.roblox.com/asset/?id=6022668945",
        ["hourglass_disabled"] = "http://www.roblox.com/asset/?id=6026568193",
        ["line_style"] = "http://www.roblox.com/asset/?id=6026568276",
        ["account_circle"] = "http://www.roblox.com/asset/?id=6022668898",
        ["settings_cell"] = "http://www.roblox.com/asset/?id=6031280890",
        ["search_off"] = "http://www.roblox.com/asset/?id=6031260783",
        ["shop"] = "http://www.roblox.com/asset/?id=6031265983",
        ["anchor"] = "http://www.roblox.com/asset/?id=6023426906",
        ["language"] = "http://www.roblox.com/asset/?id=6026568213",
        ["settings_brightness"] = "http://www.roblox.com/asset/?id=6031280902",
        ["restore_page"] = "http://www.roblox.com/asset/?id=6031154877",
        ["chrome_reader_mode"] = "http://www.roblox.com/asset/?id=6023426912",
        ["sync_alt"] = "http://www.roblox.com/asset/?id=6031233840",
        ["book"] = "http://www.roblox.com/asset/?id=6022860343",
        ["smart_button"] = "http://www.roblox.com/asset/?id=6031265962",
        ["request_page"] = "http://www.roblox.com/asset/?id=6031154873",
        ["lock_clock"] = "http://www.roblox.com/asset/?id=6026568260",
        ["android"] = "http://www.roblox.com/asset/?id=6022668966",
        ["outgoing_mail"] = "http://www.roblox.com/asset/?id=6026568242",
        ["dynamic_form"] = "http://www.roblox.com/asset/?id=6023426970",
        ["track_changes"] = "http://www.roblox.com/asset/?id=6031225814",
        ["source"] = "http://www.roblox.com/asset/?id=6031289451",
        ["thumb_down"] = "http://www.roblox.com/asset/?id=6031229336",
        ["integration_instructions"] = "http://www.roblox.com/asset/?id=6026568214",
        ["opacity"] = "http://www.roblox.com/asset/?id=6026568295",
        ["perm_identity"] = "http://www.roblox.com/asset/?id=6031215978",
        ["view_module"] = "http://www.roblox.com/asset/?id=6031079152",
        ["perm_data_setting"] = "http://www.roblox.com/asset/?id=6031215991",
        ["assignment_turned_in"] = "http://www.roblox.com/asset/?id=6023426904",
        ["change_history"] = "http://www.roblox.com/asset/?id=6023426914",
        ["thumb_down_off_alt"] = "http://www.roblox.com/asset/?id=6031229354",
        ["text_rotation_angledown"] = "http://www.roblox.com/asset/?id=6031251513",
        ["bookmark"] = "http://www.roblox.com/asset/?id=6022852108",
        ["view_stream"] = "http://www.roblox.com/asset/?id=6031079164",
        ["remove_done"] = "http://www.roblox.com/asset/?id=6031086169",
        ["markunread_mailbox"] = "http://www.roblox.com/asset/?id=6031082531",
        ["store"] = "http://www.roblox.com/asset/?id=6031265968",
        ["text_rotation_angleup"] = "http://www.roblox.com/asset/?id=6031229337",
        ["eco"] = "http://www.roblox.com/asset/?id=6023426988",
        ["find_in_page"] = "http://www.roblox.com/asset/?id=6023426986",
        ["api"] = "http://www.roblox.com/asset/?id=6022668911",
        ["launch"] = "http://www.roblox.com/asset/?id=6026568211",
        ["text_rotation_down"] = "http://www.roblox.com/asset/?id=6031229334",
        ["flip_to_back"] = "http://www.roblox.com/asset/?id=6023565896",
        ["contact_page"] = "http://www.roblox.com/asset/?id=6022668881",
        ["preview"] = "http://www.roblox.com/asset/?id=6031260793",
        ["restore"] = "http://www.roblox.com/asset/?id=6031260800",
        ["favorite_border"] = "http://www.roblox.com/asset/?id=6023565882",
        ["assignment_late"] = "http://www.roblox.com/asset/?id=6022668880",
        ["youtube_searched_for"] = "http://www.roblox.com/asset/?id=6031075934",
        ["hourglass_full"] = "http://www.roblox.com/asset/?id=6026568190",
        ["timeline"] = "http://www.roblox.com/asset/?id=6031229350",
        ["turned_in"] = "http://www.roblox.com/asset/?id=6031225808",
        ["info"] = "http://www.roblox.com/asset/?id=6026568227",
        ["restore_from_trash"] = "http://www.roblox.com/asset/?id=6031154869",
        ["arrow_circle_down"] = "http://www.roblox.com/asset/?id=6022668877",
        ["flaky"] = "http://www.roblox.com/asset/?id=6031082523",
        ["alarm_on"] = "http://www.roblox.com/asset/?id=6023426920",
        ["swap_vertical_circle"] = "http://www.roblox.com/asset/?id=6031233839",
        ["open_in_new"] = "http://www.roblox.com/asset/?id=6026568256",
        ["watch_later"] = "http://www.roblox.com/asset/?id=6031075924",
        ["alarm_off"] = "http://www.roblox.com/asset/?id=6023426901",
        ["maximize"] = "http://www.roblox.com/asset/?id=6026568267",
        ["lock_outline"] = "http://www.roblox.com/asset/?id=6031082533",
        ["outbond"] = "http://www.roblox.com/asset/?id=6026568244",
        ["view_carousel"] = "http://www.roblox.com/asset/?id=6031251507",
        ["published_with_changes"] = "http://www.roblox.com/asset/?id=6031243328",
        ["verified_user"] = "http://www.roblox.com/asset/?id=6031225819",
        ["drag_indicator"] = "http://www.roblox.com/asset/?id=6023426962",
        ["lightbulb_outline"] = "http://www.roblox.com/asset/?id=6026568254",
        ["segment"] = "http://www.roblox.com/asset/?id=6031260773",
        ["assignment"] = "http://www.roblox.com/asset/?id=6022668882",
        ["work_outline"] = "http://www.roblox.com/asset/?id=6031075930",
        ["line_weight"] = "http://www.roblox.com/asset/?id=6026568226",
        ["dangerous"] = "http://www.roblox.com/asset/?id=6022668916",
        ["assessment"] = "http://www.roblox.com/asset/?id=6022668897",
        ["view_day"] = "http://www.roblox.com/asset/?id=6031079153",
        ["help_center"] = "http://www.roblox.com/asset/?id=6026568192",
        ["logout"] = "http://www.roblox.com/asset/?id=6031082522",
        ["event"] = "http://www.roblox.com/asset/?id=6023426959",
        ["get_app"] = "http://www.roblox.com/asset/?id=6023565889",
        ["tab"] = "http://www.roblox.com/asset/?id=6031233851",
        ["label"] = "http://www.roblox.com/asset/?id=6031082525",
        ["g_translate"] = "http://www.roblox.com/asset/?id=6031082526",
        ["view_week"] = "http://www.roblox.com/asset/?id=6031079154",
        ["view_in_ar"] = "http://www.roblox.com/asset/?id=6031079158",
        ["card_travel"] = "http://www.roblox.com/asset/?id=6023426925",
        ["lock_open"] = "http://www.roblox.com/asset/?id=6026568220",
        ["voice_over_off"] = "http://www.roblox.com/asset/?id=6031075927",
        ["app_blocking"] = "http://www.roblox.com/asset/?id=6022668952",
        ["settings_ethernet"] = "http://www.roblox.com/asset/?id=6031280883",
        ["supervised_user_circle"] = "http://www.roblox.com/asset/?id=6031289449",
        ["done_all"] = "http://www.roblox.com/asset/?id=6023426929",
        ["lightbulb"] = "http://www.roblox.com/asset/?id=6026568247",
        ["find_replace"] = "http://www.roblox.com/asset/?id=6023426979",
        ["bookmarks"] = "http://www.roblox.com/asset/?id=6023426924",
        ["today"] = "http://www.roblox.com/asset/?id=6031229352",
        ["class"] = "http://www.roblox.com/asset/?id=6022668949",
        ["supervisor_account"] = "http://www.roblox.com/asset/?id=6031251516",
        ["support"] = "http://www.roblox.com/asset/?id=6031251532",
        ["done_outline"] = "http://www.roblox.com/asset/?id=6023426936",
        ["reorder"] = "http://www.roblox.com/asset/?id=6031154868",
        ["fact_check"] = "http://www.roblox.com/asset/?id=6023426951",
        ["thumb_up"] = "http://www.roblox.com/asset/?id=6031229347",
        ["assignment_returned"] = "http://www.roblox.com/asset/?id=6023426899",
        ["card_giftcard"] = "http://www.roblox.com/asset/?id=6023426978",
        ["trending_down"] = "http://www.roblox.com/asset/?id=6031225811",
        ["settings_backup_restore"] = "http://www.roblox.com/asset/?id=6031280886",
        ["settings_voice"] = "http://www.roblox.com/asset/?id=6031265966",
        ["dns"] = "http://www.roblox.com/asset/?id=6023426958",
        ["perm_scan_wifi"] = "http://www.roblox.com/asset/?id=6031215985",
        ["plagiarism"] = "http://www.roblox.com/asset/?id=6031243320",
        ["commute"] = "http://www.roblox.com/asset/?id=6022668901",
        ["gif"] = "http://www.roblox.com/asset/?id=6031082540",
        ["work"] = "http://www.roblox.com/asset/?id=6031075939",
        ["picture_in_picture_alt"] = "http://www.roblox.com/asset/?id=6031215979",
        ["query_builder"] = "http://www.roblox.com/asset/?id=6031086183",
        ["label_off"] = "http://www.roblox.com/asset/?id=6026568209",
        ["all_out"] = "http://www.roblox.com/asset/?id=6022668876",
        ["article"] = "http://www.roblox.com/asset/?id=6022668907",
        ["shopping_basket"] = "http://www.roblox.com/asset/?id=6031265997",
        ["mark_as_unread"] = "http://www.roblox.com/asset/?id=6026568223",
        ["work_off"] = "http://www.roblox.com/asset/?id=6031075937",
        ["delete_outline"] = "http://www.roblox.com/asset/?id=6022668962",
        ["account_box"] = "http://www.roblox.com/asset/?id=6023426915",
        ["home_filled"] = "rbxassetid://9080449299",
        ["lock"] = "http://www.roblox.com/asset/?id=6026568224",
        ["perm_device_information"] = "http://www.roblox.com/asset/?id=6031215996",
        ["add_task"] = "http://www.roblox.com/asset/?id=6022668912",
        ["text_rotate_up"] = "http://www.roblox.com/asset/?id=6031251526",
        ["swipe"] = "http://www.roblox.com/asset/?id=6031233863",
        ["eject"] = "http://www.roblox.com/asset/?id=6023426930",
        ["mediation"] = "http://www.roblox.com/asset/?id=6026568249",
        ["label_important_outline"] = "http://www.roblox.com/asset/?id=6026568199",
        ["settings_remote"] = "http://www.roblox.com/asset/?id=6031289442",
        ["history_toggle_off"] = "http://www.roblox.com/asset/?id=6026568196",
        ["invert_colors"] = "http://www.roblox.com/asset/?id=6026568253",
        ["visibility_off"] = "http://www.roblox.com/asset/?id=6031075929",
        ["addchart"] = "http://www.roblox.com/asset/?id=6023426905",
        ["cancel_schedule_send"] = "http://www.roblox.com/asset/?id=6022668963",
        ["loyalty"] = "http://www.roblox.com/asset/?id=6026568237",
        ["speaker_notes_off"] = "http://www.roblox.com/asset/?id=6031265965",
        ["online_prediction"] = "http://www.roblox.com/asset/?id=6026568239",
        ["remove_shopping_cart"] = "http://www.roblox.com/asset/?id=6031260778",
        ["text_rotate_vertical"] = "http://www.roblox.com/asset/?id=6031251518",
        ["visibility"] = "http://www.roblox.com/asset/?id=6031075931",
        ["add_to_drive"] = "http://www.roblox.com/asset/?id=6022860335",
        ["accessible"] = "http://www.roblox.com/asset/?id=6022668902",
        ["bookmark_border"] = "http://www.roblox.com/asset/?id=6022860339",
        ["tour"] = "http://www.roblox.com/asset/?id=6031229362",
        ["compare_arrows"] = "http://www.roblox.com/asset/?id=6022668951",
        ["view_sidebar"] = "http://www.roblox.com/asset/?id=6031079160",
        ["face"] = "http://www.roblox.com/asset/?id=6023426944",
        ["wysiwyg"] = "http://www.roblox.com/asset/?id=6031075938",
        ["camera_enhance"] = "http://www.roblox.com/asset/?id=6023426935",
        ["perm_camera_mic"] = "http://www.roblox.com/asset/?id=6031215983",
        ["model_training"] = "http://www.roblox.com/asset/?id=6026568222",
        ["arrow_circle_up"] = "http://www.roblox.com/asset/?id=6022668934",
        ["euro_symbol"] = "http://www.roblox.com/asset/?id=6023426954",
        ["pending_actions"] = "http://www.roblox.com/asset/?id=6031260777",
        ["not_accessible"] = "http://www.roblox.com/asset/?id=6026568269",
        ["explore_off"] = "http://www.roblox.com/asset/?id=6023426953",
        ["build"] = "http://www.roblox.com/asset/?id=6023426938",
        ["backup"] = "http://www.roblox.com/asset/?id=6023426911",
        ["settings_input_antenna"] = "http://www.roblox.com/asset/?id=6031280891",
        ["disabled_by_default"] = "http://www.roblox.com/asset/?id=6023426939",
        ["upgrade"] = "http://www.roblox.com/asset/?id=6031225815",
        ["contactless"] = "http://www.roblox.com/asset/?id=6022668886",
        ["trending_flat"] = "http://www.roblox.com/asset/?id=6031225818",
        ["schedule"] = "http://www.roblox.com/asset/?id=6031260808",
        ["offline_pin"] = "http://www.roblox.com/asset/?id=6031084770",
        ["date_range"] = "http://www.roblox.com/asset/?id=6022668894",
        ["flight_land"] = "http://www.roblox.com/asset/?id=6023565897",
        ["view_headline"] = "http://www.roblox.com/asset/?id=6031079151",
        ["cached"] = "http://www.roblox.com/asset/?id=6023426921",
        ["unpublished"] = "http://www.roblox.com/asset/?id=6031225817",
        ["outlet"] = "http://www.roblox.com/asset/?id=6031084748",
        ["favorite"] = "http://www.roblox.com/asset/?id=6023426974",
        ["vertical_split"] = "http://www.roblox.com/asset/?id=6031225820",
        ["report_problem"] = "http://www.roblox.com/asset/?id=6031086176",
        ["fingerprint"] = "http://www.roblox.com/asset/?id=6023565895",
        ["important_devices"] = "http://www.roblox.com/asset/?id=6026568202",
        ["outbox"] = "http://www.roblox.com/asset/?id=6026568263",
        ["all_inbox"] = "http://www.roblox.com/asset/?id=6022668909",
        ["label_important"] = "http://www.roblox.com/asset/?id=6026568215",
        ["print"] = "http://www.roblox.com/asset/?id=6031243324",
        ["settings_bluetooth"] = "http://www.roblox.com/asset/?id=6031280905",
        ["power_settings_new"] = "http://www.roblox.com/asset/?id=6031260781",
        ["zoom_out"] = "http://www.roblox.com/asset/?id=6031075577",
        ["stars"] = "http://www.roblox.com/asset/?id=6031265971",
        ["offline_bolt"] = "http://www.roblox.com/asset/?id=6031084742",
        ["feedback"] = "http://www.roblox.com/asset/?id=6023426957",
        ["accessibility"] = "http://www.roblox.com/asset/?id=6022668887",
        ["announcement"] = "http://www.roblox.com/asset/?id=6022668946",
        ["settings_input_hdmi"] = "http://www.roblox.com/asset/?id=6031280970",
        ["leaderboard"] = "http://www.roblox.com/asset/?id=6026568216",
        ["view_quilt"] = "http://www.roblox.com/asset/?id=6031079155",
        ["note_add"] = "http://www.roblox.com/asset/?id=6031084749",
        ["theaters"] = "http://www.roblox.com/asset/?id=6031229335",
        ["alarm"] = "http://www.roblox.com/asset/?id=6023426910",
        ["settings_input_composite"] = "http://www.roblox.com/asset/?id=6031280896",
        ["grade"] = "http://www.roblox.com/asset/?id=6026568189",
        ["tab_unselected"] = "http://www.roblox.com/asset/?id=6031251505",
        ["swap_vert"] = "http://www.roblox.com/asset/?id=6031233847",
        ["assignment_return"] = "http://www.roblox.com/asset/?id=6023426931",
        ["highlight_alt"] = "http://www.roblox.com/asset/?id=6023565913",
        ["shopping_bag"] = "http://www.roblox.com/asset/?id=6031265970",
        ["contact_support"] = "http://www.roblox.com/asset/?id=6022668879",
        ["flip_to_front"] = "http://www.roblox.com/asset/?id=6023565894",
        ["touch_app"] = "http://www.roblox.com/asset/?id=6031229361",
        ["room"] = "http://www.roblox.com/asset/?id=6031154875",
        ["send_and_archive"] = "http://www.roblox.com/asset/?id=6031280889",
        ["view_array"] = "http://www.roblox.com/asset/?id=6031225842",
        ["settings_power"] = "http://www.roblox.com/asset/?id=6031289446",
        ["admin_panel_settings"] = "http://www.roblox.com/asset/?id=6022668961",
        ["open_in_browser"] = "http://www.roblox.com/asset/?id=6026568266",
        ["card_membership"] = "http://www.roblox.com/asset/?id=6023426942",
        ["rule"] = "http://www.roblox.com/asset/?id=6031154859",
        ["schedule_send"] = "http://www.roblox.com/asset/?id=6031154866",
        ["calendar_today"] = "http://www.roblox.com/asset/?id=6022668917",
        ["info_outline"] = "http://www.roblox.com/asset/?id=6026568210",
        ["description"] = "http://www.roblox.com/asset/?id=6022668888",
        ["dashboard_customize"] = "http://www.roblox.com/asset/?id=6022668899",
        ["rowing"] = "http://www.roblox.com/asset/?id=6031154857",
        ["swap_horizontal_circle"] = "http://www.roblox.com/asset/?id=6031233833",
        ["account_balance_wallet"] = "http://www.roblox.com/asset/?id=6022668892",
        ["view_agenda"] = "http://www.roblox.com/asset/?id=6031225831",
        ["shop_two"] = "http://www.roblox.com/asset/?id=6031289461",
        ["done"] = "http://www.roblox.com/asset/?id=6023426926",
        ["circle_notifications"] = "http://www.roblox.com/asset/?id=6023426923",
        ["compress"] = "http://www.roblox.com/asset/?id=6022668878",
        ["calendar_view_day"] = "http://www.roblox.com/asset/?id=6023426946",
        ["thumbs_up_down"] = "http://www.roblox.com/asset/?id=6031229373",
        ["account_balance"] = "http://www.roblox.com/asset/?id=6022668900",
        ["play_for_work"] = "http://www.roblox.com/asset/?id=6031260776",
        ["pets"] = "http://www.roblox.com/asset/?id=6031260782",
        ["view_column"] = "http://www.roblox.com/asset/?id=6031079172",
        ["search"] = "http://www.roblox.com/asset/?id=6031154871",
        ["autorenew"] = "http://www.roblox.com/asset/?id=6023565901",
        ["copyright"] = "http://www.roblox.com/asset/?id=6023565898",
        ["privacy_tip"] = "http://www.roblox.com/asset/?id=6031260784",
        ["arrow_right_alt"] = "http://www.roblox.com/asset/?id=6022668890",
        ["delete"] = "http://www.roblox.com/asset/?id=6022668885",
        ["nightlight_round"] = "http://www.roblox.com/asset/?id=6031084743",
        ["batch_prediction"] = "http://www.roblox.com/asset/?id=6022860334",
        ["shopping_cart"] = "http://www.roblox.com/asset/?id=6031265976",
        ["login"] = "http://www.roblox.com/asset/?id=6031082527",
        ["settings_input_svideo"] = "http://www.roblox.com/asset/?id=6031289444",
        ["payment"] = "http://www.roblox.com/asset/?id=6031084751",
        ["update"] = "http://www.roblox.com/asset/?id=6031225810",
        ["text_rotation_none"] = "http://www.roblox.com/asset/?id=6031229344",
        ["perm_contact_calendar"] = "http://www.roblox.com/asset/?id=6031215990",
        ["explore"] = "http://www.roblox.com/asset/?id=6023426941",
        ["delete_forever"] = "http://www.roblox.com/asset/?id=6022668939",
        ["rounded_corner"] = "http://www.roblox.com/asset/?id=6031154861",
        ["book_online"] = "http://www.roblox.com/asset/?id=6022860332",
        ["quickreply"] = "http://www.roblox.com/asset/?id=6031243319",
        ["bug_report"] = "http://www.roblox.com/asset/?id=6022852107",
        ["subtitles_off"] = "http://www.roblox.com/asset/?id=6031289466",
        ["close_fullscreen"] = "http://www.roblox.com/asset/?id=6023426928",
        ["horizontal_split"] = "http://www.roblox.com/asset/?id=6026568194",
        ["minimize"] = "http://www.roblox.com/asset/?id=6026568240",
        ["filter_list_alt"] = "http://www.roblox.com/asset/?id=6023426955",
        ["add_shopping_cart"] = "http://www.roblox.com/asset/?id=6022668875",
        ["next_plan"] = "http://www.roblox.com/asset/?id=6026568231",
        ["view_list"] = "http://www.roblox.com/asset/?id=6031079156",
        ["receipt"] = "http://www.roblox.com/asset/?id=6031086173",
        ["polymer"] = "http://www.roblox.com/asset/?id=6031260785",
        ["spellcheck"] = "http://www.roblox.com/asset/?id=6031289450",
        ["wifi_protected_setup"] = "http://www.roblox.com/asset/?id=6031075926",
        ["label_outline"] = "http://www.roblox.com/asset/?id=6026568207",
        ["highlight_off"] = "http://www.roblox.com/asset/?id=6023565916",
        ["turned_in_not"] = "http://www.roblox.com/asset/?id=6031225806",
        ["edit_off"] = "http://www.roblox.com/asset/?id=6023426983",
        ["question_answer"] = "http://www.roblox.com/asset/?id=6031086172",
        ["settings_overscan"] = "http://www.roblox.com/asset/?id=6031289459",
        ["trending_up"] = "http://www.roblox.com/asset/?id=6031225816",
        ["verified"] = "http://www.roblox.com/asset/?id=6031225809",
        ["flight_takeoff"] = "http://www.roblox.com/asset/?id=6023565891",
        ["grading"] = "http://www.roblox.com/asset/?id=6026568191",
        ["dashboard"] = "http://www.roblox.com/asset/?id=6022668883",
        ["expand"] = "http://www.roblox.com/asset/?id=6022668891",
        ["backup_table"] = "http://www.roblox.com/asset/?id=6022860338",
        ["analytics"] = "http://www.roblox.com/asset/?id=6022668884",
        ["picture_in_picture"] = "http://www.roblox.com/asset/?id=6031215994",
        ["settings"] = "http://www.roblox.com/asset/?id=6031280882",
        ["accessible_forward"] = "http://www.roblox.com/asset/?id=6022668906",
        ["pan_tool"] = "http://www.roblox.com/asset/?id=6031084771",
        ["https"] = "http://www.roblox.com/asset/?id=6026568200",
        ["filter_alt"] = "http://www.roblox.com/asset/?id=6023426984",
        ["thumb_up_off_alt"] = "http://www.roblox.com/asset/?id=6031229342",
        ["record_voice_over"] = "http://www.roblox.com/asset/?id=6031243318",
        ["help_outline"] = "http://www.roblox.com/asset/?id=6026568201",
        ["check_circle"] = "http://www.roblox.com/asset/?id=6023426945",
        ["comment_bank"] = "http://www.roblox.com/asset/?id=6023426937",
        ["perm_phone_msg"] = "http://www.roblox.com/asset/?id=6031215986",
        ["settings_applications"] = "http://www.roblox.com/asset/?id=6031280894",
        ["exit_to_app"] = "http://www.roblox.com/asset/?id=6023426922",
        ["saved_search"] = "http://www.roblox.com/asset/?id=6031154867",
        ["toll"] = "http://www.roblox.com/asset/?id=6031229343",
        ["not_started"] = "http://www.roblox.com/asset/?id=6026568232",
        ["subject"] = "http://www.roblox.com/asset/?id=6031289452",
        ["redeem"] = "http://www.roblox.com/asset/?id=6031086170",
        ["input"] = "http://www.roblox.com/asset/?id=6026568225",
        ["settings_input_component"] = "http://www.roblox.com/asset/?id=6031280884",
        ["assignment_ind"] = "http://www.roblox.com/asset/?id=6022668935",
        ["swap_horiz"] = "http://www.roblox.com/asset/?id=6031233841",
        ["fullscreen"] = "http://www.roblox.com/asset/?id=6031094681",
        ["cancel"] = "http://www.roblox.com/asset/?id=6031094677",
        ["subdirectory_arrow_left"] = "http://www.roblox.com/asset/?id=6031104654",
        ["close"] = "http://www.roblox.com/asset/?id=6031094678",
        ["arrow_back_ios"] = "http://www.roblox.com/asset/?id=6031091003",
        ["east"] = "http://www.roblox.com/asset/?id=6031094675",
        ["unfold_more"] = "http://www.roblox.com/asset/?id=6031104644",
        ["south"] = "http://www.roblox.com/asset/?id=6031104646",
        ["arrow_drop_up"] = "http://www.roblox.com/asset/?id=6031090990",
        ["arrow_back"] = "http://www.roblox.com/asset/?id=6031091000",
        ["arrow_downward"] = "http://www.roblox.com/asset/?id=6031090991",
        ["west"] = "http://www.roblox.com/asset/?id=6031104677",
        ["legend_toggle"] = "http://www.roblox.com/asset/?id=6031097233",
        ["fullscreen_exit"] = "http://www.roblox.com/asset/?id=6031094691",
        ["last_page"] = "http://www.roblox.com/asset/?id=6031094686",
        ["switch_right"] = "http://www.roblox.com/asset/?id=6031104649",
        ["check"] = "http://www.roblox.com/asset/?id=6031094667",
        ["home_work"] = "http://www.roblox.com/asset/?id=6031094683",
        ["north_east"] = "http://www.roblox.com/asset/?id=6031097228",
        ["double_arrow"] = "http://www.roblox.com/asset/?id=6031094674",
        ["more_vert"] = "http://www.roblox.com/asset/?id=6031104648",
        ["chevron_left"] = "http://www.roblox.com/asset/?id=6031094670",
        ["more_horiz"] = "http://www.roblox.com/asset/?id=6031104650",
        ["unfold_less"] = "http://www.roblox.com/asset/?id=6031104681",
        ["first_page"] = "http://www.roblox.com/asset/?id=6031094682",
        ["payments"] = "http://www.roblox.com/asset/?id=6031097227",
        ["arrow_right"] = "http://www.roblox.com/asset/?id=6031090994",
        ["offline_share"] = "http://www.roblox.com/asset/?id=6031097267",
        ["south_west"] = "http://www.roblox.com/asset/?id=6031104652",
        ["expand_less"] = "http://www.roblox.com/asset/?id=6031094679",
        ["south_east"] = "http://www.roblox.com/asset/?id=6031104642",
        ["assistant_navigation"] = "http://www.roblox.com/asset/?id=6031091006",
        ["apps"] = "http://www.roblox.com/asset/?id=6031090999",
        ["arrow_upward"] = "http://www.roblox.com/asset/?id=6031090997",
        ["app_settings_alt"] = "http://www.roblox.com/asset/?id=6031090998",
        ["subdirectory_arrow_right"] = "http://www.roblox.com/asset/?id=6031104647",
        ["north_west"] = "http://www.roblox.com/asset/?id=6031104630",
        ["switch_left"] = "http://www.roblox.com/asset/?id=6031104651",
        ["chevron_right"] = "http://www.roblox.com/asset/?id=6031094680",
        ["arrow_forward"] = "http://www.roblox.com/asset/?id=6031090995",
        ["arrow_forward_ios"] = "http://www.roblox.com/asset/?id=6031091008",
        ["arrow_drop_down"] = "http://www.roblox.com/asset/?id=6031091004",
        ["refresh"] = "http://www.roblox.com/asset/?id=6031097226",
        ["pivot_table_chart"] = "http://www.roblox.com/asset/?id=6031097234",
        ["expand_more"] = "http://www.roblox.com/asset/?id=6031094687",
        ["campaign"] = "http://www.roblox.com/asset/?id=6031094666",
        ["arrow_left"] = "http://www.roblox.com/asset/?id=6031091002",
        ["arrow_drop_down_circle"] = "http://www.roblox.com/asset/?id=6031091001",
        ["menu_open"] = "http://www.roblox.com/asset/?id=6031097229",
        ["waterfall_chart"] = "http://www.roblox.com/asset/?id=6031104632",
        ["assistant_direction"] = "http://www.roblox.com/asset/?id=6031091005",
        ["menu"] = "http://www.roblox.com/asset/?id=6031097225",
        ["personal_video"] = "http://www.roblox.com/asset/?id=6034457070",
        ["power_off"] = "http://www.roblox.com/asset/?id=6034457087",
        ["wifi_off"] = "http://www.roblox.com/asset/?id=6034461625",
        ["adb"] = "http://www.roblox.com/asset/?id=6034418515",
        ["airline_seat_recline_normal"] = "http://www.roblox.com/asset/?id=6034418512",
        ["sync_problem"] = "http://www.roblox.com/asset/?id=6034452653",
        ["network_check"] = "http://www.roblox.com/asset/?id=6034461631",
        ["event_busy"] = "http://www.roblox.com/asset/?id=6034439634",
        ["airline_seat_flat"] = "http://www.roblox.com/asset/?id=6034418511",
        ["disc_full"] = "http://www.roblox.com/asset/?id=6034418518",
        ["sd_card"] = "http://www.roblox.com/asset/?id=6034457089",
        ["time_to_leave"] = "http://www.roblox.com/asset/?id=6034452660",
        ["phone_bluetooth_speaker"] = "http://www.roblox.com/asset/?id=6034457057",
        ["phone_paused"] = "http://www.roblox.com/asset/?id=6034457066",
        ["phone_locked"] = "http://www.roblox.com/asset/?id=6034457058",
        ["more"] = "http://www.roblox.com/asset/?id=6034461627",
        ["add_call"] = "http://www.roblox.com/asset/?id=6034418524",
        ["account_tree"] = "http://www.roblox.com/asset/?id=6034418507",
        ["do_not_disturb_on"] = "http://www.roblox.com/asset/?id=6034439649",
        ["event_note"] = "http://www.roblox.com/asset/?id=6034439637",
        ["sync_disabled"] = "http://www.roblox.com/asset/?id=6034452649",
        ["mms"] = "http://www.roblox.com/asset/?id=6034461621",
        ["airline_seat_flat_angled"] = "http://www.roblox.com/asset/?id=6034418513",
        ["bluetooth_audio"] = "http://www.roblox.com/asset/?id=6034418522",
        ["vibration"] = "http://www.roblox.com/asset/?id=6034452651",
        ["system_update"] = "http://www.roblox.com/asset/?id=6034452663",
        ["enhanced_encryption"] = "http://www.roblox.com/asset/?id=6034439652",
        ["wc"] = "http://www.roblox.com/asset/?id=6034452643",
        ["live_tv"] = "http://www.roblox.com/asset/?id=6034439648",
        ["folder_special"] = "http://www.roblox.com/asset/?id=6034439639",
        ["phone_missed"] = "http://www.roblox.com/asset/?id=6034457056",
        ["airline_seat_recline_extra"] = "http://www.roblox.com/asset/?id=6034418528",
        ["sms"] = "http://www.roblox.com/asset/?id=6034452645",
        ["tap_and_play"] = "http://www.roblox.com/asset/?id=6034452650",
        ["confirmation_number"] = "http://www.roblox.com/asset/?id=6034418519",
        ["event_available"] = "http://www.roblox.com/asset/?id=6034439643",
        ["sms_failed"] = "http://www.roblox.com/asset/?id=6034452676",
        ["do_not_disturb_alt"] = "http://www.roblox.com/asset/?id=6034461619",
        ["do_not_disturb"] = "http://www.roblox.com/asset/?id=6034439645",
        ["ondemand_video"] = "http://www.roblox.com/asset/?id=6034457065",
        ["no_encryption"] = "http://www.roblox.com/asset/?id=6034457059",
        ["airline_seat_legroom_extra"] = "http://www.roblox.com/asset/?id=6034418508",
        ["tv_off"] = "http://www.roblox.com/asset/?id=6034452646",
        ["sim_card_alert"] = "http://www.roblox.com/asset/?id=6034452641",
        ["airline_seat_legroom_normal"] = "http://www.roblox.com/asset/?id=6034418532",
        ["wifi"] = "http://www.roblox.com/asset/?id=6034461626",
        ["do_not_disturb_off"] = "http://www.roblox.com/asset/?id=6034439642",
        ["imagesearch_roller"] = "http://www.roblox.com/asset/?id=6034439635",
        ["power"] = "http://www.roblox.com/asset/?id=6034457105",
        ["airline_seat_legroom_reduced"] = "http://www.roblox.com/asset/?id=6034418520",
        ["phone_in_talk"] = "http://www.roblox.com/asset/?id=6034457067",
        ["airline_seat_individual_suite"] = "http://www.roblox.com/asset/?id=6034418514",
        ["priority_high"] = "http://www.roblox.com/asset/?id=6034457092",
        ["phone_callback"] = "http://www.roblox.com/asset/?id=6034457104",
        ["phone_forwarded"] = "http://www.roblox.com/asset/?id=6034457106",
        ["sync"] = "http://www.roblox.com/asset/?id=6034452662",
        ["vpn_lock"] = "http://www.roblox.com/asset/?id=6034452648",
        ["support_agent"] = "http://www.roblox.com/asset/?id=6034452656",
        ["network_locked"] = "http://www.roblox.com/asset/?id=6034457064",
        ["directions_off"] = "http://www.roblox.com/asset/?id=6034418517",
        ["drive_eta"] = "http://www.roblox.com/asset/?id=6034464371",
        ["sensor_window"] = "http://www.roblox.com/asset/?id=6031067242",
        ["sensor_door"] = "http://www.roblox.com/asset/?id=6031067241",
        ["keyboard_return"] = "http://www.roblox.com/asset/?id=6034818370",
        ["monitor"] = "http://www.roblox.com/asset/?id=6034837803",
        ["device_hub"] = "http://www.roblox.com/asset/?id=6034789877",
        ["keyboard"] = "http://www.roblox.com/asset/?id=6034818398",
        ["keyboard_voice"] = "http://www.roblox.com/asset/?id=6034818360",
        ["cast"] = "http://www.roblox.com/asset/?id=6034789876",
        ["developer_board"] = "http://www.roblox.com/asset/?id=6034789883",
        ["tablet"] = "http://www.roblox.com/asset/?id=6034848733",
        ["keyboard_hide"] = "http://www.roblox.com/asset/?id=6034818386",
        ["dock"] = "http://www.roblox.com/asset/?id=6034789888",
        ["phonelink"] = "http://www.roblox.com/asset/?id=6034837801",
        ["device_unknown"] = "http://www.roblox.com/asset/?id=6034789884",
        ["speaker_group"] = "http://www.roblox.com/asset/?id=6034848732",
        ["desktop_mac"] = "http://www.roblox.com/asset/?id=6034789898",
        ["point_of_sale"] = "http://www.roblox.com/asset/?id=6034837798",
        ["memory"] = "http://www.roblox.com/asset/?id=6034837807",
        ["keyboard_tab"] = "http://www.roblox.com/asset/?id=6034818363",
        ["router"] = "http://www.roblox.com/asset/?id=6034837806",
        ["sim_card"] = "http://www.roblox.com/asset/?id=6034837800",
        ["headset"] = "http://www.roblox.com/asset/?id=6034789880",
        ["gamepad"] = "http://www.roblox.com/asset/?id=6034789879",
        ["speaker"] = "http://www.roblox.com/asset/?id=6034848746",
        ["devices_other"] = "http://www.roblox.com/asset/?id=6034789873",
        ["laptop"] = "http://www.roblox.com/asset/?id=6034818367",
        ["scanner"] = "http://www.roblox.com/asset/?id=6034837799",
        ["tv"] = "http://www.roblox.com/asset/?id=6034848740",
        ["headset_mic"] = "http://www.roblox.com/asset/?id=6034818383",
        ["browser_not_supported"] = "http://www.roblox.com/asset/?id=6034789875",
        ["computer"] = "http://www.roblox.com/asset/?id=6034789874",
        ["connected_tv"] = "http://www.roblox.com/asset/?id=6034789870",
        ["phonelink_off"] = "http://www.roblox.com/asset/?id=6034837804",
        ["headset_off"] = "http://www.roblox.com/asset/?id=6034818402",
        ["cast_connected"] = "http://www.roblox.com/asset/?id=6034789895",
        ["watch"] = "http://www.roblox.com/asset/?id=6034848747",
        ["keyboard_arrow_up"] = "http://www.roblox.com/asset/?id=6034818379",
        ["keyboard_backspace"] = "http://www.roblox.com/asset/?id=6034818381",
        ["laptop_chromebook"] = "http://www.roblox.com/asset/?id=6034818364",
        ["phone_iphone"] = "http://www.roblox.com/asset/?id=6034837811",
        ["smartphone"] = "http://www.roblox.com/asset/?id=6034848731",
        ["power_input"] = "http://www.roblox.com/asset/?id=6034837794",
        ["videogame_asset"] = "http://www.roblox.com/asset/?id=6034848748",
        ["desktop_windows"] = "http://www.roblox.com/asset/?id=6034789893",
        ["keyboard_arrow_down"] = "http://www.roblox.com/asset/?id=6034818372",
        ["laptop_mac"] = "http://www.roblox.com/asset/?id=6034837808",
        ["laptop_windows"] = "http://www.roblox.com/asset/?id=6034837796",
        ["keyboard_arrow_right"] = "http://www.roblox.com/asset/?id=6034818365",
        ["cast_for_education"] = "http://www.roblox.com/asset/?id=6034789872",
        ["keyboard_capslock"] = "http://www.roblox.com/asset/?id=6034818403",
        ["toys"] = "http://www.roblox.com/asset/?id=6034848752",
        ["tablet_android"] = "http://www.roblox.com/asset/?id=6034848734",
        ["mouse"] = "http://www.roblox.com/asset/?id=6034837797",
        ["phone_android"] = "http://www.roblox.com/asset/?id=6034837793",
        ["keyboard_arrow_left"] = "http://www.roblox.com/asset/?id=6034818375",
        ["security"] = "http://www.roblox.com/asset/?id=6034837802",
        ["dry_cleaning"] = "http://www.roblox.com/asset/?id=6034754456",
        ["bakery_dining"] = "http://www.roblox.com/asset/?id=6034767610",
        ["place"] = "http://www.roblox.com/asset/?id=6034503372",
        ["run_circle"] = "http://www.roblox.com/asset/?id=6034503367",
        ["local_post_office"] = "http://www.roblox.com/asset/?id=6034513883",
        ["takeout_dining"] = "http://www.roblox.com/asset/?id=6034467808",
        ["nightlife"] = "http://www.roblox.com/asset/?id=6034510003",
        ["design_services"] = "http://www.roblox.com/asset/?id=6034754453",
        ["celebration"] = "http://www.roblox.com/asset/?id=6034767613",
        ["near_me_disabled"] = "http://www.roblox.com/asset/?id=6034509988",
        ["add_location_alt"] = "http://www.roblox.com/asset/?id=6034483678",
        ["directions_run"] = "http://www.roblox.com/asset/?id=6034754445",
        ["local_fire_department"] = "http://www.roblox.com/asset/?id=6034684949",
        ["add_road"] = "http://www.roblox.com/asset/?id=6034483677",
        ["my_location"] = "http://www.roblox.com/asset/?id=6034509987",
        ["dinner_dining"] = "http://www.roblox.com/asset/?id=6034754457",
        ["local_airport"] = "http://www.roblox.com/asset/?id=6034687951",
        ["zoom_out_map"] = "http://www.roblox.com/asset/?id=6035229856",
        ["pin_drop"] = "http://www.roblox.com/asset/?id=6034470807",
        ["subway"] = "http://www.roblox.com/asset/?id=6034467790",
        ["electric_moped"] = "http://www.roblox.com/asset/?id=6034744027",
        ["restaurant_menu"] = "http://www.roblox.com/asset/?id=6034503378",
        ["local_gas_station"] = "http://www.roblox.com/asset/?id=6034684935",
        ["local_cafe"] = "http://www.roblox.com/asset/?id=6034687954",
        ["theater_comedy"] = "http://www.roblox.com/asset/?id=6034467796",
        ["directions_bus"] = "http://www.roblox.com/asset/?id=6034754434",
        ["hail"] = "http://www.roblox.com/asset/?id=6034744033",
        ["satellite"] = "http://www.roblox.com/asset/?id=6034503370",
        ["local_phone"] = "http://www.roblox.com/asset/?id=6034513884",
        ["electric_bike"] = "http://www.roblox.com/asset/?id=6034744032",
        ["local_see"] = "http://www.roblox.com/asset/?id=6034513887",
        ["transit_enterexit"] = "http://www.roblox.com/asset/?id=6034467805",
        ["local_convenience_store"] = "http://www.roblox.com/asset/?id=6034687956",
        ["local_offer"] = "http://www.roblox.com/asset/?id=6034513891",
        ["electric_car"] = "http://www.roblox.com/asset/?id=6034744029",
        ["beenhere"] = "http://www.roblox.com/asset/?id=6034483675",
        ["miscellaneous_services"] = "http://www.roblox.com/asset/?id=6034509993",
        ["maps_ugc"] = "http://www.roblox.com/asset/?id=6034509992",
        ["moped"] = "http://www.roblox.com/asset/?id=6034509999",
        ["medical_services"] = "http://www.roblox.com/asset/?id=6034510001",
        ["money"] = "http://www.roblox.com/asset/?id=6034509997",
        ["transfer_within_a_station"] = "http://www.roblox.com/asset/?id=6034467809",
        ["electrical_services"] = "http://www.roblox.com/asset/?id=6034744038",
        ["museum"] = "http://www.roblox.com/asset/?id=6034510005",
        ["add_location"] = "http://www.roblox.com/asset/?id=6034483672",
        ["layers"] = "http://www.roblox.com/asset/?id=6034687957",
        ["handyman"] = "http://www.roblox.com/asset/?id=6034744057",
        ["local_pharmacy"] = "http://www.roblox.com/asset/?id=6034513903",
        ["electric_rickshaw"] = "http://www.roblox.com/asset/?id=6034744043",
        ["alt_route"] = "http://www.roblox.com/asset/?id=6034483670",
        ["no_transfer"] = "http://www.roblox.com/asset/?id=6034503363",
        ["pedal_bike"] = "http://www.roblox.com/asset/?id=6034503374",
        ["directions_transit"] = "http://www.roblox.com/asset/?id=6034754436",
        ["railway_alert"] = "http://www.roblox.com/asset/?id=6034470823",
        ["local_police"] = "http://www.roblox.com/asset/?id=6034513895",
        ["directions_car"] = "http://www.roblox.com/asset/?id=6034754441",
        ["category"] = "http://www.roblox.com/asset/?id=6034767621",
        ["attractions"] = "http://www.roblox.com/asset/?id=6034767620",
        ["person_pin_circle"] = "http://www.roblox.com/asset/?id=6034503375",
        ["cleaning_services"] = "http://www.roblox.com/asset/?id=6034767619",
        ["terrain"] = "http://www.roblox.com/asset/?id=6034467794",
        ["no_meals"] = "http://www.roblox.com/asset/?id=6034510024",
        ["train"] = "http://www.roblox.com/asset/?id=6034467803",
        ["delivery_dining"] = "http://www.roblox.com/asset/?id=6034767644",
        ["pest_control"] = "http://www.roblox.com/asset/?id=6034470809",
        ["directions"] = "http://www.roblox.com/asset/?id=6034754449",
        ["atm"] = "http://www.roblox.com/asset/?id=6034767614",
        ["rate_review"] = "http://www.roblox.com/asset/?id=6034503385",
        ["local_bar"] = "http://www.roblox.com/asset/?id=6034687950",
        ["local_drink"] = "http://www.roblox.com/asset/?id=6034687965",
        ["directions_railway"] = "http://www.roblox.com/asset/?id=6034754433",
        ["person_pin"] = "http://www.roblox.com/asset/?id=6034503364",
        ["ev_station"] = "http://www.roblox.com/asset/?id=6034744037",
        ["home_repair_service"] = "http://www.roblox.com/asset/?id=6034744064",
        ["bus_alert"] = "http://www.roblox.com/asset/?id=6034767618",
        ["agriculture"] = "http://www.roblox.com/asset/?id=6034483674",
        ["volunteer_activism"] = "http://www.roblox.com/asset/?id=6034467799",
        ["breakfast_dining"] = "http://www.roblox.com/asset/?id=6034483671",
        ["layers_clear"] = "http://www.roblox.com/asset/?id=6034687975",
        ["plumbing"] = "http://www.roblox.com/asset/?id=6034470800",
        ["taxi_alert"] = "http://www.roblox.com/asset/?id=6034467792",
        ["add_business"] = "http://www.roblox.com/asset/?id=6034483666",
        ["badge"] = "http://www.roblox.com/asset/?id=6034767607",
        ["edit_attributes"] = "http://www.roblox.com/asset/?id=6034754443",
        ["directions_walk"] = "http://www.roblox.com/asset/?id=6034754448",
        ["local_play"] = "http://www.roblox.com/asset/?id=6034513889",
        ["bike_scooter"] = "http://www.roblox.com/asset/?id=6034483669",
        ["two_wheeler"] = "http://www.roblox.com/asset/?id=6034467795",
        ["local_florist"] = "http://www.roblox.com/asset/?id=6034684940",
        ["local_hotel"] = "http://www.roblox.com/asset/?id=6034684939",
        ["no_meals_ouline"] = "http://www.roblox.com/asset/?id=6034510025",
        ["festival"] = "http://www.roblox.com/asset/?id=6034744031",
        ["local_shipping"] = "http://www.roblox.com/asset/?id=6034684926",
        ["directions_boat"] = "http://www.roblox.com/asset/?id=6034754442",
        ["wrong_location"] = "http://www.roblox.com/asset/?id=6034467801",
        ["restaurant"] = "http://www.roblox.com/asset/?id=6034503366",
        ["directions_subway"] = "http://www.roblox.com/asset/?id=6034754440",
        ["not_listed_location"] = "http://www.roblox.com/asset/?id=6034503380",
        ["electric_scooter"] = "http://www.roblox.com/asset/?id=6034744041",
        ["ramen_dining"] = "http://www.roblox.com/asset/?id=6034503377",
        ["edit_road"] = "http://www.roblox.com/asset/?id=6034744035",
        ["local_printshop"] = "http://www.roblox.com/asset/?id=6034513897",
        ["map"] = "http://www.roblox.com/asset/?id=6034684930",
        ["car_rental"] = "http://www.roblox.com/asset/?id=6034767641",
        ["multiple_stop"] = "http://www.roblox.com/asset/?id=6034510026",
        ["brunch_dining"] = "http://www.roblox.com/asset/?id=6034767611",
        ["local_laundry_service"] = "http://www.roblox.com/asset/?id=6034684943",
        ["set_meal"] = "http://www.roblox.com/asset/?id=6034503368",
        ["local_car_wash"] = "http://www.roblox.com/asset/?id=6034687976",
        ["pest_control_rodent"] = "http://www.roblox.com/asset/?id=6034470803",
        ["local_pizza"] = "http://www.roblox.com/asset/?id=6034513885",
        ["local_grocery_store"] = "http://www.roblox.com/asset/?id=6034684933",
        ["traffic"] = "http://www.roblox.com/asset/?id=6034467797",
        ["departure_board"] = "http://www.roblox.com/asset/?id=6034767615",
        ["icecream"] = "http://www.roblox.com/asset/?id=6034687967",
        ["navigation"] = "http://www.roblox.com/asset/?id=6034509984",
        ["near_me"] = "http://www.roblox.com/asset/?id=6034509996",
        ["fastfood"] = "http://www.roblox.com/asset/?id=6034744034",
        ["local_library"] = "http://www.roblox.com/asset/?id=6034684931",
        ["local_activity"] = "http://www.roblox.com/asset/?id=6034687955",
        ["local_hospital"] = "http://www.roblox.com/asset/?id=6034684956",
        ["menu_book"] = "http://www.roblox.com/asset/?id=6034509994",
        ["directions_bike"] = "http://www.roblox.com/asset/?id=6034754459",
        ["store_mall_directory"] = "http://www.roblox.com/asset/?id=6034470811",
        ["trip_origin"] = "http://www.roblox.com/asset/?id=6034467804",
        ["tram"] = "http://www.roblox.com/asset/?id=6034467806",
        ["edit_location"] = "http://www.roblox.com/asset/?id=6034754439",
        ["streetview"] = "http://www.roblox.com/asset/?id=6034470805",
        ["hvac"] = "http://www.roblox.com/asset/?id=6034687960",
        ["lunch_dining"] = "http://www.roblox.com/asset/?id=6034684928",
        ["car_repair"] = "http://www.roblox.com/asset/?id=6034767617",
        ["compass_calibration"] = "http://www.roblox.com/asset/?id=6034767623",
        ["360"] = "http://www.roblox.com/asset/?id=6034767608",
        ["flight"] = "http://www.roblox.com/asset/?id=6034744030",
        ["local_mall"] = "http://www.roblox.com/asset/?id=6034684934",
        ["hotel"] = "http://www.roblox.com/asset/?id=6034687977",
        ["local_parking"] = "http://www.roblox.com/asset/?id=6034513893",
        ["hardware"] = "http://www.roblox.com/asset/?id=6034744036",
        ["local_dining"] = "http://www.roblox.com/asset/?id=6034687963",
        ["park"] = "http://www.roblox.com/asset/?id=6034503369",
        ["location_pin"] = "http://www.roblox.com/asset/?id=6034684937",
        ["local_movies"] = "http://www.roblox.com/asset/?id=6034684936",
        ["local_atm"] = "http://www.roblox.com/asset/?id=6034687953",
        ["local_taxi"] = "http://www.roblox.com/asset/?id=6034684927",
        ["brightness_low"] = "http://www.roblox.com/asset/?id=6034989542",
        ["screen_lock_landscape"] = "http://www.roblox.com/asset/?id=6034996700",
        ["graphic_eq"] = "http://www.roblox.com/asset/?id=6034989551",
        ["screen_lock_rotation"] = "http://www.roblox.com/asset/?id=6034996710",
        ["signal_cellular_4_bar"] = "http://www.roblox.com/asset/?id=6035030076",
        ["airplanemode_inactive"] = "http://www.roblox.com/asset/?id=6034983848",
        ["signal_wifi_0_bar"] = "http://www.roblox.com/asset/?id=6035030067",
        ["battery_full"] = "http://www.roblox.com/asset/?id=6034983854",
        ["gps_fixed"] = "http://www.roblox.com/asset/?id=6034989550",
        ["brightness_high"] = "http://www.roblox.com/asset/?id=6034989541",
        ["ad_units"] = "http://www.roblox.com/asset/?id=6034983845",
        ["signal_cellular_alt"] = "http://www.roblox.com/asset/?id=6035030079",
        ["bluetooth_connected"] = "http://www.roblox.com/asset/?id=6034983855",
        ["wifi_tethering"] = "http://www.roblox.com/asset/?id=6035039430",
        ["dvr"] = "http://www.roblox.com/asset/?id=6034989561",
        ["screen_search_desktop"] = "http://www.roblox.com/asset/?id=6034996711",
        ["network_wifi"] = "http://www.roblox.com/asset/?id=6034996712",
        ["access_alarms"] = "http://www.roblox.com/asset/?id=6034983853",
        ["nfc"] = "http://www.roblox.com/asset/?id=6034996698",
        ["location_disabled"] = "http://www.roblox.com/asset/?id=6034996694",
        ["signal_wifi_4_bar"] = "http://www.roblox.com/asset/?id=6035030077",
        ["access_time"] = "http://www.roblox.com/asset/?id=6034983856",
        ["mobile_off"] = "http://www.roblox.com/asset/?id=6034996702",
        ["battery_unknown"] = "http://www.roblox.com/asset/?id=6034983842",
        ["signal_cellular_null"] = "http://www.roblox.com/asset/?id=6035030075",
        ["bluetooth_disabled"] = "http://www.roblox.com/asset/?id=6034989562",
        ["developer_mode"] = "http://www.roblox.com/asset/?id=6034989549",
        ["network_cell"] = "http://www.roblox.com/asset/?id=6034996709",
        ["sd_storage"] = "http://www.roblox.com/asset/?id=6034996719",
        ["signal_cellular_no_sim"] = "http://www.roblox.com/asset/?id=6035030078",
        ["devices"] = "http://www.roblox.com/asset/?id=6034989540",
        ["screen_rotation"] = "http://www.roblox.com/asset/?id=6034996701",
        ["device_thermostat"] = "http://www.roblox.com/asset/?id=6034989544",
        ["signal_wifi_off"] = "http://www.roblox.com/asset/?id=6035030074",
        ["widgets"] = "http://www.roblox.com/asset/?id=6035039429",
        ["bluetooth"] = "http://www.roblox.com/asset/?id=6034983880",
        ["battery_charging_full"] = "http://www.roblox.com/asset/?id=6034983849",
        ["mobile_friendly"] = "http://www.roblox.com/asset/?id=6034996699",
        ["signal_cellular_0_bar"] = "http://www.roblox.com/asset/?id=6035030072",
        ["storage"] = "http://www.roblox.com/asset/?id=6035030083",
        ["send_to_mobile"] = "http://www.roblox.com/asset/?id=6034996697",
        ["location_searching"] = "http://www.roblox.com/asset/?id=6034996695",
        ["brightness_auto"] = "http://www.roblox.com/asset/?id=6034989545",
        ["wifi_lock"] = "http://www.roblox.com/asset/?id=6035039428",
        ["gps_not_fixed"] = "http://www.roblox.com/asset/?id=6034989547",
        ["access_alarm"] = "http://www.roblox.com/asset/?id=6034983844",
        ["battery_alert"] = "http://www.roblox.com/asset/?id=6034983843",
        ["signal_cellular_off"] = "http://www.roblox.com/asset/?id=6035030084",
        ["signal_cellular_connected_no_internet_4"] = "http://www.roblox.com/asset/?id=6035229858",
        ["gps_off"] = "http://www.roblox.com/asset/?id=6034989548",
        ["add_alarm"] = "http://www.roblox.com/asset/?id=6034983850",
        ["brightness_medium"] = "http://www.roblox.com/asset/?id=6034989543",
        ["usb"] = "http://www.roblox.com/asset/?id=6035030080",
        ["airplanemode_active"] = "http://www.roblox.com/asset/?id=6034983864",
        ["reset_tv"] = "http://www.roblox.com/asset/?id=6034996696",
        ["wallpaper"] = "http://www.roblox.com/asset/?id=6035030102",
        ["settings_system_daydream"] = "http://www.roblox.com/asset/?id=6035030081",
        ["bluetooth_searching"] = "http://www.roblox.com/asset/?id=6034989553",
        ["add_to_home_screen"] = "http://www.roblox.com/asset/?id=6034983858",
        ["screen_lock_portrait"] = "http://www.roblox.com/asset/?id=6034996706",
        ["data_usage"] = "http://www.roblox.com/asset/?id=6034989568",
        ["_auto_delete"] = "http://www.roblox.com/asset/?id=6031071068",
        ["_error"] = "http://www.roblox.com/asset/?id=6031071057",
        ["_notification_important"] = "http://www.roblox.com/asset/?id=6031071056",
        ["_add_alert"] = "http://www.roblox.com/asset/?id=6031071067",
        ["_warning"] = "http://www.roblox.com/asset/?id=6031071053",
        ["_error_outline"] = "http://www.roblox.com/asset/?id=6031071050",
        ["check_box_outline_blank"] = "http://www.roblox.com/asset/?id=6031068420",
        ["toggle_off"] = "http://www.roblox.com/asset/?id=6031068429",
        ["indeterminate_check_box"] = "http://www.roblox.com/asset/?id=6031068445",
        ["radio_button_checked"] = "http://www.roblox.com/asset/?id=6031068426",
        ["toggle_on"] = "http://www.roblox.com/asset/?id=6031068430",
        ["check_box"] = "http://www.roblox.com/asset/?id=6031068421",
        ["radio_button_unchecked"] = "http://www.roblox.com/asset/?id=6031068433",
        ["star"] = "http://www.roblox.com/asset/?id=6031068423",
        ["star_border"] = "http://www.roblox.com/asset/?id=6031068425",
        ["star_half"] = "http://www.roblox.com/asset/?id=6031068427",
        ["star_outline"] = "http://www.roblox.com/asset/?id=6031068428",
        ["multiline_chart"] = "http://www.roblox.com/asset/?id=6034941721",
        ["pie_chart"] = "http://www.roblox.com/asset/?id=6034973076",
        ["format_line_spacing"] = "http://www.roblox.com/asset/?id=6034910905",
        ["format_align_left"] = "http://www.roblox.com/asset/?id=6034900727",
        ["linear_scale"] = "http://www.roblox.com/asset/?id=6034941707",
        ["insert_photo"] = "http://www.roblox.com/asset/?id=6034941703",
        ["scatter_plot"] = "http://www.roblox.com/asset/?id=6034973094",
        ["post_add"] = "http://www.roblox.com/asset/?id=6034973083",
        ["format_textdirection_r_to_l"] = "http://www.roblox.com/asset/?id=6034925623",
        ["format_size"] = "http://www.roblox.com/asset/?id=6034910908",
        ["format_color_fill"] = "http://www.roblox.com/asset/?id=6034910903",
        ["format_paint"] = "http://www.roblox.com/asset/?id=6034925618",
        ["format_underlined"] = "http://www.roblox.com/asset/?id=6034925627",
        ["format_shapes"] = "http://www.roblox.com/asset/?id=6034910909",
        ["title"] = "http://www.roblox.com/asset/?id=6034934042",
        ["highlight"] = "http://www.roblox.com/asset/?id=6034925617",
        ["bar_chart"] = "http://www.roblox.com/asset/?id=6034898096",
        ["format_indent_increase"] = "http://www.roblox.com/asset/?id=6034900724",
        ["merge_type"] = "http://www.roblox.com/asset/?id=6034941705",
        ["bubble_chart"] = "http://www.roblox.com/asset/?id=6034925612",
        ["publish"] = "http://www.roblox.com/asset/?id=6034973085",
        ["format_indent_decrease"] = "http://www.roblox.com/asset/?id=6034900733",
        ["margin"] = "http://www.roblox.com/asset/?id=6034941701",
        ["table_rows"] = "http://www.roblox.com/asset/?id=6034934025",
        ["stacked_line_chart"] = "http://www.roblox.com/asset/?id=6034934039",
        ["border_clear"] = "http://www.roblox.com/asset/?id=6034898135",
        ["border_color"] = "http://www.roblox.com/asset/?id=6034898100",
        ["border_inner"] = "http://www.roblox.com/asset/?id=6034898131",
        ["insert_chart"] = "http://www.roblox.com/asset/?id=6034925628",
        ["border_top"] = "http://www.roblox.com/asset/?id=6034900726",
        ["padding"] = "http://www.roblox.com/asset/?id=6034973078",
        ["border_vertical"] = "http://www.roblox.com/asset/?id=6034900725",
        ["score"] = "http://www.roblox.com/asset/?id=6034934041",
        ["border_right"] = "http://www.roblox.com/asset/?id=6034898120",
        ["add_chart"] = "http://www.roblox.com/asset/?id=6034898093",
        ["space_bar"] = "http://www.roblox.com/asset/?id=6034934037",
        ["border_outer"] = "http://www.roblox.com/asset/?id=6034898104",
        ["mode_comment"] = "http://www.roblox.com/asset/?id=6034941700",
        ["attach_money"] = "http://www.roblox.com/asset/?id=6034898098",
        ["drag_handle"] = "http://www.roblox.com/asset/?id=6034910907",
        ["format_align_right"] = "http://www.roblox.com/asset/?id=6034900723",
        ["pie_chart_outlined"] = "http://www.roblox.com/asset/?id=6034973077",
        ["horizontal_rule"] = "http://www.roblox.com/asset/?id=6034925610",
        ["border_all"] = "http://www.roblox.com/asset/?id=6034898101",
        ["border_style"] = "http://www.roblox.com/asset/?id=6034898097",
        ["insert_comment"] = "http://www.roblox.com/asset/?id=6034925609",
        ["vertical_align_top"] = "http://www.roblox.com/asset/?id=6034973080",
        ["vertical_align_center"] = "http://www.roblox.com/asset/?id=6034934051",
        ["format_color_text"] = "http://www.roblox.com/asset/?id=6034910910",
        ["format_quote"] = "http://www.roblox.com/asset/?id=6034925629",
        ["height"] = "http://www.roblox.com/asset/?id=6034925613",
        ["add_comment"] = "http://www.roblox.com/asset/?id=6034898128",
        ["format_strikethrough"] = "http://www.roblox.com/asset/?id=6034910904",
        ["strikethrough_s"] = "http://www.roblox.com/asset/?id=6034934030",
        ["border_left"] = "http://www.roblox.com/asset/?id=6034898099",
        ["format_list_bulleted"] = "http://www.roblox.com/asset/?id=6034925620",
        ["format_italic"] = "http://www.roblox.com/asset/?id=6034910912",
        ["format_list_numbered"] = "http://www.roblox.com/asset/?id=6034925622",
        ["attach_file"] = "http://www.roblox.com/asset/?id=6034898102",
        ["wrap_text"] = "http://www.roblox.com/asset/?id=6034973118",
        ["insert_invitation"] = "http://www.roblox.com/asset/?id=6034973091",
        ["format_list_numbered_rtl"] = "http://www.roblox.com/asset/?id=6034910906",
        ["border_horizontal"] = "http://www.roblox.com/asset/?id=6034898105",
        ["format_align_center"] = "http://www.roblox.com/asset/?id=6034900718",
        ["format_textdirection_l_to_r"] = "http://www.roblox.com/asset/?id=6034925619",
        ["show_chart"] = "http://www.roblox.com/asset/?id=6034934032",
        ["insert_chart_outlined"] = "http://www.roblox.com/asset/?id=6034925606",
        ["vertical_align_bottom"] = "http://www.roblox.com/asset/?id=6034934023",
        ["subscript"] = "http://www.roblox.com/asset/?id=6034934059",
        ["format_align_justify"] = "http://www.roblox.com/asset/?id=6034900721",
        ["format_clear"] = "http://www.roblox.com/asset/?id=6034910902",
        ["notes"] = "http://www.roblox.com/asset/?id=6034973084",
        ["insert_drive_file"] = "http://www.roblox.com/asset/?id=6034941697",
        ["functions"] = "http://www.roblox.com/asset/?id=6034925614",
        ["insert_emoticon"] = "http://www.roblox.com/asset/?id=6034973079",
        ["insert_link"] = "http://www.roblox.com/asset/?id=6034973074",
        ["format_color_reset"] = "http://www.roblox.com/asset/?id=6034900743",
        ["monetization_on"] = "http://www.roblox.com/asset/?id=6034973115",
        ["short_text"] = "http://www.roblox.com/asset/?id=6034934035",
        ["mode_edit"] = "http://www.roblox.com/asset/?id=6034941708",
        ["superscript"] = "http://www.roblox.com/asset/?id=6034934034",
        ["table_chart"] = "http://www.roblox.com/asset/?id=6034973081",
        ["format_bold"] = "http://www.roblox.com/asset/?id=6034900732",
        ["money_off"] = "http://www.roblox.com/asset/?id=6034973088",
        ["border_bottom"] = "http://www.roblox.com/asset/?id=6034898094",
        ["text_fields"] = "http://www.roblox.com/asset/?id=6034934040",
        ["note"] = "http://www.roblox.com/asset/?id=6026663734",
        ["shuffle"] = "http://www.roblox.com/asset/?id=6026667003",
        ["library_books"] = "http://www.roblox.com/asset/?id=6026660085",
        ["library_music"] = "http://www.roblox.com/asset/?id=6026660075",
        ["surround_sound"] = "http://www.roblox.com/asset/?id=6026671209",
        ["forward_30"] = "http://www.roblox.com/asset/?id=6026660088",
        ["music_video"] = "http://www.roblox.com/asset/?id=6026663704",
        ["videocam_off"] = "http://www.roblox.com/asset/?id=6026671212",
        ["control_camera"] = "http://www.roblox.com/asset/?id=6026647916",
        ["explicit"] = "http://www.roblox.com/asset/?id=6026647913",
        ["3k_plus"] = "http://www.roblox.com/asset/?id=6026681598",
        ["fiber_pin"] = "http://www.roblox.com/asset/?id=6026660064",
        ["skip_previous"] = "http://www.roblox.com/asset/?id=6026667011",
        ["pause_circle_filled"] = "http://www.roblox.com/asset/?id=6026663718",
        ["video_settings"] = "http://www.roblox.com/asset/?id=6026671211",
        ["movie"] = "http://www.roblox.com/asset/?id=6026660081",
        ["add_to_queue"] = "http://www.roblox.com/asset/?id=6026647903",
        ["6k"] = "http://www.roblox.com/asset/?id=6026681579",
        ["web_asset"] = "http://www.roblox.com/asset/?id=6026671239",
        ["play_circle_outline"] = "http://www.roblox.com/asset/?id=6026663726",
        ["volume_off"] = "http://www.roblox.com/asset/?id=6026671224",
        ["mic_off"] = "http://www.roblox.com/asset/?id=6026660076",
        ["featured_play_list"] = "http://www.roblox.com/asset/?id=6026647932",
        ["pause_circle_outline"] = "http://www.roblox.com/asset/?id=6026663701",
        ["slow_motion_video"] = "http://www.roblox.com/asset/?id=6026681583",
        ["7k"] = "http://www.roblox.com/asset/?id=6026681584",
        ["playlist_add"] = "http://www.roblox.com/asset/?id=6026663728",
        ["fiber_smart_record"] = "http://www.roblox.com/asset/?id=6026660080",
        ["8k"] = "http://www.roblox.com/asset/?id=6026643014",
        ["hd"] = "http://www.roblox.com/asset/?id=6026660065",
        ["repeat_one_on"] = "http://www.roblox.com/asset/?id=6026666992",
        ["recent_actors"] = "http://www.roblox.com/asset/?id=6026663773",
        ["fiber_new"] = "http://www.roblox.com/asset/?id=6026647930",
        ["fiber_dvr"] = "http://www.roblox.com/asset/?id=6026647912",
        ["hearing_disabled"] = "http://www.roblox.com/asset/?id=6026660068",
        ["forward_10"] = "http://www.roblox.com/asset/?id=6026660062",
        ["4k_plus"] = "http://www.roblox.com/asset/?id=6026643005",
        ["repeat_one"] = "http://www.roblox.com/asset/?id=6026681590",
        ["equalizer"] = "http://www.roblox.com/asset/?id=6026647906",
        ["stop"] = "http://www.roblox.com/asset/?id=6026681576",
        ["2k"] = "http://www.roblox.com/asset/?id=6026643032",
        ["playlist_add_check"] = "http://www.roblox.com/asset/?id=6026663727",
        ["not_interested"] = "http://www.roblox.com/asset/?id=6026663743",
        ["videocam"] = "http://www.roblox.com/asset/?id=6026671213",
        ["sort_by_alpha"] = "http://www.roblox.com/asset/?id=6026667009",
        ["library_add"] = "http://www.roblox.com/asset/?id=6026660063",
        ["stop_circle"] = "http://www.roblox.com/asset/?id=6026681577",
        ["pause"] = "http://www.roblox.com/asset/?id=6026663719",
        ["new_releases"] = "http://www.roblox.com/asset/?id=6026663730",
        ["album"] = "http://www.roblox.com/asset/?id=6026647905",
        ["sd"] = "http://www.roblox.com/asset/?id=6026681582",
        ["volume_up"] = "http://www.roblox.com/asset/?id=6026671215",
        ["replay_5"] = "http://www.roblox.com/asset/?id=6026666993",
        ["high_quality"] = "http://www.roblox.com/asset/?id=6026660059",
        ["shuffle_on"] = "http://www.roblox.com/asset/?id=6026666996",
        ["play_arrow"] = "http://www.roblox.com/asset/?id=6026663699",
        ["snooze"] = "http://www.roblox.com/asset/?id=6026667006",
        ["closed_caption_disabled"] = "http://www.roblox.com/asset/?id=6026647900",
        ["subscriptions"] = "http://www.roblox.com/asset/?id=6026671207",
        ["skip_next"] = "http://www.roblox.com/asset/?id=6026667005",
        ["branding_watermark"] = "http://www.roblox.com/asset/?id=6026647911",
        ["speed"] = "http://www.roblox.com/asset/?id=6026681578",
        ["art_track"] = "http://www.roblox.com/asset/?id=6026647908",
        ["3k"] = "http://www.roblox.com/asset/?id=6026681574",
        ["4k"] = "http://www.roblox.com/asset/?id=6026643017",
        ["volume_mute"] = "http://www.roblox.com/asset/?id=6026671214",
        ["playlist_play"] = "http://www.roblox.com/asset/?id=6026663723",
        ["remove_from_queue"] = "http://www.roblox.com/asset/?id=6026663771",
        ["fast_forward"] = "http://www.roblox.com/asset/?id=6026647902",
        ["play_disabled"] = "http://www.roblox.com/asset/?id=6026663702",
        ["fast_rewind"] = "http://www.roblox.com/asset/?id=6026647942",
        ["5k"] = "http://www.roblox.com/asset/?id=6026681575",
        ["replay_10"] = "http://www.roblox.com/asset/?id=6026667007",
        ["video_library"] = "http://www.roblox.com/asset/?id=6026671208",
        ["loop"] = "http://www.roblox.com/asset/?id=6026660087",
        ["replay_circle_filled"] = "http://www.roblox.com/asset/?id=6026667002",
        ["5g"] = "http://www.roblox.com/asset/?id=6026643007",
        ["library_add_check"] = "http://www.roblox.com/asset/?id=6026660083",
        ["repeat"] = "http://www.roblox.com/asset/?id=6026666998",
        ["queue_play_next"] = "http://www.roblox.com/asset/?id=6026663700",
        ["forward_5"] = "http://www.roblox.com/asset/?id=6026660067",
        ["web"] = "http://www.roblox.com/asset/?id=6026671234",
        ["mic_none"] = "http://www.roblox.com/asset/?id=6026660066",
        ["queue"] = "http://www.roblox.com/asset/?id=6026663724",
        ["closed_caption_off"] = "http://www.roblox.com/asset/?id=6026647943",
        ["hearing"] = "http://www.roblox.com/asset/?id=6026660060",
        ["queue_music"] = "http://www.roblox.com/asset/?id=6026663725",
        ["airplay"] = "http://www.roblox.com/asset/?id=6026647929",
        ["9k"] = "http://www.roblox.com/asset/?id=6026643013",
        ["video_label"] = "http://www.roblox.com/asset/?id=6026671204",
        ["8k_plus"] = "http://www.roblox.com/asset/?id=6026643003",
        ["play_circle_filled"] = "http://www.roblox.com/asset/?id=6026663705",
        ["1k"] = "http://www.roblox.com/asset/?id=6026643002",
        ["fiber_manual_record"] = "http://www.roblox.com/asset/?id=6026647909",
        ["closed_caption"] = "http://www.roblox.com/asset/?id=6026647896",
        ["subtitles"] = "http://www.roblox.com/asset/?id=6026671203",
        ["featured_video"] = "http://www.roblox.com/asset/?id=6026647910",
        ["replay_30"] = "http://www.roblox.com/asset/?id=6026667010",
        ["10k"] = "http://www.roblox.com/asset/?id=6026643035",
        ["5k_plus"] = "http://www.roblox.com/asset/?id=6026643028",
        ["6k_plus"] = "http://www.roblox.com/asset/?id=6026643019",
        ["replay"] = "http://www.roblox.com/asset/?id=6026666999",
        ["repeat_on"] = "http://www.roblox.com/asset/?id=6026666994",
        ["1k_plus"] = "http://www.roblox.com/asset/?id=6026681580",
        ["2k_plus"] = "http://www.roblox.com/asset/?id=6026681588",
        ["games"] = "http://www.roblox.com/asset/?id=6026660074",
        ["volume_down"] = "http://www.roblox.com/asset/?id=6026671206",
        ["mic"] = "http://www.roblox.com/asset/?id=6026660078",
        ["call_to_action"] = "http://www.roblox.com/asset/?id=6026647898",
        ["7k_plus"] = "http://www.roblox.com/asset/?id=6026643012",
        ["av_timer"] = "http://www.roblox.com/asset/?id=6026647934",
        ["9k_plus"] = "http://www.roblox.com/asset/?id=6026681585",
        ["radio"] = "http://www.roblox.com/asset/?id=6026663698",
        ["10mp"] = "http://www.roblox.com/asset/?id=6031328149",
        ["20mp"] = "http://www.roblox.com/asset/?id=6031488940",
        ["wb_twighlight"] = "http://www.roblox.com/asset/?id=6034412760",
        ["movie_creation"] = "http://www.roblox.com/asset/?id=6034323681",
        ["crop_portrait"] = "http://www.roblox.com/asset/?id=6031630198",
        ["filter_5"] = "http://www.roblox.com/asset/?id=6031597518",
        ["broken_image"] = "http://www.roblox.com/asset/?id=6031471480",
        ["flip_camera_android"] = "http://www.roblox.com/asset/?id=6034333280",
        ["flip_camera_ios"] = "http://www.roblox.com/asset/?id=6034333267",
        ["circle"] = "http://www.roblox.com/asset/?id=6031625146",
        ["photo_camera_front"] = "http://www.roblox.com/asset/?id=6031771000",
        ["assistant"] = "http://www.roblox.com/asset/?id=6031360356",
        ["face_retouching_natural"] = "http://www.roblox.com/asset/?id=6034333274",
        ["palette"] = "http://www.roblox.com/asset/?id=6034316009",
        ["nature_people"] = "http://www.roblox.com/asset/?id=6034323711",
        ["14mp"] = "http://www.roblox.com/asset/?id=6031328161",
        ["gradient"] = "http://www.roblox.com/asset/?id=6034333261",
        ["filter_4"] = "http://www.roblox.com/asset/?id=6031597512",
        ["panorama_wide_angle_select"] = "http://www.roblox.com/asset/?id=6031770990",
        ["photo"] = "http://www.roblox.com/asset/?id=6031770993",
        ["grid_off"] = "http://www.roblox.com/asset/?id=6034333286",
        ["leak_add"] = "http://www.roblox.com/asset/?id=6034407074",
        ["landscape"] = "http://www.roblox.com/asset/?id=6034407069",
        ["exposure_plus_1"] = "http://www.roblox.com/asset/?id=6034328970",
        ["slideshow"] = "http://www.roblox.com/asset/?id=6031754546",
        ["camera_alt"] = "http://www.roblox.com/asset/?id=6031572307",
        ["audiotrack"] = "http://www.roblox.com/asset/?id=6031471489",
        ["filter_none"] = "http://www.roblox.com/asset/?id=6031600815",
        ["blur_off"] = "http://www.roblox.com/asset/?id=6031371055",
        ["crop_16_9"] = "http://www.roblox.com/asset/?id=6031630205",
        ["blur_on"] = "http://www.roblox.com/asset/?id=6031371068",
        ["brightness_4"] = "http://www.roblox.com/asset/?id=6031471483",
        ["details"] = "http://www.roblox.com/asset/?id=6034328968",
        ["panorama_horizontal"] = "http://www.roblox.com/asset/?id=6034315966",
        ["camera_rear"] = "http://www.roblox.com/asset/?id=6031572316",
        ["hdr_weak"] = "http://www.roblox.com/asset/?id=6034407083",
        ["collections"] = "http://www.roblox.com/asset/?id=6031625145",
        ["hdr_enhanced_select"] = "http://www.roblox.com/asset/?id=6034333281",
        ["adjust"] = "http://www.roblox.com/asset/?id=6031339048",
        ["burst_mode"] = "http://www.roblox.com/asset/?id=6031572306",
        ["nature"] = "http://www.roblox.com/asset/?id=6034323695",
        ["brightness_6"] = "http://www.roblox.com/asset/?id=6031572309",
        ["19mp"] = "http://www.roblox.com/asset/?id=6031339054",
        ["grain"] = "http://www.roblox.com/asset/?id=6034333288",
        ["receipt_long"] = "http://www.roblox.com/asset/?id=6031763428",
        ["photo_filter"] = "http://www.roblox.com/asset/?id=6031770992",
        ["edit"] = "http://www.roblox.com/asset/?id=6034328955",
        ["healing"] = "http://www.roblox.com/asset/?id=6034407071",
        ["exposure_neg_1"] = "http://www.roblox.com/asset/?id=6034328957",
        ["exposure"] = "http://www.roblox.com/asset/?id=6034328962",
        ["wb_shade"] = "http://www.roblox.com/asset/?id=6034315974",
        ["compare"] = "http://www.roblox.com/asset/?id=6031625151",
        ["cases"] = "http://www.roblox.com/asset/?id=6031572324",
        ["timer_3"] = "http://www.roblox.com/asset/?id=6031754540",
        ["exposure_plus_2"] = "http://www.roblox.com/asset/?id=6034328961",
        ["12mp"] = "http://www.roblox.com/asset/?id=6031328140",
        ["22mp"] = "http://www.roblox.com/asset/?id=6031360353",
        ["timer_off"] = "http://www.roblox.com/asset/?id=6031734881",
        ["auto_stories"] = "http://www.roblox.com/asset/?id=6031360360",
        ["rotate_left"] = "http://www.roblox.com/asset/?id=6031763427",
        ["wb_iridescent"] = "http://www.roblox.com/asset/?id=6034315972",
        ["shutter_speed"] = "http://www.roblox.com/asset/?id=6031763443",
        ["switch_video"] = "http://www.roblox.com/asset/?id=6031754536",
        ["23mp"] = "http://www.roblox.com/asset/?id=6031339045",
        ["euro"] = "http://www.roblox.com/asset/?id=6034328963",
        ["15mp"] = "http://www.roblox.com/asset/?id=6031328158",
        ["filter_center_focus"] = "http://www.roblox.com/asset/?id=6031600817",
        ["photo_library"] = "http://www.roblox.com/asset/?id=6031770998",
        ["mp"] = "http://www.roblox.com/asset/?id=6034323674",
        ["looks_4"] = "http://www.roblox.com/asset/?id=6034407089",
        ["filter_2"] = "http://www.roblox.com/asset/?id=6031597521",
        ["crop_3_2"] = "http://www.roblox.com/asset/?id=6034328956",
        ["auto_fix_normal"] = "http://www.roblox.com/asset/?id=6031371074",
        ["auto_fix_off"] = "http://www.roblox.com/asset/?id=6031360381",
        ["wb_auto"] = "http://www.roblox.com/asset/?id=6031734875",
        ["switch_camera"] = "http://www.roblox.com/asset/?id=6031754550",
        ["filter_vintage"] = "http://www.roblox.com/asset/?id=6031600811",
        ["photo_size_select_small"] = "http://www.roblox.com/asset/?id=6031763457",
        ["blur_linear"] = "http://www.roblox.com/asset/?id=6031488930",
        ["hdr_on"] = "http://www.roblox.com/asset/?id=6034333279",
        ["tag_faces"] = "http://www.roblox.com/asset/?id=6031754560",
        ["21mp"] = "http://www.roblox.com/asset/?id=6031339065",
        ["camera"] = "http://www.roblox.com/asset/?id=6031572312",
        ["image_aspect_ratio"] = "http://www.roblox.com/asset/?id=6034407073",
        ["filter_b_and_w"] = "http://www.roblox.com/asset/?id=6031600824",
        ["crop_landscape"] = "http://www.roblox.com/asset/?id=6031630202",
        ["13mp"] = "http://www.roblox.com/asset/?id=6031328137",
        ["grid_on"] = "http://www.roblox.com/asset/?id=6034333276",
        ["motion_photos_pause"] = "http://www.roblox.com/asset/?id=6034323668",
        ["filter_6"] = "http://www.roblox.com/asset/?id=6031597524",
        ["linked_camera"] = "http://www.roblox.com/asset/?id=6034407082",
        ["panorama_fish_eye"] = "http://www.roblox.com/asset/?id=6034315969",
        ["panorama"] = "http://www.roblox.com/asset/?id=6034315955",
        ["color_lens"] = "http://www.roblox.com/asset/?id=6031625148",
        ["lens"] = "http://www.roblox.com/asset/?id=6034407081",
        ["crop_din"] = "http://www.roblox.com/asset/?id=6031630208",
        ["exposure_neg_2"] = "http://www.roblox.com/asset/?id=6034328973",
        ["mic_external_off"] = "http://www.roblox.com/asset/?id=6034323672",
        ["crop_free"] = "http://www.roblox.com/asset/?id=6031630212",
        ["crop_original"] = "http://www.roblox.com/asset/?id=6031630204",
        ["panorama_photosphere_select"] = "http://www.roblox.com/asset/?id=6034315975",
        ["photo_size_select_actual"] = "http://www.roblox.com/asset/?id=6031771012",
        ["leak_remove"] = "http://www.roblox.com/asset/?id=6034407080",
        ["collections_bookmark"] = "http://www.roblox.com/asset/?id=6034328965",
        ["straighten"] = "http://www.roblox.com/asset/?id=6031754545",
        ["timelapse"] = "http://www.roblox.com/asset/?id=6031754541",
        ["picture_as_pdf"] = "http://www.roblox.com/asset/?id=6031763425",
        ["crop_rotate"] = "http://www.roblox.com/asset/?id=6031630203",
        ["control_point_duplicate"] = "http://www.roblox.com/asset/?id=6034328959",
        ["photo_camera_back"] = "http://www.roblox.com/asset/?id=6031771007",
        ["looks_3"] = "http://www.roblox.com/asset/?id=6034407088",
        ["motion_photos_off"] = "http://www.roblox.com/asset/?id=6034323670",
        ["rotate_right"] = "http://www.roblox.com/asset/?id=6031763429",
        ["view_compact"] = "http://www.roblox.com/asset/?id=6031734878",
        ["crop_7_5"] = "http://www.roblox.com/asset/?id=6031630197",
        ["style"] = "http://www.roblox.com/asset/?id=6031754538",
        ["exposure_zero"] = "http://www.roblox.com/asset/?id=6034329000",
        ["camera_front"] = "http://www.roblox.com/asset/?id=6031572318",
        ["hdr_strong"] = "http://www.roblox.com/asset/?id=6034333272",
        ["view_comfy"] = "http://www.roblox.com/asset/?id=6031734876",
        ["panorama_vertical"] = "http://www.roblox.com/asset/?id=6034315963",
        ["panorama_vertical_select"] = "http://www.roblox.com/asset/?id=6034315961",
        ["looks_two"] = "http://www.roblox.com/asset/?id=6034412757",
        ["filter_drama"] = "http://www.roblox.com/asset/?id=6031600813",
        ["center_focus_strong"] = "http://www.roblox.com/asset/?id=6031625147",
        ["18mp"] = "http://www.roblox.com/asset/?id=6031339064",
        ["7mp"] = "http://www.roblox.com/asset/?id=6031328139",
        ["wb_sunny"] = "http://www.roblox.com/asset/?id=6034412758",
        ["filter_9_plus"] = "http://www.roblox.com/asset/?id=6031600812",
        ["crop"] = "http://www.roblox.com/asset/?id=6034328964",
        ["vignette"] = "http://www.roblox.com/asset/?id=6031734905",
        ["brightness_2"] = "http://www.roblox.com/asset/?id=6031488938",
        ["crop_square"] = "http://www.roblox.com/asset/?id=6031630222",
        ["looks_5"] = "http://www.roblox.com/asset/?id=6034412764",
        ["flip"] = "http://www.roblox.com/asset/?id=6034333275",
        ["looks_one"] = "http://www.roblox.com/asset/?id=6034412761",
        ["flash_off"] = "http://www.roblox.com/asset/?id=6034333270",
        ["hdr_off"] = "http://www.roblox.com/asset/?id=6034333266",
        ["photo_album"] = "http://www.roblox.com/asset/?id=6031770989",
        ["motion_photos_paused"] = "http://www.roblox.com/asset/?id=6034323675",
        ["photo_camera"] = "http://www.roblox.com/asset/?id=6031770997",
        ["2mp"] = "http://www.roblox.com/asset/?id=6031328138",
        ["3mp"] = "http://www.roblox.com/asset/?id=6031328136",
        ["24mp"] = "http://www.roblox.com/asset/?id=6031360352",
        ["filter_9"] = "http://www.roblox.com/asset/?id=6031597534",
        ["6mp"] = "http://www.roblox.com/asset/?id=6031328131",
        ["remove_red_eye"] = "http://www.roblox.com/asset/?id=6031763426",
        ["4mp"] = "http://www.roblox.com/asset/?id=6031328152",
        ["add_a_photo"] = "http://www.roblox.com/asset/?id=6031339049",
        ["filter_3"] = "http://www.roblox.com/asset/?id=6031597513",
        ["crop_5_4"] = "http://www.roblox.com/asset/?id=6034328960",
        ["8mp"] = "http://www.roblox.com/asset/?id=6031328133",
        ["camera_roll"] = "http://www.roblox.com/asset/?id=6031572314",
        ["panorama_wide_angle"] = "http://www.roblox.com/asset/?id=6031770995",
        ["transform"] = "http://www.roblox.com/asset/?id=6031734873",
        ["flare"] = "http://www.roblox.com/asset/?id=6031600816",
        ["image_search"] = "http://www.roblox.com/asset/?id=6034407084",
        ["auto_awesome"] = "http://www.roblox.com/asset/?id=6031360365",
        ["motion_photos_on"] = "http://www.roblox.com/asset/?id=6034323669",
        ["rotate_90_degrees_ccw"] = "http://www.roblox.com/asset/?id=6031763456",
        ["filter_1"] = "http://www.roblox.com/asset/?id=6031597511",
        ["filter_tilt_shift"] = "http://www.roblox.com/asset/?id=6031600814",
        ["image"] = "http://www.roblox.com/asset/?id=6034407078",
        ["center_focus_weak"] = "http://www.roblox.com/asset/?id=6031625144",
        ["blur_circular"] = "http://www.roblox.com/asset/?id=6031488945",
        ["bedtime"] = "http://www.roblox.com/asset/?id=6031371054",
        ["auto_fix_high"] = "http://www.roblox.com/asset/?id=6031360355",
        ["monochrome_photos"] = "http://www.roblox.com/asset/?id=6034323678",
        ["flash_auto"] = "http://www.roblox.com/asset/?id=6034333287",
        ["5mp"] = "http://www.roblox.com/asset/?id=6031328144",
        ["photo_size_select_large"] = "http://www.roblox.com/asset/?id=6031763423",
        ["assistant_photo"] = "http://www.roblox.com/asset/?id=6031339052",
        ["animation"] = "http://www.roblox.com/asset/?id=6031625150",
        ["looks"] = "http://www.roblox.com/asset/?id=6034407096",
        ["17mp"] = "http://www.roblox.com/asset/?id=6031339055",
        ["panorama_horizontal_select"] = "http://www.roblox.com/asset/?id=6034315965",
        ["flash_on"] = "http://www.roblox.com/asset/?id=6034333271",
        ["iso"] = "http://www.roblox.com/asset/?id=6034407106",
        ["music_note"] = "http://www.roblox.com/asset/?id=6034323673",
        ["music_off"] = "http://www.roblox.com/asset/?id=6034323679",
        ["navigate_next"] = "http://www.roblox.com/asset/?id=6034315956",
        ["timer"] = "http://www.roblox.com/asset/?id=6031754564",
        ["loupe"] = "http://www.roblox.com/asset/?id=6034412770",
        ["navigate_before"] = "http://www.roblox.com/asset/?id=6034323696",
        ["brightness_1"] = "http://www.roblox.com/asset/?id=6031471488",
        ["brightness_7"] = "http://www.roblox.com/asset/?id=6031471491",
        ["tonality"] = "http://www.roblox.com/asset/?id=6031734891",
        ["brush"] = "http://www.roblox.com/asset/?id=6031572320",
        ["colorize"] = "http://www.roblox.com/asset/?id=6031625161",
        ["filter_7"] = "http://www.roblox.com/asset/?id=6031597515",
        ["16mp"] = "http://www.roblox.com/asset/?id=6031328168",
        ["timer_10"] = "http://www.roblox.com/asset/?id=6031734880",
        ["portrait"] = "http://www.roblox.com/asset/?id=6031763434",
        ["tune"] = "http://www.roblox.com/asset/?id=6031734877",
        ["image_not_supported"] = "http://www.roblox.com/asset/?id=6034407076",
        ["wb_cloudy"] = "http://www.roblox.com/asset/?id=6031734907",
        ["auto_awesome_motion"] = "http://www.roblox.com/asset/?id=6031360370",
        ["filter_8"] = "http://www.roblox.com/asset/?id=6031597532",
        ["brightness_5"] = "http://www.roblox.com/asset/?id=6031471479",
        ["movie_filter"] = "http://www.roblox.com/asset/?id=6034323687",
        ["add_photo_alternate"] = "http://www.roblox.com/asset/?id=6031471484",
        ["add_to_photos"] = "http://www.roblox.com/asset/?id=6031371075",
        ["texture"] = "http://www.roblox.com/asset/?id=6031754553",
        ["11mp"] = "http://www.roblox.com/asset/?id=6031328141",
        ["mic_external_on"] = "http://www.roblox.com/asset/?id=6034323671",
        ["looks_6"] = "http://www.roblox.com/asset/?id=6034412759",
        ["dehaze"] = "http://www.roblox.com/asset/?id=6031630200",
        ["control_point"] = "http://www.roblox.com/asset/?id=6031625131",
        ["panorama_photosphere"] = "http://www.roblox.com/asset/?id=6034412763",
        ["filter_frames"] = "http://www.roblox.com/asset/?id=6031600833",
        ["auto_awesome_mosaic"] = "http://www.roblox.com/asset/?id=6031371053",
        ["9mp"] = "http://www.roblox.com/asset/?id=6031328146",
        ["filter"] = "http://www.roblox.com/asset/?id=6031597514",
        ["brightness_3"] = "http://www.roblox.com/asset/?id=6031572317",
        ["dirty_lens"] = "http://www.roblox.com/asset/?id=6034328967",
        ["wb_incandescent"] = "http://www.roblox.com/asset/?id=6034316010",
        ["filter_hdr"] = "http://www.roblox.com/asset/?id=6031600819",
        ["textsms"] = "http://www.roblox.com/asset/?id=6035202006",
        ["comment"] = "http://www.roblox.com/asset/?id=6035181871",
        ["call_end"] = "http://www.roblox.com/asset/?id=6035173845",
        ["qr_code_scanner"] = "http://www.roblox.com/asset/?id=6035202022",
        ["phonelink_setup"] = "http://www.roblox.com/asset/?id=6035202025",
        ["call_merge"] = "http://www.roblox.com/asset/?id=6035173843",
        ["phonelink_erase"] = "http://www.roblox.com/asset/?id=6035202085",
        ["contact_mail"] = "http://www.roblox.com/asset/?id=6035181868",
        ["contact_phone"] = "http://www.roblox.com/asset/?id=6035181861",
        ["screen_share"] = "http://www.roblox.com/asset/?id=6035202008",
        ["present_to_all"] = "http://www.roblox.com/asset/?id=6035202020",
        ["stay_primary_portrait"] = "http://www.roblox.com/asset/?id=6035202009",
        ["message"] = "http://www.roblox.com/asset/?id=6035202033",
        ["sentiment_satisfied_alt"] = "http://www.roblox.com/asset/?id=6035202069",
        ["stay_current_portrait"] = "http://www.roblox.com/asset/?id=6035202004",
        ["voicemail"] = "http://www.roblox.com/asset/?id=6035202019",
        ["business"] = "http://www.roblox.com/asset/?id=6035173853",
        ["mail_outline"] = "http://www.roblox.com/asset/?id=6035190844",
        ["vpn_key"] = "http://www.roblox.com/asset/?id=6035202034",
        ["forward_to_inbox"] = "http://www.roblox.com/asset/?id=6035190840",
        ["contacts"] = "http://www.roblox.com/asset/?id=6035181864",
        ["phonelink_ring"] = "http://www.roblox.com/asset/?id=6035202066",
        ["domain_disabled"] = "http://www.roblox.com/asset/?id=6035181862",
        ["person_add_disabled"] = "http://www.roblox.com/asset/?id=6035202007",
        ["stay_primary_landscape"] = "http://www.roblox.com/asset/?id=6035202026",
        ["alternate_email"] = "http://www.roblox.com/asset/?id=6035173865",
        ["phone_disabled"] = "http://www.roblox.com/asset/?id=6035202028",
        ["email"] = "http://www.roblox.com/asset/?id=6035181866",
        ["mobile_screen_share"] = "http://www.roblox.com/asset/?id=6035202021",
        ["live_help"] = "http://www.roblox.com/asset/?id=6035190836",
        ["chat_bubble"] = "http://www.roblox.com/asset/?id=6035181858",
        ["stop_screen_share"] = "http://www.roblox.com/asset/?id=6035202042",
        ["location_on"] = "http://www.roblox.com/asset/?id=6035190846",
        ["chat_bubble_outline"] = "http://www.roblox.com/asset/?id=6035181869",
        ["dialer_sip"] = "http://www.roblox.com/asset/?id=6035181865",
        ["no_sim"] = "http://www.roblox.com/asset/?id=6035202030",
        ["list_alt"] = "http://www.roblox.com/asset/?id=6035190838",
        ["call"] = "http://www.roblox.com/asset/?id=6035173859",
        ["pause_presentation"] = "http://www.roblox.com/asset/?id=6035202015",
        ["invert_colors_off"] = "http://www.roblox.com/asset/?id=6035190842",
        ["call_missed_outgoing"] = "http://www.roblox.com/asset/?id=6035173847",
        ["stay_current_landscape"] = "http://www.roblox.com/asset/?id=6035202011",
        ["import_export"] = "http://www.roblox.com/asset/?id=6035202040",
        ["add_ic_call"] = "http://www.roblox.com/asset/?id=6035173839",
        ["dialpad"] = "http://www.roblox.com/asset/?id=6035181892",
        ["nat"] = "http://www.roblox.com/asset/?id=6035202082",
        ["unsubscribe"] = "http://www.roblox.com/asset/?id=6035202044",
        ["mark_chat_unread"] = "http://www.roblox.com/asset/?id=6035190841",
        ["portable_wifi_off"] = "http://www.roblox.com/asset/?id=6035202091",
        ["location_off"] = "http://www.roblox.com/asset/?id=6035202049",
        ["person_search"] = "http://www.roblox.com/asset/?id=6035202013",
        ["phonelink_lock"] = "http://www.roblox.com/asset/?id=6035202064",
        ["desktop_access_disabled"] = "http://www.roblox.com/asset/?id=6035181863",
        ["import_contacts"] = "http://www.roblox.com/asset/?id=6035190854",
        ["rss_feed"] = "http://www.roblox.com/asset/?id=6035202016",
        ["chat"] = "http://www.roblox.com/asset/?id=6035173838",
        ["print_disabled"] = "http://www.roblox.com/asset/?id=6035202041",
        ["mark_email_read"] = "http://www.roblox.com/asset/?id=6035202038",
        ["hourglass_top"] = "http://www.roblox.com/asset/?id=6035190886",
        ["clear_all"] = "http://www.roblox.com/asset/?id=6035181870",
        ["forum"] = "http://www.roblox.com/asset/?id=6035202002",
        ["qr_code"] = "http://www.roblox.com/asset/?id=6035202012",
        ["speaker_phone"] = "http://www.roblox.com/asset/?id=6035202018",
        ["rtt"] = "http://www.roblox.com/asset/?id=6035202010",
        ["domain_verification"] = "http://www.roblox.com/asset/?id=6035181867",
        ["app_registration"] = "http://www.roblox.com/asset/?id=6035173870",
        ["call_split"] = "http://www.roblox.com/asset/?id=6035173861",
        ["cell_wifi"] = "http://www.roblox.com/asset/?id=6035173852",
        ["phone_enabled"] = "http://www.roblox.com/asset/?id=6035202089",
        ["call_made"] = "http://www.roblox.com/asset/?id=6035173858",
        ["call_received"] = "http://www.roblox.com/asset/?id=6035173844",
        ["phone"] = "http://www.roblox.com/asset/?id=6035202017",
        ["ring_volume"] = "http://www.roblox.com/asset/?id=6035202032",
        ["mark_email_unread"] = "http://www.roblox.com/asset/?id=6035202027",
        ["hourglass_bottom"] = "http://www.roblox.com/asset/?id=6035202043",
        ["read_more"] = "http://www.roblox.com/asset/?id=6035202014",
        ["duo"] = "http://www.roblox.com/asset/?id=6035181860",
        ["more_time"] = "http://www.roblox.com/asset/?id=6035202036",
        ["wifi_calling"] = "http://www.roblox.com/asset/?id=6035202065",
        ["swap_calls"] = "http://www.roblox.com/asset/?id=6035202037",
        ["cancel_presentation"] = "http://www.roblox.com/asset/?id=6035173837",
        ["call_missed"] = "http://www.roblox.com/asset/?id=6035173850",
        ["mark_chat_read"] = "http://www.roblox.com/asset/?id=6035202031",
        ["text_snippet"] = "http://www.roblox.com/asset/?id=6031302995",
        ["snippet_folder"] = "http://www.roblox.com/asset/?id=6031302947",
        ["workspaces_outline"] = "http://www.roblox.com/asset/?id=6031302952",
        ["file_download"] = "http://www.roblox.com/asset/?id=6031302931",
        ["request_quote"] = "http://www.roblox.com/asset/?id=6031302941",
        ["approval"] = "http://www.roblox.com/asset/?id=6031302928",
        ["drive_folder_upload"] = "http://www.roblox.com/asset/?id=6031302929",
        ["rule_folder"] = "http://www.roblox.com/asset/?id=6031302940",
        ["attach_email"] = "http://www.roblox.com/asset/?id=6031302935",
        ["topic"] = "http://www.roblox.com/asset/?id=6031302976",
        ["upload_file"] = "http://www.roblox.com/asset/?id=6031302959",
        ["attachment"] = "http://www.roblox.com/asset/?id=6031302921",
        ["file_download_done"] = "http://www.roblox.com/asset/?id=6031302926",
        ["drive_file_move_outline"] = "http://www.roblox.com/asset/?id=6031302924",
        ["cloud_upload"] = "http://www.roblox.com/asset/?id=6031302992",
        ["cloud_circle"] = "http://www.roblox.com/asset/?id=6031302919",
        ["folder_shared"] = "http://www.roblox.com/asset/?id=6031302945",
        ["cloud_download"] = "http://www.roblox.com/asset/?id=6031302917",
        ["file_upload"] = "http://www.roblox.com/asset/?id=6031302996",
        ["workspaces_filled"] = "http://www.roblox.com/asset/?id=6031302961",
        ["cloud_queue"] = "http://www.roblox.com/asset/?id=6031302916",
        ["cloud"] = "http://www.roblox.com/asset/?id=6031302918",
        ["folder_open"] = "http://www.roblox.com/asset/?id=6031302934",
        ["grid_view"] = "http://www.roblox.com/asset/?id=6031302950",
        ["cloud_off"] = "http://www.roblox.com/asset/?id=6031302993",
        ["create_new_folder"] = "http://www.roblox.com/asset/?id=6031302933",
        ["cloud_done"] = "http://www.roblox.com/asset/?id=6031302927",
        ["folder"] = "http://www.roblox.com/asset/?id=6031302932",
        ["drive_file_move"] = "http://www.roblox.com/asset/?id=6031302922",
        ["drive_file_rename_outline"] = "http://www.roblox.com/asset/?id=6031302994",
        ["notifications_active"] = "http://www.roblox.com/asset/?id=6034304908",
        ["sentiment_neutral"] = "http://www.roblox.com/asset/?id=6034230636",
        ["sick"] = "http://www.roblox.com/asset/?id=6034230642",
        ["poll"] = "http://www.roblox.com/asset/?id=6034267991",
        ["emoji_events"] = "http://www.roblox.com/asset/?id=6034275726",
        ["groups"] = "http://www.roblox.com/asset/?id=6034281935",
        ["sports_soccer"] = "http://www.roblox.com/asset/?id=6034227075",
        ["person_add"] = "http://www.roblox.com/asset/?id=6034287514",
        ["mood_bad"] = "http://www.roblox.com/asset/?id=6034295706",
        ["person_remove_alt_1"] = "http://www.roblox.com/asset/?id=6034287515",
        ["king_bed"] = "http://www.roblox.com/asset/?id=6034281948",
        ["architecture"] = "http://www.roblox.com/asset/?id=6034275730",
        ["deck"] = "http://www.roblox.com/asset/?id=6034295703",
        ["group_add"] = "http://www.roblox.com/asset/?id=6034281909",
        ["sports_basketball"] = "http://www.roblox.com/asset/?id=6034230649",
        ["emoji_symbols"] = "http://www.roblox.com/asset/?id=6034281899",
        ["switch_account"] = "http://www.roblox.com/asset/?id=6034227138",
        ["remove_moderator"] = "http://www.roblox.com/asset/?id=6034267998",
        ["coronavirus"] = "http://www.roblox.com/asset/?id=6034275724",
        ["people"] = "http://www.roblox.com/asset/?id=6034287513",
        ["person"] = "http://www.roblox.com/asset/?id=6034287594",
        ["elderly"] = "http://www.roblox.com/asset/?id=6034295698",
        ["clean_hands"] = "http://www.roblox.com/asset/?id=6034275729",
        ["emoji_flags"] = "http://www.roblox.com/asset/?id=6034304898",
        ["psychology"] = "http://www.roblox.com/asset/?id=6034287516",
        ["person_add_alt"] = "http://www.roblox.com/asset/?id=6034267994",
        ["sports_volleyball"] = "http://www.roblox.com/asset/?id=6034227139",
        ["domain"] = "http://www.roblox.com/asset/?id=6034275722",
        ["emoji_objects"] = "http://www.roblox.com/asset/?id=6034281900",
        ["ios_share"] = "http://www.roblox.com/asset/?id=6034281941",
        ["history_edu"] = "http://www.roblox.com/asset/?id=6034281934",
        ["share"] = "http://www.roblox.com/asset/?id=6034230648",
        ["military_tech"] = "http://www.roblox.com/asset/?id=6034295711",
        ["sports_kabaddi"] = "http://www.roblox.com/asset/?id=6034227141",
        ["cake"] = "http://www.roblox.com/asset/?id=6034295702",
        ["engineering"] = "http://www.roblox.com/asset/?id=6034281908",
        ["emoji_food_beverage"] = "http://www.roblox.com/asset/?id=6034304883",
        ["notifications_none"] = "http://www.roblox.com/asset/?id=6034308947",
        ["emoji_people"] = "http://www.roblox.com/asset/?id=6034281904",
        ["thumb_down_alt"] = "http://www.roblox.com/asset/?id=6034227069",
        ["sentiment_very_satisfied"] = "http://www.roblox.com/asset/?id=6034230650",
        ["nights_stay"] = "http://www.roblox.com/asset/?id=6034304881",
        ["reduce_capacity"] = "http://www.roblox.com/asset/?id=6034268013",
        ["add_moderator"] = "http://www.roblox.com/asset/?id=6034295699",
        ["science"] = "http://www.roblox.com/asset/?id=6034230640",
        ["pages"] = "http://www.roblox.com/asset/?id=6034304892",
        ["sentiment_satisfied"] = "http://www.roblox.com/asset/?id=6034230668",
        ["plus_one"] = "http://www.roblox.com/asset/?id=6034268012",
        ["party_mode"] = "http://www.roblox.com/asset/?id=6034287521",
        ["person_remove"] = "http://www.roblox.com/asset/?id=6034267996",
        ["single_bed"] = "http://www.roblox.com/asset/?id=6034230651",
        ["mood"] = "http://www.roblox.com/asset/?id=6034295704",
        ["public"] = "http://www.roblox.com/asset/?id=6034287522",
        ["sports_rugby"] = "http://www.roblox.com/asset/?id=6034227073",
        ["sports_handball"] = "http://www.roblox.com/asset/?id=6034227074",
        ["person_add_alt_1"] = "http://www.roblox.com/asset/?id=6034287519",
        ["people_alt"] = "http://www.roblox.com/asset/?id=6034287518",
        ["notifications_off"] = "http://www.roblox.com/asset/?id=6034304894",
        ["whatshot"] = "http://www.roblox.com/asset/?id=6034287525",
        ["emoji_transportation"] = "http://www.roblox.com/asset/?id=6034281894",
        ["outdoor_grill"] = "http://www.roblox.com/asset/?id=6034304900",
        ["sentiment_very_dissatisfied"] = "http://www.roblox.com/asset/?id=6034230659",
        ["masks"] = "http://www.roblox.com/asset/?id=6034295710",
        ["luggage"] = "http://www.roblox.com/asset/?id=6034295708",
        ["sports_motorsports"] = "http://www.roblox.com/asset/?id=6034227071",
        ["sports_esports"] = "http://www.roblox.com/asset/?id=6034227061",
        ["location_city"] = "http://www.roblox.com/asset/?id=6034304889",
        ["sports_golf"] = "http://www.roblox.com/asset/?id=6034227060",
        ["sentiment_dissatisfied"] = "http://www.roblox.com/asset/?id=6034230637",
        ["no_luggage"] = "http://www.roblox.com/asset/?id=6034304891",
        ["fireplace"] = "http://www.roblox.com/asset/?id=6034281910",
        ["emoji_nature"] = "http://www.roblox.com/asset/?id=6034281896",
        ["group"] = "http://www.roblox.com/asset/?id=6034281901",
        ["thumb_up_alt"] = "http://www.roblox.com/asset/?id=6034227076",
        ["sports_tennis"] = "http://www.roblox.com/asset/?id=6034227068",
        ["facebook"] = "http://www.roblox.com/asset/?id=6034281898",
        ["sports_mma"] = "http://www.roblox.com/asset/?id=6034227072",
        ["person_outline"] = "http://www.roblox.com/asset/?id=6034268008",
        ["sports_baseball"] = "http://www.roblox.com/asset/?id=6034230652",
        ["sports_cricket"] = "http://www.roblox.com/asset/?id=6034230660",
        ["people_outline"] = "http://www.roblox.com/asset/?id=6034287528",
        ["notifications_paused"] = "http://www.roblox.com/asset/?id=6034304896",
        ["emoji_emotions"] = "http://www.roblox.com/asset/?id=6034275731",
        ["follow_the_signs"] = "http://www.roblox.com/asset/?id=6034281911",
        ["sanitizer"] = "http://www.roblox.com/asset/?id=6034287586",
        ["self_improvement"] = "http://www.roblox.com/asset/?id=6034230634",
        ["notifications"] = "http://www.roblox.com/asset/?id=6034308946",
        ["public_off"] = "http://www.roblox.com/asset/?id=6034287538",
        ["recommend"] = "http://www.roblox.com/asset/?id=6034287524",
        ["sports_football"] = "http://www.roblox.com/asset/?id=6034227067",
        ["sports_hockey"] = "http://www.roblox.com/asset/?id=6034227064",
        ["school"] = "http://www.roblox.com/asset/?id=6034230641",
        ["connect_without_contact"] = "http://www.roblox.com/asset/?id=6034275800",
        ["sports"] = "http://www.roblox.com/asset/?id=6034230647",
        ["construction"] = "http://www.roblox.com/asset/?id=6034275725",
        ["inventory"] = "http://www.roblox.com/asset/?id=6035056487",
        ["add_box"] = "http://www.roblox.com/asset/?id=6035047375",
        ["how_to_reg"] = "http://www.roblox.com/asset/?id=6035053288",
        ["unarchive"] = "http://www.roblox.com/asset/?id=6035078921",
        ["block_flipped"] = "http://www.roblox.com/asset/?id=6035047378",
        ["file_copy"] = "http://www.roblox.com/asset/?id=6035053293",
        ["bolt"] = "http://www.roblox.com/asset/?id=6035047381",
        ["remove_circle_outline"] = "http://www.roblox.com/asset/?id=6035067843",
        ["move_to_inbox"] = "http://www.roblox.com/asset/?id=6035067838",
        ["save_alt"] = "http://www.roblox.com/asset/?id=6035067842",
        ["weekend"] = "http://www.roblox.com/asset/?id=6035078894",
        ["where_to_vote"] = "http://www.roblox.com/asset/?id=6035078913",
        ["biotech"] = "http://www.roblox.com/asset/?id=6035047385",
        ["report_off"] = "http://www.roblox.com/asset/?id=6035067830",
        ["clear"] = "http://www.roblox.com/asset/?id=6035047409",
        ["redo"] = "http://www.roblox.com/asset/?id=6035056483",
        ["link"] = "http://www.roblox.com/asset/?id=6035056475",
        ["drafts"] = "http://www.roblox.com/asset/?id=6035053297",
        ["push_pin"] = "http://www.roblox.com/asset/?id=6035056481",
        ["reply"] = "http://www.roblox.com/asset/?id=6035067844",
        ["undo"] = "http://www.roblox.com/asset/?id=6035078896",
        ["archive"] = "http://www.roblox.com/asset/?id=6035047379",
        ["add"] = "http://www.roblox.com/asset/?id=6035047377",
        ["insights"] = "http://www.roblox.com/asset/?id=6035067839",
        ["flag"] = "http://www.roblox.com/asset/?id=6035053279",
        ["save"] = "http://www.roblox.com/asset/?id=6035067857",
        ["text_format"] = "http://www.roblox.com/asset/?id=6035078890",
        ["content_cut"] = "http://www.roblox.com/asset/?id=6035053280",
        ["ballot"] = "http://www.roblox.com/asset/?id=6035047386",
        ["remove"] = "http://www.roblox.com/asset/?id=6035067836",
        ["calculate"] = "http://www.roblox.com/asset/?id=6035047384",
        ["report"] = "http://www.roblox.com/asset/?id=6035067826",
        ["markunread"] = "http://www.roblox.com/asset/?id=6035056476",
        ["delete_sweep"] = "http://www.roblox.com/asset/?id=6035053301",
        ["gesture"] = "http://www.roblox.com/asset/?id=6035053287",
        ["link_off"] = "http://www.roblox.com/asset/?id=6035056484",
        ["forward"] = "http://www.roblox.com/asset/?id=6035053298",
        ["reply_all"] = "http://www.roblox.com/asset/?id=6035067824",
        ["how_to_vote"] = "http://www.roblox.com/asset/?id=6035053295",
        ["square_foot"] = "http://www.roblox.com/asset/?id=6035078918",
        ["outlined_flag"] = "http://www.roblox.com/asset/?id=6035056486",
        ["add_circle"] = "http://www.roblox.com/asset/?id=6035047380",
        ["stacked_bar_chart"] = "http://www.roblox.com/asset/?id=6035078892",
        ["policy"] = "http://www.roblox.com/asset/?id=6035056512",
        ["backspace"] = "http://www.roblox.com/asset/?id=6035047397",
        ["sort"] = "http://www.roblox.com/asset/?id=6035078888",
        ["content_paste"] = "http://www.roblox.com/asset/?id=6035053285",
        ["low_priority"] = "http://www.roblox.com/asset/?id=6035056491",
        ["font_download"] = "http://www.roblox.com/asset/?id=6035053275",
        ["shield"] = "http://www.roblox.com/asset/?id=6035078889",
        ["waves"] = "http://www.roblox.com/asset/?id=6035078898",
        ["select_all"] = "http://www.roblox.com/asset/?id=6035067834",
        ["dynamic_feed"] = "http://www.roblox.com/asset/?id=6035053289",
        ["mail"] = "http://www.roblox.com/asset/?id=6035056477",
        ["amp_stories"] = "http://www.roblox.com/asset/?id=6035047382",
        ["filter_list"] = "http://www.roblox.com/asset/?id=6035053294",
        ["send"] = "http://www.roblox.com/asset/?id=6035067832",
        ["create"] = "http://www.roblox.com/asset/?id=6035053304",
        ["stream"] = "http://www.roblox.com/asset/?id=6035078897",
        ["next_week"] = "http://www.roblox.com/asset/?id=6035067835",
        ["inbox"] = "http://www.roblox.com/asset/?id=6035067831",
        ["add_link"] = "http://www.roblox.com/asset/?id=6035047374",
        ["content_copy"] = "http://www.roblox.com/asset/?id=6035053278",
        ["remove_circle"] = "http://www.roblox.com/asset/?id=6035067837",
        ["add_circle_outline"] = "http://www.roblox.com/asset/?id=6035047391",
        ["block"] = "http://www.roblox.com/asset/?id=6035047387",
        ["tag"] = "http://www.roblox.com/asset/?id=6035078895",
        ["beach_access"] = "http://www.roblox.com/asset/?id=6035107923",
        ["stroller"] = "http://www.roblox.com/asset/?id=6035161535",
        ["family_restroom"] = "http://www.roblox.com/asset/?id=6035121916",
        ["corporate_fare"] = "http://www.roblox.com/asset/?id=6035121908",
        ["no_meeting_room"] = "http://www.roblox.com/asset/?id=6035153649",
        ["do_not_touch"] = "http://www.roblox.com/asset/?id=6035121915",
        ["ac_unit"] = "http://www.roblox.com/asset/?id=6035107929",
        ["business_center"] = "http://www.roblox.com/asset/?id=6035107933",
        ["spa"] = "http://www.roblox.com/asset/?id=6035153639",
        ["no_flash"] = "http://www.roblox.com/asset/?id=6035145424",
        ["no_cell"] = "http://www.roblox.com/asset/?id=6035145376",
        ["room_service"] = "http://www.roblox.com/asset/?id=6035153648",
        ["tapas"] = "http://www.roblox.com/asset/?id=6035161533",
        ["microwave"] = "http://www.roblox.com/asset/?id=6035145367",
        ["meeting_room"] = "http://www.roblox.com/asset/?id=6035145361",
        ["wash"] = "http://www.roblox.com/asset/?id=6035161540",
        ["escalator"] = "http://www.roblox.com/asset/?id=6035121939",
        ["house_siding"] = "http://www.roblox.com/asset/?id=6035145393",
        ["food_bank"] = "http://www.roblox.com/asset/?id=6035121921",
        ["foundation"] = "http://www.roblox.com/asset/?id=6035121918",
        ["elevator"] = "http://www.roblox.com/asset/?id=6035121912",
        ["room_preferences"] = "http://www.roblox.com/asset/?id=6035153642",
        ["do_not_step"] = "http://www.roblox.com/asset/?id=6035121910",
        ["free_breakfast"] = "http://www.roblox.com/asset/?id=6035145363",
        ["house"] = "http://www.roblox.com/asset/?id=6035145364",
        ["child_care"] = "http://www.roblox.com/asset/?id=6035107927",
        ["night_shelter"] = "http://www.roblox.com/asset/?id=6035145378",
        ["child_friendly"] = "http://www.roblox.com/asset/?id=6035121942",
        ["checkroom"] = "http://www.roblox.com/asset/?id=6035107931",
        ["hot_tub"] = "http://www.roblox.com/asset/?id=6035145382",
        ["dry"] = "http://www.roblox.com/asset/?id=6035121909",
        ["charging_station"] = "http://www.roblox.com/asset/?id=6035107925",
        ["all_inclusive"] = "http://www.roblox.com/asset/?id=6035107920",
        ["bento"] = "http://www.roblox.com/asset/?id=6035107924",
        ["no_backpack"] = "http://www.roblox.com/asset/?id=6035145368",
        ["storefront"] = "http://www.roblox.com/asset/?id=6035161534",
        ["no_food"] = "http://www.roblox.com/asset/?id=6035145372",
        ["backpack"] = "http://www.roblox.com/asset/?id=6035107928",
        ["stairs"] = "http://www.roblox.com/asset/?id=6035153637",
        ["carpenter"] = "http://www.roblox.com/asset/?id=6035107955",
        ["no_stroller"] = "http://www.roblox.com/asset/?id=6035153661",
        ["roofing"] = "http://www.roblox.com/asset/?id=6035153656",
        ["umbrella"] = "http://www.roblox.com/asset/?id=6035161550",
        ["sports_bar"] = "http://www.roblox.com/asset/?id=6035153638",
        ["apartment"] = "http://www.roblox.com/asset/?id=6035107922",
        ["smoke_free"] = "http://www.roblox.com/asset/?id=6035153647",
        ["pool"] = "http://www.roblox.com/asset/?id=6035153655",
        ["bathtub"] = "http://www.roblox.com/asset/?id=6035107939",
        ["no_drinks"] = "http://www.roblox.com/asset/?id=6035145390",
        ["escalator_warning"] = "http://www.roblox.com/asset/?id=6035121930",
        ["wheelchair_pickup"] = "http://www.roblox.com/asset/?id=6035161536",
        ["smoking_rooms"] = "http://www.roblox.com/asset/?id=6035153636",
        ["rice_bowl"] = "http://www.roblox.com/asset/?id=6035153662",
        ["tty"] = "http://www.roblox.com/asset/?id=6035161541",
        ["no_photography"] = "http://www.roblox.com/asset/?id=6035153664",
        ["casino"] = "http://www.roblox.com/asset/?id=6035107936",
        ["fence"] = "http://www.roblox.com/asset/?id=6035121923",
        ["grass"] = "http://www.roblox.com/asset/?id=6035145359",
        ["countertops"] = "http://www.roblox.com/asset/?id=6035121914",
        ["kitchen"] = "http://www.roblox.com/asset/?id=6035145362",
        ["golf_course"] = "http://www.roblox.com/asset/?id=6035145423",
        ["soap"] = "http://www.roblox.com/asset/?id=6035153645",
        ["water_damage"] = "http://www.roblox.com/asset/?id=6035161563",
        ["airport_shuttle"] = "http://www.roblox.com/asset/?id=6035107921",
        ["fitness_center"] = "http://www.roblox.com/asset/?id=6035121907",
        ["baby_changing_station"] = "http://www.roblox.com/asset/?id=6035107930",
        ["fire_extinguisher"] = "http://www.roblox.com/asset/?id=6035121913",
        ["sparkle"] = "http://www.roblox.com/asset/?id=4483362748"
    }
}

local function GetIcon(icon, source)
    if not icon or icon == "" then return nil end
    source = source or "Material"
    if source == "Custom" or string.find(tostring(icon), "rbxassetid://") then
        return string.find(tostring(icon), "rbxassetid://") and icon or ("rbxassetid://" .. icon)
    elseif source == "Lucide" then
        if isStudio then
            return "rbxassetid://10723434557"
        else
            local iconData = game:HttpGet("https://raw.githubusercontent.com/latte-soft/lucide-roblox/refs/heads/master/lib/Icons.luau")
            local icons = loadstring(iconData)()
            local clean = string.match(string.lower(icon), "^%s*(.*)%s*$")
            local sizedicons = icons['48px']
            local r = sizedicons and sizedicons[clean]
            if r and type(r[1]) == "number" then
                return {
                    id = r[1],
                    imageRectSize = Vector2.new(r[2][1], r[2][2]),
                    imageRectOffset = Vector2.new(r[3][1], r[3][2])
                }
            end
            return "rbxassetid://10723434557"
        end
    else
        return IconModule.Material[icon] or IconModule.Material["view_in_ar"]
    end
end

-- ══════════════════════════════════════════════════════════════
--  SECCION 5: SISTEMA DE TEMAS, GRADIENTES & PALETAS
-- ══════════════════════════════════════════════════════════════
local Themes = {}
Themes.Predeterminado = "Negro"

Themes.Lista = {
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
        Accent          = Color3.fromRGB(140, 105, 210),
        AccentLight     = Color3.fromRGB(175, 145, 230),
        Highlight       = Color3.fromRGB(205, 185, 240),
        Text            = Color3.fromRGB(240, 240, 240),
        TextDark        = Color3.fromRGB(230, 230, 230),
        Border          = Color3.fromRGB(18, 12, 28),
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
    },
    Halloween = {
        Background      = Color3.fromRGB(32, 22, 45),
        BackgroundDark  = Color3.fromRGB(22, 14, 32),
        BackgroundLight = Color3.fromRGB(45, 32, 62),
        Accent          = Color3.fromRGB(255, 122, 24),
        AccentLight     = Color3.fromRGB(255, 168, 92),
        Highlight       = Color3.fromRGB(180, 240, 120),
        Text            = Color3.fromRGB(245, 240, 255),
        TextDark        = Color3.fromRGB(230, 220, 245),
        Border          = Color3.fromRGB(12, 8, 20),
        Panel           = Color3.fromRGB(38, 26, 52),
        PanelClaro      = Color3.fromRGB(50, 35, 68),
        Fila            = Color3.fromRGB(42, 30, 58),
        Entrada         = Color3.fromRGB(26, 17, 38),
        Apagado         = Color3.fromRGB(70, 60, 80),
    }
}

local PresetGradients = {
    ["Nightlight (Classic)"] = {Color3.fromRGB(147, 255, 239), Color3.fromRGB(201, 211, 233), Color3.fromRGB(255, 167, 227)},
    ["Nightlight (Neo)"]     = {Color3.fromRGB(117, 164, 206), Color3.fromRGB(123, 201, 201), Color3.fromRGB(224, 138, 175)},
    ["Starlight"]            = {Color3.fromRGB(147, 255, 239), Color3.fromRGB(181, 206, 241), Color3.fromRGB(214, 158, 243)},
    ["Solar"]                = {Color3.fromRGB(242, 157, 76), Color3.fromRGB(240, 179, 81), Color3.fromRGB(238, 201, 86)},
    ["Sparkle"]              = {Color3.fromRGB(199, 130, 242), Color3.fromRGB(221, 130, 238), Color3.fromRGB(243, 129, 233)},
    ["Lime"]                 = {Color3.fromRGB(170, 255, 127), Color3.fromRGB(163, 220, 138), Color3.fromRGB(155, 185, 149)},
    ["Vine"]                 = {Color3.fromRGB(0, 191, 143), Color3.fromRGB(0, 126, 94), Color3.fromRGB(0, 61, 46)},
    ["Cherry"]               = {Color3.fromRGB(148, 54, 54), Color3.fromRGB(168, 67, 70), Color3.fromRGB(188, 80, 86)},
    ["Daylight"]             = {Color3.fromRGB(51, 156, 255), Color3.fromRGB(89, 171, 237), Color3.fromRGB(127, 186, 218)},
    ["Blossom"]              = {Color3.fromRGB(255, 165, 243), Color3.fromRGB(213, 129, 231), Color3.fromRGB(170, 92, 218)},
}

local Theme = {}
for k, v in pairs(Themes.Lista[Themes.Predeterminado]) do Theme[k] = v end
AlanLuna.Theme = Theme

AlanLuna.ThemeGradient = ColorSequence.new{
    ColorSequenceKeypoint.new(0.00, Theme.Accent),
    ColorSequenceKeypoint.new(0.50, Theme.AccentLight),
    ColorSequenceKeypoint.new(1.00, Theme.Highlight)
}

local registroTema = {}
local muertosTema = 0

local function compactarRegistro(registro)
    local j = 0
    for i = 1, #registro do
        local e = registro[i]
        if not e.muerta then
            j = j + 1
            registro[j] = e
        end
    end
    for i = #registro, j + 1, -1 do registro[i] = nil end
end

function AlanLuna:Registrar(instancia, propiedad, claveTema)
    local entrada = {instancia = instancia, propiedad = propiedad, claveTema = claveTema}
    table.insert(registroTema, entrada)
    if typeof(instancia) == "Instance" then
        instancia.Destroying:Connect(function()
            entrada.muerta = true
            muertosTema = muertosTema + 1
            if muertosTema >= 64 and muertosTema * 4 >= #registroTema then
                muertosTema = 0
                compactarRegistro(registroTema)
            end
        end)
    end
end

-- ══════════════════════════════════════════════════════════════
--  SECCION 6: MOTION, TWEENING & LUNA GLASS BLUR MODULE
-- ══════════════════════════════════════════════════════════════
AlanLuna.Motion = {
    Directo         = 0,
    Press           = 0.14,
    Hover           = 0.25,
    HoverIntensidad = 0.20,
    FlashIn         = 0.08,
    FlashOut        = 0.35,
    Expand          = 0.30,
    Modal           = 0.35,
    Page            = 0.30,
    Spin            = 0.60,
    EaseEntrar      = Enum.EasingStyle.Exponential,
    EaseSalir       = Enum.EasingStyle.Exponential,
    EasePop         = Enum.EasingStyle.Back,
    EaseSuave       = Enum.EasingStyle.Exponential,
    EaseLineal      = Enum.EasingStyle.Linear,
}

local COLOR_FLASH_EXITO = Color3.fromRGB(46, 204, 113)
local COLOR_FLASH_ERROR = Color3.fromRGB(231, 76, 60)

local tweensActivos = setmetatable({}, {__mode = "k"})

local function clavePropiedades(props)
    local nombres = {}
    for nombre in pairs(props) do table.insert(nombres, nombre) end
    table.sort(nombres)
    return table.concat(nombres, ",")
end

local Utils = {}

function Utils.Tween(obj, props, tiempo, estilo, direccion, callback)
    if not obj or not obj.Parent then return nil end
    local clave = clavePropiedades(props)
    local porObjeto = tweensActivos[obj]
    local anterior = porObjeto and porObjeto[clave]
    if anterior then pcall(function() anterior:Cancel() end) end

    if tiempo == 0 then
        pcall(function()
            for prop, val in pairs(props) do obj[prop] = val end
        end)
        if callback then callback() end
        return nil
    end

    local info = TweenInfo.new(
        tiempo or AlanLuna.Motion.Expand,
        estilo or AlanLuna.Motion.EaseEntrar,
        direccion or Enum.EasingDirection.Out
    )
    local ok, tw = pcall(function()
        local t = TweenService:Create(obj, info, props)
        if callback then t.Completed:Connect(callback) end
        t:Play()
        return t
    end)
    if ok then
        tweensActivos[obj] = tweensActivos[obj] or {}
        tweensActivos[obj][clave] = tw
    end
    return ok and tw or nil
end

function tween(object, goal, callback, tweenin)
    return Utils.Tween(
        object,
        goal,
        tweenin and tweenin.Time or 0.3,
        tweenin and tweenin.EasingStyle or Enum.EasingStyle.Exponential,
        tweenin and tweenin.EasingDirection or Enum.EasingDirection.Out,
        callback
    )
end

local function BlurModule(Frame)
    local camera = Workspace.CurrentCamera
    local MTREL = "Glass"
    local root = Instance.new('Folder', camera)
    root.Name = 'AlanLunaBlur'
    AlanLuna:RegistrarInstancia(root)

    local gToken = math.random(1, 99999999)
    local DepthOfField = Instance.new('DepthOfFieldEffect', Lighting)
    DepthOfField.FarIntensity = 0
    DepthOfField.FocusDistance = 51.6
    DepthOfField.InFocusRadius = 50
    DepthOfField.NearIntensity = 6
    DepthOfField.Name = "DPT_" .. gToken
    AlanLuna:RegistrarInstancia(DepthOfField)

    local frame = Instance.new('Frame')
    frame.Parent = Frame
    frame.Size = UDim2.new(0.98, 0, 0.98, 0)
    frame.Position = UDim2.new(0.5, 0, 0.5, 0)
    frame.AnchorPoint = Vector2.new(0.5, 0.5)
    frame.BackgroundTransparency = 1

    local GenUid; do
        local id = 0
        function GenUid()
            id = id + 1
            return 'alanluna::' .. tostring(id)
        end
    end

    local DrawQuad; do
        local acos, max, pi, sqrt = math.acos, math.max, math.pi, math.sqrt
        local sz = 0.22
        local function DrawTriangle(v1, v2, v3, p0, p1)
            local s1 = (v1 - v2).magnitude
            local s2 = (v2 - v3).magnitude
            local s3 = (v3 - v1).magnitude
            local smax = max(s1, s2, s3)
            local A, B, C
            if s1 == smax then A, B, C = v1, v2, v3
            elseif s2 == smax then A, B, C = v2, v3, v1
            elseif s3 == smax then A, B, C = v3, v1, v2 end

            local para = ((B-A).x*(C-A).x + (B-A).y*(C-A).y + (B-A).z*(C-A).z) / (A-B).magnitude
            local perp = sqrt((C-A).magnitude^2 - para*para)
            local dif_para = (A - B).magnitude - para
            local st = CFrame.new(B, A)
            local za = CFrame.Angles(pi/2, 0, 0)
            local cf0 = st
            local Top_Look = (cf0 * za).lookVector
            local Mid_Point = A + CFrame.new(A, B).lookVector * para
            local Needed_Look = CFrame.new(Mid_Point, C).lookVector
            local dot = Top_Look.x*Needed_Look.x + Top_Look.y*Needed_Look.y + Top_Look.z*Needed_Look.z
            local ac = CFrame.Angles(0, 0, acos(dot))

            cf0 = cf0 * ac
            if ((cf0 * za).lookVector - Needed_Look).magnitude > 0.01 then
                cf0 = cf0 * CFrame.Angles(0, 0, -2*acos(dot))
            end
            cf0 = cf0 * CFrame.new(0, perp/2, -(dif_para + para/2))

            local cf1 = st * ac * CFrame.Angles(0, pi, 0)
            if ((cf1 * za).lookVector - Needed_Look).magnitude > 0.01 then
                cf1 = cf1 * CFrame.Angles(0, 0, 2*acos(dot))
            end
            cf1 = cf1 * CFrame.new(0, perp/2, dif_para/2)

            if not p0 then
                p0 = Instance.new('Part')
                p0.FormFactor = 'Custom'
                p0.TopSurface = 0
                p0.BottomSurface = 0
                p0.Anchored = true
                p0.CanCollide = false
                p0.CastShadow = false
                p0.Material = MTREL
                p0.Size = Vector3.new(sz, sz, sz)
                local mesh = Instance.new('SpecialMesh', p0)
                mesh.MeshType = 2
                mesh.Name = 'WedgeMesh'
            end
            p0.WedgeMesh.Scale = Vector3.new(0, perp/sz, para/sz)
            p0.CFrame = cf0

            if not p1 then p1 = p0:clone() end
            p1.WedgeMesh.Scale = Vector3.new(0, perp/sz, dif_para/sz)
            p1.CFrame = cf1
            return p0, p1
        end

        function DrawQuad(v1, v2, v3, v4, parts)
            parts[1], parts[2] = DrawTriangle(v1, v2, v3, parts[1], parts[2])
            parts[3], parts[4] = DrawTriangle(v3, v2, v4, parts[3], parts[4])
        end
    end

    local uid = GenUid()
    local parts = {}
    local f = Instance.new('Folder', root)
    f.Name = frame.Name

    local parents = {}
    local function add(child)
        if child:IsA'GuiObject' then
            parents[#parents + 1] = child
            add(child.Parent)
        end
    end
    add(frame)

    local function UpdateOrientation(fetchProps)
        if not (frame and frame.Parent and Frame and Frame.Parent) then
            pcall(function() RunService:UnbindFromRenderStep(uid) end)
            pcall(function() root:Destroy() end)
            pcall(function() DepthOfField:Destroy() end)
            return
        end
        local properties = {
            Transparency = 0.98,
            BrickColor = BrickColor.new('Institutional white'),
        }
        local zIndex = 1 - 0.05*frame.ZIndex
        local tl, br = frame.AbsolutePosition, frame.AbsolutePosition + frame.AbsoluteSize
        local tr, bl = Vector2.new(br.x, tl.y), Vector2.new(tl.x, br.y)
        do
            local rot = 0
            for _, v in ipairs(parents) do rot = rot + v.Rotation end
            if rot ~= 0 and rot%180 ~= 0 then
                local mid = tl:lerp(br, 0.5)
                local s, c = math.sin(math.rad(rot)), math.cos(math.rad(rot))
                local vec = tl
                tl = Vector2.new(c*(tl.x - mid.x) - s*(tl.y - mid.y), s*(tl.x - mid.x) + c*(tl.y - mid.y)) + mid
                tr = Vector2.new(c*(tr.x - mid.x) - s*(tr.y - mid.y), s*(tr.x - mid.x) + c*(tr.y - mid.y)) + mid
                bl = Vector2.new(c*(bl.x - mid.x) - s*(bl.y - mid.y), s*(bl.x - mid.x) + c*(bl.y - mid.y)) + mid
                br = Vector2.new(c*(br.x - mid.x) - s*(br.y - mid.y), s*(br.x - mid.x) + c*(br.y - mid.y)) + mid
            end
        end
        DrawQuad(
            camera:ScreenPointToRay(tl.x, tl.y, zIndex).Origin,
            camera:ScreenPointToRay(tr.x, tr.y, zIndex).Origin,
            camera:ScreenPointToRay(bl.x, bl.y, zIndex).Origin,
            camera:ScreenPointToRay(br.x, br.y, zIndex).Origin,
            parts
        )
        if fetchProps then
            for _, pt in pairs(parts) do pt.Parent = f end
            for propName, propValue in pairs(properties) do
                for _, pt in pairs(parts) do pt[propName] = propValue end
            end
        end
    end

    UpdateOrientation(true)
    RunService:BindToRenderStep(uid, 2000, UpdateOrientation)

    Frame.Destroying:Connect(function()
        pcall(function() RunService:UnbindFromRenderStep(uid) end)
        pcall(function() root:Destroy() end)
        pcall(function() DepthOfField:Destroy() end)
    end)
    return { Root = root, Effect = DepthOfField, Uid = uid }
end

-- ══════════════════════════════════════════════════════════════
--  SECCION 7: BASE UTILITIES (COMPACT & RESTYLED LUNA VISUAL)
-- ══════════════════════════════════════════════════════════════
local _contadorInstanciasUI = 0
local function contarInstanciaCreada(inst)
    _contadorInstanciasUI = _contadorInstanciasUI + 1
    inst.Destroying:Connect(function()
        _contadorInstanciasUI = _contadorInstanciasUI - 1
    end)
    return inst
end

function Utils.Corner(padre, radio)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, radio or 6)
    c.Parent = padre
    return c
end

function Utils.Stroke(padre, color, grosor, transparencia)
    local s = Instance.new("UIStroke")
    s.Color = color or Color3.fromRGB(64, 61, 76)
    s.Thickness = grosor or 1
    s.Transparency = transparencia or 0.5
    s.Parent = padre
    return s
end

function Utils.GradienteAcento(instancia, rotacion)
    local gradiente = Instance.new("UIGradient")
    gradiente.Color = AlanLuna.ThemeGradient
    gradiente.Rotation = rotacion or 0
    gradiente.Parent = instancia
    AlanLuna:Registrar(gradiente, "Color", function()
        return AlanLuna.ThemeGradient
    end)
    return gradiente
end

function Utils.Hover(objetoEventos, objetoColor, intensidad, duracion, obtenerColorBase)
    if not objetoEventos or not objetoColor then return end
    objetoColor = objetoColor or objetoEventos
    intensidad = intensidad or AlanLuna.Motion.HoverIntensidad
    duracion = duracion or AlanLuna.Motion.Hover

    local enHover = false
    local colorReposo = nil
    local reposoVigenteHasta = 0

    local stroke = objetoColor:FindFirstChildOfClass("UIStroke")

    AlanLuna:RegistrarConexion(objetoEventos.MouseEnter:Connect(function()
        if enHover then return end
        enHover = true
        pcall(function()
            local base = (obtenerColorBase and obtenerColorBase()) or objetoColor.BackgroundColor3
            colorReposo = base
            Utils.Tween(objetoColor, {
                BackgroundColor3 = base:Lerp(Color3.new(1, 1, 1), intensidad)
            }, duracion, AlanLuna.Motion.EaseEntrar)
            if stroke then
                Utils.Tween(stroke, {Color = Color3.fromRGB(87, 84, 104), Transparency = 0.3}, duracion, AlanLuna.Motion.EaseEntrar)
            end
        end)
    end))

    AlanLuna:RegistrarConexion(objetoEventos.MouseLeave:Connect(function()
        if not enHover then return end
        enHover = false
        pcall(function()
            local destino = (obtenerColorBase and obtenerColorBase()) or colorReposo
            if destino then
                colorReposo = destino
                reposoVigenteHasta = os.clock() + duracion + 0.08
                Utils.Tween(objetoColor, {BackgroundColor3 = destino}, duracion, AlanLuna.Motion.EaseEntrar)
            end
            if stroke then
                Utils.Tween(stroke, {Color = Color3.fromRGB(64, 61, 76), Transparency = 0.5}, duracion, AlanLuna.Motion.EaseEntrar)
            end
        end)
    end))
end

function Utils.ClickFeedback(objetoVisual)
    if not objetoVisual or not objetoVisual.Parent then return end
    local escala = objetoVisual:FindFirstChild("__AlanLuna_ClickScale")
    if not escala then
        escala = Instance.new("UIScale")
        escala.Name = "__AlanLuna_ClickScale"
        escala.Scale = 1
        escala.Parent = objetoVisual
    end
    escala.Scale = 0.97
    Utils.Tween(escala, {Scale = 1}, AlanLuna.Motion.Press, AlanLuna.Motion.EasePop)
end

function Utils.ClickConfiable(objeto, callback, objetoVisual)
    local UMBRAL_MOVIMIENTO_CLICK = 15
    local posDown = nil
    AlanLuna:RegistrarConexion(objeto.MouseButton1Down:Connect(function(x, y)
        posDown = Vector2.new(x, y)
        Utils.ClickFeedback(objetoVisual or objeto)
    end))
    AlanLuna:RegistrarConexion(objeto.MouseButton1Up:Connect(function(x, y)
        if not posDown then return end
        local movio = (Vector2.new(x, y) - posDown).Magnitude > UMBRAL_MOVIMIENTO_CLICK
        posDown = nil
        if movio then return end
        callback()
    end))
end

function Utils.HitboxAmpliado(boton, padding)
    padding = padding or 0
    if padding <= 0 or not boton then return boton end
    local hitbox = Utils.BotonBase({
        Padre = boton,
        Size = UDim2.new(1, padding * 2, 1, padding * 2),
        Posicion = UDim2.new(0, -padding, 0, -padding),
        Transparencia = 1,
        Radio = false,
    })
    hitbox.ZIndex = boton.ZIndex + 1
    return hitbox
end

function Utils.FlashFeedback(instancia, exito, colorNormal)
    if not instancia or not instancia.Parent then return end
    local colorFlash = exito and COLOR_FLASH_EXITO or COLOR_FLASH_ERROR
    pcall(function()
        Utils.Tween(instancia, {BackgroundColor3 = colorFlash}, AlanLuna.Motion.FlashIn)
        task.delay(AlanLuna.Motion.FlashIn, function()
            pcall(function()
                Utils.Tween(instancia, {BackgroundColor3 = colorNormal}, AlanLuna.Motion.FlashOut)
            end)
        end)
    end)
end

function Utils.Frame(cfg)
    cfg = cfg or {}
    local f = Instance.new("Frame")
    contarInstanciaCreada(f)
    f.Size = cfg.Size or UDim2.new(1, 0, 0, cfg.Alto or 26)
    f.Position = cfg.Posicion or UDim2.new(0, 0, 0, 0)
    if cfg.Ancla then f.AnchorPoint = cfg.Ancla end
    f.BackgroundColor3 = cfg.Color or Theme.Fila
    f.BackgroundTransparency = cfg.Transparencia or 0.5
    f.BorderSizePixel = 0
    f.ClipsDescendants = cfg.Recortar or false
    f.LayoutOrder = cfg.Orden or 0
    if cfg.Visible ~= nil then f.Visible = cfg.Visible end
    f.Parent = cfg.Padre
    if cfg.Radio ~= false then Utils.Corner(f, cfg.Radio or 6) end
    if cfg.Borde ~= false then
        local stroke = Utils.Stroke(f, cfg.ColorBorde or Color3.fromRGB(64, 61, 76), cfg.GrosorBorde or 1, cfg.TransparenciaBorde or 0.5)
        if cfg.ClaveTemaBorde then
            AlanLuna:Registrar(stroke, "Color", cfg.ClaveTemaBorde)
        end
    end
    return f
end

function Utils.Fila(padre, alto, orden, color)
    return Utils.Frame({
        Padre = padre,
        Size = UDim2.new(1, 0, 0, alto or 26),
        Orden = orden,
        Color = color or Theme.Fila,
        Radio = 6,
        Transparencia = 0.5,
        Borde = true
    })
end

local registroEscalaTexto = {}
local muertosEscalaTexto = 0
local escalasTexto = { tabs = 1, general = 1, titulo = 1 }

local function hayAncestroOculto(inst)
    local actual = inst
    while actual do
        if actual:IsA("GuiObject") and not actual.Visible then return true end
        actual = actual.Parent
    end
    return false
end

local function calcularYAplicarTamano(entrada)
    local inst = entrada.instancia
    if not (inst and inst.Parent) then return end
    local factor = escalasTexto[entrada.categoria] or 1
    local piso = 6
    local objetivo = math.max(piso, math.floor(entrada.base * factor + 0.5))

    if not entrada.truncable then
        pcall(function() inst.TextSize = objetivo end)
        return
    end

    local anchoDisponible = inst.AbsoluteSize.X
    if anchoDisponible <= 0 then
        if hayAncestroOculto(inst) then return end
        entrada.reintentos = (entrada.reintentos or 0) + 1
        if entrada.reintentos > 10 then return end
        task.defer(calcularYAplicarTamano, entrada)
        return
    end
    entrada.reintentos = 0

    local altoDisponible = inst.AbsoluteSize.Y > 0 and inst.AbsoluteSize.Y or 100
    local tamano = objetivo
    while tamano > piso do
        local okMedida, ancho = pcall(function()
            return TextService:GetTextSize(inst.Text, tamano, inst.Font, Vector2.new(10000, altoDisponible)).X
        end)
        if not okMedida or ancho <= anchoDisponible then break end
        tamano = tamano - 1
    end
    pcall(function() inst.TextSize = tamano end)
end

local function registrarEscalaTexto(instancia, tamanoBase, categoria, truncable)
    categoria = categoria or "general"
    local entrada = {
        instancia = instancia,
        base = tamanoBase,
        categoria = categoria,
        truncable = truncable or false,
        reintentos = 0,
    }
    table.insert(registroEscalaTexto, entrada)
    instancia.Destroying:Connect(function()
        entrada.muerta = true
        muertosEscalaTexto = muertosEscalaTexto + 1
        if muertosEscalaTexto >= 64 and muertosEscalaTexto * 4 >= #registroEscalaTexto then
            muertosEscalaTexto = 0
            compactarRegistro(registroEscalaTexto)
        end
    end)
    if truncable then
        AlanLuna:RegistrarConexion(instancia:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
            calcularYAplicarTamano(entrada)
        end))
        task.defer(calcularYAplicarTamano, entrada)
    elseif escalasTexto[categoria] ~= 1 then
        calcularYAplicarTamano(entrada)
    end
end

local function aplicarEscalaTexto(categoria, factor)
    escalasTexto[categoria] = factor
    for _, entrada in ipairs(registroEscalaTexto) do
        if entrada.categoria == categoria then
            calcularYAplicarTamano(entrada)
        end
    end
end

function Utils.Texto(cfg)
    cfg = cfg or {}
    local l = Instance.new("TextLabel")
    contarInstanciaCreada(l)
    l.BackgroundTransparency = 1
    l.Size = cfg.Size or UDim2.new(1, -6, 1, 0)
    l.Position = cfg.Posicion or UDim2.new(0, 6, 0, 0)
    l.Font = cfg.Fuente or Enum.Font.GothamMedium
    local tamanoBase = cfg.Tamano or 11
    l.TextSize = tamanoBase
    l.TextColor3 = cfg.Color or Theme.Text
    l.TextXAlignment = cfg.Alineacion or Enum.TextXAlignment.Left
    l.TextTruncate = cfg.Truncar and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None
    l.TextWrapped = cfg.Ajustar or false
    l.TextTransparency = cfg.TextoTransparencia or 0
    l.RichText = cfg.RichText or false
    l.Text = cfg.Texto or ""
    l.LayoutOrder = cfg.Orden or 0
    l.Parent = cfg.Padre

    if cfg.ColorTema then
        AlanLuna:Registrar(l, "TextColor3", cfg.ColorTema)
    elseif not cfg.Color then
        AlanLuna:Registrar(l, "TextColor3", "Text")
    end

    registrarEscalaTexto(l, tamanoBase, cfg.Categoria, cfg.Truncar)
    return l
end

function Utils.BotonBase(cfg)
    cfg = cfg or {}
    local b = Instance.new("TextButton")
    contarInstanciaCreada(b)
    b.Size = cfg.Size or UDim2.new(1, 0, 0, cfg.Alto or 26)
    b.Position = cfg.Posicion or UDim2.new(0, 0, 0, 0)
    if cfg.Ancla then b.AnchorPoint = cfg.Ancla end
    b.BackgroundTransparency = cfg.Transparencia == nil and 1 or cfg.Transparencia
    b.BackgroundColor3 = cfg.Color or Theme.Fila
    b.AutoButtonColor = false
    b.Text = ""
    b.BorderSizePixel = 0
    b.LayoutOrder = cfg.Orden or 0
    b.Parent = cfg.Padre
    if cfg.Radio ~= false then Utils.Corner(b, cfg.Radio or 6) end
    return b
end

function Utils.Diferir(fn)
    local pendiente = false
    return function()
        if pendiente then return end
        pendiente = true
        task.delay(0.03, function()
            pendiente = false
            fn()
        end)
    end
end

function Utils.FactorEscalaUI(inst)
    local f = 1
    local actual = inst
    while actual do
        local ok, sc = pcall(function() return actual:FindFirstChildOfClass("UIScale") end)
        if ok and sc then f = f * sc.Scale end
        actual = actual.Parent
    end
    return (f > 0) and f or 1
end

function Utils.HacerFilaDinamica(fila, lbl, altoMin, padY)
    padY = padY or 5
    lbl.TextWrapped   = true
    lbl.TextTruncate  = Enum.TextTruncate.None
    lbl.AutomaticSize = Enum.AutomaticSize.Y
    lbl.AnchorPoint   = Vector2.new(0, 0.5)
    lbl.Position      = UDim2.new(lbl.Position.X.Scale, lbl.Position.X.Offset, 0.5, 0)
    lbl.Size          = UDim2.new(lbl.Size.X.Scale, lbl.Size.X.Offset, 0, 0)
    local function recalcular()
        if not (fila.Parent and lbl.Parent) then return end
        local h = lbl.AbsoluteSize.Y
        if h <= 0 then return end
        local alto = math.max(altoMin, math.ceil(h / Utils.FactorEscalaUI(lbl)) + padY * 2)
        if fila.Size.Y.Offset ~= alto then
            fila.Size = UDim2.new(fila.Size.X.Scale, fila.Size.X.Offset, 0, alto)
        end
    end
    AlanLuna:RegistrarConexion(lbl:GetPropertyChangedSignal("AbsoluteSize"):Connect(Utils.Diferir(recalcular)))
    task.defer(recalcular)
end

local EventManager = {}
EventManager._activo = nil
EventManager._alFinalizar = nil

function EventManager:Arrastrar(callback, alFinalizar)
    self._activo = callback
    self._alFinalizar = alFinalizar
end

function EventManager:DetenerArrastre()
    self._activo = nil
    if self._alFinalizar then
        local cb = self._alFinalizar
        self._alFinalizar = nil
        pcall(cb)
    end
end

function EventManager:HayArrastreActivo()
    return self._activo ~= nil
end

if type(_G.AlanLuna_ConexionesEventManager) == "table" then
    for _, c in ipairs(_G.AlanLuna_ConexionesEventManager) do
        pcall(function() if c and c.Connected then c:Disconnect() end end)
    end
end
_G.AlanLuna_ConexionesEventManager = {}

local conexionInputChanged = UserInputService.InputChanged:Connect(function(input)
    if EventManager._activo and (
        input.UserInputType == Enum.UserInputType.MouseMovement or
        input.UserInputType == Enum.UserInputType.Touch
    ) then
        pcall(EventManager._activo, input)
    end
end)

local conexionInputEnded = UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or
       input.UserInputType == Enum.UserInputType.Touch then
        EventManager:DetenerArrastre()
    end
end)

table.insert(_G.AlanLuna_ConexionesEventManager, conexionInputChanged)
table.insert(_G.AlanLuna_ConexionesEventManager, conexionInputEnded)
AlanLuna.EventManager = EventManager

function Utils.Arrastrable(disparador, objetivo, eventMgr)
    local arrastrando = false
    local inicioArrastre, inicioObjetivo

    disparador.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            arrastrando     = true
            inicioArrastre  = Vector2.new(input.Position.X, input.Position.Y)
            inicioObjetivo  = objetivo.Position

            local conexionInputChanged
            conexionInputChanged = input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    arrastrando = false
                    if eventMgr then eventMgr:DetenerArrastre() end
                    if conexionInputChanged then
                        conexionInputChanged:Disconnect()
                        conexionInputChanged = nil
                    end
                end
            end)
            AlanLuna:RegistrarConexion(conexionInputChanged)

            if eventMgr then
                eventMgr:Arrastrar(function(inp)
                    if not arrastrando then return end
                    local delta = Vector2.new(inp.Position.X, inp.Position.Y) - inicioArrastre
                    objetivo.Position = UDim2.new(
                        inicioObjetivo.X.Scale,  inicioObjetivo.X.Offset + delta.X,
                        inicioObjetivo.Y.Scale,  inicioObjetivo.Y.Offset + delta.Y
                    )
                end)
            end
        end
    end)
end

local numeroTweensActivos = setmetatable({}, {__mode = "k"})

function Utils.TweenNumero(desde, hasta, duracion, callback, estilo, direccion, clave)
    if type(callback) ~= "function" then return end
    if desde == hasta then
        callback(hasta)
        return
    end

    local llave = clave or callback
    local anterior = numeroTweensActivos[llave]
    if anterior then
        pcall(function() anterior.tween:Cancel() end)
        pcall(function() anterior.valor:Destroy() end)
    end

    local valor = Instance.new("NumberValue")
    valor.Value = desde
    local conexion = valor:GetPropertyChangedSignal("Value"):Connect(function()
        pcall(callback, valor.Value)
    end)

    local info = TweenInfo.new(
        duracion or 0.22,
        estilo or AlanLuna.Motion.EaseEntrar,
        direccion or Enum.EasingDirection.Out
    )
    local ok, tw = pcall(function()
        return TweenService:Create(valor, info, {Value = hasta})
    end)
    if not ok then
        conexion:Disconnect()
        valor:Destroy()
        callback(hasta)
        return
    end

    local registro = {tween = tw, valor = valor}
    numeroTweensActivos[llave] = registro
    tw:Play()
    tw.Completed:Connect(function()
        conexion:Disconnect()
        valor:Destroy()
        if numeroTweensActivos[llave] == registro then numeroTweensActivos[llave] = nil end
    end)
end

function Utils.EnvolverInstancia(inst)
    local proxy = setmetatable({}, {
        __index = function(_, clave)
            local ok, valor = pcall(function() return inst[clave] end)
            if not ok then return nil end
            if type(valor) == "function" then
                return function(_, ...) return valor(inst, ...) end
            end
            return valor
        end,
        __newindex = function(_, clave, valor) inst[clave] = valor end,
    })
    rawset(proxy, "Instancia", inst)
    return proxy
end

function Utils.AnexarBloqueo(elem, fila)
    local overlay, lblMotivo, insignia
    local bloqueado, motivo = false, nil
    local POS_INSIGNIA = UDim2.new(1, -6, 0.5, 0)
    local tokenSacudida = 0
    rawset(elem, "Fila", fila)
    local trazo, tokenResaltado = nil, 0

    local function sinSelf(a, b)
        if a == elem then return b end
        return a
    end

    local function refrescarTexto()
        if lblMotivo then
            lblMotivo.Text = "🔒 " .. (motivo and motivo ~= "" and motivo or "Bloqueado")
        end
    end

    local function asegurarOverlay()
        if overlay and overlay.Parent then return end
        overlay = Instance.new("TextButton")
        overlay.Name = "AlanLuna_Locked"
        overlay.Size = UDim2.new(1, 0, 1, 0)
        overlay.BackgroundColor3 = Theme.BackgroundDark
        overlay.BackgroundTransparency = 0.35
        overlay.BorderSizePixel = 0
        overlay.AutoButtonColor = false
        overlay.Text = ""
        overlay.ZIndex = 100
        overlay.Visible = false
        overlay.Parent = fila
        local esquina = fila:FindFirstChildOfClass("UICorner")
        if esquina then Utils.Corner(overlay, esquina.CornerRadius.Offset) end
        AlanLuna:Registrar(overlay, "BackgroundColor3", "BackgroundDark")

        insignia = Utils.Frame({
            Padre = overlay, Size = UDim2.new(0.55, -6, 0, 22),
            Posicion = POS_INSIGNIA, Ancla = Vector2.new(1, 0.5),
            Color = Theme.Panel, Radio = 5,
        })
        insignia.ZIndex = 101
        AlanLuna:Registrar(insignia, "BackgroundColor3", "Panel")

        lblMotivo = Utils.Texto({
            Padre = insignia, Texto = "",
            Size = UDim2.new(1, -10, 1, 0), Posicion = UDim2.new(0, 5, 0, 0),
            Alineacion = Enum.TextXAlignment.Center, Tamano = 11, Truncar = true,
        })
        lblMotivo.ZIndex = 102

        Utils.ClickConfiable(overlay, function()
            if not (insignia and insignia.Parent) then return end
            tokenSacudida = tokenSacudida + 1
            local mio = tokenSacudida
            Utils.FlashFeedback(insignia, false, Theme.Panel)
            task.spawn(function()
                for _, dx in ipairs({-3, 3, -3, 3, 0}) do
                    if tokenSacudida ~= mio or not (insignia and insignia.Parent) then return end
                    Utils.Tween(insignia, {
                        Position = UDim2.new(POS_INSIGNIA.X.Scale, POS_INSIGNIA.X.Offset + dx, POS_INSIGNIA.Y.Scale, POS_INSIGNIA.Y.Offset),
                    }, 0.05, AlanLuna.Motion.EaseSuave)
                    task.wait(0.05)
                end
            end)
        end, insignia)
    end

    local function animarEntradaBloqueo()
        local transparenciaVelo = overlay.BackgroundTransparency
        local transparenciaInsignia = insignia.BackgroundTransparency
        local transparenciaTexto = lblMotivo.TextTransparency
        overlay.BackgroundTransparency = 1
        insignia.BackgroundTransparency = 1
        lblMotivo.TextTransparency = 1
        insignia.Position = UDim2.new(POS_INSIGNIA.X.Scale, POS_INSIGNIA.X.Offset + 20, POS_INSIGNIA.Y.Scale, POS_INSIGNIA.Y.Offset)
        Utils.Tween(overlay, {BackgroundTransparency = transparenciaVelo}, AlanLuna.Motion.Expand)
        Utils.Tween(insignia, {BackgroundTransparency = transparenciaInsignia, Position = POS_INSIGNIA}, AlanLuna.Motion.Expand, AlanLuna.Motion.EasePop)
        Utils.Tween(lblMotivo, {TextTransparency = transparenciaTexto}, AlanLuna.Motion.Expand)
    end

    local function bloquear(nuevoMotivo, animar)
        local yaBloqueado = bloqueado
        motivo = nuevoMotivo
        asegurarOverlay()
        refrescarTexto()
        overlay.Visible = true
        bloqueado = true
        if animar and not yaBloqueado and fila.AbsoluteSize.X > 0 then
            animarEntradaBloqueo()
        end
    end

    rawset(elem, "Lock", function(a, b)
        bloquear(sinSelf(a, b), true)
    end)

    rawset(elem, "Unlock", function()
        local estabaBloqueado = bloqueado
        bloqueado = false
        if overlay then overlay.Visible = false end
        if estabaBloqueado and overlay and fila.Parent and fila.AbsoluteSize.X > 0 then
            local fantasma = Instance.new("Frame")
            fantasma.Name = "__AlanLuna_LockFade"
            fantasma.Size = UDim2.new(1, 0, 1, 0)
            fantasma.BackgroundColor3 = overlay.BackgroundColor3
            fantasma.BackgroundTransparency = overlay.BackgroundTransparency
            fantasma.BorderSizePixel = 0
            fantasma.Active = false
            fantasma.ZIndex = overlay.ZIndex
            local esquinaOverlay = overlay:FindFirstChildOfClass("UICorner")
            if esquinaOverlay then Utils.Corner(fantasma, esquinaOverlay.CornerRadius.Offset) end
            fantasma.Parent = fila
            Utils.Tween(fantasma, {BackgroundTransparency = 1}, AlanLuna.Motion.Expand, AlanLuna.Motion.EaseSalir)
            task.delay(AlanLuna.Motion.Expand + 0.05, function()
                if fantasma.Parent then fantasma:Destroy() end
            end)
        end
    end)

    rawset(elem, "IsLocked", function() return bloqueado end)

    rawset(elem, "SetLockedTitle", function(a, b)
        motivo = sinSelf(a, b)
        refrescarTexto()
    end)

    rawset(elem, "Highlight", function(a, b)
        local opciones = sinSelf(a, b)
        local duracion = 2
        if type(opciones) == "number" then
            duracion = opciones
        elseif type(opciones) == "table" and type(opciones.Duracion) == "number" then
            duracion = opciones.Duracion
        end
        duracion = math.clamp(duracion, 0.5, 10)

        tokenResaltado = tokenResaltado + 1
        local mio = tokenResaltado
        if trazo then trazo:Destroy() end
        trazo = Instance.new("UIStroke")
        trazo.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        trazo.Thickness = 1.5
        trazo.Color = Theme.AccentLight
        trazo.Transparency = 1
        trazo.Parent = fila

        local pulsos = math.max(1, math.floor(duracion / 0.8))
        local propio = trazo
        local tw = TweenService:Create(propio,
            TweenInfo.new(0.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, pulsos - 1, true),
            {Transparency = 0})
        tw:Play()
        task.delay(duracion + 0.2, function()
            if propio.Parent then propio:Destroy() end
            if tokenResaltado == mio then trazo = nil end
        end)
    end)

    return function(nuevoMotivo) bloquear(nuevoMotivo, false) end
end

function Utils.EnvolverControlBloqueable(Seccion, contenedor, nombre)
    local original = Seccion[nombre]
    if type(original) ~= "function" then return end
    Seccion[nombre] = function(self, cfg)
        local previos = {}
        for _, hijo in ipairs(contenedor:GetChildren()) do previos[hijo] = true end
        local resultado = original(self, cfg)
        local fila
        for _, hijo in ipairs(contenedor:GetChildren()) do
            if not previos[hijo] and hijo:IsA("GuiObject")
                and (not fila or hijo.LayoutOrder > fila.LayoutOrder) then
                fila = hijo
            end
        end
        if not fila then return resultado end
        local elem = resultado
        if typeof(resultado) == "Instance" then elem = Utils.EnvolverInstancia(resultado) end
        if type(elem) ~= "table" then return resultado end
        local bloquearInicial = Utils.AnexarBloqueo(elem, fila)
        if type(cfg) == "table" and cfg.Locked then bloquearInicial(cfg.LockedTitle) end
        return elem
    end
end

function Utils.FundirEntrada(raiz, duracion, incluirRaiz)
    local objetivos = {}
    local function registrar(inst)
        if inst:IsA("GuiObject") then
            if inst.BackgroundTransparency < 0.99 then
                table.insert(objetivos, {inst, "BackgroundTransparency", inst.BackgroundTransparency})
            end
            if (inst:IsA("TextLabel") or inst:IsA("TextButton") or inst:IsA("TextBox")) and inst.TextTransparency < 0.99 then
                table.insert(objetivos, {inst, "TextTransparency", inst.TextTransparency})
            end
            if (inst:IsA("ImageLabel") or inst:IsA("ImageButton")) and inst.ImageTransparency < 0.99 then
                table.insert(objetivos, {inst, "ImageTransparency", inst.ImageTransparency})
            end
        elseif inst:IsA("UIStroke") and inst.Transparency < 0.99 then
            table.insert(objetivos, {inst, "Transparency", inst.Transparency})
        end
    end
    if incluirRaiz then registrar(raiz) end
    for _, d in ipairs(raiz:GetDescendants()) do registrar(d) end
    for _, o in ipairs(objetivos) do o[1][o[2]] = 1 end
    for _, o in ipairs(objetivos) do
        Utils.Tween(o[1], {[o[2]] = o[3]}, duracion, AlanLuna.Motion.EaseEntrar)
    end
end

function Utils.AnimarInsercion(marco, eje)
    if not (marco and marco.Parent) then return end
    local tamFinal = marco.Size
    local clipOriginal = marco.ClipsDescendants
    marco.ClipsDescendants = true
    if eje == "x" then
        marco.Size = UDim2.new(tamFinal.X.Scale, 0, tamFinal.Y.Scale, tamFinal.Y.Offset)
    else
        marco.Size = UDim2.new(tamFinal.X.Scale, tamFinal.X.Offset, tamFinal.Y.Scale, 0)
    end
    Utils.FundirEntrada(marco, AlanLuna.Motion.Expand, false)
    Utils.Tween(marco, {Size = tamFinal}, AlanLuna.Motion.Expand, AlanLuna.Motion.EaseEntrar)
    task.delay(AlanLuna.Motion.Expand + 0.05, function()
        if marco.Parent then
            marco.Size = tamFinal
            marco.ClipsDescendants = clipOriginal
        end
    end)
end

function Utils.EntradaModal(fondo, card)
    local transparenciaFondo = fondo.BackgroundTransparency
    fondo.BackgroundTransparency = 1
    local escala = Instance.new("UIScale")
    escala.Scale = 0.95
    escala.Parent = card
    Utils.FundirEntrada(card, AlanLuna.Motion.Modal, true)
    Utils.Tween(fondo, {BackgroundTransparency = transparenciaFondo}, AlanLuna.Motion.Expand, AlanLuna.Motion.EaseEntrar)
    Utils.Tween(escala, {Scale = 1}, AlanLuna.Motion.Modal, AlanLuna.Motion.EasePop)
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

function Utils.AnexarDescripcion(fila, padre, orden, texto, anchoZona)
    local panel = Utils.Frame({
        Padre = padre, Size = UDim2.new(1, 0, 0, 0),
        Color = Theme.Fila, Orden = orden, Radio = 6,
    })
    panel.AutomaticSize = Enum.AutomaticSize.Y
    panel.Visible = false
    AlanLuna:Registrar(panel, "BackgroundColor3", "Fila")

    local relleno = Instance.new("UIPadding")
    relleno.PaddingTop, relleno.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
    relleno.PaddingLeft, relleno.PaddingRight = UDim.new(0, 24), UDim.new(0, 10)
    relleno.Parent = panel

    local lblDescripcion = Utils.Texto({
        Padre = panel, Texto = tostring(texto),
        Size = UDim2.new(1, 0, 0, 0), Posicion = UDim2.new(0, 0, 0, 0),
        Ajustar = true, Tamano = 10, Color = Theme.TextDark, ColorTema = "TextDark",
    })
    lblDescripcion.AutomaticSize = Enum.AutomaticSize.Y

    local zona = Utils.BotonBase({
        Padre = fila, Size = anchoZona or UDim2.new(1, 0, 1, 0),
        Color = Theme.Fila, Transparencia = 1, Radio = 6,
    })
    local flecha = Instance.new("ImageLabel")
    flecha.BackgroundTransparency = 1
    flecha.Image = "rbxassetid://83472139709682"
    flecha.ScaleType = Enum.ScaleType.Fit
    flecha.Size = UDim2.new(0, 9, 0, 9)
    flecha.AnchorPoint = Vector2.new(0.5, 0.5)
    flecha.Position = UDim2.new(0, 12, 0.5, 0)
    flecha.Rotation = -90
    flecha.Parent = fila
    AlanLuna:Registrar(flecha, "ImageColor3", "Text")

    Utils.ClickConfiable(zona, function()
        panel.Visible = not panel.Visible
        Utils.Tween(flecha, {Rotation = panel.Visible and 0 or -90}, AlanLuna.Motion.Expand)
    end)
    return panel
end

-- ══════════════════════════════════════════════════════════════
--  SECCION 8: STATE SYSTEM, PROXY AUTOSAVE & KEYBIND REGISTRY
-- ══════════════════════════════════════════════════════════════
local function nuevaTablaElementos()
    return setmetatable({}, {
        __newindex = function(t, flag, elem)
            rawset(t, flag, elem)
            if type(elem) == "table" and type(elem.Get) == "function" then
                local ok, valor = pcall(elem.Get)
                if ok and valor ~= nil then elem._defecto = copiarDefecto(valor) end
            end
        end,
    })
end

AlanLuna.Elementos = nuevaTablaElementos()
AlanLuna.Options = {}

local ventanaActivaGuardado = nil
local hayCambiosSinGuardar = false
local loopAutoguardadoActivo = false
local _cargandoDesdeArchivo = false

local function marcarCambioPendiente()
    if _cargandoDesdeArchivo then return end
    hayCambiosSinGuardar = true
end

local function iniciarLoopAutoguardado()
    if loopAutoguardadoActivo then return end
    loopAutoguardadoActivo = true
    AlanLuna:RegistrarHilo(task.spawn(function()
        while loopAutoguardadoActivo do
            task.wait(10)
            if hayCambiosSinGuardar and ventanaActivaGuardado and ventanaActivaGuardado.NombreConfig and AlanLuna.SaveManager then
                hayCambiosSinGuardar = false
                pcall(function()
                    AlanLuna.SaveManager:GuardarSilencioso(ventanaActivaGuardado.NombreConfig)
                end)
            end
        end
    end))
end

local _ventanasConSelectorTemas = setmetatable({}, {__mode = "k"})
local _flagsReales = {}
local _flagsNoPersistir = {}
local _flagsUI = {}
local _keybindsRegistrados = {}

local function _descomponerTecla(v)
    if typeof(v) == "table" then
        return v.KeyCode, v.Ctrl or false, v.Shift or false, v.Alt or false
    end
    return v, false, false, false
end

local function _formatoTecla(keyCode, ctrl, shift, alt)
    if not keyCode or keyCode == Enum.KeyCode.Unknown then return "Ninguna" end
    local partes = {}
    if ctrl then table.insert(partes, "Ctrl") end
    if shift then table.insert(partes, "Shift") end
    if alt then table.insert(partes, "Alt") end
    table.insert(partes, keyCode.Name)
    return table.concat(partes, "+")
end

local function _teclasEnConflicto(a, b)
    local kA, cA, sA, aA = _descomponerTecla(a)
    local kB, cB, sB, aB = _descomponerTecla(b)
    if not kA or not kB then return false end
    if kA == Enum.KeyCode.Unknown or kB == Enum.KeyCode.Unknown then return false end
    return kA == kB and cA == cB and sA == sB and aA == aB
end

local function _revisarConflictoKeybind(entryPropio, nuevoValor)
    local conflictos = {}
    for _, entrada in ipairs(_keybindsRegistrados) do
        if entrada ~= entryPropio then
            local okValor, valorAjeno = pcall(entrada.GetValor)
            if okValor and _teclasEnConflicto(nuevoValor, valorAjeno) then
                table.insert(conflictos, entrada.texto or "Keybind")
            end
        end
    end
    if #conflictos > 0 then
        local k, c, s, a = _descomponerTecla(nuevoValor)
        pcall(function()
            AlanLuna:Notificar({
                Title    = "⚠️ Tecla en uso",
                Content  = "'" .. _formatoTecla(k, c, s, a) .. "' ya está asignada a: " .. table.concat(conflictos, ", "),
                Duration = 4,
                Icon     = "warning"
            })
        end)
    end
end

local function _revisarConflictosAlCargar()
    if #_keybindsRegistrados < 2 then return end
    local porFirma = {}
    for _, entrada in ipairs(_keybindsRegistrados) do
        local ok, valor = pcall(entrada.GetValor)
        if ok then
            local k, c, s, a = _descomponerTecla(valor)
            if k and k ~= Enum.KeyCode.Unknown then
                local firma = k.Name .. "|" .. tostring(c) .. "|" .. tostring(s) .. "|" .. tostring(a)
                porFirma[firma] = porFirma[firma] or {
                    k = k, c = c, s = s, a = a, textos = {},
                }
                table.insert(porFirma[firma].textos, entrada.texto or "Keybind")
            end
        end
    end

    for _, grupo in pairs(porFirma) do
        if #grupo.textos >= 2 then
            pcall(function()
                AlanLuna:Notificar({
                    Title    = "⚠️ Teclas en conflicto",
                    Content  = "'" .. _formatoTecla(grupo.k, grupo.c, grupo.s, grupo.a) .. "' está asignada a: " .. table.concat(grupo.textos, ", "),
                    Duration = 6,
                    Icon     = "warning"
                })
            end)
        end
    end
end

local function crearSenal()
    local conectados = {}
    local senal = {}
    function senal:Connect(callback)
        if type(callback) ~= "function" then
            return {Disconnect = function() end}
        end
        local entrada = {activo = true, callback = callback}
        table.insert(conectados, entrada)
        return {
            Disconnect = function() entrada.activo = false end,
        }
    end
    function senal:Fire(...)
        local instantanea = table.move(conectados, 1, #conectados, 1, {})
        for _, entrada in ipairs(instantanea) do
            if entrada.activo then
                local ok, err = pcall(entrada.callback, ...)
                if not ok then AlanLuna:_RegistrarError("Eventos", err) end
            end
        end
    end
    return senal
end

AlanLuna.Eventos = {
    FlagCambiada      = crearSenal(),
    TabCambiada       = crearSenal(),
    TemaCambiado      = crearSenal(),
    ControlRegistrado = crearSenal(),
    TipoCambiado      = crearSenal(),
    HistorialCambiado = crearSenal(),
    CategoriaCambiada = crearSenal(),
    SubTabCambiada    = crearSenal(),
}

AlanLuna.Flags = setmetatable({}, {
    __index = _flagsReales,
    __newindex = function(_, clave, valor)
        if type(valor) ~= "table" and _flagsReales[clave] == valor then
            return
        end
        _flagsReales[clave] = valor
        marcarCambioPendiente()
        if AlanLuna.Eventos then
            AlanLuna.Eventos.FlagCambiada:Fire(clave, valor)
        end
    end,
})

function AlanLuna:ObtenerFlag(flag)
    return AlanLuna.Flags[flag]
end

function AlanLuna:ObtenerElemento(flag)
    return AlanLuna.Elementos[flag]
end

function AlanLuna:ActualizarLabel(flag, texto)
    local elem = self.Elementos[flag]
    if not elem then return false end
    return pcall(elem.Set, texto)
end

function AlanLuna:MarcarComoUI(flagOTabla)
    if type(flagOTabla) == "table" then
        for _, f in ipairs(flagOTabla) do _flagsUI[f] = true end
    else
        _flagsUI[flagOTabla] = true
    end
end

function AlanLuna:Try(flag, fallback)
    local elem = self.Elementos[flag]
    if not elem then return fallback end
    local ok, val = pcall(elem.Get)
    if not ok or val == nil then return fallback end
    return val
end

-- ══════════════════════════════════════════════════════════════
--  SECCION 9: ERROR HANDLING & LOGGING ENGINE
-- ══════════════════════════════════════════════════════════════
local MAX_LOGS_ERRORES = 50
AlanLuna._Logs = {}

function AlanLuna:_RegistrarError(contexto, mensaje)
    table.insert(self._Logs, {
        Momento  = os.time(),
        Contexto = tostring(contexto or "?"),
        Mensaje  = tostring(mensaje or ""),
    })
    if #self._Logs > MAX_LOGS_ERRORES then
        table.remove(self._Logs, 1)
    end
    warn("[AlanLuna] Error en '" .. tostring(contexto or "?") .. "': " .. tostring(mensaje or ""))
end

function AlanLuna:ObtenerErrores()
    local copia = {}
    for i, entrada in ipairs(self._Logs) do copia[i] = clonarTabla(entrada) end
    return copia
end

local function intentarSilencioso(descripcion, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and AlanLuna.DebugMode then
        warn("[AlanLuna] (DebugMode) '" .. descripcion .. "' falló: " .. tostring(err))
    end
    return ok, err
end

local function advertirDev(tipo, nombre, mensaje)
    warn(("[AlanLuna] %s \"%s\": %s"):format(tipo, tostring(nombre or "?"), mensaje))
end

local function ejecutarConFallback(callback, contexto, ...)
    if not callback then return end
    local args = {...}
    local ok, err = pcall(function() return callback(table.unpack(args)) end)
    if not ok then
        AlanLuna:_RegistrarError(contexto, err)
        local mensajeCompleto = tostring(err)
        local mensajeMostrado = mensajeCompleto:sub(1, 120)
        if #mensajeCompleto > 120 then
            mensajeMostrado = mensajeMostrado .. "… (ver AlanLuna:ObtenerErrores())"
        end
        if AlanLuna.MostrarErroresEnUI ~= false and AlanLuna.Notificar then
            pcall(function()
                AlanLuna:Notificar({
                    Title = "⚠️ Error en " .. (contexto or "control"),
                    Content = mensajeMostrado,
                    Duration = 6,
                    Icon = "warning"
                })
            end)
        end
        warn("[AlanLuna] Callback error (" .. (contexto or "?") .. "):", err)
    end
    return ok
end

local function validarCallback(tipo, cfg)
    if cfg.Callback ~= nil and type(cfg.Callback) ~= "function" then
        advertirDev(tipo, cfg.Texto, "'Callback' se pasó pero no es una función (es " .. typeof(cfg.Callback) .. "). Se ignoró.")
        cfg.Callback = nil
    end
end

-- ══════════════════════════════════════════════════════════════
--  SECCION 10: HARDWARE CAPABILITIES & ENVIRONMENT DIAGNOSTICS
-- ══════════════════════════════════════════════════════════════
local function detectarEjecutor()
    if type(getexecutorname) == "function" then
        local ok, nombre = pcall(getexecutorname)
        if ok and nombre and nombre ~= "" then return nombre end
    end
    local lista = {
        {function() return syn ~= nil end, "Synapse X"},
        {function() return krnl ~= nil end, "Krnl"},
        {function() return fluxus ~= nil end, "Fluxus"},
        {function() return sirhurt ~= nil end, "SirHurt"},
        {function() return PROTOSMASHER_LOADED ~= nil end, "ProtoSmasher"},
        {function() return is_sirhurt_closure ~= nil end, "SirHurt (alt)"},
        {function() return identifyexecutor ~= nil end, (identifyexecutor and identifyexecutor()) or "Identified Executor"},
    }
    for _, entrada in ipairs(lista) do
        local ok2, esEse = pcall(entrada[1])
        if ok2 and esEse then return entrada[2] end
    end
    return "Desconocido"
end

local TIPOS_ENTORNO_VALIDOS = {
    PC = true, Movil = true, Tablet = true,
    Consola = true, Studio = true, Desconocido = true,
}

AlanLuna.Capacidades = {
    Archivos     = fsDisponible(),
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
        return (ok and p) or nil
    end)(),
    ViewportSize = (function()
        local c = Workspace.CurrentCamera
        return c and c.ViewportSize or Vector2.new(0, 0)
    end)(),
    Tipo         = "Desconocido",
    EsTactil     = false,
    EsEscritorio = false,
    EsTouchOnly  = false,
}

function AlanLuna.Capacidades:NombrePlataforma()
    local p = self.Plataforma
    if not p then return "Desconocida" end
    return p.Name or tostring(p)
end

function AlanLuna:RecalcularDerivadosEntorno()
    local C = self.Capacidades
    local PLATAFORMAS_CONSOLA = {
        XboxOne = true, XboxSeriesX = true, XboxSeriesS = true,
        PS4 = true, PS5 = true, UWP = true,
    }
    local nombrePlataforma = C.Plataforma and C.Plataforma.Name
    local tipo

    if _G.AlanLuna_TipoForzado and TIPOS_ENTORNO_VALIDOS[_G.AlanLuna_TipoForzado] then
        tipo = _G.AlanLuna_TipoForzado
    elseif C.EsStudio then
        tipo = "Studio"
    elseif nombrePlataforma and PLATAFORMAS_CONSOLA[nombrePlataforma] then
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

AlanLuna:RecalcularDerivadosEntorno()

if type(_G.AlanLuna_ConexionesCapacidades) == "table" then
    for _, c in ipairs(_G.AlanLuna_ConexionesCapacidades) do
        pcall(function() if c and c.Connected then c:Disconnect() end end)
    end
end
_G.AlanLuna_ConexionesCapacidades = {}

local function engancharViewportCapacidades(camara)
    if not camara then return end
    local conexion = camara:GetPropertyChangedSignal("ViewportSize"):Connect(function()
        AlanLuna.Capacidades.ViewportSize = camara.ViewportSize
        AlanLuna:RecalcularDerivadosEntorno()
    end)
    table.insert(_G.AlanLuna_ConexionesCapacidades, conexion)
end

engancharViewportCapacidades(Workspace.CurrentCamera)
table.insert(_G.AlanLuna_ConexionesCapacidades,
    Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
        local c = Workspace.CurrentCamera
        if not c then return end
        AlanLuna.Capacidades.ViewportSize = c.ViewportSize
        AlanLuna:RecalcularDerivadosEntorno()
        engancharViewportCapacidades(c)
    end)
)

AlanLuna.Features = {
    { nombre = "GUI",          claveCapacidad = nil,          test = function() return true end, nivel = "requerido" },
    { nombre = "Archivos",     claveCapacidad = "Archivos",   nivel = "recomendado", mensaje = "No se podrán guardar configuraciones." },
    { nombre = "Drawing",      claveCapacidad = "Drawing",    nivel = "recomendado", mensaje = "Los ESP visuales no funcionarán." },
    { nombre = "ProtectGUI",   claveCapacidad = "ProtectGUI", nivel = "recomendado", mensaje = "La GUI puede ser detectada por anti-cheats." },
    { nombre = "GetHUI",       claveCapacidad = "GetHUI",     nivel = "recomendado", mensaje = "La GUI puede quedar detrás del CoreGui." },
    { nombre = "Teclado",      claveCapacidad = "Teclado",    nivel = "opcional",    mensaje = "Los Keybind se activarán en modo táctil." },
    { nombre = "Gamepad",      claveCapacidad = "Gamepad",    nivel = "opcional",    mensaje = "No se podrá usar control para atajos." },
    { nombre = "Loadstring",   test = function() return type(loadstring) == "function" end, nivel = "opcional", mensaje = "No se podrán cargar scripts externos." },
    { nombre = "SetClipboard", test = function() return type(setclipboard) == "function" end, nivel = "opcional", mensaje = "No se podrá copiar texto al portapapeles." },
}

local _indiceFeatures = {}
for _, f in ipairs(AlanLuna.Features) do _indiceFeatures[f.nombre] = f end

function AlanLuna:VerificarSoporte(nombre)
    local f = _indiceFeatures[nombre]
    if not f then
        return { ok = false, nivel = "desconocido", nombre = nombre, mensaje = "Función no reconocida por AlanLuna." }
    end
    local ok = false
    if f.claveCapacidad then
        ok = self.Capacidades[f.claveCapacidad] == true
    elseif f.test then
        local okTest, r = pcall(f.test)
        ok = okTest and r == true
    end
    return { ok = ok, nivel = f.nivel, nombre = f.nombre, mensaje = ok and nil or f.mensaje }
end

function AlanLuna:ForzarTipo(tipo)
    if tipo and not TIPOS_ENTORNO_VALIDOS[tipo] then
        return false, "Tipo inválido. Válidos: PC, Movil, Tablet, Consola, Studio, Desconocido."
    end
    _G.AlanLuna_TipoForzado = tipo
    self:RecalcularDerivadosEntorno()
    return true
end

function AlanLuna:LiberarForzado()
    return self:ForzarTipo(nil)
end

function AlanLuna:DiagnosticoCompleto()
    local C = self.Capacidades
    local soportadas, total, advertencias = 0, 0, {}
    for _, f in ipairs(self.Features) do
        total = total + 1
        local r = self:VerificarSoporte(f.nombre)
        if r.ok then
            soportadas = soportadas + 1
        elseif f.nivel ~= "requerido" then
            table.insert(advertencias, {
                nombre  = f.nombre,
                nivel   = f.nivel,
                mensaje = r.mensaje,
            })
        end
    end
    return {
        Tipo          = C.Tipo,
        Plataforma    = C:NombrePlataforma(),
        EsStudio      = C.EsStudio,
        Ejecutor      = detectarEjecutor(),
        Viewport      = C.ViewportSize,
        Forzado       = _G.AlanLuna_TipoForzado,
        FeaturesOk    = soportadas,
        FeaturesTotal = total,
        Advertencias  = advertencias,
        Capacidades   = C,
    }
end

function AlanLuna:Profiler()
    local datos = {
        Flags      = 0,
        Elementos  = 0,
        Conexiones = 0,
        Hilos      = 0,
        Dibujos    = 0,
        Instancias = 0,
        ObjetosGui = 0,
        MemoriaMb  = nil,
    }
    for _ in pairs(_flagsReales) do datos.Flags = datos.Flags + 1 end
    for _ in pairs(AlanLuna.Elementos) do datos.Elementos = datos.Elementos + 1 end
    local instancia = _G.AlanLuna_Instancia
    if instancia then
        datos.Conexiones = #(instancia.Conexiones or {})
        datos.Hilos      = #(instancia.Hilos or {})
        datos.Dibujos    = #(instancia.Dibujos or {})
        datos.Instancias = #(instancia.Instancias or {})
    end
    local okGui, padreGui = pcall(obtenerPadreGui)
    if okGui and padreGui then
        local sg = padreGui:FindFirstChild("AlanLuna_ScreenGui")
        if sg then
            local okDesc, desc = pcall(function() return sg:GetDescendants() end)
            if okDesc then datos.ObjetosGui = #desc end
        end
    end
    local okStats, statsService = pcall(function() return game:GetService("Stats") end)
    if okStats and statsService then
        local okMem, mem = pcall(function() return statsService:GetTotalMemoryUsageMb() end)
        if okMem and type(mem) == "number" and mem > 0 then
            datos.MemoriaMb = math.floor(mem + 0.5)
        end
    end
    print(("[AlanLuna] Profiler -> Flags:%d  Elementos:%d  Conexiones:%d  Hilos:%d  Dibujos:%d  Instancias:%d  ObjetosGUI:%d  Memoria:%s")
        :format(datos.Flags, datos.Elementos, datos.Conexiones, datos.Hilos,
                datos.Dibujos, datos.Instancias, datos.ObjetosGui,
                datos.MemoriaMb and ("~" .. datos.MemoriaMb .. "MB") or "N/D"))
    return datos
end

-- ══════════════════════════════════════════════════════════════
--  SECCION 11: UNDO / REDO HISTORY ENGINE
-- ══════════════════════════════════════════════════════════════
AlanLuna._historial = { deshacer = {}, rehacer = {}, ultimos = {}, pausa = 0 }
local MAX_HISTORIAL = 50

local function avisarHistorial()
    local h = AlanLuna._historial
    AlanLuna.Eventos.HistorialCambiado:Fire(#h.deshacer, #h.rehacer)
end

if type(_G.AlanLuna_ConexionesModulo) == "table" then
    for _, c in ipairs(_G.AlanLuna_ConexionesModulo) do
        pcall(function() c:Disconnect() end)
    end
end
_G.AlanLuna_ConexionesModulo = {}

table.insert(_G.AlanLuna_ConexionesModulo, AlanLuna.Eventos.FlagCambiada:Connect(function(flag, valor)
    local h = AlanLuna._historial
    local previo = h.ultimos[flag]
    h.ultimos[flag] = copiarDefecto(valor)
    if h.pausa > 0 or _flagsUI[flag] or _flagsNoPersistir[flag] then return end
    local elem = AlanLuna.Elementos[flag]
    if previo == nil and elem then previo = elem._defecto end
    if previo == nil then return end
    if type(valor) ~= "table" and previo == valor then return end

    local ahora = os.clock()
    local ultima = h.deshacer[#h.deshacer]
    if ultima and #ultima.cambios == 1 and ultima.cambios[1].flag == flag and ahora - ultima.t < 0.6 then
        ultima.cambios[1].despues = copiarDefecto(valor)
        ultima.t = ahora
        if type(valor) ~= "table" and ultima.cambios[1].antes == valor then
            table.remove(h.deshacer)
        end
    elseif ultima and ahora - ultima.t < 0.05 then
        table.insert(ultima.cambios, { flag = flag, antes = copiarDefecto(previo), despues = copiarDefecto(valor) })
        ultima.t = ahora
    else
        table.insert(h.deshacer, {
            t = ahora,
            cambios = { { flag = flag, antes = copiarDefecto(previo), despues = copiarDefecto(valor) } },
        })
        if #h.deshacer > MAX_HISTORIAL then table.remove(h.deshacer, 1) end
    end
    h.rehacer = {}
    avisarHistorial()
end))

local function aplicarCambiosHistorial(cambios, usarAntes, enReverso)
    local h = AlanLuna._historial
    h.pausa = h.pausa + 1
    local total = #cambios
    for i = 1, total do
        local c = cambios[enReverso and (total - i + 1) or i]
        local elem = AlanLuna.Elementos[c.flag]
        if elem and type(elem.Set) == "function" then
            local fuente = usarAntes and c.antes or c.despues
            local valor = copiarDefecto(fuente)
            pcall(elem.Set, valor, true)
            h.ultimos[c.flag] = copiarDefecto(valor)
        end
    end
    h.pausa = h.pausa - 1
end

function AlanLuna:Deshacer()
    local h = self._historial
    local entrada = table.remove(h.deshacer)
    if not entrada then return false end
    aplicarCambiosHistorial(entrada.cambios, true, true)
    table.insert(h.rehacer, entrada)
    avisarHistorial()
    return true, entrada
end

function AlanLuna:Rehacer()
    local h = self._historial
    local entrada = table.remove(h.rehacer)
    if not entrada then return false end
    aplicarCambiosHistorial(entrada.cambios, false, false)
    table.insert(h.deshacer, entrada)
    avisarHistorial()
    return true, entrada
end

function AlanLuna:PuedeDeshacer() return #self._historial.deshacer > 0 end
function AlanLuna:PuedeRehacer() return #self._historial.rehacer > 0 end
function AlanLuna:ObtenerHistorial() return { Deshacer = #self._historial.deshacer, Rehacer = #self._historial.rehacer } end

function AlanLuna:LimpiarHistorial()
    local h = self._historial
    h.deshacer, h.rehacer, h.ultimos = {}, {}, {}
    for flag, elem in pairs(self.Elementos) do
        if type(elem) == "table" and type(elem.Get) == "function" then
            local ok, valor = pcall(elem.Get)
            if ok and valor ~= nil then h.ultimos[flag] = copiarDefecto(valor) end
        end
    end
    avisarHistorial()
end

function AlanLuna:DescribirCambio(entrada)
    if type(entrada) ~= "table" or not entrada.cambios or #entrada.cambios == 0 then return "" end
    local primero = entrada.cambios[1]
    local function texto(v)
        if type(v) == "table" then return "[tabla]" end
        return tostring(v)
    end
    local resumen = tostring(primero.flag) .. ": " .. texto(primero.antes) .. " -> " .. texto(primero.despues)
    if #entrada.cambios > 1 then resumen = resumen .. " (+" .. (#entrada.cambios - 1) .. ")" end
    return resumen
end

-- ══════════════════════════════════════════════════════════════
--  SECCION 12: UNIFIED SAVE MANAGER v3 (LUNA & ALANUI FORMATS)
-- ══════════════════════════════════════════════════════════════
local VERSION_FORMATO_GUARDADO = 3
_G.AlanLuna_EstadoNavegacion = { cat = nil, tab = nil, sub = nil }

local function esColor3(v) return typeof and typeof(v) == "Color3" end
local function esEnum(v) return typeof and typeof(v) == "EnumItem" end

local function empaquetarFlagsParaGuardar(flags, soloUI)
    local resultado = {
        __version = VERSION_FORMATO_GUARDADO,
        __navegacion = _G.AlanLuna_EstadoNavegacion
    }
    for clave, valor in pairs(flags) do
        local omitir = _flagsNoPersistir[clave]
            or (soloUI and not _flagsUI[clave])
            or (not soloUI and _flagsUI[clave])
        if not omitir then
            if esColor3(valor) then
                resultado[clave] = {
                    __color3 = true,
                    R = math.floor(valor.R * 255 + 0.5),
                    G = math.floor(valor.G * 255 + 0.5),
                    B = math.floor(valor.B * 255 + 0.5),
                }
            elseif esEnum(valor) then
                resultado[clave] = {
                    __enum = true,
                    EnumType = tostring(valor.EnumType),
                    Name = valor.Name,
                }
            elseif type(valor) == "table" and esEnum(valor.KeyCode) then
                resultado[clave] = {
                    __keybindMods = true,
                    KeyCode = valor.KeyCode.Name,
                    Ctrl = valor.Ctrl or false,
                    Shift = valor.Shift or false,
                    Alt = valor.Alt or false,
                }
            else
                resultado[clave] = valor
            end
        end
    end
    return resultado
end

local function desempaquetarValorCargado(valor)
    if type(valor) == "table" and valor.__color3 then
        return Color3.fromRGB(valor.R or 0, valor.G or 0, valor.B or 0)
    end
    if type(valor) == "table" and valor.__enum then
        local ok, enumItem = pcall(function() return Enum[valor.EnumType][valor.Name] end)
        return (ok and enumItem) or Enum.KeyCode.Unknown
    end
    if type(valor) == "table" and valor.__keybindMods then
        local ok, keyCode = pcall(function() return Enum.KeyCode[valor.KeyCode] end)
        return {
            KeyCode = ok and keyCode or Enum.KeyCode.Unknown,
            Ctrl = valor.Ctrl or false,
            Shift = valor.Shift or false,
            Alt = valor.Alt or false,
        }
    end
    return valor
end

local function prepararDatosCargados(datos)
    if type(datos) ~= "table" then return {} end

    if type(datos.objects) == "table" then
        local migrado = {}
        for _, obj in ipairs(datos.objects) do
            if obj.flag then
                if obj.state ~= nil then
                    migrado[obj.flag] = obj.state
                elseif obj.value ~= nil then
                    migrado[obj.flag] = tonumber(obj.value) or obj.value
                elseif obj.text ~= nil then
                    migrado[obj.flag] = obj.text
                elseif obj.color ~= nil then
                    if type(obj.color) == "string" and obj.color:sub(1,1) == "#" then
                        local r = tonumber(obj.color:sub(2, 3), 16) or 255
                        local g = tonumber(obj.color:sub(4, 5), 16) or 255
                        local b = tonumber(obj.color:sub(6, 7), 16) or 255
                        migrado[obj.flag] = Color3.fromRGB(r, g, b)
                    end
                end
            end
        end
        return migrado
    end

    local versionOrigen = tonumber(datos.__version) or 1
    datos.__version = nil

    if datos.__navegacion and type(datos.__navegacion) == "table" then
        _G.AlanLuna_EstadoNavegacion = datos.__navegacion
        datos.__navegacion = nil
    end

    if versionOrigen > VERSION_FORMATO_GUARDADO then
        pcall(function()
            AlanLuna:Notificar({
                Title   = "⚠️ Config más nueva",
                Content = "El archivo guardado es de un formato más reciente (v" .. versionOrigen .. ").",
                Duration = 5,
                Icon = "warning"
            })
        end)
    end

    return datos
end

AlanLuna.SaveManager = {}
local SM = AlanLuna.SaveManager
SM.Carpeta = "AlanUI/Config"
SM.CarpetaUI = "AlanUI/Config/_ui"

function SM:Configurar(carpeta) self.Carpeta = carpeta or self.Carpeta end

local function asegurarCarpeta()
    if not (fsDisponible() and type(isfolder) == "function" and type(makefolder) == "function") then return end
    local ruta = ""
    for parte in SM.Carpeta:gmatch("[^/]+") do
        ruta = ruta == "" and parte or (ruta .. "/" .. parte)
        if not isfolder(ruta) then pcall(makefolder, ruta) end
    end
end

local function asegurarCarpetaUI()
    if not (fsDisponible() and type(isfolder) == "function" and type(makefolder) == "function") then return end
    local ruta = ""
    for parte in SM.CarpetaUI:gmatch("[^/]+") do
        ruta = ruta == "" and parte or (ruta .. "/" .. parte)
        if not isfolder(ruta) then pcall(makefolder, ruta) end
    end
end

function SM:Guardar(nombre)
    nombre = nombre or "default"
    if not fsDisponible() then
        AlanLuna:Notificar({Title = "SaveManager", Content = "Ejecutor sin soporte de archivos.", Duration = 4, Icon = "warning"})
        return false
    end
    asegurarCarpeta()
    local ruta = SM.Carpeta .. "/" .. nombre .. ".json"
    local huboCambios = true
    local ok, err = pcall(function()
        local datos = empaquetarFlagsParaGuardar(_flagsReales)
        local json = HttpService:JSONEncode(datos)
        if type(isfile) == "function" and isfile(ruta) then
            local okLeer, jsonExistente = pcall(readfile, ruta)
            if okLeer and jsonExistente == json then
                huboCambios = false
            end
        end
        if huboCambios then writefile(ruta, json) end
    end)
    if ok then
        if huboCambios then
            AlanLuna:Notificar({Title = "Configuración guardada", Content = nombre .. ".json", Duration = 3, Icon = "check_circle"})
        else
            AlanLuna:Notificar({Title = "✅ Ya estaba al día", Content = nombre .. ".json sin cambios", Duration = 3, Icon = "info"})
        end
    else
        AlanLuna:_RegistrarError("SaveManager:Guardar", err)
        AlanLuna:Notificar({Title = "❌ Error al guardar", Content = tostring(err):sub(1, 100), Duration = 5, Icon = "warning"})
    end
    return ok
end

function SM:GuardarSilencioso(nombre)
    nombre = nombre or "default"
    if not AlanLuna.Capacidades.Archivos then return false end
    asegurarCarpeta()
    local ok, err = pcall(function()
        local datos = empaquetarFlagsParaGuardar(_flagsReales)
        local json = HttpService:JSONEncode(datos)
        writefile(SM.Carpeta .. "/" .. nombre .. ".json", json)
    end)
    if not ok then AlanLuna:_RegistrarError("SaveManager:GuardarSilencioso", err) end
    return ok
end

function SM:Cargar(nombre)
    nombre = nombre or "default"
    local ruta = SM.Carpeta .. "/" .. nombre .. ".json"
    if not (fsDisponible() and type(isfile) == "function" and isfile(ruta)) then return false end

    local okLeer, contenido = pcall(readfile, ruta)
    if not okLeer then
        AlanLuna:_RegistrarError("SaveManager:Cargar (leer)", contenido)
        return false
    end
    local okDecode, datos = pcall(function() return HttpService:JSONDecode(contenido) end)
    if not okDecode then
        AlanLuna:_RegistrarError("SaveManager:Cargar (JSONDecode)", datos)
        return false
    end
    datos = prepararDatosCargados(datos)

    _cargandoDesdeArchivo = true
    local okBucle, errBucle = pcall(function()
        for flag, valorCrudo in pairs(datos) do
            local valor = desempaquetarValorCargado(valorCrudo)
            AlanLuna.Flags[flag] = valor
            if AlanLuna.Elementos[flag] then
                pcall(AlanLuna.Elementos[flag].Set, valor, true)
            end
        end
    end)
    _cargandoDesdeArchivo = false
    if not okBucle then AlanLuna:_RegistrarError("SaveManager:Cargar (bucle)", errBucle) end
    _revisarConflictosAlCargar()
    AlanLuna:Notificar({Title = "Configuración cargada", Content = nombre .. ".json", Duration = 3, Icon = "check_circle"})
    return true
end

function SM:CargarSilencioso(nombre)
    nombre = nombre or "default"
    local ruta = SM.Carpeta .. "/" .. nombre .. ".json"
    if not (fsDisponible() and type(isfile) == "function" and isfile(ruta)) then return false end

    local okLeer, contenido = pcall(readfile, ruta)
    if not okLeer then return false end
    local okDecode, datos = pcall(function() return HttpService:JSONDecode(contenido) end)
    if not okDecode then return false end
    datos = prepararDatosCargados(datos)

    _cargandoDesdeArchivo = true
    pcall(function()
        for flag, valorCrudo in pairs(datos) do
            local valor = desempaquetarValorCargado(valorCrudo)
            AlanLuna.Flags[flag] = valor
            if AlanLuna.Elementos[flag] then
                pcall(AlanLuna.Elementos[flag].Set, valor, true)
            end
        end
    end)
    _cargandoDesdeArchivo = false
    _revisarConflictosAlCargar()
    AlanLuna:Notificar({Title = "Configuración cargada", Content = nombre .. ".json", Duration = 3, Icon = "check_circle"})
    return true
end

function SM:Listar()
    if not (fsDisponible() and type(listfiles) == "function") then return {} end
    local resultado = {}
    local ok, archivos = pcall(listfiles, SM.Carpeta)
    if ok then
        for _, ruta in ipairs(archivos) do
            local nombre = ruta:match("([^/\\]+)%.json$")
            if nombre then table.insert(resultado, nombre) end
        end
    end
    return resultado
end

function SM:Eliminar(nombre)
    if type(nombre) ~= "string" or nombre == "" then return false end
    if not (fsDisponible() and type(isfile) == "function" and type(delfile) == "function") then return false end
    local ruta = SM.Carpeta .. "/" .. nombre .. ".json"
    if not isfile(ruta) then return false end
    return (pcall(delfile, ruta))
end

function SM:CambiarPerfil(ventana, nombre)
    if type(ventana) ~= "table" or type(nombre) ~= "string" or nombre == "" then return false end
    if ventana.NombreConfig then SM:GuardarSilencioso(ventana.NombreConfig) end
    ventana.NombreConfig = nombre
    local existia = SM:Cargar(nombre)
    if not existia then
        AlanLuna:Notificar({Title = "Perfil nuevo", Content = "'" .. nombre .. "' sin guardado previo", Duration = 3, Icon = "info"})
    end
    return true
end

local function nombrePerfilValido(nombre)
    if type(nombre) ~= "string" then return false end
    local limpio = nombre:match("^%s*(.-)%s*$")
    if limpio == "" or #limpio > 60 or limpio:find('[/\\:*?"<>|%c]') then return false end
    return true, limpio
end

function SM:Duplicar(origen, destino)
    local okO, nombreO = nombrePerfilValido(origen)
    local okD, nombreD = nombrePerfilValido(destino)
    if not (okO and okD) then return false, "Nombre de perfil inválido" end
    if not (fsDisponible() and type(isfile) == "function") then return false, "Sin soporte de archivos" end
    asegurarCarpeta()
    local rutaO = SM.Carpeta .. "/" .. nombreO .. ".json"
    local rutaD = SM.Carpeta .. "/" .. nombreD .. ".json"
    if not isfile(rutaO) then return false, "No existe perfil origen" end
    if isfile(rutaD) then return false, "Ya existe perfil destino" end
    local ok, err = pcall(function() writefile(rutaD, readfile(rutaO)) end)
    return ok, err
end

function SM:Renombrar(origen, destino)
    local ok, motivo = SM:Duplicar(origen, destino)
    if not ok then return false, motivo end
    local _, nombreO = nombrePerfilValido(origen)
    SM:Eliminar(nombreO)
    return true
end

function SM:Exportar(nombre)
    local okN, limpio = nombrePerfilValido(nombre)
    if not okN or not fsDisponible() then return nil, "Error de archivo" end
    local ruta = SM.Carpeta .. "/" .. limpio .. ".json"
    if not isfile(ruta) then return nil, "No existe perfil" end
    local okL, texto = pcall(readfile, ruta)
    if not okL then return nil, "Error al leer" end
    local copiado = false
    if type(setclipboard) == "function" then copiado = (pcall(setclipboard, texto)) end
    return texto, copiado
end

function SM:Importar(nombre, texto, sobreescribir)
    local okN, limpio = nombrePerfilValido(nombre)
    if not okN or type(texto) ~= "string" or not fsDisponible() then return false, "Datos inválidos" end
    local okJ, datos = pcall(function() return HttpService:JSONDecode(texto) end)
    if not okJ or type(datos) ~= "table" then return false, "JSON inválido" end
    asegurarCarpeta()
    local ruta = SM.Carpeta .. "/" .. limpio .. ".json"
    if isfile(ruta) and not sobreescribir then return false, "Ya existe" end
    local ok, err = pcall(writefile, ruta, texto)
    return ok, err
end

function SM:GuardarUI(nombre)
    nombre = nombre or "default"
    if not fsDisponible() then return false end
    asegurarCarpetaUI()
    local ruta = SM.CarpetaUI .. "/" .. nombre .. ".json"
    local ok = pcall(function()
        local datos = empaquetarFlagsParaGuardar(_flagsReales, true)
        writefile(ruta, HttpService:JSONEncode(datos))
    end)
    return ok
end

function SM:CargarUI(nombre)
    nombre = nombre or "default"
    local ruta = SM.CarpetaUI .. "/" .. nombre .. ".json"
    if not (fsDisponible() and type(isfile) == "function" and isfile(ruta)) then return false end
    local okLeer, contenido = pcall(readfile, ruta)
    if not okLeer then return false end
    local okDecode, datos = pcall(function() return HttpService:JSONDecode(contenido) end)
    if not okDecode then return false end
    datos = prepararDatosCargados(datos)

    _cargandoDesdeArchivo = true
    pcall(function()
        for flag, valorCrudo in pairs(datos) do
            if _flagsUI[flag] then
                local valor = desempaquetarValorCargado(valorCrudo)
                AlanLuna.Flags[flag] = valor
                if AlanLuna.Elementos[flag] then
                    pcall(AlanLuna.Elementos[flag].Set, valor, true)
                end
            end
        end
    end)
    _cargandoDesdeArchivo = false
    _revisarConflictosAlCargar()
    return true
end

function SM:ListarUI()
    if not (fsDisponible() and type(listfiles) == "function") then return {} end
    local resultado = {}
    local ok, archivos = pcall(listfiles, SM.CarpetaUI)
    if ok then
        for _, ruta in ipairs(archivos) do
            local n = ruta:match("([^/\\]+)%.json$")
            if n then table.insert(resultado, n) end
        end
    end
    return resultado
end

function SM:EliminarUI(nombre)
    if not (fsDisponible() and type(isfile) == "function" and type(delfile) == "function") then return false end
    local ruta = SM.CarpetaUI .. "/" .. (nombre or "default") .. ".json"
    if not isfile(ruta) then return false end
    return (pcall(delfile, ruta))
end

function AlanLuna:SaveConfig(Path)
    return self.SaveManager:Guardar(Path)
end

function AlanLuna:LoadConfig(Path)
    return self.SaveManager:Cargar(Path)
end

function AlanLuna:RefreshConfigList()
    return self.SaveManager:Listar()
end

function AlanLuna:LoadAutoloadConfig()
    if not fsDisponible() then return end
    local ruta = self.Folder .. "/autoload.txt"
    if type(isfile) == "function" and isfile(ruta) then
        local ok, n = pcall(readfile, ruta)
        if ok and n and n ~= "" then
            self.SaveManager:Cargar(n)
        end
    end
end

-- ══════════════════════════════════════════════════════════════
--  SECCION 13: VISIBILIDAD CONDICIONAL & LABELS AUTO-ACTUALIZABLES
-- ══════════════════════════════════════════════════════════════
local _labelsAutoActualizables = setmetatable({}, {__mode = "k"})

table.insert(_G.AlanLuna_ConexionesModulo, RunService.Heartbeat:Connect(function()
    local ahora = os.clock()
    for entrada, config in pairs(_labelsAutoActualizables) do
        if entrada and entrada.Parent and ahora >= config.proxima then
            config.proxima = ahora + config.cada
            local ok, nuevo = pcall(config.fn)
            if ok and nuevo ~= nil then
                pcall(config.aplicar, nuevo)
            elseif not ok then
                AlanLuna:_RegistrarError("Label auto-update ('" .. tostring(config.flag) .. "')", nuevo)
            end
        end
    end
end))

local registroVisibilidad = setmetatable({}, {__mode = "k"})

local function cumpleVisibilidadCondicional(fila)
    local condicion = registroVisibilidad[fila]
    if not condicion then return true end
    local ok, resultado = pcall(condicion)
    if not ok then
        AlanLuna:_RegistrarError("VisibleSi", resultado)
        return true
    end
    return resultado and true or false
end

local function registrarVisibilidadCondicional(fila, visibleSi)
    if type(visibleSi) ~= "function" or not fila then return end
    registroVisibilidad[fila] = visibleSi
    fila.Visible = cumpleVisibilidadCondicional(fila)
end

local function reevaluarVisibilidadCondicional()
    for fila, _ in pairs(registroVisibilidad) do
        if fila and fila.Parent then
            fila.Visible = cumpleVisibilidadCondicional(fila)
        end
    end
end

table.insert(_G.AlanLuna_ConexionesModulo, AlanLuna.Eventos.FlagCambiada:Connect(reevaluarVisibilidadCondicional))

local indiceBusqueda = {}
local seccionesRegistradas = {}

local function registrarBuscable(fila, texto, visibleSi)
    table.insert(indiceBusqueda, {fila = fila, texto = (texto or ""):lower()})
    registrarVisibilidadCondicional(fila, visibleSi)
end

-- ══════════════════════════════════════════════════════════════
--  SECCION 14: THEME MANAGER (ESTILO HIBRIDO & PRESETS)
-- ══════════════════════════════════════════════════════════════
AlanLuna.ThemeManager = {}
local TM = AlanLuna.ThemeManager
TM.Temas = Themes.Lista

function TM:AplicarTema(nombreOTabla)
    local esPreset = false
    local presetColores = nil

    if type(nombreOTabla) == "string" and string.sub(nombreOTabla, 1, 10) == "Gradient: " then
        local rawName = string.sub(nombreOTabla, 11)
        if PresetGradients[rawName] then
            esPreset = true
            presetColores = PresetGradients[rawName]
            AlanLuna.ThemeGradient = ColorSequence.new{
                ColorSequenceKeypoint.new(0.00, presetColores[1]),
                ColorSequenceKeypoint.new(0.50, presetColores[2]),
                ColorSequenceKeypoint.new(1.00, presetColores[3])
            }
        end
    end

    if not esPreset then
        local tabla = type(nombreOTabla) == "string" and self.Temas[nombreOTabla] or nombreOTabla
        if not tabla then return end
        for clave, valor in pairs(tabla) do Theme[clave] = valor end
        AlanLuna.ThemeGradient = ColorSequence.new{
            ColorSequenceKeypoint.new(0.00, Theme.Accent),
            ColorSequenceKeypoint.new(0.50, Theme.AccentLight),
            ColorSequenceKeypoint.new(1.00, Theme.Highlight)
        }
    end

    local animar = AlanLuna._ventanaRevelada == true
    local paginasOcultas = {}
    if animar then
        local activa = _G.AlanLuna_Instancia
        local ventana = activa and activa.Ventana
        if ventana and ventana.Tabs then
            for _, tab in ipairs(ventana.Tabs) do
                if tab.Pagina and not tab.Pagina.Visible then
                    table.insert(paginasOcultas, tab.Pagina)
                end
            end
        end
    end

    local function estaEnPaginaOculta(instancia)
        for _, pagina in ipairs(paginasOcultas) do
            if instancia:IsDescendantOf(pagina) then return true end
        end
        return false
    end

    for _, entrada in ipairs(registroTema) do
        if entrada.instancia and entrada.instancia.Parent then
            local nuevoValor
            if type(entrada.claveTema) == "function" then
                local ok, resultado = pcall(entrada.claveTema)
                if ok then nuevoValor = resultado end
            else
                nuevoValor = Theme[entrada.claveTema]
            end
            if nuevoValor ~= nil then
                intentarSilencioso(
                    "ThemeManager: aplicar " .. tostring(entrada.propiedad),
                    function()
                        local instancia, propiedad = entrada.instancia, entrada.propiedad
                        if animar and typeof(nuevoValor) == "Color3"
                        and typeof(instancia[propiedad]) == "Color3"
                        and not estaEnPaginaOculta(instancia) then
                            Utils.Tween(instancia, {[propiedad] = nuevoValor}, AlanLuna.Motion.Page, AlanLuna.Motion.EaseSuave)
                        else
                            instancia[propiedad] = nuevoValor
                        end
                    end
                )
            end
        end
    end

    local nombreAplicado = type(nombreOTabla) == "string" and nombreOTabla or nil
    for ventana in pairs(_ventanasConSelectorTemas) do
        if ventana._SincronizarSelectorTemas then
            pcall(ventana._SincronizarSelectorTemas, nombreAplicado)
        end
    end

    AlanLuna.Eventos.TemaCambiado:Fire(nombreAplicado)
end

function TM:AgregarTema(nombre, tabla)
    if type(nombre) == "string" and type(tabla) == "table" then
        self.Temas[nombre] = tabla
    end
end

function TM:GuardarTemaActual()
    if not fsDisponible() then return false end
    asegurarCarpeta()
    local ok, json = pcall(function()
        local datos = {}
        for clave, valor in pairs(Theme) do
            datos[clave] = {valor.R, valor.G, valor.B}
        end
        return HttpService:JSONEncode(datos)
    end)
    if not ok then return false end
    return pcall(writefile, SM.Carpeta .. "/tema.json", json)
end

-- ══════════════════════════════════════════════════════════════
--  SECCION 15: NOTIFICACIONES LUNA UI (BLUR & ANIMACION ESCALONADA)
-- ══════════════════════════════════════════════════════════════
local notifGuiRef = nil
local notifContainer = nil
local MAX_NOTIF_SIMULTANEAS = 4
local colaNotif = {}
local notifActivas = 0

local function asegurarContenedorNotificaciones()
    if notifContainer and notifContainer.Parent then return notifContainer end
    local padre = obtenerPadreGui()
    if not notifGuiRef or not notifGuiRef.Parent then
        notifGuiRef = padre:FindFirstChild("AlanLuna_NotifGui") or Instance.new("ScreenGui")
        notifGuiRef.Name = "AlanLuna_NotifGui"
        notifGuiRef.ResetOnSpawn = false
        notifGuiRef.IgnoreGuiInset = true
        notifGuiRef.DisplayOrder = 10000000
        notifGuiRef.Parent = padre
        protegerGui(notifGuiRef)
        AlanLuna:RegistrarInstancia(notifGuiRef)
    end

    notifContainer = notifGuiRef:FindFirstChild("AlanUI_Notificaciones")
    if not notifContainer then
        notifContainer = Instance.new("Frame")
        notifContainer.Name = "AlanUI_Notificaciones"
        notifContainer.BackgroundTransparency = 1
        notifContainer.Size = UDim2.new(0, 310, 1, -20)
        notifContainer.Position = UDim2.new(1, -320, 0, 10)
        notifContainer.ZIndex = 10000
        notifContainer.Parent = notifGuiRef

        local listLayout = Instance.new("UIListLayout")
        listLayout.Name = "UIListLayout"
        listLayout.SortOrder = Enum.SortOrder.LayoutOrder
        listLayout.VerticalAlignment = Enum.VerticalAlignment.Bottom
        listLayout.Padding = UDim.new(0, 8)
        listLayout.Parent = notifContainer
    end
    return notifContainer
end

local COLORES_TIPO_NOTIF = {
    Success = Color3.fromRGB(46, 204, 113),
    Warning = Color3.fromRGB(241, 196, 15),
    Error   = Color3.fromRGB(231, 76, 60),
    Info    = Color3.fromRGB(90, 140, 210),
}

local function mostrarTarjetaNotif(data)
    notifActivas = notifActivas + 1
    local contenedor = asegurarContenedorNotificaciones()

    local titulo = data.Title or data.Titulo or "Notificación"
    local contenido = data.Content or data.Texto or ""
    local iconoNombre = data.Icon or data.Icono or "info"
    local source = data.ImageSource or "Material"
    local duracion = data.Duration or data.Duracion or math.min(math.max((#contenido * 0.08) + 2.5, 3), 10)
    local tipo = data.Type or data.Tipo
    local colorAcento = (tipo and COLORES_TIPO_NOTIF[tipo]) or Theme.Accent

    local card = Instance.new("Frame")
    card.Name = titulo
    card.BackgroundColor3 = Theme.Panel
    card.BackgroundTransparency = 1
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    card.Size = UDim2.new(1, 0, 0, 0)
    card.ZIndex = 10001
    card.Parent = contenedor

    Utils.Corner(card, 8)
    local stroke = Utils.Stroke(card, colorAcento, 1, 1)

    local blurData = BlurModule(card)

    local sombra = Instance.new("ImageLabel")
    sombra.Name = "Shadow"
    sombra.BackgroundTransparency = 1
    sombra.Image = "rbxassetid://1316045217"
    sombra.ImageColor3 = Color3.new(0, 0, 0)
    sombra.ImageTransparency = 1
    sombra.ScaleType = Enum.ScaleType.Slice
    sombra.SliceCenter = Rect.new(10, 10, 118, 118)
    sombra.Size = UDim2.new(1, 14, 1, 14)
    sombra.Position = UDim2.new(0, -7, 0, -7)
    sombra.ZIndex = 10000
    sombra.Parent = card

    local iconoImg = Instance.new("ImageLabel")
    iconoImg.Name = "Icon"
    iconoImg.BackgroundTransparency = 1
    iconoImg.ImageTransparency = 1
    iconoImg.Size = UDim2.new(0, 22, 0, 22)
    iconoImg.Position = UDim2.new(0, 10, 0, 10)
    iconoImg.ZIndex = 10002
    iconoImg.Parent = card

    local iconData = GetIcon(iconoNombre, source)
    if type(iconData) == "table" then
        iconoImg.Image = "rbxassetid://" .. tostring(iconData.id)
        iconoImg.ImageRectSize = iconData.imageRectSize
        iconoImg.ImageRectOffset = iconData.imageRectOffset
    elseif type(iconData) == "string" then
        iconoImg.Image = iconData
    end

    local titleLbl = Instance.new("TextLabel")
    titleLbl.Name = "Title"
    titleLbl.BackgroundTransparency = 1
    titleLbl.TextTransparency = 1
    titleLbl.Font = Enum.Font.GothamBold
    titleLbl.TextSize = 13
    titleLbl.TextColor3 = Theme.Highlight
    titleLbl.TextXAlignment = Enum.TextXAlignment.Left
    titleLbl.Size = UDim2.new(1, -44, 0, 20)
    titleLbl.Position = UDim2.new(0, 38, 0, 10)
    titleLbl.Text = titulo
    titleLbl.ZIndex = 10002
    titleLbl.Parent = card

    local descLbl = Instance.new("TextLabel")
    descLbl.Name = "Description"
    descLbl.BackgroundTransparency = 1
    descLbl.TextTransparency = 1
    descLbl.Font = Enum.Font.Gotham
    descLbl.TextSize = 11
    descLbl.TextColor3 = Theme.Text
    descLbl.TextXAlignment = Enum.TextXAlignment.Left
    descLbl.TextWrapped = true
    descLbl.Size = UDim2.new(1, -44, 0, 0)
    descLbl.Position = UDim2.new(0, 38, 0, 30)
    descLbl.Text = contenido
    descLbl.ZIndex = 10002
    descLbl.Parent = card

    local boundsY = TextService:GetTextSize(contenido, 11, Enum.Font.Gotham, Vector2.new(250, 1000)).Y
    local alturaTotal = math.max(48, boundsY + 42)
    descLbl.Size = UDim2.new(1, -44, 0, boundsY)

    Utils.Tween(card, {Size = UDim2.new(1, 0, 0, alturaTotal)}, 0.45, AlanLuna.Motion.EaseEntrar)
    Utils.Tween(card, {BackgroundTransparency = 0.45}, 0.35, AlanLuna.Motion.EaseEntrar)
    Utils.Tween(titleLbl, {TextTransparency = 0}, 0.3, AlanLuna.Motion.EaseEntrar)
    Utils.Tween(iconoImg, {ImageTransparency = 0}, 0.3, AlanLuna.Motion.EaseEntrar)
    Utils.Tween(descLbl, {TextTransparency = 0.15}, 0.3, AlanLuna.Motion.EaseEntrar)
    Utils.Tween(stroke, {Transparency = 0.6}, 0.35, AlanLuna.Motion.EaseEntrar)
    Utils.Tween(sombra, {ImageTransparency = 0.8}, 0.35, AlanLuna.Motion.EaseEntrar)

    local function cerrar()
        if not (card and card.Parent) then return end
        Utils.Tween(card, {BackgroundTransparency = 1}, 0.3, AlanLuna.Motion.EaseSalir)
        Utils.Tween(stroke, {Transparency = 1}, 0.3, AlanLuna.Motion.EaseSalir)
        Utils.Tween(titleLbl, {TextTransparency = 1}, 0.25, AlanLuna.Motion.EaseSalir)
        Utils.Tween(descLbl, {TextTransparency = 1}, 0.25, AlanLuna.Motion.EaseSalir)
        Utils.Tween(iconoImg, {ImageTransparency = 1}, 0.25, AlanLuna.Motion.EaseSalir)
        Utils.Tween(sombra, {ImageTransparency = 1}, 0.25, AlanLuna.Motion.EaseSalir)
        Utils.Tween(card, {Size = UDim2.new(1, 0, 0, 0)}, 0.35, AlanLuna.Motion.EaseSalir)

        task.delay(0.36, function()
            pcall(function() card:Destroy() end)
            notifActivas = math.max(0, notifActivas - 1)
            local siguiente = table.remove(colaNotif, 1)
            if siguiente then mostrarTarjetaNotif(siguiente) end
        end)
    end

    task.delay(duracion, cerrar)
end

function AlanLuna:Notificar(data)
    data = data or {}
    if notifActivas >= MAX_NOTIF_SIMULTANEAS then
        local prioridad = data.Prioridad or 0
        local pos = #colaNotif + 1
        for i, enCola in ipairs(colaNotif) do
            if (enCola.Prioridad or 0) < prioridad then
                pos = i
                break
            end
        end
        table.insert(colaNotif, pos, data)
        return
    end
    mostrarTarjetaNotif(data)
end

function AlanLuna:Notification(data)
    self:Notificar(data)
end

-- ══════════════════════════════════════════════════════════════
--  SECCION 16: DIALOGO MODAL DE CONFIRMACION (AlanLuna:Confirmar)
-- ══════════════════════════════════════════════════════════════
function AlanLuna:Confirmar(cfg)
    cfg = cfg or {}
    local padre = obtenerPadreGui()
    local gui = self._guiConfirmar or padre:FindFirstChild("AlanLuna_ScreenGui") or padre:FindFirstChild("AlanLuna_NotifGui")
    if not (gui and gui.Parent) then
        self:_RegistrarError("Confirmar", "no hay una ventana activa donde mostrar el modal")
        return nil
    end

    local botones = {}
    if type(cfg.Botones) == "table" and #cfg.Botones > 0 then
        for _, b in ipairs(cfg.Botones) do table.insert(botones, clonarTabla(b)) end
    else
        if cfg.BotonCancelar then
            local b = clonarTabla(cfg.BotonCancelar)
            b.Texto = b.Texto or "Cancelar"
            b.Variante = b.Variante or "neutral"
            table.insert(botones, b)
        end
        local aceptar = clonarTabla(cfg.BotonAceptar or {})
        aceptar.Texto = aceptar.Texto or "Aceptar"
        aceptar.Variante = aceptar.Variante or "primary"
        table.insert(botones, aceptar)
    end

    self._modalesAbiertos = (self._modalesAbiertos or 0) + 1
    local zBase = 500 + (self._modalesAbiertos - 1) * 10
    local tituloError = cfg.Titulo or "Confirmar"

    local fondo = Utils.Frame({
        Padre = gui, Size = UDim2.new(1, 0, 1, 0),
        Color = Color3.new(0, 0, 0), Transparencia = 0.5, Radio = false,
    })
    fondo.ZIndex = zBase
    fondo.Active = true

    local blurData = BlurModule(fondo)

    local cerrado = false
    fondo.Destroying:Connect(function()
        if cerrado then return end
        cerrado = true
        self._modalesAbiertos = math.max(0, (self._modalesAbiertos or 1) - 1)
        for i = #registroTema, 1, -1 do
            local inst = registroTema[i].instancia
            if inst == fondo or inst:IsDescendantOf(fondo) then table.remove(registroTema, i) end
        end
        for i = #registroEscalaTexto, 1, -1 do
            local inst = registroEscalaTexto[i].instancia
            if inst == fondo or inst:IsDescendantOf(fondo) then table.remove(registroEscalaTexto, i) end
        end
        task.defer(function()
            local activa = _G.AlanLuna_Instancia
            if not activa then return end
            for i = #activa.Conexiones, 1, -1 do
                if activa.Conexiones[i].Connected == false then table.remove(activa.Conexiones, i) end
            end
        end)
    end)

    local card = Utils.Frame({
        Padre = fondo, Size = UDim2.new(0, 300, 0, 0),
        Posicion = UDim2.new(0.5, 0, 0.5, 0), Ancla = Vector2.new(0.5, 0.5),
        Color = Theme.Panel, Radio = 8,
        Borde = true, ColorBorde = Theme.Border, GrosorBorde = 1,
        ClaveTemaBorde = "Border",
        Transparencia = 0.25,
    })
    card.ZIndex = zBase + 1
    card.AutomaticSize = Enum.AutomaticSize.Y
    AlanLuna:Registrar(card, "BackgroundColor3", "Panel")

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = card

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft, pad.PaddingRight = UDim.new(0, 14), UDim.new(0, 14)
    pad.PaddingTop, pad.PaddingBottom = UDim.new(0, 14), UDim.new(0, 14)
    pad.Parent = card

    local orden = 0
    if cfg.Icono then
        orden = orden + 1
        local lblIcono = Utils.Texto({
            Padre = card, Texto = tostring(cfg.Icono),
            Size = UDim2.new(1, 0, 0, 26), Orden = orden,
            Alineacion = Enum.TextXAlignment.Center, Tamano = 22,
        })
        lblIcono.ZIndex = zBase + 2
    end

    if cfg.Titulo then
        orden = orden + 1
        local lblTitulo = Utils.Texto({
            Padre = card, Texto = tostring(cfg.Titulo),
            Size = UDim2.new(1, 0, 0, 0), Orden = orden,
            Fuente = Enum.Font.GothamBold, Tamano = 14, Ajustar = true,
            Alineacion = cfg.Icono and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
            Color = Theme.Highlight,
        })
        lblTitulo.AutomaticSize = Enum.AutomaticSize.Y
        lblTitulo.ZIndex = zBase + 2
        AlanLuna:Registrar(lblTitulo, "TextColor3", "Highlight")
    end

    if cfg.Contenido then
        orden = orden + 1
        local lblCuerpo = Utils.Texto({
            Padre = card, Texto = tostring(cfg.Contenido),
            Size = UDim2.new(1, 0, 0, 0), Orden = orden,
            Ajustar = true, Tamano = 11, TextoTransparencia = 0.15,
            Alineacion = cfg.Icono and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
        })
        lblCuerpo.AutomaticSize = Enum.AutomaticSize.Y
        lblCuerpo.ZIndex = zBase + 2
    end

    local total = #botones
    local vertical = total > 3
    orden = orden + 1
    local filaBotones = Utils.Frame({
        Padre = card, Size = UDim2.new(1, 0, 0, vertical and 0 or 30),
        Transparencia = 1, Orden = orden,
    })
    filaBotones.ZIndex = zBase + 2
    if vertical then filaBotones.AutomaticSize = Enum.AutomaticSize.Y end

    local layoutBotones = Instance.new("UIListLayout")
    layoutBotones.FillDirection = vertical and Enum.FillDirection.Vertical or Enum.FillDirection.Horizontal
    layoutBotones.Padding = UDim.new(0, 6)
    layoutBotones.SortOrder = Enum.SortOrder.LayoutOrder
    layoutBotones.Parent = filaBotones

    local blanco = Color3.fromRGB(255, 255, 255)
    local function cerrar()
        if fondo.Parent then fondo:Destroy() end
    end
    local function presionar(i)
        local boton = botones[i]
        if not boton then return end
        cerrar()
        if type(boton.Callback) == "function" then
            ejecutarConFallback(boton.Callback, boton.Texto or tituloError)
        end
    end

    for i, boton in ipairs(botones) do
        local variante = boton.Variante or "neutral"
        local anchoBtn = vertical and UDim2.new(1, 0, 0, 30)
            or UDim2.new(1 / total, -math.ceil(6 * (total - 1) / total), 1, 0)
        local color, claveTema, colorTexto, conBorde = Theme.Fila, "Fila", nil, false
        local transparencia = 0.3
        if variante == "primary" then
            color, claveTema, colorTexto = Theme.Accent, "Accent", blanco
        elseif variante == "danger" then
            color, claveTema, colorTexto = Color3.fromRGB(180, 50, 50), nil, blanco
        elseif variante == "tertiary" then
            color, claveTema, conBorde, transparencia = Theme.Panel, nil, true, 1
        end

        local btn = Utils.BotonBase({
            Padre = filaBotones, Size = anchoBtn,
            Color = color, Transparencia = transparencia, Radio = 6,
        })
        btn.LayoutOrder = i
        btn.ZIndex = zBase + 3
        if claveTema then AlanLuna:Registrar(btn, "BackgroundColor3", claveTema) end
        if conBorde then
            local trazo = Utils.Stroke(btn, Theme.Border, 1, 0)
            AlanLuna:Registrar(trazo, "Color", "Border")
        else
            Utils.Hover(btn, btn)
        end

        local lbl = Utils.Texto({
            Padre = btn, Texto = tostring(boton.Texto or "OK"),
            Alineacion = Enum.TextXAlignment.Center, Tamano = 11,
            Fuente = Enum.Font.GothamMedium, Color = colorTexto, Truncar = true,
        })
        lbl.ZIndex = zBase + 4

        btn.MouseButton1Click:Connect(function() presionar(i) end)
    end

    Utils.EntradaModal(fondo, card)

    return { Cerrar = cerrar, Presionar = presionar, Fondo = fondo }
end

-- ══════════════════════════════════════════════════════════════
--  SECCION 17: KOMPONEN BARU 1 — POPUP SYSTEM (MODAL APILABLE)
-- ══════════════════════════════════════════════════════════════
AlanLuna._modalesAbiertos = 0

function AlanLuna:Popup(cfg)
    cfg = cfg or {}
    local padre = obtenerPadreGui()
    local sg = padre:FindFirstChild("AlanLuna_ScreenGui") or padre:FindFirstChild("AlanLuna_NotifGui")
    if not sg then
        sg = Instance.new("ScreenGui")
        sg.Name = "AlanLuna_PopupGui"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        sg.DisplayOrder = 999999
        sg.Parent = padre
        protegerGui(sg)
        AlanLuna:RegistrarInstancia(sg)
    end

    self._modalesAbiertos = (self._modalesAbiertos or 0) + 1
    local zBase = 500 + (self._modalesAbiertos - 1) * 10

    local fondo = Instance.new("TextButton")
    fondo.Name = "PopupBackdrop"
    fondo.Size = UDim2.new(1, 0, 1, 0)
    fondo.BackgroundColor3 = Color3.new(0, 0, 0)
    fondo.BackgroundTransparency = 1
    fondo.AutoButtonColor = false
    fondo.Text = ""
    fondo.ZIndex = zBase
    fondo.Parent = sg

    local blurData = BlurModule(fondo)

    local anchoCard = math.clamp(cfg.Ancho or 340, 300, 420)
    local card = Instance.new("Frame")
    card.Name = "PopupCard"
    card.Size = UDim2.new(0, anchoCard, 0, 0)
    card.Position = UDim2.new(0.5, 0, 0.5, 0)
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.BackgroundColor3 = Theme.Panel
    card.BackgroundTransparency = 0.25
    card.BorderSizePixel = 0
    card.ClipsDescendants = true
    card.AutomaticSize = Enum.AutomaticSize.Y
    card.ZIndex = zBase + 1
    card.Parent = fondo

    Utils.Corner(card, 8)
    local cardStroke = Utils.Stroke(card, Theme.Accent, 1, 0.4)
    AlanLuna:Registrar(cardStroke, "Color", "Accent")

    local layout = Instance.new("UIListLayout")
    layout.Padding = UDim.new(0, 10)
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Parent = card

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft   = UDim.new(0, 14)
    pad.PaddingRight  = UDim.new(0, 14)
    pad.PaddingTop    = UDim.new(0, 14)
    pad.PaddingBottom = UDim.new(0, 14)
    pad.Parent = card

    local orden = 0

    if cfg.Icono then
        orden = orden + 1
        local iconFrame = Instance.new("ImageLabel")
        iconFrame.BackgroundTransparency = 1
        iconFrame.Size = UDim2.new(0, 26, 0, 26)
        iconFrame.LayoutOrder = orden
        iconFrame.ZIndex = zBase + 2
        local ic = GetIcon(cfg.Icono, "Material")
        if type(ic) == "table" then
            iconFrame.Image = "rbxassetid://" .. tostring(ic.id)
            iconFrame.ImageRectSize = ic.imageRectSize
            iconFrame.ImageRectOffset = ic.imageRectOffset
        elseif type(ic) == "string" then
            iconFrame.Image = ic
        end
        iconFrame.Parent = card
    end

    if cfg.Titulo then
        orden = orden + 1
        local lblTitulo = Utils.Texto({
            Padre = card,
            Texto = tostring(cfg.Titulo),
            Size = UDim2.new(1, 0, 0, 22),
            Fuente = Enum.Font.GothamBold,
            Tamano = 14,
            Color = Theme.Highlight,
            Orden = orden,
        })
        lblTitulo.ZIndex = zBase + 2
        AlanLuna:Registrar(lblTitulo, "TextColor3", "Highlight")
    end

    local contenedorContenido = nil
    if cfg.Contenido then
        orden = orden + 1
        if type(cfg.Contenido) == "function" then
            contenedorContenido = Instance.new("Frame")
            contenedorContenido.BackgroundTransparency = 1
            contenedorContenido.Size = UDim2.new(1, 0, 0, 0)
            contenedorContenido.AutomaticSize = Enum.AutomaticSize.Y
            contenedorContenido.LayoutOrder = orden
            contenedorContenido.ZIndex = zBase + 2
            contenedorContenido.Parent = card
            pcall(cfg.Contenido, contenedorContenido)
        else
            local lblCuerpo = Utils.Texto({
                Padre = card,
                Texto = tostring(cfg.Contenido),
                Size = UDim2.new(1, 0, 0, 0),
                Ajustar = true,
                Tamano = 11,
                Color = Theme.Text,
                Orden = orden,
            })
            lblCuerpo.AutomaticSize = Enum.AutomaticSize.Y
            lblCuerpo.ZIndex = zBase + 2
            AlanLuna:Registrar(lblCuerpo, "TextColor3", "Text")
        end
    end

    local botones = cfg.Botones or { { Texto = "OK", Variante = "primary" } }
    orden = orden + 1

    local filaBotones = Instance.new("Frame")
    filaBotones.BackgroundTransparency = 1
    filaBotones.Size = UDim2.new(1, 0, 0, 28)
    filaBotones.LayoutOrder = orden
    filaBotones.ZIndex = zBase + 2
    filaBotones.Parent = card

    local bLayout = Instance.new("UIListLayout")
    bLayout.FillDirection = Enum.FillDirection.Horizontal
    bLayout.HorizontalAlignment = Enum.HorizontalAlignment.Right
    bLayout.Padding = UDim.new(0, 6)
    bLayout.Parent = filaBotones

    local cerrado = false
    local function cerrarModal()
        if cerrado then return end
        cerrado = true
        AlanLuna._modalesAbiertos = math.max(0, (AlanLuna._modalesAbiertos or 1) - 1)
        Utils.Tween(fondo, {BackgroundTransparency = 1}, 0.25, AlanLuna.Motion.EaseSalir)
        Utils.Tween(card, {Position = UDim2.new(0.5, 0, 0.6, 0), BackgroundTransparency = 1}, 0.25, AlanLuna.Motion.EaseSalir)
        task.delay(0.26, function()
            pcall(function() fondo:Destroy() end)
            if cfg.AlCerrar then pcall(cfg.AlCerrar) end
        end)
    end

    for _, bDef in ipairs(botones) do
        local btn = Utils.BotonBase({
            Padre = filaBotones,
            Size = UDim2.new(0, 75, 1, 0),
            Color = Theme.Fila,
            Transparencia = 0.3,
            Radio = 6
        })
        btn.ZIndex = zBase + 3

        local bColor = Theme.Fila
        local tColor = Theme.Text
        if bDef.Variante == "primary" then
            bColor = Theme.Accent
            tColor = Color3.fromRGB(255, 255, 255)
        elseif bDef.Variante == "danger" then
            bColor = Color3.fromRGB(180, 50, 50)
            tColor = Color3.fromRGB(255, 255, 255)
        end
        btn.BackgroundColor3 = bColor
        Utils.Hover(btn, btn)

        local bLbl = Utils.Texto({
            Padre = btn,
            Texto = bDef.Texto or "Boton",
            Alineacion = Enum.TextXAlignment.Center,
            Tamano = 11,
            Color = tColor,
            Size = UDim2.new(1, 0, 1, 0),
            Posicion = UDim2.new(0, 0, 0, 0)
        })
        bLbl.ZIndex = zBase + 4

        btn.MouseButton1Click:Connect(function()
            if bDef.Callback then ejecutarConFallback(bDef.Callback, bDef.Texto or "PopupBtn") end
            cerrarModal()
        end)
    end

    if cfg.Cerrable ~= false then
        fondo.MouseButton1Click:Connect(function()
            cerrarModal()
        end)
    end

    if cfg.AutoCerrar and tonumber(cfg.AutoCerrar) then
        task.delay(cfg.AutoCerrar, cerrarModal)
    end

    local cardScale = Instance.new("UIScale")
    cardScale.Scale = 0.9
    cardScale.Parent = card
    Utils.Tween(fondo, {BackgroundTransparency = 0.5}, 0.3, AlanLuna.Motion.EaseEntrar)
    Utils.Tween(cardScale, {Scale = 1}, 0.35, AlanLuna.Motion.EasePop)

    return {
        Cerrar = cerrarModal,
        Actualizar = function(_, nuevoTexto)
            if contenedorContenido and contenedorContenido:FindFirstChildOfClass("TextLabel") then
                contenedorContenido:FindFirstChildOfClass("TextLabel").Text = tostring(nuevoTexto)
            end
        end,
        Contenedor = contenedorContenido or card,
        Fondo = fondo,
    }
end

function AlanUI:Popup(cfg) return AlanLuna:Popup(cfg) end

-- ══════════════════════════════════════════════════════════════
--  SECCION 18: KOMPONEN BARU 2 — HUD STATS OVERLAY
-- ══════════════════════════════════════════════════════════════
local hudsActivos = {}

function AlanLuna:HUD(cfg)
    cfg = cfg or {}
    local nombre = cfg.Nombre or "HUD"
    if hudsActivos[nombre] then return hudsActivos[nombre] end

    local padre = obtenerPadreGui()
    local sg = padre:FindFirstChild("AlanLuna_ScreenGui") or padre:FindFirstChild("AlanLuna_NotifGui")
    if not sg then
        sg = Instance.new("ScreenGui")
        sg.Name = "AlanLuna_ScreenGui"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        sg.Parent = padre
        protegerGui(sg)
        AlanLuna:RegistrarInstancia(sg)
    end

    local hudFolder = sg:FindFirstChild("AlanUI_HudOverlay") or Instance.new("Folder")
    hudFolder.Name = "AlanUI_HudOverlay"
    hudFolder.Parent = sg

    local posiciones = {
        TopLeft     = UDim2.new(0, 15, 0, 15),
        TopRight    = UDim2.new(1, -215, 0, 15),
        BottomLeft  = UDim2.new(0, 15, 1, -55),
        BottomRight = UDim2.new(1, -215, 1, -55),
        Top         = UDim2.new(0.5, -100, 0, 15)
    }

    local posInicial = (typeof(cfg.Posicion) == "UDim2" and cfg.Posicion) or posiciones[cfg.Posicion] or posiciones.TopLeft

    local hudFrame = Utils.Frame({
        Padre = hudFolder,
        Size = UDim2.new(0, 200, 0, 30),
        Posicion = posInicial,
        Color = Theme.Panel,
        Transparencia = 0.35,
        Radio = 8,
        Borde = true,
        ColorBorde = Theme.Border,
        ClaveTemaBorde = "Border"
    })
    hudFrame.Name = "HUD_" .. nombre
    hudFrame.AutomaticSize = Enum.AutomaticSize.XY
    hudFrame.Active = true

    local blurData = BlurModule(hudFrame)

    local listLayout = Instance.new("UIListLayout")
    listLayout.FillDirection = Enum.FillDirection.Horizontal
    listLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    listLayout.Padding = UDim.new(0, 8)
    listLayout.Parent = hudFrame

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft   = UDim.new(0, 8)
    pad.PaddingRight  = UDim.new(0, 8)
    pad.PaddingTop    = UDim.new(0, 4)
    pad.PaddingBottom = UDim.new(0, 4)
    pad.Parent = hudFrame

    if cfg.Draggable ~= false then
        Utils.Arrastrable(hudFrame, hudFrame, AlanLuna.EventManager)
    end

    local items = {}

    for _, eDef in ipairs(cfg.Elementos or {}) do
        local itemFrame = Instance.new("Frame")
        itemFrame.BackgroundTransparency = 1
        itemFrame.Size = UDim2.new(0, 0, 1, 0)
        itemFrame.AutomaticSize = Enum.AutomaticSize.X
        itemFrame.Parent = hudFrame

        local iLayout = Instance.new("UIListLayout")
        iLayout.FillDirection = Enum.FillDirection.Horizontal
        iLayout.VerticalAlignment = Enum.VerticalAlignment.Center
        iLayout.Padding = UDim.new(0, 4)
        iLayout.Parent = itemFrame

        if eDef.Icono then
            local ico = Instance.new("ImageLabel")
            ico.BackgroundTransparency = 1
            ico.Size = UDim2.new(0, 14, 0, 14)
            local icAsset = GetIcon(eDef.Icono, "Material")
            if type(icAsset) == "table" then
                ico.Image = "rbxassetid://" .. tostring(icAsset.id)
                ico.ImageRectSize = icAsset.imageRectSize
                ico.ImageRectOffset = icAsset.imageRectOffset
            elseif type(icAsset) == "string" then
                ico.Image = icAsset
            end
            ico.Parent = itemFrame
        end

        local valLbl = Utils.Texto({
            Padre = itemFrame,
            Texto = tostring(eDef.Label and (eDef.Label .. ": ") or "") .. tostring(eDef.Valor or "--") .. tostring(eDef.Sufijo or ""),
            Tamano = 10,
            Color = Theme.Text,
            Size = UDim2.new(0, 0, 1, 0)
        })
        valLbl.AutomaticSize = Enum.AutomaticSize.X

        local barraFill = nil
        if eDef.Tipo == "bar" then
            local bBg = Utils.Frame({
                Padre = itemFrame,
                Size = UDim2.new(0, 40, 0, 6),
                Color = Theme.Entrada,
                Radio = 3
            })
            barraFill = Utils.Frame({
                Padre = bBg,
                Size = UDim2.new(math.clamp((tonumber(eDef.Valor) or 0) / (eDef.Max or 100), 0, 1), 0, 1, 0),
                Color = Theme.Accent,
                Radio = 3
            })
            Utils.GradienteAcento(barraFill)
        end

        items[eDef.Flag] = { Label = valLbl, Bar = barraFill, Def = eDef }
    end

    local HUDObj = {}

    function HUDObj:Set(flag, val)
        local it = items[flag]
        if not it then return end
        local suf = it.Def.Sufijo or ""
        local pre = it.Def.Label and (it.Def.Label .. ": ") or ""
        it.Label.Text = pre .. tostring(val) .. suf
        if it.Bar and it.Def.Max then
            local num = tonumber(val) or 0
            Utils.Tween(it.Bar, {Size = UDim2.new(math.clamp(num / it.Def.Max, 0, 1), 0, 1, 0)}, 0.2)
        end
    end

    function HUDObj:Vincular(flag, fn, cada)
        cada = cada or 0.5
        AlanLuna:RegistrarHilo(task.spawn(function()
            while hudFrame and hudFrame.Parent do
                local ok, res = pcall(fn)
                if ok and res ~= nil then HUDObj:Set(flag, res) end
                task.wait(cada)
            end
        end))
    end

    function HUDObj:Mostrar() hudFrame.Visible = true end
    function HUDObj:Ocultar() hudFrame.Visible = false end
    function HUDObj:Alternar() hudFrame.Visible = not hudFrame.Visible end
    function HUDObj:Destruir()
        hudsActivos[nombre] = nil
        pcall(function() hudFrame:Destroy() end)
    end

    if cfg.Actualizar then pcall(cfg.Actualizar, HUDObj) end

    hudsActivos[nombre] = HUDObj
    return HUDObj
end

-- ══════════════════════════════════════════════════════════════
--  SECCION 19: KOMPONEN BARU 3 — BOTON EXTERNO (FLOATING BUTTON)
-- ══════════════════════════════════════════════════════════════
local botonesExternosSlots = {}

function AlanLuna:BotonExterno(cfg)
    cfg = cfg or {}
    local nombre = cfg.Nombre or ("ExtBtn_" .. math.random(1e5, 1e6))
    local padre = obtenerPadreGui()
    local sg = padre:FindFirstChild("AlanLuna_ScreenGui") or padre:FindFirstChild("AlanLuna_NotifGui")
    if not sg then
        sg = Instance.new("ScreenGui")
        sg.Name = "AlanLuna_ScreenGui"
        sg.ResetOnSpawn = false
        sg.IgnoreGuiInset = true
        sg.Parent = padre
        protegerGui(sg)
        AlanLuna:RegistrarInstancia(sg)
    end

    local extFolder = sg:FindFirstChild("AlanUI_ExternalOverlay") or Instance.new("Folder")
    extFolder.Name = "AlanUI_ExternalOverlay"
    extFolder.Parent = sg

    local posSlot = type(cfg.Posicion) == "string" and cfg.Posicion or "RightCenter"
    botonesExternosSlots[posSlot] = (botonesExternosSlots[posSlot] or 0) + 1
    local slotIndex = botonesExternosSlots[posSlot]

    local posiciones = {
        RightCenter = UDim2.new(1, -55, 0.5, -25 + (slotIndex - 1) * 54),
        LeftCenter  = UDim2.new(0, 15, 0.5, -25 + (slotIndex - 1) * 54),
        BottomRight = UDim2.new(1, -55, 1, -65 - (slotIndex - 1) * 54)
    }

    local posFinal = (typeof(cfg.Posicion) == "UDim2" and cfg.Posicion) or posiciones[posSlot] or posiciones.RightCenter

    local btn = Utils.BotonBase({
        Padre = extFolder,
        Size = UDim2.new(0, 46, 0, 46),
        Posicion = posFinal,
        Color = Theme.Panel,
        Transparencia = 0.35,
        Radio = 23,
    })
    btn.Name = nombre
    btn.Active = true
    btn.ZIndex = 50000

    local blurData = BlurModule(btn)
    local stroke = Utils.Stroke(btn, Theme.Border, 1.5, 0.3)
    AlanLuna:Registrar(stroke, "Color", "Border")

    local icon = Instance.new("ImageLabel")
    icon.BackgroundTransparency = 1
    icon.Size = UDim2.new(0, 22, 0, 22)
    icon.Position = UDim2.new(0.5, -11, 0.5, -11)
    icon.ZIndex = 50002
    local icAsset = GetIcon(cfg.Icono or "crosshair", "Material")
    if type(icAsset) == "table" then
        icon.Image = "rbxassetid://" .. tostring(icAsset.id)
        icon.ImageRectSize = icAsset.imageRectSize
        icon.ImageRectOffset = icAsset.imageRectOffset
    elseif type(icAsset) == "string" then
        icon.Image = icAsset
    end
    icon.Parent = btn

    Utils.Arrastrable(btn, btn, AlanLuna.EventManager)

    local estado = false
    local enCooldown = false
    local modo = cfg.Modo or "Toggle"

    local pulseTween = nil
    local function setVisualState(on)
        if on then
            Utils.Tween(btn, {BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.15}, 0.25)
            Utils.Tween(stroke, {Color = Theme.Highlight, Transparency = 0}, 0.25)
            pulseTween = TweenService:Create(stroke, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {Transparency = 0.7})
            pulseTween:Play()
        else
            if pulseTween then pulseTween:Cancel(); pulseTween = nil end
            Utils.Tween(btn, {BackgroundColor3 = Theme.Panel, BackgroundTransparency = 0.35}, 0.25)
            Utils.Tween(stroke, {Color = Theme.Border, Transparency = 0.4}, 0.25)
        end
    end

    local function disparar(forzarEstado)
        if modo == "Toggle" then
            estado = (forzarEstado ~= nil and forzarEstado) or not estado
            setVisualState(estado)
            if cfg.Callback then ejecutarConFallback(cfg.Callback, nombre, estado) end
            if estado and cfg.CallbackOn then ejecutarConFallback(cfg.CallbackOn, nombre) end
            if not estado and cfg.CallbackOff then ejecutarConFallback(cfg.CallbackOff, nombre) end
        elseif modo == "Once" and not enCooldown then
            enCooldown = true
            estado = true
            setVisualState(true)
            if cfg.Callback then ejecutarConFallback(cfg.Callback, nombre, true) end
            if cfg.CallbackOn then ejecutarConFallback(cfg.CallbackOn, nombre) end

            local dur = cfg.Duracion or 2
            local cd = cfg.Cooldown or 3

            local pRing = Instance.new("Frame")
            pRing.Size = UDim2.new(1, 0, 0, 3)
            pRing.Position = UDim2.new(0, 0, 1, -3)
            pRing.BackgroundColor3 = Theme.Highlight
            pRing.BorderSizePixel = 0
            pRing.ZIndex = 50003
            pRing.Parent = btn

            Utils.Tween(pRing, {Size = UDim2.new(0, 0, 0, 3)}, dur, Enum.EasingStyle.Linear)

            task.delay(dur, function()
                pcall(function() pRing:Destroy() end)
                estado = false
                setVisualState(false)
                if cfg.Callback then ejecutarConFallback(cfg.Callback, nombre, false) end
                if cfg.CallbackOff then ejecutarConFallback(cfg.CallbackOff, nombre) end

                local cdLbl = Utils.Texto({
                    Padre = btn,
                    Texto = tostring(cd),
                    Size = UDim2.new(1, 0, 1, 0),
                    Posicion = UDim2.new(0, 0, 0, 0),
                    Alineacion = Enum.TextXAlignment.Center,
                    Tamano = 14,
                    Fuente = Enum.Font.GothamBold,
                    Color = Color3.fromRGB(255, 100, 100)
                })
                cdLbl.ZIndex = 50004
                icon.ImageTransparency = 0.8

                for s = cd, 1, -1 do
                    cdLbl.Text = tostring(s)
                    task.wait(1)
                end
                pcall(function() cdLbl:Destroy() end)
                icon.ImageTransparency = 0
                enCooldown = false
            end)
        end
    end

    Utils.ClickConfiable(btn, function() disparar() end)

    if cfg.Tecla then
        AlanLuna:RegistrarConexion(UserInputService.InputBegan:Connect(function(inp, gpe)
            if gpe then return end
            if inp.KeyCode == cfg.Tecla then disparar() end
        end))
    end

    local ExtObj = {
        Activar = function() disparar(true) end,
        Desactivar = function() disparar(false) end,
        Alternar = function() disparar() end,
        GetEstado = function() return estado end,
        SetPosicion = function(_, p)
            if typeof(p) == "UDim2" then btn.Position = p end
        end,
        Destruir = function()
            if pulseTween then pulseTween:Cancel() end
            pcall(function() btn:Destroy() end)
        end
    }
    return ExtObj
end

-- ══════════════════════════════════════════════════════════════
--  SECCION 20: VENTANA PRINCIPAL & NAVEGACION CATEGORY/TAB/SUBTAB
-- ══════════════════════════════════════════════════════════════
local function anchoTexto(texto, tamano)
    return TextService:GetTextSize(
        texto or "", tamano or 11, Enum.Font.Gotham, Vector2.new(1000, 20)
    ).X
end

function AlanLuna:CrearVentana(config)
    config = config or {}
    local titulo       = config.Titulo or config.Name or "AlanLuna"
    local subtitulo    = (config.Subtitulo or config.Subtitle or "by AlanbeikersFF & Nebula Softworks") .. "  •  v" .. AlanLuna.Version
    local anchoX       = config.TamanoX or 620
    local anchoY       = config.TamanoY or 380
    local teclaUI      = config.TeclaToggle or config.Bind or Enum.KeyCode.RightControl
    local modoHorizontal = config.Orientacion == "horizontal"

    limpiarInstanciaPrevia()
    _G.AlanLuna_Instancia = {
        Conexiones = {},
        Hilos = {},
        Dibujos = {},
        Instancias = {},
        Ventana = nil,
        Titulo = titulo,
    }

    local padreGui = obtenerPadreGui()
    local sg = Instance.new("ScreenGui")
    sg.Name           = "AlanLuna_ScreenGui"
    sg.ResetOnSpawn   = false
    sg.IgnoreGuiInset = true
    sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    sg.Parent         = padreGui
    protegerGui(sg)
    AlanLuna:RegistrarInstancia(sg)

    asegurarContenedorNotificaciones()
    AlanLuna._guiConfirmar = sg

    local main = Utils.Frame({
        Padre = sg,
        Size = UDim2.new(0, 0, 0, 0),
        Posicion = UDim2.new(0.5, 0, 0.5, 0),
        Ancla = Vector2.new(0.5, 0.5),
        Color = Theme.Panel,
        Radio = 10,
        Recortar = true,
        Borde = true,
        ColorBorde = Theme.Border,
        GrosorBorde = 1.5,
        ClaveTemaBorde = "Border",
        Transparencia = 0.25,
    })
    main.Active = true
    AlanLuna:Registrar(main, "BackgroundColor3", "Panel")

    local blurData = BlurModule(main)

    local sombraPantalla = Utils.Frame({
        Padre = sg,
        Size = UDim2.new(1, 0, 1, 0),
        Posicion = UDim2.new(0, 0, 0, 0),
        Color = Color3.new(0, 0, 0),
        Transparencia = 1,
        Radio = false,
        Borde = false,
    })
    sombraPantalla.ZIndex = -10
    Utils.Tween(sombraPantalla, {BackgroundTransparency = 0.94}, AlanLuna.Motion.Modal)

    AlanLuna:RegistrarConexion(main:GetPropertyChangedSignal("Visible"):Connect(function()
        sombraPantalla.Visible = main.Visible
    end))

    local POSICION_ORIGINAL_VENTANA = UDim2.new(0.5, 0, 0.5, 0)
    Utils.Tween(main, {
        Size = UDim2.new(0, anchoX, 0, anchoY),
        Position = POSICION_ORIGINAL_VENTANA,
    }, AlanLuna.Motion.Modal, AlanLuna.Motion.EasePop)

    local escalaUI = Instance.new("UIScale")
    escalaUI.Scale = 1
    escalaUI.Parent = main

    local escalaManual = 1
    local anchoXBase, anchoYBase = anchoX, anchoY
    local factorAncho, factorAlto = 1, 1

    local function actualizarTamanoVentana()
        local nuevoAncho = anchoXBase * factorAncho
        local nuevoAlto  = anchoYBase * factorAlto
        local duracion = EventManager:HayArrastreActivo() and AlanLuna.Motion.Directo or AlanLuna.Motion.Page
        Utils.Tween(main, {
            Size     = UDim2.new(0, nuevoAncho, 0, nuevoAlto),
            Position = UDim2.new(0.5, 0, 0.5, 0),
        }, duracion, AlanLuna.Motion.EaseEntrar)
    end

    local function recalcularEscala()
        local camara = Workspace.CurrentCamera
        if not camara then return end
        local tam = camara.ViewportSize
        if tam.X <= 0 or tam.Y <= 0 then return end

        local esMovil = tam.X < 700 or tam.Y < 500
        local pctAncho = esMovil and 0.95 or 0.82
        local pctAlto  = esMovil and 0.88 or 0.82

        local anchoActual = anchoXBase * factorAncho
        local altoActual  = anchoYBase * factorAlto

        local escalaPorAncho = (tam.X * pctAncho) / anchoActual
        local escalaPorAlto  = (tam.Y * pctAlto)  / altoActual
        local escalaAuto = math.min(escalaPorAncho, escalaPorAlto, 1.15)
        escalaAuto = math.max(escalaAuto, 0.45)

        local limiteEscala = math.min((tam.X * 0.98) / anchoActual, (tam.Y * 0.90) / altoActual)
        local escalaFinal = math.max(0.3, math.min(escalaAuto * escalaManual, limiteEscala))
        local duracion = EventManager:HayArrastreActivo() and AlanLuna.Motion.Directo or AlanLuna.Motion.Page
        Utils.Tween(escalaUI, {Scale = escalaFinal}, duracion, AlanLuna.Motion.EaseEntrar)
    end

    recalcularEscala()

    local conexionViewport = nil
    local function engancharCamara()
        if conexionViewport then
            AlanLuna:DesconectarYLimpiar(conexionViewport)
            conexionViewport = nil
        end
        local camaraActual = Workspace.CurrentCamera
        if camaraActual then
            conexionViewport = AlanLuna:RegistrarConexion(
                camaraActual:GetPropertyChangedSignal("ViewportSize"):Connect(recalcularEscala)
            )
        end
    end
    engancharCamara()
    AlanLuna:RegistrarConexion(
        Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
            engancharCamara()
            recalcularEscala()
        end)
    )

    -- ── PILL MINIMIZAR ──────────────────────────────────────────
    local textoPill = "⚡ " .. titulo
    local anchoPill = math.clamp(anchoTexto(textoPill, 12) + 40, 130, 260)

    local pillRestaurar = Utils.BotonBase({
        Padre = sg,
        Size = UDim2.new(0, anchoPill, 0, 28),
        Posicion = UDim2.new(0.5, 0, 0, 25),
        Ancla = Vector2.new(0.5, 0.5),
        Color = Theme.Panel,
        Transparencia = 0.2,
        Radio = 14,
        Borde = true,
        ColorBorde = Theme.Accent,
        GrosorBorde = 1,
    })
    pillRestaurar.Visible = false
    pillRestaurar.ZIndex  = 50
    pillRestaurar.Active  = true
    AlanLuna:Registrar(pillRestaurar, "BackgroundColor3", "Panel")

    local blurPill = BlurModule(pillRestaurar)

    Utils.Texto({
        Padre = pillRestaurar, Texto = textoPill,
        Size = UDim2.new(1, -12, 1, 0), Posicion = UDim2.new(0, 6, 0, 0),
        Alineacion = Enum.TextXAlignment.Center, Truncar = true,
        Fuente = Enum.Font.GothamBold, Tamano = 11,
    })

    local ventanaAbierta = true
    local animandoVentana = false
    local idOperacionVentana = 0

    local function alternarVentana(abrir)
        if animandoVentana or abrir == ventanaAbierta then return end
        animandoVentana = true
        ventanaAbierta = abrir
        local idOperacion = idOperacionVentana + 1
        idOperacionVentana = idOperacion
        local function esOperacionVigente() return idOperacionVentana == idOperacion end

        if abrir then
            local tamanoObjetivo = UDim2.new(0, anchoXBase * factorAncho, 0, anchoYBase * factorAlto)
            Utils.Tween(pillRestaurar, {Size = UDim2.new(0, 0, 0, 0)}, AlanLuna.Motion.Expand, AlanLuna.Motion.EaseSalir)

            main.Visible = true
            main.Size = UDim2.new(0, 0, 0, 0)
            main.Position = POSICION_ORIGINAL_VENTANA
            Utils.Tween(main, {Size = tamanoObjetivo}, AlanLuna.Motion.Modal, AlanLuna.Motion.EasePop)

            task.spawn(function()
                task.wait(AlanLuna.Motion.Expand)
                if esOperacionVigente() then
                    pillRestaurar.Visible = false
                    pillRestaurar.Size = UDim2.new(0, anchoPill, 0, 28)
                end
                task.wait(math.max(0, AlanLuna.Motion.Modal - AlanLuna.Motion.Expand))
                if esOperacionVigente() then
                    main.Size = tamanoObjetivo
                    animandoVentana = false
                end
            end)
        else
            Utils.Tween(main, {Size = UDim2.new(0, 0, 0, 0)}, AlanLuna.Motion.Expand, AlanLuna.Motion.EaseSalir)
            task.spawn(function()
                task.wait(AlanLuna.Motion.Expand + 0.04)
                if not esOperacionVigente() then return end
                main.Visible = false
                main.Size = UDim2.new(0, 0, 0, 0)
                pillRestaurar.Size = UDim2.new(0, 0, 0, 0)
                pillRestaurar.Visible = true
                Utils.Tween(pillRestaurar, {Size = UDim2.new(0, anchoPill, 0, 28)}, AlanLuna.Motion.Modal, AlanLuna.Motion.EasePop)
                task.wait(AlanLuna.Motion.Modal + 0.01)
                if esOperacionVigente() then
                    pillRestaurar.Size = UDim2.new(0, anchoPill, 0, 28)
                    animandoVentana = false
                end
            end)
        end
    end

    pillRestaurar.MouseButton1Click:Connect(function() alternarVentana(true) end)

    -- ── HEADER / TOPBAR ─────────────────────────────────────────
    local barraTitulo = Utils.Frame({
        Padre = main, Size = UDim2.new(1, 0, 0, 32),
        Color = Theme.Background, Radio = 10, Transparencia = 0.35,
        Borde = false,
    })
    barraTitulo.Active = true
    AlanLuna:Registrar(barraTitulo, "BackgroundColor3", "Background")

    local tapa = Utils.Frame({
        Padre = barraTitulo, Size = UDim2.new(1, 0, 0, 8),
        Posicion = UDim2.new(0, 0, 1, -8),
        Color = Theme.Background, Radio = false, Borde = false,
        Transparencia = 0.35,
    })
    AlanLuna:Registrar(tapa, "BackgroundColor3", "Background")

    local lineaAcento = Utils.Frame({
        Padre = main, Size = UDim2.new(1, -20, 0, 2),
        Posicion = UDim2.new(0, 10, 0, 31), Color = Theme.Accent, Radio = false,
        Borde = false, Transparencia = 0.1,
    })
    lineaAcento.ZIndex = barraTitulo.ZIndex + 2
    AlanLuna:Registrar(lineaAcento, "BackgroundColor3", "Accent")
    Utils.GradienteAcento(lineaAcento)

    Utils.Arrastrable(barraTitulo, main, AlanLuna.EventManager)

    local lblTitulo = Utils.Texto({
        Padre = barraTitulo, Texto = titulo,
        Posicion = UDim2.new(0, 10, 0, 2), Size = UDim2.new(0.5, 0, 0, 16),
        Fuente = Enum.Font.GothamBold, Tamano = 13, Color = Theme.TextDark,
        Categoria = "titulo", Truncar = true,
    })
    AlanLuna:Registrar(lblTitulo, "TextColor3", "TextDark")

    local lblSub = Utils.Texto({
        Padre = barraTitulo, Texto = subtitulo,
        Posicion = UDim2.new(0, 10, 0, 17), Size = UDim2.new(0.5, 0, 0, 12),
        Tamano = 10, Color = Theme.TextDark, TextoTransparencia = 0.25,
        Categoria = "titulo", Truncar = true,
    })
    AlanLuna:Registrar(lblSub, "TextColor3", "TextDark")

    local btnCerrar = Utils.BotonBase({
        Padre = barraTitulo, Size = UDim2.new(0, 24, 0, 20),
        Posicion = UDim2.new(1, -16, 0.5, 0), Ancla = Vector2.new(0.5, 0.5),
        Color = Color3.fromRGB(180, 50, 50), Transparencia = 1, Radio = 5,
    })
    local icoCerrar = Utils.Texto({
        Padre = btnCerrar, Texto = "✕",
        Size = UDim2.new(1, 0, 1, 0), Posicion = UDim2.new(0, 0, 0, 0),
        Alineacion = Enum.TextXAlignment.Center, Tamano = 12, Fuente = Enum.Font.GothamBold,
    })
    btnCerrar.MouseButton1Down:Connect(function()
        Utils.Tween(btnCerrar, {BackgroundTransparency = 0.75}, AlanLuna.Motion.FlashIn)
    end)
    btnCerrar.MouseButton1Up:Connect(function()
        Utils.Tween(btnCerrar, {BackgroundTransparency = 1}, AlanLuna.Motion.Hover)
    end)

    local function mostrarConfirmacionDestruir()
        AlanLuna:Confirmar({
            Titulo    = "⚠️ ¿Cerrar interfaz?",
            Contenido = "¿Estás seguro de que deseas destruir la interfaz? Todas las conexiones y overlays se limpiarán por completo.",
            Icono     = "warning",
            Botones   = {
                { Texto = "Cancelar", Variante = "neutral" },
                {
                    Texto = "Eliminar", Variante = "danger",
                    Callback = function()
                        if sg and sg.Parent then sg:Destroy() end
                    end
                }
            }
        })
    end
    Utils.ClickConfiable(btnCerrar, mostrarConfirmacionDestruir)

    local btnMin = Utils.BotonBase({
        Padre = barraTitulo, Size = UDim2.new(0, 24, 0, 20),
        Posicion = UDim2.new(1, -44, 0.5, 0), Ancla = Vector2.new(0.5, 0.5),
        Color = Theme.BackgroundDark, Transparencia = 1, Radio = 5,
    })
    Utils.Texto({
        Padre = btnMin, Texto = "—",
        Size = UDim2.new(1, 0, 1, 0), Posicion = UDim2.new(0, 0, 0, 0),
        Alineacion = Enum.TextXAlignment.Center, Fuente = Enum.Font.GothamBold,
        Tamano = 13, Color = Theme.TextDark,
    })
    btnMin.MouseButton1Down:Connect(function()
        Utils.Tween(btnMin, {BackgroundTransparency = 0.7}, AlanLuna.Motion.FlashIn)
    end)
    btnMin.MouseButton1Up:Connect(function()
        Utils.Tween(btnMin, {BackgroundTransparency = 1}, AlanLuna.Motion.Hover)
    end)
    Utils.ClickConfiable(btnMin, function() alternarVentana(false) end)

    -- ── BREADCRUMB & CONTENT CONTAINERS ─────────────────────────
    local anchoBarraLat = modoHorizontal and 0 or 155
    local altoBarraHoriz = modoHorizontal and 34 or 0

    local barraLat = Instance.new("ScrollingFrame")
    barraLat.Size                = UDim2.new(0, 155, 1, -33)
    barraLat.Position            = UDim2.new(0, 0, 0, 33)
    barraLat.BackgroundColor3    = Theme.PanelClaro
    barraLat.BackgroundTransparency = 0.4
    barraLat.BorderSizePixel     = 0
    barraLat.Visible             = not modoHorizontal
    barraLat.ScrollingDirection  = Enum.ScrollingDirection.Y
    barraLat.ScrollBarThickness  = 3
    barraLat.ScrollBarImageColor3 = Theme.Accent
    barraLat.CanvasSize          = UDim2.new(0, 0, 0, 0)
    barraLat.AutomaticCanvasSize = Enum.AutomaticSize.Y
    barraLat.Parent              = main
    AlanLuna:Registrar(barraLat, "BackgroundColor3", "PanelClaro")

    local layoutTabs = Instance.new("UIListLayout")
    layoutTabs.Padding   = UDim.new(0, 3)
    layoutTabs.SortOrder = Enum.SortOrder.LayoutOrder
    layoutTabs.Parent    = barraLat

    local padTabs = Instance.new("UIPadding")
    padTabs.PaddingTop   = UDim.new(0, 6)
    padTabs.PaddingLeft  = UDim.new(0, 5)
    padTabs.PaddingRight = UDim.new(0, 5)
    padTabs.Parent       = barraLat

    local barraHoriz = Instance.new("ScrollingFrame")
    barraHoriz.Size                = UDim2.new(1, 0, 0, 34)
    barraHoriz.Position            = UDim2.new(0, 0, 0, 33)
    barraHoriz.BackgroundColor3    = Theme.PanelClaro
    barraHoriz.BackgroundTransparency = 0.4
    barraHoriz.BorderSizePixel     = 0
    barraHoriz.Visible             = modoHorizontal
    barraHoriz.ScrollingDirection  = Enum.ScrollingDirection.X
    barraHoriz.ScrollBarThickness  = 3
    barraHoriz.ScrollBarImageColor3 = Theme.Accent
    barraHoriz.CanvasSize          = UDim2.new(0, 0, 0, 0)
    barraHoriz.AutomaticCanvasSize = Enum.AutomaticSize.X
    barraHoriz.Parent              = main
    AlanLuna:Registrar(barraHoriz, "BackgroundColor3", "PanelClaro")

    local layoutHoriz = Instance.new("UIListLayout")
    layoutHoriz.FillDirection     = Enum.FillDirection.Horizontal
    layoutHoriz.Padding           = UDim.new(0, 4)
    layoutHoriz.SortOrder         = Enum.SortOrder.LayoutOrder
    layoutHoriz.VerticalAlignment = Enum.VerticalAlignment.Center
    layoutHoriz.Parent            = barraHoriz

    local padHoriz = Instance.new("UIPadding")
    padHoriz.PaddingLeft, padHoriz.PaddingRight   = UDim.new(0, 6), UDim.new(0, 6)
    padHoriz.PaddingTop, padHoriz.PaddingBottom   = UDim.new(0, 3), UDim.new(0, 3)
    padHoriz.Parent                               = barraHoriz

    local function posContenedor()
        if modoHorizontal then
            return UDim2.new(0, 0, 0, 68), UDim2.new(1, 0, 1, -68)
        else
            return UDim2.new(0, 155, 0, 33), UDim2.new(1, -155, 1, -33)
        end
    end

    local posP, sizeP = posContenedor()
    local contenedorPaginas = Utils.Frame({
        Padre = main, Size = sizeP, Posicion = posP,
        Transparencia = 1, Radio = false, Borde = false,
    })

    local breadcrumbActivo = true
    local breadcrumbFrame = Utils.Frame({
        Padre = contenedorPaginas, Size = UDim2.new(1, -16, 0, 20),
        Posicion = UDim2.new(0, 8, 0, 4), Transparencia = 1,
        Radio = false, Borde = false, Orden = 0,
    })
    local lblBreadcrumb = Utils.Texto({
        Padre = breadcrumbFrame, Texto = "",
        Size = UDim2.new(1, 0, 1, 0), Posicion = UDim2.new(0, 0, 0, 0),
        Tamano = 10, Color = Theme.TextDark, TextoTransparencia = 0.35,
        Fuente = Enum.Font.GothamMedium,
    })

    AlanLuna:RegistrarConexion(
        UserInputService.InputBegan:Connect(function(input, procesado)
            if not procesado and input.KeyCode == teclaUI then
                alternarVentana(not ventanaAbierta)
            end
        end)
    )

    -- ── HIERARKI DATA STRUCTURES ────────────────────────────────
    local Ventana = {
        Categorias = {},
        Tabs       = {},
        _main      = main,
        NombreConfig = config.NombreConfig or "autosave",
        Bind       = teclaUI,
        State      = true,
    }

    local catOrden = 0
    local primeraTabGlobal = true
    local categoriaActivaNombre = nil
    local tabActivaNombre = nil
    local subTabActivaNombre = nil

    local function actualizarBreadcrumb()
        if not breadcrumbActivo then
            breadcrumbFrame.Visible = false
            return
        end
        breadcrumbFrame.Visible = true
        local str = (categoriaActivaNombre or "") .. " › " .. (tabActivaNombre or "")
        if subTabActivaNombre and subTabActivaNombre ~= "Main" then
            str = str .. " › " .. subTabActivaNombre
        end
        lblBreadcrumb.Text = str
    end

    function Ventana:Breadcrumb(activo)
        breadcrumbActivo = (activo ~= false)
        actualizarBreadcrumb()
        return breadcrumbActivo
    end

    function Ventana:CategoriaActual() return categoriaActivaNombre end
    function Ventana:TabActual() return tabActivaNombre end
    function Ventana:SubTabActual() return subTabActivaNombre end

    -- ── SEARCH ENGINE GLOBAL ────────────────────────────────────
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

        local primerMatchTab = nil
        for _, cat in pairs(Ventana.Categorias) do
            local catTieneMatch = false
            for _, t in pairs(cat.Tabs) do
                local tabTieneMatch = false
                for _, sub in pairs(t.SubTabs) do
                    for _, s in ipairs(sub.Secciones) do
                        local secMatch = false
                        for _, hijo in ipairs(s.contenedor:GetChildren()) do
                            if hijo:IsA("GuiObject") and hijo.Visible then
                                secMatch = true
                                break
                            end
                        end
                        s.marco.Visible = (texto == "") or secMatch
                        if secMatch then tabTieneMatch = true end
                    end
                end
                t.BotonLat.Visible = (texto == "") or tabTieneMatch
                if tabTieneMatch then
                    catTieneMatch = true
                    if not primerMatchTab then primerMatchTab = t end
                end
            end
            if cat.HeaderLat then
                cat.HeaderLat.Visible = (texto == "") or catTieneMatch
                if buscandoActivo and catTieneMatch and cat.Colapsada then
                    cat:AlternarColapso(false)
                end
            end
        end

        if buscandoActivo and primerMatchTab then
            primerMatchTab:Seleccionar()
        end
    end

    function Ventana:Buscar(texto)
        filtrarBusqueda(texto)
    end

    if config.Buscador ~= false then
        local busquedaId = 0
        local function conectarBuscador(caja)
            caja:GetPropertyChangedSignal("Text"):Connect(function()
                busquedaId = busquedaId + 1
                local idActual = busquedaId
                local txt = caja.Text
                task.delay(0.12, function()
                    if idActual == busquedaId then filtrarBusqueda(txt) end
                end)
            end)
        end

        local function crearCajaBuscador()
            local caja = Instance.new("TextBox")
            caja.BackgroundColor3 = Theme.Entrada
            caja.BackgroundTransparency = 0.4
            caja.PlaceholderText  = "🔍 Buscar..."
            caja.Text             = ""
            caja.TextColor3       = Theme.Text
            caja.Font             = Enum.Font.Gotham
            caja.TextSize         = 10
            caja.ClearTextOnFocus = false
            caja.BorderSizePixel  = 0
            Utils.Corner(caja, 5)
            AlanLuna:Registrar(caja, "BackgroundColor3", "Entrada")
            AlanLuna:Registrar(caja, "TextColor3", "Text")
            conectarBuscador(caja)
            return caja
        end

        local buscadorBox = crearCajaBuscador()
        buscadorBox.Size        = UDim2.new(1, 0, 0, 20)
        buscadorBox.LayoutOrder = 0
        buscadorBox.Parent      = barraLat

        local buscadorBoxHoriz = crearCajaBuscador()
        buscadorBoxHoriz.Size     = UDim2.new(0, 130, 0, 22)
        buscadorBoxHoriz.Position = UDim2.new(1, -145, 0, 40)
        buscadorBoxHoriz.ZIndex   = 10
        buscadorBoxHoriz.Visible  = modoHorizontal
        buscadorBoxHoriz.Parent   = main
        Ventana._buscadorBoxHoriz = buscadorBoxHoriz
    end

    -- ── CREAR CATEGORIA ENGINE ──────────────────────────────────
    function Ventana:CrearCategoria(catCfg)
        if type(catCfg) == "string" then catCfg = { Nombre = catCfg } end
        catCfg = catCfg or {}
        local nombreCat = catCfg.Nombre or "General"
        if self.Categorias[nombreCat] then return self.Categorias[nombreCat] end

        catOrden = catOrden + 1
        local esSistema = (nombreCat == "System")
        local colapsada = (catCfg.Colapsada == true) and not esSistema

        local headerLat = Utils.Frame({
            Padre = barraLat, Size = UDim2.new(1, 0, 0, 22),
            Color = Theme.Panel, Transparencia = 1, Orden = esSistema and -1000 or (catOrden * 100),
            Radio = false, Borde = false,
        })

        local btnHeader = Utils.BotonBase({
            Padre = headerLat, Size = UDim2.new(1, 0, 1, 0),
            Transparencia = 1, Radio = false,
        })

        local icoFlecha = Instance.new("ImageLabel")
        icoFlecha.BackgroundTransparency = 1
        icoFlecha.Image = "rbxassetid://83472139709682"
        icoFlecha.Size = UDim2.new(0, 8, 0, 8)
        icoFlecha.AnchorPoint = Vector2.new(0.5, 0.5)
        icoFlecha.Position = UDim2.new(0, 8, 0.5, 0)
        icoFlecha.Rotation = colapsada and -90 or 0
        icoFlecha.Visible = not esSistema
        icoFlecha.Parent = headerLat
        AlanLuna:Registrar(icoFlecha, "ImageColor3", "TextDark")

        local lblCat = Utils.Texto({
            Padre = headerLat,
            Texto = (catCfg.Icono and (catCfg.Icono .. " ") or "") .. string.upper(nombreCat),
            Size = UDim2.new(1, -20, 1, 0),
            Posicion = UDim2.new(0, esSistema and 6 or 16, 0, 0),
            Font = Enum.Font.GothamBold,
            Tamano = 9,
            Color = catCfg.Color or Theme.AccentLight,
            Truncar = true,
        })
        if not catCfg.Color then AlanLuna:Registrar(lblCat, "TextColor3", "AccentLight") end

        local contenedorTabsCat = Instance.new("Frame")
        contenedorTabsCat.Name = "TabsContainer_" .. nombreCat
        contenedorTabsCat.BackgroundTransparency = 1
        contenedorTabsCat.Size = UDim2.new(1, 0, 0, 0)
        contenedorTabsCat.AutomaticSize = Enum.AutomaticSize.Y
        contenedorTabsCat.LayoutOrder = esSistema and -999 or ((catOrden * 100) + 1)
        contenedorTabsCat.Visible = not colapsada
        contenedorTabsCat.Parent = barraLat

        local catList = Instance.new("UIListLayout")
        catList.Padding = UDim.new(0, 2)
        catList.SortOrder = Enum.SortOrder.LayoutOrder
        catList.Parent = contenedorTabsCat

        local CategoriaObj = {
            Nombre     = nombreCat,
            Colapsada  = colapsada,
            Tabs       = {},
            HeaderLat  = headerLat,
            Contenedor = contenedorTabsCat,
        }

        function CategoriaObj:AlternarColapso(forzar)
            if esSistema then return end
            self.Colapsada = (forzar ~= nil and forzar) or not self.Colapsada
            contenedorTabsCat.Visible = not self.Colapsada
            Utils.Tween(icoFlecha, {Rotation = self.Colapsada and -90 or 0}, 0.2)
        end

        if not esSistema then
            Utils.ClickConfiable(btnHeader, function()
                CategoriaObj:AlternarColapso()
            end)
        end

        function CategoriaObj:CrearTab(tabCfg)
            if type(tabCfg) == "string" then tabCfg = { Nombre = tabCfg } end
            tabCfg = tabCfg or {}
            local nombreTab = tabCfg.Nombre or "Tab"
            local iconoTab = tabCfg.Icono or "▪"
            local showTitle = tabCfg.ShowTitle ~= false

            local ordenTabInterno = #self.Contenedor:GetChildren()

            local botonLat = Utils.BotonBase({
                Padre = self.Contenedor, Size = UDim2.new(1, 0, 0, 26),
                Color = Theme.Fila, Transparencia = 0.5,
                Orden = ordenTabInterno, Radio = 6,
            })
            local hitboxTabLat = Utils.HitboxAmpliado(botonLat, 6)
            Utils.Hover(hitboxTabLat, botonLat)
            AlanLuna:Registrar(botonLat, "BackgroundColor3", "Fila")

            local indicadorLat = Utils.Frame({
                Padre = botonLat, Size = UDim2.new(0, 2.5, 1, -6),
                Posicion = UDim2.new(0, 0, 0, 3),
                Color = Theme.Accent, Radio = 2, Borde = false,
            })
            indicadorLat.BackgroundTransparency = 1
            AlanLuna:Registrar(indicadorLat, "BackgroundColor3", "Accent")

            local icAsset = GetIcon(iconoTab, "Material")
            local iconoObj
            if icAsset then
                local img = Instance.new("ImageLabel")
                img.BackgroundTransparency = 1
                img.Size = UDim2.new(0, 14, 0, 14)
                img.Position = UDim2.new(0, 6, 0.5, -7)
                if type(icAsset) == "table" then
                    img.Image = "rbxassetid://" .. tostring(icAsset.id)
                    img.ImageRectSize = icAsset.imageRectSize
                    img.ImageRectOffset = icAsset.imageRectOffset
                else
                    img.Image = icAsset
                end
                img.Parent = botonLat
                iconoObj = img
            else
                local txtIco = Utils.Texto({
                    Padre = botonLat, Texto = iconoTab,
                    Size = UDim2.new(0, 18, 1, 0), Posicion = UDim2.new(0, 4, 0, 0),
                    Alineacion = Enum.TextXAlignment.Center, Tamano = 11,
                })
                iconoObj = txtIco
            end

            local lblTab = Utils.Texto({
                Padre = botonLat, Texto = nombreTab,
                Size = UDim2.new(1, -26, 1, 0), Posicion = UDim2.new(0, 24, 0, 0),
                Fuente = Enum.Font.GothamMedium, Tamano = 10.5,
                Categoria = "tabs", Truncar = true,
            })

            local botonHoriz = Utils.BotonBase({
                Padre = barraHoriz, Size = UDim2.new(0, 85, 0, 24),
                Color = Theme.Fila, Transparencia = 0.5,
                Orden = ordenTabInterno, Radio = 6,
            })
            botonHoriz.AutomaticSize = Enum.AutomaticSize.X
            local padH = Instance.new("UIPadding")
            padH.PaddingLeft, padH.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
            padH.Parent = botonHoriz

            local indicadorHoriz = Utils.Frame({
                Padre = botonHoriz, Size = UDim2.new(1, -6, 0, 2),
                Posicion = UDim2.new(0, 3, 1, -2), Color = Theme.Accent,
                Radio = 1, Borde = false,
            })
            indicadorHoriz.BackgroundTransparency = 1
            AlanLuna:Registrar(indicadorHoriz, "BackgroundColor3", "Accent")

            local lblH = Utils.Texto({
                Padre = botonHoriz, Texto = nombreTab,
                Size = UDim2.new(1, 0, 1, 0), Alineacion = Enum.TextXAlignment.Center,
                Tamano = 10, Fuente = Enum.Font.GothamMedium, Categoria = "tabs",
            })

            local paginaTab = Instance.new("Frame")
            paginaTab.Name = "TabPage_" .. nombreTab
            paginaTab.Size = UDim2.new(1, 0, 1, -24)
            paginaTab.Position = UDim2.new(0, 0, 0, 24)
            paginaTab.BackgroundTransparency = 1
            paginaTab.Visible = primeraTabGlobal
            paginaTab.Parent = contenedorPaginas

            if showTitle then
                local tLbl = Utils.Texto({
                    Padre = paginaTab, Texto = nombreTab,
                    Size = UDim2.new(1, -20, 0, 20), Posicion = UDim2.new(0, 10, 0, 0),
                    Fuente = Enum.Font.GothamBold, Tamano = 14, Color = Theme.Highlight,
                })
                AlanLuna:Registrar(tLbl, "TextColor3", "Highlight")
            end

            local subTabBar = Utils.Frame({
                Padre = paginaTab, Size = UDim2.new(1, -16, 0, 24),
                Posicion = UDim2.new(0, 8, 0, showTitle and 22 or 2),
                Transparencia = 1, Radio = false, Borde = false,
            })
            subTabBar.Visible = false

            local subLayout = Instance.new("UIListLayout")
            subLayout.FillDirection = Enum.FillDirection.Horizontal
            subLayout.Padding = UDim.new(0, 4)
            subLayout.Parent = subTabBar

            local subTabContainer = Utils.Frame({
                Padre = paginaTab,
                Size = UDim2.new(1, 0, 1, showTitle and -48 or -28),
                Posicion = UDim2.new(0, 0, 0, showTitle and 48 or 28),
                Transparencia = 1, Radio = false, Borde = false,
            })

            local TabObj = {
                Nombre         = nombreTab,
                Categoria      = nombreCat,
                Boton          = botonLat,
                BotonLat       = botonLat,
                BotonHoriz     = botonHoriz,
                IndicadorLat   = indicadorLat,
                IndicadorHoriz = indicadorHoriz,
                Pagina         = paginaTab,
                SubTabBar      = subTabBar,
                SubTabContainer = subTabContainer,
                SubTabs        = {},
                SubTabsOrden   = {},
            }

            function TabObj:Seleccionar()
                for _, catIter in pairs(Ventana.Categorias) do
                    for _, tIter in pairs(catIter.Tabs) do
                        tIter.Pagina.Visible = false
                        Utils.Tween(tIter.IndicadorLat,   {BackgroundTransparency = 1}, 0.2)
                        Utils.Tween(tIter.IndicadorHoriz, {BackgroundTransparency = 1}, 0.2)
                    end
                end
                self.Pagina.Visible = true
                Utils.Tween(self.IndicadorLat,   {BackgroundTransparency = 0}, 0.2)
                Utils.Tween(self.IndicadorHoriz, {BackgroundTransparency = 0}, 0.2)

                categoriaActivaNombre = self.Categoria
                tabActivaNombre = self.Nombre

                if #self.SubTabsOrden > 0 then
                    local activoSub = self.SubTabs[subTabActivaNombre] or self.SubTabsOrden[1]
                    if activoSub then activoSub:Seleccionar() end
                else
                    subTabActivaNombre = nil
                end
                actualizarBreadcrumb()
                AlanLuna.Eventos.TabCambiada:Fire(self.Categoria, self.Nombre)
            end

            Utils.ClickConfiable(hitboxTabLat, function() TabObj:Seleccionar() end, botonLat)
            Utils.ClickConfiable(botonHoriz, function() TabObj:Seleccionar() end)

            -- ── CREAR SUBTAB ENGINE ─────────────────────────────────
            function TabObj:CrearSubTab(subCfg)
                if type(subCfg) == "string" then subCfg = { Nombre = subCfg } end
                subCfg = subCfg or {}
                local subNombre = subCfg.Nombre or "Main"
                if self.SubTabs[subNombre] then return self.SubTabs[subNombre] end

                local subBtn = Utils.BotonBase({
                    Padre = self.SubTabBar, Size = UDim2.new(0, 70, 1, 0),
                    Color = Theme.Fila, Transparencia = 0.5, Radio = 5,
                })
                subBtn.AutomaticSize = Enum.AutomaticSize.X
                local sPad = Instance.new("UIPadding")
                sPad.PaddingLeft, sPad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
                sPad.Parent = subBtn

                local sLbl = Utils.Texto({
                    Padre = subBtn, Texto = subNombre,
                    Size = UDim2.new(1, 0, 1, 0), Alineacion = Enum.TextXAlignment.Center,
                    Tamano = 10, Fuente = Enum.Font.GothamMedium,
                })

                local subPagina = Instance.new("ScrollingFrame")
                subPagina.Name = "SubPage_" .. subNombre
                subPagina.Size = UDim2.new(1, 0, 1, 0)
                subPagina.BackgroundTransparency = 1
                subPagina.BorderSizePixel = 0
                subPagina.ScrollBarThickness = 3
                subPagina.ScrollBarImageColor3 = Theme.Accent
                subPagina.CanvasSize = UDim2.new(0, 0, 0, 0)
                subPagina.AutomaticCanvasSize = Enum.AutomaticSize.Y
                subPagina.Visible = (#self.SubTabsOrden == 0)
                subPagina.Parent = self.SubTabContainer

                local pLayout = Instance.new("UIListLayout")
                pLayout.Padding   = UDim.new(0, 10)
                pLayout.SortOrder = Enum.SortOrder.LayoutOrder
                pLayout.Parent    = subPagina

                local pPad = Instance.new("UIPadding")
                pPad.PaddingTop, pPad.PaddingBottom = UDim.new(0, 6), UDim.new(0, 10)
                pPad.PaddingLeft, pPad.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
                pPad.Parent = subPagina

                local SubTabObj = {
                    Nombre    = subNombre,
                    Boton     = subBtn,
                    Pagina    = subPagina,
                    Secciones = {},
                }

                function SubTabObj:Seleccionar()
                    for _, s in pairs(TabObj.SubTabs) do
                        s.Pagina.Visible = false
                        Utils.Tween(s.Boton, {BackgroundColor3 = Theme.Fila}, 0.2)
                    end
                    self.Pagina.Visible = true
                    Utils.Tween(self.Boton, {BackgroundColor3 = Theme.Accent}, 0.2)
                    subTabActivaNombre = self.Nombre
                    actualizarBreadcrumb()
                    AlanLuna.Eventos.SubTabCambiada:Fire(TabObj.Categoria, TabObj.Nombre, self.Nombre)
                end

                Utils.ClickConfiable(subBtn, function() SubTabObj:Seleccionar() end)

                table.insert(self.SubTabsOrden, SubTabObj)
                self.SubTabs[subNombre] = SubTabObj

                if #self.SubTabsOrden >= 2 then
                    self.SubTabBar.Visible = true
                    self.SubTabContainer.Position = UDim2.new(0, 0, 0, showTitle and 48 or 28)
                    self.SubTabContainer.Size = UDim2.new(1, 0, 1, showTitle and -48 or -28)
                else
                    self.SubTabBar.Visible = false
                    self.SubTabContainer.Position = UDim2.new(0, 0, 0, showTitle and 24 or 4)
                    self.SubTabContainer.Size = UDim2.new(1, 0, 1, showTitle and -24 or -4)
                end

                -- ── CREAR SECCION ENGINE (2-COLUMN SUPPORT) ─────────────
                function SubTabObj:CrearSeccion(secNombre, secCfg)
                    secCfg = secCfg or {}
                    local numColumnas = secCfg.Columnas or 1
                    local colapsable  = secCfg.Colapsable ~= false
                    local colapsadaPorDefecto = colapsable and (secCfg.ColapsadaPorDefecto == true)

                    local marco = Utils.Frame({
                        Padre = subPagina, Size = UDim2.new(1, 0, 0, 0),
                        Color = Theme.Panel, Radio = 6, Borde = true,
                        ColorBorde = Theme.Border, ClaveTemaBorde = "Border",
                        Transparencia = 0.35,
                    })
                    marco.AutomaticSize = Enum.AutomaticSize.Y

                    local btnHeader, flecha, lblSec
                    if colapsable then
                        btnHeader = Utils.BotonBase({
                            Padre = marco, Size = UDim2.new(1, 0, 0, 24),
                            Transparencia = 1, Radio = false,
                        })
                        Utils.Hover(btnHeader, marco, nil, nil, function() return Theme.Panel end)

                        flecha = Instance.new("ImageLabel")
                        flecha.BackgroundTransparency = 1
                        flecha.Image = "rbxassetid://83472139709682"
                        flecha.Size = UDim2.new(0, 10, 0, 10)
                        flecha.AnchorPoint = Vector2.new(0.5, 0.5)
                        flecha.Position = UDim2.new(0, 10, 0.5, 0)
                        flecha.Rotation = colapsadaPorDefecto and -90 or 0
                        flecha.Parent = btnHeader
                        AlanLuna:Registrar(flecha, "ImageColor3", "AccentLight")

                        lblSec = Utils.Texto({
                            Padre = btnHeader, Texto = secNombre or "Sección",
                            Size = UDim2.new(1, -24, 1, 0), Posicion = UDim2.new(0, 20, 0, 0),
                            Fuente = Enum.Font.GothamBold, Tamano = 11, Color = Theme.AccentLight,
                        })
                        AlanLuna:Registrar(lblSec, "TextColor3", "AccentLight")
                    else
                        lblSec = Utils.Texto({
                            Padre = marco, Texto = secNombre or "Sección",
                            Size = UDim2.new(1, -12, 0, 20), Posicion = UDim2.new(0, 8, 0, 2),
                            Fuente = Enum.Font.GothamBold, Tamano = 11, Color = Theme.AccentLight,
                        })
                        AlanLuna:Registrar(lblSec, "TextColor3", "AccentLight")
                    end

                    local contenedorCuerpo = Utils.Frame({
                        Padre = marco, Size = UDim2.new(1, 0, 0, 0),
                        Posicion = UDim2.new(0, 0, 0, 24), Transparencia = 1,
                        Radio = false, Borde = false,
                    })
                    contenedorCuerpo.AutomaticSize = Enum.AutomaticSize.Y
                    contenedorCuerpo.Visible = not colapsadaPorDefecto

                    local col1, col2 = nil, nil
                    if numColumnas == 2 then
                        local filaCols = Instance.new("Frame")
                        filaCols.BackgroundTransparency = 1
                        filaCols.Size = UDim2.new(1, 0, 0, 0)
                        filaCols.AutomaticSize = Enum.AutomaticSize.Y
                        filaCols.Parent = contenedorCuerpo

                        local padCols = Instance.new("UIPadding")
                        padCols.PaddingLeft, padCols.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
                        padCols.PaddingTop, padCols.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
                        padCols.Parent = filaCols

                        col1 = Instance.new("Frame")
                        col1.Name = "Columna1"
                        col1.BackgroundTransparency = 1
                        col1.Size = UDim2.new(0.5, -4, 0, 0)
                        col1.Position = UDim2.new(0, 0, 0, 0)
                        col1.AutomaticSize = Enum.AutomaticSize.Y
                        col1.Parent = filaCols

                        local l1 = Instance.new("UIListLayout")
                        l1.Padding = UDim.new(0, 5)
                        l1.SortOrder = Enum.SortOrder.LayoutOrder
                        l1.Parent = col1

                        col2 = Instance.new("Frame")
                        col2.Name = "Columna2"
                        col2.BackgroundTransparency = 1
                        col2.Size = UDim2.new(0.5, -4, 0, 0)
                        col2.Position = UDim2.new(0.5, 4, 0, 0)
                        col2.AutomaticSize = Enum.AutomaticSize.Y
                        col2.Parent = filaCols

                        local l2 = Instance.new("UIListLayout")
                        l2.Padding = UDim.new(0, 5)
                        l2.SortOrder = Enum.SortOrder.LayoutOrder
                        l2.Parent = col2
                    else
                        local padC = Instance.new("UIPadding")
                        padC.PaddingLeft, padC.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
                        padC.PaddingTop, padC.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
                        padC.Parent = contenedorCuerpo

                        local lC = Instance.new("UIListLayout")
                        lC.Padding = UDim.new(0, 5)
                        lC.SortOrder = Enum.SortOrder.LayoutOrder
                        lC.Parent = contenedorCuerpo
                    end

                    local entradaSec = {
                        marco = marco,
                        contenedor = contenedorCuerpo,
                        flecha = flecha,
                        colapsable = colapsable,
                        colapsada = colapsadaPorDefecto,
                    }

                    local function aplicarColapsada(v, animar)
                        entradaSec.colapsada = v
                        if flecha then
                            if animar then Utils.Tween(flecha, {Rotation = v and -90 or 0}, 0.2)
                            else flecha.Rotation = v and -90 or 0 end
                        end
                        if not animar then
                            contenedorCuerpo.Visible = not v
                            return
                        end
                        if v then
                            Utils.Tween(contenedorCuerpo, {Size = UDim2.new(1, 0, 0, 0)}, 0.25, AlanLuna.Motion.EaseSalir)
                            task.delay(0.25, function()
                                if entradaSec.colapsada then contenedorCuerpo.Visible = false end
                            end)
                        else
                            contenedorCuerpo.Visible = true
                            Utils.Tween(contenedorCuerpo, {Size = UDim2.new(1, 0, 0, contenedorCuerpo.AbsoluteSize.Y)}, 0.25, AlanLuna.Motion.EaseEntrar)
                        end
                    end
                    entradaSec.AplicarColapsada = aplicarColapsada

                    if colapsable and btnHeader then
                        Utils.ClickConfiable(btnHeader, function()
                            aplicarColapsada(not entradaSec.colapsada, true)
                        end)
                    end

                    table.insert(SubTabObj.Secciones, entradaSec)
                    table.insert(seccionesRegistradas, entradaSec)

                    local Seccion = {
                        marco = marco,
                        contenedor = contenedorCuerpo,
                        _col1 = col1,
                        _col2 = col2,
                        _contadorItems = 0,
                    }

                    local CONTROLES_ANCHOS = {
                        Slider = true, RangeSlider = true, Input = true,
                        ColorPicker = true, TagInput = true, Dropdown = true,
                        Parrafo = true, Imagen = true,
                    }

                    function Seccion:_ObtenerContenedorDestino(tipoControl, cfgCtrl)
                        if numColumnas ~= 2 then return contenedorCuerpo end
                        if cfgCtrl and cfgCtrl.Columna == 1 then return col1 end
                        if cfgCtrl and cfgCtrl.Columna == 2 then return col2 end

                        if CONTROLES_ANCHOS[tipoControl] and not (cfgCtrl and cfgCtrl.Columna) then
                            return contenedorCuerpo
                        end

                        self._contadorItems = self._contadorItems + 1
                        return (self._contadorItems % 2 == 1) and col1 or col2
                    end

                    return Seccion
                end

                function TabObj:CrearSeccion(secNombre, secCfg)
                    local subMain = self.SubTabs["Main"] or self:CrearSubTab("Main")
                    return subMain:CrearSeccion(secNombre, secCfg)
                end

                return SubTabObj
            end

            table.insert(Ventana.Tabs, TabObj)
            self.Tabs[nombreTab] = TabObj

            if primeraTabGlobal then
                TabObj:Seleccionar()
                primeraTabGlobal = false
            end

            return TabObj
        end

        self.Categorias[nombreCat] = CategoriaObj
        return CategoriaObj
    end

    function Ventana:CrearTab(tabCfg, icono)
        if type(tabCfg) == "string" then
            tabCfg = { Nombre = tabCfg, Icono = icono }
        end
        local catGeneral = self.Categorias["General"] or self:CrearCategoria("General")
        return catGeneral:CrearTab(tabCfg)
    end

    local catSystem = Ventana:CrearCategoria({ Nombre = "System", Icono = "settings" })
    Ventana._catSystem = catSystem

    if config.AutoGuardar ~= false and fsDisponible() then
        ventanaActivaGuardado = Ventana
        task.defer(function()
            pcall(function() AlanLuna.SaveManager:CargarSilencioso(Ventana.NombreConfig) end)
            pcall(function() AlanLuna.SaveManager:CargarUI("preinstalada") end)
        end)

        sg.Destroying:Connect(function()
            loopAutoguardadoActivo = false
            pcall(function() AlanLuna.SaveManager:GuardarSilencioso(Ventana.NombreConfig) end)
        end)
        iniciarLoopAutoguardado()
    end

    _G.AlanLuna_Instancia.Ventana = Ventana
    return Ventana
end

function AlanLuna:CreateWindow(cfg)
    return self:CrearVentana(cfg)
end

function AlanLuna:CrearVentanaConSeguridad(config)
    config = config or {}
    local instanciaActiva = _G.AlanLuna_Instancia
    local ventanaActual = instanciaActiva and instanciaActiva.Ventana

    if not (ventanaActual and ventanaActual._main and ventanaActual._main.Parent) then
        return AlanLuna:CrearVentana(config)
    end

    local tituloActual = instanciaActiva.Titulo or "Interfaz actual"
    local tituloNuevo  = config.Titulo or config.Name or "Nuevo script"

    local resp = nil
    AlanLuna:Confirmar({
        Titulo    = "⚠️ Script activo detectado",
        Contenido = string.format("Ya hay una ventana abierta (\"%s\"). ¿Deseas reemplazarla por \"%s\"?", tituloActual, tituloNuevo),
        Icono     = "warning",
        Botones   = {
            { Texto = "No", Variante = "neutral", Callback = function() resp = false end },
            { Texto = "Sí", Variante = "primary", Callback = function() resp = true end },
        }
    })

    if resp == true then
        pcall(function() ventanaActual:Destruir() end)
        return AlanLuna:CrearVentana(config)
    end
    return nil
end

-- ══════════════════════════════════════════════════════════════
--  SECCION 21: CONTROL HELPERS (ARRASTRE, RANGOS & PANELES)
-- ══════════════════════════════════════════════════════════════
local function crearBarraArrastrable(cfg)
    local fondo = Utils.Frame({
        Padre = cfg.Padre, Size = cfg.Size, Posicion = cfg.Posicion,
        Color = Theme.Entrada, Radio = 4, Transparencia = 0.4,
    })
    AlanLuna:Registrar(fondo, "BackgroundColor3", "Entrada")

    local aroArrastre = Utils.Stroke(fondo, Theme.AccentLight, 1.5, 1)
    AlanLuna:Registrar(aroArrastre, "Color", "AccentLight")

    local function marcarArrastre(activo)
        Utils.Tween(aroArrastre, {Transparency = activo and 0 or 1}, AlanLuna.Motion.Hover)
    end

    local relleno = Utils.Frame({
        Padre = fondo,
        Size = UDim2.new((cfg.Valor - cfg.Min) / (cfg.Max - cfg.Min), 0, 1, 0),
        Color = Theme.Accent, Radio = 4, Transparencia = 0,
        Borde = false,
    })
    AlanLuna:Registrar(relleno, "BackgroundColor3", "Accent")
    Utils.GradienteAcento(relleno, 0)

    if cfg.Pasos and cfg.Incremento and cfg.Incremento > 0 then
        local totalPasos = math.floor((cfg.Max - cfg.Min) / cfg.Incremento + 0.5)
        if totalPasos >= 2 and totalPasos <= 40 then
            for i = 1, totalPasos - 1 do
                local rel = i / totalPasos
                local marca = Utils.Frame({
                    Padre = fondo, Size = UDim2.new(0, 1.5, 1, 0),
                    Posicion = UDim2.new(rel, -1, 0, 0),
                    Color = Theme.Border, Transparencia = 0.4, Radio = false, Borde = false,
                })
                marca.ZIndex = 2
                AlanLuna:Registrar(marca, "BackgroundColor3", "Border")
            end
        end
    end

    local function fijarVisual(valor)
        local rel = math.clamp((valor - cfg.Min) / (cfg.Max - cfg.Min), 0, 1)
        local duracion = EventManager:HayArrastreActivo() and AlanLuna.Motion.Directo or AlanLuna.Motion.Page
        Utils.Tween(relleno, {Size = UDim2.new(rel, 0, 1, 0)}, duracion, AlanLuna.Motion.EaseEntrar)
    end

    local function calcularYAplicar(input)
        local rel = math.clamp(
            (input.Position.X - fondo.AbsolutePosition.X) / fondo.AbsoluteSize.X, 0, 1
        )
        local v = cfg.Min + rel * (cfg.Max - cfg.Min)
        Utils.Tween(relleno, {Size = UDim2.new(rel, 0, 1, 0)}, AlanLuna.Motion.Directo)
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
            Transparencia = 1, Radio = false, Borde = false,
        })
        hitbox.ZIndex = fondo.ZIndex + 1
        objetoInput = hitbox
    end

    objetoInput.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if EventManager:HayArrastreActivo() then return end

            local UMBRAL_GESTO = 10
            local inicio = Vector2.new(input.Position.X, input.Position.Y)
            local decidido = false
            local esArrastre = false

            local scrollAncestro = fondo:FindFirstAncestorWhichIsA("ScrollingFrame")
            local scrollEstabaActivo = scrollAncestro and scrollAncestro.ScrollingEnabled

            local function candidato(inputMovido)
                if not decidido then
                    local actual = Vector2.new(inputMovido.Position.X, inputMovido.Position.Y)
                    local delta = actual - inicio
                    if delta.Magnitude < UMBRAL_GESTO then return end
                    decidido = true
                    if math.abs(delta.X) > math.abs(delta.Y) then
                        esArrastre = true
                        if scrollAncestro then scrollAncestro.ScrollingEnabled = false end
                        marcarArrastre(true)
                    else
                        EventManager:DetenerArrastre()
                        return
                    end
                end
                if esArrastre then
                    calcularYAplicar(inputMovido)
                end
            end

            EventManager:Arrastrar(candidato, function()
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
        Color = Theme.Entrada, Radio = 4, Transparencia = 0.4,
    })
    AlanLuna:Registrar(fondo, "BackgroundColor3", "Entrada")

    local function relX(v)
        return math.clamp((v - cfg.Min) / (cfg.Max - cfg.Min), 0, 1)
    end

    local relleno = Utils.Frame({
        Padre = fondo,
        Posicion = UDim2.new(relX(cfg.ValorMin), 0, 0, 0),
        Size = UDim2.new(relX(cfg.ValorMax) - relX(cfg.ValorMin), 0, 1, 0),
        Color = Theme.Accent, Radio = 4, Transparencia = 0,
        Borde = false,
    })
    AlanLuna:Registrar(relleno, "BackgroundColor3", "Accent")
    Utils.GradienteAcento(relleno, 0)

    local DIAMETRO_MANIJA = cfg.DiametroManija or 14
    local function crearManija()
        local m = Utils.Frame({
            Padre = fondo,
            Size = UDim2.new(0, DIAMETRO_MANIJA, 0, DIAMETRO_MANIJA),
            Ancla = Vector2.new(0.5, 0.5),
            Color = Theme.Highlight, Radio = 999, Transparencia = 0,
        })
        m.ZIndex = 3
        AlanLuna:Registrar(m, "BackgroundColor3", "Highlight")
        local aro = Utils.Stroke(m, Theme.AccentLight, 1.5, 1)
        AlanLuna:Registrar(aro, "Color", "AccentLight")
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
        Utils.Tween(aro, {Transparency = activo and 0 or 1}, AlanLuna.Motion.Hover)
    end

    local function fijarVisual(vMin, vMax)
        posicionarManija(manijaMin, vMin)
        posicionarManija(manijaMax, vMax)
        relleno.Position = UDim2.new(relX(vMin), 0, 0, 0)
        relleno.Size = UDim2.new(relX(vMax) - relX(vMin), 0, 1, 0)
    end

    local function calcularValor(input)
        local rel = math.clamp(
            (input.Position.X - fondo.AbsolutePosition.X) / fondo.AbsoluteSize.X, 0, 1
        )
        return cfg.Min + rel * (cfg.Max - cfg.Min)
    end

    fondo.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            if EventManager:HayArrastreActivo() then return end

            local UMBRAL_GESTO = 10
            local inicio = Vector2.new(input.Position.X, input.Position.Y)
            local decidido = false
            local esArrastre = false
            local moviendoMin = nil

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
                    local actual = Vector2.new(inputMovido.Position.X, inputMovido.Position.Y)
                    local delta = actual - inicio
                    if delta.Magnitude < UMBRAL_GESTO then return end
                    decidido = true
                    if math.abs(delta.X) > math.abs(delta.Y) then
                        esArrastre = true
                        elegirManija(input)
                        if scrollAncestro then scrollAncestro.ScrollingEnabled = false end
                        marcarArrastre(moviendoMin and aroMin or aroMax, true)
                    else
                        EventManager:DetenerArrastre()
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

            EventManager:Arrastrar(candidato, function()
                if esArrastre then
                    marcarArrastre(moviendoMin and aroMin or aroMax, false)
                end
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
        for _, conexion in ipairs(conexionesCierre) do
            AlanLuna:DesconectarYLimpiar(conexion)
        end
        conexionesCierre = {}
    end

    local function alternar()
        abierto = not abierto
        local alto = abierto and obtenerAltoAbierto() or altoCerrado
        Utils.Tween(marco, {Size = UDim2.new(1, 0, 0, alto)}, AlanLuna.Motion.Expand)

        limpiarConexionesCierre()

        if abierto then
            local UMBRAL_MOVIMIENTO = AlanLuna.Capacidades.EsTactil and 18 or 10
            local inicio = nil
            table.insert(conexionesCierre, AlanLuna:RegistrarConexion(
                UserInputService.InputBegan:Connect(function(input)
                    if input.UserInputType ~= Enum.UserInputType.MouseButton1 and
                       input.UserInputType ~= Enum.UserInputType.Touch then return end
                    if marco.Parent and estaFuera(input) then
                        inicio = {
                            tipo = input.UserInputType,
                            pos = Vector2.new(input.Position.X, input.Position.Y),
                        }
                    else
                        inicio = nil
                    end
                end)
            ))
            table.insert(conexionesCierre, AlanLuna:RegistrarConexion(
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

-- ══════════════════════════════════════════════════════════════
--  SECCION 22: TOOLTIP ENGINE (OVERLAY & GESTURES)
-- ══════════════════════════════════════════════════════════════
local overlayGui, panelAyuda, lblAyuda, conexionCierreGlobal

local function obtenerOverlayTooltip()
    if overlayGui and overlayGui.Parent then return overlayGui end

    overlayGui = Instance.new("ScreenGui")
    overlayGui.Name = "AlanLuna_TooltipOverlay"
    overlayGui.ResetOnSpawn = false
    overlayGui.IgnoreGuiInset = true
    overlayGui.DisplayOrder = 9999999
    pcall(function() overlayGui.Parent = obtenerPadreGui() end)
    protegerGui(overlayGui)
    AlanLuna:RegistrarInstancia(overlayGui)

    panelAyuda = Instance.new("Frame")
    panelAyuda.Name = "PanelAyuda"
    panelAyuda.BackgroundColor3 = Theme.Panel
    panelAyuda.BackgroundTransparency = 0.2
    panelAyuda.BorderSizePixel = 0
    panelAyuda.Visible = false
    panelAyuda.ZIndex = 1000
    panelAyuda.Size = UDim2.new(0, 190, 0, 0)
    panelAyuda.AutomaticSize = Enum.AutomaticSize.Y
    panelAyuda.Parent = overlayGui
    AlanLuna:Registrar(panelAyuda, "BackgroundColor3", "Panel")
    Utils.Corner(panelAyuda, 6)
    local strokeTooltip = Utils.Stroke(panelAyuda, Theme.Accent, 1, 0.3)
    AlanLuna:Registrar(strokeTooltip, "Color", "Accent")

    local blurTip = BlurModule(panelAyuda)

    local pad = Instance.new("UIPadding")
    pad.PaddingLeft, pad.PaddingRight   = UDim.new(0, 8), UDim.new(0, 8)
    pad.PaddingTop,  pad.PaddingBottom  = UDim.new(0, 6), UDim.new(0, 6)
    pad.Parent = panelAyuda

    lblAyuda = Utils.Texto({
        Padre = panelAyuda, Texto = "",
        Size = UDim2.new(1, 0, 0, 0),
        Tamano = 10.5, Ajustar = true,
    })
    lblAyuda.AutomaticSize = Enum.AutomaticSize.Y
    lblAyuda.ZIndex = 1001
    AlanLuna:Registrar(lblAyuda, "TextColor3", "Text")

    return overlayGui
end

local function cerrarTooltipGlobal()
    if panelAyuda then panelAyuda.Visible = false end
    if conexionCierreGlobal then
        AlanLuna:DesconectarYLimpiar(conexionCierreGlobal)
        conexionCierreGlobal = nil
    end
end

local function mostrarTooltipEn(elementoRef, textoAyuda)
    obtenerOverlayTooltip()

    if panelAyuda.Visible and lblAyuda.Text == textoAyuda then
        cerrarTooltipGlobal()
        return
    end

    cerrarTooltipGlobal()

    lblAyuda.Text = textoAyuda
    panelAyuda.Size = UDim2.new(0, 190, 0, 0)

    local pos = elementoRef.AbsolutePosition
    local tam = elementoRef.AbsoluteSize
    local x = pos.X
    local y = pos.Y + tam.Y + 4
    local anchoPantalla = overlayGui.AbsoluteSize.X
    if anchoPantalla > 0 then
        x = math.min(x, anchoPantalla - 198)
    end
    panelAyuda.Position = UDim2.new(0, math.max(4, x), 0, y)
    panelAyuda.Visible = true

    local escalaTip = panelAyuda:FindFirstChild("__AlanLuna_TooltipScale")
    if not escalaTip then
        escalaTip = Instance.new("UIScale")
        escalaTip.Name = "__AlanLuna_TooltipScale"
        escalaTip.Parent = panelAyuda
    end
    escalaTip.Scale = 0.92
    Utils.Tween(escalaTip, {Scale = 1}, AlanLuna.Motion.Expand, AlanLuna.Motion.EasePop)

    conexionCierreGlobal = AlanLuna:RegistrarConexion(
        UserInputService.InputBegan:Connect(function(input)
            if input.UserInputType ~= Enum.UserInputType.MouseButton1 and
               input.UserInputType ~= Enum.UserInputType.Touch then return end
            cerrarTooltipGlobal()
        end)
    )
end

local function agregarTooltip(fila, posicion, textoAyuda)
    if not textoAyuda then return end

    local btnInfo = Utils.BotonBase({
        Padre = fila, Size = UDim2.new(0, 18, 0, 18),
        Posicion = posicion, Color = Theme.AccentLight,
        Transparencia = 0.2, Radio = 9,
    })
    btnInfo.ZIndex = 5
    AlanLuna:Registrar(btnInfo, "BackgroundColor3", "AccentLight")

    local lblSigno = Utils.Texto({
        Padre = btnInfo, Texto = "?",
        Alineacion = Enum.TextXAlignment.Center,
        Fuente = Enum.Font.GothamBold, Tamano = 11,
        Color = Theme.TextDark,
    })
    AlanLuna:Registrar(lblSigno, "TextColor3", "TextDark")

    btnInfo.MouseButton1Click:Connect(function()
        mostrarTooltipEn(btnInfo, textoAyuda)
    end)

    return btnInfo
end

local function agregarTooltipTexto(fila, textoLabel, textoAyuda, lblInstancia, offsetDerecho)
    if not textoAyuda then return end
    if not (lblInstancia and lblInstancia.Size) then
        agregarTooltip(fila, UDim2.new(0, 160, 0, 4), textoAyuda)
        return
    end

    local TAM_INFO = 18
    local RESERVA  = TAM_INFO + 10
    local sx = lblInstancia.Size.X.Scale
    local ox = offsetDerecho or lblInstancia.Size.X.Offset
    local px = lblInstancia.Position.X.Offset
    lblInstancia.Size = UDim2.new(sx, ox - RESERVA - px,
        lblInstancia.Size.Y.Scale, lblInstancia.Size.Y.Offset)

    local xInfo = ox - TAM_INFO - 4
    local btnInfo = agregarTooltip(fila, UDim2.new(sx, xInfo, 0.5, 0), textoAyuda)
    btnInfo.AnchorPoint = Vector2.new(0, 0.5)

    local function centrarY()
        if not (btnInfo.Parent and lblInstancia.Parent and fila.Parent) then return end
        if lblInstancia.AbsoluteSize.Y <= 0 then return end
        local e = Utils.FactorEscalaUI(fila)
        local cy = (lblInstancia.AbsolutePosition.Y - fila.AbsolutePosition.Y
            + lblInstancia.AbsoluteSize.Y / 2) / e
        btnInfo.Position = UDim2.new(sx, xInfo, 0, math.floor(cy + 0.5))
    end
    AlanLuna:RegistrarConexion(lblInstancia:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        centrarY(); task.defer(centrarY)
    end))
    AlanLuna:RegistrarConexion(fila:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
        centrarY(); task.defer(centrarY)
    end))
    task.defer(centrarY)

    fila.Active = true
    local UMBRAL_MOVIMIENTO = AlanLuna.Capacidades.EsTactil and 18 or 10
    local TIEMPO_MANTENER = 0.45
    local toqueActual = nil

    local function abrirSiNoEstaAbierto()
        if panelAyuda and panelAyuda.Visible and lblAyuda and lblAyuda.Text == textoAyuda then return end
        pcall(mostrarTooltipEn, fila, textoAyuda)
    end

    fila.InputBegan:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        toqueActual = input
        local posInicial = Vector2.new(input.Position.X, input.Position.Y)
        local inicio = os.clock()
        task.spawn(function()
            while toqueActual == input do
                if not (fila and fila.Parent) then return end
                if input.UserInputState == Enum.UserInputState.End then return end
                local pos = Vector2.new(input.Position.X, input.Position.Y)
                if (pos - posInicial).Magnitude > UMBRAL_MOVIMIENTO then return end
                if os.clock() - inicio >= TIEMPO_MANTENER then
                    toqueActual = nil
                    abrirSiNoEstaAbierto()
                    return
                end
                task.wait(0.05)
            end
        end)
    end)
    fila.InputEnded:Connect(function(input)
        if input.UserInputType ~= Enum.UserInputType.MouseButton1
        and input.UserInputType ~= Enum.UserInputType.Touch then return end
        toqueActual = nil
    end)
    pcall(function()
        fila.TouchLongPress:Connect(function(_, estado)
            if estado == Enum.UserInputState.Begin then abrirSiNoEstaAbierto() end
        end)
    end)

    return btnInfo
end

-- ══════════════════════════════════════════════════════════════
--  SECCION 23: INYECCION DE CONTROLES EN SECCION & LAYOUT 2-COL
-- ══════════════════════════════════════════════════════════════
local function aplicarMetodosControles(Seccion)
    local orden = 0
    local function siguienteOrden() orden = orden + 1; return orden end

    local function crearCabecera(alto, texto, anchoLabel, offsetX, modo, contDestino)
        local fila = Utils.Fila(contDestino, alto, siguienteOrden(), Theme.Fila)
        AlanLuna:Registrar(fila, "BackgroundColor3", "Fila")
        Utils.Hover(fila, fila)
        if modo ~= "fijo" then
            local lblD = Utils.Texto({
                Padre = fila, Texto = texto,
                Size = UDim2.new(anchoLabel or 1, offsetX or -46, 1, 0),
                Tamano = 11, Ajustar = true,
            })
            if modo ~= "manual" then Utils.HacerFilaDinamica(fila, lblD, alto, 5) end
            return fila, lblD
        end
        local lbl = Utils.Texto({
            Padre = fila, Texto = texto,
            Size = UDim2.new(anchoLabel or 1, offsetX or -46, 1, 0),
            Tamano = 11, Truncar = true,
        })
        return fila, lbl
    end

    local function crearControlBooleano(tipoNombre, cfg, crearVisual)
        cfg = cfg or {}
        validarCallback(tipoNombre, cfg)
        local flag  = cfg.Flag or cfg.Texto or (tipoNombre .. "_" .. tostring(math.random(1e5, 1e6)))
        local valor = cfg.Defecto or false
        AlanLuna.Flags[flag] = valor

        local destino = Seccion:_ObtenerContenedorDestino(tipoNombre, cfg)
        local fila, lbl = crearCabecera(26, cfg.Texto or tipoNombre, 1, -48, nil, destino)

        if cfg.Icono then
            local icData = GetIcon(cfg.Icono, "Material")
            if icData then
                local icImg = Instance.new("ImageLabel")
                icImg.BackgroundTransparency = 1
                icImg.Size = UDim2.new(0, 14, 0, 14)
                icImg.Position = UDim2.new(0, 6, 0.5, -7)
                if type(icData) == "table" then
                    icImg.Image = "rbxassetid://" .. tostring(icData.id)
                    icImg.ImageRectSize = icData.imageRectSize
                    icImg.ImageRectOffset = icData.imageRectOffset
                else
                    icImg.Image = icData
                end
                icImg.Parent = fila
                lbl.Position = UDim2.new(0, 24, 0, 0)
                lbl.Size = UDim2.new(lbl.Size.X.Scale, lbl.Size.X.Offset - 18, 1, 0)
            end
        end

        agregarTooltipTexto(fila, cfg.Texto or tipoNombre, cfg.Tooltip, lbl)
        registrarBuscable(fila, cfg.Texto or tipoNombre, cfg.VisibleSi)

        local visual = crearVisual(fila, function() return valor end)

        local function actualizar(v, disparar)
            if type(v) ~= "boolean" then return end
            valor = v
            AlanLuna.Flags[flag] = v
            visual.actualizarVisual(v)

            if v == true and cfg.Desactivar then
                for _, otraFlag in ipairs(cfg.Desactivar) do
                    local ctrl = AlanLuna.Elementos[otraFlag]
                    if ctrl and ctrl.Get() == true then ctrl.Set(false, true) end
                end
            end

            if disparar and cfg.Callback then
                ejecutarConFallback(cfg.Callback, cfg.Texto or "control", v)
            end
        end

        local hitbox = Utils.HitboxAmpliado(visual.clicable, 8)
        Utils.ClickConfiable(hitbox, function() actualizar(not valor, true) end, visual.clicable)

        if cfg.Tecla then
            AlanLuna:RegistrarConexion(UserInputService.InputBegan:Connect(function(input, procesado)
                if procesado then return end
                if input.KeyCode == cfg.Tecla then actualizar(not valor, true) end
            end))
        end

        local elemObj = {
            Set = function(v, dispararCallback) actualizar(v, dispararCallback or false) end,
            Get = function() return valor end,
            UpdateState = function(_, v) actualizar(v, true) end,
            CurrentValue = valor,
        }

        AlanLuna.Elementos[flag] = elemObj
        AlanLuna.Options[flag] = elemObj

        if cfg.Callback then ejecutarConFallback(cfg.Callback, cfg.Texto or "control", valor) end
        return {
            Set = function(...) actualizar(normalizarArgSet(...), true) end,
            Get = function() return valor end,
            UpdateState = function(_, v) actualizar(v, true) end,
            CurrentValue = valor,
        }
    end

    function Seccion:Boton(cfg)
        cfg = cfg or {}
        validarCallback("Botón", cfg)
        local destino = self:_ObtenerContenedorDestino("Boton", cfg)
        local fila = Utils.BotonBase({
            Padre = destino, Size = UDim2.new(1, 0, 0, 26),
            Color = Theme.Fila, Transparencia = 0.5,
            Orden = siguienteOrden(), Radio = 6,
        })
        AlanLuna:Registrar(fila, "BackgroundColor3", "Fila")
        Utils.Hover(fila, fila)

        local textoConIcono = cfg.Texto or cfg.Name or "Botón"
        if cfg.Icono and not string.find(tostring(cfg.Icono), "rbxassetid://") and IconModule.Material[cfg.Icono] == nil then
            textoConIcono = cfg.Icono .. " " .. textoConIcono
        end

        local icAsset = cfg.Icono and GetIcon(cfg.Icono, "Material")
        if icAsset then
            local icImg = Instance.new("ImageLabel")
            icImg.BackgroundTransparency = 1
            icImg.Size = UDim2.new(0, 14, 0, 14)
            icImg.Position = UDim2.new(0, 6, 0.5, -7)
            if type(icAsset) == "table" then
                icImg.Image = "rbxassetid://" .. tostring(icAsset.id)
                icImg.ImageRectSize = icAsset.imageRectSize
                icImg.ImageRectOffset = icAsset.imageRectOffset
            else
                icImg.Image = icAsset
            end
            icImg.Parent = fila
        end

        local lblBoton = Utils.Texto({
            Padre = fila, Texto = textoConIcono, RichText = cfg.RichText,
            Size = UDim2.new(1, icAsset and -24 or -10, 1, 0),
            Posicion = UDim2.new(0, icAsset and 22 or 6, 0, 0),
            Tamano = 11,
        })

        agregarTooltipTexto(fila, cfg.Texto or "Botón", cfg.Tooltip or cfg.Description, lblBoton)
        registrarBuscable(fila, cfg.Texto or "Botón", cfg.VisibleSi)

        local spinner, hiloGiro
        local function activarSpinner(activo)
            if activo and not spinner then
                spinner = Utils.Texto({
                    Padre = fila, Texto = "◐",
                    Size = UDim2.new(0, 16, 1, 0), Posicion = UDim2.new(1, -22, 0, 0),
                    Alineacion = Enum.TextXAlignment.Center, Tamano = 12, Color = Theme.AccentLight,
                })
                AlanLuna:Registrar(spinner, "TextColor3", "AccentLight")
            end
            if not spinner then return end
            spinner.Visible = activo
            if activo then
                hiloGiro = AlanLuna:RegistrarHilo(task.spawn(function()
                    while spinner and spinner.Visible do
                        Utils.Tween(spinner, {Rotation = spinner.Rotation + 360}, AlanLuna.Motion.Spin, AlanLuna.Motion.EaseLineal)
                        task.wait(AlanLuna.Motion.Spin)
                    end
                end))
            end
        end

        local flashId = 0
        local enCurso = false
        Utils.ClickConfiable(fila, function()
            if cfg.Async and enCurso then return end
            flashId = flashId + 1
            local idActual = flashId
            Utils.Tween(fila, {BackgroundColor3 = Theme.Accent, BackgroundTransparency = 0.2}, AlanLuna.Motion.FlashIn)
            task.delay(0.12, function()
                if idActual == flashId and fila and fila.Parent then
                    Utils.Tween(fila, {BackgroundColor3 = Theme.Fila, BackgroundTransparency = 0.5}, AlanLuna.Motion.Expand)
                end
            end)
            if cfg.Callback then
                if cfg.Async then
                    enCurso = true
                    activarSpinner(true)
                    task.spawn(function()
                        ejecutarConFallback(cfg.Callback, cfg.Texto or "control")
                        enCurso = false
                        if fila and fila.Parent then activarSpinner(false) end
                    end)
                else
                    ejecutarConFallback(cfg.Callback, cfg.Texto or "control")
                end
            end
        end)

        return fila
    end

    function Seccion:Toggle(cfg)
        return crearControlBooleano("Toggle", cfg, function(fila, obtenerValor)
            local perilla = Utils.BotonBase({
                Padre = fila, Size = UDim2.new(0, 36, 0, 18),
                Posicion = UDim2.new(1, -42, 0.5, -9),
                Color = obtenerValor() and Theme.Accent or Theme.Apagado,
                Transparencia = 0.2, Radio = 9,
            })
            AlanLuna:Registrar(perilla, "BackgroundColor3", function()
                return obtenerValor() and Theme.Accent or Theme.Apagado
            end)

            local pGrad = Utils.GradienteAcento(perilla)
            pGrad.Enabled = obtenerValor()

            local circulo = Utils.Frame({
                Padre = perilla, Size = UDim2.new(0, 14, 0, 14),
                Posicion = obtenerValor() and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7),
                Color = Theme.Text, Radio = 7, Borde = false, Transparencia = 0,
            })
            AlanLuna:Registrar(circulo, "BackgroundColor3", "Text")

            return {
                clicable = perilla,
                actualizarVisual = function(v)
                    pGrad.Enabled = v
                    Utils.Tween(perilla, {BackgroundColor3 = v and Theme.Accent or Theme.Apagado}, AlanLuna.Motion.Expand)
                    Utils.Tween(circulo, {
                        Position = v and UDim2.new(1, -16, 0.5, -7) or UDim2.new(0, 2, 0.5, -7)
                    }, AlanLuna.Motion.Page, AlanLuna.Motion.EasePop)
                end,
            }
        end)
    end

    function Seccion:Casilla(cfg)
        return crearControlBooleano("Casilla", cfg, function(fila, obtenerValor)
            local caja = Utils.BotonBase({
                Padre = fila, Size = UDim2.new(0, 18, 0, 18),
                Posicion = UDim2.new(1, -26, 0.5, -9),
                Color = obtenerValor() and Theme.Accent or Theme.Entrada,
                Transparencia = 0.3, Radio = 4,
            })
            AlanLuna:Registrar(caja, "BackgroundColor3", function()
                return obtenerValor() and Theme.Accent or Theme.Entrada
            end)
            local strokeCasilla = Utils.Stroke(caja, Theme.Border, 1, 0.3)
            AlanLuna:Registrar(strokeCasilla, "Color", "Border")

            local check = Utils.Frame({
                Padre = caja, Size = UDim2.new(1, 0, 1, 0), Color = Theme.Text, Transparencia = 1, Borde = false,
            })
            local trazoCorto = Utils.Frame({
                Padre = check, Size = UDim2.new(0, 5, 0, 2),
                Posicion = UDim2.new(0.5, -5, 0.5, 1), Color = Theme.Text,
                Transparencia = obtenerValor() and 0 or 1, Radio = 1, Borde = false,
            })
            trazoCorto.Rotation = 45
            local trazoLargo = Utils.Frame({
                Padre = check, Size = UDim2.new(0, 10, 0, 2),
                Posicion = UDim2.new(0.5, -2, 0.5, -3), Color = Theme.Text,
                Transparencia = obtenerValor() and 0 or 1, Radio = 1, Borde = false,
            })
            trazoLargo.Rotation = -45
            AlanLuna:Registrar(trazoCorto, "BackgroundColor3", "Text")
            AlanLuna:Registrar(trazoLargo, "BackgroundColor3", "Text")

            return {
                clicable = caja,
                actualizarVisual = function(v)
                    Utils.Tween(caja, {BackgroundColor3 = v and Theme.Accent or Theme.Entrada}, AlanLuna.Motion.Hover)
                    Utils.Tween(trazoCorto, {BackgroundTransparency = v and 0 or 1}, AlanLuna.Motion.Hover)
                    Utils.Tween(trazoLargo, {BackgroundTransparency = v and 0 or 1}, AlanLuna.Motion.Hover)
                end,
            }
        end)
    end

    function Seccion:Slider(cfg)
        cfg = cfg or {}
        validarCallback("Slider", cfg)
        local flag      = cfg.Flag or cfg.Texto or cfg.Name or ("Slider_" .. tostring(math.random(1e5, 1e6)))
        local range     = cfg.Range or {cfg.Min or 0, cfg.Max or 100}
        local minimo    = range[1]
        local maximo    = range[2]
        if minimo >= maximo then maximo = minimo + 1 end
        local incremento = cfg.Increment or cfg.Incremento or 1
        if incremento <= 0 then incremento = 1 end
        local sufijo    = cfg.Sufijo or ""
        local valor     = math.clamp(cfg.CurrentValue or cfg.Defecto or minimo, minimo, maximo)
        AlanLuna.Flags[flag] = valor

        local destino = self:_ObtenerContenedorDestino("Slider", cfg)
        local fila = Utils.Fila(destino, 42, siguienteOrden(), Theme.Fila)
        AlanLuna:Registrar(fila, "BackgroundColor3", "Fila")
        Utils.Hover(fila, fila)
        registrarBuscable(fila, cfg.Texto or cfg.Name or "Slider", cfg.VisibleSi)

        local lblSlider = Utils.Texto({
            Padre = fila, Texto = cfg.Texto or cfg.Name or "Slider",
            Size = UDim2.new(1, -90, 0, 16), Posicion = UDim2.new(0, 6, 0, 5),
            Truncar = true, Tamano = 11,
        })
        agregarTooltipTexto(fila, cfg.Texto or cfg.Name or "Slider", cfg.Tooltip or cfg.Description, lblSlider, -90)

        local inputValor = Instance.new("TextBox")
        inputValor.Size             = UDim2.new(0, 80, 0, 18)
        inputValor.Position         = UDim2.new(1, -86, 0, 4)
        inputValor.BackgroundColor3 = Theme.Entrada
        inputValor.BackgroundTransparency = 0.4
        inputValor.Text             = tostring(valor) .. sufijo
        inputValor.TextColor3       = Theme.Highlight
        inputValor.Font             = Enum.Font.GothamBold
        inputValor.TextSize         = 11
        inputValor.TextXAlignment   = Enum.TextXAlignment.Right
        inputValor.BorderSizePixel  = 0
        inputValor.ClearTextOnFocus = false
        inputValor.Parent           = fila
        Utils.Corner(inputValor, 4)
        AlanLuna:Registrar(inputValor, "BackgroundColor3", "Entrada")
        AlanLuna:Registrar(inputValor, "TextColor3", "Highlight")

        local function redondear(v)
            local factor = 1 / incremento
            return math.clamp(
                math.floor((v - minimo) * factor + 0.5) / factor + minimo,
                minimo, maximo
            )
        end

        local function quitarSufijo(txt)
            if sufijo ~= "" and txt:sub(-#sufijo) == sufijo then
                return txt:sub(1, -#sufijo - 1)
            end
            return txt
        end

        local decimales = 0
        local dec = tostring(incremento):match("%.(%d+)$")
        if dec then decimales = #dec end
        local function formatearValor(n)
            if decimales > 0 then return string.format("%." .. decimales .. "f", n) end
            return tostring(math.floor(n + 0.5))
        end

        local ultimoProcesado = valor
        local function animarTextoVisible(v, instantaneo)
            if instantaneo then
                inputValor.Text = formatearValor(v) .. sufijo
            else
                Utils.TweenNumero(ultimoProcesado, v, AlanLuna.Motion.Page, function(n)
                    if inputValor and inputValor.Parent then
                        inputValor.Text = formatearValor(redondear(n)) .. sufijo
                    end
                end)
            end
        end

        local function procesarNuevoValor(vCrudo)
            local v = redondear(vCrudo)
            if v == ultimoProcesado then return end
            ultimoProcesado = v
            valor = v
            AlanLuna.Flags[flag] = v
            animarTextoVisible(v, true)
            if cfg.Callback then
                ejecutarConFallback(cfg.Callback, cfg.Texto or cfg.Name or "control", v)
            end
        end

        local barraSlider, relleno, fijarVisual = crearBarraArrastrable({
            Padre = fila,
            Size = UDim2.new(1, -12, 0, 7),
            Posicion = UDim2.new(0, 6, 0, 27),
            Min = minimo, Max = maximo, Valor = valor,
            Incremento = incremento, Pasos = cfg.Pasos,
            AltoHitbox = 16, OffsetHitboxY = 0,
            OnCambio = procesarNuevoValor,
        })

        inputValor.FocusLost:Connect(function(enterPressed)
            if not enterPressed then return end
            local txt = quitarSufijo(inputValor.Text):gsub("%s+", "")
            local num = tonumber(txt)
            if num then
                num = redondear(num)
                ultimoProcesado = num
                valor = num
                AlanLuna.Flags[flag] = num
                animarTextoVisible(num, true)
                fijarVisual(num)
                Utils.FlashFeedback(inputValor, true, Theme.Entrada)
                if cfg.Callback then
                    ejecutarConFallback(cfg.Callback, cfg.Texto or cfg.Name or "Slider", num)
                end
            else
                animarTextoVisible(valor, true)
                Utils.FlashFeedback(inputValor, false, Theme.Entrada)
            end
        end)

        local elemObj = {
            Set = function(v, dispararCallback)
                if typeof(v) ~= "number" then return end
                v = redondear(v)
                ultimoProcesado = v
                valor = v
                AlanLuna.Flags[flag] = v
                animarTextoVisible(v, false)
                fijarVisual(v)
                if dispararCallback and cfg.Callback then
                    ejecutarConFallback(cfg.Callback, cfg.Texto or cfg.Name or "control", v)
                end
            end,
            Get = function() return valor end,
            CurrentValue = valor,
        }
        AlanLuna.Elementos[flag] = elemObj
        AlanLuna.Options[flag] = elemObj

        return {
            Set = function(...) elemObj.Set(normalizarArgSet(...), true) end,
            Get = function() return valor end,
            CurrentValue = valor,
        }
    end

    function Seccion:RangeSlider(cfg)
        cfg = cfg or {}
        validarCallback("RangeSlider", cfg)
        local flag      = cfg.Flag or cfg.Texto or ("RangeSlider_" .. tostring(math.random(1e5, 1e6)))
        local range     = cfg.Range or {cfg.Min or 0, cfg.Max or 100}
        local minimo    = range[1]
        local maximo    = range[2]
        if minimo >= maximo then maximo = minimo + 1 end
        local incremento = cfg.Incremento or 1
        local sufijo    = cfg.Sufijo or ""
        local defecto   = cfg.Defecto or {min = minimo, max = maximo}
        local valorMin  = math.clamp(defecto.min or minimo, minimo, maximo)
        local valorMax  = math.clamp(defecto.max or maximo, minimo, maximo)
        if valorMin > valorMax then valorMin, valorMax = valorMax, valorMin end

        local function flagActual() return {min = valorMin, max = valorMax} end
        AlanLuna.Flags[flag] = flagActual()

        local destino = self:_ObtenerContenedorDestino("RangeSlider", cfg)
        local fila = Utils.Fila(destino, 42, siguienteOrden(), Theme.Fila)
        AlanLuna:Registrar(fila, "BackgroundColor3", "Fila")
        Utils.Hover(fila, fila)
        registrarBuscable(fila, cfg.Texto or "RangeSlider", cfg.VisibleSi)

        local lblSlider = Utils.Texto({
            Padre = fila, Texto = cfg.Texto or "RangeSlider",
            Size = UDim2.new(1, -130, 0, 16), Posicion = UDim2.new(0, 6, 0, 5),
            Truncar = true, Tamano = 11,
        })
        agregarTooltipTexto(fila, cfg.Texto or "RangeSlider", cfg.Tooltip, lblSlider, -130)

        local lblValores = Utils.Texto({
            Padre = fila, Size = UDim2.new(0, 120, 0, 16),
            Posicion = UDim2.new(1, -126, 0, 5), Alineacion = Enum.TextXAlignment.Right,
            Fuente = Enum.Font.GothamBold, Tamano = 11, Color = Theme.Highlight,
        })
        AlanLuna:Registrar(lblValores, "TextColor3", "Highlight")

        local function redondear(v)
            local factor = 1 / incremento
            return math.clamp(
                math.floor((v - minimo) * factor + 0.5) / factor + minimo,
                minimo, maximo
            )
        end

        local function actualizarTextoVisible()
            lblValores.Text = tostring(valorMin) .. sufijo .. " – " .. tostring(valorMax) .. sufijo
        end
        actualizarTextoVisible()

        local ultimoMin, ultimoMax = valorMin, valorMax
        local function procesarNuevoRango(vMinCrudo, vMaxCrudo)
            local vMin = redondear(vMinCrudo)
            local vMax = redondear(vMaxCrudo)
            if vMin > vMax then vMin, vMax = vMax, vMin end
            if vMin == ultimoMin and vMax == ultimoMax then return end
            ultimoMin, ultimoMax = vMin, vMax
            valorMin, valorMax = vMin, vMax
            AlanLuna.Flags[flag] = flagActual()
            actualizarTextoVisible()
            if cfg.Callback then
                ejecutarConFallback(cfg.Callback, cfg.Texto or "control", flagActual())
            end
        end

        local _, fijarVisual = crearBarraArrastrableRango({
            Padre = fila, Size = UDim2.new(1, -12, 0, 7),
            Posicion = UDim2.new(0, 6, 0, 27),
            Min = minimo, Max = maximo, ValorMin = valorMin, ValorMax = valorMax,
            ObtenerMin = function() return ultimoMin end,
            ObtenerMax = function() return ultimoMax end,
            OnCambio = procesarNuevoRango,
        })

        local elemObj = {
            Set = function(v, dispararCallback)
                if type(v) ~= "table" or v.min == nil or v.max == nil then return end
                local vMin = redondear(math.clamp(v.min, minimo, maximo))
                local vMax = redondear(math.clamp(v.max, minimo, maximo))
                if vMin > vMax then vMin, vMax = vMax, vMin end
                ultimoMin, ultimoMax = vMin, vMax
                valorMin, valorMax = vMin, vMax
                AlanLuna.Flags[flag] = flagActual()
                actualizarTextoVisible()
                fijarVisual(vMin, vMax)
                if dispararCallback and cfg.Callback then
                    ejecutarConFallback(cfg.Callback, cfg.Texto or "control", flagActual())
                end
            end,
            Get = function() return flagActual() end,
        }
        AlanLuna.Elementos[flag] = elemObj
        AlanLuna.Options[flag] = elemObj

        return {
            Set = function(...) elemObj.Set(normalizarArgSet(...), true) end,
            Get = function() return flagActual() end,
        }
    end

    function Seccion:NumberStepper(cfg)
        cfg = cfg or {}
        validarCallback("NumberStepper", cfg)
        local flag = cfg.Flag or cfg.Texto or ("NumberStepper_" .. tostring(math.random(1e5, 1e6)))
        local minimo = cfg.Min or 0
        local maximo = cfg.Max or 100
        if minimo >= maximo then maximo = minimo + 1 end
        local incremento = cfg.Incremento or 1
        local decimales = cfg.Decimales or (tostring(incremento):find("%.") and (#tostring(incremento) - tostring(incremento):find("%.")) or 0)
        local prefijo = cfg.Prefijo or ""
        local sufijo  = cfg.Sufijo or ""

        local function redondear(v)
            local factor = 1 / incremento
            return math.clamp(
                math.floor((v - minimo) * factor + 0.5) / factor + minimo,
                minimo, maximo
            )
        end

        local valor = redondear(math.clamp(cfg.Defecto or minimo, minimo, maximo))
        AlanLuna.Flags[flag] = valor

        local function formatear(v)
            local txt = (decimales > 0) and string.format("%." .. decimales .. "f", v) or tostring(math.floor(v + 0.5))
            return prefijo .. txt .. sufijo
        end

        local function quitarAfijos(txt)
            if prefijo ~= "" and txt:sub(1, #prefijo) == prefijo then txt = txt:sub(#prefijo + 1) end
            if sufijo ~= "" and txt:sub(-#sufijo) == sufijo then txt = txt:sub(1, -#sufijo - 1) end
            return txt
        end

        local destino = self:_ObtenerContenedorDestino("NumberStepper", cfg)
        local fila, lbl = crearCabecera(26, cfg.Texto or "NumberStepper", 1, -120, nil, destino)
        agregarTooltipTexto(fila, cfg.Texto or "NumberStepper", cfg.Tooltip, lbl)
        registrarBuscable(fila, cfg.Texto or "NumberStepper", cfg.VisibleSi)

        local ANCHO_BOTON = 20
        local ANCHO_CAJA  = 54
        local GAP = 3
        local ALTO_CONTROL = 18

        local btnMenos = Utils.BotonBase({
            Padre = fila, Color = Theme.Entrada, Transparencia = 0.4, Radio = 4,
            Size = UDim2.new(0, ANCHO_BOTON, 0, ALTO_CONTROL),
            Posicion = UDim2.new(1, -(ANCHO_BOTON * 2 + ANCHO_CAJA + GAP * 2 + 6), 0.5, -ALTO_CONTROL/2),
        })
        AlanLuna:Registrar(btnMenos, "BackgroundColor3", "Entrada")
        Utils.Texto({
            Padre = btnMenos, Texto = "−", Size = UDim2.new(1, 0, 1, 0),
            Alineacion = Enum.TextXAlignment.Center, Fuente = Enum.Font.GothamBold, Tamano = 12,
        })

        local caja = Instance.new("TextBox")
        caja.Size = UDim2.new(0, ANCHO_CAJA, 0, ALTO_CONTROL)
        caja.Position = UDim2.new(1, -(ANCHO_BOTON + ANCHO_CAJA + GAP + 6), 0.5, -ALTO_CONTROL/2)
        caja.BackgroundColor3 = Theme.Entrada
        caja.BackgroundTransparency = 0.4
        caja.Text = formatear(valor)
        caja.TextColor3 = Theme.Highlight
        caja.Font = Enum.Font.GothamBold
        caja.TextSize = 10.5
        caja.TextXAlignment = Enum.TextXAlignment.Center
        caja.ClearTextOnFocus = false
        caja.BorderSizePixel = 0
        caja.Parent = fila
        Utils.Corner(caja, 4)
        AlanLuna:Registrar(caja, "BackgroundColor3", "Entrada")
        AlanLuna:Registrar(caja, "TextColor3", "Highlight")

        local btnMas = Utils.BotonBase({
            Padre = fila, Color = Theme.Entrada, Transparencia = 0.4, Radio = 4,
            Size = UDim2.new(0, ANCHO_BOTON, 0, ALTO_CONTROL),
            Posicion = UDim2.new(1, -(ANCHO_BOTON + 6), 0.5, -ALTO_CONTROL/2),
        })
        AlanLuna:Registrar(btnMas, "BackgroundColor3", "Entrada")
        Utils.Texto({
            Padre = btnMas, Texto = "+", Size = UDim2.new(1, 0, 1, 0),
            Alineacion = Enum.TextXAlignment.Center, Fuente = Enum.Font.GothamBold, Tamano = 12,
        })

        local function aplicarCambio(signo)
            local nuevo = redondear(valor + signo * incremento)
            if nuevo == valor then return end
            valor = nuevo
            AlanLuna.Flags[flag] = valor
            caja.Text = formatear(valor)
            if cfg.Callback then ejecutarConFallback(cfg.Callback, cfg.Texto or "control", valor) end
        end

        local idPresion = 0
        local function iniciarPresion(signo, btnRef)
            idPresion = idPresion + 1
            local miId = idPresion
            aplicarCambio(signo)
            task.spawn(function()
                task.wait(0.4)
                while idPresion == miId and btnRef.Parent do
                    aplicarCambio(signo)
                    task.wait(0.1)
                end
            end)
        end
        local function detenerPresion() idPresion = idPresion + 1 end

        AlanLuna:RegistrarConexion(btnMenos.MouseButton1Down:Connect(function() iniciarPresion(-1, btnMenos) end))
        AlanLuna:RegistrarConexion(btnMenos.MouseButton1Up:Connect(detenerPresion))
        AlanLuna:RegistrarConexion(btnMenos.MouseLeave:Connect(detenerPresion))

        AlanLuna:RegistrarConexion(btnMas.MouseButton1Down:Connect(function() iniciarPresion(1, btnMas) end))
        AlanLuna:RegistrarConexion(btnMas.MouseButton1Up:Connect(detenerPresion))
        AlanLuna:RegistrarConexion(btnMas.MouseLeave:Connect(detenerPresion))

        caja.FocusLost:Connect(function(enterPressed)
            if not enterPressed then return end
            local txt = quitarAfijos(caja.Text)
            local num = tonumber(txt)
            if not num then
                caja.Text = formatear(valor)
                Utils.FlashFeedback(caja, false, Theme.Entrada)
                return
            end
            local nuevo = redondear(num)
            valor = nuevo
            AlanLuna.Flags[flag] = valor
            caja.Text = formatear(valor)
            Utils.FlashFeedback(caja, true, Theme.Entrada)
            if cfg.Callback then ejecutarConFallback(cfg.Callback, cfg.Texto or "control", valor) end
        end)

        local elemObj = {
            Set = function(v, dispararCallback)
                if type(v) ~= "number" then return end
                valor = redondear(v)
                AlanLuna.Flags[flag] = valor
                caja.Text = formatear(valor)
                if dispararCallback and cfg.Callback then
                    ejecutarConFallback(cfg.Callback, cfg.Texto or "control", valor)
                end
            end,
            Get = function() return valor end,
        }
        AlanLuna.Elementos[flag] = elemObj
        AlanLuna.Options[flag] = elemObj

        return {
            Set = function(...) elemObj.Set(normalizarArgSet(...), true) end,
            Get = function() return valor end,
        }
    end

    function Seccion:Input(cfg)
        cfg = cfg or {}
        validarCallback("Input", cfg)
        local flag  = cfg.Flag or cfg.Texto or cfg.Name or ("Input_" .. tostring(math.random(1e5, 1e6)))
        local valor = cfg.CurrentValue or cfg.Defecto or ""
        AlanLuna.Flags[flag] = valor

        local esArea = cfg.Tipo == "textarea"
        local altoArea = math.clamp(cfg.Alto or 70, 45, 300)
        local destino = self:_ObtenerContenedorDestino("Input", cfg)

        local fila, lblInput
        if esArea then
            fila, lblInput = crearCabecera(26, cfg.Texto or cfg.Name or "Input", nil, nil, "manual", destino)
            lblInput.AutomaticSize = Enum.AutomaticSize.Y
            lblInput.Size = UDim2.new(1, -16, 0, 0)
            lblInput.Position = UDim2.new(0, 6, 0, 6)
        else
            fila, lblInput = crearCabecera(26, cfg.Texto or cfg.Name or "Input", 0.45, nil, nil, destino)
        end

        agregarTooltipTexto(fila, cfg.Texto or cfg.Name or "Input", cfg.Tooltip or cfg.Description, lblInput)
        registrarBuscable(fila, cfg.Texto or cfg.Name or "Input", cfg.VisibleSi)

        local caja = Instance.new("TextBox")
        caja.Size             = UDim2.new(0.5, -10, 0, 20)
        caja.Position         = UDim2.new(0.5, 2, 0.5, -10)
        caja.BackgroundColor3 = Theme.Entrada
        caja.BackgroundTransparency = 0.4
        caja.Text             = tostring(valor)
        caja.PlaceholderText  = cfg.Placeholder or cfg.PlaceholderText or ""
        caja.TextColor3       = Theme.Highlight
        caja.Font             = Enum.Font.Gotham
        caja.TextSize         = 11
        caja.ClearTextOnFocus = (cfg.ClearTextOnFocus or cfg.RemoveTextAfterFocusLost) or false
        caja.BorderSizePixel  = 0
        caja.Parent           = fila
        Utils.Corner(caja, 4)
        AlanLuna:Registrar(caja, "BackgroundColor3", "Entrada")
        AlanLuna:Registrar(caja, "TextColor3", "Highlight")

        if esArea then
            caja.Size             = UDim2.new(1, -12, 0, altoArea)
            caja.Position         = UDim2.new(0, 6, 0, 24)
            caja.MultiLine        = true
            caja.TextWrapped      = true
            caja.TextXAlignment   = Enum.TextXAlignment.Left
            caja.TextYAlignment   = Enum.TextYAlignment.Top
            local padArea = Instance.new("UIPadding")
            padArea.PaddingLeft, padArea.PaddingRight = UDim.new(0, 6), UDim.new(0, 6)
            padArea.PaddingTop, padArea.PaddingBottom = UDim.new(0, 4), UDim.new(0, 4)
            padArea.Parent = caja

            fila.Size = UDim2.new(1, 0, 0, altoArea + 30)
        end

        local maxCaracteres = cfg.MaxCharacters or cfg.MaxCaracteres or (esArea and 2000 or 200)

        caja:GetPropertyChangedSignal("Text"):Connect(function()
            if cfg.Numeric then
                local txt = caja.Text
                if not tonumber(txt) and txt ~= "." and txt ~= "" then
                    caja.Text = txt:match("[0-9.]*") or ""
                end
            end
            if #caja.Text > maxCaracteres then
                caja.Text = caja.Text:sub(1, maxCaracteres)
                Utils.FlashFeedback(caja, false, Theme.Entrada)
            end
            if not cfg.Enter and not esArea then
                valor = caja.Text
                AlanLuna.Flags[flag] = valor
                if cfg.Callback then ejecutarConFallback(cfg.Callback, cfg.Texto or "Input", valor) end
            end
        end)

        caja.FocusLost:Connect(function(enterPressed)
            local textoLimpio = caja.Text:gsub("^%s+", ""):gsub("%s+$", "")
            local valorFinal = textoLimpio

            if cfg.Tipo == "number" or cfg.Numeric then
                local n = tonumber(textoLimpio)
                if not n and textoLimpio ~= "" then
                    caja.Text = tostring(valor)
                    Utils.FlashFeedback(caja, false, Theme.Entrada)
                    return
                elseif n then
                    if cfg.Min and n < cfg.Min then n = cfg.Min end
                    if cfg.Max and n > cfg.Max then n = cfg.Max end
                    valorFinal = n
                end
            elseif cfg.Tipo == "pattern" and cfg.Regex then
                local patronLimpio = cfg.Regex:gsub("^%^", ""):gsub("%$$", "")
                if not textoLimpio:match("^" .. patronLimpio .. "$") then
                    caja.Text = tostring(valor)
                    Utils.FlashFeedback(caja, false, Theme.Entrada)
                    return
                end
            end

            valor = valorFinal
            caja.Text = tostring(valorFinal)
            AlanLuna.Flags[flag] = valor
            if (enterPressed or esArea or cfg.Enter) and cfg.Callback then
                ejecutarConFallback(cfg.Callback, cfg.Texto or "Input", valor)
            end
        end)

        local elemObj = {
            Set = function(v, dispararCallback)
                valor = v
                caja.Text = tostring(v)
                AlanLuna.Flags[flag] = v
                if dispararCallback and cfg.Callback then
                    ejecutarConFallback(cfg.Callback, cfg.Texto or "Input", v)
                end
            end,
            Get = function() return valor end,
            CurrentValue = valor,
        }
        AlanLuna.Elementos[flag] = elemObj
        AlanLuna.Options[flag] = elemObj

        return {
            Set = function(...) elemObj.Set(normalizarArgSet(...), true) end,
            Get = function() return valor end,
            CurrentValue = valor,
        }
    end

    function Seccion:TagInput(cfg)
        cfg = cfg or {}
        validarCallback("TagInput", cfg)
        local flag          = cfg.Flag or cfg.Texto or ("TagInput_" .. tostring(math.random(1e5, 1e6)))
        local maxCaracteres = cfg.MaxCaracteres or 200
        local maxTags       = cfg.MaxTags

        local tags = {}
        local tagsLower = {}
        for _, t in ipairs(cfg.Defecto or {}) do
            if type(t) == "string" then
                local limpio = t:gsub("^%s+", ""):gsub("%s+$", "")
                if limpio ~= "" and not tagsLower[limpio:lower()] then
                    table.insert(tags, limpio)
                    tagsLower[limpio:lower()] = true
                end
            end
        end

        local function flagActual()
            local copia = {}
            for i, t in ipairs(tags) do copia[i] = t end
            return copia
        end
        AlanLuna.Flags[flag] = flagActual()

        local destino = self:_ObtenerContenedorDestino("TagInput", cfg)
        local fila = Utils.Fila(destino, 56, siguienteOrden(), Theme.Fila)
        AlanLuna:Registrar(fila, "BackgroundColor3", "Fila")
        Utils.Hover(fila, fila)
        registrarBuscable(fila, cfg.Texto or "TagInput", cfg.VisibleSi)

        local lblTitulo = Utils.Texto({
            Padre = fila, Texto = cfg.Texto or "TagInput",
            Size = UDim2.new(1, -12, 0, 16), Posicion = UDim2.new(0, 6, 0, 4),
            Truncar = true, Tamano = 11,
        })
        agregarTooltipTexto(fila, cfg.Texto or "TagInput", cfg.Tooltip, lblTitulo)

        local contenedorChips = Utils.Frame({
            Padre = fila, Size = UDim2.new(1, -12, 0, 0),
            Posicion = UDim2.new(0, 6, 0, 22), Transparencia = 1,
            Radio = false, Borde = false,
        })
        local layoutChips = Instance.new("UIListLayout")
        layoutChips.FillDirection = Enum.FillDirection.Horizontal
        layoutChips.Wraps = true
        layoutChips.Padding = UDim.new(0, 4)
        layoutChips.Parent = contenedorChips

        local caja = Instance.new("TextBox")
        caja.Size             = UDim2.new(1, -12, 0, 22)
        caja.Position         = UDim2.new(0, 6, 0, 26)
        caja.BackgroundColor3 = Theme.Entrada
        caja.BackgroundTransparency = 0.4
        caja.PlaceholderText  = cfg.Placeholder or "Escribe y pulsa Enter..."
        caja.Text             = ""
        caja.TextColor3       = Theme.Highlight
        caja.Font             = Enum.Font.Gotham
        caja.TextSize         = 10.5
        caja.ClearTextOnFocus = false
        caja.BorderSizePixel  = 0
        caja.Parent           = fila
        Utils.Corner(caja, 4)
        AlanLuna:Registrar(caja, "BackgroundColor3", "Entrada")
        AlanLuna:Registrar(caja, "TextColor3", "Highlight")

        local dibujarChips

        local function agregarUnTag(crudo)
            local limpio = crudo:gsub("^%s+", ""):gsub("%s+$", "")
            if limpio == "" then return false end
            if tagsLower[limpio:lower()] then return false end
            if maxTags and #tags >= maxTags then
                Utils.FlashFeedback(caja, false, Theme.Entrada)
                return false
            end
            table.insert(tags, limpio)
            tagsLower[limpio:lower()] = true
            return true
        end

        local function commitCaja()
            local huboCambio = false
            for frag in (caja.Text .. ","):gmatch("([^,]*),") do
                if agregarUnTag(frag) then huboCambio = true end
            end
            if huboCambio then
                AlanLuna.Flags[flag] = flagActual()
                dibujarChips()
                if cfg.Callback then ejecutarConFallback(cfg.Callback, cfg.Texto or "control", flagActual()) end
            end
            caja.Text = ""
        end

        caja.FocusLost:Connect(commitCaja)

        local function reLayoutChips()
            if not (fila and fila.Parent) then return end
            local e = Utils.FactorEscalaUI(fila)
            local altoChips = (#tags > 0) and math.ceil(layoutChips.AbsoluteContentSize.Y / e) or 0
            contenedorChips.Size = UDim2.new(1, -12, 0, altoChips)
            local yCaja = 22 + altoChips + (altoChips > 0 and 5 or 3)
            caja.Position = UDim2.new(0, 6, 0, yCaja)
            fila.Size = UDim2.new(1, 0, 0, yCaja + 22 + 6)
        end
        AlanLuna:RegistrarConexion(layoutChips:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(Utils.Diferir(reLayoutChips)))

        dibujarChips = function()
            for _, hijo in ipairs(contenedorChips:GetChildren()) do
                if hijo:IsA("Frame") then hijo:Destroy() end
            end
            for i, t in ipairs(tags) do
                local anchoT = math.ceil(TextService:GetTextSize(t, 10.5, Enum.Font.GothamBold, Vector2.new(1000, 20)).X)
                local chip = Utils.Frame({
                    Padre = contenedorChips,
                    Size = UDim2.new(0, anchoT + 26, 0, 18),
                    Color = Theme.Accent, Radio = 9, Transparencia = 0.2,
                })
                AlanLuna:Registrar(chip, "BackgroundColor3", "Accent")
                Utils.GradienteAcento(chip)

                Utils.Texto({
                    Padre = chip, Texto = t, Size = UDim2.new(0, anchoT, 1, 0),
                    Posicion = UDim2.new(0, 6, 0, 0), Tamano = 10, Fuente = Enum.Font.GothamBold,
                    Color = Color3.fromRGB(255, 255, 255),
                })
                local btnX = Instance.new("TextButton")
                btnX.BackgroundTransparency = 1
                btnX.Text = "×"
                btnX.Font = Enum.Font.GothamBold
                btnX.TextSize = 13
                btnX.TextColor3 = Color3.fromRGB(255, 255, 255)
                btnX.Size = UDim2.new(0, 14, 1, 0)
                btnX.Position = UDim2.new(1, -16, 0, 0)
                btnX.Parent = chip
                btnX.MouseButton1Click:Connect(function()
                    table.remove(tags, i)
                    tagsLower[t:lower()] = nil
                    AlanLuna.Flags[flag] = flagActual()
                    dibujarChips()
                    if cfg.Callback then ejecutarConFallback(cfg.Callback, cfg.Texto or "control", flagActual()) end
                end)
            end
            task.defer(reLayoutChips)
        end
        dibujarChips()

        local elemObj = {
            Set = function(v, dispararCallback)
                if type(v) ~= "table" then return end
                tags = {}
                tagsLower = {}
                for _, t in ipairs(v) do
                    if type(t) == "string" and not tagsLower[t:lower()] then
                        table.insert(tags, t)
                        tagsLower[t:lower()] = true
                    end
                end
                AlanLuna.Flags[flag] = flagActual()
                dibujarChips()
                if dispararCallback and cfg.Callback then
                    ejecutarConFallback(cfg.Callback, cfg.Texto or "control", flagActual())
                end
            end,
            Get = function() return flagActual() end,
        }
        AlanLuna.Elementos[flag] = elemObj
        AlanLuna.Options[flag] = elemObj

        return {
            Set = function(...) elemObj.Set(normalizarArgSet(...), true) end,
            Get = function() return flagActual() end,
        }
    end

    function Seccion:RadioGroup(cfg)
        cfg = cfg or {}
        validarCallback("RadioGroup", cfg)
        local flag     = cfg.Flag or cfg.Texto or ("RadioGroup_" .. tostring(math.random(1e5, 1e6)))
        local opciones = cfg.Opciones or {}
        local valor    = cfg.Defecto or opciones[1]
        AlanLuna.Flags[flag] = valor

        local destino = self:_ObtenerContenedorDestino("RadioGroup", cfg)
        local fila, lbl = crearCabecera(50, cfg.Texto or "RadioGroup", nil, nil, "manual", destino)
        lbl.AutomaticSize = Enum.AutomaticSize.Y
        lbl.Size = UDim2.new(1, -16, 0, 0)
        lbl.Position = UDim2.new(0, 6, 0, 6)
        agregarTooltipTexto(fila, cfg.Texto or "RadioGroup", cfg.Tooltip, lbl)
        registrarBuscable(fila, cfg.Texto or "RadioGroup", cfg.VisibleSi)

        local filaBotones = Utils.Frame({
            Padre = fila, Size = UDim2.new(1, -12, 0, 22),
            Posicion = UDim2.new(0, 6, 0, 24), Transparencia = 1,
            Radio = false, Borde = false,
        })
        local layoutBotones = Instance.new("UIListLayout")
        layoutBotones.FillDirection = Enum.FillDirection.Horizontal
        layoutBotones.Padding       = UDim.new(0, 4)
        layoutBotones.Parent        = filaBotones

        local botonesOp = {}
        local function refrescarVisual()
            for opcion, btn in pairs(botonesOp) do
                local activo = (opcion == valor)
                Utils.Tween(btn, {
                    BackgroundColor3 = activo and Theme.Accent or Theme.Entrada,
                    BackgroundTransparency = activo and 0.2 or 0.5,
                }, AlanLuna.Motion.Hover)
                local lblBtn = btn:FindFirstChildOfClass("TextLabel")
                if lblBtn then lblBtn.TextColor3 = activo and Theme.Text or Theme.TextDark end
            end
        end

        local function elegir(opcion)
            if opcion == valor then return end
            valor = opcion
            AlanLuna.Flags[flag] = valor
            refrescarVisual()
            if cfg.Callback then ejecutarConFallback(cfg.Callback, cfg.Texto or "RadioGroup", valor) end
        end

        for i, opcion in ipairs(opciones) do
            local activo = (opcion == valor)
            local btn = Utils.BotonBase({
                Padre = filaBotones,
                Size = UDim2.new(1 / math.max(#opciones, 1), -math.floor(4 * (#opciones - 1) / #opciones), 1, 0),
                Color = activo and Theme.Accent or Theme.Entrada,
                Transparencia = activo and 0.2 or 0.5, Radio = 5, Orden = i,
            })
            AlanLuna:Registrar(btn, "BackgroundColor3", function()
                return (opcion == valor) and Theme.Accent or Theme.Entrada
            end)
            local lblBtn = Utils.Texto({
                Padre = btn, Texto = tostring(opcion), Size = UDim2.new(1, 0, 1, 0),
                Alineacion = Enum.TextXAlignment.Center, Tamano = 10.5, Truncar = true,
                Color = activo and Theme.Text or Theme.TextDark,
            })
            Utils.ClickConfiable(btn, function() elegir(opcion) end)
            botonesOp[opcion] = btn
        end

        local elemObj = {
            Set = function(v, dispararCallback)
                valor = v
                AlanLuna.Flags[flag] = v
                refrescarVisual()
                if dispararCallback and cfg.Callback then
                    ejecutarConFallback(cfg.Callback, cfg.Texto or "RadioGroup", v)
                end
            end,
            Get = function() return valor end,
        }
        AlanLuna.Elementos[flag] = elemObj
        AlanLuna.Options[flag] = elemObj

        return {
            Set = function(...) elemObj.Set(normalizarArgSet(...), true) end,
            Get = function() return valor end,
        }
    end

    function Seccion:Dropdown(cfg)
        cfg = cfg or {}
        validarCallback("Dropdown", cfg)
        local flag     = cfg.Flag or cfg.Texto or cfg.Name or ("Dropdown_" .. tostring(math.random(1e5, 1e6)))
        local opciones = cfg.Options or cfg.Opciones or {}
        local multi    = cfg.MultipleOptions or cfg.Multi or false
        local seleccion = {}

        if multi then
            local def = cfg.CurrentOption or cfg.Defecto or {}
            if type(def) == "table" then
                for _, v in ipairs(def) do seleccion[v] = true end
            elseif type(def) == "string" then
                seleccion[def] = true
            end
        else
            local def = cfg.CurrentOption or cfg.Defecto
            if type(def) == "table" then def = def[1] end
            if def then seleccion[def] = true end
        end

        AlanLuna.Flags[flag] = multi and clonarTabla(seleccion) or (cfg.CurrentOption or cfg.Defecto)

        local UMBRAL_BUSQUEDA = 8
        local conBusqueda     = #opciones > UMBRAL_BUSQUEDA
        local ALTO_FILA       = 26
        local ALTO_BUSQUEDA   = conBusqueda and 22 or 0

        local destino = self:_ObtenerContenedorDestino("Dropdown", cfg)
        local marco = Utils.Frame({
            Padre = destino, Size = UDim2.new(1, 0, 0, ALTO_FILA),
            Color = Theme.Fila, Orden = siguienteOrden(), Recortar = true,
            Transparencia = 0.5,
        })
        AlanLuna:Registrar(marco, "BackgroundColor3", "Fila")
        registrarBuscable(marco, cfg.Texto or cfg.Name or "Dropdown", cfg.VisibleSi)

        local cabecera = Utils.BotonBase({Padre = marco, Size = UDim2.new(1, 0, 0, ALTO_FILA)})
        Utils.Hover(cabecera, marco)

        local lbl = Utils.Texto({
            Padre = marco, Size = UDim2.new(1, -26, 0, ALTO_FILA),
            Truncar = true, Tamano = 11,
        })
        local flecha = Instance.new("ImageLabel")
        flecha.BackgroundTransparency = 1
        flecha.Image = "rbxassetid://83472139709682"
        flecha.Size = UDim2.new(0, 9, 0, 9)
        flecha.AnchorPoint = Vector2.new(0.5, 0.5)
        flecha.Position = UDim2.new(1, -12, 0.5, 0)
        flecha.Parent = marco
        AlanLuna:Registrar(flecha, "ImageColor3", "Text")

        agregarTooltipTexto(marco, cfg.Texto or cfg.Name or "Dropdown", cfg.Tooltip or cfg.Description, lbl)

        local searchBox = nil
        if conBusqueda then
            searchBox = Instance.new("TextBox")
            searchBox.Size             = UDim2.new(1, -8, 0, ALTO_BUSQUEDA - 2)
            searchBox.Position         = UDim2.new(0, 4, 0, ALTO_FILA + 2)
            searchBox.BackgroundColor3 = Theme.Entrada
            searchBox.BackgroundTransparency = 0.4
            searchBox.PlaceholderText  = "🔍 Buscar opción..."
            searchBox.Text             = ""
            searchBox.TextColor3       = Theme.Text
            searchBox.Font             = Enum.Font.Gotham
            searchBox.TextSize         = 10
            searchBox.BorderSizePixel  = 0
            searchBox.ClearTextOnFocus = false
            searchBox.Parent           = marco
            Utils.Corner(searchBox, 4)
            AlanLuna:Registrar(searchBox, "BackgroundColor3", "Entrada")
            AlanLuna:Registrar(searchBox, "TextColor3", "Text")
        end

        local listaOp = Utils.Frame({
            Padre = marco, Size = UDim2.new(1, 0, 0, #opciones * 22),
            Posicion = UDim2.new(0, 0, 0, ALTO_FILA + ALTO_BUSQUEDA + 2),
            Transparencia = 1, Radio = false, Borde = false,
        })
        local layoutOp = Instance.new("UIListLayout")
        layoutOp.Padding = UDim.new(0, 2)
        layoutOp.SortOrder = Enum.SortOrder.LayoutOrder
        layoutOp.Parent = listaOp

        local function valorMostrado()
            if multi then
                local nombres = {}
                for _, o in ipairs(opciones) do
                    if seleccion[o] then table.insert(nombres, o) end
                end
                return #nombres > 0 and table.concat(nombres, ", ") or "Ninguno"
            end
            for k, v in pairs(seleccion) do if v then return k end end
            return "Ninguno"
        end

        local function actualizarLabel()
            lbl.Text = (cfg.Texto or cfg.Name or "Dropdown") .. ": " .. valorMostrado()
        end
        actualizarLabel()

        local botonesOp = {}
        local alternar

        local function elegir(opcion, sinCerrar)
            if multi then
                seleccion[opcion] = not seleccion[opcion] or nil
            else
                seleccion = {[opcion] = true}
            end
            local res = multi and clonarTabla(seleccion) or opcion
            AlanLuna.Flags[flag] = res
            for op, btn in pairs(botonesOp) do
                btn.BackgroundColor3 = seleccion[op] and Theme.Accent or Theme.Entrada
                btn.BackgroundTransparency = seleccion[op] and 0.2 or 0.5
            end
            actualizarLabel()
            if cfg.Callback then ejecutarConFallback(cfg.Callback, cfg.Texto or "Dropdown", res) end
            if not multi and not sinCerrar and alternar then alternar() end
        end

        for i, op in ipairs(opciones) do
            local btn = Utils.BotonBase({
                Padre = listaOp, Size = UDim2.new(1, -8, 0, 20),
                Posicion = UDim2.new(0, 4, 0, 0),
                Color = seleccion[op] and Theme.Accent or Theme.Entrada,
                Transparencia = seleccion[op] and 0.2 or 0.5,
                Orden = i, Radio = 4,
            })
            AlanLuna:Registrar(btn, "BackgroundColor3", function()
                return seleccion[op] and Theme.Accent or Theme.Entrada
            end)
            Utils.Texto({
                Padre = btn, Texto = tostring(op), Size = UDim2.new(1, -8, 1, 0),
                Posicion = UDim2.new(0, 6, 0, 0), Tamano = 10.5, Truncar = true,
            })
            Utils.ClickConfiable(btn, function() elegir(op) end)
            botonesOp[op] = btn
        end

        alternar = hacerExpandible(marco, ALTO_FILA, function()
            local n = #opciones
            return ALTO_FILA + ALTO_BUSQUEDA + (n * 22) + 6
        end)

        Utils.ClickConfiable(cabecera, function()
            local ab = alternar()
            Utils.Tween(flecha, {Rotation = ab and 180 or 0}, AlanLuna.Motion.Expand)
            if searchBox then searchBox.Visible = ab end
        end)

        if searchBox then
            searchBox:GetPropertyChangedSignal("Text"):Connect(function()
                local t = searchBox.Text:lower()
                for op, btn in pairs(botonesOp) do
                    btn.Visible = (t == "") or (op:lower():find(t, 1, true) ~= nil)
                end
            end)
        end

        local function obtenerValor()
            if multi then return clonarTabla(seleccion) end
            for k, v in pairs(seleccion) do if v then return k end end
            return nil
        end

        local elemObj = {
            Set = function(v, dispararCallback)
                if multi then
                    seleccion = (type(v) == "table" and clonarTabla(v)) or {[v] = true}
                else
                    seleccion = {[v] = true}
                end
                for op, btn in pairs(botonesOp) do
                    btn.BackgroundColor3 = seleccion[op] and Theme.Accent or Theme.Entrada
                    btn.BackgroundTransparency = seleccion[op] and 0.2 or 0.5
                end
                actualizarLabel()
                AlanLuna.Flags[flag] = multi and clonarTabla(seleccion) or v
                if dispararCallback and cfg.Callback then
                    ejecutarConFallback(cfg.Callback, cfg.Texto or "Dropdown", AlanLuna.Flags[flag])
                end
            end,
            Get = obtenerValor,
            CurrentOption = multi and clonarTabla(seleccion) or (cfg.CurrentOption or cfg.Defecto),
        }
        AlanLuna.Elementos[flag] = elemObj
        AlanLuna.Options[flag] = elemObj

        return {
            Set = function(...) elemObj.Set(normalizarArgSet(...), true) end,
            Get = obtenerValor,
            CurrentOption = elemObj.CurrentOption,
        }
    end

    function Seccion:ColorPicker(cfg)
        cfg = cfg or {}
        validarCallback("ColorPicker", cfg)
        local flag        = cfg.Flag or cfg.Texto or cfg.Name or ("Color_" .. tostring(math.random(1e5, 1e6)))
        local colorActual = cfg.Color or cfg.Defecto or Color3.fromRGB(255, 255, 255)
        AlanLuna.Flags[flag] = colorActual

        local ALTO_FILA = 26
        local destino = self:_ObtenerContenedorDestino("ColorPicker", cfg)
        local marco = Utils.Frame({
            Padre = destino, Size = UDim2.new(1, 0, 0, ALTO_FILA),
            Color = Theme.Fila, Orden = siguienteOrden(), Recortar = true,
            Transparencia = 0.5,
        })
        AlanLuna:Registrar(marco, "BackgroundColor3", "Fila")

        local cabecera = Utils.BotonBase({Padre = marco, Size = UDim2.new(1, 0, 0, ALTO_FILA)})
        Utils.Hover(cabecera, marco)

        local lbl = Utils.Texto({
            Padre = marco, Texto = cfg.Texto or cfg.Name or "Color",
            Size = UDim2.new(1, -44, 0, ALTO_FILA), Truncar = true, Tamano = 11,
        })
        local muestra = Utils.Frame({
            Padre = marco, Size = UDim2.new(0, 24, 0, 14),
            Posicion = UDim2.new(1, -30, 0.5, -7),
            Color = colorActual, Radio = 3, Transparencia = 0,
        })

        agregarTooltipTexto(marco, cfg.Texto or cfg.Name or "Color", cfg.Tooltip, lbl, -44)
        registrarBuscable(marco, cfg.Texto or cfg.Name or "Color", cfg.VisibleSi)

        local panel = Utils.Frame({
            Padre = marco, Size = UDim2.new(1, -12, 0, 105),
            Posicion = UDim2.new(0, 6, 0, ALTO_FILA + 2), Transparencia = 1,
            Radio = false, Borde = false,
        })
        local layoutP = Instance.new("UIListLayout")
        layoutP.Padding = UDim.new(0, 4)
        layoutP.Parent = panel

        local r = colorActual.R * 255
        local g = colorActual.G * 255
        local b = colorActual.B * 255
        local fijarVisualR, fijarVisualG, fijarVisualB
        local hexBox = nil

        local function aHex(c)
            return string.format("#%02X%02X%02X", math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5))
        end

        local function actualizarColor()
            local nuevo = Color3.fromRGB(math.floor(r + 0.5), math.floor(g + 0.5), math.floor(b + 0.5))
            colorActual = nuevo
            muestra.BackgroundColor3 = nuevo
            if hexBox then hexBox.Text = aHex(nuevo) end
            AlanLuna.Flags[flag] = nuevo
            if cfg.Callback then ejecutarConFallback(cfg.Callback, cfg.Texto or "ColorPicker", nuevo) end
        end

        local function canalRGB(nombreCanal, ordenC, getV, setV)
            local filaC = Utils.Frame({
                Padre = panel, Size = UDim2.new(1, 0, 0, 18),
                Orden = ordenC, Transparencia = 1, Radio = false, Borde = false,
            })
            Utils.Texto({
                Padre = filaC, Texto = nombreCanal, Size = UDim2.new(0, 14, 1, 0),
                Fuente = Enum.Font.GothamBold, Tamano = 9.5,
            })
            local _, _, fv = crearBarraArrastrable({
                Padre = filaC, Size = UDim2.new(1, -16, 0, 6),
                Posicion = UDim2.new(0, 16, 0.5, -3),
                Min = 0, Max = 255, Valor = getV(),
                OnCambio = function(v) setV(v); actualizarColor() end,
            })
            return fv
        end

        fijarVisualR = canalRGB("R", 1, function() return r end, function(v) r = v end)
        fijarVisualG = canalRGB("G", 2, function() return g end, function(v) g = v end)
        fijarVisualB = canalRGB("B", 3, function() return b end, function(v) b = v end)

        local filaHex = Utils.Frame({
            Padre = panel, Size = UDim2.new(1, 0, 0, 18),
            Orden = 4, Transparencia = 1, Radio = false, Borde = false,
        })
        Utils.Texto({
            Padre = filaHex, Texto = "Hex", Size = UDim2.new(0, 24, 1, 0),
            Fuente = Enum.Font.GothamBold, Tamano = 9.5,
        })
        hexBox = Instance.new("TextBox")
        hexBox.Size = UDim2.new(1, -26, 1, 0)
        hexBox.Position = UDim2.new(0, 26, 0, 0)
        hexBox.BackgroundColor3 = Theme.Entrada
        hexBox.BackgroundTransparency = 0.4
        hexBox.BorderSizePixel = 0
        hexBox.Font = Enum.Font.Code
        hexBox.TextSize = 10.5
        hexBox.TextColor3 = Theme.Text
        hexBox.Text = aHex(colorActual)
        hexBox.ClearTextOnFocus = false
        hexBox.Parent = filaHex
        Utils.Corner(hexBox, 3)
        AlanLuna:Registrar(hexBox, "BackgroundColor3", "Entrada")
        AlanLuna:Registrar(hexBox, "TextColor3", "Text")

        hexBox.FocusLost:Connect(function()
            local limpio = hexBox.Text:gsub("^#", ""):gsub("%s", "")
            if #limpio == 6 and not limpio:match("%X") then
                r = tonumber(limpio:sub(1,2), 16)
                g = tonumber(limpio:sub(3,4), 16)
                b = tonumber(limpio:sub(5,6), 16)
                fijarVisualR(r); fijarVisualG(g); fijarVisualB(b)
                actualizarColor()
                Utils.FlashFeedback(hexBox, true, Theme.Entrada)
            else
                hexBox.Text = aHex(colorActual)
                Utils.FlashFeedback(hexBox, false, Theme.Entrada)
            end
        end)

        local alternar = hacerExpandible(marco, ALTO_FILA, function() return ALTO_FILA + 112 end)
        Utils.ClickConfiable(cabecera, function() alternar() end)

        local elemObj = {
            Set = function(v, dispararCallback)
                if typeof(v) ~= "Color3" then return end
                colorActual = v
                r = v.R * 255; g = v.G * 255; b = v.B * 255
                muestra.BackgroundColor3 = v
                if hexBox then hexBox.Text = aHex(v) end
                AlanLuna.Flags[flag] = v
                fijarVisualR(r); fijarVisualG(g); fijarVisualB(b)
                if dispararCallback and cfg.Callback then
                    ejecutarConFallback(cfg.Callback, cfg.Texto or "ColorPicker", v)
                end
            end,
            Get = function() return colorActual end,
            Color = colorActual,
        }
        AlanLuna.Elementos[flag] = elemObj
        AlanLuna.Options[flag] = elemObj

        return {
            Set = function(...) elemObj.Set(normalizarArgSet(...), true) end,
            Get = function() return colorActual end,
            Color = colorActual,
        }
    end

    function Seccion:Keybind(cfg)
        cfg = cfg or {}
        validarCallback("Keybind", cfg)
        local flag     = cfg.Flag or cfg.Texto or cfg.Name or ("Keybind_" .. tostring(math.random(1e5, 1e6)))
        local conMods  = cfg.ConModificadores or false
        local defecto  = cfg.CurrentBind or cfg.Defecto or (conMods and {KeyCode = Enum.KeyCode.Unknown} or Enum.KeyCode.Unknown)
        if conMods and typeof(defecto) ~= "table" then
            defecto = {KeyCode = defecto, Ctrl = false, Shift = false, Alt = false}
        end
        local valor = defecto
        local esperando = false
        local conexionCaptura = nil
        local _asignadaEnEsteFrame = false
        AlanLuna.Flags[flag] = valor

        local entryConflicto = { flag = flag, texto = cfg.Texto or cfg.Name or "Keybind" }
        entryConflicto.GetValor = function() return valor end
        table.insert(_keybindsRegistrados, entryConflicto)

        local function textoTecla(v)
            if not conMods then
                return (v == Enum.KeyCode.Unknown) and "Ninguna" or v.Name
            end
            if typeof(v) ~= "table" then v = {KeyCode = v, Ctrl = false, Shift = false, Alt = false} end
            if not v or v.KeyCode == Enum.KeyCode.Unknown then return "Ninguna" end
            local partes = {}
            if v.Ctrl then table.insert(partes, "Ctrl") end
            if v.Shift then table.insert(partes, "Shift") end
            if v.Alt then table.insert(partes, "Alt") end
            table.insert(partes, v.KeyCode.Name)
            return table.concat(partes, "+")
        end

        local destino = self:_ObtenerContenedorDestino("Keybind", cfg)
        local fila, lbl = crearCabecera(26, cfg.Texto or cfg.Name or "Keybind", 1, -64, nil, destino)
        agregarTooltipTexto(fila, cfg.Texto or cfg.Name or "Keybind", cfg.Tooltip or cfg.Description, lbl)
        registrarBuscable(fila, cfg.Texto or cfg.Name or "Keybind", cfg.VisibleSi)

        local btnTecla = Utils.BotonBase({
            Padre = fila, Size = UDim2.new(0, 54, 0, 18),
            Posicion = UDim2.new(1, -58, 0.5, -9),
            Color = Theme.Entrada, Transparencia = 0.4, Radio = 4,
        })
        AlanLuna:Registrar(btnTecla, "BackgroundColor3", "Entrada")
        Utils.Hover(btnTecla, btnTecla)

        local lblTecla = Utils.Texto({
            Padre = btnTecla, Texto = textoTecla(valor),
            Alineacion = Enum.TextXAlignment.Center,
            Color = Theme.Highlight, Tamano = 9.5, Truncar = true,
        })
        AlanLuna:Registrar(lblTecla, "TextColor3", "Highlight")

        local function actualizarTecla(tecla, disparar)
            valor = tecla
            AlanLuna.Flags[flag] = tecla
            lblTecla.Text = textoTecla(tecla)
            if disparar and cfg.Callback then
                ejecutarConFallback(cfg.Callback, cfg.Texto or cfg.Name or "Keybind", tecla)
            end
        end

        AlanLuna:RegistrarConexion(UserInputService.InputBegan:Connect(function(input, procesado)
            if procesado or esperando or _asignadaEnEsteFrame then return end
            local k, c, s, a = _descomponerTecla(valor)
            if k == Enum.KeyCode.Unknown or input.KeyCode ~= k then return end

            if conMods then
                local ctrlA = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl)
                local shiftA = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
                local altA = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
                if ctrlA ~= c or shiftA ~= s or altA ~= a then return end
            end

            if cfg.Callback then
                ejecutarConFallback(cfg.Callback, cfg.Texto or cfg.Name or "Keybind", valor)
            end
        end))

        Utils.ClickConfiable(btnTecla, function()
            if esperando then return end
            esperando = true
            lblTecla.Text = "..."
            btnTecla.BackgroundColor3 = Theme.Accent

            conexionCaptura = UserInputService.InputBegan:Connect(function(input, procesado)
                if procesado or not esperando then return end
                if input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode ~= Enum.KeyCode.Unknown then
                    local esMod = conMods and (
                        input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.RightControl or
                        input.KeyCode == Enum.KeyCode.LeftShift or input.KeyCode == Enum.KeyCode.RightShift or
                        input.KeyCode == Enum.KeyCode.LeftAlt or input.KeyCode == Enum.KeyCode.RightAlt
                    )
                    if esMod then return end

                    esperando = false
                    btnTecla.BackgroundColor3 = Theme.Entrada
                    if conexionCaptura then conexionCaptura:Disconnect(); conexionCaptura = nil end

                    local nuevoValor = conMods and {
                        KeyCode = input.KeyCode,
                        Ctrl = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.RightControl),
                        Shift = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift),
                        Alt = UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt) or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt),
                    } or input.KeyCode

                    _revisarConflictoKeybind(entryConflicto, nuevoValor)
                    _asignadaEnEsteFrame = true
                    task.defer(function() _asignadaEnEsteFrame = false end)
                    actualizarTecla(nuevoValor, false)
                end
            end)
            AlanLuna:RegistrarConexion(conexionCaptura)
        end)

        local elemObj = {
            Set = function(v, dispararCallback) actualizarTecla(v, dispararCallback or false) end,
            Get = function() return valor end,
            CurrentBind = valor,
        }
        AlanLuna.Elementos[flag] = elemObj
        AlanLuna.Options[flag] = elemObj

        return {
            Set = function(...) elemObj.Set(normalizarArgSet(...), true) end,
            Get = function() return valor end,
            CurrentBind = valor,
        }
    end

    function Seccion:Label(cfg)
        cfg = cfg or {}
        local flag  = cfg.Flag or ("Label_" .. tostring(math.random(1e5, 1e6)))
        local valor = tostring(cfg.Valor or "")
        _flagsNoPersistir[flag] = true

        local destino = self:_ObtenerContenedorDestino("Label", cfg)
        local fila, lbl = crearCabecera(26, cfg.Texto or cfg.Text or "Label", 1, -100, nil, destino)
        agregarTooltipTexto(fila, cfg.Texto or "Label", cfg.Tooltip, lbl)
        registrarBuscable(fila, cfg.Texto or "Label", cfg.VisibleSi)

        local lblValor = Utils.Texto({
            Padre = fila, Texto = valor, Size = UDim2.new(0, 90, 1, 0),
            Posicion = UDim2.new(1, -96, 0, 0), Alineacion = Enum.TextXAlignment.Right,
            Color = Theme.AccentLight, Tamano = 10.5, Truncar = true,
        })
        AlanLuna:Registrar(lblValor, "TextColor3", "AccentLight")

        local function fijar(v)
            valor = tostring(v)
            lblValor.Text = valor
            _flagsReales[flag] = v
        end

        _flagsReales[flag] = cfg.Valor
        local elemObj = {
            Set = function(v) fijar(v) end,
            Get = function() return valor end,
        }
        AlanLuna.Elementos[flag] = elemObj

        if cfg.Cada and cfg.Actualizar and type(cfg.Actualizar) == "function" then
            local cada = tonumber(cfg.Cada)
            if cada and cada >= 0.05 then
                _labelsAutoActualizables[lblValor] = {
                    cada = cada, fn = cfg.Actualizar, aplicar = fijar,
                    flag = flag, proxima = os.clock() + cada,
                }
            end
        end

        return {
            Set = function(...) fijar(normalizarArgSet(...)) end,
            SetTexto = function(...) fijar(normalizarArgSet(...)) end,
            Get = function() return valor end,
        }
    end

    function Seccion:Progreso(cfg)
        cfg = cfg or {}
        local flag  = cfg.Flag or ("Progreso_" .. tostring(math.random(1e5, 1e6)))
        local valor = math.clamp(cfg.Defecto or 0, 0, 100)
        _flagsNoPersistir[flag] = true
        _flagsReales[flag] = valor

        local destino = self:_ObtenerContenedorDestino("Progreso", cfg)
        local fila, lbl = crearCabecera(34, cfg.Texto or "Progreso", nil, nil, "fijo", destino)
        lbl.Size = UDim2.new(1, -55, 0, 16)
        lbl.Position = UDim2.new(0, 6, 0, 2)
        agregarTooltipTexto(fila, cfg.Texto or "Progreso", cfg.Tooltip, lbl)
        registrarBuscable(fila, cfg.Texto or "Progreso", cfg.VisibleSi)

        local lblValor = Utils.Texto({
            Padre = fila, Texto = math.floor(valor) .. "%",
            Size = UDim2.new(0, 45, 0, 16), Posicion = UDim2.new(1, -50, 0, 2),
            Alineacion = Enum.TextXAlignment.Right, Color = Theme.AccentLight, Tamano = 10,
        })
        AlanLuna:Registrar(lblValor, "TextColor3", "AccentLight")

        local fondo = Utils.Frame({
            Padre = fila, Size = UDim2.new(1, -12, 0, 5),
            Posicion = UDim2.new(0, 6, 0, 22), Color = Theme.Entrada,
            Radio = 3, Transparencia = 0.4,
        })
        AlanLuna:Registrar(fondo, "BackgroundColor3", "Entrada")

        local relleno = Utils.Frame({
            Padre = fondo, Size = UDim2.new(valor / 100, 0, 1, 0),
            Color = Theme.Accent, Radio = 3, Transparencia = 0, Borde = false,
        })
        AlanLuna:Registrar(relleno, "BackgroundColor3", "Accent")
        Utils.GradienteAcento(relleno)

        local function fijar(v)
            if type(v) ~= "number" then return end
            valor = math.clamp(v, 0, 100)
            Utils.Tween(relleno, {Size = UDim2.new(valor / 100, 0, 1, 0)}, AlanLuna.Motion.Expand)
            lblValor.Text = math.floor(valor + 0.5) .. "%"
            _flagsReales[flag] = valor
        end

        local elemObj = {
            Set = function(v) fijar(v) end,
            Get = function() return valor end,
        }
        AlanLuna.Elementos[flag] = elemObj
        return {
            Set = function(...) fijar(normalizarArgSet(...)) end,
            Get = function() return valor end,
        }
    end

    function Seccion:Parrafo(cfg)
        cfg = cfg or {}
        local destino = self:_ObtenerContenedorDestino("Parrafo", cfg)
        local marco2 = Utils.Frame({
            Padre = destino, Size = UDim2.new(1, 0, 0, 0),
            Color = Theme.Fila, Orden = siguienteOrden(), Radio = 6,
            Transparencia = 0.5,
        })
        marco2.AutomaticSize = Enum.AutomaticSize.Y
        AlanLuna:Registrar(marco2, "BackgroundColor3", "Fila")

        local padP = Instance.new("UIPadding")
        padP.PaddingTop, padP.PaddingBottom = UDim.new(0, 6), UDim.new(0, 6)
        padP.PaddingLeft, padP.PaddingRight = UDim.new(0, 8), UDim.new(0, 8)
        padP.Parent = marco2

        local layoutP = Instance.new("UIListLayout")
        layoutP.Padding = UDim.new(0, 2)
        layoutP.SortOrder = Enum.SortOrder.LayoutOrder
        layoutP.Parent = marco2

        if cfg.Titulo or cfg.Title then
            local lblTit = Utils.Texto({
                Padre = marco2, Texto = cfg.Titulo or cfg.Title,
                Size = UDim2.new(1, 0, 0, 0), Fuente = Enum.Font.GothamBold,
                Tamano = 11, Color = Theme.Highlight, Ajustar = true, Orden = 1,
            })
            lblTit.AutomaticSize = Enum.AutomaticSize.Y
            AlanLuna:Registrar(lblTit, "TextColor3", "Highlight")
        end

        local lblCont = Utils.Texto({
            Padre = marco2, Texto = cfg.Contenido or cfg.Content or cfg.Text or "",
            Size = UDim2.new(1, 0, 0, 0), Tamano = 10.5, Color = Theme.Text,
            Ajustar = true, Orden = 2,
        })
        lblCont.AutomaticSize = Enum.AutomaticSize.Y
        AlanLuna:Registrar(lblCont, "TextColor3", "Text")

        return {
            Instancia = marco2,
            Set = function(...)
                local t = normalizarArgSet(...)
                lblCont.Text = tostring(t)
            end,
        }
    end

    function Seccion:Divider(cfg)
        cfg = cfg or {}
        local destino = self:_ObtenerContenedorDestino("Divider", cfg)
        local fila = Utils.Frame({
            Padre = destino, Size = UDim2.new(1, 0, 0, cfg.Texto and 24 or 12),
            Orden = siguienteOrden(), Transparencia = 1, Radio = false, Borde = false,
        })
        if cfg.Texto then
            Utils.Texto({
                Padre = fila, Texto = tostring(cfg.Texto),
                Size = UDim2.new(1, -12, 0, 14), Posicion = UDim2.new(0, 6, 0, 0),
                Fuente = Enum.Font.GothamBold, Tamano = 9.5, ColorTema = "AccentLight",
            })
        end
        local linea = Utils.Frame({
            Padre = fila, Size = UDim2.new(1, 0, 0, 1.5),
            Posicion = UDim2.new(0, 0, 1, -2), Color = Theme.Accent,
            Radio = false, Borde = false, Transparencia = 0.3,
        })
        AlanLuna:Registrar(linea, "BackgroundColor3", "Accent")
        Utils.GradienteAcento(linea)
        return { Instancia = fila }
    end

    function Seccion:Imagen(cfg)
        cfg = cfg or {}
        local destino = self:_ObtenerContenedorDestino("Imagen", cfg)
        local altoFijo = math.clamp(cfg.Alto or 90, 30, 350)
        local fila = Utils.Frame({
            Padre = destino, Size = UDim2.new(1, 0, 0, altoFijo),
            Transparencia = 1, Orden = siguienteOrden(), Radio = false, Borde = false,
        })
        local img = Instance.new("ImageLabel")
        img.BackgroundColor3 = Theme.Fila
        img.BackgroundTransparency = 0.5
        img.BorderSizePixel = 0
        img.Image = type(cfg.Url) == "string" and cfg.Url or ""
        img.ScaleType = Enum.ScaleType.Fit
        img.Size = UDim2.new(1, 0, 1, 0)
        img.Parent = fila
        Utils.Corner(img, 6)
        AlanLuna:Registrar(img, "BackgroundColor3", "Fila")
        return {
            Set = function(...)
                local u = normalizarArgSet(...)
                if type(u) == "string" then img.Image = u end
            end,
            Get = function() return img.Image end,
            Instancia = img,
        }
    end

    function Seccion:Grupo(cfg)
        cfg = cfg or {}
        local destino = self:_ObtenerContenedorDestino("Grupo", cfg)
        local ALTO_G = 26
        local filaG = Utils.Frame({
            Padre = destino, Size = UDim2.new(1, 0, 0, ALTO_G),
            Transparencia = 1, Orden = siguienteOrden(), Radio = false, Borde = false,
        })
        local layG = Instance.new("UIListLayout")
        layG.FillDirection = Enum.FillDirection.Horizontal
        layG.Padding = UDim.new(0, 6)
        layG.Parent = filaG

        local botonesG = {}
        local grupo = { Instancia = filaG }
        function grupo:Boton(cfgB)
            local btn = Seccion:Boton(cfgB)
            btn.Parent = filaG
            table.insert(botonesG, btn)
            local tot = #botonesG
            for _, b in ipairs(botonesG) do
                b.Size = UDim2.new(1 / tot, -math.ceil(6 * (tot - 1) / tot), 1, 0)
            end
            return btn
        end
        return grupo
    end

    function Seccion:Construir(lista)
        local res = {}
        for i, def in ipairs(lista or {}) do
            local tipoCtrl = def.Control or def.Tipo
            if tipoCtrl and type(self[tipoCtrl]) == "function" then
                local obj = self[tipoCtrl](self, def)
                res[i] = obj
                if def.Flag then res[def.Flag] = obj end
            end
        end
        return res
    end

    for _, n in ipairs({
        "Boton", "Toggle", "Casilla", "Slider", "RangeSlider", "NumberStepper",
        "Input", "TagInput", "Dropdown", "RadioGroup", "ColorPicker", "Keybind",
    }) do
        Utils.EnvolverControlBloqueable(Seccion, Seccion.contenedor, n)
    end
end

local function hookCrearSeccionParaControles()
    local oldCrearVentana = AlanLuna.CrearVentana
    function AlanLuna:CrearVentana(config)
        local Ventana = oldCrearVentana(self, config)

        local oldCrearCategoria = Ventana.CrearCategoria
        function Ventana:CrearCategoria(catCfg)
            local CatObj = oldCrearCategoria(self, catCfg)

            local oldCrearTab = CatObj.CrearTab
            function CatObj:CrearTab(tabCfg)
                local TabObj = oldCrearTab(self, tabCfg)

                local oldCrearSubTab = TabObj.CrearSubTab
                function TabObj:CrearSubTab(subCfg)
                    local SubTabObj = oldCrearSubTab(self, subCfg)

                    local oldCrearSeccion = SubTabObj.CrearSeccion
                    function SubTabObj:CrearSeccion(secNombre, secCfg)
                        local Seccion = oldCrearSeccion(self, secNombre, secCfg)
                        aplicarMetodosControles(Seccion)
                        return Seccion
                    end

                    return SubTabObj
                end

                function TabObj:CrearSeccion(secNombre, secCfg)
                    local subMain = self.SubTabs["Main"] or self:CrearSubTab("Main")
                    return subMain:CrearSeccion(secNombre, secCfg)
                end

                -- Aliases Drop-in de Luna UI sobre Tab
                TabObj.CreateButton      = function(_, c) return TabObj:CrearSeccion(""):Boton(c) end
                TabObj.CreateToggle      = function(_, c, f) if f then c.Flag = f end return TabObj:CrearSeccion(""):Toggle(c) end
                TabObj.CreateSlider      = function(_, c, f) if f then c.Flag = f end return TabObj:CrearSeccion(""):Slider(c) end
                TabObj.CreateInput       = function(_, c, f) if f then c.Flag = f end return TabObj:CrearSeccion(""):Input(c) end
                TabObj.CreateDropdown    = function(_, c, f) if f then c.Flag = f end return TabObj:CrearSeccion(""):Dropdown(c) end
                TabObj.CreateColorPicker = function(_, c, f) if f then c.Flag = f end return TabObj:CrearSeccion(""):ColorPicker(c) end
                TabObj.CreateBind        = function(_, c, f) if f then c.Flag = f end return TabObj:CrearSeccion(""):Keybind(c) end
                TabObj.CreateKeybind     = TabObj.CreateBind
                TabObj.CreateLabel       = function(_, c) return TabObj:CrearSeccion(""):Label(c) end
                TabObj.CreateParagraph   = function(_, c) return TabObj:CrearSeccion(""):Parrafo(c) end
                TabObj.CreateDivider     = function(_) return TabObj:CrearSeccion(""):Divider() end
                TabObj.CreateSection     = function(_, n) return TabObj:CrearSeccion(n) end

                return TabObj
            end

            return CatObj
        end

        return Ventana
    end
end

hookCrearSeccionParaControles()

-- ══════════════════════════════════════════════════════════════
--  SECCION 24: LUNA UI 1:1 CONFIG SECTION & THEME SECTION
-- ══════════════════════════════════════════════════════════════
local ClassParser = {
    ["Toggle"] = {
        Save = function(Flag, data)
            return {
                type = "Toggle",
                flag = Flag,
                state = data.CurrentValue or false
            }
        end,
        Load = function(Flag, data)
            if AlanLuna.Options[Flag] then
                AlanLuna.Options[Flag]:Set(data.state)
            end
        end
    },
    ["Slider"] = {
        Save = function(Flag, data)
            return {
                type = "Slider",
                flag = Flag,
                value = (data.CurrentValue and tostring(data.CurrentValue)),
            }
        end,
        Load = function(Flag, data)
            if AlanLuna.Options[Flag] and data.value then
                AlanLuna.Options[Flag]:Set(tonumber(data.value) or data.value)
            end
        end
    },
    ["Input"] = {
        Save = function(Flag, data)
            return {
                type = "Input",
                flag = Flag,
                text = data.CurrentValue
            }
        end,
        Load = function(Flag, data)
            if AlanLuna.Options[Flag] and data.text and type(data.text) == "string" then
                AlanLuna.Options[Flag]:Set(data.text)
            end
        end
    },
    ["Dropdown"] = {
        Save = function(Flag, data)
            return {
                type = "Dropdown",
                flag = Flag,
                value = data.CurrentOption
            }
        end,
        Load = function(Flag, data)
            if AlanLuna.Options[Flag] and data.value then
                AlanLuna.Options[Flag]:Set(data.value)
            end
        end
    },
    ["Colorpicker"] = {
        Save = function(Flag, data)
            local function Color3ToHex(color)
                return string.format("#%02X%02X%02X", math.floor(color.R * 255), math.floor(color.G * 255), math.floor(color.B * 255))
            end

            return {
                type = "Colorpicker",
                flag = Flag,
                color = Color3ToHex(data.Color) or nil,
                alpha = data.Alpha
            }
        end,
        Load = function(Flag, data)
            local function HexToColor3(hex)
                local r = tonumber(hex:sub(2, 3), 16) / 255
                local g = tonumber(hex:sub(4, 5), 16) / 255
                local b = tonumber(hex:sub(6, 7), 16) / 255
                return Color3.new(r, g, b)
            end

            if AlanLuna.Options[Flag] and data.color then
                AlanLuna.Options[Flag]:Set(HexToColor3(data.color))
            end
        end
    }
}

local function registrarMetodosLunaAvanzados(TabObj)
    function TabObj:BuildConfigSection()
        if isStudio then
            self:CrearSeccion("Configuraciones"):Label({Texto = "Config system unavailable. (Environment isStudio)"})
            return "Config system unavailable."
        end

        local inputPath = nil
        local selectedConfig = nil

        local secCreator = self:CrearSeccion("Config Creator", { Columnas = 1 })

        secCreator:Input({
            Texto = "Config Name",
            Placeholder = "Name",
            Defecto = "",
            Callback = function(input)
                inputPath = input
            end,
        })

        local configSelection

        secCreator:Boton({
            Texto = "Create Config",
            Tooltip = "Create a config with all of your current settings.",
            Callback = function()
                if not inputPath or string.gsub(inputPath, " ", "") == "" then
                    AlanLuna:Notificar({
                        Title = "Interface",
                        Icon = "warning",
                        ImageSource = "Material",
                        Content = "Config name cannot be empty."
                    })
                    return
                end

                local success, returned = AlanLuna.SaveManager:Guardar(inputPath)
                if not success then
                    AlanLuna:Notificar({
                        Title = "Interface",
                        Icon = "warning",
                        ImageSource = "Material",
                        Content = "Unable to save config, return error: " .. tostring(returned)
                    })
                else
                    AlanLuna:Notificar({
                        Title = "Interface",
                        Icon = "info",
                        ImageSource = "Material",
                        Content = string.format("Created config %q", inputPath),
                    })
                end

                if configSelection and configSelection.ActualizarOpciones then
                    configSelection.ActualizarOpciones(AlanLuna.SaveManager:Listar())
                end
            end
        })

        local secSettings = self:CrearSeccion("Config Load/Settings", { Columnas = 1 })

        configSelection = secSettings:Dropdown({
            Texto = "Select Config",
            Tooltip = "Select a config to load your settings on.",
            Opciones = AlanLuna.SaveManager:Listar(),
            Defecto = {},
            Multi = false,
            Callback = function(Value)
                selectedConfig = Value
            end,
        })

        secSettings:Boton({
            Texto = "Load Config",
            Tooltip = "Load your saved config settings.",
            Callback = function()
                if not selectedConfig then return end
                local success, returned = AlanLuna.SaveManager:Cargar(selectedConfig)
                if not success then
                    AlanLuna:Notificar({
                        Title = "Interface",
                        Icon = "warning",
                        ImageSource = "Material",
                        Content = "Unable to load config, return error: " .. tostring(returned)
                    })
                    return
                end

                AlanLuna:Notificar({
                    Title = "Interface",
                    Icon = "info",
                    ImageSource = "Material",
                    Content = string.format("Loaded config %q", selectedConfig),
                })
            end
        })

        secSettings:Boton({
            Texto = "Overwrite Config",
            Tooltip = "Overwrite your current config settings.",
            Callback = function()
                if not selectedConfig then return end
                local success, returned = AlanLuna.SaveManager:Guardar(selectedConfig)
                if not success then
                    AlanLuna:Notificar({
                        Title = "Interface",
                        Icon = "warning",
                        ImageSource = "Material",
                        Content = "Unable to overwrite config, return error: " .. tostring(returned)
                    })
                    return
                end

                AlanLuna:Notificar({
                    Title = "Interface",
                    Icon = "info",
                    ImageSource = "Material",
                    Content = string.format("Overwrote config %q", selectedConfig),
                })
            end
        })

        secSettings:Boton({
            Texto = "Refresh Config List",
            Tooltip = "Refresh the current config list.",
            Callback = function()
                if configSelection and configSelection.ActualizarOpciones then
                    configSelection.ActualizarOpciones(AlanLuna.SaveManager:Listar())
                end
            end,
        })

        local loadlabel
        secSettings:Boton({
            Texto = "Set as autoload",
            Tooltip = "Set a config to auto load setting in your next session.",
            Callback = function()
                if not selectedConfig then return end
                local name = selectedConfig
                writefile(AlanLuna.Folder .. "/autoload.txt", name)
                if loadlabel then
                    loadlabel:Set("Current autoload config: " .. name)
                end

                AlanLuna:Notificar({
                    Title = "Interface",
                    Icon = "info",
                    ImageSource = "Material",
                    Content = string.format("Set %q to auto load", name),
                })
            end,
        })

        loadlabel = secSettings:Parrafo({
            Titulo = "Current Auto Load",
            Contenido = "None"
        })

        secSettings:Boton({
            Texto = "Delete Autoload",
            Tooltip = "Delete The Autoload File",
            Callback = function()
                if isfile(AlanLuna.Folder .. "/autoload.txt") then
                    delfile(AlanLuna.Folder .. "/autoload.txt")
                end
                if loadlabel then
                    loadlabel:Set("None")
                end

                AlanLuna:Notificar({
                    Title = "Interface",
                    Icon = "info",
                    ImageSource = "Material",
                    Content = "Deleted Autoload",
                })
            end,
        })

        if isfile(AlanLuna.Folder .. "/autoload.txt") then
            local name = readfile(AlanLuna.Folder .. "/autoload.txt")
            if loadlabel then
                loadlabel:Set("Current autoload config: " .. name)
            end
        end
    end

    function TabObj:BuildThemeSection()
        local secEditor = self:CrearSeccion("Custom Editor", { Columnas = 1 })

        local c1cp = secEditor:ColorPicker({
            Texto = "Color 1",
            Color = Color3.fromRGB(117, 164, 206),
        }, "LunaInterfaceSuitePrebuiltCPC1")

        local c2cp = secEditor:ColorPicker({
            Texto = "Color 2",
            Color = Color3.fromRGB(123, 201, 201),
        }, "LunaInterfaceSuitePrebuiltCPC2")

        local c3cp = secEditor:ColorPicker({
            Texto = "Color 3",
            Color = Color3.fromRGB(224, 138, 184),
        }, "LunaInterfaceSuitePrebuiltCPC3")

        local function updateGradient()
            local c1 = (c1cp and c1cp:Get()) or Color3.fromRGB(255, 255, 255)
            local c2 = (c2cp and c2cp:Get()) or Color3.fromRGB(255, 255, 255)
            local c3 = (c3cp and c3cp:Get()) or Color3.fromRGB(255, 255, 255)
            AlanLuna.ThemeGradient = ColorSequence.new{
                ColorSequenceKeypoint.new(0.00, c1),
                ColorSequenceKeypoint.new(0.50, c2),
                ColorSequenceKeypoint.new(1.00, c3)
            }
            AlanLuna.Eventos.TemaCambiado:Fire("Custom Gradient")
        end

        task.spawn(function()
            task.wait(0.5)
            if c1cp then c1cp.Callback = updateGradient end
            if c2cp then c2cp.Callback = updateGradient end
            if c3cp then c3cp.Callback = updateGradient end
        end)

        local secPresets = self:CrearSeccion("Preset Gradients", { Columnas = 2 })

        for nombrePreset, colores in pairs(PresetGradients) do
            secPresets:Boton({
                Texto = tostring(nombrePreset),
                Callback = function()
                    if c1cp then c1cp:Set(colores[1]) end
                    if c2cp then c2cp:Set(colores[2]) end
                    if c3cp then c3cp:Set(colores[3]) end
                    updateGradient()
                end,
            })
        end
    end
end

-- ══════════════════════════════════════════════════════════════
--  SECCION 25: LUNA HOME TAB PORT (DASHBOARD & STATS)
-- ══════════════════════════════════════════════════════════════
local function crearHomeTabLuna(Ventana, HomeTabSettings)
    HomeTabSettings = Kwargify({
        Icon = 1,
        SupportedExecutors = {"Vega X", "Delta", "Nihon", "Xeno", "Synapse X", "Krnl", "Fluxus"},
        DiscordInvite = "nebula"
    }, HomeTabSettings or {})

    local catGeneral = Ventana.Categorias["General"] or Ventana:CrearCategoria("General")
    local homeTab = catGeneral:CrearTab({
        Nombre = "Home",
        Icono = (HomeTabSettings.Icon == 2) and "dashboard" or "home",
        ShowTitle = true
    })

    local secProfile = homeTab:CrearSeccion("Player Profile", { Columnas = 2 })

    local headshot = Players:GetUserThumbnailAsync(LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size420x420)
    secProfile:Imagen({
        Url = headshot,
        Alto = 80,
        Columna = 1
    })

    secProfile:Label({ Texto = "Display Name", Valor = LocalPlayer.DisplayName, Columna = 2 })
    secProfile:Label({ Texto = "Username", Valor = "@" .. LocalPlayer.Name, Columna = 2 })
    secProfile:Label({ Texto = "Account ID", Valor = tostring(LocalPlayer.UserId), Columna = 2 })

    local secClient = homeTab:CrearSeccion("Client & Server Status", { Columnas = 2 })

    local execName = (isStudio and "Roblox Studio (Debugging)") or detectarEjecutor()
    secClient:Label({ Texto = "Executor", Valor = execName, Columna = 1 })

    local isSupported = false
    for _, ex in pairs(HomeTabSettings.SupportedExecutors) do
        if ex == execName or isStudio then isSupported = true; break end
    end
    secClient:Label({
        Texto = "Compatibility",
        Valor = isSupported and "🟢 Supported" or "🟡 Untested",
        Columna = 1
    })

    local pingLbl = secClient:Label({ Texto = "Latency", Valor = "0 ms", Columna = 1 })
    local timeLbl = secClient:Label({ Texto = "Server Time", Valor = "00:00:00", Columna = 2 })
    local playersLbl = secClient:Label({ Texto = "Players", Valor = "-- / --", Columna = 2 })

    local regionStr = "Global"
    pcall(function() regionStr = Localization:GetCountryRegionForPlayerAsync(LocalPlayer) end)
    secClient:Label({ Texto = "Region", Valor = regionStr, Columna = 2 })

    local secDiscord = homeTab:CrearSeccion("Discord Community", { Columnas = 1 })
    secDiscord:Boton({
        Texto = "Join Official Discord Server",
        Icono = "chat",
        Callback = function()
            local link = "https://discord.gg/" .. tostring(HomeTabSettings.DiscordInvite)
            if setclipboard then setclipboard(link) end
            if request then
                request({
                    Url = 'http://127.0.0.1:6463/rpc?v=1',
                    Method = 'POST',
                    Headers = {
                        ['Content-Type'] = 'application/json',
                        Origin = 'https://discord.com'
                    },
                    Body = HttpService:JSONEncode({
                        cmd = 'INVITE_BROWSER',
                        nonce = HttpService:GenerateGUID(false),
                        args = {code = HomeTabSettings.DiscordInvite}
                    })
                })
            end
            AlanLuna:Notificar({
                Title = "Discord Invite",
                Content = "Link copied to clipboard: " .. link,
                Duration = 3,
                Icon = "check_circle"
            })
        end
    })

    local function formatDigits(int) return string.format("%02i", int) end
    local function convertToHMS(seconds)
        local m = (seconds - seconds % 60) / 60
        seconds = seconds - m * 60
        local h = (m - m % 60) / 60
        m = m - h * 60
        return formatDigits(h) .. ":" .. formatDigits(m) .. ":" .. formatDigits(seconds)
    end

    local function getPing()
        local s = game:GetService("Stats")
        if s and s:FindFirstChild("Network") and s.Network:FindFirstChild("ServerStatsItem") then
            local p = s.Network.ServerStatsItem:FindFirstChild("Data Ping")
            if p then return math.clamp(p:GetValue(), 5, 1000) end
        end
        return 50
    end

    AlanLuna:RegistrarHilo(task.spawn(function()
        while homeTab and homeTab.Pagina and homeTab.Pagina.Parent do
            if homeTab.Pagina.Visible then
                local ms = isStudio and math.round((LocalPlayer:GetNetworkPing() * 2) / 0.01) or math.floor(getPing())
                pingLbl:Set(tostring(ms) .. " ms")
                timeLbl:Set(convertToHMS(time()))
                playersLbl:Set(#Players:GetPlayers() .. " / " .. Players.MaxPlayers)
            end
            task.wait(1)
        end
    end))

    return homeTab
end

-- ══════════════════════════════════════════════════════════════
--  SECCION 26: PESTANA PREINSTALADA ALANUI (SISTEMA & AJUSTES)
-- ══════════════════════════════════════════════════════════════
local function agregarPestanaPreinstaladaCompleta(Ventana, cfg)
    cfg = cfg or {}

    local catSystem = Ventana.Categorias["System"] or Ventana:CrearCategoria({ Nombre = "System", Icono = "settings" })
    local sysTab = catSystem:CrearTab({
        Nombre = cfg.Nombre or "Preinstalada",
        Icono = "settings",
        ShowTitle = true
    })

    local secInfo = sysTab:CrearSeccion("Información", { Columnas = 2 })
    secInfo:Label({ Texto = "Ejecutor", Valor = detectarEjecutor(), Columna = 1 })
    secInfo:Label({ Texto = "Versión AlanLuna", Valor = AlanLuna.Version, Columna = 1 })
    secInfo:Label({ Texto = "Desarrollo", Valor = "AlanbeikersFF & Nebula", Columna = 1 })

    local lblFps = secInfo:Label({ Texto = "FPS", Valor = "–", Columna = 2 })
    local lblFrameTime = secInfo:Label({ Texto = "Frame Time", Valor = "–", Columna = 2 })
    local lblEstado = secInfo:Label({ Texto = "Estado", Valor = "–", Columna = 2 })
    local lblSalud = secInfo:Label({
        Texto = "Salud Interfaz",
        Valor = "🟢 Óptimo",
        Tooltip = "Evalúa memoria, crecimiento de instancias y tasa de refresco.",
        Columna = 2
    })

    local statsOk, statsService = pcall(function() return game:GetService("Stats") end)
    local lblMemoria = nil
    if statsOk and statsService then
        lblMemoria = secInfo:Label({ Texto = "Memoria", Valor = "–", Columna = 1 })
    end

    local ultimo, frames = os.clock(), 0
    AlanLuna:RegistrarConexion(RunService.Heartbeat:Connect(function()
        frames = frames + 1
        local ahora = os.clock()
        if ahora - ultimo >= 1 then
            local intervalo = ahora - ultimo
            local fps = math.round(frames / intervalo)
            local ft = math.round((intervalo / frames) * 1000 * 10) / 10
            lblFps:Set(fps .. " FPS")
            lblFrameTime:Set(ft .. " ms")

            if fps >= 50 then lblEstado:Set("🟢 Excelente")
            elseif fps >= 30 then lblEstado:Set("🟡 Normal")
            else lblEstado:Set("🔴 Degradado") end

            if lblMemoria then
                local okMem, m = pcall(function() return statsService:GetTotalMemoryUsageMb() end)
                if okMem and m then lblMemoria:Set("~" .. math.round(m) .. " MB") end
            end

            frames, ultimo = 0, ahora
        end
    end))

    local secDiag = sysTab:CrearSeccion("Diagnóstico de Hardware", { Columnas = 2 })
    local C = AlanLuna.Capacidades
    secDiag:Label({ Texto = "Dispositivo", Valor = C.Tipo .. " (" .. C:NombrePlataforma() .. ")", Columna = 1 })
    secDiag:Label({ Texto = "Pantalla", Valor = math.floor(C.ViewportSize.X) .. "x" .. math.floor(C.ViewportSize.Y), Columna = 1 })

    local fSoportadas, fTotales = 0, 0
    for _, f in ipairs(AlanLuna.Features) do
        fTotales = fTotales + 1
        if AlanLuna:VerificarSoporte(f.nombre).ok then fSoportadas = fSoportadas + 1 end
    end
    secDiag:Label({ Texto = "Capacidades", Valor = fSoportadas .. " / " .. fTotales, Columna = 2 })

    secDiag:Dropdown({
        Texto = "Forzar Tipo",
        Opciones = {"Auto", "PC", "Movil", "Tablet", "Consola"},
        Defecto = _G.AlanLuna_TipoForzado or "Auto",
        Columna = 2,
        Callback = function(v)
            if v == "Auto" then AlanLuna:LiberarForzado() else AlanLuna:ForzarTipo(v) end
        end
    })

    local secAp = sysTab:CrearSeccion("Apariencia & Dimensiones", { Columnas = 2 })
    local nombresTemas = {}
    for n in pairs(AlanLuna.ThemeManager.Temas) do table.insert(nombresTemas, n) end
    table.sort(nombresTemas)

    for n in pairs(PresetGradients) do
        table.insert(nombresTemas, "Gradient: " .. n)
    end

    secAp:Dropdown({
        Texto = "Tema de Interfaz",
        Flag = "sys_tema",
        Opciones = nombresTemas,
        Defecto = Themes.Predeterminado,
        Columna = 1,
        Callback = function(v)
            AlanLuna.ThemeManager:AplicarTema(v)
            AlanLuna:Notificar({ Title = "Apariencia", Content = "Tema " .. v .. " aplicado.", Duration = 2 })
        end
    })

    secAp:Slider({
        Texto = "Escala General",
        Flag = "sys_escala",
        Min = 70, Max = 130, Incremento = 5, Sufijo = "%", Defecto = 100,
        Columna = 1,
        Callback = function(v)
            if Ventana._main and Ventana._main:FindFirstChildOfClass("UIScale") then
                Ventana._main:FindFirstChildOfClass("UIScale").Scale = (v / 100)
            end
        end
    })

    secAp:Slider({
        Texto = "Ancho Ventana",
        Flag = "sys_ancho",
        Min = 70, Max = 130, Incremento = 5, Sufijo = "%", Defecto = 100,
        Columna = 2,
        Callback = function(v)
            local factor = v / 100
            local nuevoAncho = 620 * factor
            Utils.Tween(Ventana._main, {Size = UDim2.new(0, nuevoAncho, 0, Ventana._main.Size.Y.Offset)}, 0.2)
        end
    })

    secAp:Slider({
        Texto = "Alto Ventana",
        Flag = "sys_alto",
        Min = 70, Max = 130, Incremento = 5, Sufijo = "%", Defecto = 100,
        Columna = 2,
        Callback = function(v)
            local factor = v / 100
            local nuevoAlto = 380 * factor
            Utils.Tween(Ventana._main, {Size = UDim2.new(0, Ventana._main.Size.X.Offset, 0, nuevoAlto)}, 0.2)
        end
    })

    AlanLuna:MarcarComoUI({"sys_tema", "sys_escala", "sys_ancho", "sys_alto"})

    local secProfiles = sysTab:CrearSeccion("Perfiles & Guardado", { Columnas = 2 })
    local perfilSel = nil

    local dropP = secProfiles:Dropdown({
        Texto = "Perfil",
        Opciones = AlanLuna.SaveManager:Listar(),
        Columna = 1,
        Callback = function(v) perfilSel = v end
    })

    secProfiles:Boton({
        Texto = "Cargar Seleccionado",
        Columna = 1,
        Callback = function()
            if perfilSel then AlanLuna.SaveManager:Cargar(perfilSel) end
        end
    })

    local nuevoNombre = ""
    secProfiles:Input({
        Texto = "Nuevo Perfil",
        Placeholder = "Nombre...",
        Columna = 2,
        Callback = function(v) nuevoNombre = v end
    })

    secProfiles:Boton({
        Texto = "Guardar Nuevo",
        Columna = 2,
        Callback = function()
            if nuevoNombre ~= "" then
                AlanLuna.SaveManager:Guardar(nuevoNombre)
                dropP.ActualizarOpciones(AlanLuna.SaveManager:Listar())
            end
        end
    })

    local secHistorial = sysTab:CrearSeccion("Historial de Modificaciones", { Columnas = 2 })
    local lblHist = secHistorial:Label({ Texto = "Estado", Valor = "Sin cambios", Columna = 1 })

    AlanLuna:RegistrarConexion(AlanLuna.Eventos.HistorialCambiado:Connect(function(u, r)
        lblHist:Set(u .. " Deshacer · " .. r .. " Rehacer")
    end))

    secHistorial:Boton({
        Texto = "↩️ Deshacer",
        Columna = 2,
        Callback = function() AlanLuna:Deshacer() end
    })

    secHistorial:Boton({
        Texto = "↪️ Rehacer",
        Columna = 2,
        Callback = function() AlanLuna:Rehacer() end
    })

    return sysTab
end

-- ══════════════════════════════════════════════════════════════
--  SECCION 27: MONKEY PATCHING & HOOKING GLOBAL DE COMPATIBILIDAD
-- ══════════════════════════════════════════════════════════════
local oldCrearVentanaFinal = AlanLuna.CrearVentana
function AlanLuna:CrearVentana(config)
    local Ventana = oldCrearVentanaFinal(self, config)

    local catSystem = Ventana.Categorias["System"] or Ventana:CrearCategoria({ Nombre = "System", Icono = "settings" })

    local tabConfigLuna = catSystem:CrearTab({
        Nombre = "Config",
        Icono = "settings",
        ShowTitle = true
    })
    registrarMetodosLunaAvanzados(tabConfigLuna)
    tabConfigLuna:BuildConfigSection()
    tabConfigLuna:BuildThemeSection()

    if config.PestanaPreinstalada ~= false then
        agregarPestanaPreinstaladaCompleta(Ventana, config)
    end

    function Ventana:CreateHomeTab(hSettings)
        return crearHomeTabLuna(Ventana, hSettings)
    end

    local oldCrearCategoria = Ventana.CrearCategoria
    function Ventana:CrearCategoria(catCfg)
        local CatObj = oldCrearCategoria(self, catCfg)
        local oldCrearTab = CatObj.CrearTab
        function CatObj:CrearTab(tabCfg)
            local TabObj = oldCrearTab(self, tabCfg)
            registrarMetodosLunaAvanzados(TabObj)
            return TabObj
        end
        return CatObj
    end

    return Ventana
end

function AlanLuna:Destroy()
    local inst = _G.AlanLuna_Instancia
    if inst and inst.Ventana and inst.Ventana._main then
        pcall(function() inst.Ventana._main.Parent:Destroy() end)
    end
    limpiarInstanciaPrevia()
end

AlanUI = AlanLuna
Luna = AlanLuna

if getgenv then
    getgenv().AlanLuna = AlanLuna
    getgenv().AlanUI = AlanLuna
    getgenv().Luna = AlanLuna
end

return AlanLuna
