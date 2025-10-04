<#
.SYNOPSIS
    Renders an .Rmd file using RMarkdown by invoking Rscript.

.DESCRIPTION
    This function simplifies the process of compiling .Rmd files into various formats (like HTML, PDF)
    by wrapping the `rmarkdown::render()` function in R. It checks for the existence of Rscript,
    constructs the necessary command-line arguments, and executes the rendering process.

.PARAMETER File
    Specifies the path to the .Rmd file to be rendered.

.PARAMETER NewWindow
    If specified, the Rscript process will be started in a new console window.

.PARAMETER All
    If specified, renders the input file to all output formats defined in its YAML metadata
    by setting `output_format='all'`.

.PARAMETER NoWait
    If specified, the PowerShell script will not wait for the Rscript process to complete.

.PARAMETER Script
    Allows passing a custom R script string to be executed instead of rendering a file.

.EXAMPLE
    # Compile 'document.Rmd' to the default format (e.g., HTML)
    Invoke-RMarkdown -File index.Rmd

.EXAMPLE
    # Using the alias to compile 'report.Rmd' to all available formats
    rmarkdown index.Rmd -All

.EXAMPLE
    # Execute a custom R script to display
    # the first few rows of the iris dataset
    Invoke-RMarkdown -Script 'head(iris)'
          Sepal.Length Sepal.Width Petal.Length Petal.Width Species
        1          5.1         3.5          1.4         0.2  setosa
        2          4.9         3.0          1.4         0.2  setosa
        3          4.7         3.2          1.3         0.2  setosa
        4          4.6         3.1          1.5         0.2  setosa
        5          5.0         3.6          1.4         0.2  setosa
        6          5.4         3.9          1.7         0.4  setosa

.LINK
    This function is part of a toolchain that may include:
    Invoke-TinyTeX (tinytex), math2tex, tex2pdf, inkconv

.NOTES
    Requires R to be installed and 'Rscript' to be available in the system's PATH.
    The R Project for Statistical Computing: https://www.r-project.org/
#>
function Invoke-RMarkdown {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $False, Position = 0)]
        [Alias('f')]
        [String] $File,

        [Parameter(Mandatory = $False)]
        [Switch] $NewWindow,

        [Parameter(Mandatory = $False)]
        [Switch] $All,

        [Parameter(Mandatory = $False)]
        [Switch] $NoWait,

        [Parameter(Mandatory = $False)]
        [String] $Script
    )

    # Helper function to check if a command is available in the PATH.
    function Test-CommandExists {
        param([string]$command)
        return [bool](Get-Command -Name $command -ErrorAction SilentlyContinue)
    }

    #region 1. Pre-execution Checks
    #================================================================================
    # Ensure Rscript is installed and available before proceeding.
    #================================================================================
    $rscriptCommand = "Rscript"
    if (-not (Test-CommandExists -command $rscriptCommand)) {
        Write-Error "$rscriptCommand command not found. Please ensure R is installed and in your PATH." -ErrorAction Continue
        if ($IsWindows) {
            Write-Error "You can install R on Windows using winget: winget install --id RProject.R --source winget --exact"
        }
        else {
            Write-Error "You can install R on Debian-based systems using: sudo apt install r-base"
        }
        Write-Error "For more information, visit: https://www.r-project.org/" -ErrorAction Stop
    }

    # Verify that the specified file exists if the -File parameter is used.
    if ( -not $File -and -not $Script ) {
        $File = './index.Rmd'
    }
    if ($File -and -not (Test-Path -LiteralPath $File)) {
        Write-Error "The specified file does not exist: $File" -ErrorAction Stop
    }
    #endregion

    #region 2. Build Rscript Arguments
    #================================================================================
    # Construct the list of R expressions (-e) to be passed to Rscript.
    #================================================================================
    [String[]] $rScriptExpressions = @()

    if ($File) {
        # Get the relative path of the Rmd file.
        [String] $rmdFilePath = (Resolve-Path -LiteralPath $File -Relative)

        # Rscript on Windows expects forward slashes in paths.
        if ($IsWindows) {
            $rmdFilePath = $rmdFilePath.Replace('\', '/')
        }

        # The core R commands to load rmarkdown and render the file.
        $rScriptExpressions += """library(rmarkdown);"""

        if ($All) {
            # Render to all formats specified in the Rmd file's YAML header.
            $rScriptExpressions += """rmarkdown::render(input='$rmdFilePath', encoding='UTF-8', output_format='all');"""
        }
        else {
            # Render to the default format.
            $rScriptExpressions += """rmarkdown::render(input='$rmdFilePath', encoding='UTF-8');"""
        }
    }
    elseif ($Script) {
        # Execute a custom R script provided by the user.
        $rScriptExpressions += $Script
    }
    else {
        # If no file or script is provided, just show the current working directory as a default action.
        $rScriptExpressions += """getwd();"""
    }

    # Combine base arguments and R expressions.
    [String[]] $processArgs = @("--vanilla", "--slave")
    foreach ($expression in $rScriptExpressions) {
        $processArgs += "-e", $expression
    }
    #endregion

    #region 3. Execute Rscript
    #================================================================================
    # Run the Rscript command with the constructed arguments.
    #================================================================================
    # Use splatting for cleaner parameter passing to Start-Process.
    $startProcessParams = @{
        FilePath     = $rscriptCommand
        ArgumentList = $processArgs
    }

    if (-not $NewWindow) {
        $startProcessParams.Add("NoNewWindow", $True)
    }
    if (-not $NoWait) {
        $startProcessParams.Add("Wait", $True)
    }

    try {
        # Display the command that will be executed for transparency.
        $commandToDisplay = "$rscriptCommand $($processArgs -join ' ')"
        Write-Debug -Message $commandToDisplay

        # Execute the process.
        Start-Process @startProcessParams
    }
    catch {
        Write-Error "An error occurred while trying to run Rscript: $_" -ErrorAction Stop
    }
    #endregion
}

#region Alias Setup
#================================================================================
# Set a convenient alias 'rmarkdown' for the Invoke-RMarkdown function.
# This makes the function easier to use from the command line.
# The script checks for existing commands or aliases to avoid conflicts.
#================================================================================
[String] $tmpAliasName = "rmarkdown"
[String] $tmpCmdName   = "Invoke-RMarkdown"
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
