// SPDX-License-Identifier: GLP-3.0
pragma solidity 0.8.17;

import {IVotes} from "@openzeppelin/contracts/governance/utils/IVotes.sol";

/***************************************************/
/******** Prototype - NOT FOR PROD ****************/
/*************************************************/

interface P_ISPOGVote is IVotes {
    function initSPOGAddress(address _spogAddress) external;

    function mint(address _account, uint256 _amount) external;
}
