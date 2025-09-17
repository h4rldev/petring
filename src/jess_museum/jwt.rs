use chrono::{Duration, Utc};
use dotenvy::dotenv;
use jsonwebtoken::{Algorithm, DecodingKey, EncodingKey, Validation};
use serde::{Deserialize, Serialize};
use std::collections::HashSet;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Claims {
    pub sub: String,         // bot token
    pub exp: i64,            // expiration
    pub iat: i64,            // issued at
    pub aud: String,         // refresh or access token
    pub jti: Option<String>, // token id
}

pub enum TokenType {
    Access,
    Refresh,
}

#[derive(Debug)]
pub enum TokenError {
    InvalidToken,
    ExpiredToken,
    FailedToGenerate,
    FailedToRefresh,
    InvalidFormat,
}

pub struct TokenBlacklist {
    tokens: HashSet<String>,
}

impl TokenBlacklist {
    pub fn new() -> Self {
        Self {
            tokens: HashSet::new(),
        }
    }

    pub fn add_token(&mut self, token: &str) {
        self.tokens.insert(token.to_string());
    }

    pub fn remove_token(&mut self, token: &str) {
        self.tokens.remove(token);
    }

    pub fn contains_token(&self, token: &str) -> bool {
        self.tokens.contains(token)
    }
}

impl Claims {
    pub fn new(bot_token: &str, token_type: TokenType) -> Self {
        let (exp, jti) = match token_type {
            TokenType::Access => (300, None),
            TokenType::Refresh => (86400, Some(Uuid::new_v4().to_string())),
        };

        Self {
            sub: bot_token.to_string(),
            exp: Utc::now().timestamp() + Duration::seconds(exp).num_seconds(),
            iat: Utc::now().timestamp(),
            aud: match token_type {
                TokenType::Access => "access".to_string(),
                TokenType::Refresh => "refresh".to_string(),
            },
            jti,
        }
    }
}

pub struct TokenSecrets {
    access_secret: String,
    refresh_secret: String,
    blacklist: TokenBlacklist,
}

impl TokenSecrets {
    pub fn new() -> Self {
        dotenv().ok();

        let access_secret =
            std::env::var("ACCESS_TOKEN_SECRET").expect("ACCESS_TOKEN_SECRET not set");
        let refresh_secret =
            std::env::var("REFRESH_TOKEN_SECRET").expect("REFRESH_TOKEN_SECRET not set");

        Self {
            access_secret,
            refresh_secret,
            blacklist: TokenBlacklist::new(),
        }
    }

    pub fn access_secret(&self) -> &str {
        &self.access_secret
    }

    pub fn refresh_secret(&self) -> &str {
        &self.refresh_secret
    }
}

pub fn generate_token(claims: Claims, secrets: &TokenSecrets) -> Result<String, TokenError> {
    let header = jsonwebtoken::Header::new(jsonwebtoken::Algorithm::HS256);
    let secret = match claims.aud.as_str() {
        "access" => secrets.access_secret(),
        "refresh" => secrets.refresh_secret(),
        _ => panic!("Invalid token type"),
    };

    match jsonwebtoken::encode(
        &header,
        &claims,
        &EncodingKey::from_secret(secret.as_bytes()),
    ) {
        Ok(token) => Ok(token),
        Err(_) => Err(TokenError::FailedToGenerate),
    }
}

pub fn verify_token(token: &str, secrets: &TokenSecrets) -> Result<Claims, TokenError> {
    if secrets.blacklist.contains_token(token) {
        return Err(TokenError::InvalidToken);
    }

    let validation = Validation::new(Algorithm::HS256);

    let claims = match jsonwebtoken::decode::<Claims>(
        token,
        &DecodingKey::from_secret(secrets.access_secret().as_bytes()),
        &validation,
    ) {
        Ok(claims) => claims.claims,
        Err(_) => return Err(TokenError::InvalidToken),
    };

    if Utc::now().timestamp() > claims.exp {
        return Err(TokenError::ExpiredToken);
    }

    Ok(claims)
}

pub fn refresh_token(token: &str, secrets: &TokenSecrets) -> Result<(String, String), TokenError> {
    if secrets.blacklist.contains_token(token) {
        return Err(TokenError::InvalidToken);
    }

    let mut validation = Validation::new(Algorithm::HS256);
    validation.validate_exp = true;

    let refresh_claims = match jsonwebtoken::decode::<Claims>(
        token,
        &DecodingKey::from_secret(secrets.refresh_secret().as_bytes()),
        &validation,
    ) {
        Ok(claims) => claims,
        Err(_) => return Err(TokenError::InvalidToken),
    };

    if refresh_claims.claims.aud != "refresh" {
        // If you manage to get here, contact us please
        // :)
        return Err(TokenError::InvalidFormat);
    }

    let access_token_claims = Claims::new(&refresh_claims.claims.sub, TokenType::Access);
    let access_token = match generate_token(access_token_claims, &secrets) {
        Ok(token) => token,
        Err(_) => return Err(TokenError::FailedToRefresh),
    };

    let refresh_token_claims = Claims::new(&refresh_claims.claims.sub, TokenType::Refresh);
    let refresh_token = match generate_token(refresh_token_claims, &secrets) {
        Ok(token) => token,
        Err(_) => return Err(TokenError::FailedToRefresh),
    };

    Ok((access_token, refresh_token))
}
