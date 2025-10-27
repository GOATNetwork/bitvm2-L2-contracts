pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {IPegBTC} from "../src/interfaces/IPegBTC.sol";
import {IBitcoinSPV} from "../src/interfaces/IBitcoinSPV.sol";
import {CommitteeManagement} from "../src/CommitteeManagement.sol";
import {StakeManagement} from "../src/StakeManagement.sol";

import {GatewayDebug, CommitteeManagementDebug} from "../src/GatewayDebug.sol";
import {PegBTC} from "../src/PegBTC.sol";
import {UpgradeableProxy} from "../src/UpgradeableProxy.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DeployGateway is Script {
    address public deployer;
    address public bitcoinSPV;

    function setUp() public virtual {
        bitcoinSPV = vm.envAddress("BITCOINSPV_ADDR");
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.createWallet(deployerPrivateKey).addr;
        console.log("deployer address: ", deployer);
        vm.startBroadcast(deployerPrivateKey);
        deploy();
        vm.stopBroadcast();
    }

    function deploy() public {
        // deploy contracts
        GatewayDebug gatewayImpl = new GatewayDebug();
        console.log("Gateway implementation contract address: ", address(gatewayImpl));

        UpgradeableProxy proxy = new UpgradeableProxy(address(gatewayImpl), deployer, "");
        console.log("Gateway proxy contract contract address: ", address(proxy));
        GatewayDebug gateway = GatewayDebug(payable(proxy));

        PegBTC pegBTC = new PegBTC(address(gateway));
        console.log("PegBTC contract address: ", address(pegBTC));

        // Read committee config from env
        // - COMMITTEE_0, COMMITTEE_1, ... (addresses)
        // - WATCHTOWER_0, WATCHTOWER_1, ... (bytes32)
        address[] memory initialMembers = _readSequentialAddresses("COMMITTEE");
        uint256 initialRequired = (initialMembers.length * 2 + 2) / 3;
        bytes32[] memory initialWatchtowers = _readSequentialBytes32("WATCHTOWER");
        address[] memory initialAuthorizedCallers = new address[](1);
        initialAuthorizedCallers[0] = address(gateway);
        CommitteeManagementDebug committeeManagement =
            new CommitteeManagementDebug(initialMembers, initialRequired, initialAuthorizedCallers, initialWatchtowers);
        console.log("CommitteeManagement contract address: ", address(committeeManagement));

        StakeManagement stakeManagement = new StakeManagement(IERC20(address(pegBTC)), address(gateway));
        console.log("StakeManagement contract address: ", address(stakeManagement));

        gateway.initialize(
            IPegBTC(address(pegBTC)),
            IBitcoinSPV(bitcoinSPV),
            CommitteeManagement(address(committeeManagement)),
            StakeManagement(address(stakeManagement))
        );
    }

    // Helpers: read env arrays as sequential variables with numeric suffixes
    // Example: BASE=PREFIX, reads PREFIX_0, PREFIX_1, ... until a default is hit.
    function _readSequentialAddresses(string memory baseKey) internal view returns (address[] memory out) {
        // first pass: count
        uint256 count = 0;
        while (true) {
            string memory key = string(abi.encodePacked(baseKey, "_", vm.toString(count)));
            address val = vm.envOr(key, address(0));
            if (val == address(0)) break;
            unchecked {
                count++;
            }
        }
        out = new address[](count);
        for (uint256 i = 0; i < count; i++) {
            string memory key = string(abi.encodePacked(baseKey, "_", vm.toString(i)));
            out[i] = vm.envAddress(key);
        }
    }

    function _readSequentialBytes32(string memory baseKey) internal view returns (bytes32[] memory out) {
        // first pass: count
        uint256 count = 0;
        while (true) {
            string memory key = string(abi.encodePacked(baseKey, "_", vm.toString(count)));
            bytes32 val = vm.envOr(key, bytes32(0));
            if (val == bytes32(0)) break;
            unchecked {
                count++;
            }
        }
        out = new bytes32[](count);
        for (uint256 i = 0; i < count; i++) {
            string memory key = string(abi.encodePacked(baseKey, "_", vm.toString(i)));
            out[i] = vm.envBytes32(key);
        }
    }
}
