#!/usr/bin/env ruby

require 'Roo-xls'

# TODO: Actually display the help
def display_help
  
end

# Try to open the file. If it exists, is unique, and has content, return it
def try_to_open(filename)
  # Exists and unique?
  results = Dir.glob filename
  if results.empty?
    raise "NO RESULTS FOUND FOR \"#{filename}\""
  elsif results.length > 1
    raise "AMBIGUOUS NAME \"#{filename}\""
  end

  # Open
  sheet = Roo::Spreadsheet.open(results.first)

  begin
    sheet.parse(header_search: [/name|id|birth|phone/i])
  rescue
    raise "COULD NOT FIND HEADER ROW IN \"#{results.first}\""
  end
end

def retrieve_file(filename)
  sheet = nil
  until sheet do
    unless filename
      print "Enter name of file: "
      filename = gets.chomp
    end

    begin
      sheet = try_to_open filename
    rescue Exception => e
      puts "ERROR: #{e}"
      puts "Please try again."
      filename = nil
    end
  end

  [sheet, filename]
end

puts

filename_a = ARGV.shift
filename_b = ARGV.shift

data_a, filename_a = retrieve_file filename_a
data_b, filename_b = retrieve_file filename_b

headers_list_a = data_a.map {|row| row.keys}.flatten.uniq
headers_list_b = data_b.map {|row| row.keys}.flatten.uniq

headers_a = Hash[*((1..headers_list_a.length).zip(headers_list_a).flatten)]
headers_b = Hash[*((1..headers_list_b.length).zip(headers_list_b).flatten)]

len = [headers_a.length, headers_b.length].max

column_width = 20
format_str = sprintf("%%-%ds%%-%ds%%-%ds%%-%ds\n", *([column_width] * 4))

puts "HEADERS BY FILE"
printf(format_str, filename_a, "Column Name", filename_b, "Column Name")
puts (["-"] * (column_width * 4)).join
len.times do |i|
  h_key_a = headers_a.keys[i]
  h_val_a = nil
  h_key_b = headers_b.keys[i]
  h_val_b = nil

  if h_key_a
    h_val_a = headers_a[h_key_a]
  else
    h_key_a = h_val_a = ""
  end

  if h_key_b
    h_val_b = headers_b[h_key_b]
  else
    h_key_b = h_val_b = ""
  end

  printf(format_str, h_key_a, h_val_a, h_key_b, h_val_b)
end

target_headers_a = nil
target_headers_b = nil

joiner = " "
until target_headers_a and target_headers_b
  print "Enter list of headers from #{filename_a} by number (e.g. 1 2 4 9): "
  target_headers_a = gets.split(/\W+/).map {|n| headers_a[n.to_i]}
  print "Enter list of headers from #{filename_b} by number (e.g. 1 2 4 9): "
  target_headers_b = gets.split(/\W+/).map {|n| headers_b[n.to_i]}

  if target_headers_a.include? nil or target_headers_b.include? nil
    puts "One or more of the header columns you specified are invalid!"
    target_headers_a = target_headers_b = nil
  elsif target_headers_a.length != target_headers_b.length
    print "The given lists of columns are different lengths! Are you sure? (y/n) "
    if gets !~ /y/i
      target_headers_a = target_headers_b = nil
    end
  else
    example_key_a = target_headers_a.map{|hdr| data_a.first[hdr]}.join joiner
    example_key_b = target_headers_b.map{|hdr| data_a.first[hdr]}.join joiner

    puts "Match based on the keys \"#{target_headers_a.join ", "}\" and \"#{target_headers_b.join ", "}\"?"
    puts "Example: the first key from each file is:"
    printf(sprintf("%%-%ds: \"%%s\"\n", column_width), filename_a, example_key_a)
    printf(sprintf("%%-%ds: \"%%s\"\n", column_width), filename_b, example_key_b)
    print "Do you want to proceed with these key formats? (y/n) "

    if gets !~ /y/i
      target_headers_a = target_headers_b = nil
    end
  end
end

# Get preferences from user (joiner, nocase, disregards)
print "Field joiner is currently \"#{joiner}\". Change? (y/n) "
if gets =~ /y/i
  print "Enter new field joiner: "
  joiner = gets.chomp
  puts "Joiner is now \"#{joiner}\""
end

# Okay, for now we're just going to force nocase
nocase = true
# nocase = false
# print "Ignore case? (y/n) "
# if gets =~ /[Yy]/
#   nocase = true
# end

disregards = [/^\W*$/, /none/i, /n\/?a/i]
puts "Set to view the following as \"blank\":"
disregards.each do |disregard|
  p disregard
end
print "Add another? (y/n): "
if gets =~ /y/i
  print "Enter new pattern to disregard (don't include outisde slashes): "
  disregards << /#{gets.chomp}/
  p disregards[-1]
end

