// SPDX-License-Identifier: GLP-3.0

pragma solidity 0.8.17;

import "./SPOGVotes.sol";

contract VoteToken is SPOGVotes {
    constructor(string memory name, string memory symbol) SPOGVotes(name, symbol) {}
}
