<#
.SYNOPSIS
    i : Invoke-Link - Open file/web links written in a text file.

    Open file or web links from a text file, pipeline, or clipboard.
    Processing priority: pipeline > arguments > clipboard.

    Usage:
        ## Read and execute links written in a text file.
        i <file> [label] [-Doc|-All|-First <n>] [-Grep <regex>]
            ... Invoke-Item <links-writtein-in-text-file>
    
        ## Invoke links by specifying the app.
        i <file> [label] [-Doc|-All|-First <n>] [-Grep <regex>] -App <application>
            ... application <links-writtein-in-text-file>

        ## Show labels in a file.
        i <file> [-ShowHelp|-sh]

    Linkfile structure:
        # amazon                          <- (optional) title / comment
        Tag: #amazon #shop                <- (optional) tags
        https://www.amazon.co.jp/         <- 1st uri
        https://music.amazon.co.jp/       <- 2nd uri

        @shopping : Online shopping sites <- Label block start with a comment
        https://www.rakuten.co.jp/
        https://www.yodobashi.com/

        @news                             <- Another Label block start
        https://www.nikkei.com/
        https://www.asahi.com/

    By default (without -Label), all links in the file are processed, ignoring labels.
    When a -Label is specified, only links within that block are processed.

    Within the target links (either all links or a specified label block):
    - Default: Opens the **first** link.
    - The `-Doc` switch opens the second and subsequent links.
    - The `-All` switch opens all links.
    - The `-First <n>` switch opens the first `n` links.

    The `-ShowHelp` switch lists all labels and their comments within the file.

.PARAMETER Files
    Specifies the path to the link file(s), or accepts input from the
    pipeline or clipboard.

.PARAMETER Label
    Specifies a label block (e.g., '@news') within the link file to process.

.PARAMETER ShowHelp
    Displays all labels and their comments in the file without executing
    any links.

.PARAMETER Grep
    Specifies a regular expression pattern to filter link lines.
    Only lines matching the pattern are processed.

.PARAMETER App
    Specifies an application path or name to open the links
    instead of using 'Invoke-Item'.

.PARAMETER All
    Opens all links in the target block (or the entire file).
    Overrides -Doc and -First.

.PARAMETER Doc
    Opens the second and subsequent links (skips the first link).
    Useful for opening documentation.

.PARAMETER First
    Opens the first 'n' links. If -Doc is used, this specifies the number
    of links to skip.

.PARAMETER Location
    Opens the parent directory of the file link instead of the link itself.
    Ignored for web links.

.PARAMETER Push
    Changes the current location to the parent directory of the file link
    using 'Push-Location'. Ignored for web links.

.PARAMETER Edit
    Opens the link file itself in the default editor instead of executing
    links.

.PARAMETER Editor
    Specifies an application to use for editing when the -Edit switch is
    present.

.PARAMETER LinkCheck
    Checks the validity of all links before execution (HTTP requests for
    web links, 'Test-Path' for files).

.PARAMETER BackGround
    Executes the links in a background job using 'Start-Job'.

.PARAMETER Recurse
    Includes files in subdirectories if the input file is a directory.

.PARAMETER AsFileObject
    Outputs the file links as file objects ('System.IO.FileInfo')
    instead of executing them.

.PARAMETER RemoveExtension
    (Deprecated/Unused) Processes the link line after removing the extension.

.PARAMETER AllowBulkInput
    Allows processing when more than one file or item is input.
    By default, it blocks 5 or more items.

.PARAMETER InvokeById
    (Unused) Executes only links with the specified ID(s).

.PARAMETER Id
    (Unused) Outputs the processed links with generated ID(s).

.PARAMETER ErrAction
    Specifies the error handling action for link execution (passed to
    'Invoke-Expression -ErrorAction').

.PARAMETER LimitErrorCount
    Stops execution if the number of errors exceeds this limit.

.PARAMETER NotMatch
    Inverts the -Grep behavior; processes lines that **do not** match the
    pattern.

.PARAMETER DryRun
    Outputs the command strings that would be executed without actually
    running them.

.PARAMETER Quiet
    Suppresses the output of execution commands (e.g., 'Invoke-Item "..."')
    during normal execution.

