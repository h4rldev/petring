pub mod ads;
pub mod users;

// Re-export entities for easier access
pub use ads::{ActiveModel as AdModel, Entity as Ads};
pub use users::{ActiveModel as UserModel, Entity as Users};

// Entity collection for convenience
pub mod entities {
    pub use super::{AdModel, Ads};
    pub use super::{UserModel, Users};
}
