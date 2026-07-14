#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true, ConfirmImpact = 'Medium')]
param(
    [ValidateNotNullOrEmpty()]
    [string] $PrinterName = 'DYMO LabelWriter 450 @ PiLab',

    [ValidateNotNullOrEmpty()]
    [string] $IppUri = 'ipp://pilab.local:631/printers/dymo',

    [ValidateNotNullOrEmpty()]
    [string] $DriverName = 'DYMO LabelWriter 450',

    [switch] $Replace
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-WindowsIppPortName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Uri
    )

    try {
        $parsedUri = [System.Uri]::new($Uri, [System.UriKind]::Absolute)
    }
    catch {
        throw "Invalid IPP URI '$Uri'. Use ipp://host:631/printers/queue."
    }

    if (-not $parsedUri.IsAbsoluteUri -or [string]::IsNullOrWhiteSpace($parsedUri.Host)) {
        throw "Invalid IPP URI '$Uri'. Use ipp://host:631/printers/queue."
    }

    $windowsScheme = switch ($parsedUri.Scheme.ToLowerInvariant()) {
        'ipp' { 'http' }
        'ipps' { 'https' }
        'http' { 'http' }
        'https' { 'https' }
        default { throw "Unsupported URI scheme '$($parsedUri.Scheme)'. Use ipp, ipps, http, or https." }
    }

    if (-not [string]::IsNullOrEmpty($parsedUri.UserInfo) -or
        -not [string]::IsNullOrEmpty($parsedUri.Query) -or
        -not [string]::IsNullOrEmpty($parsedUri.Fragment)) {
        throw 'The IPP URI must not contain credentials, a query string, or a fragment.'
    }

    $path = $parsedUri.AbsolutePath.TrimEnd('/')
    if ($path -notmatch '^/printers/[A-Za-z0-9_.-]+(?:/\.printer)?$') {
        throw "Invalid CUPS queue path '$path'. Use /printers/queue."
    }

    if (-not $path.EndsWith('/.printer', [System.StringComparison]::OrdinalIgnoreCase)) {
        $path = "$path/.printer"
    }

    $builder = New-Object System.UriBuilder
    $builder.Scheme = $windowsScheme
    $builder.Host = $parsedUri.Host
    $builder.Port = if ($parsedUri.Scheme -in @('ipp', 'ipps') -and $parsedUri.Port -lt 1) {
        631
    }
    else {
        $parsedUri.Port
    }
    $builder.Path = $path
    $builder.Query = ''
    $builder.Fragment = ''

    return $builder.Uri.AbsoluteUri.TrimEnd('/')
}

function Test-TcpEndpoint {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $HostName,

        [Parameter(Mandatory = $true)]
        [int] $Port
    )

    $client = New-Object System.Net.Sockets.TcpClient

    try {
        $connection = $client.ConnectAsync($HostName, $Port)
        if (-not $connection.Wait(3000)) {
            return $false
        }

        return $client.Connected
    }
    catch {
        return $false
    }
    finally {
        $client.Dispose()
    }
}

function ConvertTo-CupsPpdUri {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $WindowsPort
    )

    $portUri = [System.Uri]::new($WindowsPort, [System.UriKind]::Absolute)
    if (-not $portUri.AbsolutePath.EndsWith('/.printer', [System.StringComparison]::OrdinalIgnoreCase)) {
        throw "Windows IPP port '$WindowsPort' does not end in /.printer."
    }

    $builder = New-Object System.UriBuilder($portUri)
    $builder.Path = $portUri.AbsolutePath.Substring(0, $portUri.AbsolutePath.Length - '/.printer'.Length) + '.ppd'
    $builder.Query = ''
    $builder.Fragment = ''
    return $builder.Uri.AbsoluteUri
}

