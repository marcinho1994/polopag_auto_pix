-- ########### CONFIGURAVEL POR VOCE! ##############--
local isWindows = false -- Defina como true se estiver no Windows, ou deixe false para Linux.
local tmpCooldownStorage = 99995 -- Use uma storage livre do servidor, você também pode registrar seguindo o mesmo padrão, por exemplo: Storage.Timers.PoloPagPixCooldown.
-- PoloPag.com API Key. (Ao se registrar, o valor cairá automaticamente na sua chave Pix CPF/CNPJ de qualquer banco)
local API_KEY_POLOPAG = "" -- PoloPag API Key.
local PIX_VALUES = {{
    price = 1,
    points = 10
}, {
    price = 5,
    points = 50
}, {
    price = 10,
    points = 100
}, {
    price = 30,
    points = 300
}, {
    price = 50,
    points = 500
}, {
    price = 80,
    points = 800
}, {
    price = 100,
    points = 1000
}, {
    price = 120,
    points = 1200
}, {
    price = 150,
    points = 1500
}, {
    price = 300,
    points = 3000
}, {
    price = 500,
    points = 5000
}, {
    price = 1000,
    points = 10000
}, {
    price = 1500,
    points = 15000
}}

local coinsTableInDatabase = "coins_transferable"
local commandPixExhaust = 1
local commandPixSelectExhaust = 5

-- ########### MODIFIQUE APENAS SE NECESSARIO ##############--
local PIX_VALUES_MODAL_WINDOW_ID = 9595
local PIX_GENERATED_MODAL_WINDOW_ID = 9696
local MODAL_EVENT_NAME = "ModalWindowPix"
local COPIA_COLA_ITEMID_SCREEN = 24774 -- ItemID que vai aparecer na screen do copia e cola (24774 = tibia coin)

-- ########### NAO INDICAMOS MODIFICAR ##############
-- Constants
local PIX_VALUES_MODAL_TITLE = "Gerador de Pix"
local PIX_VALUES_MODAL_MESSAGE = "Os pontos serao adicionados na conta do seu personagem"
local PIX_VALUES_MODAL_BUTTON_GENERATE = "Gerar Pix"

local MODAL_CANCEL_BUTTON_STRING = "Sair"
local MODAL_CANCEL_BUTTON_NUMBER = 5

local MODAL_NEXTSTEP_BUTTON_NUMBER = 0
local MODAL_COPIA_COLA_BUTTON_NUMBER = 0

local PIX_GENERATED_MODAL_TITLE = "Pix Gerado: "
local PIX_GENERATED_MODAL_MESSAGE_TUTORIAL = "Escaneie o QRCode e efetue o pagamento."
local PIX_GENERATED_MODAL_MESSAGE_WARNING =
    "Os seus pontos vao ser creditados automaticamente ao finalizar o pagamento."
local PIX_GENERATED_MODAL_BUTTON_COPIA_COLA_ = "Copia e Cola"
local PIX_GENERATED_MODAL_BUTTON_VERIFY_PIX = "Verificar"

local URL_POLOPAG_GENERATE_COB = "https://api.polopag.com/v1/cobpix"
local URL_YOUR_SERVER_WEBHOOK = "https://teste.com/polopag_webhook.php" -- URL do seu webhook

local SPACE_HTML = "<br>"

-- ########### NAO MODIFIQUE NADA!!!!!!!! ##############
-- Class
local PixGenerator = {}
PixGenerator.__index = PixGenerator

PixGenerator.instances = {}

-- Localizations
local stringFormat = string.format
local stringRep = string.rep

-- Private Functions
local function PixGeneratorFactory(accountId)
    if accountId and PixGenerator.instances[accountId] then
        return PixGenerator.instances[accountId]
    end

    local instance = PixGenerator:_new(accountId)

    if accountId then
        PixGenerator.instances[accountId] = instance
    end

    return instance
end

local function checkPlayerIsExhausted(player, exhaustTime)
    local cooldown = player:getStorageValue(tmpCooldownStorage)
    if cooldown > os.time() then
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "You need to wait to use this command again.")
        player:getPosition():sendMagicEffect(CONST_ME_POFF)
        return true
    end

    player:setStorageValue(tmpCooldownStorage, os.time() + exhaustTime)
    return false
end

local function sendErrorGeneratingPix(player)
    local header = "                   [GERADOR DE PIX]"
    local textMSG = " [ERROR] = Aconteceu um erro, reinicie o pagamento."
    player:popupFYI(stringFormat("%s\n\n%s", header, textMSG))
