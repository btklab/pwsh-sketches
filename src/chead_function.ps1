<#
.SYNOPSIS
    chead - Cuts the first part of files or pipeline input.

        Usage:
            1..5 | chead -n 2
            ls | chead

    This function cuts a specified number of lines from the beginning of the input,
    or cuts all lines up to and including the first line that matches a regular expression.
    It is optimized for memory efficiency, especially when dealing with large files or streams,
    by processing input line by line or in chunks rather than loading everything into memory.

.PARAMETER Lines
    Specifies the number of lines to cut from the beginning of the input.
    The default is 1. This parameter has an alias of '-n'.
    This parameter belongs to the 'Lines' parameter set and cannot be used with -Match.

.PARAMETER Match
    Specifies a regular expression. The function will cut all lines from the beginning
    of the input until it finds a line that matches this pattern. The matching line
    is also cut. This parameter cannot be used with -Lines.
    This parameter belongs to the 'Match' parameter set and cannot be used with -Lines.

.PARAMETER Path
    Specifies the path to one or more files to be processed.
    Wildcards are not permitted. This parameter has an alias of '-p'.
    When this parameter is used, pipeline input is ignored.

.PARAMETER InputObject
    Accepts input from the pipeline. Each object passed through the pipeline
    will be processed by the 'PROCESS' block.

.LINK
    head, tail, chead, ctail, tail-f

.EXAMPLE
    # Example 1: Cut the first line (default behavior) from pipeline input.
    1..5 | chead
    # Output:
    # 2
    # 3
    # 4
    # 5

.EXAMPLE
    # Example 2: Cut the first 2 lines from a file using the -n alias.
    1..5 | Set-Content -Path 'a.txt'
    chead -n 2 -Path 'a.txt'
    # Output:
    # 3
    # 4
    # 5

.EXAMPLE
    # Example 3: Cut lines until a line containing '3' is found.
    'Line 1', 'Line 2', 'Line 3', 'Line 4' | chead -Match '3'
    # Output:
    # Line 4

.EXAMPLE
    # Example 4: Using a more complex regex to cut until a line starting with 'c'.
    'apple', 'banana', 'cherry', 'date' | Set-Content -Path 'b.txt'
    chead -Match '^c' -Path 'b.txt'
    # Output:
    # date

.NOTES
    This function processes input from either files (using -Path) or the pipeline (-InputObject),
    but not both simultaneously. If -Path is specified, pipeline input is ignored.
    When using the pipeline, input is processed line by line for memory efficiency.
#>
function chead {
    [CmdletBinding(DefaultParameterSetName='Lines')] # Set 'Lines' as the default parameter set
    param (
        # Parameter set for cutting a specific number of lines.
        [Parameter(Mandatory=$false, ParameterSetName='Lines')]
        [Alias('n')]
        [int] $Lines = 1,

        # Parameter set for cutting until a regex match.
        [Parameter(Mandatory=$false, ParameterSetName='Match')]
        [Alias('m')]
        [string] $Match,

        # Common parameter for file input.
        [Parameter(Mandatory=$false, Position=0)]
        [Alias('p')]
        [string[]] $Path,

        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [object] $InputObject
    )

    # BEGIN block: Executed once when the function starts.
    # Used to initialize state variables that persist across PROCESS block calls.
    BEGIN {
        # Counter to track how many lines still need to be skipped when using the 'Lines' parameter set.
        # Initialized with the value of $Lines (defaulting to 1 if not specified).
        [int]$linesToSkip = $Lines
        # Flag to indicate if the regex match has been found when using the 'Match' parameter set.
        # This determines when to start outputting lines.
        [bool]$foundMatch = $false
        # Check if the -Path parameter was provided.
        if ($Path.Count -gt 0) {
            # Iterate through each file specified in the -Path array.
            foreach ($file in $Path) {
                # Use a try-catch block to gracefully handle potential errors during file reading,
                # such as file not found or access denied.
                try {
                    # Read the file content in chunks for memory efficiency.
                    # -ReadCount 1000 tells Get-Content to read 1000 lines at a time into an array.
                    # This avoids loading the entire (potentially very large) file into memory at once.
                    $fileContentChunks = Get-Content -LiteralPath $file -Encoding utf8 -ReadCount 1000

                    # Reset state variables for each new file being processed.
                    # This ensures that the cutting logic starts fresh for every file.
                    [int]$linesToSkip = $Lines
                    [bool]$foundMatch = $false

                    # Iterate through each chunk (or line if -ReadCount is 1) of the file content.
                    foreach ($line in $fileContentChunks) {
                        # Apply the same cutting logic as in the PROCESS block,
                        # but now to lines read from the file.
                        if ($PSCmdlet.ParameterSetName -eq 'Match') {
                            if ($foundMatch) {
                                Write-Output $line
                            }
                            elseif ($line -match $Match) {
                                $foundMatch = $true
                            }
                        }
                        else { # 'Lines' parameter set or default
                            if ($linesToSkip -gt 0) {
                                $linesToSkip--
                            }
                            else {
                                Write-Output $line
                            }
                        }
                    }
                }
                catch {
                    # Output an error message if file reading fails, including the file name
                    # and the specific exception message for easier debugging.
                    Write-Error "Error reading file: $($file) - $($_.Exception.Message)"
                }
            }
            return
        }
    }

    # PROCESS block: Executed for each input object received from the pipeline.
    # This is where the core line-by-line processing logic for pipeline input resides.
    PROCESS {
        # If the -Path parameter is specified, it means input is coming from files,
        # not the pipeline. In this case, we should ignore pipeline input.
        # File processing will be handled in the END block.
        if ($Path.Count -eq 0) {
            # Determine which cutting method to apply based on the active parameter set.
            # $PSCmdlet.ParameterSetName holds the name of the parameter set currently in use.
            if ($PSCmdlet.ParameterSetName -eq 'Match') {
                # Logic for cutting until a regex match is found.
                # If the match has already been found, output the current line.
                if ($foundMatch) {
                    Write-Output $InputObject # $_ represents the current pipeline object (line)
                }
                # If the match has not yet been found, check if the current line matches the regex.
                elseif ($InputObject -match $Match) {
                    # A match is found. Set the flag to true so all subsequent lines will be outputted.
                    # The matching line itself is skipped (cut) as per the function's definition.
                    $foundMatch = $true
                }
                # If no match is found and the flag is still false, the line is implicitly skipped (cut).
            }
            # Logic for cutting a fixed number of lines from the start (default or when -Lines is used).
            else {
                # If there are still lines to skip, decrement the counter.
                if ($linesToSkip -gt 0) {
                    $linesToSkip--
                }
                # If all initial lines have been skipped, start outputting the current line.
                else {
                    Write-Output $InputObject
                }
            }
        }
    }
}
