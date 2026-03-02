
#using namespace System.Management.Automation
#try{ 
#Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
#} catch {}
#Set-PSReadlineOption -AddToHistoryHandler
#  $x | where { $y=cat $_ | ss  -Pattern "\bcall" | ss "\bput" ; $y.Length -ge 1 }
. $PSScriptRoot\secret.ps1
#Write-Host "started"
New-Alias ss Select-String
New-Alias grep Select-String
New-Alias z Get-Help -ErrorAction SilentlyContinue
New-Alias m Get-Member
# Remove the default cd alias
Remove-Alias cd
$qtpath="C:\Program Files\neovim-qt 0.2.19\bin\nvim-qt.exe"
# Create a new cd function
#
#
function Checkout-FileWithDifferentName {
    param (
        [string]$FilePath,
        [string]$NewFileName,
        [string]$Branch = "main"
    )
    # Check if the file exists in the current directory
    if (-Not (Test-Path $FilePath)) {
        Write-Error "File '$FilePath' does not exist in the current directory."
        return
    }
    # Get the directory and file name from the file path
    $directory = Split-Path $FilePath
    $fileName = Split-Path $FilePath -Leaf
    # Change to the directory containing the file
    Push-Location $directory
    try {
        # Stash any local changes to the file
        git stash push $fileName
        # Checkout the file from the specified branch
        git checkout $Branch -- $fileName
        # Rename the checked-out file
        mv  $fileName  $NewFileName
        # Restore the stashed changes
        git stash pop
    }
    catch {
        Write-Error "An error occurred: $_"
    }
    finally {
        # Return to the original directory
        Pop-Location
    }
}


function ConvertPSObjectToHashtable
{
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process
    {
        if ($null -eq $InputObject)
        { return $null 
        }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string])
        {
            $collection = @(
                foreach ($object in $InputObject)
                { ConvertPSObjectToHashtable $object 
                }
            )

            Write-Output -NoEnumerate $collection
        } elseif ($InputObject -is [psobject])
        {
            $hash = @{}

            foreach ($property in $InputObject.PSObject.Properties)
            {
                $hash[$property.Name] = (ConvertPSObjectToHashtable $property.Value).PSObject.BaseObject
            }

            $hash
        } else
        {
            $InputObject
        }
    }
}

$global:jsonFile = Join-Path -Path $env:USERPROFILE -ChildPath ('cmdLines.json' )

