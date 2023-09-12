// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import { IEpochBasedInflationaryVoteToken } from "./IEpochBasedInflationaryVoteToken.sol";

interface IPowerToken is IEpochBasedInflationaryVoteToken {
    event Buy(address indexed buyer, uint256 amount, uint256 cost);
    event EpochMarkedActive(uint256 indexed epoch);

    error AlreadyClaimed();

    function activeEpochs() external view returns (uint256 activeEpochs_);

    function amountToAuction() external view returns (uint256 amountToAuction_);

    function auctionSlope() external view returns (uint256 auctionSlope_);

    function bootstrapEpoch() external view returns (uint256 bootstrapEpoch);

    function bootstrapToken() external view returns (address bootstrapToken);

    function buy(uint256 amount_, address destination_) external;

    // TODO: buyWithPermit

    function cash() external view returns (address cash_);

    function getCost(uint256 amount_) external view returns (uint256 price_);

    function isActiveEpoch(uint256 epoch_) external view returns (bool isActiveEpoch_);

    function markEpochActive() external;

    function treasury() external view returns (address treasury_);
}
