<# :
@echo off
setlocal
set "SCRIPT_PATH=%~f0"
set "WORK_DIR=%CD%"
title Field Test Easy Tool
cd /d "%~dp0"
powershell -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -Command "iex (Get-Content -LiteralPath '%~f0' -Raw)"
exit /b
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# --- GLOBAL SETTINGS ---
$Global:DEST_ROOT = $env:WORK_DIR
[System.IO.Directory]::SetCurrentDirectory($Global:DEST_ROOT)

$Global:ADB_EXE = "adb" 
$Global:UNISOC_PATH = "/sdcard/ylog"
$Global:SAMSUNG_PATH = "/sdcard/log"

# --- TIMEOUT MESSAGE BOX FUNCTION ---
function Show-TimeoutMsgBox {
    param([string]$Message, [int]$TimeoutSeconds)
    
    $MsgForm = New-Object System.Windows.Forms.Form
    $MsgForm.Text = "Confirmation"
    $MsgForm.Size = New-Object System.Drawing.Size(350,170)
    $MsgForm.StartPosition = "CenterParent"
    $MsgForm.FormBorderStyle = "FixedDialog"
    $MsgForm.ControlBox = $false
    $MsgForm.TopMost = $true

    $Label = New-Object System.Windows.Forms.Label
    $Label.Location = New-Object System.Drawing.Point(20,20)
    $Label.Size = New-Object System.Drawing.Size(300,50)
    $Label.Text = "$Message`n`nAuto-ignore em $TimeoutSeconds segundos..."
    $MsgForm.Controls.Add($Label)

    $BtnYes = New-Object System.Windows.Forms.Button
    $BtnYes.Text = "Yes"
    $BtnYes.Location = New-Object System.Drawing.Point(60,85)
    $BtnYes.DialogResult = [System.Windows.Forms.DialogResult]::Yes
    $MsgForm.Controls.Add($BtnYes)

    $BtnNo = New-Object System.Windows.Forms.Button
    $BtnNo.Text = "No"
    $BtnNo.Location = New-Object System.Drawing.Point(180,85)
    $BtnNo.DialogResult = [System.Windows.Forms.DialogResult]::No
    $MsgForm.Controls.Add($BtnNo)

    $script:TimeLeft = $TimeoutSeconds
    $T = New-Object System.Windows.Forms.Timer
    $T.Interval = 1000
    $T.Add_Tick({
        $script:TimeLeft--
        $Label.Text = "$Message`n`nAuto-ignore em $script:TimeLeft segundos..."
        if ($script:TimeLeft -le 0) {
            $T.Stop()
            $MsgForm.DialogResult = [System.Windows.Forms.DialogResult]::No
            $MsgForm.Close()
        }
    })
    $T.Start()

    $Result = $MsgForm.ShowDialog()
    $T.Stop()
    return $Result
}


# ==========================================
# SISTEMA DE ATUALIZAÇÃO AUTOMÁTICA (REPOSITÓRIO PÚBLICO)
# ==========================================
$CurrentVersionStr = "1.0"
$CurrentVersion = [version]$CurrentVersionStr

# CONFIGURAÇÃO DO GITHUB
$GitHubUser   = "engpctelecom"
$GitHubRepo   = "ft-easy-tool"
$Branch       = "main"

