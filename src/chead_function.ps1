<#
.SYNOPSIS
    chead - Cut the first part of files.

        Usage:
            1..5 | chead -n 2
            ls | chead

    Cuts a specified number of lines from the beginning of the input,
    or cuts all lines up to and including the first line that matches a regular expression.

.PARAMETER Lines
    Specifies the number of lines to cut from the beginning of the input.
    The default is 1. This parameter has an alias of '-n'.

.PARAMETER Until
    Specifies a regular expression. The function will cut all lines from the beginning
    of the input until it finds a line that matches this pattern. The matching line
    is also cut. This parameter cannot be used with -Lines.

.PARAMETER Path
    Specifies the path to one or more files to be processed.
    Wildcards are not permitted. This parameter has an alias of '-p'.

.PARAMETER InputObject
    Accepts input from the pipeline.

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
    'Line 1', 'Line 2', 'Line 3', 'Line 4' | chead -Until '3'
    # Output:
    # Line 4

.EXAMPLE
    # Example 4: Using a more complex regex to cut until a line starting with 'c'.
    'apple', 'banana', 'cherry', 'date' | Set-Content -Path 'b.txt'
    chead -Until '^c' -Path 'b.txt'
    # Output:
    # date

.NOTES
    This function processes input from either files (using -Path) or the pipeline, but not both at the same time.
    When using the pipeline, the entire input is collected before processing begins.
#>
function chead {
    [CmdletBinding()]
    param (
        # Parameter set for cutting a specific number of lines.
        [Parameter(Mandatory=$false)]
        [Alias('n')]
        [int] $Lines = 1,

        # Parameter set for cutting until a regex match.
        [Parameter(Mandatory=$false)]
        [Alias('u')]
        [string] $Until,

        # Common parameter for file input.
        [Parameter(Mandatory=$false, Position=0)]
        [Alias('p')]
        [string[]] $Path,

        # Common parameter for pipeline input.
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [psobject[]] $InputObject
    )

    # This nested helper function defines the core logic for processing a stream of text.
    # Using a helper function avoids duplicating the processing logic for file and pipeline inputs,
    # making the code cleaner and easier to maintain.
    function Process-Content {
        param (
            [Parameter(Mandatory=$true)]
            [object[]] $Content
        )

        # Decide which cutting method to use based on the active parameter set.
        # A switch statement is a clean way to handle mutually exclusive modes of operation.
        if ( $Until ) {
            # Method: Cut until a line matches the regex pattern.
            # This flag tracks whether we have found the target line yet.
            [bool] $foundMatch = $false
            foreach ($line in $Content) {
                # If we have already found our matching line, we can start outputting.
                if ($foundMatch) {
                    # Pass the current line to the output stream.
                    Write-Output $line
                }
                # Check if the current line matches the user-provided regex.
                elseif ($line -match $Until) {
                    # A match is found. Set the flag so that all subsequent lines will be outputted.
                    # This matching line itself is skipped because this block will terminate
                    # and the next iteration will enter the 'if ($foundMatch)' block.
                    [bool] $foundMatch = $true
                }
                # If the match has not been found yet, we do nothing with the line,
                # effectively skipping (cutting) it.
            }
            break
        } else {
            # Method: Cut a fixed number of lines from the start.
            # Select-Object -Skip is highly efficient for this specific task.
            $Content | Select-Object -Skip $Lines
            break
        }
    }

    # Determine the source of the input: files or pipeline.
    if ($Path) {
        # Input is from one or more files specified by the -Path parameter.
        foreach ($file in $Path) {
            # Read the entire content of the file. Note: Get-Content reads the file
            # into an array of strings, which is suitable for the Process-Content function.
            $fileContent = Get-Content -LiteralPath $file
            Process-Content -Content $fileContent
        }
    } else {
        # Input is from the pipeline.
        # The automatic variable '$input' contains all objects passed through the pipeline.
        # We pass this collection directly to our processing function.
        Process-Content -Content $input
    }
}
