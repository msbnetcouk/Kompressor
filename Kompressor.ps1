### VARIABLES #######################################################################

$bf6 = ':9996'
$bf7 = ':9997'
$b6 = '9996'
$b7 = '9997'
$bfWait = '5000'
$script:boundary = [System.Guid]::NewGuid().ToString("N")
$contentType = "multipart/form-data; boundary=`"$script:boundary`""
# $bfver = '0.36.0'
$bfver = '0.313.0' 
$bfkey = '00000000000000000000000000000000'
$lf = "`r`n"
$script:network = 'msbnet'
$snapA = 'CURRENT'
$snapB = 'CANDIDATE'
$blurb = '[ msbnet.co.uk::Kompressor - network supercharger ]'
$prereqFiles = 'json\template_tf.json', 'json\template_wi1.json', 'json\template_wi2.json'

### /VARIABLES ######################################################################









### CLASSES #########################################################################

class bfField {
    [array]$Section
    bfField([string]$FieldName, [string]$FieldValue) {
        [string]$script:FieldBoundary = $script:boundary
        $this.Section = @(
            "--$script:FieldBoundary",
            "Content-Disposition: form-data; name=`"$FieldName`"",
            '',
            $FieldValue
        )
    }
    bfField([string]$FieldName, [string]$FieldValue, [string]$FileName) {
        [string]$script:FieldBoundary = $script:boundary
        $this.Section = @(
            "--$script:FieldBoundary",
            "Content-Disposition: form-data; name=`"$FieldName`"; filename=`"$FileName`"",
            '',
            $FieldValue
        )
    }
    bfField([int]$one, [string]$FieldName, [string]$FieldValue, [string]$FileName) {
        [string]$script:FieldBoundary = $script:boundary
        $this.Section = @(
            "--$script:FieldBoundary",
            "Content-Disposition: form-data; name=`"$FieldName`"; filename=`"$FileName`"",
            "Content-Type: application/octet-stream",
            '',
            $FieldValue
        )
    }    
    bfField() {
        [string]$script:FieldBoundary = $script:boundary
        $this.Section = @(
            "--$script:FieldBoundary--"
        )
    }
}

### /CLASSES ########################################################################










### FUNCTIONS #######################################################################

function Test-PreReq([string]$arg1)
{
    # $ENV:PATH="$ENV:PATH;C:\Program Files\7-Zip"
    if ($null -eq (Get-Command $arg1 -ErrorAction SilentlyContinue)) 
    { 
        $script:bfTextBox.AppendText("Unable to find $arg1 in your PATH"+$lf)
    }
}

Function Test-TCPPort
{
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$True,Position=1)]
    [string]$IPAddress,
    [Parameter(Mandatory=$True,Position=2)]
    [string]$Port,
    [Parameter(Mandatory=$True,Position=3)]
    [int]$Timeout
)
# Thanks Carl - https://www.jagerteg.se/2017/10/06/script-test-tcp-port/

    $TCPObject = new-Object system.Net.Sockets.TcpClient
    if($TCPObject.ConnectAsync($IPAddress,$Port).Wait($Timeout))
    {
        $TCPObject.Close()
        return $true
    }
    else
    {
        $TCPObject.Close()
        return $false
    }
}

function Get-Networks
{
    $bfheaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $bfheaders.Add("X-Batfish-Version", $bfver)
    $bfheaders.Add("X-Batfish-Apikey", $bfkey)
    $dirnets = Invoke-RestMethod -Uri http://$script:bfsrv6/v2/networks -Headers $bfheaders -Method GET
    $script:bfTextBox.AppendText("List networks..."+$lf+$lf)
    $script:bfTextBox.AppendText($dirnets.name+$lf)
    $script:bfTextBox.AppendText($dirnets+$lf)
}

function Set-Network([string]$arg1)
{
    $error.clear()
    $bfheaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $bfheaders.Add("X-Batfish-Version", $bfver)
    $bfheaders.Add("X-Batfish-Apikey", $bfkey)
    try {
        Invoke-RestMethod -Uri http://$script:bfsrv6/v2/networks/$arg1 -Headers $bfheaders -Method GET
    } catch {
        $_.Exception.Response.StatusCode.value__ -eq 404
        New-Network $script:network
    }
}

