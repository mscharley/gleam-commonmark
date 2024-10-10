// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import commonmark.{parse}
import commonmark/demo/model.{type Model, type Msg, Model, SetTab, UpdateInput}
import commonmark/html.{to_html}
import lustre/effect

pub fn update(model: Model, msg: Msg) -> #(Model, effect.Effect(Msg)) {
  case msg {
    SetTab(tab) -> #(Model(..model, tab: tab), effect.none())
    UpdateInput(input) -> {
      let document = parse(input)
      #(
        Model(
          ..model,
          input: input,
          document: document,
          html: to_html(document),
        ),
        effect.none(),
      )
    }
  }
}
