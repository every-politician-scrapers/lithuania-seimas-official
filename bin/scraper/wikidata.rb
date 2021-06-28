#!/bin/env ruby
# frozen_string_literal: true

require 'cgi'
require 'csv'
require 'scraped'
require 'pry'

class Results < Scraped::JSON
  field :members do
    json[:results][:bindings].map { |result| fragment(result => Member).to_h }
  end
end

class Member < Scraped::JSON
  field :item do
    json.dig(:item, :value).to_s.split('/').last
  end

  field :name do
    json.dig(:name, :value)
  end

  PARTY_MAP = {
    'Social Democratic Party of Lithuania' => 'Lithuanian Social Democratic Party Political Group',
    'Lithuanian Peasant and Greens Union' => 'Lithuanian Farmers and Greens Union Political Group',
    'Liberal Movement' => 'Liberals Movement Political Group',
    'Homeland Union – Lithuanian Christian Democrats' => 'Homeland Union-Lithuanian Christian Democrat Political Group',
    'Freedom Party' => 'Freedom Party Political Group',
    'Labour Party' => 'Labour Party Political Group',
    'independent politician' => 'Non-attached Members',
  }

  field :party do
    PARTY_MAP.fetch(partyLabel, partyLabel)
  end

  private

  def partyLabel
    json.dig(:partyLabel, :value)
  end
end

WIKIDATA_SPARQL_URL = 'https://query.wikidata.org/sparql?format=json&query=%s'

memberships_query = <<SPARQL
  SELECT ?item ?name ?party ?partyLabel ?start
  WHERE {
    ?item p:P39 ?statement .
    ?statement ps:P39 wd:Q18507240 ; pq:P2937 wd:Q100387097 .
    FILTER NOT EXISTS { ?statement pq:P582 ?end }
    OPTIONAL { ?statement pq:P580 ?start }
    OPTIONAL { ?statement pq:P4100 ?party }

    OPTIONAL { ?statement prov:wasDerivedFrom/pr:P1810 ?sourceName }
    OPTIONAL { ?item rdfs:label ?enLabel FILTER(LANG(?enLabel) = "en") }
    BIND(COALESCE(?sourceName, ?enLabel) AS ?name)
    SERVICE wikibase:label { bd:serviceParam wikibase:language "[AUTO_LANGUAGE],en,lt". }
  }
  ORDER BY ?name
SPARQL

url = WIKIDATA_SPARQL_URL % CGI.escape(memberships_query)
headers = { 'User-Agent' => 'every-politican-scrapers/northern-ireland-assembly-official' }
data = Results.new(response: Scraped::Request.new(url: url, headers: headers).response).members

header = data.first.keys.to_csv
rows = data.map { |row| row.values.to_csv }
abort 'No results' if rows.count.zero?

puts header + rows.join
