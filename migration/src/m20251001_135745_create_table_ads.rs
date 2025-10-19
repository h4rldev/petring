use sea_orm_migration::{prelude::*, schema::*, sea_orm::sqlx::types::chrono::Utc};

#[derive(DeriveMigrationName)]
pub struct Migration;

#[async_trait::async_trait]
impl MigrationTrait for Migration {
    async fn up(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .create_table(
                Table::create()
                    .table(Ads::Table)
                    .if_not_exists()
                    .col(pk_auto(Ads::Id))
                    .col(string_uniq(Ads::Username).not_null())
                    .col(integer_uniq(Ads::DiscordId).not_null())
                    .col(string_uniq(Ads::ImageUrl).not_null())
                    .col(string_uniq(Ads::AdUrl).not_null())
                    .col(boolean(Ads::Verified).not_null().default(false))
                    .col(
                        string(Ads::CreatedAt)
                            .not_null()
                            .default(Utc::now().to_rfc3339()),
                    )
                    .col(string(Ads::EditedAt).not_null().default(""))
                    .col(string(Ads::VerifiedAt).not_null().default(""))
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("ads_username_idx")
                    .table(Ads::Table)
                    .col(Ads::Username)
                    .unique()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("ads_url_idx")
                    .table(Ads::Table)
                    .col(Ads::ImageUrl)
                    .unique()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("ads_discord_id_idx")
                    .table(Ads::Table)
                    .col(Ads::DiscordId)
                    .unique()
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("ads_created_at_idx")
                    .table(Ads::Table)
                    .col(Ads::CreatedAt)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("ads_edited_at_idx")
                    .table(Ads::Table)
                    .col(Ads::EditedAt)
                    .to_owned(),
            )
            .await?;

        manager
            .create_index(
                Index::create()
                    .name("ads_verified_at_idx")
                    .table(Ads::Table)
                    .col(Ads::VerifiedAt)
                    .to_owned(),
            )
            .await?;

        Ok(())
    }

    async fn down(&self, manager: &SchemaManager) -> Result<(), DbErr> {
        manager
            .drop_index(
                Index::drop()
                    .name("ads_username_idx")
                    .table(Ads::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("ads_url_idx")
                    .table(Ads::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("ads_discord_id_idx")
                    .table(Ads::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("ads_created_at_idx")
                    .table(Ads::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("ads_edited_at_idx")
                    .table(Ads::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_index(
                Index::drop()
                    .name("ads_verified_at_idx")
                    .table(Ads::Table)
                    .to_owned(),
            )
            .await?;

        manager
            .drop_table(Table::drop().table(Ads::Table).to_owned())
            .await?;

        Ok(())
    }
}

#[derive(DeriveIden)]
enum Ads {
    Table,
    Id,
    Username,
    DiscordId,
    ImageUrl,
    AdUrl,
    Verified,
    CreatedAt,
    EditedAt,
    VerifiedAt,
}
