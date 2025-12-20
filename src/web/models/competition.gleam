import gleam/float
import gleam/int
import gleam/option.{type Option, None, Some}
import gleam/time/calendar
import scraper/kacr
import wisp

pub type CompetitionOrigin {
  KACR(id: Int)
  Dogco(id: Int)
}

pub type CompetitionVariant {
  SingleDay(date: calendar.Date)
  MultiDay(start_date: calendar.Date, end_date: calendar.Date)
}

pub type GPSCoordinates {
  GPSCoordinates(latitude: Float, longitude: Float)
}

pub type Occupancy {
  Finite(signed_up: List(Int), capacity: Int)
  Infinite(signed_up: List(Int))
}

pub type AbstractCompetition {
  Competition(
    id: String,
    name: String,
    date: CompetitionVariant,
    origin: CompetitionOrigin,
    info: Option(CompetitionInfo),
    deadline: Option(calendar.Date),
    occupancy: Occupancy,
  )
  LockedCompetition(
    id: String,
    name: String,
    date: CompetitionVariant,
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
    occupancy: Finite([query.signed_up], query.signed_up + query.vacancies),
    date: SingleDay(calendar.Date(2023, calendar.April, 15)),
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
      occupancy: Finite([10, 20], 40),
      date: MultiDay(
        start_date: calendar.Date(2023, calendar.April, 15),
        end_date: calendar.Date(2023, calendar.April, 16),
      ),
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
      occupancy: Finite([10, 20], 40),
      date: MultiDay(
        start_date: calendar.Date(2023, calendar.April, 15),
        end_date: calendar.Date(2023, calendar.April, 16),
      ),
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
      occupancy: Finite([10, 20, 5], 50),
      date: SingleDay(calendar.Date(2023, calendar.April, 16)),
      origin: KACR(5505),
      deadline: None,
      info: None,
    ),
    LockedCompetition(
      id: wisp.random_string(64),
      name: "Zamčeno",
      date: SingleDay(calendar.Date(2023, calendar.April, 16)),
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

pub fn stringify_competition_date(
  competition_date: CompetitionVariant,
) -> String {
  case competition_date {
    SingleDay(date) -> date_to_string(date)
    MultiDay(start, end) -> date_to_string(start) <> "-" <> date_to_string(end)
  }
}
