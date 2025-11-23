<#
.SYNOPSIS
    Replace-InQuote (Alias: qsed) - Scoped Regular Expression Replacer.

    Performs text replacement ONLY within specified delimiters
    (e.g., quotes, brackets).

    It ignores text outside these delimiters.

.DESCRIPTION
    This tool allows for surgical text modification. Instead of running a replace
    operation on the whole line, it first isolates text blocks wrapped in 
    start/end tokens (default is double quotes), and applies the replacement 
    only there.

    It is powered by a C# class using MatchEvaluators for high performance.

    Common Use Cases:
    1. Replacing commas with dots inside CSV quotes without breaking the CSV structure.
    2. Redacting sensitive info inside brackets [Secret].
    3. Normalizing whitespace inside parentheses.

    LIMITATIONS:
    - Nested delimiters (e.g., "(outer (inner) outer)") are NOT supported. 
    The regex uses non-greedy matching and will stop at the first closing delimiter.

.LINK
    csv2txt, csv2unquote, Replace-InQuote

.NOTES
    about_Regular_Expressions - PowerShell
    https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_regular_expressions

    Regular Expression Language - Quick Reference - .NET
    https://learn.microsoft.com/en-us/dotnet/standard/base-types/regular-expression-language-quick-reference

.PARAMETER Pattern
    The Regex pattern to search for INSIDE the delimiters.

.PARAMETER Replacement
    The string to replace the matches with.

.PARAMETER StartToken
    The delimiter that starts the scope. Default is double quote (").

.PARAMETER EndToken
    The delimiter that ends the scope. Default is double quote (").

.PARAMETER Path
    Path to the input file. Triggers high-speed file processing mode.

.EXAMPLE
    # Scenario: Clean up a CSV where fields contain commas.
    # Input:  "Smith, John", "Doe, Jane"
    # Action: Replace ',' with '.' ONLY inside the quotes.
    $data | Replace-InQuote -Pattern "," -Replacement "."

    # Output: "Smith. John", "Doe. Jane"

.EXAMPLE
    # Scenario: Replace spaces with underscores inside brackets [ ].
    "Data [Type A] [Type B]" | Replace-InQuote -Start "[" -End "]" -Pattern "\s" -Replacement "_"

    # Output: "Data [Type_A] [Type_B]"

.EXAMPLE
    # Scenario: Remove all digits inside single quotes.
    "ID: 'A123' Code: 'B456'" | Replace-InQuote -Start "'" -End "'" -Pattern "\d" -Replacement ""

    # Output: "ID: 'A' Code: 'B'"

#>
function Replace-InQuote {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [Alias("f","from")]
        [string]$Pattern,

        [Parameter(Mandatory=$true, Position=1)]
        [Alias("t","to")]
        [string]$Replacement,

        [Parameter(Mandatory=$false)]
        [string]$StartToken = '"',

        [Parameter(Mandatory=$false)]
        [string]$EndToken = '"',

        [Parameter(Mandatory=$false)]
        [Alias("p")]
        [string]$Path,

        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [object]$InputObject
    )

    begin {
        # --- Load C# Backend ---
        if (-not ('ScopedRegexReplacer' -as [type])) {
            $scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
            
            # Paths to DLL and Source
            [string] $libFileName = "Replace-InQuote_function"
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

        # Initialize Logic for Pipeline Mode
        if (-not $Path) {
            Write-Verbose "Mode: Pipeline Stream"
            # We create the instance once to reuse the compiled Regex
            $replacer = [ScopedRegexReplacer]::new($StartToken, $EndToken, $Pattern, $Replacement)
        }
        else {
            Write-Verbose "Mode: High-Speed File Access"
        }
    }

    process {
        if (-not $Path) {
            # Handle Pipeline Input
            if ($InputObject -is [System.IO.FileInfo]) {
                # Case: Piped file object (Get-ChildItem)
                $lines = Get-Content -Path $InputObject.FullName
                foreach ($line in $lines) {
                    Write-Output $replacer.ProcessLine($line)
                }
            }
            else {
                # Case: Piped String
                $lineString = [string]$InputObject
                Write-Output $replacer.ProcessLine($lineString)
            }
        }
    }

    end {
        if ($Path) {
            # Handle Direct File Input (Fastest)
            $resolvedPath = (Resolve-Path $Path).Path
            
            try {
                $results = [ScopedRegexReplacer]::ProcessFile(
                    $resolvedPath, 
                    $StartToken, 
                    $EndToken, 
                    $Pattern, 
                    $Replacement
                )
                
                foreach ($line in $results) {
                    Write-Output $line
                }
            }
            catch {
                Write-Error "File Processing Error: $_"
            }
        }
    }
}
# set alias
[String] $tmpAliasName = "qsed"
[String] $tmpCmdName   = "Replace-InQuote"
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
