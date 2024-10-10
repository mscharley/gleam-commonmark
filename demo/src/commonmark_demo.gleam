//// This module only exists to give lustre the hardcoded entrypoint it wants

// This Source Code Form is subject to the terms of the Mozilla Public
// License, v. 2.0. If a copy of the MPL was not distributed with this
// file, You can obtain one at http://mozilla.org/MPL/2.0/.

import commonmark/demo/message
import commonmark/demo/model
import commonmark/demo/view
import lustre

pub fn main() {
  let app = lustre.application(model.init, message.update, view.view)
  let assert Ok(_) = lustre.start(app, "#app", Nil)

  Nil
}
