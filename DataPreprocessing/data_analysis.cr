require "./data_loader"

# Module for statistical analysis of data
module DataAnalysis
  # Custom error class for analysis errors
  class AnalysisError < Exception
  end

  # Class containing statistical analysis methods
  class Analyzer
    getter data : Array(Hash(String, String))
    
    def initialize(@data)
      raise AnalysisError.new("Empty dataset") if @data.empty?
    end

    # Calculate basic statistics for a numeric column
    def column_stats(column_name : String) : NamedTuple(
      mean: Float64,
      median: Float64,
      std_dev: Float64,
      min: Float64,
      max: Float64,
      count: Int32
    )
      values = numeric_values(column_name)
      
      {
        mean: calculate_mean(values),
        median: calculate_median(values),
        std_dev: calculate_std_dev(values),
        min: values.min,
        max: values.max,
        count: values.size
      }
    end

    # Calculate correlation between two numeric columns
    def correlation(column1 : String, column2 : String) : Float64
      values1 = numeric_values(column1)
      values2 = numeric_values(column2)
      
      raise AnalysisError.new("Columns must have same length") if values1.size != values2.size
      
      mean1 = calculate_mean(values1)
      mean2 = calculate_mean(values2)
      
      covariance = values1.zip(values2).sum { |x, y| (x - mean1) * (y - mean2) } / values1.size
      std_dev1 = Math.sqrt(values1.sum { |x| (x - mean1) ** 2 } / values1.size)
      std_dev2 = Math.sqrt(values2.sum { |x| (x - mean2) ** 2 } / values2.size)
      
      covariance / (std_dev1 * std_dev2)
    end

    # Calculate frequency distribution for a column
    def frequency_distribution(column_name : String) : Hash(String, Int32)
      frequencies = Hash(String, Int32).new(0)
      @data.each do |row|
        value = row[column_name]?
        frequencies[value] += 1 if value
      end
      frequencies
    end

    # Generate summary statistics for all numeric columns
    def summary_statistics : Hash(String, NamedTuple(
      mean: Float64,
      median: Float64,
      std_dev: Float64,
      min: Float64,
      max: Float64,
      count: Int32
    ))
      numeric_columns = find_numeric_columns
      stats = {} of String => NamedTuple(
        mean: Float64,
        median: Float64,
        std_dev: Float64,
        min: Float64,
        max: Float64,
        count: Int32
      )
      
      numeric_columns.each do |column|
        stats[column] = column_stats(column)
      end
      
      stats
    end

    # Find outliers using IQR method
    def find_outliers(column_name : String, iqr_multiplier : Float64 = 1.5) : Array(Float64)
      values = numeric_values(column_name)
      sorted = values.sort
      q1 = sorted[values.size // 4]
      q3 = sorted[values.size * 3 // 4]
      iqr = q3 - q1
      
      lower_bound = q1 - (iqr * iqr_multiplier)
      upper_bound = q3 + (iqr * iqr_multiplier)
      
      values.select { |x| x < lower_bound || x > upper_bound }
    end

    private def numeric_values(column_name : String) : Array(Float64)
      values = @data.compact_map do |row|
        value = row[column_name]?
        value.try(&.to_f?) if value
      end
      
      raise AnalysisError.new("No numeric values found in column: #{column_name}") if values.empty?
      values
    end

    private def calculate_mean(values : Array(Float64)) : Float64
      values.sum / values.size
    end

    private def calculate_median(values : Array(Float64)) : Float64
      sorted = values.sort
      mid = sorted.size // 2
      sorted.size.odd? ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2
    end

    private def calculate_std_dev(values : Array(Float64)) : Float64
      mean = calculate_mean(values)
      variance = values.sum { |x| (x - mean) ** 2 } / values.size
      Math.sqrt(variance)
    end

    private def find_numeric_columns : Array(String)
      return [] of String if @data.empty?
      
      @data.first.keys.select do |column|
        @data.any? { |row| row[column]?.try(&.to_f?) }
      end
    end
  end
end

# Example usage
begin
  # Load data using enhanced DataLoader
  config = DataLoader::Config.new(headers: true)
  loader = DataLoader::Loader.new("data.csv", config)
  data = loader.load_csv

  # Initialize analyzer
  analyzer = DataAnalysis::Analyzer.new(data)

  # Get summary statistics for all numeric columns
  summary_stats = analyzer.summary_statistics
  puts "Summary Statistics:"
  summary_stats.each do |column, stats|
    puts "\nColumn: #{column}"
    puts "Mean: #{stats[:mean]}"
    puts "Median: #{stats[:median]}"
    puts "Standard Deviation: #{stats[:std_dev]}"
    puts "Min: #{stats[:min]}"
    puts "Max: #{stats[:max]}"
    puts "Count: #{stats[:count]}"
  end

  # Calculate correlation between two columns
  correlation = analyzer.correlation("price", "quantity")
  puts "\nCorrelation between price and quantity: #{correlation}"

  # Find outliers in a specific column
  outliers = analyzer.find_outliers("price")
  puts "\nOutliers in price column: #{outliers}"

  # Get frequency distribution for a categorical column
  distribution = analyzer.frequency_distribution("category")
  puts "\nCategory distribution:"
  distribution.each do |category, count|
    puts "#{category}: #{count}"
  end

rescue DataLoader::LoadError => e
  puts "Data loading error: #{e.message}"
rescue DataAnalysis::AnalysisError => e
  puts "Analysis error: #{e.message}"
rescue ex : Exception
  puts "Unexpected error: #{ex.message}"
end