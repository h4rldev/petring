use sea_orm::entity::prelude::*;
use serde::{Deserialize, Serialize};

#[derive(Clone, Debug, PartialEq, DeriveEntityModel, Serialize, Deserialize)]
#[sea_orm(table_name = "ads")]
pub struct Model {
    #[sea_orm(primary_key, auto_increment = true)]
    pub id: i32,
    #[sea_orm(unique)]
    pub username: String,
    #[sea_orm(unique)]
    pub discord_id: i64,
    #[sea_orm(unique)]
    pub image_url: String,
    #[sea_orm(unique)]
    pub ad_url: String,
    #[sea_orm(default_value = "false")]
    pub verified: bool,
    pub created_at: String,
    #[sea_orm(default_value = "")]
    pub edited_at: String,
    #[sea_orm(default_value = "", not_null)]
    pub verified_at: String,
}

#[derive(Copy, Clone, Debug, EnumIter, DeriveRelation)]
pub enum Relation {
    #[sea_orm(
        belongs_to = "super::users::Entity",
        from = "Column::Username",
        to = "super::users::Column::Username"
    )]
    Users,
}

impl Related<super::users::Entity> for Entity {
    fn to() -> RelationDef {
        Relation::Users.def()
    }
}

impl ActiveModelBehavior for ActiveModel {}
