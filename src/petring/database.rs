pub mod users;

// Re-export entities for easier access
pub use users::{ActiveModel as UserModel, Entity as Users};

// Entity collection for convenience
pub mod entities {
    pub use super::{UserModel, Users};
}
