using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation;     // Required for PSObject
using System.Collections.Specialized;  // Required for OrderedDictionary
using System.IO;                       // Required for high-speed file reading

namespace SummaryObjectProcessor
{
    /// <summary>
    /// Internal class to track statistics for a single property.
    /// This class uses an incremental approach for Sum, SumOfSquares, Min, and Max
    /// to avoid recalculating them on every object.
    /// It stores all values in a list *only* for quantile calculation,
    /// which requires sorting the entire dataset for that property.
    /// </summary>
    internal class PropertyStats
    {
        public long Count { get; private set; }
        public double Sum { get; private set; }
        public double SumOfSquares { get; private set; } // Used for Standard Deviation
        public double Min { get; private set; }
        public double Max { get; private set; }
        
        /// <summary>
        /// This list is the most memory-intensive part.
        /// It is necessary for calculating accurate quantiles (Median, Qt25, Qt75).
        /// </summary>
        public List<double> ValuesForQuantiles { get; private set; }

        public PropertyStats()
        {
            Count = 0;
            Sum = 0;
            SumOfSquares = 0;
            Min = double.MaxValue;
            Max = double.MinValue;
            ValuesForQuantiles = new List<double>();
        }

        /// <summary>
        /// Add a new value to the running statistics.
        /// </summary>
        public void AddValue(double value)
        {
            Count++;
            Sum += value;
            SumOfSquares += value * value;
            if (value < Min) Min = value;
            if (value > Max) Max = value;
            ValuesForQuantiles.Add(value);
        }
    }

    /// <summary>
    /// Main aggregator class that manages the statistics for all properties.
    /// This is instantiated by CsvSummaryProcessor and used for both
    /// pipeline and file-based processing.
    /// </summary>
    public class StatisticsAggregator
    {
        // A dictionary mapping property names (e.g., "carat", "depth")
        // to their corresponding statistics-tracking object.
        private readonly Dictionary<string, PropertyStats> _stats;
        
        // Holds the specific properties to summarize.
        // If empty or null, auto-detection mode is enabled.
        private readonly string[] _explicitProperties;
        
        // Tracks whether we have processed the first object/row yet.
        // Used for auto-detecting numeric properties.
        private bool _firstRowProcessed;
        
        // A set of property names that were identified as numeric.
        // This is populated either by _explicitProperties or by auto-detection.
        private readonly HashSet<string> _numericPropertiesToTrack;

        /// <summary>
        /// Constructor: Initializes the aggregator.
        /// </summary>
        /// <param name="properties">User-specified properties, or null for auto-detect.</param>
        public StatisticsAggregator(string[] properties)
        {
            _stats = new Dictionary<string, PropertyStats>(StringComparer.OrdinalIgnoreCase);
            _numericPropertiesToTrack = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            _firstRowProcessed = false;

            // If the user provided specific properties, store them.
            if (properties != null && properties.Length > 0)
            {
                _explicitProperties = properties;
                // Pre-populate the tracking set with the user's choices.
                foreach (var prop in properties)
                {
                    _numericPropertiesToTrack.Add(prop);
                }
            }
            else
            {
                // No properties provided, so enable auto-detection.
                _explicitProperties = null;
            }
        }

        /// <summary>
        /// Public accessor for the CsvSummaryProcessor to discover which
        /// properties were selected by the auto-detection logic.
        /// </summary>
        public HashSet<string> GetTrackedProperties()
        {
            return _numericPropertiesToTrack;
        }

        /// <summary>
        /// Processes a single PSObject from the pipeline.
        /// This is a wrapper that converts the PSObject to a standard dictionary
        /// and calls the common ProcessRow method.
        /// </summary>
        public void AddObject(PSObject obj)
        {
            if (obj == null) return;
            
            // Convert PSObject to a dictionary for the common processing logic
            var row = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);
            foreach (var propInfo in obj.Properties)
            {
                if (propInfo.Value != null)
                {
                    row[propInfo.Name] = propInfo.Value.ToString();
                }
            }
            
            ProcessRow(row);
        }

