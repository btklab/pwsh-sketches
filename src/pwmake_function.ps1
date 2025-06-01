<#
.SYNOPSIS
    pwmake - PowerShell implementation of GNU make command

    Reads and executes a Makefile in the current directory or a specified path.

    Usage:
        - man2 pwmake
        - pwmake (finds and executes Makefile in the current directory)
        - pwmake -FilePath path/to/Makefile (specifies external Makefile path)
        - pwmake -ShowHelp (gets help comment written at the end of each target line)
        - pwmake -DryRun
        - pwmake -Parameter "hoge"
        - pwmake -Parameters "hoge", "fuga"

    Makefile minimal examples:

        ```Makefile
        all: ## do nothing
            echo "hoge"
        ```Makefile
        file := index.md

        .PHONY: all
        all: ${file} ## echo filename
            echo ${file}
            # $param is predefined [string] variable
            echo $param
            # $params is also predefined [string[]] variable
            echo $params
            echo $params[0]
        ```

    Execution examples:

        ```powershell
        pwmake
        pwmake -FilePath ./path/to/the/Makefile
        pwmake -ShowHelp
        pwmake -DryRun
        pwmake -Parameter "hoge"             # set predefined variable string
        pwmake -Parameters "hoge", "fuga"    # set predefined variable string array
        pwmake -Variables "file=main.md" # override variable
        ```

    Note:
        Only the following automatic variables are implemented:
            - $PSScriptRoot : Makefile directory path
            - $@ : Target file name
            - $< : The name of the first dependent file
            - $^ : Names of all dependent files
            - %.ext : Replace with a string with the extension removed
                  from the target name. Only target line can be used.

        ```Makefile
        # '%' example:
        %.tex: %.md
            cat $< | md2html > $@
        ```Makefile
        root := $PSScriptRoot/args
        all:
            echo $PSScriptRoot
            echo $PSScriptRoot/hoge
            echo ${root}
        ```

    Detail:
        - Makefile format roughly follows GNU make
            - but spaces at the beginning of the line are
              accepted with Tab or Space
            - to define variables, use ${} instead of $()
            - if @() is used, it is interpreted as a Subexpression
              operator (described later)
        - If no target is specified in args, the first target is executed.
        - Since it operates in the current process, dot sourcing functions
          read in current process can also be described in Makefile.
        - If the file path specified in Makefile is not an absolute
          path, it is regarded as a relative path.
        - [-n|-DryRun] switch available.
            - [-toposort] switch show Makefile dependencies.
        - Comment with "#"
            - only the target line and Variable declaration line (a line
              that does not start with a blank space) can be commented
              at the end of the line.
                - comment at the end of command line is unavailable, but
                  using the "-DeleteCommentEndOfCommandLine" switch forces
                  delete comment from the "#" sign to the end of the line.
            - end-of-line comment not allowed in command line.
            - do not comment out if the rightmost character of the comment
              line is double-quote or single-quote. for example, following
              command interpreted as "#" in a strings.
                - "# this is not a comment"
            - but also following is not considered a comment. this is
              unexpected result.
                - key = val ## note grep "hoge"
            - Any line starting with whitespaces and "#" is treated as a
              comment line regardless of the rightmost character.
            - The root directory of the relative path written in the Makefile is
              where the pwmake command was executed.
            - "-f <file>" reads external Makefile.
                - the root directory of relative path in the external Makefile
                  is the Makefile path.

        Comment out example:

            home := $($HOME) ## comment

            target: deps  ## comment
                command |
                    sed 's;^#;;' |
                    # grep -v 'hoge' | <-- allowed comment out
                    grep -v 'hoge' | ## notice!!  <-- not allowed (use -DeleteCommentEndOfCommandLine)
                    > a.md

    Tips:
        If you put "## comment..." at the end of each target line
        in Makefile, you can get the comment as help message for
        each target with pwmake -ShowHelp [-f MakefilePath]

            ```Makefile
            target: [dep dep ...] ## this is help message
            ```

            ```powershell
            PS> pwmake -ShowHelp
            ##
            ## target synopsis
            ## ------ --------
            ## help   help message
            ## new    create directory and set skeleton files
            ```

    Note:
        - Variables can be declared between the first line and the line
          containing colon ":"
        - Lines containing a colon ":" are considered target lines, and
          all other lines that beginning with whitespaces are command lines.
        - Do not include spaces in file path and target names.
        - Command lines are preceded by one or more spaces or tabs.
        - If "@" is added to the beginning of the command line, the command
          line will not be echoed to the output.
        - Use ${var} when using the declared variables. Do not use @(var).
        - but $(powershell-command) can be used for the value to be
          assigned to the variable. for example,
            - DATE := $((Get-Date).ToString('yyyy-MM-dd'))
                - assigns with expands the right side
            - DATE := ${(Get-Date).ToString('yyyy-MM-dd')}
                - assigns without expanding the right side
            - DATE  = $((Get-Date).ToString('yyyy-MM-dd'))
                - assigns without expanding the right side
            - DATE  = ${(Get-Date).ToString('yyyy-MM-dd')}
                - assigns without expanding the right side
            - Note: except for the first example, variables are expanded at runtime.
        - Only one shell-command is accepted per line when assigning variables
        - Shell variable assignment foo := $(Get-Date).ToString('yyyy-MM-dd')
            - executes the shell before assigning to the variable and store it in
              the variable.
            - executes the shell when it is used by assigning it as an expression.
            - if a variable assigned with "=" is assigned to another variable,
              the expression is assigned to that variable with either "=" or ":=".
        - If there is no particular reason, it may be easier to understand variables
          by immediately evaluating them with ":=", such as vat := str, var = $(),
          and then assigning them.
        - Variables that are evaluated when used, such as var = $(), can behave in
          unexpected ways unless you understand them well.
        - Shell variable assignment foo := Get-Date assigns as a simple strings.
          If the character string on the right side can be interpreted as a
          powershell command, it may be executed when used line foo = $(Get-Command).
          However, it is safer to wrap powershell commands in $().

        - The linefeed escape character is following:
            - backslash
            - backquote
            - pipeline (vertical bar)

    references:

        - https://www.gnu.org/software/make/
        - https://www.oreilly.co.jp/books/4873112699/

