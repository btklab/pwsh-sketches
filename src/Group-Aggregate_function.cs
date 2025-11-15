using System;
using System.Collections.Generic;
using System.Linq;

// A stateful class to handle stream-based aggregation
public class StreamAggregator {
    // Internal class to hold intermediate aggregation data for each group
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

    private readonly string[] _groupBy;
    private readonly string[] _aggregate;
    private readonly string _method;
    private readonly bool _count; // This flag indicates if an additional DataCount column should be added
    private readonly Dictionary<string, GroupData> _results;
    private const string keySeparator = "<|>";

    public StreamAggregator(string[] groupBy, string[] aggregate, string method, bool count = false) {
        _groupBy = groupBy;
        _aggregate = aggregate;
        _method = method;
        _count = count;
        _results = new Dictionary<string, GroupData>();
    }

    // Process a single row at a time
    public void AddRow(Dictionary<string, string> row) {
        var keyParts = _groupBy.Select(c => row.ContainsKey(c) ? row[c] : "").ToArray();
        var compositeKey = string.Join(keySeparator, keyParts);

        if (!_results.ContainsKey(compositeKey)) {
            _results[compositeKey] = new GroupData(keyParts, _aggregate);
        }

        var groupData = _results[compositeKey];
        groupData.Count++; // Increment count for this group

        // Only perform sum/min/max if the aggregation method is not "Count"
        if (_method != "Count") {
            foreach (var aggColumn in _aggregate) {
                if (row.ContainsKey(aggColumn) && double.TryParse(row[aggColumn], out var value)) {
                    groupData.Sums[aggColumn] += value;
                    if (value > groupData.MaxValues[aggColumn]) groupData.MaxValues[aggColumn] = value;
                    if (value < groupData.MinValues[aggColumn]) groupData.MinValues[aggColumn] = value;
                }
            }
        }
    }

    // Finalize the aggregation and return the results
    public List<Dictionary<string, object>> GetResult() {
        var finalResults = new List<Dictionary<string, object>>();

        foreach (var groupData in _results.Values) {
            if (groupData.Count == 0) continue; // Skip empty groups

            var resultRow = new Dictionary<string, object>();
            // Add group-by columns to the result row
            for (int i = 0; i < _groupBy.Length; i++) {
                resultRow[_groupBy[i]] = groupData.KeyParts[i];
            }

            // Handle the primary aggregation method (Sum, Average, Max, Min, or Count)
            if (_method == "Count") {
                // If the method is "Count", the primary aggregated value is the group count
                resultRow["Count"] = groupData.Count;
            } else {
                // For other methods, calculate based on sums, max, or min values
                foreach (var aggColumn in _aggregate) {
                    if (groupData.Sums.ContainsKey(aggColumn)) {
                        double result = 0;
                        switch (_method) {
                            case "Sum":     result = groupData.Sums[aggColumn]; break;
                            case "Average": result = groupData.Sums[aggColumn] / groupData.Count; break;
                            case "Max":     result = groupData.MaxValues[aggColumn]; break;
                            case "Min":     result = groupData.MinValues[aggColumn]; break;
                        }
                        //resultRow[aggColumn] = Math.Round(result, 2);
                        resultRow[aggColumn] = result; // Add the aggregated value
                    }
                }
            }

            // Add DataCount column if _count is true, regardless of the primary aggregation method.
            // This ensures DataCount is always present when requested, even if _method is "Count".
            if (_count == true) {
                resultRow["DataCount"] = groupData.Count;
            }

            finalResults.Add(resultRow);
        }
        return finalResults;
    }
}