//// This module defines the Markdown AST used.
////
//// This AST can be used to manipulate markdown documents or render them with your own
//// algorithm.
////
//// CommonMark defines two major types of elements which have a hierarchical relationship:
////
//// * A Document has many blocks.
//// * A block contains either other blocks or a list of inline elements
//// * Inline elements define the textual contents of the document.

import gleam/dict.{type Dict}
import gleam/option.{type Option}

/// The emphasis marker used to generate an emphasis inline element.
pub type EmphasisMarker {
  AsteriskEmphasisMarker
  UnderscoreEmphasisMarker
}

/// Inline nodes are used to define the formatting and individual elements that appear in a
/// document.
pub type InlineNode {
  CodeSpan(contents: String)
  Emphasis(contents: List(InlineNode), marker: EmphasisMarker)
  StrongEmphasis(contents: List(InlineNode), marker: EmphasisMarker)
  StrikeThrough(contents: List(InlineNode))
  Link(contents: List(InlineNode), title: Option(String), href: String)
  ReferenceLink(contents: List(InlineNode), ref: String)
  Image(alt: String, title: Option(String), href: String)
  ReferenceImage(alt: String, ref: String)
  UriAutolink(href: String)
  EmailAutolink(href: String)
  HtmlInline(html: String)
  /// Literal text content that should be rendered as-is. In particular, this means that the
  /// content is not HTML-safe, nor is any other precaution taken for specific renderers. Renderers
  /// should take appropriate precautions to make sure that this text is displayed as presented.
  ///
  /// Text content shouldn't normally contain line breaks. See `HardLineBreak` and `SoftLineBreak`
  /// for the canonical representation of line breaks that renderers can make decisions about. The
  /// exception is `CodeBlock(Text(""))` which may contain line breaks (standardised to `"\n"`) as
  /// the full block of text inside the `CodeBlock` is returned as a single pre-formatted text blob.
  PlainText(contents: String)
  HardLineBreak
  SoftLineBreak
}

/// Represents a single item in a list.
///
/// Standardised markdown rendering should not output paragraph tags inside a tight list item. The
/// intention here is to try to mirror the visual style of the original document, where tight items
/// are grouped together tightly.
pub type ListItem {
  /// A "loose" list item.
  ListItem(contents: List(BlockNode))
  /// A "tight" list item.
  TightListItem(contents: List(BlockNode))
}

/// The list marker used to define an ordered list.
pub type OrderedListMarker {
  /// The list used a `.` as the marker for the ordered list.
  PeriodListMarker
  /// The list used a `)` as the marker for the ordered list.
  BracketListMarker
}

/// The list marker used to define an unordered list.
pub type UnorderedListMarker {
  /// The list used a `-` as the marker for the unordered list.
  DashListMarker
  /// The list used a `+` as the marker for the unordered list.
  PlusListMarker
  /// The list used a `*` as the marker for the unordered list.
  AsteriskListMarker
}

/// The level of the alert.
pub type AlertLevel {
  NoteAlert
  TipAlert
  ImportantAlert
  WarningAlert
  CautionAlert
}

/// Block nodes are used to define the overall structure of a document.
pub type BlockNode {
  HorizontalBreak
  Heading(level: Int, contents: List(InlineNode))
  CodeBlock(info: Option(String), full_info: Option(String), contents: String)
  HtmlBlock(html: String)
  Paragraph(contents: List(InlineNode))
  BlockQuote(contents: List(BlockNode))
  AlertBlock(level: AlertLevel, contents: List(BlockNode))
  OrderedList(contents: List(ListItem), start: Int, marker: OrderedListMarker)
  UnorderedList(contents: List(ListItem), marker: UnorderedListMarker)
}

/// A reference used with ReferenceLink nodes.
pub type Reference {
  Reference(href: String, title: Option(String))
}

/// A dictionary of references keyed by the name of the reference.
pub type ReferenceList =
  Dict(String, Reference)

/// Documents contain all the information necessary to render a document, both structural and
/// metadata.
pub type Document {
  Document(blocks: List(BlockNode), references: ReferenceList)
}

/// Errors that can occur while rendering.
pub type RenderError {
  /// There was a link or image that points to a reference which doesn't exist.
  MissingReference(reference: String)
}
