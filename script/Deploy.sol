pragma solidity ^0.8.0;

import {Script, console} from "forge-std/Script.sol";

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IBitcoinSPV} from "../src/interfaces/IBitcoinSPV.sol";

import {GatewayUpgradeable} from "../src/Gateway.sol";
import {PegBTC} from "../src/PegBTC.sol";
import {UpgradeableProxy} from "../src/UpgradeableProxy.sol";

contract TaskTest is Script {
    address public deployer;

    address public relayer;
    address public bitcoinSPV;

    function setUp() public virtual {
        relayer = vm.envAddress("RELAYER_ADDR");
        bitcoinSPV = vm.envAddress("BITCOIN_CONTRACT");
    }

    function run() public {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        deployer = vm.createWallet(deployerPrivateKey).addr;
        vm.startBroadcast(deployerPrivateKey);

        deploy();

        vm.stopBroadcast();
    }

    function deploy() public {
        // deploy contracts
        PegBTC pegBTC = new PegBTC(deployer);

        GatewayUpgradeable gateway = new GatewayUpgradeable(
            IERC20(pegBTC),
            IBitcoinSPV(bitcoinSPV),
            relayer
        );
        UpgradeableProxy proxy = new UpgradeableProxy(
            address(gateway),
            deployer,
            ""
        );
        gateway = GatewayUpgradeable(payable(proxy));

        console.log("Gateway contract address: ", address(gateway));
    }
}
