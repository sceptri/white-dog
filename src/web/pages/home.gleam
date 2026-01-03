import gleam/int
import gleam/list
import gleam/option
import gleam/string
import lustre/attribute.{class, href, title}
import lustre/element.{type Element, text}
import lustre/element/html.{button, div, h1, hr}
import web/models/competition.{type AbstractCompetition}

pub fn root(events: List(AbstractCompetition)) -> Element(t) {
  div([class("app")], [
    h1([class("app-title")], [text("Předskokan 🐶")]),
    competition_list(events),
  ])
}

fn competition_list(events: List(AbstractCompetition)) -> Element(t) {
  div([class("competitions")], [
    div([class("competitions-inner")], [
      div(
        [class("competitions-list")],
        events
          |> list.map(each_competition),
      ),
      no_competitions(),
    ]),
  ])
}

fn each_competition(event: AbstractCompetition) -> Element(t) {
  div(
    [class("competition")],
    [
      div([class("competition-header")], [
        html.p([class("competition-title")], [text(event.name)]),
        html.p([class("competition-title")], [
          text(competition.stringify_competition_date(event)),
        ]),
      ]),
      hr([]),
      div([class("competition-info")], [
        div([class("competition-info-row")], [
          competition_occupancy(event),
          html.p([], [competition_deadline(event)]),
        ]),
        div([class("competition-info-row")], [
          button([class("competition-watch")], [text("Sledovat")]),
          competition_external_links(event),
        ]),
      ]),
    ]
      |> list.append(competition_info(event)),
  )
}

fn no_competitions() -> Element(t) {
  div([class("competitions-empty")], [])
}

fn competition_external_links(event: AbstractCompetition) -> Element(t) {
  let link_text = case event.origin {
    competition.KACR(id) -> "KAČR (ID:" <> int.to_string(id) <> ")"
    competition.Dogco(id) -> "Dogco (ID:" <> int.to_string(id) <> ")"
  }

  let link_url = case event.origin {
    competition.KACR(id) ->
      "https://kacr.info/competitions/" <> int.to_string(id)
    competition.Dogco(id) -> "https://dogco.cz/zavod?id=" <> int.to_string(id)
  }

  let origin_a =
    html.a([href(link_url), class("competition-link")], [text(link_text)])

  case event.info {
    option.None -> origin_a
    option.Some(info) ->
      case info.agigames_id {
        option.None -> origin_a
        option.Some(agigames) ->
          html.p([], [
            origin_a,
            text(" | "),
            html.a(
              [
                href(
                  "https://new.agigames.cz/tv_home.php?zid="
                  <> int.to_string(agigames),
                ),
                class("competition-link"),
              ],
              [text("Agigames (ID: " <> int.to_string(agigames) <> ")")],
            ),
          ])
      }
  }
}

fn competition_deadline(event: AbstractCompetition) -> Element(t) {
  case event {
    competition.LockedCompetition(_, _, _, _, _) -> text("")
    competition.Competition(_, _, _, _, _, deadline) ->
      case deadline {
        option.None ->
          text("Deadline na přihlašování je neznámý nebo již skončilo.")
        option.Some(deadline_date) ->
          text("Deadline: " <> competition.date_to_string(deadline_date))
      }
  }
}

fn competition_occupancy(event: AbstractCompetition) -> Element(t) {
  case event {
    competition.LockedCompetition(_, _, _, _, _) ->
      html.p([], [text("Nedostupná obsazenost")])
    competition.Competition(_, _, days, _, _, _) ->
      html.div(
        [class("competition-occupancy")],
        list.append(
          [text("Obsazenost: ")],
          days
            |> list.filter_map(fn(day) {
              case day.occupancy {
                option.Some(daily_occupancy) -> Ok(#(daily_occupancy, day.date))
                option.None -> Error(Nil)
              }
            })
            |> list.map(fn(day) {
              let #(daily_occupancy, date) = day

              html.p(
                [
                  title(
                    competition.date_to_string(date)
                    <> ": ("
                    <> daily_occupancy.signed_up
                    |> list.map(int.to_string)
                    |> string.join(with: ", ")
                    <> ")",
                  ),
                ],
                case daily_occupancy {
                  competition.Finite(signed_up, capacity) -> [
                    html.u([], [
                      text(int.to_string(list.fold(signed_up, 0, int.add))),
                    ]),
                    text("/" <> int.to_string(capacity)),
                  ]
                  competition.Infinite(signed_up) -> [
                    text(
                      int.to_string(list.fold(signed_up, 0, int.add)) <> "/∞",
                    ),
                  ]
                },
              )
            }),
        ),
      )
  }
}

fn competition_info(event: AbstractCompetition) -> List(Element(t)) {
  case event.info {
    option.None -> []
    option.Some(info) -> [
      html.details([], [
        html.summary([class("competition-more-info-summary")], [
          text("Podrobnosti:"),
        ]),
        div(
          [class("competition-more-info")],
          [
            div([class("competition-info-row")], [
              html.p([], [text("Místo: " <> info.location)]),
              html.p([], [
                text(case info.gps {
                  option.None -> ""
                  option.Some(gps) -> competition.gps_to_string(gps)
                }),
              ]),
            ]),
            div([class("competition-info-row")], [
              html.p([], [
                text("Web: "),
                html.a([class("competition-link"), href(info.web)], [
                  text("Odkaz"),
                ]),
              ]),
              html.p([], [
                text(
                  list.fold(info.judge, "", fn(text, judge) {
                    case text {
                      "" -> "Rozhodčí: " <> judge
                      so_far -> so_far <> ", " <> judge
                    }
                  }),
                ),
              ]),
            ]),
          ]
            |> list.append(competition_conditions(info))
            |> list.append(competition_note(info)),
        ),
      ]),
    ]
  }
}

fn competition_conditions(info: competition.CompetitionInfo) -> List(Element(t)) {
  case info.conditions {
    option.None -> []
    option.Some(conditions) -> [
      div([class("competition-info-row")], [
        html.p([], [text("Podmínky: " <> conditions)]),
      ]),
    ]
  }
}

fn competition_note(info: competition.CompetitionInfo) -> List(Element(t)) {
  case info.note {
    option.None -> []
    option.Some(note) -> [
      div([class("competition-info-row")], case string.contains(note, "<") {
        True ->
          list.append([html.p([class("note-header")], [text("Poznámka: ")])], [
            element.unsafe_raw_html("note", "div", [], note),
          ])
        False -> [
          html.p([class("note-header")], [
            text("Poznámka: " <> note),
          ]),
        ]
      }),
    ]
  }
}
