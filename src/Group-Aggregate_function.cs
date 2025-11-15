using System;
using System.Collections.Generic;
using System.Linq;
using System.IO; // Required for high-speed file reading

/// <summary>
/// A stateful class to handle stream-based aggregation.
/// This class is designed to be instantiated once and process rows incrementally.
/// It's marked 'public' so it can be returned to PowerShell.
/// </summary>
public class StreamAggregator {
    
    /// <summary>
    /// Internal class to hold intermediate aggregation data for each group.
    /// This avoids repeatedly recalculating values.
    /// </summary>
    private class GroupData {
        public long Count = 0;
        public Dictionary<string, double> Sums = new Dictionary<string, double>();
        public Dictionary<string, double> MaxValues = new Dictionary<string, double>();
        public Dictionary<string, double> MinValues = new Dictionary<string, double>();
        public readonly string[] KeyParts; // Store the original group-by values

        public GroupData(string[] keyParts, string[] aggregateColumns) {
            KeyParts = keyParts;
            foreach (var col in aggregateColumns) {
                Sums[col] = 0;
                MaxValues[col] = double.MinValue;
                MinValues[col] = double.MaxValue;
            }
        }
    }

    // Configuration fields set at initialization
    private readonly string[] _groupBy;
    private readonly string[] _aggregate;
    private readonly string _method;
    private readonly bool _count; // Flag to add an additional "DataCount" column
    
    // State field: This dictionary holds all aggregated data in memory.
    private readonly Dictionary<string, GroupData> _results;
    
    // Constant for creating composite keys in the dictionary.
    private const string keySeparator = "<|>";

    public StreamAggregator(string[] groupBy, string[] aggregate, string method, bool count = false) {
        _groupBy = groupBy;
        _aggregate = aggregate;
        _method = method;
        _count = count;
        _results = new Dictionary<string, GroupData>();
    }

    /// <summary>
    /// Processes a single row of data.
    /// This is the core logic that updates the aggregation state.
    /// </summary>
    /// <param name="row">A dictionary representing one row (ColumnName -> Value)</param>
    public void AddRow(Dictionary<string, string> row) {
        // 1. Determine the group for this row
        //    We create a composite key (e.g., "Sales<|>North") from the GroupBy columns.
        var keyParts = _groupBy.Select(c => row.ContainsKey(c) ? row[c] : "").ToArray();
        var compositeKey = string.Join(keySeparator, keyParts);

        // 2. Find or create the state object for this group
        if (!_results.ContainsKey(compositeKey)) {
            _results[compositeKey] = new GroupData(keyParts, _aggregate);
        }
        var groupData = _results[compositeKey];

        // 3. Update the group's state
        groupData.Count++; // Always increment the row count for the group

        // 4. Perform numerical aggregations (Sum, Max, Min)
        //    This is skipped if the method is "Count" to save processing time.
        if (_method != "Count") {
            foreach (var aggColumn in _aggregate) {
                // Ensure column exists and value is a valid number
                if (row.ContainsKey(aggColumn) && double.TryParse(row[aggColumn], out var value)) {
                    // Update all possible aggregation types simultaneously.
                    // This is efficient as we only parse the value once.
                    groupData.Sums[aggColumn] += value;
                    if (value > groupData.MaxValues[aggColumn]) groupData.MaxValues[aggColumn] = value;
                    if (value < groupData.MinValues[aggColumn]) groupData.MinValues[aggColumn] = value;
                }
            }
        }
    }

