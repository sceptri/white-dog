import web/models/competition
import web/pages/home

pub fn home(events: List(competition.AbstractCompetition)) {
  home.root(events)
}
