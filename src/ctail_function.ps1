<#
.SYNOPSIS
    ctail - Cuts the tail of files or pipeline input.

.DESCRIPTION
    Streams input from either the pipeline or one or more files.
    You can remove a fixed number of lines from the end (-Lines),
    or stop at the first regex match and drop the rest (-Match).
    Processes one line at a time for minimal memory usage.

.PARAMETER Lines
    Number of lines to remove from the end of the input.

.PARAMETER Match
    Regular expression at which to cut off the rest of the input.

.PARAMETER Path
    One or more file paths to read instead of using the pipeline.

.PARAMETER InputObject
    Objects streamed in from the pipeline.

.EXAMPLE
    # Remove the last two lines from pipeline input
    1..5 | ctail -n 2

.EXAMPLE
    # Output everything before the first line containing "ERROR"
    ctail -Match 'ERROR' -Path 'application.log'
#>
function ctail {
    [CmdletBinding(DefaultParameterSetName = 'Lines')]
    param (
        # Number of lines to drop from the end
        [Parameter(ParameterSetName = 'Lines')]
        [Alias('n')]
        [int] $Lines = 1,

        # Regex at which to stop and drop all following lines
        [Parameter(ParameterSetName = 'Match')]
        [Alias('m')]
        [string] $Match,

        # File paths to process instead of pipeline
        [Parameter(ParameterSetName = 'Lines', Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Parameter(ParameterSetName = 'Match',  Position = 0, ValueFromPipelineByPropertyName = $true)]
        [Alias('p')]
        [string[]] $Path,

        # Pipeline input
        [Parameter(ParameterSetName = 'Lines', ValueFromPipeline = $true)]
        [Parameter(ParameterSetName = 'Match',  ValueFromPipeline = $true)]
        [object] $InputObject
    )

    Begin {
        # This determines when to end outputting lines.
        [bool]$foundMatch = $false
        # Buffer used in Lines mode to hold up to $Lines previous lines
        $buffer = New-Object 'System.Collections.Generic.Queue[object]'
        # If -Path is specified, read each file line by line
        if ($PSBoundParameters.ContainsKey('Path')) {
            foreach ($file in $Path) {
                # Reset buffer for each file
                $buffer.Clear()

                # Stream each line to avoid loading the entire file
                Get-Content -LiteralPath $file -Encoding utf8 -ReadCount 1 | ForEach-Object {
                    [string]$line = $_
                    switch ($PSCmdlet.ParameterSetName) {

                        'Match' {
                            # Stop reading once the match is found
                            if ($line -match $Match) {
                                break
                            }
                            Write-Output $line
                        }

                        'Lines' {
                            # Same queue logic as pipeline mode
                            $buffer.Enqueue($line)
                            if ($buffer.Count -gt $Lines) {
                                Write-Output $buffer.Dequeue()
                            }
                        }
                    }
                }
            }
            return
        }
    }

    Process {
        # If no -Path was provided, treat pipeline input here
        if (-not $PSBoundParameters.ContainsKey('Path')) {
            switch ($PSCmdlet.ParameterSetName) {

                'Match' {
                    # Drop all following lines once we hit the regex
                    if ( $foundMatch ) {
                        return
                    }
                    if ($InputObject -match $Match) {
                        [bool]$foundMatch = $true
                        return
                    }
                    Write-Output $InputObject
                }

                'Lines' {
                    # Enqueue each incoming line;
                    # once buffer exceeds $Lines, dequeue and output
                    $buffer.Enqueue($InputObject)
                    if ($buffer.Count -gt $Lines) {
                        Write-Output $buffer.Dequeue()
                    }
                }
            }
        }
    }
}