.LINK
    toposort, pwmake

.EXAMPLE
    # Makefile example1: simple Makefile

    ```Makefile
    .PHONY: all
    all: hoge.txt

    hoge.txt: log.txt
        1..10 | grep 10 >> hoge.txt

    log.txt:
        (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') | sed 's;2022;2000;' | md2html >> log.txt
    ```

.EXAMPLE
    # Get help of each task and DryRun Makefile
    PS > cat Makefile

    ```Makefile
    # use uplatex
    file    := a
    texfile := ${file}.tex
    dvifile := ${file}.dvi
    pdffile := ${file}.pdf
    date    := $((Get-Date).ToString('yyyy-MM-dd (ddd) HH:mm:ss'))

    .PHONY: all
    all: ${pdffile} ## Generate pdf file and open.
        @echo ${date}

    ${pdffile}: ${dvifile} ## Generate pdf file from dvi file.
        dvipdfmx -o $@ $<

    ${dvifile}: ${texfile} ## Generate dvi file from tex file.
        uplatex $<
        uplatex $<

    .PHONY: clean
    clean: ## Remove cache files.
        Remove-Item -Path *.aux,*.dvi,*.log -Force
    ```

    # Get help of each task
    PS > pwmake -FilePath Makefile -ShowHelp
    PS > pwmake -ShowHelp

    target synopsis
    ------ --------
    all    Generate pdf file and open.
    a.pdf  Generate pdf file from dvi file.
    a.dvi  Generate dvi file from tex file.
    clean  Remove cache files.

    # DryRun
    PS > pwmake -DryRun
    ######## override args ##########
    None

    ######## argblock ##########
    file=a
    texfile=a.tex
    dvifile=a.dvi
    pdffile=a.pdf
    date=2023-01-15 (Sun) 10:26:09

    ######## phonies ##########
    all
    clean

    ######## comBlock ##########
    all: a.pdf
     @echo 2023-01-15 (Sun) 10:26:09

    a.pdf: a.dvi
     dvipdfmx -o $@ $<

    a.dvi: a.tex
     uplatex $<
     uplatex $<

    clean:
     Remove-Item -Path *.aux,*.dvi,*.log -Force

    ######## topological sorted target lines ##########
    a.tex
    a.dvi
    a.pdf
    all

    ######## topological sorted command lines ##########
    uplatex a.tex
    uplatex a.tex
    dvipdfmx -o a.pdf a.dvi
    @echo 2023-01-15 (Sun) 10:26:09

    ######## execute commands ##########
    uplatex a.tex
    uplatex a.tex
    dvipdfmx -o a.pdf a.dvi
    @echo 2023-01-15 (Sun) 10:26:09


    # Processing stops when a run-time error occurs
    PS > pwmake
    > uplatex a.tex
    pwmake: The term 'uplatex' is not recognized as a name of a cmdlet, function, script file, or executable program.
    Check the spelling of the name, or if a path was included, verify that the path is correct and try again.

.EXAMPLE
    # use predefined vaiable: $PSScriptRoot
    # This gets the parent folder path of the Make file.
    PS > cat Makefile

    ```Makefile
    root := $PSScriptRoot/args
    all:
        echo $PSScriptRoot
        echo $PSScriptRoot/hoge
        echo ${root}
    ```

    PS> pwmake -FilePath ./Makefile
        C:/Users/btklab/cms/
        C:/Users/btklab/cms/hoge
        C:/Users/btklab/cms/args

.EXAMPLE
    # clone posh-source to posh-mocks
    PS > cat Makefile

    ```Makefile
    home := $($HOME)
    pwshdir  := ${home}\cms\bin\pwsh
    poshmock := ${home}\cms\bin\pwsh-sketches

    .PHONY: all
    all: pwsh ## update all

    .PHONY: pwsh
    pwsh: ${pwshdir} ${poshmock} ## update pwsh scripts
    @Push-Location -LiteralPath "${pwshdir}\"
    Copy-Item -Destination "${poshmock}" -LiteralPath ./README.md, \
        ./CHANGELOG.md, \
        ./.gitignore, \
        ./examples.md
    Set-Location -LiteralPath "src"
    Copy-Item -Destination "${poshmock}\src\" -LiteralPath ./man2_function.ps1, \
        ./self_function.ps1, \
        ./delf_function.ps1, \
        ./sm2_function.ps1, \
        ./man2_function.ps1
    @Pop-Location
    @if ( -not (Test-Path -LiteralPath "${pwshdir}\img\") ) { \
        Write-Error "src is not exists: ""${pwshdir}\img\""" -ErrorAction Stop \
    }
    @if ( -not (Test-Path -LiteralPath "${poshmock}\img\") ) { \
        Write-Error "dst is not exists: ""${poshmock}\img\""" -ErrorAction Stop \
    }
    # mirror dirs
    Robocopy "${pwshdir}\img\" "${poshmock}\img\" /MIR /XA:SH /R:0 /W:1 /COPY:DAT /DCOPY:DAT /UNILOG:NUL /TEE
    Robocopy "${pwshdir}\examples\" "${poshmock}\examples\" /MIR /XA:SH /R:0 /W:1 /COPY:DAT /DCOPY:DAT /UNILOG:NUL /TEE
    Robocopy "${pwshdir}\.github\" "${poshmock}\.github\" /MIR /XA:SH /R:0 /W:1 /COPY:DAT /DCOPY:DAT /UNILOG:NUL /TEE
    Robocopy "${pwshdir}\tests\" "${poshmock}\tests\" /MIR /XA:SH /R:0 /W:1 /COPY:DAT /DCOPY:DAT /UNILOG:NUL /TEE
    ```

