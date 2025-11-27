use rustler::{Env, ResourceArc};
use std::collections::HashMap;
use std::panic::RefUnwindSafe;
use tantivy::collector::TopDocs;
use tantivy::query::{Query, TermQuery};
use tantivy::schema::FieldType;
use tantivy::{Searcher, TantivyDocument};

use crate::reader::ReaderResource;

/// Resource wrapper for Tantivy Searcher
pub struct SearcherResource {
    pub searcher: Searcher,
}

unsafe impl Send for SearcherResource {}
unsafe impl Sync for SearcherResource {}
impl RefUnwindSafe for SearcherResource {}

/// Query definition passed from Elixir
#[derive(Debug, rustler::NifStruct)]
#[module = "Muninn.Query.Term"]
pub struct TermQueryDef {
    pub field: String,
    pub value: String,
}

/// Creates a new Searcher from an IndexReader
pub fn searcher_new(reader_res: ResourceArc<ReaderResource>) -> Result<ResourceArc<SearcherResource>, String> {
    let searcher = reader_res.reader.searcher();

    Ok(ResourceArc::new(SearcherResource { searcher }))
}

/// Performs a term query search, returns native Elixir terms
pub fn searcher_search_term<'a>(
    env: rustler::Env<'a>,
    searcher_res: ResourceArc<SearcherResource>,
    query_def: TermQueryDef,
    limit: usize,
) -> Result<rustler::Term<'a>, String> {
    let searcher = &searcher_res.searcher;
    let schema = searcher.index().schema();

    // Get the field
    let field = schema
        .get_field(&query_def.field)
        .map_err(|_| format!("Field '{}' not found in schema", query_def.field))?;

    // Build the query based on field type
    let query: Box<dyn Query> = {
        let field_entry = schema.get_field_entry(field);
        match field_entry.field_type() {
            FieldType::Str(_) => {
                // For text fields, create a term query
                let term = tantivy::Term::from_field_text(field, &query_def.value);
                Box::new(TermQuery::new(term, Default::default()))
            }
            _ => {
                return Err(format!(
                    "Field '{}' is not a text field. Only text fields are currently supported for term queries.",
                    query_def.field
                ));
            }
        }
    };

    // Execute the search
    let top_docs = searcher
        .search(&*query, &TopDocs::with_limit(limit))
        .map_err(|e| format!("Search failed: {}", e))?;

    // Convert results to Elixir format
    let total_hits = top_docs.len();
    let mut hits = Vec::new();

    for (score, doc_address) in top_docs {
        let doc: TantivyDocument = searcher
            .doc(doc_address)
            .map_err(|e| format!("Failed to retrieve document: {}", e))?;

        let hit_map = document_to_hit_map(env, &schema, &doc, score);
        hits.push(hit_map);
    }

    // Build the result map
    use rustler::types::map;
    use rustler::Encoder;

    let result_map = map::map_new(env)
        .map_put("total_hits".encode(env), total_hits.encode(env))
        .ok()
        .unwrap()
        .map_put("hits".encode(env), hits.encode(env))
        .ok()
        .unwrap();

    Ok(result_map)
}

/// Converts a Tantivy document to an Elixir hit map with score
fn document_to_hit_map<'a>(
    env: rustler::Env<'a>,
    schema: &tantivy::schema::Schema,
    doc: &TantivyDocument,
    score: f32,
) -> rustler::Term<'a> {
    use rustler::types::map;
    use rustler::Encoder;

    // Create the document map
    let mut doc_fields: HashMap<String, rustler::Term> = HashMap::new();

    for field in schema.fields() {
        let field_name = field.1.name().to_string();
        let values: Vec<_> = doc.get_all(field.0).collect();

        // Take the first value (for now, we don't support multi-valued fields)
        if let Some(value) = values.first() {
            match value {
                tantivy::schema::OwnedValue::Str(s) => {
                    doc_fields.insert(field_name, s.as_str().encode(env));
                }
                tantivy::schema::OwnedValue::U64(n) => {
                    doc_fields.insert(field_name, n.encode(env));
                }
                tantivy::schema::OwnedValue::I64(n) => {
                    doc_fields.insert(field_name, n.encode(env));
                }
                tantivy::schema::OwnedValue::F64(n) => {
                    doc_fields.insert(field_name, n.encode(env));
                }
                tantivy::schema::OwnedValue::Bool(b) => {
                    doc_fields.insert(field_name, b.encode(env));
                }
                _ => {} // Skip unsupported types
            }
        }
    }

    // Convert HashMap to Elixir map
    let doc_map = doc_fields.encode(env);

    // Create the hit map with score and doc
    map::map_new(env)
        .map_put("score".encode(env), score.encode(env))
        .ok()
        .unwrap()
        .map_put("doc".encode(env), doc_map)
        .ok()
        .unwrap()
}

pub fn load(env: Env) -> bool {
    rustler::resource!(SearcherResource, env);
    true
}