function Test-CupsPrinterEndpoint {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Uri
    )

    $response = $null

    try {
        $ppdUri = ConvertTo-CupsPpdUri -WindowsPort $Uri
        $request = [System.Net.HttpWebRequest]::Create($ppdUri)
        $request.Method = 'GET'
        $request.Timeout = 5000
        $request.ReadWriteTimeout = 5000
        $response = [System.Net.HttpWebResponse] $request.GetResponse()
        $statusCode = [int] $response.StatusCode
        $mediaType = ([string] $response.ContentType).Split(';')[0].Trim()
        return $statusCode -ge 200 -and
            $statusCode -lt 300 -and
            $mediaType -ieq 'application/vnd.cups-ppd'
    }
    catch {
        return $false
    }
    finally {
        if ($null -ne $response) {
            $response.Dispose()
        }
    }
}

function Get-ExactPrinter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    return @(Get-Printer -Full | Where-Object { $_.Name -eq $Name }) | Select-Object -First 1
}

function Test-InternetPrinterPort {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string] $PortName
    )

    $ports = @(Get-PrinterPort | Where-Object { $_.Name -eq $PortName })
    if ($ports.Count -ne 1) {
        return $false
    }

    $monitorName = [string] $ports[0].PortMonitor
    if ($monitorName -ieq 'Internet Port') {
        return $true
    }

    if ([string]::IsNullOrWhiteSpace($monitorName)) {
        return $false
    }

    try {
        $monitorPath = Join-Path `
            -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors' `
            -ChildPath $monitorName
        $monitorDriver = (Get-ItemProperty -LiteralPath $monitorPath -Name Driver).Driver
        return [System.IO.Path]::GetFileName($monitorDriver) -ieq 'inetpp.dll'
    }
    catch {
        return $false
    }
}

function Test-QueueConfiguration {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [object] $Queue,

        [Parameter(Mandatory = $true)]
        [string] $ExpectedDriver,

        [Parameter(Mandatory = $true)]
        [string] $ExpectedPort
    )

    if ($Queue.DriverName -ne $ExpectedDriver -or $Queue.Datatype -ine 'RAW') {
        return $false
    }

    try {
        $actualPort = ConvertTo-WindowsIppPortName -Uri $Queue.PortName
    }
    catch {
        return $false
    }

    if ($actualPort -ine $ExpectedPort) {
        return $false
    }

    if (-not (Test-InternetPrinterPort -PortName $Queue.PortName)) {
        return $false
    }

    return $true
}

function Test-ManagedPrinterQueue {
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [object] $Queue,

        [Parameter(Mandatory = $true)]
        [string] $ExpectedDriver,

        [Parameter(Mandatory = $true)]
        [string] $ExpectedPort
    )

    if ($Queue.Comment -ne 'Managed by Cups-Dymo-LabelWriter450' -or
        $Queue.DriverName -ne $ExpectedDriver) {
        return $false
    }

    try {
        return (ConvertTo-WindowsIppPortName -Uri $Queue.PortName) -ieq $ExpectedPort
    }
    catch {
        return $false
    }
}

