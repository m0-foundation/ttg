// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IDualGovernor } from "./interfaces/IDualGovernor.sol";
import { IDualGovernorDeployer } from "./interfaces/IDualGovernorDeployer.sol";
import { IPowerTokenDeployer } from "./interfaces/IPowerTokenDeployer.sol";
import { IRegistrar } from "./interfaces/IRegistrar.sol";

contract Registrar is IRegistrar {
    uint256 internal constant _STARTING_PROPOSAL_FEE = 0.001e18;
    uint256 internal constant _STARTING_MAX_TOTAL_ZERO_REWARD_PER_ACTIVE_EPOCH = 1_000;

    uint256 internal constant _ONE = 10_000;

    uint16 internal constant _STARTING_POWER_TOKEN_THRESHOLD_RATIO = uint16(_ONE / 2);
    uint16 internal constant _STARTING_ZERO_TOKEN_THRESHOLD_RATIO = uint16(_ONE / 2);

    address public immutable governorDeployer;
    address public immutable powerTokenDeployer;
    address public immutable vault;
    address public immutable zeroToken;

    address public governor;
    address public powerToken;

    mapping(bytes32 key => bytes32 value) internal _valueAt;

    modifier onlyGovernor() {
        if (msg.sender != governor) revert CallerIsNotGovernor();

        _;
    }

    constructor(address governorDeployer_, address powerTokenDeployer_, address bootstrapToken_) {
        governorDeployer = governorDeployer_;
        powerTokenDeployer = powerTokenDeployer_;

        address powerToken_ = powerToken = IPowerTokenDeployer(powerTokenDeployer_).getNextDeploy();

        address governor_ = governor = IDualGovernorDeployer(governorDeployer_).deploy(
            powerToken_,
            _STARTING_PROPOSAL_FEE,
            _STARTING_MAX_TOTAL_ZERO_REWARD_PER_ACTIVE_EPOCH,
            _STARTING_POWER_TOKEN_THRESHOLD_RATIO,
            _STARTING_ZERO_TOKEN_THRESHOLD_RATIO
        );

        vault = IDualGovernor(governor_).vault();
        zeroToken = IDualGovernor(governor_).zeroToken();

        IPowerTokenDeployer(powerTokenDeployer_).deploy(
            governor_,
            IDualGovernorDeployer(governorDeployer_).allowedCashTokensAt(0),
            bootstrapToken_
        );
    }

    function addToList(bytes32 list_, address account_) external onlyGovernor {
        _valueAt[_getKeyInSet(list_, account_)] = bytes32(uint256(1));

        emit AddressAddedToList(list_, account_);
    }

    function removeFromList(bytes32 list_, address account_) external onlyGovernor {
        delete _valueAt[_getKeyInSet(list_, account_)];

        emit AddressRemovedFromList(list_, account_);
    }

    function updateConfig(bytes32 key_, bytes32 value_) external onlyGovernor {
        emit ConfigUpdated(key_, _valueAt[key_] = value_);
    }

    function reset(address bootstrapToken_) external onlyGovernor {
        address powerToken_ = powerToken = IPowerTokenDeployer(powerTokenDeployer).getNextDeploy();

        address oldGovernor_ = governor;

        address newGovernor_ = governor = IDualGovernorDeployer(governorDeployer).deploy(
            powerToken_,
            IDualGovernor(oldGovernor_).proposalFee(),
            IDualGovernor(oldGovernor_).maxTotalZeroRewardPerActiveEpoch(),
            uint16(IDualGovernor(oldGovernor_).powerTokenThresholdRatio()),
            uint16(IDualGovernor(oldGovernor_).zeroTokenThresholdRatio())
        );

        IPowerTokenDeployer(powerTokenDeployer).deploy(
            newGovernor_,
            IDualGovernorDeployer(governorDeployer).allowedCashTokensAt(0),
            bootstrapToken_
        );
    }

    function get(bytes32 key_) external view returns (bytes32 value_) {
        return _valueAt[key_];
    }

    function get(bytes32[] calldata keys_) external view returns (bytes32[] memory values_) {
        values_ = new bytes32[](keys_.length);

        for (uint256 index_; index_ < keys_.length; ++index_) {
            values_[index_] = _valueAt[keys_[index_]];
        }
    }

    function listContains(bytes32 list_, address account_) external view returns (bool contains_) {
        return _valueAt[_getKeyInSet(list_, account_)] == bytes32(uint256(1));
    }

    function listContains(bytes32 list_, address[] calldata accounts_) external view returns (bool contains_) {
        for (uint256 index_; index_ < accounts_.length; ++index_) {
            if (_valueAt[_getKeyInSet(list_, accounts_[index_])] != bytes32(uint256(1))) return false;
        }

        return true;
    }

    function _getKeyInSet(bytes32 list_, address account_) private pure returns (bytes32 key_) {
        return keccak256(abi.encodePacked(list_, account_));
    }
}
