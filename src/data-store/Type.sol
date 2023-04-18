// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

enum Type {
    NIL, // 0 - default -- must be first
    ADDRESS, // 1
    BOOL, // 2
    BYTES, // 3
    STRING, // 4
    UINT256 // 5
}

library TypeLib {
    function toInt(Type t) public pure returns (uint256) {
        return uint256(t);
    }
}
