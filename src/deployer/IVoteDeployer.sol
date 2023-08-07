// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.19;

interface IVoteDeployer {
    error CallerIsNotOwner();

    function deployVote(
        string memory name,
        string memory symbol,
        address registrar,
        address value,
        address expectedGovernor,
        bytes32 salt
    ) external returns (address vote);

    function getDeterministicVoteAddress(
        string memory name,
        string memory symbol,
        address registrar,
        address value,
        bytes32 salt
    ) external view returns (address deterministicAddress_);

    function owner() external view returns (address owner);

    function governor() external view returns (address governor);
}
