use sea_orm_migration::{prelude::*, schema::*, sea_orm::sqlx::types::chrono::Utc};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(Users::Table)
                    .if_not_exists()
                    .col(pk_auto(Users::Id))
                    .col(string_uniq(Users::Username).not_null())
                    .col(integer_uniq(Users::DiscordId).not_null())
                    .col(string_uniq(Users::Url).not_null())
                    .col(boolean(Users::Verified).not_null().default(false))
                    .col(
                        string(Users::CreatedAt)
                            .not_null()
                            .default(Utc::now().to_rfc3339()),
                    )
                    .col(string(Users::EditedAt).not_null().default(""))
                    .col(string(Users::VerifiedAt).not_null().default(""))
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("members_username_idx")
                    .table(Users::Table)
                    .col(Users::Username)
                    .unique()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("members_url_idx")
                    .table(Users::Table)
                    .col(Users::Url)
                    .unique()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("members_discord_idx")
                    .table(Users::Table)
                    .col(Users::DiscordId)
                    .unique()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("members_created_at_idx")
                    .table(Users::Table)
                    .col(Users::CreatedAt)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("members_edited_at_idx")
                    .table(Users::Table)
                    .col(Users::EditedAt)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("members_verified_at_idx")
                    .table(Users::Table)
                    .col(Users::VerifiedAt)
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
                    .table(Users::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("members_url_idx")
                    .table(Users::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("members_discord_idx")
                    .table(Users::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("members_created_at_idx")
                    .table(Users::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("members_edited_at_idx")
                    .table(Users::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("members_verified_at_idx")
                    .table(Users::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_table(Table::drop().table(Users::Table).to_owned())
            .await?;

        Ok(())
    }
}

#[derive(DeriveIden)]
enum Users {
    Table,
    Id,
    Username,
    DiscordId,
    Url,
    Verified,
    CreatedAt,
    EditedAt,
    VerifiedAt,
}