end

local function findPixByReferenceAndShowWindow(pid, accountId)
    local player = Player(pid)
    if player then
        local pixInstance = PixGeneratorFactory(accountId)
        if pixInstance then
            local query = string.format([[
        SELECT * FROM `polopag_transacoes`
        WHERE reference = %s
        AND expires_at > NOW()
        LIMIT 1]], db.escapeString(pixInstance:getReference()))

            local resultId = db.storeQuery(query)
            if resultId ~= false then
                local txid = result.getString(resultId, "txid")
                local base64 = result.getString(resultId, "base64")
                local copia_e_cola = result.getString(resultId, "copia_e_cola")
                local coins_table = result.getString(resultId, "coins_table")
                local status = result.getString(resultId, "status")
                local expires_at = result.getString(resultId, "expires_at")
                result.free(resultId)

                if (status and status == "ATIVA") then
                    if base64 and copia_e_cola and coins_table and txid then
                        pixInstance:setStatus(status)
                        pixInstance:setBase64(base64)
                        pixInstance:setQRCodeURL("&nbsp;<img src='data:image/png;base64," .. base64 .. "'/>")
                        pixInstance:setCopiaCola(copia_e_cola)
                        pixInstance:setTXID(txid)
                        pixInstance:setCoinsTable(coins_table)
                        pixInstance:setExpirationAt(expires_at)
                        pixInstance:showPixWindow(player, pixInstance:getlastChoice())
                        return true
                    end
                end
            end
        end
        sendErrorGeneratingPix(player)
    end

    return false
end

local function generateQrCodeData()
    local qrCodeData = {}
    for i = 1, #PIX_VALUES do
        qrCodeData[i] = {
            base64 = "",
            url = "",
            txid = "",
            copiaECola = "",
            price = 0,
            points = 0,
            reference = "",
            coinsTable = "",
            expirationAt = "",
            status = ""
        }
    end

    return qrCodeData
end

local function brTagsFormat(quantity)
    return stringRep(SPACE_HTML, quantity)
end

-- Set Metodos
function PixGenerator:setlastChoice(choice)
    self.lastChoice = choice
end

function PixGenerator:setBase64(base64)
    self.qrcodeData[self.lastChoice].base64 = base64
end

function PixGenerator:setQRCodeURL(url)
    self.qrcodeData[self.lastChoice].url = url
end

function PixGenerator:setCopiaCola(copiaCola)
    self.qrcodeData[self.lastChoice].copiaECola = copiaCola
end

function PixGenerator:setTXID(txid)
    self.qrcodeData[self.lastChoice].txid = txid
end

function PixGenerator:setPrice(price)
    self.qrcodeData[self.lastChoice].price = price
end

function PixGenerator:setPoints(points)
    self.qrcodeData[self.lastChoice].points = points
end

function PixGenerator:setReference(reference)
    self.qrcodeData[self.lastChoice].reference = reference
end

function PixGenerator:setCoinsTable(coinsTable)
    self.qrcodeData[self.lastChoice].coinsTable = coinsTable
end

function PixGenerator:setExpirationAt(expirationAt)
    self.qrcodeData[self.lastChoice].expirationAt = expirationAt
end

function PixGenerator:setStatus(status)
    self.qrcodeData[self.lastChoice].status = status
end

-- Get Metodos
function PixGenerator:getlastChoice()
    return self.lastChoice
end

function PixGenerator:getBase64()
    return self.qrcodeData[self.lastChoice].base64
end

function PixGenerator:getQRCodeURL()
    return self.qrcodeData[self.lastChoice].url
end

function PixGenerator:getCopiaCola()
    return self.qrcodeData[self.lastChoice].copiaECola
end

function PixGenerator:getTXID()
    return self.qrcodeData[self.lastChoice].txid
end

function PixGenerator:getPrice()
    return self.qrcodeData[self.lastChoice].price
end

function PixGenerator:getPoints()
    return self.qrcodeData[self.lastChoice].points
end

function PixGenerator:getReference()
    return self.qrcodeData[self.lastChoice].reference
end

function PixGenerator:getCoinsTable()
    return self.qrcodeData[self.lastChoice].coinsTable
end

function PixGenerator:getExpirationAt()
    return self.qrcodeData[self.lastChoice].expirationAt
end

function PixGenerator:getStatus()
    return self.qrcodeData[self.lastChoice].status
end

