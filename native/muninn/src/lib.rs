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

rustler::init!("Elixir.Muninn.Native", load = on_load);

fn on_load(env: rustler::Env, _info: rustler::Term) -> bool {
    schema::load(env);
    index::load(env);
    true
}
