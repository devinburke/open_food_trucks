# frozen_string_literal: true

require 'net/http'
require 'json'
require 'tty-table'

def start_loader
  Thread::new do
		spinner = Enumerator.new do |e|
		  loop do
		    e.yield '|'
		    e.yield '/'
		    e.yield '-'
		    e.yield '\\'
		  end
		end

	  loop do
  	  printf("\rLoading: %s", spinner.next)
			sleep(0.1)
	  end
	end
end

def query_api(query)
	uri = URI.parse("http://data.sfgov.org/resource/bbb8-hzi6.json")
	uri.query = query

	req = Net::HTTP::Get.new(uri.to_s)
	Net::HTTP.start(uri.host, uri.port) { |http| http.request(req) }
end

def get_trucks(offset, per_page)
	fields = ["applicant", "location"]
	query  = "$query=SELECT #{fields.join(',')} WHERE dayofweekstr = '#{$day_of_week}' AND '#{$formatted_time}' BETWEEN start24 AND end24 ORDER BY applicant ASC LIMIT #{per_page} OFFSET #{offset}"
	trucks = JSON.parse(query_api(query).body)

	trucks.map(&:values)
end

def total_pages
	fields = ["applicant", "location"]

	query = "$query=SELECT COUNT(*) WHERE dayofweekstr = '#{$day_of_week}' AND '#{$formatted_time}' BETWEEN start24 AND end24"

	JSON.parse(query_api(query).body)[0]["COUNT"]
end

def generate_table(page = 0)
	per_page = 10
	total = (total_pages.to_i / per_page).ceil
	spinner = start_loader
	offset = per_page * page

	table = TTY::Table.new ['Name','Address'], get_trucks(offset, per_page)

	spinner.exit
  printf("\rDone: On Page #{page + 1}/#{total + 1}")
	puts "\n\n#{table}\n\n"

	if(total > 1)
		start_paging(page, total)
	else
		puts "\nNo More Pages"
	end
end

def start_paging(page, total)
	exit if page === total

	prompt = "> "
  puts "Enter next #{'or prev ' unless page == 0}to change the page, press Enter to exit"
	print prompt

	user_input = gets.chomp

	if(user_input === "next")
 	  page += 1

 	  generate_table page
		start_paging(page, total)
	elsif(user_input === "prev" && page != 0)
 	  page -= 1

 	  generate_table page
		start_paging(page, total)
	else
		exit
	end
end

time = Time.at(0)
$day_of_week = time.strftime("%A")
$formatted_time = time.strftime("%H:%M")

generate_table
