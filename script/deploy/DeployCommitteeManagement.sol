// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";
import {CommitteeManagement} from "../../src/CommitteeManagement.sol";
import {UpgradeableProxy} from "../../src/UpgradeableProxy.sol";

contract DeployCommitteeManagement is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.createWallet(deployerPrivateKey).addr;
        address gatewayProxy = vm.envAddress("GATEWAY_PROXY_ADDR");

        vm.startBroadcast(deployerPrivateKey);

        address[] memory initialMembers = _readSequentialAddresses("COMMITTEE");
        require(initialMembers.length > 0, "COMMITTEE list empty");
        bytes32[] memory initialWatchtowers = _readSequentialBytes32(
            "WATCHTOWER"
        );
        require(initialWatchtowers.length > 0, "WATCHTOWER list empty");
        uint256 initialRequired = (initialMembers.length * 2 + 2) / 3;
        address[] memory initialAuthorizedCallers = new address[](1);
        initialAuthorizedCallers[0] = gatewayProxy;

        CommitteeManagement committeeImpl = new CommitteeManagement();
        console.log(
            "CommitteeManagement implementation contract address: ",
            address(committeeImpl)
        );

        bytes memory committeeInitData = abi.encodeWithSelector(
            CommitteeManagement.initialize.selector,
            initialMembers,
            initialRequired,
            initialAuthorizedCallers,
            initialWatchtowers
        );
        UpgradeableProxy committeeProxy = new UpgradeableProxy(
            address(committeeImpl),
            deployer,
            committeeInitData
        );
        console.log(
            "CommitteeManagement proxy contract address: ",
            address(committeeProxy)
        );

        vm.stopBroadcast();
    }

    function _readSequentialAddresses(
        string memory baseKey
    ) internal view returns (address[] memory out) {
        uint256 count = 0;
        while (true) {
            string memory key = string(
                abi.encodePacked(baseKey, "_", vm.toString(count))
            );
            address val = vm.envOr(key, address(0));
            if (val == address(0)) break;
            unchecked {
                count++;
            }
        }
        out = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            string memory key = string(
                abi.encodePacked(baseKey, "_", vm.toString(i))
            );
            out[i] = vm.envAddress(key);
        }
    }

    function _readSequentialBytes32(
        string memory baseKey
    ) internal view returns (bytes32[] memory out) {
        uint256 count = 0;
        while (true) {
            string memory key = string(
                abi.encodePacked(baseKey, "_", vm.toString(count))
            );
            bytes32 val = vm.envOr(key, bytes32(0));
            if (val == bytes32(0)) break;
            unchecked {
                count++;
            }
        }
        out = new bytes32[](count);
        for (uint256 i = 0; i < count; i++) {
            string memory key = string(
                abi.encodePacked(baseKey, "_", vm.toString(i))
            );
            out[i] = vm.envBytes32(key);
        }
    }
}