    /// <summary>
    /// Finalizes the aggregation and returns the complete result set.
    /// </summary>
    /// <returns>A list of dictionaries, where each dictionary is a result row.</returns>
    public List<Dictionary<string, object>> GetResult() {
        var finalResults = new List<Dictionary<string, object>>();

        foreach (var groupData in _results.Values) {
            if (groupData.Count == 0) continue; // Skip groups that were created but had no data

            var resultRow = new Dictionary<string, object>();
            
            // Add group-by columns (e.g., "Department" = "Sales")
            for (int i = 0; i < _groupBy.Length; i++) {
                resultRow[_groupBy[i]] = groupData.KeyParts[i];
            }

            // Calculate and add the primary aggregated values
            if (_method == "Count") {
                resultRow["Count"] = groupData.Count;
            } else {
                foreach (var aggColumn in _aggregate) {
                    if (groupData.Sums.ContainsKey(aggColumn)) {
                        double result = 0;
                        switch (_method) {
                            case "Sum":     result = groupData.Sums[aggColumn]; break;
                            case "Average": result = groupData.Sums[aggColumn] / groupData.Count; break;
                            case "Max":     result = groupData.MaxValues[aggColumn]; break;
                            case "Min":     result = groupData.MinValues[aggColumn]; break;
                        }
                        resultRow[aggColumn] = result;
                    }
                }
            }

            // Add the optional "DataCount" column if requested
            if (_count == true) {
                resultRow["DataCount"] = groupData.Count;
            }

            finalResults.Add(resultRow);
        }
        return finalResults;
    }
}


/// <summary>
/// Public-facing class providing high-speed CSV processing.
/// This class contains the main entry points called from PowerShell.
/// </summary>
public static class CsvProcessor
{
    /// <summary>
    /// Creates a new StreamAggregator instance.
    /// Used by PowerShell for the pipeline processing mode.
    /// </summary>
    public static StreamAggregator CreateAggregator(string[] groupBy, string[] aggregate, string method, bool count)
    {
        return new StreamAggregator(groupBy, aggregate, method, count);
    }

    /// <summary>
    /// Processes an entire CSV file directly from disk.
    /// This is the high-performance path that bypasses PowerShell's Import-Csv.
    /// </summary>
    /// <param name="filePath">The full path to the CSV file.</param>
    /// <returns>The final aggregated list of results.</returns>
    public static List<Dictionary<string, object>> ProcessFile(string filePath, string[] groupBy, string[] aggregate, string method, bool count)
    {
        // Instantiate the same stateful aggregator used by the pipeline mode
        var aggregator = new StreamAggregator(groupBy, aggregate, method, count);

        // Use a high-speed StreamReader to read the file line by line
        using (var sr = new StreamReader(filePath))
        {
            // Read the header row
            var headerLine = sr.ReadLine();
            if (headerLine == null)
            {
                // Handle empty file
                return aggregator.GetResult();
            }

            // Parse header and create a map of "ColumnName" -> index (e.g., "Salary" -> 3)
            // NOTE: This is a basic CSV parser. It will not handle commas inside quotes.
            // For max performance, we assume a simple, well-formed CSV.
            var headers = headerLine.Split(',');
            var headerMap = new Dictionary<string, int>();
            for(int i = 0; i < headers.Length; i++)
            {
                headerMap[headers[i]] = i;
            }

            // Create a single dictionary to re-use for each row
            // This avoids allocating a new dictionary for every line
            var rowDict = new Dictionary<string, string>();
            
            // Get all columns we *must* read
            var allRequiredColumns = new HashSet<string>(groupBy);
            if(method != "Count") 
            {
                allRequiredColumns.UnionWith(aggregate);
            }
            
            // Convert column names to their integer indices for fast lookup
            var requiredIndices = new List<Tuple<string, int>>();
            foreach(var colName in allRequiredColumns)
            {
                if(!headerMap.ContainsKey(colName)) {
                    // Throw a specific error if a required column is missing
                    throw new KeyNotFoundException($"The column '{colName}' was not found in the CSV file header.");
                }
                requiredIndices.Add(new Tuple<string, int>(colName, headerMap[colName]));
            }


            string line;
            // Read the file line by line until the end
            while ((line = sr.ReadLine()) != null)
            {
                // NOTE: Again, assumes no quoted commas for speed.
                var parts = line.Split(',');
                
                // Clear the reusable dictionary
                rowDict.Clear();

                // Populate the dictionary *only* with the columns we need
                foreach(var colInfo in requiredIndices)
                {
                    // colInfo.Item1 = ColumnName (string)
                    // colInfo.Item2 = ColumnIndex (int)
                    if (colInfo.Item2 < parts.Length)
                    {
                        rowDict[colInfo.Item1] = parts[colInfo.Item2];
                    }
                }
                
                // Pass the efficiently-built row to the aggregator
                aggregator.AddRow(rowDict);
            }
        }

        // All lines processed, return the final result
        return aggregator.GetResult();
    }
}