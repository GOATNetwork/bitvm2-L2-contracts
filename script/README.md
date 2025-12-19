# Deployment Scripts

## Environment setup

1. Copy `.env.example` to `.env` and replace the placeholder values.
2. Add as many `COMMITTEE_<index>` and `WATCHTOWER_<index>` entries as needed. Indexes must be sequential (e.g., `_0`, `_1`, `_2`).
3. Export the variables into your shell (`set -a && source .env && set +a`) or let Foundry load them via `--env .env`.

## Deploying the Gateway stack

The `DeployGateway` script provisions the PegBTC token, Gateway (implementation + proxy), CommitteeManagement proxy, and StakeManagement proxy. Each proxy is initialized via constructor-calldata so there is no uninitialized window.

```bash
make deployTest
```

or for mainnet

```bash
make deployMain
```

Under the hood these targets expand to `forge script script/DeployGateway.sol:DeployGateway` with the Goat RPC aliases defined in `foundry.toml`, `--broadcast -vvvv`, and Blockscout verification flags (`--verifier blockscout --verifier-url ...`). Provide `PRIVATE_KEY`, `BITCOINSPV_ADDR`, committee, and watchtower env vars before invoking the Makefile.

Key environment variables consumed by the script:

- `PRIVATE_KEY`: broadcaster key (hex string, no quotes).
- `BITCOINSPV_ADDR`: already deployed Bitcoin SPV contract on the target chain.
- `COMMITTEE_<i>`: sequential list of committee member addresses (at least one required).
- `WATCHTOWER_<i>`: sequential list of 32-byte watchtower identifiers (at least one required).