        /// <summary>
        /// Core logic for processing a single row of data, represented as a dictionary.
        /// This is called by both AddObject (pipeline mode) and ProcessFile (file mode).
        /// </summary>
        public void ProcessRow(Dictionary<string, string> row)
        {
            if (row == null) return;

            // --- Auto-detection logic (if needed) ---
            // If this is the first row AND no explicit properties were given,
            // we inspect this row to decide which properties to track.
            if (!_firstRowProcessed && _explicitProperties == null)
            {
                foreach (var kvp in row)
                {
                    if (kvp.Value == null) continue;
                    
                    // Try to parse the value as a double.
                    // If it succeeds, we'll track this property.
                    if (double.TryParse(kvp.Value, out _))
                    {
                        _numericPropertiesToTrack.Add(kvp.Key);
                    }
                }
            }
            _firstRowProcessed = true;
            
            // --- Data Aggregation ---
            // Iterate over the set of properties we've decided to track.
            foreach (var propName in _numericPropertiesToTrack)
            {
                // Check if the row contains the property we're looking for.
                if (!row.ContainsKey(propName) || row[propName] == null) continue;

                // Try to parse the value.
                if (double.TryParse(row[propName], out double value))
                {
                    // If the property isn't in our statistics dictionary, add it.
                    if (!_stats.ContainsKey(propName))
                    {
                        _stats[propName] = new PropertyStats();
                    }
                    
                    // Add the parsed value to its tracking object.
                    _stats[propName].AddValue(value);
                }
            }
        }

        /// <summary>
        /// Called in the 'end' block after all objects/rows are processed.
        /// This performs the final calculations (sorting, quantiles).
        /// </summary>
        /// <returns>A list of OrderedDictionary objects, each representing a summary row.</returns>
        public List<OrderedDictionary> GetResult()
        {
            var finalResults = new List<OrderedDictionary>();

            // Iterate through each property we've tracked.
            foreach (var kvp in _stats.OrderBy(kv => kv.Key)) // Sort by property name
            {
                string propertyName = kvp.Key;
                PropertyStats stats = kvp.Value;

                if (stats.Count == 0) continue; // Skip empty properties.

                var resultRow = new OrderedDictionary();
                
                // Add "Property" first to ensure it's the first column.
                resultRow["Property"] = propertyName;
                resultRow["Count"] = stats.Count;
                resultRow["Mean"] = stats.Sum / stats.Count;

                // Calculate Standard Deviation (Sample).
                if (stats.Count > 1)
                {
                    // Formula: sqrt( (Sum(x^2) - (Sum(x)^2 / N)) / (N-1) )
                    double variance = (stats.SumOfSquares - (stats.Sum * stats.Sum) / stats.Count) / (stats.Count - 1);
                    resultRow["SD"] = Math.Sqrt(variance);
                }
                else
                {
                    resultRow["SD"] = 0.0; // Standard deviation is 0 for a single point
                }

                resultRow["Min"] = stats.Min;

                // --- Quantile and Outlier Calculation ---
                // Sort the list of values *once* for this property.
                var sortedValues = stats.ValuesForQuantiles.OrderBy(x => x).ToList();

                // Calculate quantiles using linear interpolation.
                double qt25 = GetQuantile(sortedValues, 0.25);
                double median = GetQuantile(sortedValues, 0.50);
                double qt75 = GetQuantile(sortedValues, 0.75);

                resultRow["Qt25"] = qt25;
                resultRow["Median"] = median;
                resultRow["Qt75"] = qt75;
                resultRow["Max"] = stats.Max; // Max was already tracked incrementally.

                // Calculate Outliers using the IQR (Interquartile Range) method.
                // Outliers are values < (Qt25 - 1.5*IQR) or > (Qt75 + 1.5*IQR).
                double iqr = qt75 - qt25;
                double lowerBound = qt25 - 1.5 * iqr;
                double upperBound = qt75 + 1.5 * iqr;

                // Use LINQ .Count() to find outliers.
                long outlierCount = sortedValues.Count(x => x < lowerBound || x > upperBound);
                resultRow["Outlier"] = outlierCount;

                finalResults.Add(resultRow);
            }

            return finalResults;
        }