function Add-DymoPrinterQueue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name,

        [Parameter(Mandatory = $true)]
        [string] $Driver,

        [Parameter(Mandatory = $true)]
        [string] $Port,

        [Parameter(Mandatory = $true)]
        [ref] $Created
    )

    $Created.Value = $false
    Add-Printer `
        -Name $Name `
        -DriverName $Driver `
        -PortName $Port `
        -Datatype RAW `
        -Comment 'Managed by Cups-Dymo-LabelWriter450' `
        -Confirm:$false `
        -ErrorAction Stop
    $Created.Value = $true

    $queue = Get-ExactPrinter -Name $Name
    if ($null -eq $queue -or -not (Test-QueueConfiguration -Queue $queue -ExpectedDriver $Driver -ExpectedPort $Port)) {
        throw "Post-install validation failed for '$Name'."
    }
}

function Set-DefaultPrinterByName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string] $Name
    )

    $printer = @(Get-CimInstance -ClassName Win32_Printer |
            Where-Object { $_.Name -eq $Name }) | Select-Object -First 1
    if ($null -eq $printer) {
        throw "Unable to find '$Name' while restoring the default printer."
    }

    $result = Invoke-CimMethod -InputObject $printer -MethodName SetDefaultPrinter
    if ($result.ReturnValue -ne 0) {
        throw "Windows returned $($result.ReturnValue) while setting '$Name' as the default printer."
    }
}

if ($env:OS -ne 'Windows_NT') {
    throw 'This helper must be run on the Windows computer that will own the printer queue.'
}

$currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
$currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw 'Open Windows PowerShell as Administrator and run this helper again.'
}

if ($PrinterName -match '[\x00-\x1f*?\[\]]') {
    throw 'PrinterName must not contain control characters or wildcard characters.'
}

if ($DriverName -match '(?i)Microsoft IPP Class Driver|Generic|AirPrint') {
    throw 'Use the model-specific DYMO LabelWriter 450 driver, not a class or generic driver.'
}

Import-Module PrintManagement -ErrorAction Stop

$configurationMutex = [System.Threading.Mutex]::new(
    $false,
    'Global\CupsDymoLabelWriter450QueueSetup'
)
$configurationMutexAcquired = $false

try {
    try {
        $configurationMutexAcquired = $configurationMutex.WaitOne(0)
    }
    catch [System.Threading.AbandonedMutexException] {
        $configurationMutexAcquired = $true
    }

    if (-not $configurationMutexAcquired) {
        throw 'Another DYMO queue setup is already running on this computer.'
    }

$internetPrintingFeature = Get-Command Get-WindowsOptionalFeature -ErrorAction SilentlyContinue
if ($null -ne $internetPrintingFeature) {
    try {
        $feature = Get-WindowsOptionalFeature `
            -Online `
            -FeatureName Printing-Foundation-InternetPrinting-Client `
            -ErrorAction Stop
        if ($feature.State -ne 'Enabled') {
            throw "Internet Printing Client is not enabled (state: $($feature.State)). Enable it with: Enable-WindowsOptionalFeature -Online -FeatureName Printing-Foundation-InternetPrinting-Client -All"
        }
    }
    catch {
        if ($_.Exception.Message -like 'Internet Printing Client is not enabled.*') {
            throw
        }

        Write-Verbose "Could not query the Internet Printing Client feature: $($_.Exception.Message)"
    }
}

$windowsPort = ConvertTo-WindowsIppPortName -Uri $IppUri
$parsedWindowsPort = [System.Uri]::new($windowsPort)

if (-not (Test-TcpEndpoint -HostName $parsedWindowsPort.Host -Port $parsedWindowsPort.Port)) {
    throw "Cannot reach $($parsedWindowsPort.Host) on TCP port $($parsedWindowsPort.Port). Check the Pi hostname, network, and CUPS service."
}

if (-not (Test-CupsPrinterEndpoint -Uri $windowsPort)) {
    $ppdUri = ConvertTo-CupsPpdUri -WindowsPort $windowsPort
    throw "The queue-specific CUPS PPD was not found at $ppdUri. Check the Pi queue name and CUPS access."
}

$installedDriver = @(Get-PrinterDriver | Where-Object { $_.Name -eq $DriverName })
if ($installedDriver.Count -eq 0) {
    $candidateNames = @(Get-PrinterDriver |
            Where-Object { $_.Name -match '(?i)DYMO.*450' } |
            ForEach-Object { $_.Name })
    $candidateText = if ($candidateNames.Count -gt 0) {
        " Installed DYMO 450 drivers: $($candidateNames -join ', ')."
    }
    else {
        ''
    }

    throw "Exact printer driver '$DriverName' is not installed.$candidateText Install the DYMO software first. Windows Protected Print Mode must be off because it blocks third-party drivers."
}

$existingQueue = Get-ExactPrinter -Name $PrinterName

