// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {SPOG} from "src/core/SPOG.sol";
import {ISPOGGovernor} from "src/interfaces/ISPOGGovernor.sol";

/// @title SPOGFactory
/// @notice This contract is used to deploy SPOG contracts
contract SPOGFactory {
    event SPOGDeployed(address indexed addr, uint256 salt);

    /// @notice Create a new SPOG
    /// @param _initSPOGData The data used to initialize spogData
    /// @param _voteVault The address of the $VOTE governor `Vault` contract
    /// @param _valueVault The address of the $VALUE governor `Vault` contract
    /// @param _time The duration of a voting epoch
    /// @param _voteQuorum The fraction of the current $VOTE supply voting "YES" for actions that require a `VOTE QUORUM`
    /// @param _valueQuorum The fraction of the current $VALUE supply voting "YES" required for actions that require a `VALUE QUORUM`
    /// @param _valueFixedInflationAmount The fixed inflation amount for the $VALUE token
    /// @param _voteGovernor The address of the SPOG governor contract for $VOTE token
    /// @param _valueGovernor The address of the SPOG governor contract for $VALUE token
    /// @param _salt The salt used to deploy the SPOG contract
    /// @return the address of the newly deployed contract
    function deploy(
        bytes memory _initSPOGData,
        address _voteVault,
        address _valueVault,
        uint256 _time,
        uint256 _voteQuorum,
        uint256 _valueQuorum,
        uint256 _valueFixedInflationAmount,
        ISPOGGovernor _voteGovernor,
        ISPOGGovernor _valueGovernor,
        uint256 _salt
    ) public returns (SPOG) {
        SPOG spog = new SPOG{salt: bytes32(_salt)}(
            _initSPOGData,
            _voteVault,
            _valueVault,
            _time,
            _voteQuorum,
            _valueQuorum,
            _valueFixedInflationAmount,
            _voteGovernor,
            _valueGovernor
        );

        emit SPOGDeployed(address(spog), _salt);

        return spog;
    }

    /// @dev This function is used to get the bytecode of the SPOG contract to be deployed
    function getBytecode(
        bytes memory _initSPOGData,
        address _valueVault,
        address _voteVault,
        uint256 _time,
        uint256 _voteQuorum,
        uint256 _valueQuorum,
        uint256 _valueFixedInflationAmount,
        ISPOGGovernor _voteGovernor,
        ISPOGGovernor _valueGovernor
    ) public pure returns (bytes memory) {
        bytes memory bytecode = type(SPOG).creationCode;

        return abi.encodePacked(
            bytecode,
            abi.encode(
                _initSPOGData,
                _voteVault,
                _valueVault,
                _time,
                _voteQuorum,
                _valueQuorum,
                _valueFixedInflationAmount,
                _voteGovernor,
                _valueGovernor
            )
        );
    }

    /// @dev Compute the address of the SPOG contract to be deployed
    /// @param bytecode The bytecode of the contract to be deployed
    /// @param _salt is a random number used to create an address
    function predictSPOGAddress(bytes memory bytecode, uint256 _salt) public view returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));

        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint256(hash)));
    }

    fallback() external {
        revert("SPOGFactory: non-existent function");
    }
}
