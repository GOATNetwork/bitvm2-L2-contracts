// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";

import {GatewayDebug} from "../src/GatewayDebug.sol";

/*
	Script: call GatewayDebug.debugCancelWithdraw(graphId) as an operator.
	Required env vars:
	- PRIVATE_KEY:   uint256 private key of the operator who initialized the withdraw
	- GATEWAY_ADDR:  address of the Gateway (proxy) deployed on the network
	- GRAPH_ID:      bytes16 hex
*/
contract DebugCancelWithdraw is Script {
	function run() external {
		uint256 pk = vm.envUint("PRIVATE_KEY");
		address gatewayAddr = vm.envAddress("GATEWAY_ADDR");
        bytes memory graphRaw = vm.envBytes("GRAPH_ID");
        require(graphRaw.length == 16, "GRAPH_ID must be 16 bytes hex");
        bytes16 graphId;
        assembly {
            graphId := mload(add(graphRaw, 0x20))
        }
		address operator = vm.addr(pk);
		console.log("Gateway:", gatewayAddr);
		console.log("Operator:", operator);
		console.log("GraphId:", vm.toString(graphId));

		vm.startBroadcast(pk);
		GatewayDebug(gatewayAddr).debugCancelWithdraw(graphId);
		vm.stopBroadcast();

		console.log("debugCancelWithdraw sent");
	}
}