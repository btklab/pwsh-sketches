<#
.SYNOPSIS
    pwmake - PowerShell implementation of GNU Make command

    Implementation of core GNU Make command features,
    including dependency resolution via topological sorting,
    with some modified specifications:
    
        - Syntax: Leading whitespace on command lines may be either
          a <tab> or a <spaces>.
        - Abbreviation: Targets prefixed with "@" can be treated
          as ".PHONY <target>" without explicitly declaring ".PHONY".
        - Help messages: Appending "## help message" at the end
          of a target line enables it to be displayed in help output.
        - to define variables, use ${} instead of $()
            - if @() is used, it is interpreted as a Subexpression
              operator (described later)


    Reads and executes a Makefile in the current directory.
    File names must not contain spaces.

    Usage:
        - man pwmake
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
        ```

        ```Makefile
        file := index.md

        .PHONY: all
        all: ${file} ## echo filename
            echo ${file}
            # $param is predefined [string] variable
            echo $Parameter
            # $params is also predefined [string[]] variable
            echo $Parameters
            echo $Parameters[0]
        ```

    Instead of writing ".PHONY <Target>", you can also place "@"
    at the beginning of the target.

        ```Makefile
        file := index.md

        # "@" is equivalent to .PHONY <target>
        @all: ${file} ## echo filename
            echo ${file}
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
            - %.ext : Replaces with a string with the extension removed
                  from the target name. Only target line can be used.

        ```Makefile
        # '%' example:
        %.tex: %.md
            cat $< | md2html > $@
        ```

        ```Makefile
        root := $PSScriptRoot/args
        all:
            echo $PSScriptRoot
            echo $PSScriptRoot/hoge
            echo ${root}
        ```

    Detail:
        - Syntax: Leading whitespace on command lines may be either
          a <tab> or a <spaces>.
        - Abbreviation: Targets prefixed with "@" can be treated
          as ".PHONY <target>" without explicitly declaring ".PHONY".
        - Help messages: Appending "## help message" at the end
          of a target line enables it to be displayed in help output.
        - to define variables, use ${} instead of $()
            - if @() is used, it is interpreted as a Subexpression
              operator (described later)
        - If no target is specified in args, the first target is executed.
        - Since it operates in the current process, dot sourcing functions
          read in current process can also be described in Makefile.
        - If the file path specified in Makefile is not an absolute
          path, it is regarded as a relative path.
        - [-n|-DryRun] switch available.
            - [-toposort] switch shows Makefile dependencies.
        - Comment with "#"
            - only the target line and Variable declaration line (a line
              that does not start with a blank space) can be commented
              at the end of the line.
                - comment at the end of command line is unavailable, but
                  using the "-DeleteCommentEndOfCommandLine" switch forces
                  deletion of comments from the "#" sign to the end of the line.
            - End-of-line comments not allowed in command line.
            - Do not comment out if the rightmost character of the comment
              line is double-quote or single-quote. For example, the following
              command is interpreted as "#" in a string.
                - "# this is not a comment"
            - But also the following is not considered a comment. This is
              an unexpected result.
                - key = val ## note grep "hoge"
            - Any line starting with whitespaces and "#" is treated as a
              comment line regardless of the rightmost character.
            - The root directory of the relative path written in the Makefile is
              where the pwmake command was executed.
            - "-f <file>" reads external Makefile.
                - the root directory of relative path in the external Makefile
                  is the Makefile path.
        - pwmake -f <directory>
            - If you run make -f <directory>, it lists the files in <directory>.
            - If you run make -f <file> and <file> contains an asterisk '*' or
              a question mark '?', it lists the matching files.
            
        Comment example:
            
            home := $($HOME) # comment

            target: deps  ## comment (help message)
                command |
                    sed 's;^#;;' |
                    # grep -v 'hoge' | <-- allowed comment out
                    grep -v 'hoge' | ## notice!!  <-- not allowed (use -DeleteCommentEndOfCommandLine)
                    > a.md
        
    Tips:
        If you put "## comment..." at the end of each target line
        in Makefile, you can get the comment as help message for
        each target with pwmake -ShowHelp [-FilePath MakefilePath]

            ```Makefile
            target: [dep dep ...] ## this is help message
            ```powershell
            PS> pwmake -ShowHelp
            ##
            ## isPhony target synopsis
            ## ------- ------ --------
            ## PHONY   help   help message
            ## FILE    new    create directory and set skeleton files
            ```
            
    Note:
        - Variables can be declared between the first line and the line
          containing a colon ":"
        - Lines containing a colon ":" are considered target lines, and
          all other lines that begin with whitespaces are command lines.
        - Do not include spaces in file paths and target names.
        - Command lines are preceded by one or more spaces or tabs.
        - If "@" is added to the beginning of the command line, the command
          line will not be echoed to the output.
        - Use ${var} when using the declared variables. Do not use @(var).
        - But $(powershell-command) can be used for the value to be
          assigned to the variable. For example,
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
        - Shell variable assignment foo := Get-Date assigns as simple strings.
          If the character string on the right side can be interpreted as a
          powershell command, it may be executed when used line foo = $(Get-Command).
          However, it is safer to wrap powershell commands in $().
        
        - The linefeed escape character is as follows:
            - backslash
            - backtick
            - pipeline (vertical bar)

    References:
        - https://www.gnu.org/software/make/
        - https://www.oreilly.co.jp/books/4873112699/

.LINK
    toposort, pwmake

.EXAMPLE
    # Makefile example1: simple Makefile

    ```Makefile
    .PHONY: all
    all: hoge.txt ## Generate hoge.txt

    hoge.txt: log.txt ## Generate hoge.txt from log.txt
        1..10 | grep 10 >> hoge.txt

    log.txt: ## Generate log.txt
        (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') | sed 's;2022;2000;' >> log.txt
    ```

    pwmake -ShowHelp

    isPhony target   synopsis
    ------- ------   --------
    PHONY   all      Generate hoge.txt
    FILE    hoge.txt Generate hoge.txt from log.txt
    FILE    log.txt  Generate log.txt

.EXAMPLE
    # Makefile example2: use "@" to define phony target.
    # Equivalent to the previous Makefile.

    ```Makefile
    @all: hoge.txt ## Generate hoge.txt

    hoge.txt: log.txt ## Generate hoge.txt from log.txt
        1..10 | grep 10 >> hoge.txt

    log.txt: ## Generate log.txt
        (Get-Date).ToString('yyyy-MM-dd HH:mm:ss') | sed 's;2022;2000;' >> log.txt
    ```

    pwmake -ShowHelp

    isPhony target   synopsis
    ------- ------   --------
    PHONY   all      Generate hoge.txt
    FILE    hoge.txt Generate hoge.txt from log.txt
    FILE    log.txt  Generate log.txt

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

    @all: ${pdffile} ## Generate pdf file and open.
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

    isPhony target synopsis
    ------- ------ --------
    PHONY   all    Generate pdf file and open.
    FILE    a.pdf  Generate pdf file from dvi file.
    FILE    a.dvi  Generate dvi file from tex file.
    PHONY   clean  Remove cache files.

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
    # use predefined variable: $PSScriptRoot
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

    isPhony target synopsis
    ------- ------ --------
    PHONY   all    Add ".txt" to the extension of the script file and Zip archive
    PHONY   clean  Remove "*.txt" items in Documents directory

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

.EXAMPLE
    # list up files in directory
    
    pwmake -f ../makefiles/

    Directory: C:/Users/btklab/cms/makefiles

    calendar.Makefile
    clip2graph-graphviz.Makefile
    clip2img_from_clipboard.Makefile
    dictjugler.Makefile
    dilemma.pu.Makefile
    ...
    supersimpler.Makefile
    weather_ical.Makefile

.EXAMPLE
    # list up files if filename contains '*' or '?'
    
    pwmake -f ../makefiles/update-*

    Directory: C:/Users/btklab/cms/makefiles

    update-sketches.Makefile
    update-hogefuga.Makefile

#>
function pwmake {
    Param(
        [Parameter(Position=0, Mandatory=$False)]
        [Alias('t')]
        [string] $TargetName,

        [Parameter(Position=1, Mandatory=$False)]
        [Alias('v')]
        [string[]] $OverrideVariables,

        [Parameter(Mandatory=$False)]
        [Alias('f')]
        [string] $FilePath = "Makefile",

        [Parameter(Mandatory=$False)]
        [Alias('d')]
        [string] $DependencyDelimiter = " ",

        [Parameter(Mandatory=$False)]
        [Alias('td')]
        [string] $TargetDefinitionDelimiter = ":",

        [Parameter(Mandatory=$False)]
        [ValidateSet("stop","silentlyContinue")]
        [string] $ErrorActionPreference = "stop",

        [Parameter(Mandatory=$False)]
        [switch] $ShowHelp,

        [Parameter(Mandatory=$False)]
        [switch] $DeleteCommentsAtEndOfCommandLine,

        [Parameter(Mandatory=$False)]
        [string] $Parameter,

        [Parameter(Mandatory=$False)]
        [string[]] $Parameters,

        [Parameter(Mandatory=$False)]
        [Alias('p')]
        [switch] $PushAndPop,

        [Parameter(Mandatory=$False)]
        [Alias('n')]
        [switch] $DryRun
    )

    #region Helper Functions

    ## Function to parse and display help messages
    function Parse-MakefileHelp ([string[]] $variableBlock, [string] $makefileFullPath) {
        ## Help messages are expected to be in the following format:
        ##   target: [dep dep ...] ## synopsis
        ##
        ## Example output:
        ##   PS> pwmake -ShowHelp
        ##
        ##   isPhony target synopsis
        ##   ------- ------ --------
        ##   PHONY   help   help message
        ##   FILE    new    create directory and set skeleton files
        ##
        $variableDictionary = @{}
        if ($variableBlock) {
            foreach ($variable in $variableBlock) {
                ## Get variables and add to dictionary (key, value)
                $key, $value = Get-VariableAndValue "$variable" $variableDictionary
                if ($variableDictionary) {
                    foreach ($k in $variableDictionary.Keys) {
                        ## Replace variables
                        [string] $targetVariable = '${' + $k + '}'
                        [string] $replaceVariable = $variableDictionary[$k]
                        [string] $value = $value.Replace($targetVariable, $replaceVariable)
                    }
                }
                $variableDictionary.Add($key, $value)
            }
        }
        [string[]] $collectedPhonyTargetsForShowHelp = @()
        Select-String '^[a-zA-Z0-9_\-\{\}\$\.\ \@]+?:' -Path $makefileFullPath -Raw `
            | ForEach-Object {
                [string] $helpString = [string]$_
                if ($helpString -match ':='){
                    ## Skip variable definition lines
                    return
                } elseif ($helpString -match '^\.PHONY'){
                    ## Collect PHONY targets
                    ## and Skip PHONY definition lines
                    [string[]] $tmpCommandBlock, [string[]] $tmpPhonyTargets = Collect-PhonyTargets $helpString
                    if ($tmpPhonyTargets.Count -gt 0){
                        foreach ($phonyTarget in $tmpPhonyTargets){
                            if ($phonyTarget -notin $collectedPhonyTargetsForShowHelp){
                                [string[]] $collectedPhonyTargetsForShowHelp += $phonyTarget
                            }
                        }
                    }
                    return
                } elseif ($helpString -match ' ## '){
                    [string] $helpString = $helpString -replace ':.*? ## ', ' ## '
                } else {
                    [string] $helpString = $helpString -replace ':.*$', ''
                }
                if ($variableBlock){
                    ## Replace variables
                    foreach ($k in $variableDictionary.Keys){
                        [string] $before = '${' + $k + '}'
                        [string] $after = $variableDictionary[$k]
                        [string] $helpString = $helpString.Replace($before, $after)
                    }
                }
                $helpString
                } `
            | ForEach-Object {
                [string[]] $helpArray = $_.split(' ## ', 2)
                $helpTarget = $helpArray[0].trim()
                if ($helpTarget -match '^\@'){
                    ## If the target starts with '@', isPhony is set to 'PHONY'
                    $helpObject = [ordered] @{
                        isPhony = 'PHONY'
                        target = $helpArray[0] -replace '^\@', ''
                        synopsis = $helpArray[1]
                    }
                } elseif ( $helpTarget -in $collectedPhonyTargetsForShowHelp ) {
                    ## If the target is in the collected PHONY targets
                    $helpObject = [ordered] @{
                        isPhony = 'PHONY'
                        target = $helpArray[0]
                        synopsis = $helpArray[1]
                    }
                } else {
                    ## If the target is not a PHONY target, but a FILE target.
                    $helpObject = [ordered] @{
                        isPhony = 'FILE'
                        target = $helpArray[0]
                        synopsis = $helpArray[1]
                    }
                }
                return $([pscustomobject] $helpObject)
            }
    }

    ## Function to read Makefile content, expand included files, and add end-of-line marks
    function Read-AndExpandMakefile ([string]$makefile) {
        [string[]] $lines = @()
        [string] $parentDirectory = Split-Path "$makefile" -Parent
        [string[]] $lines = Get-Content -LiteralPath "$makefile" -Encoding utf8 `
            | ForEach-Object {
                [string] $makefileLine = [string] $_
                if ($makefileLine -match '^include '){
                    ## Include other Makefiles
                    [string] $includePath = $makefileLine -replace '^include ','';
                    [string] $includePath = $includePath.trim();
                    [string[]] $fileList = $includePath -split ' ';
                    foreach ($file in $fileList){
                        [string] $fullPath = Join-Path "$parentDirectory" "$file";
                        Get-Content -Path "$fullPath" -Encoding utf8;
                        Write-Output ''; # Add empty line at the end of included file
                    }
                } else {
                    Write-Output "$makefileLine";
                }
            }
        return $lines;
    }

    ## Function to remove comments from command lines
    function Remove-MakefileComments ([string[]]$lines, [switch]$deleteCommentsAtEndOfCommandLine) {
        [string[]] $cleanedLines = @()
        foreach ($line in $lines) {
            if ($line -notmatch '^\s*#'){ # If the line does not start with a comment
                if ($line -match '^\s+'){ # If it's a command line
                    if ($deleteCommentsAtEndOfCommandLine){
                        # Remove end-of-line comments (e.g., command # comment)
                        [string[]] $cleanedLines += $line -replace '#.*$', '';
                    } else {
                        [string[]] $cleanedLines += $line;
                    }
                } else { # If it's a target line or variable definition line
                    # Remove end-of-line comments (e.g., target: deps ## comment)
                    [string[]] $cleanedLines += $line -replace '#.*[^"'']$', '';
                }
            } else { # If the line starts with a comment, skip the entire line
                continue;
            }
        }
        return $cleanedLines;
    }

    ## Function to process line break escape characters at the end of lines
    function Process-LineBreakEscapes ([string[]]$lines) {
        [string] $previousLine = '';
        [string[]] $processedLines = @();
        foreach ($line in $lines) {
            if ($line -match ' \\$' ){ # Backslash
                [string] $previousLine = $previousLine + ($line -replace '\s+\\$', "`n");
            } elseif ($line -match ' \`$' ){ # Backtick
                [string] $previousLine = $previousLine + ($line -replace '\s+\`$', "`n");
            } elseif ($line -match ' \|$' ){ # Pipe
                [string] $previousLine = $previousLine + ($line -replace '\s+\|$'," |`n");
            } else {
                if ($previousLine -ne ''){
                    [string[]] $processedLines += $previousLine + $line;
                    [string] $previousLine = '';
                } else {
                    [string[]] $processedLines += $line;
                }
            }
        }
        if ($previousLine -ne ''){
            [string[]] $processedLines += ($previousLine -replace '\s*$','');
        }
        return $processedLines;
    }

    ## Function to split Makefile lines into argument and command blocks
    function Separate-MakefileBlocks ([string[]]$lines) {
        [bool] $isVariableBlock = $true;
        [string[]] $variableBlock = @();
        [string[]] $commandBlock = @();
        foreach ($line in $lines) {
            if ($line -match '.'){
                if ($line -notmatch '='){
                    [bool] $isVariableBlock = $False;
                }
            }
            if ($isVariableBlock){
                if (($line -ne '') -and ($line -match ':=')){
                    [string[]] $variableBlock += ($line -replace '\s*:=\s*',':=');
                } elseif (($line -ne '') -and ($line -match '=')){
                    [string[]] $variableBlock += ($line -replace '\s*=\s*','=');
                }
            } else {
                [string[]] $commandBlock += $line;
            }
        }
        [string[]] $commandBlock += ''; # Add empty line for CreateTargetDictionaries function
        return $variableBlock, $commandBlock;
    }

    ## Function to apply variables specified in command line arguments to Makefile lines
    function Apply-OverrideVariables ([string[]]$lines, [string[]]$overrideVariables, [string] $makefileParentDirectory) {
        $variableDictionary = @{};
        foreach ($variable in $overrideVariables) {
            if ($variable -notmatch '='){
                Write-Error "Please use the format ""<name>=<val>"" when setting variables: $variable" -ErrorAction Stop;
            }
            [string[]] $variableArray = $variable -split "=", 2;
            [string] $key = $variableArray[0].trim();
            [string] $value = $variableArray[1].trim();
            $variableDictionary.Add($key, $value);
        }

        [string[]] $processedLines = @();
        foreach ($line in $lines) {
            [string] $currentLine = $line;
            foreach ($key in $variableDictionary.Keys){
                [string] $before = '${' + $key + '}';
                [string] $after = $variableDictionary[$key];
                [string] $currentLine = $currentLine.Replace($before, $after);
            }
            [string[]] $processedLines += $currentLine;
        }
        return $processedLines;
    }

    ## Function to get key and value from a variable definition line
    function Get-VariableAndValue ([string]$variableDefinition, $variableDictionary, [string] $makefileParentDirectory) {
        [string] $key = '';
        [string] $value = '';

        if ($variableDefinition -match ':='){
            ## ':=' defines a simply-expanded variable
            [string[]] $variableArray = $variableDefinition -split ":=", 2;
            [string] $key = $variableArray[0].trim();
            [string] $value = $variableArray[1].trim();
            
            # Check for reserved variable names
            if ($key -match '^parameter$' -or $key -match '^parameters$' -or $key -match '^PSScriptRoot$'){
                Write-Error "Variable name ""$key"" is reserved. Please use another keyword." -ErrorAction Stop;
            }

            ## Replace ${var}
            if ($value -match '\$\{'){
                if ($variableDictionary){
                    foreach ($k in $variableDictionary.Keys){
                        [string] $before = '${' + $k + '}';
                        [string] $after = $variableDictionary[$k];
                        [string] $value = $value.Replace($before, $after);
                    }
                }
            }
            ## Execute shell command
            if ($value -match '\$\(..*\)'){
               ## If $value contains $(command), execute $value as a shell command before variable assignment
               [string] $commandToExecute = $value -replace '^.*(\$\(..*\)).*$', '$1';
               [string] $executedResult = Invoke-Expression "$commandToExecute";
               [string] $value = $value.Replace($commandToExecute, $executedResult);
            }
        } else {
            ## '=' defines a recursively-expanded variable
            [string[]] $variableArray = $variableDefinition -split "=", 2;
            [string] $key = $variableArray[0].trim();
            [string] $value = $variableArray[1].trim();
            
            # Check for reserved variable names
            if ($key -match '^parameter$' -or $key -match '^parameters$' -or $key -match '^PSScriptRoot$'){
                Write-Error "Variable name ""$key"" is reserved. Please use another keyword." -ErrorAction Stop;
            }
        }
        ## Replace predefined variables
        [string] $value = $value.Replace('${PSScriptRoot}', $makefileParentDirectory);
        [string] $value = $value.Replace('{$PSScriptRoot}', $makefileParentDirectory);
        [string] $value = $value.Replace('$PSScriptRoot', $makefileParentDirectory);
        return $key, $value;
    }

    ## Function to resolve variables in the argument block
    function Resolve-VariableBlockVariables ([string[]]$variableBlock, [string] $makefileParentDirectory) {
        $resolvedVariables = @{};
        [string[]] $processedVariableBlock = @();
        foreach ($variableDefinition in $variableBlock) {
            $key, $value = Get-VariableAndValue "$variableDefinition" $resolvedVariables $makefileParentDirectory;
            if ($resolvedVariables){
                foreach ($k in $resolvedVariables.Keys){
                    [string] $before = '${' + $k + '}';
                    [string] $after = $resolvedVariables[$k];
                    [string] $value = $value.Replace($before, $after);
                }
            }
            $resolvedVariables.Add($key, $value);
            [string[]] $processedVariableBlock += "$key=$value";
        }
        return $processedVariableBlock, $resolvedVariables;
    }

    ## Function to resolve variables in the command block
    function Resolve-CommandBlockVariables ([string[]]$commandBlock, $resolvedVariables) {
        [string[]] $processedCommandBlock = @();
        foreach ($line in $commandBlock) {
            [string] $currentLine = $line;
            foreach ($key in $resolvedVariables.Keys){
                [string] $before = '${' + $key + '}';
                [string] $after = $resolvedVariables[$key];
                [string] $currentLine = $currentLine.Replace($before, $after);
            }
            [string[]] $processedCommandBlock += $currentLine;
        }
        return $processedCommandBlock;
    }

    ## Function to collect PHONY targets and remove them from the command block
    function Collect-PhonyTargets ([string[]]$commandBlock) {
        [string[]] $phonyList = @()
        [string[]] $phonyTargets = @()
        [string[]] $filteredCommandBlock = @()
        foreach ($line in $commandBlock) {
            if ($line -match '^\.PHONY:'){
                # Set .PHONY targets
                [string[]] $phonyList = ($line -replace '^\.PHONY:\s*') -split $DependencyDelimiter
                [string[]] $phonyTargets += $phonyList
            } elseif ($line -match '^@[^ \{\(\:]+:'){
                # Set .PHONY targets.
                # If the target starts with '@'
                [string[]] $phonyList = ($line -replace '^@([^ \{\(\:]+):.*$', '$1').Trim()
                [string[]] $phonyTargets += $phonyList
                # Remove '@' from the beginning of the line
                [string[]] $filteredCommandBlock += $line -replace '^@', ''
            } else {
                # Normal command line or target line
                [string[]] $filteredCommandBlock += $line
            }
        }
        return $filteredCommandBlock, $phonyTargets
    }

    ## Function to replace '%' in the command block with the target string
    function Replace-PercentInCommandBlock ([string[]]$commandBlock, [string]$targetName) {
        ## Shortest string with extension removed from the target string
        [string] $replacement = $targetName -replace '\.[^.\\/]*$', '';
        [string] $replacement += '.';
        
        [string[]] $processedCommandBlock = @();
        foreach ($line in $commandBlock) {
            if ($line -match '%\.'){
                if ($line -match '^[^\s].*:'){ # If it's a target line
                    [string[]] $processedCommandBlock += $line.Replace('%.',"$replacement");
                } else { # If it's a command line
                    [string[]] $processedCommandBlock += $line;
                }
            } else {
                [string[]] $processedCommandBlock += $line;
            }
        }
        return $processedCommandBlock;
    }

    ## Function to clean up the command block and add empty lines before target lines
    function Clean-CommandBlock ([string[]]$commandBlock) {
        [string[]] $cleanedBlock = @();
        [bool]$isFirstTargetLine = $true;
        foreach ($line in $commandBlock) {
            if ($line -ne ''){
                if ($isFirstTargetLine){
                    [string[]] $cleanedBlock += $line;
                    [bool] $isFirstTargetLine = $False;
                } elseif ($line -match '^[^\s].*:'){
                    [string[]] $cleanedBlock += ''; # Add empty line before a normal target line
                    [string[]] $cleanedBlock += $line;
                } else {
                    if ($line -notmatch '^\s'){
                        Write-Error "Unexpected line: $line" -ErrorAction Stop;
                    }
                    [string[]] $cleanedBlock += $line;
                }
            }
        }
        [string[]] $cleanedBlock += ''; # Add empty line at the end
        return $cleanedBlock;
    }

    ## Function to create target and dependency dictionaries
    function Create-TargetDictionaries ([string[]]$commandBlock, [string]$targetDefinitionDelimiter, [string]$dependencyDelimiter) {
        $commandDictionary = @{};
        $targetDependencyDictionary = @{};
        [string[]] $targetLines = @();
        [string] $firstTargetFound = '';
        [string[]] $currentCommands = @();
        [string] $currentTarget = '';

        foreach ($line in $commandBlock) {
            if ($line -eq ''){ # Block separator (empty line)
                if ($currentTarget -ne ''){
                    $commandDictionary.Add($currentTarget, $currentCommands);
                    [string[]] $currentCommands = @();
                    [string] $currentTarget = '';
                }
            } else {
                if ($line -match '^[^\s+].*:' -and $line -notmatch '^\.PHONY:'){ # Target: dependency line
                    [string[]] $targetLines += $line;
                    $targetPart, $dependencyPart = $line -split $targetDefinitionDelimiter, 2;
                    [string] $targetName = $targetPart.trim();
                    [string] $dependencies = $dependencyPart.trim();
                    [string[]] $dependencyArray = @();
                    if ($dependencies -ne '') {
                        [string[]] $dependencyArray = $dependencies -split $dependencyDelimiter;
                    }
                    $targetDependencyDictionary.Add($targetName, $dependencyArray);
                    
                    if ($firstTargetFound -eq ''){
                        [string] $firstTargetFound = $targetName;
                    }
                    [string] $currentTarget = $targetName;
                } elseif ($line -match '^\s') { # Command line
                    [string[]] $currentCommands += $line.trim();
                } else {
                    Write-Error "Unexpected line: $line" -ErrorAction Stop;
                }
            }
        }
        return $targetLines, $commandDictionary, $targetDependencyDictionary, $firstTargetFound;
    }

    ## Function to get the dependencies dictionary
    function Get-DependenciesDictionary ([string[]]$targetLines, [string]$targetDefinitionDelimiter, [string]$dependencyDelimiter) {
        $dependenciesDictionary = @{};
        foreach ($line in $targetLines) {
            $targetPart, $dependencyPart = $line -split $targetDefinitionDelimiter, 2;
            [string] $targetName = $targetPart.trim();
            [string] $dependencies = $dependencyPart.trim();
            [string[]] $dependencyArray = @();
            if ($dependencies -ne '') {
                [string[]] $dependencyArray = $dependencies -split $dependencyDelimiter;
            }
            $dependenciesDictionary.Add($targetName, $dependencyArray);
        }
        return $dependenciesDictionary;
    }

    ## Function to check if a target exists
    function Test-TargetExistence ([string]$target, $dependencies) {
        return $dependencies.ContainsKey($target);
    }

    ## Function to topologically sort targets using Tarjan's algorithm
    function Sort-TargetsTopologically ([string]$target, $dependencies, $marked = @{}, $sorted = @()) {
        ## Tarjan's topological sort
        ## :arg dependencies: Dictionary of (target, [list of dependencies]) pairs
        if ($marked[$target]){ return $sorted; } # Skip if already marked
        $marked[$target] = $True; # Mark the current node

        [string[]] $dependenciesList = $dependencies[$target];
        if ($dependenciesList.Count -gt 0) {
            foreach ($dependency in $dependenciesList){
                [string[]] $sorted = Sort-TargetsTopologically $dependency $dependencies $marked $sorted;
            }
        }
        [string[]] $sorted += $target; # Add the processed node to the sorted list
        return $sorted;
    }

    ## Function to check if a target contains a PHONY target
    function Test-TargetContainsPhony ([string]$target, [string[]]$phonyTargets) {
        [string[]] $targetArray = $target -split $DependencyDelimiter;
        foreach ($t in $targetArray){
            foreach ($phony in $phonyTargets){
                if ($t -eq $phony){ return $True; }
            }
        }
        return $False;
    }

    ## Function to check if a dependency contains a PHONY target
    function Test-DependencyContainsPhony ([string[]]$dependencies, [string[]]$phonyTargets) {
        foreach ($dependency in $dependencies){
            if (Test-TargetContainsPhony $dependency $phonyTargets){ return $True; }
            if ( -not (Test-Path -LiteralPath "$dependency") ){ return $True; }
        }
        return $False;
    }

    ## Function to check if a target file does not exist
    function Test-TargetFileDoesNotExist ([string]$target) {
        [string[]] $targetArray = "$target" -split $DependencyDelimiter;
        foreach ($t in $targetArray){
            if ( -not (Test-Path -LiteralPath "$t") ){ return $True; }
        }
        return $False;
    }

    ## Function to check if a dependency file does not exist
    function Test-DependencyFileDoesNotExist ([string[]]$dependencies, [string[]]$phonyTargets) {
        foreach ($dependency in $dependencies){
            if (Test-TargetContainsPhony $dependency $phonyTargets){ return $True; }
            if ( -not (Test-Path -LiteralPath "$dependency") ){ return $True; }
        }
        return $False;
    }

    ## Function to get the last write time of files
    function Get-FileLastWriteTime ([string[]]$files, [string]$comparisonType = "older") {
        if (-not $files) { return $null; }
        [datetime] $resultDate = (Get-Item -LiteralPath $files[0]).LastWriteTime;
        foreach ($file in $files){
            [datetime]$tempDate = (Get-Item -LiteralPath "$file").LastWriteTime;
            if ($comparisonType -eq 'older'){
                if ($tempDate -lt $resultDate){ $resultDate = $tempDate; }
            } else {
                if ($tempDate -gt $resultDate){ $resultDate = $tempDate; }
            }
        }
        return $resultDate;
    }

    ## Function to check if the target file is older than its dependencies
    function Test-TargetFileOlderThanDependencies ([string]$target, [string[]]$dependencies) {
        [string[]] $targetArray = $target -split $DependencyDelimiter;
        [datetime] $targetFileOlderDate = Get-FileLastWriteTime $targetArray "older";
        [datetime] $dependencyFileNewerDate = Get-FileLastWriteTime $dependencies "newer";
        
        Write-Debug "Target's oldest last write time: $($targetFileOlderDate.ToString('yyyy-MM-dd HH:mm:ss'))";
        Write-Debug "Dependency's newest last write time: $($dependencyFileNewerDate.ToString('yyyy-MM-dd HH:mm:ss'))";

        if ($targetFileOlderDate -lt $dependencyFileNewerDate){
            return $True;
        } else {
            return $False;
        }
    }

    ## Function to determine if a target should be executed
    function Should-ExecuteTarget ([string]$target, $targetDependencyDictionary, $phonyTargets) {
        $dependencies = $targetDependencyDictionary[$target];
        [bool]$hasDependencies = ($dependencies -ne $null) -and ($dependencies.Length -gt 0) -and ($dependencies[0] -ne '');

        if (-not $hasDependencies){
            ## If the target has no dependencies
            if (Test-TargetContainsPhony "$target" $phonyTargets){
                Write-Debug "Check: Test-TargetContainsPhony: $target";
                return $True;
            }
            if (Test-TargetFileDoesNotExist "$target"){
                Write-Debug "Check: Test-TargetFileDoesNotExist: $target";
                return $True;
            }
            Write-Debug "Check: TargetFileExists: $target";
        } else {
            ## If the target has dependencies
            ### Test targets
            if (Test-TargetContainsPhony "$target" $phonyTargets){
                Write-Debug "Check: Test-TargetContainsPhony: $target";
                return $True;
            }
            if (Test-TargetFileDoesNotExist "$target"){
                Write-Debug "Check: Test-TargetFileDoesNotExist: $target";
                return $True;
            }
            ## Test dependencies
            if (Test-DependencyContainsPhony $dependencies $phonyTargets){
                Write-Debug "Check: Test-DependencyContainsPhony: $($target): $($dependencies)";
                return $True;
            }
            if (Test-DependencyFileDoesNotExist $dependencies $phonyTargets){
                Write-Debug "Check: Test-DependencyFileDoesNotExist: $($target): $($dependencies)";
                return $True;
            }
            if (Test-TargetFileOlderThanDependencies "$target" $dependencies){
                Write-Debug "Check: Test-TargetFileOlderThanDependencies: $($target): $($dependencies)";
                return $True;
            }
            Write-Debug "Check: TargetFileNewerThanDependencies: $($target): $($dependencies)";
        }
        return $False;
    }

    ## Function to replace automatic variables in the command line
    function Replace-AutomaticVariables ([string]$commandLine, [string]$target, $targetDependencyDictionary, [string]$makefileParentDirectory, [string]$dependencyDelimiter) {
        ## Replace automatic variables written in each command line
        ##     $@ : Target file name
        ##     $< : The name of the first dependent file
        ##     $^ : Names of all dependent files
        ##     %.ext : Replaces with a string with the extension removed
        ##         from the target name. Only target line can be used.
        ##     $PSScriptRoot : Parent path of Makefile

        ## Set dependency line
        [string[]] $dependencies = $targetDependencyDictionary[$target];
        [string] $dependencyString = '';
        if ($dependencies -ne $null -and $dependencies.Length -gt 0 -and $dependencies[0] -ne '') {
            [string] $dependencyString = $dependencies -join $dependencyDelimiter;
        }

        ## Set replacement strings
        [string] $autoVariableTargetAll   = $target;
        [string] $autoVariableTargetFirst = ($target -split $dependencyDelimiter)[0];
        [string] $autoVariableDependencyAll      = $dependencyString;
        [string] $autoVariableDependencyFirst    = ($dependencyString -split $dependencyDelimiter)[0];

        ## Replace automatic variables
        [string] $commandLine = $commandLine.Replace('$@',"$autoVariableTargetFirst");
        [string] $commandLine = $commandLine.Replace('$<',"$autoVariableDependencyFirst");
        [string] $commandLine = $commandLine.Replace('$^',"$autoVariableDependencyAll");
        [string] $commandLine = $commandLine.Replace('${PSScriptRoot}', $makefileParentDirectory);
        [string] $commandLine = $commandLine.Replace('{$PSScriptRoot}', $makefileParentDirectory);
        [string] $commandLine = $commandLine.Replace('$PSScriptRoot', $makefileParentDirectory);
        return $commandLine;
    }

    #endregion

    #region Main Logic
    # test path
    if ($FilePath -eq '' -or $FilePath -eq $Null) {
        Write-Error "FilePath is not specified." -ErrorAction stop
        return
    } elseif ( Test-Path -LiteralPath $FilePath -PathType Container){
        Get-ChildItem -LiteralPath $FilePath | Format-Wide 
        return
    } elseif ( $FilePath -match '\*|\?' ){
        Get-ChildItem -Path $FilePath | Format-Wide 
        return
    }
    ## Initialization
    [string] $makefile = $FilePath;
    
    ## Check Makefile existence
    if (-not (Test-Path -LiteralPath $makefile)){
        Write-Error "Makefile ""$makefile"" not found." -ErrorAction Stop;
    }
    [string] $makefileParentDirectory = (Resolve-Path -LiteralPath "$makefile" | Split-Path -Parent).Replace('\', '/');

    ## Parse Makefile
    [string[]] $rawLines = Read-AndExpandMakefile "$makefile";
    [string[]] $cleanedLines = Remove-MakefileComments $rawLines $DeleteCommentsAtEndOfCommandLine;
    [string[]] $processedLines = Process-LineBreakEscapes $cleanedLines;

    ## Variable replacement (overrides from command line arguments)
    if ($OverrideVariables){
        [string[]] $processedLines = Apply-OverrideVariables $processedLines $OverrideVariables $makefileParentDirectory;
    }
    
    ## Separate blocks
    [string[]] $variableBlock, [string[]] $commandBlock = Separate-MakefileBlocks $processedLines;

    ## Display help
    if ($ShowHelp){
        Parse-MakefileHelp $variableBlock $FilePath;
        return
    }

    ## Resolve variables in argument block
    [string[]] $resolvedVariableBlock, $resolvedVariables = Resolve-VariableBlockVariables $variableBlock $makefileParentDirectory;
    [string[]] $commandBlock = Resolve-CommandBlockVariables $commandBlock $resolvedVariables;

    ## Replace '%'
    # At this point, the target is not yet determined, so either pass an empty string temporarily or
    # process again later. Current logic handles this during command execution, so it's fine here.
    # However, if '%' affects the target name itself, it would need to be processed here.

    ## Collect PHONY targets
    [string[]] $commandBlock, [string[]] $phonyTargets = Collect-PhonyTargets $commandBlock;

    ## Clean up command block
    [string[]] $commandBlock = Clean-CommandBlock $commandBlock;

    ## Debug output (DryRun mode)
    if ($DryRun){
        Write-Output "######## override args ##########";
        if($OverrideVariables){$OverrideVariables}else{"None"};
        Write-Output '';
        Write-Output "######## variable block ##########";
        if($resolvedVariableBlock){$resolvedVariableBlock}else{"None"};
        Write-Output '';
        Write-Output "######## phonies ##########";
        if($phonyTargets){$phonyTargets}else{"None"};
        Write-Output '';
        Write-Output "######## command block ##########";
        $commandBlock;
    }

    ## Create target and dependency dictionaries
    [string[]]$targetLines, $commandDictionary, $targetDependencyDictionary, [string]$firstTarget = Create-TargetDictionaries $commandBlock $TargetDefinitionDelimiter $DependencyDelimiter;

    ## Determine execution target
    [string] $executionTarget = $TargetName;
    if (-not $executionTarget){
        [string] $executionTarget = $firstTarget;
    }

    ## Check target existence
    if (-not (Test-TargetExistence $executionTarget $commandDictionary)){
        Write-Error "Target ""$executionTarget"" does not exist in $makefile." -ErrorAction Stop;
    }

    ## Get dependencies dictionary
    $dependenciesDictionary = Get-DependenciesDictionary $targetLines $TargetDefinitionDelimiter $DependencyDelimiter;

    ## Get topologically sorted target list
    [string[]] $sortedTargets = Sort-TargetsTopologically "$executionTarget" $dependenciesDictionary;
    
    ## Replace '%' (after final target is determined)
    # For each target in sortedTargets, perform '%' replacement again.
    # This is because Sort-TargetsTopologically preserves original target names.
    # In practice, this is handled when replacing automatic variables in individual command lines, so it's not strictly necessary here.
    # However, if '%' affects the target name itself, it would need to be processed here.

    try {
        ## Change current directory (if PushAndPop is specified)
        if ($PushAndPop){
            [String] $currentLocation = (Resolve-Path -Relative .).Replace('\','/');
            [String] $targetLocation = (Resolve-Path -Relative $makefileParentDirectory).Replace('\','/');
            Push-Location -LiteralPath $makefileParentDirectory;
            Write-Host "";
            Write-Host "Changed directory to ""$targetLocation""." -ForegroundColor Blue;
            Write-Host "";
        }

        ## Debug log (DryRun mode)
        if ($DryRun){
            Write-Output "######## topological sorted target lines ##########";
            foreach ($line in $sortedTargets) {
                Write-Output "$line";
            }
            Write-Output "";
            Write-Output "######## topological sorted command lines ##########";
            foreach ($tempTarget in $sortedTargets) {
                foreach($commandLine in $commandDictionary[$tempTarget]) {
                    if ($commandLine -notmatch '^\s*$'){
                        $commandLine = Replace-AutomaticVariables "$commandLine" "$tempTarget" $targetDependencyDictionary $makefileParentDirectory $DependencyDelimiter;
                        Write-Output "$commandLine";
                    }
                }
            }
        }

        ## Execute commands
        [bool]$isCommandExecuted = $False;
        if ($DryRun){
            Write-Output "";
            Write-Output "######## execute commands ##########";
        }
        
        foreach ($targetToExecute in $sortedTargets) {
            ## Check if target exists
            if (-not (Test-TargetExistence $targetToExecute $commandDictionary)){
                if (Test-TargetFileDoesNotExist "$targetToExecute"){
                    Write-Error "Error: File does not exist: '$targetToExecute'." -ErrorAction Stop;
                } else {
                    continue; # Skip if target file exists
                }
            }
            
            ## Get command lines for the target
            [string[]]$commandsForTarget = $commandDictionary[$targetToExecute];
            
            ## Determine if the target should be executed
            [bool] $shouldExecute = Should-ExecuteTarget "$targetToExecute" $targetDependencyDictionary $phonyTargets;
            
            if (-not $shouldExecute){
                continue; # Do not execute commands
            }
            
            ## Skip if no commands exist
            if ($commandsForTarget.Count -eq 0){
                continue;
            }

            ## Execute command lines
            foreach ($commandLine in $commandsForTarget){
                ## Replace automatic variables
                [string] $processedCommandLine = Replace-AutomaticVariables "$commandLine" "$targetToExecute" $targetDependencyDictionary $makefileParentDirectory $DependencyDelimiter;
                
                if (($processedCommandLine -eq '') -or ($processedCommandLine -match '^\s*$')){
                    continue;
                }

                ## Main execution
                if ($DryRun){
                    Write-Output "$processedCommandLine";
                } else {
                    [bool] $echoCommand = $True;
                    if ($processedCommandLine -match '^@[^\(\{]'){
                        [bool] $echoCommand = $False;
                        [string] $processedCommandLine = $processedCommandLine -replace '^@', '';
                    }
                    if ($echoCommand){
                        Write-Host "> $processedCommandLine" -ForegroundColor Green;
                    }
                    try {
                        [bool] $isCommandExecuted = $True;
                        Invoke-Expression "$processedCommandLine";
                    } catch {
                        if ($ErrorActionPreference -eq "stop"){
                            Write-Error $_.Exception.Message -ErrorAction Stop;
                        } else {
                            Write-Warning $_.Exception.Message;
                        }
                    }
                }
            }
            if ($echoCommand){ Write-Host ""; }
        }
        
        if ((-not $isCommandExecuted) -and (-not $DryRun)){
            Write-Host "make: '$executionTarget' is up to date.";
        }
    } finally {
        if ($PushAndPop){
            Pop-Location;
            Write-Host "";
            Write-Host "Returned to original directory ""$currentLocation""." -ForegroundColor Blue;
        }
    }
    #endregion
}

