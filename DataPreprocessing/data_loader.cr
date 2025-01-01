require "csv"
require "json"
require "yaml"

# DataLoader module provides functionality to load and parse various data formats
module DataLoader
  # Custom error class for data loading errors
  class LoadError < Exception
  end

  # Configuration class to store loader settings
  class Config
    property delimiter : Char
    property headers : Bool
    property encoding : String
    property max_rows : Int32?

    def initialize(
      @delimiter = ',',
      @headers = true,
      @encoding = "UTF-8",
      @max_rows = nil
    )
    end
  end

  # Main loader class with support for different file formats
  class Loader
    getter config : Config
    getter file_path : String

    def initialize(@file_path : String, @config = Config.new)
    end

    # Load CSV data with error handling and validation
    def load_csv : Array(Hash(String, String))
      raise LoadError.new("File not found: #{@file_path}") unless File.exists?(@file_path)
      
      begin
        rows = [] of Hash(String, String)
        CSV.parse(File.read(@file_path), headers: @config.headers, separator: @config.delimiter) do |row|
          break if @config.max_rows && rows.size >= @config.max_rows
          rows << row.to_h
        end
        rows
      rescue ex : CSV::MalformedCSVError
        raise LoadError.new("Invalid CSV format: #{ex.message}")
      rescue ex : Exception
        raise LoadError.new("Error loading CSV: #{ex.message}")
      end
    end

    # Load JSON data
    def load_json : Hash(String, JSON::Any)
      raise LoadError.new("File not found: #{@file_path}") unless File.exists?(@file_path)
      
      begin
        JSON.parse(File.read(@file_path)).as_h
      rescue ex : JSON::ParseException
        raise LoadError.new("Invalid JSON format: #{ex.message}")
      rescue ex : Exception
        raise LoadError.new("Error loading JSON: #{ex.message}")
      end
    end

    # Load YAML data
    def load_yaml : Hash(String, YAML::Any)
      raise LoadError.new("File not found: #{@file_path}") unless File.exists?(@file_path)
      
      begin
        YAML.parse(File.read(@file_path)).as_h
      rescue ex : YAML::ParseException
        raise LoadError.new("Invalid YAML format: #{ex.message}")
      rescue ex : Exception
        raise LoadError.new("Error loading YAML: #{ex.message}")
      end
    end

    # Validate data structure against a schema
    def validate_schema(data : Array(Hash(String, String)), required_columns : Array(String)) : Bool
      return false if data.empty?
      
      data.all? do |row|
        required_columns.all? { |col| row.has_key?(col) && !row[col].empty? }
      end
    end

    # Get basic statistics about the loaded data
    def data_statistics(data : Array(Hash(String, String))) : Hash(String, Int32)
      {
        "row_count" => data.size,
        "column_count" => data.first?.try(&.size) || 0,
        "empty_cells" => data.sum { |row| row.count { |_, v| v.empty? } }
      }
    end
  end
end

# Example usage
begin
  # Initialize loader with custom configuration
  config = DataLoader::Config.new(
    delimiter: ',',
    headers: true,
    max_rows: 1000
  )
  
  loader = DataLoader::Loader.new("data.csv", config)
  
  # Load CSV data
  data = loader.load_csv
  
  # Validate required columns
  required_columns = ["id", "name", "value"]
  if loader.validate_schema(data, required_columns)
    puts "Data validation passed"
    
    # Get statistics
    stats = loader.data_statistics(data)
    puts "Statistics: #{stats}"
    
    # Process data
    data.each do |row|
      # Process each row...
      puts row
    end
  else
    puts "Data validation failed"
  end

rescue DataLoader::LoadError => e
  puts "Error: #{e.message}"
rescue ex : Exception
  puts "Unexpected error: #{ex.message}"
end
require "./DataPreprocessing/data_loader"

# Initialize loader with custom configuration
config = DataLoader::Config.new(
  delimiter: ',',
  headers: true,
  max_rows: 1000
)

loader = DataLoader::Loader.new("data.csv", config)

# Load CSV data
data = loader.load_csv

# Print loaded data
puts data