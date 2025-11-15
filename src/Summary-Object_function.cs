using System;
using System.Collections.Generic;
using System.Linq;
using System.Management.Automation; // Required for PSObject
using System.Collections.Specialized; // Added for OrderedDictionary

namespace SummaryObject
{
    // Internal class to track statistics for a single property.
    // This class uses an incremental approach for Sum, SumOfSquares, Min, and Max
    // to avoid recalculating them on every object.
    // It stores all values in a list *only* for quantile calculation,
    // which requires sorting the entire dataset for that property.
    internal class PropertyStats
    {
        public long Count { get; private set; }
        public double Sum { get; private set; }
        public double SumOfSquares { get; private set; } // Used for Standard Deviation
        public double Min { get; private set; }
        public double Max { get; private set; }
        
        // This list is the most memory-intensive part.
        // It is necessary for calculating accurate quantiles (Median, Qt25, Qt75).
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

        // Add a new value to the running statistics.
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

    // Main aggregator class that manages the statistics for all properties.
    // This is the object instantiated in the 'begin' block.
    public class StatisticsAggregator
    {
        // A dictionary mapping property names (e.g., "carat", "depth")
        // to their corresponding statistics-tracking object.
        private readonly Dictionary<string, PropertyStats> _stats;
        
        // Holds the specific properties to summarize.
        // If empty, auto-detection mode is enabled.
        private readonly string[] _explicitProperties;
        
        // Tracks whether we have processed the first object yet.
        // Used for auto-detecting numeric properties.
        private bool _firstObjectProcessed;
        
        // A set of property names that were identified as numeric.
        private readonly HashSet<string> _numericPropertiesToTrack;

        // Constructor: Initializes the aggregator.
        public StatisticsAggregator(string[] properties)
        {
            _stats = new Dictionary<string, PropertyStats>(StringComparer.OrdinalIgnoreCase);
            _numericPropertiesToTrack = new HashSet<string>(StringComparer.OrdinalIgnoreCase);
            _firstObjectProcessed = false;

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

        // Processes a single PSObject from the pipeline.
        public void AddObject(PSObject obj)
        {
            if (obj == null) return;

            // --- Auto-detection logic (if needed) ---
            // If this is the first object AND no explicit properties were given,
            // we inspect this object to decide which properties to track.
            if (!_firstObjectProcessed && _explicitProperties == null)
            {
                foreach (var propInfo in obj.Properties)
                {
                    if (propInfo.Value == null) continue;
                    
                    // Try to parse the value as a double.
                    // If it succeeds, we'll track this property.
                    if (double.TryParse(propInfo.Value.ToString(), out _))
                    {
                        _numericPropertiesToTrack.Add(propInfo.Name);
                    }
                }
            }
            _firstObjectProcessed = true;
            
            // --- Data Aggregation ---
            // Iterate over the set of properties we've decided to track.
            foreach (var propName in _numericPropertiesToTrack)
            {
                var prop = obj.Properties[propName];
                if (prop == null || prop.Value == null) continue;

                // Try to parse the value.
                if (double.TryParse(prop.Value.ToString(), out double value))
                {
                    // If the property isn't in our dictionary, add it.
                    if (!_stats.ContainsKey(propName))
                    {
                        _stats[propName] = new PropertyStats();
                    }
                    
                    // Add the parsed value to its tracking object.
                    _stats[propName].AddValue(value);
                }
            }
        }

        // Called in the 'end' block after all objects are processed.
        // This performs the final LINQ calculations (sorting, quantiles).
        // Return type changed to List<OrderedDictionary> to guarantee property order.
        public List<OrderedDictionary> GetResult()
        {
            // Changed to List<OrderedDictionary>
            var finalResults = new List<OrderedDictionary>();

            // Iterate through each property we've tracked.
            foreach (var kvp in _stats)
            {
                string propertyName = kvp.Key;
                PropertyStats stats = kvp.Value;

                if (stats.Count == 0) continue; // Skip empty properties.

                // Changed to OrderedDictionary
                var resultRow = new OrderedDictionary();
                
                // Add "Property" first to ensure it's the first column.
                resultRow["Property"] = propertyName;
                resultRow["Count"] = stats.Count;
                resultRow["Mean"] = stats.Sum / stats.Count;

                // Calculate Standard Deviation (Sample).
                // Uses the incremental Sum and SumOfSquares.
                if (stats.Count > 1)
                {
                    // Formula: sqrt( (Sum(x^2) - (Sum(x)^2 / N)) / (N-1) )
                    double variance = (stats.SumOfSquares - (stats.Sum * stats.Sum) / stats.Count) / (stats.Count - 1);
                    resultRow["SD"] = Math.Sqrt(variance);
                }
                else
                {
                    resultRow["SD"] = 0.0;
                }

                resultRow["Min"] = stats.Min;

                // --- Quantile and Outlier Calculation (LINQ) ---
                // This is the LINQ-heavy part. We sort the list once.
                var sortedValues = stats.ValuesForQuantiles.OrderBy(x => x).ToList();

                // Calculate quantiles using linear interpolation.
                double qt25 = GetQuantile(sortedValues, 0.25);
                double median = GetQuantile(sortedValues, 0.50);
                double qt75 = GetQuantile(sortedValues, 0.75);

                resultRow["Qt25"] = qt25;
                resultRow["Median"] = median;
                resultRow["Qt75"] = qt75;
                resultRow["Max"] = stats.Max; // Max was already tracked.

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

        // Helper function to calculate a quantile from a *sorted* list.
        // Uses the "linear interpolation" method (matches Excel, R type 7).
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
}
