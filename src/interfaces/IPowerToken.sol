// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IEpochBasedInflationaryVoteToken } from "../abstract/interfaces/IEpochBasedInflationaryVoteToken.sol";

interface IPowerToken is IEpochBasedInflationaryVoteToken {
    /******************************************************************************************************************\
    |                                                      Events                                                      |
    \******************************************************************************************************************/

    event Buy(address indexed buyer, uint256 amount, uint256 cost);

    event EpochMarkedActive(uint256 indexed epoch);

    /******************************************************************************************************************\
    |                                                      Errors                                                      |
    \******************************************************************************************************************/

    error AlreadyClaimed();

    error EpochAlreadyActive();

    error InsufficientAuctionSupply();

    error InvalidCashTokenAddress();

    error InvalidVaultAddress();

    error NotStandardGovernor();

    error TransferFromFailed();

    error ZeroGovernorAddress();

    /******************************************************************************************************************\
    |                                              Interactive Functions                                               |
    \******************************************************************************************************************/

    function buy(uint256 amount, address destination) external;

    // TODO: buyWithPermit

    function markEpochActive() external;

    function markParticipation(address delegatee) external;

    function setNextCashToken(address nextCashToken_) external;

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    function INITIAL_SUPPLY() external pure returns (uint256 initialSupply);

    function activeEpochs() external view returns (uint256 activeEpochs);

    function amountToAuction() external view returns (uint256 amountToAuction);

    function bootstrapEpoch() external view returns (uint256 bootstrapEpoch);

    function bootstrapToken() external view returns (address bootstrapToken);

    function cashToken() external view returns (address cashToken);

    function getCost(uint256 amount) external view returns (uint256 price);

    function standardGovernor() external view returns (address governor);

    function isActiveEpoch(uint256 epoch) external view returns (bool isActiveEpoch);

    function vault() external view returns (address vault);
}
