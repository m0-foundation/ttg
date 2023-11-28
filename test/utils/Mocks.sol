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

    function balanceOfAt(address account_, uint256) external view returns (uint256 balance_) {
        return _balances[account_];
    }

    function totalSupplyAt(uint256) external view returns (uint256 totalSupply_) {
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
    address public nextDeploy;

    function setNextDeploy(address nextDeploy_) external {
        nextDeploy = nextDeploy_;
    }

    function deploy(address, address, uint16) external view returns (address deployed_) {
        return nextDeploy;
    }
}

contract MockEpochBasedVoteToken {
    mapping(address account => mapping(uint256 epoch => uint256 balance)) public balanceOfAt;

    mapping(uint256 epoch => uint256 totalSupply) public totalSupplyAt;

    function setBalanceOfAt(address account_, uint256 epoch_, uint256 balance_) external {
        balanceOfAt[account_][epoch_] = balance_;
    }

    function setTotalSupplyAt(uint256 epoch_, uint256 totalSupplyAt_) external {
        totalSupplyAt[epoch_] = totalSupplyAt_;
    }

    function balancesOfAt(
        address account_,
        uint256[] calldata epochs_
    ) external view returns (uint256[] memory balances_) {
        balances_ = new uint256[](epochs_.length);

        for (uint256 index_; index_ < epochs_.length; ++index_) {
            balances_[index_] = balanceOfAt[account_][epochs_[index_]];
        }
    }

    function totalSuppliesAt(uint256[] calldata epochs_) external view returns (uint256[] memory totalSupplies_) {
        totalSupplies_ = new uint256[](epochs_.length);

        for (uint256 index_; index_ < epochs_.length; ++index_) {
            totalSupplies_[index_] = totalSupplyAt[epochs_[index_]];
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

    function getPastVotes(address, uint256) external view returns (uint256 votePower_) {
        return _votePower;
    }

    function markNextVotingEpochAsActive() external {}

    function markParticipation(address delegatee_) external {}

    function setNextCashToken(address newCashToken_) external {}

    function totalSupplyAt(uint256) external view returns (uint256 totalSupply_) {
        return _totalSupplyAt;
    }
}

contract MockPowerTokenDeployer {
    address public nextDeploy;

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

    uint256 public proposalFee;

    function setCashToken(address cashToken_) external {
        cashToken = cashToken_;
    }

    function setProposalFee(uint256 proposalFee_) external {
        proposalFee = proposalFee_;
    }
}

contract MockStandardGovernorDeployer {
    address public nextDeploy;
    address public vault;
    address public zeroGovernor;
    address public zeroToken;

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
    address public startingCashToken;

    function setStartingCashToken(address startingCashToken_) external {
        startingCashToken = startingCashToken_;
    }
}
