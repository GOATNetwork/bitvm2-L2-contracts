// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SequencerSetPublisher} from "../../src/SequencerSetPublisher.sol";

contract DeploySequencerSetPublisher is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address initialOwner = vm.addr(deployerPrivateKey);
        console.log("current balance: ", initialOwner.balance);
        vm.startBroadcast(deployerPrivateKey);
        SequencerSetPublisher publisher = new SequencerSetPublisher();
        publisher.initialize(
            initialOwner
        );
        vm.stopBroadcast();
        console.log("SequencerSetPublisher deployed at:", address(publisher));
    }
}
