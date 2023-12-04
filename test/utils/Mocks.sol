// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.23;

contract MockBootstrapToken {
    uint256 internal _totalSupply;

    mapping(address account => uint256 balance) internal _balances;

    function setBalance(address account_, uint256 balance_) external {
        _balances[account_] = balance_;
    }

    function setTotalSupply(uint256 totalSupply_) external {
        _totalSupply = totalSupply_;
    }

    function pastBalanceOf(address account_, uint256) external view returns (uint256 balance_) {
        return _balances[account_];
    }

    function pastTotalSupply(uint256) external view returns (uint256 totalSupply_) {
        return _totalSupply;
    }
}

contract MockCashToken {
    bool internal _transferFromFail;

    function setTransferFromFail(bool transferFromFail_) external {
        _transferFromFail = transferFromFail_;
    }

    function transferFrom(address, address, uint256) external view returns (bool success_) {
        return !_transferFromFail;
    }
}

contract MockEmergencyGovernor {
    uint16 public thresholdRatio;

    function setThresholdRatio(uint16 thresholdRatio_) external {
        thresholdRatio = thresholdRatio_;
    }
}

contract MockEmergencyGovernorDeployer {
    address public lastDeploy;
    address public nextDeploy;

    function setLastDeploy(address lastDeploy_) external {
        lastDeploy = lastDeploy_;
    }

    function setNextDeploy(address nextDeploy_) external {
        nextDeploy = nextDeploy_;
    }

    function deploy(address, address, uint16) external view returns (address deployed_) {
        return nextDeploy;
    }
}

contract MockEpochBasedVoteToken {
    mapping(address account => mapping(uint256 epoch => uint256 balance)) public pastBalanceOf;

    mapping(uint256 epoch => uint256 totalSupply) public pastTotalSupply;

    function setPastBalanceOf(address account_, uint256 epoch_, uint256 balance_) external {
        pastBalanceOf[account_][epoch_] = balance_;
    }

    function setPastTotalSupply(uint256 epoch_, uint256 totalSupplyAt_) external {
        pastTotalSupply[epoch_] = totalSupplyAt_;
    }

    function pastBalancesOf(
        address account_,
        uint256 startEpoch_,
        uint256 endEpoch_
    ) external view returns (uint256[] memory balances_) {
        balances_ = new uint256[](endEpoch_ - startEpoch_ + 1);

        for (uint256 index_; index_ < endEpoch_ - startEpoch_ + 1; ++index_) {
            balances_[index_] = pastBalanceOf[account_][startEpoch_ + index_];
        }
    }

    function pastTotalSupplies(
        uint256 startEpoch_,
        uint256 endEpoch_
    ) public view virtual returns (uint256[] memory totalSupplies_) {
        totalSupplies_ = new uint256[](endEpoch_ - startEpoch_ + 1);

        for (uint256 index_; index_ < endEpoch_ - startEpoch_ + 1; ++index_) {
            totalSupplies_[index_] = pastTotalSupply[startEpoch_ + index_];
        }
    }
}

contract MockERC20 {
    mapping(address account => uint256 balance) public balanceOf;

    function setBalance(address account_, uint256 balance_) external {
        balanceOf[account_] = balance_;
    }

    function transfer(address, uint256) external pure returns (bool success_) {
        return true;
    }

    function transferFrom(address, address, uint256) external pure returns (bool success_) {
        return true;
    }
}

contract MockPowerToken {
    uint256 internal _votePower;
    uint256 internal _totalSupplyAt;

    function setVotePower(uint256 votePower_) external {
        _votePower = votePower_;
    }

    function setPastTotalSupply(uint256 totalSupplyAt_) external {
        _totalSupplyAt = totalSupplyAt_;
    }

    function getPastVotes(address, uint256) external view returns (uint256 votePower_) {
        return _votePower;
    }

    function markNextVotingEpochAsActive() external {}

    function markParticipation(address delegatee_) external {}

    function setNextCashToken(address newCashToken_) external {}

    function pastTotalSupply(uint256) external view returns (uint256 totalSupply_) {
        return _totalSupplyAt;
    }
}

contract MockPowerTokenDeployer {
    address public lastDeploy;
    address public nextDeploy;

    function setLastDeploy(address lastDeploy_) external {
        lastDeploy = lastDeploy_;
    }

    function setNextDeploy(address nextDeploy_) external {
        nextDeploy = nextDeploy_;
    }

    function deploy(address, address, address) external view returns (address deployed_) {
        return nextDeploy;
    }
}

contract MockRegistrar {
    function addToList(bytes32 list_, address account_) external {}

    function removeFromList(bytes32 list_, address account_) external {}
}

contract MockStandardGovernor {
    address public cashToken;
    address public voteToken;

    uint256 public proposalFee;

    function setCashToken(address cashToken_) external {
        cashToken = cashToken_;
    }

    function setCashToken(address, uint256) external {}

    function setVoteToken(address voteToken_) external {
        voteToken = voteToken_;
    }

    function setProposalFee(uint256 proposalFee_) external {
        proposalFee = proposalFee_;
    }
}

contract MockStandardGovernorDeployer {
    address public lastDeploy;
    address public nextDeploy;
    address public vault;
    address public zeroGovernor;
    address public zeroToken;

    function setLastDeploy(address lastDeploy_) external {
        lastDeploy = lastDeploy_;
    }

    function setNextDeploy(address nextDeploy_) external {
        nextDeploy = nextDeploy_;
    }

    function setVault(address vault_) external {
        vault = vault_;
    }

    function setZeroGovernor(address zeroGovernor_) external {
        zeroGovernor = zeroGovernor_;
    }

    function setZeroToken(address zeroToken_) external {
        zeroToken = zeroToken_;
    }

    function deploy(address, address, address, uint256, uint256) external view returns (address deployed_) {
        return nextDeploy;
    }
}

contract MockZeroToken {
    function mint(address account_, uint256 amount_) external {}
}

contract MockZeroGovernor {
    address public emergencyGovernorDeployer;
    address public powerTokenDeployer;
    address public standardGovernorDeployer;
    address public voteToken;

    function setEmergencyGovernorDeployer(address emergencyGovernorDeployer_) external {
        emergencyGovernorDeployer = emergencyGovernorDeployer_;
    }

    function setPowerTokenDeployer(address powerTokenDeployer_) external {
        powerTokenDeployer = powerTokenDeployer_;
    }

    function setStandardGovernorDeployer(address standardGovernorDeployer_) external {
        standardGovernorDeployer = standardGovernorDeployer_;
    }

    function setVoteToken(address voteToken_) external {
        voteToken = voteToken_;
    }
}
