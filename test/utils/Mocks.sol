// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.19;

contract MockEpochBasedVoteToken {
    mapping(uint256 epoch => uint256 totalSupply) internal _totalSupplyAt;

    function setTotalSupplyAt(uint256 epoch_, uint256 totalSupplyAt_) external {
        _totalSupplyAt[epoch_] = totalSupplyAt_;
    }

    function totalSupplyAt(uint256 epoch_) external view returns (uint256 totalSupply_) {
        totalSupply_ = _totalSupplyAt[epoch_];
    }
}

contract MockPowerTokenDeployer {
    function deploy(address governor_, address cash_) external view returns (address deployed_) {}

    function getNextDeploy() external view returns (address nextDeploy_) {}
}

contract MockDualGovernorDeployer {
    address internal _nextDeploy;

    function setNextDeploy(address nextDeploy_) external {
        _nextDeploy = nextDeploy_;
    }

    function deploy(
        address cash_,
        address powerToken_,
        uint256 proposalFee_,
        uint256 minProposalFee_,
        uint256 maxProposalFee_,
        uint256 reward_,
        uint16 zeroTokenQuorumRatio_,
        uint16 powerTokenQuorumRatio_
    ) external view returns (address deployed_) {
        deployed_ = _nextDeploy;
    }
}

contract MockDualGovernor {
    function cash() external view returns (address cash_) {}

    function maxProposalFee() external view returns (uint256 maxProposalFee_) {}

    function minProposalFee() external view returns (uint256 minProposalFee_) {}

    function proposalFee() external view returns (uint256 proposalFee_) {}

    function reward() external view returns (uint256 reward_) {}

    function powerTokenQuorumRatio() external view returns (uint256 powerTokenQuorumRatio_) {}

    function zeroTokenQuorumRatio() external view returns (uint256 zeroTokenQuorumRatio_) {}
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
