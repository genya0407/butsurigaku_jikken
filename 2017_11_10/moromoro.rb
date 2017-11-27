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

class Hash
  def except(*keys)
    dup.except!(*keys)
  end

  def except!(*keys)
    keys.each { |key| delete(key) }
    self
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
  
  def plot(targets: [{ x: 'x', y: 'y' }], options: {}, file: nil)
    # set options
    colors = ['#43dde6', '#364f6b', '#fc5185', '#fccf4d']
    point_types =[7, 9, 13]
    line_options = point_types.map.with_index do |pt, pt_index|
      colors.map.with_index do |color_name, index|
        ["style line #{index + pt_index * colors.count + 1}", "pt #{pt} lc rgb \"#{color_name}\""]
      end
    end.inject(:+).to_h.merge('style increment': 'user')
    default_options = {
      key: 'box outside',
      tics: 'scale 3 font ",15"',
      mxtics: '',
      mytics: '',
      grid: 'x y',
      xl: targets.first[:x],
      yl: targets.first[:y],
    }#.merge(line_options)
    options = default_options.merge(options)
    [:xl, :yl].each do |label_name|
      if not options[label_name].nil?
        options[label_name] = "'#{options[label_name]}' font ',20'"
      end
    end

    # create data
    data = targets.map do |target|
      x_axis_name = target[:x]
      y_axis_name = target[:y]
      xs = by_col(x_axis_name)
      ys = by_col(y_axis_name)

      trace = [xs, ys]
      if yerror_axis_name = target[:yerror]
        yerrors = by_col(yerror_axis_name)
        trace.push(yerrors)
      end
      trace.push({title: target[:y]}.merge(target.except(:x, :y, :yerror)))

      trace
    end

    if file
      Numo.gnuplot do
        set terminal: 'png'
        set output: file

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
  
  def slope(x:, y:)
    xs, ys = fetch_xy(x, y)
    cov(xs, ys)/variance(xs)
  end

  def slope_error(x:, y:)
    xs, ys = fetch_xy(x, y)

    a = slope(x: x, y: y)
    b = segment(x: x, y: y)
    Math.sqrt(1.to_f/delta(xs, ys)*xs.map{|x| x**2}.inject(:+)) * sigma(xs, ys, a, b)
  end

  def segment(x:, y:)
    xs, ys = fetch_xy(x, y)
    ys.mean - slope(x: x, y: y) * xs.mean
  end

  def integral(x:, y:)
    xs, ys = fetch_xy(x, y)
    """
    xs.drop(1).zip(xs).zip(ys.drop(1)).map do |(x1, x0), y|
      y * (x1 - x0)
    end.inject(:+)
    """
    xys = xs.zip(ys)
    xys.drop(1).zip(xys).map do |xy1, xy0|
      x0, y0 = xy0
      x1, y1 = xy1

      (y1 + y0) * (x1 - x0) / 2.0
    end.inject(:+)
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

  private
  def fetch_xy(x, y)
    xs = by_col(x).to_a
    ys = by_col(y).to_a

    [xs, ys]
  end
end

class Array
  def to_df
    headers = self.map { |row| row.keys }.flatten.uniq
    DF.new(headers, self)
  end

  def mean
    inject(:+)/count.to_f
  end
end

# xs, ys = [[50,50],[50,70],[80,60],[70,90],[90,100]].transpose
# cov(xs, ys) == 188.0
def cov(xs, ys)
  ex = xs.mean
  ey = ys.mean

  xs.zip(ys).map { |x,y| (x - ex) * (y - ey) }.mean
end

# xs = [50,60,70,70,100]
# variance(xs) == 280.0
def variance(xs)
  ex = xs.mean
  xs.map { |x| (x - ex)**2 }.mean
end

# xs = [1,2,3,4]
# ys = [3,5,7,9]
# a = 2
# b = 1
# sigma(xs, ys, a, b) == 0
def sigma(xs, ys, a, b)
  n = xs.to_a.count
  xys = xs.zip(ys)
  Math.sqrt(1.to_f/(n-2)*(xys.map{ |x, y| (y - b - a*x)**2 }.inject(:+)))
end

def delta(xs, ys)
  xs.count * xs.map { |x| x**2 }.inject(:+) - (xs.inject(:+))**2   
end