function New-Network([string]$arg1)
{
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Accept-Encoding", 'gzip, deflate')
    $headers.Add("Accept", '*/*')
    [array]$NewNet = [bfField]::New('apikey', $bfkey)
    [array]$NewNet += [bfField]::New('networkname', $script:network)
    [array]$NewNet += [bfField]::New('version', $bfver)
    [array]$NewNet += [bfField]::New()        
    $newnetreq = Invoke-RestMethod -Uri "http://$script:bfsrv7/batfishworkmgr/initnetwork" -Headers $headers -ContentType $contentType -Method POST -Body ($NewNet.Section -join $lf)
    $script:bfTextBox.AppendText($lf+"$arg1 CFG:  Creating network... "+$newnetreq+$lf)

}

<#
function New-Snapshot([string]$arg1, [string]$arg2)
{
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Accept-Encoding", 'gzip, deflate')
    $headers.Add("Accept", '*/*')

    [array]$NewSnap = [bfField]::New('apikey', $bfkey)
    [array]$NewSnap += [bfField]::New('networkname', $script:network)
    [array]$NewSnap += [bfField]::New('snapshotname', $arg1)
    [array]$NewSnap += [bfField]::New(1, 'zipfile', $arg2, 'filename')
    [array]$NewSnap += [bfField]::New('version', $bfver)
    [array]$NewSnap += [bfField]::New()

    $uploadSnapshot = Invoke-RestMethod -Uri http://$script:bfsrv7/batfishworkmgr/uploadsnapshot -Headers $headers -ContentType $contentType -Method POST -Body ($NewSnap.Section -join $lf)
    $script:bfTextBox.AppendText($lf+"$snapA CFG:  Uploading question... "+$uploadSnapshot+$lf)
}
#>

function New-SnapshotCurl([string]$arg1)
{
    # Curl seems to need this...
    $ErrorActionPreference='silentlycontinue'
    # Use curl.exe -x 127.0.0.1:8888 for proxy
    $curlResponse = curl.exe -F apikey="$bfkey" -F networkname="$script:network" -F snapshotname="$arg1" -F "zipfile=@$env:TEMP\Kompressor\$script:network\$arg1.zip" -F version="$bfver" $script:bfsrv7/batfishworkmgr/uploadsnapshot
    $script:bfTextBox.AppendText("$arg1 CFG: Uploading to Batfish via Curl... " + $curlResponse)

    # Queue the workitem

    $wiGUID2 = [System.Guid]::NewGuid().ToString()
    $workItem2 = Get-Content json\template_wi2.json -raw | ConvertFrom-Json
    $workItem2.containerName = $script:network
    $workItem2.id = $wiGUID2
    $workItem2.requestParams.testrig = $arg1
    $workItem2.testrigName = $arg1
    $bodyWorkItem2 = $workItem2 | ConvertTo-Json -depth 5 -Compress

    [array]$NewField4 = [bfField]::New('workitem', $bodyWorkItem2)
    [array]$NewField4 += [bfField]::New('apikey', $bfkey)
    [array]$NewField4 += [bfField]::New('version', $bfver)
    [array]$NewField4 += [bfField]::New()

    $queueWorkItem2 = Invoke-RestMethod -Uri http://$script:bfsrv7/batfishworkmgr/queuework -Headers $headers -ContentType $contentType -Method POST -Body ($NewField4.section -join $lf)
    
    $script:bfTextBox.AppendText($lf+"$arg1 CFG: Queuing workitem... "+$queueWorkItem2)

    # Get work status

    [array]$NewField5 = [bfField]::New('apikey', $bfkey)
    [array]$NewField5 += [bfField]::New('workid', $wiGUID2)
    [array]$NewField5 += [bfField]::New('version', $bfver)
    [array]$NewField5 += [bfField]::New()

    do { 
        $script:getWorkStatusNSC = Invoke-RestMethod -Uri "http://$script:bfsrv7/batfishworkmgr/getworkstatus" -Headers $headers -ContentType $contentType -Method POST -Body ($NewField5.section -join $lf)
    }
    until (
        $script:getWorkStatusNSC.workstatus -eq 'TERMINATEDNORMALLY' -or 
        $script:getWorkStatusNSC.workstatus -eq 'TERMINATEDABNORMALLY' -or 
        $script:getWorkStatusNSC -eq 'failure'
    )    
    $script:bfTextBox.AppendText($lf+"$arg1 CFG: Get work status... "+$script:getWorkStatusNSC)

}

