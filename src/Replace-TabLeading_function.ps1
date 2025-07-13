<#
.SYNOPSIS
    Replace-TabLeading (Alias:tabsed) - Replaces leading tabs at the beginning of each line.
    
    Replaces leading tabs (or specified character)
    at the beginning of each line with a given string.

.DESCRIPTION
    This function scans each line of input (from pipeline or array) and replaces only the characters
    at the beginning of each line that match the specified `From` value (default is tab "`t") with the
    string specified in `To` (default is four spaces). Only leading matches are replaced; characters
    found later in the line are not changed.

.PARAMETER InputObject
    The input string(s), either passed directly or through the pipeline.

.PARAMETER From
    The character or string to replace when found at the beginning of a line.
    Default is a tab ("`t").

.PARAMETER To
    The string used to replace each instance of the `From` pattern.
    Default is four spaces.

.EXAMPLE
    # Replace leading tabs with two spaces
    [string[]] $tablines = @()
    [string[]] $tablines += "`t" * 2 + "line1"
    [string[]] $tablines += "`t" * 1 + "line2"
    [string[]] $tablines += "`t" * 0 + "line3"
    [string[]] $tablines += "`t" * 1 + "line4"
    $tablines | Replace-TabLeading -From "`t" -To (" " * 2)

    # Output:
    [  ][  ]line1
    [  ]line2
    line3
    [  ]line4

.EXAMPLE
    # Verbose output with tab replacement
    $tablines | Replace-TabLeading -Verbose

    # Verbose Output:
    VERBOSE: <tab><tab>line1
    [    ][    ]line1
    VERBOSE: <tab>line2
    [    ]line2
    VERBOSE: line3
    line3
    VERBOSE: <tab>line4
    [    ]line4

.EXAMPLE
    # Replace leading 4 spaces with two spaces
    [string[]] $tablines = @()
    [string[]] $tablines += " " * 4 * 2 + "line1" # 8 spaces
    [string[]] $tablines += " " * 4 * 1 + "line2" # 4 spaces
    [string[]] $tablines += " " * 4 * 0 + "line3" # 0 spaces
    [string[]] $tablines += " " * 4 * 1 + "line4" # 4 spaces
    $tablines | Replace-TabLeading -From (" " * 4) -To (" " * 2)

    # Output:
    [  ][  ]line1
    [  ]line2
    line3
    [  ]line4

#>
function Replace-TabLeading {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false, Position=0)]
        [Alias('t')]
        [string] $To = [string](' ' * 4),
        
        [Parameter(Mandatory=$false)]
        [Alias('f')]
        [string] $From = "`t",
        
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [string[]] $InputObject
    )
    begin {
        [int] $fromLength = @($From.GetEnumerator()).Length
        if ( $fromLength -gt 0){
            #pass
        } else {
            Write-Error "-From Could not specified." -ErrorAction Stop
        }
        [regex] $escapedRegex = [regex]::Escape($From)
        Write-Verbose "FromCount: $($fromLength)"
    }
    process {
        [string] $line = $_
        if ($line -match "^(?<tabs>($escapedRegex)+)") {
            
            [int] $tabCountOrig = $matches['tabs'].Length
            if ( $fromLength -eq 1){
                [int] $tabCount = $tabCountOrig
            } else {
                [int] $tabCount = [math]::Floor( $tabCountOrig / $fromLength )
            }
            Write-Verbose "$(('<tab>' * $tabCount) + $line.Substring($tabCountOrig))"
            Write-Verbose "tabCount: $tabCount"
            [string] $line = ($To * $tabCount) + $line.Substring($tabCountOrig)
        } else {
            Write-Verbose $line
        }
        Write-Output $line
    }
}

# set alias
# This block automatically sets an alias for the function upon script load.
[String] $tmpAliasName = "tabsed"
[String] $tmpCmdName = "Replace-TabLeading"

# Get the script's own path to inform the user if an alias conflict occurs.
[String] $tmpCmdPath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath $($MyInvocation.MyCommand.Name) `
    | Resolve-Path -Relative

# Convert script path to Unix-style for display clarity if on Windows.
if ( $IsWindows ){ $tmpCmdPath = $tmpCmdPath.Replace('\' ,'/') }

# Check if an alias with the desired name already exists.
if ((Get-Command -Name $tmpAliasName -ErrorAction SilentlyContinue).Count -gt 0){
    try {
        # If the existing command is an alias and refers to this function, just re-set it.
        if ( (Get-Command -Name $tmpAliasName).CommandType -eq "Alias" ){
            if ( (Get-Command -Name $tmpAliasName).ReferencedCommand.Name -eq $tmpCmdName ){
                Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
                    | ForEach-Object{
                        Write-Host "$($_.DisplayName) (updated)" -ForegroundColor Green # Indicate alias was updated
                    }
            } else {
                # Alias exists but points to a different command; throw error.
                throw
            }
        # If the existing command is an executable (e.g., gitbash.exe), allow overriding with this alias.
        } elseif ( "$((Get-Command -Name $tmpAliasName).Name)" -match '\.exe$') {
            Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
                | ForEach-Object{
                    Write-Host "$($_.DisplayName) (overriding existing executable)" -ForegroundColor Yellow # Indicate override
                }
        } else {
            # Any other type of command conflict; throw error.
            throw
        }
    } catch {
        # Inform the user about the alias conflict and where to resolve it.
        Write-Error "Alias ""$tmpAliasName"" is already in use by ""$((Get-Command -Name $tmpAliasName).ReferencedCommand.Name)"" or another command. Please change the alias name in the script: ""$tmpCmdPath""" -ErrorAction Stop
    } finally {
        # Clean up temporary variables regardless of success or failure.
        Remove-Variable -Name "tmpAliasName" -Force
        Remove-Variable -Name "tmpCmdName" -Force
    }
} else {
    # If no alias exists, create it.
    Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
        | ForEach-Object {
            Write-Host "$($_.DisplayName) (created)" -ForegroundColor Green # Confirm alias creation
        }
    # Clean up temporary variables.
    Remove-Variable -Name "tmpAliasName" -Force
    Remove-Variable -Name "tmpCmdName" -Force
}
