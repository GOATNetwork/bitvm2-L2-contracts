deploy-gateway-main:
	forge script script/deploy/DeployGateway.sol:DeployGateway --rpc-url goatMainnet --broadcast -vvvv --verify --verifier blockscout --verifier-url https://explorer.goat.network/api/

deploy-gateway-test:
	forge script script/deploy/DeployGateway.sol:DeployGateway --rpc-url goatTestnet --broadcast -vvvv --verify --verifier blockscout --verifier-url https://explorer.testnet3.goat.network/api/

deploy-pegbtc-main:
	forge script script/deploy/DeployPegBTC.sol:DeployPegBTC --rpc-url goatMainnet --broadcast -vvvv --verify --verifier blockscout --verifier-url https://explorer.goat.network/api/

deploy-pegbtc-test:
	forge script script/deploy/DeployPegBTC.sol:DeployPegBTC --rpc-url goatTestnet --broadcast -vvvv --verify --verifier blockscout --verifier-url https://explorer.testnet3.goat.network/api/

deploy-committee-main:
	forge script script/deploy/DeployCommitteeManagement.sol:DeployCommitteeManagement --rpc-url goatMainnet --broadcast -vvvv --verify --verifier blockscout --verifier-url https://explorer.goat.network/api/

deploy-committee-test:
	forge script script/deploy/DeployCommitteeManagement.sol:DeployCommitteeManagement --rpc-url goatTestnet --broadcast -vvvv --verify --verifier blockscout --verifier-url https://explorer.testnet3.goat.network/api/

deploy-stake-main:
	forge script script/deploy/DeployStakeManagement.sol:DeployStakeManagement --rpc-url goatMainnet --broadcast -vvvv --verify --verifier blockscout --verifier-url https://explorer.goat.network/api/

deploy-stake-test:
	forge script script/deploy/DeployStakeManagement.sol:DeployStakeManagement --rpc-url goatTestnet --broadcast -vvvv --verify --verifier blockscout --verifier-url https://explorer.testnet3.goat.network/api/