function Remove-Snapshot([string]$arg1, [string]$arg2)
{
    $bfheaders = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $bfheaders.Add("X-Batfish-Version", $bfver)
    $bfheaders.Add("X-Batfish-Apikey", $bfkey)
    Invoke-RestMethod -Uri http://$script:bfsrv6/v2/networks/$arg1/snapshots/$arg2 -Headers $bfheaders -Method DELETE
}

function New-Question([string]$arg1,[string]$arg2,[string]$arg3,[string]$arg4)
{
    $headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $headers.Add("Accept-Encoding", 'gzip, deflate')
    $headers.Add("Accept", '*/*')
    $testFilter = Get-Content json\template_tf.json -raw | ConvertFrom-Json
    $tfguid = "__testFilters_"+[System.Guid]::NewGuid().ToString()
    $startLoc = $textBoxbfq6.Text
    $testFilter.instance.instanceName = $tfguid
    $testFilter.instance.variables.filters.value = $arg4
    $testFilter.instance.variables.headers.value.applications = @( $arg3 )
    $testFilter.instance.variables.headers.value.dstIps = $arg2
    $testFilter.instance.variables.headers.value.srcIps = $arg1
    $testFilter.instance.variables.nodes.value = $script:network
    $testFilter.instance.variables.startLocation.value = "@enter($script:network[$startLoc])"
    $bfmoo = $testFilter | ConvertTo-Json -depth 5 | Format-Json2
    
    [array]$NewField = [bfField]::New('apikey', $bfkey)
    [array]$NewField += [bfField]::New('networkname', $script:network)
    [array]$NewField += [bfField]::New('questionname', $testFilter.instance.instanceName)
    [array]$NewField += [bfField]::New('file', $bfmoo, 'question')
    [array]$NewField += [bfField]::New('file2', '{}', 'parameters')
    [array]$NewField += [bfField]::New('version', $bfver)
    [array]$NewField += [bfField]::New()

    $uploadquestion = Invoke-RestMethod -Uri "http://$script:bfsrv7/batfishworkmgr/uploadquestion" -Headers $headers -ContentType $contentType -Method POST -Body ($NewField.section -join $lf)
    $script:bfTextBox.AppendText($lf+$lf+"*** Uploading question... "+$uploadquestion)
    $tttj = $testFilter.instance.instanceName

    # Queue the workitem

    $wiGUID = [System.Guid]::NewGuid().ToString()
    $workItem = Get-Content json\template_wi1.json -raw | ConvertFrom-Json
    $workItem.containerName = $script:network
    $workItem.id = $wiGUID
    $workItem.requestParams.questionname = $testFilter.instance.instanceName
    $workItem.requestParams.testrig = $textBoxbfq5.Text
    $workItem.testrigName = $textBoxbfq5.Text
    $bodyWorkItem = $workItem | ConvertTo-Json -depth 5 -Compress

    [array]$NewField2 = [bfField]::New('workitem', $bodyWorkItem)
    [array]$NewField2 += [bfField]::New('apikey', $bfkey)
    [array]$NewField2 += [bfField]::New('version', $bfver)
    [array]$NewField2 += [bfField]::New()

    $queueWorkItem = Invoke-RestMethod -Uri "http://$script:bfsrv7/batfishworkmgr/queuework" -Headers $headers -ContentType $contentType -Method POST -Body ($NewField2.section -join $lf)
    $script:bfTextBox.AppendText($lf+"*** Queuing workitem... "+$queueWorkItem)

    # Get work status

    [array]$NewField3 = [bfField]::New('apikey', $bfkey)
    [array]$NewField3 += [bfField]::New('workid', $wiGUID)
    [array]$NewField3 += [bfField]::New('version', $bfver)
    [array]$NewField3 += [bfField]::New()

    do { 
        $script:getWorkStatusNQ = Invoke-RestMethod -Uri "http://$script:bfsrv7/batfishworkmgr/getworkstatus" -Headers $headers -ContentType $contentType -Method POST -Body ($NewField3.section -join $lf)
    }
    until (
        $script:getWorkStatusNQ.workstatus -eq 'TERMINATEDNORMALLY' -or 
        $script:getWorkStatusNQ.workstatus -eq 'TERMINATEDABNORMALLY' -or 
        $script:getWorkStatusNQ -eq 'failure'
    )

    $script:bfTextBox.AppendText($lf+"*** Get work status... "+$script:getWorkStatusNQ)
    
    # Get the results

    $snapshot = $textBoxbfq5.text
    $bf2headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
    $bf2headers.Add("X-Batfish-Version", $bfver)
    $bf2headers.Add("X-Batfish-Apikey", $bfkey)
    $getanswer = Invoke-RestMethod -Uri "http://$script:bfsrv6/v2/networks/$script:network/questions/$tttj/answer?snapshot=$snapshot" -Headers $bf2headers -Method GET
    $script:bfTextBox.AppendText($lf+"*** Getting answer... "+$getanswer.status+" - "+$getanswer.summary.notes)
    $script:bfTextBox.AppendText($lf+$lf+$getanswer.answerElements.rows.Action+" - "+$getanswer.answerElements.rows.Line_Content+$lf)
}

