<#
.SYNOPSIS
    Invoke-Vivliostyle (Alias: iviv) - Wrapper for Vivliostyle CLI.

    Wrapper for Vivliostyle CLI basic operations
    (create, build, preview, install) as subcommands.

    Usage:
        ## init (create)
        iviv init
        iviv init "mybook"

        ## build
        iviv build

        ## preview
        iviv preview

        ## install node
        winget install --id OpenJS.NodeJS.LTS --source winget --exact
        npm install -g @vivliostyle/cli

.LINK
    Vivliostyle - Enjoy CSS Typesetting!
    https://vivliostyle.org/ja/

    Vivliostyle Docs
    https://docs.vivliostyle.org/#/

    Vivliostyle - GitHub
    https://github.com/vivliostyle

.DESCRIPTION
    This script provides a single function, Invoke-Vivliostyle, to help manage Vivliostyle projects.
    It supports project creation, PDF build, preview, and CLI installation, with clear code and comments for maintainability.

.EXAMPLE
    Invoke-Vivliostyle create -ProjectName "mybook"
    # Create a new Vivliostyle project named 'mybook'.

#>
function Invoke-Vivliostyle {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false, Position=0)]
        [ValidateSet("init", "build", "preview", "install", "sample", "docs", "github", "home")]
        [Alias('c')]
        [string]$Command,

        [Parameter(Mandatory=$false, Position=1)]
        [Alias('p')]
        [string]$ProjectName = "mybook"
    )

    # Use a switch statement for clarity and maintainability
    switch -Exact ($Command) {
        "init" {
            # Ensure the project name is provided
            if (-not $ProjectName) {
                Write-Host "Please specify a project name using -ProjectName."
                return
            }
            if ( Test-Path -LiteralPath $ProjectName ){
                Write-Error "Project: $ProjectName is not empty directory." -ErrorAction Stop
                return
            }
            # Run Vivliostyle project creation
            npm create book $ProjectName
            Push-Location $ProjectName
            Get-ChildItem
            break
        }
        "build" {
            # Build PDF from the specified source directory
            npm run build
            break
        }
        "preview" {
            # Start the Vivliostyle preview server
            npm run preview
            break
        }
        "install" {
            Write-Host "Install Node.js via winget:" -ForegroundColor green
            Write-Output "winget install --id OpenJS.NodeJS.LTS --source winget --exact"
            Write-Output "npm install -g @vivliostyle/cli"
            break
        }
        "sample" {
            Start-Process "https://vivliostyle.org/ja/samples/"
            Start-Process "https://vivliostyle.org/ja/"
        }
        "docs" {
            Start-Process "https://vivliostyle.org/ja/"
            Start-Process "https://docs.vivliostyle.org/#/"
        }
        "github" {
            Start-Process "https://github.com/vivliostyle"
            Start-Process "https://vivliostyle.org/ja/"
        }
        "home" {
            Start-Process "https://vivliostyle.org/ja/"
        }
        default {
            Get-Help Invoke-Vivliostyle
        }
    }
} 

# set alias
# This block automatically sets an alias for the function upon script load.
[String] $tmpAliasName = "iviv"
[String] $tmpCmdName = "Invoke-Vivliostyle"

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
