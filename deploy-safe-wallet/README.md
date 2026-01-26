# Deploy Smart Contracts via Safe-Wallet MultiSig

Using https://app.safe.global/

This TS project performs the same steps known from `contracts/script/deploy` but creates a transaction via Safe-Wallet. If one deployment definition changes, the other one should be changed as well.

## Initial Setup

```bash
cd contracts/deploy-safe-wallet
npm install  ## tested with npm 10.8.1
cp .env.example .env
# Edit .env with your values
```

Creating the transaction requires an ETH private key, so at least one wallet of the MultiSig cannot be a hardware wallet. 

## Deploy to World Mainnet

There exist multiple targets as defined in `contracts/deploy-safe-wallet/package.json`

Key Registry with Deps
```bash
just deploy-safe-wallet-oprf-key-registry-with-deps mainnet
```


Key Registry
```bash
just deploy-safe-wallet-oprf-key-registry mainnet
```

Other supported arguments besides `mainnet` for testing are:
  - `local`
  - `sepolia`

## Testing with local anvil Sepolia fork

### Step 1: Test locally on forked Sepolia

Define `ETH_RPC` env var
```bash
export ETH_RPC=https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY
```

```bash
# Terminal 1: Start Anvil fork (tested with anvil Version: 1.3.5-stable)
anvil --fork-url $ETH_RPC

# Terminal 2: Run deployment
npm run deploy:local
```

This will:
- Execute the full deployment through your Safe on the fork
- Show you the deterministic addresses for all contracts(except Proxy)
- Verify everything works before going to production

### Step 2: Propose to Sepolia

```bash
npm run deploy:sepolia
```

This will:
- Build the same transactions
- Propose them to the Safe Transaction Service
- Give you a link to share with other signers

### Step 3: Sign and execute

1. Other Safe owners open the link(Or get a notification via Safe App)
2. Review and sign the transaction
3. Once threshold is met, execute

## Deterministic Addresses

Using the same `DEPLOY_SALT`, you'll get identical contract addresses on any EVM network. This is useful for:
- Cross-chain deployments
- Documentation
- Frontend configuration before deployment

## File Structure

```
deploy-safe/
├── src/
│   └── deploy.ts      # Main deployment script
├── package.json
├── tsconfig.json
├── .env.example
└── README.md
```

## Environment Variables

| Variable | Description |
|----------|-------------|
| `SAFE_ADDRESS` | Your Safe multi-sig address |
| `SIGNER_PRIVATE_KEY` | Private key of one Safe owner |
| `THRESHOLD` | OPRF threshold |
| `NUM_PEERS` | OPRF peer count |
| `DEPLOY_SALT` | CREATE2 salt for deterministic addresses |
| `*_RPC_URL` | RPC endpoints for each network |
| `ACCUMULATOR_ADDRESS` | define address when using deployOprfKeyRegistry |
| `KEY_GEN_VERIFIER_ADDRESS` | define address when using deployOprfKeyRegistry |
