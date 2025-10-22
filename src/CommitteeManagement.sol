// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import {MultiSigVerifier} from "./MultiSigVerifier.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

/// @title CommitteeManagement
/// @notice Manages committee membership verification, authorized message execution with anti-replay,
///         watchtower registry, peerId registry, and a whitelist of integrator contracts that are
///         allowed to consume committee-signed authorizations.
/// @dev Inherits MultiSigVerifier for owner set and threshold management. Messages are domain-bound
///      to this contract address and are protected by a per-message nonce scheme stored off-chain
///      in the signed payload and on-chain by the `executed` mapping.
contract CommitteeManagement is MultiSigVerifier {
    using EnumerableMap for EnumerableMap.AddressToBytes32Map;
    using EnumerableSet for EnumerableSet.AddressSet;
    using EnumerableSet for EnumerableSet.Bytes32Set;

    // ========== Storage ==========
    // Mapping of committee member -> peerId
    EnumerableMap.AddressToBytes32Map private committeePeerId;
    // Set of registered watchtowers
    EnumerableSet.Bytes32Set private watchtowerList;
    // Whitelist of contracts allowed to externally consume committee-signed authorizations
    EnumerableSet.AddressSet private authorizedCallers;

    /// @notice Tracks whether a nonced message hash has been consumed on-chain to prevent replay.
    mapping(bytes32 => bool) public executed;

    // ========== Constructor ==========
    /// @param initialMembers Initial committee owner addresses
    /// @param requiredSignatures Threshold for a message to be considered authorized
    constructor(address[] memory initialMembers, uint256 requiredSignatures)
        MultiSigVerifier(initialMembers, requiredSignatures)
    {}

    // ========== Views / Getters ==========
    /// @notice Returns whether an address is a current committee member (owner)
    function isCommitteeMember(address member) external view returns (bool) {
        return isOwner[member];
    }

    /// @notice Returns the number of committee members
    function committeeSize() external view returns (uint256) {
        return ownerCount;
    }

    /// @notice Returns the current signature threshold (quorum)
    function quorumSize() external view returns (uint256) {
        return requiredSignatures;
    }

    /// @notice Helper to verify signatures using the inherited MultiSigVerifier
    /// @param msgHash The message hash to verify (already domain- and nonce-bound if applicable)
    /// @param signatures Committee signatures
    function verifySignatures(bytes32 msgHash, bytes[] memory signatures) external view returns (bool) {
        return verify(msgHash, signatures);
    }

    /// @notice Register/update the caller's PeerId for P2P usage
    function registerPeerId(bytes32 peerId) external {
        require(isOwner[msg.sender], "Not a committee member");
        committeePeerId.set(msg.sender, peerId);
    }

    /// @notice Get the stored PeerId of a committee member
    function getCommitteePeerId(address member) external view returns (bytes32) {
        require(isOwner[member], "Not a committee member");
        require(committeePeerId.contains(member), "Member has no registered PeerId");
        return committeePeerId.get(member);
    }

    /// @notice Checks whether a peerId is currently associated with any active committee member
    function isValidPeerId(bytes32 peerId) external view returns (bool) {
        for (uint256 i = 0; i < committeePeerId.length(); i++) {
            (address member, bytes32 storedPeerId) = committeePeerId.at(i);
            if (storedPeerId == peerId) {
                if (isOwner[member]) {
                    return true;
                } else {
                    return false;
                }
            }
        }
        return false;
    }

    /// @notice Returns the list of registered watchtowers
    function getWatchtowers() external view returns (bytes32[] memory) {
        return watchtowerList.values();
    }

    // ========== Modifiers ==========
    /// @dev Restricts external execution of nonced signatures to whitelisted callers.
    modifier onlyAuthorizedCaller() {
        require(authorizedCallers.contains(msg.sender), "caller not authorized");
        _;
    }

    // ========== Authorization Execution ==========
    /// @dev Internal implementation usable by this contract's own flows (e.g., add/remove watchtower)
    /// @param msgHash Preimage message hash (without nonce). Must be domain-bound by this contract in its encoder
    /// @param nonce Per-usage nonce agreed off-chain and included in signatures
    /// @param signatures Committee signatures authorizing the action
    function _executeNoncedSignatures(bytes32 msgHash, uint256 nonce, bytes[] memory signatures) internal {
        bytes32 noncedHash = getNoncedDigest(msgHash, nonce);
        require(!executed[noncedHash], "Already executed");
        require(verify(noncedHash, signatures), "Not enough valid committee signatures");
        executed[noncedHash] = true;
    }

    /// @notice External entry point restricted to approved integrator contracts (e.g., Gateway)
    /// @dev Prevents signature-burning by unapproved third parties.
    /// @param msgHash Preimage message hash (without nonce). Must be domain-bound by this contract in its encoder
    /// @param nonce Per-usage nonce agreed off-chain and included in signatures
    /// @param signatures Committee signatures authorizing the action
    function executeNoncedSignatures(bytes32 msgHash, uint256 nonce, bytes[] memory signatures)
        external
        onlyAuthorizedCaller
    {
        _executeNoncedSignatures(msgHash, nonce, signatures);
    }

    // ========== Watchtower Management ==========
    /// @notice Add a watchtower address via committee authorization
    function addWatchtower(bytes32 watchtower, uint256 nonce, bytes[] memory authSignatures) external {
        bytes32 msgHash = getAddWatchtowerDigest(watchtower);
        _executeNoncedSignatures(msgHash, nonce, authSignatures);
        watchtowerList.add(watchtower);
    }

    /// @notice Remove a watchtower address via committee authorization
    function removeWatchtower(bytes32 watchtower, uint256 nonce, bytes[] memory authSignatures) external {
        bytes32 msgHash = getRemoveWatchtowerDigest(watchtower);
        _executeNoncedSignatures(msgHash, nonce, authSignatures);
        watchtowerList.remove(watchtower);
    }

    // ========== Digest Helpers (Watchtower) ==========
    /// @dev Returns the domain-bound message hash for adding a watchtower (without nonce)
    function getAddWatchtowerDigest(bytes32 watchtower) internal view returns (bytes32) {
        bytes32 typeHash = keccak256("ADD_WATCHTOWER(bytes32 watchtower)");
        return keccak256(abi.encode(typeHash, address(this), watchtower));
    }

    /// @notice Returns the fully nonced digest for adding a watchtower
    function getAddWatchtowerDigestNonced(bytes32 watchtower, uint256 nonce) public view returns (bytes32) {
        bytes32 msgHash = getAddWatchtowerDigest(watchtower);
        return getNoncedDigest(msgHash, nonce);
    }

    /// @dev Returns the domain-bound message hash for removing a watchtower (without nonce)
    function getRemoveWatchtowerDigest(bytes32 watchtower) internal view returns (bytes32) {
        bytes32 typeHash = keccak256("REMOVE_WATCHTOWER(bytes32 watchtower)");
        return keccak256(abi.encode(typeHash, address(this), watchtower));
    }

    /// @notice Returns the fully nonced digest for removing a watchtower
    function getRemoveWatchtowerDigestNonced(bytes32 watchtower, uint256 nonce) public view returns (bytes32) {
        bytes32 msgHash = getRemoveWatchtowerDigest(watchtower);
        return getNoncedDigest(msgHash, nonce);
    }

    /// @notice Returns the fully nonced digest for an action-specific preimage hash
    /// @dev Domain-bound by this contract address and includes the provided nonce.
    function getNoncedDigest(bytes32 msgHash, uint256 nonce) public view returns (bytes32) {
        bytes32 typeHash = keccak256("NONCED_MESSAGE(bytes32 msgHash,uint256 nonce)");
        return keccak256(abi.encode(typeHash, address(this), msgHash, nonce));
    }

    // ------------------------------------------------------------
    // Authorized caller management (to mitigate signature-burning)
    // ------------------------------------------------------------

    event AuthorizedCallerAdded(address caller);
    event AuthorizedCallerRemoved(address caller);

    /// @notice Returns whether an address is authorized to call executeNoncedSignatures externally
    function isAuthorizedCaller(address caller) external view returns (bool) {
        return authorizedCallers.contains(caller);
    }

    /// @notice Add an authorized external caller via committee authorization
    function addAuthorizedCaller(address caller, uint256 nonce, bytes[] memory authSignatures) external {
        bytes32 msgHash = getAddAuthorizedCallerDigest(caller);
        _executeNoncedSignatures(msgHash, nonce, authSignatures);
        authorizedCallers.add(caller);
        emit AuthorizedCallerAdded(caller);
    }

    /// @notice Remove an authorized external caller via committee authorization
    function removeAuthorizedCaller(address caller, uint256 nonce, bytes[] memory authSignatures) external {
        bytes32 msgHash = getRemoveAuthorizedCallerDigest(caller);
        _executeNoncedSignatures(msgHash, nonce, authSignatures);
        authorizedCallers.remove(caller);
        emit AuthorizedCallerRemoved(caller);
    }

    // ========== Digest Helpers (Authorized Callers) ==========
    /// @dev Returns the domain-bound message hash for adding an authorized external caller (without nonce)
    function getAddAuthorizedCallerDigest(address caller) internal view returns (bytes32) {
        bytes32 typeHash = keccak256("ADD_AUTH_CALLER(address caller)");
        return keccak256(abi.encode(typeHash, address(this), caller));
    }

    /// @notice Returns the fully nonced digest for adding an authorized external caller
    function getAddAuthorizedCallerDigestNonced(address caller, uint256 nonce) public view returns (bytes32) {
        bytes32 msgHash = getAddAuthorizedCallerDigest(caller);
        return getNoncedDigest(msgHash, nonce);
    }

    /// @dev Returns the domain-bound message hash for removing an authorized external caller (without nonce)
    function getRemoveAuthorizedCallerDigest(address caller) internal view returns (bytes32) {
        bytes32 typeHash = keccak256("REMOVE_AUTH_CALLER(address caller)");
        return keccak256(abi.encode(typeHash, address(this), caller));
    }

    /// @notice Returns the fully nonced digest for removing an authorized external caller
    function getRemoveAuthorizedCallerDigestNonced(address caller, uint256 nonce) public view returns (bytes32) {
        bytes32 msgHash = getRemoveAuthorizedCallerDigest(caller);
        return getNoncedDigest(msgHash, nonce);
    }
}
