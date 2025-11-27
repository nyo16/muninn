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

rustler::init!("Elixir.Muninn.Native", load = on_load);

fn on_load(env: rustler::Env, _info: rustler::Term) -> bool {
    schema::load(env);
    index::load(env);
    writer::load(env);
    true
}
