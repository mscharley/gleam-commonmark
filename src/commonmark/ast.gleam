pub type InlineNode {
  CodeSpan(contents: String)
  Emphasis(contents: List(InlineNode))
  Link(title: List(InlineNode), href: String)
  Image(title: String, href: String)
  Autolink(href: String)
  // HtmlInline() // TODO: [SPEC 6.6]
  Text(contents: String)
  HardLineBreak
  SoftLineBreak
}

pub type ListItem {
  ListItem(contents: List(BlockNode))
}

pub type BlockNode {
  HorizontalBreak
  Heading(level: Int, contents: List(InlineNode))
  CodeBlock(info: String, contents: String)
  // HtmlBlock() // TODO: [SPEC 4.6]
  // LinkReference
  Paragraph(contents: List(InlineNode))
  BlockQuote(contents: List(BlockNode))
  OrderedList(contents: List(ListItem))
  UnorderedList(contents: List(ListItem))
}

pub type Document {
  Document(blocks: List(BlockNode))
}
