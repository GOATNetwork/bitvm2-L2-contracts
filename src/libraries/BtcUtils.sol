// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

library BtcUtils {
    error InvalidBtcSignature();
    error InvalidBtcPubkey();
    error InvalidPubkeyLength();
    error InvalidPublicKeyX();
    error ModexpFailed();

    uint256 constant SECP256K1N_DIV_2 = 0x7FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF5D576E7357A4501DDFE92F46681B20A0;

    function verifyBtcSignature(
        bytes32 sigHash,
        bytes memory btcPubkey,
        bytes memory btcSig
    ) internal view {
        if (btcSig.length != 64) {
            revert InvalidBtcSignature();
        }
        bytes32 r;
        bytes32 s;
        assembly {
            r := mload(add(btcSig, 32))
            s := mload(add(btcSig, 64))
        }
        if (uint256(s) == 0 || uint256(s) > SECP256K1N_DIV_2) {
            revert InvalidBtcSignature();
        }
        
        address signer1 = ecrecover(sigHash, 27, r, s);
        address signer2 = ecrecover(sigHash, 28, r, s);
        address derivedAddress = deriveAddress(btcPubkey);
        
        if (derivedAddress == address(0)) {
            revert InvalidBtcPubkey();
        }
        
        if (signer1 != derivedAddress && signer2 != derivedAddress) {
            revert InvalidBtcSignature();
        }
    }

    function deriveAddress(bytes memory pubkey) internal view returns (address) {
        if (pubkey.length != 33) {
            revert InvalidPubkeyLength();
        }
        uint256 x;
        uint8 prefix;
        assembly {
            prefix := byte(0, mload(add(pubkey, 32)))
            x := mload(add(pubkey, 33))
        }
        
        uint256 y = deriveY(prefix, x);
        return address(uint160(uint256(keccak256(abi.encodePacked(x, y)))));
    }

    function deriveY(uint8 prefix, uint256 x) internal view returns (uint256) {
        uint256 p = 0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEFFFFFC2F;
        // y^2 = x^3 + 7 mod p
        uint256 y2 = addmod(mulmod(x, mulmod(x, x, p), p), 7, p);
        
        // y = (y^2)^((p+1)/4) mod p
        uint256 exp = 0x3FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFBFFFFF0C;
        
        uint256 y = modexp(y2, exp, p);
        
        if (mulmod(y, y, p) != y2) {
            revert InvalidPublicKeyX();
        }
        
        if ((y % 2) != (prefix % 2)) {
            y = p - y;
        }
        return y;
    }

    function modexp(uint256 base, uint256 exp, uint256 mod) internal view returns (uint256) {
        bytes memory input = abi.encodePacked(
            uint256(32), // base length
            uint256(32), // exp length
            uint256(32), // mod length
            base,
            exp,
            mod
        );
        
        (bool success, bytes memory output) = address(0x05).staticcall(input);
        if (!success) {
            revert ModexpFailed();
        }
        return abi.decode(output, (uint256));
    }
}
