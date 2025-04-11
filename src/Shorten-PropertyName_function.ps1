<#
.SYNOPSIS
    Shorten-PropertyName - Shorten property names

    Shorten the property names to one letter after each
    hyphens/underscores/dots. The aim is to reduce the
    number of characters input for long property name
    when data exploration.

        Rename rules:
            - Pattern 1: For property name without delimiter
                - Display as is
            - Pattern 2: For property names containing delimiter
                - Concatenate the following strings with delimiter
                    - first character
                    - the first character after the delimiter
        
        Delimiters are allowed "_", "-", "."
        Default delimiter is "_".

        Examples: name -> replaced name
            sepal_length   -> s_l
            bill_length_mm -> b_l_m
            species        -> species
            year           -> year
            
        If -VeryShorten option specified,
        do not output delimiter:
            sepal_length   -> sl
            bill_length_mm -> blm
            species        -> species
            year           -> year

    The delimiter can be changed using the -d option.
    (no need to escape special character)

        For example:
            -d "."
            -d "-"
            -d "_" (default)

    If replaced proerty name duplicates, raise error and stop processing.

.LINK
    Shorten-PropertyName, Drop-NA, Replace-NA, Apply-Function, Add-Stats, Detect-XrsAnomaly, Plot-BarChart, Get-First, Get-Last, Select-Field, Delete-Field