$ExecutionContext.InvokeCommand.PostCommandLookupAction = {
try{ 
    $cmdLine = $MyInvocation.Line
    if ($args[1].CommandOrigin -ne 'Runspace' -or $cmdLine -match 'PostCommandLookupAction|^prompt$')
    { return 
    }

    $currentDir = (Get-Location).Path

    if (!(Test-Path -Path $global:jsonFile))
    {
        @{ $currentDir = @($cmdLine) } | ConvertTo-Json | Set-Content -Path $global:jsonFile
    } else
    {
        $existingCmdLines = Get-Content -Path $global:jsonFile | ConvertFrom-Json 
        $existingCmdLines = ConvertPSObjectToHashtable $existingCmdLines

        if (!$existingCmdLines.ContainsKey($currentDir))
        {
            $existingCmdLines.Add($currentDir, @($cmdLine))
        } else
        {
            if (!$existingCmdLines[$currentDir].Contains($cmdLine))
            {
                $existingCmdLines[$currentDir] += $cmdLine
            }
        }
        $existingCmdLines | ConvertTo-Json | Set-Content -Path $global:jsonFile
    }
    }catch { 
Write-Debug "error in PostCommandLookupAction: $_"
    }
}
$parameters = @{
    Key = 'Alt+q'
    BriefDescription = 'Go to last dir'
    LongDescription = 'Go to last dir'
    ScriptBlock = {
        param($key, $arg)   # The arguments are ignored in this example
        CdLast 
    }
}
Set-PSReadLineKeyHandler @parameters
$parameters = @{
    Key = 'Alt+e'
    BriefDescription = 'Execute from last same direrctory'
    LongDescription = 'Execute from last commands typed in same direrctory'
    ScriptBlock = {
        param($key, $arg)   # The arguments are ignored in this example
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert( $(GrepOnCurDir) )
        #[Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()

    }
}
Set-PSReadLineKeyHandler @parameters
$parameters = @{
    Key = 'Alt+h'
    BriefDescription = 'Grep from last same direrctory'
    LongDescription = 'Grep from last commands typed globally'
    ScriptBlock = {
        param($key, $arg)   # The arguments are ignored in this example
        [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
        [Microsoft.PowerShell.PSConsoleReadLine]::Insert( $(SimpHist) )
    }
}
Set-PSReadLineKeyHandler @parameters



function GrepOnCurDir()
{
    $currentDir = (Get-Location).Path
    $existingCmdLines = Get-Content -Path $global:jsonFile | ConvertFrom-Json 
    $existingCmdLines = ConvertPSObjectToHashtable $existingCmdLines
    $existingCmdLines[$currentDir] | fzf
}
function MyCD
{
    try{ 
        Set-Location @args
    }catch{ 
        Write-Error "asdas"
        Write-Error $_.Exception.InnerException.Message
        return
    }
    #$curtime =$(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    #$dict = @{
    #Id = "30"
    #CommandLine = "cd $(Get-Location)"
    #ExecutionStatus = "Completed"
    #StartExecutionTime = $curtime
    #EndExecutionTime = $curtime
    #Duration = "00:00:00.0389011"
    #}
    #$historyObject = New-Object -TypeName PSObject -Property $dict
    #Add-History -InputObject $historyObject
    try{ 
    $historyLocation = $(Get-PSReadLineOption).HistorySavePath

    Add-Content -Path $historyLocation -Value "cd $(Get-Location)"
    }catch {
        Write-Debug "error in MyCD: $_"
    }
}
# Set cd to use the new function
Set-Alias cd MyCD
function SimpHistEx
{
    $va=$(SimpHist)
    [Microsoft.PowerShell.PSConsoleReadLine]::RevertLine()
    [Microsoft.PowerShell.PSConsoleReadLine]::Insert( $va )
    [Microsoft.PowerShell.PSConsoleReadLine]::AcceptLine()

    #[System.Windows.Forms.SendKeys]::SendWait($va)


}
function SimpHist 
{
    $historyLocation = $(Get-PSReadLineOption).HistorySavePath
    $all = Get-Content $historyLocation
    return $($all | Sort-Object -Unique | FZF)
}
# Function to get history of saved locations
function StupidHist
{
    $historyLocation = $(Get-PSReadLineOption).HistorySavePath
    $all = Get-Content $historyLocation | select-string -Pattern "^cd .:" | %{ echo ($_ -replace "^cd (.*)","`$1") } | Sort-Object -Unique 
    return $all | Where-Object { Test-Path $($_) }
}
# Function to change to the last visited location
function CdLast
{
    $location = StupidHist | FZF
    if ($location)
    {
        Set-Location $location
    }
}
# Create an alias for CdLast
Set-Alias q CdLast
function ConVM
{
    $Username = "User"
    $Password = ConvertTo-SecureString "Password1" -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential($Username, $Password)
    $Session = New-PSSession -VMName win10 -Credential $Credential
    return $Session 
}

function ClearShada
{
    rm C:\Users\ekarni\AppData\Local\nvim-data\shada\*
    ResetNeo
}
function Which($arg)
{
    python -c "import shutil; print(shutil.which('$arg'))"
}
function AddWrapper([parameter(mandatory=$true, position=0)][string]$For,[parameter(mandatory=$true, position=1)][string]$To) 
{
    $paramDictionary = [RuntimeDefinedParameterDictionary]::new()
    $paramset= $(Get-Command $For).Parameters.Values | %{[System.Management.Automation.RuntimeDefinedParameter]::new($_.Name,$_.ParameterType,$_.Attributes)}
    $paramsetlet= $(Get-Command empt).Parameters.Keys 
    $paramsetlet+= $(Get-Command $To).ScriptBlock.Ast.Body.ParamBlock.Parameters.Name | %{ $_.VariablePath.UserPath }
    $paramset | %{ if ( -not ($paramsetlet -contains $_.Name) )
        {$paramDictionary.Add($_.Name,$_)
        }}
    return $paramDictionary
}
function GetRestOfParams()
{
    #if dontincludecommon provide source function else dst function
    Param([parameter(mandatory=$true, position=1)][hashtable]$params, 
        [parameter(mandatory=$true, position=0)][string]$dstsource,
        [parameter(mandatory=$false, position=2)][switch][bool]$dontincludecommon=$true)
    $dstorgparams=$(Get-Command $dstsource).Parameters.Keys
    $z= $params
    if ( -not $dontincludecommon)
    {
        $z.Keys | %{ if ( -not ($dstorgparams -contains $_) )
            {$z.Remove($_)
            } } | Out-Null
    } else 
    { 
        $dyn= $(Get-Command $dstsource).Parameters.Values | Where-Object -Property IsDynamic -Eq $false
        $dyn | %{ $z.Remove($_.Name) } | Out-Null
    }
    return $z
}

function Empt
{
    [CmdletBinding()]
    Param([parameter(mandatory=$true, position=0)][string]$aaaa)
    1
}

function Let
{
    [CmdletBinding()]
    Param([parameter(mandatory=$true, position=0)][string]$Option,[parameter(mandatory=$false, position=0)][string]$OptionB)


    DynamicParam
    {
        AddWrapper -For Get -To $MyInvocation.MyCommand.Name
    }
    Begin
    { 
        $params = GetRestOfParams Let $PSBoundParameters -dontincludecommon
    }
    Process
    {
        Get @params -OptionB ( $OptionB + "1"
        )
    }
}

function Get
{
    [CmdLetBinding()]
    Param([parameter(mandatory=$false, position=0)][string]$OptionA,
        [parameter(mandatory=$false, position=1)][string]$OptionB)
    Write-Host "opta",$OptionA
    Write-Host "optb",$OptionB
}
Function LookFor {
    param(
        [Parameter(Position=0)]
        [string]$Proc = "*",
        
        [Parameter(Position=1)]
        [string]$cmd = "*",
        
        [Parameter()]
        [string]$Title = "*",
        
        [Parameter()]
        [switch]$ShowTable
    )
    
    $processes = Get-Process | Where-Object { 
        $_.Name -like $Proc -and 
        $_.CommandLine -like $cmd -and
        ($_.MainWindowTitle -like $Title)
    }
    
    if ($ShowTable) {
        $processes | Select-Object Id, Name, MainWindowTitle, CommandLine
    } else {
        $processes 
    }
}


Function Term($Proc,$cmd="*")
{
(Get-Process) | Where { $_.name -like $Proc}    | Where-Object CommandLine -like $cmd | ForEach-Object{Get-CimInstance Win32_Process -Filter ("ProcessId = {0}" -f ($_.Id)) } | %{ Invoke-CimMethod -InputObject $_ -MethodName Terminate }
}

Function KillAllPyCharm()
{
    Term python *pydevd*
    Term python *ibsrv*
    Term cmd *ibsrv*
}
Function EditInNeo($ar, $line)
{
    Write-Host $ar $line
    $fileArg = $ar
    if ($line) {
        $lineArg = "+$line"
        Write-Host nvr --remote $lineArg $ar --servername  $(Get-Content C:\temp\listen.txt)
        #cmd /S "pause"
        nvr --remote $lineArg $ar --servername  $(Get-Content C:\temp\listen.txt)
        if ($LASTEXITCODE -eq 1)
        {&$qtpath $lineArg $ar
        }
    } else {
        Write-Host nvr --remote $ar --servername  $(Get-Content C:\temp\listen.txt)
        nvr --remote $ar --servername  $(Get-Content C:\temp\listen.txt)
        if ($LASTEXITCODE -eq 1)
        {&$qtpath $ar
        }
    }
    Show-Window nvim-qt
}


Function ResetNeo($a)
{
    #DelProcess nvim-qt
    Term nvim-qt
    Term nvim
    if ($a)
    {
        Start-Process $qtpath -ArgumentList ($a)
    } else
    { Start-Process $qtpath
    }

    #ps | Where-Object -Property ProcessName  -Like "*goneovim*"| %{Write-Host $_.Id ,$_.ProcessName ;$_.Kill()}
    #C:\Users\ekarni\Downloads\Goneovim-v0.4.12-win64\goneovim.exe
}

Function DelProcess($name)
{
    ps | Where-Object -Property ProcessName  -Like "*$name*"| %{Write-Host $_.Id ,$_.ProcessName ;$_.Kill()}
}
function TranslatePath($fil)
{
    wsl bash -c "wslpath -w '$fil'"
}
function RunBash($fil)
{
    wsl bash -c "source /home/ekarni/.bash_profile; $fil" 
}
function OtherPython($a)
{
    Invoke-expression "C:\users\ekarni\AppData\Local\Programs\Python\Python39\python.exe $a"
}
function Show-Window
{
    param(
        [Parameter(Mandatory)]
        [string] $ProcessName
    )

    # As a courtesy, strip '.exe' from the name, if present.
    $ProcessName = $ProcessName -replace '\.exe$'

    # Get the PID of the first instance of a process with the given name
    # that has a non-empty window title.
    # NOTE: If multiple instances have visible windows, it is undefined
    #       which one is returned.
    $hWnd = (Get-Process -ErrorAction Ignore $ProcessName).Where({ $_.MainWindowTitle }, 'First').MainWindowHandle

    if (-not $hWnd)
    { Throw "No $ProcessName process with a non-empty window title found." 
    }

    $type = Add-Type -PassThru -NameSpace Util -Name SetFgWin -MemberDefinition @'
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);    
    [DllImport("user32.dll", SetLastError=true)]
    public static extern bool IsIconic(IntPtr hWnd);    // Is the window minimized?
'@ 

    # Note: 
    #  * This can still fail, because the window could have bee closed since
    #    the title was obtained.
    #  * If the target window is currently minimized, it gets the *focus*, but its
    #    *not restored*.
    $null = $type::SetForegroundWindow($hWnd)
    # If the window is minimized, restore it.
    # Note: We don't call ShowWindow() *unconditionally*, because doing so would
    #       restore a currently *maximized* window instead of activating it in its current state.
    if ($type::IsIconic($hwnd))
    {
        $type::ShowWindow($hwnd, 9) # SW_RESTORE
    }

}
Function Get-LockingProcess
{

    [cmdletbinding()]
    Param(
        [Parameter(Position=0, Mandatory=$True,
            HelpMessage="What is the path or filename? You can enter a partial name without wildcards")]
        [Alias("name")]
        [ValidateNotNullorEmpty()]
        [string]$Path
    )

    # Define the path to Handle.exe
    # //$Handle = "G:\Sysinternals\handle.exe"
    $Handle = "C:\SysinternalsSuite\handle.exe"

    # //[regex]$matchPattern = "(?<Name>\w+\.\w+)\s+pid:\s+(?<PID>\b(\d+)\b)\s+type:\s+(?<Type>\w+)\s+\w+:\s+(?<Path>.*)"
    # //[regex]$matchPattern = "(?<Name>\w+\.\w+)\s+pid:\s+(?<PID>\d+)\s+type:\s+(?<Type>\w+)\s+\w+:\s+(?<Path>.*)"
    # (?m) for multiline matching.
    # It must be . (not \.) for user group.
    [regex]$matchPattern = "(?m)^(?<Name>\w+\.\w+)\s+pid:\s+(?<PID>\d+)\s+type:\s+(?<Type>\w+)\s+(?<User>.+)\s+\w+:\s+(?<Path>.*)$"

    # skip processing banner
    $data = &$handle -u $path -nobanner
    # join output for multi-line matching
    $data = $data -join "`n"
    $MyMatches = $matchPattern.Matches( $data )

    # //if ($MyMatches.value) {
    if ($MyMatches.count)
    {

        $MyMatches | foreach {
            [pscustomobject]@{
                FullName = $_.groups["Name"].value
                Name = $_.groups["Name"].value.split(".")[0]
                ID = $_.groups["PID"].value
                Type = $_.groups["Type"].value
                User = $_.groups["User"].value.trim()
                Path = $_.groups["Path"].value
                toString = "pid: $($_.groups["PID"].value), user: $($_.groups["User"].value), image: $($_.groups["Name"].value)"
            } #hashtable
        } #foreach
    } #if data
    else
    {
        Write-Warning "No matching handles found"
    }
} #end function
function copy-foldertovirtualmachine
{
    param(
        [parameter (mandatory = $true, valuefrompipeline = $true)]
        [string]$VMName,
        [string]$FromFolder = '.\'
    )
    foreach ($File in (Get-ChildItem $Folder -recurse | ? Mode -ne 'd-----'))
    {

        $relativePath = $item.FullName.Substring($Root.Length)
        Copy-VMFile -VM (Get-VM $VMName) -SourcePath $file.fullname -DestinationPath $file.fullname -FileSource Host -CreateFullPath -Force
    }
}

