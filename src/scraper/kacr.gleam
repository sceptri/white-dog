import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/list
import gleam/option
import gleam/regexp
import gleam/result
import gleam/string

import presentable_soup as soup
import scraper/utils as scraper

pub type CompetitionQuery {
  CompetitionQuery(id: Int, vacancies: Int, signed_up: Int, name: String)
}

pub fn query_competition(id: Int) -> Result(CompetitionQuery, Nil) {
  let assert Ok(html_doc) = kacr_request(id) as "Competition is invalid"

  let query =
    soup.element([
      soup.class("statistics"),
    ])

  //   let assert Ok(_) = soup.find(in: html_doc, matching: query)
  //     as "Competition is invalid (KACR does not track registrations)"

  use vacancies <- result.try(extract_vacancies(html_doc))
  use signed_up <- result.try(extract_signed_up(html_doc))
  use name <- result.try(extract_name(html_doc))

  Ok(CompetitionQuery(id, vacancies, signed_up, name))
}

fn extract_name(html_doc: String) -> Result(String, Nil) {
  let name_query =
    soup.element([soup.tag("div"), soup.id("container")])
    |> soup.descendant([soup.tag("h1")])

  soup.find(html_doc, matching: name_query)
  |> scraper.get_first_text
}

fn extract_signed_up(html_doc: String) -> Result(Int, Nil) {
  let statistics_query =
    soup.element([soup.class("statistics")])
    |> soup.descendant([soup.tag("tbody")])

  use tables <- result.try(soup.find_all(html_doc, matching: statistics_query))
  use processed_statistics <- result.try(
    tables
    |> list.map(process_single_day)
    |> list.first,
  )
  processed_statistics
}

fn process_single_day(table: soup.Element) -> Result(Int, Nil) {
  use rows <- result.try(
    Ok(table)
    |> scraper.get_children
    |> result.map(scraper.filter_elements(_, "tr")),
  )

  case list.length(rows) > 2 {
    True -> process_table_rows(rows)
    False -> Error(Nil)
  }
}

fn process_table_rows(rows: List(soup.Element)) -> Result(Int, Nil) {
  let signed_ups =
    scraper.penultimate(rows)
    |> scraper.get_children
    |> result.map(scraper.filter_elements(_, "td"))
    |> result.map(list.map(_, summary_column_info))

  // All taken slots
  echo signed_ups

  signed_ups
  |> result.try(list.first)
  |> result.flatten
}

fn summary_column_info(el: soup.Element) -> Result(Int, Nil) {
  Ok(el)
  |> scraper.get_children
  |> result.try(scraper.penultimate)
  |> scraper.get_first_text
  |> result.try(int.parse)
}

fn extract_vacancies(html_doc: String) -> Result(Int, Nil) {
  let vacancies_query =
    soup.element([soup.tag("td"), soup.class("red")])
    |> soup.descendant([soup.tag("span")])

  soup.find(html_doc, matching: vacancies_query)
  |> scraper.get_first_text
  |> result.try(parse_vacancies_text)
  //|> result.replace_error("Could not determine the number of vacant spots!")
}

fn parse_vacancies_text(text: String) -> Result(Int, Nil) {
  let unlimited_capacity = 10_000
  let assert Ok(capacity_regex) = regexp.from_string("([0-9]+) volných míst")

  case text {
    "∞ volných míst" -> Ok(unlimited_capacity)
    "Žádná volná místa" -> Ok(0)
    other ->
      regexp.scan(capacity_regex, other)
      |> list.first
      |> result.try(fn(match) { list.first(match.submatches) })
      |> result.try(option.to_result(_, Nil))
      |> result.try(int.parse)
  }
}

fn kacr_request(competition_id: Int) -> Result(String, httpc.HttpError) {
  let assert Ok(base_req) =
    request.to(
      "https://kacr.info/competitions/"
      |> string.append(int.to_string(competition_id)),
    )
    as "HTTP Request creation (before sending) failed"

  use resp <- result.try(httpc.send(base_req))

  assert resp.status == 200 as "HTTP Request to KACR failed"
  Ok(resp.body)
}
