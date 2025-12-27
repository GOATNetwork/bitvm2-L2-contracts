// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {CommitteeManagement} from "../src/CommitteeManagement.sol";
import {GatewayUpgradeable} from "../src/Gateway.sol";

/*
    Script: Register a peer ID for the committee.
    Required env vars:
    - PRIVATE_KEY:    uint256 private key to broadcast from (committee member)
    - GATEWAY_ADDR:   address of deployed Gateway (proxy)
    - PEER_ID:        bytes peer ID to register
*/
contract RegisterPeerId is Script {
    function run() public {
        uint256 committeePrivateKey = vm.envUint("PRIVATE_KEY");
        address committee = vm.addr(committeePrivateKey);
        
        address gatewayAddr = vm.envAddress("GATEWAY_ADDR");
        address committeeManagementAddr = address(GatewayUpgradeable(payable(gatewayAddr)).committeeManagement());
        bytes memory peerId = vm.envBytes("PEER_ID");

        console.log("Committee:", committee);
        console.log("Gateway:", gatewayAddr);
        console.log("Committee Management:", committeeManagementAddr);
        console.log("Peer ID:", vm.toString(peerId));

        vm.startBroadcast(committeePrivateKey);

        CommitteeManagement(committeeManagementAddr).registerPeerId(peerId);
        
        console.log("Peer ID registered successfully");

        vm.stopBroadcast();
    }
}
