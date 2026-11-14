///|
/// Stability annotations retained from WIT source.
#derive(Eq, Debug)
pub struct Attributes {
  since : String?
  unstable : String?
  deprecated : String?
}

///|
fn Attributes::empty() -> Attributes {
  { since: None, unstable: None, deprecated: None, }
}

///|
fn Attributes::is_empty(self : Attributes) -> Bool {
  self.since is None && self.unstable is None && self.deprecated is None
}

///|
/// Options shared by string, multi-file, and filesystem resolution.
pub struct ResolveOptions {
  features : Array[String]
  all_features : Bool
  target_version : String?
}

///|
pub fn ResolveOptions::new(
  features~ : Array[String] = [],
  all_features~ : Bool = false,
  target_version? : String,
) -> ResolveOptions {
  { features, all_features, target_version, }
}

///|
#derive(Eq, Debug)
pub struct TopLevelUse {
  from : UsePath
  name : String
  attributes : Attributes
}

///|
pub extend Attributes with Eq::{equal, not_equal}

///|
pub extend Attributes with Debug::{to_repr}

///|
pub extend TopLevelUse with Eq::{equal, not_equal}

///|
pub extend TopLevelUse with Debug::{to_repr}

///|
fn world_item_annotations(item : WorldItem) -> (WorldItem, Attributes, String?) {
  match item {
    Attributed(attributes, item) => {
      let (item, _, external_id) = world_item_annotations(item)
      (item, attributes, external_id)
    }
    External(id, item) => {
      let (item, attributes, _) = world_item_annotations(item)
      (item, attributes, Some(id))
    }
    _ => (item, Attributes::empty(), None)
  }
}
