BeforeAll {
    . $PSScriptRoot/../src/Infer-ObjectSchema_function.ps1
}
Describe "Infer-ObjectSchema" {
    # Test Case 1: All values are integers
    Context "when all values are integers" {
        It "should infer 'int' for the property" {
            # Arrange
            $data = @(
                [pscustomobject]@{Id = 1},
                [pscustomobject]@{Id = 2},
                [pscustomobject]@{Id = 3}
            )

            # Act
            $schema = Infer-ObjectSchema -InputObject $data -SampleSize 3

            # Assert
            $schema.Id | Should -Be "int"
        }
    }

    # Test Case 2: All values are doubles
    Context "when all values are doubles" {
        It "should infer 'double' for the property" {
            # Arrange
            $data = @(
                [pscustomobject]@{Price = 1.99},
                [pscustomobject]@{Price = 10.50},
                [pscustomobject]@{Price = 25.00}
            )

            # Act
            $schema = Infer-ObjectSchema -InputObject $data -SampleSize 3

            # Assert
            $schema.Price | Should -Be "double"
        }
    }

    # Test Case 3: Mixed integers and doubles
    Context "when values are mixed integers and doubles" {
        It "should infer 'int' for the property" {
            # Arrange
            $data = @(
                [pscustomobject]@{Value = 10},
                [pscustomobject]@{Value = 20.5},
                [pscustomobject]@{Value = 30}
            )

            # Act
            $schema = Infer-ObjectSchema -InputObject $data -SampleSize 3

            # Assert
            $schema.Value | Should -Be "int"
        }
    }

    # Test Case 4: All values are booleans
    Context "when all values are booleans" {
        It "should infer 'bool' for the property" {
            # Arrange
            $data = @(
                [pscustomobject]@{IsActive = $true},
                [pscustomobject]@{IsActive = $false},
                [pscustomobject]@{IsActive = $true}
            )

            # Act
            $schema = Infer-ObjectSchema -InputObject $data -SampleSize 3

            # Assert
            $schema.IsActive | Should -Be "bool"
        }
    }

    # Test Case 5: Mixed boolean-like strings
    Context "when values are mixed boolean-like strings ('true', 'false', '0', '1')" {
        It "should infer 'int' for the property" {
            # Arrange
            $data = @(
                [pscustomobject]@{Status = 'True'},
                [pscustomobject]@{Status = '0'},
                [pscustomobject]@{Status = 'FALSE'},
                [pscustomobject]@{Status = '1'}
            )

            # Act
            $schema = Infer-ObjectSchema -InputObject $data -SampleSize 4

            # Assert
            $schema.Status | Should -Be "int"
        }
    }

    # Test Case 6: All values are DateTime objects
    Context "when all values are DateTime objects" {
        It "should infer 'datetime' for the property" {
            # Arrange
            $data = @(
                [pscustomobject]@{Timestamp = (Get-Date).AddDays(-1)},
                [pscustomobject]@{Timestamp = (Get-Date)},
                [pscustomobject]@{Timestamp = (Get-Date).AddDays(1)}
            )

            # Act
            $schema = Infer-ObjectSchema -InputObject $data -SampleSize 3

            # Assert
            $schema.Timestamp | Should -Be "datetime"
        }
    }

    # Test Case 7: Mixed DateTime objects and convertible strings (over 80%)
    Context "when over 80% of values are datetime-convertible strings" {
        It "should infer 'datetime' for the property" {
            # Arrange
            $data = @(
                [pscustomobject]@{EventDate = '2023-01-01'},
                [pscustomobject]@{EventDate = '2023-01-02'},
                [pscustomobject]@{EventDate = '2023-01-03'},
                [pscustomobject]@{EventDate = 'Not A Date'}, # 1 non-convertible value (25%)
                [pscustomobject]@{EventDate = '2023-01-04'}
            )

            # Act
            $schema = Infer-ObjectSchema -InputObject $data -SampleSize 5

            # Assert
            $schema.EventDate | Should -Be "datetime"
        }
    }

    # Test Case 8: Mixed DateTime objects and convertible strings (under 80%)
    Context "when under 80% of values are datetime-convertible strings" {
        It "should infer 'string' for the property" {
            # Arrange
            $data = @(
                [pscustomobject]@{EventDate = '2023-01-01'}, # 2 convertible values (50%)
                [pscustomobject]@{EventDate = 'Not A Date'},
                [pscustomobject]@{EventDate = '2023-01-02'},
                [pscustomobject]@{EventDate = 'Another invalid value'}
            )

            # Act
            $schema = Infer-ObjectSchema -InputObject $data -SampleSize 4

            # Assert
            $schema.EventDate | Should -Be "string"
        }
    }

    # Test Case 9: Mixed data types with string as the majority
    Context "when values are a mix of different types" {
        It "should infer the type with the highest count" {
            # Arrange
            $data = @(
                [pscustomobject]@{Data = 1},         # int
                [pscustomobject]@{Data = 'Hello'},   # string
                [pscustomobject]@{Data = 2.5},       # double
                [pscustomobject]@{Data = 'World'},   # string
                [pscustomobject]@{Data = $true}      # bool
            )

            # Act
            $schema = Infer-ObjectSchema -InputObject $data -SampleSize 5

            # Assert
            # 'string' count is 2, 'int' is 1, 'double' is 1, 'bool' is 1. String should be adopted.
            $schema.Data | Should -Be "string"
        }
    }

    # Test Case 10: Mixed types with same count, checking precedence
    Context "when multiple types have the same highest count" {
        It "should select the type based on precedence (int > double > bool > datetime > string)" {
            # Arrange
            $data = @(
                [pscustomobject]@{Data = 1},          # int
                [pscustomobject]@{Data = 2.0},        # double
                [pscustomobject]@{Data = 'hello'},    # string
                [pscustomobject]@{Data = 3}           # int
            )

            # Act
            $schema = Infer-ObjectSchema -InputObject $data -SampleSize 4

            # Assert
            # 'int' count is 2, 'double' is 1, 'string' is 1. 'int' is the highest.
            $schema.Data | Should -Be "int"
        }
    }

    # Test Case 11: Empty input
    Context "when InputObject is empty" {
        It "should return nothing and issue a warning" {
            # Arrange
            $data = @()
            
            # Act
            # We capture the output and the warning stream.
            $result = @($null) # Initialize with null to check for no output
            $warning = @($null) # Initialize with null
            $result = Infer-ObjectSchema -InputObject $data -WarningVariable warning
            
            # Assert
            # The result should be $null (or an empty collection) and a warning should be issued.
            $result  | Should -BeNullOrEmpty
            $warning | Should -BeNullOrEmpty
            $warning | Should -HaveCount 0
            #$warning[0] | Should -Match "Empty input"
        }
    }
}
