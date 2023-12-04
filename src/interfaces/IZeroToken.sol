// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IEpochBasedVoteToken } from "../abstract/interfaces/IEpochBasedVoteToken.sol";

interface IZeroToken is IEpochBasedVoteToken {
    /******************************************************************************************************************\
    |                                                      Errors                                                      |
    \******************************************************************************************************************/

    error InvalidStandardGovernorDeployerAddress();

    error LengthMismatch(uint256 length1, uint256 length2);

    error NotStandardGovernor();

    error StartEpochAfterEndEpoch();

    /******************************************************************************************************************\
    |                                              Interactive Functions                                               |
    \******************************************************************************************************************/

    function mint(address recipient, uint256 amount) external;

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    function getPastVotes(
        address account,
        uint256 startEpoch,
        uint256 endEpoch
    ) external view returns (uint256[] memory votingPowers);

    function pastBalancesOf(
        address account,
        uint256 startEpoch,
        uint256 endEpoch
    ) external view returns (uint256[] memory balances);

    function pastDelegates(
        address account,
        uint256 startEpoch,
        uint256 endEpoch
    ) external view returns (address[] memory delegatees);

    function pastTotalSupplies(
        uint256 startEpoch,
        uint256 endEpoch
    ) external view returns (uint256[] memory totalSupplies);

    function standardGovernor() external view returns (address standardGovernor);

    function standardGovernorDeployer() external view returns (address standardGovernorDeployer);
}
