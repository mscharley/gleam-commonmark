//// This module only exists to give lustre the hardcoded entrypoint it wants

import commonmark/demo/message
import commonmark/demo/model
import commonmark/demo/view
import lustre

pub fn main() {
  let app = lustre.application(model.init, message.update, view.view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}
