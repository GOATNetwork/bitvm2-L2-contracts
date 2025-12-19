deployMain:
	forge script script/DeployGateway.sol:DeployGateway --rpc-url goatMainnet --broadcast -vvvv --verify --verifier blockscout --verifier-url https://explorer.goat.network/api/

deployTest:
	forge script script/DeployGateway.sol:DeployGateway --rpc-url goatTestnet --broadcast -vvvv --verify --verifier blockscout --verifier-url https://explorer.testnet3.goat.network/api/

