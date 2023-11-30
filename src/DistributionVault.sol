// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IERC20 } from "../lib/common/src/interfaces/IERC20.sol";

import { ERC20Helper } from "../lib/erc20-helper/src/ERC20Helper.sol";

import { PureEpochs } from "./libs/PureEpochs.sol";

import { IEpochBasedVoteToken } from "./abstract/interfaces/IEpochBasedVoteToken.sol";

import { IDistributionVault } from "./interfaces/IDistributionVault.sol";

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

    function claim(
        address token_,
        uint256 startEpoch_,
        uint256 endEpoch_,
        address destination_
    ) external returns (uint256 claimed_) {
        claimed_ = getClaimable(token_, msg.sender, startEpoch_, endEpoch_);

        for (uint256 epoch_ = startEpoch_; epoch_ <= endEpoch_; ++epoch_) {
            _claims[token_][epoch_][msg.sender] = true;
        }

        // TODO: Consider replacing with a balance check and optional `distribute`.
        _lastTokenBalances[token_] -= claimed_;

        emit Claim(token_, msg.sender, startEpoch_, endEpoch_, claimed_);

        if (!ERC20Helper.transfer(token_, destination_, claimed_)) revert TransferFailed();
    }

    function getClaimable(
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

        return (_distributions[token_][epoch_] * balance_) / totalSupply_;
    }
}
