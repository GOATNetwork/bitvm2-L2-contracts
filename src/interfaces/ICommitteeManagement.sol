// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

interface ICommitteeManagement {
    event PeerIdUpdated(address indexed member, bytes peerId);
    event WatchtowerAdded(bytes32 indexed watchtower);
    event WatchtowerRemoved(bytes32 indexed watchtower);
    event AuthorizedCallerAdded(address caller);
    event AuthorizedCallerRemoved(address caller);

    function isCommitteeMember(address member) external view returns (bool);
    function committeeSize() external view returns (uint256);
    function quorumSize() external view returns (uint256);
    function verifySignatures(bytes32 msgHash, bytes[] memory signatures) external view returns (bool);
    function registerPeerId(bytes calldata peerId) external;
    function getCommitteePeerId(address member) external view returns (bytes memory);
    function isValidPeerId(bytes calldata peerId) external view returns (bool);
    function getWatchtowers() external view returns (bytes32[] memory);
    function addWatchtower(bytes32 watchtower, uint256 nonce, bytes[] memory authSignatures) external;
    function removeWatchtower(bytes32 watchtower, uint256 nonce, bytes[] memory authSignatures) external;
    function getNoncedDigest(bytes32 msgHash, uint256 nonce) external view returns (bytes32);
    function getAddWatchtowerDigestNonced(bytes32 watchtower, uint256 nonce) external view returns (bytes32);
    function getRemoveWatchtowerDigestNonced(bytes32 watchtower, uint256 nonce) external view returns (bytes32);
    function isAuthorizedCaller(address caller) external view returns (bool);
    function addAuthorizedCaller(address caller, uint256 nonce, bytes[] memory authSignatures) external;
    function removeAuthorizedCaller(address caller, uint256 nonce, bytes[] memory authSignatures) external;
    function getAddAuthorizedCallerDigestNonced(address caller, uint256 nonce) external view returns (bytes32);
    function getRemoveAuthorizedCallerDigestNonced(address caller, uint256 nonce) external view returns (bytes32);
    function executeNoncedSignatures(bytes32 msgHash, uint256 nonce, bytes[] memory signatures) external;
}