try {
    $Timestamp = (Get-Date).Ticks
    $RemoteVersionStr = Invoke-RestMethod -Uri $RemoteVersionUrl -Headers $Headers -UseBasicParsing -ErrorAction Stop
    $CleanVersionStr = $RemoteVersionStr -replace '[^\d\.]', ''

    $RemoteVersion = $null
    
    # O TryParse tenta converter de forma invisível. Se falhar (ex: ler "11"), ele retorna falso e segue o código sem travar.
    if ([System.Version]::TryParse($CleanVersionStr, [ref]$RemoteVersion)) {
        
        if ($RemoteVersion -gt $CurrentVersion) {
            
            $updTitle = "FT Easy Tool - OTA Update"
            $updMsg = "A new version ($RemoteVersion) is available!`n`nDo you want to update now? The tool will restart."
            
            $decision = [System.Windows.Forms.MessageBox]::Show($updMsg, $updTitle, [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Information, [System.Windows.Forms.MessageBoxDefaultButton]::Button1, [System.Windows.Forms.MessageBoxOptions]::DefaultDesktopOnly)
            
            if ($decision -eq [System.Windows.Forms.DialogResult]::Yes) {
                
                $tempFile = Join-Path $env:TEMP "FTEasyTool_update.tmp"
                
                Invoke-WebRequest -Uri $RemoteScriptUrl -Headers $Headers -OutFile $tempFile -UseBasicParsing -ErrorAction Stop

                if (Test-Path $tempFile) {
                    $cmdArgs = "/c ping 127.0.0.1 -n 2 > nul & move /y `"$tempFile`" `"$env:SCRIPT_PATH`" > nul & start `"`" `"$env:SCRIPT_PATH`""
                    
                    Start-Process -FilePath "cmd.exe" -ArgumentList $cmdArgs -WindowStyle Hidden -Verb RunAs
                    
                    [Environment]::Exit(0)
                }
            }
        }
    }
} catch {
    $ErroReal = $_.Exception.Message
    [System.Windows.Forms.MessageBox]::Show("Failed to check for updates: $ErroReal", "OTA Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error, [System.Windows.Forms.MessageBoxDefaultButton]::Button1, [System.Windows.Forms.MessageBoxOptions]::DefaultDesktopOnly)
}
# ==========================================


# --- MAIN WINDOW ---
$Form = New-Object System.Windows.Forms.Form
$Form.Text = "Field Test Easy Tool v$CurrentVersionStr"
$Form.Size = New-Object System.Drawing.Size(500, 890)
$Form.StartPosition = "CenterScreen"
$Form.FormBorderStyle = "Sizable"
$Form.MaximizeBox = $true
$Form.BackColor = [System.Drawing.Color]::FromArgb(245, 245, 245)

$FontTitulo = New-Object System.Drawing.Font("Segoe UI", 11, [System.Drawing.FontStyle]::Bold)
$FontBotoes = New-Object System.Drawing.Font("Segoe UI", 9)
$FontSmall = New-Object System.Drawing.Font("Segoe UI", 8)

$Header = New-Object System.Windows.Forms.Label
$Header.Text = "Field Test Easy Tool`nDesigned by Paulo Cezar Almeida"
$Header.TextAlign = "MiddleCenter"
$Header.Size = New-Object System.Drawing.Size(480, 50)
$Header.Location = New-Object System.Drawing.Point(10, 10)
$Header.Font = $FontTitulo
$Form.Controls.Add($Header)

$StatusLabel = New-Object System.Windows.Forms.Label
$StatusLabel.Text = "Status: Waiting..."
$StatusLabel.Location = New-Object System.Drawing.Point(20, 70)
$StatusLabel.AutoSize = $true
$Form.Controls.Add($StatusLabel)

$StatusDot = New-Object System.Windows.Forms.Panel
$StatusDot.Size = New-Object System.Drawing.Size(12, 12)
$StatusDot.Location = New-Object System.Drawing.Point(140, 73)
$StatusDot.BackColor = "Gray"
$Form.Controls.Add($StatusDot)

$LogBox = New-Object System.Windows.Forms.TextBox
$LogBox.Multiline = $true
$LogBox.ReadOnly = $true
$LogBox.ScrollBars = "Vertical"
$LogBox.Size = New-Object System.Drawing.Size(440, 200)
$LogBox.Location = New-Object System.Drawing.Point(20, 610)
$LogBox.BackColor = "Black"
$LogBox.ForeColor = "White"
$LogBox.Font = New-Object System.Drawing.Font("Consolas", 12)
$LogBox.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$Form.Controls.Add($LogBox)

$BtnClear = New-Object System.Windows.Forms.Button
$BtnClear.Text = "Clear Log"
$BtnClear.Size = New-Object System.Drawing.Size(70, 22)
$BtnClear.Location = New-Object System.Drawing.Point(390, 585)
$BtnClear.Font = $FontSmall
$BtnClear.BackColor = "White"
$BtnClear.FlatStyle = "Flat"
$BtnClear.Add_Click({ $LogBox.Clear() })
$BtnClear.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$Form.Controls.Add($BtnClear)

$BtnSupport = New-Object System.Windows.Forms.Button
$BtnSupport.Text = "Support"
$BtnSupport.Size = New-Object System.Drawing.Size(70, 22)
$BtnSupport.Location = New-Object System.Drawing.Point(310, 585) 
$BtnSupport.Font = $FontSmall
$BtnSupport.BackColor = "White"
$BtnSupport.FlatStyle = "Flat"
$BtnSupport.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Right
$Form.Controls.Add($BtnSupport)

$BtnSupport.Add_Click({
    $SupportForm = New-Object System.Windows.Forms.Form
    $SupportForm.Text = "Support"
    $SupportForm.Size = New-Object System.Drawing.Size(350, 210)
    $SupportForm.StartPosition = "CenterParent" 
    $SupportForm.FormBorderStyle = "FixedDialog" 
    $SupportForm.MaximizeBox = $false
    $SupportForm.MinimizeBox = $false
    $SupportForm.BackColor = "White"

    # ARRAY SEGURO: Evita quebras de linha que derrubam o script
    $textoContato = @(
        "Paulo Cezar - Support"
        "Bugs n Suggestions please contact"
        "Developed by: Paulo Cezar Almeida"
		"Test Engineer"
        "E-mail: pauloalmeida1337@gmail.com"
    ) -join "`n"

    $TxtContact = New-Object System.Windows.Forms.Label
    $TxtContact.Text = $textoContato
    $TxtContact.Size = New-Object System.Drawing.Size(310, 110)
    $TxtContact.Location = New-Object System.Drawing.Point(20, 20)
    $TxtContact.Font = New-Object System.Drawing.Font("Segoe UI", 9.5, [System.Drawing.FontStyle]::Regular)
    $SupportForm.Controls.Add($TxtContact)

    $BtnClosePop = New-Object System.Windows.Forms.Button
    $BtnClosePop.Text = "Close"
    $BtnClosePop.Size = New-Object System.Drawing.Size(80, 25)
    $BtnClosePop.Location = New-Object System.Drawing.Point(125, 130)
    $BtnClosePop.FlatStyle = "Flat"
    $BtnClosePop.BackColor = "LightGray"
    $BtnClosePop.Add_Click({ $SupportForm.Close() })
    $SupportForm.Controls.Add($BtnClosePop)

    $SupportForm.ShowDialog()
})

function Write-Log($msg) {
    $LogBox.AppendText("$msg`r`n")
    $LogBox.SelectionStart = $LogBox.Text.Length
    $LogBox.ScrollToCaret()
}

$Timer = New-Object System.Windows.Forms.Timer
$Timer.Interval = 2000 
$Timer.Add_Tick({
    $state = & $Global:ADB_EXE get-state 2>$null
    if ($state -eq "device") { $StatusDot.BackColor = "Green"; $StatusLabel.Text = "Status: Connected" }
    else { $StatusDot.BackColor = "Red"; $StatusLabel.Text = "Status: Disconnected" }
})
$Timer.Start()

function Create-Button($text, $y, $color, $action) {
    $btn = New-Object System.Windows.Forms.Button
    $btn.Text = $text
    $btn.Size = New-Object System.Drawing.Size(440, 35)
    $btn.Location = New-Object System.Drawing.Point(20, $y)
    $btn.Font = $FontBotoes
    $btn.BackColor = $color
    $btn.FlatStyle = "Flat"
    $btn.Cursor = [System.Windows.Forms.Cursors]::Hand
    $btn.Add_Click($action)
    $Form.Controls.Add($btn)
}

function Get-OppoCustomOTP {
    # 1. Cria o Pop-up solicitando a Input Key ao usuário
    [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
    $PromptMessage = "Enter the key code from *#9900# menu:"
    $PopupTitle = "Samsung OTP Generator (new version)"
    $DefaultValue = "01569705" # Chave padrão que você usou no exemplo

    $ProvidedKey = [Microsoft.VisualBasic.Interaction]::InputBox($PromptMessage, $PopupTitle, $DefaultValue)

    # Valida se o usuário cancelou o pop-up ou deixou a caixa vazia
    if ([string]::IsNullOrWhiteSpace($ProvidedKey)) {
        Write-Log "[ERROR] OTP Generation failed. Key code not provided."
        return
    }

    Write-Log "[*] Input Key fornecida: '$ProvidedKey'"

    # 2. Configurações e Chave Secreta Estática (Convertida de Hex para Bytes)
    $SecretKeyHex = "120395F099840593405B03838449A72933484040A3034750C0403938290A293B"
    $SecretKeyBytes = [byte[]](0..(($SecretKeyHex.Length / 2) - 1) | ForEach-Object { 
        [Convert]::ToByte($SecretKeyHex.Substring(($_ * 2), 2), 16) 
    })

    $TimeStepX = 300
    $DigitDecimal = 1000000 # 10^6 para 6 dígitos

    # 3. Extração do Nonce (Equivalente ao providedKey.substring(2))
    $Nonce = ""
    if ($ProvidedKey.Length -ge 2) {
        $Nonce = $ProvidedKey.Substring(2)
    }

    # 4. Cálculo do TimeStep baseado no Unix Timestamp atual
    $CurrentTimestamp = [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
    $TimeStep = [Math]::Floor($CurrentTimestamp / $TimeStepX)
    $TimeHex = ([string]::Format("{0:X}", [long]$TimeStep)).PadLeft(16, '0')

    # 5. Validação se o nonce possui exatamente 6 dígitos numéricos
    $IsNumeric6Digits = ($Nonce.Length -eq 6) -and ($Nonce -match '^\d+$')

    if ($IsNumeric6Digits) {
        $MessageHex = $Nonce + $TimeHex
        $PaddingLength = 22
    } else {
        $MessageHex = $TimeHex
        $PaddingLength = 16
    }

    # Aplica o padding e converte a string Hex para array de Bytes
    $PaddedHex = $MessageHex.PadLeft($PaddingLength, '0')
    $MessageBytes = [byte[]](0..(($PaddedHex.Length / 2) - 1) | ForEach-Object { 
        [Convert]::ToByte($PaddedHex.Substring(($_ * 2), 2), 16) 
    })

    # 6. Cálculo do HMAC-SHA256
    $Hmac = New-Object System.Security.Cryptography.HMACSHA256
    $Hmac.Key = $SecretKeyBytes
    $HmacHash = $Hmac.ComputeHash($MessageBytes)

    # 7. Truncamento Dinâmico (Dynamic Truncation)
    $Offset = $HmacHash[-1] -band 0x0F
    $Byte1 = $HmacHash[$Offset]
    $Byte2 = $HmacHash[$Offset + 1]
    $Byte3 = $HmacHash[$Offset + 2]
    $Byte4 = $HmacHash[$Offset + 3]

    $LargeInt = ([int]$Byte1 -shl 24) -bor ([int]$Byte2 -shl 16) -bor ([int]$Byte3 -shl 8) -bor [int]$Byte4
    $LargeInt = $LargeInt -band 0x7FFFFFFF

    # 8. Gera o token final de 6 dígitos
    $OtpValue = $LargeInt % $DigitDecimal
    $FinalOtp = ($OtpValue.ToString()).PadLeft(6, '0')

    Write-Log "[OK] Final OTP: $FinalOtp"
}

function Get-SamsungLegacyOTP {
    # 1. Cria o Pop-up solicitando a Input Key do menu *#9900#
    [void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')
    $PromptMessage = "Enter the key code from *#9900# menu:"
    $PopupTitle = "Samsung Legacy OTP"
    
    $ProvidedKey = [Microsoft.VisualBasic.Interaction]::InputBox($PromptMessage, $PopupTitle, "")

    if ([string]::IsNullOrWhiteSpace($ProvidedKey)) {
        Write-Log "[ERROR] OTP Generation failed. Key code not provided."
        return
    }

    Write-Log "--- SAMSUNG LEGACY OTP GEN ---"
    Write-Log "[*] Base OTP Key: '$ProvidedKey'"

    # Loop equivalente ao: for (var i = -1; i < 3; i++)
    for ($i = -1; $i -lt 3; $i++) {
        
        # 2. Subtrai os minutos do offset do tempo UTC atual
        $TargetDate = ([DateTime]::UtcNow).AddMinutes(-$i)
        
        # Monta a string no formato exato do JS: YYMMmmDDHH (Ano, Mês, Minuto, Dia, Hora)
        $YearStr   = ($TargetDate.ToString("yy")).PadLeft(2, '0')
        $MonthStr  = ($TargetDate.Month.ToString()).PadLeft(2, '0')
        $MinuteStr = ($TargetDate.Minute.ToString()).PadLeft(2, '0')
        $DayStr    = ($TargetDate.Day.ToString()).PadLeft(2, '0')
        $HourStr   = ($TargetDate.Hour.ToString()).PadLeft(2, '0')
        
        $DateString = "$YearStr$MonthStr$MinuteStr$DayStr$HourStr"
        $FullArgString = $ProvidedKey + $DateString

        # 3. Matemática do HashCode Corrigida
        $nHashValue = 0L # Começamos com um inteiro de 64-bit (Long)
        
        foreach ($char in $FullArgString.ToCharArray()) {
            $charCode = [int][char]$char
            
            # Passo A: O JS força o bitwise shift em um Int32. Fazemos o mesmo aqui.
            $shifted = [int32]$nHashValue -shl 5
            
            # Passo B: A soma. Usamos [long] para impedir que o PowerShell gere um 
            # erro de OverflowException quando a matemática passar de 2.1 bilhões.
            $sum = [long]$shifted + [long]$nHashValue + [long]$charCode
            
            # Passo C: O Equivalente ao JS ">> 32" ou ">> 0".
            # O BitConverter extrai os 32 bits exatos da memória, descartando o excedente 
            # e forçando o número a ser um Int32 com sinal, igual ao navegador.
            $bytes = [BitConverter]::GetBytes($sum)
            $nHashValue = [BitConverter]::ToInt32($bytes, 0)
        }

        # Equivalente ao Math.abs(nHashValue)
        $FinalHash = [Math]::Abs($nHashValue)

        # Exibe o resultado de cada offset no terminal de Logs
        Write-Log "Offset: $i min | Key: $FinalHash"
    }
    Write-Log "------------------------------"
}

# --- BOTÕES ---

Create-Button "1. Info Extractor" 105 "LightBlue" {
    Write-Log "----------------------------------"
    $devId = & $Global:ADB_EXE shell getprop ro.boot.chipid
    if ([string]::IsNullOrWhiteSpace($devId)) { $devId = & $Global:ADB_EXE get-serialno }
    Write-Log "Serial Number: $($devId.Trim())"
    $engInfo = & $Global:ADB_EXE shell "dumpsys engineer --query_indicate_info"
    $engInfo | Select-String "IMEI1:", "GUID:" | ForEach-Object { Write-Log $_.ToString().Trim() }
    $dcsInfo = & $Global:ADB_EXE shell "dumpsys activity provider DcsContentProvider env"
    $dcsInfo | Select-String "DUID:", "OtaVersion:", "FactoryVersion:" | ForEach-Object { Write-Log $_.ToString().Trim() }
    Write-Log "----------------------------------"
}

Create-Button "2. Oppo Log Puller (QCOM/MTK)" 155 "White" {
    $dest = $Global:DEST_ROOT
    [System.IO.Directory]::SetCurrentDirectory($dest)

    Write-Log "[0%] Initializing Log Puller..."

    $title = "Oppo Automation Tool"
    $msg = "Copy the latest screenshot?"
    $buttons = [System.Windows.Forms.MessageBoxButtons]::YesNo
    $icon = [System.Windows.Forms.MessageBoxIcon]::Question
    
    $decision = [System.Windows.Forms.MessageBox]::Show($msg, $title, $buttons, $icon)

    Write-Log "[10%] Searching for latest log on device..."
    $latestRaw = & $Global:ADB_EXE shell "ls -t $Global:LOG_KIT_PATH | head -n 1"
    if ([string]::IsNullOrWhiteSpace($latestRaw)) { Write-Log "[ERROR] Log not found."; return }
    $latest = $latestRaw.Trim()
    
    $localFolderPath = Join-Path $dest $latest
    $zipDestination = "$localFolderPath.zip"
    
    Write-Log "[30%] Downloading Log: $latest (Wait...)"
    $pullProcess = Start-Process -FilePath $Global:ADB_EXE -ArgumentList "pull `"$Global:LOG_KIT_PATH/$latest`" `"$localFolderPath`"" -NoNewWindow -PassThru -Wait
    
    if ($pullProcess.ExitCode -ne 0) {
        Write-Log "[ERROR] Failed to transfer. Verify device connection."
        return
    }

    if ($decision -eq [System.Windows.Forms.DialogResult]::Yes) {
        Write-Log "[60%] Fetching latest screenshot from device..."
        $ssRaw = & $Global:ADB_EXE shell "ls -t /sdcard/Pictures/Screenshots | head -n 1"
        if (-not [string]::IsNullOrWhiteSpace($ssRaw)) {
            $ssFile = $ssRaw.Trim()
            $localSSPath = Join-Path $dest $ssFile
            
            Start-Process -FilePath $Global:ADB_EXE -ArgumentList "pull `"/sdcard/Pictures/Screenshots/$ssFile`" `"$localSSPath`"" -NoNewWindow -Wait
            
            if (Test-Path -LiteralPath $localSSPath) { 
                Move-Item -LiteralPath $localSSPath -Destination $localFolderPath -Force 
            }
        }
    } else {
        Write-Log "[60%] Skipping screenshot extraction (User choice)."
    }
    
    if (Test-Path -LiteralPath $localFolderPath) {
        Write-Log "[80%] Compressing files into ZIP..."
        
        Compress-Archive -LiteralPath $localFolderPath -DestinationPath $zipDestination -Force
        Remove-Item -LiteralPath $localFolderPath -Recurse -Force
        
        Write-Log "[100%] [OK] Success: $dest"
    } else {
        Write-Log "[ERROR] Failed to locate pulled folder to compress."
    }
}

Create-Button "3. UNISOC Log Puller" 195 "White" {
    Write-Log "Extracting UNISOC..."
    $time = Get-Date -Format "yyyyMMdd_HHmm"
    
    # Cria os caminhos absolutos garantindo a pasta do botão direito
    $tempPath = Join-Path -Path $Global:DEST_ROOT -ChildPath "ylog_temp"
    $zipPath = Join-Path -Path $Global:DEST_ROOT -ChildPath "Log_UNISOC_$time.zip"
    
    # Usa os caminhos blindados para extrair, zipar e limpar
    & $Global:ADB_EXE pull $Global:UNISOC_PATH "$tempPath"
    Compress-Archive -Path "$tempPath" -DestinationPath "$zipPath" -Force
    Remove-Item -Recurse -Force "$tempPath"
    
    Write-Log "[OK] Log_UNISOC_$time.zip created."
}

Create-Button "4. Samsung Log Puller" 235 "White" {
    Write-Log "Extracting Samsung..."
    $time = Get-Date -Format "yyyyMMdd_HHmm"
    
    # Cria os caminhos absolutos garantindo a pasta do botão direito
    $tempPath = Join-Path -Path $Global:DEST_ROOT -ChildPath "samsung_temp"
    $zipPath = Join-Path -Path $Global:DEST_ROOT -ChildPath "Log_Samsung_$time.zip"
    
    # Usa os caminhos blindados para extrair, zipar e limpar
    & $Global:ADB_EXE pull $Global:SAMSUNG_PATH "$tempPath"
    Compress-Archive -Path "$tempPath" -DestinationPath "$zipPath" -Force
    Remove-Item -Recurse -Force "$tempPath"
    
    Write-Log "[OK] Log_Samsung_$time.zip created."
}

Create-Button "5. Multiple Screenshots" 275 "White" {
    $time = Get-Date -Format "yyyyMMdd_HHmmss"
    $filename = "screen_$time.png"
    
    # Junta a pasta exata do botão direito com o nome do arquivo
    $fullPath = Join-Path -Path $Global:DEST_ROOT -ChildPath $filename
    
    # 1. Captura a screenshot do celular e salva no PC
    Start-Process -FilePath $Global:ADB_EXE -ArgumentList "exec-out screencap -p" -NoNewWindow -RedirectStandardOutput "$fullPath" -Wait
    
    # 2. VALIDAÇÃO E COPIAR PARA O CTRL+C
    if (Test-Path -LiteralPath $fullPath) {
        try {
            # Carrega a imagem na memória como um objeto System.Drawing.Image
            $ImageObject = [System.Drawing.Image]::FromFile($fullPath)
            
            # Copia o objeto de imagem direto para a área de transferência do Windows (Ctrl+C)
            [System.Windows.Forms.Clipboard]::SetImage($ImageObject)
            
            # Libera o arquivo para não travar o sistema
            $ImageObject.Dispose()
            
            Write-Log "[OK] Screenshot saved and Copied to Clipboard!"
        }
        catch {
            Write-Log "[WARN] Screenshot Saved, but Failed to copy to Clipboard."
        }
    } else {
        Write-Log "[ERROR] Failed to screenshot."
    }
}


Create-Button "6. Files Explorer" 355 "White" {
    Write-Log "Opening custom file browser..."

    # 1. Cria a janela do File Explorer customizado
    $ExpForm = New-Object System.Windows.Forms.Form
    $ExpForm.Text = "Android File Explorer"
    $ExpForm.Size = New-Object System.Drawing.Size(450, 550)
    $ExpForm.StartPosition = "CenterParent"
    $ExpForm.FormBorderStyle = "FixedDialog"
    $ExpForm.MaximizeBox = $false
    
    # 2. Barra de endereço para mostrar o caminho atual
    $TxtPath = New-Object System.Windows.Forms.TextBox
    $TxtPath.Location = New-Object System.Drawing.Point(10, 10)
    $TxtPath.Size = New-Object System.Drawing.Size(415, 25)
    $TxtPath.ReadOnly = $true
    $TxtPath.BackColor = "White"
    $ExpForm.Controls.Add($TxtPath)

    # 3. Lista interativa (ListView) com suporte a multiseleção
    $ListView = New-Object System.Windows.Forms.ListView
    $ListView.Location = New-Object System.Drawing.Point(10, 40)
    $ListView.Size = New-Object System.Drawing.Size(415, 400)
    $ListView.View = [System.Windows.Forms.View]::Details
    $ListView.FullRowSelect = $true
    $ListView.MultiSelect = $true 
    $ListView.GridLines = $true
    $ListView.Columns.Add("Name", 390) | Out-Null
    $ExpForm.Controls.Add($ListView)

    # 4. Botão de Extração
    $BtnPull = New-Object System.Windows.Forms.Button
    $BtnPull.Location = New-Object System.Drawing.Point(10, 450)
    $BtnPull.Size = New-Object System.Drawing.Size(200, 40)
    $BtnPull.Text = "Pull Selected to PC"
    $BtnPull.BackColor = "LightBlue"
    $BtnPull.FlatStyle = "Flat"
    $ExpForm.Controls.Add($BtnPull)

    # 5. Botão de Fechar
    $BtnClose = New-Object System.Windows.Forms.Button
    $BtnClose.Location = New-Object System.Drawing.Point(225, 450)
    $BtnClose.Size = New-Object System.Drawing.Size(200, 40)
    $BtnClose.Text = "Close"
    $BtnClose.BackColor = "LightGray"
    $BtnClose.FlatStyle = "Flat"
    $BtnClose.Add_Click({ $ExpForm.Close() })
    $ExpForm.Controls.Add($BtnClose)

    # Variavel de escopo de script para o caminho atualizar nos eventos
    $script:currentRemotePath = "/sdcard/"
    
    # Função interna para varrer o diretório via ADB e preencher a lista
    $LoadDirectory = {
        $TxtPath.Text = $script:currentRemotePath
        $ListView.Items.Clear()
        
        $rawList = & $Global:ADB_EXE shell "ls -p `"$script:currentRemotePath`""
        
        if ($script:currentRemotePath -ne "/sdcard/" -and $script:currentRemotePath -ne "/") {
            $ListView.Items.Add("[..] Back") | Out-Null
        }
        
        foreach ($item in $rawList) {
            $trimItem = $item.Trim()
            if (-not [string]::IsNullOrWhiteSpace($trimItem)) {
                $ListView.Items.Add($trimItem) | Out-Null
            }
        }
    }

    # 6. Evento de Duplo Clique (Navegação instantânea)
    $ListView.Add_DoubleClick({
        if ($ListView.SelectedItems.Count -eq 0) { return }
        $selected = $ListView.SelectedItems[0].Text
        
        if ($selected -eq "[..] Back") {
            $parts = $script:currentRemotePath.TrimEnd('/') -split '/'
            $script:currentRemotePath = ($parts[0..($parts.Length - 2)] -join '/') + "/"
            if ($script:currentRemotePath -eq "/") { $script:currentRemotePath = "/sdcard/" }
            &$LoadDirectory
        }
        elseif ($selected.EndsWith("/")) {
            $script:currentRemotePath = "$script:currentRemotePath$selected"
            &$LoadDirectory
        }
    })

    # 7. Evento do Botão Pull (Com janela de destino customizada)
    $BtnPull.Add_Click({
        if ($ListView.SelectedItems.Count -eq 0) { return }

        # --- JANELA DE DESTINO ---
        $DestForm = New-Object System.Windows.Forms.Form
        $DestForm.Text = "Destination Path"
        $DestForm.Size = New-Object System.Drawing.Size(460, 150)
        $DestForm.StartPosition = "CenterParent"
        $DestForm.FormBorderStyle = "FixedDialog"
        $DestForm.MaximizeBox = $false
        $DestForm.MinimizeBox = $false
        $DestForm.BackColor = "White"

        $LblDest = New-Object System.Windows.Forms.Label
        $LblDest.Text = "Paste the folder path or browse:"
        $LblDest.Location = New-Object System.Drawing.Point(15, 10)
        $LblDest.AutoSize = $true
        $DestForm.Controls.Add($LblDest)

        $TxtDest = New-Object System.Windows.Forms.TextBox
        $TxtDest.Location = New-Object System.Drawing.Point(15, 30)
        $TxtDest.Size = New-Object System.Drawing.Size(330, 25)
        # Preenche com o Desktop por padrão
        $TxtDest.Text = [Environment]::GetFolderPath("Desktop")
        $DestForm.Controls.Add($TxtDest)

        $BtnBrowse = New-Object System.Windows.Forms.Button
        $BtnBrowse.Text = "Browse..."
        $BtnBrowse.Location = New-Object System.Drawing.Point(355, 29)
        $BtnBrowse.Size = New-Object System.Drawing.Size(75, 24)
        $BtnBrowse.FlatStyle = "Flat"
        $BtnBrowse.BackColor = "LightGray"
        $BtnBrowse.Add_Click({
            $diag = New-Object System.Windows.Forms.FolderBrowserDialog
            if ($diag.ShowDialog() -eq "OK") {
                $TxtDest.Text = $diag.SelectedPath
            }
        })
        $DestForm.Controls.Add($BtnBrowse)

        $BtnOk = New-Object System.Windows.Forms.Button
        $BtnOk.Text = "Extract"
        $BtnOk.Location = New-Object System.Drawing.Point(135, 70)
        $BtnOk.Size = New-Object System.Drawing.Size(85, 30)
        $BtnOk.BackColor = "LightBlue"
        $BtnOk.FlatStyle = "Flat"
        $BtnOk.DialogResult = [System.Windows.Forms.DialogResult]::OK
        $DestForm.Controls.Add($BtnOk)

        $BtnCancelDest = New-Object System.Windows.Forms.Button
        $BtnCancelDest.Text = "Cancel"
        $BtnCancelDest.Location = New-Object System.Drawing.Point(230, 70)
        $BtnCancelDest.Size = New-Object System.Drawing.Size(85, 30)
        $BtnCancelDest.BackColor = "White"
        $BtnCancelDest.FlatStyle = "Flat"
        $BtnCancelDest.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
        $DestForm.Controls.Add($BtnCancelDest)

        if ($DestForm.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $destPath = $TxtDest.Text
            
            if (-not (Test-Path -LiteralPath $destPath)) {
                try {
                    New-Item -ItemType Directory -Force -Path $destPath | Out-Null
                } catch {
                    [System.Windows.Forms.MessageBox]::Show("Invalid path or access denied.", "Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Error)
                    return
                }
            }
            
            $successCount = 0
            foreach ($item in $ListView.SelectedItems) {
                $itemName = $item.Text
                if ($itemName -ne "[..] Back") {
                    $remoteTarget = "$script:currentRemotePath$itemName"
                    Write-Log "Pulling: $remoteTarget"
                    
                    & $Global:ADB_EXE pull "$remoteTarget" "$destPath\"
                    $successCount++
                }
            }
            Write-Log "[OK] $successCount item(s) copied to $destPath."
            [System.Windows.Forms.MessageBox]::Show("$successCount item(s) copied to:`n$destPath", "Download Complete", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Information)
        }
    })

    # Executa o carregamento inicial e abre a janela customizada
    &$LoadDirectory
    [void]$ExpForm.ShowDialog()
}

Create-Button "8. Samsung OTP Generator (New version)" 395 "White" {
    # Chama a função que abre o pop-up e processa a lógica
    Get-OppoCustomOTP
}

Create-Button "9. Samsung OTP Generator (Legacy version)" 435 "White" {
    Get-SamsungLegacyOTP
}

Create-Button "Turn OFF device" 480 "LightCoral" {
    & $Global:ADB_EXE shell reboot -p
    Write-Log "[OK] Command executed."
}

Create-Button "Exit" 525 "LightGray" { $Form.Close() }

$Form.Add_Shown({ $Form.Activate() })
[void]$Form.ShowDialog()