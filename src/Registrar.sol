// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.21;

import { IEmergencyGovernorDeployer } from "./interfaces/IEmergencyGovernorDeployer.sol";
import { IPowerTokenDeployer } from "./interfaces/IPowerTokenDeployer.sol";
import { IRegistrar } from "./interfaces/IRegistrar.sol";
import { IStandardGovernorDeployer } from "./interfaces/IStandardGovernorDeployer.sol";
import { IZeroGovernor } from "./interfaces/IZeroGovernor.sol";

contract Registrar is IRegistrar {
    address public immutable emergencyGovernorDeployer;
    address public immutable powerTokenDeployer;
    address public immutable standardGovernorDeployer;
    address public immutable vault;
    address public immutable zeroGovernor;
    address public immutable zeroToken;

    mapping(bytes32 key => bytes32 value) internal _valueAt;

    modifier onlyStandardOrEmergencyGovernor() {
        _revertIfNotStandardOrEmergencyGovernor();

        _;
    }

    constructor(address zeroGovernor_) {
        if ((zeroGovernor = zeroGovernor_) == address(0)) revert InvalidZeroGovernorAddress();

        emergencyGovernorDeployer = IZeroGovernor(zeroGovernor_).emergencyGovernorDeployer();

        powerTokenDeployer = IZeroGovernor(zeroGovernor_).powerTokenDeployer();

        address standardGovernorDeployer_ = IZeroGovernor(zeroGovernor_).standardGovernorDeployer();

        standardGovernorDeployer = standardGovernorDeployer_;

        address zeroToken_ = IZeroGovernor(zeroGovernor_).voteToken();

        if ((zeroToken = zeroToken_) == address(0)) revert InvalidZeroTokenAddress();

        address vault_ = IStandardGovernorDeployer(standardGovernorDeployer_).vault();

        if ((vault = vault_) == address(0)) revert InvalidVaultAddress();
    }

    /******************************************************************************************************************\
    |                                      External/Public Interactive Functions                                       |
    \******************************************************************************************************************/

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

    /******************************************************************************************************************\
    |                                       External/Public View/Pure Functions                                        |
    \******************************************************************************************************************/

    function emergencyGovernor() public view returns (address emergencyGovernor_) {
        return IEmergencyGovernorDeployer(emergencyGovernorDeployer).lastDeploy();
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

    function powerToken() external view returns (address powerToken_) {
        return IPowerTokenDeployer(powerTokenDeployer).lastDeploy();
    }

    function standardGovernor() public view returns (address standardGovernor_) {
        return IStandardGovernorDeployer(standardGovernorDeployer).lastDeploy();
    }

    /******************************************************************************************************************\
    |                                          Internal View/Pure Functions                                            |
    \******************************************************************************************************************/

    function _getKeyInSet(bytes32 list_, address account_) internal pure returns (bytes32 key_) {
        return keccak256(abi.encodePacked(list_, account_));
    }

    function _revertIfNotStandardOrEmergencyGovernor() internal view {
        if (msg.sender != standardGovernor() && msg.sender != emergencyGovernor()) {
            revert NotStandardOrEmergencyGovernor();
        }
    }
}
