using System;
using System.Collections.Generic;
using System.IO;
using System.Text;

/// <summary>
/// Provides functionality to convert CSV (Comma-Separated Values) to SSV (Space-Separated Values).
/// This class handles both stream-based processing (for pipelines) and file-based processing.
/// </summary>
public class CsvToSsvConverter
{
    // Configuration: What string to use when a field is empty (e.g., "_", "0", "NA")
    private readonly string _nullPlaceholder;

    // State: Accumulates text across multiple lines if a CSV field contains a newline inside quotes.
    private StringBuilder _lineBuffer;
    
    // State: Tracks if we are currently inside a double-quoted field.
    private bool _inQuote;

    /// <summary>
    /// Initializes a new instance of the converter with a specific placeholder for empty values.
    /// </summary>
    /// <param name="nullPlaceholder">The string to use for empty CSV fields.</param>
    public CsvToSsvConverter(string nullPlaceholder)
    {
        _nullPlaceholder = nullPlaceholder;
        _lineBuffer = new StringBuilder();
        _inQuote = false;
    }

    /// <summary>
    /// Processes a single line of input from the PowerShell pipeline.
    /// If a CSV row spans multiple lines (due to newlines inside quotes), this method
    /// buffers the input and returns null until the row is complete.
    /// </summary>
    /// <param name="inputLine">A single line of text from the input.</param>
    /// <returns>The converted SSV string, or null if waiting for more lines to complete the CSV row.</returns>
    public string ProcessLine(string inputLine)
    {
        // If we are continuing a quoted field from the previous line, 
        // append the strictly escaped newline character "\n" as per requirements.
        if (_inQuote)
        {
            _lineBuffer.Append("\\n");
        }

        // Iterate through the characters to track quote state and build the buffer
        for (int i = 0; i < inputLine.Length; i++)
        {
            char c = inputLine[i];
            _lineBuffer.Append(c);

            if (c == '"')
            {
                _inQuote = !_inQuote; // Toggle state
            }
        }

        // If we are still inside a quote, we cannot process the row yet.
        // We return null to indicate we need the next line from the pipeline.
        if (_inQuote)
        {
            return null; 
        }

        // The row is complete. Parse, transform, and clear the buffer.
        string completeRow = _lineBuffer.ToString();
        _lineBuffer.Clear();

        return ConvertRowToSsv(completeRow, _nullPlaceholder);
    }

    /// <summary>
    /// High-performance method to process an entire file directly.
    /// This avoids the overhead of passing strings between PowerShell and C# for every line.
    /// </summary>
    /// <param name="filePath">Path to the source CSV file.</param>
    /// <param name="nullPlaceholder">The string to use for empty CSV fields.</param>
    /// <returns>A list of converted SSV strings.</returns>
    public static List<string> ProcessFile(string filePath, string nullPlaceholder)
    {
        var results = new List<string>();
        
        // Use StreamReader for memory-efficient reading of large files
        using (var sr = new StreamReader(filePath))
        {
            string line;
            var buffer = new StringBuilder();
            bool inQuote = false;

            while ((line = sr.ReadLine()) != null)
            {
                if (inQuote)
                {
                    buffer.Append("\\n");
                }

                // Analyze quotes in the current line
                foreach (char c in line)
                {
                    buffer.Append(c);
                    if (c == '"')
                    {
                        inQuote = !inQuote;
                    }
                }

                // If the CSV row is closed (even number of quotes), process it immediately
                if (!inQuote)
                {
                    results.Add(ConvertRowToSsv(buffer.ToString(), nullPlaceholder));
                    buffer.Clear();
                }
                // If inQuote is true, the loop continues to the next ReadLine() 
                // to append the rest of the cell.
            }
        }
        return results;
    }

    /// <summary>
    /// Core Logic: Parses a raw CSV row and transforms it into the target SSV format.
    /// </summary>
    private static string ConvertRowToSsv(string csvRow, string nullPlaceholder)
    {
        var fields = ParseCsv(csvRow);
        var ssvBuilder = new StringBuilder();

        for (int i = 0; i < fields.Count; i++)
        {
            if (i > 0) ssvBuilder.Append(' '); // Space delimiter

            string field = fields[i];

            // Requirement: Empty fields are represented by the placeholder (default "_")
            if (string.IsNullOrEmpty(field))
            {
                ssvBuilder.Append(nullPlaceholder);
            }
            else
            {
                // Apply the specific character escaping rules defined in the requirements
                var transformed = new StringBuilder(field.Length + 5);
                foreach (char c in field)
                {
                    switch (c)
                    {
                        case '\\':
                            transformed.Append(@"\\"); // "\" convert to "\\"
                            break;
                        case '_':
                            transformed.Append(@"\_"); // "_" convert to "\_"
                            break;
                        case ' ':
                            transformed.Append('_');   // Space convert to "_"
                            break;
                        default:
                            transformed.Append(c);
                            break;
                    }
                }
                ssvBuilder.Append(transformed.ToString());
            }
        }

        return ssvBuilder.ToString();
    }

    /// <summary>
    /// Parses a single CSV line into a list of fields.
    /// Handles quoted fields and escaped quotes ("") correctly.
    /// </summary>
    private static List<string> ParseCsv(string line)
    {
        var fields = new List<string>();
        var currentField = new StringBuilder();
        bool insideQuote = false;

        for (int i = 0; i < line.Length; i++)
        {
            char c = line[i];

            if (insideQuote)
            {
                if (c == '"')
                {
                    // Check for double double-quotes (escaped quote)
                    if (i + 1 < line.Length && line[i + 1] == '"')
                    {
                        currentField.Append('"');
                        i++; // Skip the next quote
                    }
                    else
                    {
                        insideQuote = false; // End of quoted field
                    }
                }
                else
                {
                    currentField.Append(c);
                }
            }
            else
            {
                if (c == ',')
                {
                    // End of field
                    fields.Add(currentField.ToString());
                    currentField.Clear();
                }
                else if (c == '"')
                {
                    insideQuote = true; // Start of quoted field
                }
                else
                {
                    currentField.Append(c);
                }
            }
        }
        
        // Add the last field
        fields.Add(currentField.ToString());

        return fields;
    }
}
