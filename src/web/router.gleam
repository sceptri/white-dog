import gleam/function
import gleam/list
import gleam/result
import lustre/element
import scraper/kacr
import web/models/competition
import web/pages
import web/pages/layout.{layout}
import web/web.{type Context}
import wisp.{type Request, type Response}

pub fn handle_request(req: Request, ctx: Context) -> Response {
  use req <- web.middleware(req, ctx)

  case wisp.path_segments(req) {
    // Homepage
    [] -> {
      [
        pages.home(
          //   [
          //     kacr.query_competition(5503),
          //     kacr.query_competition(5504),
          //     kacr.query_competition(5505),
          //   ]
          //   |> list.filter_map(function.identity)
          //   |> list.map(competition.build_from_kacr_query)
          //   |> list.filter_map(function.identity),
          competition.test_competitions(),
        ),
      ]
      |> layout
      |> element.to_document_string
      |> wisp.html_response(200)
    }

    // All the empty responses
    ["internal-server-error"] -> wisp.internal_server_error()
    ["unprocessable-entity"] -> wisp.unprocessable_content()
    ["method-not-allowed"] -> wisp.method_not_allowed([])
    ["entity-too-large"] -> wisp.content_too_large()
    ["bad-request"] -> wisp.bad_request("Bad request!")
    _ -> wisp.not_found()
  }
}
