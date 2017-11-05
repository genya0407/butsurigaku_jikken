require 'erb'
require 'rbplotly'
require 'csv'

class String
  def to_df
    headers = lines.first.split(',').map(&:strip)
    rows = lines.drop(1).map { |line| line.split(',').map(&:strip).map(&:to_f) }
                          .map { |row| headers.zip(row).to_h }.to_a
    DF.new(headers, rows)
  end
end

class DF < Array
  attr_accessor :headers

  def initialize(headers, rows)
    @headers = headers
    super(rows)
  end  

  def to_html
    erb = ERB.new <<TEMPLATE
<table>
  <tr>
  <% self.headers.each do |header| %>
    <th><%= header %></th>
  <% end %>
  </tr>

  <% self.each do |row| %>
    <tr>
    <% self.headers.each do |header| %>
      <td><%= row[header] %></td>
    <% end %>
    </tr>
  <% end %>
</table>
TEMPLATE
    erb.result(binding)
  end

  def map
    resulting_arr = super
    self.class.new(headers, resulting_arr)
  end

  def by_col(col_name)
    self.map { |row| row[col_name] }
  end
  
  def to_plotly(targets: [{ x: 'x', y: 'y', name: nil }], type: :scatter, mode: :markers, layout: {})
    data = targets.map do |target|
      x_axis_name = target[:x]
      y_axis_name = target[:y]
      xs = self.map { |row| row[x_axis_name] }
      ys = self.map { |row| row[y_axis_name] }
      trace = { x: xs, y: ys, type: type, mode: mode, name: target[:name] }

      trace
    end

    Plotly::Plot.new(data: data, layout: layout)
  end
  
  def save_csv(filename)
    CSV.open(filename, 'wb') do |csv|
      csv << headers
      each do |row|
        csv << row.values
      end
    end
    filename
  end
end

class Array
  def to_df
    headers = self.map { |row| row.keys }.flatten.uniq
    DF.new(headers, self)
  end
end