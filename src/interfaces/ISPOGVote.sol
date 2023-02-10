// SPDX-License-Identifier: GLP-3.0
pragma solidity 0.8.17;

import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

interface ISPOGVote is IVotes {
    function initSPOGAddress(address _spogAddress) external;

    // used only in prototype - not for production use
    function mint(address _account, uint256 _amount) external;
}
