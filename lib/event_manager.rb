require 'csv'
require 'erb'
require 'google/apis/civicinfo_v2'

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
    'You can find your representatives by visiting '\
      'www.commoncause.org/take-action/find-elected-officials'
  end
end

# Save processed letter into file whose name is label by the id passed
def save_thank_letter(id, letter)
  Dir.mkdir('output') unless Dir.exist?('output')
  filename = "output/thanks_#{id}.html"

  File.open(filename, 'w') do |file|
    file.write(letter)
  end
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

puts 'Event Manager Initialized!'