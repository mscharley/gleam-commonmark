import commonmark
import commonmark_demo/model.{type Model, Model}
import gleam/io
import lustre/effect

pub type Msg {
  SetTab(model.Tab)
  UpdateInput(String)
}

pub fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    SetTab(tab) -> #(Model(..model, tab: tab), effect.none())
    UpdateInput(input) -> {
      let document = commonmark.parse(input)
      #(
        Model(
          ..model,
          input: input,
          document: document,
          html: commonmark.to_html(document),
        ),
        effect.none(),
      )
    }
  }
}
