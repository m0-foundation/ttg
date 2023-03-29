// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.17;

import {GovSPOG} from "src/core/GovSPOG.sol";
import {ISPOGVotes} from "src/interfaces/ISPOGVotes.sol";

/// @title GovSPOGFactory
/// @notice Factory contract for GovSPOG
contract GovSPOGFactory {
    event GovSPOGDeployed(address indexed addr, uint256 salt);

    /// @dev Deploy a new GovSPOG contract
    /// @param votingTokenContract address of the voting token contract
    /// @param quorumNumeratorValue numerator value for quorum
    /// @param votingPeriod_ voting period
    /// @param name_ name of the GovSPOG contract
    /// @param _salt salt for the contract address
    /// @return govSpog address of the deployed GovSPOG contract
    function deploy(
        ISPOGVotes votingTokenContract,
        uint256 quorumNumeratorValue,
        uint256 votingPeriod_,
        string memory name_,
        uint256 _salt
    ) public returns (GovSPOG) {
        GovSPOG govSpog = new GovSPOG{salt: bytes32(_salt)}(
            votingTokenContract,
            quorumNumeratorValue,
            votingPeriod_,
            name_
        );

        emit GovSPOGDeployed(address(govSpog), _salt);
        return govSpog;
    }

    /// @dev get the bytecode of the GovSPOG contract to be deployed
    /// @param votingTokenContract address of the voting token contract
    /// @param quorumNumeratorValue numerator value for quorum
    /// @param votingPeriod_ voting period
    /// @param name_ name of the GovSPOG contract
    /// @return bytecode of the GovSPOG contract
    function getBytecode(
        ISPOGVotes votingTokenContract,
        uint256 quorumNumeratorValue,
        uint256 votingPeriod_,
        string memory name_
    ) public pure returns (bytes memory) {
        return abi.encodePacked(
            type(GovSPOG).creationCode, abi.encode(votingTokenContract, quorumNumeratorValue, votingPeriod_, name_)
        );
    }

    /// @dev Compute the address of the GovSPOG contract to be deployed
    /// @param bytecode bytecode of the GovSPOG contract
    /// @param _salt salt for the contract address
    /// @return address of the GovSPOG contract
    function predictGovSPOGAddress(bytes memory bytecode, uint256 _salt) public view returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));

        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint256(hash)));
    }

    fallback() external {
        revert("GovSPOGFactory: non-existent function called");
    }
}
