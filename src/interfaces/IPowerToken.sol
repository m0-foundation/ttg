// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IEpochBasedInflationaryVoteToken } from "../abstract/interfaces/IEpochBasedInflationaryVoteToken.sol";

/**
 * @title  An instance of an EpochBasedInflationaryVoteToken delegating control to a Standard Governor,
 *         and enabling auctioning of the unowned inflated supply.
 * @author M^0 Labs
 */
interface IPowerToken is IEpochBasedInflationaryVoteToken {
    /* ============ Events ============ */

    /**
     * @notice Emitted when `buyer` has bought `amount` tokens from the auction, as a total cash token value of `cost`.
     * @param  buyer  The address of account that bought tokens from the auction.
     * @param  amount The amount of tokens bought.
     * @param  cost   The total cash token cost of the purchase.
     */
    event Buy(address indexed buyer, uint240 amount, uint256 cost);

    /**
     * @notice Emitted when the cash token is queued to become `nextCashToken` at the start of epoch `startingEpoch`.
     * @param  startingEpoch The epoch number as a clock value in which the new cash token takes effect.
     * @param  nextCashToken The address of the cash token taking effect at `startingEpoch`.
     */
    event NextCashTokenSet(uint16 indexed startingEpoch, address indexed nextCashToken);

    /**
     * @notice Emitted in the constructor at deployment.
     * @param  tagline The tagline of the contract.
     */
    event Tagline(string tagline);

    /**
     * @notice Emitted when the target supply is queued to become `targetSupply` at the start of epoch `targetEpoch`.
     * @param  targetEpoch  The epoch number as a clock value in which the new target supply takes effect.
     * @param  targetSupply The target supply taking effect at `startingEpoch`.
     */
    event TargetSupplyInflated(uint16 indexed targetEpoch, uint240 indexed targetSupply);

    /* ============ Custom Errors ============ */

    /// @notice Revert message when the total supply of the bootstrap token is larger than `type(uint240).max`.
    error BootstrapSupplyTooLarge();

    /// @notice Revert message when the total supply of the bootstrap token is 0.
    error BootstrapSupplyZero();

    /**
     * @notice Revert message when the amount available for auction is less than the minimum requested to buy.
     * @param  amountToAuction    The amount available for auction.
     * @param  minAmountRequested The minimum amount that was requested to buy.
     */
    error InsufficientAuctionSupply(uint240 amountToAuction, uint240 minAmountRequested);

    /// @notice Revert message when the Bootstrap Token specified in the constructor is address(0).
    error InvalidBootstrapTokenAddress();

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

    /// @notice Revert message when auction calculations use zero as denominator.
    error DivisionByZero();

    /// @notice Revert message when the buy order has expired using epoch-based expiration clock.
    error ExpiredBuyOrder();

    /// @notice Revert message when the buy order has zero maximum and minimum amounts.
    error ZeroPurchaseAmount();

    /**
     * @notice Revert message when trying to sync to an epoch that is before the bootstrap epoch.
     * @param  bootstrapEpoch The bootstrap epoch.
     * @param  epoch          The epoch attempting to be synced to, not inclusively.
     */
    error SyncBeforeBootstrap(uint16 bootstrapEpoch, uint16 epoch);

    /* ============ Interactive Functions ============ */

    /**
     * @notice Allows a caller to buy `amount` tokens from the auction.
     * @param  minAmount   The minimum amount of tokens the caller is interested in buying.
     * @param  maxAmount   The maximum amount of tokens the caller is interested in buying.
     * @param  destination The address of the account to send the bought tokens.
     * @param  expiryEpoch The epoch number at the end of which the buy order expires.
     * @return amount      The amount of token bought.
     * @return cost        The total cash token cost of the purchase.
     */
    function buy(
        uint256 minAmount,
        uint256 maxAmount,
        address destination,
        uint16 expiryEpoch
    ) external returns (uint240 amount, uint256 cost);

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

    /* ============ View/Pure Functions ============ */

    /// @notice Returns the amount of tokens that can be bought in the auction.
    function amountToAuction() external view returns (uint240);

    /// @notice Returns the epoch from which token balances and voting powers are bootstrapped.
    function bootstrapEpoch() external view returns (uint16);

    /// @notice Returns the address of the token in which token balances and voting powers are bootstrapped.
    function bootstrapToken() external view returns (address);

    /// @notice Returns the address of the cash token required to buy from the token auction.
    function cashToken() external view returns (address);

    /**
     * @notice Returns the total cost, in cash token, of purchasing `amount` tokens from the auction.
     * @param  amount Some amount of tokens.
     * @return The total cost, in cash token, of `amount` tokens.
     */
    function getCost(uint256 amount) external view returns (uint256);

    /// @notice Returns the address of the Standard Governor.
    function standardGovernor() external view returns (address);

    /// @notice Returns the target supply, which helps determine the amount of tokens up for auction.
    function targetSupply() external view returns (uint256);

    /// @notice Returns the address of the Vault.
    function vault() external view returns (address);

    /// @notice Returns the initial supply of the token.
    function INITIAL_SUPPLY() external pure returns (uint240);
}
