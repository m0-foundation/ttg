// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.23;

import { IEmergencyGovernorDeployer } from "./interfaces/IEmergencyGovernorDeployer.sol";
import { IPowerTokenDeployer } from "./interfaces/IPowerTokenDeployer.sol";
import { IRegistrar } from "./interfaces/IRegistrar.sol";
import { IStandardGovernorDeployer } from "./interfaces/IStandardGovernorDeployer.sol";
import { IZeroGovernor } from "./interfaces/IZeroGovernor.sol";

/// @title A book of record of SPOG-specific contracts and arbitrary key-value pairs and lists.
contract Registrar is IRegistrar {
    /// @inheritdoc IRegistrar
    address public immutable emergencyGovernorDeployer;

    /// @inheritdoc IRegistrar
    address public immutable standardGovernorDeployer;

    /// @inheritdoc IRegistrar
    address public immutable zeroGovernor;

    /// @notice A mapping of keys to values.
    mapping(bytes32 key => bytes32 value) internal _valueAt;

    /// @notice Revert if the caller is not the Standard Governor nor the Emergency Governor.
    modifier onlyStandardOrEmergencyGovernor() {
        _revertIfNotStandardOrEmergencyGovernor();
        _;
    }

    /**
     * @notice Constructs a new Registrar contract.
     * @param zeroGovernor_ The address of the ZeroGovernor contract.
     */
    constructor(address zeroGovernor_) {
        if ((zeroGovernor = zeroGovernor_) == address(0)) revert InvalidZeroGovernorAddress();

        IZeroGovernor zeroGovernorInstance_ = IZeroGovernor(zeroGovernor_);

        if ((emergencyGovernorDeployer = zeroGovernorInstance_.emergencyGovernorDeployer()) == address(0))
            revert InvalidEmergencyGovernorDeployerAddress();

        if ((standardGovernorDeployer = zeroGovernorInstance_.standardGovernorDeployer()) == address(0))
            revert InvalidStandardGovernorDeployerAddress();
    }

    /******************************************************************************************************************\
    |                                      External/Public Interactive Functions                                       |
    \******************************************************************************************************************/

    /// @inheritdoc IRegistrar
    function addToList(bytes32 list_, address account_) external onlyStandardOrEmergencyGovernor {
        _valueAt[_getIsInListKey(list_, account_)] = bytes32(uint256(1));

        emit AddressAddedToList(list_, account_);
    }

    /// @inheritdoc IRegistrar
    function removeFromList(bytes32 list_, address account_) external onlyStandardOrEmergencyGovernor {
        delete _valueAt[_getIsInListKey(list_, account_)];

        emit AddressRemovedFromList(list_, account_);
    }

    /// @inheritdoc IRegistrar
    function setKey(bytes32 key_, bytes32 value_) external onlyStandardOrEmergencyGovernor {
        emit KeySet(key_, _valueAt[_getValueKey(key_)] = value_);
    }

    /******************************************************************************************************************\
    |                                       External/Public View/Pure Functions                                        |
    \******************************************************************************************************************/

    /// @inheritdoc IRegistrar
    function get(bytes32 key_) external view returns (bytes32 value_) {
        return _valueAt[_getValueKey(key_)];
    }

    /// @inheritdoc IRegistrar
    function get(bytes32[] calldata keys_) external view returns (bytes32[] memory values_) {
        values_ = new bytes32[](keys_.length);

        for (uint256 index_; index_ < keys_.length; ++index_) {
            values_[index_] = _valueAt[_getValueKey(keys_[index_])];
        }
    }

    /// @inheritdoc IRegistrar
    function listContains(bytes32 list_, address account_) external view returns (bool contains_) {
        return _valueAt[_getIsInListKey(list_, account_)] == bytes32(uint256(1));
    }

    /// @inheritdoc IRegistrar
    function listContains(bytes32 list_, address[] calldata accounts_) external view returns (bool contains_) {
        for (uint256 index_; index_ < accounts_.length; ++index_) {
            if (_valueAt[_getIsInListKey(list_, accounts_[index_])] != bytes32(uint256(1))) return false;
        }

        return true;
    }

    /// @inheritdoc IRegistrar
    function emergencyGovernor() public view returns (address emergencyGovernor_) {
        return IEmergencyGovernorDeployer(emergencyGovernorDeployer).lastDeploy();
    }

    /// @inheritdoc IRegistrar
    function standardGovernor() public view returns (address standardGovernor_) {
        return IStandardGovernorDeployer(standardGovernorDeployer).lastDeploy();
    }

    /******************************************************************************************************************\
    |                                          Internal View/Pure Functions                                            |
    \******************************************************************************************************************/

    function _getValueKey(bytes32 key_) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("VALUE", key_));
    }

    function _getIsInListKey(bytes32 list_, address account_) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("IN_LIST", list_, account_));
    }

    function _revertIfNotStandardOrEmergencyGovernor() internal view {
        if (msg.sender != standardGovernor() && msg.sender != emergencyGovernor()) {
            revert NotStandardOrEmergencyGovernor();
        }
    }
}