function NewVMDrive
{
    $Username = "user"
    $Password = ConvertTo-SecureString "Password1" -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential($Username, $Password)
    New-PSDrive -Name "V" -PSProvider "FileSystem" -Root "\\192.168.10.2\c$" -Credential $cred -Persist 
}
function GetGitStash
{
    git stash list | ss mychanges | %{ $_ -replace ":.*$"} | %{ git diff $_^1 $_}
}
function  CheckCommit ($n,$line)
{
    $commits= git log --pretty=format:%h -n $n
    $commits | %{ git show $_ | select-string $line} 
}

function RemoveCommit([string]$commit)
{
    $commitid=git log --pretty="%h" --grep=$commit


    $st= "sed -i 's/^pick $($commitid)/drop $($commitid)/' `$file"
    $st= $commands -join "`n"

    $st="func() {
local file=`$1
$st
}; func"
    $env:GIT_SEQUENCE_EDITOR=$st
    try
    {
        git rebase -i HEAD~$count
    } finally
    {
        Remove-Item Env:\GIT_SEQUENCE_EDITOR
    }
}
function ExtractFromLastStash($file)
{
    $x=git diff stash@`{0`}^1 stash@`{0`} -- $file 
    return $x
}

function Checkout-FileFromStash {
    param (
        [Parameter(Mandatory = $true)]
        [string]$FilePath,
        [Parameter(Mandatory = $false)]
        [int]$StashIndex
    )
    # Get the list of stashes
    $stashes = git stash list
    if ($stashes.Count -eq 0) {
        Write-Host "No stashes found."
        return
    }
    # Display the list of stashes
    Write-Host "Available stashes:"
    $stashes | ForEach-Object { Write-Host $_ }
    # If StashIndex is not provided, prompt the user to select a stash
    if (-not $PSBoundParameters.ContainsKey('StashIndex')) {
        $StashIndex = Read-Host "Enter the index of the stash you want to use (e.g., 0 for stash@{0})"
        # Validate the user's input
        if (-not $StashIndex -match '^\d+$') {
            Write-Error "Invalid input. Please enter a valid stash index."
            return
        }
    }
    # Checkout the specified file from the selected stash
    try {
        git checkout stash@{$StashIndex} -- $FilePath
        Write-Host "File '$FilePath' has been checked out from stash@{$StashIndex}."
    } catch {
        Write-Error "An error occurred while checking out the file: $_"
    }
}
function StashAll($name)
{
    git stash store $(git stash create) -m $name
}
#function GitPullKeepLocal ()
#{
    #param ( 
        #[parameter()][switch]$keeplocalinconflict =$null,
        #[parameter()][switch]$dontkeepstash=$false 

        #) 

    #$commit_hash=$(git rev-parse HEAD)
    #git stash save | Out-Null
    #git pull --rebase 
    #$conflicts = $(git diff --name-only --diff-filter=U)
    #$changes = $(git diff --name-only $commit_hash)
    #if ($conflicts)
    #{
        #Write-Host "There are merge conflicts. Please run git pull. Aborting"
        ##abort the pull
        #git rebase --abort
        

        ## Exit or throw an error here, if you want to stop the script
    #} else
    #{

        ## Checkout files from the stash
        #git checkout stash -- . | Out-Null
        #git reset | Out-Null
        #$localch= $(git diff --name-only)
        #$int = $localch | ?{ $changes -contains $_  } 
        #if ($int)
        #{
            #echo "Following files are in both: $int " 

        
            #if ($(-not ($keeplocalinconflict)))
            #{
                #$userInput = Read-Host -Prompt "Do you want to keep local changes in case of conflict? (y/n/merge)"
                #if ($userInput -eq "y") {
                    #$keeplocalinconflict = $true
                #} else {
                    #echo "reseting to remote"
                    #git checkout -- $int
                #}
                #if ($userInput -eq "merge")
                #{
                    #git stash apply
                #}
            #}
        #}

        #if ($dontkeepstash) 
        #{
            #git stash drop
        #}
        ## Drop the stash
    #}
#}

function RestartWsl()
{
    Get-Service LxssManager | Restart-Service

}
function UpdateVim($typ)
{
    cd C:\Users\ekarni
    Write-Host "usage: new-version-zip-filename (ie nightly)"
    Remove-Item -Path nvim-win64.zip -ErrorAction SilentlyContinue
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile("https://github.com/neovim/neovim/releases/download/$typ/nvim-win64.zip", "C:\Users\ekarni\nvim-win64.zip")
    if (Test-Path -Path nvim-temp)
    {
        Write-Host "moving temp to last temp"
        Remove-Item -Path ./neovim-lasttemp -Recurse -Force -ErrorAction SilentlyContinue
        Move-Item -Path nvim-temp -Destination nvim-lasttemp
    }
    #Move-Item -Path nvim-temp -Destination nvim-lasttemp     -ErrorAction SilentlyContinue
    Move-Item -Path ./Neovim -Destination nvim-temp
    Expand-Archive -Path nvim-win64.zip -DestinationPath ./Neovim -Force


}

function Add-ToPath {
    param (
        [string]$PathToAdd
    )
    # Check if the path already exists in the PATH variable
    $currentPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
    if ($currentPath -like "*$PathToAdd*") {
        Write-Host "The path '$PathToAdd' is already in the system PATH."
        return
    }
    # Add the new path to the existing PATH variable
    $newPath = $currentPath + ";" + $PathToAdd
    # Update the system PATH variable
    [System.Environment]::SetEnvironmentVariable("Path", $newPath, [System.EnvironmentVariableTarget]::Machine)
    Write-Host "The path '$PathToAdd' has been added to the system PATH."
}
New-Alias gitp GitPullKeepLocal
function FindGitFile ($x) 
{
    git log --follow -- $x
}

function IIF($condition, $truePart, $falsePart) {
    if ($condition) {
        return $truePart
    } else {
        return $falsePart
    }
}

# PowerShell functions for chess analyzer operations


function Ext2 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory=$false)]
        [string]$WorkingDirectory = $PWD.Path,
        
        [Parameter(Mandatory=$false)]
        [switch]$NoExit,
        
        [Parameter(Mandatory=$false)]
        [string[]]$ArgumentList
    )
    
    # Convert the scriptblock to a string
    $scriptString = $ScriptBlock.ToString()
    
    # Convert the script string to base64
    $bytes = [System.Text.Encoding]::Unicode.GetBytes($scriptString)
    $encodedCommand = [Convert]::ToBase64String($bytes)
    
    # Build the PowerShell arguments
    $pwshArgs = @("pwsh","-EncodedCommand", $encodedCommand)
    
    # Add NoExit if specified
    if ($NoExit) {
        $pwshArgs = @("-NoExit") + $pwshArgs
    }
    
    # Add any additional arguments
    if ($ArgumentList) {
        $pwshArgs += $ArgumentList
    }
    
    # Start the new PowerShell process
    $startInfo = @{
        FilePath = "start"
        ArgumentList = $pwshArgs
        WorkingDirectory = $WorkingDirectory
        UseNewEnvironment = $false
    }
    
    Start-Process @startInfo
}
function DebugIt {
    # SSH with port forwarding
    Write-Host "Setting up SSH tunnel for debugging..." -ForegroundColor Cyan
    Start-Process powershell -ArgumentList "-Command ssh ubuntu@54.228.92.153 -L1234:localhost:8888"
    
    # Get running pod and set up port forwarding
    Write-Host "Setting up Kubernetes port forwarding..." -ForegroundColor Cyan
    $RUN_POD = kubectl get pods | Where-Object { $_ -match "Running" } | ForEach-Object { ($_ -split '\s+')[0] } | Select-Object -First 1
    if ($RUN_POD) {
        Write-Host "Found running pod: $RUN_POD" -ForegroundColor Green
        kubectl port-forward $RUN_POD 8888:1234 --address localhost
    } else {
        Write-Host "No running pods found!" -ForegroundColor Red
    }
}

function SendReq {
    # Run the websocket client
    Write-Host "Sending request via websocket client..." -ForegroundColor Cyan
    & "C:\Users\ekarni\.pyenv\pyenv-win\versions\3.13\python3.13t.exe" c:\gitproj\chess_analyzer\websocket_client.py xx
}
function Select-Zip {
[CmdletBinding()]
Param(
    [Parameter(Mandatory=$true, Position=0)]
    $First,

    [Parameter(Position=1)]
    $Second = (0..([int]::MaxValue)),

    [Parameter(Position=2)]
    $ResultSelector = { ,$args }
)

# If Second is not explicitly provided, default to zipping with indices (like Python enumerate)
if ($PSBoundParameters.Count -eq 1) {
    $Second = 0..([int]::MaxValue)
}

[System.Linq.Enumerable]::Zip($First, $Second, [Func[Object, Object, Object[]]]$ResultSelector)
} 

function Tuple-Zip { 
    param (
        [Parameter(Mandatory=$true)]
        [array]$Array1,
        
        [Parameter(Mandatory=$true)]
        [array]$Array2
    )
    $zipped= select-Zip $Array1 $Array2 
    return @($zipped.ForEach({ [System.Tuple]::Create($_[0], $_[1]*100) })) 
}

function Find {
 <# 
 .SYNOPSIS 
 
 Does find files similar to find in bash 
 .PARAMETER name 
     Filters name inside like (*a*) is accepted
 .PARAMETER norecurse 
         Don't do it recursively 
 .PARAMETER justname 
     Return the name and not full path
 .PARAMETER nohidden
     Exclude hidden files and directories
 .PARAMETER exec
  Accept a script block to execute and pass it $_ param
 #> 
 param(
     [Parameter(Mandatory=$true)]
     [string]$path ,
 
     [Parameter(Mandatory=$false)]
     [string]$fullpath ="*",
 
     [Parameter(Mandatory=$false)]
     [string]$name ="*",
 
     [Parameter(Mandatory=$false)]
     [ValidateSet('All', 'File', 'Directory')]
     [string]$type = 'All',
 
     [switch]$norecurse = $false ,
     [switch]$justname = $false ,
     [switch]$retitem = $false ,
     [switch]$nohidden = $false ,
     [switch]$noignoreerr = $false ,
 
 [Parameter(Mandatory=$false)]
     [scriptblock]$exec=$null 
 
 )
     $act= IIF $noignoreerr Continue SilentlyContinue
 
     Get-ChildItem -Path $path -Recurse:$(-not $norecurse) -Force:$(-not $nohidden) -ErrorAction $act |
     Where-Object { $_.Name -like $name } | Where-Object { $_.FullName -like $fullpath } |  ForEach-Object { 
         $x=$_
         $item = switch ($type) {
             'All' { $x }
             'File' { if (!$x.PSIsContainer) { $x } }
             'Directory' { if ($x.PSIsContainer) { $x } }
         }
         
         if ($item) {
             if ($retitem) {
                 $item
             } else {
                 if ($exec) {
                     $exec.InvokeWithContext($null, [psvariable]::new('_', $item))
                 }
                 
                 if ($justname) {
                     $item.Name
                 } else {
                     $item.FullName
                 }
             }
         }
     }
 
 }
 
 function FilesInCommit($cmt) {
 <#
 .DESCRIPTION
 Gets list of files changed in a specific git commit
 .PARAMETER cmt
 Commit hash or reference
 .OUTPUTS
 Array of file paths modified in the commit
 #>
     return $(git diff-tree --no-commit-id --name-only $cmt -r)
 }
 function RunPreCommitOnCommit($cmt) {
 <#
 .DESCRIPTION
 Runs pre-commit hooks on files changed in a specific commit
 .PARAMETER cmt
 Commit hash or reference to check
 #>
     pre-commit run  --files $(git diff-tree --no-commit-id --name-only $cmt -r)
 }
 function AddOnModified($ext) {
 <#
 .DESCRIPTION
 Stages modified files in git, optionally filtering by extension
 .PARAMETER ext
 Optional file extension to filter by
 #>
 
     if ($ext) {
 
             git add $(git ls-files --modified | select-string $ext)
     }
     else {
     git add $(git ls-files --modified)
     }
 }
 
 function GitChangesForFile($fil) {
 <#
 .DESCRIPTION
 Shows all changes made to a specific file across git history
 .PARAMETER fil
 File path to check
 #>
 <#
 .DESCRIPTION
 Shows all changes made to a specific file across git history
 .PARAMETER fil
 File path to check
 #>
 
     git log --reflog --follow --format=%h -- $fil | %{ Write-host " change $_"; git --no-pager diff $_ -- $fil } 
 }
 function GitLogForFile($fil) {
 <#
 .DESCRIPTION
 Shows commit history for a file or directory
 .PARAMETER fil
 File or directory path to check
 #>
 <#
 .DESCRIPTION
 Shows commit history for a file or directory
 .PARAMETER fil
 File or directory path to check
 #>
     git log --all --first-parent --remotes --reflog --author-date-order -- $fil
 }
 function StagedFiles() {
     <#
         .DESCRIPTION
         Lists files currently staged in git
         .OUTPUTS
         Array of staged file paths
 #>
         git diff --name-only --cached
 }
 function GitPullAdvanced ()
 {
 <#
 .DESCRIPTION
 Performs git pull while preserving local changes using stash
 .PARAMETER keeplocalinconflict
 Switch to keep local changes in case of conflicts
 .PARAMETER dontkeepstash
 Switch to discard stash after applying changes
 .PARAMETER checkout
 do checkout instead of pull
 .PARAMETER useremotefiles
 Switch to use all files from remote branch, overriding local changes
 #>
     param (
         [parameter()][switch]$keeplocalinconflict =$null,
         [parameter()][switch]$dontkeepstash=$false,
         [parameter()][switch]$checkout=$false,
         [parameter()][switch]$useremotefiles=$false,
         [parameter(Position=0)][string]$branch,
         [parameter()][string]$repository
     )
     function DoPull($x)
     {
         if ($branch )
         {
             if (-not $repository) {Write-Error "no repo";return }
             git pull --rebase $repository $branch @x
         }
         else 
         {
             git pull @x
         }
 
     }
 try { 
     $oldrend= $PSStyle.OutputRendering 
     $PSStyle.OutputRendering = 1
 
 
     $commit_hash=$(git rev-parse HEAD)
     git stash save | Out-Null
     $outcheckout=""
     git fetch 
     if ($checkout)
     {
         $outcheckout=git checkout $branch 2>&1 
         echo $outcheckout
     }else {
         DoPull
     }
     if ($outcheckout -like "*The following untracked working tree files would be overwritten*") {
         $y= $outcheckout | where { $_  -like "`t*" }  | %{ $($_ | Out-string) -replace "`t","" } | %{ $_ -replace "`r`n","" } | %{ $_ -replace "`n","" }
         echo "adding to stash $y"
         git stash pop
         $y | %{ git add $_ }
         git stash  | Out-Null
         git checkout $branch 2>&1
 
     }
     if (-not $?)
     {
         Write-Host "unsucessful $LASTEXITCODE" #for now
         $conflicts = $(git diff --name-only --diff-filter=U  )
         if ((-not $conflicts))
         {
             $z= askyn "countinue" 
             if (-not $z){return}
         }
     }
 
     $conflicts = $(git diff --name-only --diff-filter=U  )
     $changes = $(git diff --name-only $commit_hash )
     if ($conflicts)
     {
         if ($checkout) {
             Write-Host "wtf "
                 return
         }
         Write-Host "There are merge conflicts. Please run git pull. Aborting"
     $userInput = Read-Host -Prompt @"
Do you want to resolve  conflict using ours/theirs/no? 
no just cancels (type exactly)
"@ 
 
         if ($userInput -eq "no" ){
             return 
         }
         git rebase --abort
         DoPull @("-X","$userInput")
         if (-not $?){Write-Host "unsucessful pull";return}
     }
 
     # Checkout files from the stash
     git checkout stash -- . | Out-Null
     git reset | Out-Null
     $localch= $(git diff --name-only)
     $int = $localch | ?{ $changes -contains $_  } 
     if ($int)
     {
         Write-Host "Following files are different in local branch: $int " 
         if ($(-not ($keeplocalinconflict)))
         {
             if (-not $useremotefiles) 
             {
             $userInput = Read-Host -Prompt "Do you want to keep local changes in case of conflict? (y/n/apply)"
             } else{ $userInput='n'} 
             if ($userInput -eq "y") {
                 $keeplocalinconflict = $true
             } else {
                 Write-Host "reseting to remote"
                     if ($branch)
                     {
                         Write-Host "git checkout $branch @int "
                         git checkout $branch -- @int 
                     }
                     else 
                     {
                         git checkout -- @int
                     }
             } 
             if ($userInput -eq "apply")
             {
                 git stash apply
             }
         }
     }
 
     if ($dontkeepstash) 
     {
         git stash drop
     }
 }
 finally 
 {$PSStyle.OutputRendering=$oldrend}
 # Drop the stash
 }
 
 function SquashCommits([int]$count) {
 <#
 .DESCRIPTION
 Squashes the last N commits into a single commit using interactive rebase
 .PARAMETER count
 Number of commits to squash together
 #>
 $commitHashes = git log --pretty=format:%h -n $count
 
 $commands= ( 0..$($count-2) ) |  %{   "sed -i 's/^pick $($commitHashes[$_])/squash $($commitHashes[$_])/' `$file"    }
 $st= $commands -join "`n"
 
 $st="func() {
 local file=`$1
 $st
 }; func"
 Write-Host $st
 $env:GIT_SEQUENCE_EDITOR=$st
 try{
         git rebase -i HEAD~$count
     }finally
     {
         Remove-Item Env:\GIT_SEQUENCE_EDITOR
     }
 }
  function Find-GitFileFromReflog {
 <#
 .SYNOPSIS
 Searches git reflog for exact file paths based on partial filename matches
 
 .DESCRIPTION
 This function searches through the git reflog (all log entries) to find exact file paths
 that match a partial filename. It uses git log --all --name-only to examine all commits
 and their changed files, then filters results based on the partial filename provided.
 
 .PARAMETER PartialFilename
 Partial filename to search for (e.g., "config", "*.ps1", "test")
 
 .PARAMETER MaxResults
 Maximum number of results to return (default: 50)
 
 .PARAMETER IncludeDeleted
 Switch to include files that have been deleted
 
 .EXAMPLE
 Find-GitFileFromReflog "config"
 Finds all file paths containing "config" in their name
 
 .EXAMPLE
 Find-GitFileFromReflog "*.ps1" -MaxResults 10
 Finds up to 10 PowerShell files
 
 .EXAMPLE
 Find-GitFileFromReflog "test" -IncludeDeleted
 Finds all files with "test" in name, including deleted ones
 
 .OUTPUTS
 Array of unique file paths that match the partial filename
 #>
     [CmdletBinding()]
     param(
         [Parameter(Mandatory=$true, Position=0)]
         [string]$PartialFilename,
         
         [Parameter(Mandatory=$false)]
         [int]$MaxResults = 50,
         
         [Parameter(Mandatory=$false)]
         [switch]$IncludeDeleted
     )
     
     try {
         # Check if we're in a git repository
         $gitRoot = git rev-parse --show-toplevel 2>$null
         if ($LASTEXITCODE -ne 0) {
             Write-Error "Not in a git repository"
             return
         }
         
         Write-Verbose "Searching git reflog for files matching: $PartialFilename"
         
         # Get all files from git log --all (includes reflog entries)
         $gitCommand = "git log --all --name-only --pretty=format:"
         if ($IncludeDeleted) {
             $gitCommand += " --diff-filter=ACDMRT"
         }
         
         $allFiles = Invoke-Expression $gitCommand | Where-Object { $_ -ne "" }
         
         # Convert partial filename to regex pattern for flexible matching
         $pattern = $PartialFilename -replace '\*', '.*' -replace '\?', '.'
         
         # Filter files that match the pattern
         $matchingFiles = $allFiles | Where-Object { 
             $fileName = Split-Path $_ -Leaf
             $fileName -match $pattern -or $_ -match $pattern
         } | Sort-Object -Unique
         
         # Limit results if specified
         if ($MaxResults -gt 0) {
             $matchingFiles = $matchingFiles | Select-Object -First $MaxResults
         }
         
         if ($matchingFiles.Count -eq 0) {
             Write-Warning "No files found matching pattern: $PartialFilename"
             return
         }
         
         Write-Host "Found $($matchingFiles.Count) unique file(s) matching '$PartialFilename':" -ForegroundColor Green
         
         # Return results with additional metadata
         $results = @()
         foreach ($file in $matchingFiles) {
             # Check if file currently exists
             $exists = Test-Path (Join-Path $gitRoot $file)
             
             # Get last commit that touched this file
             $lastCommit = git log -1 --pretty=format:"%h %ai %s" -- $file 2>$null
              git log --reflog --all --follow --format=%h --
              $reflog =  git log --reflog --all --follow --format=%h -- $file 
             
             $result = [PSCustomObject]@{
                 Path = $file
                 FullPath = Join-Path $gitRoot $file
                 Exists = $exists
                 LastCommit = $lastCommit
                 RefLog = $reflog
                 FileName = Split-Path $file -Leaf
             }
             $results += $result
         }
         
         return $results
     }
     catch {
         Write-Error "Error searching git reflog: $_"
     }
 }
 
 function UnfilterList ($ls)
 {
     Process { 
         $el=$_; 
         If (-not $( $ls | where { $el -imatch $_}) )
         {
             return $_ 
         }
     }
 
 }
 
 function FilterList ($ls)
 {
     Process { 
         $el=$_; 
         If ($( $ls | where { $el -imatch $_}) )
         {
             return $_ 
         }
     }
 
 }
 function ExtendedPSList($file)
 {
     <#
         .DESCRIPTION
         Gets extended process information including user, command line and creation date
         .PARAMETER file
         Optional file to write output to
         .OUTPUTS
         Array of process objects with extended properties
 #>
         return  Get-WmiObject Win32_Process | Select Name,ProcessId,ParentProcessId,@{Name="UserName";Expression={$_.GetOwner().User}}, CommandLine, @{Name='CreationDate'; Expression={ [System.Management.ManagementDateTimeConverter]::ToDateTime($_.CreationDate)}}
 }
 function Ext
 {<#
     .DESCRIPTION
         Executes script block in new powershell env
 #>
         [CmdletBinding()]
         param (
                 [parameter(Position=0)]
                 [ScriptBlock]$ScriptBlock
 
               )
 
             $cmd=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($ScriptBlock.ToString()))
             Start-Process -FilePath  "$([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)" -ArgumentList ("-EncodedCommand",$cmd)
 }
 function ExtPwsh
 {<#
     .DESCRIPTION
         Executes script block in new powershell env
 #>
         [CmdletBinding()]
         param (
                 [parameter(Position=0)]
                 [ScriptBlock]$ScriptBlock
 
               )
 
             $cmd=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($ScriptBlock.ToString()))
             Start-Process "pwsh" -ArgumentList ("-EncodedCommand",$cmd)
 }
 Function DoGridView ($v) 
 {
     $v | Export-Clixml -Path c:\temp\outgridview.tmp
         ExtPwsh { try{  $v = Import-Clixml -Path c:\temp\outgridview.tmp 
             $v | Out-GridView
         } catch {} 
 
         Read-Host -Prompt "Press Enter to continue"
         }
 
 }
 function IntroduceGitTreeAlias
 {
     git config --global alias.tree "log --oneline --decorate --all --graph"
 }

function Get-MD5 {
    <#
    .SYNOPSIS
    Calculate MD5 hash for a string or file

    .DESCRIPTION
    Computes the MD5 hash of a string or file and returns it as a hexadecimal string

    .PARAMETER String
    The string to hash

    .PARAMETER Path
    Path to the file to hash

    .EXAMPLE
    Get-MD5 -String "hello world"

    .EXAMPLE
    Get-MD5 -Path "C:\file.txt"
    #>
    [CmdletBinding(DefaultParameterSetName='String')]
    param(
        [Parameter(Mandatory=$true, ParameterSetName='String', Position=0)]
        [string]$String,

        [Parameter(Mandatory=$true, ParameterSetName='File')]
        [string]$Path
    )

    if ($PSCmdlet.ParameterSetName -eq 'File') {
        (Get-FileHash -Algorithm MD5 -Path $Path).Hash
    }
    else {
        $md5 = [System.Security.Cryptography.MD5]::Create()
        $hash = $md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($String))
        [System.BitConverter]::ToString($hash) -replace '-', ''
    }
}
Function Format-ErrorWithStackTrace($ErrorRecord)
{
    # Helper function to get source line from file
    function Get-SourceLine($scriptPath, $lineNumber) {
        if ($scriptPath -and $lineNumber -and (Test-Path $scriptPath)) {
            try {
                $lines = Get-Content $scriptPath -ErrorAction SilentlyContinue
                if ($lines -and $lineNumber -le $lines.Count) {
                    return $lines[$lineNumber - 1].Trim()
                }
            } catch {
                # Silently continue if we can't get source line
            }
        }
        return $null
    }

    # Helper function to enhance stack trace with source lines
    function Add-SourceLinesToStackTrace($stackTrace) {
        if (-not $stackTrace) { return "" }

        $enhancedTrace = ""
        $lines = $stackTrace -split "`n"

        foreach ($line in $lines) {
            $enhancedTrace += $line + "`n"

            # Parse stack trace line to extract file path and line number
            # Format: "at <ScriptBlock>, <path>: line <number>"
            if ($line -match 'at .+, (.+):\s*line\s+(\d+)') {
                $scriptPath = $matches[1]
                $lineNum = [int]$matches[2]

                $sourceLine = Get-SourceLine $scriptPath $lineNum
                if ($sourceLine) {
                    $enhancedTrace += "   SOURCE: $sourceLine`n"
                }
            }
        }

        return $enhancedTrace
    }

