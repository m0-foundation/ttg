// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IEpochBasedInflationaryVoteToken } from "../abstract/interfaces/IEpochBasedInflationaryVoteToken.sol";

interface IPowerToken is IEpochBasedInflationaryVoteToken {
    /******************************************************************************************************************\
    |                                                      Errors                                                      |
    \******************************************************************************************************************/

    error AlreadyClaimed();

    error InsufficientAuctionSupply();

    error InvalidCashTokenAddress();

    error InvalidVaultAddress();

    error NotStandardGovernor();

    error TransferFromFailed();

    error ZeroGovernorAddress();

    /******************************************************************************************************************\
    |                                                      Events                                                      |
    \******************************************************************************************************************/

    event Buy(address indexed buyer, uint256 amount, uint256 cost);

    event NextCashTokenSet(uint256 indexed startingEpoch, address indexed nextCashToken);

    event TargetSupplyInflated(uint256 indexed targetEpoch, uint256 indexed targetSupply);

    /******************************************************************************************************************\
    |                                              Interactive Functions                                               |
    \******************************************************************************************************************/

    function buy(uint256 amount, address destination) external;

    function markNextVotingEpochAsActive() external;

    function markParticipation(address delegatee) external;

    function setNextCashToken(address nextCashToken) external;

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    function INITIAL_SUPPLY() external pure returns (uint256 initialSupply);

    function amountToAuction() external view returns (uint256 amountToAuction);

    function bootstrapEpoch() external view returns (uint256 bootstrapEpoch);

    function bootstrapToken() external view returns (address bootstrapToken);

    function cashToken() external view returns (address cashToken);

    function getCost(uint256 amount) external view returns (uint256 price);

    function standardGovernor() external view returns (address governor);

    function targetSupply() external view returns (uint256 targetSupply);

    function vault() external view returns (address vault);
}
