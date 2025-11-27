use rustler::{Env, ResourceArc};
use std::collections::HashMap;
use std::panic::RefUnwindSafe;
use tantivy::collector::TopDocs;
use tantivy::query::{BooleanQuery, Occur, PhraseQuery, Query, QueryParser, RegexQuery, TermQuery};
use tantivy::schema::FieldType;
use tantivy::snippet::SnippetGenerator;
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

/// Performs a query using Tantivy's QueryParser with natural syntax
/// Supports: field:value, AND/OR, phrase queries "exact match", etc.
pub fn searcher_search_query<'a>(
    env: rustler::Env<'a>,
    searcher_res: ResourceArc<SearcherResource>,
    query_string: String,
    default_fields: Vec<String>,
    limit: usize,
) -> Result<rustler::Term<'a>, String> {
    let searcher = &searcher_res.searcher;
    let schema = searcher.index().schema();

    // Convert default field names to Field references
    let mut fields = Vec::new();
    for field_name in &default_fields {
        let field = schema
            .get_field(field_name)
            .map_err(|_| format!("Field '{}' not found in schema", field_name))?;
        fields.push(field);
    }

    if fields.is_empty() {
        return Err("At least one default field must be provided".to_string());
    }

    // Create QueryParser with default fields
    let query_parser = QueryParser::for_index(searcher.index(), fields);

    // Parse the query string
    let query = query_parser
        .parse_query(&query_string)
        .map_err(|e| format!("Failed to parse query '{}': {}", query_string, e))?;

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

/// Performs a query with snippet highlighting
/// Returns matching words highlighted in context
pub fn searcher_search_with_snippets<'a>(
    env: rustler::Env<'a>,
    searcher_res: ResourceArc<SearcherResource>,
    query_string: String,
    default_fields: Vec<String>,
    snippet_fields: Vec<String>,
    max_snippet_chars: usize,
    limit: usize,
) -> Result<rustler::Term<'a>, String> {
    let searcher = &searcher_res.searcher;
    let schema = searcher.index().schema();

    // Convert default field names to Field references
    let mut fields = Vec::new();
    for field_name in &default_fields {
        let field = schema
            .get_field(field_name)
            .map_err(|_| format!("Field '{}' not found in schema", field_name))?;
        fields.push(field);
    }

    if fields.is_empty() {
        return Err("At least one default field must be provided".to_string());
    }

    // Create QueryParser with default fields
    let query_parser = QueryParser::for_index(searcher.index(), fields);

    // Parse the query string
    let query = query_parser
        .parse_query(&query_string)
        .map_err(|e| format!("Failed to parse query '{}': {}", query_string, e))?;

    // Execute the search
    let top_docs = searcher
        .search(&*query, &TopDocs::with_limit(limit))
        .map_err(|e| format!("Search failed: {}", e))?;

    // Create snippet generators for requested fields
    let mut snippet_generators = HashMap::new();
    for field_name in &snippet_fields {
        let field = schema
            .get_field(field_name)
            .map_err(|_| format!("Snippet field '{}' not found in schema", field_name))?;

        // Check if field is a text field
        let field_entry = schema.get_field_entry(field);
        if !matches!(field_entry.field_type(), FieldType::Str(_)) {
            continue; // Skip non-text fields
        }

        let mut generator = SnippetGenerator::create(searcher, &*query, field)
            .map_err(|e| format!("Failed to create snippet generator: {}", e))?;

        generator.set_max_num_chars(max_snippet_chars);
        snippet_generators.insert(field_name.clone(), generator);
    }

    // Convert results to Elixir format with snippets
    let total_hits = top_docs.len();
    let mut hits = Vec::new();

    for (score, doc_address) in top_docs {
        let doc: TantivyDocument = searcher
            .doc(doc_address)
            .map_err(|e| format!("Failed to retrieve document: {}", e))?;

        let hit_map = document_to_hit_map_with_snippets(
            env,
            &schema,
            &doc,
            score,
            &snippet_generators,
        );
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

/// Performs a prefix search for autocomplete/typeahead
/// Searches for terms starting with the given prefix
pub fn searcher_search_prefix<'a>(
    env: rustler::Env<'a>,
    searcher_res: ResourceArc<SearcherResource>,
    field_name: String,
    prefix: String,
    limit: usize,
) -> Result<rustler::Term<'a>, String> {
    let searcher = &searcher_res.searcher;
    let schema = searcher.index().schema();

    // Get the field
    let field = schema
        .get_field(&field_name)
        .map_err(|_| format!("Field '{}' not found in schema", field_name))?;

    // Check if field is a text field
    let field_entry = schema.get_field_entry(field);
    if !matches!(field_entry.field_type(), FieldType::Str(_)) {
        return Err(format!(
            "Field '{}' is not a text field. Prefix search only works on text fields.",
            field_name
        ));
    }

    // Create a regex pattern for prefix matching
    // Note: Tantivy's RegexQuery uses tantivy-fst which has limitations
    // We use a simple approach: ^prefix[a-z]* for lowercase text
    if prefix.is_empty() {
        return Err("Prefix cannot be empty".to_string());
    }

    let escaped_prefix = regex::escape(&prefix.to_lowercase());
    // Match the prefix followed by any word characters
    // [a-z0-9]* allows zero or more alphanumeric chars (matches exact term too)
    let pattern = format!("{}[a-z0-9]*", escaped_prefix);

    let regex_query = RegexQuery::from_pattern(&pattern, field)
        .map_err(|e| format!("Failed to create prefix query: {}", e))?;

    // Execute the search
    let top_docs = searcher
        .search(&regex_query, &TopDocs::with_limit(limit))
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

/// Converts a Tantivy document to an Elixir hit map with snippets
fn document_to_hit_map_with_snippets<'a>(
    env: rustler::Env<'a>,
    schema: &tantivy::schema::Schema,
    doc: &TantivyDocument,
    score: f32,
    snippet_generators: &HashMap<String, SnippetGenerator>,
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

    // Generate snippets for requested fields
    let mut snippets_map: HashMap<String, rustler::Term> = HashMap::new();

    for (field_name, generator) in snippet_generators {
        let snippet = generator.snippet_from_doc(doc);
        let snippet_html = snippet.to_html();
        snippets_map.insert(field_name.clone(), snippet_html.encode(env));
    }

    let snippets_elixir_map = snippets_map.encode(env);

    // Create the hit map with score, doc, and snippets
    map::map_new(env)
        .map_put("score".encode(env), score.encode(env))
        .ok()
        .unwrap()
        .map_put("doc".encode(env), doc_map)
        .ok()
        .unwrap()
        .map_put("snippets".encode(env), snippets_elixir_map)
        .ok()
        .unwrap()
}

pub fn load(env: Env) -> bool {
    rustler::resource!(SearcherResource, env);
    true
}
