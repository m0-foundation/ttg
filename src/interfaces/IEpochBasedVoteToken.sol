// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.20;

import { IERC5805 } from "./IERC5805.sol";
import { IERC20Permit } from "./IERC20Permit.sol";

interface IEpochBasedVoteToken is IERC5805, IERC20Permit {
    error AlreadyDelegated();

    error AmountExceedsUint240();

    error TransferToSelf();

    /******************************************************************************************************************\
    |                                              View/Pure Functions                                                 |
    \******************************************************************************************************************/

    function balanceOfAt(address account, uint256 epoch) external view returns (uint256 balance);

    function delegatesAt(address account, uint256 epoch) external view returns (address delegatee);

    function totalSupplyAt(uint256 epoch) external view returns (uint256 totalSupply);
}
