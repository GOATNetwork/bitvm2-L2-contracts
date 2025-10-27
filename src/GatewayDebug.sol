// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {GatewayUpgradeable} from "./Gateway.sol";
import {CommitteeManagement} from "./CommitteeManagement.sol";
import {StakeManagement} from "./StakeManagement.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract GatewayDebug is GatewayUpgradeable {
    function mockProceedWithdraw(bytes16 graphId) external onlyCommittee {
        WithdrawData storage withdrawData = withdrawDataMap[graphId];
        withdrawData.status = WithdrawStatus.Processing;
    }

    function debugMintPegBTC(address to, uint256 amount) external onlyCommittee {
        pegBTC.mint(to, amount);
    }

    function debugUpdateCommitteeManagement(address newCommitteeManagement) external onlyCommittee {
        committeeManagement = CommitteeManagement(newCommitteeManagement);
    }

    function debugUpdateStakeManagement(address newStakeManagement) external onlyCommittee {
        stakeManagement = StakeManagement(newStakeManagement);
    }
}

contract CommitteeManagementDebug is CommitteeManagement {
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    constructor(
        address[] memory initialMembers,
        uint256 initialRequired,
        address[] memory initialAuthorizedCallers,
        bytes32[] memory initialWatchtowers
    ) CommitteeManagement(initialMembers, initialRequired, initialAuthorizedCallers, initialWatchtowers) {}

    modifier onlyCommittee() {
        require(isOwner[msg.sender], "only committee member can call");
        _;
    }

    function debugUpdateCommittee(address[] calldata newCommittee, uint256 newRequired) external onlyCommittee {
        _applyOwners(newCommittee, newRequired);
    }

    function debugAddWatchtower(bytes32 watchtower) external onlyCommittee {
        watchtowerList.add(watchtower);
    }

    function debugRemoveWatchtower(bytes32 watchtower) external onlyCommittee {
        watchtowerList.remove(watchtower);
    }

    function debugAddAuthorizedCaller(address caller) external onlyCommittee {
        authorizedCallers.add(caller);
    }

    function debugRemoveAuthorizedCaller(address caller) external onlyCommittee {
        authorizedCallers.remove(caller);
    }

    function debugRegisterPeerId(address member, bytes calldata peerId) external onlyCommittee {
        require(isOwner[member], "Not a committee member");

        // Clear previous index if existed
        bytes memory prev = committeePeerId[member];
        if (prev.length != 0) {
            bytes32 prevHash = keccak256(prev);
            if (peerIdOwnerByHash[prevHash] == member) {
                delete peerIdOwnerByHash[prevHash];
            }
        }

        bytes32 h = keccak256(peerId);
        address current = peerIdOwnerByHash[h];
        require(current == address(0) || current == member, "peerId already registered by another member");

        committeePeerId[member] = peerId;
        peerIdOwnerByHash[h] = member;
    }
}