.EXAMPLE
    # before (long property name)
    Import-Csv iris.csv `
        | Get-Random -Count 3 `
        | ft

    sepal_length sepal_width petal_length petal_width species
    ------------ ----------- ------------ ----------- -------
    6.8          3.0         5.5          2.1         virginica
    6.9          3.1         5.4          2.1         virginica
    5.0          3.6         1.4          0.2         setosa

    # after (short property name)

    Import-Csv iris.csv `
        | Get-Random -Count 3 `
        | Shorten-PropertyName `
        | ft

    s_l s_w p_l p_w species
    --- --- --- --- -------
    4.8 3.4 1.9 0.2 setosa
    6.2 3.4 5.4 2.3 virginica
    6.0 2.9 4.5 1.5 versicolor

    # after2 (very short property name)

    Import-Csv iris.csv `
        | Get-Random -Count 3 `
        | Shorten-PropertyName -VeryShorten `
        | ft

    sl  sw  pl  pw  species
    --  --  --  --  -------
    6.5 3.0 5.8 2.2 virginica
    5.1 3.5 1.4 0.2 setosa
    6.3 3.3 4.7 1.6 versicolor

    # change delimiter (no need to escape special character)
    
    cat iris.csv `
        | sed 's;_;.;g' `
        | ConvertFrom-Csv `
        | Get-Random -Count 3 `
        | Shorten-PropertyName -d "." `
        | ft

    s.l s.w p.l p.w species
    --- --- --- --- -------
    5.7 2.8 4.1 1.3 versicolor
    6.3 2.9 5.6 1.8 virginica
    4.4 3.2 1.3 0.2 setosa

.EXAMPLE
    # before (long property name)

    Import-Csv penguins.csv `
        | Get-Random `
        | ft

    count species   island bill_length_mm bill_depth_mm flipper_length_mm body_mass_g sex    year
    ----- -------   ------ -------------- ------------- ----------------- ----------- ---    ----
    301   Chinstrap Dream  46.7           17.9          195               3300        female 2007

    # after (short property name)

    Import-Csv penguins.csv `
        | Get-Random `
        | Shorten-PropertyName `
        | ft

    count species island b_l_m b_d_m f_l_m b_m_g sex  year
    ----- ------- ------ ----- ----- ----- ----- ---  ----
    262   Gentoo  Biscoe 48.1  15.1  209   5500  male 2009

    # after (very short)

    Import-Csv penguins.csv `
        | Get-Random `
        | Shorten-PropertyName -v `
        | ft

    count species island blm  bdm  flm bmg  sex  year
    ----- ------- ------ ---  ---  --- ---  ---  ----
    246   Gentoo  Biscoe 49.5 16.1 224 5650 male 2009

.EXAMPLE
    # Raise error and stop processing if property name dupulicated

    cat iris.csv `
        | sed 's;sepal_width;sepal_l;' `
        | ConvertFrom-Csv `
        | Get-Random -Count 3 `
        | Shorten-PropertyName `
        | ft
    
    Shorten-PropertyName:
    Line |
       5 |          | Shorten-PropertyName `
         |            ~~~~~~~~~~~~~~~~~~~~
         | Property name: "sepal_l" -> "s_l" already exists.

.EXAMPLE
    # Shorten property names to any desired character count
    # using -Length option
    dataset iris3 | Select-Object -First 1
    
    Sepal.L..Setosa     : 5.1
    Sepal.W..Setosa     : 3.5
    Petal.L..Setosa     : 1.4
    Petal.W..Setosa     : 0.2
    Sepal.L..Versicolor : 7
    Sepal.W..Versicolor : 3.2
    Petal.L..Versicolor : 4.7
    Petal.W..Versicolor : 1.4
    Sepal.L..Virginica  : 6.3
    Sepal.W..Virginica  : 3.3
    Petal.L..Virginica  : 6
    Petal.W..Virginica  : 2.5

    # raise dupulicated error
    dataset iris3 `
        | Select-Object -First 1 `
        | Shorten-PropertyName -Delimiter "." -Length 1

    Shorten-PropertyName: Property name: "Sepal.L..Virginica" -> "S.L..V" already exists.

    # Shorten property names to 2 characters
    dataset iris3 `
        | Select-Object -First 1 `
        | Shorten-PropertyName -Delimiter "." -Length 2
    
    Se.L..Se : 5.1
    Se.W..Se : 3.5
    Pe.L..Se : 1.4
    Pe.W..Se : 0.2
    Se.L..Ve : 7
    Se.W..Ve : 3.2
    Pe.L..Ve : 4.7
    Pe.W..Ve : 1.4
    Se.L..Vi : 6.3
    Se.W..Vi : 3.3
    Pe.L..Vi : 6
    Pe.W..Vi : 2.5

#>
function Shorten-PropertyName
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False)]
        [Alias('d')]
        [string] $Delimiter = '_'
        ,
        [Parameter(Mandatory=$False)]
        [Alias('v')]
        [switch] $VeryShorten
        ,
        [Alias('l')]
        [int[]] $Length
        ,
        [Parameter(Mandatory=$False, ValueFromPipeline=$True)]
        [PSObject] $InputObject
    )
    # escape delimiter
    [regex] $escapedDelimiter = [regex]::Escape($Delimiter)
    # get all property names
    [String[]] $OldPropertyNames = ($input[0].PSObject.Properties).Name
    [String[]] $ReplaceComAry = @()
    [String[]] $newNameAry = @()
    [String[]] $tmpNameAry = @()
    foreach ( $oldName in $OldPropertyNames ){
        [string[]] $splitNames = $oldName -split $escapedDelimiter
        # collect delimited names
        foreach ( $splitName in $splitNames ){
            if ( $splitName.Length -eq 0 ){
                # empty string
                $tmpNameAry += $splitName
            } elseif ( $splitName.Length -eq 1 ){
                # single character
                $tmpNameAry += $splitName
            } else {
                # multiple characters
                if ( $Length.Count -eq 1 ){
                    if ( $Length[0] -gt $splitName.Length ){
                        [int] $sNum = 0
                        [int] $eNum = $splitName.Length
                    } else {
                        [int] $sNum = 0
                        [int] $eNum = $Length[0]
                    }
                } elseif ( $SubString.Count -gt 1 ){
                    [int] $sNum = $Length[0]
                    [int] $eNum = $Length[1]
                } else {
                    [int] $sNum = 0
                    [int] $eNum = 1
                }
                try {
                    $tmpNameAry += $splitName.SubString($sNum, $eNum)
                } catch {
                    Write-Error $error[0] -ErrorAction Stop
                }
            }
        }
        # create new property name
        if ( $VeryShorten ){
            [string] $newName = $tmpNameAry -join ''
        } else {
            [string] $newName = $tmpNameAry -join $Delimiter
        }
        Write-Debug $newName
        # duplicate test for newname
        if ( $newName -in $newNameAry ){
            Write-Error "Property name: ""$oldName"" -> ""$newName"" already exists." -ErrorAction Stop
        }
        $newNameAry += $newName
        $ReplaceComAry += "@{N=""$newName""; E={`$_.""$($oldName)""}}"
        [String[]] $tmpNameAry = @()
    }
    # invoke command strings
    $hash = $ReplaceComAry | ForEach-Object { Invoke-Expression -Command $_ }
    $input | Select-Object -Property $hash
}
