import gleam/float
import gleam/int
import gleam/list
import gleam/option.{type Option, None, Some}
import gleam/time/calendar
import scraper/kacr
import wisp

pub type CompetitionOrigin {
  KACR(id: Int)
  Dogco(id: Int)
}

pub type Occupancy {
  Finite(signed_up: List(Int), capacity: Int)
  Infinite(signed_up: List(Int))
}

pub type CompetitionDay {
  CompetitionDay(date: calendar.Date, occupancy: Option(Occupancy))
}

pub type GPSCoordinates {
  GPSCoordinates(latitude: Float, longitude: Float)
}

pub type AbstractCompetition {
  Competition(
    id: String,
    name: String,
    days: List(CompetitionDay),
    origin: CompetitionOrigin,
    info: Option(CompetitionInfo),
    deadline: Option(calendar.Date),
  )
  LockedCompetition(
    id: String,
    name: String,
    days: List(calendar.Date),
    origin: CompetitionOrigin,
    info: Option(CompetitionInfo),
  )
}

pub type CompetitionInfo {
  CompetitionInfo(
    gps: Option(GPSCoordinates),
    location: String,
    judge: List(String),
    web: String,
    agigames_id: Option(Int),
    note: Option(String),
  )
}

pub fn build_from_kacr_query(
  query: kacr.CompetitionQuery,
) -> Result(AbstractCompetition, Nil) {
  Ok(Competition(
    id: wisp.random_string(64),
    name: query.name,
    days: [
      CompetitionDay(
        // TODO: Fix this
        date: calendar.Date(2023, calendar.April, 15),
        occupancy: Some(Finite(
          [query.signed_up],
          query.signed_up + query.vacancies,
        )),
      ),
    ],
    origin: KACR(query.id),
    deadline: None,
    info: None,
  ))
}

pub fn test_competitions() -> List(AbstractCompetition) {
  [
    Competition(
      id: wisp.random_string(64),
      name: "Test",
      days: [
        CompetitionDay(
          calendar.Date(2023, calendar.April, 15),
          Some(Finite([10, 20], 40)),
        ),
        CompetitionDay(calendar.Date(2023, calendar.April, 16), None),
      ],
      origin: KACR(5503),
      deadline: Some(calendar.Date(2023, calendar.March, 15)),
      info: Some(CompetitionInfo(
        gps: Some(GPSCoordinates(17.0, 19.0)),
        location: "Přerov",
        judge: ["Jan Novák", "Pan Starák"],
        web: "https://google.com",
        agigames_id: Some(3117),
        note: Some("..."),
      )),
    ),
    Competition(
      id: wisp.random_string(64),
      name: "Bílany u Kroměříže - Vánoční Bílany 20.12. - 2 x zkouška A1,A3,A2 (1 x Jumping A1,A2,A3 otevřený )",
      days: [
        CompetitionDay(
          calendar.Date(2023, calendar.April, 15),
          Some(Finite([10, 20], 40)),
        ),
        CompetitionDay(
          calendar.Date(2023, calendar.April, 16),
          Some(Finite([15, 20], 45)),
        ),
      ],
      origin: Dogco(123),
      deadline: Some(calendar.Date(2023, calendar.March, 15)),
      info: Some(CompetitionInfo(
        gps: None,
        location: "Přerov",
        judge: ["Jan Novák"],
        web: "https://google.com",
        agigames_id: Some(3117),
        note: None,
      )),
    ),
    Competition(
      id: wisp.random_string(64),
      name: "Nějaký název",
      days: [
        CompetitionDay(
          calendar.Date(2023, calendar.April, 16),
          Some(Finite([10, 20, 5], 50)),
        ),
      ],
      origin: KACR(5505),
      deadline: None,
      info: None,
    ),
    LockedCompetition(
      id: wisp.random_string(64),
      name: "Zamčeno",
      days: [
        calendar.Date(2023, calendar.April, 16),
      ],
      origin: KACR(5504),
      info: None,
    ),
  ]
}

pub fn gps_to_string(gps: GPSCoordinates) -> String {
  "GPS: "
  <> float.to_string(gps.latitude)
  <> ", "
  <> float.to_string(gps.longitude)
}

pub fn date_to_string(input_date: calendar.Date) -> String {
  int.to_string(input_date.day)
  <> "."
  <> int.to_string(calendar.month_to_int(input_date.month))
  <> "."
  <> int.to_string(input_date.year)
}

pub fn stringify_competition_date(event: AbstractCompetition) -> String {
  case event {
    Competition(_, _, days, _, _, _) ->
      days |> list.map(fn(day) { day.date }) |> stringify_date_list
    LockedCompetition(_, _, days, _, _) -> stringify_date_list(days)
  }
}

pub fn stringify_date_list(days: List(calendar.Date)) -> String {
  case list.length(days) {
    0 -> "-"
    1 -> {
      let assert Ok(only_day) = list.first(days)
      date_to_string(only_day)
    }
    _ -> {
      let sorted_dates = days |> list.sort(by: calendar.naive_date_compare)

      let assert Ok(start) = sorted_dates |> list.first
      let assert Ok(end) = sorted_dates |> list.reverse |> list.first

      date_to_string(start) <> "-" <> date_to_string(end)
    }
  }
}