# Populate hashes of unique keys pointing to records
# TODO: rename records_b to reflect the fact that it is an array of arrays of hashes
records_a = {}
records_b = {}

data_a.each do |record|
  key = target_headers_a.map{|hdr| record[hdr]}.join joiner
  if nocase
    key = key.to_s.downcase
  end
  # Warn about duplication in the primary file
  if records_a.key? key
    raise "Multiple records in #{filename_a} have the same key \"#{key}\"!"
  else
    records_a[key] = record
  end
end
data_b.each do |record|
  key = target_headers_b.map{|hdr| record[hdr]}.join joiner
  if nocase
    key = key.to_s.downcase
  end
  if records_b.key? key
    if records_b[key].kind_of? Array
      records_b[key] << record
    else
      records_b[key] = []
    end
  else
    records_b[key] = []
    records_b[key] << record
  end
end

# Hashes are populated. Now match corresponding records
records = []
bad_records_a = []
bad_records_b = []

unique_keys_a = records_a.keys - records_b.keys
unique_keys_b = records_b.keys - records_a.keys
unique_records_a = unique_keys_a.map {|key| records_a[key]}
unique_records_b = unique_keys_b.map {|key| records_b[key]}
common_keys_a = records_a.keys - unique_keys_a # These should always be identical, right?
common_keys_b = records_b.keys - unique_keys_b

# records_b.keys.each do |key|
common_keys_b.each do |key|
  if records_a.key? key # This should be redundant
    # The unique record from A
    record_a = records_a[key]
    # The list of possibly same-keyed records from B
    record_b_list = records_b[key]

    record_b_list.each do |record_b|
      # Start with just the material from A
      record = headers_a.values.map {|hdr| record_a[hdr]}
      # Keep all fields from A, add the ones from B.
      # record_b.keys.each do |fieldname|
      headers_b.each do |fieldname_arr|
        fieldname = fieldname_arr[1]

        # If a field from B is named the same as a field from A,
        if record_a.key? fieldname
          # then if the data matches, ignore it,
          if record_a[fieldname] == record_b[fieldname] or (nocase and record_a[fieldname].to_s.downcase == record_b[fieldname].to_s.downcase)
            # Literally do nothing

          # but if the data conflicts, we got a problem.
          else
            puts "Warning! Found fields with the same name that conflict!"
            puts "#{record_a[fieldname]} != #{record_b[fieldname]}"
            bad_records_a << record_a
            bad_records_b << record_b

            # and we bail
            next
          end
        else
          record << record_b[fieldname]
        end
      end
      records << record
    end
  end
end

# TODO: Create local directory named "#{filename_base_a}_#{filename_base_b}/"
#       and put the resulting files there

filename_base_a = filename_a.split(/\./).first
filename_base_b = filename_b.split(/\./).first
result_filename = "#{filename_base_a}_#{filename_base_b}_CROSS.csv"

print "Saving results to #{result_filename}... "
CSV.open(result_filename, "w") do |csv|
  #csv << headers_list_a + headers_list_b
  csv << headers_list_a & headers_list_b
  records.each do |record|
    csv << record
  end
end
puts "done!"

unless bad_records_a.empty?
  bad_filename_a = "#{filename_base_a}_BAD.csv"
  puts "Also found bad records from #{filename_a}!"
  print "Saving to #{bad_filename_a}... "
  CSV.open(bad_filename_a, "w") do |csv|
    csv << headers_list_a
    bad_records_a.each do |record|
      if record and
        csv << headers_list_b.map {|header| record[header]}
      end
    end
  end
  puts "done!"
end

unless bad_records_b.empty?
  bad_filename_b = "#{filename_base_b}_BAD.csv"
  puts "Also found bad records from #{filename_b}!"
  print "Saving to #{bad_filename_b}... "
  CSV.open(bad_filename_b, "w") do |csv|
    csv << headers_list_b
    bad_records_b.each do |record|
      if record
        csv << headers_list_b.map {|header| record[header]}
      end
    end
  end
  puts "done!"
end

unless unique_records_a.empty?
  unique_filename_a = "#{filename_base_a}_UNIQUE.csv"
  puts "Also found unique records from #{filename_a}!"
  print "Saving to #{unique_filename_a}... "
  CSV.open(unique_filename_a, "w") do |csv|
    csv << headers_list_a

    unique_records_a.each do |record|
      if record
        csv << headers_list_a.map {|header| record[header]}
      end
    end
  end
  puts "done!"
end

unless unique_records_b.empty?
  unique_filename_b = "#{filename_base_b}_UNIQUE.csv"
  puts "Also found unique records from #{filename_b}!"
  print "Saving to #{unique_filename_b}... "
  CSV.open(unique_filename_b, "w") do |csv|
    csv << headers_list_b

    unique_records_b.flatten.each do |record|
      if record
        csv << headers_list_b.map {|header| record[header]}
      end
    end
  end
  puts "done!"
end

# TODO: Actually refactor something.
