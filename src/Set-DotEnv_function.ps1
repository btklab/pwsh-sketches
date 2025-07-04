<#
.SYNOPSIS
    Set-DotEnv (Alias: pwenv) - Set the contents of the .myenv file for the current process

    Read ".myenv" file  and temporarily add environment variables.

        ".myenv" file format (UTF8): 
            <key>=<value>
    
    - By default, the .myenv file in the current directory is read.
      If the -GPG switch is specified or the file extension is .gpg,
      (e.g.: .myenv.gpg) it is automatically treated as a GPG-encrypted
      file and decrypted using gpg.exe
    - The default behavior is dryrun. Run with the -Execute option.
    - The scope of the environment variable is the current process.
      It is temporary, not permanent.
      It is cleared when the terminal is closed.
    - If the environment variable name already exists, the process
      will stop. Overwrite with the -OverWrite option.
    - Blank lines are ignored.
    - Lines beginning with a pound sign are ignored.
    - Lines without a "=" delimiter are ignored.
    - When there are multiple matches of the delimiter "=",
      the key is obtained by the shortest match on the left.

    Install GnuPG or Gpg4win:

      GNU Privacy Guard : winget install --id GnuPG.GnuPG --source winget -e
      Gpg4win           : winget install --id GnuPG.Gpg4win --source winget -e

    list-keys using gpg.exe on commandline:
      gpg --list-keys

    Encrypt .myenv using gpg.exe on commandline:
      gpg --encrypt .myenv [-r <FINGERPRINT>]

    Decrypt and output to console .myenv.gpg using gpg.exe:
      gpg -o - --decrypt .myenv.gpg


.EXAMPLE
    PS> cat .myenv
        # my .myenv
        MY_MAIL_ADDR=btklab@exa=mple.com
        HOGE="hoge fuga"

    # dry run
    PS> pwenv
        Dry run mode. envVariable is not set.
            Name         Value
            ----         -----
            MY_MAIL_ADDR btklab@exa=mple.com
            HOGE         hoge fuga

    # execute (set env)
    PS> pwenv -e

    # overwrite error
    PS> pwenv -e
        Set-DotEnv: (pwenv) MY_MAIL_ADDR is already exists. if you want to overwrite it, use -OverWrite option.

    # overwrite env
    PS> pwenv -e -o

    # clear env
    PS> exit

#>
function Set-DotEnv {

    [CmdletBinding()]
    param (
        [Parameter( Mandatory=$False, Position=0 )]
        [Alias('p')]
        [String[]] $Path = @('./.myenv')
        ,
        [Parameter( Mandatory=$False )]
        [Alias('o')]
        [Switch] $OverWrite
        ,
        [Parameter( Mandatory=$False )]
        [Alias('d')]
        [Switch] $DryRun
        ,
        [Parameter( Mandatory=$False )]
        [Alias('e')]
        [Switch] $Execute
        ,
        [Parameter( Mandatory=$False )]
        [Switch] $GPG
        ,
        [Parameter( Mandatory=$False )]
        [Alias('q')]
        [Switch] $Quiet
    )
    # private function
    function isCommandExist ([string]$Name) {
        try { Get-Command -Name $Name -ErrorAction Stop > $Null
            return $True
        } catch {
            return $False
        }
    }
    filter TrimAndRemoveComment {
        [String] $line = $_
        [String] $line = $line.Trim()
        if ( $line -eq '' ){
            #pass
        } elseif ( $line -match '^#' ) {
            #pass
        } elseif ( $line -notmatch '=' ) {
            #pass
        } else {
            Write-Output $line
        }
    }
    filter TrimQuote {
        [String] $line = $_
        [String] $line = $line -replace '^"', '' -replace '"$', ''
        [String] $line = $line -replace "^'", "" -replace "'$", ""
        Write-Output $line
    }
    # test option
    if ( $Path.Count -gt 0 ){
        #pass
    } else {
        Write-Error "Could not specify ""$Path""" -ErrorAction Stop
    }
    # main
    foreach ( $p in $Path ){
        # test path
        if ( (Test-Path -LiteralPath "$p.gpg" ) ){
            $p = "$p.gpg"
        }
        if ( -not (Test-Path -LiteralPath $p ) ){
            Write-Error """$Path"" is not exists." -ErrorAction Stop
        }
        write-debug "Target file: $p"
        # read file
        $envHash = [ordered] @{}
        [string] $ext = (Get-Item -LiteralPath $p).Extension
        if ( $GPG -or $ext -eq '.gpg' ){
            if ( -not (isCommandExist "gpg") ){
                Write-Host "gpg.exe could not found."
                Write-Host ""
                Write-Host "Please install GnuPG or Gpg4win:"
                Write-Host "  GNU Privacy Guard : winget install --id GnuPG.GnuPG --source winget -e"
                Write-Host "  Gpg4win           : winget install --id GnuPG.Gpg4win --source winget -e"
                Write-Host ""
                Write-Host "list-keys using gpg.exe on commandline:"
                Write-Host "  gpg --list-keys"
                Write-Host ""
                Write-Host "Encrypt .myenv using gpg.exe on commandline:"
                Write-Host "  gpg --encrypt .myenv [-r <FINGERPRINT>]"
                Write-Host ""
                Write-Host "Decrypt and output to console .myenv.gpg using gpg.exe:"
                Write-Host "  gpg -o - --decrypt .myenv.gpg"
                Write-Host ""
                Write-Error "Exection Error." -ErrorAction Stop
            }
            [string[]] $contents = gpg -o - --decrypt $p
        } else {
            [string[]] $contents = Get-Content -LiteralPath "$p" -Encoding utf8
        }
        $contents `
            | TrimAndRemoveComment `
            | ForEach-Object {
                $name, $val = $_ -split '\s*=\s*', 2
                [String] $val = Write-Output $val | TrimQuote
                $envHash[$name] = $val
                Write-Debug "$name=$val"
                # test env name
                [String] $envVarName = $name
                if ([string]::IsNullOrEmpty([System.Environment]::GetEnvironmentVariable($envVarName))) {
                    #pass
                } else {
                    if ( -not $OverWrite ){
                        Write-Error "(pwenv) $envVarName is already exists. if you want to overwrite it, use -OverWrite option." -ErrorAction Stop
                    }
                }
            }
        # set env
        if ( -not $Execute ){
            Write-Host "Dry run mode. envVariable is not set." -ForegroundColor Yellow
        }
        foreach ($key in $envHash.keys){
            if ( $Execute ){
                Set-Content -LiteralPath "env:\$key" -Value $envHash[$key]
                if ( -not $Quiet ){
                    $myObject = [PSCustomObject]@{
                        Name  = $key
                        Value = $envHash[$key]
                    }
                    $myObject
                }
            } else {
                if ( -not $Quiet ){
                    $myObject = [PSCustomObject]@{
                        Name  = $key
                        Value = $envHash[$key]
                    }
                    $myObject
                }
            }
       }
    }
}
# set alias
[String] $tmpAliasName = "pwenv"
[String] $tmpCmdName   = "Set-DotEnv"
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

