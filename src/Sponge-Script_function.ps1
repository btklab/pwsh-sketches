<#
.SYNOPSIS
    Sponge-Script (Alias:sponges) - Buffer all input before passing to the next command via the pipeline.

    This function simplifies writing to the same file
    by chaining pipelines without parentheses backtracking.

    Basically, this function buffer standard input.

        $input -> ($input)

    Optionally, you can specify a script(scriptblock) to pass the buffered input.

        cat a.txt | Sponge-Script {Set-Content a.txt}

    The above is equivalent to following:
        
        (cat a.txt) | Set-Content a.txt

.LINK
    Sponge-Property, Sponge-Script

.EXAMPLE
    # An Error occurs when outputting to the same file.
    cat a.txt | Set-Content a.txt
    
        Set-Content: The process cannot access the file
        because it is being used by another process.
    
    # Buffer all input before outputting using sponge
    cat a.txt | Sponge-Script {Set-Content a.txt} -Debug
    
        DEBUG: ($input) | Set-Content a.txt

    # The above is equivalent to the following:

        (cat a.txt) | Set-Content a.txt

    # The redirection operators ">", ">>", and "2>" are supported.
    cat a.txt | Sponge-Script {> a.txt} -Debug

        DEBUG: ($input) > a.txt

#>
function Sponge-Script {
    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$False, Position=0 )]
        [Alias('script')]
        [scriptblock] $Scriptblock
        ,
        [parameter( Mandatory=$False, ValueFromPipeline=$True )]
        [object[]] $InputObject
    )
    # set variable
    [string] $Delimiter = '|'
    # create script str
    if ( $ScriptBlock ){
        [string] $cmd = $ScriptBlock.ToString().Trim()
        if ( $cmd -match '^[1-9]*\>' ){
            $cmd = $cmd
        } else {
            $cmd = "$Delimiter $cmd"
        }
        [string] $cmd = '($input) ' + $cmd
        Write-Debug $cmd
        Invoke-Expression -Command $cmd -ErrorAction Stop
    } else {
        ($input)
    }
}
# set alias
[String] $tmpAliasName = "sponges"
[String] $tmpCmdName   = "Sponge-Script"
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

