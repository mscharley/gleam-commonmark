//// This module defines the Markdown AST used.
////
//// This AST can be used to manipulate markdown documents or render them with your own
//// algorithm.
////
//// CommonMark defines two major types of elements which have a hierarchical relationship:
////
//// * A Document has many blocks.
//// * A block has zero or more inline elements that make up it's content.
//// * Inline elements define the textual contents of the document.

import gleam/dict.{type Dict}
import gleam/option.{type Option}

pub type InlineNode {
  CodeSpan(contents: String)
  Emphasis(contents: List(InlineNode))
  StrongEmphasis(contents: List(InlineNode))
  Link(title: List(InlineNode), href: String)
  Image(title: String, href: String)
  Autolink(href: String)
  HtmlInline(html: String)
  /// Text contents shouldn't contain line breaks. See HardLineBreak and SoftLineBreak for the canonical representation of line breaks that renderers can make decisions about.
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
  CodeBlock(info: Option(String), full_info: Option(String), contents: String)
  HtmlBlock(html: String)
  LinkReference(name: String, href: String)
  Paragraph(contents: List(InlineNode))
  BlockQuote(contents: List(BlockNode))
  OrderedList(contents: List(ListItem))
  UnorderedList(contents: List(ListItem))
}

pub type Document {
  Document(blocks: List(BlockNode), references: Dict(String, String))
}