-- Todos Métodos
function PixGenerator:updatePixTransactionStatus(txid, newStatus)
    local query = string.format([[
        UPDATE `polopag_transacoes`
        SET status = %s
        WHERE txid = %s]], db.escapeString(newStatus), db.escapeString(txid))

    local success = db.query(query)
    if not success then
        return false, "Falha ao atualizar o status da transacao PIX."
    end

    return true, "Status da transacao PIX atualizado com sucesso."
end

function PixGenerator:getPixTransactionStatusFromDb(accountId, txid)
    local query = string.format([[
        SELECT status FROM `polopag_transacoes`
        WHERE txid = %s
        LIMIT 1]], accountId, db.escapeString(txid))

    local status
    local resultId = db.storeQuery(query)
    if resultId ~= false then
        status = result.getString(resultId, "status")
        result.free(resultId)

        if status then
            self:setStatus(status)
            return status
        end
    end
    return status
end

function PixGenerator:findActiveNonExpiredPix(accountId, price, points)
    local query = string.format([[
        SELECT * FROM `polopag_transacoes`
        WHERE account_id = %d AND status = 'ATIVA'
        AND price = %.2f
        AND points = %d
        AND expires_at > NOW()
        LIMIT 1]], accountId, string.format("%.2f", price), points)

    local resultId = db.storeQuery(query)
    if resultId ~= false then
        local txid = result.getString(resultId, "txid")
        local base64 = result.getString(resultId, "base64")
        local copia_e_cola = result.getString(resultId, "copia_e_cola")
        local reference = result.getString(resultId, "reference")
        local coins_table = result.getString(resultId, "coins_table")
        local status = result.getString(resultId, "status")
        local expires_at = result.getString(resultId, "expires_at")
        result.free(resultId)
        if (status and status == "ATIVA") then
            if base64 and copia_e_cola and reference and coins_table and txid then
                self:setStatus(status)
                self:setBase64(base64)
                self:setQRCodeURL("&nbsp;<img src='data:image/png;base64," .. base64 .. "'/>")
                self:setCopiaCola(copia_e_cola)
                self:setTXID(txid)
                self:setReference(reference)
                self:setCoinsTable(coins_table)
                self:setExpirationAt(expires_at)
                return true
            end
        end
    end
    return false
end

function PixGenerator:getPixTransactionStatus()
    local query = [[
        SELECT status FROM `polopag_transacoes`
        WHERE txid = '%s']]

    local resultId = db.storeQuery(query)
    if resultId ~= false then
        local status = result.getString(resultId, "status")
        result.free(resultId)
        return status
    else
        return nil, "Transacao PIX nao encontrada."
    end
end

function PixGenerator:generateQRCode()
    local formattedPrice = string.format("%.2f", self:getPrice())
    local reference = string.format("PIX%s%s%s", self.accountId, os.time(), math.random(100000000, 999999999))
    local solicitacaoPagador = configManager.getString(configKeys.SERVER_NAME):gsub("%s+", "")
    self:setReference(reference)

    local command = string.format("python3 polopag.py %s %s %s %s %s %s %s %s > /dev/null 2>&1 &", self.apiKey,
        formattedPrice, solicitacaoPagador, URL_YOUR_SERVER_WEBHOOK, self:getPoints(), reference, coinsTableInDatabase,
        self.accountId)

    if isWindows then
        local handle = io.popen("cd")
        local currentDir = handle:read("*a"):gsub("\n", ""):gsub("\r", "")
        handle:close()

        local scriptPath = currentDir .. "\\polopag.py"
        command = string.format("start /B python %s %s %s %s %s %s %s %s %s", scriptPath, self.apiKey,
            formattedPrice, solicitacaoPagador, URL_YOUR_SERVER_WEBHOOK, self:getPoints(), reference,
            coinsTableInDatabase, self.accountId)
    end

    os.execute(command)

    return true
end

function PixGenerator:addCoinsToAccount(coinTable, pointsToAdd, txid)
    pointsToAdd = tonumber(pointsToAdd)
    if not pointsToAdd then
        return false
    end

    local update = self:updatePixTransactionStatus(txid, "COINS ENVIADOS")
    if not update then
        return false
    end

    local query = string.format("UPDATE `accounts` SET `%s` = `%s` + %d WHERE `id` = %d", coinTable, coinTable,
        pointsToAdd, self.accountId)

    local success = db.query(query)
    if not success then
        return false
    end

    return true
end

