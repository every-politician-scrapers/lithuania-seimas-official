#!/bin/env ruby
# frozen_string_literal: true

require 'csv'
require 'scraped'
require 'pry'

class Legislature
  # details for an individual member
  class Member < Scraped::HTML
    field :id do
      url[/(\d+)$/, 1]
    end

    field :name do
      noko.css('.sn-list-name a/@title').text.tidy
    end

    field :party do
      noko.css('.sn-list-frakcija').text.tidy
    end

    field :party_short do
      noko.css('.frakcija-spalva').attr('class').text.split(' ').last
    end

    private

    def url
      noko.css('.sn-list-name a/@href').text
    end
  end

  # The page listing all the members
  class Members < Scraped::HTML
    field :members do
      noko.css('.list-member').map { |mp| fragment(mp => Member).to_h }
    end
  end
end

url = 'https://www.lrs.lt/sip/portal.show?p_r=35299&p_k=2&filtertype=0'
data = Legislature::Members.new(response: Scraped::Request.new(url: url).response).members

header = data.first.keys.to_csv
rows = data.map { |row| row.values.to_csv }
abort 'No results' if rows.count.zero?

puts header + rows.join
