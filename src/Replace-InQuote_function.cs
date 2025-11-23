using System;
using System.Collections.Generic;
using System.IO;
using System.Text.RegularExpressions;

/// <summary>
/// Provides functionality to perform Regex replacements ONLY within specific delimiters.
/// 
/// Common Use Case:
/// Replacing commas with dots inside double quotes, while leaving commas outside quotes alone.
/// 
/// Design Principle:
/// Uses a "MatchEvaluator" delegate to intercept the outer match (the text inside delimiters),
/// processes that inner text, and then returns the reconstructed string.
/// </summary>
public class ScopedRegexReplacer
{
    // The compiled regex used to find the delimiters (the "Scope").
    private readonly Regex _scopeFinder;
    
    // The regex pattern to find INSIDE the scope.
    private readonly string _innerPattern;
    
    // The replacement string to apply INSIDE the scope.
    private readonly string _innerReplacement;

    // We store the delimiters to reconstruct the string correctly after modification.
    private readonly string _startDelim;
    private readonly string _endDelim;

    /// <summary>
    /// Initializes the replacer by constructing the scope-finding Regex.
    /// </summary>
    /// <param name="startDelim">The starting marker (e.g., ").</param>
    /// <param name="endDelim">The ending marker (e.g., ").</param>
    /// <param name="innerPattern">The Regex pattern to search for INSIDE the delimiters.</param>
    /// <param name="innerReplacement">The string to replace matches with.</param>
    public ScopedRegexReplacer(string startDelim, string endDelim, string innerPattern, string innerReplacement)
    {
        _startDelim = startDelim;
        _endDelim = endDelim;
        _innerPattern = innerPattern;
        _innerReplacement = innerReplacement;

        // 1. Escape the delimiters to ensure they are treated as literals, not Regex commands.
        //    Example: If delimiter is "[", we want to match literal "[" not start of a class.
        string safeStart = Regex.Escape(startDelim);
        string safeEnd = Regex.Escape(endDelim);

        // 2. Build the "Outer" Regex.
        //    Pattern: StartDelimiter + (Content) + EndDelimiter
        //    We use "(.*?)" which is a Non-Greedy capture group. 
        //    It matches the shortest possible string between delimiters.
        //    Singleline mode is enabled (?s) to ensure dot (.) matches newlines if they exist inside quotes.
        string outerPattern = $"(?s){safeStart}(.*?){safeEnd}";

        _scopeFinder = new Regex(outerPattern, RegexOptions.Compiled);
    }

    /// <summary>
    /// Processes a single string (line).
    /// </summary>
    public string ProcessLine(string input)
    {
        if (string.IsNullOrEmpty(input)) return input;

        // The MatchEvaluator is a callback function that runs for every found "Scope".
        return _scopeFinder.Replace(input, match =>
        {
            // match.Groups[1] is the content strictly BETWEEN the delimiters.
            string contentInside = match.Groups[1].Value;

            // Apply the user's specific replacement logic to the inner content.
            string processedContent = Regex.Replace(contentInside, _innerPattern, _innerReplacement);

            // Reassemble the parts: Start + ModifiedContent + End
            return _startDelim + processedContent + _endDelim;
        });
    }

    /// <summary>
    /// Processes an entire file line-by-line using a stream.
    /// Optimized for memory usage on large files.
    /// </summary>
    public static List<string> ProcessFile(string path, string start, string end, string pattern, string replace)
    {
        var results = new List<string>();
        
        // Instantiate the logic once
        var replacer = new ScopedRegexReplacer(start, end, pattern, replace);

        using (var sr = new StreamReader(path))
        {
            string line;
            while ((line = sr.ReadLine()) != null)
            {
                results.Add(replacer.ProcessLine(line));
            }
        }
        return results;
    }
}
