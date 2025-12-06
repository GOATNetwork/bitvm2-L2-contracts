// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {GatewayDebug} from "../src/GatewayDebug.sol";

/*
	Required env vars:
	- PRIVATE_KEY:   uint256 private key of the operator who initialized the withdraw
	- GATEWAY_ADDR:  address of the Gateway (proxy) deployed on the network
	- TO: recipient_address
	- AMOUNT: amount_to_mint
*/
contract DebugMintPegBTC is Script {
    address public sender;
    address payable public gateway;

    function setUp() public virtual {
        gateway = payable(vm.envAddress("GATEWAY_ADDR"));
    }

    function run() public {
        uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
        sender = vm.createWallet(senderPrivateKey).addr;
        console.log("sender address: ", sender);

        vm.startBroadcast(senderPrivateKey);
        _mintPegBTC();
        vm.stopBroadcast();
    }

    function _mintPegBTC() public {
        address to = vm.envAddress("TO");
        uint256 amount = vm.envUint("AMOUNT");
        require(to != address(0), "TO env required");
        require(amount > 0, "AMOUNT env required");

        GatewayDebug(gateway).debugMintPegBTC(to, amount);
        console.log("debugMintPegBTC called with to:", to, "amount:", amount);
    }
}