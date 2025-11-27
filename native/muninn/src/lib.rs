// Suppress warnings from rustler macro internals
#![allow(unused_must_use, non_local_definitions)]

mod atoms {
    rustler::atoms! {
        ok,
        error,
        // Error atoms
        not_found,
        invalid_schema,
        io_error,
        index_error,
    }
}

mod schema;
mod index;
mod writer;
mod reader;
mod searcher;

// NIF entry point
#[rustler::nif]
fn schema_build(schema_def: schema::SchemaDef) -> Result<rustler::ResourceArc<schema::SchemaResource>, rustler::Error> {
    schema::schema_build(schema_def)
}

#[rustler::nif]
fn schema_num_fields(schema: rustler::ResourceArc<schema::SchemaResource>) -> usize {
    schema.schema.fields().count()
}

#[rustler::nif]
fn index_create(path: String, schema_def: schema::SchemaDef) -> Result<rustler::ResourceArc<index::IndexResource>, String> {
    index::create_index(path, schema_def)
}

#[rustler::nif]
fn index_open(path: String) -> Result<rustler::ResourceArc<index::IndexResource>, String> {
    index::open_index(path)
}

#[rustler::nif]
fn writer_add_document(
    index: rustler::ResourceArc<index::IndexResource>,
    document: rustler::Term,
) -> Result<(), String> {
    writer::writer_add_document(index, document)
}

#[rustler::nif(schedule = "DirtyIo")]
fn writer_commit(index: rustler::ResourceArc<index::IndexResource>) -> Result<(), String> {
    writer::writer_commit(index)
}

#[rustler::nif]
fn writer_rollback(index: rustler::ResourceArc<index::IndexResource>) -> Result<(), String> {
    writer::writer_rollback(index)
}

#[rustler::nif]
fn reader_new(index: rustler::ResourceArc<index::IndexResource>) -> Result<rustler::ResourceArc<reader::ReaderResource>, String> {
    reader::reader_new(index)
}

#[rustler::nif]
fn searcher_new(reader: rustler::ResourceArc<reader::ReaderResource>) -> Result<rustler::ResourceArc<searcher::SearcherResource>, String> {
    searcher::searcher_new(reader)
}

#[rustler::nif]
fn searcher_search_term<'a>(
    env: rustler::Env<'a>,
    searcher: rustler::ResourceArc<searcher::SearcherResource>,
    query: searcher::TermQueryDef,
    limit: usize,
) -> Result<rustler::Term<'a>, String> {
    searcher::searcher_search_term(env, searcher, query, limit)
}

#[rustler::nif]
fn searcher_search_query<'a>(
    env: rustler::Env<'a>,
    searcher: rustler::ResourceArc<searcher::SearcherResource>,
    query_string: String,
    default_fields: Vec<String>,
    limit: usize,
) -> Result<rustler::Term<'a>, String> {
    searcher::searcher_search_query(env, searcher, query_string, default_fields, limit)
}

#[rustler::nif]
fn searcher_search_with_snippets<'a>(
    env: rustler::Env<'a>,
    searcher: rustler::ResourceArc<searcher::SearcherResource>,
    query_string: String,
    default_fields: Vec<String>,
    snippet_fields: Vec<String>,
    max_snippet_chars: usize,
    limit: usize,
) -> Result<rustler::Term<'a>, String> {
    searcher::searcher_search_with_snippets(
        env,
        searcher,
        query_string,
        default_fields,
        snippet_fields,
        max_snippet_chars,
        limit,
    )
}

#[rustler::nif]
fn searcher_search_prefix<'a>(
    env: rustler::Env<'a>,
    searcher: rustler::ResourceArc<searcher::SearcherResource>,
    field_name: String,
    prefix: String,
    limit: usize,
) -> Result<rustler::Term<'a>, String> {
    searcher::searcher_search_prefix(env, searcher, field_name, prefix, limit)
}

#[rustler::nif]
fn searcher_search_range_u64<'a>(
    env: rustler::Env<'a>,
    searcher: rustler::ResourceArc<searcher::SearcherResource>,
    field_name: String,
    lower: u64,
    upper: u64,
    lower_inclusive: bool,
    upper_inclusive: bool,
    limit: usize,
) -> Result<rustler::Term<'a>, String> {
    searcher::searcher_search_range_u64(env, searcher, field_name, lower, upper, lower_inclusive, upper_inclusive, limit)
}

#[rustler::nif]
fn searcher_search_range_i64<'a>(
    env: rustler::Env<'a>,
    searcher: rustler::ResourceArc<searcher::SearcherResource>,
    field_name: String,
    lower: i64,
    upper: i64,
    lower_inclusive: bool,
    upper_inclusive: bool,
    limit: usize,
) -> Result<rustler::Term<'a>, String> {
    searcher::searcher_search_range_i64(env, searcher, field_name, lower, upper, lower_inclusive, upper_inclusive, limit)
}

#[rustler::nif]
fn searcher_search_range_f64<'a>(
    env: rustler::Env<'a>,
    searcher: rustler::ResourceArc<searcher::SearcherResource>,
    field_name: String,
    lower: f64,
    upper: f64,
    lower_inclusive: bool,
    upper_inclusive: bool,
    limit: usize,
) -> Result<rustler::Term<'a>, String> {
    searcher::searcher_search_range_f64(env, searcher, field_name, lower, upper, lower_inclusive, upper_inclusive, limit)
}

#[rustler::nif]
fn searcher_search_fuzzy<'a>(
    env: rustler::Env<'a>,
    searcher: rustler::ResourceArc<searcher::SearcherResource>,
    field_name: String,
    term: String,
    distance: u8,
    transposition_cost_one: bool,
    limit: usize,
) -> Result<rustler::Term<'a>, String> {
    searcher::searcher_search_fuzzy(env, searcher, field_name, term, distance, transposition_cost_one, limit)
}

#[rustler::nif]
fn searcher_search_fuzzy_prefix<'a>(
    env: rustler::Env<'a>,
    searcher: rustler::ResourceArc<searcher::SearcherResource>,
    field_name: String,
    prefix: String,
    distance: u8,
    transposition_cost_one: bool,
    limit: usize,
) -> Result<rustler::Term<'a>, String> {
    searcher::searcher_search_fuzzy_prefix(env, searcher, field_name, prefix, distance, transposition_cost_one, limit)
}

#[rustler::nif]
fn searcher_search_fuzzy_with_snippets<'a>(
    env: rustler::Env<'a>,
    searcher: rustler::ResourceArc<searcher::SearcherResource>,
    field_name: String,
    term: String,
    snippet_fields: Vec<String>,
    distance: u8,
    transposition_cost_one: bool,
    max_snippet_chars: usize,
    limit: usize,
) -> Result<rustler::Term<'a>, String> {
    searcher::searcher_search_fuzzy_with_snippets(env, searcher, field_name, term, snippet_fields, distance, transposition_cost_one, max_snippet_chars, limit)
}

rustler::init!("Elixir.Muninn.Native", load = on_load);

fn on_load(env: rustler::Env, _info: rustler::Term) -> bool {
    schema::load(env);
    index::load(env);
    writer::load(env);
    reader::load(env);
    searcher::load(env);
    true
}