$errorInfo = @"
ERROR DETAILS:
==============
Message: $($ErrorRecord.Exception.Message)
Exception Type:
$($ErrorRecord.Exception.GetType().FullName)

STACK TRACE:
============
$(Add-SourceLinesToStackTrace $ErrorRecord.ScriptStackTrace)

EXCEPTION STACK TRACE:
=====================
$($ErrorRecord.Exception.StackTrace)

"@

# Add inner exception if it exists
        if ($ErrorRecord.Exception.InnerException) {
            $errorInfo += @"
INNER EXCEPTION:
================
Message:
$($ErrorRecord.Exception.InnerException.Message)
Type: $($ErrorRecord.Exception.InnerException.GetType().FullName)
Stack Trace:
$($ErrorRecord.Exception.InnerException.StackTrace)
"@
        }

# Add position info
$errorInfo += @"
POSITION:
=========
Line:
$($ErrorRecord.InvocationInfo.ScriptLineNumber)
Offset: $($ErrorRecord.InvocationInfo.OffsetInLine)
Script: $($ErrorRecord.InvocationInfo.ScriptName)
Command: $($ErrorRecord.InvocationInfo.MyCommand)

"@

    # Add source line at error position
    $sourceLine = Get-SourceLine $ErrorRecord.InvocationInfo.ScriptName $ErrorRecord.InvocationInfo.ScriptLineNumber
    if ($sourceLine) {
        $errorInfo += @"
SOURCE LINE:
============
$sourceLine

"@
    }

    return $errorInfo
} 
function FindFileRg {
    <#
    .SYNOPSIS
    Find all files and search them with ripgrep

    .DESCRIPTION
    Recursively finds files that match pattern (rg)

    .PARAMETER SearchString
    The string/pattern to search for using ripgrep

    .PARAMETER Path
    The starting directory path (default: current directory)

    .PARAMETER FilePattern
    Optional file pattern to filter files (e.g., "*.ps1", "*.txt")

    .EXAMPLE
    FindRg "function"
    Searches for "function" in all files in current directory

    .EXAMPLE
    FindRg "TODO" -Path "C:\Projects" -FilePattern "*.cs"
    Searches for "TODO" in all .cs files under C:\Projects
    #>
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$SearchString,

        [Parameter(Position=1)]
        [string]$Path = ".",

        [Parameter()]
        [string]$FilePattern = "*"
    )

    # Get all files using Find function
    $files = @(Find -path $Path -name $FilePattern -type File)

    if ($files.Count -gt 0) {
        # Pass files list to ripgrep as arguments
        echo $files | rg $SearchString -

    } else {
        Write-Warning "No files found in path: $Path"
    }
}

