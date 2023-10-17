// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.20;

import { ERC20Permit } from "../../src/ERC20Permit.sol";
import { ERC712 } from "../../src/ERC712.sol";

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
    address public zeroToken;

    function setZeroToken(address zeroToken_) external {
        zeroToken = zeroToken_;
    }

    function cashToken() external view returns (address cashToken_) {}

    function maxProposalFee() external view returns (uint256 maxProposalFee_) {}

    function minProposalFee() external view returns (uint256 minProposalFee_) {}

    function powerTokenQuorumRatio() external view returns (uint256 powerTokenQuorumRatio_) {}

    function proposalFee() external view returns (uint256 proposalFee_) {}

    function reward() external view returns (uint256 reward_) {}

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

contract MockERC20Permit is ERC20Permit {
    uint256 public totalSupply;

    mapping(address account => uint256 balance) public balanceOf;

    constructor(
        string memory symbol_,
        string memory name_,
        uint8 decimals_
    ) ERC20Permit(symbol_, decimals_) ERC712(name_) {}

    function mint(address recipient_, uint256 amount_) external {
        balanceOf[recipient_] += amount_;
        totalSupply += amount_;

        emit Transfer(address(0), recipient_, amount_);
    }

    function _transfer(address sender_, address recipient_, uint256 amount_) internal override {
        balanceOf[sender_] -= amount_;
        balanceOf[recipient_] += amount_;

        emit Transfer(sender_, recipient_, amount_);
    }
}
