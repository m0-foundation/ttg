// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.19;

import { ERC165 } from "@openzeppelin/contracts/utils/introspection/ERC165.sol";

import { ISPOG } from "src/interfaces/ISPOG.sol";

contract SPOGMock is ERC165 {
    function supportsInterface(bytes4 interfaceId) public view override returns (bool) {
        return interfaceId == type(ISPOG).interfaceId || super.supportsInterface(interfaceId);
    }
}
