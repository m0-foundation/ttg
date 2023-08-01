// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

import { ISPOGControlled } from "../interfaces/ISPOGControlled.sol";

interface IGovernanceDeployer is ISPOGControlled {
    error GovernorAddressMismatch(address deployed, address expected);
    error VoteAddressMismatch(address deployed, address expected);

    function deployGovernance(bytes memory deployArguments) external returns (address governor, address vote);

    function deployGovernance(
        string memory voteName,
        string memory voteSymbol,
        string memory governorName,
        address value,
        uint256 voteQuorum,
        uint256 valueQuorum,
        bytes32 salt
    ) external returns (address governor, address vote);

    function getGovernanceAddresses(
        bytes memory deployArguments
    ) external view returns (address governor, address vote);

    function getGovernanceAddresses(
        string memory voteName,
        string memory voteSymbol,
        string memory governorName,
        address value,
        uint256 voteQuorum,
        uint256 valueQuorum,
        bytes32 salt
    ) external view returns (address governor, address vote);

    function governorDeployer() external view returns (address governorDeployer);

    function voteDeployer() external view returns (address voteDeployer);
}
