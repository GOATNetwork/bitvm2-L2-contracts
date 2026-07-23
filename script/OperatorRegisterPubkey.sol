// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {Script, console} from "forge-std/Script.sol";
import {GatewayUpgradeable} from "../src/Gateway.sol";
import {StakeManagement} from "../src/StakeManagement.sol";
import {BtcUtils} from "../src/libraries/BtcUtils.sol";

/*
    Script: Register a public key for the operator.
    Required env vars:
    - PRIVATE_KEY:    uint256 private key to broadcast from (operator)
    - BTC_PRIVATE_KEY:uint256 private key corresponding to PUBKEY
    - GATEWAY_ADDR:   address of deployed Gateway (proxy)
    - PUBKEY:         x-only bytes32 public key to register
    - PUBKEY_PREFIX:  compressed pubkey prefix (2 for even Y, 3 for odd Y)
*/
contract OperatorRegisterPubkey is Script {
    function run() public {
        uint256 operatorPrivateKey = vm.envUint("PRIVATE_KEY");
        uint256 btcPrivateKey = vm.envUint("BTC_PRIVATE_KEY");
        address operator = vm.addr(operatorPrivateKey);

        address gatewayAddr = vm.envAddress("GATEWAY_ADDR");
        bytes32 pubkey = vm.envBytes32("PUBKEY");
        bytes1 pubkeyPrefix = bytes1(uint8(vm.envUint("PUBKEY_PREFIX")));

        console.log("Operator:", operator);
        console.log("Gateway:", gatewayAddr);
        console.log("Pubkey:", vm.toString(pubkey));

        address stakeManagementAddr = address(GatewayUpgradeable(payable(gatewayAddr)).stakeManagement());
        console.log("StakeManagement:", stakeManagementAddr);

        StakeManagement stakeManagement = StakeManagement(stakeManagementAddr);
        bytes32 digest = stakeManagement.getRegisterPubkeyDigest(operator);
        (, bytes32 r, bytes32 s) = vm.sign(btcPrivateKey, digest);
        bytes memory signature = abi.encodePacked(r, s);

        // Fail before broadcasting if the Bitcoin key cannot authorize this registration.
        BtcUtils.verifyBtcSignature(digest, abi.encodePacked(pubkeyPrefix, pubkey), signature);
        require(stakeManagement.addressToPubkey(operator) == bytes32(0), "operator already has a pubkey");
        require(stakeManagement.pubkeyToAddress(pubkey) == address(0), "pubkey already registered");

        vm.startBroadcast(operatorPrivateKey);
        stakeManagement.registerPubkey(pubkey, pubkeyPrefix, signature);

        console.log("Pubkey registered successfully");

        vm.stopBroadcast();
    }
}
