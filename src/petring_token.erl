-module (petring_token).
-export ([mint/0, hash/1]).

-spec mint() -> Base64 :: binary().
mint() ->
  base64:encode(crypto:strong_rand_bytes(32), #{mode => urlsafe, padding => false}).

-spec hash(binary()) -> Hash :: binary().
hash(Token) ->
  crypto:hash(sha256, Token).
