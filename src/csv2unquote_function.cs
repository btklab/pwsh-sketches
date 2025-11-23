using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

/// <summary>
/// Provides functionality to strip double quotes from CSV lines while intelligently handling commas.
/// 
/// Transformation Rules:
/// 1. Double Quotes ("): Removed entirely.
/// 2. Commas inside quotes (Numeric): If surrounded by digits (e.g., "1,000"), the comma is removed.
/// 3. Commas inside quotes (Text): If not numeric (e.g., "City, State"), the comma is replaced with a dot (.).
/// 4. Newlines inside quotes: Ignored (the parser processes line-by-line strictly).
/// </summary>
public class CsvQuoteSanitizer
{
    /// <summary>
    /// Processes a single line of CSV text.
    /// Useful for pipeline processing where data streams line by line.
    /// </summary>
    /// <param name="inputLine">The raw CSV line.</param>
    /// <returns>The sanitized string.</returns>
    public string ProcessLine(string inputLine)
    {
        if (string.IsNullOrEmpty(inputLine))
        {
            return string.Empty;
        }

        return SanitizeRow(inputLine);
    }

    /// <summary>
    /// Processes an entire file from disk.
    /// This avoids the overhead of passing strings between PowerShell and C# repeatedly.
    /// </summary>
    /// <param name="filePath">The absolute path to the source file.</param>
    /// <returns>A list of sanitized strings.</returns>
    public static List<string> ProcessFile(string filePath)
    {
        var results = new List<string>();

        // Use StreamReader to handle large files without loading everything into memory at once
        using (var sr = new StreamReader(filePath))
        {
            string line;
            while ((line = sr.ReadLine()) != null)
            {
                results.Add(SanitizeRow(line));
            }
        }

        return results;
    }

    /// <summary>
    /// Core Logic: Iterates through characters to strip quotes and transform commas.
    /// </summary>
    private static string SanitizeRow(string line)
    {
        // Pre-allocate buffer with the same length to avoid memory reallocation resizing
        StringBuilder buffer = new StringBuilder(line.Length);
        
        bool isInsideQuote = false;

        for (int i = 0; i < line.Length; i++)
        {
            char currentChar = line[i];

            if (currentChar == '"')
            {
                // Toggle state. We do not append the quote to the buffer (stripping it).
                isInsideQuote = !isInsideQuote;
            }
            else if (currentChar == ',' && isInsideQuote)
            {
                // We are inside a quoted field. We must decide: Delete or Replace?
                if (IsDigitSeparator(line, i))
                {
                    // It is a number (e.g., "1,000"). 
                    // Do nothing. We effectively delete the comma by not appending it.
                }
                else
                {
                    // It is text (e.g., "Smith, John"). 
                    // Replace comma with a dot to preserve readability without breaking CSV structure.
                    buffer.Append('.'); 
                }
            }
            else
            {
                // Standard character or a delimiter outside of quotes. Keep as is.
                buffer.Append(currentChar);
            }
        }

        return buffer.ToString();
    }

    /// <summary>
    /// Heuristic: Determines if a comma at index [i] is a numeric thousands separator.
    /// Rule: A comma is numeric if the character immediately before AND after are digits.
    /// </summary>
    private static bool IsDigitSeparator(string text, int index)
    {
        // Boundary check: Comma cannot be the first or last character to be a separator
        if (index <= 0 || index >= text.Length - 1)
        {
            return false;
        }

        char prevChar = text[index - 1];
        char nextChar = text[index + 1];

        return char.IsDigit(prevChar) && char.IsDigit(nextChar);
    }
}
