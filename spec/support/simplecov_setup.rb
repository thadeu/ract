require 'simplecov'
require 'simplecov-console'

if ENV['COV'] == '1' or ENV['CI']
  SimpleCov.start do
    enable_coverage :branch
    project_name 'react'

    track_files 'lib/**/*.rb'

    # Dont cover this paths
    add_filter 'lib/react/version.rb'
    add_filter '/spec/'
    add_filter '/examples/'

    SimpleCov::Formatter::Console.sort = :path
    SimpleCov::Formatter::Console.output_style = :table
    SimpleCov::Formatter::Console.max_rows = 15
    SimpleCov::Formatter::Console.max_lines = 5
    SimpleCov::Formatter::Console.missing_len = 10
    SimpleCov::Formatter::Console.show_covered = true

    # Use both HTML and Console formatters
    SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
      SimpleCov::Formatter::HTMLFormatter,
      SimpleCov::Formatter::Console
    ])
  end
end
