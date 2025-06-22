<#
.SYNOPSIS
    Invoke-GitBash (Alias: gitbash) - Executes Git Bash commands on Windows.

    This function provides a convenient way to run Git Bash commands directly from
    PowerShell, automatically handling path conversions for Windows-style arguments.
    It locates the Git installation and executes the specified command with its
    arguments, optionally accepting pipeline input.

.DESCRIPTION
    Many Git commands and associated utilities (like `ls`, `cat`, `diff`) are
    designed for a Unix-like environment. When working on Windows, their paths
    often use forward slashes (`/`) instead of backslashes (`\`). This function
    abstracts that detail, allowing users to pass Windows paths as arguments,
    which are then automatically converted to the Git Bash compatible format.

    It also offers a default 'show' command to list available executables in
    the Git Bash `usr/bin` directory, making it easier to discover commands.

.PARAMETER Command
    The Git Bash command to execute (e.g., 'diff', 'ls', 'cat').
    Defaults to 'show', which lists available executables.

.PARAMETER Argument
    Arguments to pass to the Git Bash command. Windows paths are automatically
    converted to use forward slashes.

.EXAMPLE
    # Run 'git diff' with specific files, automatically handling Windows paths.
    # This shows the differences between two files using Git's diff utility.
    gitbash diff ./file1.txt ./file2.txt

.EXAMPLE
    # View the list of available Git Bash executables.
    # This is helpful to see what commands can be run directly.
    gitbash
    gitbash show

.EXAMPLE
    # Execute a simple 'ls' command in the Git Bash environment.
    gitbash ls

.EXAMPLE
    # Use pipeline input with a Git Bash command like 'grep'.
    # This demonstrates redirecting PowerShell output to a Git Bash utility.
    Get-Content .\my_log.txt | gitbash grep "error"

.LINK
    https://git-scm.com/docs/git-diff
    https://git-scm.com/docs/git-bash
#>
function Invoke-GitBash {
    param (
        [Parameter(Mandatory=$false, Position=0)]
        [string] $Command = "show", # Default command to run if none is specified
        
        [Parameter(ValueFromRemainingArguments=$true)]
        [string[]] $Argument, # Catches all unassigned arguments
        
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [string[]] $TextObject # Accepts pipeline input
    )
    
    # private function
    function replacePathDelim {
        param (
            [string] $path
        )
        # Converts Windows-style backslashes to Unix-style forward slashes.
        return $($path.Replace('\', '/'))
    }
    
    [string]$commandPath = ""
    
    # Determine the Git Bash 'usr/bin' directory.
    # We check common installation paths to find where Git executables reside.
    if (Test-Path "$HOME/AppData/Local/Programs/Git/usr/bin") {
        [string] $commandPath = "$HOME/AppData/Local/Programs/Git/usr/bin"
    } elseif (Test-Path "C:/Program Files/Git/usr/bin") {
        [string] $commandPath = "C:/Program Files/Git/usr/bin"
    } else {
        # If Git Bash is not found in expected locations, stop execution.
        Write-Error "The 'Git Path' was not found. Please ensure Git Bash is installed in a default location or add its 'usr\bin' directory to your PATH." -ErrorAction stop
    }
    [string] $commandPath = replacePathDelim $commandPath
    Write-Debug "Git Bash command path: $commandPath"
    
    # Handle the special 'show' command to list available executables.
    if ( $Command -eq 'show'){
        # Convert path to Unix-style for Git Bash's 'ls.exe'.
        [string] $manPath = $commandPath
        [string] $lsPath = Join-Path -Path $commandPath -ChildPath "ls.exe"
        [string] $lsPath =  replacePathDelim $lsPath
        # Execute 'ls.exe' to list contents of the Git Bash bin directory.
        & $lsPath $manPath "--ignore={*.dll,*.lib,*.hs}"
        return # Exit after showing the commands.
    }
    
    # Construct the full path to the Git Bash executable.
    # This ensures that even commands like 'git.exe' or 'ls' are correctly resolved.
    if ( $Command -match '\.exe$' ){
        # If the command already includes '.exe', use it directly.
        [string] $exePath = Join-Path -Path $commandPath -ChildPath "$Command"
    } else {
        # Otherwise, assume it's a command in the bin directory and append '.exe'.
        [string] $exePath = Join-Path -Path $commandPath -ChildPath "$Command"
        # Check if the command exists without '.exe' first, then try with '.exe'.
        if ( -not (Test-Path -Path $exePath -ErrorAction SilentlyContinue) ){
            [string] $exePath = Join-Path -Path $commandPath -ChildPath "$Command.exe"
        }
    }
    [string] $exePath = replacePathDelim $exePath
    
    # Verify that the constructed command path actually exists.
    if ( -not (Test-Path -Path $exePath -ErrorAction SilentlyContinue) ){
        Write-Error "The command '$Command' was not found in the Git Bash path: $commandPath. Ensure the command name is correct or specify its full path." -ErrorAction stop
    }
    
    # Prepare arguments for Git Bash by converting Windows paths.
    # Git Bash expects forward slashes for paths.
    [string[]] $replacedArguments = @()
    if ( $Argument.Count -gt 0 ){
        foreach ( $arg in $Argument ){
            # Only convert arguments that are valid Windows file system paths.
            if ( (Test-Path -Path $arg) ){
                [string] $replacedPath = replacePathDelim $arg
                $replacedArguments += $replacedPath
            } else {
                # Non-path arguments are passed as-is.
                $replacedArguments += $arg
            }
            Write-Debug "Argument processed: $arg -> $replacedPath"
        }
    }
    Write-Debug "Command path: $exePath, Arguments: $replacedArguments"
    
    # Execute the Git Bash command.
    # Handles cases with and without pipeline input or arguments.
    if ( $TextObject.Count -gt 0 ){
        # Redirect pipeline input if provided.
        if ( $Argument.Count -gt 0 ){
            $input | & $exePath $replacedArguments
        } else {
            $input | & $exePath
        }
    } else {
        # Execute without pipeline input.
        if ( $Argument.Count -gt 0 ){
            & $exePath $replacedArguments
        } else {
            & $exePath
        }
    }
}

# set alias
# This block automatically sets an alias for the function upon script load.
[String] $tmpAliasName = "gitbash"
[String] $tmpCmdName = "Invoke-GitBash"

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
