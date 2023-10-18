// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.20;

import { IERC5805 } from "./IERC5805.sol";
import { IERC20Permit } from "./IERC20Permit.sol";

interface IEpochBasedVoteToken is IERC5805, IERC20Permit {
    error AlreadyDelegated();

    error AmountExceedsUint240();

    error InvalidEpochOrdering();

    error TransferToSelf();

    /******************************************************************************************************************\
    |                                              View/Pure Functions                                                 |
    \******************************************************************************************************************/

    function balanceOfAt(address account, uint256 epoch) external view returns (uint256 balance);

    function balancesOfAt(address account, uint256[] calldata epochs) external view returns (uint256[] memory balances);

    function balancesOfBetween(
        address account,
        uint256 startEpoch,
        uint256 endEpoch
    ) external view returns (uint256[] memory balances);

    function delegatesAt(address account, uint256 epoch) external view returns (address delegatee);

    function totalSupplyAt(uint256 epoch) external view returns (uint256 totalSupply);

    function totalSuppliesAt(uint256[] calldata epochs) external view returns (uint256[] memory totalSupplies);

    function totalSuppliesBetween(
        uint256 startEpoch,
        uint256 endEpoch
    ) external view returns (uint256[] memory totalSupplies);
}
