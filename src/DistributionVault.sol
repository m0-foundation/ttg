// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.20;

import { ERC20Helper } from "../lib/erc20-helper/src/ERC20Helper.sol";

import { IDistributionVault } from "./interfaces/IDistributionVault.sol";
import { IEpochBasedVoteToken } from "./interfaces/IEpochBasedVoteToken.sol";
import { IERC20 } from "./interfaces/IERC20.sol";

import { PureEpochs } from "./PureEpochs.sol";

contract DistributionVault is IDistributionVault {
    address public immutable baseToken;

    mapping(address token => uint256 balance) internal _lastTokenBalances;

    mapping(address token => mapping(uint256 epoch => uint256 amount)) internal _distributions;

    mapping(address token => mapping(uint256 epoch => mapping(address account => bool claimed))) internal _claims;

    constructor(address baseToken_) {
        baseToken = baseToken_;
    }

    function distribute(address token_) external {
        uint256 currentEpoch_ = PureEpochs.currentEpoch();

        uint256 lastTokenBalances_ = _lastTokenBalances[token_];

        uint256 amount_ = IERC20(token_).balanceOf(address(this)) - lastTokenBalances_;

        emit Distribution(token_, currentEpoch_, amount_);

        _distributions[token_][currentEpoch_] += amount_;

        _lastTokenBalances[token_] = lastTokenBalances_ + amount_;
    }

    function claim(address token_, uint256 epoch_, address destination_) external returns (uint256 claimed_) {
        claimed_ = claimableOfAt(token_, msg.sender, epoch_);

        _claims[token_][epoch_][msg.sender] = true;

        emit Claim(token_, msg.sender, epoch_, claimed_);

        // TODO: Consider replacing with a balance check and optional `distribute`.
        _lastTokenBalances[token_] -= claimed_;

        if (!ERC20Helper.transfer(token_, destination_, claimed_)) revert TransferFailed();
    }

    function claim(
        address token_,
        uint256[] calldata epochs_,
        address destination_
    ) external returns (uint256 claimed_) {
        claimed_ = claimableOfAt(token_, msg.sender, epochs_);

        for (uint256 index_; index_ < epochs_.length; ++index_) {
            uint256 epoch_ = epochs_[index_];

            _claims[token_][epoch_][msg.sender] = true;

            emit Claim(token_, msg.sender, epoch_, claimed_);
        }

        // TODO: Consider replacing with a balance check and optional `distribute`.
        _lastTokenBalances[token_] -= claimed_;

        if (!ERC20Helper.transfer(token_, destination_, claimed_)) revert TransferFailed();
    }

    function claim(
        address token_,
        uint256 startEpoch_,
        uint256 endEpoch_,
        address destination_
    ) external returns (uint256 claimed_) {
        claimed_ = claimableOfBetween(token_, msg.sender, startEpoch_, endEpoch_);

        for (uint256 epoch_ = startEpoch_; epoch_ <= endEpoch_; ++epoch_) {
            _claims[token_][epoch_][msg.sender] = true;

            emit Claim(token_, msg.sender, epoch_, claimed_);
        }

        // TODO: Consider replacing with a balance check and optional `distribute`.
        _lastTokenBalances[token_] -= claimed_;

        if (!ERC20Helper.transfer(token_, destination_, claimed_)) revert TransferFailed();
    }

    function claimableOfAt(address token_, address account_, uint256 epoch_) public view returns (uint256 claimable_) {
        claimable_ = _getClaimable(
            token_,
            account_,
            epoch_,
            IEpochBasedVoteToken(baseToken).balanceOfAt(account_, epoch_),
            IEpochBasedVoteToken(baseToken).totalSupplyAt(epoch_)
        );
    }

    function claimableOfAt(
        address token_,
        address account_,
        uint256[] calldata epochs_
    ) public view returns (uint256 claimable_) {
        uint256[] memory balances_ = IEpochBasedVoteToken(baseToken).balancesOfAt(account_, epochs_);
        uint256[] memory totalSupplies_ = IEpochBasedVoteToken(baseToken).totalSuppliesAt(epochs_);

        for (uint256 index_; index_ < epochs_.length; ++index_) {
            claimable_ += _getClaimable(token_, account_, epochs_[index_], balances_[index_], totalSupplies_[index_]);
        }
    }

    function claimableOfBetween(
        address token_,
        address account_,
        uint256 startEpoch_,
        uint256 endEpoch_
    ) public view returns (uint256 claimable_) {
        uint256[] memory balances_ = IEpochBasedVoteToken(baseToken).balancesOfBetween(
            account_,
            startEpoch_,
            endEpoch_
        );
        uint256[] memory totalSupplies_ = IEpochBasedVoteToken(baseToken).totalSuppliesBetween(startEpoch_, endEpoch_);

        uint256 epochCount_ = endEpoch_ - startEpoch_ + 1;

        for (uint256 index_; index_ < epochCount_; ++index_) {
            claimable_ += _getClaimable(
                token_,
                account_,
                startEpoch_ + index_,
                balances_[index_],
                totalSupplies_[index_]
            );
        }
    }

    function _getClaimable(
        address token_,
        address account_,
        uint256 epoch_,
        uint256 balance_,
        uint256 totalSupply_
    ) internal view returns (uint256 claimable_) {
        if (epoch_ >= PureEpochs.currentEpoch()) revert EpochTooHigh();

        if (_claims[token_][epoch_][account_]) return 0;

        claimable_ = _getClaimable(_distributions[token_][epoch_], balance_, totalSupply_);
    }

    function _getClaimable(
        uint256 totalDistribution_,
        uint256 balance_,
        uint256 totalSupply_
    ) internal pure returns (uint256 claimable_) {
        claimable_ = (totalDistribution_ * balance_) / totalSupply_;
    }
}
