<#
.SYNOPSIS
    Head-Object (Alias: head) - Outputs the first part of files or pipeline objects.

.DESCRIPTION
    This function outputs a specified number of lines or objects from the beginning
    of files or pipeline input. It defaults to the first 10 items.

    If file paths are provided as arguments, it reads from the files.
    Otherwise, it processes objects from the pipeline in a memory-efficient, streaming manner.

.LINK
    Get-Content, Select-Object

.EXAMPLE
    # Get the first 5 numbers from a range.
    1..10 | head -n 5

.EXAMPLE
    # Get the first 10 items from the current directory.
    Get-ChildItem | head

.EXAMPLE
    head *.* -n 3
    
    ==> timeline-date-val.txt <==
    date val1 val2
    2018-01 107.3 272.1
    2018-02 98.1 262.1
    
    ==> tips.csv <==
    "total_bill","tip","sex","smoker","day","time","size"
    16.99,1.01,"Female","No","Sun","Dinner",2
    10.34,1.66,"Male","No","Sun","Dinner",3
    
    ==> titanic.csv <==
    survived,pclass,sex,age,sibsp,parch,fare,embarked,class,who,adult_male,deck,embark_town,alive,alone
    0,3,male,22.0,1,0,7.25,S,Third,man,True,,Southampton,no,False
    1,1,female,38.0,1,0,71.2833,C,First,woman,False,C,Cherbourg,yes,False

.EXAMPLE
    # Display the first 3 lines of every .txt and .csv file in the current directory.
    head *.txt, *.csv -n 3
#>
function Head-Object {
    [CmdletBinding()]
    Param(
        # The path to the file(s) to be processed. Wildcards are permitted.
        [Parameter(Mandatory=$False, Position=0)]
        [alias('p')]
        [string[]] $Path,
        
        # The number of lines or objects to output from the beginning.
        [Parameter(Mandatory=$False)]
        [alias('n')]
        [int] $Num = 10,
        
        # Accepts input from the pipeline, one object at a time.
        [parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [object] $InputObject
    )

    begin {
        # Counter for tracking the number of items processed from the pipeline.
        [int]$lineCount = 0

        # This block handles file-based input.
        # It only runs if no input was received from the pipeline, making file-path
        # and pipeline processing mutually exclusive.
        if ( $Path.Count -gt 0) {
            # Use -ErrorAction SilentlyContinue to handle cases where wildcards match no files.
            [object[]] $PathObjects = Get-ChildItem -Path $Path -ErrorAction SilentlyContinue
            if ($PathObjects.Count -eq 0) {
                # Do nothing if no files were found.
                return
            }

            if ($PathObjects.Count -eq 1) {
                # If there's only one file, output its content directly.
                $splatting = @{
                    Path       = $PathObjects[0].FullName
                    TotalCount = $Num
                    Encoding   = "utf8"
                }
                Get-Content @splatting
            } else {
                # If there are multiple files, iterate through them and display
                # each file's name as a header before its content, similar to UNIX head.
                foreach ($p in $PathObjects) {
                    [string] $fileName = $p.Name
                    $splatting = @{
                        Path       = $p.FullName
                        TotalCount = $Num
                        Encoding   = "utf8"
                    }
                    Write-Host ""
                    Write-Host "==> $fileName <==" -ForegroundColor Green
                    Get-Content @splatting
                }
            }
            return
        }
    }

    process {
        if ( $Path.Count -eq 0 ) {
            # Continue to output objects only until the limit ($Num) is reached.
            # This avoids processing the entire pipeline if only the first few items are needed.
            if ($lineCount -lt $Num) {
                Write-Output $_
                $lineCount++
            }
        }
    }
}

#region Alias Setup
# The following logic safely sets up the 'head' alias for the Head-Object function.
# It checks for existing commands or aliases to prevent unintended conflicts.
[String] $tmpAliasName = "head"
[String] $tmpCmdName   = "Head-Object"
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
# endregion