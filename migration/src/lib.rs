pub use sea_orm_migration::prelude::*;

pub struct Migrator;

#[async_trait::async_trait]
impl MigratorTrait for Migrator {
    fn migrations() -> Vec<Box<dyn MigrationTrait>> {
        vec![
            Box::new(m20250922_025851_create_table_users::Migration),
            Box::new(m20251001_135745_create_table_ads::Migration),
        ]
    }
}
mod m20250922_025851_create_table_users;
mod m20251001_135745_create_table_ads;
