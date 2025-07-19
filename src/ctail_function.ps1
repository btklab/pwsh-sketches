<#
.SYNOPSIS
    ctail - Cut the last part of files.

        Usage:
            1..5 | ctail -n 2
            ls | ctail

    Cuts lines from the end of the input. This can be a specified number of lines,
    or all lines after a line that matches a regular expression.

.PARAMETER Lines
    Specifies the number of lines to cut from the end of the input.
    The default is 1. This parameter has an alias of '-n'.

.PARAMETER After
    Specifies a regular expression. The function will output all lines until it finds
    a line that matches this pattern. The matching line WILL be included as the last
    line of output. All subsequent lines are cut.

.PARAMETER OnAndAfter
    Specifies a regular expression. The function will output all lines until it finds
    a line that matches this pattern. The matching line and all subsequent lines
    WILL BE CUT from the output.

.PARAMETER Path
    Specifies the path to one or more files to be processed.
    Wildcards are not permitted. This parameter has an alias of '-p'.

.PARAMETER InputObject
    Accepts input from the pipeline.

.LINK
    head, tail, chead, ctail, tail-f

.EXAMPLE
    # Example 1: Cut the last line (default behavior).
    1..5 | ctail
    # Output:
    # 1
    # 2
    # 3
    # 4

.EXAMPLE
    # Example 2: Cut the last 2 lines from a file.
    1..5 | Set-Content -Path 'a.txt'
    ctail -n 2 -Path 'a.txt'
    # Output:
    # 1
    # 2
    # 3

.EXAMPLE
    # Example 3: Use -After to output everything up to and including the line with '3'.
    'Line 1', 'Line 2', 'Line 3', 'Line 4', 'Line 5' | ctail -After '3'
    # Output:
    # Line 1
    # Line 2
    # Line 3

.EXAMPLE
    # Example 4: Use -OnAndAfter to output everything before the line with '3'.
    'Line 1', 'Line 2', 'Line 3', 'Line 4', 'Line 5' | ctail -OnAndAfter '3'
    # Output:
    # Line 1
    # Line 2

.NOTES
    The -Lines, -After, and -OnAndAfter parameters are mutually exclusive.
    This function processes input from either files (using -Path) or the pipeline.
#>
function ctail {
    [CmdletBinding()]
    param (
        # Parameter set for cutting a specific number of lines from the end.
        [Parameter(Mandatory=$false)]
        [Alias('n')]
        [int] $Lines = 1,

        # Parameter set for cutting after a regex match.
        [Parameter(Mandatory=$false)]
        [Alias('a')]
        [string] $After,

        [Parameter(Mandatory=$false)]
        [Alias('o')]
        [string] $OnAndAfter,

        # Common parameter for file input.
        [Parameter(Mandatory=$false, Position=0)]
        [Alias('p')]
        [string[]] $Path,

        # Common parameter for pipeline input.
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [psobject[]] $InputObject
    )

    # This nested helper function contains the core logic for processing a stream of text.
    # This approach avoids code duplication for file and pipeline inputs, enhancing maintainability.
    function Process-Content {
        param (
            [Parameter(Mandatory=$true)]
            [object[]] $Content
        )

        # A switch statement provides a clean way to select the operation mode
        # based on the parameter set used by the caller.
        if ( $After -or $OnAndAfter ) {
            # Method: Output lines until a regex match is found, then stop.
            foreach ($line in $Content) {
                # Output the current line.
                if ($OnAndAfter -and ($line -match $OnAndAfter) ) {
                    #pass
                } else {
                    Write-Output $line
                }

                # Check if the current line matches the specified regex.
                if ($OnAndAfter -and ($line -match $OnAndAfter) ) {
                    # Match found. We break the loop immediately, which stops
                    # any further lines from being output. This effectively
                    # "cuts" the rest of the file.
                    break
                }
                if ($After -and ($line -match $After)) {
                    # Match found. We break the loop immediately, which stops
                    # any further lines from being output. This effectively
                    # "cuts" the rest of the file.
                    break
                }
            }
            break
        } else {
            # Method: Cut a fixed number of lines from the end.
            # 'Select-Object -SkipLast' is the most direct and efficient
            # cmdlet for this purpose.
            $Content | Select-Object -SkipLast $Lines
            break
        }
    }

    # Determine the input source: files or pipeline.
    if ($Path) {
        # Input is from one or more files specified by the -Path parameter.
        foreach ($file in $Path) {
            # Read all content from the file into an array of strings.
            $fileContent = Get-Content -LiteralPath $file
            # Pass the content to our core logic function.
            Process-Content -Content $fileContent
        }
    } else {
        # Input is from the pipeline.
        # The automatic variable '$input' holds all pipeline input.
        # We pass this collection directly to our processing function.
        Process-Content -Content $input
    }
}
