<#
.SYNOPSIS
    Get-LabelBlock (Alias:glb) - Extracts lines from label blocks matching Regex.

    By default, labels start with "@", and a block is defined as the lines
    between one "@label" and the next. Label lines themselves are excluded
    unless -IncludeLabelLine is used.

    The block name is extracted by removing the label prefix (e.g., "@"),
    splitting at ':' to ignore comments, taking the first part, and trimming whitespace.

    example-links.txt:

        @shopping : Online shopping sites <- label line
        https://www.amazon.com/           <- block content line
        https://www.ebay.com/             <- block content line
        
        @news                             <- label line
        https://www.reuters.com/          <- block content line
        https://www.ap.org/               <- block content line

    Example usage:

        Get-LabelBlock example-links.txt shop -TrimEmptyLine

        Output:
            https://www.amazon.com/
            https://www.ebay.com/

    This function provides multiple modes for filtering text line-by-line
    from files or pipeline input using a streaming, memory-efficient process:
 
    1. -Grep: (Highest priority) Outputs lines matching the -Grep regex.
    2. -ListLabels: Outputs only the lines that match the -Pattern (label lines).
    3. -Label: (Default block mode) Outputs lines *within* a specific block.
    4. Pass-Through: If no mode is specified, outputs all lines.

    The block-starting lines themselves are *not* included in the output,
    unless the -IncludeLabelLine switch is used.

.LINK
    Invoke-Link, Get-LablelBlock, Get-Block

.PARAMETER Path
    [string[]] - Optional. Position 0.
    Specifies the path to the input text file(s). Wildcards are permitted.
    If -Path is specified, pipeline input is ignored. Files are read
    line-by-line with UTF-8 encoding.

.PARAMETER Label
    [string] - Optional. Position 1.
    The "name" of the block label to extract, treated as a regex pattern.
    If this parameter is omitted, all lines are output (pass-through mode).
    - For default pattern ("^@"), a line "@news : ..." is matched by -Label "news".
    - For pattern "^##\s*", a line "## My Section" is matched by -Label "My Section".

.PARAMETER Pattern
    [string] - Optional. Default is '^@'.
    The regex pattern used to identify a line as the start of *any* block.

.PARAMETER TrimEmptyLine
    [switch] - Optional.
    If specified, all empty lines (or lines with only whitespace)
    will be removed from the final output.

.PARAMETER IncludeLabelLine
    [switch] - Optional.
    If specified (in -Label mode), the block-starting line (e.g., "@news")
    will be included in the output, just before its content.

.PARAMETER Grep
    [string] - Optional.
    If specified, all other logic (-Label, -ListLabels) is ignored.
    The function will only output lines from the input that match
    this regex pattern (similar to 'Select-String -Pattern ...').

.PARAMETER ListLabels
    [switch] - Optional.
    If specified, -Label block extraction is ignored. The function
    will only output the label lines themselves (i.e., lines
    that match the -Pattern regex).

.PARAMETER InputObject
    [string[]] - Optional.
    Accepts input from the pipeline (e.g., from Get-Content). This is
    processed only if -Path is not specified.

.EXAMPLE
    # --- Sample File: my-links.txt ---
    # @shopping : Online shopping sites
    # https://www.amazon.com/
    #
    # https://www.ebay.com/
    #
    # @news
    # https://www.reuters.com/
    # https://www.ap.org/
    # ---

    # Example 1: Get a specific block (standard)
    Get-LabelBlock ".\my-links.txt" "shopping"

    # Output:
    # https://www.amazon.com/
    #
    # https://www.ebay.com/
    #

.EXAMPLE
    # Example 2: Get a block AND trim empty lines
    Get-LabelBlock ".\my-links.txt" "shopping" -TrimEmptyLine

    # Output:
    # https://www.amazon.com/
    # https://www.ebay.com/

.EXAMPLE
    # Example 3: Get a block AND include the label line
    Get-LabelBlock ".\my-links.txt" "shopping" -IncludeLabelLine

    # Output:
    # @shopping : Online shopping sites
    # https://www.amazon.com/
    #
    # https://www.ebay.com/
    #

.EXAMPLE
    # Example 4: Using -Grep to find all links (overrides -Label)
    Get-LabelBlock ".\my-links.txt" -Label "shopping" -Grep "https?://"

    # Output:
    # https://www.amazon.com/
    # https://www.ebay.com/
    # https://www.reuters.com/
    # https://www.ap.org/

