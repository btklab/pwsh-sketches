<#
.SYNOPSIS
    addb - add text bottom of line

    Inspired by:
        greymd/egzact: Generate flexible patterns on the shell - GitHub
        https://github.com/greymd/egzact

.EXAMPLE
    "A B C D" | addt '<table>' | addb '</table>'
    <table>
    A B C D
    </table>

.EXAMPLE
    "A B C D" | addt '# this is title','' | addb '','this is footer'
    # this is title
    
    A B C D
    
    this is footer


.LINK
    addt, addb, addl, addr

#>
function addb {
  # Enable common parameters like -Verbose, -Debug, and -ErrorAction.
  # This makes the function more robust and consistent with standard PowerShell cmdlets.
  [CmdletBinding()]
  Param (
    # The text to append to the end of the entire output.
    [Parameter(Position=0, Mandatory=$true)]
    [AllowEmptyString()]
    [string[]] $TextToAdd,

    # The input objects coming from the pipeline.
    [Parameter(ValueFromPipeline=$true)]
    [string[]] $InputObject
  )

  # The 'process' block is executed for each object that comes from the pipeline.
  # We simply pass the input object through to the next command.
  # This approach allows for efficient streaming of data, which is crucial
  # for handling large inputs without consuming excessive memory.
  process {
    Write-Output $InputObject
  }

  # The 'end' block is executed only once, after all pipeline input has been processed.
  # This is the perfect place to append our text, ensuring it appears at the very end.
  end {
    # Loop through each line of the text to be added and output it.
    foreach ($line in $TextToAdd){
      Write-Output $line
    }
  }
}
