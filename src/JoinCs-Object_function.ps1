<#
.SYNOPSIS
    JoinCs-Object (Alias: joioncs) - High-performance INNER/OUTER Join using C#.

    Performs an INNER or OUTER join on two datasets (Master and Transaction).
    This version is highly optimized: it uses an external C# class (JoinCs-Object_function.cs)
    to perform a Hash Join, and, crucially, to read CSV files directly from disk 
    when file paths are provided to maximize speed (O(M + N)).

    DEPENDENCY:
    - Requires 'JoinCs-Object_function.cs' to be in the same directory as this script.

.DESCRIPTION
    Receive a transaction object via the pipeline (or -Tran parameter),
    combine it with the master object using common key(s), and return it.

    File-to-File Join: Fastest path (C# handles file I/O and parsing).
    Object-to-File/Object-to-Object Join: Slower, as PowerShell objects must be processed.

.PARAMETER Master
    The Master dataset. Can be an array of objects or a file path to a CSV.
    If a file path is used, C# directly loads and parses it for maximum speed.

.PARAMETER Tran
    The Transaction dataset. Can be an array of objects, a file path, or input 
    from the pipeline. File path input is the fastest path.

.PARAMETER MasterKey
    The property name(s) in the Master dataset to use as the join key.

.PARAMETER TransKey
    The property name(s) in the Transaction dataset to use as the join key.
    Defaults to MasterKey if not specified.

.PARAMETER Where
    A script block to filter the joined results (executed after joining).

.PARAMETER AddSuffixToMasterProperty
    Suffix to append to Master property names to avoid collisions with Transaction properties.
    Default: "m_"

.PARAMETER AddPrefixToMasterProperty
    Prefix to prepend to Master property names.
    Default: "" (None)

.PARAMETER Delimiter
    Delimiter character to use if inputs are CSV files. Default: ","

.PARAMETER MasterHeader
    Header columns if Master CSV lacks headers or needs renaming.

.PARAMETER TranHeader
    Header columns if Transaction CSV lacks headers or needs renaming.

.PARAMETER Dummy
    Value to use for Master columns when no match is found. Default: $Null.

.PARAMETER OnlyIfInBoth
    (Inner Join) Output only if the key exists in both datasets.

.PARAMETER OnlyIfInTransaction
    (Left Anti Join) Output only if the key does NOT exist in the Master dataset.

.PARAMETER IncludeMasterKey
    If set, includes the key columns from the Master dataset in the output.
    By default, join keys from Master are excluded to avoid duplication.

.EXAMPLE
    # 1. Fastest Path: Join two large CSV files directly using file paths.
    JoinCs-Object -Master "master.csv" -Tran "tran.csv" -On "EmployeeID"

.EXAMPLE
    # 2. Pipeline Input (slower but flexible)
    Import-Csv tran.csv | JoinCs-Object (Import-Csv master.csv) -On Id

.EXAMPLE
    # 3. Join file to file and filter results
    JoinCs-Object -Master $m -Tran $t -On Id -TransKey EmployeeId -Where { [int]$_.Amount -gt 500 }

#>
function JoinCs-Object
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$True, Position=0)]
        [Alias('m')]
        [object[]] $Master,
        
        [Parameter(Mandatory=$False)]
        [Alias('t')]
        [object[]] $Tran,
        
        [Parameter(Mandatory=$True, Position=1)]
        [Alias('On')]
        [string[]] $MasterKey,
        
        [Parameter(Mandatory=$False)]
        [Alias('tkey')]
        [string[]] $TransKey,
        
        [Parameter(Mandatory=$False)]
        [scriptblock] $Where,
        
        [Parameter(Mandatory=$False)]
        [Alias('s')]
        [string] $AddSuffixToMasterProperty = "m_",
        
        [Parameter(Mandatory=$False)]
        [Alias('p')]
        [string] $AddPrefixToMasterProperty,
        
        [Parameter(Mandatory=$False)]
        [Alias('d')]
        [string] $Delimiter = ",",
        
        [Parameter(Mandatory=$False)]
        [Alias('mh')]
        [string[]] $MasterHeader,
        
        [Parameter(Mandatory=$False)]
        [Alias('th')]
        [string[]] $TransHeader,
        
        [Parameter(Mandatory=$False)]
        [string] $Dummy = $Null,
        
        [Parameter(Mandatory=$False)]
        [switch] $OnlyIfInBoth,
        
        [Parameter(Mandatory=$False)]
        [switch] $OnlyIfInTransaction,
        
        [Parameter(Mandatory=$False)]
        [switch] $IncludeMasterKey,
        
        # This is for pipeline input
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [object[]] $InputObject
    )

    Begin
    {
        # Helper to detect if a parameter is a single, existing file path and resolve it
        function Get-ResolvedFilePath {
            param($InputObject)

            # Handle null
            if ($null -eq $InputObject) { return $null }

            # Unwrap array if it contains a single item (PS often wraps args in object[])
            $item = $InputObject
            if ($item -is [System.Collections.IEnumerable] -and $item -isnot [string]) {
                if ($item.Count -eq 1) {
                    $item = $item[0]
                } else {
                    return $null # Multiple items or empty
                }
            }

            # Handle FileInfo / DirectoryInfo objects (e.g. from Get-ChildItem)
            if ($item -is [System.IO.FileSystemInfo]) {
                $item = $item.FullName
            }

            # Check if it is a string and a valid file path
            if ($item -is [string] -and -not [string]::IsNullOrWhiteSpace($item)) {
                if (Test-Path -LiteralPath $item -PathType Leaf) {
                    # Return absolute path to avoid CWD issues between PS and C#
                    return (Convert-Path -LiteralPath $item)
                }
            }

            return $null
        }

        # Validate and resolve paths
        $resolvedMasterPath = Get-ResolvedFilePath -InputObject $Master
        $resolvedTranPath   = Get-ResolvedFilePath -InputObject $Tran

        $private:isMasterFile = $null -ne $resolvedMasterPath
        $private:isTranFile   = $null -ne $resolvedTranPath

        # --- Load C# Class ---
        # Compile the C# class if it is not already loaded in the session
        if (-not ('CsvQuoteSanitizer' -as [type])) {
            $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
            
            # Paths to DLL and Source
            [string] $libFileName = "JoinCs-Object_function"
            [string] $dllFileName = "$libFileName.dll"
            [string] $csFileName  = "$libFileName.cs"
            [string] $dllPath = Join-Path $scriptDir $dllFileName
            [string] $csPath  = Join-Path $scriptDir $csFileName
    
            # Try loading the DLL first (Recommended for production)
            if (Test-Path $dllPath) {
                Write-Verbose "Loading compiled assembly: $dllPath"
                try {
                    Add-Type -Path $dllPath
                }
                catch {
                    Write-Error "Failed to load assembly '$dllPath': $_"
                    return
                }
            }
            # Fallback to C# source compilation (Dev/Test only)
            elseif (Test-Path $csPath) {
                Write-Verbose "Compiled assembly not found. Falling back to runtime compilation of: $csPath"
                Write-Warning "Compiling C# source at runtime. For better security and performance, run '${libFileName}_build.ps1' to generate the DLL."
                try {
                    Add-Type -Path $csPath
                }
                catch {
                    Write-Error "Failed to compile C# file: $_"
                    return
                }
            }
            else {
                Write-Error "Could not find '$dllFileName' or '$csFileName' in $scriptDir."
                return
            }
        }


        # Instantiate and Initialize the engine
        $Engine = New-Object JoinerEngine
        if (-not $TransKey) { $TransKey = $MasterKey }
        $Engine.Initialize($MasterKey, $TransKey, $AddPrefixToMasterProperty, $AddSuffixToMasterProperty, $Dummy, $IncludeMasterKey.IsPresent, $Delimiter)

        # ---------------------------------------------------------------------
        # Load Master Data
        # ---------------------------------------------------------------------
        Write-Debug "Loading Master Data..."

        if ($private:isMasterFile) {
            # FAST PATH: Master is a file, use C# to load it directly
            Write-Debug "Master: Loading from file (C# Fast Path) - $resolvedMasterPath"
            $Engine.LoadMasterFile($resolvedMasterPath, $MasterHeader)
        }
        else {
            # Error handling logic
            
            # Check if user tried to pass a file path but it wasn't found
            $item = $Master
            if ($item -is [System.Collections.IEnumerable] -and $item -isnot [string] -and $item.Count -eq 1) { $item = $item[0] }
            
            if ($item -is [string] -and -not [string]::IsNullOrWhiteSpace($item)) {
                 Write-Error "Master file not found at path: '$item'. Please check that the file exists." -ErrorAction Stop
            }

            # Original error for object input
            Write-Error "The C# optimized function requires the -Master parameter to be a valid, existing file path. Please pass the path to the CSV file." -ErrorAction Stop
        }
    }

    Process
    {
        # This flag ensures that if -Tran is passed, we process it only once, 
        # and then handle the pipeline input in subsequent calls.
        if ($Tran -and -not $private:tranProcessed) {
            $private:tranProcessed = $true
            
            if ($private:isTranFile) {
                # FAST PATH: Transaction is a file, use C# to process it directly
                Write-Debug "Transaction: Processing from file (C# Fast Path) - $resolvedTranPath"
                
                # C# method returns IEnumerable<PSObject>, which PowerShell automatically handles
                $Engine.ProcessTransactionFile($resolvedTranPath, $TransHeader, $OnlyIfInBoth.IsPresent, $OnlyIfInTransaction.IsPresent) |
                ForEach-Object {
                    # Apply PowerShell specific -Where filter
                    if ($Where) {
                        if ($_ | Where-Object $Where) {
                            $_
                        }
                    } else {
                        $_
                    }
                }
            }
            else {
                # SLOWER PATH: Transaction is an object array
                Write-Debug "Transaction: Processing from object array (Slower Path)"
                $private:currentTransHeaders = @($Tran[0].PSObject.Properties.Name) # Guess headers from first object
                foreach ($item in $Tran) {
                    $result = $Engine.ProcessTransactionObject($item, $private:currentTransHeaders, $OnlyIfInBoth.IsPresent, $OnlyIfInTransaction.IsPresent)
                    if ($result) {
                        # Apply -Where filter
                        if ($Where) {
                            if ($result | Where-Object $Where) {
                                $result
                            }
                        } else {
                            $result
                        }
                    }
                }
            }
        }
        
        # Pipeline Input (Handles streaming when no -Tran file is specified)
        if ($InputObject) {
            if (-not $private:pipelineHeaderGuess) {
                # Guess headers from the first object in the pipeline
                $private:pipelineHeaderGuess = @($InputObject[0].PSObject.Properties.Name)
                Write-Debug "Pipeline: Guessed headers: $($private:pipelineHeaderGuess -join ', ')"
            }
            Write-Debug "Transaction: Processing from pipeline objects (Slower Path)"
            
            foreach ($item in $InputObject) {
                $result = $Engine.ProcessTransactionObject($item, $private:pipelineHeaderGuess, $OnlyIfInBoth.IsPresent, $OnlyIfInTransaction.IsPresent)
                if ($result) {
                    # Apply -Where filter
                    if ($Where) {
                        if ($result | Where-Object $Where) {
                            $result
                        }
                    } else {
                        $result
                    }
                }
            }
        }
    }

    End
    {
        $Engine = $null
    }
}
# set alias
[String] $tmpAliasName = "joincs"
[String] $tmpCmdName   = "JoinCs-Object"
[String] $tmpCmdPath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath $($MyInvocation.MyCommand.Name) `
    | Resolve-Path -Relative
if ( $IsWindows ){ $tmpCmdPath = $tmpCmdPath.Replace('\' ,'/') }
# is alias already exists?
if ((Get-Command -Name $tmpAliasName -ErrorAction SilentlyContinue).Count -gt 0){
    try {
        if ( (Get-Command -Name $tmpAliasName).CommandType -eq "Alias" ){
            if ( (Get-Command -Name $tmpAliasName).ReferencedCommand.Name -eq $tmpCmdName ){
                Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
                    | ForEach-Object{
                        Write-Host "$($_.DisplayName)" -ForegroundColor Green
                    }
            } else {
                throw
            }
        } elseif ( "$((Get-Command -Name $tmpAliasName).Name)" -match '\.exe$') {
            Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
                | ForEach-Object{
                    Write-Host "$($_.DisplayName)" -ForegroundColor Green
                }
        } else {
            throw
        }
    } catch {
        Write-Error "Alias ""$tmpAliasName ($((Get-Command -Name $tmpAliasName).ReferencedCommand.Name))"" is already exists. Change alias needed. Please edit the script at the end of the file: ""$tmpCmdPath""" -ErrorAction Stop
    } finally {
        Remove-Variable -Name "tmpAliasName" -Force
        Remove-Variable -Name "tmpCmdName" -Force
    }
} else {
    Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
        | ForEach-Object {
            Write-Host "$($_.DisplayName)" -ForegroundColor Green
        }
    Remove-Variable -Name "tmpAliasName" -Force
    Remove-Variable -Name "tmpCmdName" -Force
}
