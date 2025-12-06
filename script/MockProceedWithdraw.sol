// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {GatewayDebug} from "../src/GatewayDebug.sol";

/*
    Required env vars:
	- PRIVATE_KEY:    uint256 private key to broadcast from (operator)
	- GATEWAY_ADDR:   address of deployed Gateway (proxy)
    - GRAPH_ID:       bytes16 hex 
*/
contract MockProceedWithdraw is Script {
	address public sender;
	address payable public gateway;

	function setUp() public virtual {
		gateway = payable(vm.envAddress("GATEWAY_ADDR"));
	}

	function run() public {
		uint256 senderPrivateKey = vm.envUint("PRIVATE_KEY");
		sender = vm.createWallet(senderPrivateKey).addr;
		console.log("sender address:", sender);

		vm.startBroadcast(senderPrivateKey);
		_mockProceedWithdraw();
		vm.stopBroadcast();
	}

	function _mockProceedWithdraw() public {
        bytes memory graphRaw = vm.envBytes("GRAPH_ID");
        require(graphRaw.length == 16, "GRAPH_ID must be 16 bytes hex");
        bytes16 graphId;
        assembly {
            graphId := mload(add(graphRaw, 0x20))
        }
        console.log("\ngraphId:", vm.toString(graphId));

		GatewayDebug(gateway).mockProceedWithdraw(graphId);
		console.log("mockProceedWithdraw sent for graphId:", vm.toString(uint256(uint128(bytes16(graphId)))));
	}
}