.EXAMPLE
    # Rename extension of script files and Zip archive
    PS > pwmake -FilePath ~/Documents/Makefile -ShowHelp

    target synopsis
    ------ --------
    all    Add ".txt" to the extension of the script file and Zip archive
    clean  Remove "*.txt" items in Documents directory

    # Show Makefile
    PS > cat ~/Documents/Makefile
    documentdir := ~/Documents

    .PHONY: all
    all: ## Add ".txt" to the extension of the script file and Zip archive
        ls -Path ${documentdir}/*.ps1, \
            ${documentdir}/*.py, \
            ${documentdir}/*.R, \
            ${documentdir}/*.yaml, \
            ${documentdir}/*.Makefile, \
            ${documentdir}/*.md, \
            ${documentdir}/*.Rmd, \
            ${documentdir}/*.qmd, \
            ${documentdir}/*.bat, \
            ${documentdir}/*.cmd, \
            ${documentdir}/*.vbs, \
            ${documentdir}/*.js, \
            ${documentdir}/*.vimrc, \
            ${documentdir}/*.gvimrc |
            ForEach-Object { \
                Write-Host "Rename: $($_.Name) -> $($_.Name).txt" \
                $_ | Rename-Item -NewName {$_.Name -replace '$', '.txt' } \
            }
        Compress-Archive -Path ${documentdir}/*.txt -DestinationPath ${documentdir}/a.zip -Update

    .PHONY: clean
    clean: ## Remove "*.txt" items in Documents directory
        ls -Path "${documentdir}/*.txt" |
            ForEach-Object { \
                Write-Host "Remove: $($_.Name)" \
                Remove-Item -LiteralPath $_.FullName \
            }

#>
function pwmake {
    Param(
        [Parameter(Position=0, Mandatory=$False)]
        [Alias('t')]
        [string] $TargetName,

        [Parameter(Position=1, Mandatory=$False)]
        [Alias('v')]
        [string[]] $VariablesToOverride,

        [Parameter(Mandatory=$False)]
        [Alias('f')]
        [string] $FilePath = "Makefile",

        [Parameter(Mandatory=$False)]
        [Alias('d')]
        [string] $DependencyDelimiter = " ",

        [Parameter(Mandatory=$False)]
        [Alias('td')]
        [string] $TargetDependencySeparator = ":",

        [Parameter(Mandatory=$False)]
        [ValidateSet("stop","silentlyContinue")]
        [string] $ErrorActionPreference = "stop",

        [Parameter(Mandatory=$False)]
        [switch] $ShowHelp,

        [Parameter(Mandatory=$False)]
        [switch] $DeleteCommandComments,

        [Parameter(Mandatory=$False)]
        [string] $SingleParameter,

        [Parameter(Mandatory=$False)]
        [string[]] $MultipleParameters,

        [Parameter(Mandatory=$False)]
        [string] $ScriptRootPath,

        [Parameter(Mandatory=$False)]
        [Alias('p')]
        [switch] $PushPopLocation,

        [Parameter(Mandatory=$False)]
        [Alias('n')]
        [switch] $DryRunMode
    )

    ## Function to parse help messages from the Makefile.
    ## It extracts target names and their synopsis comments.
    function ParseMakefileHelp ([string[]] $argumentBlock) {
        if ($argumentBlock){
            $variableDictionary = @{}
            foreach ($variable in $argumentBlock) {
                ## Get arguments and add to dictionary (key, val)
                $key, $value = GetArgumentVariable "$variable" $variableDictionary
                if($variableDictionary){
                    foreach ($k in $variableDictionary.Keys){
                        ## Replace variables
                        [string]$targetVariable = '${' + $k + '}'
                        [string]$replaceVariable = $variableDictionary[$k]
                        $value = $value.Replace($targetVariable, $replaceVariable)
                    }
                }
                $variableDictionary.Add($key, $value)
                #Write-Output "$key=$value"
            }
        }
        Select-String '^[a-zA-Z0-9_\-\{\}\$\.\ ]+?:' -Path $FilePath -Raw `
            | ForEach-Object {
                $helpString = [string]$_
                if ($helpString -match ':='){
                    ## Skip variable definition line
                    return
                } elseif ($helpString -match '^\.phony'){
                    ## Skip phony definition line
                    return
                } elseif ($helpString -match ' ## '){
                    $helpString = $helpString -replace ':.*? ## ', ' ## '
                } else {
                    $helpString = $helpString -replace ':.*$', ''
                }
                if ($argumentBlock){
                    ## Replace variables
                    foreach ($k in $variableDictionary.Keys){
                        [string]$before = '${' + $k + '}'
                        [string]$after = $variableDictionary[$k]
                        $helpString = $helpString.Replace($before, $after)
                    }
                }
                $helpString
                } `
            | ForEach-Object {
                $helpArray = $_.split(' ## ', 2)
                return [pscustomobject]@{
                    target = $helpArray[0]
                    synopsis = $helpArray[1]}
            }
    }

    ## Initialize variables
    $phonyTargets = @{}
    [string] $currentMakefile = $FilePath
    ## Test if Makefile exists
    $isMakefileExist = Test-Path -LiteralPath $currentMakefile
    if( -not $isMakefileExist){
        Write-Error "Could not find ""$currentMakefile""" -ErrorAction Stop
    }
    [string] $makefileDirectory = Resolve-Path -LiteralPath "$currentMakefile" | Split-Path -Parent
    [string] $makefileDirectory = $makefileDirectory.Replace('\', '/')

    ## Private function: Adds an end-of-file mark and includes other Makefiles.
    function AddEndOfFileMarkAndInclude ([string]$makefileToInclude){
        [string[]] $fileLines = @()
        [string] $parentDirectory = Split-Path "$makefileToInclude" -Parent
        [string[]] $fileLines = Get-Content -LiteralPath "$makefileToInclude" -Encoding utf8 `
            | ForEach-Object {
                $makefileLine = [string]$_
                if ($makefileLine -match '^include '){
                    ## Include other makefile
                    $makefileLine = $makefileLine -replace '^include ',''
                    $makefileLine = $makefileLine.trim()
                    [string[]]$fileListArray = $makefileLine -split ' '
                    foreach ($file in $fileListArray){
                        $filePath = Join-Path "$parentDirectory" "$file"
                        Get-Content -Path "$filePath" -Encoding utf8
                        Write-Output ''
                    }
                } else {
                    Write-Output "$makefileLine"
                }
            }
        return $fileLines
    }

    ## Private function: Deletes leading spaces based on flags and regex.
    function RemoveLeadingSpaces ([string]$lineContent, [bool]$isFirstCommandFlag, [regex]$regexPattern){
        if($regexPattern){
            $lineContent = $lineContent -replace $regexPattern, ''}
        if($isFirstCommandFlag){
            $lineContent = $lineContent -replace '^\s+',' '}
        else{
            $lineContent = $lineContent -replace '^\s+',''}
        return $lineContent
    }

    ## Private function: Removes line breaks based on escape characters.
    function ConsolidateLines ([string[]]$inputLines){
        [string] $previousLine = ''
        [string[]] $outputLines = $inputLines | ForEach-Object {
                [string] $currentLine = [string] $_
                if ( $currentLine -match ' \\$' ){
                    ## Backslash
                    $currentLine = $currentLine -replace '\s+\\$', "`n"
                    $previousLine = $previousLine + $currentLine
                } elseif ( $currentLine -match ' \`$' ){
                    ## Backquote
                    $currentLine = $currentLine -replace '\s+\`$', "`n"
                    $previousLine = $previousLine + $currentLine
                } elseif ( $currentLine -match ' \|$' ){
                    ## Pipe
                    $currentLine = $currentLine -replace '\s+\|$'," |`n"
                    $previousLine = $previousLine + $currentLine
                } else {
                    if($previousLine -ne ''){
                        $previousLine = $previousLine + $currentLine
                        Write-Output $previousLine
                        $previousLine = ''
                    }else{
                        Write-Output $currentLine
                    }
                }
            }
        if ( $previousLine -ne '' ){
            $previousLine = $previousLine -replace '\s*$',''
            [string[]] $outputLines += ,$previousLine
        }
        return $outputLines
    }

    ## Private function: Deletes comments from lines.
    function RemoveComments ([string[]]$inputLines){
        $outputLines = foreach ($line in $inputLines) {
            if($line -notmatch '^\s*#'){
                if($line -match '^\s+'){
                    ## Command line
                    if ( $DeleteCommandComments ){
                        if ( $line -notmatch '#' ){
                            # Does not contain "#"
                            # Pass
                        } else {
                            # Delete comment like: command # comment
                            $line = $line -replace '#.*$', ''
                        }
                    }
                }else{
                    ## Target: dependency line
                    $line = $line -replace '#.*[^"'']$', ''
                }
                $line = $line -replace ' *$', ''
                Write-Output $line
            }
        }
        return $outputLines
    }

    ## Private function: Separates lines into argument and command blocks.
    function SeparateBlocks ([string[]]$inputLines){
        [bool] $isArgumentBlock = $true
        [string[]] $argumentBlock = @()
        [string[]] $commandBlock = @()
        foreach ($line in $inputLines) {
            if ($line -match '.'){
                if ($line -notmatch '='){
                    $isArgumentBlock = $False
                }
            }
            if ($isArgumentBlock){
                if( ($line -ne '') -and ($line -match ':=') ){
                    $line = $line -replace '\s*:=\s*',':='
                    $argumentBlock += ,@($line)
                }elseif( ($line -ne '') -and ($line -match '=') ){
                    $line = $line -replace '\s*=\s*','='
                    $argumentBlock += ,@($line)
                }
            }else{
                $commandBlock += ,@($line)
            }
        }
        ## Add emptyline at the end of commandBlock for CreateTargetDictionary function
        $commandBlock += ,@('')
        return $argumentBlock, $commandBlock
    }

    ## Private function: Replaces variables with override values.
    function ApplyOverrideVariables ([string[]]$inputLines){
        ## Test and set variables in dictionary
        $variableDictionary = @{}
        foreach ($variable in $VariablesToOverride) {
            if($variable -notmatch '='){
                Write-Error "Use ""<name>=<val>"" when setting -Variables $variable" -ErrorAction Stop}
            $variableArray = $variable -split "=", 2
            $key = $variableArray[0].trim()
            $value = $variableArray[1].trim()
            $variableDictionary.Add($key, $value)
        }
        ## Replace variables in lines
        $outputLines = foreach ($line in $inputLines) {
            foreach ($key in $variableDictionary.Keys){
                ## Replace variable
                [string]$before = '${' + $key + '}'
                [string]$after = $variableDictionary[$key]
                $line = $line.Replace($before, $after)
            }
            Write-Output $line
        }
        return $outputLines
    }

    ## Private function: Gets key and value from an argument variable string.
    function GetArgumentVariable ([string]$variableString, $variableDictionary){
        ## Input -> var := str
        ## Input -> var := ${var}
        ## Input -> var := ${var}.png
        ## Input -> var := $(shell command)
        ## Return: key:var, val:hoge
        if ($variableString -match ':='){
            ## ':=' defines a simply-expanded variable
            $variableArray = $variableString -split ":=", 2
            [string]$key = $variableArray[0].trim()
            [string]$value = $variableArray[1].trim()
            if ( $key -match '^[Pp]aram$'){
                Write-Error 'Variable name: "Param" is predefined. Please use another keyword.' -ErrorAction Stop
            }
            if ( $key -match '^[Pp]arams$'){
                Write-Error 'Variable name: "Params" is predefined. Please use another keyword.' -ErrorAction Stop
            }
            if ( $key -match '^PSScriptRoot$'){
                Write-Error 'Variable name: "PSScriptRoot" is predefined. Please use another keyword.' -ErrorAction Stop
            }
            ## Replace ${var}
            if ($value -match '\$\{'){
                if($variableDictionary){
                    foreach ($k in $variableDictionary.Keys){
                        ## Replace variables
                        [string]$before = '${' + $k + '}'
                        [string]$after = $variableDictionary[$k]
                        $value = $value.Replace($before, $after)
                    }
                }
            }
            ## Execute shell command
            if ($value -match '\$\(..*\)'){
               ## If $value contains $(command)
               ##     execute $value as shell command before variable assignment
               [string]$before = $value -replace '^.*(\$\(..*\)).*$', '$1'
               [string]$after = Invoke-Expression "$before"
               [string]$value = $value.Replace($before, $after)
            }
        } else {
            ## '=' defines a recursively-expanded variable
            $variableArray = $variableString -split "=", 2
            [string]$key = $variableArray[0].trim()
            [string]$value = $variableArray[1].trim()
            if ( $key -match '^[Pp]aram$'){
                Write-Error 'Variable name: "Param" is predefined. Please use another keyword.' -ErrorAction Stop
            }
            if ( $key -match '^[Pp]arams$'){
                Write-Error 'Variable name: "Params" is predefined. Please use another keyword.' -ErrorAction Stop
            }
            if ( $key -match '^PSScriptRoot$'){
                Write-Error 'Variable name: "PSScriptRoot" is predefined. Please use another keyword.' -ErrorAction Stop
            }
            #$value = '$(' + $value + ')'
        }
        ## Replace predefined variable
        $value = $value.Replace('${PSScriptRoot}', $makefileDirectory)
        $value = $value.Replace('{$PSScriptRoot}', $makefileDirectory)
        $value = $value.Replace('$PSScriptRoot', $makefileDirectory)
        return $key, $value
    }

    ## Private function: Replaces variables in the argument block.
    function ProcessArgumentBlock ([string[]]$argumentBlock){
        $variableDictionary = @{}
        ## Replace variables in argumentBlock
        $processedArgumentBlock = foreach ($variable in $argumentBlock) {
            ## Get key, value
            $key, $value = GetArgumentVariable "$variable" $variableDictionary
            if($variableDictionary){
                foreach ($k in $variableDictionary.Keys){
                    ## Replace variables
                    [string]$before = '${' + $k + '}'
                    [string]$after = $variableDictionary[$k]
                    $value = $value.Replace($before, $after)
                }
            }
            $variableDictionary.Add($key, $value)
            Write-Output "$key=$value"
        }
        return $processedArgumentBlock
    }

    ## Private function: Replaces variables in the command block.
    function ProcessCommandBlock ([string[]]$argumentBlock, [string[]]$commandBlock){
        $variableDictionary = @{}
        ## Set replace-dictionary
        foreach ($variable in $argumentBlock) {
            $variableArray = $variable -split "=", 2
            $key = $variableArray[0].trim()
            $value = $variableArray[1].trim()
            $variableDictionary.Add($key, $value)
        }
        $processedCommandBlock = foreach ($line in $commandBlock) {
            foreach ($key in $variableDictionary.Keys){
                [string]$before = '${' + $key + '}'
                [string]$after = $variableDictionary[$key]
                $line = $line.Replace($before, $after)
            }
            Write-Output $line
        }
        return $processedCommandBlock
    }

    ## Private function: Collects phony targets from the command block.
    function ExtractPhonyTargets ([string[]]$commandBlock){
        [string[]]$extractedPhonies = @()
        $processedCommandBlock = foreach ($line in $commandBlock) {
            if ($line -match '^\.PHONY:'){
                $line = $line -replace '^\.PHONY:\s*'
                $temporaryPhonies = $line -split $DependencyDelimiter
                foreach ($phony in $temporaryPhonies){
                    $extractedPhonies += $phony
                }
            } else {
                Write-Output $line
            }
        }
        return $processedCommandBlock, $extractedPhonies
    }

    ## Private function: Creates dictionaries for targets, commands, and dependencies.
    function CreateTargetDictionaries ([string[]]$commandBlock){
        $commandDictionary    = @{}
        $targetDependencyDictionary = @{}
        [bool]$isFirstTargetEncountered = $true
        [string[]]$targetLineArray = @()
        [string[]]$commandArray = @()
        [string[]]$dependencyArray = @()
        foreach ($line in $commandBlock) {
            if ($line -eq ''){
                if($isFirstTargetEncountered){
                    Write-Error "Wrong start line" -ErrorAction Stop}
                ## Output dictionary
                $commandDictionary.Add($targetName, $commandArray)
                [string[]]$commandArray = @()
            } else {
                if($line -match '^[^\s+].*:'){
                    ## Target: dependency line
                    $targetLineArray += ,@($line)
                    $targetName, $dependencies = $line -split ':', 2
                    $targetName = $targetName.trim()
                    $dependencies = $dependencies.trim()
                    $dependencyArray = $dependencies -split $DependencyDelimiter
                    $targetDependencyDictionary.Add($targetName, $dependencyArray)
                    if($isFirstTargetEncountered){
                        ## Get first target name
                        $isFirstTargetEncountered = $False
                        $firstTarget = $targetName
                    }
                } elseif ($line -match '^\s') {
                    ## Command line
                    $commandArray += ,@($line.trim())
                } else {
                    Write-Error "Unexpected line: $line" -ErrorAction Stop
                }
            }
        }
        return $targetLineArray, $commandDictionary, $targetDependencyDictionary, $firstTarget
    }

    ## Private function: Cleans the command block by adding empty lines.
    function CleanCommandBlock ([string[]]$inputArray){
        $isFirstLine = $true
        $outputArray = foreach ($line in $inputArray) {
            if ($line -ne ''){
                if ($isFirstLine){
                    ## First target line: output only input line
                    Write-Output $line
                    $isFirstLine = $False
                }elseif ($line -match '^[^\s].*:'){
                    ## Normal target line: output with emptyline
                    Write-Output ''
                    Write-Output $line
                }else{
                    ## Command line: output only input line
                    if($line -notmatch '^\s'){
                        Write-Error "Unexpected line: $line" -ErrorAction Stop
                    }
                    Write-Output $line
                }
            }
        }
        $outputArray += @('')
        return $outputArray
    }

    ## Private function: Checks if '%' is used correctly.
    function IsPercentPlaceholderUsedCorrectly ([string]$lineContent, [switch]$isTargetLine){
        if($isTargetLine){
            if ($lineContent -match '%\.'){ return $True }
        } else {
            if ($lineContent -match '\$%\.'){ return $True }
        }
        Write-Error "Use the symbol '%' with the extension: $lineContent" -ErrorAction Stop
        return $False

    }
    ## Private function: Replaces '%' with the target string.
    function ReplacePercentWithTarget ([string[]]$inputArray){
        ## Shortest remove right from dot in target string
        $replacementTarget = $TargetName -replace '\.[^.\\/]*$', ''
        $replacementTarget += '.'
        #Write-Debug $replacementTarget
        $outputArray = foreach ($line in $inputArray) {
            if ($line -match '%\.'){
                if ($line -match '^[^\s].*:'){
                    ## Target line: replace '%.' to target
                    $line = $line.Replace('%.',"$replacementTarget")
                    Write-Output $line
                }else{
                    Write-Output $line
                }
            }else{
                Write-Output $line
            }
        }
        return $outputArray
    }

    ## Private function: Gets dependency dictionary.
    function GetDependencyDictionary ([string[]]$targetLines){
        $dependencyDictionary = @{}
        $isFirstTargetFlag = $True
        foreach ($line in $targetLines) {
            $target, $dependencies = $line -split $TargetDependencySeparator, 2
            $target = $target.trim(); $dependencies = $dependencies.trim()
            if($dependencies -eq ''){
                $dependencyArray = @()
            } else {
                $dependencyArray = $dependencies -split $DependencyDelimiter
            }
            $dependencyDictionary.Add($target, $dependencyArray)
            if($isFirstTargetFlag){
                $isFirstTargetFlag = $False
                $firstTarget = $target
            }
        }
        return $dependencyDictionary
    }

    ## Private function: Checks if a target exists in dependencies.
    function DoesTargetExist ([string]$target, $dependencies){
        $targetFound = $False
        foreach ($key in $dependencies.Keys){
            if($key -eq $target){$targetFound = $True}
        }
        return $targetFound
    }

    ## Private function: Performs Tarjan's topological sort.
    function PerformTopologicalSort ([string]$target, $dependencies, $markedNodes = @{}, $sortedNodes = @()){
        ## Tarjan's topological sort
        ## :arg dependencies: dict of ``(target, [list of dependencies])`` pairs
        if ($markedNodes[$target]){ return }
        $markedNodes[$target] = $True
        [string]$unifiedDependencies = $dependencies[$target] -Join $DependencyDelimiter
        if (DoesTargetExist $unifiedDependencies $dependencies){
            PerformTopologicalSort $unifiedDependencies $dependencies $markedNodes $sortedNodes
        } else {
            foreach ($member in $dependencies[$target]){
                PerformTopologicalSort $member $dependencies $markedNodes $sortedNodes
            }
        }
        $sortedNodes += $target
        return $sortedNodes
    }

    ## Private function: Checks if a target contains a phony.
    function DoesTargetContainPhony ( [string]$target, [string[]]$phonyList ){
        $targetArray = $target -split $DependencyDelimiter
        foreach ($individualTarget in $targetArray){
            foreach ($phony in $phonyList){
                if ($individualTarget -eq $phony){ return $True }
            }
        }
        return $False
    }

    ## Private function: Checks if a dependency contains a phony.
    function DoesDependencyContainPhony ( [string[]]$dependencyArray, [string[]]$phonyList ){
        foreach ($dependency in $dependencyArray){
            foreach ($phony in $phonyList){
                if ($dependency -eq $phony){ return $True }
            }
        }
        return $False
    }

    ## Private function: Checks if a target file does not exist.
    function IsTargetFileMissing ( [string]$target ){
        $targetArray = "$target" -split $DependencyDelimiter
        foreach ($individualTarget in $targetArray){
            if ( -not (Test-Path -LiteralPath "$individualTarget") ){ return $True }
        }
        return $False
    }

    ## Private function: Checks if a dependency file does not exist.
    function AreDependencyFilesMissing ( [string[]]$dependencies, [string[]]$phonyList ){
        $dependencyArray = $dependencies -split $DependencyDelimiter
        foreach ($dependency in $dependencyArray){
            if ( DoesTargetContainPhony $dependency $phonyList )   { return $True }
            if ( -not (Test-Path -LiteralPath "$dependency") ){ return $True }
        }
        return $False
    }

    ## Private function: Gets the last write time of files.
    function GetFileLastWriteTime ([string[]]$files, [string]$comparisonType = "older"){
        [datetime]$returnDate = (Get-Item -LiteralPath $files[0]).LastWriteTime
        foreach ($file in $files){
            [datetime]$temporaryDate = (Get-Item -LiteralPath "$file").LastWriteTime
            if ($comparisonType -eq 'older'){
                if ($temporaryDate -lt $returnDate){ $returnDate = $temporaryDate }
            }else{
                if ($temporaryDate -gt $returnDate){ $returnDate = $temporaryDate }
            }
        }
        return $returnDate
    }

    ## Private function: Checks if target file is older than dependency file.
    function IsTargetFileOlderThanDependency ([string]$target, [string[]]$dependencyArray){
        $targetArray = $target -split $DependencyDelimiter
        [datetime]$targetFileOldestDate = GetFileLastWriteTime $targetArray "older"
        [datetime]$dependencyFileNewestDate = GetFileLastWriteTime $dependencyArray "newer"
        Write-Debug "Target oldest: $($targetFileOldestDate.ToString('yyyy-MM-dd HH:mm:ss'))"
        Write-Debug "Dependency newest: $($dependencyFileNewestDate.ToString('yyyy-MM-dd HH:mm:ss'))"
        if ($targetFileOldestDate -lt $dependencyFileNewestDate){
            return $True
        } else {
            return $False
        }
    }

    ## Private function: Determines if a target should be executed.
    function ShouldTargetExecute ([string]$target, $targetDependencyDictionary, $phonyList){
        if ($targetDependencyDictionary[$target][0] -eq '') {
            $hasDependencies = $False
        } else {
            $hasDependencies = $True
        }
        if ( $hasDependencies -eq $False ){
            ## If target has no dependency
            if (DoesTargetContainPhony "$target" $phonyList){
                Write-Debug "Check: DoesTargetContainPhony: $target"
                return $True }
            if (IsTargetFileMissing "$target"){
                Write-Debug "Check: IsTargetFileMissing: $target"
                return $True }
            Write-Debug "Check: TargetFileExists: $target"
        } else {
            ## If target has dependencies
            ### Test targets
            if (DoesTargetContainPhony "$target" $phonyList){
                Write-Debug "Check: DoesTargetContainPhony: $target"
                return $True }
            if (IsTargetFileMissing "$target"){
                Write-Debug "Check: IsTargetFileMissing: $target"
                return $True }
            ## Test dependencies
            [string[]]$dependencyArray = $targetDependencyDictionary[$target]
            if (DoesDependencyContainPhony $dependencyArray $phonyList){
                Write-Debug "Check: DoesDependencyContainPhony: $($target): $($dependencyArray)"
                return $True }
            if (AreDependencyFilesMissing $dependencyArray $phonyList){
                Write-Debug "Check: AreDependencyFilesMissing: $($target): $($dependencyArray)"
                return $True }
            if (IsTargetFileOlderThanDependency "$target" $dependencyArray){
                Write-Debug "Check: IsTargetFileOlderThanDependency: $($target): $($dependencyArray)"
                return $True }
             Write-Debug "Check: TargetFileNewerThanDependency: $($target): $($dependencyArray)"
        }
        return $False
    }

    ## Private function: Checks if a target file does not exist.
    function IsTargetFileAbsent ([string]$target){
        $targetFileIsMissing = $False
        $targetArray = "$target" -split $DependencyDelimiter
        foreach ($file in $targetArray){
            if ( -not (Test-Path -LiteralPath $file)){
                $targetFileIsMissing = $True
            }
        }
        return $targetFileIsMissing
    }

    ## Private function: Replaces automatic variables in command lines.
    function ReplaceAutomaticVariables ([string]$commandLine, [string]$target, $targetDependencyDictionary){
        ## Replace automatic variables written in each command line
        ##     $@ : Target file name
        ##     $< : The name of the first dependent file
        ##     $^ : Names of all dependent file
        ##     %.ext : Replace with a string with the extension removed
        ##         from the target name. Only target line can be used.
        ##     $PSScriptRoot : Parent path of Makefile

        ## Set dependency line
        if ($targetDependencyDictionary[$target][0] -eq '') {
            $dependency = ''
        }else{
            $dependency = $targetDependencyDictionary[$target] -join "$DependencyDelimiter"
        }

        ## Set replace string
        [string]$autoVarTargetAll   = $target
        [string]$autoVarTargetFirst = ($target -split "$DependencyDelimiter")[0]
        [string]$autoVarDependencyAll   = $dependency
        [string]$autoVarDependencyFirst = ($dependency -split "$DependencyDelimiter")[0]

        ## Replace automatic variables
        $commandLine = $commandLine.Replace('$@',"$autoVarTargetFirst")
        $commandLine = $commandLine.Replace('$<',"$autoVarDependencyFirst")
        $commandLine = $commandLine.Replace('$^',"$autoVarDependencyAll")
        $commandLine = $commandLine.Replace('${PSScriptRoot}', $makefileDirectory)
        $commandLine = $commandLine.Replace('{$PSScriptRoot}', $makefileDirectory)
        $commandLine = $commandLine.Replace('$PSScriptRoot', $makefileDirectory)
        return $commandLine
    }

    ## Parse Makefile
    [string[]] $allLines    = @()
    [string[]] $argumentBlock = @()
    [string[]] $commandBlock = @()
    [string[]] $phonyList  = @()

    ### Preprocessing
    [string[]] $allLines = AddEndOfFileMarkAndInclude "$currentMakefile"
    [string[]] $allLines = RemoveComments $allLines
    [string[]] $allLines = ConsolidateLines $allLines

    ### Replace variables
    if($VariablesToOverride){
        [string[]] $allLines = ApplyOverrideVariables $allLines
    }
    $argumentBlock, $commandBlock = SeparateBlocks $allLines

    ### Replace '%' to target string
    $commandBlock = ReplacePercentWithTarget $commandBlock

    ## Show help
    if ($ShowHelp){
        if($argumentBlock){
            ParseMakefileHelp $argumentBlock
        } else {
            ParseMakefileHelp
        }
        return
    }

    ### Replace argument block
    if($argumentBlock){
        $argumentBlock = ProcessArgumentBlock $argumentBlock
        $commandBlock = ProcessCommandBlock $argumentBlock $commandBlock
    }

    ### Create phony list
    $commandBlock, $phonyList = ExtractPhonyTargets $commandBlock

    ### Cleaning commandBlock: add emptyline before target line
    $commandBlock = CleanCommandBlock $commandBlock

    ### Debug
    if($DryRunMode){
        Write-Output "######## OVERRIDE VARIABLES ##########"
        if($VariablesToOverride){$VariablesToOverride}else{"None"}
        Write-Output ''
        Write-Output "######## ARGUMENT BLOCK ##########"
        if($argumentBlock){$argumentBlock}else{"None"}
        Write-Output ''
        Write-Output "######## PHONY TARGETS ##########"
        if($phonyList){$phonyList}else{"None"}
        Write-Output ''
        Write-Output "######## COMMAND BLOCK ##########"
        $commandBlock
    }

    ## Command Block:
    ##   Data structure: (block separator -eq emptyline)
    ## ----------------------------
    ##    target: dependent,...
    ##        command1
    ##        command2
    ##
    ##    target: dependent,...
    ##        command1
    ##        command2
    ##

    ## Set dictionary
    $targetLineArray, $commandDictionary, $targetDependencyDictionary, $firstTarget = CreateTargetDictionaries $commandBlock

    ## Set target
    if($TargetName){
        [string] $currentTarget = $TargetName
    } else {
        [string] $currentTarget = $firstTarget
    }

    ## Is target exist?
    if ( -not $commandDictionary.ContainsKey($currentTarget) ){
        Write-Error "Target: $currentTarget is not exist in $currentMakefile" -ErrorAction Stop}

    ## Set target and dependencies
    $dependencyDictionary = GetDependencyDictionary $targetLineArray

    ## Get topologically sorted target line
    [string[]]$sortedTargetList = @()
    $sortedTargetList = PerformTopologicalSort "$currentTarget" $dependencyDictionary

    try {
        ## Push-Location -LiteralPath
        if ( $PushPopLocation ){
            [String] $currentLocation = (Resolve-Path -Relative .).Replace('\','/')
            [String] $targetLocation = (Resolve-Path -Relative $makefileDirectory).Replace('\','/')
            Push-Location -LiteralPath $makefileDirectory
            Write-Host ""
            Write-Host "Push to ""$targetLocation""" -ForegroundColor Blue
            Write-Host ""
        }
        ## Debug log
        if ($DryRunMode){
            Write-Output "######## TOPOLOGICALLY SORTED TARGET LINES ##########"
            foreach ($line in $sortedTargetList) {
                Write-Output "$line"
            }
            Write-Output ""
            Write-Output "######## TOPOLOGICALLY SORTED COMMAND LINES ##########"
            foreach ($temporaryTarget in $sortedTargetList) {
                foreach($commandLine in $commandDictionary[$temporaryTarget]) {
                    if ( $commandLine -notmatch '^\s*$' ){
                        $commandLine = ReplaceAutomaticVariables "$commandLine" "$temporaryTarget" $targetDependencyDictionary
                        #Write-Output "$($temporaryTarget): $commandLine"
                        Write-Output "$commandLine"
                    }
                }
            }
        }
        ## Execute commands
        $isCommandExecuted = $False
        if ($DryRunMode){
            Write-Output ""
            Write-Output "######## EXECUTING COMMANDS ##########"
        }
        [string[]]$executedCommandArray = @()
        foreach ($target in $sortedTargetList) {
            $targetLineExists = $commandDictionary.ContainsKey($target)
            if ( -not $targetLineExists ){
                if (IsTargetFileAbsent "$target"){
                    ## Target file is not exists
                    Write-Error "Error: file is not exists: '$target'." -ErrorAction Stop
                } else {
                    ## Target file is exists
                    continue
                }
            }
            ## Set commandline as string array
            [string[]]$commandLines = $commandDictionary[$target]
            ## Set dependency line as string
            if ($targetDependencyDictionary[$target][0] -eq '') {
                $dependency = ''
            }else{
                $dependency = $targetDependencyDictionary[$target] -join "$DependencyDelimiter"
            }
            ## Target should be execute?
            $commandExecutionFlag = ShouldTargetExecute "$target" $targetDependencyDictionary $phonyList
            if( -not $commandExecutionFlag ){
                ## Continue ForEach-Object
                ## Do not execute commands
                #if ($DryRunMode){ Write-Output "[F] $($target): $dependency" }
                continue
            }
            ## Are commandlines exists?
            if ($commandLines.Count -eq 0){
                ## Continue ForEach-Object
                #if ($DryRunMode){ Write-Output "[F] $($target): $dependency" }
                continue
            }
            ## Execute commandlines
            foreach ($commandLine in $commandLines){
                ## Replace automatic variables
                [string] $commandLine = ReplaceAutomaticVariables "$commandLine" "$target" $targetDependencyDictionary
                if (($commandLine -eq '') -or ($commandLine -match '^\s*$')){
                    continue
                }
                ## Main
                if ($DryRunMode){
                    ## Out debug
                    #Write-Output "[T] $($target): $commandLine"
                    Write-Output "$commandLine"
                }else{
                    ## Execute commandline
                    $echoCommand = $True
                    if ($commandLine -match '^@[^\(\{]'){
                        $echoCommand = $False
                        $commandLine = $commandLine -replace '^@', ''
                    }
                    if ($echoCommand){
                        Write-Host "> $commandLine" -ForegroundColor Green
                    }
                    try {
                        $isCommandExecuted = $True
                        Invoke-Expression "$commandLine"
                    } catch {
                        if ($ErrorActionPreference -eq "stop"){
                            #Write-Warning "Error: $($target): $commandLine"
                            Write-Error $Error[0] -ErrorAction Stop
                        }else{
                            #Write-Warning "Error: $($target): $commandLine"
                            Write-Warning $Error[0]
                        }
                    }
                }
            }
            if ($echoCommand){ Write-Host "" }
        }
        if( (-not $isCommandExecuted) -and (-not $DryRunMode)){
            Write-Host "make: '$currentTarget' is up to date."
        }
    } finally {
        if ( $PushPopLocation ){
            Pop-Location
            Write-Host ""
            Write-Host "Pop to ""$currentLocation""" -ForegroundColor Blue
        }
    }
}
