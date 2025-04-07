<#
.SYNOPSIS
    Format-Path (Alias: fpath) - Remove double-quotes and replace backslashes to slashes from windows path
    
    If Paths is not specified in the args or pipline input,
    it tries to use the value from the clipboard.

    Multiple lines are allowed.

    Usage:
        # get paths from clipboard
        fpath
        Get-Clipboard | fpath

        # get paths from clipboard and set output to clipboard
        fpath | Set-Clipboard

        # get path from parameter
        fpath "C:\Users\hoge\fuga\piyo_function.ps1"
        C:/Users/hoge/fuga/piyo_function.ps1

        # get path from stdin
        "C:\Users\hoge\fuga\piyo_function.ps1" | fpath
        C:/Users/hoge/fuga/piyo_function.ps1

        # get path from file
        cat paths.txt | fpath


.EXAMPLE
    # get path from parameter
    fpath "C:\Users\hoge\fuga\piyo_function.ps1"
    C:/Users/hoge/fuga/piyo_function.ps1

    # get path from stdin
    "C:\Users\hoge\fuga\piyo_function.ps1" | fpath
    C:/Users/hoge/fuga/piyo_function.ps1

    # get paths from clipboard
    fpath
    Get-Clipboard | fpath

    # get path from file
    cat paths.txt | fpath

.EXAMPLE
    # get paths from clipboard and set output to clipboard
    fpath | Set-Clipboard

.LINK
    ml (Get-OGP), fpath

#>
function Format-Path {
    param (
        [Parameter( Mandatory=$False, Position=0, ValueFromPipeline=$True)]
        [Alias('p')]
        [string[]] $Path
    )
    if ( -not $Path ){ [string[]] $Path = Get-ClipBoard }
    if ( $Path.Count -eq 0 ){ return }
    foreach ( $pat in $Path ){
        if ( $pat -ne ''){
            [string] $writeLine = $pat.Replace('"','').Replace('\','/')
            Write-Output $writeLine
        }
    }
}
# set alias
[String] $tmpAliasName = "fstep"
[String] $tmpCmdName   = "ForEach-Step"
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
