<#
.SYNOPSIS
    Invoke-Lang (alias: lang) - Invoke a command with a temporary language environment.

    The temporary language is specified by the "-Language" option.
    The default value is -Language "en-US".

    If an error occurs, output an error message and restore
    the original language settings.

.EXAMPLE
    # default language setting
    Get-Culture | ft

    LCID             Name             DisplayName
    ----             ----             -----------
    1041             ja-JP            Japanese

    # run command in "en-US"
    lang {Get-Date; Get-Culture | ft } -lang "en-US"

    Sunday, March 2, 2025 9:36:07 PM

    LCID             Name             DisplayName
    ----             ----             -----------
    1033             en-US            English (United States)

    # check language settings
    Get-Culture | ft

    LCID             Name             DisplayName
    ----             ----             -----------
    1041             ja-JP            Japanese

.EXAMPLE
    # If an error occurs, output an error message
    # and restore the original language settings.

    # default language setting
    Get-Culture | ft

    LCID             Name             DisplayName
    ----             ----             -----------
    1041             ja-JP            Japanese

    # run command in "en-US" and raise error
    lang {Get-Data; Get-Culture | ft } -lang "en-US"

        Invoke-Lang: An error occurred: The term 'Get-Data' is not recognized as a name of a cmdlet, function, script file, or executable program.
        Check the spelling of the name, or if a path was included, verify that the path is correct and try again.

    # check language settings
    Get-Culture | ft

    LCID             Name             DisplayName
    ----             ----             -----------
    1041             ja-JP            Japanese

.LINK
    Invoke-Lang, Set-Lang

.NOTES
    Install-Language (LanguagePackManagement)
    https://learn.microsoft.com/en-us/powershell/module/languagepackmanagement/install-language
    
    Thread.CurrentCulture Property (System.Threading)
    https://learn.microsoft.com/en-us/dotnet/api/system.threading.thread.currentculture

#>
function Invoke-Lang {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$True, Position=0 )]
        [Alias('c')]
        [Scriptblock] $Command
        ,
        [Parameter( Mandatory=$False, Position=1 )]
        [Alias('l')]
        [Alias('lang')]
        [String] $Language = "en-US"
    )
    # Import the necessary .NET class
    Add-Type -AssemblyName System.Globalization
    [Object] $currentCulture = [System.Globalization.CultureInfo]::CurrentCulture
    # Set the desired culture (e.g., en-US)
    [Object] $dstCulture = New-Object System.Globalization.CultureInfo($Language)
    # Apply the culture to the current thread
    [System.Threading.Thread]::CurrentThread.CurrentCulture = $dstCulture
    [System.Threading.Thread]::CurrentThread.CurrentUICulture = $dstCulture
    # Verify the change
    #Write-Debug "Current Culture: $([System.Threading.Thread]::CurrentThread.CurrentCulture.Name)"
    #Write-Debug "Current UI Culture: $([System.Threading.Thread]::CurrentThread.CurrentUICulture.Name)"
    #Get-Culture
    try {
        Invoke-Command -ScriptBlock $Command
    } catch {
        Write-Error "An error occurred: $_"
    } finally {
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $currentCulture
        [System.Threading.Thread]::CurrentThread.CurrentUICulture = $currentCulture
    }
}
# set alias
[String] $tmpAliasName = "lang"
[String] $tmpCmdName   = "Invoke-Lang"
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
