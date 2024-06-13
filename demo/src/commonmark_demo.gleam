import commonmark_demo/message.{type Msg, update}
import commonmark_demo/model.{type Model, Model}
import gleam/dynamic
import gleam/io
import gleam/result
import lustre
import lustre/attribute
import lustre/effect
import lustre/element
import lustre/element/html
import lustre/event
import lustre/ui
import lustre/ui/button
import lustre/ui/layout/aside
import pprint

fn init(_flags) -> #(Model, effect.Effect(Msg)) {
  #(io.debug(model.new()), effect.none())
}

fn on_input(event: dynamic.Dynamic) -> Result(Msg, dynamic.DecodeErrors) {
  use target <- result.try(dynamic.field("target", dynamic.dynamic)(event))
  use value <- result.try(dynamic.field("value", dynamic.string)(target))
  // do your stuff!
  Ok(message.UpdateInput(value))
}

fn tab_button(
  model: Model,
  tab: model.Tab,
  label: String,
) -> element.Element(Msg) {
  ui.button(
    [
      event.on_click(message.SetTab(tab)),
      attribute.style([#("margin-right", "1em")]),
      case model.tab == tab {
        True -> button.primary()
        False -> button.outline()
      },
    ],
    [element.text(label)],
  )
}

fn view(model: Model) -> element.Element(Msg) {
  ui.centre(
    [],
    ui.aside(
      [
        aside.content_first(),
        aside.align_centre(),
        attribute.style([
          #("width", "100vw"),
          #("--gap", "1em"),
          #("--min", "40%"),
        ]),
      ],
      html.textarea(
        [
          event.on("input", on_input),
          attribute.style([
            #("padding", "0.25em"),
            #("max-width", "50%"),
            #("height", "100vh"),
            #("background", "#eeeeee"),
            #("flex-grow", "1"),
            #(
              "font-family",
              "ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,Liberation Mono,Courier New,monospace;",
            ),
          ]),
        ],
        model.input,
      ),
      html.div(
        [
          attribute.style([
            #("max-width", "50%"),
            #("height", "100vh"),
            #("overflow-y", "scroll"),
          ]),
        ],
        [
          html.div([], [
            html.div([attribute.style([#("margin", "0.75em 0")])], [
              tab_button(model, model.Preview, "Preview"),
              tab_button(model, model.AST, "AST"),
            ]),
            case model.tab {
              model.AST ->
                html.div([], [
                  html.pre([attribute.style([#("white-space", "pre-wrap")])], [
                    element.text(pprint.format(model.document)),
                  ]),
                ])
              model.Preview ->
                ui.prose(
                  [attribute.attribute("dangerous-unescaped-html", model.html)],
                  [],
                )
            },
          ]),
        ],
      ),
    ),
  )
}

pub fn main() {
  let app = lustre.application(init, update, view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}
