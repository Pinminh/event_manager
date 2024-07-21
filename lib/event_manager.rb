require 'csv'
require 'erb'
require 'date'
require 'google/apis/civicinfo_v2'
require 'pry-byebug'

def clean_zipcode(zipcode)
  zipcode.to_s.rjust(5, '0').slice(0, 5)
end

def clean_phone_number(phone_number)
  phone_number = phone_number.gsub(/\D/, '')

  return nil unless [10, 11].include?(phone_number.length)
  return phone_number if phone_number.length == 10
  return phone_number.slice(1..-1) if phone_number[0] == 1

  nil
end

# Return an array of officials associated with zipcode, or return a string
# indicating that officials cannot be found
def legislators_by_zip(zipcode)
  civic_info = Google::Apis::CivicinfoV2::CivicInfoService.new
  civic_info.key = 'AIzaSyClRzDqDh5MsXwnCWi0kOiiBivP6JsSyBw'

  begin
    civic_info.representative_info_by_address(
      address: zipcode,
      levels: 'country',
      roles: %w[legislatorUpperBody legislatorLowerBody]
    ).officials
  rescue Google::Apis::ClientError
    'You can find your representatives by visiting ' \
    'www.commoncause.org/take-action/find-elected-officials'
  end
end

# Save processed letter into file whose name is label by the id passed
def save_thank_letter(id, letter)
  FileUtils.mkdir_p 'output'
  filename = "output/thanks_#{id}.html"

  File.write(filename, letter)
end

# Return CSV parser or contents (can be looped through)
def csv_parser(csv_path)
  CSV.open(
    csv_path,
    headers: true,
    header_converters: :symbol
  )
end

# Save all thank-you letters with given ERB template from provided CSV
def save_letters_from_csv(csv_path, letter_erb_path)
  contents = csv_parser(csv_path)

  template_letter = File.read(letter_erb_path)
  erb_template_letter = ERB.new(template_letter)

  contents.each do |row|
    attendee_id = row[0]
    attendee_name = row[:first_name]
    zipcode = clean_zipcode(row[:zipcode])
    legislators = legislators_by_zip(zipcode)

    form_letter = erb_template_letter.result(binding)

    save_thank_letter(attendee_id, form_letter)
  end
end

# Return an array whose index indicates hour of a day and associated value is
# the number of people registered on that hour
def initialize_regtime_charts(csv_path)
  contents = csv_parser(csv_path)

  datetime_pattern = '%m/%d/%y %H:%M'

  hour_chart = Array.new(24, 0)
  wday_chart = Array.new(7, 0)
  day_chart = Array.new(32, 0)
  month_chart = Array.new(13, 0)

  contents.each do |row|
    datetime = Time.strptime(row[:regdate], datetime_pattern)

    hour_chart[datetime.hour] += 1
    wday_chart[datetime.wday] += 1
    day_chart[datetime.day] += 1
    month_chart[datetime.month] += 1
  end

  wday_chart.rotate!
  { hour: hour_chart, wday: wday_chart, day: day_chart, month: month_chart }
end

# Return a copy of numbers array but each elements turn into ratio respect to
# the maximum element
def to_ratio_by_max(original_numbers, multiplier = 1)
  return nil unless original_numbers.is_a?(Array)

  numbers = original_numbers.clone
  numbers.map! { |num| num.is_a?(Integer) && num.positive? ? num : 0 }

  max_number = numbers.max
  numbers.map! { |num| multiplier * num.to_f / max_number }
end

def regtime_charts(csv_path)
  charts = initialize_regtime_charts(csv_path)

  charts[:day][0] = charts[:month][0] = nil
  charts
end

# Return time label corresponding to hour, day, weekday, or month
def time_label_by_chart(chart, num_label)
  case chart.length
  when 24 then "#{num_label}:00".rjust(5)
  when 7  then Date::DAYNAMES.rotate[num_label].to_s.rjust(9)
  when 32 then "Day ##{num_label.to_s.rjust(2)}"
  when 13 then Date::MONTHNAMES[num_label].to_s.rjust(9)
  else ''
  end
end

# Display time chart with with bar format
def display_time_chart(original_chart, bar_max_width = 100)
  return nil if original_chart.nil?

  chart = to_ratio_by_max(original_chart, bar_max_width)
  chart[0] = nil if [32, 13].include?(chart.length)

  chart.each_with_index do |num, idx|
    next if num.nil?

    time_label = time_label_by_chart(chart, idx)
    time_bar = "\u{0275A}" * num.to_i

    puts "#{time_label} #{time_bar}"
  end
end

puts 'Event Manager Initialized!'

samples_folder = 'samples/'
sample_filename = 'event_attendees_full.csv'
sample_path = samples_folder + sample_filename

charts = regtime_charts(sample_path)

estimated_label_width = 10
display_bar_width = 150

charts.each_value do |chart|
  display_time_chart(chart, display_bar_width)

  puts '_' * (estimated_label_width + display_bar_width)
end