function New-ZipSnap([string]$arg1, [object]$arg2) {
    if ((Test-Path $env:TEMP\Kompressor -PathType Any) -eq $true) {
        Remove-Item -Recurse -Path "$env:TEMP\Kompressor"
        $script:bfTextBox.AppendText($lf+"$arg1 CFG: Purging temp directory " + "$env:TEMP\Kompressor" + $lf)
    }
    $script:bfTextBox.AppendText("$arg1 CFG: Creating temp directory " + "$env:TEMP\Kompressor" + $lf)
    New-Item -ItemType "directory" -Force -Path $env:TEMP\Kompressor\$script:network\$arg1\configs
    
    $script:bfTextBox.AppendText("$arg1 CFG: Copying " + $arg2.FileName + "..." + $lf)
    Copy-Item $arg2.FileName -Force -Destination $env:TEMP\Kompressor\$script:network\$arg1\configs
    
    # Compress-Archive fscks the zip file up - back slashes instead of forward slashes - so we're using 7zip
    # Compress-Archive -Force -Path $env:TEMP\Kompressor\$network\BASE -DestinationPath $env:TEMP\Kompressor\$network\BASE.zip
    
    $zipResponse = "7z a $env:TEMP\Kompressor\$script:network\$arg1.zip $env:TEMP\Kompressor\$script:network\$arg1\"
    Invoke-Expression $zipResponse
    $script:bfTextBox.AppendText("$arg1 CFG: Compressing via 7zip... $env:TEMP\Kompressor\$script:network\$arg1 " + $lf)
}

function Format-Json2([Parameter(Mandatory, ValueFromPipeline)][String] $json) {
    $indent = 0;
    ($json -Split "`n" | ForEach-Object {
        if ($_ -match '[\}\]]\s*,?\s*$') {
            # This line ends with ] or }, decrement the indentation level
            $indent--
        }
        $line = ('  ' * $indent) + $($_.TrimStart() -replace '":  (["{[])', '": $1' -replace ':  ', ': ')
        if ($_ -match '[\{\[]\s*$') {
            # This line ends with [ or {, increment the indentation level
            $indent++
        }
        $line
    }) -Join "`n"
}

### /FUNCTIONS ######################################################################











Add-Type -AssemblyName System.Windows.Forms

