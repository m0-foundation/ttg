// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IEmergencyGovernor } from "./interfaces/IEmergencyGovernor.sol";
import { IEmergencyGovernorDeployer } from "./interfaces/IEmergencyGovernorDeployer.sol";
import { IPowerTokenDeployer } from "./interfaces/IPowerTokenDeployer.sol";
import { IRegistrar } from "./interfaces/IRegistrar.sol";
import { IStandardGovernor } from "./interfaces/IStandardGovernor.sol";
import { IStandardGovernorDeployer } from "./interfaces/IStandardGovernorDeployer.sol";
import { IZeroGovernor } from "./interfaces/IZeroGovernor.sol";

contract Registrar is IRegistrar {
    uint256 internal constant _MAX_TOTAL_ZERO_REWARD_PER_ACTIVE_EPOCH = 1_000;
    uint256 internal constant _ONE = 10_000;

    address public immutable emergencyGovernorDeployer;
    address public immutable powerTokenDeployer;
    address public immutable standardGovernorDeployer;
    address public immutable vault;
    address public immutable zeroGovernor;
    address public immutable zeroToken;

    address public emergencyGovernor;
    address public powerToken;
    address public standardGovernor;

    mapping(bytes32 key => bytes32 value) internal _valueAt;

    modifier onlyStandardOrEmergencyGovernor() {
        _revertIfNotStandardOrEmergencyGovernor();

        _;
    }

    modifier onlyZeroGovernor() {
        _revertIfNotZeroGovernor();

        _;
    }

    constructor(
        address standardGovernorDeployer_,
        address emergencyGovernorDeployer_,
        address powerTokenDeployer_,
        address bootstrapToken_,
        uint256 standardProposalFee_,
        uint16 emergencyProposalThresholdRatio_
    ) {
        if ((standardGovernorDeployer = standardGovernorDeployer_) == address(0)) {
            revert InvalidStandardGovernorDeployerAddress();
        }

        if ((emergencyGovernorDeployer = emergencyGovernorDeployer_) == address(0)) {
            revert InvalidEmergencyGovernorDeployerAddress();
        }

        if ((powerTokenDeployer = powerTokenDeployer_) == address(0)) {
            revert InvalidPowerTokenDeployerAddress();
        }

        address zeroGovernor_ = zeroGovernor = IStandardGovernorDeployer(standardGovernorDeployer_).zeroGovernor();
        zeroToken = IStandardGovernorDeployer(standardGovernorDeployer_).zeroToken();
        vault = IStandardGovernorDeployer(standardGovernorDeployer_).vault();

        // Deploy the ephemeral `standardGovernor`, `emergencyGovernor`, and `powerToken` contracts, where:
        // - the starting cash token is already defined by the `zeroGovernor` contract
        // - the token to bootstrap the `powerToken` balances and voting powers is defined in the constructor
        // - the starting `emergencyGovernor` threshold ratio is defined as a constant
        // - the starting `standardGovernor` proposal fee is defined as a constant
        (standardGovernor, emergencyGovernor, powerToken) = _deployEphemeralContracts(
            powerTokenDeployer_,
            standardGovernorDeployer_,
            emergencyGovernorDeployer_,
            IZeroGovernor(zeroGovernor_).startingCashToken(),
            bootstrapToken_,
            emergencyProposalThresholdRatio_,
            standardProposalFee_
        );
    }

    function addToList(bytes32 list_, address account_) external onlyStandardOrEmergencyGovernor {
        _valueAt[_getKeyInSet(list_, account_)] = bytes32(uint256(1));

        emit AddressAddedToList(list_, account_);
    }

    function removeFromList(bytes32 list_, address account_) external onlyStandardOrEmergencyGovernor {
        delete _valueAt[_getKeyInSet(list_, account_)];

        emit AddressRemovedFromList(list_, account_);
    }

    function updateConfig(bytes32 key_, bytes32 value_) external onlyStandardOrEmergencyGovernor {
        emit ConfigUpdated(key_, _valueAt[key_] = value_);
    }

    function reset(address bootstrapToken_) external onlyZeroGovernor {
        IStandardGovernor standardGovernor_ = IStandardGovernor(standardGovernor);

        emit ResetExecuted(bootstrapToken_);

        // Redeploy the ephemeral `standardGovernor`, `emergencyGovernor`, and `powerToken` contracts, where:
        // - the cash token is the same cash token in the existing `standardGovernor`
        // - the token to bootstrap the `powerToken` balances and voting powers is defined in the arguments
        // - the `emergencyGovernor` threshold ratio is the same threshold ratio in the existing `emergencyGovernor`
        // - the `standardGovernor` proposal fee is the same proposal fee in the existing `standardGovernor`
        (standardGovernor, emergencyGovernor, powerToken) = _deployEphemeralContracts(
            powerTokenDeployer,
            standardGovernorDeployer,
            emergencyGovernorDeployer,
            standardGovernor_.cashToken(),
            bootstrapToken_,
            IEmergencyGovernor(emergencyGovernor).thresholdRatio(),
            standardGovernor_.proposalFee()
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

    function _deployEphemeralContracts(
        address powerTokenDeployer_,
        address standardGovernorDeployer_,
        address emergencyGovernorDeployer_,
        address cashToken_,
        address bootstrapToken_,
        uint16 emergencyProposalThresholdRatio_,
        uint256 proposalFee_
    ) internal returns (address standardGovernor_, address emergencyGovernor_, address powerToken_) {
        address expectedPowerToken_ = IPowerTokenDeployer(powerTokenDeployer_).getNextDeploy();
        address expectedStandardGovernor_ = IStandardGovernorDeployer(standardGovernorDeployer_).getNextDeploy();

        emergencyGovernor_ = IEmergencyGovernorDeployer(emergencyGovernorDeployer_).deploy(
            expectedPowerToken_,
            expectedStandardGovernor_,
            emergencyProposalThresholdRatio_
        );

        standardGovernor_ = IStandardGovernorDeployer(standardGovernorDeployer_).deploy(
            expectedPowerToken_,
            emergencyGovernor_,
            cashToken_,
            proposalFee_,
            _MAX_TOTAL_ZERO_REWARD_PER_ACTIVE_EPOCH
        );

        if (expectedStandardGovernor_ != standardGovernor_) {
            revert UnexpectedStandardGovernorDeployed(expectedPowerToken_, powerToken_);
        }

        powerToken_ = IPowerTokenDeployer(powerTokenDeployer_).deploy(standardGovernor_, cashToken_, bootstrapToken_);

        if (expectedPowerToken_ != powerToken_) revert UnexpectedPowerTokenDeployed(expectedPowerToken_, powerToken_);

        emit EphemeralContractsDeployed(standardGovernor_, emergencyGovernor_, powerToken_);
    }

    function _getKeyInSet(bytes32 list_, address account_) internal pure returns (bytes32 key_) {
        return keccak256(abi.encodePacked(list_, account_));
    }

    function _revertIfNotStandardOrEmergencyGovernor() internal view {
        if (msg.sender != standardGovernor && msg.sender != emergencyGovernor) {
            revert CallerIsNotStandardOrEmergencyGovernor();
        }
    }

    function _revertIfNotZeroGovernor() internal view {
        if (msg.sender != zeroGovernor) {
            revert CallerIsNotZeroGovernor();
        }
    }
}