function PixGenerator:initiatePix(choice)
    local values = PIX_VALUES[choice]
    if values then
        self:setlastChoice(choice)
        self:setPrice(values.price)
        self:setPoints(values.points)
        self:setCoinsTable(coinsTableInDatabase)

        local hasActivePIX = self:findActiveNonExpiredPix(self.accountId, self:getPrice(), self:getPoints())
        if not hasActivePIX then
            self:generateQRCode()
        end
        return true
    end
    return false, "Erro - Valores nao encontrados."
end

function PixGenerator:getImage()
    local informationPriceValue = stringFormat("Valor: R$%s,00", self:getPrice())
    local informationPointsValue = stringFormat("Coins: %s", self:getPoints())

    local qrCode = self:getQRCodeURL()

    local formattedString = stringFormat("%s%s%s%s%s%s%s%s%s%s", PIX_GENERATED_MODAL_MESSAGE_TUTORIAL, brTagsFormat(2),
        PIX_GENERATED_MODAL_MESSAGE_WARNING, brTagsFormat(2), informationPriceValue, brTagsFormat(1),
        informationPointsValue, brTagsFormat(1), qrCode, brTagsFormat(15))

    return formattedString
end

function PixGenerator:showCopiaColaWindow(player)
    self:showPixWindow(player, self:getlastChoice())

    player:showTextDialog(COPIA_COLA_ITEMID_SCREEN, self:getCopiaCola())

    return true
end

function PixGenerator:showPixWindow(player, choice)
    local window = ModalWindow(PIX_GENERATED_MODAL_WINDOW_ID)
    window:setTitle(PIX_GENERATED_MODAL_TITLE)

    window:setMessage(self:getImage())

    window:addButton(MODAL_COPIA_COLA_BUTTON_NUMBER, PIX_GENERATED_MODAL_BUTTON_COPIA_COLA_)
    window:addButton(MODAL_CANCEL_BUTTON_NUMBER, MODAL_CANCEL_BUTTON_STRING)
    window:setDefaultEnterButton(0)
    window:setDefaultEscapeButton(2)

    window:sendToPlayer(player)

    return true
end

function PixGenerator:generateWindow(player, lastWindowId, buttonId, choice)
    if (buttonId == MODAL_CANCEL_BUTTON_NUMBER) then
        return false
    end

    if (lastWindowId == PIX_VALUES_MODAL_WINDOW_ID) and (buttonId == MODAL_NEXTSTEP_BUTTON_NUMBER) then
        if checkPlayerIsExhausted(player, commandPixSelectExhaust) then
            return false
        end

        if self:initiatePix(choice) then
            addEvent(findPixByReferenceAndShowWindow, 3000, player:getId(), player:getAccountId())
        else
            sendErrorGeneratingPix(player)
        end
    elseif (lastWindowId == PIX_GENERATED_MODAL_WINDOW_ID) then
        if (buttonId == MODAL_COPIA_COLA_BUTTON_NUMBER) then
            self:showCopiaColaWindow(player)
        end
    end

    return false
end

function PixGenerator:getChoices(window)
    for _, choiceValue in ipairs(PIX_VALUES) do
        window:addChoice(_, stringFormat("R$%s,00 = %s pontos", choiceValue.price, choiceValue.points))
    end
end

function PixGenerator:sendPixValuesModalWindow(player)
    if checkPlayerIsExhausted(player, commandPixExhaust) then
        return
    end

    player:registerEvent(MODAL_EVENT_NAME)
    local window = ModalWindow(PIX_VALUES_MODAL_WINDOW_ID)

    window:setTitle(PIX_VALUES_MODAL_TITLE)
    window:setMessage(stringFormat("%s: %s", PIX_VALUES_MODAL_MESSAGE, player:getName()))

    self:getChoices(window)

    window:addButton(MODAL_NEXTSTEP_BUTTON_NUMBER, PIX_VALUES_MODAL_BUTTON_GENERATE)
    window:addButton(MODAL_CANCEL_BUTTON_NUMBER, MODAL_CANCEL_BUTTON_STRING)
    window:setDefaultEnterButton(0)
    window:setDefaultEscapeButton(1)

    window:sendToPlayer(player)
end

function PixGenerator:_new(accountId)
    self = setmetatable({}, PixGenerator)
    self.lastChoice = 0
    self.qrcodeData = generateQrCodeData()
    self.apiKey = API_KEY_POLOPAG
    self.accountId = accountId
    return self
end

local function PixGeneratorFactory(accountId)
    if accountId and PixGenerator.instances[accountId] then
        return PixGenerator.instances[accountId]
    end

    local instance = PixGenerator:_new(accountId)

    if accountId then
        PixGenerator.instances[accountId] = instance
    end

    return instance
end

return PixGeneratorFactory
