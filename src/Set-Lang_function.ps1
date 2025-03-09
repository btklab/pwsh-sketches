<#
.SYNOPSIS
    Set-Lang - Set the language for the current thread.

.EXAMPLE
    Set-Lang -Name ja-JP

.LINK
    Execute-Lang, Set-Lang

.NOTES
    Install-Language (LanguagePackManagement)
    https://learn.microsoft.com/en-us/powershell/module/languagepackmanagement/install-language

    Thread.CurrentCulture Property (System.Threading)
    https://learn.microsoft.com/en-us/dotnet/api/system.threading.thread.currentculture

#>
function Set-Lang {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$True, Position=0 )]
        [Alias('n')]
        [String] $Name
    )
    # Import the necessary .NET class
    Add-Type -AssemblyName System.Globalization
    # Save the current culture and UI culture
    #[Object] $originalCulture = [System.Globalization.CultureInfo]::CurrentCulture
    #[Object] $originalUICulture = [System.Globalization.CultureInfo]::CurrentUICulture
    # Set the desired culture (e.g., ja-JP)
    [Object] $dstCulture = New-Object System.Globalization.CultureInfo($Name)
    # Apply the culture to the current thread
    [System.Threading.Thread]::CurrentThread.CurrentCulture = $dstCulture
    [System.Threading.Thread]::CurrentThread.CurrentUICulture = $dstCulture
    # Verify the change
    Write-Debug "Current Culture: $([System.Threading.Thread]::CurrentThread.CurrentCulture.Name)"
    Write-Debug "Current UI Culture: $([System.Threading.Thread]::CurrentThread.CurrentUICulture.Name)"
    Get-Culture
}
## set alias
#[String] $tmpAliasName = "alias"
#[String] $tmpCmdName = "Set-Lang"
#[String] $tmpCmdPath = Join-Path `
#    -Path $PSScriptRoot `
#    -ChildPath $($MyInvocation.MyCommand.Name) `
#    | Resolve-Path -Relative
#if ( $IsWindows ){ $tmpCmdPath = $tmpCmdPath.Replace('\' ,'/') }
## is alias already exists?
#if ((Get-Command -Name $tmpAliasName -ErrorAction SilentlyContinue).Count -gt 0){
#    try {
#        if ( (Get-Command -Name $tmpAliasName).CommandType -eq "Alias" ){
#            if ( (Get-Command -Name $tmpAliasName).ReferencedCommand.Name -eq $tmpCmdName ){
#                Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
#                    | ForEach-Object{
#                        Write-Host "$($_.DisplayName)" -ForegroundColor Green
#                    }
#            } else {
#                throw
#            }
#        } elseif ( "$((Get-Command -Name $tmpAliasName).Name)" -match '\.exe$') {
#            Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
#                | ForEach-Object{
#                    Write-Host "$($_.DisplayName)" -ForegroundColor Green
#                }
#        } else {
#            throw
#        }
#    } catch {
#        Write-Error "Alias ""$tmpAliasName ($((Get-Command -Name $tmpAliasName).ReferencedCommand.Name))"" is already exists. Change alias needed. Please edit the script at the end of the file: ""$tmpCmdPath""" -ErrorAction Stop
#    } finally {
#        Remove-Variable -Name "tmpAliasName" -Force
#        Remove-Variable -Name "tmpCmdName" -Force
#    }
#} else {
#    Set-Alias -Name $tmpAliasName -Value $tmpCmdName -PassThru `
#        | ForEach-Object {
#            Write-Host "$($_.DisplayName)" -ForegroundColor Green
#        }
#    Remove-Variable -Name "tmpAliasName" -Force
#    Remove-Variable -Name "tmpCmdName" -Force
#}