        /// <summary>
        /// Helper function to calculate a quantile from a *sorted* list.
        /// Uses the "linear interpolation" method (matches Excel, R type 7).
        /// </summary>
        private double GetQuantile(List<double> sortedList, double quantile)
        {
            if (sortedList.Count == 0) return 0.0;
            
            // Calculate the (0-based) real-valued index.
            double realIndex = quantile * (sortedList.Count - 1);
            int index = (int)realIndex;
            double fraction = realIndex - index; // The fractional part

            // If we're at the end or no fraction, just return the value.
            if ((index + 1) >= sortedList.Count || fraction == 0)
            {
                return sortedList[index];
            }

            // Interpolate between the two surrounding values.
            return sortedList[index] * (1 - fraction) + sortedList[index + 1] * fraction;
        }
    }

    /// <summary>
    /// Public-facing static class providing high-speed CSV processing
    /// and factory methods for PowerShell.
    /// </summary>
    public static class CsvSummaryProcessor
    {
        /// <summary>
        /// Creates a new StatisticsAggregator instance.
        /// Used by PowerShell for the pipeline processing mode.
        /// </summary>
        public static StatisticsAggregator CreateAggregator(string[] properties)
        {
            return new StatisticsAggregator(properties);
        }

        /// <summary>
        /// Processes an entire CSV file directly from disk.
        /// This is the high-performance path that bypasses PowerShell's Import-Csv.
        /// </summary>
        /// <param name="filePath">The full path to the CSV file.</param>
        /// <param name="properties">User-specified properties, or null for auto-detect.</param>
        /// <returns>The final aggregated list of results.</returns>
        public static List<OrderedDictionary> ProcessFile(string filePath, string[] properties)
        {
            // 1. Instantiate the same stateful aggregator used by the pipeline mode
            var aggregator = new StatisticsAggregator(properties);
            bool isAutoDetect = (properties == null || properties.Length == 0);

            using (var sr = new StreamReader(filePath))
            {
                // 2. Read and parse the header row
                var headerLine = sr.ReadLine();
                if (headerLine == null)
                {
                    return aggregator.GetResult(); // Handle empty file
                }
                
                // NOTE: Assumes a simple CSV (no commas in quoted fields) for max performance.
                var headers = headerLine.Split(',');
                
                // Create a reusable dictionary to hold row data
                var rowDict = new Dictionary<string, string>(StringComparer.OrdinalIgnoreCase);

                // This list will hold the (ColumnName, ColumnIndex) tuples we need to read.
                List<Tuple<string, int>> requiredColumnInfo = null;

                // 3. Process data rows
                string line;
                while ((line = sr.ReadLine()) != null)
                {
                    var parts = line.Split(',');
                    rowDict.Clear();

                    // --- Column Selection Logic ---
                    if (requiredColumnInfo == null)
                    {
                        // This is the first data row. We must determine which columns to read.
                        if (isAutoDetect)
                        {
                            // Auto-detect mode: We must read *all* columns for this *first* row
                            // so the aggregator can perform its auto-detection.
                            for (int i = 0; i < headers.Length; i++)
                            {
                                if (i < parts.Length)
                                {
                                    rowDict[headers[i]] = parts[i];
                                }
                            }
                            
                            // Process the full row to trigger auto-detection
                            aggregator.ProcessRow(rowDict);

                            // Now, get the list of properties the aggregator *chose* to track
                            var trackedProps = aggregator.GetTrackedProperties();
                            requiredColumnInfo = new List<Tuple<string, int>>();
                            for(int i = 0; i < headers.Length; i++)
                            {
                                if(trackedProps.Contains(headers[i]))
                                {
                                    requiredColumnInfo.Add(new Tuple<string, int>(headers[i], i));
                                }
                            }
                            
                            // This row is processed, continue to the next line
                            continue; 
                        }
                        else
                        {
                            // Explicit property mode: We build the requiredColumnInfo list once
                            // based on the user's -Property parameter.
                            var propSet = aggregator.GetTrackedProperties(); // Already populated by constructor
                            requiredColumnInfo = new List<Tuple<string, int>>();
                            for(int i = 0; i < headers.Length; i++)
                            {
                                if(propSet.Contains(headers[i]))
                                {
                                    requiredColumnInfo.Add(new Tuple<string, int>(headers[i], i));
                                }
                            }
                        }
                    }
                    
                    // --- Efficient Row Population ---
                    // For all subsequent rows (or all rows in explicit mode),
                    // we only parse and store the columns we absolutely need.
                    foreach (var colInfo in requiredColumnInfo)
                    {
                        // colInfo.Item1 = ColumnName (string)
                        // colInfo.Item2 = ColumnIndex (int)
                        if (colInfo.Item2 < parts.Length)
                        {
                            rowDict[colInfo.Item1] = parts[colInfo.Item2];
                        }
                    }
                    
                    // Pass the efficiently-built row to the aggregator
                    aggregator.ProcessRow(rowDict);
                }
            }

            // 4. All lines processed, return the final result
            return aggregator.GetResult();
        }
    }
}
