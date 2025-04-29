pragma solidity ^0.8.0;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";

import {GatewayUpgradeable} from "../src/Gateway.sol";
import {PegBTC} from "../src/PegBTC.sol";
import {UpgradeableProxy} from "../src/UpgradeableProxy.sol";

import {IBitcoinSPV} from "../src/interfaces/IBitcoinSPV.sol";

contract MerkleTest is Test {
    GatewayUpgradeable public gateway;

    address public msgSender;
    address public admin = address(1);
    address public relayer = address(2);

    function setUp() public virtual {
        msgSender = address(this);

        // deploy contracts
        PegBTC pegBTC = new PegBTC(admin);

        gateway = new GatewayUpgradeable(
            pegBTC,
            IBitcoinSPV(address(0)),
            relayer
        );
        UpgradeableProxy proxy = new UpgradeableProxy(
            address(gateway),
            admin,
            ""
        );
        gateway = GatewayUpgradeable(payable(proxy));
    }

    function test_MerklProof() public {
        bytes32 blockHash = 0x30275a78098ef52810890cf21a006b67e5a06fa3671accf7a723f60000000000;
        bytes32 merkleRoot = 0xefd0e339a15d6bc1de81ac9d879e4ea4ea0525c53dadaa8d1b3f12f1bbd5942f;
        bytes
            memory rawHeader = hex"00003e2060477a7f175bd203f1227aa0460f5cdd4fc17d5eea8835697a67370000000000efd0e339a15d6bc1de81ac9d879e4ea4ea0525c53dadaa8d1b3f12f1bbd5942f03230f68ffff001d46003136";

        (bytes32 parsedBlockHash, bytes32 parsedMerkleRoot) = gateway
            .parseBtcBlockHeader(rawHeader);
        assertEq(parsedBlockHash, blockHash);
        assertEq(parsedMerkleRoot, merkleRoot);

        bytes32 txId = 0xa8ef0c496c6546bb55d78914e0a820e0db1ab610f1b65192a0e14e006d08a350;
        bytes32[] memory proof = new bytes32[](9);
        proof[
            0
        ] = 0x399e64a71c8b3b296946a3cabd6945f23e4e462eefb57994306b510d479b0a1c;
        proof[
            1
        ] = 0x4068b1b58ba1de837e3dc2faf91d6223dba905c50746f14cafb02843c2634296;
        proof[
            2
        ] = 0xd5a94b777d6e39679e9d26523ae9f4fef61a08aa1bdaa98baea79611a91c4867;
        proof[
            3
        ] = 0xda50f82e817fc9fdc760c5161c79c8a534656aef1afa6d29826e9316e5f9a73c;
        proof[
            4
        ] = 0x81a2cfd5168e51d0faa695efff3ee006b11b0b2bb8d5b006dd4775b24538136a;
        proof[
            5
        ] = 0xc6d6d9ba381c5ae7521604313f25c7e7ac0d17d6a1e6833c2bc7ae104dcdd4ca;
        proof[
            6
        ] = 0x9d75b98a520a1372efb50e4db3e3b1ea6e9d9b60a555fe69ccb1e62f8129818b;
        proof[
            7
        ] = 0x368ee7a427c02346a4ad97a7be455fdf2b81e0af0053e3e1272b39f26510bf11;
        proof[
            8
        ] = 0x47030f03a42b203b699b3fca8154348ecdd0d64a079423cf6e8d07464e0435a0;
        uint256 txIndex = 189;
        assertTrue(
            gateway.verifyMerkleProof(parsedMerkleRoot, proof, txId, txIndex)
        );
    }
}
