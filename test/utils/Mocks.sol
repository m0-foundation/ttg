// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

contract MockEpochBasedVoteToken {
    mapping(address account => mapping(uint256 epoch => uint256 balance)) internal _balances;

    mapping(uint256 epoch => uint256 totalSupply) internal _totalSupplyAt;

    function setBalanceAt(address account_, uint256 epoch_, uint256 balance_) external {
        _balances[account_][epoch_] = balance_;
    }

    function setTotalSupplyAt(uint256 epoch_, uint256 totalSupplyAt_) external {
        _totalSupplyAt[epoch_] = totalSupplyAt_;
    }

    function balancesOfAt(
        address account_,
        uint256[] calldata epochs_
    ) external view returns (uint256[] memory balances_) {
        balances_ = new uint256[](epochs_.length);

        for (uint256 index_; index_ < epochs_.length; ++index_) {
            balances_[index_] = _balances[account_][epochs_[index_]];
        }
    }

    function totalSupplyAt(uint256 epoch_) external view returns (uint256 totalSupply_) {
        totalSupply_ = _totalSupplyAt[epoch_];
    }

    function totalSuppliesAt(uint256[] calldata epochs_) external view returns (uint256[] memory totalSupplies_) {
        totalSupplies_ = new uint256[](epochs_.length);

        for (uint256 index_; index_ < epochs_.length; ++index_) {
            totalSupplies_[index_] = _totalSupplyAt[epochs_[index_]];
        }
    }
}

contract MockPowerTokenDeployer {
    function deploy(
        address governor_,
        address cashToken_,
        address bootstrapToken_
    ) external view returns (address deployed_) {}

    function getNextDeploy() external view returns (address nextDeploy_) {}
}

contract MockDualGovernorDeployer {
    address internal _nextDeploy;

    function setNextDeploy(address nextDeploy_) external {
        _nextDeploy = nextDeploy_;
    }

    function deploy(
        address cashToken_,
        address powerToken_,
        uint256 proposalFee_,
        uint256 maxTotalZeroRewardPerActiveEpoch_,
        uint16 powerTokenThresholdRatio_,
        uint16 zeroTokenThresholdRatio_
    ) external view returns (address deployed_) {
        deployed_ = _nextDeploy;
    }
}

contract MockDualGovernor {
    address public zeroToken;

    function setZeroToken(address zeroToken_) external {
        zeroToken = zeroToken_;
    }

    function cashToken() external view returns (address cashToken_) {}

    function powerTokenThresholdRatio() external view returns (uint256 thresholdRatio_) {}

    function proposalFee() external view returns (uint256 proposalFee_) {}

    function maxTotalZeroRewardPerActiveEpoch() external view returns (uint256 reward_) {}

    function vault() external view returns (address vault_) {}

    function zeroTokenThresholdRatio() external view returns (uint256 thresholdRatio_) {}
}

contract MockBootstrapToken {
    uint256 internal _totalSupply;

    mapping(address account => uint256 balance) internal _balances;

    function setBalance(address account_, uint256 balance_) external {
        _balances[account_] = balance_;
    }

    function setTotalSupply(uint256 totalSupply_) external {
        _totalSupply = totalSupply_;
    }

    function balanceOfAt(address account_, uint256 epoch_) external view returns (uint256 balance_) {
        balance_ = _balances[account_];
    }

    function totalSupplyAt(uint256 epoch_) external view returns (uint256 totalSupply_) {
        totalSupply_ = _totalSupply;
    }
}

contract MockCashToken {
    bool internal _transferFromSuccess;

    function setTransferFromSuccess(bool transferFromSuccess_) external {
        _transferFromSuccess = transferFromSuccess_;
    }

    function transferFrom(address sender_, address recipient_, uint256 amount_) external returns (bool success_) {
        success_ = _transferFromSuccess;
    }
}

contract MockPowerToken {
    uint256 internal _votePower;
    uint256 internal _totalSupplyAt;

    function setVotePower(uint256 votePower_) external {
        _votePower = votePower_;
    }

    function setTotalSupplyAt(uint256 totalSupplyAt_) external {
        _totalSupplyAt = totalSupplyAt_;
    }

    function getPastVotes(address account_, uint256 timepoint_) external view returns (uint256 votePower_) {
        votePower_ = _votePower;
    }

    function markParticipation(address delegatee_) external {}

    function totalSupplyAt(uint256 epoch_) external view returns (uint256 totalSupply_) {
        totalSupply_ = _totalSupplyAt;
    }
}

contract MockZeroToken {
    function mint(address account_, uint256 amount_) external {}
}

contract MockERC20 {
    mapping(address account => uint256 balance) internal _balances;

    function setBalance(address account_, uint256 balance_) external {
        _balances[account_] = balance_;
    }

    function balanceOf(address account_) external view returns (uint256 balance_) {
        balance_ = _balances[account_];
    }

    function transfer(address recipient_, uint256 amount_) external returns (bool success_) {
        success_ = true;
    }
}
