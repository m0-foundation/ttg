// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IERC712 } from "../../../lib/common/src/interfaces/IERC712.sol";

import { IERC6372 } from "./IERC6372.sol";

// See https://eips.ethereum.org/EIPS/eip-5805

interface IERC5805 is IERC712, IERC6372 {
    event DelegateChanged(address indexed delegator, address indexed fromDelegate, address indexed toDelegate);

    event DelegateVotesChanged(address indexed delegate, uint256 previousBalance, uint256 newBalance);

    /******************************************************************************************************************\
    |                                             Interactive Functions                                                |
    \******************************************************************************************************************/

    function delegate(address delegatee) external;

    function delegateBySig(address delegatee, uint256 nonce, uint256 expiry, uint8 v, bytes32 r, bytes32 s) external;

    /******************************************************************************************************************\
    |                                              View/Pure Functions                                                 |
    \******************************************************************************************************************/

    function DELEGATION_TYPEHASH() external view returns (bytes32 typehash);

    function delegates(address account) external view returns (address delegatee);

    function getPastVotes(address account, uint256 timepoint) external view returns (uint256 votePower);

    function getVotes(address account) external view returns (uint256 votePower);
}
