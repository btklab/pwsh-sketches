<#
.SYNOPSIS
    Infer-ObjectSchema - Infers the schema from objects.

    Infers the schema (property names and their most likely data types)from objects.

.LINK
    Sort-Property, Infer-ObjectSchema

.DESCRIPTION
    This function analyzes a sample of input objects to determine the data type for each property.
    It prioritizes numeric types (int, double) over date/time, boolean, and finally string,
    to provide the most specific type inference possible.
    This is useful for understanding data structures, validating data, or preparing data for
    schema-driven processes (e.g., database imports, API definitions).

.PARAMETER InputObject
    The collection of objects from which to infer the schema.
    Each object is expected to have consistent properties.

.PARAMETER SampleSize
    The number of objects to sample from the InputObject collection.
    A larger sample size increases the accuracy of type inference but may impact performance.
    Defaults to 100.

.OUTPUTS
    System.Collections.Hashtable
        A hashtable where keys are property names and values are the inferred data types (e.g., 'int', 'string', 'datetime').

.EXAMPLE
    # Example 1: Infer schema from a simple array of custom objects
    $data = @(
        [pscustomobject]@{Id = 1; Name = "Alice"; IsActive = $true; Created = (Get-Date).AddDays(-10)},
        [pscustomobject]@{Id = 2; Name = "Bob"; IsActive = $false; Created = (Get-Date).AddDays(-5)},
        [pscustomobject]@{Id = 3; Name = "Charlie"; IsActive = $true; Created = (Get-Date)}
    )
    Infer-ObjectSchema -InputObject $data

    # Expected Output (may vary slightly based on date format and PowerShell version):
    # Name              Value
    # ----              -----
    # Id                int
    # Name              string
    # IsActive          bool
    # Created           datetime

.EXAMPLE
    # Example 2: Infer schema with a smaller sample size
    $largeData = 1..1000 | ForEach-Object {
        [pscustomobject]@{
            Index = $_
            Value = [math]::Round((Get-Random -Minimum 0 -Maximum 1000) / 100, 2)
            Timestamp = (Get-Date).AddHours(-$_)
        }
    }
    Infer-ObjectSchema -InputObject $largeData -SampleSize 50

.NOTES
    - This function assumes that all objects in the input collection have the same set of properties.
      It infers properties based on the first object in the sample.
    - Type inference for 'datetime' is based on a threshold (80% of values successfully converting to [datetime]).
    - This function performs type inference based on string representations of values.
      For precise type handling, consider strong typing at the source.
#>
function Infer-ObjectSchema {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false)]
        [int]$SampleSize = 100,
        
        [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
        [object[]]$InputObject        
    )

    # Validate input: If no objects are provided, there's no schema to infer.
    # This prevents errors and provides immediate feedback to the user.
    if (-not $InputObject) {
        #Write-Warning "Empty input. No schema to infer." -ErrorAction Stop
        return
    }

    # Take a sample of the input objects to balance performance and accuracy.
    # Processing a large collection fully can be slow, while a small sample
    # might not represent the true data types if types vary within the collection.
    $sample = @()
    if ( $input.Count -gt 0 ){
        [object[]] $sample = $input | Select-Object -First $SampleSize
    } else {
        [object[]] $sample = $InputObject | Select-Object -First $SampleSize
    }    
    # Initialize a hashtable to store the inferred schema.
    # This will map property names to their determined data types.
    $schema = @{}

    # If the sample is empty, we can't infer a schema.
    if (-not $sample) {
        #Write-Warning "Could not get objects from the sample. Cannot infer schema." -ErrorAction Stop
        return
    }

    # Iterate through the properties of the first object in the sample.
    # We assume that all objects in the collection share the same set of properties.
    # 'NoteProperty' is used to get actual data properties, excluding methods or other members.
    foreach ($property in ($sample | Select-Object -First 1 | Get-Member -MemberType NoteProperty)) {
        $name = $property.Name
        # Collect all values for the current property from the sampled objects.
        # This allows us to analyze the diversity of values for type inference.
        $values = $sample | ForEach-Object { $_.$name }
        #Write-Debug "Processing property: $name with values: $values"

        # Initialize a hashtable to track the counts of each potential type.
        $typeCounts = @{
            'int'      = 0
            'double'   = 0
            'datetime' = 0
            'bool'     = 0
            'string'   = 0
        }

        # Iterate through each value and determine the most specific possible type.
        foreach ($val in $values) {
            if ($null -eq $val) {
                $typeCounts['string']++ # Count null as a string
                Write-Debug "Processing name: $name, value: $val, type: string (null value)"
                continue
            }
            
            [int] $intOut = 0
            [double] $doubleOut = 0.0
            [datetime] $dateOut = [datetime]::MinValue
            [bool] $boolOut = $false
            
            if ([int]::TryParse($val.ToString(), [ref]$intOut)) {
                $typeCounts['int']++
                Write-Debug "Processing name: $name, value: $val, type: int"
            }
            elseif ([double]::TryParse($val.ToString(), [ref]$doubleOut)) {
                $typeCounts['double']++
                Write-Debug "Processing name: $name, value: $val, type: double"
            }
            elseif ([datetime]::TryParse($val.ToString(), [ref]$dateOut)) {
                $typeCounts['datetime']++
                Write-Debug "Processing name: $name, value: $val, type: datetime"
            }
            elseif ([bool]::TryParse($val.ToString(), [ref]$boolOut)) {
                $typeCounts['bool']++
                Write-Debug "Processing name: $name, value: $val, type: bool"
            }
            else {
                $typeCounts['string']++
                Write-Debug "Processing name: $name, value: $val, type: string"
            }
        }
        
        # Determine the most frequently occurring type.
        [string] $inferredType = 'string' # Default to string
        [int] $maxCount = 0

        # Define the type precedence (prioritizing more specific types)
        [string[]] $typePrecedence = @('int', 'double', 'bool', 'datetime', 'string')

        foreach ($type in $typePrecedence) {
            if ($typeCounts[$type] -gt $maxCount) {
                $maxCount = $typeCounts[$type]
                $inferredType = $type
            } elseif ($typeCounts[$type] -eq $maxCount) {
                # If the counts are the same, decide based on precedence
                # Check if the current inferredType has a higher precedence than the current $type
                $currentInferredTypeIndex = [array]::IndexOf($typePrecedence, $inferredType)
                $currentTypeIndex = [array]::IndexOf($typePrecedence, $type)

                if ($currentTypeIndex -lt $currentInferredTypeIndex) {
                    $inferredType = $type
                }
            }
        }

        # Logic to only adopt a specific type if a majority of values can be converted to it.
        # For example, for datetime, only if 80% or more can be converted.
        if ($inferredType -eq 'datetime') {
            $datetimeConvertibleCount = ($values | Where-Object { $_ -as [datetime] }).Count
            if (($datetimeConvertibleCount / $values.Count) -lt 0.8) {
                $inferredType = 'string'
            }
        }

        # Add the inferred property name and its determined type to the schema hashtable.
        $schema[$name] = $inferredType
    }

    # Return the completed schema hashtable.
    return $schema
}
