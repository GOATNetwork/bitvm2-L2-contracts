// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {CommitteeManagement} from "../src/CommitteeManagement.sol";
import {GatewayUpgradeable} from "../src/Gateway.sol";

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
