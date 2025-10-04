function Get-Block {
    <#
    .SYNOPSIS
        Get-Block -- Extracts blocks of text.

        Extracts blocks of text from standard input
        that are between two patterns (shortest match mode).

    .DESCRIPTION
        The Get-Block function reads text from the pipeline and extracts blocks based on patterns (regular expressions or simple strings).

        It performs a "shortest match" and outputs all blocks that fit the criteria. A block starts with a line matching the -From pattern and ends with the first subsequent line matching the -To pattern (unless -Until is used).

        - If -From is omitted, the block starts from the beginning of the input.
        - If -To or -Until is omitted, the block continues to the end of the input.

        -To outputs the line matching the pattern.
        -Until outputs the line immediately preceding the line matching the pattern, excluding the pattern line itself.

        You can control which blocks are returned using the -First or -Last switches.

    .PARAMETER From
        The pattern (regex or literal string) that marks the beginning of a block. If omitted, the block starts from the beginning of the input.

    .PARAMETER To
        The pattern (regex or literal string) that marks the end of a block, INCLUDING the matching line in the output. If omitted, the block continues to the end of the input.

    .PARAMETER Until
        The pattern (regex or literal string) that marks the end of a block, EXCLUDING the matching line from the output. The block ends with the line immediately before the match. If omitted, the block continues to the end of the input.

    .PARAMETER InputObject
        The input text to be processed. This is typically provided via the pipeline.

    .PARAMETER CaseSensitive
        If specified, the matching for all patterns will be case-sensitive. By default, matching is case-insensitive.

    .PARAMETER SimpleMatch
        If specified, -From, -To, and -Until are treated as literal substring patterns (not regular expressions), using the -like or -clike comparison operator.

    .PARAMETER First
        If specified, this switch outputs only the first block found.

    .PARAMETER Last
        If specified, this switch outputs only the last block found. Note: Using -Last requires the script to buffer all input in memory, which may be slow for very large inputs.

    .INPUTS
        System.String
        You can pipe strings to this function.

    .OUTPUTS
        System.String
        The function outputs the strings that constitute the extracted block(s).

    .EXAMPLE
        # Example 1: Use SimpleMatch for a case-insensitive substring match
        PS C:\> "Line: Header", "START Block", "Data", "End Block", "Line 5" | Get-Block -From Block -To End -SimpleMatch
        START Block
        Data
        End Block

    .EXAMPLE
        # Example 2: Use SimpleMatch with CaseSensitive for a case-sensitive substring match
        PS C:\> "Line: Header", "Start Block", "Data", "END Block", "Line 5" | Get-Block -From Start -To END -SimpleMatch -CaseSensitive
        Start Block
        Data
        END Block

    .EXAMPLE
        # Example 3: Use Until with SimpleMatch (excluding the END line)
        PS C:\> "Line: Header", "START Block", "Data", "END Block", "Line 5" | Get-Block -From Block -Until END -SimpleMatch
        START Block
        Data
    #>
    [CmdletBinding(DefaultParameterSetName = 'ShortestTo')]
    param (
        [Parameter(Mandatory = $false, Position = 0)]
        [Alias('f')]
        [string]$From,

        [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'ShortestTo')]
        [Alias('t')]
        [string]$To,

        [Parameter(Mandatory = $false, Position = 1, ParameterSetName = 'ShortestUntil')]
        [Alias('u')]
        [string]$Until,

        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [string]$InputObject,

        [Parameter(Mandatory = $false)]
        [Alias('i')]
        [switch]$CaseSensitive,

        [Parameter(Mandatory = $false)]
        [switch]$SimpleMatch,

        [Parameter(ParameterSetName = 'ShortestUntil')]
        [switch]$First,

        [Parameter(ParameterSetName = 'ShortestUntil')]
        [switch]$Last
    )

    begin {
        # Store boolean flags for matching logic
        $isCaseSensitive = $CaseSensitive.IsPresent
        $isSimpleMatch = $SimpleMatch.IsPresent
        
        $useUntil = $PSBoundParameters.ContainsKey('Until')

        # Initialize for shortest match (streaming).
        # If -From is not specified, $inBlock starts as true.
        $inBlock = -not $PSBoundParameters.ContainsKey('From')
        $currentBlock = [System.Collections.Generic.List[string]]::new()
        $foundFirst = $false
        
        # If -Last is specified, we must store all found blocks.
        if ($Last) {
            $allBlocks = [System.Collections.Generic.List[object]]::new()
        }
    }

    process {
        # If -First is specified and we've already found and outputted the block, skip all subsequent processing.
        if ($First -and $foundFirst) {
            return
        }

        if (-not $inBlock) {
            # We are not in a block, looking for the 'From' pattern.
            $fromPattern = $From
            $fromMatch = $false
            
            if ($PSBoundParameters.ContainsKey('From')) {
                # Determine match based on flags
                if ($isSimpleMatch) {
                    # SimpleMatch (Substring): Use -like or -clike with wildcard prefix/suffix
                    $wildcardPattern = "*$fromPattern*"
                    if ($isCaseSensitive) {
                        $fromMatch = ($InputObject -clike $wildcardPattern)
                    } else {
                        $fromMatch = ($InputObject -like $wildcardPattern)
                    }
                } else {
                    # Regex match (Default): Use -match or -cmatch
                    if ($isCaseSensitive) {
                        $fromMatch = ($InputObject -cmatch $fromPattern)
                    } else {
                        $fromMatch = ($InputObject -match $fromPattern)
                    }
                }
            }

            if ($fromMatch) {
                $inBlock = $true
                $currentBlock.Add($InputObject)
            }
        }
        else {
            # We are inside a block.

            # Check for the end of the block if -To or -Until is specified.
            $toOrUntilSpecified = $PSBoundParameters.ContainsKey('To') -or $PSBoundParameters.ContainsKey('Until')

            if ($toOrUntilSpecified) {
                $endPattern = if ($useUntil) { $Until } else { $To }
                $endMatch = $false

                # Determine match based on flags
                if ($isSimpleMatch) {
                    # SimpleMatch (Substring): Use -like or -clike with wildcard prefix/suffix
                    $wildcardPattern = "*$endPattern*"
                    if ($isCaseSensitive) {
                        $endMatch = ($InputObject -clike $wildcardPattern)
                    } else {
                        $endMatch = ($InputObject -like $wildcardPattern)
                    }
                } else {
                    # Regex match (Default): Use -match or -cmatch
                    if ($isCaseSensitive) {
                        $endMatch = ($InputObject -cmatch $endPattern)
                    } else {
                        $endMatch = ($InputObject -match $endPattern)
                    }
                }

                if ($endMatch) {
                    # Block is ending
                    if (-not $useUntil) {
                        # -To: include the matching line
                        $currentBlock.Add($InputObject)
                    }
                    # If -Until: do NOT include the matching line

                    if ($Last) {
                        # Store the completed block if -Last is active.
                        $allBlocks.Add($currentBlock.ToArray())
                    }
                    elseif ($First) {
                        # Output immediately and set flag if -First is active.
                        $currentBlock | ForEach-Object { Write-Output $_ }
                        $foundFirst = $true
                    }
                    else {
                        # Default: output all found blocks immediately.
                        $currentBlock | ForEach-Object { Write-Output $_ }
                    }

                    # Reset for the next block.
                    $currentBlock.Clear()
                    $inBlock = $false
                    return # Stop further processing for this line.
                }
            }

            # If the block didn't end, add the current line to the block.
            $currentBlock.Add($InputObject)
        }
    }

    end {
        # --- Shortest Match Finalization ---

        # Handle any unterminated block at the end of the input
        if ($currentBlock.Count -gt 0) {
            if ($Last) {
                # Store the final unterminated block.
                $allBlocks.Add($currentBlock.ToArray())
            }
            # For -First or default, output if no block has been outputted yet.
            elseif (-not $foundFirst) {
                $currentBlock | ForEach-Object { Write-Output $_ }
            }
        }

        # If -Last was specified, output only the very last block collected (terminated or unterminated).
        if ($Last -and $allBlocks.Count -gt 0) {
            $allBlocks[-1] | ForEach-Object { Write-Output $_ }
        }
    }
}