# Main form
$form = New-Object System.Windows.Forms.Form
$form.Text = $blurb
$form.Size = '1600,900'
$form.StartPosition = 'CenterScreen'
$form.AutoSize = $true
$form.AutoScale = $true
$form.AutoScaleMode = 'Font'
$form.AllowDrop = $true
# $form.FormBorderStyle = 'Sizable'
# $form.DesktopBounds
$form.Opacity = .99


# Create the CURRENT/BASE file browse button
$bfCURbrowseButton = New-Object System.Windows.Forms.Button
$bfCURbrowseButton.Location = '10,10'
$bfCURbrowseButton.Size = '75,25'
$bfCURbrowseButton.Text = "$snapA CFG..."
$bfCURbrowseButton.AutoSize = $true
$bfCURbrowseButton.Add_Click(
    {
        $script:FileBrowserA = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
            InitialDirectory = [Environment]::GetFolderPath('Desktop') 
            Filter = 'Configs (*.cfg)|*.cfg'
        }
        $null = $FileBrowserA.ShowDialog() 
        $bflinecountA = (Get-Content $FileBrowserA.FileName)
        $bfCURLabel.Text = $FileBrowserA.FileName + " - " + $bflinecountA.count + " lines"
    }
)
$form.Controls.Add($bfCURbrowseButton)


# Initialise BASE/CURRENT snapshot button
$bfCURinitButton = New-Object System.Windows.Forms.Button
$bfCURinitButton.Location = '10,60'
$bfCURinitButton.Size = '75,25'
$bfCURinitButton.Text = "Initialise..."
$bfCURinitButton.AutoSize = $true
$bfCURinitButton.Add_Click(
    {
        # $ts = Get-Date -Format "HH:mm:ss:fff"
        $script:bfsrv = $textBoxbfq7.text
        $script:bfsrv6 = $script:bfsrv+$bf6
        $script:bfsrv7 = $script:bfsrv+$bf7
        $script:network = $textBoxbfq8.text
        
        foreach ($pFile in $prereqFiles) {
            if (!(Test-Path $pFile -PathType Leaf) -eq $true) {
                $script:bfTextBox.AppendText($lf+"$pFile not found!"+$lf)
            }
        }

        if (!(Test-TCPPort -IPAddress $script:bfsrv -Port $b6 -Timeout $bfWait) -eq $true -or
        (!(Test-TCPPort -IPAddress $script:bfsrv -Port $b7 -Timeout $bfWait) -eq $true))
        {
            $script:bfTextBox.AppendText($lf+"Batfish server $script:bfsrv NOT online."+$lf)
        } else {
            New-ZipSnap $snapA $script:FileBrowserA
            
            $script:bfTextBox.AppendText("$snapA CFG: Setting active network... " + $script:network + $lf)
            Set-Network $script:network
            
            $script:bfTextBox.AppendText("$snapA CFG: Purging old snapshot... $snapA" + $lf)
            Remove-Snapshot $script:network $snapA
            
            New-SnapshotCurl $snapA
    
            if ((Test-Path $env:TEMP\Kompressor -PathType Any) -eq $true) {
                Remove-Item -Recurse -Path "$env:TEMP\Kompressor"
                $script:bfTextBox.AppendText($lf+"$snapA CFG: Purging temp directory " + "$env:TEMP\Kompressor" + $lf)
            }

        }
    }
)
$form.Controls.Add($bfCURinitButton)

# Create the CANDIDATE/DEST file browse button
$bfCANbrowseButton = New-Object System.Windows.Forms.Button
$bfCANbrowseButton.Location = '800,10'
$bfCANbrowseButton.Size = '75,25'
$bfCANbrowseButton.Text = "$snapB CFG..."
$bfCANbrowseButton.AutoSize = $true
$bfCANbrowseButton.Add_Click(
    {
        $script:FileBrowserB = New-Object System.Windows.Forms.OpenFileDialog -Property @{ 
            InitialDirectory = [Environment]::GetFolderPath('Desktop') 
            Filter = 'Configs (*.cfg)|*.cfg'
        }
        $null = $FileBrowserB.ShowDialog() 
        # Write-Host $FileBrowserB.FileName
        $bflinecountB = (Get-Content $FileBrowserB.FileName)
        $bfCANLabel.Text = $FileBrowserB.FileName + " - " + $bflinecountB.count + " lines"
    }
)
$form.Controls.Add($bfCANbrowseButton)

