// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IEpochBasedInflationaryVoteToken } from "../abstract/interfaces/IEpochBasedInflationaryVoteToken.sol";

/**
 * @title An instance of an EpochBasedInflationaryVoteToken delegating control to a Standard Governor, and enabling
 *        auctioning of the unowned inflated supply.
 */
interface IPowerToken is IEpochBasedInflationaryVoteToken {
    /******************************************************************************************************************\
    |                                                      Errors                                                      |
    \******************************************************************************************************************/

    /**
     * @notice Revert message when the amount available for auction is less than the minimum requested to buy.
     * @param  amountToAuction    The amount available for auction.
     * @param  minAmountRequested The minimum amount that was requested to buy.
     */
    error InsufficientAuctionSupply(uint256 amountToAuction, uint256 minAmountRequested);

    /// @notice Revert message when the Cash Token specified in the constructor is address(0).
    error InvalidCashTokenAddress();

    /// @notice Revert message when the Standard Governor specified in the constructor is address(0).
    error InvalidStandardGovernorAddress();

    /// @notice Revert message when the Vault specified in the constructor is address(0).
    error InvalidVaultAddress();

    /// @notice Revert message when the caller is not the Standard Governor.
    error NotStandardGovernor();

    /// @notice Revert message when a token transferFrom fails.
    error TransferFromFailed();

    /******************************************************************************************************************\
    |                                                      Events                                                      |
    \******************************************************************************************************************/

    /**
     * @notice Emitted when `buyer` has bought `amount` tokens from the auction, as a total cash token value of `cost`.
     * @param  buyer  The address of account that bought tokens from the auction.
     * @param  amount The amount of tokens bought.
     * @param  cost   The total cash token cost of the purchase.
     */
    event Buy(address indexed buyer, uint256 amount, uint256 cost);

    /**
     * @notice Emitted when the cash token is queued to become `nextCashToken` at the start of epoch `startingEpoch`.
     * @param  startingEpoch The epoch number as a clock value in which the new cash token takes effect.
     * @param  nextCashToken The address of the cash token taking effect at `startingEpoch`.
     */
    event NextCashTokenSet(uint256 indexed startingEpoch, address indexed nextCashToken);

    /**
     * @notice Emitted when the target supply is queued to become `targetSupply` at the start of epoch `targetEpoch`.
     * @param  targetEpoch  The epoch number as a clock value in which the new target supply takes effect.
     * @param  targetSupply The target supply taking effect at `startingEpoch`.
     */
    event TargetSupplyInflated(uint256 indexed targetEpoch, uint256 indexed targetSupply);

    /******************************************************************************************************************\
    |                                              Interactive Functions                                               |
    \******************************************************************************************************************/

    /**
     * @notice Allows a caller to buy `amount` tokens from the auction.
     * @param  minAmount   The minimum amount of tokens the caller is interested in buying.
     * @param  maxAmount   The maximum amount of tokens the caller is interested in buying.
     * @param  destination The address of the account to send the bought tokens.
     * @return amount      The amount of token bought.
     * @return cost        The total cash token cost of the purchase.
     */
    function buy(
        uint256 minAmount,
        uint256 maxAmount,
        address destination
    ) external returns (uint256 amount, uint256 cost);

    /// @notice Marks the next voting epoch as targeted for inflation.
    function markNextVotingEpochAsActive() external;

    /**
     * @notice Marks `delegatee` as having participated in the current epoch, thus receiving voting power inflation.
     * @param  delegatee The address of the account being marked as having participated.
     */
    function markParticipation(address delegatee) external;

    /**
     * @notice Queues the cash token that will take effect from the next epoch onward.
     * @param  nextCashToken The address of the cash token taking effect from the next epoch onward.
     */
    function setNextCashToken(address nextCashToken) external;

    /******************************************************************************************************************\
    |                                               View/Pure Functions                                                |
    \******************************************************************************************************************/

    /// @notice Returns the initial supply of the token.
    function INITIAL_SUPPLY() external pure returns (uint256 initialSupply);

    /// @notice Returns the amount of tokens that can be bought in the auction.
    function amountToAuction() external view returns (uint256 amountToAuction);

    /// @notice Returns the epoch from which token balances and voting powers are bootstrapped.
    function bootstrapEpoch() external view returns (uint256 bootstrapEpoch);

    /// @notice Returns the address of the token in which token balances and voting powers are bootstrapped.
    function bootstrapToken() external view returns (address bootstrapToken);

    /// @notice Returns the address of the cash token required to buy from the token auction.
    function cashToken() external view returns (address cashToken);

    /**
     * @notice Returns the total cost, in cash token, of purchasing `amount` tokens from the auction.
     * @param  amount Some amount of tokens.
     * @return cost   The total cost, in cash token, of `amount` tokens.
     */
    function getCost(uint256 amount) external view returns (uint256 cost);

    /// @notice Returns the address of the Standard Governor.
    function standardGovernor() external view returns (address governor);

    /// @notice Returns the target supply, which helps determine the amount of tokens up for auction.
    function targetSupply() external view returns (uint256 targetSupply);

    /// @notice Returns the address of the Vault.
    function vault() external view returns (address vault);
}
