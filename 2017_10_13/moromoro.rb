require 'erb'
require 'rbplotly'
require 'csv'
require "numo/gnuplot"

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
  
  def plot(targets: [{ x: 'x', y: 'y', title: nil }], options: {}, file: nil)
    default_options = {
      nokey: '',
      tics: 'font ",15"',
      grid: 'x y'
    }
    options = default_options.merge(options)
    [:xl, :yl].each do |label_name|
      if not options[label_name].nil?
        options[label_name] = "'#{options[label_name]}' font ',20'"
      end
    end
    data = targets.map do |target|
      x_axis_name = target[:x]
      y_axis_name = target[:y]
      xs = by_col(x_axis_name)
      ys = by_col(y_axis_name)

      [xs, ys, { title: (target[:title] || '凡例') }]
    end

    if file
      Numo.gnuplot do
        output file

        options.each do |k, v|
          set k, v
        end
        plot *data
      end
    end

    Numo.noteplot do
      options.each do |k, v|
        set k, v
      end
      plot *data
    end
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