# Initialise DEST snapshot button
$bfCANinitButton = New-Object System.Windows.Forms.Button
$bfCANinitButton.Location = '800,60'
$bfCANinitButton.Size = '75,25'
$bfCANinitButton.Text = "Initialise..."
$bfCANinitButton.AutoSize = $true
$bfCANinitButton.Add_Click(
    {
        # $ts = Get-Date -Format "HH:mm:ss:fff"
        $script:bfsrv = $textBoxbfq7.text
        $script:bfsrv6 = $script:bfsrv+$bf6
        $script:bfsrv7 = $script:bfsrv+$bf7
        $script:network = $textBoxbfq8.text

        foreach ($pFile in $prereqFiles) {
            if (!(Test-Path $pFile -PathType Leaf) -eq $true) {
                $script:bfTextBox.AppendText($lf+"$pFile not found!"+$lf)
            }
        }
        
        if (!(Test-TCPPort -IPAddress $script:bfsrv -Port $b6 -Timeout $bfWait) -eq $true -or
        (!(Test-TCPPort -IPAddress $script:bfsrv -Port $b7 -Timeout $bfWait) -eq $true))
        {
            $script:bfTextBox.AppendText($lf+"Batfish server $script:bfsrv NOT online."+$lf)
        } else {
            New-ZipSnap $snapB $script:FileBrowserB
            $script:bfTextBox.AppendText("$snapB CFG: Setting active network... " + $script:network + $lf)
            Set-Network $script:network
            $script:bfTextBox.AppendText("$snapB CFG: Purging old snapshot... $snapB" + $lf)
            Remove-Snapshot $script:network $snapB
            New-SnapshotCurl $snapB
    
            if ((Test-Path $env:TEMP\Kompressor -PathType Any) -eq $true) {
                Remove-Item -Recurse -Path "$env:TEMP\Kompressor"
                $script:bfTextBox.AppendText($lf+"$snapB CFG: Purging temp directory " + "$env:TEMP\Kompressor" + $lf)
            }

        }
    }
)
$form.Controls.Add($bfCANinitButton)

# Create the bfCURLabel
$bfCURLabel = New-Object System.Windows.Forms.Label
$bfCURLabel.Location = '160,15'
$bfCURLabel.Size = '280,20'
$bfCURLabel.AutoSize = $true
$bfCURLabel.Text = "No config file selected."
$form.Controls.Add($bfCURLabel)

# Create the bfCANLabel
$bfCANLabel = New-Object System.Windows.Forms.Label
$bfCANLabel.Location = '950,15'
$bfCANLabel.Size = '280,20'
$bfCANLabel.AutoSize = $true
$bfCANLabel.Text = "No config file selected."
$form.Controls.Add($bfCANLabel)


# Create the bfTextBox
$bfTextBox = New-Object System.Windows.Forms.TextBox
$bfTextBox.Location = '10,260'
$bfTextBox.Size = '1550,400'
$bfTextBox.AllowDrop = $true
$bfTextBox.AcceptsReturn = $true
$bfTextBox.AcceptsTab = $false
$bfTextBox.Multiline = $true
$bfTextBox.WordWrap = $false
$bfTextBox.ScrollBars = 'Both'
$bfTextBox.AutoSize = $true
$script:bfTextBox.Text = $blurb+$lf+$lf
# $bfTextBox.Font = New-Object System.Drawing.Font("Arial",16,[System.Drawing.FontStyle]::Regular)
$form.Controls.Add($bfTextBox)

# Create the OK button
$bfOKButton = New-Object System.Windows.Forms.Button
$bfOKButton.Location = '1485,700'
$bfOKButton.Size = '75,25'
$bfOKButton.Text = "OK"
$bfOKButton.AutoSize = $true
$bfOKButton.Add_Click(
    { 
        $form.Close() 
    }
)
$form.Controls.Add($bfOKButton)

