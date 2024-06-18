import commonmark/demo/model.{type Model, type Msg, Model}
import gleam/dynamic
import gleam/result
import lustre/attribute
import lustre/element
import lustre/element/html
import lustre/event
import lustre/ui
import lustre/ui/button
import lustre/ui/layout/aside
import pprint

fn on_input(event: dynamic.Dynamic) -> Result(Msg, dynamic.DecodeErrors) {
  use target <- result.try(dynamic.field("target", dynamic.dynamic)(event))
  use value <- result.try(dynamic.field("value", dynamic.string)(target))
  Ok(model.UpdateInput(value))
}

fn tab_button(
  model: Model,
  tab: model.Tab,
  label: String,
) -> element.Element(Msg) {
  ui.button(
    [
      event.on_click(model.SetTab(tab)),
      attribute.style([#("margin-right", "1em")]),
      case model.tab == tab {
        True -> button.primary()
        False -> button.outline()
      },
    ],
    [element.text(label)],
  )
}

fn edit_area(content: String) -> element.Element(Msg) {
  html.textarea(
    [
      event.on("input", on_input),
      attribute.style([
        #("padding", "0.25em"),
        #("max-width", "50%"),
        #("height", "100vh"),
        #("background", "#eeeeee"),
        #("border-right", "2px solid var(--element-border-strong)"),
        #("flex-grow", "1"),
        #("font-family", "var(--font-mono)"),
        #("resize", "none"),
        #("z-index", "1"),
      ]),
    ],
    content,
  )
}

pub fn view(model: Model) -> element.Element(Msg) {
  ui.centre(
    [],
    ui.aside(
      [
        aside.content_first(),
        aside.align_centre(),
        attribute.style([
          #("width", "100vw"),
          #("--gap", "0"),
          #("--min", "50%"),
        ]),
      ],
      edit_area(model.input),
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
            html.div(
              [
                attribute.style([
                  #("padding", "0.75em 1em"),
                  #("width", "100%"),
                  #("position", "sticky"),
                  #("background", "var(--primary-app-background-subtle)"),
                  #("border-bottom", "2px solid var(--element-border-strong)"),
                  #("top", "0"),
                ]),
              ],
              [
                tab_button(model, model.Preview, "Preview"),
                tab_button(model, model.AST, "AST"),
              ],
            ),
            html.div([attribute.style([#("padding", "1em")])], [
              case model.tab {
                model.AST ->
                  html.div([], [
                    html.pre([attribute.style([#("white-space", "pre-wrap")])], [
                      element.text(pprint.format(model.document)),
                    ]),
                  ])
                model.Preview ->
                  ui.prose(
                    [
                      attribute.style([#("width", "100%")]),
                      attribute.attribute(
                        "dangerous-unescaped-html",
                        model.html,
                      ),
                    ],
                    [],
                  )
              },
            ]),
          ]),
        ],
      ),
    ),
  )
}
