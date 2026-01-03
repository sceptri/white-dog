import gleam/function
import gleam/http/request
import gleam/httpc
import gleam/int
import gleam/list
import gleam/option
import gleam/order
import gleam/regexp
import gleam/result
import gleam/string
import gleam/time/calendar
import web/models/competition

import presentable_soup as soup
import scraper/utils as scraper

const unlimited_capacity = 10_000

pub fn query_competition(
  id: Int,
) -> Result(competition.AbstractCompetition, Nil) {
  let assert Ok(html_doc) = kacr_request(id) as "Competition is invalid"

  let query =
    soup.element([
      soup.class("statistics"),
    ])

  //   let assert Ok(_) = soup.find(in: html_doc, matching: query)
  //     as "Competition is invalid (KACR does not track registrations)"

  let signed_up = extract_occupancy(html_doc)
  let days_only = extract_days_only(html_doc)
  let info = extract_details(html_doc)
  let deadline = extract_deadline(html_doc)

  use name <- result.try(extract_name(html_doc))

  case signed_up {
    Ok(days) if days != [] ->
      Ok(competition.Competition(
        id: int.to_string(id),
        name: name,
        days: days,
        origin: competition.KACR(id),
        deadline: option.from_result(deadline),
        info: option.from_result(info),
      ))
    Error(_) | Ok(_) ->
      case days_only {
        Ok(days_only) ->
          Ok(competition.LockedCompetition(
            id: int.to_string(id),
            name: name,
            days: days_only,
            origin: competition.KACR(id),
            info: option.from_result(info),
          ))

        Error(_) -> Error(Nil)
      }
  }
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

fn extract_details(html_doc: String) -> Result(competition.CompetitionInfo, Nil) {
  let details_query =
    soup.element([soup.class("summary")])
    |> soup.descendant([soup.tag("span")])

  use all_info <- result.try(soup.find_all(html_doc, matching: details_query))
  let info_pairs =
    all_info
    |> list.window_by_2
    |> list.filter_map(fn(pair) {
      let #(name, value) = pair
      use name_text <- result.map(scraper.get_first_text(Ok(name)))
      #(name_text, value)
    })

  use terrain <- result.try(
    list.key_find(info_pairs, "Terén: ")
    |> scraper.get_first_text,
  )

  use inside <- result.try(
    list.key_find(info_pairs, "Uvnitř: ")
    |> scraper.get_first_text,
  )

  let conditions = case inside {
    "Ano" -> "Uvnitř - " <> terrain
    "Ne" -> "Venku - " <> terrain
    _ -> terrain
  }

  use judge <- result.try(
    list.key_find(info_pairs, "Rozhodčí: ")
    |> scraper.get_children
    |> result.map(scraper.filter_elements(_, tag: "a"))
    |> result.map(list.map(_, fn(el) { scraper.get_first_text(Ok(el)) }))
    |> result.map(list.filter_map(_, function.identity)),
  )

  use web <- result.try(
    list.key_find(info_pairs, "Propozice: ")
    |> scraper.get_children
    |> result.try(list.last)
    |> scraper.get_first_text,
  )

  use location <- result.try(
    list.key_find(info_pairs, "Upřesnění místa: ")
    |> scraper.get_first_text,
  )

  use gps <- result.try(
    list.key_find(info_pairs, "GPS: ")
    |> scraper.get_children
    |> result.try(list.last)
    |> scraper.get_first_text
    |> result.try(competition.string_to_gps),
  )

  let note_query = soup.element([soup.class("markdown")])

  use note <- result.try(
    soup.find_all(html_doc, matching: note_query)
    |> result.map(list.drop(_, up_to: 1))
    |> result.try(list.first)
    |> scraper.get_children
    |> result.map(soup.elements_to_string),
  )

  Ok(competition.CompetitionInfo(
    gps: option.Some(gps),
    location: location,
    judge: judge,
    web: web,
    // Should it be like this?
    agigames_id: option.None,
    conditions: option.Some(conditions),
    note: option.Some(note),
  ))
}

fn extract_days_only(html_doc: String) -> Result(List(calendar.Date), Nil) {
  let details_query =
    soup.element([soup.class("summary")])
    |> soup.descendant([soup.tag("span")])

  use all_info <- result.try(soup.find_all(html_doc, matching: details_query))
  let info_pairs =
    all_info
    |> list.window_by_2
    |> list.filter_map(fn(pair) {
      let #(name, value) = pair
      use name_text <- result.map(scraper.get_first_text(Ok(name)))
      #(name_text, value)
    })

  use days_range <- result.try(
    list.key_find(info_pairs, "Datum: ")
    |> scraper.get_first_text,
  )

  case string.split(days_range, " - ") {
    [from, to] -> {
      use from_date <- result.try(competition.string_to_date(from))
      use to_date <- result.try(competition.string_to_date(to))

      get_date_range(from_date, to_date)
    }
    [only] ->
      case competition.string_to_date(only) {
        Ok(only) -> Ok([only])
        Error(_) -> Error(Nil)
      }
    _ -> Error(Nil)
  }
}

// TODO: Add deadline in the past
fn extract_deadline(html_doc: String) -> Result(calendar.Date, Nil) {
  let deadline_query = soup.element([soup.tag("p")])

  soup.find(html_doc, matching: deadline_query)
  |> scraper.get_first_text
  |> result.try(fn(text) {
    case text {
      "Přihlašování na tento závod je otevřené, končí " <> date_and_time -> {
        case string.split(date_and_time, " v ") {
          [date, _] -> competition.string_to_date(date)
          _ -> Error(Nil)
        }
      }
      _ -> Error(Nil)
    }
  })
}

fn get_date_range(
  from start_date: calendar.Date,
  to end_date: calendar.Date,
) -> Result(List(calendar.Date), Nil) {
  case calendar.naive_date_compare(start_date, end_date) {
    order.Gt -> Error(Nil)
    order.Eq -> Ok([start_date])
    order.Lt ->
      case get_date_range(next_day(start_date), end_date) {
        Ok(range) -> Ok(list.append([start_date], range))
        Error(_) -> Error(Nil)
      }
  }
}

fn next_day(date: calendar.Date) -> calendar.Date {
  let next = calendar.Date(date.year, date.month, date.day + 1)
  case calendar.is_valid_date(next) {
    True -> next
    False -> {
      let next_month =
        calendar.month_from_int(calendar.month_to_int(date.month) + 1)
      case next_month {
        Ok(month) -> calendar.Date(date.year, month, 1)
        Error(_) -> calendar.Date(date.year + 1, calendar.January, 1)
      }
    }
  }
}