.EXAMPLE
    # Example 5: Using -ListLabels to find all block definitions
    Get-LabelBlock ".\my-links.txt" -ListLabels

    # Output:
    # @shopping : Online shopping sites
    # @news

.EXAMPLE
    # Example 6: Custom pattern for Markdown AND trim empty lines
    # (See notes.md from Example 4 in previous version)
    Get-LabelBlock ".\notes.md" "Research" -Pattern "^##\s*" -TrimEmptyLine

    # Output:
    # - Find papers on topic A
    # - Read book B
#>
function Get-LabelBlock {
    [CmdletBinding(DefaultParameterSetName='Path')]
    param (
        # Path accepts wildcards and multiple files.
        [Parameter(Mandatory=$false, Position=0, ParameterSetName='Path')]
        [Alias('p', 'f', 'file')]
        [string[]]$Path,

        # The name of the block to extract. Treated as a regex pattern.
        # If not specified, all lines are output (pass-through).
        [Parameter(Mandatory=$false, Position=1)]
        [Alias('l')]
        [string]$Label,

        # The regex pattern to identify the start of a block.
        [Parameter(Mandatory=$false)]
        [Alias('Prefix')]
        [string]$Pattern = '^@', # Default to the original '@' pattern
        
        # Switch to remove empty/whitespace-only lines from output.
        [Parameter(Mandatory=$false)]
        [Alias('t')]
        [switch]$TrimEmptyLine,

        # Switch to include the matching label line in the output.
        [Parameter(Mandatory=$false)]
        [Alias('i')]
        [switch]$IncludeLabelLine,

        # High-priority regex filter; overrides -Label and -ListLabels.
        [Parameter(Mandatory=$false)]
        [Alias('g')]
        [string]$Grep,

        # High-priority switch to list only label lines. Overrides -Label.
        [Parameter(Mandatory=$false)]
        [Alias('ll')]
        [switch]$ListLabels,

        # Accepts input from the pipeline (e.g., from Get-Content)
        [Parameter(Mandatory=$false, ParameterSetName='Pipeline', ValueFromPipeline=$true)]
        [string]$InputObject 
    )

    begin {
        # --- Internal Helper Function ---
        # This function contains the core logic for processing a single line
        # and decides whether to output it, based on the function's parameters.
        # It updates the $inBlockStatus parameter (passed by reference)
        # to maintain state across calls.
        # This avoids duplicating logic in the process {} and end {} blocks.
        function Process-Line {
            param (
                [string]$line,
                [ref]$inBlockStatus # Pass the state variable by reference
            )

            # Helper function to consolidate output logic, respecting -TrimEmptyLine
            function Write-OutputLine ([string]$outLine) {
                if (-not $TrimEmptyLine -or $outLine -match '\S') {
                    Write-Output $outLine
                }
            }

            # --- Logic Precedence ---
            # 1. -Grep (Highest)
            # 2. -ListLabels
            # 3. -Label (Block extraction)
            # 4. Pass-Through (Default)

            # Mode 1: -Grep (highest precedence)
            if ($PSBoundParameters.ContainsKey('Grep')) {
                if ($line -match $Grep) {
                    Write-OutputLine $line
                }
                return # Done with this line
            }

            # Mode 2: -ListLabels
            if ($ListLabels) {
                if ($line -match $Pattern) {
                    [string[]]$splitLabel = $line.Split(':', 2)
                    $o = [ordered]@{}
                    $o['Name']    = 'stdin'
                    $o['Label']   = $splitLabel[0].Trim()
                    $o['Comment'] = $splitLabel[1].Trim()
                    [pscustomobject]$o
                    #Write-Output $line # Label lines aren't empty, no trim check needed
                }
                return # Done with this line
            }
            
            # Mode 3: -Label (Block Extraction)
            if ($filteringEnabled) {
                if ($line -match $Pattern) {
                    # --- BLOCK START LINE DETECTED ---
                    # Extract the name of this block.
                    # 1. Remove the StartPattern part (e.g., "@" or "## ")
                    # 2. Split on ':' (to remove comments like "label : notes")
                    # 3. Take the first part [0]
                    # 4. Trim whitespace
                    [string]$nameWithComment = $line -replace $Pattern, ''
                    [string]$currentLabelName = $nameWithComment.Split(':', 2)[0].Trim()

                    if ($currentLabelName -match $labelRegex) {
                        # --- Target block found ---
                        $inBlockStatus.Value = $true # Set state to "in"
                        if ($IncludeLabelLine) {
                            Write-Output $line # Output the label line itself
                        }
                    } else {
                        # --- Other block found ---
                        $inBlockStatus.Value = $false # Set state to "out"
                    }
                    return # Done with this line (it's a label line)
                
                } elseif ($inBlockStatus.Value) {
                    # --- NON-BLOCK LINE, INSIDE TARGET BLOCK ---
                    Write-OutputLine $line
                    return # Done with this line
                }
                # If not a pattern and not in a block, fall through (do nothing)
                return
            }

            # Mode 4: Pass-Through (default)
            Write-OutputLine $line
        }
        # --- End of Internal Helper Function ---

        # Check if filtering by label is enabled (Mode 3).
        $filteringEnabled = $PSBoundParameters.ContainsKey('Label')

        # Prepare the regex for the label name if filtering is enabled.
        $labelRegex = $null
        if ($filteringEnabled) {
            # Trim leading '@' just in case, for backward compatibility.
            $labelRegex = $Label.TrimStart('@')
        }

        # This flag tracks if we are "inside" a target block.
        # For pipeline processing, it maintains state across calls to process {}.
        $inBlock_Pipeline = $false
    }

    process {
        # This block handles pipeline input.
        # It runs only when data is piped in (ParameterSetName='Pipeline').
        
        # We must iterate over $InputObject, which contains the line(s)
        # provided by the pipeline for this specific process() call.
        if ( $Path.Count -eq 0 ){
            [string] $line = $InputObject
            # Call the centralized processing logic
            Process-Line -line $line -inBlockStatus ([ref]$inBlock_Pipeline)
        }
    }

    end {
        # This block handles file input.
        # It runs only if -Path was specified (ParameterSetName='Path').
        if ($PSCmdlet.ParameterSetName -eq 'Path') {
            try {
                # Resolve wildcards to get a list of file objects.
                # Use -ErrorAction SilentlyContinue to handle non-matching wildcards gracefully.
                $resolvedPaths = Resolve-Path -Path $Path -ErrorAction SilentlyContinue
                
                if (-not $resolvedPaths) {
                    Write-Warning "No files found matching path: $Path" -ErrorAction Stop
                    return
                }

                # Process each file found.
                foreach ($file in $resolvedPaths) {
                    # Ensure we are only processing files, not directories.
                    if (Test-Path -LiteralPath $file.ProviderPath -PathType Container) {
                        Write-Verbose "Skipping directory: $($file.ProviderPath)"
                        continue
                    }
                    if ( $ListLabels ) {
                        [object[]] $matchedObjects = Select-String -Pattern $Pattern -Path $file
                        foreach ($m in $matchedObjects) {
                            [string[]]$splitLabel = $m.line.Split(':', 2)
                            $o = [ordered]@{}
                            $o['Name']    = $m.Filename
                            $o['Label']   = $splitLabel[0].Trim()
                            $o['Comment'] = $splitLabel[1].Trim()
                            [pscustomobject]$o
                        }
                        continue
                    }

                    # State flag. This *must* be reset for *each file*.
                    [bool]$inBlock_File = $false

                    # Read the file line-by-line (streaming) using Get-Content.
                    # Specify UTF-8 encoding as requested.
                    # Use a 'foreach' loop on the Get-Content command to stream.
                    foreach ($line in (Get-Content -LiteralPath $file.ProviderPath -Encoding utf8)) {
                        # Call the centralized processing logic
                        Process-Line -line $line -inBlockStatus ([ref]$inBlock_File)
                    }
                    # End of file read loop
                }
                # End of file list loop
            } catch {
                # Handle any errors during file resolution or reading.
                $errMsg = "Error processing path '$Path'. Error: $($_.Exception.Message)"
                $errRecord = New-Object System.Management.Automation.ErrorRecord(
                    $_.Exception, "FileProcessingError",
                    [System.Management.Automation.ErrorCategory]::ReadError, $Path
                )
                $PSCmdlet.WriteError($errRecord)
            }
        }
    }
}

# set alias
[String] $tmpAliasName = "glb"
[String] $tmpCmdName   = "Get-LabelBlock"
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

