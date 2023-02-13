// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import {SPOG} from "./SPOG.sol";
import {IGovSPOG} from "./interfaces/IGovSPOG.sol";

/// @title SPOGFactory
/// @notice This contract is used to deploy SPOG contracts
contract SPOGFactory {
    event SPOGDeployed(address indexed addr, uint256 salt);

    /// @notice Create a new SPOG
    /// @param _cash The currency accepted for tax payment in the SPOG (must be ERC20)
    /// @param _taxRange The minimum and maximum value of `tax`
    /// @param _inflator The percentage supply increase in $VOTE for each voting epoch
    /// @param _reward The number of $VALUE to be distributed in each voting epoch
    /// @param _voteTime The duration of a voting epoch
    /// @param _inflatorTime The duration of an auction if $VOTE is inflated (should be less than `VOTE TIME`)
    /// @param _sellTime The duration of an auction if `SELL` is called
    /// @param _forkTime The duration that $VALUE holders have to choose a fork
    /// @param _voteQuorum The fraction of the current $VOTE supply voting "YES" for actions that require a `VOTE QUORUM`
    /// @param _valueQuorum The fraction of the current $VALUE supply voting "YES" required for actions that require a `VALUE QUORUM`
    /// @param _tax The cost (in `cash`) to call various functions
    /// @param _govSPOG The address of the SPOG governance contract
    /// @return the address of the newly deployed contract
    function deploy(
        address _cash,
        uint256[2] memory _taxRange,
        uint256 _inflator,
        uint256 _reward,
        uint256 _voteTime,
        uint256 _inflatorTime,
        uint256 _sellTime,
        uint256 _forkTime,
        uint256 _voteQuorum,
        uint256 _valueQuorum,
        uint256 _tax,
        IGovSPOG _govSPOG,
        uint256 _salt
    ) public returns (SPOG) {
        SPOG spog = new SPOG{salt: bytes32(_salt)}(
            _cash,
            _taxRange,
            _inflator,
            _reward,
            _voteTime,
            _inflatorTime,
            _sellTime,
            _forkTime,
            _voteQuorum,
            _valueQuorum,
            _tax,
            _govSPOG
        );

        // below line is only used for prototype - remove in production
        spogs.push(address(spog));

        return spog;
    }

    /// @dev This function is used to get the bytecode of the SPOG contract to be deployed
    function getBytecode(
        address _cash,
        uint256[2] memory _taxRange,
        uint256 _inflator,
        uint256 _reward,
        uint256 _voteTime,
        uint256 _inflatorTime,
        uint256 _sellTime,
        uint256 _forkTime,
        uint256 _voteQuorum,
        uint256 _valueQuorum,
        uint256 _tax,
        IGovSPOG _govSPOG
    ) public pure returns (bytes memory) {
        bytes memory bytecode = type(SPOG).creationCode;

        return
            abi.encodePacked(
                bytecode,
                abi.encode(
                    _cash,
                    _taxRange,
                    _inflator,
                    _reward,
                    _voteTime,
                    _inflatorTime,
                    _sellTime,
                    _forkTime,
                    _voteQuorum,
                    _valueQuorum,
                    _tax,
                    _govSPOG
                )
            );
    }

    /// @dev Compute the address of the SPOG contract to be deployed
    /// @param bytecode The bytecode of the contract to be deployed
    /// @param _salt is a random number used to create an address
    function predictSPOGAddress(bytes memory bytecode, uint256 _salt)
        public
        view
        returns (address)
    {
        bytes32 hash = keccak256(
            abi.encodePacked(
                bytes1(0xff),
                address(this),
                _salt,
                keccak256(bytecode)
            )
        );

        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint256(hash)));
    }

    /***************************************************/
    /******** Prototype Helpers - NOT FOR PROD ********/
    /*************************************************/

    address[] private spogs;

    // function to get spogs array elements
    function getSpogs() external view returns (address[] memory) {
        return spogs;
    }

    // function to get spogs array length
    function getSpogsLength() external view returns (uint256) {
        return spogs.length;
    }
}
