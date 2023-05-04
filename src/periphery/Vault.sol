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

    /// @dev Claim Vote token inflation rewards by vote holders
    function claimVoteTokenRewards() external {
        address votingToken = address(voteGovernor.votingToken());
        uint256 currentEpoch = voteGovernor.currentEpoch();

        _checkParticipation(currentEpoch);

        // vote holders claim their epoch vote rewards
        _withdrawTokenRewards(currentEpoch, votingToken, votingToken);
    }

    /// @dev Claim Value token inflation rewards by vote holders
    function claimValueTokenRewards() external {
        address rewardToken = address(valueGovernor.votingToken());
        uint256 previousEpoch = voteGovernor.currentEpoch() - 1;

        _checkParticipation(previousEpoch);

        // vote holders claim their epoch value rewards
        _withdrawTokenRewards(previousEpoch, address(voteGovernor.votingToken()), rewardToken);
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

        _withdrawTokenRewards(epoch, address(valueGovernor.votingToken()), token);
    }

    // @notice Update vote governor after `RESET` was executed
    // @param newVoteGovernor New vote governor
    function updateVoteGovernor(ISPOGGovernor newVoteGovernor) external onlySPOG {
        voteGovernor = newVoteGovernor;

        emit VoteGovernorUpdated(address(newVoteGovernor), address(newVoteGovernor.votingToken()));
    }

    function _getTotalSupplyForBasicProRata(uint256 epoch, address votingToken) private view returns (uint256) {
        uint256 inflation = epochTokenDeposit[votingToken][epoch];
        // vote and value epochs are in sync
        uint256 epochStart = voteGovernor.startOfEpoch(epoch);
        return ISPOGVotes(votingToken).getPastTotalSupply(epochStart) - inflation;
    }

    function _getTotalSupplyForOnlyActiveProRata(uint256 epoch) private view returns (uint256) {
        return voteGovernor.epochSumOfVoteWeight(epoch);
    }

    // TODO potentially modifier ?
    function _checkParticipation(uint256 epoch) private view {
        // withdraw rewards only if voted on all proposals in epoch
        uint256 numOfProposalsVotedOnEpoch = voteGovernor.accountEpochNumProposalsVotedOn(msg.sender, epoch);
        uint256 totalProposalsEpoch = voteGovernor.epochProposalsCount(epoch);
        require(
            numOfProposalsVotedOnEpoch == totalProposalsEpoch,
            "Vault: unable to withdraw due to not voting on all proposals"
        );
    }

    /// @dev Withdraw Vote and Value token rewards
    function _withdrawTokenRewards(uint256 epoch, address votingToken, address rewardToken) private {
        require(epochTokenDeposit[rewardToken][epoch] > 0, "Vault: no rewards to withdraw");
        require(!hasClaimedTokenRewardsForEpoch[msg.sender][epoch][rewardToken], "Vault: rewards already withdrawn");
        hasClaimedTokenRewardsForEpoch[msg.sender][epoch][rewardToken] = true;

        uint256 votingTokenTotalApplicableSupply;
        // if vote holders claim value inflation, use special case - total supply calculations for only active participants
        // otherwise use standard total supply calculations
        if (votingToken == address(voteGovernor.votingToken()) && rewardToken == address(valueGovernor.votingToken())) {
            votingTokenTotalApplicableSupply = _getTotalSupplyForOnlyActiveProRata(epoch);
        } else {
            votingTokenTotalApplicableSupply = _getTotalSupplyForBasicProRata(epoch, votingToken);
        }

        // get reward amount user is eligible to withdraw for the epoch
        uint256 epochStartBlockNumber = voteGovernor.startOfEpoch(epoch);
        uint256 accountVotesWeight = ISPOGVotes(votingToken).getPastVotes(msg.sender, epochStartBlockNumber);
        uint256 amountToBeSharedOnProRataBasis = epochTokenDeposit[rewardToken][epoch];
        uint256 percentageOfTotalSupply = accountVotesWeight * 100 / votingTokenTotalApplicableSupply;
        uint256 amountToWithdraw = percentageOfTotalSupply * amountToBeSharedOnProRataBasis / 100;

        // withdraw rewards
        epochTokenTotalWithdrawn[rewardToken][epoch] += amountToWithdraw;
        IERC20(rewardToken).safeTransfer(msg.sender, amountToWithdraw);

        emit TokenRewardsWithdrawn(msg.sender, rewardToken, amountToWithdraw);
    }

    fallback() external {
        revert("Vault: non-existent function");
    }
}