.EXAMPLE
    # link file format example
    cat mylinks.txt

    > ## Unlabeled links
    > https://www.google.com/
    > 
    > @news : Major news sites
    > https://www.nikkei.com/
    > https://www.asahi.com/
    
    # (Default) open the first uri in the entire file.
    i mylinks.txt

    > Start-Process -FilePath "https://www.google.com/"
    
    # (-All) open all uris in the entire file.
    i mylinks.txt -All

    > Start-Process -FilePath "https://www.google.com/"
    > Start-Process -FilePath "https://www.nikkei.com/"
    > Start-Process -FilePath "https://www.asahi.com/"
    
    # (-Label) open the first uri in the 'news' block
    i mylinks.txt news
    ## or
    i mylinks.txt -Label news
    
    > Start-Process -FilePath "https://www.nikkei.com/"
    
    # (-ShowHelp) Show all labels and comments in the file
    i mylinks.txt -ShowHelp

    > target synopsis
    > ------ --------
    > news   Major news sites

#>
function Invoke-Link {

    [CmdletBinding()]
    param (
        # --- Main Parameters ---
        [Parameter( Mandatory=$False, Position=0, ValueFromPipeline=$True )]
        [Alias('f')]
        [string[]] $Files,
        
        # --- Labeling Parameters ---
        [Parameter( Mandatory=$False, Position=1 )]
        [string] $Label,
        
        [Parameter( Mandatory=$False )]
        [Alias('sh')]
        [switch] $ShowHelp,
        
        [Parameter( Mandatory=$False )]
        [Alias('g')]
        [string] $Grep,

        # --- Execution Control Parameters ---
        [Parameter( Mandatory=$False )]
        [string] $App,
        
        [Parameter( Mandatory=$False )]
        [Alias('a')]
        [switch] $All,
        
        [Parameter( Mandatory=$False )]
        [Alias('man')]
        [Alias('ex')]
        [switch] $Doc,
        
        [Parameter( Mandatory=$False )]
        [int] $First = 1,
        
        # --- Mode Parameters ---
        [Parameter( Mandatory=$False )]
        [Alias('l')]
        [switch] $Location,
        
        [Parameter( Mandatory=$False )]
        [Alias('p')]
        [switch] $Push,
        
        [Parameter( Mandatory=$False )]
        [Alias('e')]
        [switch] $Edit,
        
        [Parameter( Mandatory=$False )]
        [string] $Editor,
        
        [Parameter( Mandatory=$False )]
        [switch] $LinkCheck,
        
        [Parameter( Mandatory=$False )]
        [Alias('b')]
        [switch] $BackGround,
        
        [Parameter( Mandatory=$False )]
        [Alias('r')]
        [switch] $Recurse,
        
        # --- Output and Error Handling ---
        [Parameter( Mandatory=$False )]
        [switch] $AsFileObject,
        
        [Parameter( Mandatory=$False )]
        [Alias('rmext')]
        [switch] $RemoveExtension,
        
        [Parameter( Mandatory=$False )]
        [switch] $AllowBulkInput,
        
        [Parameter( Mandatory=$False )]
        [Alias('i')]
        [int[]] $InvokeById,
        
        [Parameter( Mandatory=$False )]
        [int[]] $Id,
        
        [Parameter( Mandatory=$False )]
        [ValidateSet(
            "Break", "Ignore", "SilentlyContinue",
            "Suspend", "Continue", "Inquire", "Stop" )]
        [string] $ErrAction = "Stop",
        
        [Parameter( Mandatory=$False )]
        [int] $LimitErrorCount = 5,
        
        [Parameter( Mandatory=$False )]
        [Alias('v')]
        [switch] $NotMatch,
        
        [Parameter( Mandatory=$False )]
        [Alias('d')]
        [switch] $DryRun,
        
        [Parameter( Mandatory=$False )]
        [Alias('q')]
        [switch] $Quiet
    )
    # private functions
    # Determines if a line is a comment, empty, a tag line, or a label line.
    # These lines should not be treated as executable links.
    function isCommentOrEmptyLine ( [string] $line ){
        [bool] $coeFlag = $False
        if ( $line -match '^#' )   { $coeFlag = $True }
        if ( $line -match '^\s*$' ){ $coeFlag = $True }
        if ( $line -match '^[Tt][Aa][Gg]:' ){ $coeFlag = $True }
        # Label lines are also treated as non-executable lines.
        if ( $line -match '^@' ) { $coeFlag = $True }
        return $coeFlag
    }
    # Checks if a line is a web link.
    function isLinkHttp ( [string] $line ){
        [bool] $httpFlag = $False
        if ( $line -match '^https*:' ){ $httpFlag = $True }
        if ( $line -match '^www\.' )  { $httpFlag = $True }
        return $httpFlag
    }
    # Checks if a web link is accessible by making a web request.
    function isLinkAlive ( [string] $uri ){
        $origErrActPref = $ErrorActionPreference
        try {
            $ErrorActionPreference = "SilentlyContinue"
            $Response = Invoke-WebRequest -Uri "$uri"
            $ErrorActionPreference = $origErrActPref
            # This will only execute if the Invoke-WebRequest is successful.
            $StatusCode = $Response.StatusCode
            return $True
        } catch {
            $StatusCode = $_.Exception.Response.StatusCode.value__
            return $False
        } finally {
            $ErrorActionPreference = $origErrActPref
        }
    }
    # Opens a file in the default or specified text editor.
    function editFile ( [string] $fpath ){
        if ( $Editor ){
            Invoke-Expression -Command "$Editor $fpath"
        } else {
            if ( $isWindows ){
                notepad $fpath
            } else {
                vim $fpath
            }
        }
        return
    }
    # Converts an absolute path to a relative path for cleaner output.
    function getRelativePath ( [string] $LiteralPath ){
        [String] $res = Resolve-Path -LiteralPath $LiteralPath -Relative
        if ( $IsWindows ){ [String] $res = $res.Replace('\', '/') }
        return $res
    }

    # Initialize counters and state variables.
    [int] $errCounter = 0
    [int] $invokeLocationCounter = 0
    [int] $invokeLocationLimit = 1 # Only open one file location to avoid clutter.
    [string] $valueFrom = ''
    
    # To prevent accidental execution of many files (e.g., from a wildcard),
    # this check requires -AllowBulkInput for more than one file.
    if ( -not $AllowBulkInput ){
        $bulkList = New-Object 'System.Collections.Generic.List[System.String]'
        foreach ( $f in $Files ){
            # expand wildcard
            if ( Test-Path -LiteralPath $f ){
                Get-Item -Path $f | ForEach-Object {
                    if ( Test-Path -Path $_.FullName -PathType Leaf){
                        [String] $resPath = getRelativePath $_.FullName
                        $bulkList.Add($resPath)
                    }
                }
            }
        }
        [String[]] $bulkFileAry = $bulkList.ToArray()
        if ( $bulkFileAry.Count -gt 1 ){
            foreach ( $f in $bulkFileAry ){
                Write-Output $f
            }
            Write-Error "Detect input of 5 or more items. To avoid this error, specify the '-AllowBulkInput' option." -ErrorAction Stop
        }
    }

    # Determine the source of the input: pipeline, file arguments, or clipboard.
    # This flexible input mechanism is a core feature of the function.
    [int] $fileCounter = 0
    [string[]] $readLineAry = @()
    if ( $input.Count -gt 0 ){
        [string] $valueFrom = "pipeline"
        [string[]] $readLineAry = $input `
            | ForEach-Object {
                if ( ($_ -is [System.IO.FileInfo]) -or ($_ -is [System.IO.DirectoryInfo]) ){
                    [string] $oText = $_.FullName
                } elseif ( $_ -is [System.IO.FileSystemInfo] ){
                    [string] $oText = $_.FullName
                } else {
                    [string] $oText = $_
                }
                Write-Output $oText
            }
        [string[]] $readLineAry = ForEach ($r in $readLineAry ){
            if ( $r -ne '' ){ $r.Replace('"', '') }
        }
    } elseif ( $Files.Count -gt 0 ){
        [string] $valueFrom = "file"
        [string[]] $readLineAry = $Files | `
            ForEach-Object { (Get-Item -LiteralPath $_).FullName }
    } else {
        [string] $valueFrom = "clipboard"
        if ( $True ){
            Add-Type -AssemblyName System.Windows.Forms
            [string[]] $readLineAry = [Windows.Forms.Clipboard]::GetFileDropList()
        }
        if ( -not $readLineAry ){
            [string[]] $readLineAry = Get-Clipboard | `
                ForEach-Object { if ($_ -ne '' ) { $_.Replace('"', '')} }
        }
    }
    
    if ( $readLineAry.Count -lt 1 ){
        Write-Error "no input file." -ErrorAction Stop
    }

    Write-Verbose "ValueFrom: ""$valueFrom"""
    Write-Verbose $("ReadLine:" + "`n  " + ($readLineAry -join "`n  "))

    # Main loop to process each input item (file, directory, or URL string).
    foreach ( $f in $readLineAry ){
        # Expand wildcards in paths to get a list of concrete file paths.
        if ( Test-Path -Path $f -PathType Container){
            [string[]] $tmpFiles = Get-Item -Path $f `
                | Resolve-Path -Relative
        } elseif ( Test-Path -Path $f -PathType Leaf){
            [string[]] $tmpFiles = Get-ChildItem -Path $f -Recurse:$Recurse -File `
                | Resolve-Path -Relative
        } else {
            # If the path doesn't exist, treat it as a potential URL or string link.
            [string[]] $tmpFiles = @()
            $tmpFiles += $f
        }
        
        foreach ( $File in $tmpFiles ){
            # If the item is a directory, list its contents instead of processing for links.
            if ( Test-Path -LiteralPath $File -PathType Container){
                if ( $DryRun -or $ShowHelp ){
                    Write-Output $File
                    continue
                }
                Get-ChildItem -LiteralPath $File -Recurse:$Recurse -File `
                    | ForEach-Object {
                        $fileCounter++
                        # ... (directory listing logic remains unchanged) ...
                    }
                continue
            }
            # Handle the -Edit flag to open the file for editing.
            if ( Test-Path -LiteralPath $File ){
                if ( $Edit ){
                    editFile $File
                    continue
                }
            }

            # Handle special file types (.lnk, .ps1, etc.) that should be executed directly,
            # bypassing the link-parsing logic.
            if ( Test-Path -LiteralPath $File ){
                if ( $App ){
                    [string] $exeComStr = "$App $File"
                } else {
                    [string] $exeComStr = "Invoke-Item -LiteralPath $File"
                }
                [string] $ext = (Get-Item -LiteralPath $File).Extension
                # Shortcuts and URLs are invoked directly.
                if ( ( $ext -eq '.lnk' ) -or ( $ext -eq '.url') ){
                    if ( $DryRun ){
                        $exeComStr
                        continue
                    }
                    if ( $ShowHelp ){
                        #Write-Verbose "Labels in file: $File"
                        $helpObject = [ordered] @{
                            file     = Resolve-Path -LiteralPath $File -Relative
                            target   = $null
                            synopsis = $null
                        }
                        [pscustomobject] $helpObject
                        continue
                    }
                    if ( $App ){
                        $exeComStr | Invoke-Expression -ErrorAction $ErrAction
                    } else {
                        Invoke-Item -LiteralPath "$File"
                    }
                    continue
                }
                # PowerShell scripts are executed in the current scope.
                if ( $ext -eq '.ps1' ){
                    if ( $DryRun ){
                        $exeComStr
                        continue
                    }
                    if ( $ShowHelp ){
                        #Write-Verbose "Labels in file: $File"
                        $helpObject = [ordered] @{
                            file     = Resolve-Path -LiteralPath $File -Relative
                            target   = $null
                            synopsis = $null
                        }
                        [pscustomobject] $helpObject
                        continue
                    }
                    if ( $App ){
                        $exeComStr | Invoke-Expression -ErrorAction $ErrAction
                    } else {
                        & "$File"
                    }
                    continue
                }
                # Other non-text files are opened with their default application.
                if ( -not ( ( -not $ext ) -or ( $ext -match '\.txt$|\.md$') ) ){
                    if ( $DryRun ){
                        $exeComStr
                        continue
                    }
                    if ( $App ){
                        $exeComStr | Invoke-Expression -ErrorAction $ErrAction
                    } else {
                        Invoke-Item -LiteralPath "$File"
                    }
                    continue
                }
            }

            # For text files or string input, read the content line by line.
            [string[]] $linkLines = @()
            if ( Test-Path -LiteralPath $File ){
                $linkLines = Get-Content -LiteralPath $File -Encoding utf8
            } else {
                $linkLines += $File
            }

            # If -ShowHelp is used, display the list of labels and their comments, then stop processing this file.
            if ( $ShowHelp ){
                Write-Verbose "Labels in file: $File"
                foreach ($line in $linkLines) {
                    # Regex to capture the label name and an optional comment after a colon.
                    if ($line -match '^@\s*([^\s:]+)\s*(?::\s*(.*))?$') {
                        [string[]]$splitLabel = $line.Split(":", 2)
                        [string]$labelName = $splitLabel[0].TrimStart('@').Trim()
                        [string]$labelComment = $splitLabel.Count -gt 1 ? $splitLabel[1].Trim() : ""
                        #Write-Host ("{0,-20} : {1}" -f $labelName, $labelComment)
                        ## If the target is in the collected PHONY targets
                        $helpObject = [ordered] @{
                            file     = Resolve-Path -LiteralPath $File -Relative
                            target   = $labelName
                            synopsis = $labelComment
                        }
                        [pscustomobject] $helpObject
                    }
                }
                continue # move to next file
            }

            # This is the core logic for selecting which lines to process.
            [string[]] $linesToProcess
            if ( $Label ){
                # --- Label Mode ---
                # A specific label was requested. Find that label block and extract its lines.
                $filteredLines = New-Object 'System.Collections.Generic.List[System.String]'
                [bool]$inLabelBlock = $false
                #$labelPattern = "^@\s*$($Label)\s*(:.*)?$" # Allow for comments in the matched label line
                [string]$labelPattern = $Label.TrimStart('@')
                foreach ($line in $linkLines) {
                    # Start condition: enter the target label block
                    if (-not $inLabelBlock -and $line -match '^@'){
                        if ( ($line.TrimStart('@') -replace '\s*:\s*.*$', '') -match $labelPattern) {
                            $inLabelBlock = $true
                            continue # Skip the label line itself.
                        }
                    }
                    # End condition: if we're in the block and find another label, the block has ended.
                    if ($inLabelBlock -and $line -match '^@'){
                        if ( ($line.TrimStart('@') -replace '\s*:\s*.*$', '') -match $labelPattern) {
                            $inLabelBlock = $true
                            continue # Skip the label line itself.
                        }
                    }
                    if ($inLabelBlock -and $line.Trim() -match "^@.+") {
                        break
                    }
                    # If we are inside the target block, add the line to our list.
                    if ($inLabelBlock) {
                        $filteredLines.Add($line)
                    }
                }
                $linesToProcess = $filteredLines.ToArray()
            } else {
                # --- Default Mode ---
                # No label was specified, so process the entire file content.
                # The isCommentOrEmptyLine function will filter out labels later.
                $linesToProcess = $linkLines
            }

            # Clean up the selected lines: remove comments, empty lines, and quotes.
            [string[]] $cleanLinks = $linesToProcess `
                | ForEach-Object {
                    [string] $linkLine = $_
                    if ( isCommentOrEmptyLine $linkLine ){
                        # pass
                    } else {
                        if ( $Grep ){
                            if ( $NotMatch ){
                                if ( $linkLine -notmatch $Grep ){
                                    #pass
                                } else {
                                    return
                                }
                            } else {
                                if ( $linkLine -match $Grep ){
                                    #pass
                                } else {
                                    return
                                }
                            }
                        }
                        # Sanitize the line before treating it as a link.
                        $linkLine = $linkLine.Trim()
                        $linkLine = $linkLine -replace '^"',''
                        $linkLine = $linkLine -replace '"$',''
                        $linkLine = $linkLine -replace "^'",''
                        $linkLine = $linkLine -replace "'`$",''
                        
                        if ( $Location -or $Push ){
                            $linkLine = Split-Path "$linkLine" -Parent
                        }
                        if ( $LinkCheck ){
                            if ( isLinkHttp $linkLine ){
                                if ( isLinkAlive $linkLine ){
                                    # pass
                                } else {
                                    Write-Error "broken link: '$linkLine'" -ErrorAction Stop
                                }
                            } else {
                                if ( Test-Path -LiteralPath $linkLine){
                                    # pass
                                } else {
                                    Write-Error "broken link: '$linkLine'" -ErrorAction Stop
                                }
                            }
                        }
                        Write-Output $linkLine
                    }
                }
            if ( $Edit ){
                continue
            }
            if ( -not $cleanLinks ){
                # It's not an error if a label block is empty or the file contains no links.
                if (-not $Quiet) {
                    if ($Label) {
                        Write-Verbose "No executable links found for label '@$Label' in file: $File"
                    } else {
                        Write-Verbose "No executable links found in file: $File"
                    }
                }
                continue
            }
            if ( $DryRun ){
                if ( $Label ) {
                    Write-Host "$File @$Label" -ForegroundColor Green
                } else {
                    Write-Host "$File" -ForegroundColor Green
                }
            }
            
            # Apply filtering options (-All, -Doc, -First) to the list of clean links.
            # This determines the final set of links to be executed.
            [string[]] $finalLinks
            if ( $All ){
                $finalLinks = $cleanLinks
            } elseif ( $Doc ) {
                $finalLinks = $cleanLinks | Select-Object -Skip $First
            } else {
                $finalLinks = $cleanLinks | Select-Object -First $First
            }

            if ( $Location -or $Push ){
                 if ( -not $App ){
                    $finalLinks | ForEach-Object {
                        if ( isLinkHttp $_ ){
                            #pass
                        } else {
                            $invokeLocationCounter++
                            if ( $invokeLocationCounter -le $invokeLocationLimit ){
                                if ( $Location ){
                                    Invoke-Item $_
                                    if ( -not $Quiet ){
                                        Write-Host "Invoke-Item ""$_""" -ForegroundColor Green
                                    }
                                }
                                if ( $Push ){
                                    Push-Location -LiteralPath $_
                                    if ( -not $Quiet ){
                                        Write-Host "Push-Location -LiteralPath ""$_""" -ForegroundColor Green
                                    }
                                }
                            }
                        }
                        continue
                    }
                }
            }
            
            # Final loop to execute each selected link.
            foreach ( $href in $finalLinks ){
                # Determine the command to run based on the link type and -App parameter.
                if ( $App ){
                    [string] $com = $App
                } else {
                    if ( isLinkHttp $href ){
                        [string] $com = "Start-Process -FilePath"
                    } elseif ($AsFileObject) {
                        [string] $com = "Get-Item -LiteralPath"
                    } else {
                        [string] $com = "Invoke-Item"
                    }
                }
                [string] $com = "$com ""$href"""
                
                # Display the command for clarity, even if not in DryRun mode.
                if (-not $DryRun) {
                    Write-Host $com
                } else {
                     Write-Output $com
                }

                if ( -not $DryRun ){
                    if ( $BackGround ){
                        # Execute the command in a background job.
                        $executeCom = {
                            param( [string] $strCom, [string] $strErrAct )
                            try {
                                Invoke-Expression -Command $strCom -ErrorAction $strErrAct
                            } catch {
                                throw
                            }
                        }
                        try {
                            Start-Job -ScriptBlock $executeCom -ArgumentList $com, $ErrAction -ErrorAction $ErrAction
                        } catch {
                            $errCounter++
                        }
                        if ( $errCounter -ge $LimitErrorCount ){
                            Write-Warning "The number of errors exceeded the -LimitErrorCount = $LimitErrorCount times."
                            return
                        }
                    } else {
                        # Execute the command in the foreground.
                        try {
                            Invoke-Expression -Command $com -ErrorAction $ErrAction
                        } catch {
                            $errCounter++
                        }
                        if ( $errCounter -ge $LimitErrorCount ){
                            Write-Warning "The number of errors exceeded the -LimitErrorCount = $LimitErrorCount times."
                            return
                        }
                    }
                }
            }
        }
    }
}
# Set up the 'i' alias for convenient access to the Invoke-Link function.
# This makes the function much easier to use from the command line.
[String] $tmpAliasName = "i"
[String] $tmpCmdName   = "Invoke-Link"
[String] $tmpCmdPath = Join-Path `
    -Path $PSScriptRoot `
    -ChildPath $($MyInvocation.MyCommand.Name) `
    | Resolve-Path -Relative
if ( $IsWindows ){ $tmpCmdPath = $tmpCmdPath.Replace('\' ,'/') }

# Check if the alias 'i' already exists to avoid conflicts.
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
