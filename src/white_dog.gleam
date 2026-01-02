import dot_env
import dot_env/env
import gcourier/message
import gcourier/smtp
import gleam/erlang/process
import gleam/option.{Some}
import mail/mailer
import mist
import scraper/kacr
import web/router
import web/web.{Context}
import wisp
import wisp/wisp_mist

pub fn main() {
  // let start_time = timestamp.system_time()

  let competition_id = 5381
  let assert Ok(competition) = kacr.query_competition(competition_id)
    as "Could not scrape this competition!"
  echo competition

  // let end_time = timestamp.system_time()
  // echo timestamp.difference(start_time, end_time)
  //   |> duration.to_seconds
  //   |> fn(time) { time *. 1000.0 }

  let message =
    message.build()
    |> message.set_from("robot@zapadlo.name", Some("Robot"))
    |> message.set_sender("robot@zapadlo.name", Some("Robot"))
    |> message.add_recipient("stepan.zapadlo@gmail.com", message.To)
    |> message.set_subject("You're Invited: Pizza & Ping Pong Night!")
    |> message.set_html(mailer.prepare_body(
      "
      <html>
          <body>
              <h1 style='color:tomato;'>🎈 You're Invited! 🎈</h1>
              <p>Hey friend,</p>
              <p>We're hosting a <strong>Pizza & Ping Pong Night</strong> this Friday at 7 PM. 
              Expect good vibes, cheesy slices, and fierce paddle battles!</p>
              <p>Let us know if you're in. And bring your A-game. 🏓</p>
              <p>Cheers,<br/>The Fun Club</p>
          </body>
      </html>
  ",
    ))

  wisp.configure_logger()

  dot_env.new()
  |> dot_env.set_path(".env")
  |> dot_env.set_debug(False)
  |> dot_env.load

  let assert Ok(mail_password) = env.get_string("MAIL_PASSWORD")

  //   smtp.send(
  //     "smtp.seznam.cz",
  //     587,
  //     Some(#("robot@zapadlo.name", mail_password)),
  //     message,
  //   )

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