function Get-Histogram {
    [CmdletBinding(DefaultParameterSetName='BucketCount')]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, Position=1)]
        [ValidateNotNullOrEmpty()]
        [array]
        $InputObject
        ,
        [Parameter(Position=2)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Property
        ,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [float]
        $Minimum
        ,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [float]
        $Maximum
        ,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias('Width')]
        [float]
        $BucketWidth = 1
        ,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [Alias('Count')]
        [float]
        $BucketCount
        ,
        [Parameter()]
        [switch]
        $Visualize
        ,
        [Parameter()]
        [ValidateRange(1, 200)]
        [int]
        $BarWidth = 73
        ,
        [Parameter()]
        [switch]
        $Weighted
    )

    Begin {
        Write-Verbose ('[{0}] Initializing' -f $MyInvocation.MyCommand)

        $Buckets = @{}
        $Data = @()
    }

    Process {
        Write-Verbose ('[{0}] Processing {1} items' -f $MyInvocation.MyCommand, $InputObject.Length)

        $InputObject | ForEach-Object {
            if ($Weighted) {
                # Expect data in format (probability, value) or [probability, value]
                if ($_ -is [array] -and $_.Count -eq 2) {
                    $Data += [PSCustomObject]@{
                        Weight = $_[0]
                        Value = $_[1]
                    }
                } elseif ($_.GetType().ToString() -like 'System.Tuple*') {
                    $Data += [PSCustomObject]@{
                        Weight = $_.Item1
                        Value = $_.Item2
                    }
                } else {
                    Write-Host $_
                    throw ('Weighted data must be in format (probability, value) or [probability, value]')
                }
            } else {
                if ($Property) {
                    if (-Not ($_ | Select-Object -ExpandProperty $Property -ErrorAction SilentlyContinue)) {
                        throw ('Input object does not contain a property called <{0}>.' -f $Property)
                    }
                }
                $Data += $_
            }
        }
    }

    End {
        Write-Verbose ('[{0}] Building histogram' -f $MyInvocation.MyCommand)

        Write-Debug ('[{0}] Retrieving measurements from upstream cmdlet.' -f $MyInvocation.MyCommand)
        if ($Weighted) {
            $Stats = $Data | Microsoft.PowerShell.Utility\Measure-Object -Minimum -Maximum -Property Value
        } elseif ($Property) {
            $Stats = $Data | Microsoft.PowerShell.Utility\Measure-Object -Minimum -Maximum -Property $Property
        } else {
            $Stats = $Data | Microsoft.PowerShell.Utility\Measure-Object -Minimum -Maximum
        }

        if (-Not $PSBoundParameters.ContainsKey('Minimum')) {
            $Minimum = $Stats.Minimum
            Write-Debug ('[{0}] Minimum value not specified. Using smallest value ({1}) from input data.' -f $MyInvocation.MyCommand, $Minimum)
        }
        if (-Not $PSBoundParameters.ContainsKey('Maximum')) {
            $Maximum = $Stats.Maximum
            Write-Debug ('[{0}] Maximum value not specified. Using largest value ({1}) from input data.' -f $MyInvocation.MyCommand, $Maximum)
        }
        if (-Not $PSBoundParameters.ContainsKey('BucketCount')) {
            $BucketCount = [math]::Ceiling(($Maximum - $Minimum) / $BucketWidth)
            Write-Debug ('[{0}] Bucket count not specified. Calculated {1} buckets from width of {2}.' -f $MyInvocation.MyCommand, $BucketCount, $BucketWidth)
        }
        if ($BucketCount -gt 100) {
            Write-Warning ('[{0}] Generating {1} buckets' -f $MyInvocation.MyCommand, $BucketCount)
        }

        Write-Debug ('[{0}] Building buckets using: Minimum=<{1}> Maximum=<{2}> BucketWidth=<{3}> BucketCount=<{4}>' -f $MyInvocation.MyCommand, $Minimum, $Maximum, $BucketWidth, $BucketCount)
        $OverallCount = 0
        $Buckets = 1..$BucketCount | ForEach-Object {
            [pscustomobject]@{
                Index         = $_
                lowerBound    = $Minimum + ($_ - 1) * $BucketWidth
                upperBound    = $Minimum +  $_      * $BucketWidth
                Count         = 0
                RelativeCount = 0
                Group         = @()
                PSTypeName    = 'HistogramBucket'
            }
        }

        Write-Debug ('[{0}] Building histogram' -f $MyInvocation.MyCommand)
        $Data | ForEach-Object {
            if ($Weighted) {
                $Value = $_.Value
                $Weight = $_.Weight
            } elseif ($Property) {
                $Value = $_.$Property
                $Weight = 1
            } else {
                $Value = $_
                $Weight = 1
            }

            if ($Value -ge $Minimum -and $Value -le $Maximum) {
                $BucketIndex = [math]::Floor(($Value - $Minimum) / $BucketWidth)
                if ($BucketIndex -lt $Buckets.Length) {
                    $Buckets[$BucketIndex].Count += $Weight
                    $Buckets[$BucketIndex].Group += $_
                    $OverallCount += $Weight
                }
            }
        }

        Write-Debug ('[{0}] Adding relative count' -f $MyInvocation.MyCommand)
        $Buckets | ForEach-Object {
            if ($OverallCount -gt 0) {
                $_.RelativeCount = $_.Count / $OverallCount
            } else {
                $_.RelativeCount = 0
            }
        }

        if ($Visualize) {
            Write-Debug ('[{0}] Generating visualization' -f $MyInvocation.MyCommand)

            $MaxCount = ($Buckets | Measure-Object -Property Count -Maximum).Maximum

            $Buckets | Where-Object { $_.Count -gt 0 } | ForEach-Object {
                # Format the bucket range/label
                $Label = if ($Property) {
                    "[{0:N1}-{1:N1}]" -f $_.lowerBound, $_.upperBound
                } else {
                    "[{0:N1}-{1:N1}]" -f $_.lowerBound, $_.upperBound
                }

                # Calculate percentage
                $Percentage = if ($OverallCount -gt 0) {
                    [int](100 * $_.Count / $OverallCount)
                } else {
                    0
                }

                # Calculate bar length based on proportion to max count
                $BarLength = if ($MaxCount -gt 0) {
                    [int]($BarWidth * $_.Count / $MaxCount)
                } else {
                    0
                }

                # Create the bar
                $Bar = ("*" * $BarLength).PadRight($BarWidth)

                # Format and display the line
                $DataPointCount = $_.Group.Length
                $Line = "{0} {1}% {2} [n={3}, wt={4:N2}]" -f `
                    $Label.PadLeft(20), `
                    $Percentage.ToString().PadLeft(3), `
                    $Bar, `
                    $DataPointCount, `
                    $_.Count

                Write-Host $Line -ForegroundColor Green
            }
        }

        Write-Debug ('[{0}] Returning histogram' -f $MyInvocation.MyCommand)
        $Buckets
    }
}
function SetPrimary()
{
    $di=  $(Get-DisplayInfo | ? {$_.DisplayName -eq  "DELL U2419H"} ).DisplayId
    Set-DisplayPrimary -DisplayId $di
}
function RunWTAdmin()
{
     Start-process -Verb RunAs "C:\Users\ekarni\AppData\Local\Microsoft\WindowsApps\wt.exe"
}
