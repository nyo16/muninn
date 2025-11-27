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

rustler::init!("Elixir.Muninn.Native", load = on_load);

fn on_load(env: rustler::Env, _info: rustler::Term) -> bool {
    schema::load(env);
    index::load(env);
    writer::load(env);
    reader::load(env);
    searcher::load(env);
    true
}
