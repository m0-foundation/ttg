// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.21;

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
        return _balances[account_];
    }

    function totalSupplyAt(uint256 epoch_) external view returns (uint256 totalSupply_) {
        return _totalSupply;
    }
}

contract MockCashToken {
    bool internal _transferFromSuccess;

    function setTransferFromSuccess(bool transferFromSuccess_) external {
        _transferFromSuccess = transferFromSuccess_;
    }

    function transferFrom(address sender_, address recipient_, uint256 amount_) external returns (bool success_) {
        return _transferFromSuccess;
    }
}

contract MockEmergencyGovernor {
    uint16 internal _thresholdRatio;

    function setThresholdRatio(uint16 thresholdRatio_) external {
        _thresholdRatio = thresholdRatio_;
    }

    function thresholdRatio() external view returns (uint16 thresholdRatio_) {
        return _thresholdRatio;
    }
}

contract MockEmergencyGovernorDeployer {
    address internal _nextDeploy;

    function setNextDeploy(address nextDeploy_) external {
        _nextDeploy = nextDeploy_;
    }

    function deploy(
        address voteToken_,
        address standardGovernor_,
        uint16 thresholdRatio_
    ) external returns (address deployed_) {
        return _nextDeploy;
    }

    function getNextDeploy() external view returns (address nextDeploy_) {
        return _nextDeploy;
    }
}

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
        return _totalSupplyAt[epoch_];
    }

    function totalSuppliesAt(uint256[] calldata epochs_) external view returns (uint256[] memory totalSupplies_) {
        totalSupplies_ = new uint256[](epochs_.length);

        for (uint256 index_; index_ < epochs_.length; ++index_) {
            totalSupplies_[index_] = _totalSupplyAt[epochs_[index_]];
        }
    }
}

contract MockERC20 {
    mapping(address account => uint256 balance) internal _balances;

    function setBalance(address account_, uint256 balance_) external {
        _balances[account_] = balance_;
    }

    function balanceOf(address account_) external view returns (uint256 balance_) {
        return _balances[account_];
    }

    function transfer(address recipient_, uint256 amount_) external returns (bool success_) {
        return true;
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
        return _votePower;
    }

    function markParticipation(address delegatee_) external {}

    function setNextCashToken(address newCashToken_) external {}

    function totalSupplyAt(uint256 epoch_) external view returns (uint256 totalSupply_) {
        return _totalSupplyAt;
    }
}

contract MockPowerTokenDeployer {
    address internal _nextDeploy;

    function setNextDeploy(address nextDeploy_) external {
        _nextDeploy = nextDeploy_;
    }

    function deploy(
        address governor_,
        address cashToken_,
        address bootstrapToken_
    ) external view returns (address deployed_) {
        return _nextDeploy;
    }

    function getNextDeploy() external view returns (address nextDeploy_) {
        return _nextDeploy;
    }
}

contract MockRegistrar {
    function addToList(bytes32 list_, address account_) external {}

    function removeFromList(bytes32 list_, address account_) external {}
}

contract MockStandardGovernor {
    address internal _cashToken;

    uint256 internal _proposalFee;

    function setCashToken(address cashToken_) external {
        _cashToken = cashToken_;
    }

    function setProposalFee(uint256 proposalFee_) external {
        _proposalFee = proposalFee_;
    }

    function cashToken() external view returns (address cashToken_) {
        return _cashToken;
    }

    function proposalFee() external view returns (uint256 proposalFee_) {
        return _proposalFee;
    }
}

contract MockStandardGovernorDeployer {
    address internal _nextDeploy;
    address internal _vault;
    address internal _zeroGovernor;
    address internal _zeroToken;

    function setNextDeploy(address nextDeploy_) external {
        _nextDeploy = nextDeploy_;
    }

    function setVault(address vault_) external {
        _vault = vault_;
    }

    function setZeroGovernor(address zeroGovernor_) external {
        _zeroGovernor = zeroGovernor_;
    }

    function setZeroToken(address zeroToken_) external {
        _zeroToken = zeroToken_;
    }

    function deploy(
        address voteToken_,
        address emergencyGovernor_,
        address cashToken_,
        uint256 proposalFee_,
        uint256 maxTotalZeroRewardPerActiveEpoch_
    ) external returns (address deployed_) {
        return _nextDeploy;
    }

    function getNextDeploy() external view returns (address nextDeploy_) {
        return _nextDeploy;
    }

    function vault() external view returns (address vault_) {
        return _vault;
    }

    function zeroGovernor() external view returns (address zeroGovernor_) {
        return _zeroGovernor;
    }

    function zeroToken() external view returns (address zeroToken_) {
        return _zeroToken;
    }
}

contract MockZeroToken {
    function mint(address account_, uint256 amount_) external {}
}

contract MockZeroGovernor {
    address internal _startingCashToken;

    function setStartingCashToken(address startingCashToken_) external {
        _startingCashToken = startingCashToken_;
    }

    function startingCashToken() external view returns (address startingCashToken_) {
        return _startingCashToken;
    }
}
