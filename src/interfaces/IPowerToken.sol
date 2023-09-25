// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import { IEpochBasedInflationaryVoteToken } from "./IEpochBasedInflationaryVoteToken.sol";

interface IPowerToken is IEpochBasedInflationaryVoteToken {
    error AlreadyClaimed();

    error EpochAlreadyActive();

    error InsufficientAuctionSupply();

    error NotGovernor();

    error TransferFromFailed();

    event Buy(address indexed buyer, uint256 amount, uint256 cost);

    event EpochMarkedActive(uint256 indexed epoch);

    function activeEpochs() external view returns (uint256 activeEpochs);

    function amountToAuction() external view returns (uint256 amountToAuction);

    function bootstrapEpoch() external view returns (uint256 bootstrapEpoch);

    function bootstrapToken() external view returns (address bootstrapToken);

    function buy(uint256 amount, address destination) external;

    // TODO: buyWithPermit

    function cashToken() external view returns (address cashToken);

    function getCost(uint256 amount) external view returns (uint256 price);

    function governor() external view returns (address governor);

    function isActiveEpoch(uint256 epoch) external view returns (bool isActiveEpoch);

    function markEpochActive() external;

    function markParticipation(address delegatee) external;

    function treasury() external view returns (address treasury);
}
