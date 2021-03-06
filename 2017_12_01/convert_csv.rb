require 'csv'

filepath = ARGV[0]
tabular_count = ARGV[1].to_i
caption = ARGV[2]

table = CSV.readlines(filepath, headers: true)
headers = table.headers
all_rows = table.map { |row| row.to_h }
rows_count_for_each_tabular = (all_rows.size / tabular_count.to_f).ceil

latex_tabulars = all_rows.each_slice(rows_count_for_each_tabular).map do |rows|
  latex_rows = rows.map do |row|
    headers.map { |header| row[header] }.join(' & ')
  end.join(" \\\\ \\hline \n")
  <<-TABULAR
  \\subfloat{
  \\begin{tabular}{|#{"c|" * headers.count}}
    \\hline
    #{headers.map{|h| "$ #{h} $"}.join(' & ')} \\\\ \\hline \\hline
    #{latex_rows} \\\\ \\hline
  \\end{tabular}
  }
  TABULAR
end.join

puts latex_tabulars