if ($null -ne $existingQueue) {
    $sameDriver = $existingQueue.DriverName -eq $DriverName
    $samePort = $false

    try {
        $samePort = (ConvertTo-WindowsIppPortName -Uri $existingQueue.PortName) -ieq $windowsPort
    }
    catch {
        $samePort = $false
    }

    $sameInternetPort = $samePort -and (Test-InternetPrinterPort -PortName $existingQueue.PortName)

    if ($sameDriver -and $sameInternetPort -and $existingQueue.Datatype -ine 'RAW') {
        $pendingJobs = @(Get-PrintJob -PrinterName $PrinterName -ErrorAction Stop)
        if ($pendingJobs.Count -gt 0) {
            throw "Queue '$PrinterName' still has jobs. Cancel or finish them before changing its datatype."
        }

        if (-not $PSCmdlet.ShouldProcess($PrinterName, 'Set the spool datatype to RAW')) {
            return
        }

        $previousDatatype = $existingQueue.Datatype
        try {
            Set-Printer -Name $PrinterName -Datatype RAW -Confirm:$false -ErrorAction Stop
            $existingQueue = Get-ExactPrinter -Name $PrinterName
            if (-not (Test-QueueConfiguration -Queue $existingQueue -ExpectedDriver $DriverName -ExpectedPort $windowsPort)) {
                throw "RAW datatype verification failed for '$PrinterName'."
            }
        }
        catch {
            $datatypeError = $_
            try {
                Set-Printer `
                    -Name $PrinterName `
                    -Datatype $previousDatatype `
                    -Confirm:$false `
                    -ErrorAction Stop
                $restoredQueue = Get-ExactPrinter -Name $PrinterName
                if ($null -eq $restoredQueue -or $restoredQueue.Datatype -ine $previousDatatype) {
                    throw "Windows did not restore datatype '$previousDatatype'."
                }
            }
            catch {
                Write-Warning "Could not restore datatype '$previousDatatype' on '$PrinterName': $($_.Exception.Message)"
            }

            throw $datatypeError
        }

        Write-Output "Configured '$PrinterName' to spool DYMO-ready data as RAW."
        Write-Output 'No print job was submitted.'
        return
    }

    if (Test-QueueConfiguration -Queue $existingQueue -ExpectedDriver $DriverName -ExpectedPort $windowsPort) {
        Write-Output "Queue '$PrinterName' is already configured for network-safe raw output."
        return
    }

    if (-not $Replace) {
        throw "Queue '$PrinterName' exists with driver '$($existingQueue.DriverName)', port '$($existingQueue.PortName)', and datatype '$($existingQueue.Datatype)'. Rerun with -Replace to replace this mismatched queue safely."
    }

    if ($existingQueue.Shared) {
        throw "Queue '$PrinterName' is shared. Unshare it before using -Replace."
    }

    $pendingJobs = @(Get-PrintJob -PrinterName $PrinterName -ErrorAction Stop)
    if ($pendingJobs.Count -gt 0) {
        throw "Queue '$PrinterName' still has jobs. Cancel or finish them before using -Replace."
    }

    $token = [Guid]::NewGuid().ToString('N').Substring(0, 8)
    $stagingName = "$PrinterName setup $token"
    $backupName = "$PrinterName backup $token"
    $failedReplacementName = "$PrinterName failed setup $token"
    $oldQueueSnapshot = [PSCustomObject] @{
        DriverName = $existingQueue.DriverName
        PortName   = $existingQueue.PortName
        Datatype   = $existingQueue.Datatype
        Comment    = $existingQueue.Comment
    }
    $defaultWasOldQueue = @(Get-CimInstance -ClassName Win32_Printer |
            Where-Object { $_.Name -eq $PrinterName -and $_.Default }).Count -eq 1

    if (-not $PSCmdlet.ShouldProcess($PrinterName, "Replace it with a verified DYMO RAW queue at $windowsPort")) {
        return
    }

    $stagingCreated = $false
    try {
        Add-DymoPrinterQueue `
            -Name $stagingName `
            -Driver $DriverName `
            -Port $windowsPort `
            -Created ([ref] $stagingCreated)
    }
    catch {
        $stagingError = $_
        $partialStagingQueue = Get-ExactPrinter -Name $stagingName
        if ($null -ne $partialStagingQueue -and
            ($stagingCreated -or
                (Test-ManagedPrinterQueue -Queue $partialStagingQueue -ExpectedDriver $DriverName -ExpectedPort $windowsPort))) {
            Write-Warning "The failed staging queue '$stagingName' was retained so the helper cannot delete queued work. Remove it manually after confirming it has no jobs."
        }

        throw $stagingError
    }

    $oldQueueRenamed = $false
    $replacementQueueRenamed = $false
    try {
        $pendingJobs = @(Get-PrintJob -PrinterName $PrinterName -ErrorAction Stop)
        if ($pendingJobs.Count -gt 0) {
            throw "Queue '$PrinterName' received a job during setup; replacement was cancelled."
        }

        Rename-Printer -Name $PrinterName -NewName $backupName -Confirm:$false -ErrorAction Stop
        $backupQueue = Get-ExactPrinter -Name $backupName
        $oldNameQueue = Get-ExactPrinter -Name $PrinterName
        if ($null -ne $backupQueue -and $null -eq $oldNameQueue) {
            $oldQueueRenamed = $true
        }
        else {
            throw "Windows did not complete the backup rename for '$PrinterName'."
        }

        $backupJobs = @(Get-PrintJob -PrinterName $backupName -ErrorAction Stop)
        if ($backupJobs.Count -gt 0) {
            throw "Queue '$PrinterName' received a job during setup; its original queue and jobs will be restored."
        }

        Rename-Printer -Name $stagingName -NewName $PrinterName -Confirm:$false -ErrorAction Stop

        $finalQueue = Get-ExactPrinter -Name $PrinterName
        $remainingStagingQueue = Get-ExactPrinter -Name $stagingName
        if ($null -ne $finalQueue -and $null -eq $remainingStagingQueue) {
            $replacementQueueRenamed = $true
        }

        if (-not $replacementQueueRenamed -or
            -not (Test-QueueConfiguration -Queue $finalQueue -ExpectedDriver $DriverName -ExpectedPort $windowsPort)) {
            throw "Post-swap validation failed for '$PrinterName'."
        }

        if ($defaultWasOldQueue) {
            Set-DefaultPrinterByName -Name $PrinterName
        }
    }
    catch {
        $swapError = $_
        $rollbackErrors = @()
        $restoredOriginalQueue = $false

        if (-not $oldQueueRenamed) {
            $possibleBackupQueue = Get-ExactPrinter -Name $backupName
            $possibleOriginalNameQueue = Get-ExactPrinter -Name $PrinterName
            if ($null -ne $possibleBackupQueue -and
                $null -eq $possibleOriginalNameQueue -and
                $possibleBackupQueue.DriverName -eq $oldQueueSnapshot.DriverName -and
                $possibleBackupQueue.PortName -eq $oldQueueSnapshot.PortName -and
                $possibleBackupQueue.Datatype -eq $oldQueueSnapshot.Datatype -and
                $possibleBackupQueue.Comment -eq $oldQueueSnapshot.Comment) {
                $oldQueueRenamed = $true
            }
        }

        if ($oldQueueRenamed) {
            $replacementQueue = Get-ExactPrinter -Name $PrinterName
            if ($null -ne $replacementQueue) {
                if (Test-ManagedPrinterQueue -Queue $replacementQueue -ExpectedDriver $DriverName -ExpectedPort $windowsPort) {
                    try {
                        Rename-Printer `
                            -Name $PrinterName `
                            -NewName $failedReplacementName `
                            -Confirm:$false `
                            -ErrorAction Stop
                        if ($null -ne (Get-ExactPrinter -Name $PrinterName)) {
                            throw "The replacement still owns the name '$PrinterName'."
                        }
                    }
                    catch {
                        $rollbackErrors += "Could not move the replacement aside: $($_.Exception.Message)"
                    }
                }
                else {
                    $rollbackErrors += "An unrecognized queue owns the name '$PrinterName'; it was not removed."
                }
            }

            if ($null -eq (Get-ExactPrinter -Name $PrinterName)) {
                try {
                    $backupQueue = Get-ExactPrinter -Name $backupName
                    if ($null -eq $backupQueue) {
                        throw "The original backup queue '$backupName' is missing."
                    }

                    Rename-Printer `
                        -Name $backupName `
                        -NewName $PrinterName `
                        -Confirm:$false `
                        -ErrorAction Stop

                    $restoredQueue = Get-ExactPrinter -Name $PrinterName
                    $restoredOriginalQueue = $null -ne $restoredQueue -and
                        $restoredQueue.DriverName -eq $oldQueueSnapshot.DriverName -and
                        $restoredQueue.PortName -eq $oldQueueSnapshot.PortName -and
                        $restoredQueue.Datatype -eq $oldQueueSnapshot.Datatype -and
                        $restoredQueue.Comment -eq $oldQueueSnapshot.Comment
                    if (-not $restoredOriginalQueue) {
                        throw 'The restored queue does not match the original queue snapshot.'
                    }
                }
                catch {
                    $rollbackErrors += "Could not restore the original queue name: $($_.Exception.Message)"
                }
            }

            if ($restoredOriginalQueue -and $defaultWasOldQueue) {
                try {
                    Set-DefaultPrinterByName -Name $PrinterName
                }
                catch {
                    $rollbackErrors += "Could not restore the default-printer choice: $($_.Exception.Message)"
                }
            }
        }

        if (-not $oldQueueRenamed -or $restoredOriginalQueue) {
            foreach ($temporaryName in @($stagingName, $failedReplacementName)) {
                $temporaryQueue = Get-ExactPrinter -Name $temporaryName
                if ($null -ne $temporaryQueue -and
                    (Test-ManagedPrinterQueue -Queue $temporaryQueue -ExpectedDriver $DriverName -ExpectedPort $windowsPort)) {
                    Write-Warning "Temporary queue '$temporaryName' was retained so the helper cannot delete queued work. Remove it manually after confirming it has no jobs."
                }
            }
        }

        if ($rollbackErrors.Count -gt 0) {
            $rollbackDetail = $rollbackErrors -join ' '
            throw "Replacement failed: $($swapError.Exception.Message) Rollback was incomplete: $rollbackDetail The original queue may remain as '$backupName'."
        }

        throw $swapError
    }

    Write-Output "Replaced '$PrinterName' with a verified DYMO RAW queue at $windowsPort."
    Write-Output "Retained the original queue as '$backupName' so queued work cannot be deleted automatically."
    Write-Output 'After confirming it has no jobs, remove that backup manually from Print Management.'
    Write-Output 'No print job was submitted.'
    return
}

if (-not $PSCmdlet.ShouldProcess($PrinterName, "Create a DYMO RAW queue at $windowsPort")) {
    return
}

try {
    $targetCreated = $false
    Add-DymoPrinterQueue `
        -Name $PrinterName `
        -Driver $DriverName `
        -Port $windowsPort `
        -Created ([ref] $targetCreated)
}
catch {
    $creationError = $_
    $partialQueue = Get-ExactPrinter -Name $PrinterName
    if ($null -ne $partialQueue -and
        ($targetCreated -or
            (Test-ManagedPrinterQueue -Queue $partialQueue -ExpectedDriver $DriverName -ExpectedPort $windowsPort))) {
        Write-Warning "The failed queue '$PrinterName' was retained so the helper cannot delete queued work. Remove it manually after confirming it has no jobs."
    }

    throw $creationError
}

Write-Output "Configured '$PrinterName' with the DYMO driver and RAW IPP transport at $windowsPort."
Write-Output 'No print job was submitted.'
}
finally {
    if ($configurationMutexAcquired) {
        try {
            $configurationMutex.ReleaseMutex()
        }
        catch {
            Write-Warning "Could not release the DYMO setup lock: $($_.Exception.Message)"
        }
    }

    $configurationMutex.Dispose()
}