# Create the Cancel button
$bfCancelButton = New-Object System.Windows.Forms.Button
$bfCancelButton.Location = '10,700'
$bfCancelButton.Size = '75,25'
$bfCancelButton.Text = "Cancel"
$bfCancelButton.AutoSize = $true
$bfCancelButton.Add_Click(
    {
        $form.Close() 
    }
)
$form.Controls.Add($bfCancelButton)


# QUESTION INPUT BOXES ###########################################

# box1 - srcIp
$textBoxbfq1 = New-Object System.Windows.Forms.TextBox
$textBoxbfq1.Location = '10,120'
$textBoxbfq1.Size = '150,100'
[ipaddress]$textBoxbfq1.text = '172.16.11.2'
$textBoxbfq1.AutoSize = $true
$form.Controls.Add($textBoxbfq1)

# box1Label - srcIp
$textBoxbfq1Label = New-Object System.Windows.Forms.Label
$textBoxbfq1Label.Location = '10,105'
$textBoxbfq1Label.Size = '280,20'
$textBoxbfq1Label.AutoSize = $true
$textBoxbfq1Label.Text = 'srcIp'
$form.Controls.Add($textBoxbfq1Label)

# box2 - dstIp
$textBoxbfq2 = New-Object System.Windows.Forms.TextBox
$textBoxbfq2.Location = '190,120'
$textBoxbfq2.Size = '150,100'
[ipaddress]$textBoxbfq2.text = '10.10.4.2'
$textBoxbfq2.AutoSize = $true
$form.Controls.Add($textBoxbfq2)

# box2Label - dstIp
$textBoxbfq2Label = New-Object System.Windows.Forms.Label
$textBoxbfq2Label.Location = '190,105'
$textBoxbfq2Label.Size = '280,20'
$textBoxbfq2Label.AutoSize = $true
$textBoxbfq2Label.Text = 'dstIp'
$form.Controls.Add($textBoxbfq2Label)

# box3 - service
$textBoxbfq3 = New-Object System.Windows.Forms.TextBox
$textBoxbfq3.Location = '380,120'
$textBoxbfq3.Size = '150,55'
$textBoxbfq3.text = 'http'
$textBoxbfq3.AutoSize = $true
$form.Controls.Add($textBoxbfq3)

# box3Label - service
$textBoxbfq3Label = New-Object System.Windows.Forms.Label
$textBoxbfq3Label.Location = '380,105'
$textBoxbfq3Label.Size = '280,20'
$textBoxbfq3Label.AutoSize = $true
$textBoxbfq3Label.Text = 'service'
$form.Controls.Add($textBoxbfq3Label)

# box4 - policy
$textBoxbfq4 = New-Object System.Windows.Forms.TextBox
$textBoxbfq4.Location = '10,160'
$textBoxbfq4.Size = '150,55'
$textBoxbfq4.text = 'zone~ACC~to~zone~SRV'
$textBoxbfq4.AutoSize = $true
$form.Controls.Add($textBoxbfq4)

# box4Label - policy
$textBoxbfq4Label = New-Object System.Windows.Forms.Label
$textBoxbfq4Label.Location = '10,145'
$textBoxbfq4Label.Size = '280,20'
$textBoxbfq4Label.AutoSize = $true
$textBoxbfq4Label.Text = 'policy'
$form.Controls.Add($textBoxbfq4Label)

# box5 - snapshot
$textBoxbfq5 = New-Object System.Windows.Forms.ComboBox
$textBoxbfq5.Location = '190,160'
$textBoxbfq5.DropDownStyle = 'DropDownList'
$textBoxbfq5.AutoCompleteSource = 'ListItems'
$textBoxbfq5.AutoCompleteMode = 'Suggest'
$textBoxbfq5.Items.AddRange(@('CURRENT', 'CANDIDATE' ))
$textBoxbfq5.SelectedIndex = 0
$textBoxbfq5.Size = '150,55'
$textBoxbfq5.AutoSize = $true
$form.Controls.Add($textBoxbfq5)

