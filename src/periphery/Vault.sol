// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.19;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";
import {ISPOGVotes} from "src/interfaces/tokens/ISPOGVotes.sol";
import {IVault} from "src/interfaces/IVault.sol";

import {IERC20PricelessAuction} from "src/interfaces/IERC20PricelessAuction.sol";
import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

/// @title Vault
/// @notice contract that will hold the SPOG assets. It has rules for transferring ERC20 tokens out of the smart contract.
contract Vault is IVault {
    using SafeERC20 for IERC20;

    ISPOGGovernor public voteGovernor;
    ISPOGGovernor public immutable valueGovernor;
    IERC20PricelessAuction public immutable auctionContract;

    // address => epoch => token => bool
    mapping(address => mapping(uint256 => mapping(address => bool))) public hasClaimedTokenRewardsForEpoch;

    // token address => epoch => amount
    mapping(address => mapping(uint256 => uint256)) public epochTokenDeposit;
    mapping(address => mapping(uint256 => uint256)) public epochTokenTotalWithdrawn;

    constructor(ISPOGGovernor _voteGovernor, ISPOGGovernor _valueGovernor, IERC20PricelessAuction _auctionContract) {
        voteGovernor = _voteGovernor;
        valueGovernor = _valueGovernor;
        auctionContract = _auctionContract;
    }

    modifier onlySPOG() {
        require(msg.sender == address(voteGovernor.spogAddress()), "Vault: Only spog");

        _;
    }

    /// @notice Deposit voting (vote and value) reward tokens for epoch
    /// @param epoch Epoch to deposit tokens for
    /// @param token Token to deposit
    /// @param amount Amount of vote tokens to deposit
    function depositEpochRewardTokens(uint256 epoch, address token, uint256 amount) external onlySPOG {
        epochTokenDeposit[token][epoch] += amount;
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

        emit EpochRewardsDeposit(epoch, token, amount);
    }

    /// @notice Sell unclaimed vote tokens
    /// @param epoch Epoch to view unclaimed tokens
    function unclaimedVoteTokensForEpoch(uint256 epoch) public view returns (uint256) {
        address token = address(voteGovernor.votingToken());
        return epochTokenDeposit[token][epoch] - epochTokenTotalWithdrawn[token][epoch];
    }

    /// @notice Sell unclaimed vote tokens
    /// @param epoch Epoch to sell tokens from
    /// @param paymentToken Token to accept for payment
    /// @param duration The duration of the auction
    function sellUnclaimedVoteTokens(uint256 epoch, address paymentToken, uint256 duration) external onlySPOG {
        uint256 currentEpoch = voteGovernor.currentEpoch();
        require(epoch < currentEpoch, "Vault: epoch is not in the past");

        address token = address(voteGovernor.votingToken());
        address auction = Clones.cloneDeterministic(address(auctionContract), bytes32(epoch));

        uint256 unclaimed = unclaimedVoteTokensForEpoch(epoch);
        IERC20(token).approve(auction, unclaimed);

        IERC20PricelessAuction(auction).initialize(token, paymentToken, duration, address(this), unclaimed);

        emit VoteTokenAuction(token, epoch, auction, unclaimed);
    }

    /// @dev Withdraw Vote Token Rewards
    function withdrawVoteTokenRewards() external {
        address token = address(voteGovernor.votingToken());
        uint256 currentEpoch = voteGovernor.currentEpoch();
        uint256 epochRewards = epochTokenDeposit[token][currentEpoch];
        uint256 totalVotingTokenSupplyApplicable = voteGovernor.votingToken().totalSupply() - epochRewards;
        _withdrawTokenRewards(token, currentEpoch, totalVotingTokenSupplyApplicable);
    }

    /// @dev Withdraw Value Token Rewards
    function withdrawValueTokenRewards() external {
        address token = address(valueGovernor.votingToken());
        uint256 previousEpoch = voteGovernor.currentEpoch() - 1;
        uint256 totalVotingTokenSupplyApplicable = voteGovernor.epochSumOfVoteWeight(previousEpoch);
        _withdrawTokenRewards(token, previousEpoch, totalVotingTokenSupplyApplicable);
    }

    /// @dev Withdraw rewards for multiple epochs for a token
    /// @param epochs Epochs to withdraw rewards for
    /// @param token Token to withdraw rewards for
    function withdrawRewardsForValueHolders(uint256[] memory epochs, address token) external {
        uint256 length = epochs.length;
        for (uint256 i; i < length;) {
            withdrawRewardsForValueHolders(epochs[i], token);

            unchecked {
                ++i;
            }
        }
    }

    /// @dev Withdraw rewards for a single epoch for a token
    /// @param epoch Epoch to withdraw rewards for
    /// @param token Token to withdraw rewards for
    function withdrawRewardsForValueHolders(uint256 epoch, address token) public {
        require(epoch < valueGovernor.currentEpoch(), "Vault: epoch is not in the past");
        require(epochTokenDeposit[token][epoch] > 0, "Vault: no rewards to withdraw");
        require(!hasClaimedTokenRewardsForEpoch[msg.sender][epoch][token], "Vault: rewards already withdrawn");

        hasClaimedTokenRewardsForEpoch[msg.sender][epoch][token] = true;

        uint256 amountToBeSharedOnProRataBasis = epochTokenDeposit[token][epoch];

        uint256 epochStartBlockNumber = valueGovernor.startOfEpoch(epoch);

        uint256 totalValueTokenSupplyApplicable =
            ISPOGVotes(valueGovernor.votingToken()).getPastTotalSupply(epochStartBlockNumber);

        uint256 accountBalanceAtEpochStart = valueGovernor.getVotes(msg.sender, epochStartBlockNumber);

        uint256 percentageOfTotalSupply = accountBalanceAtEpochStart * 100 / totalValueTokenSupplyApplicable;

        uint256 amountToWithdraw = percentageOfTotalSupply * amountToBeSharedOnProRataBasis / 100;

        IERC20(token).safeTransfer(msg.sender, amountToWithdraw);

        emit TokenRewardsWithdrawn(msg.sender, token, amountToWithdraw);
    }

    // @notice Update vote governor after `RESET` was executed
    // @param newVoteGovernor New vote governor
    function updateVoteGovernor(ISPOGGovernor newVoteGovernor) external onlySPOG {
        voteGovernor = newVoteGovernor;

        emit VoteGovernorUpdated(address(newVoteGovernor), address(newVoteGovernor.votingToken()));
    }

    function _withdrawTokenRewards(address token, uint256 epoch, uint256 totalVotingTokenSupplyApplicable) private {
        require(!hasClaimedTokenRewardsForEpoch[msg.sender][epoch][token], "Vault: rewards already withdrawn");
        hasClaimedTokenRewardsForEpoch[msg.sender][epoch][token] = true;

        // withdraw rewards only if voted on all proposals in epoch
        uint256 numOfProposalsVotedOnEpoch = voteGovernor.accountEpochNumProposalsVotedOn(msg.sender, epoch);
        uint256 totalProposalsEpoch = voteGovernor.epochProposalsCount(epoch);
        require(
            numOfProposalsVotedOnEpoch == totalProposalsEpoch,
            "Vault: unable to withdraw due to not voting on all proposals"
        );

        // get inflation amount user is eligible to withdraw for the epoch
        uint256 accountVotesWeight = voteGovernor.getVotes(msg.sender, voteGovernor.startOfEpoch(epoch));
        uint256 amountToBeSharedOnProRataBasis = epochTokenDeposit[token][epoch];
        // uint256 totalVotingTokenSupplyApplicable =
        //     voteGovernor.votingToken().totalSupply() - amountToBeSharedOnProRataBasis;
        uint256 percentageOfTotalSupply = accountVotesWeight * 100 / totalVotingTokenSupplyApplicable;
        uint256 amountToWithdraw = percentageOfTotalSupply * amountToBeSharedOnProRataBasis / 100;

        // withdraw rewards
        epochTokenTotalWithdrawn[token][epoch] += amountToWithdraw;
        IERC20(token).safeTransfer(msg.sender, amountToWithdraw);

        emit TokenRewardsWithdrawn(msg.sender, token, amountToWithdraw);
    }

    fallback() external {
        revert("Vault: non-existent function");
    }
}
