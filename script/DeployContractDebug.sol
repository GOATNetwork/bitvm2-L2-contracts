pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {IPegBTC} from "../src/interfaces/IPegBTC.sol";
import {IBitcoinSPV} from "../src/interfaces/IBitcoinSPV.sol";
import {CommitteeManagement} from "../src/CommitteeManagement.sol";
import {StakeManagement} from "../src/StakeManagement.sol";
import {ICommitteeManagement} from "../src/interfaces/ICommitteeManagement.sol";
import {IStakeManagement} from "../src/interfaces/IStakeManagement.sol";

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
        GatewayDebug gatewayImpl = new GatewayDebug();
        console.log(
            "Gateway implementation contract address: ",
            address(gatewayImpl)
        );

        UpgradeableProxy gatewayProxy = new UpgradeableProxy(
            address(gatewayImpl),
            deployer,
            ""
        );
        console.log("Gateway proxy contract address: ", address(gatewayProxy));
        GatewayDebug gateway = GatewayDebug(payable(gatewayProxy));

        PegBTC pegBTC = new PegBTC(address(gateway));
        console.log("PegBTC contract address: ", address(pegBTC));

        address[] memory initialMembers = _readSequentialAddresses("COMMITTEE");
        uint256 initialRequired = (initialMembers.length * 2 + 2) / 3;
        bytes32[] memory initialWatchtowers = _readSequentialBytes32(
            "WATCHTOWER"
        );
        require(initialMembers.length > 0, "COMMITTEE list empty");
        require(initialWatchtowers.length > 0, "WATCHTOWER list empty");
        address[] memory initialAuthorizedCallers = new address[](1);
        initialAuthorizedCallers[0] = address(gateway);

        CommitteeManagementDebug committeeImpl = new CommitteeManagementDebug();
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
        ICommitteeManagement committeeManagement = ICommitteeManagement(
            address(committeeProxy)
        );

        StakeManagement stakeImpl = new StakeManagement();
        console.log(
            "StakeManagement implementation contract address: ",
            address(stakeImpl)
        );
        bytes memory stakeInitData = abi.encodeWithSelector(
            StakeManagement.initialize.selector,
            IERC20(address(pegBTC)),
            address(gateway)
        );
        UpgradeableProxy stakeProxy = new UpgradeableProxy(
            address(stakeImpl),
            deployer,
            stakeInitData
        );
        console.log(
            "StakeManagement proxy contract address: ",
            address(stakeProxy)
        );
        IStakeManagement stakeManagement = IStakeManagement(
            address(stakeProxy)
        );

        gateway.initialize(
            IPegBTC(address(pegBTC)),
            IBitcoinSPV(bitcoinSPV),
            committeeManagement,
            stakeManagement
        );
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
