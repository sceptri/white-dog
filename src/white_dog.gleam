import dot_env
import dot_env/env
import gleam/erlang/process
import mist
import web/router
import web/web.{Context}
import wisp
import wisp/wisp_mist

pub fn main() {
  // let start_time = timestamp.system_time()

  //   let competition_id = 5503
  //   let assert Ok(competition) = kacr.query_competition(competition_id)
  //   echo competition

  // let end_time = timestamp.system_time()
  // echo timestamp.difference(start_time, end_time)
  //   |> duration.to_seconds
  //   |> fn(time) { time *. 1000.0 }

  wisp.configure_logger()

  dot_env.new()
  |> dot_env.set_path(".env")
  |> dot_env.set_debug(False)
  |> dot_env.load

  let assert Ok(secret_key_base) = env.get_string("SECRET_KEY_BASE")

  let ctx = Context(static_directory: static_directory(), items: [])
  let handler = router.handle_request(_, ctx)

  let assert Ok(_) =
    wisp_mist.handler(handler, secret_key_base)
    |> mist.new
    |> mist.port(8000)
    |> mist.start

  process.sleep_forever()

  Ok(Nil)
}

fn static_directory() {
  let assert Ok(priv_directory) = wisp.priv_directory("white_dog")
  priv_directory <> "/static"
}
