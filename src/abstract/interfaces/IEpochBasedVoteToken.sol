// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IERC20Permit } from "../../../lib/common/src/interfaces/IERC20Permit.sol";

import { IERC5805 } from "./IERC5805.sol";

interface IEpochBasedVoteToken is IERC5805, IERC20Permit {
    error AlreadyDelegated();

    error AmountExceedsUint240();

    error InvalidEpochOrdering();

    error StartEpochAfterEndEpoch();

    error TransferToSelf();

    /******************************************************************************************************************\
    |                                             Interactive Functions                                                |
    \******************************************************************************************************************/

    function delegateBySig(
        address account,
        address delegatee,
        uint256 nonce,
        uint256 expiry,
        bytes memory signature
    ) external;

    /******************************************************************************************************************\
    |                                              View/Pure Functions                                                 |
    \******************************************************************************************************************/

    function balanceOfAt(address account, uint256 epoch) external view returns (uint256 balance);

    function balancesOfBetween(
        address account,
        uint256 startEpoch,
        uint256 endEpoch
    ) external view returns (uint256[] memory balances);

    function delegatesAt(address account, uint256 epoch) external view returns (address delegatee);

    function totalSupplyAt(uint256 epoch) external view returns (uint256 totalSupply);

    function totalSuppliesBetween(
        uint256 startEpoch,
        uint256 endEpoch
    ) external view returns (uint256[] memory totalSupplies);
}
