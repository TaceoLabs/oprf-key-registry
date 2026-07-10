# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### ⛰️ Features

- Added changeVerifierContract method (#34) ([3c2a8b6](https://github.com/TaceoLabs/oprf-key-registry/commit/3c2a8b6c3e12f204d2ab96124941f39d6ca76097))
- Allow nodes to report key gen stuck (#41) ([2422112](https://github.com/TaceoLabs/oprf-key-registry/commit/24221126014cc12fb569e9ca5180247552a46668))
- Added ERC165 support for key-registry ([4d291d4](https://github.com/TaceoLabs/oprf-key-registry/commit/4d291d40e49cc56dcd9e6140589940f5444d01e3))
- Added state getters to interface for v1 ([1a2decb](https://github.com/TaceoLabs/oprf-key-registry/commit/1a2decbfb986f02a1122237a9f805e67f4513912))
- Add helpers to v2 contract for peer retrieval ([936bd43](https://github.com/TaceoLabs/oprf-key-registry/commit/936bd433b6f9e9d309482ee20c5007215339e7dc))

### 🐛 Bug Fixes

- Prevents reseting a deleted key if abort is called ([61f492c](https://github.com/TaceoLabs/oprf-key-registry/commit/61f492cc55247b2d26d79314409f6b88231cd980))
- Adds uniquness check for eph public keys to prevent replay attacks ([824e6bb](https://github.com/TaceoLabs/oprf-key-registry/commit/824e6bb42cca37931442ebc30fbfa002f32413d2))
- Update working directory in justfile ([1e0c7c2](https://github.com/TaceoLabs/oprf-key-registry/commit/1e0c7c25853113a874ad359256864c1c8bbdeabf))

### 🚜 Refactor

- [**breaking**] Remove the storage gap from key-registry ([b16376c](https://github.com/TaceoLabs/oprf-key-registry/commit/b16376caecd6ccc0b904bdadc8164b4e8c90ad03))
- [**breaking**] Removed the babyjubjub lib and extracted in dedicated lib (#37) ([0042884](https://github.com/TaceoLabs/oprf-key-registry/commit/00428849d269192703e0901145a2723e82b34f1c))
- Moved interfaces to dedicated file ([6f038bb](https://github.com/TaceoLabs/oprf-key-registry/commit/6f038bb25d6aa65455e5a8ff67251f59e1f0b036))

### 🏗️ Build

- Add upgradeable proxy check in ci (#31) ([c4b6c12](https://github.com/TaceoLabs/oprf-key-registry/commit/c4b6c12f4a32d6ebc526c2ab562df722f13f0910))
- Added justfile ([090efa5](https://github.com/TaceoLabs/oprf-key-registry/commit/090efa5e0ca46590bb879432164e1eec81326854))
- Added deploy and upgrade proxy scripts ([b8e6396](https://github.com/TaceoLabs/oprf-key-registry/commit/b8e63964230536e15fbcd6a41addf8fbf3d39029))
- Added two just commands (#33) ([e387586](https://github.com/TaceoLabs/oprf-key-registry/commit/e387586d3850927b77c6ddbd36ef6180f4996eaf))
- Added change verifier script and just commands (#36) ([93e4f28](https://github.com/TaceoLabs/oprf-key-registry/commit/93e4f28ac48791be0eb28da16fb2e114bfe3add6))
- Bump actions/setup-node from 4 to 6 (#45) ([5eba78a](https://github.com/TaceoLabs/oprf-key-registry/commit/5eba78ae4ba2469f6d480cf0f2a19a201cc8e46f))
- Bump actions/checkout from 5 to 6 (#46) ([5fb6b50](https://github.com/TaceoLabs/oprf-key-registry/commit/5fb6b50eee5447626a41951b7a2bfdb332c0ac30))
- Bump actions/checkout from 6 to 7 (#49) ([e94ee7f](https://github.com/TaceoLabs/oprf-key-registry/commit/e94ee7ffba0a798469ba64f36463af44f8640998))
- Add scripts for Safe:Wallet interaction (#42) ([b4b2347](https://github.com/TaceoLabs/oprf-key-registry/commit/b4b234797947a58ad32d8cbb4ff888a4b3db7780))

### 📚 Documentation

- Update Readme (#29) ([e3269dd](https://github.com/TaceoLabs/oprf-key-registry/commit/e3269dd040aca0352271753233f2bd8e8a4a9d96))
- Add contract audits (#39) ([7a4ee8b](https://github.com/TaceoLabs/oprf-key-registry/commit/7a4ee8b66d2dbe44cfd559dd7cc6146d627c31a3))
- Added docs for unreleased v2 ([cae0a17](https://github.com/TaceoLabs/oprf-key-registry/commit/cae0a1739780b3fe136d4fcadeea5d2bfa194aa1))
- Use inheritdocs (#52) ([ddc5060](https://github.com/TaceoLabs/oprf-key-registry/commit/ddc50600b720c02e535cbf67ad0ea70f04b3a1d2))

### 🧪 Testing

- Add wrong-round event for key-registry-mock (#26) ([2837db7](https://github.com/TaceoLabs/oprf-key-registry/commit/2837db7863a6dd85e9605d7561952432851b9e9e))
- Add finalize_event for mock contract (#27) ([895ad65](https://github.com/TaceoLabs/oprf-key-registry/commit/895ad65957d3f83f8ec54fdfc03ff941e9affd1b))
- Add test for ERC165 support ([56d42d9](https://github.com/TaceoLabs/oprf-key-registry/commit/56d42d9c249aa21c72f5841a47366a5a6d7584fd))

## [1.0.0-rc.1] - 2026-02-10

### ⛰️ Features

- Added admin methods to interface (#21) ([2fb77a1](https://github.com/TaceoLabs/oprf-key-registry/commit/2fb77a1ff33622671fe019d845ed8823d0e79ecd))
- Emit an event if one of the registered OPRF peers changes. (#25) ([30eff1a](https://github.com/TaceoLabs/oprf-key-registry/commit/30eff1a8ef7bc2274b7daf01a51d3980cc18eb20))

### 🐛 Bug Fixes

- Remove leftover constants from contract ([817107a](https://github.com/TaceoLabs/oprf-key-registry/commit/817107a2bfaa842e477917f89c0a5274cff1cb1c))

### 🚜 Refactor

- Make party id indexable in KeyGenConfirmation (#18) ([6b90a47](https://github.com/TaceoLabs/oprf-key-registry/commit/6b90a47bcadde15f4a82911c4f64118db24315b6))
- [**breaking**] Explicitly pass in the owner into the contract during init ([c8042bf](https://github.com/TaceoLabs/oprf-key-registry/commit/c8042bfc2e54b531c7a5ab7b3fbea51169a18837))
- [**breaking**] Set epoch to be a u32 (#24) ([0baafb8](https://github.com/TaceoLabs/oprf-key-registry/commit/0baafb81d9190e7a0a9c39a19b06ec09378030c0))

### 🧪 Testing

- Added mock oprf key-registry (#19) ([2c2a17c](https://github.com/TaceoLabs/oprf-key-registry/commit/2c2a17c59f6c5e6a806cde36483829accac0df97))
- Added mocked version for invalid proof test (#23) ([a655038](https://github.com/TaceoLabs/oprf-key-registry/commit/a655038ad4496683ae7f53b56c0e3dcb37230e24))

## [1.0.0-beta.1] - 2026-01-20

### ⛰️ Features

- Add IOprfKeyRegistry interface (#9) ([95ce183](https://github.com/TaceoLabs/oprf-key-registry/commit/95ce18337f14b086ed0a3704dddee2095b95d849))
- Add abort functionality to KeyReshare (#5) ([2d58b77](https://github.com/TaceoLabs/oprf-key-registry/commit/2d58b77a317858dc1688e547c4eab5b598bd7814))
- Prevents initKeyGen with id 0 (#11) ([4b23ebe](https://github.com/TaceoLabs/oprf-key-registry/commit/4b23ebecc6026fb6426db7c503f42993a81bb072))
- Allow owner to add key-gen admins as well ([79b9b04](https://github.com/TaceoLabs/oprf-key-registry/commit/79b9b0426ccc53ae856bc2d984d84e4f47c9b9dc))
- [**breaking**] WrongRound error not wraps the current round ([2b37c31](https://github.com/TaceoLabs/oprf-key-registry/commit/2b37c3122775cb72ac79d3cc5d973829058fe6bb))

### 🐛 Bug Fixes

- Generated epoch in round3 event now correct #8 ([53f901e](https://github.com/TaceoLabs/oprf-key-registry/commit/53f901eafc1bb94686596178c4507361f189f8d2))
- Removed unnecessary delete of nodeRoles ([1b4e01e](https://github.com/TaceoLabs/oprf-key-registry/commit/1b4e01e329dbdf7bf67822a6d2c4ee6a0ec9869c))
- Fixed stuck event and added test ([1e43143](https://github.com/TaceoLabs/oprf-key-registry/commit/1e4314352afb5817576bcbff3d1a674829483406))
- Fixed the round checks for loading pks/ciphers (#14) ([174f83b](https://github.com/TaceoLabs/oprf-key-registry/commit/174f83b0e54f971af54818a7254d0c1eb7e7e958))

### 🚜 Refactor

- Revert nonce to transaction confirmation event (#4)" (#6) ([bec8eb5](https://github.com/TaceoLabs/oprf-key-registry/commit/bec8eb54f4e7de5f0b25a2c3b77308e7c9039512))
- [**breaking**] Rewrote babyjubjub to library ([e339fe9](https://github.com/TaceoLabs/oprf-key-registry/commit/e339fe95ded4e15ee5d4c8111c5e7564f9ed5e92))
- [**breaking**] Move functionallity of key-gen into types library ([a0f2b63](https://github.com/TaceoLabs/oprf-key-registry/commit/a0f2b63f8cecbffba742537f55d51b02481ffaa6))
- [**breaking**] Renamed Types library to OprfKeyGen library ([ddb5569](https://github.com/TaceoLabs/oprf-key-registry/commit/ddb5569bb31a6300add2a2ac27bbe05ec0631e33))
- Moved from external calls to public calls ([7ec48ad](https://github.com/TaceoLabs/oprf-key-registry/commit/7ec48adaab7511fc489b40dbdde376b05a37189f))

### 🏗️ Build

- Removed babyjubjub contract from deploy scripts ([b2b8678](https://github.com/TaceoLabs/oprf-key-registry/commit/b2b8678bcf16a88f664e68a6790d68ba262fdbe5))

### 📚 Documentation

- Update broken doc in BabyJubJub.sol ([b1000f9](https://github.com/TaceoLabs/oprf-key-registry/commit/b1000f93d802d885a08e2c18e9472f4300797424))

### 🧪 Testing

- Added kats for reshare once and twice (#10) ([42c8ba0](https://github.com/TaceoLabs/oprf-key-registry/commit/42c8ba04c0f36f9400dea07d5536f644aa2a5431))

## [0.1.0-beta.1] - 2026-01-13

### ⛰️ Features

- Update key-gen verifier contracts and tests for latest circuits (#2) ([2f85b8c](https://github.com/TaceoLabs/oprf-key-registry/commit/2f85b8cfd1d064187fef8bf5026f6be71f94e027))
- Contract add nonce to transaction confirmation event (#4) ([509a11d](https://github.com/TaceoLabs/oprf-key-registry/commit/509a11dcc712c15cf3037ba8aa52e100b6fc647a))

### 🐛 Bug Fixes

- Now only checks commitments in round 1 reshare if producer ([9670d10](https://github.com/TaceoLabs/oprf-key-registry/commit/9670d10bba7e881e98f0bd658bc24de80bedd407))

### 🚜 Refactor

- Round 2 event now also emits generated epoch ([8d48cad](https://github.com/TaceoLabs/oprf-key-registry/commit/8d48cad453e607108d5afeef01235443ad12833b))

