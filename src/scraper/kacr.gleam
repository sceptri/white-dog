import gleam/function
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/list
import gleam/option
import gleam/regexp
import gleam/result
import gleam/string
import gleam/time/calendar
import web/models/competition

import presentable_soup as soup
import scraper/utils as scraper

pub type CompetitionQuery {
  CompetitionQuery(id: Int, vacancies: Int, signed_up: Int, name: String)
}

const unlimited_capacity = 10_000

pub fn query_competition(id: Int) -> Result(String, Nil) {
  let assert Ok(html_doc) = kacr_request(id) as "Competition is invalid"

  let query =
    soup.element([
      soup.class("statistics"),
    ])

  //   let assert Ok(_) = soup.find(in: html_doc, matching: query)
  //     as "Competition is invalid (KACR does not track registrations)"

  use signed_up <- result.try(extract_occupancy(html_doc))
  echo signed_up
  use name <- result.try(extract_name(html_doc))

  Ok(name)
}

fn extract_name(html_doc: String) -> Result(String, Nil) {
  let name_query =
    soup.element([soup.tag("div"), soup.id("container")])
    |> soup.descendant([soup.tag("h1")])

  soup.find(html_doc, matching: name_query)
  |> scraper.get_first_text
}

fn extract_occupancy(
  html_doc: String,
) -> Result(List(competition.CompetitionDay), Nil) {
  let statistics_query =
    soup.element([soup.class("statistics")])
    |> soup.descendant([soup.tag("tbody")])

  use tables <- result.try(soup.find_all(html_doc, matching: statistics_query))

  tables
  |> list.map(process_single_day)
  |> list.filter_map(function.identity)
  |> Ok
}

fn process_single_day(
  table: soup.Element,
) -> Result(competition.CompetitionDay, Nil) {
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

fn process_table_rows(
  rows: List(soup.Element),
) -> Result(competition.CompetitionDay, Nil) {
  let signed_ups =
    scraper.penultimate(rows)
    |> scraper.get_children
    |> result.map(scraper.filter_elements(_, "td"))
    |> result.map(list.map(_, summary_column_info))
    |> result.map(scraper.drop_last)

  let vacancies =
    list.last(rows)
    |> go_lower_in_table
    |> go_lower_in_table
    |> scraper.get_first_text
    |> result.try(parse_vacancies_text)

  let date =
    list.first(rows)
    |> go_lower_in_table
    |> scraper.get_first_text
    |> result.map(string.replace(in: _, each: "\n", with: ""))
    |> result.try(competition.string_to_date)

  case signed_ups, vacancies, date {
    Ok(signed_ups), Ok(vacancies), Ok(date) -> {
      let ok_signed_ups = list.filter_map(signed_ups, function.identity)
      let signed_up_sum = list.fold(ok_signed_ups, 0, int.add)
      let empty_signed_ups = list.is_empty(ok_signed_ups)

      case vacancies, signed_up_sum, empty_signed_ups {
        _, _, True -> Error(Nil)
        0, 0, False -> Ok(competition.CompetitionDay(date, option.None))
        capacity, _, False if capacity == unlimited_capacity ->
          Ok(competition.CompetitionDay(
            date,
            option.Some(competition.Infinite(ok_signed_ups)),
          ))
        _, signed_up_sum, False ->
          Ok(competition.CompetitionDay(
            date,
            option.Some(competition.Finite(
              ok_signed_ups,
              vacancies + signed_up_sum,
            )),
          ))
      }
    }
    _, _, _ -> Error(Nil)
  }
}

fn go_lower_in_table(
  row: Result(soup.Element, Nil),
) -> Result(soup.Element, Nil) {
  row
  |> scraper.get_children
  |> result.try(scraper.penultimate)
}

fn summary_column_info(el: soup.Element) -> Result(Int, Nil) {
  case el {
    soup.Element(_, attributes, _) -> {
      case list.contains(attributes, #("class", "inactive")) {
        True -> Error(Nil)
        False ->
          Ok(el)
          |> scraper.get_children
          |> result.try(scraper.penultimate)
          |> scraper.get_first_text
          |> result.try(int.parse)
      }
    }
    _ -> Error(Nil)
  }
}

fn parse_vacancies_text(text: String) -> Result(Int, Nil) {
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
