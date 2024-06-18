import commonmark
import commonmark/demo/model.{type Model, type Msg, Model, SetTab, UpdateInput}
import lustre/effect

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
