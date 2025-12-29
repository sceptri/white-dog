import gleam/string

pub fn prepare_body(body: String) -> String {
  body
  |> string.replace("\r\n", "\n")
  |> string.replace("\n", "\r\n")
}
