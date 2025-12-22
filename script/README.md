# Deployment Scripts

## Environment setup

1. Copy `.env.example` to `.env` and replace the placeholder values.
2. Add as many `COMMITTEE_<index>` and `WATCHTOWER_<index>` entries as needed. Indexes must be sequential (e.g., `_0`, `_1`, `_2`).
3. Export the variables into your shell (`set -a && source .env && set +a`) or let Foundry load them via `--env .env`.

## Deploying the Gateway stack

All deployment scripts now live under `script/deploy/` and each script focuses on a single contract. Run them in the order below, updating your `.env` with the emitted addresses between steps:

1. **Gateway proxy** – `script/deploy/DeployGateway.sol:DeployGateway`
2. **PegBTC token** – `script/deploy/DeployPegBTC.sol:DeployPegBTC`
3. **CommitteeManagement proxy** – `script/deploy/DeployCommitteeManagement.sol:DeployCommitteeManagement`
4. **StakeManagement proxy** – `script/deploy/DeployStakeManagement.sol:DeployStakeManagement`
5. **Gateway init via constructor data** – rerun the Gateway deploy script once `PEGBTC_ADDR`, `BITCOINSPV_ADDR`, `COMMITTEE_PROXY_ADDR`, and `STAKE_PROXY_ADDR` are known so that the proxy is deployed with the correct initializer calldata.

Example command:

```bash
forge script script/deploy/DeployGateway.sol:DeployGateway \
  --rpc-url goatTestnet \
  --broadcast -vvvv \
  --verify --verifier blockscout \
  --verifier-url https://explorer.testnet3.goat.network/api/
```

Repeat the command with the appropriate script name (and `goatMainnet` when deploying to mainnet). Required environment variables grow as you progress:

- `PRIVATE_KEY`: broadcaster key (hex string, no quotes).
- `BITCOINSPV_ADDR`: previously deployed Bitcoin SPV contract.
- `GATEWAY_PROXY_ADDR`: emitted when deploying the gateway proxy (needed by PegBTC + Committee scripts).
- `PEGBTC_ADDR`, `COMMITTEE_PROXY_ADDR`, `STAKE_PROXY_ADDR`: used by the Gateway deploy script when encoding initializer calldata.
- `COMMITTEE_<i>` / `WATCHTOWER_<i>`: sequential committee + watchtower definitions for the committee deploy script.
