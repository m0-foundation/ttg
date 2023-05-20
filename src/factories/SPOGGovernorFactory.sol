// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import {SPOGGovernor} from "src/core/governance/SPOGGovernor.sol";
import {ISPOGVotes} from "src/interfaces/tokens/ISPOGVotes.sol";

/// @title SPOGGovernorFactory
/// @notice Factory contract for SPOGGovernor
contract SPOGGovernorFactory {
    event SPOGGovernorDeployed(address indexed addr, uint256 salt);

    /// @dev Deploy a new SPOGGovernor contract
    /// @param votingTokenContract address of the voting token contract
    /// @param quorumNumeratorValue numerator value for quorum
    /// @param votingPeriod_ voting period
    /// @param name_ name of the SPOGGovernor contract
    /// @param _salt salt for the contract address
    /// @return governor address of the deployed SPOGGovernor contract
    function deploy(
        ISPOGVotes votingTokenContract,
        uint256 quorumNumeratorValue,
        uint256 votingPeriod_,
        string memory name_,
        uint256 _salt
    ) public returns (SPOGGovernor) {
        SPOGGovernor governor = new SPOGGovernor{salt: bytes32(_salt)}(
            votingTokenContract,
            votingTokenContract,
            quorumNumeratorValue,
            votingPeriod_,
            name_
        );

        emit SPOGGovernorDeployed(address(governor), _salt);
        return governor;
    }

    /// @dev get the bytecode of the SPOGGovernor contract to be deployed
    /// @param votingTokenContract address of the voting token contract
    /// @param quorumNumeratorValue numerator value for quorum
    /// @param votingPeriod_ voting period
    /// @param name_ name of the SPOGGovernor contract
    /// @return bytecode of the SPOGGovernor contract
    function getBytecode(
        ISPOGVotes votingTokenContract,
        uint256 quorumNumeratorValue,
        uint256 votingPeriod_,
        string memory name_
    ) public pure returns (bytes memory) {
        return abi.encodePacked(
            type(SPOGGovernor).creationCode, abi.encode(votingTokenContract, quorumNumeratorValue, votingPeriod_, name_)
        );
    }

    /// @dev Compute the address of the SPOGGovernor contract to be deployed
    /// @param bytecode bytecode of the SPOGGovernor contract
    /// @param _salt salt for the contract address
    /// @return address of the SPOGGovernor contract
    function predictSPOGGovernorAddress(bytes memory bytecode, uint256 _salt) public view returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), _salt, keccak256(bytecode)));

        // NOTE: cast last 20 bytes of hash to address
        return address(uint160(uint256(hash)));
    }

    fallback() external {
        revert("SPOGGovernorFactory: non-existent function called");
    }
}
