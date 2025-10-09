pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {IPegBTC} from "../src/interfaces/IPegBTC.sol";
import {IBitcoinSPV} from "../src/interfaces/IBitcoinSPV.sol";
import {ICommitteeManagement} from "../src/interfaces/ICommitteeManagement.sol";
import {IStakeManagement} from "../src/interfaces/IStakeManagement.sol";

import {GatewayUpgradeable} from "../src/Gateway.sol";
import {PegBTC} from "../src/PegBTC.sol";
import {UpgradeableProxy} from "../src/UpgradeableProxy.sol";
import {CommitteeManagement} from "../src/CommitteeManagement.sol";
import {StakeManagement} from "../src/StakeManagement.sol";
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
        GatewayUpgradeable gatewayImpl = new GatewayUpgradeable();
        console.log("Gateway implementation contract address: ", address(gatewayImpl));
        UpgradeableProxy proxy = new UpgradeableProxy(address(gatewayImpl), deployer, "");
        console.log("Gateway proxy contract contract address: ", address(proxy));
        GatewayUpgradeable gateway = GatewayUpgradeable(payable(proxy));
        PegBTC pegBTC = new PegBTC(address(gateway));
        console.log("PegBTC contract address: ", address(pegBTC));
        address[] memory initialMembers = new address[](1);
        initialMembers[0] = deployer;
        CommitteeManagement committeeManagement = new CommitteeManagement(initialMembers, 1);
        console.log("CommitteeManagement contract address: ", address(committeeManagement));
        StakeManagement stakeManagement = new StakeManagement(IERC20(address(pegBTC)), address(gateway));
        console.log("StakeManagement contract address: ", address(stakeManagement));
        gateway.initialize(
            IPegBTC(address(pegBTC)),
            IBitcoinSPV(bitcoinSPV),
            ICommitteeManagement(address(committeeManagement)),
            IStakeManagement(address(stakeManagement))
        );
    }
}
