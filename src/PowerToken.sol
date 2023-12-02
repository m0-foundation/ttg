// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";

import { ERC20Helper } from "../lib/erc20-helper/src/ERC20Helper.sol";

import { PureEpochs } from "./libs/PureEpochs.sol";

import { IERC5805 } from "./abstract/interfaces/IERC5805.sol";
import { IEpochBasedVoteToken } from "./abstract/interfaces/IEpochBasedVoteToken.sol";

import { EpochBasedInflationaryVoteToken } from "./abstract/EpochBasedInflationaryVoteToken.sol";
import { EpochBasedVoteToken } from "./abstract/EpochBasedVoteToken.sol";

import { IPowerToken } from "./interfaces/IPowerToken.sol";

contract PowerToken is IPowerToken, EpochBasedInflationaryVoteToken {
    uint256 internal constant _AUCTION_PERIODS = 100;

    uint256 public constant INITIAL_SUPPLY = 1_000_000_000;

    address public immutable bootstrapToken;
    address public immutable standardGovernor;
    address public immutable vault;

    uint256 public immutable bootstrapEpoch;

    uint256 internal immutable _bootstrapSupply;

    uint256 internal _nextCashTokenStartingEpoch;

    address internal _cashToken;
    address internal _nextCashToken;

    uint256 internal _nextTargetSupplyStartingEpoch;

    uint256 internal _targetSupply;
    uint256 internal _nextTargetSupply = INITIAL_SUPPLY;

    modifier onlyStandardGovernor() {
        if (msg.sender != standardGovernor) revert NotStandardGovernor();

        _;
    }

    constructor(
        address bootstrapToken_,
        address standardGovernor_,
        address cashToken_,
        address vault_
    ) EpochBasedInflationaryVoteToken("Power Token", "POWER", 0, ONE / 10) {
        _bootstrapSupply = IEpochBasedVoteToken(bootstrapToken = bootstrapToken_).pastTotalSupply(
            bootstrapEpoch = (PureEpochs.currentEpoch() - 1)
        );

        _update(_totalSupplies, _add, INITIAL_SUPPLY);

        if ((standardGovernor = standardGovernor_) == address(0)) revert ZeroGovernorAddress();
        if ((_nextCashToken = cashToken_) == address(0)) revert InvalidCashTokenAddress();
        if ((vault = vault_) == address(0)) revert InvalidVaultAddress();
    }

    /******************************************************************************************************************\
    |                                      External/Public Interactive Functions                                       |
    \******************************************************************************************************************/

    function buy(uint256 amount_, address destination_) external {
        if (amount_ > amountToAuction()) revert InsufficientAuctionSupply();

        uint256 cost_ = getCost(amount_);

        emit Buy(msg.sender, amount_, cost_);

        // NOTE: Not calling `distribute` on vault since:
        //         - anyone can do it, anytime
        //         - `PowerToken` should not need to know how the vault works
        if (!ERC20Helper.transferFrom(cashToken(), msg.sender, vault, cost_)) revert TransferFromFailed();

        _mint(destination_, amount_);
    }

    function markNextVotingEpochAsActive() external onlyStandardGovernor {
        uint256 currentEpoch_ = PureEpochs.currentEpoch();

        // The next voting epoch is the targetEpoch.
        uint256 targetEpoch_ = currentEpoch_ + (_isVotingEpoch(currentEpoch_) ? 2 : 1);

        if (currentEpoch_ >= _nextTargetSupplyStartingEpoch) {
            _targetSupply = _nextTargetSupply;
            _nextTargetSupplyStartingEpoch = targetEpoch_;
        }

        uint256 nextTargetSupply_ = _nextTargetSupply = _targetSupply + (_targetSupply * participationInflation) / ONE;

        emit TargetSupplyInflated(targetEpoch_, nextTargetSupply_);
    }

    function markParticipation(address delegatee_) external onlyStandardGovernor {
        _markParticipation(delegatee_);
    }

    function setNextCashToken(address nextCashToken_) external onlyStandardGovernor {
        if (nextCashToken_ == address(0)) revert InvalidCashTokenAddress();

        uint256 currentEpoch_ = PureEpochs.currentEpoch();

        if (currentEpoch_ >= _nextCashTokenStartingEpoch) {
            _cashToken = _nextCashToken;
            _nextCashTokenStartingEpoch = currentEpoch_ + 1;
        }

        _nextCashToken = nextCashToken_;

        emit NextCashTokenSet(_nextCashTokenStartingEpoch, _nextCashToken);
    }

    /******************************************************************************************************************\
    |                                       External/Public View/Pure Functions                                        |
    \******************************************************************************************************************/

    function amountToAuction() public view returns (uint256 amountToAuction_) {
        if (_isVotingEpoch(PureEpochs.currentEpoch())) return 0;

        uint256 targetSupply_ = targetSupply();
        uint256 totalSupply_ = totalSupply();

        return targetSupply_ > totalSupply_ ? targetSupply_ - totalSupply_ : 0;
    }

    function balanceOf(
        address account_
    ) public view override(IERC20, EpochBasedInflationaryVoteToken) returns (uint256 balance_) {
        return
            (PureEpochs.currentEpoch() <= bootstrapEpoch) || (_balances[account_].length == 0)
                ? _bootstrapBalanceOfAt(account_, bootstrapEpoch)
                : super.balanceOf(account_);
    }

    function pastBalanceOf(
        address account_,
        uint256 epoch_
    ) public view override(IEpochBasedVoteToken, EpochBasedInflationaryVoteToken) returns (uint256 balance_) {
        return
            (epoch_ <= bootstrapEpoch) || (_balances[account_].length == 0)
                ? _bootstrapBalanceOfAt(account_, epoch_)
                : super.pastBalanceOf(account_, epoch_);
    }

    function cashToken() public view returns (address cashToken_) {
        return PureEpochs.currentEpoch() >= _nextCashTokenStartingEpoch ? _nextCashToken : _cashToken;
    }

    function getCost(uint256 amount_) public view returns (uint256 cost_) {
        uint256 currentEpoch_ = PureEpochs.currentEpoch();

        uint256 blocksRemaining_ = _isVotingEpoch(currentEpoch_)
            ? PureEpochs._EPOCH_PERIOD
            : PureEpochs.blocksRemainingInCurrentEpoch();

        uint256 blocksPerPeriod_ = PureEpochs._EPOCH_PERIOD / _AUCTION_PERIODS;
        uint256 leftPoint_ = 1 << (blocksRemaining_ / blocksPerPeriod_);
        uint256 remainder_ = blocksRemaining_ % blocksPerPeriod_;

        return
            (ONE * amount_ * ((remainder_ * leftPoint_) + ((blocksPerPeriod_ - remainder_) * (leftPoint_ >> 1)))) /
            (blocksPerPeriod_ * pastTotalSupply(currentEpoch_ - 1));
    }

    function getVotes(
        address account_
    ) public view override(IERC5805, EpochBasedVoteToken) returns (uint256 votingPower_) {
        return
            _votingPowers[account_].length == 0
                ? _bootstrapBalanceOfAt(account_, bootstrapEpoch)
                : super.getVotes(account_);
    }

    function getPastVotes(
        address account_,
        uint256 epoch_
    ) public view override(IERC5805, EpochBasedVoteToken) returns (uint256 votingPower_) {
        return
            _votingPowers[account_].length == 0
                ? _bootstrapBalanceOfAt(account_, epoch_)
                : super.getPastVotes(account_, epoch_);
    }

    function targetSupply() public view returns (uint256 targetSupply_) {
        return PureEpochs.currentEpoch() >= _nextTargetSupplyStartingEpoch ? _nextTargetSupply : _targetSupply;
    }

    function totalSupply() public view override(IERC20, EpochBasedVoteToken) returns (uint256 totalSupply_) {
        return PureEpochs.currentEpoch() <= bootstrapEpoch ? INITIAL_SUPPLY : super.totalSupply();
    }

    function pastTotalSupply(
        uint256 epoch_
    ) public view override(IEpochBasedVoteToken, EpochBasedVoteToken) returns (uint256 totalSupply_) {
        return epoch_ <= bootstrapEpoch ? INITIAL_SUPPLY : super.pastTotalSupply(epoch_);
    }

    /******************************************************************************************************************\
    |                                           Internal View/Pure Functions                                           |
    \******************************************************************************************************************/

    function _bootstrap(address account_) internal {
        if (_balances[account_].length != 0) return;

        uint256 bootstrapBalance_ = _bootstrapBalanceOfAt(account_, bootstrapEpoch);

        if (bootstrapBalance_ == 0) return;

        _updateBalance(account_, _add, bootstrapBalance_);
        _updateVotingPower(account_, _add, bootstrapBalance_);
    }

    function _bootstrapBalanceOfAt(address account_, uint256 epoch_) internal view returns (uint256 balance_) {
        return
            (IEpochBasedVoteToken(bootstrapToken).pastBalanceOf(account_, epoch_) * INITIAL_SUPPLY) / _bootstrapSupply;
    }

    function _delegate(address delegator_, address newDelegatee_) internal override {
        _bootstrap(delegator_);
        _bootstrap(newDelegatee_);
        super._delegate(delegator_, newDelegatee_);
    }

    function _markParticipation(address delegatee_) internal override {
        _bootstrap(delegatee_);
        super._markParticipation(delegatee_);
    }

    function _mint(address recipient_, uint256 amount_) internal override {
        _bootstrap(recipient_);
        super._mint(recipient_, amount_);
    }

    function _transfer(address sender_, address recipient_, uint256 amount_) internal override {
        _bootstrap(sender_);
        _bootstrap(recipient_);
        super._transfer(sender_, recipient_, amount_);
    }
}
