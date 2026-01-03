import gleam/list
import gleam/result
import presentable_soup as soup

pub fn get_first_text(element: Result(soup.Element, Nil)) -> Result(String, Nil) {
  element
  |> get_children
  |> result.try(list.first)
  |> result.try(fn(el_text) {
    case el_text {
      soup.Text(text) -> Ok(text)
      _ -> Error(Nil)
    }
  })
}

pub fn get_children(
  element: Result(soup.Element, Nil),
) -> Result(List(soup.Element), Nil) {
  result.try(element, fn(el) {
    case el {
      soup.Element(_, _, children) -> Ok(children)
      _ -> Error(Nil)
    }
  })
}

pub fn penultimate(collection: List(a)) -> Result(a, Nil) {
  list.reverse(collection)
  |> list.drop(1)
  |> list.first
}

pub fn filter_elements(
  collection: List(soup.Element),
  tag tag: String,
) -> List(soup.Element) {
  list.filter(collection, fn(el) {
    case el {
      soup.Element(used_tag, _, _) -> used_tag == tag
      _ -> False
    }
  })
}

pub fn drop_last(from collection: List(a)) -> List(a) {
  collection
  |> list.reverse
  |> list.drop(up_to: 1)
  |> list.reverse
}
