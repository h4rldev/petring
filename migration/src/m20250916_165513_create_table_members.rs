use sea_orm_migration::{prelude::*, schema::*};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(Members::Table)
                    .if_not_exists()
                    .col(pk_auto(Members::Id))
                    .col(string_uniq(Members::UserName).not_null())
                    .col(string_uniq(Members::Discord).not_null())
                    .col(string_uniq(Members::Url).not_null())
                    .col(boolean(Members::Verified).not_null().default(false))
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("members_username_idx")
                    .table(Members::Table)
                    .col(Members::UserName)
                    .unique()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("members_url_idx")
                    .table(Members::Table)
                    .col(Members::Url)
                    .unique()
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(
                Index::drop()
                    .name("members_username_idx")
                    .table(Members::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("members_url_idx")
                    .table(Members::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_table(Table::drop().table(Members::Table).to_owned())
            .await?;

        Ok(())
    }
}

#[derive(DeriveIden)]
enum Members {
    Table,
    Id,
    UserName,
    Discord,
    Url,
    Verified,
}
