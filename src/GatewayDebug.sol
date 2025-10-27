// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {GatewayUpgradeable} from "./Gateway.sol";
import {CommitteeManagement} from "./CommitteeManagement.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

contract GatewayDebug is GatewayUpgradeable {
    function mockProceedWithdraw(bytes16 graphId) external onlyCommittee {
        WithdrawData storage withdrawData = withdrawDataMap[graphId];
        withdrawData.status = WithdrawStatus.Processing;
    }

    function debugMintPegBTC(address to, uint256 amount) external onlyCommittee {
        pegBTC.mint(to, amount);
    }
}

contract CommitteeManagementDebug is CommitteeManagement {
    using EnumerableMap for EnumerableMap.AddressToBytes32Map;
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

    function debugRegisterPeerId(address member, bytes32 peerId) external onlyCommittee {
        require(isOwner[member], "Not a committee member");
        committeePeerId.set(member, peerId);
    }
}
