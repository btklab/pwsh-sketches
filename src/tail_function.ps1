<#
.SYNOPSIS
    Tail-Object (Alias: tail) - Outputs the last part of files or pipeline objects.

.DESCRIPTION
    This function outputs a specified number of lines or objects from the end
    of files or pipeline input. It defaults to the last 10 items.

    If file paths are provided as arguments, it reads from the files.
    Otherwise, it processes objects from the pipeline in a memory-efficient, streaming manner.

.LINK
    Get-Content, Select-Object

.EXAMPLE
    # Get the last 5 numbers from a range.
    1..20 | tail -n 5

.EXAMPLE
    # Get the last 10 items from the current directory.
    Get-ChildItem | tail

.EXAMPLE
    tail *.*

    ==> timeline-date-val.txt <==
    2020-04 366.5 544.1
    2020-05 605.8 770.3
    2020-06 706.9 836.6

    ==> tips.csv <==
    22.67,2,"Male","Yes","Sat","Dinner",2
    17.82,1.75,"Male","No","Sat","Dinner",2
    18.78,3,"Female","No","Thur","Dinner",2

    ==> titanic.csv <==
    0,3,female,,1,2,23.45,S,Third,woman,False,,Southampton,no,False
    1,1,male,26.0,0,0,30.0,C,First,man,True,C,Cherbourg,yes,True
    0,3,male,32.0,0,0,7.75,Q,Third,man,True,,Queenstown,no,True

.EXAMPLE
    # Display the last 3 lines of every .txt and .csv file.
    tail *.txt, *.csv -n 3
#>
function Tail-Object {
    [CmdletBinding()]
    Param(
        # The path to the file(s) to be processed. Wildcards are permitted.
        [Parameter(Mandatory=$False, Position=0)]
        [alias('p')]
        [string[]] $Path,
        
        # The number of lines or objects to output from the end.
        [Parameter(Mandatory=$False)]
        [alias('n')]
        [int] $Num = 10,
        
        # Accepts input from the pipeline, one object at a time.
        [parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [object] $InputObject
    )

    begin {
        if ($Path.Count -gt 0) {
            # This block handles file-based input. It only runs if no input was
            # received from the pipeline.
            [object[]] $PathObjects = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue
            
            if ($PathObjects.Count -eq 0) {
                return
            }

            if ($PathObjects.Count -eq 1) {
                # If there's only one file, output its content directly.
                # Get-Content -Tail is already memory-efficient for file reading.
                $splatting = @{
                    Path     = $PathObjects[0].FullName
                    Tail     = $Num
                    Encoding = "utf8"
                }
                Get-Content @splatting
            } 
            else {
                # If there are multiple files, display each file's name as a header.
                foreach ($p in $PathObjects) {
                    [string] $fileName = $p.Name
                    $splatting = @{
                        Path     = $p.FullName
                        Tail     = $Num
                        Encoding = "utf8"
                    }
                    Write-Host ""
                    Write-Host "==> $fileName <==" -ForegroundColor Green
                    Get-Content @splatting
                }
            }
            return
        }

        # A fixed-size buffer (queue) is used to store the most recent items
        # from the pipeline without holding the entire stream in memory.
        $buffer = [System.Collections.Generic.Queue[object]]::new()
    }

    process {
        if ( $Path.Count -eq 0 ) {
            # Mark that we have received at least one object from the pipeline.
            # Add the new item to the queue.
            $buffer.Enqueue($_)

            # If the queue size exceeds the desired number of lines, remove the oldest item.
            # This maintains a "sliding window" of the most recent N items.
            if ($buffer.Count -gt $Num) {
                [void]$buffer.Dequeue()
            }
        }
    }

    end {
        # The 'end' block executes after all pipeline processing is complete.
        if ($Path.Count -eq 0) {
            # If input came from the pipeline, the buffer now holds the last N items.
            # Output the contents of the buffer.
            $buffer.ToArray()
        }
    }
}

#region Alias Setup
# The following logic safely sets up the 'tail' alias for the Tail-Object function.
# It checks for existing commands or aliases to prevent unintended conflicts.
[String] $tmpAliasName = "tail"
[String] $tmpCmdName   = "Tail-Object"
# Get the relative path of this script for use in clear error messages.
[String] $tmpCmdPath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath $($MyInvocation.MyCommand.Name) `
    | Resolve-Path -Relative
if ($IsWindows) { $tmpCmdPath = $tmpCmdPath.Replace('\', '/') }
$existingCommand = Get-Command -Name $tmpAliasName -ErrorAction SilentlyContinue
if ($existingCommand) {
    # The name is already in use. We need to check if it's safe to override.
    if (($existingCommand.CommandType -eq "Alias" -and $existingCommand.ReferencedCommand.Name -eq $tmpCmdName)) {
        # The alias already points to our function, which is fine. No action needed.
    } 
    elseif ($existingCommand.Name -match '\.exe$') {
        # The name is an executable (e.g., a GNU utility). 
        # We can safely create a PowerShell-specific alias that takes precedence.
        Set-Alias -Name $tmpAliasName -Value $tmpCmdName
    }
    else {
        # The name is a conflicting command or alias. Throw a terminating error.
        $errorMessage = "Error: Alias '$tmpAliasName' is already in use and points to '$($existingCommand.Definition)'. " +
                        "To avoid conflicts, please edit the alias name at the end of the script: '$tmpCmdPath'"
        Write-Error $errorMessage -ErrorAction Stop
    }
}
else {
    # The alias doesn't exist, so we can create it safely.
    Set-Alias -Name $tmpAliasName -Value $tmpCmdName
}
# Clean up the temporary variables used for this setup.
Remove-Variable -Name "tmpAliasName", "tmpCmdName", "tmpCmdPath" -ErrorAction SilentlyContinue
#endregion