# box5Label - snapshot
$textBoxbfq5Label = New-Object System.Windows.Forms.Label
$textBoxbfq5Label.Location = '190,145'
$textBoxbfq5Label.Size = '280,20'
$textBoxbfq5Label.AutoSize = $true
$textBoxbfq5Label.Text = 'snapshot'
$form.Controls.Add($textBoxbfq5Label)

# box6 - srcInterface
$textBoxbfq6 = New-Object System.Windows.Forms.TextBox
$textBoxbfq6.Location = '380,160'
$textBoxbfq6.Size = '150,55'
$textBoxbfq6.text = 'reth1.0'
$textBoxbfq6.AutoSize = $true
$form.Controls.Add($textBoxbfq6)

# box6Label - srcInterface
$textBoxbfq6Label = New-Object System.Windows.Forms.Label
$textBoxbfq6Label.Location = '380,145'
$textBoxbfq6Label.Size = '280,20'
$textBoxbfq6Label.AutoSize = $true
$textBoxbfq6Label.Text = 'srcInterface'
$form.Controls.Add($textBoxbfq6Label)

# box7 - batfishSrv
$textBoxbfq7 = New-Object System.Windows.Forms.TextBox
$textBoxbfq7.Location = '10,200'
$textBoxbfq7.Size = '150,55'
$textBoxbfq7.text = '203.0.113.1'
$textBoxbfq7.AutoSize = $true
$form.Controls.Add($textBoxbfq7)

# box7Label - batfishSrv
$textBoxbfq7Label = New-Object System.Windows.Forms.Label
$textBoxbfq7Label.Location = '10,185'
$textBoxbfq7Label.Size = '280,20'
$textBoxbfq7Label.AutoSize = $true
$textBoxbfq7Label.Text = 'batfishSrv'
$form.Controls.Add($textBoxbfq7Label)

# box8 - network
$textBoxbfq8 = New-Object System.Windows.Forms.TextBox
$textBoxbfq8.Location = '190,200'
$textBoxbfq8.Size = '150,55'
$textBoxbfq8.text = $script:network
$textBoxbfq8.AutoSize = $true
$form.Controls.Add($textBoxbfq8)

# box8Label - network
$textBoxbfq8Label = New-Object System.Windows.Forms.Label
$textBoxbfq8Label.Location = '190,185'
$textBoxbfq8Label.Size = '280,20'
$textBoxbfq8Label.AutoSize = $true
$textBoxbfq8Label.Text = 'network'
$form.Controls.Add($textBoxbfq8Label)

#############################################################







### QUERY button ############################################
$bfQUERYbutton = New-Object System.Windows.Forms.Button
$bfQUERYbutton.Location = '550,190'
$bfQUERYbutton.Size = '75,25'
$bfQUERYbutton.Text = 'Query...'
$bfQUERYbutton.AutoSize = $true
$bfQUERYbutton.Add_Click(
    {
        $script:bfsrv = $textBoxbfq7.text
        $script:bfsrv6 = $script:bfsrv+$bf6
        $script:bfsrv7 = $script:bfsrv+$bf7
        $script:network = $textBoxbfq8.text
        if (!(Test-TCPPort -IPAddress $script:bfsrv -Port $b6 -Timeout $bfWait) -eq $true -or
        (!(Test-TCPPort -IPAddress $script:bfsrv -Port $b7 -Timeout $bfWait) -eq $true))
        {
            $script:bfTextBox.AppendText($lf+"Batfish server $script:bfsrv NOT online."+$lf)
        } else {
            Set-Network $script:network
            New-Question $textBoxbfq1.text $textBoxbfq2.text $textBoxbfq3.text $textBoxbfq4.text
        }
    }
)
$form.Controls.Add($bfQUERYbutton)
### /QUERY button ###########################################

Test-PreReq '7z.exe'
Test-PreReq 'curl.exe'

# Run the form!
$result = $form.ShowDialog()
